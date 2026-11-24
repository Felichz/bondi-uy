// Trip navigator: sample by GPS sample, it decides which step the user is on
// and how much is left. It is pure and deterministic (no timers or I/O): the
// same sequence of samples always produces the same sequence of steps.
//
// A single detection path per step type:
//   walk    -> reached the end of the walk (geofence + confirmation)
//   wait    -> moving ON the bus route, in the direction of travel and at
//              vehicle speed (boarded)
//   bus     -> reached the alighting stop
// Also, if the user "jumps ahead" (e.g. the GPS missed the boarding and they
// are already on the bus), the navigator jumps forward; it never goes back.

import 'dart:math' as math;

import '../../contract/app_state.dart';
import '../geo/geo.dart';
import '../ports.dart';

class NavigationRules {
  /// Arrival at a stop on foot.
  final double radioStop;

  /// Arrival at the final destination.
  final double radioDestination;

  /// Alighting: distance to the alighting stop.
  final double radiusAlighting;

  /// Maximum lateral distance from the bus route to consider that the user is
  /// on board.
  final double corridorBus;

  /// Meters traveled along the line (from the stop) to confirm boarding.
  final double advanceBoarding;

  /// Minimum speed (m/s) of a moving bus (~9 km/h).
  final double speedBus;

  /// Consecutive samples that confirm a step advance.
  final int confirmations;

  /// Samples with worse accuracy are ignored.
  final double precisionMax;

  const NavigationRules({
    this.radioStop = 25,
    this.radioDestination = 30,
    this.radiusAlighting = 40,
    this.corridorBus = 40,
    this.advanceBoarding = 60,
    this.speedBus = 2.5,
    this.confirmations = 2,
    this.precisionMax = 80,
  });
}

/// Result of processing a sample.
class NavigationStatus {
  final int step;
  final ProgressStep progress;
  final bool completed;

  /// true if this sample advanced the step.
  final bool advanced;

  const NavigationStatus({
    required this.step,
    required this.progress,
    required this.completed,
    required this.advanced,
  });
}

class TripNavigator {
  final TripOption option;
  final NavigationRules rules;
  final List<Polyline?> _lines;

  int _step = 0;
  bool _completed = false;
  int _confirmadas = 0;
  int? _pasoCandidato;
  double? _metersTotalsStep;
  double _routePrevious = 0;
  LocationSample? _anterior;
  ProgressStep _progress = ProgressStep.empty;

  TripNavigator(this.option, {this.rules = const NavigationRules()})
    : _lines = [
        for (final t in option.legs)
          switch (t) {
            WalkLeg(:final geometry) => Polyline(geometry),
            BusLeg(:final geometry) => Polyline(geometry),
            WaitLeg() => null,
          },
      ];

  int get step => _step;
  bool get completed => _completed;
  ProgressStep get progress => _progress;

  NavigationStatus get status => NavigationStatus(
    step: _step,
    progress: _progress,
    completed: _completed,
    advanced: false,
  );

  /// Manual advance ("Ya subí" and "Ya llegué": "I got on", "I arrived").
  NavigationStatus confirmStep() {
    if (_completed) return status;
    _irTo(_step + 1);
    if (_anterior != null && !_completed) {
      _progress = _medir(_anterior!);
    }
    return NavigationStatus(
      step: _step,
      progress: _progress,
      completed: _completed,
      advanced: true,
    );
  }

  NavigationStatus process(LocationSample m) {
    if (_completed) return status;
    if (m.precision != null && m.precision! > rules.precisionMax) {
      return status;
    }
    final velocity = m.velocity ?? _speedEstimated(m);
    _anterior = m;

    final destination = _detectar(m.coordinate, velocity);
    var advanced = false;
    if (destination != null && destination > _step) {
      if (_pasoCandidato == destination) {
        _confirmadas++;
      } else {
        _pasoCandidato = destination;
        _confirmadas = 1;
      }
      final necesarias = _confirmationsPara(m.coordinate);
      if (_confirmadas >= necesarias) {
        _irTo(destination);
        advanced = true;
      }
    } else {
      _pasoCandidato = null;
      _confirmadas = 0;
    }

    if (!_completed) _progress = _medir(m);
    return NavigationStatus(
      step: _step,
      progress: _progress,
      completed: _completed,
      advanced: advanced,
    );
  }

  // --- Detection --------------------------------------------------------

  /// Step this sample would advance to, or null.
  int? _detectar(Coordinate c, double? velocity) {
    final leg = option.legs[_step];
    switch (leg) {
      case WalkLeg():
        final radio =
            leg.isAtDestination ? rules.radioDestination : rules.radioStop;
        if (distance(c, leg.fin) <= radio) return _step + 1;
        // Did they jump ahead and already travel on the next bus?
        final jumpBus = _stepBusSiTravels(c, velocity, from: _step + 1);
        if (jumpBus != null) return jumpBus;
        final far =
            _lines[_step]!.project(c).distanceLateral > rules.corridorBus;
        return far ? _ahead(c, velocity) : null;
      case WaitLeg():
        final bus = option.legs[_step + 1] as BusLeg;
        final line = _lines[_step + 1]!;
        if (distance(c, bus.alighting.coordinate) <= rules.radiusAlighting) {
          return _step +
              2; // We missed the whole ride: already arrived at the alighting stop.
        }
        if (_travelsOver(line, c, velocity)) return _step + 1;
        final far = distance(c, leg.stop.coordinate) > 100;
        return far ? _ahead(c, velocity) : null;
      case BusLeg():
        final line = _lines[_step]!;
        final p = line.project(c, from: _routePrevious - 100);
        // Got off: at the end of the route or next to the alighting stop, with
        // the bus stopped (or already on foot). While the bus is still moving
        // the user is still on board: they are not marked as off a few meters
        // before the stop.
        final onFinal =
            p.distanceLateral <= rules.corridorBus && line.long - p.route <= 20;
        final inTheAlighting =
            distance(c, leg.alighting.coordinate) <= rules.radiusAlighting;
        final moving = velocity != null && velocity >= rules.speedBus;
        if ((onFinal || inTheAlighting) && !moving) return _step + 1;
        // Had already reached the alighting point and now walks: got off, even
        // if between two readings it moved away from the stop along the same street.
        if (line.long - _routePrevious <= 20 &&
            velocity != null &&
            velocity < rules.speedBus) {
          return _step + 1;
        }
        // Got off between two readings (GPS cut off, app suspended, readings
        // far apart): no longer on the bus route.
        if (p.distanceLateral > rules.corridorBus) {
          return _ahead(c, velocity);
        }
        return null;
    }
  }

  /// The user is no longer where the current step says: between two readings
  /// one or more steps were passed. The first later step that matches where
  /// they are and how they move (riding a bus, walking, waiting at a stop),
  /// or the end if they already reached the destination.
  int? _ahead(Coordinate c, double? velocity) {
    final moving = velocity != null && velocity >= rules.speedBus;
    for (var j = _step + 1; j < option.legs.length; j++) {
      final t = option.legs[j];
      switch (t) {
        case BusLeg():
          if (_travelsOver(_lines[j]!, c, velocity)) return j;
        case WalkLeg():
          if (moving) continue;
          if (t.isAtDestination &&
              distance(c, t.fin) <= rules.radioDestination) {
            return j + 1;
          }
          if (_lines[j]!.project(c).distanceLateral <= rules.corridorBus) {
            return j;
          }
        case WaitLeg():
          if (!moving && distance(c, t.stop.coordinate) <= rules.radioStop) {
            return j;
          }
      }
    }
    return null;
  }

  bool _travelsOver(Polyline line, Coordinate c, double? velocity) {
    final p = line.project(c);
    if (p.distanceLateral > rules.corridorBus) return false;
    if (p.route < rules.advanceBoarding) return false;
    // Without a reported speed it cannot be told apart from someone walking on
    // the sidewalk: double the advance is required.
    if (velocity == null) return p.route >= rules.advanceBoarding * 2;
    return velocity >= rules.speedBus;
  }

  int? _stepBusSiTravels(Coordinate c, double? velocity, {required int from}) {
    for (var i = from; i < option.legs.length; i++) {
      final t = option.legs[i];
      if (t is BusLeg) {
        return _travelsOver(_lines[i]!, c, velocity) ? i : null;
      }
      if (t is WalkLeg) return null; // Only the next bus.
    }
    return null;
  }

  int _confirmationsPara(Coordinate c) {
    // Very close to the target, one sample is enough.
    final leg = option.legs[_step];
    if (leg is WalkLeg && distance(c, leg.fin) <= 10) return 1;
    return rules.confirmations;
  }

  void _irTo(int step) {
    _confirmadas = 0;
    _pasoCandidato = null;
    _metersTotalsStep = null;
    _routePrevious = 0;
    if (step >= option.legs.length) {
      _step = option.legs.length - 1;
      _completed = true;
      _progress = const ProgressStep(metersRestantes: 0);
      return;
    }
    _step = step;
    _progress = ProgressStep.empty;
  }

  double? _speedEstimated(LocationSample m) {
    final a = _anterior;
    if (a == null) return null;
    final dt = m.moment.difference(a.moment).inMilliseconds / 1000.0;
    if (dt <= 0.5) return null;
    return distance(a.coordinate, m.coordinate) / dt;
  }

  // --- Measurement ---------------------------------------------------------

  ProgressStep _medir(LocationSample m) {
    final c = m.coordinate;
    final leg = option.legs[_step];
    switch (leg) {
      case WalkLeg():
        final line = _lines[_step]!;
        final p = line.project(c, from: math.max(0, _routePrevious - 60));
        _routePrevious = p.route;
        final rest = line.leg(p.route, line.long);
        final route = [if (p.distanceLateral > 3) c, ...rest];
        final restante = (line.long - p.route) + p.distanceLateral;
        _metersTotalsStep ??= math.max(restante, 1);
        return ProgressStep(
          metersRestantes: restante.round(),
          metersTotals: _metersTotalsStep!.round(),
          routeRemaining: route.length >= 2 ? route : [c, leg.fin],
        );
      case WaitLeg():
        return ProgressStep(
          metersRestantes: distance(c, leg.stop.coordinate).round(),
        );
      case BusLeg():
        final line = _lines[_step]!;
        final p = line.project(c, from: math.max(0, _routePrevious - 100));
        _routePrevious = math.max(_routePrevious, p.route);
        final restante = line.long - _routePrevious;
        _metersTotalsStep ??= line.long;
        var missing = 0;
        Stop? next;
        for (final s in leg.stopsIntermediate) {
          final ps = line.project(s.coordinate);
          if (ps.route > _routePrevious + 15) {
            missing++;
            next ??= s;
          }
        }
        return ProgressStep(
          metersRestantes: restante.round(),
          metersTotals: _metersTotalsStep!.round(),
          // From where the bus is (progress that never goes back) to the alighting stop.
          routeRemaining:
              restante > 1 ? line.leg(_routePrevious, line.long) : null,
          stopsRestantes: missing,
          nextStop: next ?? leg.alighting,
        );
    }
  }
}
