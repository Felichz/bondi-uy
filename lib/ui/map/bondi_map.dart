// Interactive vector map of BondiUY.
//
// Draws OpenStreetMap vector tiles in the app's style (light
// or dark), the trip routes and vector markers. The camera is
// set by the UI from an [Encuadre]; the user can move it by hand.
//
// During a trip the camera follows the user frame by frame, and the markers
// that move (the user, the bus) glide between two readings instead of
// jumping.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../contract/model.dart';
import 'framing.dart';
import 'scene.dart';
import 'map_style.dart';
import 'vehicles.dart';
import 'scene_painter.dart';
import 'projection.dart';
import 'tiles/tile_source.dart';
import 'tiles/tile_manager.dart';

const _zoomMin = 10.0;
const _zoomMax = 18.5;

/// Lets the UI know whether the user moved the map, so it can re-frame.
class MapController extends ChangeNotifier {
  bool _free = false;
  VoidCallback? _recenter;

  /// true if the user moved the camera by hand (tracking is paused).
  bool get free => _free;

  void _markFree(bool v) {
    if (_free == v) return;
    _free = v;
    notifyListeners();
  }

  void recenter() => _recenter?.call();
}

class BondiMap extends StatefulWidget {
  final MapScene scene;
  final Framing? framing;
  final MapStyle style;

  /// Areas covered by panels (logical px): the framing avoids them.
  final EdgeInsets margins;
  final MapController? controller;
  final TileSource source;
  final bool decodeInIsolate;
  final void Function(String idStop)? onTapStop;
  final VoidCallback? onTapMap;
  final Coordinate centerInitial;

  const BondiMap({
    super.key,
    required this.scene,
    required this.source,
    this.style = MapStyle.light,
    this.framing,
    this.margins = EdgeInsets.zero,
    this.controller,
    this.decodeInIsolate = true,
    this.onTapStop,
    this.onTapMap,
    this.centerInitial = const Coordinate(-34.9011, -56.1645),
  });

  @override
  State<BondiMap> createState() => _BondiMapState();
}

class _BondiMapState extends State<BondiMap> with TickerProviderStateMixin {
  // One manager per style: switching from light to dark and back does not redraw.
  final Map<Brightness, TileManager> _managers = {};
  late SceneDrawer _painter;
  late Camera _camera = Camera.at(widget.centerInitial, 13);
  late final AnimationController _anim;
  late final AnimationController _heartbeat;
  Camera? _from, _toward;
  Size _size = Size.zero;
  String? _framedKey;

  Camera? _gestureStartCamera;
  Offset? _focusStart;
  Offset? _doubleTapAt;

  /// Frame clock: glides markers and follows the user. It only runs
  /// while something is moving.
  late final Ticker _clock;
  Duration _lastTick = Duration.zero;

  /// Moving markers (the user, the bus): their position is predicted between
  /// readings, and they blend when changing shape or leaving.
  final VehiclesScene _vehicles = VehiclesScene();
  Timer? _resume;

  /// The transition between framings chases the live target (the user
  /// keeps moving while the camera travels).
  bool _towardLive = false;

  /// The camera has already reached the target and follows it exactly. It lets go if the
  /// target jumps (the framing changed, a panel's height changed).
  bool _engaged = false;
  Camera? _previousTarget;

  TileManager _manager(MapStyle e) =>
      _managers[e.brightness] ??= TileManager(
        widget.source,
        e,
        useIsolate: widget.decodeInIsolate,
      )..addListener(_repaint);

  @override
  void initState() {
    super.initState();
    _painter = SceneDrawer(_manager(widget.style), widget.style);
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..addListener(() {
      final d = _from;
      final e = widget.framing;
      if (_towardLive && e != null) {
        // The destination moves with the user and can jump (a panel's height
        // changes): it is chased smoothly, never copied all at once.
        final live = _target(e);
        final h = _toward;
        if (live != null && h != null) {
          _toward = Camera.interpolate(h, live, 0.2);
        }
      }
      final h = _toward;
      if (d == null || h == null) return;
      final t = Curves.easeInOutCubic.transform(_anim.value);
      setState(() => _camera = Camera.interpolate(d, h, t));
    });
    // When a transition ends, tracking resumes from there, already
    // locked on if it was chasing the live target (there is nothing to correct).
    _anim.addStatusListener((st) {
      if (st == AnimationStatus.completed) {
        _engaged = _towardLive;
        _previousTarget = _engaged ? _camera : null;
        _towardLive = false;
        _ensureClock();
      }
    });
    _heartbeat = AnimationController(
      vsync: this,
      // One cycle: two pulses, and the balloon markers float.
      duration: const Duration(milliseconds: 3200),
    );
    _clock = createTicker(_onTick);
    widget.controller?._recenter = _recenter;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateHeartbeat();
  }

  @override
  void didUpdateWidget(BondiMap old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      widget.controller?._recenter = _recenter;
    }
    if (old.source != widget.source) {
      for (final g in _managers.values) {
        g
          ..removeListener(_repaint)
          ..dispose();
      }
      _managers.clear();
    }
    if (old.style != widget.style || old.source != widget.source) {
      _painter = SceneDrawer(_manager(widget.style), widget.style);
    }
    _updateHeartbeat();
    _synchronizeVehicles();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyFraming();
    });
  }

  void _repaint() {
    if (mounted) setState(() {});
  }

  bool get _withoutAnimations =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Pulses and dashed lines only run when something live is in the scene.
  void _updateHeartbeat() {
    final needsHeartbeat = !_withoutAnimations && widget.scene.hasHeartbeat;
    if (needsHeartbeat && !_heartbeat.isAnimating) {
      _heartbeat.repeat();
    } else if (!needsHeartbeat && _heartbeat.isAnimating) {
      _heartbeat.stop();
    }
  }

  Offset get _half => Offset(
    (_size.width / 2).floorToDouble(),
    (_size.height / 2).floorToDouble(),
  );

  // --- moving markers ----------------------------------------------

  void _synchronizeVehicles() {
    _vehicles.synchronize(
      widget.scene,
      _now,
      fuse: !_withoutAnimations && !_size.isEmpty,
    );
    _ensureClock();
  }

  /// Current frame time in seconds (respects the fake time used by the
  /// tests).
  double get _now {
    final b = SchedulerBinding.instance;
    if (b.schedulerPhase != SchedulerPhase.idle) {
      _lastNow = b.currentFrameTimeStamp.inMicroseconds / 1e6;
    }
    return _lastNow;
  }

  double _lastNow = 0;

  MapScene get _sceneShown => _vehicles.shown(widget.scene, _now);

  // --- clock: glides and tracking ---------------------------------------

  bool get _following {
    final e = widget.framing;
    return e != null &&
        e.tracking == Tracking.continuous &&
        _framedKey == e.key &&
        !(widget.controller?.free ?? false) &&
        !_anim.isAnimating &&
        _gestureStartCamera == null;
  }

  void _ensureClock() {
    if (!mounted) return;
    final now = _now;
    final makes = _vehicles.animating(now) || _following;
    if (makes && !_clock.isActive) {
      _lastTick = Duration.zero;
      _clock.start();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _lastTick = elapsed;
    final now = _now;
    var follows = _vehicles.advance(now);
    var camera = _camera;
    if (_following) {
      final target = _target(widget.framing!);
      if (target != null) {
        // Did the target move gradually (the user walking) or jump
        // (the group changed, a panel's height)? If it jumped, let go
        // and catch up to it smoothly.
        final previous = _previousTarget;
        _previousTarget = target;
        if (previous != null) {
          final jump =
              ((target.center - previous.center) * camera.scaleWorld).distance +
              (target.zoom - previous.zoom).abs() * 300;
          if (jump > 6) _engaged = false;
        }
        final dz = target.zoom - camera.zoom;
        final dc = (target.center - camera.center) * camera.scaleWorld;
        final k = 1 - math.exp(-dt / 0.35);
        if (_engaged) {
          // Stuck to the user (no lag: the dot does not "swim" on the
          // screen); the zoom adjusts smoothly.
          camera = Camera(target.center, camera.zoom + dz * k);
          if (dz.abs() > 0.002) follows = true;
        } else if (dz.abs() < 0.004 && dc.distance < 0.5) {
          camera = target;
          _engaged = true;
        } else {
          // Catching up with inertia (time constant ~0.35 s).
          camera = Camera(
            Offset.lerp(camera.center, target.center, k)!,
            camera.zoom + dz * k,
          );
          follows = true;
        }
      }
    }
    if (!follows) _clock.stop();
    setState(() => _camera = camera);
  }

  /// Ideal camera for the framing at this instant, with the moving markers
  /// at their predicted position.
  Camera? _target(Framing e) {
    if (_size.isEmpty) return null;
    final essential = [
      for (final p in e.points) mercator(p),
      for (final k in e.vehicles)
        if (_vehicles.position(k) case final p?) p,
    ];
    final extras = [
      for (final k in e.extras)
        if (_vehicles.position(k) case final p?) p,
    ];
    if (essential.isEmpty) return null;
    final v = _usableArea;
    Camera framing(List<Offset> pts) => frameMercator(
      pts,
      width: _size.width,
      height: _size.height,
      top: v.top,
      bottom: _size.height - v.bottom,
      left: v.left,
      right: _size.width - v.right,
      zoomMax: e.zoomMax,
      zoomMin: _zoomMin,
    );
    if (extras.isNotEmpty) {
      final all = framing([...essential, ...extras]);
      if (all.zoom >= math.max(e.zoomMin, e.zoomExtras) - 0.5) return all;
    }
    var cam = framing(essential);
    final anchor = _vehicles.position(e.anchor ?? '');
    if (anchor == null || cam.zoom >= e.zoomMin) return cam;
    // Not even the essentials fit with a readable zoom: it zooms in to the minimum and
    // shifts toward the group without the anchor (the user) leaving the view.
    cam = Camera(cam.center, e.zoomMin);
    final safe = v.deflate(math.min(v.width, v.height) * 0.14);
    final a = cam.toCanvas(anchor, _half);
    final inside = Offset(
      a.dx.clamp(safe.left, math.max(safe.left, safe.right)),
      a.dy.clamp(safe.top, math.max(safe.top, safe.bottom)),
    );
    return cam.copyWith(center: cam.center + (a - inside) / cam.scaleWorld);
  }

  /// Canvas area where the important things should be seen: without panels and with
  /// room for what sticks out of the markers (the bus badge, the pin).
  Rect get _usableArea {
    final m = widget.margins;
    return Rect.fromLTRB(
      m.left + 56,
      m.top + 64,
      _size.width - m.right - 56,
      _size.height - m.bottom - 28,
    );
  }

  void _applyFraming({bool force = false}) {
    final e = widget.framing;
    if (e == null || _size.isEmpty) return;
    final freshKey = e.key != _framedKey;
    if (freshKey) {
      _resume?.cancel();
      widget.controller?._markFree(false);
    }
    final free = widget.controller?.free ?? false;
    if (!force && !freshKey) {
      if (free) return;
      switch (e.tracking) {
        case Tracking.none:
          return;
        case Tracking.continuous:
          // The clock follows it frame by frame (also with "remove
          // animations": it is the real position moving, not decoration).
          _ensureClock();
          return;
        case Tracking.ifExiting:
          final destination = _target(e);
          if (destination == null) return;
          // Move only if something falls out of view or there is too much zoom.
          final gap = (destination.zoom - _camera.zoom).abs();
          if (gap < 0.6 && _allVisible(e.points)) return;
          _animateTo(destination, fast: true);
          return;
      }
    }
    final destination = _target(e);
    if (destination == null) return;
    _framedKey = e.key;
    _animateTo(destination, live: e.tracking == Tracking.continuous);
  }

  bool _allVisible(List<Coordinate> pts) {
    final m = widget.margins;
    final safe = Rect.fromLTRB(
      m.left + 40,
      m.top + 56,
      _size.width - m.right - 40,
      _size.height - m.bottom - 20,
    );
    return pts.every(
      (p) => safe.contains(_camera.toCanvas(mercator(p), _half)),
    );
  }

  void _animateTo(Camera destination, {bool fast = false, bool live = false}) {
    _engaged = false;
    _previousTarget = null;
    _towardLive = live;
    final distanceZoom = (destination.zoom - _camera.zoom).abs();
    if (_anim.isAnimating) _anim.stop();
    _from = _camera;
    _toward = destination;
    if (_withoutAnimations) {
      setState(() => _camera = destination);
      return;
    }
    _anim.duration = Duration(
      milliseconds:
          fast ? 500 : (550 + 90 * distanceZoom).clamp(550, 1100).round(),
    );
    _anim.forward(from: 0);
  }

  void _recenter() {
    _resume?.cancel();
    widget.controller?._markFree(false);
    _framedKey = null;
    _applyFraming(force: true);
  }

  /// During a trip, if the user moved the map and let go, the camera comes back
  /// on its own after a while.
  void _scheduleResume() {
    _resume?.cancel();
    final wait = widget.framing?.resumeAfter;
    if (wait != null && (widget.controller?.free ?? false)) {
      _resume = Timer(wait, () {
        if (mounted && (widget.controller?.free ?? false)) _recenter();
      });
    }
    _ensureClock();
  }

  // --- gestures ----------------------------------------------------------

  void _onStart(ScaleStartDetails d) {
    _resume?.cancel();
    _engaged = false;
    _towardLive = false;
    _anim.stop();
    _toward = null;
    _gestureStartCamera = _camera;
    _focusStart = d.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final start = _gestureStartCamera;
    final focusStart = _focusStart;
    if (start == null || focusStart == null) return;
    final focus = d.localFocalPoint;
    final zoom = (start.zoom + math.log(d.scale) / math.ln2).clamp(
      _zoomMin,
      _zoomMax,
    );
    final underFocus = start.fromCanvas(focusStart, _half);
    final scale = sizeTile * math.pow(2, zoom);
    final center = underFocus - (focus - _half) / scale.toDouble();
    if ((focus - focusStart).distance > 6 || (d.scale - 1).abs() > 0.03) {
      widget.controller?._markFree(true);
    }
    setState(() => _camera = Camera(center, zoom));
  }

  void _onFinish(ScaleEndDetails d) {
    _gestureStartCamera = null;
    _scheduleResume();
    final v = d.velocity.pixelsPerSecond;
    if (v.distance < 250 || !(widget.controller?.free ?? true)) return;
    // Brief inertia, decelerating.
    final scale = _camera.scaleWorld;
    _from = _camera;
    _toward = _camera.copyWith(center: _camera.center - (v * 0.22) / scale);
    _anim.duration = const Duration(milliseconds: 420);
    _anim.forward(from: 0);
  }

  void _onTap(TapUpDetails d) {
    final p = d.localPosition;
    String? best;
    var bestD = 18.0;
    for (final (id, pos) in _painter.visibleStops) {
      final dist = (pos - p).distance;
      if (dist < bestD) {
        bestD = dist;
        best = id;
      }
    }
    if (best != null) {
      widget.onTapStop?.call(best);
    } else {
      widget.onTapMap?.call();
    }
  }

  void _onDoubleTap() {
    final focus = _doubleTapAt;
    if (focus == null) return;
    final under = _camera.fromCanvas(focus, _half);
    final z = (_camera.zoom + 1).clamp(_zoomMin, _zoomMax);
    final scale = sizeTile * math.pow(2, z);
    widget.controller?._markFree(true);
    _animateTo(
      Camera(under - (focus - _half) / scale.toDouble(), z),
      fast: true,
    );
    _scheduleResume();
  }

  @override
  void dispose() {
    _resume?.cancel();
    _clock.dispose();
    _anim.dispose();
    _heartbeat.dispose();
    for (final g in _managers.values) {
      g
        ..removeListener(_repaint)
        ..dispose();
    }
    if (widget.controller?._recenter == _recenter) {
      widget.controller?._recenter = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _painter.family = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        if (size != _size) {
          final first = _size.isEmpty;
          _size = size;
          if (first) {
            _synchronizeVehicles();
            final e = widget.framing;
            final c = e == null ? null : _target(e);
            if (c != null) {
              _camera = c;
              _framedKey = e!.key;
            }
          }
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: _onStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onFinish,
          onTapUp: _onTap,
          onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
          onDoubleTap: _onDoubleTap,
          child: CustomPaint(
            size: size,
            isComplex: true,
            painter: _PainterMap(
              painter: _painter,
              camera: _camera,
              scene: _sceneShown,
              heartbeat: _heartbeat,
              margins: widget.margins,
              free: widget.controller?.free ?? false,
            ),
          ),
        );
      },
    );
  }
}

class _PainterMap extends CustomPainter {
  final SceneDrawer painter;
  final Camera camera;
  final MapScene scene;
  final Animation<double> heartbeat;
  final EdgeInsets margins;
  final bool free;

  _PainterMap({
    required this.painter,
    required this.camera,
    required this.scene,
    required this.heartbeat,
    required this.margins,
    required this.free,
  }) : super(repaint: heartbeat);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.clipRect(Offset.zero & size);
    painter.paint(
      canvas,
      size,
      camera,
      scene,
      phase: heartbeat.value,
      margins: margins,
      free: free,
    );
  }

  @override
  bool shouldRepaint(_PainterMap old) => true;
}
