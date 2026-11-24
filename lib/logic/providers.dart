// Composition of the logic layer and access point for the UI.
//
// The UI only uses `appStateProvider` (reads AppState) and `appActionsProvider`
// (invokes AppActions). Everything else is internal to the logic.
//
// Execution mode (`--dart-define=BONDI_MODO=...`):
//   real      OTP + Montevideo API + phone GPS (default)
//   demo      no servers: real trips recorded from Malvín to several
//             destinations, the user and the buses move on their own, with
//             time accelerated (default on the web). Reports its calls
//             (traces) so the web presentation can show the app from inside
//   simulado  real OTP, but the user and the buses move on their own
//   grabado   no network: a single recorded OTP plan + simulated world (tests)

import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contract/app_state.dart';
import '../contract/providers.dart';
import '../contract/traces.dart';
import 'app_controller.dart';
import 'ports.dart';
import 'traced.dart';
import 'services/catalog_assets.dart';
import 'services/places.dart';
import 'services/montevideo.dart';
import 'services/otp.dart';
import 'services/gps_location.dart';
import 'simulation/demo.dart';
import 'simulation/recording.dart';
import 'simulation/simulated_world.dart';

enum ModoApp { real, demo, simulated, recorded }

ModoApp modeFromEnvironment() => switch (const String.fromEnvironment(
  'BONDI_MODO',
)) {
  'demo' => ModoApp.demo,
  'simulado' => ModoApp.simulated,
  'grabado' => ModoApp.recorded,
  'real' => ModoApp.real,
  // On the web there is no reliable GPS or own servers: demo.
  _ => kIsWeb ? ModoApp.demo : ModoApp.real,
};

/// Origin of the simulated user (by default, the one from the recorded fixture).
const _originSimulated = Coordinate(-34.902448, -56.12828);

const fixtureRecorded = 'test/fixtures/trip_saldanha_plaza_otp_v2.json';

final modoAppProvider = Provider<ModoApp>((_) => modeFromEnvironment());

/// Calls between pieces, demo only (not listening to them costs nothing).
final tracesLogicProvider = Provider<Traces?>((ref) {
  if (ref.watch(modoAppProvider) != ModoApp.demo) return null;
  final t = Traces();
  ref.onDispose(t.close);
  return t;
});

final appControllerProvider = StateNotifierProvider<AppController, AppState>((
  ref,
) {
  final modo = ref.watch(modoAppProvider);
  final catalog = CatalogAssets();
  switch (modo) {
    case ModoApp.real:
      return AppController(
        planner: PlannerOtp(),
        arrivals:
            arrivalsMontevideoConfigured
                ? MontevideoArrivals()
                : const _WithoutArrivals(),
        places: searcherPlacesByDefault(),
        catalog: catalog,
        location: GpsLocation(),
      );
    case ModoApp.demo:
      return createControllerDemo(
        world: SimulatedWorld(
          catalog: catalog,
          positionInitial: houseDemo,
          // The demo sets the scale according to the trip's pace (EscalasDemo).
          p: const SimulationParams(velocity: 1),
        ),
        catalog: catalog,
        traces: ref.watch(tracesLogicProvider),
      );
    case ModoApp.simulated:
    case ModoApp.recorded:
      final world = SimulatedWorld(
        catalog: catalog,
        positionInitial: _originSimulated,
        p: const SimulationParams(velocity: 6),
      );
      final base =
          modo == ModoApp.simulated
              ? PlannerOtp()
              : _PlannerOfAsset(fixtureRecorded);
      final plan = SimulatedPlanner(base, world);
      return AppController(
        planner: plan,
        arrivals: SimulatedArrivals(world),
        places:
            modo == ModoApp.simulated
                ? searcherPlacesByDefault()
                : FixedPlaces.montevideo,
        catalog: catalog,
        location: SimulatedLocation(world),
        clock: world.now,
        config: LogicConfig(
          pollBus: Duration(milliseconds: (10000 / world.p.velocity).round()),
        ),
        onStartTrip: (o) => world.traverse(o, plan.shapesOf(o.id)),
        onFinishTrip: world.stop,
      );
  }
});

/// Connects the contract with this logic layer (use at the composition root:
/// `ProviderScope(overrides: overridesLogica)`).
final overridesLogic = <Override>[
  appStateProvider.overrideWith((ref) => ref.watch(appControllerProvider)),
  appActionsProvider.overrideWith((ref) {
    final actions = ref.watch(appControllerProvider.notifier);
    final traces = ref.watch(tracesLogicProvider);
    return traces == null ? actions : TracedActions(actions, traces);
  }),
  tracesProvider.overrideWith((ref) => ref.watch(tracesLogicProvider)),
];

class _WithoutArrivals implements SourceArrivals {
  const _WithoutArrivals();
  @override
  Future<List<StopArrival>> arrivals(String idStop) async => const [];
}

class _PlannerOfAsset implements TripPlanner {
  final String asset;
  RecordingPlanner? _plan;
  _PlannerOfAsset(this.asset);

  @override
  Future<List<PlannedTrip>> plan({
    required Coordinate origin,
    required Coordinate destination,
    required DateTime exit,
  }) async {
    _plan ??= RecordingPlanner.fromFixture(
      jsonDecode(await rootBundle.loadString(asset)) as Map<String, dynamic>,
    );
    return _plan!.plan(origin: origin, destination: destination, exit: exit);
  }
}
