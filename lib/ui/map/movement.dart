// Continuous movement from loose readings.
//
// The GPS (and the bus API) deliver point positions every few seconds.
// Showing them as-is makes the marker and the map jump; only interpolating
// between the previous and the new one makes it speed up and slow down. Like
// travel apps, here the speed is estimated and the marker keeps moving between
// readings, ALONG THE PATH when it is known (the street you walk, the bus
// route), so it turns at corners. Each new reading corrects the plan without
// jumps: the marker speeds up or eases off to reach the position the reading
// predicts, without going faster than about three times its speed (a large
// correction is spread over more time, not done in one jerk).
//
// Everything in normalized mercator coordinates (0..1) and seconds.

import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Meters per unit of normalized mercator at the latitude of Montevideo.
final double metersByUnit = 40075016.7 * math.cos(-34.9 * math.pi / 180);

class PredictedMovement {
  Offset _pos;
  double? _heading;

  // Last reading.
  Offset _fixed;
  double _tFixed;

  /// Typical time between readings (moving average), s.
  double _interval = 1;
  int _readings = 0;

  /// Estimated speed (units/s) and, without a path, 2D velocity.
  double _speed = 0;
  Offset _velocity = Offset.zero;

  _Path? _path;
  Object? _sourcePath;

  // Current plan: from (s0 | p0) to (s1 | p1) between t0 and t1.
  double _t0 = 0, _t1 = 0;
  double _s0 = 0;
  Offset _p0 = Offset.zero;
  bool _byPath = false;

  /// Difference between what was shown and the path when the plan started: it
  /// is absorbed in half a second (so changing path causes no jumps).
  Offset _detour = Offset.zero;

  /// Point the prediction cannot pass (the stop the bus is heading to). Only a
  /// real reading beyond it moves it to the other side.
  Offset? _limit;

  /// Time constant (s) with which the difference between what was shown and the
  /// new reading is absorbed.
  double _tau = 0.5;

  /// Time constant to absorb [error] (mercator): half a second, or more if the
  /// correction would otherwise exceed twice the speed (+3 m/s). With a single
  /// speed sample (just appeared) the estimate is weak: the correction does not
  /// exceed the speed.
  double _tauFor(double error) {
    // Standing still: go to the reading right away, there is no movement to follow.
    if (_still) return 0.4;
    final margin = _speed * (_readings <= 1 ? 1 : 2) + 3 / metersByUnit;
    return (error / margin).clamp(0.5, 4.0);
  }

  PredictedMovement(Offset start, double t)
    : _pos = start,
      _fixed = start,
      _tFixed = t;

  /// Position to display (mercator).
  Offset get position => _pos;

  /// Direction of travel (degrees, 0 = north), if known.
  double? get heading => _heading;

  /// The last reading received.
  Offset get fixed => _fixed;

  /// true while the plan has not finished (frames must keep being drawn).
  bool movingTo(double t) => t < _t1;

  /// A new reading at [p] at time [t]. [path] (mercator polyline, in direction
  /// of travel) restricts movement to that geometry. With [reubicado] (large
  /// jump: another bus, GPS relocating) it is shown directly, without predicting.
  void reading(
    Offset p,
    double t, {
    List<Offset>? path,
    Object? sourcePath,
    Offset? limit,
    bool relocated = false,
    bool predict = true,
  }) {
    advance(t);
    _limit = limit;
    // The path changed (another segment: you got off, you boarded the bus): the
    // earlier speed says nothing about the current one.
    var pathNew = false;
    if (path == null || path.length < 2) {
      pathNew = _path != null;
      _path = null;
      _sourcePath = null;
    } else if (!identical(sourcePath ?? path, _sourcePath)) {
      pathNew = _path != null || _sourcePath != null;
      _path = _Path(path);
      _sourcePath = sourcePath ?? path;
    }
    final dt = t - _tFixed;
    if (relocated) {
      _pos = p;
      _speed = 0;
      _velocity = Offset.zero;
      _heading = null;
      _pin(p, t);
      _t0 = _t1 = t;
      _p0 = p;
      _errorP = Offset.zero;
      _byPath = false;
      return;
    }
    if (dt > 0.05) {
      _interval = (_readings == 0 ? dt : 0.6 * _interval + 0.4 * dt).clamp(
        0.2,
        8.0,
      );
      _readings++;
      final step = p - _fixed;
      final meters = step.distance * metersByUnit;
      // Less than 1.5 m between readings: standing still (GPS noise).
      final sample = meters < 1.5 ? 0.0 : step.distance / dt;
      final v = meters < 1.5 ? Offset.zero : step / dt;
      final first = _speed == 0 || pathNew;
      _speed = first ? sample : 0.5 * _speed + 0.5 * sample;
      _velocity = first ? v : _velocity * 0.5 + v * 0.5;
      if (meters >= 1.5) _heading = _degrees(step);
    }
    if (!predict) {
      // Standing still: no speed carrying it beyond the reading.
      _speed = 0;
      _velocity = Offset.zero;
    }
    _still = !predict;
    _pin(p, t);
    _plan(p, t);
  }

  bool _still = false;

  void _pin(Offset p, double t) {
    _fixed = p;
    _tFixed = t;
  }

  void _plan(Offset p, double t) {
    // The marker follows the trajectory the reading predicts (from where the
    // reading is, at the estimated speed), and the error from where it was
    // shown is absorbed gradually: e^(-t/0.5 s). Continuous, without braking or
    // jumping. The prediction lasts two intervals: the next reading arrives
    // earlier and corrects it; if it does not arrive (no signal), it only stops then.
    final horizon = math.max(2.0, _interval * 2);
    _t0 = t;
    _horizon = horizon;
    _t1 = t + horizon;
    _sLim = null;
    _pLim = null;
    final c = _path;
    if (c != null) {
      final (sFixed, dFixed) = c.project(p);
      // With the reading on the path, the marker goes along the path even if it
      // was seen off it: it is placed near the reading (not on another lap of
      // the route) and the difference is absorbed gradually. In a straight line
      // it would leave along the tangent at the first curve.
      if (dFixed * metersByUnit < 30) {
        final window = 400 / metersByUnit;
        final (sPos, _) = c.project(
          _pos,
          from: sFixed - window,
          until: sFixed + window,
        );
        final lim = _limit;
        if (lim != null) {
          // Do not go past the stop, unless the reading is already beyond it.
          final (sLim, dLim) = c.project(lim);
          if (dLim * metersByUnit < 40 && sFixed <= sLim) _sLim = sLim;
        }
        _byPath = true;
        _s0 = sFixed;
        _errorS = sPos - sFixed;
        _tau = _tauFor(_errorS.abs());
        _t1 = math.max(_t1, t + 3 * _tau);
        // Far ahead (another route, a GPS error): going back is allowed.
        _monotonic = _errorS * metersByUnit < 40;
        _sShown = sPos;
        _detour = _pos - c.point(sPos);
        _tauDetour = _tauFor(_detour.distance);
        _t1 = math.max(_t1, t + 3 * _tauDetour);
        return;
      }
    }
    // No path: straight line at the estimated speed (standing still, if it
    // is), without going past the limit if it is heading toward it.
    _byPath = false;
    _p0 = p;
    _errorP = _pos - p;
    _tau = _tauFor(_errorP.distance);
    _t1 = math.max(_t1, t + 3 * _tau);
    final lim = _limit;
    final v = _velocity.distance;
    if (lim != null && v > 0) {
      final dir = _velocity / v;
      final untilLim = (lim - p).dx * dir.dx + (lim - p).dy * dir.dy;
      if (untilLim >= 0) _pLim = p + dir * untilLim;
    }
    _detour = Offset.zero;
  }

  // Current plan (see [_plan]).
  double _horizon = 2;
  double _tauDetour = 0.5;
  double _errorS = 0;
  double _sShown = 0;
  bool _monotonic = true;
  double? _sLim;
  Offset _errorP = Offset.zero;
  Offset? _pLim;

  /// Places the marker at instant [t].
  void advance(double t) {
    if (_t1 <= _t0) return;
    final dt = (math.min(t, _t1) - _t0).clamp(0.0, double.infinity);
    // The advance is predicted up to the horizon; the correction continues until
    // it is absorbed.
    final dtAdvance = math.min(dt, _horizon);
    final decay = math.exp(-dt / _tau);
    final absorber = math.exp(-dt / _tauDetour);
    final c = _path;
    if (_byPath && c != null) {
      var s = _s0 + _speed * dtAdvance + _errorS * decay;
      final lim = _sLim;
      if (lim != null) s = math.min(s, lim);
      if (_monotonic) s = math.max(s, _sShown);
      s = s.clamp(0.0, c.long);
      if (s - _sShown > 1e-9) _heading = _degrees(c.tangent(s));
      _sShown = s;
      _pos = c.point(s) + _detour * absorber;
    } else {
      final before = _pos;
      var p = _p0 + _velocity * dtAdvance + _errorP * decay;
      final lim = _pLim;
      final v = _velocity.distance;
      if (lim != null && v > 0) {
        final dir = _velocity / v;
        final past = (p - lim).dx * dir.dx + (p - lim).dy * dir.dy;
        if (past > 0) p -= dir * past;
      }
      _pos = p;
      final d = _pos - before;
      if (d.distance * metersByUnit > 0.05 && _velocity != Offset.zero) {
        _heading = _degrees(_velocity);
      }
    }
  }

  static double _degrees(Offset d) =>
      (math.atan2(d.dx, -d.dy) * 180 / math.pi) % 360;
}

/// Polyline with cumulative length, to move by distance traveled.
class _Path {
  final List<Offset> pts;
  final List<double> cum;

  _Path(this.pts) : cum = List.filled(pts.length, 0) {
    for (var i = 1; i < pts.length; i++) {
      cum[i] = cum[i - 1] + (pts[i] - pts[i - 1]).distance;
    }
  }

  double get long => cum.last;

  /// (distance traveled up to the nearest point, lateral distance),
  /// between [desde] and [hasta] (distances traveled) if given.
  (double, double) project(Offset p, {double? from, double? until}) {
    var bestS = 0.0, bestD = double.infinity;
    for (var i = 1; i < pts.length; i++) {
      if (from != null && cum[i] < from) continue;
      if (until != null && cum[i - 1] > until) break;
      final a = pts[i - 1], b = pts[i];
      final ab = b - a;
      final l2 = ab.dx * ab.dx + ab.dy * ab.dy;
      final u =
          l2 == 0
              ? 0.0
              : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / l2).clamp(
                0.0,
                1.0,
              );
      final q = a + ab * u;
      final d = (p - q).distance;
      if (d < bestD) {
        bestD = d;
        bestS = cum[i - 1] + math.sqrt(l2) * u;
      }
    }
    return (bestS, bestD);
  }

  int _leg(double s) {
    var i = 1;
    while (i < pts.length - 1 && cum[i] < s) {
      i++;
    }
    return i;
  }

  Offset point(double s) {
    if (s <= 0) return pts.first;
    if (s >= long) return pts.last;
    final i = _leg(s);
    final l = cum[i] - cum[i - 1];
    final u = l == 0 ? 0.0 : (s - cum[i - 1]) / l;
    return Offset.lerp(pts[i - 1], pts[i], u)!;
  }

  Offset tangent(double s) {
    final i = _leg(s.clamp(0, long));
    return pts[i] - pts[i - 1];
  }
}
