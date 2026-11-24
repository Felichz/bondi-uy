// Selection of the bus coming to a stop and its approach route.
//
// Truthfulness rules (inherited from the E2E visual contract):
// - The approach follows the GTFS shape in the direction of travel. Never a
//   straight line between bus and stop, never an inverted shape.
// - A bus that has already passed the stop is not "coming": it is discarded.
// - Between polls, the same vehicle is followed as long as it keeps coming.
// - When the bus being followed reaches the stop, it stops "coming" (the
//   source reports it as passed, or stops reporting it). If the user is
//   waiting for it, this is not the moment to announce the next one: they are
//   boarding. It is reported as arrived (0 min, 0 m) for a while; only
//   afterwards, if it did not board, does it move on to the next one.

import 'dart:math' as math;

import '../../contract/model.dart';
import '../geo/geo.dart';
import '../ports.dart';

/// Geometry of a line's route around a boarding stop.
class RouteLine {
  final Polyline line;

  /// Meters travelled along [line] up to the boarding stop.
  final double routeStop;

  /// The boarding stop on the shape.
  Coordinate get stop => line.pointAt(routeStop);

  RouteLine._(this.line, this.routeStop);

  /// The route of the bus of [tramo]: over its GTFS [shape] or, without a shape
  /// (or if the stop is not on it), over the leg's geometry. Bus tracking and
  /// the simulated world both use it, so that they place the stop in the same
  /// spot.
  static RouteLine? ofLeg(BusLeg leg, List<Coordinate>? shape) {
    final boarding = leg.boarding.coordinate,
        alighting = leg.alighting.coordinate;
    return (shape == null
            ? null
            : create(shape, boarding, alighting: alighting)) ??
        create(leg.geometry, boarding, alighting: alighting);
  }

  /// Locates the stop on the shape. If the alighting point is known, it is used
  /// to disambiguate shapes that pass twice through the same area (outbound and
  /// return).
  static RouteLine? create(
    List<Coordinate> shape,
    Coordinate boarding, {
    Coordinate? alighting,
    double maxLateral = 80,
  }) {
    if (shape.length < 2) return null;
    final line = Polyline(shape);
    Projection? chosen;
    if (alighting != null) {
      // Try each nearby pass of the boarding point and keep the one whose
      // alighting point is further ahead and closest to the shape.
      var bestCost = double.infinity;
      for (final s in _nearbyPasses(line, boarding, maxLateral)) {
        final b = line.project(alighting, from: s.route);
        if (b.route <= s.route) continue;
        final cost = s.distanceLateral + b.distanceLateral;
        if (cost < bestCost) {
          bestCost = cost;
          chosen = s;
        }
      }
    }
    chosen ??= line.project(boarding);
    if (chosen.distanceLateral > maxLateral) return null;
    return RouteLine._(line, chosen.route);
  }

  static List<Projection> _nearbyPasses(
    Polyline line,
    Coordinate c,
    double maxLateral,
  ) {
    final res = <Projection>[];
    var from = 0.0;
    while (from < line.long) {
      final until = math.min(line.long, from + 400);
      final p = line.project(c, from: from, until: until);
      if (p.distanceLateral <= maxLateral &&
          (res.isEmpty || p.route - res.last.route > 200)) {
        res.add(p);
      }
      from = until;
    }
    return res;
  }

  /// Meters of route before the bus that are included in its path.
  static const metersBack = 2000.0;

  /// Approach from bus to stop, or null if the bus is not on the route before
  /// the stop. [path] (path) also includes where it came from.
  ({
    List<Coordinate> points,
    List<Coordinate> path,
    double meters,
    double heading,
  })?
  approximation(Coordinate bus, {double maxLateral = 150}) {
    final p = line.project(bus, until: routeStop);
    if (p.distanceLateral > maxLateral) return null;
    // (Stopped at the stop, rounding may place it a bit further on.)
    if (p.route > routeStop + 1) return null;
    final rec = math.min(p.route, routeStop);
    final points = [bus, ...line.leg(rec, routeStop)];
    return (
      points: points,
      path: line.leg(math.max(0, rec - metersBack), routeStop),
      meters: routeStop - rec,
      heading: line.headingIn(rec),
    );
  }

  /// true if the bus is on the route but has already passed the stop.
  bool alreadyPassed(Coordinate bus, {double maxLateral = 150}) {
    final after = line.project(bus, from: routeStop);
    final before = line.project(bus, until: routeStop);
    return after.distanceLateral <= maxLateral &&
        after.distanceLateral + 20 < before.distanceLateral &&
        after.route > routeStop + 30;
  }
}

class BusTracker {
  final String line;
  final RouteLine? route;
  final DateTime Function()? _clock;

  /// The vehicle being followed and its last state.
  String? _vehicle;
  BusInPath? _last;

  /// The bus being followed when it was about to arrive (null if it was coming from far away).
  BusInPath? _arriving;

  /// Was someone waiting for it the last time it was seen coming?
  bool _expectedOnArrive = false;

  /// It has already been reported once as arrived; since when (or for how many
  /// polls) it is kept.
  bool _arrivalReported = false;
  DateTime? _arrivedIn;
  int _heldPolls = 0;

  /// Polls during which "arrived" is reported before moving on to the next bus,
  /// without a clock (with a clock, [retencion] is used).
  static const pollsArrived = 6;

  /// How long "arrived" is reported before moving on to the next bus: the time
  /// it takes to confirm that the user boarded, regardless of how often it is polled.
  static const retention = Duration(minutes: 2);

  /// At this distance (or 0 min) the bus is considered arriving.
  static const metersArriving = 150;

  /// At this distance from the user who stayed at the stop, the bus that has
  /// left no longer takes them.
  static const metersLost = 80.0;

  BusTracker({required this.line, this.route, DateTime Function()? clock})
    : _clock = clock;

  /// Chooses the relevant bus among the arrivals at the stop. With [retener]
  /// (the user is waiting at the stop), the bus that arrived keeps being
  /// reported as arrived for a while; without it, it moves on to the next one
  /// right away. If the bus has already left the stop, [usuarioEnLaParada]
  /// (the user stayed) and it is already far from [usuario], the user has lost
  /// it: it stops being reported.
  BusInPath? choose(
    List<StopArrival> arrivals, {
    bool retain = true,
    bool userAtTheStop = false,
    Coordinate? user,
  }) {
    final candidates = [
      for (final l in arrivals)
        if (_sameLine(l.data.line, line)) l,
    ];
    final useful = <(StopArrival, BusInPath)>[];
    for (final l in candidates) {
      final bus = _build(l);
      if (bus != null) useful.add((l, bus));
    }

    // 1) The same vehicle we were following.
    if (_vehicle != null) {
      for (final (l, b) in useful) {
        if (l.vehicle == _vehicle) return _followed(b, retain);
      }
      // No longer coming: if it was arriving, it arrived. Also if the source
      // still reports it on the far side of the stop, even though no poll saw
      // it nearby (between two polls it stopped and moved on).
      Coordinate? real;
      for (final l in candidates) {
        if (l.vehicle == _vehicle) real = l.data.position;
      }
      final step = real != null && (route?.alreadyPassed(real) ?? false);
      final arrived = _arriving ?? (step ? _last : null);
      // It left the stop, the user is still there and the bus is already far
      // from them: the user has lost it (it is no longer reported as arrived,
      // the next one comes). Far means more than the bus advances between one
      // GPS reading and the next: if the user has just boarded, the last
      // reading may still place the bus at the stop.
      final withoutTheUser =
          step &&
          user != null &&
          userAtTheStop &&
          distance(real, user) > metersLost;
      // A bus that arrived is reported at the stop at least once, even if
      // nobody is waiting for it: it does not give up its place to the next
      // one without having arrived. It is kept a while longer only if, when it
      // was seen arriving, someone was waiting for it (if it arrived while the
      // user was walking, it has already left: the next one comes).
      final first = arrived != null && !_arrivalReported && !withoutTheUser;
      final follows =
          arrived != null &&
          retain &&
          _expectedOnArrive &&
          !withoutTheUser &&
          _stillHeld();
      if (arrived != null && (first || follows)) {
        _arriving = arrived;
        _arrivalReported = true;
        return BusInPath(
          line: arrived.line,
          // If they were waiting for it, where it is going (the user is on
          // board); if not, at the stop, where it was seen arriving.
          position:
              retain && _expectedOnArrive
                  ? real ?? route?.stop ?? arrived.position
                  : route?.stop ?? arrived.position,
          minutes: 0,
          live: arrived.live,
          path: arrived.path,
          metersUntilStop: 0,
          heading: arrived.heading,
        );
      }
    }
    _arriving = null;
    _last = null;
    _arrivalReported = false;
    _heldPolls = 0;
    _arrivedIn = null;
    if (useful.isEmpty) {
      _vehicle = null;
      return null;
    }
    // 2) The next one to arrive, prioritizing those with a live position.
    useful.sort((a, b) {
      final va = a.$2.live && a.$2.position != null ? 0 : 1;
      final vb = b.$2.live && b.$2.position != null ? 0 : 1;
      if (va != vb) return va - vb;
      return a.$2.minutes.compareTo(b.$2.minutes);
    });
    final (l, b) = useful.first;
    _vehicle = l.vehicle;
    return _followed(b, retain);
  }

  bool _stillHeld() {
    final clock = _clock;
    if (clock == null) return _heldPolls++ < pollsArrived;
    final now = clock();
    _arrivedIn ??= now;
    return now.difference(_arrivedIn!) < retention;
  }

  BusInPath _followed(BusInPath b, bool retain) {
    _last = b;
    _expectedOnArrive = retain;
    final m = b.metersUntilStop;
    _arriving =
        b.live && (b.minutes == 0 || (m != null && m <= metersArriving))
            ? b
            : null;
    _heldPolls = 0;
    _arrivedIn = null;
    _arrivalReported = false;
    return b;
  }

  BusInPath? _build(StopArrival l) {
    final d = l.data;
    final pos = d.position;
    if (pos == null || route == null) {
      return BusInPath(
        line: d.line,
        position: pos,
        minutes: d.minutes,
        live: d.live,
      );
    }
    final ap = route!.approximation(pos);
    if (ap == null) {
      if (route!.alreadyPassed(pos)) return null; // already passed: not coming
      return BusInPath(
        line: d.line,
        position: pos,
        minutes: d.minutes,
        live: d.live,
      );
    }
    return BusInPath(
      line: d.line,
      position: pos,
      minutes: d.minutes,
      live: d.live,
      approximation: ap.points.length >= 2 ? ap.points : null,
      path: ap.path.length >= 2 ? ap.path : null,
      metersUntilStop: ap.meters.round(),
      heading: ap.heading,
    );
  }
}

bool _sameLine(String a, String b) =>
    a.trim().toUpperCase() == b.trim().toUpperCase();

/// Converts a raw arrival into the contract's arrival shown on the option card
/// (without geometry).
BusArrival? nextArrivalOfLine(
  List<StopArrival> arrivals,
  String line,
  RouteLine? route,
) {
  final seg = BusTracker(line: line, route: route);
  final b = seg.choose(arrivals);
  if (b == null) return null;
  return BusArrival(
    line: b.line,
    minutes: b.minutes,
    live: b.live,
    position: b.position,
  );
}
