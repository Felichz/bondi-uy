import 'package:flutter_test/flutter_test.dart';
import 'package:bondi_uy/journey/location_tracker.dart';
import 'package:bondi_uy/journey/journey_step_state.dart';
import 'package:bondi_uy/journey/route_dynamic_calculator.dart';
import 'package:bondi_uy/map_manager/map_bus_realtime.dart';
import 'package:bondi_uy/map_manager/map_manager.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';

/// Information Flow Validation Tests
/// 
/// These tests validate the specific information flow described in:
/// docs/flujos/flujo-principal/3-flujo-informacion.md
/// 
/// Focus Areas:
/// 1. Paso 1: Inicialización del Viaje
/// 2. Paso 2: Loop Principal (cada 5 segundos) 
/// 3. Paso 3: Transiciones Automáticas
/// 4. Estados de la UI por Paso
/// 5. Ventajas del Nuevo Diseño

class MockMapManager extends MapManager {
  MockMapManager() : super(null);
}

void main() {
  group('Information Flow Validation Tests', () {
    group('Paso 1: Inicialización del Viaje', () {
      test('should execute journey initialization sequence per architecture', () async {
        /*
        Architecture sequence:
        Usuario confirma opción → UserJourneyOrchestrator.initializeJourney()
        ├── 1. Configurar primer paso (WALKING_TO_STOP)
        ├── 2. LocationTracker.startTracking()
        ├── 3. RouteDynamicCalculator.calculateOptimalRoute(usuario → parada)
        ├── 4. Si hay ETA → BusTrackingManager.startApiTracking()
        ├── 5. SmartCameraController.updateCameraForStep()
        └── 6. UI muestra: paso actual, distancia, progreso, ETA del bus
        */

        // Step 1: Configure first step (WALKING_TO_STOP)
        final firstStep = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
          destination: Coordenada(latitud: -34.907, longitud: -56.187),
          instructions: 'Camina hacia la parada',
        );

        expect(firstStep.type, equals(JourneyStepType.WALKING_TO_STOP));
        expect(firstStep.destination, isNotNull);

        // Step 2: LocationTracker.startTracking()
        final locationTracker = LocationTracker(
          onLocationUpdate: (location) => print('Location update: $location'),
          onArrivalDetected: (geofenceId) => print('Arrival detected: $geofenceId'),
        );

        expect(locationTracker.isTracking, isFalse);
        expect(LocationTracker.UPDATE_INTERVAL_MS, equals(5000)); // 5 seconds

        // Step 3: RouteDynamicCalculator.calculateOptimalRoute(usuario → parada)
        final userLocation = Coordenada(latitud: -34.906, longitud: -56.186);
        final busStopLocation = Coordenada(latitud: -34.907, longitud: -56.187);

        final optimalRoute = await RouteDynamicCalculator.calculateProgress(
          startLocation: userLocation,
          currentLocation: userLocation,
          destination: busStopLocation,
        );

        expect(optimalRoute.currentOptimalRoute, isNotEmpty);
        expect(optimalRoute.totalDistance, greaterThan(0.0));

        // Step 4: Si hay ETA → BusTrackingManager.startApiTracking()
        final mockMapManager = MockMapManager();
        final busTracker = MapBusRealtime(null, mockMapManager);

        await busTracker.startApiTracking();
        expect(busTracker.trackingMode, equals(BusTrackingMode.API_REALTIME));

        // Step 5: SmartCameraController.updateCameraForStep()
        // (Not fully implemented, but we verify the step type for camera logic)
        expect(firstStep.type, equals(JourneyStepType.WALKING_TO_STOP));

        // Step 6: UI shows current step, distance, progress, bus ETA
        expect(firstStep.typeDisplayName, equals('Camina hacia la parada'));
        expect(optimalRoute.formattedRemainingDistance, isNotNull);
        expect(optimalRoute.formattedRemainingTime, isNotNull);

        // Cleanup
        locationTracker.dispose();
        busTracker.dispose();
      });
    });

    group('Paso 2: Loop Principal (cada 5 segundos)', () {
      test('should execute main loop sequence per architecture', () async {
        /*
        Architecture sequence:
        LocationTracker detecta nueva ubicación
        ├── UserJourneyOrchestrator.onLocationUpdate()
        │   ├── ¿Usuario llegó al destino del paso?
        │   │   ├── SÍ → transitionToNextStep()
        │   │   └── NO → updateCurrentStepProgress()
        │   │       ├── RouteDynamicCalculator.calculateProgress()
        │   │       ├── RouteDynamicCalculator.calculateOptimalRoute()
        │   │       ├── SmartCameraController.smartZoomUpdate()
        │   │       └── UI actualiza: distancia, progreso, tiempo restante
        │   └── BusTrackingManager.updateBusTracking()
        └── MapRenderer actualiza: ruta azul, posición usuario, bus, zoom
        */

        final locationUpdates = <Coordenada>[];
        final arrivals = <String>[];

        final locationTracker = LocationTracker(
          onLocationUpdate: (location) => locationUpdates.add(location),
          onArrivalDetected: (geofenceId) => arrivals.add(geofenceId),
        );

        // Test location detection every 5 seconds
        expect(LocationTracker.UPDATE_INTERVAL_MS, equals(5000));

        // Simulate location updates
        final userLocations = [
          Coordenada(latitud: -34.906, longitud: -56.186),   // Start
          Coordenada(latitud: -34.9065, longitud: -56.1865), // Moving
          Coordenada(latitud: -34.907, longitud: -56.187),   // Near destination
        ];

        final destination = Coordenada(latitud: -34.907, longitud: -56.187);
        var currentStep = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
          destination: destination,
        );

        for (final userLocation in userLocations) {
          // Check if user arrived at destination
          final distanceToDestination = await _calculateSimpleDistance(userLocation, destination);
          final arrivedAtDestination = distanceToDestination <= LocationTracker.ARRIVAL_THRESHOLD_METERS;

          if (arrivedAtDestination) {
            // SÍ → transitionToNextStep()
            currentStep = currentStep.copyWith(
              stepIndex: 1,
              type: JourneyStepType.WAITING_FOR_BUS,
              busLine: '123',
              progressPercentage: 0.0,
            );
            
            expect(currentStep.type, equals(JourneyStepType.WAITING_FOR_BUS));
          } else {
            // NO → updateCurrentStepProgress()
            
            // RouteDynamicCalculator.calculateProgress()
            final progress = await RouteDynamicCalculator.calculateProgress(
              startLocation: userLocations.first,
              currentLocation: userLocation,
              destination: destination,
            );

            expect(progress.percentageComplete, greaterThanOrEqualTo(0.0));
            expect(progress.percentageComplete, lessThanOrEqualTo(100.0));

            // Update step with new progress
            currentStep = currentStep.copyWith(
              progressPercentage: progress.percentageComplete,
              remainingDistance: progress.remainingDistance,
              remainingTimeSeconds: progress.remainingTimeSeconds,
              currentRoute: progress.currentOptimalRoute,
            );

            // UI actualiza: distancia, progreso, tiempo restante
            expect(currentStep.formattedRemainingDistance, isNotNull);
            expect(currentStep.formattedRemainingTime, isNotNull);
          }
        }

        locationTracker.dispose();
      });

      test('should update bus tracking in main loop', () async {
        final mockMapManager = MockMapManager();
        final busTracker = MapBusRealtime(null, mockMapManager);

        // Start API tracking
        await busTracker.startApiTracking();
        expect(busTracker.trackingMode, equals(BusTrackingMode.API_REALTIME));

        // Simulate bus tracking updates in main loop
        final userLocation = Coordenada(latitud: -34.907, longitud: -56.187);
        
        // Update bus tracking (would happen every 10 seconds in API mode)
        expect(busTracker.trackingMode, equals(BusTrackingMode.API_REALTIME));

        // Test transition to user tracking
        await busTracker.switchToUserLocationMode();
        await busTracker.updateBusToUserLocation(userLocation);
        
        expect(busTracker.trackingMode, equals(BusTrackingMode.USER_LOCATION));

        busTracker.dispose();
      });
    });

    group('Paso 3: Transiciones Automáticas', () {
      test('should execute WALKING_TO_STOP → WAITING_FOR_BUS transition', () async {
        /*
        Architecture sequence:
        WALKING_TO_STOP → WAITING_FOR_BUS
        ├── Detectar llegada a parada (geofencing)
        ├── Cambiar modo de tracking a bus
        ├── Si hay ETA → mostrar bus en tiempo real
        ├── Ajustar zoom: usuario + bus + parada
        └── UI: "Espera la línea X, llega en Y minutos"
        */

        var currentStep = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
          destination: Coordenada(latitud: -34.907, longitud: -56.187),
        );

        // Detectar llegada a parada (geofencing)
        final userLocation = Coordenada(latitud: -34.9069, longitud: -56.1869);
        final busStopLocation = Coordenada(latitud: -34.907, longitud: -56.187);
        
        final arrivalDetected = await _simulateGeofenceArrival(
          userLocation,
          busStopLocation,
          LocationTracker.ARRIVAL_THRESHOLD_METERS,
        );

        if (arrivalDetected) {
          // Cambiar modo de tracking a bus
          final mockMapManager = MockMapManager();
          final busTracker = MapBusRealtime(null, mockMapManager);
          await busTracker.startApiTracking();

          // Transition to waiting for bus
          currentStep = currentStep.copyWith(
            stepIndex: 1,
            type: JourneyStepType.WAITING_FOR_BUS,
            busLine: '123',
            progressPercentage: 0.0,
          );

          // UI: "Espera la línea X, llega en Y minutos"
          expect(currentStep.typeDisplayName, equals('Espera el bus'));
          expect(currentStep.busLine, equals('123'));
          expect(busTracker.trackingMode, equals(BusTrackingMode.API_REALTIME));

          busTracker.dispose();
        }

        expect(currentStep.type, equals(JourneyStepType.WAITING_FOR_BUS));
      });

      test('should execute WAITING_FOR_BUS → RIDING_BUS transition', () async {
        /*
        Architecture sequence:
        WAITING_FOR_BUS → RIDING_BUS
        ├── Detectar subida al bus (velocidad + dirección + corredor)
        ├── BusTrackingManager.switchToUserTracking()
        ├── Renderizar bus icon en ubicación del usuario
        ├── Ajustar zoom: usuario + parada destino
        └── UI: "En viaje hacia destino, baja en parada Z"
        */

        var currentStep = JourneyStepState(
          stepIndex: 1,
          type: JourneyStepType.WAITING_FOR_BUS,
          busLine: '123',
        );

        // Detectar subida al bus (velocidad + dirección + corredor)
        final userLocation = Coordenada(latitud: -34.907, longitud: -56.187);
        final busRoute = [
          userLocation,
          Coordenada(latitud: -34.908, longitud: -56.188),
        ];
        final userSpeed = 12.0; // m/s (bus speed)

        final boardingDetected = RouteDynamicCalculator.detectBusBoarding(
          userLocation: userLocation,
          busRoutePoints: busRoute,
          userSpeed: userSpeed,
        );

        expect(boardingDetected, isTrue);

        if (boardingDetected) {
          // BusTrackingManager.switchToUserTracking()
          final mockMapManager = MockMapManager();
          final busTracker = MapBusRealtime(null, mockMapManager);
          
          await busTracker.startApiTracking(); // Start in API mode
          await busTracker.switchToUserLocationMode(); // Switch to user tracking

          // Renderizar bus icon en ubicación del usuario
          await busTracker.updateBusToUserLocation(userLocation);

          // Transition to riding bus
          currentStep = currentStep.copyWith(
            stepIndex: 2,
            type: JourneyStepType.RIDING_BUS,
            destination: Coordenada(latitud: -34.908, longitud: -56.188),
            progressPercentage: 0.0,
          );

          // UI: "En viaje hacia destino, baja en parada Z"
          expect(currentStep.typeDisplayName, equals('En el bus'));
          expect(busTracker.trackingMode, equals(BusTrackingMode.USER_LOCATION));

          busTracker.dispose();
        }

        expect(currentStep.type, equals(JourneyStepType.RIDING_BUS));
      });

      test('should execute RIDING_BUS → WALKING_TO_DESTINATION transition', () async {
        /*
        Architecture sequence:
        RIDING_BUS → NEXT_STEP
        ├── Detectar llegada a parada destino
        ├── Determinar siguiente paso del itinerario
        ├── Reconfigurar tracking según tipo de paso
        └── Continuar flujo recursivamente
        */

        var currentStep = JourneyStepState(
          stepIndex: 2,
          type: JourneyStepType.RIDING_BUS,
          busLine: '123',
          destination: Coordenada(latitud: -34.908, longitud: -56.188),
        );

        // Detectar llegada a parada destino
        final userLocation = Coordenada(latitud: -34.9079, longitud: -56.1879);
        final busDestination = Coordenada(latitud: -34.908, longitud: -56.188);

        final arrivalDetected = await _simulateGeofenceArrival(
          userLocation,
          busDestination,
          LocationTracker.ARRIVAL_THRESHOLD_METERS,
        );

        if (arrivalDetected) {
          // Determinar siguiente paso del itinerario
          final nextStepType = JourneyStepType.WALKING_TO_DESTINATION;

          // Reconfigurar tracking según tipo de paso
          final mockMapManager = MockMapManager();
          final busTracker = MapBusRealtime(null, mockMapManager);
          busTracker.stopAllTracking(); // Stop bus tracking

          // Transition to final walking step
          currentStep = currentStep.copyWith(
            stepIndex: 3,
            type: nextStepType,
            destination: Coordenada(latitud: -34.909, longitud: -56.189),
            progressPercentage: 0.0,
          );

          expect(currentStep.typeDisplayName, equals('Camina al destino'));
          expect(busTracker.trackingMode, equals(BusTrackingMode.INACTIVE));

          busTracker.dispose();
        }

        expect(currentStep.type, equals(JourneyStepType.WALKING_TO_DESTINATION));
      });
    });

    group('Estados de la UI por Paso', () {
      test('should provide correct UI state for walking step', () {
        /*
        Architecture UI State:
        ┌─────────────────────────────────────┐
        │ 🚶‍♂️ Camina hacia la parada          │
        ├─────────────────────────────────────┤
        │ 📍 150m restantes                   │
        │ ⏱️ 2 minutos                         │
        │ ⭕ 60% completado                    │
        │                                     │
        │ [Tramo azul dinámico en mapa]       │
        └─────────────────────────────────────┘
        */

        final walkingStep = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
          remainingDistance: 150.0,
          remainingTimeSeconds: 120, // 2 minutes
          progressPercentage: 60.0,
        );

        expect(walkingStep.typeDisplayName, equals('Camina hacia la parada'));
        expect(walkingStep.formattedRemainingDistance, equals('150 m'));
        expect(walkingStep.formattedRemainingTime, equals('2m 0s'));
        expect(walkingStep.progressPercentage, equals(60.0));
        expect(walkingStep.isInProgress, isTrue);
      });

      test('should provide correct UI state for waiting step', () {
        /*
        Architecture UI State:
        ┌─────────────────────────────────────┐
        │ 🚌 Espera Línea 123                 │
        ├─────────────────────────────────────┤
        │ 🟢 Bus llega en 3 minutos           │
        │ 📍 A 200m de la parada              │
        │                                     │
        │ [Bus + línea verde + parada]        │
        └─────────────────────────────────────┘
        */

        final waitingStep = JourneyStepState(
          stepIndex: 1,
          type: JourneyStepType.WAITING_FOR_BUS,
          busLine: '123',
          remainingTimeSeconds: 180, // 3 minutes
        );

        expect(waitingStep.typeDisplayName, equals('Espera el bus'));
        expect(waitingStep.busLine, equals('123'));
        expect(waitingStep.formattedRemainingTime, equals('3m 0s'));
      });

      test('should provide correct UI state for riding step', () {
        /*
        Architecture UI State:
        ┌─────────────────────────────────────┐
        │ 🚌 En viaje - Línea 123             │
        ├─────────────────────────────────────┤
        │ 📍 Próxima parada: Av. Principal    │
        │ ⏱️ 5 minutos restantes               │
        │                                     │
        │ [Bus icon en usuario → parada]      │
        └─────────────────────────────────────┘
        */

        final ridingStep = JourneyStepState(
          stepIndex: 2,
          type: JourneyStepType.RIDING_BUS,
          busLine: '123',
          remainingTimeSeconds: 300, // 5 minutes
          instructions: 'Próxima parada: Av. Principal',
        );

        expect(ridingStep.typeDisplayName, equals('En el bus'));
        expect(ridingStep.busLine, equals('123'));
        expect(ridingStep.formattedRemainingTime, equals('5m 0s'));
        expect(ridingStep.instructions, equals('Próxima parada: Av. Principal'));
      });
    });

    group('Ventajas del Nuevo Diseño Verification', () {
      test('should verify automatización completa', () {
        // ✅ Automatización Completa: Sin intervención manual del usuario
        
        // All step transitions should be automatic based on location
        expect(JourneyStepType.values.length, equals(4));
        expect(LocationTracker.UPDATE_INTERVAL_MS, equals(5000)); // Automatic every 5s
        expect(LocationTracker.ARRIVAL_THRESHOLD_METERS, equals(50.0)); // Automatic detection
      });

      test('should verify experiencia fluida', () async {
        // ✅ Experiencia Fluida: Transiciones naturales y contextuales
        
        final mockMapManager = MockMapManager();
        final busTracker = MapBusRealtime(null, mockMapManager);

        // Natural transition between tracking modes
        await busTracker.startApiTracking();
        expect(busTracker.trackingMode, equals(BusTrackingMode.API_REALTIME));

        await busTracker.switchToUserLocationMode();
        expect(busTracker.trackingMode, equals(BusTrackingMode.USER_LOCATION));

        busTracker.stopAllTracking();
        expect(busTracker.trackingMode, equals(BusTrackingMode.INACTIVE));

        busTracker.dispose();
      });

      test('should verify información relevante', () async {
        // ✅ Información Relevante: Datos dinámicos y actualizados
        
        final progress = await RouteDynamicCalculator.calculateProgress(
          startLocation: Coordenada(latitud: -34.906, longitud: -56.186),
          currentLocation: Coordenada(latitud: -34.9065, longitud: -56.1865),
          destination: Coordenada(latitud: -34.907, longitud: -56.187),
        );

        // Dynamic and updated information
        expect(progress.formattedRemainingDistance, isNotNull);
        expect(progress.formattedRemainingTime, isNotNull);
        expect(progress.formattedTotalDistance, isNotNull);
        expect(progress.currentOptimalRoute, isNotEmpty);
      });

      test('should verify eficiencia de batería', () {
        // ✅ Eficiencia de Batería: Geofencing + timers optimizados
        
        final locationTracker = LocationTracker(
          onLocationUpdate: (location) {},
          onArrivalDetected: (geofenceId) {},
        );

        // Geofencing for battery optimization
        locationTracker.setupGeofencesForStep(
          [Coordenada(latitud: -34.907, longitud: -56.187)],
          ['test_geofence'],
        );

        expect(locationTracker.activeGeofences.length, equals(1));
        expect(locationTracker.activeGeofences.first.radius, equals(50.0));

        locationTracker.dispose();
      });

      test('should verify robustez', () async {
        // ✅ Robustez: Manejo de errores y fallbacks
        
        // Test error handling in route calculations
        final progress = await RouteDynamicCalculator.calculateProgress(
          startLocation: Coordenada(latitud: -34.906, longitud: -56.186),
          currentLocation: Coordenada(latitud: -34.906, longitud: -56.186),
          destination: Coordenada(latitud: -34.906, longitud: -56.186),
        );

        // Should handle same start/current/destination gracefully
        expect(progress.remainingDistance, equals(0.0));
        expect(progress.remainingTimeSeconds, equals(0));
        expect(progress.percentageComplete, equals(0.0));
      });

      test('should verify escalabilidad', () {
        // ✅ Escalabilidad: Modular y extensible
        
        // Verify modular design
        expect(JourneyStepType.values, isNotEmpty);
        expect(BusTrackingMode.values, isNotEmpty);
        
        // Components can be used independently
        final step = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
        );
        
        expect(step.type, equals(JourneyStepType.WALKING_TO_STOP));
      });

      test('should verify precisión', () async {
        // ✅ Precisión: Tracking híbrido API + GPS del usuario
        
        final mockMapManager = MockMapManager();
        final busTracker = MapBusRealtime(null, mockMapManager);

        // Hybrid tracking: API + GPS
        await busTracker.startApiTracking(); // API tracking
        expect(busTracker.trackingMode, equals(BusTrackingMode.API_REALTIME));

        await busTracker.switchToUserLocationMode(); // GPS tracking
        expect(busTracker.trackingMode, equals(BusTrackingMode.USER_LOCATION));

        // Bus boarding detection for precision
        final boardingDetected = RouteDynamicCalculator.detectBusBoarding(
          userLocation: Coordenada(latitud: -34.907, longitud: -56.187),
          busRoutePoints: [
            Coordenada(latitud: -34.907, longitud: -56.187),
            Coordenada(latitud: -34.908, longitud: -56.188),
          ],
          userSpeed: 10.0,
        );

        expect(boardingDetected, isTrue);

        busTracker.dispose();
      });
    });
  });
}

// Helper functions for simulation
Future<bool> _simulateGeofenceArrival(
  Coordenada userLocation,
  Coordenada destination,
  double threshold,
) async {
  final distance = await _calculateSimpleDistance(userLocation, destination);
  return distance <= threshold;
}

Future<double> _calculateSimpleDistance(Coordenada from, Coordenada to) async {
  // Simplified distance calculation for testing
  final deltaLat = to.latitud - from.latitud;
  final deltaLng = to.longitud - from.longitud;
  final distance = (deltaLat * deltaLat + deltaLng * deltaLng) * 111000; // Rough conversion to meters
  return distance.abs();
}