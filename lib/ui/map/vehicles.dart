// The moving markers (the user, the bus) between one reading and the
// next, and how the scene looks in each frame.
//
// The logic publishes isolated readings; the map turns them into continuous
// movement (see movimiento.dart), fuses markers that change shape or leave,
// and makes routes start where each marker is seen. It does not depend on
// widgets: the map passes it the scene and the time of each frame, and tests
// can walk through a whole trip frame by frame.

import 'dart:ui' show Offset;

import 'package:flutter/animation.dart' show Curves;

import '../../contract/model.dart';
import 'scene.dart';
import 'movement.dart';
import 'projection.dart';

class VehiclesScene {
  /// Duration (s) of the fades.
  static const fused = 0.45;

  /// Moving markers: their position is predicted between readings so
  /// they advance continuously.
  final Map<String, PredictedMovement> _vehicles = {};
  final Map<String, (Coordinate, bool)> _lastReading = {};

  /// Last marker shown for each mover and when it appeared: when it changes
  /// shape (your dot -> you on the bus) or leaves (the bus that arrived), the
  /// old one fades out and the new one appears, instead of jumping.
  final Map<String, MapMarker> _shown = {};
  final Map<String, double> _appearedAt = {};
  final List<(MapMarker, double)> _leaving = [];

  static String? _keyOf(MapMarker m) => switch (m) {
    MarkerUser() || MarkerUserInBus() => 'user',
    MarkerBus() => 'bus',
    _ => null,
  };

  /// Predicted position (mercator) of the mover [key] ('usuario' or 'bus').
  Offset? position(String key) => _vehicles[key]?.position;

  /// Reads the moving marks of [escena] (new readings) at [ahora] (s).
  /// With [fundir], whatever changes shape or leaves fades out.
  void synchronize(MapScene scene, double now, {required bool fuse}) {
    final views = <String>{};
    for (final m in scene.marks) {
      final k = _keyOf(m);
      if (k == null) continue;
      views.add(k);
      final before = _shown[k];
      if (fuse && (before == null || before.runtimeType != m.runtimeType)) {
        if (before != null) _leaving.add((before, now));
        _appearedAt[k] = now;
      }
      final p = mercator(m.coordinate);
      final path = m.path;
      final still = m is MarkerUser && m.still;
      final mov = _vehicles[k];
      if (mov == null) {
        _vehicles[k] = PredictedMovement(p, now);
        _lastReading[k] = (m.coordinate, still);
        continue;
      }
      // A new reading, or the same one but now still (arrived at the stop):
      // its advance must stop being predicted.
      if (_lastReading[k] == (m.coordinate, still)) continue;
      _lastReading[k] = (m.coordinate, still);
      final pathM = path == null ? null : _pathMercator(path);
      final other = _isOther(k, mov.position, p, pathM);
      if (other && fuse) {
        // It is not slid or made to jump: the one that was showing fades out
        // where it was, and the new one appears where it is.
        final seen = _shown[k];
        if (seen != null) _leaving.add((seen, now));
        _appearedAt[k] = now;
      }
      mov.reading(
        p,
        now,
        path: pathM,
        sourcePath: path,
        limit: m is MarkerBus && m.limit != null ? mercator(m.limit!) : null,
        relocated: other,
        predict: !still,
      );
    }
    for (final k in _shown.keys.toList()) {
      if (views.contains(k)) continue;
      // Gone (the bus that reached the stop): fades out where it was.
      if (fuse) _leaving.add((_shown[k]!, now));
      _shown.remove(k);
    }
    _vehicles.removeWhere((k, _) => !views.contains(k));
    _lastReading.removeWhere((k, _) => !views.contains(k));
    _appearedAt.removeWhere((k, _) => !views.contains(k));
  }

  /// true if the new reading [nueva] is not the same marker advancing from
  /// [visto] but another one: a large jump that does not follow its path (the
  /// GPS relocating, going back home), or a bus that appears behind it along
  /// its route (one arrived and the next one coming is the following one: buses
  /// do not go backward).
  static bool _isOther(
    String key,
    Offset seen,
    Offset fresh,
    List<Offset>? path,
  ) {
    final jump = (fresh - seen).distance * metersByUnit;
    if (path != null && path.length >= 2) {
      final (sSeen, dSeen) = _over(path, seen);
      final (sFresh, dFresh) = _over(path, fresh);
      if (dSeen < 30 && dFresh < 30) {
        // Same path: ahead means it is the same one advancing.
        return key == 'bus' && sFresh < sSeen - 30;
      }
    }
    return jump > 400;
  }

  /// (meters traveled, meters of distance) of [p] over [path].
  static (double, double) _over(List<Offset> path, Offset p) {
    var cum = 0.0, bestS = 0.0, bestD = double.infinity;
    for (var i = 1; i < path.length; i++) {
      final a = path[i - 1], ab = path[i] - a;
      final l2 = ab.dx * ab.dx + ab.dy * ab.dy;
      final u =
          l2 == 0
              ? 0.0
              : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / l2).clamp(
                0.0,
                1.0,
              );
      final d = (p - (a + ab * u)).distance;
      final long = ab.distance;
      if (d < bestD) {
        bestD = d;
        bestS = cum + long * u;
      }
      cum += long;
    }
    return (bestS * metersByUnit, bestD * metersByUnit);
  }

  final _paths = Expando<List<Offset>>();
  List<Offset> _pathMercator(List<Coordinate> c) =>
      _paths[c] ??= [for (final p in c) mercator(p)];

  /// true while something moves or fades at [ahora].
  bool animating(double now) =>
      _vehicles.values.any((m) => m.movingTo(now)) ||
      _leaving.isNotEmpty ||
      _appearedAt.values.any((t) => now - t < fused);

  /// Places the markers at [ahora]; true if drawing must continue.
  bool advance(double now) {
    for (final m in _vehicles.values) {
      m.advance(now);
    }
    return animating(now);
  }

  /// [escena] with the moving markers at their predicted position and with
  /// their heading; the routes that start from them (what is left to walk or
  /// ride, the bus approximation) begin where they are seen.
  MapScene shown(MapScene scene, double now) {
    if (_vehicles.isEmpty && _leaving.isEmpty) return scene;
    final readings = <String, (Coordinate, Coordinate)>{};
    final marks = <MapMarker>[];
    final opacity = Map<MapMarker, double>.identity();
    _leaving.removeWhere((s) => now - s.$2 >= fused);
    for (final (m, t0) in _leaving) {
      marks.add(m);
      opacity[m] = 1 - Curves.easeIn.transform((now - t0) / fused);
    }
    for (final m in scene.marks) {
      final k = _keyOf(m);
      final mov = _vehicles[k ?? ''];
      if (k == null || mov == null) {
        marks.add(m);
        continue;
      }
      final c = fromMercator(mov.position);
      readings[k] = (m.coordinate, c);
      final shown = m.movedTo(c, heading: mov.heading);
      _shown[k] = shown;
      marks.add(shown);
      final t0 = _appearedAt[k];
      if (t0 != null && now - t0 < fused) {
        opacity[shown] = Curves.easeOut.transform(
          ((now - t0) / fused).clamp(0.0, 1.0),
        );
      }
    }
    final strokes = [
      for (final t in scene.strokes)
        switch (t.style) {
          StrokeStyle.walk || StrokeStyle.bus when readings['user'] != null =>
            _beBornIn(t, readings['user']!),
          StrokeStyle.approximation when readings['bus'] != null => _beBornIn(
            t,
            readings['bus']!,
          ),
          _ => t,
        },
    ];
    return scene.copyWith(marks: marks, strokes: strokes, opacity: opacity);
  }
}

/// If [t] starts at the reading of a moving marker, it starts where the
/// marker is shown (trimming what is already behind).
MapStroke _beBornIn(MapStroke t, (Coordinate, Coordinate) reading) {
  final (fixed, shown) = reading;
  final pts = t.points;
  if (pts.length < 2) return t;
  final start = mercator(pts.first);
  if ((start - mercator(fixed)).distance * metersByUnit > 30) return t;
  final p = mercator(shown);
  // Closest segment to what is shown, among the first ones of the route.
  var best = 1;
  var bestD = double.infinity;
  for (var i = 1; i < pts.length && i < 400; i++) {
    final a = mercator(pts[i - 1]), b = mercator(pts[i]);
    final ab = b - a;
    final l2 = ab.dx * ab.dx + ab.dy * ab.dy;
    final u =
        l2 == 0
            ? 0.0
            : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / l2).clamp(0.0, 1.0);
    final d = (p - (a + ab * u)).distance;
    if (d < bestD) {
      bestD = d;
      best = i;
    }
  }
  return MapStroke(t.style, [shown, ...pts.skip(best)]);
}
