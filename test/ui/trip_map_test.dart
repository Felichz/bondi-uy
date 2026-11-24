// The map and the panel during the trip, as the user experiences them:
// - the camera follows the user (it does not stay still while walking or traveling),
// - the relevant stops get their balloon (where to board, the next one, where
//   to get off, the destination),
// - if the user moves the map, the camera comes back on its own after a while,
// - each advance is confirmed and the full itinerary is one tap away.

import 'dart:math' as math;

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/ui/common.dart';
import 'package:bondi_uy/ui/ui_status.dart';
import 'package:bondi_uy/ui/formats.dart';
import 'package:bondi_uy/ui/map/scene_painter.dart';
import 'package:bondi_uy/ui/map/projection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

SceneDrawer get _map => SceneDrawer.last!;

void main() {
  testWidgets('la cámara sigue al usuario y las paradas llevan su globo', (
    tester,
  ) async {
    final a = await Harness.mount(tester, prefix: 'viaje_mapa');
    await a.searchSquare();
    // Preview: the boarding stop and the arrival time, labeled.
    expect(_map.balloonsPlaced, contains('Subís al D1'));
    expect(_map.balloonsPlaced.any((g) => g.startsWith('Llegás ')), isTrue);

    await a.tocar('empezar-viaje');
    final option = (a.phase as TripPhase).option;
    final line = option.lines.first;

    // Walking: the camera follows the user as they move, with the
    // stop always in view (the bus, only if it fits without zooming out too much).
    for (var i = 0; i < 6; i++) {
      await a.wait(const Duration(seconds: 1));
      final f = a.phase as TripPhase;
      if (f.stepActual != 0) break;
      final t = f.legActual as WalkLeg;
      expect(_toTheVista(a, _map.userOnScreen!), isTrue, reason: 'vos');
      expect(_toTheVista(a, _inPantalla(t.fin)), isTrue, reason: 'la parada');
      // The incoming bus, if it is out of view, is marked at the edge.
      final bus = _map.busInPantalla;
      if (bus != null && !_toTheVista(a, bus)) {
        expect(_map.busInBorder, startsWith(line), reason: 'indicador del bus');
      }
    }
    expect(_map.balloonsPlaced, contains('Subís al $line'));
    await a.capture('caminando');

    // Waiting: the stop, the incoming bus and you.
    await a.untilStep(1);
    await a.wait(const Duration(seconds: 2));
    final wait = a.phase as TripPhase;
    if (wait.stepActual == 1 && wait.busExpected?.position != null) {
      final t = wait.legActual as WaitLeg;
      expect(_toTheVista(a, _inPantalla(t.stop.coordinate)), isTrue);
      expect(_toTheVista(a, _map.userOnScreen!), isTrue);
      expect(_toTheVista(a, _map.busInPantalla!), isTrue, reason: 'el bus');
      await a.capture('esperando');
    }

    // On the bus: the next stop with its balloon, and the alighting stop in view
    // when it is close.
    await a.untilStep(2);
    await a.wait(const Duration(seconds: 3));
    expect(find.text('Subiste al $line. ¡Buen viaje!'), findsOneWidget);
    expect(find.byKey(const ValueKey('viaje-tira-paradas')), findsOneWidget);
    expect(find.byKey(const ValueKey('viaje-proxima')), findsOneWidget);
    final next = (a.phase as TripPhase).progress.nextStop!;
    expect(
      _map.balloonsPlaced.any(
        (g) => stopName(next.name).startsWith(g.replaceAll('…', '')),
      ),
      isTrue,
      reason: 'globo de la próxima parada: ${_map.balloonsPlaced}',
    );
    await a.capture('en_bus');
    await a.until(
      () => (a.phase as TripPhase).progress.stopsRestantes == 0,
      reason: 'última parada',
    );
    await a.wait(const Duration(seconds: 2));
    expect(_map.balloonsPlaced, contains('¡Bajate en esta!'));
    await a.capture('bajate');

    // Walking to the destination: the destination labeled.
    await a.untilStep(3);
    await a.wait(const Duration(seconds: 2));
    expect(_map.balloonsPlaced, contains('Plaza Independencia'));
    await a.close();
  });

  testWidgets('la subida al bus es un solo movimiento suave', (tester) async {
    final a = await Harness.mount(tester, prefix: 'subida', velocity: 6);
    await a.searchSquare();
    await a.tocar('empezar-viaje');
    await a.untilStep(1);
    final stop = ((a.phase as TripPhase).legActual as WaitLeg).stop.coordinate;
    await a.until(
      () =>
          (a.phase as TripPhase).stepActual > 1 ||
          ((a.phase as TripPhase).busExpected?.minutes ?? 99) <= 1,
      reason: 'el bus está por llegar',
    );
    // Frame by frame (60 fps) from when the bus arrives until already on board.
    const cuadro = Duration(milliseconds: 16);
    Offset? antes;
    double? stepAntes;
    var max = 0.0, tug = 0.0;
    var after = 0;
    var arribaAntesOfConfirm = false;
    while (after < 120) {
      await a.wait(cuadro, step: cuadro);
      final f = a.phase as TripPhase;
      if (f.stepActual == 1) {
        // Your bus is at the stop: neither "no data" nor the next bus.
        expect(find.byKey(const ValueKey('viaje-sin-datos')), findsNothing);
        expect(f.busExpected?.minutes ?? 0, lessThanOrEqualTo(1));
        if (_map.userInBus) arribaAntesOfConfirm = true;
      }
      if (f.stepActual >= 2) after++;
      final p = _inPantalla(stop);
      if (antes != null) {
        final d = (p - antes).distance;
        max = math.max(max, d);
        if (stepAntes != null) tug = math.max(tug, (d - stepAntes).abs());
        stepAntes = d;
      }
      antes = p;
    }
    expect(
      arribaAntesOfConfirm,
      isTrue,
      reason: 'al irse con el bus ya se lo muestra arriba, sin esperar 60 m',
    );
    expect(max, lessThan(12), reason: 'el mapa no pega saltos');
    expect(tug, lessThan(6), reason: 'sin tirones entre cuadros');
    await a.close();
  });

  testWidgets('si movés el mapa en viaje, la cámara vuelve sola', (
    tester,
  ) async {
    final a = await Harness.mount(tester, prefix: 'reanudar');
    await a.searchSquare();
    await a.tocar('empezar-viaje');
    await a.wait(const Duration(seconds: 2));
    final ctl = a.container.read(controllerMapProvider);
    expect(ctl.free, isFalse);

    await tester.drag(
      find.byKey(const ValueKey('mapa')),
      const Offset(0, -250),
    );
    await a.wait(const Duration(milliseconds: 600));
    expect(ctl.free, isTrue);
    expect(find.byKey(const ValueKey('boton-recentrar')), findsOneWidget);
    await a.capture('mapa_movido');

    await a.wait(const Duration(seconds: 13));
    expect(ctl.free, isFalse, reason: 'volvió a seguir al usuario');
    await a.close();
  });

  testWidgets('el itinerario muestra todos los pasos y cuál es el actual', (
    tester,
  ) async {
    final a = await Harness.mount(tester, prefix: 'itinerario');
    await a.searchSquare();
    await a.tocar('empezar-viaje');
    await a.untilStep(1);
    await a.wait(const Duration(seconds: 1));
    await a.tocar('viaje-itinerario');
    expect(find.byKey(const ValueKey('itinerario')), findsOneWidget);
    final line = (a.phase as TripPhase).option.lines.first;
    expect(find.text('Esperá el $line'), findsWidgets);
    expect(find.text('Viajá en el $line'), findsOneWidget);
    expect(find.text('AHORA'), findsOneWidget);
    await a.capture('abierto');
    await a.tocar('itinerario-cerrar');
    expect(find.byKey(const ValueKey('itinerario')), findsNothing);
    await a.close();
  });

  test('capitalizar respeta siglas y conectores', () {
    expect(capitalize('PLAZA INDEPENDENCIA'), 'Plaza Independencia');
    expect(capitalize('HACIA UAM'), 'Hacia UAM');
    expect(capitalize('PARQUE DE LOS ALIADOS'), 'Parque de los Aliados');
    expect(capitalize('AV ITALIA'), 'Av Italia');
    expect(capitalize('POCITOS'), 'Pocitos');
  });
}

/// Where [c] lands on screen according to the camera of the last frame.
Offset _inPantalla(Coordinate c) =>
    _map.camera!.toCanvas(mercator(c), const Offset(206, 446));

/// Inside the visible map: below the step card and above the
/// bottom bar.
bool _toTheVista(Harness a, Offset p) {
  final arriba = 24 + 8 + a.container.read(heightCardTripProvider);
  return p.dx > 0 && p.dx < 412 && p.dy > arriba && p.dy < 892 - 100;
}
