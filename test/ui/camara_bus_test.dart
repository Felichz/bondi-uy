// La cámara del viaje puede seguir al bus que viene en vez de al usuario: a
// algunos les importa más por dónde viene el bus que dónde están ellos.

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/logic/simulacion/demo.dart';
import 'package:bondi_uy/ui/mapa/encuadre.dart';
import 'package:bondi_uy/ui/mapa/escena.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../logica/recorrido_demo.dart';
import 'arnes.dart';

void main() {
  test('con "ver el bus", la cámara sigue al bus mientras viene', () {
    final estados = recorrerDemo(
      destino: destinosDemo.first,
      enOpciones: Duration.zero,
    );
    var conBus = 0, arriba = 0;
    for (final e in estados) {
      final f = e.s.fase;
      if (f is! FaseViaje || f.estado != EstadoViaje.enCurso) continue;
      final yo = encuadreDe(e.s, const EstadoUiMapa())!;
      final bus = encuadreDe(e.s, const EstadoUiMapa(verBus: true))!;
      expect(yo.ancla, Moviles.usuario, reason: 'por defecto, sigue al usuario');
      if (puedeVerBus(f)) {
        conBus++;
        expect(bus.ancla, Moviles.bus, reason: 'el bus nunca queda afuera');
        expect(bus.moviles, contains(Moviles.bus));
        expect(bus.moviles, isNot(contains(Moviles.usuario)));
        expect(bus.clave, isNot(yo.clave), reason: 'cambiar de modo reencuadra');
        expect(bus.seguimiento, Seguimiento.continuo);
      } else {
        // Arriba del bus (el bus es el usuario) o sin bus a la vista: no hay
        // otro modo, aunque se haya elegido.
        if (f.tramoActual is TramoBus) arriba++;
        expect(bus.ancla, yo.ancla);
        expect(bus.clave, yo.clave);
      }
    }
    expect(conBus, greaterThan(10), reason: 'hubo un bus viniendo');
    expect(arriba, greaterThan(10), reason: 'y un viaje arriba del bus');
  });

  testWidgets('el botón aparece con el bus viniendo, cambia y se va al subir', (
    tester,
  ) async {
    final a = await Arnes.montar(
      tester,
      prefijo: 'camara_bus',
      demo: true,
      velocidad: 15,
    );
    await a.esperar(const Duration(seconds: 2));
    final boton = find.byKey(const ValueKey('boton-camara'));
    await a.tocar('demo-destino-plaza-independencia');
    await a.hasta(
      () =>
          a.fase is FaseOpciones &&
          (a.fase as FaseOpciones).estado == EstadoOpciones.listo,
    );
    await a.tocar('empezar-viaje');
    await a.hasta(
      () => a.fase is FaseViaje && puedeVerBus(a.fase as FaseViaje),
      razon: 'un bus viniendo',
    );
    await a.esperar(const Duration(milliseconds: 400));
    expect(find.text('Ver el bus'), findsOneWidget);
    await a.capturar('siguiendome');

    await tester.tap(boton);
    await a.esperar(const Duration(seconds: 1));
    expect(find.text('Verme a mí'), findsOneWidget);
    await a.capturar('siguiendo_al_bus');

    // Arriba del bus el botón se va: vos sos el bus.
    await a.hastaPaso(2);
    await a.esperar(const Duration(seconds: 1));
    expect(
      tester
          .widget<AnimatedScale>(
            find.byKey(const ValueKey('boton-camara-escala')),
          )
          .scale,
      0,
    );
    await a.cerrar();
  });
}
