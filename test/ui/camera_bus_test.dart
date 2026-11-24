// The trip camera can follow the incoming bus instead of the user: some people
// care more about where the bus is coming from than where they are.

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/logic/simulation/demo.dart';
import 'package:bondi_uy/ui/map/framing.dart';
import 'package:bondi_uy/ui/map/scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../logic/route_demo.dart';
import 'harness.dart';

void main() {
  test('con "ver el bus", la cámara sigue al bus mientras viene', () {
    final states = traverseDemo(
      destination: destinationsDemo.first,
      inOptions: Duration.zero,
    );
    var withBus = 0, arriba = 0;
    for (final e in states) {
      final f = e.s.phase;
      if (f is! TripPhase || f.status != TripStatus.inProgress) continue;
      final yo = framingOf(e.s, const MapUiStatus())!;
      final bus = framingOf(e.s, const MapUiStatus(verBus: true))!;
      expect(yo.anchor, Vehicles.user, reason: 'por defecto, sigue al usuario');
      if (canSeeBus(f)) {
        withBus++;
        expect(bus.anchor, Vehicles.bus, reason: 'el bus nunca queda afuera');
        expect(bus.vehicles, contains(Vehicles.bus));
        expect(bus.vehicles, isNot(contains(Vehicles.user)));
        expect(
          bus.clave,
          isNot(yo.clave),
          reason: 'cambiar de modo reencuadra',
        );
        expect(bus.tracking, Tracking.continuous);
      } else {
        // On the bus (the bus is the user) or no bus in view: there is no
        // other mode, even if one was chosen.
        if (f.legActual is BusLeg) arriba++;
        expect(bus.anchor, yo.anchor);
        expect(bus.clave, yo.clave);
      }
    }
    expect(withBus, greaterThan(10), reason: 'hubo un bus viniendo');
    expect(arriba, greaterThan(10), reason: 'y un viaje arriba del bus');
  });

  testWidgets('el botón aparece con el bus viniendo, cambia y se va al subir', (
    tester,
  ) async {
    final a = await Harness.mount(
      tester,
      prefix: 'camara_bus',
      demo: true,
      velocity: 15,
    );
    await a.wait(const Duration(seconds: 2));
    final button = find.byKey(const ValueKey('boton-camara'));
    await a.tocar('demo-destino-plaza-independencia');
    await a.until(
      () =>
          a.phase is OptionsPhase &&
          (a.phase as OptionsPhase).status == OptionsStatus.ready,
    );
    await a.tocar('empezar-viaje');
    await a.until(
      () => a.phase is TripPhase && canSeeBus(a.phase as TripPhase),
      reason: 'un bus viniendo',
    );
    await a.wait(const Duration(milliseconds: 400));
    expect(find.text('Ver el bus'), findsOneWidget);
    await a.capture('siguiendome');

    await tester.tap(button);
    await a.wait(const Duration(seconds: 1));
    expect(find.text('Verme a mí'), findsOneWidget);
    await a.capture('siguiendo_al_bus');

    // On the bus the button goes away: you are the bus.
    await a.untilStep(2);
    await a.wait(const Duration(seconds: 1));
    expect(
      tester
          .widget<AnimatedScale>(
            find.byKey(const ValueKey('boton-camara-escala')),
          )
          .scale,
      0,
    );
    await a.close();
  });
}
