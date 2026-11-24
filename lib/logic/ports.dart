// Ports: what the logic layer needs from the outside world.
//
// Each port has a real implementation (OTP, Montevideo API, Mapbox
// geocoding, GPS) and a replay/synthetic one for tests and demo mode.

import 'dart:async';

import '../contract/model.dart';

/// Planned option plus internal data the UI does not need.
class PlannedTrip {
  final TripOption option;

  /// GTFS shape (without feed prefix) of each bus leg, by leg id.
  final Map<String, String> shapeByLeg;

  const PlannedTrip(this.option, {this.shapeByLeg = const {}});
}

abstract interface class TripPlanner {
  /// Returns raw itineraries (no ranking or ETAs). Throws
  /// [ErrorServicio] if the service does not respond.
  Future<List<PlannedTrip>> plan({
    required Coordinate origin,
    required Coordinate destination,
    required DateTime exit,
  });
}

/// Arrival reported by the source, with the vehicle id so the same bus
/// can always be followed between polls.
class StopArrival {
  final BusArrival data;
  final String? vehicle;
  const StopArrival(this.data, {this.vehicle});
}

abstract interface class SourceArrivals {
  /// Upcoming arrivals at a stop. Throws [ErrorServicio] if it fails.
  Future<List<StopArrival>> arrivals(String idStop);
}

abstract interface class PlaceSearcher {
  Future<List<Place>> suggestions(String text, {Coordinate? near});
}

/// Static network data (bundled GTFS).
abstract interface class CatalogRed {
  Future<List<NetworkStop>> stops();

  /// Full geometry of a GTFS shape, or null if it does not exist.
  Future<List<Coordinate>?> shape(String shapeId);
}

class LocationSample {
  final Coordinate coordinate;
  final DateTime moment;

  /// Speed in m/s if the source reports it.
  final double? velocity;

  /// Horizontal accuracy in meters if the source reports it.
  final double? precision;

  const LocationSample({
    required this.coordinate,
    required this.moment,
    this.velocity,
    this.precision,
  });
}

enum LocationPermissionState { granted, denied, deniedParaAlways, serviceOff }

abstract interface class LocationSource {
  /// Requests permission if needed.
  Future<LocationPermissionState> ensurePermission();

  /// A single reading (or null if no fix is available in time).
  Future<LocationSample?> actual();

  /// Continuous stream of readings. Stops when the subscription is cancelled.
  Stream<LocationSample> follow();
}

class ServiceError implements Exception {
  final String service;
  final Object? cause;
  const ServiceError(this.service, [this.cause]);

  @override
  String toString() => 'ErrorServicio($service): $cause';
}

/// Injectable clock (tests and demo mode speed up time).
typedef Clock = DateTime Function();

/// The simulated world of demo mode.
abstract interface class ControlDemo {
  /// Destinations with a recorded trip.
  List<Place> get destinations;
}
