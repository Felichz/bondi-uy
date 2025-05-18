import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/point_dart.dart'; // Asumiendo la ubicación de Point_dart
import '../models/route_leg.dart'; // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< IMPORTAR ROUTELEG
import './haversine.dart'; // Asumiendo la ubicación de haversine
import 'package:flutter_polyline_points/flutter_polyline_points.dart'; // AÑADIDO para PointLatLng
import 'dart:math' as math; // AÑADIDO para math.min/max

// Función movida desde _MapScreenState
int findClosestPointIndexOnShape(
  List<Position> shapePoints,
  Point_dart targetPoint,
) {
  if (shapePoints.isEmpty) return -1;

  int closestIndex = -1;
  double minDistance = double.infinity;

  for (int i = 0; i < shapePoints.length; i++) {
    final shapePosition = shapePoints[i];
    final double shapeLat = shapePosition[1] as double;
    final double shapeLng = shapePosition[0] as double;

    final distance = calculateHaversineDistance(
      targetPoint.lat,
      targetPoint.lng,
      shapeLat,
      shapeLng,
    );
    if (distance < minDistance) {
      minDistance = distance;
      closestIndex = i;
    }
  }
  return closestIndex;
}

// AÑADIDO DESDE _MapScreenState
Future<CoordinateBounds?> calculateBoundsForPositions(
  List<Position> positions,
) async {
  print(
    "[GeometryUtils_DEBUG] calculateBoundsForPositions called with ${positions.length} positions.",
  );
  if (positions.isEmpty) {
    print(
      "[GeometryUtils_DEBUG] calculateBoundsForPositions: positions list is empty. Returning null.",
    );
    return null;
  }

  double? minLat, maxLat, minLon, maxLon;

  for (var pos in positions) {
    final lat = pos[1] as double;
    final lon = pos[0] as double;

    if (minLat == null || lat < minLat) minLat = lat;
    if (maxLat == null || lat > maxLat) maxLat = lat;
    if (minLon == null || lon < minLon) minLon = lon;
    if (maxLon == null || lon > maxLon) maxLon = lon;
  }

  if (minLat != null && maxLat != null && minLon != null && maxLon != null) {
    if (minLat == maxLat) {
      maxLat = minLat + 0.001;
      minLat = minLat - 0.001;
    }
    if (minLon == maxLon) {
      maxLon = minLon + 0.001;
      minLon = minLon - 0.001;
    }

    final Point southwest = Point(coordinates: Position(minLon, minLat));
    final Point northeast = Point(coordinates: Position(maxLon, maxLat));
    final bounds = CoordinateBounds(
      southwest: southwest,
      northeast: northeast,
      infiniteBounds: false,
    );
    print(
      "[GeometryUtils_DEBUG] calculateBoundsForPositions calculated bounds: $bounds",
    );
    return bounds;
  }
  print(
    "[GeometryUtils_DEBUG] calculateBoundsForPositions: Could not calculate bounds. Returning null.",
  );
  return null;
}

// AÑADIDO DESDE _MapScreenState
Future<CoordinateBounds?> calculateBoundsForLeg(
  List<RouteLeg>
  currentRouteLegs, // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< CAMBIAR List<dynamic> a List<RouteLeg>
  int legIndex, {
  Position? additionalPoint, // Parámetro opcional con nombre
}) async {
  print(
    "[GeometryUtils_DEBUG] calculateBoundsForLeg called for legIndex: $legIndex, additionalPoint: $additionalPoint",
  );
  if (legIndex < 0 ||
      legIndex >= currentRouteLegs.length ||
      currentRouteLegs.isEmpty) {
    print(
      "[GeometryUtils_DEBUG] calculateBoundsForLeg: Invalid legIndex or empty list. Returning null.",
    );
    return null;
  }

  final RouteLeg leg =
      currentRouteLegs[legIndex]; // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< leg es RouteLeg
  List<Position> allPositionsForBounds = [];

  // Usar acceso directo a la propiedad
  final String polylineString = leg.legGeometry.points;
  if (polylineString.isNotEmpty) {
    List<PointLatLng> decodedPoints = PolylinePoints().decodePolyline(
      polylineString,
    );
    if (decodedPoints.isNotEmpty) {
      allPositionsForBounds.addAll(
        decodedPoints.map((p) => Position(p.longitude, p.latitude)),
      );
      print(
        "[GeometryUtils_DEBUG] calculateBoundsForLeg: Decoded ${decodedPoints.length} points from polyline.",
      );
    } else {
      print(
        "[GeometryUtils_DEBUG] calculateBoundsForLeg: Decoded 0 points from polyline.",
      );
    }
  } else {
    print(
      "[GeometryUtils_DEBUG] calculateBoundsForLeg: Polyline string is empty.",
    );
  }

  // Fallback si no hay polyline (menos probable con RouteLeg)
  if (allPositionsForBounds.isEmpty) {
    final LegEndpoint fromPlace =
        leg.from; // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ACCESO DIRECTO
    final LegEndpoint toPlace =
        leg.to; // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ACCESO DIRECTO
    // fromPlace.lat y fromPlace.lon ya son double requeridos por LegEndpoint
    allPositionsForBounds.add(Position(fromPlace.lon, fromPlace.lat));
    allPositionsForBounds.add(Position(toPlace.lon, toPlace.lat));
    print(
      "[GeometryUtils_DEBUG] calculateBoundsForLeg: Using from/to points as fallback.",
    );
  }

  if (additionalPoint != null) {
    allPositionsForBounds.add(additionalPoint);
    print(
      "[GeometryUtils_DEBUG] calculateBoundsForLeg: Added additional point.",
    );
  }

  if (allPositionsForBounds.isEmpty) {
    print(
      "[GeometryUtils_DEBUG] calculateBoundsForLeg: No positions to calculate bounds from. Returning null.",
    );
    return null;
  }

  final bounds = await calculateBoundsForPositions(allPositionsForBounds);
  print(
    "[GeometryUtils_DEBUG] calculateBoundsForLeg calculated bounds: $bounds",
  );
  return bounds;
}

// AÑADIDO DESDE _MapScreenState
Future<CoordinateBounds?> calculateBoundsForRoute(List<RouteLeg> legs) async {
  // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< CAMBIAR List<dynamic> a List<RouteLeg>
  print(
    "[GeometryUtils_DEBUG] calculateBoundsForRoute called with ${legs.length} legs.",
  );
  if (legs.isEmpty) {
    print(
      "[GeometryUtils_DEBUG] calculateBoundsForRoute: legs list is empty. Returning null.",
    );
    return null;
  }

  double? minLat, maxLat, minLon, maxLon;

  for (var leg in legs) {
    // Usar acceso directo a la propiedad
    final String polylineString = leg.legGeometry.points;
    if (polylineString.isNotEmpty) {
      List<PointLatLng> decodedPoints = PolylinePoints().decodePolyline(
        polylineString,
      );
      for (var p in decodedPoints) {
        if (minLat == null || p.latitude < minLat) minLat = p.latitude;
        if (maxLat == null || p.latitude > maxLat) maxLat = p.latitude;
        if (minLon == null || p.longitude < minLon) minLon = p.longitude;
        if (maxLon == null || p.longitude > maxLon) maxLon = p.longitude;
      }
      print(
        "[GeometryUtils_DEBUG] calculateBoundsForRoute: Processed polyline for a leg.",
      );
    } else {
      // Fallback si no hay polyline (usar puntos from/to)
      final LegEndpoint fromPlace =
          leg.from; // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ACCESO DIRECTO
      final LegEndpoint toPlace =
          leg.to; // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ACCESO DIRECTO
      // fromPlace/toPlace.lat/lon ya son double requeridos
      final latFrom = fromPlace.lat;
      final lonFrom = fromPlace.lon;
      if (minLat == null || latFrom < minLat) minLat = latFrom;
      if (maxLat == null || latFrom > maxLat) maxLat = latFrom;
      if (minLon == null || lonFrom < minLon) minLon = lonFrom;
      if (maxLon == null || lonFrom > maxLon) maxLon = lonFrom;

      final latTo = toPlace.lat;
      final lonTo = toPlace.lon;
      if (minLat == null || latTo < minLat) minLat = latTo;
      if (maxLat == null || latTo > maxLat) maxLat = latTo;
      if (minLon == null || lonTo < minLon) minLon = lonTo;
      if (maxLon == null || lonTo > maxLon) maxLon = lonTo;
      print(
        "[GeometryUtils_DEBUG] calculateBoundsForRoute: Used from/to points for a leg fallback.",
      );
    }
  }

  if (minLat != null && maxLat != null && minLon != null && maxLon != null) {
    if (minLat == maxLat) {
      maxLat = minLat + 0.001;
      minLat = minLat - 0.001;
    }
    if (minLon == maxLon) {
      maxLon = minLon + 0.001;
      minLon = minLon - 0.001;
    }

    final Point southwestPoint = Point(coordinates: Position(minLon, minLat));
    final Point northeastPoint = Point(coordinates: Position(maxLon, maxLat));
    final bounds = CoordinateBounds(
      southwest: southwestPoint,
      northeast: northeastPoint,
      infiniteBounds: false,
    );
    print(
      "[GeometryUtils_DEBUG] calculateBoundsForRoute calculated bounds: $bounds",
    );
    return bounds;
  }
  print(
    "[GeometryUtils_DEBUG] calculateBoundsForRoute: Could not calculate bounds. Returning null.",
  );
  return null;
}

// Calcula la distancia total de un segmento de la polilínea (shape).
// La polilínea es una lista de `Position`.
// `startIndex` es el índice del punto de inicio en la polilínea.
// `endIndex` es el índice del punto final en la polilínea.
double getDistanceAlongPolylineSegment(
  List<Position> polyline,
  int startIndex,
  int endIndex,
) {
  if (polyline.length < 2 ||
      startIndex < 0 ||
      endIndex >= polyline.length ||
      startIndex >= endIndex) {
    return 0.0;
  }

  double totalDistance = 0.0;
  for (int i = startIndex; i < endIndex; i++) {
    totalDistance += calculateHaversineDistance(
      polyline[i][1] as double,
      polyline[i][0] as double,
      polyline[i + 1][1] as double,
      polyline[i + 1][0] as double,
    );
  }
  return totalDistance;
}

// Encuentra el punto en la polilínea que está a una distancia dada desde un punto de inicio específico en esa polilínea.
// `polyline` es la forma completa de la línea de autobús.
// `startIndexOnPolyline` es el índice en `polyline` desde donde comenzamos a medir la `distanceToTravel`.
// `distanceToTravel` es la distancia en metros que queremos avanzar a lo largo de la polilínea.
// Devuelve la `Position` resultante. Si la distancia excede el final de la polilínea, devuelve el último punto.
Position getPointAtDistanceAlongPolyline(
  List<Position> polyline,
  int startIndexOnPolyline,
  double distanceToTravel,
) {
  if (polyline.isEmpty ||
      startIndexOnPolyline < 0 ||
      startIndexOnPolyline >= polyline.length) {
    // Devuelve una posición por defecto o maneja el error como prefieras
    return polyline.isNotEmpty ? polyline.last : Position(0, 0);
  }

  if (distanceToTravel <= 0) {
    return polyline[startIndexOnPolyline];
  }

  double distanceCovered = 0.0;
  for (int i = startIndexOnPolyline; i < polyline.length - 1; i++) {
    final Position p1 = polyline[i];
    final Position p2 = polyline[i + 1];
    double segmentDistance = calculateHaversineDistance(
      p1[1] as double,
      p1[0] as double,
      p2[1] as double,
      p2[0] as double,
    );

    if (distanceCovered + segmentDistance >= distanceToTravel) {
      // El punto está en este segmento
      double remainingDistance = distanceToTravel - distanceCovered;
      double fraction = remainingDistance / segmentDistance;
      if (segmentDistance == 0)
        fraction = 0; // Evitar división por cero si p1 y p2 son iguales

      double lat =
          (p1[1] as double) +
          ((p2[1] as double) - (p1[1] as double)) * fraction;
      double lng =
          (p1[0] as double) +
          ((p2[0] as double) - (p1[0] as double)) * fraction;
      return Position(lng, lat);
    }
    distanceCovered += segmentDistance;
  }

  // Si la distancia a viajar excede la longitud de la polilínea desde el startIndex,
  // devuelve el último punto de la polilínea.
  return polyline.last;
}
