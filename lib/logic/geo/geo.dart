// Geometría sobre la superficie terrestre, a escala urbana.
//
// Proyecciones locales equirectangulares: a escala de una ciudad el error es
// despreciable y el cálculo es barato y determinista.

import 'dart:math' as math;

import '../../contract/modelo.dart';

const double _radioTierra = 6371000.0;

double _rad(double g) => g * math.pi / 180.0;

/// Distancia haversine en metros.
double distancia(Coordenada a, Coordenada b) {
  final dLat = _rad(b.lat - a.lat);
  final dLng = _rad(b.lng - a.lng);
  final h =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(a.lat)) *
          math.cos(_rad(b.lat)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * _radioTierra * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

/// Largo de una polilínea en metros.
double largo(List<Coordenada> linea) {
  var total = 0.0;
  for (var i = 1; i < linea.length; i++) {
    total += distancia(linea[i - 1], linea[i]);
  }
  return total;
}

/// Punto de una polilínea más cercano a una coordenada.
class Proyeccion {
  /// Índice del segmento [i, i+1] donde cae la proyección.
  final int segmento;

  /// Posición dentro del segmento (0..1).
  final double t;
  final Coordenada punto;

  /// Distancia perpendicular de la coordenada a la polilínea.
  final double distanciaLateral;

  /// Metros recorridos desde el inicio de la polilínea hasta [punto].
  final double recorrido;

  const Proyeccion({
    required this.segmento,
    required this.t,
    required this.punto,
    required this.distanciaLateral,
    required this.recorrido,
  });
}

/// Polilínea con las distancias acumuladas precalculadas.
class Polilinea {
  final List<Coordenada> puntos;
  final List<double> _acumulado;

  Polilinea(this.puntos)
    : assert(puntos.length >= 2, 'una polilínea necesita 2 puntos'),
      _acumulado = _acumular(puntos);

  static List<double> _acumular(List<Coordenada> p) {
    final acc = List<double>.filled(p.length, 0);
    for (var i = 1; i < p.length; i++) {
      acc[i] = acc[i - 1] + distancia(p[i - 1], p[i]);
    }
    return acc;
  }

  double get largo => _acumulado.last;

  /// Proyecta [c] sobre la polilínea. Si se da [desde]/[hasta] (metros
  /// recorridos), solo se consideran los segmentos que tocan esa ventana:
  /// sirve para shapes que pasan dos veces cerca del mismo lugar.
  Proyeccion proyectar(Coordenada c, {double? desde, double? hasta}) {
    Proyeccion? mejor;
    for (var i = 0; i < puntos.length - 1; i++) {
      if (desde != null && _acumulado[i + 1] < desde) continue;
      if (hasta != null && _acumulado[i] > hasta) break;
      final p = _proyectarEnSegmento(c, i);
      if (mejor == null || p.distanciaLateral < mejor.distanciaLateral) {
        mejor = p;
      }
    }
    return mejor ?? _proyectarEnSegmento(c, 0);
  }

  Proyeccion _proyectarEnSegmento(Coordenada c, int i) {
    final a = puntos[i], b = puntos[i + 1];
    // Plano local centrado en a (metros).
    final cosLat = math.cos(_rad(a.lat));
    double x(Coordenada p) => _rad(p.lng - a.lng) * cosLat * _radioTierra;
    double y(Coordenada p) => _rad(p.lat - a.lat) * _radioTierra;
    final bx = x(b), by = y(b), cx = x(c), cy = y(c);
    final len2 = bx * bx + by * by;
    var t = len2 == 0 ? 0.0 : (cx * bx + cy * by) / len2;
    t = t.clamp(0.0, 1.0);
    final punto = Coordenada(
      a.lat + (b.lat - a.lat) * t,
      a.lng + (b.lng - a.lng) * t,
    );
    final seg = _acumulado[i + 1] - _acumulado[i];
    return Proyeccion(
      segmento: i,
      t: t,
      punto: punto,
      distanciaLateral: distancia(c, punto),
      recorrido: _acumulado[i] + seg * t,
    );
  }

  /// Sub-polilínea entre dos distancias recorridas (desde < hasta).
  List<Coordenada> tramo(double desde, double hasta) {
    assert(desde <= hasta);
    final res = <Coordenada>[puntoEn(desde)];
    for (var i = 0; i < puntos.length; i++) {
      if (_acumulado[i] > desde && _acumulado[i] < hasta) {
        _agregarSinDuplicar(res, puntos[i]);
      }
    }
    _agregarSinDuplicar(res, puntoEn(hasta));
    if (res.length == 1) res.add(res.first);
    return res;
  }

  /// Coordenada a [metros] del inicio.
  Coordenada puntoEn(double metros) {
    if (metros <= 0) return puntos.first;
    if (metros >= largo) return puntos.last;
    var i = 0;
    while (i < _acumulado.length - 2 && _acumulado[i + 1] < metros) {
      i++;
    }
    final seg = _acumulado[i + 1] - _acumulado[i];
    final t = seg == 0 ? 0.0 : (metros - _acumulado[i]) / seg;
    final a = puntos[i], b = puntos[i + 1];
    return Coordenada(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t);
  }

  /// Rumbo aproximado (grados, 0 = norte) en [metros].
  double rumboEn(double metros) {
    final a = puntoEn(math.max(0, metros - 5));
    final b = puntoEn(math.min(largo, metros + 5));
    return rumbo(a, b);
  }
}

void _agregarSinDuplicar(List<Coordenada> lista, Coordenada c) {
  if (lista.isEmpty || distancia(lista.last, c) > 0.25) lista.add(c);
}

/// Rumbo inicial de a hacia b en grados (0..360, 0 = norte).
double rumbo(Coordenada a, Coordenada b) {
  final y = math.sin(_rad(b.lng - a.lng)) * math.cos(_rad(b.lat));
  final x =
      math.cos(_rad(a.lat)) * math.sin(_rad(b.lat)) -
      math.sin(_rad(a.lat)) *
          math.cos(_rad(b.lat)) *
          math.cos(_rad(b.lng - a.lng));
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// Decodifica una polilínea codificada (algoritmo de Google, precisión 5).
List<Coordenada> decodificarPolilinea(String codificada) {
  final res = <Coordenada>[];
  var index = 0, lat = 0, lng = 0;
  while (index < codificada.length) {
    for (var k = 0; k < 2; k++) {
      // Con aritmética común, no con operadores de bits: en web estos
      // devuelven enteros sin signo y `~x` da un número enorme.
      var mult = 1, result = 0, b = 0;
      do {
        b = codificada.codeUnitAt(index++) - 63;
        result += (b % 32) * mult;
        mult *= 32;
      } while (b >= 0x20 && index < codificada.length);
      final delta = result.isOdd ? -(result ~/ 2) - 1 : result ~/ 2;
      if (k == 0) {
        lat += delta;
      } else {
        lng += delta;
      }
    }
    res.add(Coordenada(lat / 1e5, lng / 1e5));
  }
  return res;
}
