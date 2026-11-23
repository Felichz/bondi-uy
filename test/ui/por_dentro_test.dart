// La presentación web "por dentro": la app enchufada a una placa donde se ven
// las llamadas entre sus piezas. Lo que se dibuja son llamadas reales: este
// test hace un viaje y comprueba que pasan por cada costura.

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/contract/trazas.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bondi_uy/ui/web/marco_web.dart';
import 'package:bondi_uy/ui/web/por_dentro.dart';

import 'arnes.dart';

void main() {
  test('las cajas de la placa no se pisan en ninguna ventana posible', () {
    for (var alto = altoMinimoPorDentro; alto <= 1440; alto += 40) {
      final tel = tamTelefonoPorDentro(alto);
      final minimo = anchoMinimoPorDentro(tel.width);
      for (var ancho = minimo; ancho <= 2560; ancho += 64) {
        final tam = Size(ancho, alto);
        final telefono = telefonoPorDentro(tam, tel);
        final cajas = {...cajasDeLaPlaca(tam, telefono), 'telefono': telefono};
        final ventana = Offset.zero & tam;
        final nombres = cajas.keys.toList();
        for (var i = 0; i < nombres.length; i++) {
          final r = cajas[nombres[i]]!;
          expect(
            ventana.deflate(8).contains(r.topLeft) &&
                ventana.deflate(8).contains(r.bottomRight),
            isTrue,
            reason: '${nombres[i]} se sale de la ventana en $tam',
          );
          for (var j = i + 1; j < nombres.length; j++) {
            final o = cajas[nombres[j]]!;
            expect(
              r.inflate(8).overlaps(o),
              isFalse,
              reason: '${nombres[i]} y ${nombres[j]} se pisan en $tam',
            );
          }
        }
      }
    }
  });

  // Un escritorio grande, y uno de 1920 con el navegador al 125 %.
  for (final tam in const [Size(1920, 1080), Size(1536, 745)]) {
    testWidgets(
      'un viaje, visto por dentro (${tam.width.round()}x${tam.height.round()})',
      (tester) async {
        final a = await Arnes.montar(
          tester,
          prefijo: 'por_dentro_${tam.width.round()}',
          demo: true,
          marco: true,
          tam: tam,
        );
        await a.esperar(const Duration(seconds: 2));
        expect(find.text('Por dentro'), findsWidgets);
        await a.capturar('inicio');

        await a.tocar('demo-destino-plaza-independencia');
        await a.hasta(
          () =>
              a.fase is FaseOpciones &&
              (a.fase as FaseOpciones).estado == EstadoOpciones.listo,
        );
        await a.esperar(const Duration(milliseconds: 1200));
        await a.capturar('opciones');
        await a.tocar('empezar-viaje');
        await a.esperar(const Duration(milliseconds: 1500));
        await a.capturar('caminando');
        await a.hastaPaso(1);
        await a.esperar(const Duration(milliseconds: 800));
        await a.capturar('esperando');

        // Con el mouse sobre una pieza, su tarjeta dice dónde está el código.
        final telefono = telefonoPorDentro(
          tam,
          tamTelefonoPorDentro(tam.height),
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        for (final (pieza, archivo) in const [
          ('seguidor', 'lib/logic/viaje/seguidor_bus.dart'),
          ('contrato', 'lib/contract/'),
          ('lugares', 'lib/logic/servicios/lugares.dart'),
        ]) {
          await mouse.moveTo(cajasDeLaPlaca(tam, telefono)[pieza]!.center);
          await a.esperar(const Duration(milliseconds: 300));
          expect(find.text(archivo), findsOneWidget, reason: pieza);
          await a.capturar('tarjeta_$pieza');
        }
        await mouse.moveTo(Offset(tam.width - 4, 4));
        await a.esperar(const Duration(milliseconds: 100));
        expect(find.byKey(const ValueKey('tarjeta-pieza')), findsNothing);
        await mouse.removePointer();
        await a.hastaPaso(2);
        await a.esperar(const Duration(milliseconds: 1500));
        await a.capturar('en_bus');

        // Cada costura de la app, con llamadas reales.
        for (final par in [
          (Pieza.interfaz, Pieza.controlador), // acciones de la UI
          (Pieza.controlador, Pieza.planificador),
          (Pieza.controlador, Pieza.recomendador),
          (Pieza.controlador, Pieza.llegadas),
          (Pieza.controlador, Pieza.seguidor),
          (Pieza.ubicacion, Pieza.controlador),
          (Pieza.controlador, Pieza.navegador),
        ]) {
          expect(
            a.trazas!.llamadas,
            contains(par),
            reason: 'llamadas ${par.$1} -> ${par.$2}',
          );
        }
        await a.cerrar();
      },
    );
  }
}
