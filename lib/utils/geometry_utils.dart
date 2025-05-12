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
    final double shapeLat =
        (shapePosition.lat is num)
            ? (shapePosition.lat as num).toDouble()
            : 0.0;
    final double shapeLng =
        (shapePosition.lng is num)
            ? (shapePosition.lng as num).toDouble()
            : 0.0;

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
  if (positions.isEmpty) return null;

  double? minLat, maxLat, minLon, maxLon;

  for (var pos in positions) {
    final lat =
        pos.lat as double; // ASUMIMOS QUE YA ES DOUBLE O SE CONVIERTE ANTES
    final lon =
        pos.lng as double; // ASUMIMOS QUE YA ES DOUBLE O SE CONVIERTE ANTES

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
    return CoordinateBounds(
      southwest: southwest,
      northeast: northeast,
      infiniteBounds: false,
    );
  }
  return null;
}

// AÑADIDO DESDE _MapScreenState
Future<CoordinateBounds?> calculateBoundsForLeg(
  List<RouteLeg>
  currentRouteLegs, // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< CAMBIAR List<dynamic> a List<RouteLeg>
  int legIndex, {
  Position? additionalPoint, // Parámetro opcional con nombre
}) async {
  if (legIndex < 0 ||
      legIndex >= currentRouteLegs.length ||
      currentRouteLegs.isEmpty) {
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
    }
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
  }

  if (additionalPoint != null) {
    allPositionsForBounds.add(additionalPoint);
  }

  if (allPositionsForBounds.isEmpty) return null;

  return await calculateBoundsForPositions(allPositionsForBounds);
}

// AÑADIDO DESDE _MapScreenState
Future<CoordinateBounds?> calculateBoundsForRoute(List<RouteLeg> legs) async {
  // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< CAMBIAR List<dynamic> a List<RouteLeg>
  if (legs.isEmpty) return null;

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
    return CoordinateBounds(
      southwest: southwestPoint, // Pasar Point directamente
      northeast: northeastPoint, // Pasar Point directamente
      infiniteBounds: false,
    );
  }
  return null;
}
