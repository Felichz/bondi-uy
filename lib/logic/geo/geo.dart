// Geometry on the Earth's surface, at city scale.
//
// Local equirectangular projections: at city scale the error is
// negligible, and the calculation is cheap and deterministic.

import 'dart:math' as math;

import '../../contract/model.dart';

const double _radioLand = 6371000.0;

double _rad(double g) => g * math.pi / 180.0;

/// Haversine distance in meters.
double distance(Coordinate a, Coordinate b) {
  final dLat = _rad(b.lat - a.lat);
  final dLng = _rad(b.lng - a.lng);
  final h =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(a.lat)) *
          math.cos(_rad(b.lat)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * _radioLand * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

/// Length of a polyline in meters.
double long(List<Coordinate> line) {
  var total = 0.0;
  for (var i = 1; i < line.length; i++) {
    total += distance(line[i - 1], line[i]);
  }
  return total;
}

/// Point on a polyline closest to a coordinate.
class Projection {
  /// Index of the segment [i, i+1] where the projection falls.
  final int segment;

  /// Position within the segment (0..1).
  final double t;
  final Coordinate point;

  /// Perpendicular distance from the coordinate to the polyline.
  final double distanceLateral;

  /// Meters traveled from the start of the polyline to [point].
  final double route;

  const Projection({
    required this.segment,
    required this.t,
    required this.point,
    required this.distanceLateral,
    required this.route,
  });
}

/// Polyline with precomputed cumulative distances.
class Polyline {
  final List<Coordinate> points;
  final List<double> _accumulated;

  Polyline(this.points)
    : assert(points.length >= 2, 'a polyline needs 2 points'),
      _accumulated = _accumulate(points);

  static List<double> _accumulate(List<Coordinate> p) {
    final acc = List<double>.filled(p.length, 0);
    for (var i = 1; i < p.length; i++) {
      acc[i] = acc[i - 1] + distance(p[i - 1], p[i]);
    }
    return acc;
  }

  double get long => _accumulated.last;

  /// Projects [c] onto the polyline. If [desde]/[hasta] (meters traveled) is
  /// given, only the segments touching that window are considered: this is
  /// useful for shapes that pass twice near the same place.
  Projection project(Coordinate c, {double? from, double? until}) {
    Projection? best;
    for (var i = 0; i < points.length - 1; i++) {
      if (from != null && _accumulated[i + 1] < from) continue;
      if (until != null && _accumulated[i] > until) break;
      final p = _projectInSegment(c, i);
      if (best == null || p.distanceLateral < best.distanceLateral) {
        best = p;
      }
    }
    return best ?? _projectInSegment(c, 0);
  }

  Projection _projectInSegment(Coordinate c, int i) {
    final a = points[i], b = points[i + 1];
    // Local plane centered on a (meters).
    final cosLat = math.cos(_rad(a.lat));
    double x(Coordinate p) => _rad(p.lng - a.lng) * cosLat * _radioLand;
    double y(Coordinate p) => _rad(p.lat - a.lat) * _radioLand;
    final bx = x(b), by = y(b), cx = x(c), cy = y(c);
    final len2 = bx * bx + by * by;
    var t = len2 == 0 ? 0.0 : (cx * bx + cy * by) / len2;
    t = t.clamp(0.0, 1.0);
    final point = Coordinate(
      a.lat + (b.lat - a.lat) * t,
      a.lng + (b.lng - a.lng) * t,
    );
    final seg = _accumulated[i + 1] - _accumulated[i];
    return Projection(
      segment: i,
      t: t,
      point: point,
      distanceLateral: distance(c, point),
      route: _accumulated[i] + seg * t,
    );
  }

  /// Sub-polyline between two traveled distances (desde < hasta).
  List<Coordinate> leg(double from, double until) {
    assert(from <= until);
    final res = <Coordinate>[pointAt(from)];
    for (var i = 0; i < points.length; i++) {
      if (_accumulated[i] > from && _accumulated[i] < until) {
        _addUnlessDuplicate(res, points[i]);
      }
    }
    _addUnlessDuplicate(res, pointAt(until));
    if (res.length == 1) res.add(res.first);
    return res;
  }

  /// Coordinate at [metros] from the start.
  Coordinate pointAt(double meters) {
    if (meters <= 0) return points.first;
    if (meters >= long) return points.last;
    var i = 0;
    while (i < _accumulated.length - 2 && _accumulated[i + 1] < meters) {
      i++;
    }
    final seg = _accumulated[i + 1] - _accumulated[i];
    final t = seg == 0 ? 0.0 : (meters - _accumulated[i]) / seg;
    final a = points[i], b = points[i + 1];
    return Coordinate(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t);
  }

  /// Approximate heading (degrees, 0 = north) at [metros].
  double headingIn(double meters) {
    final a = pointAt(math.max(0, meters - 5));
    final b = pointAt(math.min(long, meters + 5));
    return heading(a, b);
  }
}

void _addUnlessDuplicate(List<Coordinate> list, Coordinate c) {
  if (list.isEmpty || distance(list.last, c) > 0.25) list.add(c);
}

/// Initial heading from a to b in degrees (0..360, 0 = north).
double heading(Coordinate a, Coordinate b) {
  final y = math.sin(_rad(b.lng - a.lng)) * math.cos(_rad(b.lat));
  final x =
      math.cos(_rad(a.lat)) * math.sin(_rad(b.lat)) -
      math.sin(_rad(a.lat)) *
          math.cos(_rad(b.lat)) *
          math.cos(_rad(b.lng - a.lng));
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// Decodes an encoded polyline (Google algorithm, precision 5).
List<Coordinate> decodePolyline(String encoded) {
  final res = <Coordinate>[];
  var index = 0, lat = 0, lng = 0;
  while (index < encoded.length) {
    for (var k = 0; k < 2; k++) {
      // Using plain arithmetic, not bit operators: on web these
      // return unsigned integers and `~x` gives a huge number.
      var mult = 1, result = 0, b = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result += (b % 32) * mult;
        mult *= 32;
      } while (b >= 0x20 && index < encoded.length);
      final delta = result.isOdd ? -(result ~/ 2) - 1 : result ~/ 2;
      if (k == 0) {
        lat += delta;
      } else {
        lng += delta;
      }
    }
    res.add(Coordinate(lat / 1e5, lng / 1e5));
  }
  return res;
}
