// Web Mercator en "píxeles de arte": a zoom z el mundo mide 256·2^z px de
// arte. Un píxel de arte es el píxel visible del pixel art (varios píxeles
// lógicos de pantalla).

import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../../contract/modelo.dart';

const double tamTesela = 256;

/// Coordenada -> mundo normalizado (0..1, 0..1).
Offset mercator(Coordenada c) {
  final x = (c.lng + 180) / 360;
  final lat = c.lat.clamp(-85.0511, 85.0511) * math.pi / 180;
  final y = (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2;
  return Offset(x, y);
}

Coordenada desdeMercator(Offset m) {
  final lng = m.dx * 360 - 180;
  final n = math.pi - 2 * math.pi * m.dy;
  final lat = 180 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
  return Coordenada(lat.clamp(-85.0, 85.0), lng);
}

/// Estado de cámara: centro en mercator normalizado y zoom.
class Camara {
  final Offset centro;
  final double zoom;
  const Camara(this.centro, this.zoom);

  factory Camara.en(Coordenada c, double zoom) => Camara(mercator(c), zoom);

  double get escalaMundo => tamTesela * math.pow(2, zoom).toDouble();

  Coordenada get coordenada => desdeMercator(centro);

  /// Mundo normalizado -> píxel de arte en un lienzo de [tam] (centro en medio).
  Offset aLienzo(Offset mundo, Offset mitad) =>
      (mundo - centro) * escalaMundo + mitad;

  Offset desdeLienzo(Offset p, Offset mitad) =>
      centro + (p - mitad) / escalaMundo;

  Camara con({Offset? centro, double? zoom}) =>
      Camara(centro ?? this.centro, zoom ?? this.zoom);

  /// Cámara cuyo centro cae en un píxel de arte entero (grilla estable).
  Camara alineada() {
    final e = escalaMundo;
    return Camara(
      Offset(
        (centro.dx * e).roundToDouble() / e,
        (centro.dy * e).roundToDouble() / e,
      ),
      zoom,
    );
  }

  static Camara interpolar(Camara a, Camara b, double t) {
    // Interpolación en espacio de zoom logarítmico para que el centro no
    // "derrape" durante el cambio de escala.
    final z = a.zoom + (b.zoom - a.zoom) * t;
    final c = Offset.lerp(a.centro, b.centro, t)!;
    return Camara(c, z);
  }
}

/// Encuadra [puntos] en un lienzo de [ancho]x[alto] dejando los márgenes.
/// Zoom continuo, acotado entre [zoomMin] y [zoomMax].
Camara encuadrar(
  List<Coordenada> puntos, {
  required double ancho,
  required double alto,
  double arriba = 24,
  double abajo = 24,
  double izquierda = 24,
  double derecha = 24,
  double zoomMax = 17,
  double zoomMin = 10,
}) => encuadrarMercator(
  puntos.map(mercator).toList(),
  ancho: ancho,
  alto: alto,
  arriba: arriba,
  abajo: abajo,
  izquierda: izquierda,
  derecha: derecha,
  zoomMax: zoomMax,
  zoomMin: zoomMin,
);

/// Como [encuadrar], con puntos ya en mercator normalizado.
Camara encuadrarMercator(
  List<Offset> ms, {
  required double ancho,
  required double alto,
  double arriba = 24,
  double abajo = 24,
  double izquierda = 24,
  double derecha = 24,
  double zoomMax = 17,
  double zoomMin = 10,
}) {
  assert(ms.isNotEmpty);
  var minX = ms.first.dx, maxX = minX, minY = ms.first.dy, maxY = minY;
  for (final m in ms) {
    minX = math.min(minX, m.dx);
    maxX = math.max(maxX, m.dx);
    minY = math.min(minY, m.dy);
    maxY = math.max(maxY, m.dy);
  }
  final utilAncho = math.max(40.0, ancho - izquierda - derecha);
  final utilAlto = math.max(40.0, alto - arriba - abajo);
  final dx = maxX - minX, dy = maxY - minY;
  var zoom = zoomMax;
  if (dx > 0 || dy > 0) {
    final zx =
        dx > 0 ? math.log(utilAncho / (dx * tamTesela)) / math.ln2 : zoomMax;
    final zy =
        dy > 0 ? math.log(utilAlto / (dy * tamTesela)) / math.ln2 : zoomMax;
    zoom = math.min(zx, zy).clamp(zoomMin, zoomMax).toDouble();
  }
  final e = tamTesela * math.pow(2, zoom);
  final cx = (minX + maxX) / 2 + ((derecha - izquierda) / 2) / e;
  final cy = (minY + maxY) / 2 + ((abajo - arriba) / 2) / e;
  return Camara(Offset(cx, cy), zoom);
}
