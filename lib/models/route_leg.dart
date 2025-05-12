import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'point_dart.dart'; // Asumimos que está en el mismo directorio

// Representa un punto de inicio/fin de un tramo
class LegEndpoint {
  final String name;
  final double lon;
  final double lat;
  final DateTime? arrival;
  final DateTime? departure;
  final String? stopId; // Usually present for transit stops
  final String? stopGtfsId; // Add this optional field

  LegEndpoint({
    required this.name,
    required this.lon,
    required this.lat,
    this.arrival,
    this.departure,
    this.stopId,
    this.stopGtfsId, // Add to constructor
  });

  factory LegEndpoint.fromJson(Map<String, dynamic> json) {
    // Helper to parse date times, returning null if invalid or null
    DateTime? parseDateTime(dynamic timeValue) {
      if (timeValue is int) {
        return DateTime.fromMillisecondsSinceEpoch(timeValue);
      }
      return null; // Or handle String parsing if needed, otherwise null
    }

    return LegEndpoint(
      name: json['name'] ?? 'Unknown Endpoint',
      lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      arrival: parseDateTime(json['arrival']),
      departure: parseDateTime(json['departure']),
      stopId: json['stopId'] as String?, // Existing stopId field
      stopGtfsId:
          json['stop']?['gtfsId'] as String?, // Safely access nested gtfsId
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'lon': lon,
    'lat': lat,
    'arrival': arrival?.millisecondsSinceEpoch,
    'departure': departure?.millisecondsSinceEpoch,
    'stopId': stopId,
    'stopGtfsId': stopGtfsId, // Add to toJson
  };
}

// Representa información de la ruta (para tramos de bus)
class LegRoute {
  final String? gtfsId;
  final String? longName;
  final String? shortName;

  LegRoute({this.gtfsId, this.longName, this.shortName});

  factory LegRoute.fromJson(Map<String, dynamic> json) {
    return LegRoute(
      gtfsId: json['gtfsId'] as String?,
      longName: json['longName'] as String?,
      shortName: json['shortName'] as String?,
    );
  }
}

// Representa información del viaje (para tramos de bus)
class LegTrip {
  final String? gtfsId;
  final String? shapeId;

  LegTrip({this.gtfsId, this.shapeId});

  factory LegTrip.fromJson(Map<String, dynamic> json) {
    return LegTrip(
      gtfsId: json['gtfsId'] as String?,
      shapeId: json['shapeId'] as String?,
    );
  }
}

// Representa la geometría del tramo
class LegGeometry {
  final String points;
  final int? length;

  LegGeometry({required this.points, this.length});

  factory LegGeometry.fromJson(Map<String, dynamic> json) {
    return LegGeometry(
      points: json['points'] as String? ?? '',
      length: (json['length'] as num?)?.toInt(),
    );
  }
}

// Represents a single step within a WALK leg
class LegStep {
  final double distance; // meters
  final String? relativeDirection; // e.g., "LEFT", "CONTINUE"
  final String? streetName;
  final String? absoluteDirection; // e.g., "NORTH", "SOUTHWEST"
  final bool? stayOn;
  final bool? area;
  final bool? bogusName;
  final double lon;
  final double lat;
  final String?
  elevation; // Often comes as String or empty list, handle appropriately

  LegStep({
    required this.distance,
    this.relativeDirection,
    this.streetName,
    this.absoluteDirection,
    this.stayOn,
    this.area,
    this.bogusName,
    required this.lon,
    required this.lat,
    this.elevation,
  });

  factory LegStep.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse numeric values
    double parseDouble(dynamic value, {double defaultValue = 0.0}) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    // Elevation can be tricky, might be String, number, or List
    String? parseElevation(dynamic value) {
      if (value is String) return value.isNotEmpty ? value : null;
      if (value is num) return value.toString();
      // Handle empty list or other unexpected types
      return null;
    }

    return LegStep(
      distance: parseDouble(json['distance']),
      relativeDirection: json['relativeDirection'] as String?,
      streetName: json['streetName'] as String?,
      absoluteDirection: json['absoluteDirection'] as String?,
      stayOn: json['stayOn'] as bool?,
      area: json['area'] as bool?,
      bogusName: json['bogusName'] as bool?,
      lon: parseDouble(json['lon']),
      lat: parseDouble(json['lat']),
      elevation: parseElevation(json['elevation']),
    );
  }
}

// Represents an intermediate stop passed through during a leg
class IntermediatePlace {
  final String? name;
  final double lon;
  final double lat;
  final String? stopId; // Platform stop ID
  final String? stopGtfsId; // GTFS stop ID, if available
  final DateTime?
  arrival; // Optional: time of arrival at this intermediate stop
  final DateTime?
  departure; // Optional: time of departure from this intermediate stop

  IntermediatePlace({
    this.name,
    required this.lon,
    required this.lat,
    this.stopId,
    this.stopGtfsId,
    this.arrival,
    this.departure,
  });

  factory IntermediatePlace.fromJson(Map<String, dynamic> json) {
    // Re-use helper from LegEndpoint or define locally
    DateTime? parseDateTime(dynamic timeValue) {
      if (timeValue is int) {
        return DateTime.fromMillisecondsSinceEpoch(timeValue);
      }
      return null;
    }

    double parseDouble(dynamic value, {double defaultValue = 0.0}) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    return IntermediatePlace(
      name: json['name'] as String?,
      lon: parseDouble(json['lon']),
      lat: parseDouble(json['lat']),
      stopId: json['stopId'] as String?,
      // Assuming gtfsId might be nested under 'stop' like in LegEndpoint
      stopGtfsId:
          json['stop']?['gtfsId'] as String? ?? json['gtfsId'] as String?,
      arrival: parseDateTime(json['arrival']),
      departure: parseDateTime(json['departure']),
    );
  }
}

// Modelo principal para un tramo de la ruta (RouteLeg)
class RouteLeg {
  final String mode;
  final int startTime; // Epoch milliseconds
  final int endTime; // Epoch milliseconds
  final double duration; // Seconds
  final double distance; // Meters
  final LegEndpoint from;
  final LegEndpoint to;
  final LegRoute? route; // Nullable for non-bus legs
  final LegTrip? trip; // Nullable for non-bus legs
  final LegGeometry legGeometry;
  final List<LegStep> steps;
  final List<IntermediatePlace> intermediatePlaces; // Descomentado y tipado

  RouteLeg({
    required this.mode,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.distance,
    required this.from,
    required this.to,
    this.route,
    this.trip,
    required this.legGeometry,
    required this.steps,
    this.intermediatePlaces =
        const [], // Añadido al constructor, opcional con valor por defecto
  });

  // Constructor factory para crear desde JSON (Map<String, dynamic>)
  factory RouteLeg.fromJson(Map<String, dynamic> json) {
    // Parse steps list safely
    List<LegStep> parsedSteps = [];
    if (json['steps'] is List) {
      parsedSteps =
          (json['steps'] as List)
              .map(
                (stepJson) =>
                    LegStep.fromJson(stepJson as Map<String, dynamic>),
              )
              .toList();
    }

    // Parse intermediatePlaces list safely
    List<IntermediatePlace> parsedIntermediatePlaces = [];
    if (json['intermediatePlaces'] is List) {
      parsedIntermediatePlaces =
          (json['intermediatePlaces'] as List)
              .map(
                (placeJson) => IntermediatePlace.fromJson(
                  placeJson as Map<String, dynamic>,
                ),
              )
              .toList();
    }

    return RouteLeg(
      mode: json['mode'] as String? ?? 'UNKNOWN',
      startTime: (json['startTime'] as num?)?.toInt() ?? 0,
      endTime: (json['endTime'] as num?)?.toInt() ?? 0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      from: LegEndpoint.fromJson(json['from'] as Map<String, dynamic>? ?? {}),
      to: LegEndpoint.fromJson(json['to'] as Map<String, dynamic>? ?? {}),
      route:
          json['route'] != null
              ? LegRoute.fromJson(json['route'] as Map<String, dynamic>)
              : null,
      trip:
          json['trip'] != null
              ? LegTrip.fromJson(json['trip'] as Map<String, dynamic>)
              : null,
      legGeometry: LegGeometry.fromJson(
        json['legGeometry'] as Map<String, dynamic>? ?? {},
      ),
      steps: parsedSteps,
      intermediatePlaces: parsedIntermediatePlaces, // Usar la lista parseada
    );
  }

  // Helper para convertir una lista de dynamic/Map a List<RouteLeg>
  static List<RouteLeg> listFromJson(List<dynamic> list) {
    return list
        .map((e) => RouteLeg.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
