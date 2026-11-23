// La presentación web "por dentro": la app enchufada a una placa donde se ven
// las llamadas entre sus piezas. Lo que se dibuja son llamadas reales: este
// test hace un viaje y comprueba que pasan por cada costura.

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/contract/trazas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arnes.dart';

void main() {
  testWidgets('un viaje, visto por dentro', (tester) async {
    final a = await Arnes.montar(
      tester,
      prefijo: 'por_dentro',
      demo: true,
      marco: true,
      tam: const Size(1920, 1080),
    );
    await a.esperar(const Duration(seconds: 2));
    expect(find.text('LLAMADAS EN VIVO'), findsOneWidget);
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
  });
}
