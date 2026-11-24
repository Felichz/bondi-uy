// The "under the hood" presentation: the phone plugged into a plate where the
// app's pieces and the calls between them are seen as they happen.
//
// Each pulse is a real trace (lib/contract/traces.dart): an action the UI asks
// of the logic, the state the logic publishes, a GPS reading, a request to the
// bus API, a decision by the navigator or the tracker. Nothing is scripted: what
// you see is what the app does.
//
// The plate is painted in two layers: the fixed part (background, tracks, chips) is
// recorded once per size; the live part (pulses, lit tracks, lights, readings) is
// painted every frame, without rebuilding widgets.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contract/app_state.dart';
import '../../contract/providers.dart';
import '../../contract/traces.dart';
import '../platform/links.dart';
import '../texts/texts.dart';

// --- Plate palette (always dark) --------------------------------------

const _backgroundCenter = Color(0xFF12161D);
const _backgroundBorder = Color(0xFF06080B);
const _track = Color(0xFF232A35);
const _trackLight = Color(0xFF2E3744);

/// The materials of the fixed layer. The chassis (the UI side) follows the
/// app's theme; the board is always dark, and next to a light chassis it is a
/// little lighter (graphite), so the step between the two is not harsh.
class _Finish {
  final Color chassisTop;
  final Color chassisBottom;

  /// Brushed grain: dark streaks on light metal, light ones on dark metal.
  final bool darkGrain;
  final Color boardCenter;
  final Color boardBorder;
  final Color track;
  final Color trackLight;
  final Color boardShadow;
  final Color uiSilkscreen;

  const _Finish._({
    required this.chassisTop,
    required this.chassisBottom,
    required this.darkGrain,
    required this.boardCenter,
    required this.boardBorder,
    required this.track,
    required this.trackLight,
    required this.boardShadow,
    required this.uiSilkscreen,
  });

  static const dark = _Finish._(
    chassisTop: Color(0xFF1C222B),
    chassisBottom: Color(0xFF0F1318),
    darkGrain: false,
    boardCenter: _backgroundCenter,
    boardBorder: _backgroundBorder,
    track: _track,
    trackLight: _trackLight,
    boardShadow: Color(0xCC000000),
    uiSilkscreen: Color(0x40FFFFFF),
  );

  static const light = _Finish._(
    chassisTop: Color(0xFFDDE1E6),
    chassisBottom: Color(0xFFC9CED5),
    darkGrain: true,
    boardCenter: Color(0xFF2A313B),
    boardBorder: Color(0xFF1E242C),
    track: Color(0xFF38414E),
    trackLight: Color(0xFF485465),
    boardShadow: Color(0x66000000),
    uiSilkscreen: Color(0x59000000),
  );
}

/// The ink of the story column, on the chassis.
class _Ink {
  final Color text;
  final Color soft;
  final Color faint;

  /// The "actions" dot of the legend (white on dark, graphite on light).
  final Color action;
  final double dotGlow;
  const _Ink._(this.text, this.soft, this.faint, this.action, this.dotGlow);

  static const dark = _Ink._(_text, _textSoft, _textFaint, _action, 0.7);
  static const light = _Ink._(
    Color(0xFF111318),
    Color(0xFF4A515C),
    Color(0xFF6B7380),
    Color(0xFF39414C),
    0.35,
  );
}

const _chip = Color(0xFF151A21);
const _chipTop = Color(0xFF1D232C);
const _chipEdge = Color(0xFF323B48);
const _pin = Color(0xFF8F7A52);
const _text = Color(0xFFF2F4F7);
const _textSoft = Color(0xFFA7AEBA);
const _textFaint = Color(0xFF6B7380);

const _action = Color(0xFFE9EDF3);
const _status = Color(0xFF36D08F);
const _location = Color(0xFF6B9BFF);
const _bus = Color(0xFFFF6A55);
const _plan = Color(0xFFF2A93B);
const _network = Color(0xFF8FA6C4);

/// Color of a call according to its domain.
Color _colorOf(Trace t) {
  if (t.from == Piece.interfaceValue) return _action;
  if (t.toward == Piece.interfaceValue) return _status;
  final other = t.from == Piece.controller ? t.toward : t.from;
  return switch (other) {
    Piece.location || Piece.navigator => _location,
    Piece.arrivals || Piece.tracker => _bus,
    Piece.planner || Piece.recommender => _plan,
    Piece.catalog || Piece.places => _network,
    _ => _action,
  };
}

/// The domain color of each piece.
Color _colorPiece(Piece p) => switch (p) {
  Piece.interfaceValue => _action,
  Piece.controller => _status,
  Piece.navigator || Piece.location => _location,
  Piece.tracker || Piece.arrivals => _bus,
  Piece.recommender || Piece.planner => _plan,
  Piece.catalog || Piece.places => _network,
};

IconData _iconPiece(Piece p) => switch (p) {
  Piece.interfaceValue => Icons.swap_horiz,
  Piece.controller => Icons.hub_outlined,
  Piece.navigator => Icons.navigation_outlined,
  Piece.tracker => Icons.directions_bus_outlined,
  Piece.recommender => Icons.sort,
  Piece.location => Icons.my_location,
  Piece.arrivals => Icons.schedule,
  Piece.planner => Icons.alt_route,
  Piece.catalog => Icons.map_outlined,
  Piece.places => Icons.place_outlined,
};

/// Where each piece lives in the repository.
String _filePiece(Piece p) => switch (p) {
  Piece.interfaceValue => 'lib/contract/',
  Piece.controller => 'lib/logic/app_controller.dart',
  Piece.navigator => 'lib/logic/trip/trip_navigator.dart',
  Piece.tracker => 'lib/logic/trip/bus_tracker.dart',
  Piece.recommender => 'lib/logic/trip/recommender.dart',
  Piece.location => 'lib/logic/services/gps_location.dart',
  Piece.arrivals => 'lib/logic/services/montevideo.dart',
  Piece.planner => 'lib/logic/services/otp.dart',
  Piece.catalog => 'lib/logic/services/catalog_assets.dart',
  Piece.places => 'lib/logic/services/places.dart',
};

const _repo = 'https://github.com/Felichz/bondi-uy';

String _linkPiece(Piece p) {
  final f = _filePiece(p);
  return f.endsWith('/') ? '$_repo/tree/main/$f' : '$_repo/blob/main/$f';
}

/// The pin where a track at [pt] enters the box [c] (null if [pt] is not
/// on its edge).
Rect? _legIn(Rect c, Offset pt) {
  const e = 0.5;
  final inHeight = pt.dy > c.top && pt.dy < c.bottom;
  final inWidth = pt.dx > c.left && pt.dx < c.right;
  if (inHeight && (pt.dx - c.left).abs() < e) {
    return Rect.fromLTWH(c.left - 6, pt.dy - 2, 6, 4);
  }
  if (inHeight && (pt.dx - c.right).abs() < e) {
    return Rect.fromLTWH(c.right, pt.dy - 2, 6, 4);
  }
  if (inWidth && (pt.dy - c.top).abs() < e) {
    return Rect.fromLTWH(pt.dx - 2, c.top - 6, 4, 6);
  }
  if (inWidth && (pt.dy - c.bottom).abs() < e) {
    return Rect.fromLTWH(pt.dx - 2, c.bottom, 4, 6);
  }
  return null;
}

TextStyle _style(
  double size,
  Color color, {
  FontWeight weight = FontWeight.w500,
}) => TextStyle(
  fontFamily: 'Roboto',
  fontSize: size,
  color: color,
  fontWeight: weight,
  height: 1.25,
  fontFeatures: const [ui.FontFeature.tabularFigures()],
);

// --- Layout: where each thing goes ---------------------------------------------

/// A piece drawn on the plate: its chip, its name and its role.
class _Chip {
  final Piece piece;
  final Rect rect;
  final String name;
  final String role;

  /// Edge connector (a port to the outside world) or a core chip.
  final bool isPort;
  const _Chip(
    this.piece,
    this.rect,
    this.name,
    this.role, {
    this.isPort = false,
  });
}

class _Plane {
  final Size size;
  final Rect phone;
  final Rect connector;
  final Map<Piece, _Chip> chips;
  final Rect contract;

  /// Tracks between neighboring pieces (not the interface: that one goes
  /// through the contract, in two lanes).
  final Map<(Piece, Piece), List<Offset>> tracks;
  final List<Offset> actions;
  final List<Offset> status;

  /// The bodies of the chips (the contract included): the live part is painted underneath,
  /// so a track enters a chip through its pins and does not cross over it.
  /// Where the circuit board starts: the UI side (the story and the phone)
  /// sits on the chassis, the logic on the board.
  late final double boardEdge = connector.right + 4;

  /// The board's outline. It has a notch where the App API sits, so the
  /// contract stands half on the chassis and half on the board: it is the
  /// boundary between the two layers.
  late final Path board = () {
    final x = boardEdge;
    final notchX = contract.center.dx;
    final top = contract.top - 24, bottom = contract.bottom + 24;
    const outer = Radius.circular(8), inner = Radius.circular(14);
    return Path()
      ..moveTo(x, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(x, size.height)
      ..lineTo(x, bottom + outer.y)
      ..arcToPoint(Offset(x + outer.x, bottom), radius: outer)
      ..lineTo(notchX - inner.x, bottom)
      ..arcToPoint(
        Offset(notchX, bottom - inner.y),
        radius: inner,
        clockwise: false,
      )
      ..lineTo(notchX, top + inner.y)
      ..arcToPoint(
        Offset(notchX - inner.x, top),
        radius: inner,
        clockwise: false,
      )
      ..lineTo(x + outer.x, top)
      ..arcToPoint(Offset(x, top - outer.y), radius: outer)
      ..close();
  }();

  late final List<RRect> bodies = [
    RRect.fromRectAndRadius(contract, const Radius.circular(12)),
    for (final ch in chips.values)
      RRect.fromRectAndRadius(ch.rect, const Radius.circular(12)),
  ];

  /// The box of each piece (the interface is the App API).
  late final Map<Piece, Rect> boxes = {
    Piece.interfaceValue: contract,
    for (final ch in chips.values) ch.piece: ch.rect,
  };

  /// The pins where the tracks enter the boxes, per track point.
  late final Map<Offset, Rect> pins = () {
    final r = <Offset, Rect>{};
    for (final route in [...tracks.values, actions, status]) {
      for (final pt in route) {
        for (final c in boxes.values) {
          final pin = _legIn(c, pt);
          if (pin != null) r[pt] = pin;
        }
      }
    }
    return r;
  }();

  Piece? pieceIn(Offset o) {
    for (final e in boxes.entries) {
      if (e.value.inflate(4).contains(o)) return e.key;
    }
    return null;
  }

  String nameOf(Piece p) =>
      p == Piece.interfaceValue ? 'App API' : chips[p]!.name;

  _Plane._(
    this.size,
    this.phone,
    this.connector,
    this.chips,
    this.contract,
    this.tracks,
    this.actions,
    this.status,
  );

  // Plate measurements: the chips never shrink (nor their texts);
  // whatever width is left over is shared among the gaps.
  static const _widthContract = 150.0;
  static const _widthControl = 214.0;
  static const _coreWidth = 196.0;
  static const _coreHeight = 120.0;
  static const _portWidth = 220.0;
  static const _gapConnector = 40.0;
  static const _gapContract = 48.0;

  /// Room so the tracks to the ports bend to the right of the core.
  static const _gapPorts = 92.0;
  static const _margin = 24.0;

  /// Width the plate needs to the right of the phone.
  static const widthMin =
      _gapConnector +
      _widthContract +
      _gapContract +
      _widthControl +
      _gapPorts +
      _portWidth +
      _margin;

  factory _Plane(Size size, Rect phone) {
    final cy = phone.center.dy;
    final x0 = phone.right;
    final height = size.height;
    final surplus = math.max(0.0, size.width - x0 - widthMin);
    final connector = Rect.fromLTWH(phone.right - 6, cy - 64, 22, 128);

    Rect centered(double x, double y, double w, double h) =>
        Rect.fromCenter(center: Offset(x, y), width: w, height: h);

    final contract = Rect.fromLTWH(
      x0 + _gapConnector + surplus * 0.25,
      cy - 75,
      _widthContract,
      150,
    );
    final control = Rect.fromLTWH(
      contract.right + _gapContract + surplus * 0.30,
      cy - 84,
      _widthControl,
      168,
    );
    // Up top, the navigator and the recommender side by side, not past the right
    // edge of the controller (the tracks to the ports bend later);
    // down below, the tracker.
    const marginV = 28.0;
    final dy = math.min(height * 0.31, 300.0);
    final yTop = (cy - dy).clamp(
      marginV + _coreHeight / 2,
      control.top - 36 - _coreHeight / 2,
    );
    final yBottom = (cy + dy).clamp(
      control.bottom + 36 + _coreHeight / 2,
      height - marginV - _coreHeight / 2,
    );
    final recommender = Rect.fromLTWH(
      control.right - _coreWidth,
      yTop - _coreHeight / 2,
      _coreWidth,
      _coreHeight,
    );
    final core = <Piece, Rect>{
      Piece.recommender: recommender,
      Piece.navigator: recommender.shift(const Offset(-_coreWidth - 24, 0)),
      Piece.tracker: centered(
        control.center.dx,
        yBottom,
        _coreWidth,
        _coreHeight,
      ),
    };
    const ports = [
      Piece.location,
      Piece.arrivals,
      Piece.planner,
      Piece.catalog,
      Piece.places,
    ];
    final step = math.min(
      (height - 2 * marginV - 84) / (ports.length - 1),
      150.0,
    );
    final xPort = control.right + _gapPorts + surplus * 0.45 + _portWidth / 2;
    final chips = <Piece, _Chip>{
      Piece.controller: _Chip(
        Piece.controller,
        control,
        'AppController',
        tx.coreController,
      ),
      Piece.navigator: _Chip(
        Piece.navigator,
        core[Piece.navigator]!,
        'TripNavigator',
        tx.coreNavigator,
      ),
      Piece.recommender: _Chip(
        Piece.recommender,
        core[Piece.recommender]!,
        'Recommender',
        tx.coreRecommender,
      ),
      Piece.tracker: _Chip(
        Piece.tracker,
        core[Piece.tracker]!,
        'BusTracker',
        tx.coreTracker,
      ),
      for (var i = 0; i < ports.length; i++)
        ports[i]: _Chip(
          ports[i],
          centered(
            xPort,
            cy + (i - (ports.length - 1) / 2) * step,
            _portWidth,
            84,
          ),
          switch (ports[i]) {
            Piece.location => 'GPS',
            Piece.arrivals => 'Montevideo API',
            Piece.planner => 'OpenTripPlanner',
            Piece.catalog => 'GTFS',
            _ => 'Places',
          },
          switch (ports[i]) {
            Piece.location => 'follow() · current()',
            Piece.arrivals => 'arrivals(stop)',
            Piece.planner => 'plan(a, b)',
            Piece.catalog => 'stops() · shape(id)',
            _ => 'suggestions(text)',
          },
          isPort: true,
        ),
    };

    // Tracks from the controller to each piece: they leave from the side that faces it.
    // The ones to the ports bend to the right of the whole core.
    final tracks = <(Piece, Piece), List<Offset>>{};
    final coreRight = [
      control,
      ...core.values,
    ].map((r) => r.right).reduce(math.max);
    final byRight = [for (final p in ports) chips[p]!];
    for (var i = 0; i < byRight.length; i++) {
      final c = byRight[i];
      final exit = Offset(
        control.right,
        control.top + 28 + i * (control.height - 56) / (byRight.length - 1),
      );
      tracks[(Piece.controller, c.piece)] = _route(
        exit,
        Offset(c.rect.left, c.rect.center.dy),
        breakValue: coreRight + 28 + i * 14,
      );
    }
    for (final p in [Piece.navigator, Piece.recommender]) {
      final c = chips[p]!.rect;
      final x = c.center.dx.clamp(control.left + 30, control.right - 30);
      tracks[(Piece.controller, p)] = _routeVertical(
        Offset(x, control.top),
        Offset(c.center.dx, c.bottom),
      );
    }
    final seg = chips[Piece.tracker]!.rect;
    tracks[(Piece.controller, Piece.tracker)] = _routeVertical(
      Offset(seg.center.dx, control.bottom),
      Offset(seg.center.dx, seg.top),
    );

    // The interface reaches the controller through the contract, in two lanes:
    // actions go down, state goes up.
    List<Offset> lane(double dy) => [
      Offset(connector.right, cy + dy),
      Offset(contract.left, cy + dy),
      Offset(contract.right, cy + dy),
      Offset(control.left, cy + dy),
    ];
    return _Plane._(
      size,
      phone,
      connector,
      chips,
      contract,
      tracks,
      lane(-22),
      lane(22),
    );
  }

  /// The route of a trace: which tracks it goes through, from where to where.
  List<Offset>? route(Trace t) {
    if (t.from == Piece.interfaceValue) return actions;
    if (t.toward == Piece.interfaceValue) return status.reversed.toList();
    final forward = tracks[(t.from, t.toward)];
    if (forward != null) return forward;
    return tracks[(t.toward, t.from)]?.reversed.toList();
  }
}

/// Track route at right angles with 45° corners: leaves horizontally,
/// bends at [breakValue] and arrives horizontally.
List<Offset> _route(Offset a, Offset b, {required double breakValue}) {
  const r = 14.0;
  if ((a.dy - b.dy).abs() < 1) return [a, b];
  final s = (b.dy - a.dy).sign;
  final c = math.min(r, (b.dy - a.dy).abs() / 2);
  return [
    a,
    Offset(breakValue - c, a.dy),
    Offset(breakValue, a.dy + s * c),
    Offset(breakValue, b.dy - s * c),
    Offset(breakValue + c, b.dy),
    b,
  ];
}

/// Leaves vertically and arrives vertically, with a horizontal segment in the middle.
List<Offset> _routeVertical(Offset a, Offset b) {
  const r = 14.0;
  if ((a.dx - b.dx).abs() < 1) return [a, b];
  final middle = (a.dy + b.dy) / 2;
  final s = (b.dx - a.dx).sign;
  final v = (b.dy - a.dy).sign;
  final c = math.min(r, (b.dx - a.dx).abs() / 2);
  return [
    a,
    Offset(a.dx, middle - v * c),
    Offset(a.dx + s * c, middle),
    Offset(b.dx - s * c, middle),
    Offset(b.dx, middle + v * c),
    b,
  ];
}

// --- The live part ------------------------------------------------------------------

class _Pulse {
  final List<Offset> points;
  final List<double> cum;
  final Color color;
  final double start;
  final double duration;

  /// The pins it crosses, with their distance along the route.
  final List<(double, Rect)> pins;

  /// How many pins the head has already crossed.
  int crossed = 0;

  _Pulse(this.points, this.color, this.start, Map<Offset, Rect> pinsOfPlane)
    : cum = _accumulate(points),
      duration = (_accumulate(points).last / 900).clamp(0.35, 1.1),
      pins = [
        for (final (i, a) in _accumulate(points).indexed)
          if (pinsOfPlane[points[i]] case final r?) (a, r),
      ];

  /// Where the head is at [now] (distance along the route).
  double head(double now) =>
      Curves.easeInOutCubic.transform(
        ((now - start) / duration).clamp(0.0, 1.0),
      ) *
      long;

  static List<double> _accumulate(List<Offset> p) {
    final a = List<double>.filled(p.length, 0);
    for (var i = 1; i < p.length; i++) {
      a[i] = a[i - 1] + (p[i] - p[i - 1]).distance;
    }
    return a;
  }

  double get long => cum.last;

  Offset at(double s) {
    if (s <= 0) return points.first;
    if (s >= long) return points.last;
    var i = 1;
    while (cum[i] < s) {
      i++;
    }
    final l = cum[i] - cum[i - 1];
    return Offset.lerp(
      points[i - 1],
      points[i],
      l == 0 ? 0 : (s - cum[i - 1]) / l,
    )!;
  }

  /// The part of the route between [from] and [until] (meters along it).
  List<Offset> leg(double from, double until) {
    final r = <Offset>[at(from)];
    for (var i = 0; i < points.length; i++) {
      if (cum[i] > from && cum[i] < until) r.add(points[i]);
    }
    r.add(at(until));
    return r;
  }
}

/// The last thing that went through a piece.
class _Reading {
  String call = '';
  String? result;
  Color color = _textSoft;
  double moment = -10;
  int count = 0;
}

/// A line of the console.
class _Line {
  final DateTime moment;
  final Trace trace;
  final Color color;
  int repeats = 1;
  _Line(this.moment, this.trace, this.color);
}

class _Live extends ChangeNotifier {
  final List<_Pulse> pulses = [];
  final Map<Piece, _Reading> readings = {
    for (final p in Piece.values) p: _Reading(),
  };

  /// The last thing that crossed the App API in each direction.
  final action = _Reading();
  final status = _Reading();

  /// When something entered or left through each pin (it lights up for a moment).
  final Map<Rect, (double, Color)> pins = {};

  /// When something went through each track (so it stays lit for a moment).
  final Map<List<Offset>, (double, Color)> lit = Map.identity();
  final ValueNotifier<List<_Line>> console = ValueNotifier(const []);
  double now = 0;

  void tick(double t) {
    now = t;
    pulses.removeWhere((p) => t - p.start > p.duration + 0.4);
    // The pin lights up when the head of the pulse passes through it.
    for (final pu in pulses) {
      final s = pu.head(t);
      while (pu.crossed < pu.pins.length && pu.pins[pu.crossed].$1 <= s + 0.5) {
        pins[pu.pins[pu.crossed].$2] = (t, pu.color);
        pu.crossed++;
      }
    }
    pins.removeWhere((_, v) => t - v.$1 > 1);
    notifyListeners();
  }

  void call(Trace t, _Plane? plane) {
    final color = _colorOf(t);
    final route = plane?.route(t);
    if (route != null && pulses.length < 70) {
      // Many readings in a row on the same track: one pulse every so often
      // is enough to see it alive (not a continuous train).
      final last = lit[route];
      if (last == null || now - last.$1 > 0.09) {
        pulses.add(_Pulse(route, color, now, plane!.pins));
      }
      lit[route] = (now, color);
    }
    // What each end received (or returned). What crosses the contract
    // (actions and state) goes into the interface's reading.
    for (final p in [t.from, t.toward]) {
      readings[p]!
        ..call = t.call
        ..result = t.result
        ..color = color
        ..moment = now
        ..count += 1;
    }
    if (t.from == Piece.interfaceValue || t.toward == Piece.interfaceValue) {
      (t.from == Piece.interfaceValue ? action : status)
        ..call = t.call
        ..result = t.result
        ..color = color
        ..moment = now
        ..count += 1;
    }
    final lines = console.value;
    final last = lines.isEmpty ? null : lines.first;
    if (last != null &&
        last.trace.from == t.from &&
        last.trace.toward == t.toward &&
        _withoutArgs(last.trace.call) == _withoutArgs(t.call)) {
      last.repeats++;
      console.value = [
        _Line(t.moment, t, color)..repeats = last.repeats,
        ...lines.skip(1),
      ];
    } else {
      console.value = [_Line(t.moment, t, color), ...lines.take(39)];
    }
  }

  static String _withoutArgs(String s) {
    final i = s.indexOf('(');
    return i < 0 ? s : s.substring(0, i);
  }

  @override
  void dispose() {
    console.dispose();
    super.dispose();
  }
}

// --- Widget ----------------------------------------------------------------------

const _leftMargin = 56.0;
const _columnMin = 340.0;
const _gapMin = 32.0;

/// Where the phone [phoneSize] goes in a window of size [size]: after the narrative,
/// centered vertically. The narrative column and the gap up to the phone grow
/// with the window, but they give way first so the plate fits whole.
Rect phoneUnderTheHood(Size size, Size phoneSize) =>
    _locate(size, phoneSize).phone;

({Rect phone, double column}) _locate(Size size, Size phoneSize) {
  var column = (size.width * 0.22).clamp(_columnMin, 420.0);
  var gap = (size.width * 0.03).clamp(_gapMin, 64.0);
  final excess =
      _leftMargin +
      column +
      gap +
      phoneSize.width +
      _Plane.widthMin -
      size.width;
  if (excess > 0) {
    final ofGap = math.min(excess, gap - _gapMin);
    gap -= ofGap;
    column = math.max(_columnMin, column - (excess - ofGap));
  }
  return (
    phone: Rect.fromLTWH(
      _leftMargin + column + gap,
      (size.height - phoneSize.height) / 2,
      phoneSize.width,
      phoneSize.height,
    ),
    column: column,
  );
}

/// The boxes of the plate (the chips and the contract) for a window of size [size]
/// with the phone at [phone]. To check that they do not overlap.
@visibleForTesting
Map<String, Rect> plateBoxes(Size size, Rect phone) {
  final p = _Plane(size, phone);
  return {
    for (final e in p.chips.entries) e.key.name: e.value.rect,
    'contract': p.contract,
  };
}

/// Window width needed by the "under the hood" view with a phone of
/// [widthPhone]: the narrative, the phone and the whole plate.
double widthMinUnderTheHood(double widthPhone) =>
    _leftMargin + _columnMin + _gapMin + widthPhone + _Plane.widthMin;

class UnderTheHood extends ConsumerStatefulWidget {
  /// The phone with the app, already scaled.
  final Widget phone;
  final Size sizePhone;

  /// Header (brand and view selector).
  final Widget header;

  /// Light theme: the UI side turns light; the board stays dark.
  final bool light;

  const UnderTheHood({
    super.key,
    required this.phone,
    required this.sizePhone,
    required this.header,
    this.light = false,
  });

  @override
  ConsumerState<UnderTheHood> createState() => _UnderTheHoodState();
}

class _UnderTheHoodState extends ConsumerState<UnderTheHood>
    with TickerProviderStateMixin {
  final _live = _Live();
  late final Ticker _clock;
  StreamSubscription<Trace>? _traces;
  _Plane? _plane;
  ui.Image? _fixed;
  (Size, double, Language, bool)? _fixedKey;
  double _lastStatus = -10;

  /// The console maximized over the whole story column (its green light).
  bool _consoleZoomed = false;

  /// One animation for both halves of the move: the story folding away and
  /// the console growing into its place.
  late final AnimationController _zoom;
  late final Animation<double> _zoomed;

  /// The piece under the mouse (its card is shown next to it).
  Piece? _over;
  String? _summaryStatus;

  @override
  void initState() {
    super.initState();
    _clock = createTicker((d) => _live.tick(d.inMicroseconds / 1e6))..start();
    _zoom = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _zoomed = CurvedAnimation(parent: _zoom, curve: Curves.easeInOutCubic);
    _traces = ref
        .read(tracesProvider)
        ?.stream
        .listen((t) => _live.call(t, _plane));
  }

  @override
  void dispose() {
    _traces?.cancel();
    _clock.dispose();
    _zoom.dispose();
    _live.dispose();
    _fixed?.dispose();
    super.dispose();
  }

  /// The state the logic publishes, as a call toward the interface
  /// (only when something really changed, at most a few times per second).
  void _onPublish(AppState s) {
    final r = _summary(s);
    final now = _live.now;
    if (r == _summaryStatus && now - _lastStatus < 0.4) return;
    if (now - _lastStatus < 0.12) return;
    _summaryStatus = r;
    _lastStatus = now;
    _live.call(
      Trace(
        Piece.controller,
        Piece.interfaceValue,
        'AppState',
        result: r,
        moment: DateTime.now(),
      ),
      _plane,
    );
  }

  static String _summary(AppState s) => switch (s.phase) {
    ExplorePhase() => 'explore',
    final OptionsPhase f =>
      f.status == OptionsStatus.ready
          ? 'options (${f.options.length})'
          : 'options, ${f.status.name}',
    final TripPhase f =>
      f.status == TripStatus.completed
          ? 'trip, arrived'
          : 'trip, step ${f.currentStep + 1} of ${f.totalSteps}'
              '${f.progress.metersLeft == null ? '' : ', ${f.progress.metersLeft} m'}',
  };

  /// The fixed part, rasterized once: each frame only copies the image (a
  /// Picture would run its shadows and grid again every time).
  ui.Image _recordFixed(_Plane p, double density) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(density);
    _paintFixed(c, p, widget.light ? _Finish.light : _Finish.dark);
    final drawing = rec.endRecording();
    final image = drawing.toImageSync(
      (p.size.width * density).ceil(),
      (p.size.height * density).ceil(),
    );
    drawing.dispose();
    return image;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppState>(appStateProvider, (_, s) => _onPublish(s));
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final (:phone, :column) = _locate(size, widget.sizePhone);
        if (_plane?.size != size || _plane?.phone != phone) {
          _plane = _Plane(size, phone);
        }
        final plane = _plane!;
        final density = MediaQuery.devicePixelRatioOf(context);
        if (_fixedKey != (size, density, tx.language, widget.light)) {
          _fixed?.dispose();
          _fixed = _recordFixed(plane, density);
          _fixedKey = (size, density, tx.language, widget.light);
        }
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(
                child: MouseRegion(
                  cursor:
                      _over == null
                          ? MouseCursor.defer
                          : SystemMouseCursors.click,
                  onHover: (e) {
                    final p = plane.pieceIn(e.localPosition);
                    if (p != _over) setState(() => _over = p);
                  },
                  onExit: (_) {
                    if (_over != null) setState(() => _over = null);
                  },
                  child: GestureDetector(
                    onTapUp: (e) {
                      final p = plane.pieceIn(e.localPosition);
                      if (p != null) openLink(_linkPiece(p));
                    },
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _PainterPlate(plane, _fixed!, _live),
                      ),
                    ),
                  ),
                ),
              ),
              // The narrative flows from top to bottom; the console takes what is
              // left (and does not appear if it does not fit): nothing overlaps.
              Positioned(
                left: _leftMargin,
                top: 36,
                bottom: 36,
                width: column,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    widget.header,
                    const SizedBox(height: 24),
                    // Maximized, the console takes the story's place; the
                    // story folds away above it.
                    SizeTransition(
                      sizeFactor: ReverseAnimation(_zoomed),
                      axisAlignment: -1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          _Narrative(widget.light ? _Ink.light : _Ink.dark),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder:
                            (context, b) =>
                                b.maxHeight < 120
                                    ? const SizedBox.shrink()
                                    // As tall as its lines, no more (or all of
                                    // it, maximized).
                                    : Align(
                                      alignment: Alignment.topLeft,
                                      child: AnimatedBuilder(
                                        animation: _zoomed,
                                        builder:
                                            (context, child) => SizedBox(
                                              height:
                                                  ui.lerpDouble(
                                                    math.min(b.maxHeight, 340),
                                                    b.maxHeight,
                                                    _zoomed.value,
                                                  )!,
                                              child: child,
                                            ),
                                        child: _Console(
                                          _live.console,
                                          light: widget.light,
                                          zoomed: _consoleZoomed,
                                          onZoom: () {
                                            setState(
                                              () =>
                                                  _consoleZoomed =
                                                      !_consoleZoomed,
                                            );
                                            _consoleZoomed
                                                ? _zoom.forward()
                                                : _zoom.reverse();
                                          },
                                        ),
                                      ),
                                    ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned.fromRect(rect: phone, child: widget.phone),
              if (_over case final p?)
                _Card.together(p, plane.nameOf(p), plane.boxes[p]!, plane),
            ],
          ),
        );
      },
    );
  }
}

// --- Text -------------------------------------------------------------------------

/// The card of a piece: what it does and where its code is.
class _Card extends StatelessWidget {
  final Piece piece;
  final String name;
  const _Card(this.piece, this.name);

  static const width = 300.0;
  static const heightEstimated = 190.0;

  /// The card below the box (or above, if it does not fit below), without covering
  /// the phone.
  static Widget together(Piece p, String name, Rect box, _Plane plane) {
    final below = box.bottom + 12 + heightEstimated < plane.size.height;
    final double left = box.left.clamp(
      plane.phone.right + 16,
      math.max(plane.phone.right + 16, plane.size.width - width - 16),
    );
    return Positioned(
      left: left,
      top: below ? box.bottom + 12 : null,
      bottom: below ? null : plane.size.height - box.top + 12,
      width: width,
      child: IgnorePointer(child: _Card(p, name)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorPiece(piece);
    return DecoratedBox(
      key: const ValueKey('piece-card'),
      decoration: BoxDecoration(
        color: const Color(0xF50F1318),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2E3744)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(_iconPiece(piece), size: 17, color: color),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    name,
                    style: _style(15, _text, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _filePiece(piece),
              style: _style(12, color.withValues(alpha: 0.85)),
            ),
            const SizedBox(height: 10),
            Text(
              tx.coreDetail(piece),
              style: _style(13, _textSoft).copyWith(height: 1.45),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.open_in_new, size: 13, color: _textFaint),
                const SizedBox(width: 6),
                Text(
                  tx.coreSeeCode,
                  style: _style(12, _textFaint, weight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Narrative extends StatelessWidget {
  final _Ink ink;
  const _Narrative(this.ink);

  @override
  Widget build(BuildContext context) {
    Widget legendItem(Color c, String s) => Padding(
      padding: const EdgeInsets.only(right: 16, bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: c.withValues(alpha: ink.dotGlow),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(s, style: _style(13, ink.soft)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tx.coreTitle,
          style: _style(
            40,
            ink.text,
            weight: FontWeight.w800,
          ).copyWith(letterSpacing: -1.2, height: 1.05),
        ),
        const SizedBox(height: 16),
        Text(tx.coreLede, style: _style(16, ink.soft).copyWith(height: 1.55)),
        const SizedBox(height: 18),
        Wrap(
          children: [
            legendItem(ink.action, tx.coreKeyActions),
            legendItem(_status, tx.coreKeyStatus),
            legendItem(_location, tx.coreKeyLocation),
            legendItem(_bus, tx.coreKeyBuses),
            legendItem(_plan, tx.coreKeyPlan),
          ],
        ),
        const SizedBox(height: 6),
        Text(tx.coreNoteDemo, style: _style(12.5, ink.faint)),
      ],
    );
  }
}

class _Console extends StatelessWidget {
  final ValueNotifier<List<_Line>> lines;

  /// It follows the theme, like the window it sits in.
  final bool light;
  final bool zoomed;
  final VoidCallback onZoom;
  const _Console(
    this.lines, {
    this.light = false,
    this.zoomed = false,
    required this.onZoom,
  });

  static String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}.'
      '${(t.millisecond ~/ 100)}';

  static String _name(Piece p) => switch (p) {
    Piece.interfaceValue => 'UI',
    Piece.controller => 'AppController',
    Piece.navigator => 'TripNavigator',
    Piece.tracker => 'BusTracker',
    Piece.recommender => 'Recommender',
    Piece.planner => 'OTP',
    Piece.arrivals => 'Montevideo API',
    Piece.location => 'GPS',
    Piece.catalog => 'GTFS',
    Piece.places => 'Places',
  };

  /// A call's color, readable on a light window (the board's colors are made
  /// for a dark one).
  static Color _onLight(Color c) => switch (c) {
    _action => const Color(0xFF12161D),
    _status => const Color(0xFF0B7A50),
    _location => const Color(0xFF2557C9),
    _bus => const Color(0xFFC23A22),
    _plan => const Color(0xFFA15C00),
    _network => const Color(0xFF4A5A73),
    _ => c,
  };

  @override
  Widget build(BuildContext context) {
    final w = light ? _WindowColors.light : _WindowColors.dark;
    final time = light ? const Color(0xFF5A6375) : _textFaint;
    final route = light ? const Color(0xFF485061) : _textSoft;
    return _Window(
      colors: w,
      lights: _Lights(colors: w, zoomed: zoomed, onZoom: onZoom),
      title: Text(
        tx.coreConsole,
        style: _style(13, w.title, weight: FontWeight.w600),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 7, 16, 10),
        child: ClipRect(
          child: ValueListenableBuilder<List<_Line>>(
            valueListenable: lines,
            builder:
                // Like a terminal: the newest call is the last line, at the
                // bottom, and the older ones climb and fade.
                (context, ls, _) => ListView(
                  key: const ValueKey('console-lines'),
                  reverse: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    for (var i = 0; i < ls.length; i++)
                      Opacity(
                        opacity: (1 - i * (zoomed ? 0.025 : 0.07)).clamp(
                          0.25,
                          1.0,
                        ),
                        // A log entry: the time in its gutter; beside it, who
                        // calls whom, and under that the whole call (it wraps,
                        // it is never cut).
                        child: Padding(
                          key: const ValueKey('console-entry'),
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 72,
                                child: Text(
                                  _time(ls[i].moment),
                                  style: _style(12, time),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_name(ls[i].trace.from)} › ${_name(ls[i].trace.toward)}',
                                      style: _style(12, route),
                                    ),
                                    const SizedBox(height: 1),
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: ls[i].trace.call,
                                            style: _style(
                                              12,
                                              light
                                                  ? _onLight(ls[i].color)
                                                  : ls[i].color,
                                              weight: FontWeight.w600,
                                            ),
                                          ),
                                          if (ls[i].trace.result != null)
                                            TextSpan(
                                              text: '  = ${ls[i].trace.result}',
                                              style: _style(12, time),
                                            ),
                                          if (ls[i].repeats > 1)
                                            TextSpan(
                                              text: '  ×${ls[i].repeats}',
                                              style: _style(
                                                12,
                                                route,
                                                weight: FontWeight.w700,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}

/// The window the portfolio draws its previews in (and the knowgraph and
/// LifeUI landings their films): a bar with a centered title and the three
/// lights (here on the right), over the content.
class _WindowColors {
  final Color background;
  final Color bar;
  final Color line;
  final Color title;
  final Color lightOff;
  final List<BoxShadow> shadow;
  const _WindowColors._({
    required this.background,
    required this.bar,
    required this.line,
    required this.title,
    required this.lightOff,
    required this.shadow,
  });

  static const dark = _WindowColors._(
    background: Color(0xFF0E1117),
    bar: Color(0xFF151922),
    line: Color(0x1AD6E2FF),
    title: Color(0xFF8A93A3),
    lightOff: Color(0x29D6E2FF),
    shadow: [
      BoxShadow(
        color: Color(0x8C000000),
        blurRadius: 60,
        offset: Offset(0, 24),
      ),
    ],
  );

  static const light = _WindowColors._(
    background: Color(0xFFF6F7F9),
    bar: Color(0xFFFDFDFE),
    line: Color(0x1F121A2C),
    title: Color(0xFF5A6375),
    lightOff: Color(0x29121A2C),
    shadow: [
      BoxShadow(color: Color(0x14302414), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(
        color: Color(0x42302414),
        blurRadius: 60,
        spreadRadius: -12,
        offset: Offset(0, 24),
      ),
    ],
  );
}

class _Window extends StatelessWidget {
  final _WindowColors colors;
  final Widget title;
  final Widget lights;
  final Widget child;
  const _Window({
    required this.colors,
    required this.title,
    required this.lights,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.line),
        boxShadow: colors.shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          children: [
            Container(
              height: 34,
              decoration: BoxDecoration(
                color: colors.bar,
                border: Border(bottom: BorderSide(color: colors.line)),
              ),
              child: Stack(
                children: [
                  Center(child: title),
                  Positioned(
                    right: 13,
                    top: 0,
                    bottom: 0,
                    child: Center(child: lights),
                  ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// The three lights. Red and yellow have nothing to do here and stay grey;
/// green maximizes (and restores). Under the pointer they show their glyphs;
/// until green has been used on this visit, a ring ripples out of it.
class _Lights extends StatefulWidget {
  final _WindowColors colors;
  final bool zoomed;
  final VoidCallback onZoom;
  const _Lights({
    required this.colors,
    required this.zoomed,
    required this.onZoom,
  });

  @override
  State<_Lights> createState() => _LightsState();
}

class _LightsState extends State<_Lights> with SingleTickerProviderStateMixin {
  static bool _used = false;
  static const _green = Color(0xFF28C840);

  // Created up front: a lazy controller would be created in dispose(), when
  // the widget is already inactive.
  late final AnimationController _ring;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (!_used) _ring.repeat();
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget off() => Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: widget.colors.lightOff,
        shape: BoxShape.circle,
      ),
    );
    final zoom = Semantics(
      button: true,
      label: widget.zoomed ? tx.coreConsoleRestore : tx.coreConsoleMaximize,
      child: GestureDetector(
        key: const ValueKey('console-zoom'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!_used) {
            _used = true;
            _ring.stop();
          }
          widget.onZoom();
        },
        // A hit area a little larger than the dot.
        child: SizedBox(
          width: 20,
          height: 20,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (!_used)
                  AnimatedBuilder(
                    animation: _ring,
                    builder: (context, _) {
                      final k = (_ring.value / 0.75).clamp(0.0, 1.0);
                      final e = Curves.easeOutCubic.transform(k);
                      return Transform.scale(
                        scale: 1 + 1.6 * e,
                        child: Opacity(
                          opacity: 0.9 * (1 - k),
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: _green, width: 1.5),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                AnimatedScale(
                  scale: _hover ? 1.3 : 1,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: _green,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
                          spreadRadius: -0.25,
                        ),
                      ],
                    ),
                    child: AnimatedOpacity(
                      opacity: _hover ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: CustomPaint(
                        painter: _ZoomGlyph(restore: widget.zoomed),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          off(),
          const SizedBox(width: 8),
          off(),
          const SizedBox(width: 4),
          zoom,
        ],
      ),
    );
  }
}

/// The green light's glyph: two arrowheads out (maximize) or in (restore),
/// drawn like the landings' SVG (a 24-unit box).
class _ZoomGlyph extends CustomPainter {
  final bool restore;
  const _ZoomGlyph({required this.restore});

  @override
  void paint(Canvas c, Size size) {
    const glyph = 9.0;
    final k = glyph / 24;
    c.translate((size.width - glyph) / 2, (size.height - glyph) / 2);
    c.scale(k);
    final paint = Paint()..color = const Color(0x8C000000);
    final path =
        restore
            ? (Path()
              ..moveTo(11.5, 11.5)
              ..lineTo(3.5, 11.5)
              ..lineTo(11.5, 3.5)
              ..close()
              ..moveTo(12.5, 12.5)
              ..lineTo(20.5, 12.5)
              ..lineTo(12.5, 20.5)
              ..close())
            : (Path()
              ..moveTo(6, 6)
              ..lineTo(15, 6)
              ..lineTo(6, 15)
              ..close()
              ..moveTo(18, 18)
              ..lineTo(9, 18)
              ..lineTo(18, 9)
              ..close());
    c.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ZoomGlyph old) => old.restore != restore;
}

// --- Painting -----------------------------------------------------------------------

/// The fixed part: background, grid, decorative tracks, the network tracks and the
/// chip bodies.
void _paintFixed(Canvas c, _Plane p, _Finish f) {
  final r = Offset.zero & p.size;
  final board = p.board;

  // The chassis, under everything: dark brushed metal, a touch cooler than
  // the board. This is the UI side.
  c.drawRect(
    r,
    Paint()
      ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, [
        f.chassisTop,
        f.chassisBottom,
      ]),
  );
  // Brushed grain: fine horizontal streaks of uneven length and brightness.
  final grain = math.Random(11);
  for (var i = 0; i < 900; i++) {
    final y = grain.nextDouble() * p.size.height;
    final x = grain.nextDouble() * p.size.width;
    final long = 40 + grain.nextDouble() * 260;
    c.drawLine(
      Offset(x, y),
      Offset(x + long, y),
      Paint()
        ..color =
            f.darkGrain
                ? Color.fromARGB(5 + grain.nextInt(8), 0, 0, 0)
                : Color.fromARGB(6 + grain.nextInt(9), 255, 255, 255)
        ..strokeWidth = 0.6,
    );
  }

  // The board, raised over the chassis: its shadow first, then the board.
  c.drawPath(
    board.shift(const Offset(-2, 6)),
    Paint()
      ..color = f.boardShadow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
  );
  c.drawPath(
    board,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset(p.size.width * 0.6, p.size.height * 0.5),
        p.size.longestSide * 0.75,
        [f.boardCenter, f.boardBorder],
      ),
  );
  // Its edge catches a bit of light.
  c.drawPath(
    board,
    Paint()
      ..color = const Color(0x2EFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );

  // Dot grid, only on the board.
  final dot = Paint()..color = const Color(0x0FFFFFFF);
  for (var x = 12.0; x < p.size.width; x += 24) {
    for (var y = 12.0; y < p.size.height; y += 24) {
      if (x < p.boardEdge + 6 || !board.contains(Offset(x, y))) continue;
      c.drawRect(Rect.fromLTWH(x, y, 1.2, 1.2), dot);
    }
  }

  // Stitching vias along the board's edge.
  final stitched = [
    p.contract.inflate(30),
    for (final ch in p.chips.values) ch.rect.inflate(14),
  ];
  for (var y = 18.0; y < p.size.height - 12; y += 22) {
    final v = Offset(p.boardEdge + 9, y);
    if (!board.contains(v) || stitched.any((o) => o.contains(v))) continue;
    c.drawCircle(v, 2.4, Paint()..color = const Color(0x1AFFFFFF));
    c.drawCircle(v, 1, Paint()..color = f.boardBorder);
  }

  // Silkscreen: which layer is which, at the foot of the edge.
  TextPainter silkscreen(String s, Color ink) => TextPainter(
    text: TextSpan(
      text: s,
      style: _style(
        10,
        ink,
        weight: FontWeight.w700,
      ).copyWith(letterSpacing: 2.2),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final ui_ = silkscreen(tx.coreLayerUi, f.uiSilkscreen);
  final logic = silkscreen(tx.coreLayerLogic, const Color(0x40FFFFFF));
  final y = p.size.height - 26;
  ui_.paint(c, Offset(p.boardEdge - 14 - ui_.width, y));
  logic.paint(c, Offset(p.boardEdge + 14, y));

  // Background tracks: the plate keeps going beyond what is used.
  final chance = math.Random(7);
  final faint =
      Paint()
        ..color = const Color(0x0DFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
  final via = Paint()..color = const Color(0x14FFFFFF);
  final busy = [
    p.phone.inflate(30),
    p.contract.inflate(20),
    for (final ch in p.chips.values) ch.rect.inflate(24),
  ];
  for (var i = 0; i < 70; i++) {
    final a = Offset(
      chance.nextDouble() * p.size.width,
      chance.nextDouble() * p.size.height,
    );
    final long = 80 + chance.nextDouble() * 260;
    final horizontal = chance.nextBool();
    final b =
        horizontal
            ? Offset(
              a.dx + (chance.nextBool() ? long : -long),
              a.dy + (chance.nextDouble() - 0.5) * 120,
            )
            : Offset(
              a.dx + (chance.nextDouble() - 0.5) * 120,
              a.dy + (chance.nextBool() ? long : -long),
            );
    final pts =
        horizontal
            ? _route(a, b, breakValue: (a.dx + b.dx) / 2)
            : _routeVertical(a, b);
    if (busy.any((o) => pts.any(o.contains))) continue;
    if (pts.any((q) => q.dx < p.boardEdge + 16 || !board.contains(q))) {
      continue;
    }
    c.drawPath(Path()..addPolygon(pts, false), faint);
    c.drawCircle(a, 2.6, via);
    c.drawCircle(b, 2.6, via);
  }

  // The network: dimmed copper tracks.
  void track(List<Offset> pts) {
    final path = Path()..addPolygon(pts, false);
    c.drawPath(
      path,
      Paint()
        ..color = f.track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    c.drawPath(
      path,
      Paint()
        ..color = f.trackLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round,
    );
    for (final v in [pts.first, pts.last]) {
      if (p.pins.containsKey(v)) continue;
      c.drawCircle(v, 4.5, Paint()..color = f.track);
      c.drawCircle(v, 2, Paint()..color = f.boardBorder);
    }
  }

  for (final pts in p.tracks.values) {
    track(pts);
  }
  track(p.actions);
  track(p.status);

  // The connector where the phone plugs in.
  final conn = p.connector;
  c.drawRRect(
    RRect.fromRectAndRadius(conn, const Radius.circular(5)),
    Paint()
      ..shader = ui.Gradient.linear(conn.topLeft, conn.topRight, const [
        Color(0xFF2A313C),
        Color(0xFF181C23),
      ]),
  );
  for (var i = 0; i < 9; i++) {
    c.drawRect(
      Rect.fromLTWH(conn.right - 9, conn.top + 12 + i * 12.5, 6, 4),
      Paint()..color = _pin.withValues(alpha: 0.85),
    );
  }

  // Chip bodies, the contract included.
  bool free(Offset o) => !p.pins.values.any((q) => (q.center - o).distance < 8);
  void body(Rect rect, {required bool isPort, Color? accent}) {
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    c.drawRRect(
      rr.shift(const Offset(0, 14)),
      Paint()
        ..color = const Color(0x80000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    // Pins.
    final pin = Paint()..color = _pin.withValues(alpha: isPort ? 0.5 : 0.75);
    final n = (rect.height / 16).floor();
    for (var i = 0; i < n; i++) {
      final y = rect.top + 12 + i * (rect.height - 24) / math.max(1, n - 1);
      if (free(Offset(rect.left - 3, y))) {
        c.drawRect(Rect.fromLTWH(rect.left - 5, y - 1.5, 5, 3), pin);
      }
      if (!isPort && free(Offset(rect.right + 3, y))) {
        c.drawRect(Rect.fromLTWH(rect.right, y - 1.5, 5, 3), pin);
      }
    }
    c.drawRRect(
      rr,
      Paint()
        ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, const [
          _chipTop,
          _chip,
        ]),
    );
    c.drawRRect(
      rr.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          const [Color(0xFF3D4757), _chipEdge, Color(0xFF14181E)],
          const [0, 0.25, 1],
        ),
    );
    // The ports (the outside world) carry a strip of their domain.
    if (accent != null) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left + 8, rect.top + 14, 3, rect.height - 28),
          const Radius.circular(1.5),
        ),
        Paint()..color = accent.withValues(alpha: 0.55),
      );
    }
  }

  body(p.contract, isPort: false);
  for (final ch in p.chips.values) {
    body(
      ch.rect,
      isPort: ch.isPort,
      accent: ch.isPort ? _colorPiece(ch.piece) : null,
    );
  }
  // The pins where the tracks enter.
  for (final q in p.pins.values) {
    c.drawRect(q, Paint()..color = _pin.withValues(alpha: 0.9));
  }
}

class _PainterPlate extends CustomPainter {
  final _Plane p;
  final ui.Image fixed;
  final _Live live;
  _PainterPlate(this.p, this.fixed, this.live) : super(repaint: live);

  static final Map<String, TextPainter> _texts = {};

  /// Text cached by content and style.
  TextPainter _t(String s, TextStyle e, {double? width, int lines = 1}) {
    final k =
        '$s|${e.fontSize}|${e.color?.toARGB32()}|${e.fontWeight}|$width|$lines';
    if (_texts.length > 400) _texts.clear();
    return _texts[k] ??= (TextPainter(
      text: TextSpan(text: s, style: e),
      textDirection: TextDirection.ltr,
      maxLines: lines,
      ellipsis: '…',
    )..layout(maxWidth: width ?? double.infinity));
  }

  @override
  void paint(Canvas c, Size size) {
    c.drawImageRect(
      fixed,
      Rect.fromLTWH(0, 0, fixed.width.toDouble(), fixed.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final now = live.now;

    c.save();
    // Tracks that carried something recently: they stay lit and fade out.
    for (final e in live.lit.entries) {
      final k = (1 - (now - e.value.$1) / 1.2).clamp(0.0, 1.0);
      if (k <= 0) continue;
      final path = Path()..addPolygon(e.key, false);
      // Halo: a wide, faint stroke (no blur: cheap on any
      // machine).
      c.drawPath(
        path,
        Paint()
          ..color = e.value.$2.withValues(alpha: 0.09 * k)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
      c.drawPath(
        path,
        Paint()
          ..color = e.value.$2.withValues(alpha: 0.55 * k)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Pulses: a bright head with its trail, along the track.
    for (final pu in live.pulses) {
      final f = ((now - pu.start) / pu.duration).clamp(0.0, 1.0);
      final s = pu.head(now);
      final queue = math.max(0.0, s - 90);
      final fade =
          f >= 1
              ? (1 - (now - pu.start - pu.duration) / 0.4).clamp(0.0, 1.0)
              : 1.0;
      if (s - queue > 1) {
        final leg = pu.leg(queue, s);
        final path = Path()..addPolygon(leg, false);
        c.drawPath(
          path,
          Paint()
            ..shader = ui.Gradient.linear(leg.first, leg.last, [
              pu.color.withValues(alpha: 0),
              pu.color.withValues(alpha: 0.9 * fade),
            ])
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
      final head = pu.at(s);
      _glow(c, head, 13, pu.color, 0.55 * fade);
      c.drawCircle(
        head,
        2.8,
        Paint()
          ..color = Color.lerp(
            pu.color,
            Colors.white,
            0.6,
          )!.withValues(alpha: fade),
      );
    }

    c.restore();

    // The chip bodies, drawn again on top of the live part: the tracks and
    // pulses stay underneath. They are copied from the fixed layer (a clip with a
    // combined path was not respected on the web).
    final scale = fixed.width / size.width;
    for (final rr in p.bodies) {
      c.save();
      c.clipRRect(rr);
      final r = rr.outerRect;
      c.drawImageRect(
        fixed,
        Rect.fromLTRB(
          r.left * scale,
          r.top * scale,
          r.right * scale,
          r.bottom * scale,
        ),
        r,
        Paint()..filterQuality = FilterQuality.medium,
      );
      c.restore();
    }

    // The lit pins: something just came in (or out) through there.
    for (final e in live.pins.entries) {
      final k = (1 - (now - e.value.$1) / 0.9).clamp(0.0, 1.0);
      if (k <= 0) continue;
      _glow(c, e.key.center, 11, e.value.$2, 0.6 * k);
      c.drawRect(
        e.key,
        Paint()
          ..color =
              Color.lerp(_pin, Color.lerp(e.value.$2, Colors.white, 0.3), k)!,
      );
    }

    _api(c, p.contract, now);
    for (final ch in p.chips.values) {
      _labels(c, ch, live.readings[ch.piece]!, now);
    }
  }

  /// The activity light and the call count, top right.
  void _light(Canvas c, Rect r, _Reading l, int count, double now) {
    final active = (1 - (now - l.moment) / 0.9).clamp(0.0, 1.0);
    final light = r.topRight + const Offset(-16, 16);
    if (active > 0) _glow(c, light, 14, l.color, 0.6 * active);
    c.drawCircle(
      light,
      3.2,
      Paint()..color = Color.lerp(const Color(0xFF2A313B), l.color, active)!,
    );
    if (count == 0) return;
    final t = _t('$count', _style(10.5, _textFaint, weight: FontWeight.w600));
    t.paint(c, Offset(r.right - 26 - t.width, r.top + 10));
  }

  /// The piece's icon: livelier while something passes through it.
  void _icon(Canvas c, Piece p, Offset o, double active) {
    final i = _iconPiece(p);
    _t(
      String.fromCharCode(i.codePoint),
      TextStyle(
        fontFamily: i.fontFamily,
        package: i.fontPackage,
        fontSize: 15,
        height: 1,
        color: _colorPiece(p).withValues(alpha: 0.6 + 0.4 * active),
      ),
    ).paint(c, o);
  }

  /// The App API from the inside: the actions lane on top (they enter from
  /// the UI), the state lane below (it leaves toward the UI), level with its
  /// tracks.
  void _api(Canvas c, Rect r, double now) {
    final a = live.action, e = live.status;
    final last = a.moment >= e.moment ? a : e;
    _light(c, r, last, a.count + e.count, now);
    final active = (1 - (now - last.moment) / 0.9).clamp(0.0, 1.0);
    _icon(c, Piece.interfaceValue, Offset(r.left + 14, r.top + 18.5), active);
    final x = r.left + 36;
    _t(
      'App API',
      _style(16, _text, weight: FontWeight.w700),
      width: r.right - x - 30,
    ).paint(c, Offset(x, r.top + 16));
    final cy = r.center.dy;
    c.drawLine(
      Offset(r.left + 12, cy + 7),
      Offset(r.right - 12, cy + 7),
      Paint()
        ..color = const Color(0x14FFFFFF)
        ..strokeWidth = 1,
    );
    void lane(_Reading l, String name, double y, Color color, bool enters) {
      final k = (1 - (now - l.moment) / 0.9).clamp(0.0, 1.0);
      // An arrow in the direction of the lane.
      final m = Offset(r.left + 20, y);
      final s = enters ? 1.0 : -1.0;
      c.drawPath(
        Path()
          ..moveTo(m.dx - 3.5 * s, m.dy - 4.5)
          ..lineTo(m.dx + 3.5 * s, m.dy)
          ..lineTo(m.dx - 3.5 * s, m.dy + 4.5)
          ..close(),
        Paint()..color = Color.lerp(_textFaint, color, 0.35 + 0.65 * k)!,
      );
      // The name level with the track; below it, the last thing that went through (for
      // the state, its summary: the lane already says it is an AppState).
      final width = r.right - x - 10;
      _t(
        name,
        _style(11.5, _textFaint),
        width: width,
      ).paint(c, Offset(x, y - 7.5));
      if (l.count == 0) return;
      _t(
        enters ? l.call : (l.result ?? l.call),
        _style(11.5, l.color, weight: FontWeight.w600),
        width: width,
      ).paint(c, Offset(x, y + 8));
    }

    lane(a, 'AppActions', cy - 22, _action, true);
    lane(e, 'AppState', cy + 22, _status, false);
  }

  void _labels(Canvas c, _Chip ch, _Reading l, double now) {
    final r = ch.rect;
    final isPort = ch.isPort;
    _light(c, r, l, l.count, now);
    final active = (1 - (now - l.moment) / 0.9).clamp(0.0, 1.0);
    final x = r.left + (isPort ? 38 : 36);
    final width = r.right - x - 30;
    var y = r.top + (isPort ? 14 : 16);
    final tName = _t(
      ch.name,
      _style(isPort ? 15 : 16, _text, weight: FontWeight.w700),
      width: width,
    );
    _icon(
      c,
      ch.piece,
      Offset(r.left + (isPort ? 17 : 14), y + (tName.height - 15) / 2),
      active,
    );
    tName.paint(c, Offset(x, y));
    y += tName.height + 3;
    // The role, in two lines if needed (it is not cut off).
    final tRole = _t(
      ch.role,
      _style(11.5, _textFaint),
      width: r.right - x - 14,
      lines: isPort ? 1 : 2,
    );
    tRole.paint(c, Offset(x, y));
    y += tRole.height + 8;
    if (l.count == 0 || y + 14 > r.bottom) return;
    final tCall = _t(
      l.call,
      _style(11.5, l.color, weight: FontWeight.w600),
      width: r.right - x - 14,
    );
    tCall.paint(c, Offset(x, y));
    y += tCall.height + 2;
    final res = l.result;
    if (res != null && y + 12 < r.bottom) {
      _t(
        '= $res',
        _style(11, _textSoft),
        width: r.right - x - 14,
      ).paint(c, Offset(x, y));
    }
  }

  /// A round glow: radial gradient, no blur.
  static void _glow(Canvas c, Offset o, double r, Color color, double a) {
    if (a <= 0) return;
    c.drawCircle(
      o,
      r,
      Paint()
        ..shader = ui.Gradient.radial(o, r, [
          color.withValues(alpha: a),
          color.withValues(alpha: 0),
        ]),
    );
  }

  @override
  bool shouldRepaint(_PainterPlate old) =>
      old.p != p || old.fixed != fixed || old.live != live;
}
