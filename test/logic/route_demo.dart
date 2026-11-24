// One end-to-end demo trip, with every state the logic publishes and the clock
// (real and simulated) at that moment. Used by the tests that check how
// everything moves (demo_movimiento_test and demo_cuadros_test).

import 'dart:convert';
import 'dart:io';

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/logic/app_controller.dart';
import 'package:bondi_uy/logic/services/catalog_assets.dart';
import 'package:bondi_uy/logic/simulation/demo.dart';
import 'package:bondi_uy/logic/simulation/simulated_world.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _BundleDisc extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      utf8.decode(File(key).readAsBytesSync());
}

/// A published state, with the real clock and the simulated one at that moment.
class Instant {
  final Duration real;
  final DateTime sim;
  final AppState s;
  Instant(this.real, this.sim, this.s);
}

/// A demo trip end to end, as a visitor takes it: picks a [destino], looks at
/// the options [enOpciones] and starts the recommended one.
List<Instant> traverseDemo({
  required Place destination,
  DemoScales scales = const DemoScales(),
  required Duration inOptions,
  void Function(AppController c, FakeAsync async)? onArrive,
}) {
  late List<Instant> states;
  fakeAsync((async) {
    states = [];
    // Inside the fake time: a future created outside doesn't resolve here.
    final catalog = CatalogAssets(bundle: _BundleDisc());
    final world = SimulatedWorld(
      catalog: catalog,
      positionInitial: houseDemo,
      p: const SimulationParams(velocity: 1),
      nowSimulated: DateTime(2026, 9, 28, 18),
      elapsed: () => async.elapsed,
    );
    final c = createControllerDemo(
      world: world,
      catalog: catalog,
      bundle: _BundleDisc(),
      scales: scales,
    );
    c.addListener(
      (s) => states.add(Instant(async.elapsed, world.now(), s)),
      fireImmediately: false,
    );
    c.start();
    async.elapse(const Duration(seconds: 2));
    c.choosePlace(SearchField.destination, destination);
    c.searchTrips();
    async.elapse(const Duration(seconds: 2));
    final f = c.state.phase as OptionsPhase;
    expect(
      f.status,
      OptionsStatus.ready,
      reason: 'options to ${destination.id}',
    );
    final id = f.options.firstWhere((o) => o.recommended).id;
    c.focusOption(id);
    async.elapse(inOptions);
    c.startTrip(id);
    final limit = async.elapsed + const Duration(hours: 2);
    while (async.elapsed < limit) {
      async.elapse(const Duration(milliseconds: 50));
      final phase = c.state.phase;
      if (phase is TripPhase && phase.status == TripStatus.completed) break;
    }
    final end = c.state.phase;
    expect(
      end is TripPhase && end.status == TripStatus.completed,
      isTrue,
      reason:
          'arrives at ${destination.id}; last states:\n'
          '${states.skip(states.length - 6).map((e) => summaryInstant(e, id)).join('\n')}',
    );
    onArrive?.call(c, async);
    c.dispose();
  });
  return states;
}

/// The wait (leg index) whose bus is being shown, or null.
int? waitVisible(AppState s) {
  final f = s.phase;
  if (f is OptionsPhase) return 1; // the preview follows the first bus
  if (f is! TripPhase || f.status != TripStatus.inProgress) return null;
  for (var i = f.currentStep; i < f.totalSteps; i++) {
    final t = f.option.legs[i];
    if (t is BusLeg) return null;
    if (t is WaitLeg) return i;
  }
  return null;
}

BusInPath? busVisible(AppState s, String idOption) => switch (s.phase) {
  OptionsPhase(:final liveBuses) => liveBuses[idOption],
  TripPhase(:final busExpected) => busExpected,
  _ => null,
};

/// A readable one-line summary of a state (to understand a problem).
String summaryInstant(Instant i, String idOption) {
  final f = i.s.phase;
  final t = (i.real.inMilliseconds / 1000).toStringAsFixed(2);
  final bus = busVisible(i.s, idOption);
  final b =
      bus == null
          ? 'no bus'
          : 'bus ${bus.minutes} min ${bus.metersUntilStop} m';
  if (f is! TripPhase) return '    t=${t}s ${f.runtimeType} $b';
  return '    t=${t}s step ${f.currentStep} (${f.currentLeg.runtimeType}) '
      '${f.progress.metersLeft} m left, $b, '
      'user ${f.user?.lat.toStringAsFixed(6)},${f.user?.lng.toStringAsFixed(6)}';
}
