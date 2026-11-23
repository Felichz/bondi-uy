// Modo demo, como lo usa un visitante del portfolio: sin servidores, elige
// un destino con un toque, acelera el tiempo, hace el viaje entero, vuelve a
// casa y hace otro.

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/logic/simulacion/demo.dart';
import 'package:bondi_uy/ui/textos/textos.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    // La cifra cambia con un fundido: por un instante están la vieja y la
    // nueva.
    expect(find.textContaining('to go'), findsWidgets);
    await a.capturar('en_bus');
    await a.cerrar();
  });
  testWidgets('al subir, el aviso de que el bus llega se va', (tester) async {
    final a = await Arnes.montar(
      tester,
      prefijo: 'demo_aviso',
      demo: true,
      velocidad: 30,
    );
    await a.esperar(const Duration(seconds: 2));
    // Con trasbordo: en la segunda espera nada más tapa el aviso al subir.
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('demo-destino-punta-carretas')),
      find.byKey(const ValueKey('demo-destinos')),
      const Offset(-160, 0),
    );
    await a.esperar(const Duration(milliseconds: 300));
    await a.tocar('demo-destino-punta-carretas');
    await a.hasta(
      () =>
          a.fase is FaseOpciones &&
          (a.fase as FaseOpciones).estado == EstadoOpciones.listo,
    );
    await a.tocar('empezar-viaje');
    final aviso = find.byKey(const ValueKey('aviso-busLlegando'));
    // Esperando el segundo bus, avisa que llega (a 30x, segundos antes de
    // subir: el aviso dura más que eso).
    await a.hasta(
      () =>
          a.fase is FaseViaje &&
          (a.fase as FaseViaje).pasoActual == 3 &&
          aviso.evaluate().isNotEmpty,
      paso: const Duration(milliseconds: 100),
      razon: 'aviso de que el segundo bus llega',
    );
    await a.hastaPaso(4);
    await a.esperar(const Duration(seconds: 1));
    expect(aviso, findsNothing, reason: 'ya subió: el aviso quedó viejo');
    await a.cerrar();
  });

  // En inglés las cifras son más largas ("Arrives in 1 min" contra "Llega en
  // 1 min"): en una pantalla angosta la cifra no puede partirse en dos líneas,
  // porque con maxLines: 1 la segunda (el número) se pierde.
  testWidgets('en inglés y en pantalla angosta: la cifra se ve entera', (
    tester,
  ) async {
    final a = await Arnes.montar(
      tester,
      prefijo: 'demo_en_angosta',
      demo: true,
      idioma: Idioma.en,
      tam: const Size(360, 780),
    );
    await a.esperar(const Duration(seconds: 2));
    await a.tocar('demo-destino-plaza-independencia');
    await a.hasta(
      () =>
          a.fase is FaseOpciones &&
          (a.fase as FaseOpciones).estado == EstadoOpciones.listo,
    );
    await a.esperar(const Duration(seconds: 1));
    await a.tocar('empezar-viaje');
    await a.hastaPaso(1);
    await a.esperar(const Duration(seconds: 1));

    void entera(Finder texto) {
      expect(texto, findsWidgets);
      for (final e in texto.evaluate()) {
        final parrafo = e.renderObject! as RenderParagraph;
        expect(
          parrafo.didExceedMaxLines,
          isFalse,
          reason: '"${parrafo.text.toPlainText()}" no entra en una línea',
        );
      }
    }

    entera(find.textContaining('Arrives in'));
    await a.capturar('esperando');
    await a.hastaPaso(2);
    await a.esperar(const Duration(seconds: 2));
    entera(find.textContaining('to go'));
    await a.capturar('en_bus');
    await a.cerrar();
  });
}
