/// Detector de llegadas basado en geofencing
///
/// Encapsula toda la lógica de detección de proximidad a un punto objetivo.
/// Usa umbrales configurables y puede manejar diferentes tipos de objetivos.

import '../../backend/contrato_ui/app_ui_state.dart';
import '../../utils/geometry_utils.dart';

enum GeofenceTargetType {
  BUS_STOP,
  DESTINATION,
  WAYPOINT,
}

class GeofencingDetector {
  // Umbrales de llegada por tipo de objetivo
  static const double _busStopThresholdMeters = 40.0;
  static const double _destinationThresholdMeters = 30.0;
  static const double _waypointThresholdMeters = 50.0;

  /// Verifica si el usuario ha llegado al objetivo
  bool hasArrived({
    required Coordenada currentLocation,
    required Coordenada targetLocation,
    GeofenceTargetType targetType = GeofenceTargetType.DESTINATION,
  }) {
    final distance = calculateHaversineDistance(
      currentLocation.latitud,
      currentLocation.longitud,
      targetLocation.latitud,
      targetLocation.longitud,
    );

    final threshold = _getThresholdForType(targetType);

    return distance <= threshold;
  }

  /// Calcula la distancia actual al objetivo
  double distanceToTarget({
    required Coordenada currentLocation,
    required Coordenada targetLocation,
  }) {
    return calculateHaversineDistance(
      currentLocation.latitud,
      currentLocation.longitud,
      targetLocation.latitud,
      targetLocation.longitud,
    );
  }

  /// Verifica si el usuario está cerca del objetivo (en zona de proximidad)
  bool isNearTarget({
    required Coordenada currentLocation,
    required Coordenada targetLocation,
    required double proximityRadius,
  }) {
    final distance = distanceToTarget(
      currentLocation: currentLocation,
      targetLocation: targetLocation,
    );

    return distance <= proximityRadius;
  }

  /// Obtiene el umbral apropiado según el tipo de objetivo
  double _getThresholdForType(GeofenceTargetType type) {
    switch (type) {
      case GeofenceTargetType.BUS_STOP:
        return _busStopThresholdMeters;
      case GeofenceTargetType.DESTINATION:
        return _destinationThresholdMeters;
      case GeofenceTargetType.WAYPOINT:
        return _waypointThresholdMeters;
    }
  }

  /// Obtiene el umbral actual para un tipo de objetivo
  double getThreshold(GeofenceTargetType type) {
    return _getThresholdForType(type);
  }
}
