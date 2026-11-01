// El marcador se mueve de forma continua aunque las lecturas lleguen cada
// varios segundos: sigue avanzando entre lecturas, a la velocidad estimada y
// por la calle (dobla en la esquina, no corta en diagonal).

import 'package:bondi_uy/ui/mapa/movimiento.dart';
import 'package:flutter_test/flutter_test.dart';

/// Metros -> mercator.
double m(double metros) => metros / metrosPorUnidad;

void main() {
  // Una calle en L: 200 m al este y 200 m al sur.
  final origen = const Offset(0.35, 0.60);
  final esquina = origen + Offset(m(200), 0);
  final fin = esquina + Offset(0, m(200));
  final camino = [origen, esquina, fin];

  /// Punto a [d] metros por la calle.
  Offset porLaCalle(double d) =>
      d <= 200 ? origen + Offset(m(d), 0) : esquina + Offset(0, m(d - 200));

  double lateral(Offset p) {
    // Distancia (m) al camino en L: la menor a cada uno de sus dos tramos.
    final x = (p.dx - origen.dx) / m(1), y = (p.dy - origen.dy) / m(1);
    final aEste = Offset(x - x.clamp(0, 200), y).distance;
    final aSur = Offset(x - 200, y - y.clamp(0, 200)).distance;
    return aEste < aSur ? aEste : aSur;
  }

  test('con lecturas cada 5 s avanza sin frenar y dobla por la calle', () {
    const v = 1.4; // m/s, caminando
    const cada = 5.0;
    final mov = MovimientoPredicho(porLaCalle(0), 0);
    Offset? anterior;
    final pasos = <double>[];
    for (var cuadro = 0; cuadro <= 2500; cuadro++) {
      final t = cuadro / 10;
      // Llega una lectura cada 5 s (la posición real en ese instante).
      if (cuadro > 0 && cuadro % (cada * 10).round() == 0) {
        mov.lectura(porLaCalle(v * t), t, camino: camino);
      }
      mov.avanzar(t);
      final p = mov.posicion;
      if (anterior != null && t > 12) pasos.add((p - anterior).distance / m(1));
      anterior = p;
      if (t > 12) {
        expect(
          lateral(p),
          lessThan(1.5),
          reason: 'a los ${t.toStringAsFixed(1)} s va por la calle',
        );
      }
    }
    // Pasado el arranque, cada cuadro (0,1 s) avanza ~0,14 m: nunca se
    // queda quieto esperando la próxima lectura ni pega saltos.
    final minimo = pasos.reduce((a, b) => a < b ? a : b);
    final maximo = pasos.reduce((a, b) => a > b ? a : b);
    expect(minimo, greaterThan(0.05), reason: 'no se detiene entre lecturas');
    expect(maximo, lessThan(0.5), reason: 'no salta');
    // Mira hacia donde va: al final, hacia el sur.
    expect(mov.rumbo, closeTo(180, 5));
  });

  test('quieto no se mueve con el ruido del GPS', () {
    final mov = MovimientoPredicho(origen, 0);
    for (var i = 1; i <= 10; i++) {
      mov.lectura(origen + Offset(m(0.5) * (i.isEven ? 1 : -1), 0), i * 5.0);
    }
    mov.avanzar(60);
    expect((mov.posicion - origen).distance / m(1), lessThan(1));
  });

  test('un salto grande se muestra directo', () {
    final mov = MovimientoPredicho(origen, 0);
    final lejos = origen + Offset(m(2000), 0);
    mov.lectura(lejos, 5, reubicado: true);
    expect(mov.posicion, lejos);
  });

  test('el bus que viene no se pasa de la parada por predicción', () {
    // Viene por la calle en L hacia una parada a 150 m, a 8 m/s.
    final parada = porLaCalle(150);
    final mov = MovimientoPredicho(porLaCalle(0), 0);
    var d = 0.0;
    for (var t = 5.0; t <= 15; t += 5) {
      d = 8 * t;
      mov.lectura(porLaCalle(d), t, camino: camino, limite: parada);
    }
    // Sin más lecturas, la predicción avanza... hasta la parada, no más.
    mov.avanzar(40);
    expect((mov.posicion - parada).distance / m(1), lessThan(1.5));
    // Una lectura real más allá sí lo lleva del otro lado.
    mov.lectura(porLaCalle(190), 20, camino: camino, limite: parada);
    mov.avanzar(21);
    expect(
      (mov.posicion - porLaCalle(190)).distance / m(1),
      lessThan(20),
      reason: 'sigue al GPS real',
    );
  });

  test('sin camino, también frena en la parada', () {
    final parada = origen + Offset(m(100), 0);
    final mov = MovimientoPredicho(origen, 0);
    for (var t = 5.0; t <= 10; t += 5) {
      mov.lectura(origen + Offset(m(7 * t), 0), t, limite: parada);
    }
    mov.avanzar(60);
    expect(mov.posicion.dx, lessThanOrEqualTo(parada.dx + m(0.5)));
    expect((mov.posicion - parada).distance / m(1), lessThan(1.5));
  });
}
