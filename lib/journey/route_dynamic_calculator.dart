import 'dart:math';
import '../backend/contrato_ui/app_ui_state.dart';
import '../utils/geometry_utils.dart';

class RouteDynamicCalculator {
  // NUEVO: Calcular progreso a lo largo de una polilínea arbitraria usando proyección a segmento
  static double progressAlongPolyline({
    required Coordenada point,
    required List<Coordenada> polyline,
  }) {
    if (polyline.length < 2) return 0.0;
    // Calcular distancias acumuladas
    final cumulative = <double>[0.0];
    double acc = 0.0;
    for (int i = 0; i < polyline.length - 1; i++) {
      acc += calculateHaversineDistance(
        polyline[i].latitud,
        polyline[i].longitud,
        polyline[i + 1].latitud,
        polyline[i + 1].longitud,
      );
      cumulative.add(acc);
    }

    // Encontrar segmento más cercano proyectando
    double bestDist = double.infinity;
    double bestAlong = 0.0;
    for (int i = 0; i < polyline.length - 1; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];
      // Aproximación plana local para proyección
      final latRad = a.latitud * pi / 180.0;
      final kx = 111320.0 * cos(latRad);
      const ky = 111320.0;
      final ax = a.longitud * kx;
      final ay = a.latitud * ky;
      final bx = b.longitud * kx;
      final by = b.latitud * ky;
      final px = point.longitud * kx;
      final py = point.latitud * ky;
      final vx = bx - ax;
      final vy = by - ay;
      final wx = px - ax;
      final wy = py - ay;
      final segLen2 = vx * vx + vy * vy;
      double t = 0.0;
      if (segLen2 > 0) {
        t = (wx * vx + wy * vy) / segLen2;
        if (t < 0) t = 0;
        else if (t > 1) t = 1;
      }
      final projx = ax + t * vx;
      final projy = ay + t * vy;
      final dx = px - projx;
      final dy = py - projy;
      final dist = sqrt(dx * dx + dy * dy); // metros aprox
      if (dist < bestDist) {
        bestDist = dist;
        // Distancia acumulada hasta inicio + t * segmento
        final segMeters = calculateHaversineDistance(
          a.latitud,
          a.longitud,
          b.latitud,
          b.longitud,
        );
        bestAlong = cumulative[i] + t * segMeters;
      }
    }
    // Retorna metros recorridos y usuario puede dividir por total (último cumulative)
    return bestAlong.clamp(0.0, cumulative.last);
  }
  static Future<RouteProgress> calculateProgress({
    required Coordenada startLocation,
    required Coordenada currentLocation,
    required Coordenada destination,
  }) async {
    final totalDistance = calculateHaversineDistance(
      startLocation.latitud,
      startLocation.longitud,
      destination.latitud,
      destination.longitud,
    );
    final remainingDistance = calculateHaversineDistance(
      currentLocation.latitud,
      currentLocation.longitud,
      destination.latitud,
      destination.longitud,
    );
    final completedDistance = totalDistance - remainingDistance;

    // Asegurar que el progreso esté entre 0 y 100
    final rawProgress =
        totalDistance > 0 ? (completedDistance / totalDistance) * 100 : 0.0;
    final progressPercentage = rawProgress.clamp(0.0, 100.0);

    return RouteProgress(
      percentageComplete: progressPercentage,
      remainingDistance: remainingDistance,
      remainingTimeSeconds: _estimateWalkingTime(remainingDistance),
      currentOptimalRoute: await _calculateOptimalRoute(
        currentLocation,
        destination,
      ),
      totalDistance: totalDistance,
      completedDistance: completedDistance,
    );
  }

  static Future<List<Coordenada>> _calculateOptimalRoute(
    Coordenada from,
    Coordenada to,
  ) async {
    // Por ahora implementamos línea recta como MVP
    // En el futuro se puede integrar con servicios de routing más sofisticados
    return [from, to];
  }

  static int _estimateWalkingTime(double distanceMeters) {
    const double walkingSpeedMps =
        1.4; // 1.4 m/s = velocidad promedio caminando (5 km/h)
    if (distanceMeters <= 0) return 0;
    return (distanceMeters / walkingSpeedMps).round();
  }

  static double _estimateBusTime(double distanceMeters) {
    const double busSpeedMps = 8.33; // 8.33 m/s = 30 km/h promedio en ciudad
    if (distanceMeters <= 0) return 0;
    return distanceMeters / busSpeedMps;
  }

  static Future<RouteProgress> calculateBusProgress({
    required Coordenada startLocation,
    required Coordenada currentLocation,
    required Coordenada destination,
  }) async {
    final totalDistance = calculateHaversineDistance(
      startLocation.latitud,
      startLocation.longitud,
      destination.latitud,
      destination.longitud,
    );
    final remainingDistance = calculateHaversineDistance(
      currentLocation.latitud,
      currentLocation.longitud,
      destination.latitud,
      destination.longitud,
    );
    final completedDistance = totalDistance - remainingDistance;

    final rawProgress =
        totalDistance > 0 ? (completedDistance / totalDistance) * 100 : 0.0;
    final progressPercentage = rawProgress.clamp(0.0, 100.0);

    return RouteProgress(
      percentageComplete: progressPercentage,
      remainingDistance: remainingDistance,
      remainingTimeSeconds: _estimateBusTime(remainingDistance).round(),
      currentOptimalRoute: await _calculateOptimalRoute(
        currentLocation,
        destination,
      ),
      totalDistance: totalDistance,
      completedDistance: completedDistance,
    );
  }

  static bool isLocationNearRoute({
    required Coordenada userLocation,
    required List<Coordenada> routePoints,
    double thresholdMeters = 100.0,
  }) {
    if (routePoints.length < 2) return false;

    for (int i = 0; i < routePoints.length - 1; i++) {
      final segmentStart = routePoints[i];
      final segmentEnd = routePoints[i + 1];

      final distanceToSegment = _pointToLineSegmentDistance(
        userLocation,
        segmentStart,
        segmentEnd,
      );

      if (distanceToSegment <= thresholdMeters) {
        return true;
      }
    }

    return false;
  }

  static double _pointToLineSegmentDistance(
    Coordenada point,
    Coordenada lineStart,
    Coordenada lineEnd,
  ) {
    // Algoritmo para calcular distancia de punto a segmento de línea
    // Usar proyección del punto sobre la línea

    final A = point.latitud - lineStart.latitud;
    final B = point.longitud - lineStart.longitud;
    final C = lineEnd.latitud - lineStart.latitud;
    final D = lineEnd.longitud - lineStart.longitud;

    final dot = A * C + B * D;
    final lenSq = C * C + D * D;

    if (lenSq == 0) {
      // El segmento es un punto
      return calculateHaversineDistance(
        point.latitud,
        point.longitud,
        lineStart.latitud,
        lineStart.longitud,
      );
    }

    var param = dot / lenSq;

    Coordenada closestPoint;
    if (param < 0) {
      closestPoint = lineStart;
    } else if (param > 1) {
      closestPoint = lineEnd;
    } else {
      closestPoint = Coordenada(
        latitud: lineStart.latitud + param * C,
        longitud: lineStart.longitud + param * D,
      );
    }

    return calculateHaversineDistance(
      point.latitud,
      point.longitud,
      closestPoint.latitud,
      closestPoint.longitud,
    );
  }

  static bool detectBusBoarding({
    required Coordenada userLocation,
    required List<Coordenada> busRoutePoints,
    required double userSpeed, // m/s
    double minBusSpeed = 2.0, // m/s (7.2 km/h)
    double routeThreshold = 100.0, // metros
    Coordenada? previousLocation,
    double? userBearing, // Dirección del movimiento en grados (0-360)
  }) {
    // Criterios mejorados para detectar que el usuario subió al bus:
    // 1. Usuario está cerca de la ruta del bus
    // 2. Usuario se mueve a velocidad de bus (no caminando)
    // 3. [NUEVO] Usuario se mueve en la dirección del bus (si hay datos disponibles)

    final isNearRoute = isLocationNearRoute(
      userLocation: userLocation,
      routePoints: busRoutePoints,
      thresholdMeters: routeThreshold,
    );

    final isMovingAtBusSpeed = userSpeed >= minBusSpeed;

    // Análisis direccional si tenemos ubicación previa
    bool isMovingInBusDirection = true; // Por defecto asumimos que sí

    if (previousLocation != null && busRoutePoints.length >= 2) {
      // Encontrar el segmento más cercano de la ruta
      int closestSegmentIndex = _findClosestSegmentIndex(
        userLocation,
        busRoutePoints,
      );

      if (closestSegmentIndex < busRoutePoints.length - 1) {
        // Calcular la dirección del segmento de ruta del bus
        final segmentStart = busRoutePoints[closestSegmentIndex];
        final segmentEnd = busRoutePoints[closestSegmentIndex + 1];
        final busBearing = _calculateBearing(segmentStart, segmentEnd);

        // Si tenemos bearing del usuario, comparar con la dirección del bus
        if (userBearing != null) {
          final bearingDifference = _angleDifference(userBearing, busBearing);
          // Permitir hasta 90 grados de diferencia (usuario podría estar en carril opuesto)
          isMovingInBusDirection = bearingDifference < 90.0;

          print(
            "[BUS_BOARDING_DIRECTION] 🧭 Bearing usuario: ${userBearing.toStringAsFixed(1)}°",
          );
          print(
            "[BUS_BOARDING_DIRECTION] 🧭 Bearing bus: ${busBearing.toStringAsFixed(1)}°",
          );
          print(
            "[BUS_BOARDING_DIRECTION] 🧭 Diferencia: ${bearingDifference.toStringAsFixed(1)}°",
          );
          print(
            "[BUS_BOARDING_DIRECTION] 🧭 En dirección correcta: $isMovingInBusDirection",
          );
        }
      }
    }

    return isNearRoute && isMovingAtBusSpeed && isMovingInBusDirection;
  }

  // Encuentra el índice del segmento más cercano
  static int _findClosestSegmentIndex(
    Coordenada point,
    List<Coordenada> routePoints,
  ) {
    int closestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < routePoints.length - 1; i++) {
      final distance = distanceToLineSegment(
        point,
        routePoints[i],
        routePoints[i + 1],
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    return closestIndex;
  }

  // Calcula el bearing (dirección) entre dos puntos en grados
  static double _calculateBearing(Coordenada start, Coordenada end) {
    final lat1 = start.latitud * pi / 180;
    final lat2 = end.latitud * pi / 180;
    final deltaLon = (end.longitud - start.longitud) * pi / 180;

    final x = sin(deltaLon) * cos(lat2);
    final y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon);

    var bearing = atan2(x, y);
    bearing = bearing * 180 / pi;
    bearing = (bearing + 360) % 360; // Normalizar a 0-360

    return bearing;
  }

  // Calcula la diferencia mínima entre dos ángulos
  static double _angleDifference(double angle1, double angle2) {
    var diff = (angle2 - angle1).abs();
    if (diff > 180) {
      diff = 360 - diff;
    }
    return diff;
  }
}

class RouteProgress {
  final double percentageComplete;
  final double remainingDistance;
  final int remainingTimeSeconds;
  final List<Coordenada> currentOptimalRoute;
  final double totalDistance;
  final double completedDistance;

  RouteProgress({
    required this.percentageComplete,
    required this.remainingDistance,
    required this.remainingTimeSeconds,
    required this.currentOptimalRoute,
    required this.totalDistance,
    required this.completedDistance,
  });

  String get formattedRemainingTime {
    final minutes = remainingTimeSeconds ~/ 60;
    final seconds = remainingTimeSeconds % 60;

    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String get formattedRemainingDistance {
    if (remainingDistance >= 1000) {
      final km = remainingDistance / 1000;
      return '${km.toStringAsFixed(1)} km';
    } else {
      return '${remainingDistance.round()} m';
    }
  }

  String get formattedTotalDistance {
    if (totalDistance >= 1000) {
      final km = totalDistance / 1000;
      return '${km.toStringAsFixed(1)} km';
    } else {
      return '${totalDistance.round()} m';
    }
  }

  bool get isCompleted => percentageComplete >= 100.0;
  bool get isStarted => percentageComplete > 0.0;

  @override
  String toString() {
    return 'RouteProgress('
        'percentageComplete: ${percentageComplete.toStringAsFixed(1)}%, '
        'remainingDistance: ${formattedRemainingDistance}, '
        'remainingTime: $formattedRemainingTime'
        ')';
  }
}
