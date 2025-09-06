import 'package:flutter_test/flutter_test.dart';
import 'package:bondi_uy/journey/route_dynamic_calculator.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';

void main() {
  group('RouteDynamicCalculator', () {
    late Coordenada montevideoCenter;
    late Coordenada pocitos;
    late Coordenada ciudadVieja;

    setUp(() {
      // Coordenadas reales de Montevideo
      montevideoCenter = Coordenada(latitud: -34.9011, longitud: -56.1645);
      pocitos = Coordenada(latitud: -34.9095, longitud: -56.1538);
      ciudadVieja = Coordenada(latitud: -34.9067, longitud: -56.2019);
    });

    group('calculateProgress', () {
      test('should calculate progress correctly for walking route', () async {
        final startLocation = montevideoCenter;
        final currentLocation = Coordenada(latitud: -34.9050, longitud: -56.1590);
        final destination = pocitos;

        final progress = await RouteDynamicCalculator.calculateProgress(
          startLocation: startLocation,
          currentLocation: currentLocation,
          destination: destination,
        );

        expect(progress.percentageComplete, greaterThan(0.0));
        expect(progress.percentageComplete, lessThanOrEqualTo(100.0));
        expect(progress.remainingDistance, greaterThan(0.0));
        expect(progress.remainingTimeSeconds, greaterThan(0));
        expect(progress.totalDistance, greaterThan(progress.remainingDistance));
        expect(progress.currentOptimalRoute, isNotEmpty);
        expect(progress.currentOptimalRoute.length, equals(2)); // Simple line for MVP
      });

      test('should handle case where user is at destination', () async {
        final location = montevideoCenter;

        final progress = await RouteDynamicCalculator.calculateProgress(
          startLocation: location,
          currentLocation: location,
          destination: location,
        );

        expect(progress.percentageComplete, equals(0.0)); // No progress if no total distance
        expect(progress.remainingDistance, equals(0.0));
        expect(progress.remainingTimeSeconds, equals(0));
        expect(progress.totalDistance, equals(0.0));
      });

      test('should clamp progress between 0 and 100 percent', () async {
        final startLocation = montevideoCenter;
        final destination = pocitos;
        // Current location beyond destination
        final beyondDestination = Coordenada(latitud: -34.9200, longitud: -56.1400);

        final progress = await RouteDynamicCalculator.calculateProgress(
          startLocation: startLocation,
          currentLocation: beyondDestination,
          destination: destination,
        );

        expect(progress.percentageComplete, greaterThanOrEqualTo(0.0));
        expect(progress.percentageComplete, lessThanOrEqualTo(100.0));
      });
    });

    group('calculateBusProgress', () {
      test('should calculate bus progress with appropriate time estimates', () async {
        final startLocation = montevideoCenter;
        final currentLocation = Coordenada(latitud: -34.9050, longitud: -56.1590);
        final destination = pocitos;

        final progress = await RouteDynamicCalculator.calculateBusProgress(
          startLocation: startLocation,
          currentLocation: currentLocation,
          destination: destination,
        );

        expect(progress.percentageComplete, greaterThan(0.0));
        expect(progress.percentageComplete, lessThanOrEqualTo(100.0));
        expect(progress.remainingTimeSeconds, greaterThan(0));
        // Bus time should generally be less than walking time for same distance
        expect(progress.remainingTimeSeconds, lessThan(progress.remainingDistance / 1.4)); // Walking speed
      });
    });

    group('isLocationNearRoute', () {
      test('should detect when user is near route', () {
        final userLocation = Coordenada(latitud: -34.9050, longitud: -56.1590);
        final routePoints = [
          montevideoCenter,
          Coordenada(latitud: -34.9055, longitud: -56.1595), // Close to user
          pocitos,
        ];

        final isNear = RouteDynamicCalculator.isLocationNearRoute(
          userLocation: userLocation,
          routePoints: routePoints,
          thresholdMeters: 100.0,
        );

        expect(isNear, isTrue);
      });

      test('should detect when user is far from route', () {
        final userLocation = ciudadVieja; // Far from route
        final routePoints = [
          montevideoCenter,
          pocitos,
        ];

        final isNear = RouteDynamicCalculator.isLocationNearRoute(
          userLocation: userLocation,
          routePoints: routePoints,
          thresholdMeters: 100.0,
        );

        expect(isNear, isFalse);
      });

      test('should handle empty route', () {
        final userLocation = montevideoCenter;
        final routePoints = <Coordenada>[];

        final isNear = RouteDynamicCalculator.isLocationNearRoute(
          userLocation: userLocation,
          routePoints: routePoints,
        );

        expect(isNear, isFalse);
      });

      test('should handle single point route', () {
        final userLocation = montevideoCenter;
        final routePoints = [montevideoCenter];

        final isNear = RouteDynamicCalculator.isLocationNearRoute(
          userLocation: userLocation,
          routePoints: routePoints,
        );

        expect(isNear, isFalse); // Single point doesn't form a route
      });
    });

    group('detectBusBoarding', () {
      test('should detect bus boarding when conditions are met', () {
        final userLocation = Coordenada(latitud: -34.9050, longitud: -56.1590);
        final busRoute = [
          montevideoCenter,
          Coordenada(latitud: -34.9055, longitud: -56.1595), // Close to user
          pocitos,
        ];
        final userSpeed = 8.0; // m/s (faster than walking)

        final isBoarding = RouteDynamicCalculator.detectBusBoarding(
          userLocation: userLocation,
          busRoutePoints: busRoute,
          userSpeed: userSpeed,
        );

        expect(isBoarding, isTrue);
      });

      test('should not detect boarding when user is walking speed', () {
        final userLocation = Coordenada(latitud: -34.9050, longitud: -56.1590);
        final busRoute = [
          montevideoCenter,
          Coordenada(latitud: -34.9055, longitud: -56.1595),
          pocitos,
        ];
        final userSpeed = 1.5; // m/s (walking speed)

        final isBoarding = RouteDynamicCalculator.detectBusBoarding(
          userLocation: userLocation,
          busRoutePoints: busRoute,
          userSpeed: userSpeed,
        );

        expect(isBoarding, isFalse);
      });

      test('should not detect boarding when user is far from route', () {
        final userLocation = ciudadVieja; // Far from route
        final busRoute = [
          montevideoCenter,
          pocitos,
        ];
        final userSpeed = 10.0; // m/s (fast)

        final isBoarding = RouteDynamicCalculator.detectBusBoarding(
          userLocation: userLocation,
          busRoutePoints: busRoute,
          userSpeed: userSpeed,
        );

        expect(isBoarding, isFalse);
      });

      test('should use default thresholds when not specified', () {
        final userLocation = Coordenada(latitud: -34.9050, longitud: -56.1590);
        final busRoute = [
          montevideoCenter,
          Coordenada(latitud: -34.9055, longitud: -56.1595),
          pocitos,
        ];
        final userSpeed = 8.0; // m/s

        final isBoarding = RouteDynamicCalculator.detectBusBoarding(
          userLocation: userLocation,
          busRoutePoints: busRoute,
          userSpeed: userSpeed,
        );

        expect(isBoarding, isTrue);
      });

      test('should allow custom thresholds', () {
        final userLocation = Coordenada(latitud: -34.9050, longitud: -56.1590);
        final busRoute = [
          montevideoCenter,
          pocitos, // No intermediate point, might be far
        ];
        final userSpeed = 3.0; // m/s (between walking and bus)

        final isBoarding = RouteDynamicCalculator.detectBusBoarding(
          userLocation: userLocation,
          busRoutePoints: busRoute,
          userSpeed: userSpeed,
          minBusSpeed: 2.5, // Lower threshold
          routeThreshold: 1000.0, // Higher route threshold
        );

        expect(isBoarding, isTrue);
      });
    });
  });

  group('RouteProgress', () {
    late RouteProgress progress;

    setUp(() {
      progress = RouteProgress(
        percentageComplete: 65.5,
        remainingDistance: 850.3,
        remainingTimeSeconds: 425,
        currentOptimalRoute: [
          Coordenada(latitud: -34.9011, longitud: -56.1645),
          Coordenada(latitud: -34.9095, longitud: -56.1538),
        ],
        totalDistance: 1200.0,
        completedDistance: 349.7,
      );
    });

    group('Formatted Strings', () {
      test('should format remaining time correctly', () {
        expect(progress.formattedRemainingTime, equals('7m 5s'));
      });

      test('should format time with only seconds', () {
        final shortProgress = RouteProgress(
          percentageComplete: 95.0,
          remainingDistance: 50.0,
          remainingTimeSeconds: 45,
          currentOptimalRoute: [],
          totalDistance: 1000.0,
          completedDistance: 950.0,
        );

        expect(shortProgress.formattedRemainingTime, equals('45s'));
      });

      test('should format remaining distance in meters', () {
        expect(progress.formattedRemainingDistance, equals('850 m'));
      });

      test('should format distance in kilometers', () {
        final longProgress = RouteProgress(
          percentageComplete: 25.0,
          remainingDistance: 2500.0,
          remainingTimeSeconds: 1800,
          currentOptimalRoute: [],
          totalDistance: 3000.0,
          completedDistance: 500.0,
        );

        expect(longProgress.formattedRemainingDistance, equals('2.5 km'));
      });

      test('should format total distance correctly', () {
        expect(progress.formattedTotalDistance, equals('1.2 km'));

        final shortProgress = RouteProgress(
          percentageComplete: 50.0,
          remainingDistance: 250.0,
          remainingTimeSeconds: 180,
          currentOptimalRoute: [],
          totalDistance: 500.0,
          completedDistance: 250.0,
        );

        expect(shortProgress.formattedTotalDistance, equals('500 m'));
      });
    });

    group('Status Properties', () {
      test('should identify completed progress', () {
        final completed = RouteProgress(
          percentageComplete: 100.0,
          remainingDistance: 0.0,
          remainingTimeSeconds: 0,
          currentOptimalRoute: [],
          totalDistance: 1000.0,
          completedDistance: 1000.0,
        );

        expect(completed.isCompleted, isTrue);
        expect(completed.isStarted, isTrue);
      });

      test('should identify started but not completed progress', () {
        expect(progress.isCompleted, isFalse);
        expect(progress.isStarted, isTrue);
      });

      test('should identify not started progress', () {
        final notStarted = RouteProgress(
          percentageComplete: 0.0,
          remainingDistance: 1000.0,
          remainingTimeSeconds: 720,
          currentOptimalRoute: [],
          totalDistance: 1000.0,
          completedDistance: 0.0,
        );

        expect(notStarted.isCompleted, isFalse);
        expect(notStarted.isStarted, isFalse);
      });
    });

    group('toString', () {
      test('should provide comprehensive string representation', () {
        final string = progress.toString();

        expect(string, contains('65.5%'));
        expect(string, contains('850 m'));
        expect(string, contains('7m 5s'));
        expect(string, contains('RouteProgress'));
      });
    });
  });

  group('Edge Cases and Error Handling', () {
    test('should handle very small distances', () async {
      final location = Coordenada(latitud: -34.9011, longitud: -56.1645);
      final nearbyLocation = Coordenada(latitud: -34.9011001, longitud: -56.1645001);

      final progress = await RouteDynamicCalculator.calculateProgress(
        startLocation: location,
        currentLocation: location,
        destination: nearbyLocation,
      );

      expect(progress.remainingDistance, greaterThanOrEqualTo(0.0));
      expect(progress.percentageComplete, greaterThanOrEqualTo(0.0));
      expect(progress.percentageComplete, lessThanOrEqualTo(100.0));
    });

    test('should handle very large distances', () async {
      final startLocation = Coordenada(latitud: -34.9011, longitud: -56.1645);
      final currentLocation = Coordenada(latitud: -34.9050, longitud: -56.1590);
      final destination = Coordenada(latitud: -34.8000, longitud: -56.0000); // Far away

      final progress = await RouteDynamicCalculator.calculateProgress(
        startLocation: startLocation,
        currentLocation: currentLocation,
        destination: destination,
      );

      expect(progress.remainingDistance, greaterThan(0.0));
      expect(progress.totalDistance, greaterThan(progress.remainingDistance));
      expect(progress.remainingTimeSeconds, greaterThan(0));
    });

    test('should handle identical coordinates', () async {
      final location = Coordenada(latitud: -34.9011, longitud: -56.1645);

      final progress = await RouteDynamicCalculator.calculateProgress(
        startLocation: location,
        currentLocation: location,
        destination: location,
      );

      expect(progress.remainingDistance, equals(0.0));
      expect(progress.totalDistance, equals(0.0));
      expect(progress.remainingTimeSeconds, equals(0));
      expect(progress.percentageComplete, equals(0.0));
    });
  });
}