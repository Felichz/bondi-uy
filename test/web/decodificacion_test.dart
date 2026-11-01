// Decodificación de datos binarios y codificados con valores negativos.
//
// Corre en la VM y también en el navegador:
//   flutter test --platform chrome test/web
// En web los operadores de bits devuelven enteros sin signo de 32 bits: un
// zigzag o una polilínea decodificados con `^`/`~` dan números enormes en vez
// de negativos (el mapa se veía con rayas que cruzaban la pantalla). En la VM
// eso no pasa, por eso este test tiene que correr también en web.

import 'dart:typed_data';

import 'package:bondi_uy/logic/geo/geo.dart';
import 'package:bondi_uy/ui/mapa/teselas/mvt.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> _varint(int v) {
  final res = <int>[];
  while (v >= 0x80) {
    res.add((v % 128) | 0x80);
    v ~/= 128;
  }
  res.add(v);
  return res;
}

List<int> _campo(int numero, List<int> contenido) => [
  ..._varint(numero * 8 + 2),
  ..._varint(contenido.length),
  ...contenido,
];

int _zigzag(int v) => v >= 0 ? v * 2 : -v * 2 - 1;

void main() {
  test('MVT: coordenadas relativas negativas', () {
    // Una línea de (10, 10) a (5, 3): el segundo punto es un delta negativo.
    final geometria = <int>[
      ..._varint(1 + 1 * 8), // MoveTo x1
      ..._varint(_zigzag(10)),
      ..._varint(_zigzag(10)),
      ..._varint(2 + 1 * 8), // LineTo x1
      ..._varint(_zigzag(-5)),
      ..._varint(_zigzag(-7)),
    ];
    final elemento = [
      ..._varint(3 * 8), ..._varint(2), // type = LINESTRING
      ..._campo(4, geometria),
    ];
    final capa = [
      ..._varint(15 * 8), ..._varint(2), // version
      ..._campo(1, 'water'.codeUnits),
      ..._campo(2, elemento),
      ..._varint(5 * 8), ..._varint(4096), // extent
    ];
    final tesela = decodificarMvt(Uint8List.fromList(_campo(3, capa)));
    final linea = tesela['water']!.elementos.single.geometria.single;
    expect([for (final p in linea) (p.x, p.y)], [(10, 10), (5, 3)]);
  });

  test('polilínea de OTP con latitudes y longitudes negativas', () {
    // Ejemplo de la documentación del algoritmo de Google.
    final pts = decodificarPolilinea('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(pts.length, 3);
    expect(pts[0].lat, closeTo(38.5, 1e-6));
    expect(pts[0].lng, closeTo(-120.2, 1e-6));
    expect(pts[2].lat, closeTo(43.252, 1e-6));
    expect(pts[2].lng, closeTo(-126.453, 1e-6));
  });
}
