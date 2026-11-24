// Demo mode: real trips planned by OTP and recorded, from a house
// in Malvín to five destinations in Montevideo. It works without any server of
// its own (only the map tiles come from the internet), so anyone can try the app on the web or on a phone.
//
// The plans were recorded with `tool/capture_trip.dart` against the local OTP
// (Intendencia GTFS + OSM Uruguay) and stored reduced to the raw plan in
// `assets/demo/<id>.json`. Schedules are run at the moment the trip is requested.

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../contract/app_state.dart';
import '../../contract/traces.dart';
import '../app_controller.dart';
import '../traced.dart';
import '../geo/geo.dart';
import '../ports.dart';
import 'recording.dart';
import 'simulated_world.dart';

/// Where the demo user lives (all trips leave from here).
const houseDemo = Coordinate(-34.902448, -56.12828);

/// How many times faster than real time the demo world runs in each part of
/// the trip. While looking at the options, on arrival and while exploring, it
/// runs at real time: the bus in the preview is the one you catch when you
/// start (at 15x, a few seconds of reading would be minutes and that bus
/// would already have passed).
class DemoScales {
  /// Until getting on the bus: walking to the stop and waiting for it (the
  /// user and the approaching bus move at this scale).
  final double walk;

  /// On the bus: a long stretch from one point to another.
  final double bus;

  const DemoScales({this.walk = 30, this.bus = 60});

  /// The scale for state [s].
  double para(AppState s) {
    final f = s.phase;
    if (f is! TripPhase || f.status != TripStatus.inProgress) return 1;
    return f.legActual is BusLeg ? bus : walk;
  }
}

/// Destinations with a recorded trip. The id is the asset name.
const destinationsDemo = [
  Place(
    id: 'plaza-independencia',
    name: 'Plaza Independencia',
    detail: 'Ciudad Vieja, Montevideo',
    coordinate: Coordinate(-34.906971, -56.19946),
  ),
  Place(
    id: 'tres-cruces',
    name: 'Terminal Tres Cruces',
    detail: 'Tres Cruces, Montevideo',
    coordinate: Coordinate(-34.8937, -56.1664),
  ),
  Place(
    id: 'estadio-centenario',
    name: 'Estadio Centenario',
    detail: 'Parque Batlle, Montevideo',
    coordinate: Coordinate(-34.8945, -56.1528),
  ),
  Place(
    id: 'mercado-puerto',
    name: 'Mercado del Puerto',
    detail: 'Ciudad Vieja, Montevideo',
    coordinate: Coordinate(-34.9064, -56.2126),
  ),
  Place(
    id: 'punta-carretas',
    name: 'Punta Carretas Shopping',
    detail: 'Punta Carretas, Montevideo',
    coordinate: Coordinate(-34.9237, -56.1590),
  ),
];

/// Returns the recorded trip to the requested destination. Without a recording
/// (another destination or another origin) there are no trips: the UI says so,
/// as it would in real life.
class DemoPlanner implements TripPlanner {
  final AssetBundle _bundle;
  final Map<String, RecordingPlanner> _cargados = {};

  DemoPlanner({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  /// At this distance (m) a requested point is considered the recorded one.
  static const tolerance = 400.0;

  @override
  Future<List<PlannedTrip>> plan({
    required Coordinate origin,
    required Coordinate destination,
    required DateTime exit,
  }) async {
    if (distance(origin, houseDemo) > tolerance) return const [];
    Place? place;
    for (final l in destinationsDemo) {
      if (distance(destination, l.coordinate) <= tolerance) place = l;
    }
    if (place == null) return const [];
    final plan =
        _cargados[place.id] ??= RecordingPlanner.fromFixture(
          jsonDecode(await _bundle.loadString('assets/demo/${place.id}.json'))
              as Map<String, dynamic>,
        );
    return plan.plan(origin: origin, destination: destination, exit: exit);
  }
}

/// The app's controller in demo mode, over [mundo] (the tests inject a fake
/// clock into it).
AppController createControllerDemo({
  required SimulatedWorld world,
  required CatalogRed catalog,
  AssetBundle? bundle,
  DemoScales scales = const DemoScales(),
  // If given, each call between pieces is reported there.
  Traces? traces,
  // Real time, regardless of the scale: the bus is polled often and the map's
  // prediction smooths out between readings.
  LogicConfig config = const LogicConfig(pollBus: Duration(milliseconds: 1500)),
}) {
  final plan = SimulatedPlanner(DemoPlanner(bundle: bundle), world);
  // The simulated world uses the catalog without tracing: its queries are not
  // the app's, they belong to the backdrop.
  final t = traces;
  final c = AppController(
    planner: t == null ? plan : TracedPlanner(plan, t),
    arrivals:
        t == null
            ? SimulatedArrivals(world)
            : TracedArrivals(SimulatedArrivals(world), t),
    places:
        t == null
            ? const FixedPlaces(destinationsDemo)
            : TracedPlaces(const FixedPlaces(destinationsDemo), t),
    catalog: t == null ? catalog : TracedCatalog(catalog, t),
    location:
        t == null
            ? SimulatedLocation(world)
            : TracedLocation(SimulatedLocation(world), t),
    clock: world.now,
    config: config,
    traces: t,
    onStartTrip: (o) => world.traverse(o, plan.shapesOf(o.id)),
    // Arrived: stays at the destination while "¡Llegaste!" is shown.
    onArrive: world.stop,
    // Finished (closed the arrival or gave up): goes back home, where the
    // next trip leaves from.
    onFinishTrip: () {
      world.stop();
      world.positionInitial = houseDemo;
    },
    demo: const _ControlDemo(),
  );
  // The world's clock follows the pace of the trip (without jumping when it
  // changes). It is not needed at startup: while exploring, nothing moves.
  c.addListener((s) {
    final v = scales.para(s);
    if (v != world.velocity) world.velocity = v;
  }, fireImmediately: false);
  return c;
}

class _ControlDemo implements ControlDemo {
  const _ControlDemo();

  @override
  List<Place> get destinations => destinationsDemo;
}
