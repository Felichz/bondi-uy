import 'package:bondi_uy/contract/modelo.dart';
import 'package:bondi_uy/logic/geo/geo.dart';
import 'package:bondi_uy/logic/puertos.dart';
import 'package:bondi_uy/logic/viaje/seguidor_bus.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

LlegadaEnParada llegadaDeSondeo(Map<String, dynamic> s) => LlegadaEnParada(
  LlegadaBus(
    linea: s['line'] as String,
    minutos: s['etaMinutes'] as int,
    enVivo: s['realtime'] as bool,
    posicion: Coordenada(
      (s['lat'] as num).toDouble(),
      (s['lng'] as num).toDouble(),
    ),
  ),
  vehiculo: s['vehicleId'] as String?,
);

void main() {
  final viaje = viajeDelFixture(0);
  final bus = viaje.opcion.tramos[2] as TramoBus;
  final shape = shapeDelAsset(viaje.shapePorTramo[bus.id]!)!;
  final recorrido =
      RecorridoLinea.crear(
        shape,
        bus.subida.coordenada,
        bajada: bus.bajada.coordenada,
      )!;

  test('cada sondeo real de D1 produce una aproximación por la calle', () {
    final seguidor = SeguidorBus(linea: 'D1', recorrido: recorrido);
    for (final s in sondeosDelFixture(0).where((s) => s['found'] == true)) {
      final b = seguidor.elegir([llegadaDeSondeo(s)])!;
      expect(b.enVivo, isTrue);
      expect(b.minutos, s['etaMinutes']);
      final ap = b.aproximacion!;
      expect(ap.first, b.posicion);
      expect(distancia(ap.last, bus.subida.coordenada), lessThan(40));
      // Nunca una cuerda: ningún salto entre puntos consecutivos > 500 m.
      for (var i = 1; i < ap.length; i++) {
        expect(distancia(ap[i - 1], ap[i]), lessThan(500));
      }
      // Recorre la calle: bastante más largo que la línea recta.
      expect(largo(ap), greaterThan(distancia(ap.first, ap.last) * 0.99));
      expect(b.metrosHastaParada, greaterThan(0));
    }
  });

  test('sigue al mismo vehículo entre sondeos', () {
    final seguidor = SeguidorBus(linea: 'D1', recorrido: recorrido);
    final s = sondeosDelFixture(0).first;
    final elegido = seguidor.elegir([llegadaDeSondeo(s)]);
    expect(elegido, isNotNull);
    // Aparece otro D1 más cerca en minutos pero se sigue al mismo.
    final otro = LlegadaEnParada(
      LlegadaBus(
        linea: 'D1',
        minutos: 1,
        enVivo: true,
        posicion: shape[shape.length ~/ 3],
      ),
      vehiculo: 'otro',
    );
    final b = seguidor.elegir([otro, llegadaDeSondeo(s)])!;
    expect(b.minutos, s['etaMinutes']);
  });

  test('un bus que ya pasó la parada no se muestra viniendo', () {
    final seguidor = SeguidorBus(linea: 'D1', recorrido: recorrido);
    final despues = Polilinea(shape).puntoEn(recorrido.recorridoParada + 800);
    final b = seguidor.elegir([
      LlegadaEnParada(
        LlegadaBus(linea: 'D1', minutos: 3, enVivo: true, posicion: despues),
      ),
    ]);
    expect(b, isNull);
  });

  test('otra línea en la misma parada se ignora', () {
    final seguidor = SeguidorBus(linea: 'D1', recorrido: recorrido);
    expect(
      seguidor.elegir([
        const LlegadaEnParada(
          LlegadaBus(linea: '104', minutos: 2, enVivo: true),
        ),
      ]),
      isNull,
    );
  });

  test('sin shape: bus con posición pero sin aproximación inventada', () {
    final seguidor = SeguidorBus(linea: 'D1');
    final s = sondeosDelFixture(0).first;
    final b = seguidor.elegir([llegadaDeSondeo(s)])!;
    expect(b.posicion, isNotNull);
    expect(b.aproximacion, isNull);
  });

  test('el bus que llegó a la parada se informa llegado, no el siguiente', () {
    final seguidor = SeguidorBus(linea: 'D1', recorrido: recorrido);
    LlegadaEnParada en(double metrosAntes, String vehiculo, int minutos) =>
        LlegadaEnParada(
          LlegadaBus(
            linea: 'D1',
            minutos: minutos,
            enVivo: true,
            posicion: Polilinea(
              shape,
            ).puntoEn(recorrido.recorridoParada - metrosAntes),
          ),
          vehiculo: vehiculo,
        );
    // El nuestro está llegando; el siguiente, a 2 km.
    final llegando = seguidor.elegir([en(80, 'a', 0), en(2000, 'b', 4)])!;
    expect(llegando.metrosHastaParada, lessThan(150));
    // Pasó la parada: la fuente ya solo informa el siguiente.
    for (var i = 0; i < SeguidorBus.sondeosLlegado; i++) {
      final b = seguidor.elegir([en(1900, 'b', 4)])!;
      expect(b.minutos, 0, reason: 'sigue "llegó" en el sondeo $i');
      expect(b.metrosHastaParada, 0);
    }
    // Si el usuario no subió, recién ahora se anuncia el siguiente.
    final siguiente = seguidor.elegir([en(1800, 'b', 4)])!;
    expect(siguiente.minutos, 4);
  });
}
