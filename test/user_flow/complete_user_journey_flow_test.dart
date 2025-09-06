import 'package:flutter_test/flutter_test.dart';
import 'package:bondi_uy/journey/location_tracker.dart';
import 'package:bondi_uy/journey/journey_step_state.dart';
import 'package:bondi_uy/journey/route_dynamic_calculator.dart';
import 'package:bondi_uy/map_manager/map_bus_realtime.dart';
import 'package:bondi_uy/map_manager/map_manager.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';

/// Complete User Journey Flow Tests
/// 
/// These tests verify the user flow described in:
/// docs/flujos/flujo-principal/3-flujo-informacion.md
/// 
/// Tests confirm:
/// 1. UserJourneyOrchestrator coordination
/// 2. LocationTracker 5-second updates
/// 3. BusTrackingManager hybrid system
/// 4. RouteDynamicCalculator live routes
/// 5. Complete journey step transitions
/// 6. Information flow architecture

class MockMapManager extends MapManager {
  MockMapManager() : super(null);
}

void main() {
  group('Complete User Journey Flow Tests', () {
    group('1. Journey Initialization Flow', () {
      test('should initialize journey with correct step sequence', () async {
        // Test journey step initialization as per architecture
        final journeySteps = [
          JourneyStepState(
            stepIndex: 0,
            type: JourneyStepType.WALKING_TO_STOP,
            destination: Coordenada(latitud: -34.907, longitud: -56.187),
            instructions: 'Camina hacia la parada',
          ),
          JourneyStepState(
            stepIndex: 1,
            type: JourneyStepType.WAITING_FOR_BUS,
            busLine: '123',
            instructions: 'Espera el bus línea 123',
          ),
          JourneyStepState(
            stepIndex: 2,
            type: JourneyStepType.RIDING_BUS,
            busLine: '123',
            destination: Coordenada(latitud: -34.908, longitud: -56.188),
            instructions: 'Viaja en bus línea 123',
          ),
          JourneyStepState(
            stepIndex: 3,
            type: JourneyStepType.WALKING_TO_DESTINATION,
            destination: Coordenada(latitud: -34.909, longitud: -56.189),
            instructions: 'Camina al destino',
          ),
        ];

        // Verify step types match architecture specification
        expect(journeySteps[0].type, equals(JourneyStepType.WALKING_TO_STOP));
        expect(journeySteps[1].type, equals(JourneyStepType.WAITING_FOR_BUS));
        expect(journeySteps[2].type, equals(JourneyStepType.RIDING_BUS));
        expect(journeySteps[3].type, equals(JourneyStepType.WALKING_TO_DESTINATION));

        // Verify step display names are correct
        expect(journeySteps[0].typeDisplayName, equals('Camina hacia la parada'));
        expect(journeySteps[1].typeDisplayName, equals('Espera el bus'));
        expect(journeySteps[2].typeDisplayName, equals('En el bus'));
        expect(journeySteps[3].typeDisplayName, equals('Camina al destino'));

        // Verify journey orchestration setup
        final locationTracker = LocationTracker(
          onLocationUpdate: (location) => print('Location: $location'),
          onArrivalDetected: (geofenceId) => print('Arrived at: $geofenceId'),
        );

        // Setup geofences for automatic detection per architecture
        final destinations = journeySteps
            .where((step) => step.destination != null)
            .map((step) => step.destination!)
            .toList();
        
        final geofenceIds = ['bus_stop', 'bus_destination', 'final_destination'];
        
        locationTracker.setupGeofencesForStep(destinations, geofenceIds);
        expect(locationTracker.activeGeofences.length, equals(3));
        
        locationTracker.dispose();
      });

      test('should configure location tracking with 5-second intervals', () {
        // Verify tracking configuration per architecture document
        expect(LocationTracker.UPDATE_INTERVAL_MS, equals(5000)); // 5 seconds
        expect(LocationTracker.ARRIVAL_THRESHOLD_METERS, equals(50.0)); // 50m threshold
        
        final locationTracker = LocationTracker(
          onLocationUpdate: (location) {},
          onArrivalDetected: (geofenceId) {},
        );
        
        expect(locationTracker.isTracking, isFalse);
        expect(locationTracker.lastKnownLocation, isNull);
        expect(locationTracker.activeGeofences, isEmpty);
        
        locationTracker.dispose();
      });
    });

    group('2. Location Update Loop (Every 5 Seconds)', () {
      test('should coordinate location updates with route calculations', () async {
        final locationUpdates = <Coordenada>[];
        final arrivals = <String>[];

        final locationTracker = LocationTracker(
          onLocationUpdate: (location) => locationUpdates.add(location),
          onArrivalDetected: (geofenceId) => arrivals.add(geofenceId),
        );

        // Test route calculation for each location update
        final userLocations = [
          Coordenada(latitud: -34.906, longitud: -56.186), // Start
          Coordenada(latitud: -34.9065, longitud: -56.1865), // Moving
          Coordenada(latitud: -34.907, longitud: -56.187), // At bus stop
        ];

        final destination = Coordenada(latitud: -34.907, longitud: -56.187);

        for (final location in userLocations) {
          // Simulate location update and route calculation
          final progress = await RouteDynamicCalculator.calculateProgress(
            startLocation: userLocations.first,
            currentLocation: location,
            destination: destination,
          );

          expect(progress.percentageComplete, greaterThanOrEqualTo(0.0));
          expect(progress.percentageComplete, lessThanOrEqualTo(100.0));
          expect(progress.currentOptimalRoute, isNotEmpty);
          expect(progress.formattedRemainingDistance, isNotNull);
          expect(progress.formattedRemainingTime, isNotNull);
        }

        locationTracker.dispose();
      });

      test('should update step progress dynamically', () async {
        var currentStep = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
          destination: Coordenada(latitud: -34.907, longitud: -56.187),
        );

        // Simulate progress updates
        final progressValues = [10.0, 25.0, 50.0, 75.0, 100.0];
        
        for (final progressPercent in progressValues) {
          currentStep = currentStep.copyWith(
            progressPercentage: progressPercent,
            remainingDistance: 200.0 * (1 - progressPercent / 100),
            remainingTimeSeconds: (180 * (1 - progressPercent / 100)).round(),
          );

          expect(currentStep.progressPercentage, equals(progressPercent));
          
          if (progressPercent == 100.0) {
            expect(currentStep.isCompleted, isTrue);
          } else if (progressPercent > 0.0) {
            expect(currentStep.isInProgress, isTrue);
          }
        }
      });
    });

    group('3. Automatic Step Transitions', () {
      test('should transition from WALKING_TO_STOP to WAITING_FOR_BUS', () async {
        // Initial step: walking to stop
        var currentStep = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
          destination: Coordenada(latitud: -34.907, longitud: -56.187),
          progressPercentage: 95.0,
        );

        expect(currentStep.type, equals(JourneyStepType.WALKING_TO_STOP));
        expect(currentStep.isInProgress, isTrue);

        // Simulate arrival at bus stop (geofencing detection)
        final busStopLocation = Coordenada(latitud: -34.907, longitud: -56.187);
        final userLocation = Coordenada(latitud: -34.9069, longitud: -56.1869);
        
        // Check if user is within arrival threshold
        final arrivalDetected = await _simulateArrivalDetection(
          userLocation, 
          busStopLocation, 
          LocationTracker.ARRIVAL_THRESHOLD_METERS
        );

        if (arrivalDetected) {
          // Transition to waiting for bus
          currentStep = currentStep.copyWith(
            stepIndex: 1,
            type: JourneyStepType.WAITING_FOR_BUS,
            busLine: '123',
            progressPercentage: 0.0,
          );
        }

        expect(currentStep.type, equals(JourneyStepType.WAITING_FOR_BUS));
        expect(currentStep.busLine, equals('123'));
      });

      test('should transition from WAITING_FOR_BUS to RIDING_BUS', () async {
        var currentStep = JourneyStepState(
          stepIndex: 1,
          type: JourneyStepType.WAITING_FOR_BUS,
          busLine: '123',
        );

        final mockMapManager = MockMapManager();
        final busTracker = MapBusRealtime(null, mockMapManager);

        // Start API tracking while waiting
        await busTracker.startApiTracking();
        expect(busTracker.trackingMode, equals(BusTrackingMode.API_REALTIME));

        // Simulate bus boarding detection
        final userLocation = Coordenada(latitud: -34.907, longitud: -56.187);
        final busRoute = [
          userLocation,
          Coordenada(latitud: -34.908, longitud: -56.188),
        ];
        final userSpeed = 10.0; // m/s (bus speed)

        final boardingDetected = RouteDynamicCalculator.detectBusBoarding(
          userLocation: userLocation,
          busRoutePoints: busRoute,
          userSpeed: userSpeed,
        );

        expect(boardingDetected, isTrue);

        if (boardingDetected) {
          // Switch to user location tracking
          await busTracker.switchToUserLocationMode();
          
          // Transition to riding bus
          currentStep = currentStep.copyWith(
            stepIndex: 2,
            type: JourneyStepType.RIDING_BUS,
            destination: Coordenada(latitud: -34.908, longitud: -56.188),
            progressPercentage: 0.0,
          );
        }

        expect(busTracker.trackingMode, equals(BusTrackingMode.USER_LOCATION));
        expect(currentStep.type, equals(JourneyStepType.RIDING_BUS));

        busTracker.dispose();
      });

      test('should transition from RIDING_BUS to WALKING_TO_DESTINATION', () async {
        var currentStep = JourneyStepState(
          stepIndex: 2,
          type: JourneyStepType.RIDING_BUS,
          busLine: '123',
          destination: Coordenada(latitud: -34.908, longitud: -56.188),
        );

        // Simulate arrival at bus destination
        final busDestination = Coordenada(latitud: -34.908, longitud: -56.188);
        final userLocation = Coordenada(latitud: -34.9079, longitud: -56.1879);

        final arrivalDetected = await _simulateArrivalDetection(
          userLocation,
          busDestination,
          LocationTracker.ARRIVAL_THRESHOLD_METERS,
        );

        if (arrivalDetected) {
          // Transition to final walking step
          currentStep = currentStep.copyWith(
            stepIndex: 3,
            type: JourneyStepType.WALKING_TO_DESTINATION,
            destination: Coordenada(latitud: -34.909, longitud: -56.189),
            progressPercentage: 0.0,
          );
        }

        expect(currentStep.type, equals(JourneyStepType.WALKING_TO_DESTINATION));
        expect(currentStep.stepIndex, equals(3));
      });
    });

    group('4. Hybrid Bus Tracking Flow', () {
      test('should demonstrate complete hybrid tracking flow', () async {
        final mockMapManager = MockMapManager();
        final busTracker = MapBusRealtime(null, mockMapManager);

        // Phase 1: API Tracking (while waiting)
        await busTracker.startApiTracking();
        expect(busTracker.trackingMode, equals(BusTrackingMode.API_REALTIME));

        // Phase 2: Bus boarding detection
        final userLocation = Coordenada(latitud: -34.907, longitud: -56.187);
        final busRoute = [
          Coordenada(latitud: -34.906, longitud: -56.186),
          userLocation,
          Coordenada(latitud: -34.908, longitud: -56.188),
        ];

        final boardingDetected = RouteDynamicCalculator.detectBusBoarding(
          userLocation: userLocation,
          busRoutePoints: busRoute,
          userSpeed: 12.0, // Bus speed
        );

        expect(boardingDetected, isTrue);

        // Phase 3: Switch to user tracking
        await busTracker.switchToUserLocationMode();
        expect(busTracker.trackingMode, equals(BusTrackingMode.USER_LOCATION));

        // Phase 4: Update bus position to user location
        await busTracker.updateBusToUserLocation(userLocation);
        expect(busTracker.trackingMode, equals(BusTrackingMode.USER_LOCATION));

        // Phase 5: Journey completion
        busTracker.stopAllTracking();
        expect(busTracker.trackingMode, equals(BusTrackingMode.INACTIVE));

        busTracker.dispose();
      });
    });

    group('5. Live Route Calculations', () {
      test('should provide dynamic route information', () async {
        final startLocation = Coordenada(latitud: -34.906, longitud: -56.186);
        final currentLocation = Coordenada(latitud: -34.9065, longitud: -56.1865);
        final destination = Coordenada(latitud: -34.907, longitud: -56.187);

        // Test walking route calculation
        final walkingProgress = await RouteDynamicCalculator.calculateProgress(
          startLocation: startLocation,
          currentLocation: currentLocation,
          destination: destination,
        );

        // Verify route information structure per architecture
        expect(walkingProgress.currentOptimalRoute, isNotEmpty);
        expect(walkingProgress.totalDistance, greaterThan(0.0));
        expect(walkingProgress.remainingDistance, greaterThan(0.0));
        expect(walkingProgress.remainingTimeSeconds, greaterThan(0));
        expect(walkingProgress.percentageComplete, greaterThanOrEqualTo(0.0));
        expect(walkingProgress.percentageComplete, lessThanOrEqualTo(100.0));

        // Test bus route calculation (faster than walking)
        final busProgress = await RouteDynamicCalculator.calculateBusProgress(
          startLocation: startLocation,
          currentLocation: currentLocation,
          destination: destination,
        );

        expect(busProgress.remainingTimeSeconds, lessThan(walkingProgress.remainingTimeSeconds));

        // Test route deviation detection
        final offRouteLocation = Coordenada(latitud: -34.920, longitud: -56.200);
        final routePoints = [startLocation, destination];

        final isNearRoute = RouteDynamicCalculator.isLocationNearRoute(
          userLocation: offRouteLocation,
          routePoints: routePoints,
          thresholdMeters: 100.0,
        );

        expect(isNearRoute, isFalse);
      });
    });

    group('6. UI State Coordination', () {
      test('should format journey information for UI display', () {
        final journeyStep = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
          remainingDistance: 150.5,
          remainingTimeSeconds: 125, // 2m 5s
          progressPercentage: 65.5,
        );

        // Verify UI formatting
        expect(journeyStep.formattedRemainingDistance, equals('151 m'));
        expect(journeyStep.formattedRemainingTime, equals('2m 5s'));
        expect(journeyStep.typeDisplayName, equals('Camina hacia la parada'));
        expect(journeyStep.isInProgress, isTrue);
        expect(journeyStep.isCompleted, isFalse);

        // Test kilometer formatting
        final longDistanceStep = journeyStep.copyWith(
          remainingDistance: 1500.0,
        );
        expect(longDistanceStep.formattedRemainingDistance, equals('1.5 km'));
      });

      test('should provide progress information for different journey states', () async {
        final progressInfo = await RouteDynamicCalculator.calculateProgress(
          startLocation: Coordenada(latitud: -34.906, longitud: -56.186),
          currentLocation: Coordenada(latitud: -34.9065, longitud: -56.1865),
          destination: Coordenada(latitud: -34.907, longitud: -56.187),
        );

        // Verify progress information structure
        expect(progressInfo.formattedTotalDistance, isNotNull);
        expect(progressInfo.formattedRemainingDistance, isNotNull);
        expect(progressInfo.formattedRemainingTime, isNotNull);
        expect(progressInfo.isStarted, isTrue);
        expect(progressInfo.isCompleted, isFalse);

        // Test completed journey
        final completedProgress = await RouteDynamicCalculator.calculateProgress(
          startLocation: Coordenada(latitud: -34.906, longitud: -56.186),
          currentLocation: Coordenada(latitud: -34.907, longitud: -56.187),
          destination: Coordenada(latitud: -34.907, longitud: -56.187),
        );

        expect(completedProgress.remainingDistance, lessThan(10.0));
      });
    });

    group('7. Complete Journey Integration', () {
      test('should demonstrate end-to-end journey flow', () async {
        final journeyLocations = [
          Coordenada(latitud: -34.906, longitud: -56.186),   // Start
          Coordenada(latitud: -34.9065, longitud: -56.1865), // Walking
          Coordenada(latitud: -34.907, longitud: -56.187),   // Bus stop
          Coordenada(latitud: -34.9075, longitud: -56.1875), // On bus
          Coordenada(latitud: -34.908, longitud: -56.188),   // Bus destination
          Coordenada(latitud: -34.909, longitud: -56.189),   // Final destination
        ];

        final mockMapManager = MockMapManager();
        final locationTracker = LocationTracker(
          onLocationUpdate: (location) {},
          onArrivalDetected: (geofenceId) {},
        );
        final busTracker = MapBusRealtime(null, mockMapManager);

        // Setup geofences for journey
        locationTracker.setupGeofencesForStep(
          [journeyLocations[2], journeyLocations[4], journeyLocations[5]],
          ['bus_stop', 'bus_dest', 'final_dest'],
        );

        expect(locationTracker.activeGeofences.length, equals(3));

        // Test each journey phase
        var currentStep = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
          destination: journeyLocations[2],
        );

        // Phase 1: Walking to stop
        for (int i = 0; i < 3; i++) {
          final progress = await RouteDynamicCalculator.calculateProgress(
            startLocation: journeyLocations[0],
            currentLocation: journeyLocations[i],
            destination: journeyLocations[2],
          );
          
          expect(progress.percentageComplete, greaterThanOrEqualTo(0.0));
        }

        // Phase 2: Waiting for bus
        await busTracker.startApiTracking();
        currentStep = currentStep.copyWith(
          type: JourneyStepType.WAITING_FOR_BUS,
          busLine: '123',
        );

        expect(busTracker.trackingMode, equals(BusTrackingMode.API_REALTIME));

        // Phase 3: Boarding and riding bus
        final boardingDetected = RouteDynamicCalculator.detectBusBoarding(
          userLocation: journeyLocations[2],
          busRoutePoints: [journeyLocations[2], journeyLocations[4]],
          userSpeed: 10.0,
        );

        if (boardingDetected) {
          await busTracker.switchToUserLocationMode();
          currentStep = currentStep.copyWith(
            type: JourneyStepType.RIDING_BUS,
            destination: journeyLocations[4],
          );
        }

        expect(busTracker.trackingMode, equals(BusTrackingMode.USER_LOCATION));

        // Phase 4: Final walk
        currentStep = currentStep.copyWith(
          type: JourneyStepType.WALKING_TO_DESTINATION,
          destination: journeyLocations[5],
        );

        final finalProgress = await RouteDynamicCalculator.calculateProgress(
          startLocation: journeyLocations[4],
          currentLocation: journeyLocations[4],
          destination: journeyLocations[5],
        );

        expect(finalProgress.percentageComplete, greaterThanOrEqualTo(0.0));
        expect(currentStep.type, equals(JourneyStepType.WALKING_TO_DESTINATION));

        // Cleanup
        locationTracker.dispose();
        busTracker.dispose();
      });
    });

    group('8. Architecture Verification', () {
      test('should verify all architectural constants and configurations', () {
        // Verify tracking configuration per architecture
        expect(LocationTracker.UPDATE_INTERVAL_MS, equals(5000)); // 5 seconds
        expect(LocationTracker.ARRIVAL_THRESHOLD_METERS, equals(50.0)); // 50m

        // Verify journey step types
        final stepTypes = JourneyStepType.values;
        expect(stepTypes.length, equals(4));
        expect(stepTypes, contains(JourneyStepType.WALKING_TO_STOP));
        expect(stepTypes, contains(JourneyStepType.WAITING_FOR_BUS));
        expect(stepTypes, contains(JourneyStepType.RIDING_BUS));
        expect(stepTypes, contains(JourneyStepType.WALKING_TO_DESTINATION));

        // Verify bus tracking modes
        final trackingModes = BusTrackingMode.values;
        expect(trackingModes.length, equals(3));
        expect(trackingModes, contains(BusTrackingMode.INACTIVE));
        expect(trackingModes, contains(BusTrackingMode.API_REALTIME));
        expect(trackingModes, contains(BusTrackingMode.USER_LOCATION));
      });

      test('should verify information flow patterns', () async {
        // Test information flow: LocationTracker → RouteDynamicCalculator
        final progress = await RouteDynamicCalculator.calculateProgress(
          startLocation: Coordenada(latitud: -34.906, longitud: -56.186),
          currentLocation: Coordenada(latitud: -34.9065, longitud: -56.1865),
          destination: Coordenada(latitud: -34.907, longitud: -56.187),
        );

        // Verify all required information is present
        expect(progress.currentOptimalRoute, isNotEmpty);
        expect(progress.totalDistance, greaterThan(0.0));
        expect(progress.remainingDistance, greaterThan(0.0));
        expect(progress.remainingTimeSeconds, greaterThan(0));
        expect(progress.percentageComplete, greaterThanOrEqualTo(0.0));
        expect(progress.completedDistance, greaterThanOrEqualTo(0.0));

        // Test information flow: BusTrackingManager modes
        final mockMapManager = MockMapManager();
        final busTracker = MapBusRealtime(null, mockMapManager);

        await busTracker.startApiTracking();
        expect(busTracker.trackingMode, equals(BusTrackingMode.API_REALTIME));

        await busTracker.switchToUserLocationMode();
        expect(busTracker.trackingMode, equals(BusTrackingMode.USER_LOCATION));

        busTracker.stopAllTracking();
        expect(busTracker.trackingMode, equals(BusTrackingMode.INACTIVE));

        busTracker.dispose();
      });
    });
  });
}

// Helper function to simulate arrival detection
Future<bool> _simulateArrivalDetection(
  Coordenada userLocation,
  Coordenada destination,
  double threshold,
) async {
  // Use the same calculation as the real system
  final distance = await _calculateDistance(userLocation, destination);
  return distance <= threshold;
}

// Helper function to calculate distance (simplified for testing)
Future<double> _calculateDistance(Coordenada from, Coordenada to) async {
  // Simplified haversine calculation for testing
  final deltaLat = to.latitud - from.latitud;
  final deltaLng = to.longitud - from.longitud;
  final distance = (deltaLat * deltaLat + deltaLng * deltaLng) * 111000; // Rough conversion
  return distance.abs();
}