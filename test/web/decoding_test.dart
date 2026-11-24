// Decoding of binary data and encoded data with negative values.
//
// Runs on the VM and also in the browser:
//   flutter test --platform chrome test/web
// On web, bitwise operators return unsigned 32-bit integers: a zigzag or a
// polyline decoded with `^`/`~` gives huge numbers instead of negatives (the
// map showed stripes crossing the screen). On the VM that does not happen,
// which is why this test also has to run on web.

import 'dart:typed_data';

import 'package:bondi_uy/logic/geo/geo.dart';
import 'package:bondi_uy/ui/map/tiles/mvt.dart';
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

List<int> _field(int number, List<int> content) => [
  ..._varint(number * 8 + 2),
  ..._varint(content.length),
  ...content,
];

int _zigzag(int v) => v >= 0 ? v * 2 : -v * 2 - 1;

void main() {
  test('MVT: negative relative coordinates', () {
    // A line from (10, 10) to (5, 3): the second point is a negative delta.
    final geometry = <int>[
      ..._varint(1 + 1 * 8), // MoveTo x1
      ..._varint(_zigzag(10)),
      ..._varint(_zigzag(10)),
      ..._varint(2 + 1 * 8), // LineTo x1
      ..._varint(_zigzag(-5)),
      ..._varint(_zigzag(-7)),
    ];
    final element = [
      ..._varint(3 * 8), ..._varint(2), // type = LINESTRING
      ..._field(4, geometry),
    ];
    final layer = [
      ..._varint(15 * 8), ..._varint(2), // version
      ..._field(1, 'water'.codeUnits),
      ..._field(2, element),
      ..._varint(5 * 8), ..._varint(4096), // extent
    ];
    final tile = decodeMvt(Uint8List.fromList(_field(3, layer)));
    final line = tile['water']!.elements.single.geometry.single;
    expect([for (final p in line) (p.x, p.y)], [(10, 10), (5, 3)]);
  });

  test('OTP polyline with negative latitudes and longitudes', () {
    // Example from Google's algorithm documentation.
    final pts = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(pts.length, 3);
    expect(pts[0].lat, closeTo(38.5, 1e-6));
    expect(pts[0].lng, closeTo(-120.2, 1e-6));
    expect(pts[2].lat, closeTo(43.252, 1e-6));
    expect(pts[2].lng, closeTo(-126.453, 1e-6));
  });
}
