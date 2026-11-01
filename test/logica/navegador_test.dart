import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/logic/geo/geo.dart';
import 'package:bondi_uy/logic/puertos.dart';
import 'package:bondi_uy/logic/viaje/navegador.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

/// Reproduce las muestras grabadas y devuelve la traza de pasos.
({List<int> pasos, bool completado, List<EstadoNavegacion> estados}) repetir(
  Navegador nav,
  List<MuestraUbicacion> muestras,
) {
  final pasos = <int>[nav.paso];
  final estados = <EstadoNavegacion>[];
  for (final m in muestras) {
    final r = nav.procesar(m);
    estados.add(r);
    if (r.paso != pasos.last) pasos.add(r.paso);
    if (r.completado) break;
  }
  return (pasos: pasos, completado: nav.completado, estados: estados);
}

void main() {
  final inicio = DateTime(2026, 8, 3, 18);

  group('Plan OTP grabado', () {
    test('D1 directo: caminar -> esperar -> bus -> caminar', () {
      final o = viajeDelFixture(0).opcion;
      expect(o.tramos.map((t) => t.runtimeType.toString()), [
        'TramoCaminar',
        'TramoEsperar',
        'TramoBus',
        'TramoCaminar',
      ]);
      final bus = o.tramos[2] as TramoBus;
      expect(bus.linea, 'D1');
      expect(bus.subida.id, '5296');
      expect(bus.bajada.id, '5124');
      expect(bus.paradasIntermedias, isNotEmpty);
      expect((o.tramos.first as TramoCaminar).haciaParada?.id, '5296');
      expect((o.tramos.last as TramoCaminar).esAlDestino, isTrue);
      expect(viajeDelFixture(0).shapePorTramo[bus.id], '9102');
    });

    test('526 -> 109: siete pasos con trasbordo caminando', () {
      final o = viajeDelFixture(9).opcion;
      expect(o.tramos.length, 7);
      expect(o.lineas, ['526', '109']);
      expect(o.transbordos, 1);
      expect((o.tramos[3] as TramoCaminar).haciaParada?.id, '4908');
    });
  });

  group('Navegación con el GPS grabado', () {
    for (final (indice, pasosEsperados) in [
      (0, [0, 1, 2, 3]),
      (9, [0, 1, 2, 3, 4, 5, 6]),
    ]) {
      test('opción $indice avanza de a un paso y termina', () {
        final nav = Navegador(viajeDelFixture(indice).opcion);
        final r = repetir(nav, muestrasDelFixture(indice, inicio));
        expect(r.pasos, pasosEsperados, reason: 'traza estricta +1');
        expect(r.completado, isTrue);
      });
    }

    test('la caminata informa metros restantes decrecientes y recorrido', () {
      final nav = Navegador(viajeDelFixture(0).opcion);
      final muestras = muestrasDelFixture(0, inicio);
      final primeros =
          [
            for (final m in muestras.take(20)) nav.procesar(m),
          ].where((e) => e.paso == 0).toList();
      expect(primeros, isNotEmpty);
      final metros = primeros.map((e) => e.progreso.metrosRestantes!).toList();
      expect(metros.first, greaterThan(250));
      expect(metros.last, lessThan(metros.first));
      final ruta = primeros.last.progreso.recorridoRestante!;
      expect(ruta.length, greaterThanOrEqualTo(2));
      expect(primeros.last.progreso.fraccion, greaterThan(0));
    });

    test('arriba del bus cuenta las paradas que faltan hasta 0', () {
      final nav = Navegador(viajeDelFixture(0).opcion);
      final enBus = <int>[];
      for (final m in muestrasDelFixture(0, inicio)) {
        final r = nav.procesar(m);
        if (r.paso == 2 && r.progreso.paradasRestantes != null) {
          enBus.add(r.progreso.paradasRestantes!);
        }
      }
      expect(enBus, isNotEmpty);
      expect(enBus.first, greaterThan(5));
      expect(enBus.last, 0);
      for (var i = 1; i < enBus.length; i++) {
        expect(enBus[i], lessThanOrEqualTo(enBus[i - 1]), reason: 'nunca sube');
      }
    });

    test('esperar sin moverse no dispara la subida', () {
      final o = viajeDelFixture(0).opcion;
      final nav = Navegador(o);
      final parada = (o.tramos[1] as TramoEsperar).parada.coordenada;
      nav.confirmarPaso(); // llegó a la parada
      for (var i = 0; i < 30; i++) {
        final r = nav.procesar(
          MuestraUbicacion(
            coordenada: parada,
            momento: inicio.add(Duration(seconds: 5 * i)),
            velocidad: 0,
          ),
        );
        expect(r.paso, 1);
      }
    });

    test('respaldo manual avanza y al final completa', () {
      final o = viajeDelFixture(0).opcion;
      final nav = Navegador(o);
      for (var i = 0; i < o.tramos.length - 1; i++) {
        expect(nav.confirmarPaso().paso, i + 1);
      }
      expect(nav.confirmarPaso().completado, isTrue);
    });

    test('si el GPS se perdió la subida, salta al bus cuando ya viaja', () {
      final o = viajeDelFixture(0).opcion;
      final nav = Navegador(o);
      final muestras = muestrasDelFixture(0, inicio);
      // Se descartan las muestras de la espera: el usuario "aparece" viajando.
      final samples = (opcionDelFixture(0)['replay']['userSamples'] as List);
      final sinEspera = [
        for (var i = 0; i < muestras.length; i++)
          if (samples[i]['phase'] != 'wait') muestras[i],
      ];
      final r = repetir(nav, sinEspera);
      expect(r.pasos.first, 0);
      expect(r.pasos, containsAllInOrder([0, 2, 3]));
      expect(r.completado, isTrue);
    });

    test('si se bajó entre dos lecturas, sigue en la caminata final', () {
      // Lecturas espaciadas (GPS cortado, app suspendida, demo acelerada):
      // ninguna cae cerca de la parada de bajada. Antes de esto el
      // navegador quedaba en "Viajá en el D1" con el usuario ya caminando.
      final o = viajeDelFixture(0).opcion;
      final bajada = (o.tramos[2] as TramoBus).bajada.coordenada;
      final nav = Navegador(o);
      final sinBajada = [
        for (final m in muestrasDelFixture(0, inicio))
          if (distancia(m.coordenada, bajada) > 150) m,
      ];
      final r = repetir(nav, sinBajada);
      expect(r.pasos, containsAllInOrder([2, 3]));
      expect(r.completado, isTrue);
    });
  });
}
