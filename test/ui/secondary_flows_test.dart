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
    if (fail) throw const ServiceError('otp', 'sin conexión');
    return real.plan(origin: origin, destination: destination, exit: exit);
  }
}

/// Keeps only the itineraries with a transfer (to exercise that flow).
class _SoloTransfers implements TripPlanner {
  final TripPlanner real;
  _SoloTransfers(this.real);

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
  Future<LocationSample?> actual() async => null;
  @override
  Stream<LocationSample> follow() => const Stream.empty();
}

void main() {
  testWidgets('trasbordo 526 -> 109: siete pasos, dos esperas en vivo', (
    tester,
  ) async {
    final a = await Harness.mount(
      tester,
      prefix: 'trasbordo',
      wrapPlan: (real) => _SoloTransfers(real),
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
        find.byKey(const ValueKey('opciones-carrusel')),
        const Offset(-300, 0),
      );
      await a.wait(const Duration(milliseconds: 700));
    }
    final option = focused();
    expect(option.lines.length, 2, reason: 'hay una opción con trasbordo');
    await a.capture('opcion_trasbordo');
    await a.tocar('empezar-viaje');
    final total = (a.phase as TripPhase).totalSteps;
    expect(total, 7);

    await a.untilStep(1);
    await a.wait(const Duration(seconds: 2));
    expect(find.textContaining('Esperá el ${option.lines[0]}'), findsOneWidget);
    await a.capture('espera_1');
    await a.untilStep(2);
    await a.wait(const Duration(seconds: 2));
    expect(
      find.textContaining('Viajá en el ${option.lines[0]}'),
      findsOneWidget,
    );
    // On board the bus there is no expected bus: the bus is the user.
    expect((a.phase as TripPhase).busExpected, isNull);
    await a.capture('en_bus_1');
    await a.untilStep(3);
    await a.wait(const Duration(seconds: 1));
    expect(find.text('Caminá hasta la parada'), findsOneWidget);
    await a.capture('trasbordo_caminando');
    await a.untilStep(4);
    await a.wait(const Duration(seconds: 2));
    expect(find.textContaining('Esperá el ${option.lines[1]}'), findsOneWidget);
    final bus = (a.phase as TripPhase).busExpected;
    expect(
      bus?.line,
      option.lines[1],
      reason: 'el bus en vivo es de la segunda línea',
    );
    await a.capture('espera_2');
    await a.untilStep(5);
    await a.until(
      () =>
          ((a.phase as TripPhase).progress.stopsRestantes ?? 99) == 0 ||
          (a.phase as TripPhase).stepActual > 5,
      max: const Duration(minutes: 5),
      reason: 'última parada',
    );
    if ((a.phase as TripPhase).stepActual == 5) {
      expect(find.text('¡Bajate en la próxima!'), findsOneWidget);
      await a.capture('bajate');
    }
    await a.untilStep(6);
    await a.until(
      () => (a.phase as TripPhase).status == TripStatus.completed,
      max: const Duration(minutes: 4),
      reason: 'llegada',
    );
    await a.wait(const Duration(seconds: 1));
    expect(find.text('¡Llegaste!'), findsOneWidget);
    // The arrival card closes by itself.
    await a.wait(const Duration(seconds: 13));
    expect(a.phase, isA<ExplorePhase>());
    await a.close();
  });

  testWidgets('volver desde opciones conserva el destino y permite repetir', (
    tester,
  ) async {
    final a = await Harness.mount(tester, prefix: 'volver');
    await a.searchSquare();
    await a.tocar('opciones-cerrar');
    expect(a.phase, isA<ExplorePhase>());
    expect(find.byKey(const ValueKey('buscar-completo')), findsOneWidget);
    expect(find.text('Plaza Independencia'), findsOneWidget);
    await a.capture('destino_guardado');
    await a.tocar('ver-viajes');
    await a.until(
      () =>
          a.phase is OptionsPhase &&
          (a.phase as OptionsPhase).status == OptionsStatus.ready,
    );
    await a.close();
  });

  testWidgets('terminar el viaje pide confirmación', (tester) async {
    final a = await Harness.mount(tester, prefix: 'terminar');
    await a.searchSquare();
    await a.tocar('empezar-viaje');
    await a.tocar('viaje-terminar');
    expect(find.text('¿Terminar el viaje?'), findsOneWidget);
    await a.capture('confirmar');
    await tester.tap(find.text('Seguir'));
    await a.wait(const Duration(milliseconds: 400));
    expect(a.phase, isA<TripPhase>());
    await a.tocar('viaje-terminar');
    await a.tocar('viaje-terminar-confirmar');
    expect(a.phase, isA<ExplorePhase>());
    await a.close();
  });

  testWidgets(
    'respaldo manual: "Ya estoy en la parada", "Ya subí", "Ya me bajé"',
    (tester) async {
      final a = await Harness.mount(tester, prefix: 'manual', velocity: 1);
      await a.searchSquare();
      await a.tocar('empezar-viaje');
      expect(find.text('Ya estoy en la parada'), findsOneWidget);
      await a.tocar('viaje-confirmar-paso');
      expect((a.phase as TripPhase).stepActual, 1);
      expect((a.phase as TripPhase).originAdvance, OriginAdvance.manual);
      expect(find.text('Ya subí al bus'), findsOneWidget);
      await a.tocar('viaje-confirmar-paso');
      expect((a.phase as TripPhase).stepActual, 2);
      expect(find.text('Ya me bajé'), findsOneWidget);
      await a.tocar('viaje-confirmar-paso');
      expect((a.phase as TripPhase).stepActual, 3);
      expect(find.text('Ya llegué'), findsOneWidget);
      await a.tocar('viaje-confirmar-paso');
      expect((a.phase as TripPhase).status, TripStatus.completed);
      await a.close();
    },
  );

  testWidgets('tocar una parada muestra sus próximos buses', (tester) async {
    final a = await Harness.mount(tester, prefix: 'parada');
    await a.until(
      () => a.controller.state.stops.isNotEmpty,
      reason: 'red de paradas',
    );
    a.controller.queryStop('5296');
    await a.wait(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('parada-nombre')), findsOneWidget);
    expect(find.byKey(const ValueKey('llegada-0')), findsOneWidget);
    await a.wait(const Duration(seconds: 1));
    await a.capture('hoja_parada');
    await a.tocar('parada-cerrar');
    expect(a.controller.state.stopQueried, isNull);
    await a.close();
  });

  testWidgets('intercambiar origen y destino', (tester) async {
    final a = await Harness.mount(tester, prefix: 'intercambiar');
    await a.searchSquare();
    await a.tocar('opciones-editar');
    await a.tocar('busqueda-intercambiar');
    final b = a.controller.state.search;
    expect(b.origin, isA<ChosenPlace>());
    expect(b.destination, isA<MyLocation>());
    await a.capture('intercambiado');
    await a.tocar('busqueda-volver');
    await a.close();
  });

  testWidgets('si falla la planificación se puede reintentar', (tester) async {
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

  testWidgets('sin resultados ofrece cambiar el destino', (tester) async {
    final a = await Harness.mount(
      tester,
      prefix: 'vacio',
      wrapPlan: (_) => _PlanEmpty(),
    );
    await a.searchSquare();
    expect((a.phase as OptionsPhase).status, OptionsStatus.withoutResults);
    expect(find.text('Cambiar destino'), findsOneWidget);
    await a.close();
  });

  testWidgets('sin permiso de ubicación: aviso y búsqueda desde otro origen', (
    tester,
  ) async {
    final a = await Harness.mount(
      tester,
      prefix: 'sin_ubicacion',
      wrapLocation: (_) => _WithoutPermission(),
    );
    await a.wait(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('aviso-ubicacion')), findsOneWidget);
    await a.capture('aviso');
    // With "Mi ubicación" as the origin, planning is not possible: it warns.
    await a.tocar('buscar-destino');
    await tester.enterText(
      find.byKey(const ValueKey('campo-destino')),
      'plaza',
    );
    await a.wait(const Duration(milliseconds: 600));
    await a.tocar('sugerencia-plaza-independencia');
    await a.wait(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('aviso-withoutLocation')), findsOneWidget);
    expect(a.phase, isA<ExplorePhase>());
    // Choose another origin and search.
    await a.tocar('buscar-completo');
    await tester.tap(find.byKey(const ValueKey('campo-origen')));
    await a.wait(const Duration(milliseconds: 300));
    await tester.enterText(
      find.byKey(const ValueKey('campo-origen')),
      'saldanha',
    );
    await a.wait(const Duration(milliseconds: 600));
    await a.tocar('sugerencia-saldanha-3941');
    await a.until(
      () =>
          a.phase is OptionsPhase &&
          (a.phase as OptionsPhase).status == OptionsStatus.ready,
      reason: 'planifica desde el origen elegido',
    );
    await a.close();
  });
}
