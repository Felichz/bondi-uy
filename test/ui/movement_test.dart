// The marker moves continuously even when readings arrive every few seconds:
// it keeps advancing between readings, at the estimated speed and along the
// street (it turns at the corner, it does not cut diagonally).

import 'package:bondi_uy/ui/map/movement.dart';
import 'package:flutter_test/flutter_test.dart';

/// Metros -> mercator.
double m(double meters) => meters / metersByUnit;

void main() {
  // An L-shaped street: 200 m east and 200 m south.
  final origin = const Offset(0.35, 0.60);
  final corner = origin + Offset(m(200), 0);
  final end = corner + Offset(0, m(200));
  final path = [origin, corner, end];

  /// Point [d] meters along the street.
  Offset byStreet(double d) =>
      d <= 200 ? origin + Offset(m(d), 0) : corner + Offset(0, m(d - 200));

  double lateral(Offset p) {
    // Distance (m) to the L-shaped path: the smaller of the distances to each of its two segments.
    final x = (p.dx - origin.dx) / m(1), y = (p.dy - origin.dy) / m(1);
    final toEast = Offset(x - x.clamp(0, 200), y).distance;
    final toSouth = Offset(x - 200, y - y.clamp(0, 200)).distance;
    return toEast < toSouth ? toEast : toSouth;
  }

  test(
    'with readings every 5 s it moves without stopping and turns along the street',
    () {
      const v = 1.4; // m/s, walking
      const every = 5.0;
      final mov = PredictedMovement(byStreet(0), 0);
      Offset? previous;
      final steps = <double>[];
      for (var frame = 0; frame <= 2500; frame++) {
        final t = frame / 10;
        // A reading arrives every 5 s (the real position at that instant).
        if (frame > 0 && frame % (every * 10).round() == 0) {
          mov.reading(byStreet(v * t), t, path: path);
        }
        mov.advance(t);
        final p = mov.position;
        if (previous != null && t > 12) {
          steps.add((p - previous).distance / m(1));
        }
        previous = p;
        if (t > 12) {
          expect(
            lateral(p),
            lessThan(1.5),
            reason: 'at ${t.toStringAsFixed(1)} s it is on the street',
          );
        }
      }
      // After startup, each frame (0.1 s) advances ~0.14 m: it never stands
      // still waiting for the next reading, nor does it jump.
      final min = steps.reduce((a, b) => a < b ? a : b);
      final max = steps.reduce((a, b) => a > b ? a : b);
      expect(min, greaterThan(0.05), reason: 'does not stop between readings');
      expect(max, lessThan(0.5), reason: 'does not jump');
      // It faces where it is going: at the end, south.
      expect(mov.heading, closeTo(180, 5));
    },
  );

  test('standing still does not move with GPS noise', () {
    final mov = PredictedMovement(origin, 0);
    for (var i = 1; i <= 10; i++) {
      mov.reading(origin + Offset(m(0.5) * (i.isEven ? 1 : -1), 0), i * 5.0);
    }
    mov.advance(60);
    expect((mov.position - origin).distance / m(1), lessThan(1));
  });

  test('a big jump is shown directly', () {
    final mov = PredictedMovement(origin, 0);
    final far = origin + Offset(m(2000), 0);
    mov.reading(far, 5, relocated: true);
    expect(mov.position, far);
  });

  test('the incoming bus does not overshoot the stop by prediction', () {
    // Coming along the L-shaped street toward a stop 150 m away, at 8 m/s.
    final stop = byStreet(150);
    final mov = PredictedMovement(byStreet(0), 0);
    var d = 0.0;
    for (var t = 5.0; t <= 15; t += 5) {
      d = 8 * t;
      mov.reading(byStreet(d), t, path: path, limit: stop);
    }
    // With no more readings, the prediction advances... up to the stop, no further.
    mov.advance(40);
    expect((mov.position - stop).distance / m(1), lessThan(1.5));
    // A real reading further on does take it past the stop.
    mov.reading(byStreet(190), 20, path: path, limit: stop);
    mov.advance(21);
    expect(
      (mov.position - byStreet(190)).distance / m(1),
      lessThan(20),
      reason: 'follows the real GPS',
    );
  });

  test('without a path, it also stops at the stop', () {
    final stop = origin + Offset(m(100), 0);
    final mov = PredictedMovement(origin, 0);
    for (var t = 5.0; t <= 10; t += 5) {
      mov.reading(origin + Offset(m(7 * t), 0), t, limit: stop);
    }
    mov.advance(60);
    expect(mov.position.dx, lessThanOrEqualTo(stop.dx + m(0.5)));
    expect((mov.position - stop).distance / m(1), lessThan(1.5));
  });
}
