import 'package:geolocator/geolocator.dart';
import '../core/step_detector.dart';
import '../core/trip_step.dart';
import '../../backend/contrato_ui/app_ui_state.dart';

/// Adaptador de geometría que traduce coordenadas GPS a contexto de detección
///
/// Esta es la CAPA 2 de la arquitectura: maneja toda la complejidad de
/// coordenadas, GPS, geometría, distancias, etc.
///
/// La CAPA 1 (TripStateMachine, StepDetectors) NO conoce coordenadas.
/// Este adaptador es el puente entre ambos mundos.
class GeometryAdapter {
  /// Ubicación actual del usuario
  Coordenada? currentUserLocation;

  /// Cache de distancias iniciales por paso
  final Map<String, double> _initialDistances = {};

  /// Repositorio de paradas (stopId -> Coordenada)
  final Map<String, Coordenada> _stopLocations;

  /// Repositorio de rutas de bus (routeId -> List<Coordenada>)
  final Map<String, List<Coordenada>> _busRoutes;

  /// Ubicación del destino final
  final Coordenada destinationLocation;

  GeometryAdapter({
    required Map<String, Coordenada> stopLocations,
    required Map<String, List<Coordenada>> busRoutes,
    required this.destinationLocation,
    this.currentUserLocation,
  })  : _stopLocations = stopLocations,
        _busRoutes = busRoutes;

  /// Actualiza la ubicación actual del usuario
  void updateUserLocation(Coordenada location) {
    currentUserLocation = location;
  }

  /// Crea el contexto de detección para un paso dado
  ///
  /// Este método traduce las coordenadas GPS complejas a un contexto simple
  /// que los detectores pueden entender.
  Future<StepDetectionContext> createContextForStep(TripStep step) async {
    if (currentUserLocation == null) {
      throw StateError('User location not available');
    }

    // Obtener ubicación objetivo según el tipo de paso
    final targetLocation = _getTargetLocation(step);

    // Calcular distancia actual
    final distanceToTarget = _calculateDistance(
      currentUserLocation!,
      targetLocation,
    );

    // Obtener o calcular distancia inicial
    final initialDistance = _initialDistances.putIfAbsent(
      step.id,
      () => step.metadata.totalDistanceMeters ?? distanceToTarget,
    );

    // Verificar si está dentro del geofence
    final isWithinGeofence = _isWithinGeofence(
      currentUserLocation!,
      targetLocation,
      radiusMeters: _getGeofenceRadius(step.type),
    );

    // Verificar si está en la ruta del bus (para wait_for_bus y on_bus)
    final isOnBusRoute = _isOnBusRoute(step, currentUserLocation!);

    // Estimar velocidad del usuario (requeriría historial de ubicaciones)
    // Por ahora retornamos 0, esto se debería calcular con ubicaciones previas
    final userSpeed = 0.0;

    // Detectar si el usuario está en movimiento
    final isUserMoving = userSpeed > 0.5; // > 0.5 m/s

    return StepDetectionContext(
      distanceToTarget: distanceToTarget,
      initialDistanceToTarget: initialDistance,
      isWithinGeofence: isWithinGeofence,
      isOnBusRoute: isOnBusRoute,
      userSpeed: userSpeed,
      isUserMoving: isUserMoving,
      timestamp: DateTime.now(),
    );
  }

  /// Obtiene la ubicación objetivo según el tipo de paso
  Coordenada _getTargetLocation(TripStep step) {
    switch (step.type) {
      case TripStepType.walkToStop:
        // Objetivo es la parada destino
        final stopId = step.metadata.destinationStopId;
        if (stopId == null) {
          throw StateError('walkToStop requires destinationStopId');
        }
        return _stopLocations[stopId] ??
            (throw StateError('Stop $stopId not found'));

      case TripStepType.waitForBus:
        // Ya estamos en la parada, el objetivo es la misma parada
        final stopId = step.metadata.originStopId;
        if (stopId == null) {
          throw StateError('waitForBus requires originStopId');
        }
        return _stopLocations[stopId] ??
            (throw StateError('Stop $stopId not found'));

      case TripStepType.onBus:
        // Objetivo es la parada destino
        final stopId = step.metadata.destinationStopId;
        if (stopId == null) {
          throw StateError('onBus requires destinationStopId');
        }
        return _stopLocations[stopId] ??
            (throw StateError('Stop $stopId not found'));

      case TripStepType.walkToDestination:
        // Objetivo es el destino final
        return destinationLocation;
    }
  }

  /// Calcula la distancia entre dos coordenadas en metros
  double _calculateDistance(Coordenada from, Coordenada to) {
    return Geolocator.distanceBetween(
      from.latitud,
      from.longitud,
      to.latitud,
      to.longitud,
    );
  }

  /// Verifica si una ubicación está dentro del geofence de otra
  bool _isWithinGeofence(
    Coordenada userLocation,
    Coordenada targetLocation, {
    required double radiusMeters,
  }) {
    final distance = _calculateDistance(userLocation, targetLocation);
    return distance <= radiusMeters;
  }

  /// Verifica si el usuario está en la ruta del bus
  bool _isOnBusRoute(TripStep step, Coordenada userLocation) {
    // Solo aplica para waitForBus y onBus
    if (step.type != TripStepType.waitForBus &&
        step.type != TripStepType.onBus) {
      return false;
    }

    final busLine = step.metadata.busLine;
    if (busLine == null) return false;

    // Obtener la ruta del bus
    final route = _busRoutes[busLine];
    if (route == null || route.isEmpty) return false;

    // Verificar si el usuario está cerca de algún punto de la ruta
    // Esto es una simplificación - en producción usarías un algoritmo más sofisticado
    const routeProximityMeters = 50.0;

    for (final routePoint in route) {
      final distance = _calculateDistance(userLocation, routePoint);
      if (distance <= routeProximityMeters) {
        return true;
      }
    }

    return false;
  }

  /// Obtiene el radio del geofence según el tipo de paso
  double _getGeofenceRadius(TripStepType stepType) {
    switch (stepType) {
      case TripStepType.walkToStop:
        return 20.0; // 20m para paradas
      case TripStepType.waitForBus:
        return 20.0; // 20m para paradas
      case TripStepType.onBus:
        return 30.0; // 30m para bajarse del bus
      case TripStepType.walkToDestination:
        return 20.0; // 20m para destino
    }
  }

  /// Resetea el cache de distancias iniciales
  void resetInitialDistances() {
    _initialDistances.clear();
  }
}

/// Factory para crear un GeometryAdapter desde datos reales de la app
GeometryAdapter createGeometryAdapterFromTripData({
  required Map<String, Coordenada> stopLocations,
  required Map<String, List<Coordenada>> busRoutes,
  required Coordenada destinationLocation,
  Coordenada? initialUserLocation,
}) {
  return GeometryAdapter(
    stopLocations: stopLocations,
    busRoutes: busRoutes,
    destinationLocation: destinationLocation,
    currentUserLocation: initialUserLocation,
  );
}
