// What the camera must show at each moment of the flow (a UI concern).
//
// Each moment focuses on a GROUP of elements (the specification of the previous
// version, old/v2/test/devtools/CAMERA_BEHAVIOR_SPEC.md):
//
// - Options: the whole trip (and the live bus if it appears).
// - Walking to the stop: you + what is left to walk + the stop; already close to
//   the stop (60 m), also the bus if it arrives in 5 min or less, and the set
//   stays readable. Meanwhile the bus is marked at the edge.
// - Waiting: the stop + the bus + you (the zoom tightens as the bus
//   gets closer).
// - On the bus: you + the next stops; near the end, the drop-off. (Not
//   the whole route: that would mean zooming out 20 km.)
// - Walking to the destination: you + what is left to walk + the destination.
// - If viewing the bus was chosen (walking to the stop or waiting): the bus that
//   is coming + the stop it is heading to, following the bus. You may end up
//   out of view.
//
// During a trip the framing is recalculated frame by frame with the predicted
// positions of the user and the bus, so it follows without jumps. If the group does not
// fit at the minimum zoom, the user takes priority ([Encuadre.ancla]): the camera
// shifts toward the group without leaving the user out of view.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../contract/app_state.dart';
import 'scene.dart';

/// How the camera follows a framing while the state changes.
enum Tracking {
  /// Frames once, when the [Encuadre.key] changes.
  none,

  /// Re-frames only if some point falls out of view (options).
  ifExiting,

  /// Re-frames continuously and smoothly (trip).
  continuous,
}

/// Moving markers a framing may include (their position is known to the
/// map, which predicts it between readings).
abstract final class Vehicles {
  static const user = 'user';
  static const bus = 'bus';
}

@immutable
class Framing {
  /// Changes when the context changes (phase, option, step): the camera re-frames
  /// even if the user has moved it.
  final String key;

  /// Fixed points of the group (stops, routes, destination).
  final List<Coordinate> points;

  /// Moving markers of the group ([Moviles]).
  final Set<String> vehicles;

  /// Desirable movers: included if the group stays readable (zoom
  /// [zoomExtras] or more); otherwise only the essentials are focused.
  final Set<String> extras;
  final double zoomExtras;

  /// The mover that must never be left out of view.
  final String? anchor;
  final Tracking tracking;
  final double zoomMax;

  /// Minimum zoom with [ancla]: if the group does not fit, seeing the anchor
  /// well takes priority (an edge indicator marks what was left out).
  final double zoomMin;

  /// If the user moved the map, the camera comes back on its own after this time
  /// without touching it (trips only: nobody should lose the thread of their trip).
  final Duration? resumeAfter;

  const Framing({
    required this.key,
    required this.points,
    this.vehicles = const {},
    this.extras = const {},
    this.zoomExtras = 14.5,
    this.anchor,
    this.tracking = Tracking.none,
    this.zoomMax = 17,
    this.zoomMin = 10,
    this.resumeAfter,
  });
}

const _resumeTrip = Duration(seconds: 12);

/// A bus at this distance in minutes (or less) enters the framing of the
/// walk to the stop...
const minutesBusNear = 5;

/// ...only when the user is this many meters from the stop. Before that,
/// the path is what matters; the bus is marked at the screen edge.
const metersToSeeBus = 60;

Framing? framingOf(AppState s, MapUiStatus ui) {
  final user = s.location.coordinate;
  switch (s.phase) {
    case ExplorePhase():
      final p = s.stopQueried;
      if (p != null) {
        return Framing(key: 'stop-${p.stop.id}', points: [p.stop.coordinate]);
      }
      if (user != null) {
        return Framing(key: 'explore', points: [user], zoomMax: 16);
      }
      return null;

    case final OptionsPhase f:
      if (f.options.isEmpty) {
        final pts = [
          if (f.origin != null) f.origin!,
          if (f.destination != null) f.destination!,
        ];
        return pts.isEmpty
            ? null
            : Framing(key: 'options-${f.status.name}', points: pts);
      }
      final o = f.options.firstWhere(
        (o) => o.id == ui.optionFocused,
        orElse:
            () => f.options.firstWhere(
              (o) => o.recommended,
              orElse: () => f.options.first,
            ),
      );
      return Framing(
        key: 'option-${o.id}',
        // If the live bus appears outside the view, it re-frames.
        tracking: Tracking.ifExiting,
        points: [
          ..._pointsOption(o),
          if (f.liveBuses[o.id]?.position case final b?) b,
        ],
      );

    case final TripPhase f:
      final pos = f.user ?? user;
      if (f.status == TripStatus.completed) {
        return Framing(
          key: 'arrival',
          points: [_end(f.option), if (pos != null) pos],
          zoomMax: 17,
        );
      }
      final t = f.currentLeg;
      final key = 'step-${f.currentStep}';
      if (followingOnBus(f, ui)) {
        final bus = f.busExpected!;
        return Framing(
          key: '$key-bus',
          points: [if (_stopThatComes(f) case final p?) p],
          vehicles: const {Vehicles.bus},
          anchor: Vehicles.bus,
          tracking: Tracking.continuous,
          // When far away, the bus is what is shown (the stop is marked at the edge).
          zoomMin: bus.minutes > 6 ? 13.5 : 14.5,
          zoomMax: 17,
          resumeAfter: _resumeTrip,
        );
      }
      final withUser = pos != null;
      Framing trip(
        List<Coordinate> points, {
        Set<String> vehicles = const {},
        Set<String> extras = const {},
        required double zoomMin,
        required double zoomMax,
      }) => Framing(
        key: key,
        points: [...points, if (!withUser && points.isEmpty) _end(f.option)],
        vehicles: {if (withUser) Vehicles.user, ...vehicles},
        extras: extras,
        anchor: withUser ? Vehicles.user : null,
        tracking: Tracking.continuous,
        zoomMin: zoomMin,
        zoomMax: zoomMax,
        resumeAfter: _resumeTrip,
      );
      switch (t) {
        case WalkLeg():
          final bus = f.busExpected;
          final rest = f.progress.metersLeft;
          final busNear =
              !t.isAtDestination &&
              rest != null &&
              rest <= metersToSeeBus &&
              bus?.position != null &&
              bus!.minutes <= minutesBusNear;
          return trip(
            [..._sample(f.progress.routeRemaining ?? t.geometry), t.end],
            extras: {if (busNear) Vehicles.bus},
            zoomMin: 15,
            zoomMax: 17.5,
          );
        case WaitLeg():
          // Also, the start of the bus route: when the bus arrives and
          // stops "coming", the framing does not collapse onto the stop, and already
          // looks like the next step's (boarding does not produce two jumps).
          final next =
              f.currentStep + 1 < f.totalSteps
                  ? f.option.legs[f.currentStep + 1]
                  : null;
          return trip(
            [
              t.stop.coordinate,
              if (next is BusLeg) ..._firstMeters(next.geometry, 350),
            ],
            vehicles: {if (f.busExpected?.position != null) Vehicles.bus},
            zoomMin: 14,
            zoomMax: 17,
          );
        case BusLeg():
          final missing = f.progress.stopsLeft;
          final next = f.progress.nextStop ?? t.alighting;
          final i = t.stopsIntermediate.indexWhere((p) => p.id == next.id);
          final following =
              i >= 0 && i + 1 < t.stopsIntermediate.length
                  ? t.stopsIntermediate[i + 1]
                  : null;
          return trip(
            [
              next.coordinate,
              if (following != null) following.coordinate,
              if (missing != null && missing <= 3) t.alighting.coordinate,
            ],
            zoomMin: 14.5,
            zoomMax: 17,
          );
      }
  }
}

/// The bus can be followed: the user is walking to the stop or waiting for it,
/// and there is a bus with a known position on its way.
bool canSeeBus(TripPhase f) =>
    f.status == TripStatus.inProgress &&
    f.currentLeg is! BusLeg &&
    f.busExpected?.position != null &&
    _stopThatComes(f) != null;

/// The camera follows the bus: it was chosen and it is possible.
bool followingOnBus(TripPhase f, MapUiStatus ui) => ui.showBus && canSeeBus(f);

/// The stop where the incoming bus is boarded (the current step's stop or the next
/// one, walking toward it).
Coordinate? _stopThatComes(TripPhase f) {
  for (final i in [f.currentStep, f.currentStep + 1]) {
    if (i >= f.totalSteps) break;
    final t = f.option.legs[i];
    if (t is WaitLeg) return t.stop.coordinate;
  }
  return null;
}

List<Coordinate> _pointsOption(TripOption o) => [
  for (final t in o.legs)
    ...switch (t) {
      WalkLeg(:final geometry) => _sample(geometry),
      BusLeg(:final geometry) => _sample(geometry),
      WaitLeg(:final stop) => [stop.coordinate],
    },
];

/// The first [metros] of [g] (flat approximation, good enough at this scale).
List<Coordinate> _firstMeters(List<Coordinate> g, double meters) {
  final r = <Coordinate>[g.first];
  var total = 0.0;
  for (var i = 1; i < g.length && total < meters; i++) {
    final dy = (g[i].lat - g[i - 1].lat) * 111320;
    final dx = (g[i].lng - g[i - 1].lng) * 111320 * 0.82;
    total += math.sqrt(dx * dx + dy * dy);
    r.add(g[i]);
  }
  return r;
}

List<Coordinate> _sample(List<Coordinate> g) {
  if (g.length <= 20) return g;
  final step = g.length ~/ 20;
  return [for (var i = 0; i < g.length; i += step) g[i], g.last];
}

Coordinate _end(TripOption o) => switch (o.legs.last) {
  WalkLeg(:final end) => end,
  BusLeg(:final alighting) => alighting.coordinate,
  WaitLeg(:final stop) => stop.coordinate,
};
