// Modo demo, como lo usa un visitante del portfolio: sin servidores, elige
// un destino con un toque, acelera el tiempo, hace el viaje entero, vuelve a
// casa y hace otro.

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/logic/simulacion/demo.dart';
import 'package:bondi_uy/ui/textos/textos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arnes.dart';

void main() {
  testWidgets('dos viajes seguidos desde la tarjeta de la demo', (
    tester,
  ) async {
    final a = await Arnes.montar(
      tester,
      prefijo: 'demo',
      demo: true,
      velocidad: velocidadDemoInicial,
    );
    await a.esperar(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('demo-tarjeta')), findsOneWidget);
    expect(find.text('Terminal Tres Cruces'), findsOneWidget);
    await a.capturar('inicio');

    Future<void> viaje(String destino) async {
      // La fila de destinos se desliza: se busca el destino como lo haría
      // una persona.
      await tester.dragUntilVisible(
        find.byKey(ValueKey('demo-destino-$destino')),
        find.byKey(const ValueKey('demo-destinos')),
        const Offset(-160, 0),
      );
      await a.esperar(const Duration(milliseconds: 300));
      await a.tocar('demo-destino-$destino');
      await a.hasta(
        () =>
            a.fase is FaseOpciones &&
            (a.fase as FaseOpciones).estado == EstadoOpciones.listo,
        razon: 'opciones de $destino',
      );
      final opciones = (a.fase as FaseOpciones).opciones;
      expect(opciones.where((o) => o.recomendada), hasLength(1));
      await a.esperar(const Duration(seconds: 1));
      await a.capturar('opciones_$destino');
      await a.tocar('empezar-viaje');
      expect(a.fase, isA<FaseViaje>());
      await a.hasta(
        () => (a.fase as FaseViaje).estado == EstadoViaje.completado,
        maximo: const Duration(minutes: 8),
        razon: 'llegar a $destino',
      );
      await a.esperar(const Duration(seconds: 1));
      expect(find.text('¡Llegaste!'), findsOneWidget);
      await a.capturar('llegada_$destino');
      await a.tocar('viaje-listo');
      expect(a.fase, isA<FaseExplorar>());
    }

    // Más rápido: la velocidad se cambia sin que el reloj salte.
    await a.tocar('demo-velocidad');
    expect(a.controlador.state.demo!.velocidad, 30);

    await viaje('tres-cruces');
    // De vuelta en casa, de donde sale el próximo viaje.
    await a.esperar(const Duration(seconds: 2));
    final ubicacion = a.controlador.state.ubicacion.coordenada!;
    expect((ubicacion.lat - casaDemo.lat).abs(), lessThan(0.001));
    expect((ubicacion.lng - casaDemo.lng).abs(), lessThan(0.001));
    await viaje('mercado-puerto');
    await a.cerrar();
  });

  testWidgets('en inglés: los textos y los formatos cambian', (tester) async {
    final a = await Arnes.montar(
      tester,
      prefijo: 'demo_en',
      demo: true,
      velocidad: velocidadDemoInicial,
      idioma: Idioma.en,
    );
    await a.esperar(const Duration(seconds: 2));
    expect(find.text('Try a trip'), findsOneWidget);
    expect(find.text('Where to?'), findsOneWidget);
    await a.capturar('inicio');
    await a.tocar('demo-destino-tres-cruces');
    await a.hasta(
      () =>
          a.fase is FaseOpciones &&
          (a.fase as FaseOpciones).estado == EstadoOpciones.listo,
    );
    await a.esperar(const Duration(seconds: 1));
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('Start trip'), findsOneWidget);
    await a.capturar('opciones');
    await a.tocar('empezar-viaje');
    await a.esperar(const Duration(seconds: 2));
    expect(find.textContaining('Step 1 of'), findsOneWidget);
    expect(find.text('Walk to the stop'), findsOneWidget);
    await a.capturar('caminando');
    await a.hastaPaso(2);
    await a.esperar(const Duration(seconds: 2));
    expect(find.textContaining('Ride the'), findsOneWidget);
    expect(find.textContaining('to go'), findsOneWidget);
    await a.capturar('en_bus');
    await a.cerrar();
  });
}
