// El mapa y el panel durante el viaje, como los vive el usuario:
// - la cámara acompaña al usuario (no se queda quieta mientras camina o viaja),
// - las paradas relevantes llevan su globo (dónde subir, la próxima, dónde
//   bajarse, el destino),
// - si el usuario mueve el mapa, la cámara vuelve sola al rato,
// - cada avance se confirma y el itinerario completo está a un toque.

import 'dart:math' as math;

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/ui/comunes.dart';
import 'package:bondi_uy/ui/estado_ui.dart';
import 'package:bondi_uy/ui/formatos.dart';
import 'package:bondi_uy/ui/mapa/pintor_escena.dart';
import 'package:bondi_uy/ui/mapa/proyeccion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arnes.dart';

PintorEscena get _mapa => PintorEscena.ultimo!;

void main() {
  testWidgets('la cámara sigue al usuario y las paradas llevan su globo', (
    tester,
  ) async {
    final a = await Arnes.montar(tester, prefijo: 'viaje_mapa');
    await a.buscarPlaza();
    // Vista previa: la parada de subida y la hora de llegada, rotuladas.
    expect(_mapa.globosPuestos, contains('Subís al D1'));
    expect(_mapa.globosPuestos.any((g) => g.startsWith('Llegás ')), isTrue);

    await a.tocar('empezar-viaje');
    final opcion = (a.fase as FaseViaje).opcion;
    final linea = opcion.lineas.first;

    // Caminando: la cámara acompaña al usuario mientras avanza, con la
    // parada siempre a la vista (el bus, solo si entra sin alejarse de más).
    for (var i = 0; i < 6; i++) {
      await a.esperar(const Duration(seconds: 1));
      final f = a.fase as FaseViaje;
      if (f.pasoActual != 0) break;
      final t = f.tramoActual as TramoCaminar;
      expect(_aLaVista(a, _mapa.usuarioEnPantalla!), isTrue, reason: 'vos');
      expect(_aLaVista(a, _enPantalla(t.fin)), isTrue, reason: 'la parada');
      // El bus que viene, si quedó fuera de la vista, se señala en el borde.
      final bus = _mapa.busEnPantalla;
      if (bus != null && !_aLaVista(a, bus)) {
        expect(
          _mapa.busEnBorde,
          startsWith(linea),
          reason: 'indicador del bus',
        );
      }
    }
    expect(_mapa.globosPuestos, contains('Subís al $linea'));
    await a.capturar('caminando');

    // Esperando: la parada, el bus que viene y vos.
    await a.hastaPaso(1);
    await a.esperar(const Duration(seconds: 2));
    final espera = a.fase as FaseViaje;
    if (espera.pasoActual == 1 && espera.busEsperado?.posicion != null) {
      final t = espera.tramoActual as TramoEsperar;
      expect(_aLaVista(a, _enPantalla(t.parada.coordenada)), isTrue);
      expect(_aLaVista(a, _mapa.usuarioEnPantalla!), isTrue);
      expect(_aLaVista(a, _mapa.busEnPantalla!), isTrue, reason: 'el bus');
      await a.capturar('esperando');
    }

    // Arriba del bus: la próxima parada con su globo y la bajada a la vista
    // cuando falta poco.
    await a.hastaPaso(2);
    await a.esperar(const Duration(seconds: 3));
    expect(find.text('Subiste al $linea. ¡Buen viaje!'), findsOneWidget);
    expect(find.byKey(const ValueKey('viaje-tira-paradas')), findsOneWidget);
    expect(find.byKey(const ValueKey('viaje-proxima')), findsOneWidget);
    final proxima = (a.fase as FaseViaje).progreso.proximaParada!;
    expect(
      _mapa.globosPuestos.any(
        (g) => nombreParada(proxima.nombre).startsWith(g.replaceAll('…', '')),
      ),
      isTrue,
      reason: 'globo de la próxima parada: ${_mapa.globosPuestos}',
    );
    await a.capturar('en_bus');
    await a.hasta(
      () => (a.fase as FaseViaje).progreso.paradasRestantes == 0,
      razon: 'última parada',
    );
    await a.esperar(const Duration(seconds: 2));
    expect(_mapa.globosPuestos, contains('¡Bajate en esta!'));
    await a.capturar('bajate');

    // Caminando al destino: el destino rotulado.
    await a.hastaPaso(3);
    await a.esperar(const Duration(seconds: 2));
    expect(_mapa.globosPuestos, contains('Plaza Independencia'));
    await a.cerrar();
  });

  testWidgets('la subida al bus es un solo movimiento suave', (tester) async {
    final a = await Arnes.montar(tester, prefijo: 'subida', velocidad: 6);
    await a.buscarPlaza();
    await a.tocar('empezar-viaje');
    await a.hastaPaso(1);
    final parada =
        ((a.fase as FaseViaje).tramoActual as TramoEsperar).parada.coordenada;
    await a.hasta(
      () =>
          (a.fase as FaseViaje).pasoActual > 1 ||
          ((a.fase as FaseViaje).busEsperado?.minutos ?? 99) <= 1,
      razon: 'el bus está por llegar',
    );
    // Cuadro a cuadro (60 fps) desde que el bus llega hasta ya arriba.
    const cuadro = Duration(milliseconds: 16);
    Offset? antes;
    double? pasoAntes;
    var maximo = 0.0, tiron = 0.0;
    var despues = 0;
    var arribaAntesDeConfirmar = false;
    while (despues < 120) {
      await a.esperar(cuadro, paso: cuadro);
      final f = a.fase as FaseViaje;
      if (f.pasoActual == 1) {
        // Tu bus está en la parada: ni "sin datos" ni el bus siguiente.
        expect(find.byKey(const ValueKey('viaje-sin-datos')), findsNothing);
        expect(f.busEsperado?.minutos ?? 0, lessThanOrEqualTo(1));
        if (_mapa.usuarioEnBus) arribaAntesDeConfirmar = true;
      }
      if (f.pasoActual >= 2) despues++;
      final p = _enPantalla(parada);
      if (antes != null) {
        final d = (p - antes).distance;
        maximo = math.max(maximo, d);
        if (pasoAntes != null) tiron = math.max(tiron, (d - pasoAntes).abs());
        pasoAntes = d;
      }
      antes = p;
    }
    expect(
      arribaAntesDeConfirmar,
      isTrue,
      reason: 'al irse con el bus ya se lo muestra arriba, sin esperar 60 m',
    );
    expect(maximo, lessThan(12), reason: 'el mapa no pega saltos');
    expect(tiron, lessThan(6), reason: 'sin tirones entre cuadros');
    await a.cerrar();
  });

  testWidgets('si movés el mapa en viaje, la cámara vuelve sola', (
    tester,
  ) async {
    final a = await Arnes.montar(tester, prefijo: 'reanudar');
    await a.buscarPlaza();
    await a.tocar('empezar-viaje');
    await a.esperar(const Duration(seconds: 2));
    final ctl = a.container.read(controladorMapaProvider);
    expect(ctl.libre, isFalse);

    await tester.drag(
      find.byKey(const ValueKey('mapa')),
      const Offset(0, -250),
    );
    await a.esperar(const Duration(milliseconds: 600));
    expect(ctl.libre, isTrue);
    expect(find.byKey(const ValueKey('boton-recentrar')), findsOneWidget);
    await a.capturar('mapa_movido');

    await a.esperar(const Duration(seconds: 13));
    expect(ctl.libre, isFalse, reason: 'volvió a seguir al usuario');
    await a.cerrar();
  });

  testWidgets('el itinerario muestra todos los pasos y cuál es el actual', (
    tester,
  ) async {
    final a = await Arnes.montar(tester, prefijo: 'itinerario');
    await a.buscarPlaza();
    await a.tocar('empezar-viaje');
    await a.hastaPaso(1);
    await a.esperar(const Duration(seconds: 1));
    await a.tocar('viaje-itinerario');
    expect(find.byKey(const ValueKey('itinerario')), findsOneWidget);
    final linea = (a.fase as FaseViaje).opcion.lineas.first;
    expect(find.text('Esperá el $linea'), findsWidgets);
    expect(find.text('Viajá en el $linea'), findsOneWidget);
    expect(find.text('AHORA'), findsOneWidget);
    await a.capturar('abierto');
    await a.tocar('itinerario-cerrar');
    expect(find.byKey(const ValueKey('itinerario')), findsNothing);
    await a.cerrar();
  });

  test('capitalizar respeta siglas y conectores', () {
    expect(capitalizar('PLAZA INDEPENDENCIA'), 'Plaza Independencia');
    expect(capitalizar('HACIA UAM'), 'Hacia UAM');
    expect(capitalizar('PARQUE DE LOS ALIADOS'), 'Parque de los Aliados');
    expect(capitalizar('AV ITALIA'), 'Av Italia');
    expect(capitalizar('POCITOS'), 'Pocitos');
  });
}

/// Dónde cae [c] en la pantalla según la cámara del último cuadro.
Offset _enPantalla(Coordenada c) =>
    _mapa.camara!.aLienzo(mercator(c), const Offset(206, 446));

/// Dentro del mapa visible: debajo de la tarjeta del paso y encima de la
/// barra inferior.
bool _aLaVista(Arnes a, Offset p) {
  final arriba = 24 + 8 + a.container.read(altoTarjetaViajeProvider);
  return p.dx > 0 && p.dx < 412 && p.dy > arriba && p.dy < 892 - 100;
}
