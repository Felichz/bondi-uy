// Secondary flows and edge cases, with the full app.

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/logic/ports.dart';
import 'package:bondi_uy/ui/ui_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

class _PlanThatFails implements TripPlanner {
  bool fail = true;
  final TripPlanner real;
  _PlanThatFails(this.real);

  @override
  Future<List<PlannedTrip>> plan({
    required Coordinate origin,
    required Coordinate destination,
    required DateTime exit,
  }) async {
    if (fail) throw const ServiceError('otp', 'no connection');
    return real.plan(origin: origin, destination: destination, exit: exit);
  }
}

/// Keeps only the itineraries with a transfer (to exercise that flow).
class _TransfersOnly implements TripPlanner {
  final TripPlanner real;
  _TransfersOnly(this.real);

  @override
  Future<List<PlannedTrip>> plan({
    required Coordinate origin,
    required Coordinate destination,
    required DateTime exit,
  }) async => [
    for (final v in await real.plan(
      origin: origin,
      destination: destination,
      exit: exit,
    ))
      if (v.option.lines.length == 2) v,
  ];
}

class _PlanEmpty implements TripPlanner {
  @override
  Future<List<PlannedTrip>> plan({
    required Coordinate origin,
    required Coordinate destination,
    required DateTime exit,
  }) async => const [];
}

class _WithoutPermission implements LocationSource {
  @override
  Future<LocationPermissionState> ensurePermission() async =>
      LocationPermissionState.denied;
  @override
  Future<LocationSample?> current() async => null;
  @override
  Stream<LocationSample> follow() => const Stream.empty();
}

void main() {
  testWidgets('transfer 526 -> 109: seven steps, two live waits', (
    tester,
  ) async {
    final a = await Harness.mount(
      tester,
      prefix: 'transfer',
      wrapPlan: (real) => _TransfersOnly(real),
    );
    await a.searchSquare();
    // Swipe to the option with two buses.
    var attempts = 0;
    TripOption focused() {
      final f = a.phase as OptionsPhase;
      final id = a.container.read(optionFocusedProvider);
      return f.options.firstWhere(
        (o) => o.id == id,
        orElse: () => f.options.first,
      );
    }

    while (focused().lines.length < 2 && attempts++ < 8) {
      await tester.drag(
        find.byKey(const ValueKey('options-carousel')),
        const Offset(-300, 0),
      );
      await a.wait(const Duration(milliseconds: 700));
    }
    final option = focused();
    expect(
      option.lines.length,
      2,
      reason: 'there is an option with a transfer',
    );
    await a.capture('option_transfer');
    await a.tap('start-trip');
    final total = (a.phase as TripPhase).totalSteps;
    expect(total, 7);

    await a.untilStep(1);
    await a.wait(const Duration(seconds: 2));
    expect(find.textContaining('Esperá el ${option.lines[0]}'), findsOneWidget);
    await a.capture('wait_1');
    await a.untilStep(2);
    await a.wait(const Duration(seconds: 2));
    expect(
      find.textContaining('Viajá en el ${option.lines[0]}'),
      findsOneWidget,
    );
    // On board the bus there is no expected bus: the bus is the user.
    expect((a.phase as TripPhase).busExpected, isNull);
    await a.capture('on_bus_1');
    await a.untilStep(3);
    await a.wait(const Duration(seconds: 1));
    expect(find.text('Caminá hasta la parada'), findsOneWidget);
    await a.capture('transfer_walking');
    await a.untilStep(4);
    await a.wait(const Duration(seconds: 2));
    expect(find.textContaining('Esperá el ${option.lines[1]}'), findsOneWidget);
    final bus = (a.phase as TripPhase).busExpected;
    expect(
      bus?.line,
      option.lines[1],
      reason: 'the live bus is from the second line',
    );
    await a.capture('wait_2');
    await a.untilStep(5);
    await a.until(
      () =>
          ((a.phase as TripPhase).progress.stopsLeft ?? 99) == 0 ||
          (a.phase as TripPhase).currentStep > 5,
      max: const Duration(minutes: 5),
      reason: 'last stop',
    );
    if ((a.phase as TripPhase).currentStep == 5) {
      expect(find.text('¡Bajate en la próxima!'), findsOneWidget);
      await a.capture('get_off');
    }
    await a.untilStep(6);
    await a.until(
      () => (a.phase as TripPhase).status == TripStatus.completed,
      max: const Duration(minutes: 4),
      reason: 'arrival',
    );
    await a.wait(const Duration(seconds: 1));
    expect(find.text('¡Llegaste!'), findsOneWidget);
    // The arrival card closes by itself.
    await a.wait(const Duration(seconds: 13));
    expect(a.phase, isA<ExplorePhase>());
    await a.close();
  });

  testWidgets(
    'going back from options keeps the destination and allows repeating',
    (tester) async {
      final a = await Harness.mount(tester, prefix: 'back');
      await a.searchSquare();
      await a.tap('options-close');
      expect(a.phase, isA<ExplorePhase>());
      expect(find.byKey(const ValueKey('search-full')), findsOneWidget);
      expect(find.text('Plaza Independencia'), findsOneWidget);
      await a.capture('saved_destination');
      await a.tap('see-trips');
      await a.until(
        () =>
            a.phase is OptionsPhase &&
            (a.phase as OptionsPhase).status == OptionsStatus.ready,
      );
      await a.close();
    },
  );

  testWidgets('finishing the trip asks for confirmation', (tester) async {
    final a = await Harness.mount(tester, prefix: 'finish');
    await a.searchSquare();
    await a.tap('start-trip');
    await a.tap('trip-finish');
    expect(find.text('¿Terminar el viaje?'), findsOneWidget);
    await a.capture('confirm');
    await tester.tap(find.text('Seguir'));
    await a.wait(const Duration(milliseconds: 400));
    expect(a.phase, isA<TripPhase>());
    await a.tap('trip-finish');
    await a.tap('trip-finish-confirm');
    expect(a.phase, isA<ExplorePhase>());
    await a.close();
  });

  testWidgets(
    'manual fallback: "Ya estoy en la parada", "Ya subí", "Ya me bajé"',
    (tester) async {
      final a = await Harness.mount(tester, prefix: 'manual', velocity: 1);
      await a.searchSquare();
      await a.tap('start-trip');
      expect(find.text('Ya estoy en la parada'), findsOneWidget);
      await a.tap('trip-confirm-step');
      expect((a.phase as TripPhase).currentStep, 1);
      expect((a.phase as TripPhase).originAdvance, OriginAdvance.manual);
      expect(find.text('Ya subí al bus'), findsOneWidget);
      await a.tap('trip-confirm-step');
      expect((a.phase as TripPhase).currentStep, 2);
      expect(find.text('Ya me bajé'), findsOneWidget);
      await a.tap('trip-confirm-step');
      expect((a.phase as TripPhase).currentStep, 3);
      expect(find.text('Ya llegué'), findsOneWidget);
      await a.tap('trip-confirm-step');
      expect((a.phase as TripPhase).status, TripStatus.completed);
      await a.close();
    },
  );

  testWidgets('tapping a stop shows its upcoming buses', (tester) async {
    final a = await Harness.mount(tester, prefix: 'stop');
    await a.until(
      () => a.controller.state.stops.isNotEmpty,
      reason: 'stop network',
    );
    a.controller.queryStop('5296');
    await a.wait(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('stop-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('arrival-0')), findsOneWidget);
    await a.wait(const Duration(seconds: 1));
    await a.capture('stop_sheet');
    await a.tap('stop-close');
    expect(a.controller.state.stopQueried, isNull);
    await a.close();
  });

  testWidgets('swap origin and destination', (tester) async {
    final a = await Harness.mount(tester, prefix: 'swap');
    await a.searchSquare();
    await a.tap('options-edit');
    await a.tap('search-swap');
    final b = a.controller.state.search;
    expect(b.origin, isA<ChosenPlace>());
    expect(b.destination, isA<MyLocation>());
    await a.capture('swapped');
    await a.tap('search-back');
    await a.close();
  });

  testWidgets('if planning fails it can be retried', (tester) async {
    late _PlanThatFails plan;
    final a = await Harness.mount(
      tester,
      prefix: 'error',
      wrapPlan: (real) => plan = _PlanThatFails(real),
    );
    await a.searchSquare();
    expect((a.phase as OptionsPhase).status, OptionsStatus.error);
    expect(find.text('No pudimos calcular el viaje'), findsOneWidget);
    await a.capture('error');
    plan.fail = false;
    await tester.tap(find.text('Reintentar'));
    await a.until(
      () => (a.phase as OptionsPhase).status == OptionsStatus.ready,
    );
    await a.close();
  });

  testWidgets('no results offers changing the destination', (tester) async {
    final a = await Harness.mount(
      tester,
      prefix: 'empty',
      wrapPlan: (_) => _PlanEmpty(),
    );
    await a.searchSquare();
    expect((a.phase as OptionsPhase).status, OptionsStatus.withoutResults);
    expect(find.text('Cambiar destino'), findsOneWidget);
    await a.close();
  });

  testWidgets('no location permission: notice and search from another origin', (
    tester,
  ) async {
    final a = await Harness.mount(
      tester,
      prefix: 'no_location',
      wrapLocation: (_) => _WithoutPermission(),
    );
    await a.wait(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('notice-location')), findsOneWidget);
    await a.capture('notice');
    // With "Mi ubicación" as the origin, planning is not possible: it warns.
    await a.tap('search-destination');
    await tester.enterText(
      find.byKey(const ValueKey('field-destination')),
      'plaza',
    );
    await a.wait(const Duration(milliseconds: 600));
    await a.tap('suggestion-plaza-independencia');
    await a.wait(const Duration(milliseconds: 500));
    expect(
      find.byKey(const ValueKey('notice-withoutLocation')),
      findsOneWidget,
    );
    expect(a.phase, isA<ExplorePhase>());
    // Choose another origin and search.
    await a.tap('search-full');
    await tester.tap(find.byKey(const ValueKey('field-origin')));
    await a.wait(const Duration(milliseconds: 300));
    await tester.enterText(
      find.byKey(const ValueKey('field-origin')),
      'saldanha',
    );
    await a.wait(const Duration(milliseconds: 600));
    await a.tap('suggestion-saldanha-3941');
    await a.until(
      () =>
          a.phase is OptionsPhase &&
          (a.phase as OptionsPhase).status == OptionsStatus.ready,
      reason: 'plans from the chosen origin',
    );
    await a.close();
  });
}
