// Web Mercator in "art pixels": at zoom z the world measures 256·2^z art px.
// An art pixel is the visible pixel of the pixel art (several logical screen
// pixels).

import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../../contract/model.dart';

const double sizeTile = 256;

/// Coordinate -> normalized world (0..1, 0..1).
Offset mercator(Coordinate c) {
  final x = (c.lng + 180) / 360;
  final lat = c.lat.clamp(-85.0511, 85.0511) * math.pi / 180;
  final y = (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2;
  return Offset(x, y);
}

Coordinate fromMercator(Offset m) {
  final lng = m.dx * 360 - 180;
  final n = math.pi - 2 * math.pi * m.dy;
  final lat = 180 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
  return Coordinate(lat.clamp(-85.0, 85.0), lng);
}

/// Camera state: center in normalized mercator and zoom.
class Camera {
  final Offset center;
  final double zoom;
  const Camera(this.center, this.zoom);

  factory Camera.en(Coordinate c, double zoom) => Camera(mercator(c), zoom);

  double get scaleWorld => sizeTile * math.pow(2, zoom).toDouble();

  Coordinate get coordinate => fromMercator(center);

  /// Normalized world -> art pixel on a canvas of [tam] (center in the middle).
  Offset toCanvas(Offset world, Offset half) =>
      (world - center) * scaleWorld + half;

  Offset fromCanvas(Offset p, Offset half) => center + (p - half) / scaleWorld;

  Camera having({Offset? center, double? zoom}) =>
      Camera(center ?? this.center, zoom ?? this.zoom);

  /// Camera whose center falls on a whole art pixel (stable grid).
  Camera aligned() {
    final e = scaleWorld;
    return Camera(
      Offset(
        (center.dx * e).roundToDouble() / e,
        (center.dy * e).roundToDouble() / e,
      ),
      zoom,
    );
  }

  static Camera interpolate(Camera a, Camera b, double t) {
    // Interpolation in logarithmic zoom space so the center does not
    // "skid" during the scale change.
    final z = a.zoom + (b.zoom - a.zoom) * t;
    final c = Offset.lerp(a.center, b.center, t)!;
    return Camera(c, z);
  }
}

/// Frames [puntos] on a canvas of [ancho]x[alto], leaving the margins.
/// Continuous zoom, clamped between [zoomMin] and [zoomMax].
Camera frame(
  List<Coordinate> points, {
  required double width,
  required double height,
  double arriba = 24,
  double abajo = 24,
  double izquierda = 24,
  double derecha = 24,
  double zoomMax = 17,
  double zoomMin = 10,
}) => frameMercator(
  points.map(mercator).toList(),
  width: width,
  height: height,
  arriba: arriba,
  abajo: abajo,
  izquierda: izquierda,
  derecha: derecha,
  zoomMax: zoomMax,
  zoomMin: zoomMin,
);

/// Like [encuadrar], with points already in normalized mercator.
Camera frameMercator(
  List<Offset> ms, {
  required double width,
  required double height,
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
  final usableWidth = math.max(40.0, width - izquierda - derecha);
  final usableHeight = math.max(40.0, height - arriba - abajo);
  final dx = maxX - minX, dy = maxY - minY;
  var zoom = zoomMax;
  if (dx > 0 || dy > 0) {
    final zx =
        dx > 0 ? math.log(usableWidth / (dx * sizeTile)) / math.ln2 : zoomMax;
    final zy =
        dy > 0 ? math.log(usableHeight / (dy * sizeTile)) / math.ln2 : zoomMax;
    zoom = math.min(zx, zy).clamp(zoomMin, zoomMax).toDouble();
  }
  final e = sizeTile * math.pow(2, zoom);
  final cx = (minX + maxX) / 2 + ((derecha - izquierda) / 2) / e;
  final cy = (minY + maxY) / 2 + ((abajo - arriba) / 2) / e;
  return Camera(Offset(cx, cy), zoom);
}
