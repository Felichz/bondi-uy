// Map scene: a declarative description of what gets drawn.
//
// `construirEscena` is a pure function of (AppState, UI state). The map
// widget only knows how to paint scenes; this way each phase of the flow has a
// predictable, testable map without rendering.

import 'package:flutter/foundation.dart';

import '../../contract/app_state.dart';
import '../formats.dart';
import '../texts/texts.dart';

enum StrokeStyle {
  /// Walk of the current step / of the focused option.
  walk,

  /// Walk of another step of the trip (context).
  walkFaint,

  /// Bus route of the current step / of the focused option.
  bus,
  busFaint,

  /// Part of the bus route already traveled.
  busDone,

  /// Live bus -> stop (over the GTFS shape).
  approximation,
}

@immutable
class MapStroke {
  final StrokeStyle style;
  final List<Coordinate> points;
  const MapStroke(this.style, this.points);
}

// ---------------------------------------------------------------------------
// Balloons: floating labels anchored to a point on the map
// ---------------------------------------------------------------------------

enum BalloonTone {
  /// White (graphite in dark mode), ink-colored text.
  normal,

  /// Filled with the bus color: the moment to act ("Bajate acá").
  urgent,
}

/// A label floating above a marker, with a pointer toward it.
@immutable
class Balloon {
  final String title;
  final String? detail;

  /// Line badge at the start ("D1").
  final String? line;

  /// Detail in the "live" color, with its pulsing dot.
  final bool live;

  /// Detail in the "scheduled" color.
  final bool scheduled;
  final BalloonTone tone;

  /// If two balloons collide, the one with higher priority wins (the other is
  /// shifted or hidden).
  final int priority;

  const Balloon(
    this.title, {
    this.detail,
    this.line,
    this.live = false,
    this.scheduled = false,
    this.tone = BalloonTone.normal,
    this.priority = 50,
  });
}

// ---------------------------------------------------------------------------
// Markers
// ---------------------------------------------------------------------------

enum StopRole { boarding, alighting }

/// Intermediate stop of a bus route.
enum RouteStopStatus {
  /// Already passed (riding the bus).
  past,

  /// Not yet.
  future,

  /// The next one the bus passes.
  next,
}

@immutable
sealed class MapMarker {
  final Coordinate coordinate;
  final Balloon? balloon;
  const MapMarker(this.coordinate, {this.balloon});

  /// The path a moving marker follows (the street being walked, the
  /// bus route): the map predicts its progress between readings along it.
  List<Coordinate>? get path => null;

  /// The same marker at another position (for moving markers).
  MapMarker movedTo(Coordinate c, {double? heading});
}

class MarkerUser extends MapMarker {
  /// Walking (with a heading arrow if known) or standing still.
  final bool walking;
  final double? heading;
  @override
  final List<Coordinate>? path;

  /// Expected not to move (waiting for the bus, arrived): the map does not
  /// predict its progress, it snaps to each reading.
  final bool still;
  const MarkerUser(
    super.coordinate, {
    this.walking = false,
    this.heading,
    this.path,
    this.still = false,
    super.balloon,
  });

  @override
  MarkerUser movedTo(Coordinate c, {double? heading}) => MarkerUser(
    c,
    walking: walking,
    heading: heading ?? this.heading,
    path: path,
    still: still,
    balloon: balloon,
  );
}

/// The user on board the bus: a single marker, the bus.
class MarkerUserInBus extends MapMarker {
  final String line;
  final double? heading;
  @override
  final List<Coordinate>? path;
  const MarkerUserInBus(
    super.coordinate, {
    required this.line,
    this.heading,
    this.path,
    super.balloon,
  });

  @override
  MarkerUserInBus movedTo(Coordinate c, {double? heading}) => MarkerUserInBus(
    c,
    line: line,
    heading: heading ?? this.heading,
    balloon: balloon,
  );
}

/// An approaching bus (live or scheduled). Its balloon says when it arrives.
class MarkerBus extends MapMarker {
  final String line;
  final bool live;

  /// Minutes left until it arrives (for the edge indicator).
  final int minutes;
  final double? heading;

  /// The stop it is heading to: its movement prediction does not go past it.
  final Coordinate? limit;
  @override
  final List<Coordinate>? path;
  const MarkerBus(
    super.coordinate, {
    required this.line,
    required this.live,
    this.minutes = 0,
    this.heading,
    this.limit,
    this.path,
    super.balloon,
  });

  @override
  MarkerBus movedTo(Coordinate c, {double? heading}) => MarkerBus(
    c,
    line: line,
    live: live,
    minutes: minutes,
    heading: heading ?? this.heading,
    limit: limit,
    path: path,
    balloon: balloon,
  );
}

class MarkerStop extends MapMarker {
  final StopRole role;

  /// true if it is the stop of the current step (highlighted).
  final bool active;

  /// Filled with the bus color: get off at this one.
  final bool urgent;
  const MarkerStop(
    super.coordinate, {
    required this.role,
    this.active = false,
    this.urgent = false,
    super.balloon,
  });

  @override
  MarkerStop movedTo(Coordinate c, {double? heading}) => this;
}

/// Intermediate stop of a bus route.
class MarkerStopRoute extends MapMarker {
  final RouteStopStatus status;
  const MarkerStopRoute(super.coordinate, this.status, {super.balloon});

  @override
  MarkerStopRoute movedTo(Coordinate c, {double? heading}) => this;
}

class MarkerDestination extends MapMarker {
  const MarkerDestination(super.coordinate, {super.balloon});

  @override
  MarkerDestination movedTo(Coordinate c, {double? heading}) => this;
}

class MarkerOrigin extends MapMarker {
  const MarkerOrigin(super.coordinate, {super.balloon});

  @override
  MarkerOrigin movedTo(Coordinate c, {double? heading}) => this;
}

/// Stop tapped while exploring.
class MarkerStopQueried extends MapMarker {
  const MarkerStopQueried(super.coordinate, {super.balloon});

  @override
  MarkerStopQueried movedTo(Coordinate c, {double? heading}) => this;
}

/// Small label over a leg of the option ("🚶 4 min", "D1").
class MarkerLeg extends MapMarker {
  final bool walk;
  final String text;
  const MarkerLeg(super.coordinate, {required this.walk, required this.text});

  @override
  MarkerLeg movedTo(Coordinate c, {double? heading}) => this;
}

/// What the user is looking for now (the stop, the get-off point, the destination).
/// If it is outside the view, an indicator on the edge points toward it.
@immutable
class MapTarget {
  final Coordinate coordinate;
  final String text;

  /// false: only flagged if the user moved the map (on the bus, the
  /// route already shows where it is heading).
  final bool always;
  const MapTarget(this.coordinate, this.text, {this.always = true});
}

@immutable
class MapScene {
  final List<MapStroke> strokes;
  final List<MapMarker> marks;

  /// Stop network: tappable when exploring; faint (context only) during a trip.
  final List<NetworkStop> networkStops;
  final bool networkStopsFaint;
  final MapTarget? target;

  /// Markers halfway through appearing or fading out (by identity; 1 if absent).
  final Map<MapMarker, double> opacities;

  const MapScene({
    this.strokes = const [],
    this.marks = const [],
    this.networkStops = const [],
    this.networkStopsFaint = false,
    this.target,
    this.opacities = const {},
  });

  double opacity(MapMarker m) => opacities[m] ?? 1;

  static const empty = MapScene();

  MapScene copyWith({
    List<MapMarker>? marks,
    List<MapStroke>? strokes,
    Map<MapMarker, double>? opacity,
  }) => MapScene(
    strokes: strokes ?? this.strokes,
    marks: marks ?? this.marks,
    networkStops: networkStops,
    networkStopsFaint: networkStopsFaint,
    target: target,
    opacities: opacity ?? opacities,
  );

  /// Something alive that pulses, moves or floats: the animation clock runs.
  bool get hasHeartbeat =>
      strokes.any((t) => t.style == StrokeStyle.approximation) ||
      marks.any(
        (m) =>
            m.balloon != null ||
            m is MarkerUser ||
            m is MarkerBus ||
            m is MarkerUserInBus ||
            m is MarkerStopQueried ||
            (m is MarkerStop && m.active) ||
            (m is MarkerStopRoute && m.status == RouteStopStatus.next),
      );
}

/// UI state that affects the map (it does not come from the logic).
@immutable
class MapUiStatus {
  /// Option focused in the carousel.
  final String? optionFocused;

  /// During a trip, the camera follows the approaching bus instead of the user.
  final bool showBus;
  const MapUiStatus({this.optionFocused, this.showBus = false});
}

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------

MapScene buildScene(AppState s, MapUiStatus ui) {
  final user = s.location.coordinate;
  final destinationName = switch (s.search.destination) {
    ChosenPlace(:final place) => place.name,
    _ => null,
  };
  switch (s.phase) {
    case ExplorePhase():
      final queried = s.stopQueried;
      return MapScene(
        networkStops: s.stops,
        marks: [
          if (queried != null)
            MarkerStopQueried(
              queried.stop.coordinate,
              balloon: Balloon(
                _short(stopName(queried.stop.name)),
                detail:
                    queried.lines.isEmpty ? null : _linesShort(queried.lines),
                priority: 90,
              ),
            ),
          if (user != null) MarkerUser(user),
        ],
      );

    case final OptionsPhase f:
      final option = _focused(f, ui.optionFocused);
      final marks = <MapMarker>[];
      final strokes = <MapStroke>[];
      if (option != null) {
        _drawOption(
          option,
          strokes,
          marks,
          currentStep: null,
          destinationName: destinationName,
        );
        final bus = f.liveBuses[option.id];
        if (bus != null && bus.position != null) {
          if (bus.approximation != null) {
            strokes.add(
              MapStroke(StrokeStyle.approximation, bus.approximation!),
            );
          }
          marks.add(
            _markerBus(bus, stop: option.firstBus?.boarding.coordinate),
          );
        }
      } else {
        if (f.origin != null) marks.add(MarkerOrigin(f.origin!));
        if (f.destination != null) marks.add(MarkerDestination(f.destination!));
      }
      if (user != null) marks.add(MarkerUser(user));
      return MapScene(strokes: strokes, marks: marks);

    case final TripPhase f:
      final strokes = <MapStroke>[];
      final marks = <MapMarker>[];
      final pos = f.user ?? user;
      if (f.status == TripStatus.completed) {
        return MapScene(
          marks: [
            MarkerDestination(_end(f.option)),
            if (pos != null) MarkerUser(pos, still: true),
          ],
        );
      }
      _drawOption(
        f.option,
        strokes,
        marks,
        currentStep: f.currentStep,
        progress: f.progress,
        destinationName: destinationName,
      );
      final current = f.currentLeg;
      final bus = f.busExpected;
      final boarding = _boarding(f);
      if (bus != null &&
          bus.position != null &&
          current is! BusLeg &&
          boarding == null) {
        if (bus.approximation != null) {
          strokes.add(MapStroke(StrokeStyle.approximation, bus.approximation!));
        }
        marks.add(_markerBus(bus, stop: _stopOfWait(f)));
      }
      if (pos != null) {
        switch (current) {
          case WaitLeg() when boarding != null:
            // Already on board even though the logic has not confirmed it yet:
            // the bus and the user are one (without waiting for the 60 m).
            marks.add(
              MarkerUserInBus(
                pos,
                line: boarding.line,
                path: boarding.geometry,
              ),
            );
          case BusLeg(:final line, :final geometry):
            marks.add(MarkerUserInBus(pos, line: line, path: geometry));
          case WalkLeg(:final geometry):
            marks.add(MarkerUser(pos, walking: true, path: geometry));
          case WaitLeg():
            marks.add(MarkerUser(pos, still: true));
        }
      }
      return MapScene(
        strokes: strokes,
        marks: marks,
        networkStops: s.stops,
        networkStopsFaint: true,
        target: _target(f, destinationName),
      );
  }
}

/// The stop where the bus for the current or next step is awaited.
Coordinate? _stopOfWait(TripPhase f) {
  for (final i in [f.currentStep, f.currentStep + 1]) {
    if (i >= f.totalSteps) break;
    final t = f.option.legs[i];
    if (t is WaitLeg) return t.stop.coordinate;
  }
  return null;
}

/// Meters the user must move away from the stop, with their bus there, to
/// show them already on board.
const metersBoarding = 25;

/// The bus of the next step if the user is already leaving on it: its bus
/// is at the stop and the user has moved away from it.
BusLeg? _boarding(TripPhase f) {
  final t = f.currentLeg;
  if (t is! WaitLeg || f.currentStep + 1 >= f.totalSteps) return null;
  final bus = f.busExpected;
  final far = f.progress.metersLeft;
  if (bus == null || far == null) return null;
  final inTheStop = bus.minutes == 0 && (bus.metersUntilStop ?? 0) <= 30;
  if (!inTheStop || far < metersBoarding) return null;
  final next = f.option.legs[f.currentStep + 1];
  return next is BusLeg ? next : null;
}

MarkerBus _markerBus(BusInPath bus, {Coordinate? stop}) => MarkerBus(
  bus.position!,
  line: bus.line,
  live: bus.live,
  minutes: bus.minutes,
  heading: bus.heading,
  limit: stop,
  path: bus.path ?? bus.approximation,
  balloon: Balloon(
    bus.minutes <= 0 ? tx.arriving : tx.arrivesIn(minutes(bus.minutes)),
    line: bus.line,
    detail: [
      bus.live ? tx.liveUpper : tx.scheduleUpper,
      if (bus.metersUntilStop != null)
        tx.toDistance(distance(bus.metersUntilStop!)),
    ].join(' · '),
    live: bus.live,
    scheduled: !bus.live,
    priority: 100,
  ),
);

/// What is sought in the current step, to flag it if it leaves the view.
MapTarget? _target(TripPhase f, String? destinationName) {
  final rest = f.progress.metersLeft;
  final a = rest == null ? '' : ' · ${distance(rest)}';
  return switch (f.currentLeg) {
    WalkLeg(:final towardStop, :final end) =>
      towardStop != null
          ? MapTarget(towardStop.coordinate, '${tx.yourStop}$a')
          : MapTarget(end, '${tx.yourDestination}$a'),
    WaitLeg(:final stop) => MapTarget(stop.coordinate, tx.yourStop),
    BusLeg(:final alighting) => MapTarget(
      alighting.coordinate,
      '${tx.youGetOff}$a',
      always: false,
    ),
  };
}

TripOption? _focused(OptionsPhase f, String? id) {
  if (f.options.isEmpty) return null;
  for (final o in f.options) {
    if (o.id == id) return o;
  }
  return f.options.firstWhere(
    (o) => o.recommended,
    orElse: () => f.options.first,
  );
}

/// Strokes, stops and balloons of an option. With [currentStep] (during a trip)
/// that step is highlighted, what is done is dimmed or disappears, and what
/// comes next stays as context.
void _drawOption(
  TripOption o,
  List<MapStroke> strokes,
  List<MapMarker> marks, {
  required int? currentStep,
  ProgressStep? progress,
  String? destinationName,
}) {
  final inTrip = currentStep != null;
  final faintFirst = <MapStroke>[];
  final activeStrokes = <MapStroke>[];
  for (var i = 0; i < o.legs.length; i++) {
    final t = o.legs[i];
    final active = !inTrip || currentStep == i;
    // What is already done is not drawn: only what remains.
    if (inTrip && i < currentStep) continue;
    switch (t) {
      case WalkLeg():
        final points =
            (currentStep == i && progress?.routeRemaining != null)
                ? progress!.routeRemaining!
                : t.geometry;
        (active ? activeStrokes : faintFirst).add(
          MapStroke(active ? StrokeStyle.walk : StrokeStyle.walkFaint, points),
        );
      case BusLeg():
        if (currentStep == i) {
          // On the bus: the whole route, gray, underneath; what remains
          // (from where the bus is, measured by the logic) in red on top,
          // covering it. The gray that shows is what has been done.
          faintFirst.add(MapStroke(StrokeStyle.busDone, t.geometry));
          final rest = progress?.routeRemaining;
          if (rest != null && rest.length >= 2) {
            activeStrokes.add(MapStroke(StrokeStyle.bus, rest));
          } else if (progress?.metersLeft == null) {
            // Just boarded and not measured yet: everything ahead.
            activeStrokes.add(MapStroke(StrokeStyle.bus, t.geometry));
          }
          continue;
        }
        final highlight =
            active || currentStep == i - 1; // waiting for this bus
        (highlight ? activeStrokes : faintFirst).add(
          MapStroke(
            highlight ? StrokeStyle.bus : StrokeStyle.busFaint,
            t.geometry,
          ),
        );
      case WaitLeg():
        break;
    }
  }
  strokes
    ..addAll(faintFirst)
    ..addAll(activeStrokes);

  // Leg labels in the preview: how long the walk is, which line.
  if (!inTrip) {
    for (final t in o.legs) {
      switch (t) {
        case WalkLeg(:final geometry, :final durationSeconds):
          if (durationSeconds < 90) continue;
          marks.add(
            MarkerLeg(
              _middle(geometry),
              walk: true,
              text: '${(durationSeconds / 60).round()} min',
            ),
          );
        case BusLeg(:final geometry, :final line):
          marks.add(MarkerLeg(_middle(geometry), walk: false, text: line));
        case WaitLeg():
          break;
      }
    }
  }

  // Stops of each bus that still matters.
  var firstBus = true;
  for (var i = 0; i < o.legs.length; i++) {
    final t = o.legs[i];
    if (t is! BusLeg) continue;
    final isFirst = firstBus;
    firstBus = false;
    if (inTrip && i < currentStep) continue;
    final onBoard = currentStep == i;
    // Waiting for this bus or walking toward its stop.
    final toward = inTrip && (currentStep == i - 1 || currentStep == i - 2);
    final missing = onBoard ? progress?.stopsLeft : null;
    final next = onBoard ? progress?.nextStop : null;
    final last = onBoard && missing == 0;

    // Intermediate stops: route context; on the bus, the ones already
    // passed are dimmed and the next one is highlighted.
    final idxNext =
        next == null
            ? -1
            : t.stopsIntermediate.indexWhere((p) => p.id == next.id);
    for (var k = 0; k < t.stopsIntermediate.length; k++) {
      final p = t.stopsIntermediate[k];
      final status =
          !onBoard
              ? RouteStopStatus.future
              : idxNext < 0
              ? (next != null && next.id == t.alighting.id
                  ? RouteStopStatus.past
                  : RouteStopStatus.future)
              : k < idxNext
              ? RouteStopStatus.past
              : k == idxNext
              ? RouteStopStatus.next
              : RouteStopStatus.future;
      marks.add(
        MarkerStopRoute(
          p.coordinate,
          status,
          balloon:
              status == RouteStopStatus.next
                  ? Balloon(
                    _short(stopName(p.name)),
                    detail: tx.nextStopUpper,
                    priority: 70,
                  )
                  : null,
        ),
      );
    }

    marks.add(
      MarkerStop(
        t.boarding.coordinate,
        role: StopRole.boarding,
        active: toward,
        balloon:
            (toward || (!inTrip && isFirst))
                ? Balloon(
                  isFirst ? tx.boardOn(t.line) : tx.changeAt(t.line),
                  detail: _short(stopName(t.boarding.name)),
                  priority: 80,
                )
                : (!inTrip)
                ? Balloon(tx.changeAt(t.line), priority: 55)
                : null,
      ),
    );
    marks.add(
      MarkerStop(
        t.alighting.coordinate,
        role: StopRole.alighting,
        active: onBoard,
        urgent: last,
        balloon:
            onBoard
                ? Balloon(
                  last ? tx.getOffHere : tx.youGetOffHere,
                  detail:
                      last
                          ? tx.ringsTheBellUpper
                          : missing == null
                          ? _short(stopName(t.alighting.name))
                          : tx.inStops(stops(missing + 1)),
                  tone: last ? BalloonTone.urgent : BalloonTone.normal,
                  priority: 95,
                )
                : null,
      ),
    );
  }

  final last = o.legs.last;
  final arrivingOnFoot =
      last is WalkLeg && inTrip && currentStep == o.legs.length - 1;
  marks.add(
    MarkerDestination(
      _end(o),
      balloon:
          !inTrip
              ? Balloon(tx.arrive(time(o.arrival)), priority: 60)
              : arrivingOnFoot
              ? Balloon(
                destinationName == null
                    ? tx.yourDestination
                    : _short(destinationName),
                detail: tx.yourDestinationUpper,
                priority: 90,
              )
              : null,
    ),
  );
  if (!inTrip) {
    final first = o.legs.first;
    marks.add(
      MarkerOrigin(switch (first) {
        WalkLeg(:final geometry) => geometry.first,
        WaitLeg(:final stop) => stop.coordinate,
        BusLeg(:final boarding) => boarding.coordinate,
      }),
    );
  }
}

Coordinate _end(TripOption o) => switch (o.legs.last) {
  WalkLeg(:final end) => end,
  BusLeg(:final alighting) => alighting.coordinate,
  WaitLeg(:final stop) => stop.coordinate,
};

/// Point halfway along a polyline (by vertex count, enough to place a label).
Coordinate _middle(List<Coordinate> g) => g[g.length ~/ 2];

/// Stop names are long ("Bv Gral Artigas - Lord Ponsomby"): in a balloon
/// they get trimmed.
String _short(String s, {int max = 24}) =>
    s.length <= max ? s : '${s.substring(0, max - 1).trimRight()}…';

String _linesShort(List<String> lines) {
  const max = 5;
  final views = lines.take(max).join(' · ');
  return lines.length > max ? '$views +${lines.length - max}' : views;
}
