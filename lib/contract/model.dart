// Domain types that cross the UI <-> logic contract.
//
// Contract rules:
// - Raw data only: numbers, enums, coordinates, proper names (streets,
//   stops, lines). Never presentational text or formats ("5 min").
// - Immutable. Logic creates new instances; the UI only reads them.
// - No Mapbox, colors, widgets or styles.

import 'package:flutter/foundation.dart' show immutable, listEquals;

@immutable
class Coordinate {
  final double lat;
  final double lng;

  const Coordinate(this.lat, this.lng)
    : assert(lat >= -90 && lat <= 90, 'latitude out of range'),
      assert(lng >= -180 && lng <= 180, 'longitude out of range');

  @override
  bool operator ==(Object other) =>
      other is Coordinate && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() =>
      'Coordinate(${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})';
}

/// A place that can be chosen as origin or destination (search suggestion).
@immutable
class Place {
  final String id;

  /// Main name ("Plaza Independencia", "Av. Brasil 2550").
  final String name;

  /// Optional context ("Ciudad Vieja, Montevideo").
  final String? detail;
  final Coordinate coordinate;

  const Place({
    required this.id,
    required this.name,
    this.detail,
    required this.coordinate,
  });

  @override
  bool operator ==(Object other) =>
      other is Place &&
      other.id == id &&
      other.name == name &&
      other.detail == detail &&
      other.coordinate == coordinate;

  @override
  int get hashCode => Object.hash(id, name, detail, coordinate);
}

@immutable
class Stop {
  final String id;
  final String name;
  final Coordinate coordinate;

  const Stop({required this.id, required this.name, required this.coordinate});

  @override
  bool operator ==(Object other) =>
      other is Stop && other.id == id && other.coordinate == coordinate;

  @override
  int get hashCode => Object.hash(id, coordinate);
}

/// A stop on the exploration map, with the lines that serve it.
@immutable
class NetworkStop {
  final Stop stop;
  final List<String> lines;

  const NetworkStop({required this.stop, required this.lines});
}

/// Next arrival of a bus at a stop.
@immutable
class BusArrival {
  final String line;

  /// Bus destination as reported by the source ("PLAZA INDEPENDENCIA").
  final String? destination;
  final int minutes;

  /// true = real-time position/ETA; false = scheduled timetable.
  final bool live;
  final Coordinate? position;

  const BusArrival({
    required this.line,
    this.destination,
    required this.minutes,
    required this.live,
    this.position,
  }) : assert(minutes >= 0);
}

/// A specific bus heading to a stop, with the street geometry it follows
/// until it arrives. [aproximacion] is null when no real geometry exists:
/// the UI must never invent a straight line.
@immutable
class BusInPath {
  final String line;

  /// null when only the timetable is known (no GPS for the bus).
  final Coordinate? position;
  final int minutes;
  final bool live;

  /// Route from bus to stop along the GTFS shape, in direction of travel.
  final List<Coordinate>? approximation;

  /// Where it comes from: the line's route from a segment before the bus
  /// (where it passed a while ago) up to the stop. Between one reading and the
  /// next, the bus moves along here.
  final List<Coordinate>? path;

  /// Meters the bus still has to travel to arrive, along the street.
  final int? metersUntilStop;

  /// Bus heading (degrees, 0 = north) from the shape, if known.
  final double? heading;

  const BusInPath({
    required this.line,
    this.position,
    required this.minutes,
    required this.live,
    this.approximation,
    this.path,
    this.metersUntilStop,
    this.heading,
  }) : assert(approximation == null || position != null);
}

// ---------------------------------------------------------------------------
// Trips
// ---------------------------------------------------------------------------

/// A leg of the trip. There are only three types (the app's view):
/// walking, waiting for the bus and riding the bus.
@immutable
sealed class Leg {
  final String id;
  const Leg(this.id);
}

@immutable
class WalkLeg extends Leg {
  final List<Coordinate> geometry;
  final int distanceMeters;
  final int durationSeconds;

  /// Stop being walked to; null if walking to the final destination.
  final Stop? towardStop;

  // The assertions validate data at runtime: this cannot be const.
  // ignore: prefer_const_constructors_in_immutables
  WalkLeg({
    required String id,
    required this.geometry,
    required this.distanceMeters,
    required this.durationSeconds,
    this.towardStop,
  }) : assert(geometry.length >= 2, 'walk leg without geometry'),
       super(id);

  bool get isAtDestination => towardStop == null;
  Coordinate get end => geometry.last;
}

@immutable
class WaitLeg extends Leg {
  final Stop stop;
  final String line;
  final String? destinationLine;

  /// Wait according to the plan (timetables), not live.
  final int waitScheduledSeconds;

  const WaitLeg({
    required String id,
    required this.stop,
    required this.line,
    this.destinationLine,
    required this.waitScheduledSeconds,
  }) : super(id);
}

@immutable
class BusLeg extends Leg {
  final String line;
  final String? destinationLine;
  final Stop boarding;
  final Stop alighting;

  /// Stops between boarding and alighting (both excluded), in travel order.
  final List<Stop> stopsIntermediate;
  final List<Coordinate> geometry;
  final int distanceMeters;
  final int durationSeconds;

  // ignore: prefer_const_constructors_in_immutables
  BusLeg({
    required String id,
    required this.line,
    this.destinationLine,
    required this.boarding,
    required this.alighting,
    required this.stopsIntermediate,
    required this.geometry,
    required this.distanceMeters,
    required this.durationSeconds,
  }) : assert(geometry.length >= 2, 'bus leg without geometry'),
       super(id);
}

/// Possible warnings for an option. The UI decides the text.
enum NoticeOption {
  longWalk,
  transferAdjusted,
  withoutLiveDataFirstBus,
  firstBusMayNotReach,
}

@immutable
class TripOption {
  final String id;
  final int durationSeconds;
  final DateTime exit;
  final DateTime arrival;
  final int walkMeters;
  final int transfers;
  final bool recommended;
  final List<Leg> legs;

  /// Next bus of the first line at the boarding stop, if known.
  final BusArrival? nextBus;
  final NoticeOption? notice;

  // ignore: prefer_const_constructors_in_immutables
  TripOption({
    required this.id,
    required this.durationSeconds,
    required this.exit,
    required this.arrival,
    required this.walkMeters,
    required this.transfers,
    required this.recommended,
    required this.legs,
    this.nextBus,
    this.notice,
  }) : assert(legs.isNotEmpty, 'option without legs'),
       assert(_validSequence(legs), 'invalid leg sequence');

  List<String> get lines => [
    for (final t in legs)
      if (t is BusLeg) t.line,
  ];

  BusLeg? get firstBus {
    for (final t in legs) {
      if (t is BusLeg) return t;
    }
    return null;
  }

  TripOption withNextBus(BusArrival? bus, {NoticeOption? notice}) => TripOption(
    id: id,
    durationSeconds: durationSeconds,
    exit: exit,
    arrival: arrival,
    walkMeters: walkMeters,
    transfers: transfers,
    recommended: recommended,
    legs: legs,
    nextBus: bus,
    notice: notice ?? this.notice,
  );

  TripOption withRecommended(bool value) => TripOption(
    id: id,
    durationSeconds: durationSeconds,
    exit: exit,
    arrival: arrival,
    walkMeters: walkMeters,
    transfers: transfers,
    recommended: value,
    legs: legs,
    nextBus: nextBus,
    notice: notice,
  );

  /// Invariant: every bus is preceded by its wait at the same stop.
  static bool _validSequence(List<Leg> legs) {
    for (var i = 0; i < legs.length; i++) {
      final t = legs[i];
      if (t is BusLeg) {
        if (i == 0) return false;
        final previous = legs[i - 1];
        if (previous is! WaitLeg) return false;
        if (previous.stop.id != t.boarding.id || previous.line != t.line) {
          return false;
        }
      }
      if (t is WaitLeg) {
        if (i + 1 >= legs.length || legs[i + 1] is! BusLeg) return false;
      }
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is TripOption &&
      other.id == id &&
      other.recommended == recommended &&
      other.nextBus == nextBus &&
      other.notice == notice &&
      listEquals(other.legs, legs);

  @override
  int get hashCode => Object.hash(id, recommended, nextBus, notice);
}
