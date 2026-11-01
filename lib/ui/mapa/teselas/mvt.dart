// Decodificador mínimo de Mapbox Vector Tiles (MVT 2.x).
//
// Solo lo necesario para dibujar: capas, tipo de geometría, propiedades y
// geometrías en coordenadas de tesela (0..extent).

import 'dart:typed_data';

enum TipoGeometria { desconocida, punto, linea, poligono }

class PuntoTesela {
  final int x;
  final int y;
  const PuntoTesela(this.x, this.y);
}

class ElementoMvt {
  final TipoGeometria tipo;
  final Map<String, Object?> propiedades;

  /// Punto: una lista por punto. Línea: una lista por línea.
  /// Polígono: una lista por anillo (exterior horario, huecos antihorarios).
  final List<List<PuntoTesela>> geometria;

  const ElementoMvt(this.tipo, this.propiedades, this.geometria);

  String? get clase => propiedades['class'] as String?;
  String? get nombre =>
      (propiedades['name:es'] ?? propiedades['name'] ?? propiedades['name_int'])
          as String?;
}

class CapaMvt {
  final String nombre;
  final int extent;
  final List<ElementoMvt> elementos;
  const CapaMvt(this.nombre, this.extent, this.elementos);
}

class TeselaMvt {
  final Map<String, CapaMvt> capas;
  const TeselaMvt(this.capas);

  static const vacia = TeselaMvt({});

  CapaMvt? operator [](String nombre) => capas[nombre];
}

/// Capas que la app dibuja; el resto se descarta al decodificar.
const capasUtiles = {
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

TeselaMvt decodificarMvt(Uint8List bytes, {Set<String> capas = capasUtiles}) {
  final r = _Lector(bytes);
  final res = <String, CapaMvt>{};
  while (!r.fin) {
    final clave = r.varint();
    final campo = clave >> 3, tipo = clave & 7;
    if (campo == 3 && tipo == 2) {
      final capa = _capa(r.sub(), capas);
      if (capa != null) res[capa.nombre] = capa;
    } else {
      r.saltar(tipo);
    }
  }
  return TeselaMvt(res);
}

CapaMvt? _capa(_Lector r, Set<String> filtro) {
  String? nombre;
  var extent = 4096;
  final crudos = <_Lector>[];
  final claves = <String>[];
  final valores = <Object?>[];
  while (!r.fin) {
    final clave = r.varint();
    final campo = clave >> 3, tipo = clave & 7;
    switch (campo) {
      case 1:
        nombre = r.texto();
        if (!filtro.contains(nombre)) return null;
      case 2:
        crudos.add(r.sub());
      case 3:
        claves.add(r.texto());
      case 4:
        valores.add(_valor(r.sub()));
      case 5:
        extent = r.varint();
      default:
        r.saltar(tipo);
    }
  }
  if (nombre == null) return null;
  return CapaMvt(nombre, extent, [
    for (final c in crudos) _elemento(c, claves, valores),
  ]);
}

Object? _valor(_Lector r) {
  Object? v;
  while (!r.fin) {
    final clave = r.varint();
    final campo = clave >> 3, tipo = clave & 7;
    switch (campo) {
      case 1:
        v = r.texto();
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
        r.saltar(tipo);
    }
  }
  return v;
}

ElementoMvt _elemento(_Lector r, List<String> claves, List<Object?> valores) {
  var tipo = TipoGeometria.desconocida;
  final props = <String, Object?>{};
  List<int> comandos = const [];
  while (!r.fin) {
    final clave = r.varint();
    final campo = clave >> 3, t = clave & 7;
    switch (campo) {
      case 2:
        final tags = r.empaquetados();
        for (var i = 0; i + 1 < tags.length; i += 2) {
          if (tags[i] < claves.length && tags[i + 1] < valores.length) {
            props[claves[tags[i]]] = valores[tags[i + 1]];
          }
        }
      case 3:
        final v = r.varint();
        tipo =
            v >= 1 && v <= 3
                ? TipoGeometria.values[v]
                : TipoGeometria.desconocida;
      case 4:
        comandos = r.empaquetados();
      default:
        r.saltar(t);
    }
  }
  return ElementoMvt(tipo, props, _geometria(comandos));
}

/// Zigzag de protobuf con aritmética común: en web los operadores de bits
/// devuelven enteros sin signo de 32 bits y `(v >> 1) ^ -(v & 1)` da
/// números enormes en vez de negativos.
int _zigzag(int v) => v.isOdd ? -((v + 1) ~/ 2) : v ~/ 2;

List<List<PuntoTesela>> _geometria(List<int> cmd) {
  final res = <List<PuntoTesela>>[];
  var actual = <PuntoTesela>[];
  var x = 0, y = 0, i = 0;
  int zz(int v) => _zigzag(v);
  while (i < cmd.length) {
    final c = cmd[i++];
    final id = c & 7, cuenta = c >> 3;
    switch (id) {
      case 1: // MoveTo
        for (var k = 0; k < cuenta && i + 1 < cmd.length; k++) {
          if (actual.isNotEmpty) res.add(actual);
          actual = <PuntoTesela>[];
          x += zz(cmd[i++]);
          y += zz(cmd[i++]);
          actual.add(PuntoTesela(x, y));
        }
      case 2: // LineTo
        for (var k = 0; k < cuenta && i + 1 < cmd.length; k++) {
          x += zz(cmd[i++]);
          y += zz(cmd[i++]);
          actual.add(PuntoTesela(x, y));
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
    // Multiplicando (no desplazando bits) para que valores de más de 32 bits
    // (ids de elementos) no se rompan en web.
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

  String texto() {
    final l = varint();
    final s = _utf8(b, i, i + l);
    i += l;
    return s;
  }

  List<int> empaquetados() {
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

  void saltar(int tipo) {
    switch (tipo) {
      case 0:
        varint();
      case 1:
        i += 8;
      case 2:
        i += varint();
      case 5:
        i += 4;
      default:
        throw FormatException('tipo de campo protobuf desconocido: $tipo');
    }
  }
}

String _utf8(Uint8List b, int desde, int hasta) {
  // Decodificación UTF-8 simple (nombres de calles con tildes y ñ).
  final cps = <int>[];
  var i = desde;
  while (i < hasta) {
    final c = b[i];
    if (c < 0x80) {
      cps.add(c);
      i++;
    } else if (c < 0xE0 && i + 1 < hasta) {
      cps.add(((c & 0x1F) << 6) | (b[i + 1] & 0x3F));
      i += 2;
    } else if (c < 0xF0 && i + 2 < hasta) {
      cps.add(
        ((c & 0x0F) << 12) | ((b[i + 1] & 0x3F) << 6) | (b[i + 2] & 0x3F),
      );
      i += 3;
    } else if (i + 3 < hasta) {
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
