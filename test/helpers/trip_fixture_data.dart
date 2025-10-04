/// Modelo para datos de viajes capturados (fixtures)
///
/// Este modelo se usa para cargar datos reales de viajes desde JSON
/// y usarlos en tests de integración.

import 'dart:convert';
import 'dart:io';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';

class TripFixtureData {
  final String tripId;
  final String name;
  final DateTime capturedAt;
  final LocationPoint origin;
  final LocationPoint destination;
  final RouteData route;
  final BusPosition? initialBusPosition;
  final ExpectedBehavior expectedBehavior;

  // Nuevos campos para testing de integración
  final List<GpsPlaybackPoint> gpsPlayback;
  final List<TripCheckpoint> checkpoints;

  TripFixtureData({
    required this.tripId,
    required this.name,
    required this.capturedAt,
    required this.origin,
    required this.destination,
    required this.route,
    this.initialBusPosition,
    required this.expectedBehavior,
    this.gpsPlayback = const [],
    this.checkpoints = const [],
  });

  factory TripFixtureData.fromJson(Map<String, dynamic> json) {
    return TripFixtureData(
      tripId: json['tripId'] as String,
      name: json['name'] as String,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      origin: LocationPoint.fromJson(json['origin'] as Map<String, dynamic>),
      destination: LocationPoint.fromJson(json['destination'] as Map<String, dynamic>),
      route: RouteData.fromJson(json['route'] as Map<String, dynamic>),
      initialBusPosition: json['initialBusPosition'] != null
          ? BusPosition.fromJson(json['initialBusPosition'] as Map<String, dynamic>)
          : null,
      expectedBehavior: ExpectedBehavior.fromJson(json['expectedBehavior'] as Map<String, dynamic>),
      gpsPlayback: json['gpsPlayback'] != null
          ? (json['gpsPlayback'] as List)
              .map((p) => GpsPlaybackPoint.fromJson(p as Map<String, dynamic>))
              .toList()
          : [],
      checkpoints: json['checkpoints'] != null
          ? (json['checkpoints'] as List)
              .map((c) => TripCheckpoint.fromJson(c as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  /// Carga un fixture desde un archivo
  static Future<TripFixtureData> loadFromFile(String path) async {
    final file = File(path);
    final contents = await file.readAsString();
    final json = jsonDecode(contents) as Map<String, dynamic>;
    return TripFixtureData.fromJson(json);
  }

  Map<String, dynamic> toJson() {
    return {
      'tripId': tripId,
      'name': name,
      'capturedAt': capturedAt.toIso8601String(),
      'origin': origin.toJson(),
      'destination': destination.toJson(),
      'route': route.toJson(),
      if (initialBusPosition != null) 'initialBusPosition': initialBusPosition!.toJson(),
      'expectedBehavior': expectedBehavior.toJson(),
      if (gpsPlayback.isNotEmpty) 'gpsPlayback': gpsPlayback.map((p) => p.toJson()).toList(),
      if (checkpoints.isNotEmpty) 'checkpoints': checkpoints.map((c) => c.toJson()).toList(),
    };
  }

  String toJsonString() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }
}

class LocationPoint {
  final double lat;
  final double lng;
  final String name;

  LocationPoint({
    required this.lat,
    required this.lng,
    required this.name,
  });

  Coordenada toCoord() => Coordenada(latitud: lat, longitud: lng);

  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      lat: json['lat'] as double,
      lng: json['lng'] as double,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lng': lng,
      'name': name,
    };
  }
}

class RouteData {
  final String routeId;
  final bool recommended;
  final int totalDuration;
  final int totalWalkDistance;
  final int totalWaitTime;
  final List<StopData> stops;
  final List<SegmentData> segments;

  RouteData({
    required this.routeId,
    required this.recommended,
    required this.totalDuration,
    required this.totalWalkDistance,
    required this.totalWaitTime,
    required this.stops,
    required this.segments,
  });

  factory RouteData.fromJson(Map<String, dynamic> json) {
    return RouteData(
      routeId: json['routeId'] as String,
      recommended: json['recommended'] as bool,
      totalDuration: json['totalDuration'] as int,
      totalWalkDistance: json['totalWalkDistance'] as int,
      totalWaitTime: json['totalWaitTime'] as int,
      stops: (json['stops'] as List)
          .map((s) => StopData.fromJson(s as Map<String, dynamic>))
          .toList(),
      segments: (json['segments'] as List)
          .map((s) => SegmentData.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'routeId': routeId,
      'recommended': recommended,
      'totalDuration': totalDuration,
      'totalWalkDistance': totalWalkDistance,
      'totalWaitTime': totalWaitTime,
      'stops': stops.map((s) => s.toJson()).toList(),
      'segments': segments.map((s) => s.toJson()).toList(),
    };
  }
}

class StopData {
  final String stopId;
  final String name;
  final double lat;
  final double lng;
  final List<String> busLines;

  StopData({
    required this.stopId,
    required this.name,
    required this.lat,
    required this.lng,
    required this.busLines,
  });

  Coordenada toCoord() => Coordenada(latitud: lat, longitud: lng);

  factory StopData.fromJson(Map<String, dynamic> json) {
    return StopData(
      stopId: json['stopId'] as String,
      name: json['name'] as String,
      lat: json['lat'] as double,
      lng: json['lng'] as double,
      busLines: (json['busLines'] as List).map((l) => l as String).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stopId': stopId,
      'name': name,
      'lat': lat,
      'lng': lng,
      'busLines': busLines,
    };
  }
}

class SegmentData {
  final String type; // "CAMINAR", "ESPERAR_BUS", "VIAJE_EN_BUS"
  final String description;
  final int duration;
  final int? distance;
  final String? from;
  final String? to;
  final String? at;
  final String? busLine;
  final bool? hasEta;
  final int? etaMinutes;
  final String? shapeId;
  final List<GeometryPoint> geometry;

  SegmentData({
    required this.type,
    required this.description,
    required this.duration,
    this.distance,
    this.from,
    this.to,
    this.at,
    this.busLine,
    this.hasEta,
    this.etaMinutes,
    this.shapeId,
    required this.geometry,
  });

  factory SegmentData.fromJson(Map<String, dynamic> json) {
    return SegmentData(
      type: json['type'] as String,
      description: json['description'] as String,
      duration: json['duration'] as int,
      distance: json['distance'] as int?,
      from: json['from'] as String?,
      to: json['to'] as String?,
      at: json['at'] as String?,
      busLine: json['busLine'] as String?,
      hasEta: json['hasEta'] as bool?,
      etaMinutes: json['etaMinutes'] as int?,
      shapeId: json['shapeId'] as String?,
      geometry: (json['geometry'] as List)
          .map((g) => GeometryPoint.fromJson(g as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'description': description,
      'duration': duration,
      if (distance != null) 'distance': distance,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (at != null) 'at': at,
      if (busLine != null) 'busLine': busLine,
      if (hasEta != null) 'hasEta': hasEta,
      if (etaMinutes != null) 'etaMinutes': etaMinutes,
      if (shapeId != null) 'shapeId': shapeId,
      'geometry': geometry.map((g) => g.toJson()).toList(),
    };
  }
}

class GeometryPoint {
  final double lat;
  final double lng;

  GeometryPoint({required this.lat, required this.lng});

  Coordenada toCoord() => Coordenada(latitud: lat, longitud: lng);

  factory GeometryPoint.fromJson(Map<String, dynamic> json) {
    return GeometryPoint(
      lat: json['lat'] as double,
      lng: json['lng'] as double,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lng': lng,
    };
  }
}

class BusPosition {
  final double lat;
  final double lng;
  final DateTime capturedAt;

  BusPosition({
    required this.lat,
    required this.lng,
    required this.capturedAt,
  });

  Coordenada toCoord() => Coordenada(latitud: lat, longitud: lng);

  factory BusPosition.fromJson(Map<String, dynamic> json) {
    return BusPosition(
      lat: json['lat'] as double,
      lng: json['lng'] as double,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lng': lng,
      'capturedAt': capturedAt.toIso8601String(),
    };
  }
}

class ExpectedBehavior {
  final int totalDuration;
  final int stepsExpected;
  final bool shouldComplete;
  final String description;

  ExpectedBehavior({
    required this.totalDuration,
    required this.stepsExpected,
    required this.shouldComplete,
    required this.description,
  });

  factory ExpectedBehavior.fromJson(Map<String, dynamic> json) {
    return ExpectedBehavior(
      totalDuration: json['totalDuration'] as int,
      stepsExpected: json['stepsExpected'] as int,
      shouldComplete: json['shouldComplete'] as bool,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalDuration': totalDuration,
      'stepsExpected': stepsExpected,
      'shouldComplete': shouldComplete,
      'description': description,
    };
  }
}

/// Punto GPS en el playback de simulación
class GpsPlaybackPoint {
  final int timestamp; // Segundos desde inicio del viaje
  final double lat;
  final double lng;
  final String? comment;

  GpsPlaybackPoint({
    required this.timestamp,
    required this.lat,
    required this.lng,
    this.comment,
  });

  Coordenada toCoord() => Coordenada(latitud: lat, longitud: lng);

  factory GpsPlaybackPoint.fromJson(Map<String, dynamic> json) {
    return GpsPlaybackPoint(
      timestamp: json['timestamp'] as int,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      comment: json['comment'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'lat': lat,
      'lng': lng,
      if (comment != null) 'comment': comment,
    };
  }
}

/// Checkpoint de validación durante el viaje
class TripCheckpoint {
  final int timestamp; // Segundos desde inicio
  final String name;
  final CheckpointAssertions assertions;

  TripCheckpoint({
    required this.timestamp,
    required this.name,
    required this.assertions,
  });

  factory TripCheckpoint.fromJson(Map<String, dynamic> json) {
    return TripCheckpoint(
      timestamp: json['timestamp'] as int,
      name: json['name'] as String,
      assertions: CheckpointAssertions.fromJson(
        json['assertions'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'name': name,
      'assertions': assertions.toJson(),
    };
  }
}

/// Assertions que se validan en un checkpoint
class CheckpointAssertions {
  final int? currentStepIndex;
  final String? currentStepType;
  final double? progressMin;
  final double? progressMax;
  final bool? isWithinGeofence;
  final double? distanceToTargetMax;
  final double? distanceToTargetMin;

  CheckpointAssertions({
    this.currentStepIndex,
    this.currentStepType,
    this.progressMin,
    this.progressMax,
    this.isWithinGeofence,
    this.distanceToTargetMax,
    this.distanceToTargetMin,
  });

  factory CheckpointAssertions.fromJson(Map<String, dynamic> json) {
    return CheckpointAssertions(
      currentStepIndex: json['currentStepIndex'] as int?,
      currentStepType: json['currentStepType'] as String?,
      progressMin: (json['progressMin'] as num?)?.toDouble(),
      progressMax: (json['progressMax'] as num?)?.toDouble(),
      isWithinGeofence: json['isWithinGeofence'] as bool?,
      distanceToTargetMax: (json['distanceToTargetMax'] as num?)?.toDouble(),
      distanceToTargetMin: (json['distanceToTargetMin'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (currentStepIndex != null) 'currentStepIndex': currentStepIndex,
      if (currentStepType != null) 'currentStepType': currentStepType,
      if (progressMin != null) 'progressMin': progressMin,
      if (progressMax != null) 'progressMax': progressMax,
      if (isWithinGeofence != null) 'isWithinGeofence': isWithinGeofence,
      if (distanceToTargetMax != null) 'distanceToTargetMax': distanceToTargetMax,
      if (distanceToTargetMin != null) 'distanceToTargetMin': distanceToTargetMin,
    };
  }
}
