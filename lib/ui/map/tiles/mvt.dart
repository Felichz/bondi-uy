// Minimal decoder for Mapbox Vector Tiles (MVT 2.x).
//
// Only what is needed for drawing: layers, geometry type, properties and
// geometries in tile coordinates (0..extent).

import 'dart:typed_data';

enum GeometryType { unknown, punto, line, polygon }

class TilePoint {
  final int x;
  final int y;
  const TilePoint(this.x, this.y);
}

class ElementoMvt {
  final GeometryType type;
  final Map<String, Object?> properties;

  /// Point: one list per point. Line: one list per line.
  /// Polygon: one list per ring (exterior clockwise, holes counterclockwise).
  final List<List<TilePoint>> geometry;

  const ElementoMvt(this.type, this.properties, this.geometry);

  String? get classValue => properties['class'] as String?;
  String? get name =>
      (properties['name:es'] ?? properties['name'] ?? properties['name_int'])
          as String?;
}

class MvtLayer {
  final String name;
  final int extent;
  final List<ElementoMvt> elementos;
  const MvtLayer(this.name, this.extent, this.elementos);
}

class TileMvt {
  final Map<String, MvtLayer> layers;
  const TileMvt(this.layers);

  static const empty = TileMvt({});

  MvtLayer? operator [](String name) => layers[name];
}

/// Layers the app draws; the rest is discarded when decoding.
const layersUseful = {
  'water',
  'waterway',
  'landcover',
  'landuse',
  'park',
  'building',
  'transportation',
  'transportation_name',
  'place',
  'aeroway',
};

TileMvt decodeMvt(Uint8List bytes, {Set<String> layers = layersUseful}) {
  final r = _Lector(bytes);
  final res = <String, MvtLayer>{};
  while (!r.fin) {
    final clave = r.varint();
    final field = clave >> 3, type = clave & 7;
    if (field == 3 && type == 2) {
      final layer = _layer(r.sub(), layers);
      if (layer != null) res[layer.name] = layer;
    } else {
      r.jump(type);
    }
  }
  return TileMvt(res);
}

MvtLayer? _layer(_Lector r, Set<String> filter) {
  String? name;
  var extent = 4096;
  final raw = <_Lector>[];
  final keys = <String>[];
  final values = <Object?>[];
  while (!r.fin) {
    final clave = r.varint();
    final field = clave >> 3, type = clave & 7;
    switch (field) {
      case 1:
        name = r.text();
        if (!filter.contains(name)) return null;
      case 2:
        raw.add(r.sub());
      case 3:
        keys.add(r.text());
      case 4:
        values.add(_value(r.sub()));
      case 5:
        extent = r.varint();
      default:
        r.jump(type);
    }
  }
  if (name == null) return null;
  return MvtLayer(name, extent, [
    for (final c in raw) _elemento(c, keys, values),
  ]);
}

Object? _value(_Lector r) {
  Object? v;
  while (!r.fin) {
    final clave = r.varint();
    final field = clave >> 3, type = clave & 7;
    switch (field) {
      case 1:
        v = r.text();
      case 2:
        v = r.float32();
      case 3:
        v = r.float64();
      case 4:
      case 5:
        v = r.varint();
      case 6:
        final z = r.varint();
        v = _zigzag(z);
      case 7:
        v = r.varint() != 0;
      default:
        r.jump(type);
    }
  }
  return v;
}

ElementoMvt _elemento(_Lector r, List<String> keys, List<Object?> values) {
  var type = GeometryType.unknown;
  final props = <String, Object?>{};
  List<int> commands = const [];
  while (!r.fin) {
    final clave = r.varint();
    final field = clave >> 3, t = clave & 7;
    switch (field) {
      case 2:
        final tags = r.packed();
        for (var i = 0; i + 1 < tags.length; i += 2) {
          if (tags[i] < keys.length && tags[i + 1] < values.length) {
            props[keys[tags[i]]] = values[tags[i + 1]];
          }
        }
      case 3:
        final v = r.varint();
        type = v >= 1 && v <= 3 ? GeometryType.values[v] : GeometryType.unknown;
      case 4:
        commands = r.packed();
      default:
        r.jump(t);
    }
  }
  return ElementoMvt(type, props, _geometry(commands));
}

/// Protobuf zigzag with plain arithmetic: on web the bit operators
/// return 32-bit unsigned integers, and `(v >> 1) ^ -(v & 1)` gives
/// huge numbers instead of negatives.
int _zigzag(int v) => v.isOdd ? -((v + 1) ~/ 2) : v ~/ 2;

List<List<TilePoint>> _geometry(List<int> cmd) {
  final res = <List<TilePoint>>[];
  var actual = <TilePoint>[];
  var x = 0, y = 0, i = 0;
  int zz(int v) => _zigzag(v);
  while (i < cmd.length) {
    final c = cmd[i++];
    final id = c & 7, cuenta = c >> 3;
    switch (id) {
      case 1: // MoveTo
        for (var k = 0; k < cuenta && i + 1 < cmd.length; k++) {
          if (actual.isNotEmpty) res.add(actual);
          actual = <TilePoint>[];
          x += zz(cmd[i++]);
          y += zz(cmd[i++]);
          actual.add(TilePoint(x, y));
        }
      case 2: // LineTo
        for (var k = 0; k < cuenta && i + 1 < cmd.length; k++) {
          x += zz(cmd[i++]);
          y += zz(cmd[i++]);
          actual.add(TilePoint(x, y));
        }
      case 7: // ClosePath
        if (actual.isNotEmpty) actual.add(actual.first);
      default:
        return res;
    }
  }
  if (actual.isNotEmpty) res.add(actual);
  return res;
}

class _Lector {
  final Uint8List b;
  int i;
  final int finPos;
  _Lector(this.b, [this.i = 0, int? fin]) : finPos = fin ?? b.length;

  bool get fin => i >= finPos;

  int varint() {
    // Multiplying (not shifting bits) so values over 32 bits
    // (feature ids) don't break on web.
    var res = 0, mult = 1;
    while (true) {
      final c = b[i++];
      res += (c & 0x7f) * mult;
      if (c < 0x80) return res;
      mult *= 128;
    }
  }

  _Lector sub() {
    final l = varint();
    final s = _Lector(b, i, i + l);
    i += l;
    return s;
  }

  String text() {
    final l = varint();
    final s = _utf8(b, i, i + l);
    i += l;
    return s;
  }

  List<int> packed() {
    final s = sub();
    final res = <int>[];
    while (!s.fin) {
      res.add(s.varint());
    }
    return res;
  }

  double float32() {
    final v = ByteData.sublistView(b, i, i + 4).getFloat32(0, Endian.little);
    i += 4;
    return v;
  }

  double float64() {
    final v = ByteData.sublistView(b, i, i + 8).getFloat64(0, Endian.little);
    i += 8;
    return v;
  }

  void jump(int type) {
    switch (type) {
      case 0:
        varint();
      case 1:
        i += 8;
      case 2:
        i += varint();
      case 5:
        i += 4;
      default:
        throw FormatException('tipo de campo protobuf desconocido: $type');
    }
  }
}

String _utf8(Uint8List b, int from, int until) {
  // Simple UTF-8 decoding (street names with accents and ñ).
  final cps = <int>[];
  var i = from;
  while (i < until) {
    final c = b[i];
    if (c < 0x80) {
      cps.add(c);
      i++;
    } else if (c < 0xE0 && i + 1 < until) {
      cps.add(((c & 0x1F) << 6) | (b[i + 1] & 0x3F));
      i += 2;
    } else if (c < 0xF0 && i + 2 < until) {
      cps.add(
        ((c & 0x0F) << 12) | ((b[i + 1] & 0x3F) << 6) | (b[i + 2] & 0x3F),
      );
      i += 3;
    } else if (i + 3 < until) {
      cps.add(
        ((c & 0x07) << 18) |
            ((b[i + 1] & 0x3F) << 12) |
            ((b[i + 2] & 0x3F) << 6) |
            (b[i + 3] & 0x3F),
      );
      i += 4;
    } else {
      i++;
    }
  }
  return String.fromCharCodes(cps);
}
