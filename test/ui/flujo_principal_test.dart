// Flujo principal completo, como lo vive el usuario:
// buscar destino -> opciones (recomendada) -> empezar viaje -> caminar ->
// esperar el bus (en vivo) -> viajar -> caminar -> ¡Llegaste! -> inicio.
//
// Corre headless con el mapa pixel real, la lógica real, el plan OTP grabado
// (Saldanha da Gama 3941 -> Plaza Independencia) y el mundo simulado.
// Deja capturas en build/capturas/.

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/ui/mapa/pintor_escena.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arnes.dart';

void main() {
  for (final (prefijo, sinAnimaciones, oscuro) in [
    ('recomendado', false, false),
    ('oscuro', false, true),
    ('sin_animaciones', true, false),
  ]) {
    testWidgets('viaje recomendado de punta a punta ($prefijo)', (
      tester,
    ) async {
      final a = await Arnes.montar(
        tester,
        prefijo: prefijo,
        sinAnimaciones: sinAnimaciones,
        oscuro: oscuro,
      );

      // Inicio: buscador y mapa.
      expect(find.text('¿A dónde vas?'), findsOneWidget);
      await a.esperar(const Duration(seconds: 2));
      await a.capturar('inicio');

      // Buscar destino.
      await tester.tap(find.byKey(const ValueKey('buscar-destino')));
      await a.esperar(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('campo-destino')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('campo-destino')),
        'plaza',
      );
      await a.esperar(const Duration(milliseconds: 600));
      expect(
        find.byKey(const ValueKey('sugerencia-plaza-independencia')),
        findsOneWidget,
      );
      await a.capturar('sugerencias');
      await tester.tap(
        find.byKey(const ValueKey('sugerencia-plaza-independencia')),
      );
      await a.esperar(const Duration(milliseconds: 300));

      // Opciones: exactamente una recomendada, enfocada.
      await a.hasta(
        () => find.byKey(const ValueKey('empezar-viaje')).evaluate().isNotEmpty,
        razon: 'aparecen opciones',
      );
      expect(find.byKey(const ValueKey('sello-recomendado')), findsOneWidget);
      final fase = a.controlador.state.fase as FaseOpciones;
      expect(fase.opciones.where((o) => o.recomendada).length, 1);
      expect(fase.opciones.first.recomendada, isTrue);
      await a.esperar(const Duration(seconds: 2));
      // La vista previa ya muestra el bus en vivo de la opción enfocada.
      await a.hasta(
        () => (a.controlador.state.fase as FaseOpciones).busesEnVivo.isNotEmpty,
        razon: 'bus en vivo en vista previa',
      );
      await a.esperar(const Duration(seconds: 1));
      await a.capturar('opciones');

      // Deslizar a otra opción y volver.
      await tester.drag(
        find.byKey(const ValueKey('opciones-carrusel')),
        const Offset(-300, 0),
      );
      await a.esperar(const Duration(milliseconds: 800));
      await a.capturar('otra_opcion');
      await tester.drag(
        find.byKey(const ValueKey('opciones-carrusel')),
        const Offset(300, 0),
      );
      await a.esperar(const Duration(milliseconds: 800));

      // Empezar viaje.
      await tester.tap(find.byKey(const ValueKey('empezar-viaje')));
      await a.esperar(const Duration(milliseconds: 600));
      final viaje = a.controlador.state.fase as FaseViaje;
      expect(find.text('Paso 1 de ${viaje.totalPasos}'), findsOneWidget);
      expect(find.text('Caminá hasta la parada'), findsOneWidget);
      await a.esperar(const Duration(seconds: 3));
      // El punto del usuario muestra hacia dónde camina, también con las
      // animaciones del sistema desactivadas (antes se perdía el rumbo).
      expect(PintorEscena.ultimo!.rumboUsuario, isNotNull);
      await a.capturar('caminando');

      // El viaje avanza solo, paso a paso, sin saltos.
      final pasos = <int>[0];
      final capturados = <String>{};
      await a
          .hasta(
            () {
              final f = a.controlador.state.fase;
              if (f is FaseViaje) {
                if (f.pasoActual != pasos.last) pasos.add(f.pasoActual);
                return f.estado == EstadoViaje.completado;
              }
              return false;
            },
            maximo: const Duration(minutes: 8),
            paso: const Duration(milliseconds: 500),
            razon: 'el viaje se completa',
          )
          .then((_) {});
      expect(
        pasos,
        List.generate(viaje.totalPasos, (i) => i),
        reason: 'avance estricto +1',
      );
      capturados.add('fin');
      await a.esperar(const Duration(seconds: 1));
      expect(find.text('¡Llegaste!'), findsOneWidget);
      expect(find.text('Plaza Independencia'), findsOneWidget);
      await a.capturar('llegada');

      await tester.tap(find.byKey(const ValueKey('viaje-listo')));
      await a.esperar(const Duration(milliseconds: 600));
      expect(a.controlador.state.fase, isA<FaseExplorar>());
      expect(find.text('¿A dónde vas?'), findsOneWidget);
      await a.capturar('fin');
      await a.cerrar();
    });
  }
}
