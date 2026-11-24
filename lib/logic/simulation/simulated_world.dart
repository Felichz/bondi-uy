// Simulated world: accelerated clock + user GPS + synthetic buses.
//
// It serves two purposes:
// - `simulado` mode and the app's demo mode: the user and the buses move
//   on their own, at accelerated speed, along the streets and the real GTFS
//   shapes. It lets you go through every flow without going out into the street.
// - Tests: the same world with fake time (fake_async / WidgetTester).
//
// Everything is continuous in time, so nothing jumps or goes back:
// - Each line that passes a stop has a fixed schedule (a bus every
//   [ParametrosSimulacion.frecuencia]). Each vehicle is a function of
//   time: it comes along the route, stops at the stop and moves on. Once
//   set, the schedule is never shifted.
// - The user travels IN one of those vehicles (the first one that reaches
//   the stop after them): their position on top of the bus is the vehicle's.
// - The user's script starts each leg where the previous one ended: if the
//   geometry of a leg does not start right there, they walk to it.

import 'dart:async';
import 'dart:math' as math;

import '../../contract/model.dart';
import '../geo/geo.dart';
import '../ports.dart';
import '../trip/bus_tracker.dart';

class SimulationParams {
  /// Time multiplier (8 = a 40 min trip lasts 5 min).
  final double velocity;
  final double walkMps;
  final double busMps;

  /// How often (real time) a GPS sample is emitted, at most.
  final Duration intervaloGps;

  /// Maximum world time between two GPS samples: at high speed there are
  /// more samples per real second, as on a real phone (otherwise at 30x,
  /// 250 m of bus would pass between one sample and the next).
  final Duration intervaloGpsSimulated;

  /// Seconds (simulated) the user must be at the stop before their bus
  /// arrives: they take the first one that arrives after that.
  final int waitMin;

  /// How often a bus of the same line passes a stop.
  final Duration frequency;

  /// How long the bus stays parked at the boarding stop.
  final Duration stopped;

  /// How long the user takes to get off the bus.
  final Duration alighting;

  const SimulationParams({
    this.velocity = 8,
    this.walkMps = 1.4,
    this.busMps = 8.3,
    this.intervaloGps = const Duration(seconds: 1),
    this.intervaloGpsSimulated = const Duration(seconds: 5),
    this.waitMin = 3,
    this.frequency = const Duration(minutes: 4),
    this.stopped = const Duration(seconds: 10),
    this.alighting = const Duration(seconds: 8),
  });
}

class SimulatedWorld {
  final SimulationParams p;
  final CatalogRed catalog;
  Coordinate positionInitial;

  final DateTime _inicioSim;

  /// Real time elapsed since the start (injectable in tests).
  final Duration Function() _elapsed;

  SimulatedWorld({
    required this.catalog,
    required this.positionInitial,
    this.p = const SimulationParams(),
    DateTime? nowSimulated,
    Duration Function()? elapsed,
  }) : _inicioSim = nowSimulated ?? DateTime.now(),
       _elapsed = elapsed ?? (Stopwatch()..start()).elapsedFn;

  late double _velocity = p.velocity;
  Duration _anchorReal = Duration.zero;
  DateTime? _anchorSim;

  /// Time multiplier; it can be changed on the fly (the demo changes it
  /// according to the trip step).
  double get velocity => _velocity;

  /// Changes the speed without the clock jumping: from now on it runs at [v].
  set velocity(double v) => _anclar(() => _velocity = v);

  void _anclar(void Function() change) {
    final t = now();
    _anchorReal = _elapsed();
    _anchorSim = t;
    change();
  }

  /// Simulated clock (inject as `Reloj` in the controller).
  DateTime now() => (_anchorSim ?? _inicioSim).add(
    Duration(
      microseconds:
          ((_elapsed() - _anchorReal).inMicroseconds * _velocity).round(),
    ),
  );

  /// Services (line + boarding stop) with a schedule: "stop|line".
  final Map<String, _Service> _services = {};

  _Script? _script;

  // ------------------------------------------------------------------------
  // User's trip
  // ------------------------------------------------------------------------

  /// The user starts traveling [opcion] (called by the controller).
  Future<void> traverse(TripOption option, Map<String, String> shapes) async {
    final routes = <String, RouteLine?>{};
    for (final t in option.legs.whereType<BusLeg>()) {
      routes[t.id] = await _routeOf(t, shapes[t.id]);
    }
    final from = sample().coordinate;
    _script = _Script.build(this, option, routes, now(), from);
  }

  void stop() {
    final g = _script;
    if (g != null) positionInitial = g.position(now()).coordinate;
    _script = null;
  }

  LocationSample sample() {
    final t = now();
    final g = _script;
    if (g == null) {
      return LocationSample(
        coordinate: positionInitial,
        moment: t,
        velocity: 0,
        precision: 5,
      );
    }
    final pos = g.position(t);
    return LocationSample(
      coordinate: pos.coordinate,
      moment: t,
      velocity: pos.velocity,
      precision: 5,
    );
  }

  // ------------------------------------------------------------------------
  // Synthetic buses
  // ------------------------------------------------------------------------

  /// Route of the bus for [t] along its GTFS shape (or, without a shape, along
  /// the leg's geometry), with the boarding stop on the correct pass.
  Future<RouteLine?> _routeOf(BusLeg t, String? shapeId) async {
    final shape = shapeId == null ? null : await catalog.shape(shapeId);
    return RouteLine.ofLeg(t, shape);
  }

  /// The service for [line] at [parada]; if it did not exist, it is created
  /// with its next bus arriving at [primera].
  _Service _service(
    String stop,
    String line,
    RouteLine route,
    DateTime primera,
  ) =>
      _services['$stop|$line'] ??= _Service(
        line: line,
        route: route,
        primera: primera,
        p: p,
      );

  List<StopArrival> arrivalsIn(String stop, List<String> lines) {
    final t = now();
    final res = <StopArrival>[];
    // Lines serving the stop are always reported, even if the catalog
    // brings many.
    final all = {
      ...lines,
      for (final s in _services.entries)
        if (s.key.startsWith('$stop|')) s.value.line,
    };
    for (final line in all) {
      final s = _services['$stop|$line'];
      if (s == null) {
        res.add(_bySchedule(stop, line, t));
        continue;
      }
      var busInPath = false;
      for (final k in s.near(t)) {
        final rec = s.routeIn(k, t);
        // Not departed yet, already finished, or passed a while ago: the source does not report it.
        if (rec < 0 || rec > s.shape.long || rec > s.recStop + 400) {
          continue;
        }
        final seconds = s.arrival(k).difference(t).inMilliseconds / 1000;
        busInPath = true;
        res.add(
          StopArrival(
            BusArrival(
              line: line,
              minutes: (math.max(0, seconds) / 60).ceil(),
              live: true,
              position: s.shape.pointAt(rec),
            ),
            vehicle: 'sim-$line-$k',
          ),
        );
      }
      if (!busInPath) {
        // The next one has not departed yet: only its schedule.
        final k = s.nextFrom(t);
        res.add(
          StopArrival(
            BusArrival(
              line: line,
              minutes: (s.arrival(k).difference(t).inSeconds / 60).ceil(),
              live: false,
            ),
            vehicle: 'sim-$line-$k',
          ),
        );
      }
    }
    return res;
  }

  /// Lines with no known route: a fixed schedule per line and stop (it
  /// never moves backward).
  StopArrival _bySchedule(String stop, String line, DateTime t) {
    const cada = 9 * 60;
    final phase = Object.hash(stop, line).abs() % cada;
    final s = t.millisecondsSinceEpoch ~/ 1000;
    final k = ((s - phase) / cada).ceil();
    final arrives = k * cada + phase;
    return StopArrival(
      BusArrival(line: line, minutes: ((arrives - s) / 60).ceil(), live: false),
      vehicle: 'hor-$line-$k',
    );
  }

  /// Prepares the service of a line at a stop (to preview the bus in the
  /// options before starting the trip): its next bus arrives in [llegaEn].
  /// If it already existed, it is left alone: the schedule does not run.
  Future<void> prepareLine(
    BusLeg bus,
    String? shapeId, {
    required Duration arrivesIn,
  }) async {
    if (_services.containsKey('${bus.boarding.id}|${bus.line}')) return;
    final route = await _routeOf(bus, shapeId);
    if (route == null) return;
    _service(bus.boarding.id, bus.line, route, now().add(arrivesIn));
  }
}

extension on Stopwatch {
  Duration Function() get elapsedFn => () => elapsed;
}

/// A line passing a stop, with a fixed schedule: vehicle `k` reaches the stop
/// at `primera + k * frecuencia`. The service starts at vehicle 0 (the one
/// prepared so the user can catch it): there are no earlier buses that would
/// arrive first and could not be boarded.
class _Service {
  final String line;
  final RouteLine route;
  final DateTime primera;
  final SimulationParams p;

  _Service({
    required this.line,
    required this.route,
    required this.primera,
    required this.p,
  });

  Polyline get shape => route.line;
  double get recStop => route.routeStop;

  DateTime arrival(int k) => primera.add(p.frequency * k);

  /// Meters along the shape of vehicle [k] at [t]: it travels at constant
  /// speed, stops at the stop and moves on.
  double routeIn(int k, DateTime t) {
    final dt = t.difference(arrival(k)).inMicroseconds / 1e6;
    if (dt < 0) return recStop + dt * p.busMps;
    final det = p.stopped.inMicroseconds / 1e6;
    if (dt <= det) return recStop;
    return recStop + (dt - det) * p.busMps;
  }

  /// The first vehicle that reaches the stop at [t] or later.
  int nextFrom(DateTime t) => math.max(
    0,
    (t.difference(primera).inMicroseconds / p.frequency.inMicroseconds).ceil(),
  );

  /// Vehicles that may be on the route at [t].
  Iterable<int> near(DateTime t) sync* {
    final f = p.frequency.inMicroseconds / 1e6;
    final antes = (recStop / p.busMps / f).ceil() + 1;
    final after = ((shape.long - recStop) / p.busMps / f).ceil() + 1;
    final k = nextFrom(t);
    for (var i = math.max(0, k - after); i <= k + antes; i++) {
      yield i;
    }
  }
}

// --------------------------------------------------------------------------
// User's script
// --------------------------------------------------------------------------

class _Position {
  final Coordinate coordinate;
  final double velocity;
  const _Position(this.coordinate, this.velocity);
}

class _Segment {
  final DateTime from;
  final DateTime until;
  final _Position Function(DateTime t) en;
  const _Segment(this.from, this.until, this.en);
}

class _Script {
  final List<_Segment> segments;
  _Script(this.segments);

  static _Script build(
    SimulatedWorld m,
    TripOption o,
    Map<String, RouteLine?> routes,
    DateTime inicio,
    Coordinate from,
  ) {
    final p = m.p;
    final segs = <_Segment>[];
    var t = inicio;
    var here = from;
    Duration seg(double s) => Duration(microseconds: (s * 1e6).round());

    void still(DateTime until) {
      if (!until.isAfter(t)) return;
      final c = here;
      segs.add(_Segment(t, until, (_) => _Position(c, 0)));
      t = until;
    }

    // From [aqui] to [b] in a straight line over [d].
    void towardIn(Coordinate b, Duration d) {
      final a = here, t0 = t, t1 = t.add(d);
      final v = distance(a, b) / math.max(0.001, d.inMicroseconds / 1e6);
      segs.add(
        _Segment(t0, t1, (x) {
          final f = (x.difference(t0).inMicroseconds / d.inMicroseconds).clamp(
            0.0,
            1.0,
          );
          return _Position(
            Coordinate(
              a.lat + (b.lat - a.lat) * f,
              a.lng + (b.lng - a.lng) * f,
            ),
            v,
          );
        }),
      );
      t = t1;
      here = b;
    }

    // Walks along [pts] from where it is: it joins the path at its nearest
    // point (within the first meters), without going back to its start.
    void walkBy(List<Coordinate> pts) {
      var rest = pts;
      if (pts.length >= 2) {
        final poli = Polyline(pts);
        final join = poli.project(here, until: math.min(poli.long, 150));
        rest = poli.leg(join.route, poli.long);
      }
      final path = [
        if (rest.isEmpty || distance(here, rest.first) > 0.5) here,
        ...rest,
      ];
      if (path.length < 2) return;
      final poli = Polyline(path);
      final dur = seg(poli.long / p.walkMps);
      final t0 = t;
      segs.add(
        _Segment(t0, t0.add(dur), (x) {
          final f =
              dur.inMicroseconds == 0
                  ? 1.0
                  : (x.difference(t0).inMicroseconds / dur.inMicroseconds)
                      .clamp(0.0, 1.0);
          return _Position(poli.pointAt(poli.long * f), p.walkMps);
        }),
      );
      t = t0.add(dur);
      here = path.last;
    }

    // Gets off the bus of leg [i]: stays still for a few seconds and continues
    // from there (the next walk picks it up where it is). If the trip ends on
    // the bus, walks to the stop.
    void getOff(int i, Coordinate stop) {
      still(t.add(p.alighting));
      if (i + 1 >= o.legs.length) walkBy([stop]);
    }

    // The vehicle the user takes on the next boarding.
    (_Service, int)? vehicle;

    for (var i = 0; i < o.legs.length; i++) {
      final leg = o.legs[i];
      switch (leg) {
        case WalkLeg(:final geometry):
          walkBy(geometry);
        case WaitLeg(:final stop):
          if (distance(here, stop.coordinate) > 0.5) {
            walkBy([stop.coordinate]);
          }
          final bus = o.legs[i + 1] as BusLeg;
          final rec = routes[bus.id];
          if (rec == null) break;
          final min = t.add(Duration(seconds: p.waitMin));
          // The first boarding's service already exists from the preview
          // (and does not run); a transfer's service is created now, with its
          // bus arriving shortly after the user.
          final s = m._service(stop.id, bus.line, rec, min);
          // Takes the first one that arrives after them.
          final k = s.nextFrom(min);
          vehicle = (s, k);
          still(s.arrival(k));
        case BusLeg(:final boarding, :final alighting):
          final rec = routes[leg.id];
          if (rec == null) {
            // No route: goes straight along the leg's geometry.
            final poli = Polyline(leg.geometry);
            final dur = seg(poli.long / p.busMps);
            final t0 = t;
            segs.add(
              _Segment(t0, t0.add(dur), (x) {
                final f = (x.difference(t0).inMicroseconds /
                        math.max(1, dur.inMicroseconds))
                    .clamp(0.0, 1.0);
                return _Position(poli.pointAt(poli.long * f), p.busMps);
              }),
            );
            t = t0.add(dur);
            here = leg.geometry.last;
            getOff(i, alighting.coordinate);
            break;
          }
          final (s, k) =
              vehicle ??
              () {
                final s = m._service(boarding.id, leg.line, rec, t);
                return (s, s.nextFrom(t));
              }();
          vehicle = null;
          // Boards while the bus is parked at the stop: finishes boarding
          // when the bus starts moving.
          still(s.arrival(k));
          final starts = s.arrival(k).add(p.stopped);
          final board = starts.difference(t);
          towardIn(
            s.shape.pointAt(s.recStop),
            board > const Duration(seconds: 1)
                ? board
                : const Duration(seconds: 1),
          );
          // Rides that vehicle until alighting.
          final recAlighting = math.max(
            s.recStop + 1,
            s.shape.project(alighting.coordinate, from: s.recStop).route,
          );
          final arrivesAlighting = s
              .arrival(k)
              .add(p.stopped)
              .add(seg((recAlighting - s.recStop) / p.busMps));
          final t0 = t;
          segs.add(
            _Segment(
              t0,
              arrivesAlighting,
              (x) => _Position(
                s.shape.pointAt(math.min(recAlighting, s.routeIn(k, x))),
                p.busMps,
              ),
            ),
          );
          t = arrivesAlighting;
          here = s.shape.pointAt(recAlighting);
          getOff(i, alighting.coordinate);
      }
    }
    if (segs.isEmpty) {
      final c = here;
      segs.add(_Segment(t, t, (_) => _Position(c, 0)));
    }
    return _Script(segs);
  }

  _Position position(DateTime t) {
    for (final s in segments) {
      if (!t.isAfter(s.until)) {
        return s.en(t.isBefore(s.from) ? s.from : t);
      }
    }
    final last = segments.last.en(segments.last.until);
    return _Position(last.coordinate, 0);
  }
}

// --------------------------------------------------------------------------
// Simulated ports
// --------------------------------------------------------------------------

class SimulatedLocation implements LocationSource {
  final SimulatedWorld world;
  SimulatedLocation(this.world);

  @override
  Future<LocationPermissionState> ensurePermission() async =>
      LocationPermissionState.granted;

  @override
  Future<LocationSample?> actual() async => world.sample();

  /// Checks (real time) every this often whether a sample is due.
  static const _tic = Duration(milliseconds: 100);

  @override
  Stream<LocationSample> follow() {
    late StreamController<LocationSample> c;
    Timer? timer;
    c = StreamController<LocationSample>(
      onListen: () {
        // One sample every intervaloGps (real) or every intervaloGpsSimulado
        // of the world, whichever comes first (the speed changes on the fly).
        var real = Duration.zero;
        var last = world.now();
        timer = Timer.periodic(_tic, (_) {
          real += _tic;
          final now = world.now();
          if (real < world.p.intervaloGps &&
              now.difference(last) < world.p.intervaloGpsSimulated) {
            return;
          }
          real = Duration.zero;
          last = now;
          c.add(world.sample());
        });
      },
      onCancel: () => timer?.cancel(),
    );
    return c.stream;
  }
}

/// Wraps a real planner and prepares the synthetic buses for each option,
/// so the preview already shows a bus on its way.
class SimulatedPlanner implements TripPlanner {
  final TripPlanner real;
  final SimulatedWorld world;
  final Map<String, Map<String, String>> _shapes = {};

  SimulatedPlanner(this.real, this.world);

  Map<String, String> shapesOf(String idOption) =>
      _shapes[idOption] ?? const {};

  @override
  Future<List<PlannedTrip>> plan({
    required Coordinate origin,
    required Coordinate destination,
    required DateTime exit,
  }) async {
    final trips = await real.plan(
      origin: origin,
      destination: destination,
      exit: exit,
    );
    for (final v in trips) {
      _shapes[v.option.id] = v.shapeByLeg;
      final bus = v.option.firstBus;
      if (bus == null) continue;
      final walk =
          v.option.legs.first is WalkLeg
              ? (v.option.legs.first as WalkLeg).durationSeconds
              : 0;
      await world.prepareLine(
        bus,
        v.shapeByLeg[bus.id],
        arrivesIn: Duration(seconds: walk + 90),
      );
    }
    return trips;
  }
}

class SimulatedArrivals implements SourceArrivals {
  final SimulatedWorld world;

  /// Lines that pass each stop (from the catalog).
  final Future<Map<String, List<String>>> _lines;

  SimulatedArrivals(this.world)
    : _lines = world.catalog.stops().then(
        (ps) => {for (final p in ps) p.stop.id: p.lines},
      );

  @override
  Future<List<StopArrival>> arrivals(String idStop) async {
    final lines = (await _lines)[idStop] ?? const <String>[];
    return world.arrivalsIn(idStop, lines.take(6).toList());
  }
}
