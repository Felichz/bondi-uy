// Composes one map frame in logical pixels: tiles, routes,
// street labels, stops, vector markers and floating balloons.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../contract/model.dart';
import '../formats.dart';
import 'scene.dart';
import 'map_style.dart';
import 'projection.dart';
import 'tiles/tile_manager.dart';
import 'tiles/tile_painter.dart';
import '../texts/texts.dart';

class SceneDrawer {
  final TileManager tiles;
  final MapStyle style;
  SceneDrawer(this.tiles, this.style);

  /// The app's font family (a CustomPainter does not inherit the theme).
  String? family;

  List<NetworkStop>? _networkCache;
  List<Offset> _networkMercator = const [];
  final _texts = <String, TextPainter>{};

  /// Labels placed in the last frame (diagnostics and tests).
  final List<String> labelsPlaced = [];
  int labelsCandidates = 0;

  /// Balloons drawn in the last frame (diagnostics and tests).
  final List<String> balloonsPlaced = [];

  /// Where they were drawn (diagnostics and tests).
  final List<Rect> balloonBoxes = [];

  /// Where the user ended up in the last frame (diagnostics and tests).
  Offset? userOnScreen;

  /// Where the incoming bus ended up in the last frame (diagnostics and tests).
  Offset? busOnScreen;

  /// The user was drawn above the bus (diagnostics and tests).
  bool userInBus = false;

  /// Heading used to draw the user walking (diagnostics and tests).
  double? headingUser;

  /// Text of the edge indicator, if drawn (diagnostics and tests).
  String? targetInBorder;

  /// Text of the edge indicator for the incoming bus (diagnostics and tests).
  String? busInBorder;

  /// The last painter that drew a frame (diagnostics and tests).
  @visibleForTesting
  static SceneDrawer? last;

  /// Camera of the last frame (diagnostics and tests).
  Camera? camera;

  /// Network stops visible in the last frame (for tapping).
  final List<(String, Offset)> visibleStops = [];

  /// [fase] advances continuously from 0 to 1 (a ~3 s cycle): pulses, dashes
  /// that move and balloons that float.
  void paint(
    Canvas c,
    Size size,
    Camera cam,
    MapScene scene, {
    double phase = 0,
    EdgeInsets margins = EdgeInsets.zero,
    bool free = false,

    /// Floating controls over the map: no balloon or street name under them.
    List<Rect> obstacles = const [],
  }) {
    final half = Offset(
      (size.width / 2).floorToDouble(),
      (size.height / 2).floorToDouble(),
    );
    Offset toScreen(Coordinate co) => cam.toCanvas(mercator(co), half);
    last = this;
    camera = cam;

    _tiles(c, size, cam, half);

    // Visible marks, in drawing order.
    final order = <(MapMarker, Offset)>[
      for (final m in scene.marks) (m, toScreen(m.coordinate)),
    ]..removeWhere(
      (e) =>
          e.$2.dx < -80 ||
          e.$2.dy < -80 ||
          e.$2.dx > size.width + 80 ||
          e.$2.dy > size.height + 80,
    );
    order.sort((a, b) => _priority(a.$1) - _priority(b.$1));

    // Intermediate stops: at far zoom they are thinned out so they don't clog the line.
    final route = <(MarkerStopRoute, Offset)>[];
    for (final (m, p) in order) {
      if (m is! MarkerStopRoute) continue;
      if (m.status != RouteStopStatus.next &&
          (cam.zoom < 13.5 || route.any((e) => (e.$2 - p).distance < 11))) {
        continue;
      }
      route.add((m, p));
    }

    final area = Rect.fromLTRB(
      8,
      margins.top + 6,
      size.width - 8,
      size.height - margins.bottom - 6,
    );
    final boxesMarks = <Rect>[
      for (final (m, p) in order)
        if (m is! MarkerStopRoute && m is! MarkerLeg) _markerBox(m, p),
    ];
    final balloons = _locateBalloons(
      [
        for (final e in order)
          if (scene.opacity(e.$1) >= 1) e,
      ],
      area,
      boxesMarks,
      phase,
      obstacles,
    );
    balloonBoxes
      ..clear()
      ..addAll([for (final g in balloons) g.box]);

    final reserved = <Rect>[
      Rect.fromLTWH(0, 0, size.width, margins.top),
      Rect.fromLTWH(
        0,
        size.height - margins.bottom,
        size.width,
        margins.bottom,
      ),
      ...boxesMarks,
      ...obstacles,
      for (final g in balloons) g.box,
    ];
    _labels(c, size, cam, half, reserved);

    _networkStops(c, size, cam, half, scene);

    for (final t in scene.strokes) {
      _stroke(c, [for (final p in t.points) toScreen(p)], t.style, phase);
    }

    for (final (m, p) in route) {
      _stopRoute(c, m, p, phase);
    }
    userOnScreen = null;
    headingUser = null;
    busOnScreen = null;
    userInBus = false;
    for (final (m, p) in order) {
      if (m is MarkerStopRoute) continue;
      if (m is MarkerUser || m is MarkerUserInBus) userOnScreen = p;
      if (m is MarkerUser && m.walking) headingUser = m.heading;
      if (m is MarkerBus) busOnScreen = p;
      if (m is MarkerUserInBus) userInBus = true;
      final a = scene.opacity(m);
      if (a < 1) {
        if (a <= 0.01) continue;
        c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, a));
        _marker(c, m, p, phase);
        c.restore();
      } else {
        _marker(c, m, p, phase);
      }
    }

    balloonsPlaced.clear();
    for (final g in balloons) {
      _balloon(c, g, phase);
      balloonsPlaced.add(g.balloon?.title ?? g.leg!.text);
    }

    // What matters and is out of view is flagged at the edge: the incoming bus
    // (where it is and how far it has to go) and your destination.
    targetInBorder = null;
    busInBorder = null;
    final inBorder = <Rect>[];
    for (final (m, p) in [
      for (final m in scene.marks) (m, toScreen(m.coordinate)),
    ]) {
      if (m is! MarkerBus || scene.opacity(m) < 1) continue;
      final text =
          '${m.line} · ${m.minutes <= 0 ? tx.arrivingLower : minutes(m.minutes)}';
      if (_inBorder(
        c,
        p,
        area,
        inBorder,
        text: text,
        colorText: m.live ? style.live : style.scheduled,
        backgroundIcon: style.bus,
        icon: Icons.directions_bus_rounded,
      )) {
        busInBorder = text;
      }
    }
    final obj = scene.target;
    if (obj != null &&
        (obj.always || free) &&
        _inBorder(
          c,
          toScreen(obj.coordinate),
          area,
          inBorder,
          text: obj.text,
          colorText: style.ink,
          backgroundIcon: style.walk,
          icon: Icons.navigation_rounded,
          rotateIcon: true,
        )) {
      targetInBorder = obj.text;
    }

    _attribution(c, size, margins.bottom);
  }

  int _priority(MapMarker m) => switch (m) {
    MarkerStopRoute() => -1,
    MarkerLeg() => 0,
    MarkerOrigin() => 0,
    MarkerStop() => 1,
    MarkerStopQueried() => 2,
    MarkerDestination() => 3,
    MarkerBus() => 4,
    MarkerUser() => 5,
    MarkerUserInBus() => 6,
  };

  /// What each marker occupies on screen (so labels avoid it).
  Rect _markerBox(MapMarker m, Offset p) => switch (m) {
    MarkerDestination() => Rect.fromLTRB(
      p.dx - 16,
      p.dy - 42,
      p.dx + 16,
      p.dy + 4,
    ),
    MarkerUserInBus() => Rect.fromLTRB(
      p.dx - 44,
      p.dy - 42,
      p.dx + 44,
      p.dy + 8,
    ),
    _ => Rect.fromCenter(center: p, width: 34, height: 34),
  };

  // --- network stops -----------------------------------------------------

  void _networkStops(
    Canvas c,
    Size size,
    Camera cam,
    Offset half,
    MapScene scene,
  ) {
    visibleStops.clear();
    final faint = scene.networkStopsFaint;
    if (scene.networkStops.isEmpty || cam.zoom < (faint ? 16 : 15)) return;
    if (!identical(_networkCache, scene.networkStops)) {
      _networkCache = scene.networkStops;
      _networkMercator = [
        for (final p in scene.networkStops) mercator(p.stop.coordinate),
      ];
    }
    final r = faint ? 3.0 : (cam.zoom >= 16.5 ? 5.0 : 3.5);
    final background =
        Paint()
          ..color = style.markerBackground.withValues(alpha: faint ? 0.8 : 1);
    final ring =
        Paint()
          ..color = style.networkStop.withValues(alpha: faint ? 0.4 : 1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r > 4 ? 2 : 1.5;
    for (var i = 0; i < _networkMercator.length; i++) {
      final a = cam.toCanvas(_networkMercator[i], half);
      if (a.dx < -10 ||
          a.dy < -10 ||
          a.dx > size.width + 10 ||
          a.dy > size.height + 10) {
        continue;
      }
      if (!faint) visibleStops.add((scene.networkStops[i].stop.id, a));
      c.drawCircle(a, r, background);
      c.drawCircle(a, r, ring);
      // Up close, the stop shows its icon: it is recognizable without a legend.
      if (!faint && cam.zoom >= 17.2) {
        c.drawCircle(a, 9, background);
        c.drawCircle(
          a,
          9,
          Paint()
            ..color = style.networkStop
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        _icon(c, Icons.directions_bus_rounded, a, 11, style.networkStop);
      }
    }
  }

  // --- tiles ---------------------------------------------------------------

  void _tiles(Canvas c, Size size, Camera cam, Offset half) {
    c.drawRect(Offset.zero & size, Paint()..color = style.land);
    final zi = cam.zoom.floor().clamp(2, 19);
    final side = sizeTile * math.pow(2, cam.zoom - zi).toDouble();
    final n = 1 << zi;
    final origin = cam.fromCanvas(Offset.zero, half) * n.toDouble();
    final end =
        cam.fromCanvas(Offset(size.width, size.height), half) * n.toDouble();
    final res = tiles.resolution.toDouble();
    final paint = Paint()..filterQuality = FilterQuality.medium;
    double border(int t, double o) => (t - o) * side;
    for (var ty = origin.dy.floor(); ty <= end.dy.floor(); ty++) {
      for (var tx = origin.dx.floor(); tx <= end.dx.floor(); tx++) {
        // Half a pixel of overlap: no seams with the antialiasing.
        final dst = Rect.fromLTRB(
          border(tx, origin.dx) - 0.5,
          border(ty, origin.dy) - 0.5,
          border(tx + 1, origin.dx) + 0.5,
          border(ty + 1, origin.dy) + 0.5,
        );
        final img = tiles.image(zi, tx, ty);
        if (img != null) {
          c.drawImageRect(img, Rect.fromLTWH(0, 0, res, res), dst, paint);
          continue;
        }
        final parent = tiles.image(zi - 1, tx >> 1, ty >> 1);
        if (parent != null) {
          final src = Rect.fromLTWH(
            (tx & 1) * res / 2,
            (ty & 1) * res / 2,
            res / 2,
            res / 2,
          );
          c.drawImageRect(parent, src, dst, paint);
        }
      }
    }
  }

  // --- labels ---------------------------------------------------------------

  static const _zoomMin = {
    'motorway': 12.0,
    'trunk': 12.0,
    'primary': 13.0,
    'secondary': 14.0,
    'tertiary': 15.0,
    'minor': 15.5,
    'service': 17.0,
    'neighborhood': 11.0,
  };

  TextPainter _text(
    String text, {
    required bool neighborhood,
    required double size,
  }) {
    final key = '${neighborhood ? 'b' : 'c'}$size|$text';
    return _texts[key] ??= () {
      if (_texts.length > 400) _texts.clear();
      return TextPainter(
        text: TextSpan(
          text: neighborhood ? text.toUpperCase() : text,
          style: TextStyle(
            fontFamily: family,
            fontSize: size,
            fontWeight: neighborhood ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: neighborhood ? 1.4 : 0.1,
            color: neighborhood ? style.neighborhood : style.label,
            shadows: [
              for (final d in const [
                Offset(1, 0),
                Offset(-1, 0),
                Offset(0, 1),
                Offset(0, -1),
              ])
                Shadow(color: style.labelHalo, offset: d, blurRadius: 1.5),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
    }();
  }

  void _labels(
    Canvas c,
    Size size,
    Camera cam,
    Offset half,
    List<Rect> reserved,
  ) {
    final zi = cam.zoom.floor();
    final n = 1 << zi;
    final origin = cam.fromCanvas(Offset.zero, half) * n.toDouble();
    final end =
        cam.fromCanvas(Offset(size.width, size.height), half) * n.toDouble();
    final busy = <Rect>[...reserved];
    final placed = <String, Offset>{};
    final seen = <MapLabel>{};
    final candidates = <MapLabel>[];
    for (var ty = origin.dy.floor(); ty <= end.dy.floor(); ty++) {
      for (var tx = origin.dx.floor(); tx <= end.dx.floor(); tx++) {
        for (final r in tiles.labels(zi, tx, ty)) {
          if (seen.add(r)) candidates.add(r);
        }
      }
    }
    candidates.sort(
      (a, b) => (_zoomMin[a.classValue] ?? 18).compareTo(
        _zoomMin[b.classValue] ?? 18,
      ),
    );
    labelsPlaced.clear();
    labelsCandidates = candidates.length;
    // Area where a label can be read (with no panels on top).
    final visible = Rect.fromLTRB(
      40,
      (reserved.isNotEmpty ? reserved[0].bottom : 0) + 24,
      size.width - 40,
      size.height - (reserved.length > 1 ? reserved[1].height : 0) - 24,
    );
    var count = 0;
    for (final r in candidates) {
      if (count > 30) break;
      final isNeighborhood = r.classValue == 'neighborhood';
      if (isNeighborhood && cam.zoom > 14.5) continue;
      if (!isNeighborhood && cam.zoom < (_zoomMin[r.classValue] ?? 18)) {
        continue;
      }
      final tp = _text(
        r.text,
        neighborhood: isNeighborhood,
        size:
            isNeighborhood
                ? 11
                : (r.classValue == 'primary' || r.classValue == 'trunk'
                    ? 12.5
                    : 11.5),
      );
      final w = tp.width, h = tp.height;
      final pts = [for (final p in r.points) cam.toCanvas(p, half)];
      Offset? center;
      var angle = 0.0;
      if (isNeighborhood) {
        center = pts.first;
      } else {
        // Longest nearly straight stretch, even if it is made of several
        // short segments (streets come split at every vertex).
        var best = 0.0;
        var start = 0;
        for (var i = 1; i < pts.length; i++) {
          final dir = pts[i] - pts[start];
          final seg = pts[i] - pts[i - 1];
          if (seg.distance > 0 && dir.distance > 0) {
            final detour =
                (math.atan2(seg.dy, seg.dx) - math.atan2(dir.dy, dir.dx)).abs();
            final d = math.min(detour, 2 * math.pi - detour);
            if (d > 0.26 && i - 1 > start) {
              start = i - 1; // the line breaks: a new stretch starts
            }
          }
          final leg = pts[i] - pts[start];
          final long = leg.distance;
          if (long < w + 20 || long <= best) continue;
          // Only stretches whose center falls in the visible, free area.
          final middle = (pts[i] + pts[start]) / 2;
          if (!visible.contains(middle)) continue;
          best = long;
          center = middle;
          angle = math.atan2(leg.dy, leg.dx);
        }
        // Always readable: never upside down.
        if (angle > math.pi / 2) angle -= math.pi;
        if (angle < -math.pi / 2) angle += math.pi;
      }
      if (center == null) continue;
      final cos = math.cos(angle).abs(), without = math.sin(angle).abs();
      final box = Rect.fromCenter(
        center: center,
        width: w * cos + h * without,
        height: w * without + h * cos,
      );
      if (box.left < 4 ||
          box.top < 4 ||
          box.right > size.width - 4 ||
          box.bottom > size.height - 4) {
        continue;
      }
      final loose = box.inflate(6);
      if (busy.any((o) => o.overlaps(loose))) continue;
      final previous = placed[r.text];
      if (previous != null && (previous - center).distance < 260) continue;
      busy.add(loose);
      placed[r.text] = center;
      labelsPlaced.add(r.text);
      count++;
      c.save();
      c.translate(center.dx, center.dy);
      c.rotate(angle);
      tp.paint(c, Offset(-w / 2, -h / 2));
      c.restore();
    }
  }

  // --- strokes ------------------------------------------------------------------

  void _stroke(Canvas c, List<Offset> pts, StrokeStyle e, double phase) {
    if (pts.length < 2) return;
    Paint line(Color color, double w) =>
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round;
    final path = Path()..addPolygon(pts, false);
    switch (e) {
      case StrokeStyle.bus:
        c.drawPath(path, line(style.border, 10));
        c.drawPath(path, line(style.bus, 6.5));
      case StrokeStyle.busFaint:
        c.drawPath(path, line(style.busFaint, 4.5));
      case StrokeStyle.busDone:
        c.drawPath(path, line(style.networkStop.withValues(alpha: 0.28), 5));
      case StrokeStyle.walk:
        pointsAlong(
          c,
          pts,
          Paint()..color = style.border,
          radio: 4.8,
          separation: 10,
        );
        pointsAlong(
          c,
          pts,
          Paint()..color = style.walk,
          radio: 3.4,
          separation: 10,
        );
      case StrokeStyle.walkFaint:
        pointsAlong(
          c,
          pts,
          Paint()..color = style.walkFaint,
          radio: 2.4,
          separation: 8,
        );
      case StrokeStyle.approximation:
        c.drawPath(path, line(style.border, 8));
        scripts(
          c,
          pts,
          line(style.live, 4.5),
          stroke: 9,
          gap: 7,
          phase: -phase * 128,
        );
    }
  }

  // --- markers ------------------------------------------------------------------

  static final _shadow =
      Paint()
        ..color = const Color(0x38000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

  /// One float cycle per turn of [fase] (no jumps when it restarts).
  static double _floatWave(double phase) => math.sin(phase * 2 * math.pi);

  void _stopRoute(Canvas c, MarkerStopRoute m, Offset p, double phase) {
    switch (m.status) {
      case RouteStopStatus.past:
        c.drawCircle(p, 3.6, Paint()..color = style.markerBackground);
        c.drawCircle(
          p,
          3.6,
          Paint()
            ..color = style.networkStop.withValues(alpha: 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      case RouteStopStatus.future:
        c.drawCircle(p, 4.6, Paint()..color = style.markerBackground);
        c.drawCircle(
          p,
          4.6,
          Paint()
            ..color = style.bus
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2,
        );
      case RouteStopStatus.next:
        _pulse(c, p, phase, style.bus);
        c.drawCircle(p.translate(0, 1), 8, _shadow);
        c.drawCircle(p, 7.5, Paint()..color = style.markerBackground);
        c.drawCircle(
          p,
          7.5,
          Paint()
            ..color = style.bus
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        c.drawCircle(p, 2.6, Paint()..color = style.bus);
    }
  }

  void _marker(Canvas c, MapMarker m, Offset p, double phase) {
    switch (m) {
      case MarkerStopRoute() || MarkerLeg():
        break; // drawn separately
      case MarkerOrigin():
        c.drawCircle(p, 7, Paint()..color = style.markerBackground);
        c.drawCircle(
          p,
          7,
          Paint()
            ..color = style.ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      case MarkerDestination():
        _pin(c, p);
      case MarkerStop(:final role, :final active, :final urgent):
        final color = role == StopRole.boarding ? style.bus : style.ink;
        final accent = urgent ? style.bus : color;
        if (active) _pulse(c, p, phase, accent);
        c.drawCircle(p.translate(0, 1.5), 11, _shadow);
        c.drawCircle(
          p,
          11,
          Paint()..color = urgent ? style.bus : style.markerBackground,
        );
        c.drawCircle(
          p,
          11,
          Paint()
            ..color = urgent ? style.border : accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = urgent ? 2.5 : 3,
        );
        // The arrow floats outward: it rises on the way up and falls on the way down.
        final boards = role == StopRole.boarding;
        final dy = active ? _floatWave(phase) * 1.6 * (boards ? -1 : 1) : 0.0;
        _icon(
          c,
          boards ? Icons.north_rounded : Icons.south_rounded,
          p.translate(0, dy),
          13,
          urgent ? Colors.white : accent,
        );
      case MarkerStopQueried():
        _pulse(c, p, phase, style.walk);
        c.drawCircle(p.translate(0, 1.5), 12, _shadow);
        c.drawCircle(p, 12, Paint()..color = style.markerBackground);
        c.drawCircle(
          p,
          12,
          Paint()
            ..color = style.ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        _icon(c, Icons.directions_bus_rounded, p, 13, style.ink);
      case MarkerBus(:final heading, :final live):
        _vehicle(c, p, heading, live ? style.live : style.scheduled);
      case MarkerUserInBus(:final line):
        _badgeBus(c, p, line);
      case MarkerUser(:final heading, :final walking):
        if (walking && heading != null) _cone(c, p, heading);
        _pulse(c, p, phase, style.walk);
        c.drawCircle(p.translate(0, 1), 11, _shadow);
        c.drawCircle(p, 10.5, Paint()..color = Colors.white);
        c.drawCircle(p, 7.5, Paint()..color = style.walk);
    }
  }

  void _pulse(Canvas c, Offset p, double phase, Color color) {
    final t = (phase * 2) % 1.0;
    c.drawCircle(
      p,
      12 + 20 * t,
      Paint()..color = color.withValues(alpha: 0.28 * (1 - t)),
    );
  }

  /// Where the user is walking: a soft beam, like a flashlight.
  void _cone(Canvas c, Offset p, double heading) {
    final ang = (heading - 90) * math.pi / 180;
    const opens = 0.55, long = 40.0;
    final rect = Rect.fromCircle(center: p, radius: long);
    final beam =
        Path()
          ..moveTo(p.dx, p.dy)
          ..arcTo(rect, ang - opens, 2 * opens, false)
          ..close();
    c.drawPath(
      beam,
      Paint()
        ..shader = RadialGradient(
          colors: [
            style.walk.withValues(alpha: 0.42),
            style.walk.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  /// The incoming bus: a disc with the icon and, if known, its heading. The
  /// ring says whether it is live (green) or scheduled (amber).
  void _vehicle(Canvas c, Offset p, double? heading, Color ring) {
    if (heading != null) {
      final ang = (heading - 90) * math.pi / 180;
      final dir = Offset(math.cos(ang), math.sin(ang));
      final normal = Offset(-dir.dy, dir.dx);
      final tip = p + dir * 19;
      final base = p + dir * 12;
      c.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo((base + normal * 6).dx, (base + normal * 6).dy)
          ..lineTo((base - normal * 6).dx, (base - normal * 6).dy)
          ..close(),
        Paint()..color = style.bus,
      );
    }
    c.drawCircle(p.translate(0, 1.5), 13, _shadow);
    c.drawCircle(p, 13, Paint()..color = ring);
    c.drawCircle(p, 10.5, Paint()..color = style.bus);
    _icon(c, Icons.directions_bus_rounded, p, 13, Colors.white);
  }

  void _pin(Canvas c, Offset p) {
    final head = p.translate(0, -26);
    final path =
        Path()
          ..moveTo(p.dx, p.dy)
          ..quadraticBezierTo(p.dx - 5, p.dy - 10, head.dx - 12, head.dy + 5)
          ..arcToPoint(
            Offset(head.dx + 12, head.dy + 5),
            radius: const Radius.circular(13),
            largeArc: true,
          )
          ..quadraticBezierTo(p.dx + 5, p.dy - 10, p.dx, p.dy)
          ..close();
    c.drawPath(path.shift(const Offset(0, 2)), _shadow);
    c.drawPath(path, Paint()..color = style.ink);
    _icon(
      c,
      Icons.flag_rounded,
      head.translate(0, 1),
      15,
      style.brightness == Brightness.dark
          ? const Color(0xFF111318)
          : Colors.white,
    );
  }

  void _icon(Canvas c, IconData i, Offset center, double size, Color color) {
    final key = 'i${i.codePoint}|$size|${color.toARGB32()}';
    final tp =
        _texts[key] ??= (TextPainter(
          text: TextSpan(
            text: String.fromCharCode(i.codePoint),
            style: TextStyle(
              fontFamily: i.fontFamily,
              package: i.fontPackage,
              fontSize: size,
              color: color,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout());
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  /// The user on the bus: [icon + line] with a blue ring and a pointer.
  void _badgeBus(Canvas c, Offset p, String line) {
    final tl = _text2(line, 15, FontWeight.w800, Colors.white);
    const height = 30.0, icon = 18.0, pad = 8.0;
    final width = pad + icon + 4 + tl.width + pad;
    final above = p.dy - height - 9;
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(p.dx - width / 2, above, width, height),
      const Radius.circular(10),
    );
    final tip =
        Path()
          ..moveTo(p.dx - 6, above + height - 1)
          ..lineTo(p.dx, p.dy - 2)
          ..lineTo(p.dx + 6, above + height - 1)
          ..close();
    c.drawRRect(box.shift(const Offset(0, 2)), _shadow);
    c.drawRRect(box.inflate(3), Paint()..color = style.walk);
    c.drawPath(tip, Paint()..color = style.bus);
    c.drawRRect(box, Paint()..color = style.bus);
    _icon(
      c,
      Icons.directions_bus_rounded,
      Offset(box.left + pad + icon / 2, above + height / 2),
      icon,
      Colors.white,
    );
    tl.paint(
      c,
      Offset(box.left + pad + icon + 4, above + (height - tl.height) / 2),
    );
    c.drawCircle(p, 6, Paint()..color = Colors.white);
    c.drawCircle(p, 4, Paint()..color = style.walk);
  }

  TextPainter _text2(
    String t,
    double size,
    FontWeight w,
    Color color, {
    double spacing = 0,
  }) {
    final key = 'm$size${w.value}${color.toARGB32()}|$spacing|$t';
    return _texts[key] ??= () {
      if (_texts.length > 600) _texts.clear();
      return TextPainter(
        text: TextSpan(
          text: t,
          style: TextStyle(
            fontFamily: family,
            fontSize: size,
            fontWeight: w,
            color: color,
            letterSpacing: spacing,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
    }();
  }

  // --- balloons ------------------------------------------------------------------

  /// How far each marker sticks out above and below its point: the
  /// balloon's tip rests right there.
  (double above, double below) _overhangOf(MapMarker m) => switch (m) {
    MarkerDestination() => (40, 4),
    MarkerBus() => (18, 16),
    MarkerStopRoute() => (10, 10),
    MarkerUser() => (14, 14),
    _ => (15, 14),
  };

  static const _queue = 7.0;

  _Content _measureBalloon(Balloon g) {
    final urgent = g.tone == BalloonTone.urgent;
    final title = _text2(
      g.title,
      14.5,
      FontWeight.w700,
      urgent ? Colors.white : style.ink,
    );
    TextPainter? detail;
    final d = g.detail;
    if (d != null) {
      final upper = d == d.toUpperCase();
      detail = _text2(
        d,
        upper ? 10.5 : 12,
        upper ? FontWeight.w700 : FontWeight.w500,
        urgent
            ? Colors.white.withValues(alpha: 0.9)
            : g.live
            ? style.live
            : g.scheduled
            ? style.scheduled
            : style.label,
        spacing: upper ? 0.8 : 0,
      );
    }
    final line =
        g.line == null
            ? null
            : _text2(g.line!, 13, FontWeight.w800, Colors.white);
    final double widthPill = line == null ? 0 : 6 + 14 + 3 + line.width + 7;
    final point = g.live ? 10.0 : 0.0;
    final widthText = math.max(title.width, (detail?.width ?? 0.0) + point);
    final heightText = title.height + (detail == null ? 0 : detail.height);
    final double width = 20 + (line == null ? 0 : widthPill + 8) + widthText;
    final double height = 14 + math.max(line == null ? 0 : 22, heightText);
    return _Content(
      Size(width, height),
      title: title,
      detail: detail,
      line: line,
      widthPill: widthPill,
    );
  }

  _Content _measureLeg(MarkerLeg t) {
    final text = _text2(
      t.text,
      t.walk ? 12.5 : 13,
      FontWeight.w700,
      t.walk ? style.label : Colors.white,
    );
    return _Content(Size(8 + 15 + 3 + text.width + 9, 24), title: text);
  }

  List<_PlacedBalloon> _locateBalloons(
    List<(MapMarker, Offset)> marks,
    Rect area,
    List<Rect> boxesMarks,
    double phase,
    List<Rect> obstacles,
  ) {
    final candidates = [
      for (final (m, p) in marks)
        if (m.balloon != null || m is MarkerLeg) (m, p),
    ]..sort((a, b) {
      int prio(MapMarker m) => m.balloon?.priority ?? 30;
      return prio(b.$1) - prio(a.$1);
    });
    final placed = <_PlacedBalloon>[];
    bool free(Rect r, {required bool strict}) {
      if (r.left < area.left ||
          r.right > area.right ||
          r.top < area.top ||
          r.bottom > area.bottom) {
        return false;
      }
      final loose = r.inflate(3);
      if (placed.any((g) => g.box.overlaps(loose))) return false;
      if (obstacles.any((o) => o.overlaps(loose))) return false;
      if (strict && boxesMarks.any((m) => m.overlaps(r.deflate(2)))) {
        return false;
      }
      return true;
    }

    double centerX(double width, double x) =>
        (x - width / 2).clamp(area.left, area.right - width).toDouble();

    for (final (m, p) in candidates) {
      if (m is MarkerLeg) {
        final measure = _measureLeg(m);
        final box = Rect.fromCenter(
          center: p,
          width: measure.size.width,
          height: measure.size.height,
        );
        if (free(box, strict: true)) {
          placed.add(_PlacedBalloon(box, p, content: measure, leg: m));
        }
        continue;
      }
      final g = m.balloon!;
      final measure = _measureBalloon(g);
      final (above, below) = _overhangOf(m);
      final w = measure.size.width, h = measure.size.height;
      const lateral = 14.0;
      double centerY(double y) =>
          (y - h / 2).clamp(area.top, area.bottom - h).toDouble();
      // Up is the natural place; if it collides, down, and otherwise to the sides.
      final options = <(_Side, Rect, Offset)>[
        (
          _Side.above,
          Rect.fromLTWH(centerX(w, p.dx), p.dy - above - _queue - h, w, h),
          p.translate(0, -above),
        ),
        (
          _Side.below,
          Rect.fromLTWH(centerX(w, p.dx), p.dy + below + _queue, w, h),
          p.translate(0, below),
        ),
        // Higher up, with the long tail: when another marker is next to it.
        (
          _Side.above,
          Rect.fromLTWH(centerX(w, p.dx), p.dy - above - _queue - 40 - h, w, h),
          p.translate(0, -above),
        ),
        (
          _Side.right,
          Rect.fromLTWH(p.dx + lateral + _queue, centerY(p.dy), w, h),
          p.translate(lateral, 0),
        ),
        (
          _Side.left,
          Rect.fromLTWH(p.dx - lateral - _queue - w, centerY(p.dy), w, h),
          p.translate(-lateral, 0),
        ),
      ];
      final strict = g.priority < 90;
      var chosen = options.where((o) => free(o.$2, strict: strict));
      if (chosen.isEmpty && g.priority >= 90) {
        // The essentials are shown anyway, on the side that fits in the view.
        // (and, of those, one that no floating control covers, if any).
        final inView = options[0].$2.top >= area.top ? options[0] : options[1];
        bool clear((_Side, Rect, Offset) o) =>
            o.$2.top >= area.top &&
            o.$2.bottom <= area.bottom &&
            !obstacles.any((x) => x.overlaps(o.$2));
        chosen = [options.take(2).where(clear).firstOrNull ?? inView];
      }
      if (chosen.isEmpty) continue;
      final (side, box, tip) = chosen.first;
      placed.add(
        _PlacedBalloon(
          box,
          tip,
          content: measure,
          balloon: g,
          side: side,
          floats: m is MarkerBus || g.tone == BalloonTone.urgent,
        ),
      );
    }
    return placed;
  }

  void _balloon(Canvas c, _PlacedBalloon g, double phase) {
    final measure = g.content;
    final leg = g.leg;
    if (leg != null) {
      final box = RRect.fromRectAndRadius(g.box, const Radius.circular(12));
      c.drawRRect(box.shift(const Offset(0, 1.5)), _shadow);
      c.drawRRect(
        box,
        Paint()..color = leg.walk ? style.markerBackground : style.bus,
      );
      final color = leg.walk ? style.label : Colors.white;
      _icon(
        c,
        leg.walk ? Icons.directions_walk_rounded : Icons.directions_bus_rounded,
        Offset(g.box.left + 8 + 7.5, g.box.center.dy),
        15,
        color,
      );
      measure.title.paint(
        c,
        Offset(
          g.box.left + 8 + 15 + 3,
          g.box.center.dy - measure.title.height / 2,
        ),
      );
      return;
    }
    final balloon = g.balloon!;
    final dy = g.floats ? _floatWave(phase) * 2.5 : 0.0;
    final r = g.box.translate(0, dy);
    final tip = g.tip.translate(0, dy);
    final urgent = balloon.tone == BalloonTone.urgent;
    final background = urgent ? style.bus : style.markerBackground;
    final box = RRect.fromRectAndRadius(r, const Radius.circular(13));
    // The tail comes out of the edge that faces the marker.
    final Path queue;
    switch (g.side) {
      case _Side.above || _Side.below:
        final below = g.side == _Side.below;
        final base = below ? r.top + 1 : r.bottom - 1;
        final x = tip.dx.clamp(r.left + 16, r.right - 16).toDouble();
        queue =
            Path()
              ..moveTo(x - 7, base)
              ..lineTo(tip.dx, tip.dy + (below ? 2 : -2))
              ..lineTo(x + 7, base)
              ..close();
      case _Side.right || _Side.left:
        final right = g.side == _Side.right;
        final base = right ? r.left + 1 : r.right - 1;
        final y = tip.dy.clamp(r.top + 12, r.bottom - 12).toDouble();
        queue =
            Path()
              ..moveTo(base, y - 7)
              ..lineTo(tip.dx + (right ? 2 : -2), tip.dy)
              ..lineTo(base, y + 7)
              ..close();
    }
    c.drawRRect(box.shift(const Offset(0, 3)), _shadow);
    c.drawPath(queue.shift(const Offset(0, 2)), _shadow);
    c.drawPath(queue, Paint()..color = background);
    // Same family as the cards: a gradient slightly lighter at the top
    // and an edge that glows at the top and fades at the bottom.
    final dark = style.brightness == Brightness.dark;
    c.drawRRect(
      box,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(background, Colors.white, urgent ? 0.10 : 0.06)!,
            Color.lerp(background, Colors.black, dark ? 0.10 : 0.03)!,
          ],
        ).createShader(r),
    );
    c.drawRRect(
      box.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors:
              urgent
                  ? [Colors.white.withValues(alpha: 0.45), Colors.transparent]
                  : dark
                  ? [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.04),
                  ]
                  : [Colors.white, Colors.black.withValues(alpha: 0.07)],
        ).createShader(r),
    );

    var x0 = r.left + 10;
    final line = measure.line;
    if (line != null) {
      final pill = RRect.fromRectAndRadius(
        Rect.fromLTWH(x0, r.center.dy - 11, measure.widthPill, 22),
        const Radius.circular(7),
      );
      c.drawRRect(pill, Paint()..color = style.bus);
      _icon(
        c,
        Icons.directions_bus_rounded,
        Offset(x0 + 6 + 7, r.center.dy),
        14,
        Colors.white,
      );
      line.paint(c, Offset(x0 + 6 + 14 + 3, r.center.dy - line.height / 2));
      x0 += measure.widthPill + 8;
    }
    final detail = measure.detail;
    final heightText =
        measure.title.height + (detail == null ? 0 : detail.height);
    var y = r.center.dy - heightText / 2;
    measure.title.paint(c, Offset(x0, y));
    y += measure.title.height;
    if (detail != null) {
      var xd = x0;
      if (balloon.live) {
        final center = Offset(x0 + 3.5, y + detail.height / 2);
        final t = (phase * 2) % 1.0;
        c.drawCircle(
          center,
          3.5 + 4 * t,
          Paint()..color = style.live.withValues(alpha: 0.35 * (1 - t)),
        );
        c.drawCircle(center, 3.5, Paint()..color = style.live);
        xd += 10;
      }
      detail.paint(c, Offset(xd, y));
    }
  }

  // --- target out of view ---------------------------------------------

  /// If [p] is out of view, a pill on the edge points toward it (with a
  /// tip on the object's side and, if [rotarIcono], the icon rotated in that
  /// direction). It avoids overlapping the ones already placed in [puestas].
  bool _inBorder(
    Canvas c,
    Offset p,
    Rect area,
    List<Rect> placed, {
    required String text,
    required Color colorText,
    required Color backgroundIcon,
    required IconData icon,
    bool rotateIcon = false,
  }) {
    if (area.deflate(16).contains(p)) return false;
    final tp = _text2(text, 13, FontWeight.w700, colorText);
    const height = 32.0;
    final width = 6 + 22 + 8 + tp.width + 12;
    final interior = Rect.fromLTRB(
      area.left + width / 2 + 4,
      area.top + height / 2 + 4,
      area.right - width / 2 - 4,
      area.bottom - height / 2 - 4,
    );
    if (interior.width <= 0 || interior.height <= 0) return false;
    final center = area.center;
    final dir = p - center;
    if (dir.distance < 1) return false;
    var t = double.infinity;
    if (dir.dx > 0) t = math.min(t, (interior.right - center.dx) / dir.dx);
    if (dir.dx < 0) t = math.min(t, (interior.left - center.dx) / dir.dx);
    if (dir.dy > 0) t = math.min(t, (interior.bottom - center.dy) / dir.dy);
    if (dir.dy < 0) t = math.min(t, (interior.top - center.dy) / dir.dy);
    var q = center + dir * t;
    // If it overlaps another, it is shifted along the edge.
    final vertical =
        (q.dx - interior.left).abs() < 1 || (q.dx - interior.right).abs() < 1;
    for (var i = 1; i <= 4; i++) {
      final box = Rect.fromCenter(center: q, width: width, height: height);
      if (!placed.any((r) => r.overlaps(box.inflate(4)))) break;
      final step = (height + 8) * (i.isOdd ? i : -i);
      q = vertical ? q.translate(0, step) : q.translate(step, 0);
      q = Offset(
        q.dx.clamp(interior.left, interior.right),
        q.dy.clamp(interior.top, interior.bottom),
      );
    }
    final rect = Rect.fromCenter(center: q, width: width, height: height);
    placed.add(rect);
    final box = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(height / 2),
    );
    // Tip toward the object, from the edge of the pill.
    final ang = math.atan2(dir.dy, dir.dx);
    final u = Offset(math.cos(ang), math.sin(ang));
    final border = _boxExit(rect, u);
    final n = Offset(-u.dy, u.dx);
    final tip =
        Path()
          ..moveTo((border - u * 3 + n * 6).dx, (border - u * 3 + n * 6).dy)
          ..lineTo((border + u * 7).dx, (border + u * 7).dy)
          ..lineTo((border - u * 3 - n * 6).dx, (border - u * 3 - n * 6).dy)
          ..close();
    c.drawRRect(box.shift(const Offset(0, 2)), _shadow);
    c.drawPath(tip, Paint()..color = style.markerBackground);
    c.drawRRect(box, Paint()..color = style.markerBackground);
    c.drawRRect(
      box.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors:
              style.brightness == Brightness.dark
                  ? [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.04),
                  ]
                  : [Colors.white, Colors.black.withValues(alpha: 0.07)],
        ).createShader(rect),
    );
    final circle = Offset(box.left + 6 + 11, q.dy);
    c.drawCircle(circle, 11, Paint()..color = backgroundIcon);
    if (rotateIcon) {
      c.save();
      c.translate(circle.dx, circle.dy);
      c.rotate(ang + math.pi / 2);
      _icon(c, icon, Offset.zero, 14, Colors.white);
      c.restore();
    } else {
      _icon(c, icon, circle, 13, Colors.white);
    }
    tp.paint(c, Offset(box.left + 6 + 22 + 8, q.dy - tp.height / 2));
    return true;
  }

  /// Point on the edge of [r] in the direction [u] from its center.
  static Offset _boxExit(Rect r, Offset u) {
    final c = r.center;
    var t = double.infinity;
    if (u.dx.abs() > 1e-6) t = math.min(t, (r.width / 2) / u.dx.abs());
    if (u.dy.abs() > 1e-6) t = math.min(t, (r.height / 2) / u.dy.abs());
    return c + u * t;
  }

  void _attribution(Canvas c, Size size, double marginBottom) {
    final tp = _text2(
      '© OpenStreetMap',
      10,
      FontWeight.w500,
      style.neighborhood,
    );
    final y = (size.height - marginBottom - tp.height - 6).clamp(
      6.0,
      size.height,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(6, y - 2, tp.width + 10, tp.height + 4),
        const Radius.circular(6),
      ),
      Paint()..color = style.labelHalo.withValues(alpha: 0.75),
    );
    tp.paint(c, Offset(11, y));
  }
}

class _Content {
  final Size size;
  final TextPainter title;
  final TextPainter? detail;
  final TextPainter? line;
  final double widthPill;
  const _Content(
    this.size, {
    required this.title,
    this.detail,
    this.line,
    this.widthPill = 0,
  });
}

class _PlacedBalloon {
  final Rect box;

  /// Where the tip rests (the marker's edge).
  final Offset tip;
  final _Content content;
  final Balloon? balloon;
  final MarkerLeg? leg;
  final _Side side;
  final bool floats;
  const _PlacedBalloon(
    this.box,
    this.tip, {
    required this.content,
    this.balloon,
    this.leg,
    this.side = _Side.above,
    this.floats = false,
  });
}

/// Which side of the marker the balloon is on.
enum _Side { above, below, right, left }
