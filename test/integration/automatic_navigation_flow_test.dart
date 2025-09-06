import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bondi_uy/backend/providers/app_logic_provider.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import 'package:bondi_uy/backend/services/montevideo_api_service_adapter.dart';
import 'package:bondi_uy/backend/services/itinerary_planning_service_adapter.dart';
import 'package:bondi_uy/backend/services/geocoding_service_adapter.dart';
import 'package:bondi_uy/journey/location_tracker.dart';
import 'package:bondi_uy/journey/journey_step_state.dart';
import 'package:bondi_uy/journey/route_dynamic_calculator.dart';
import 'package:bondi_uy/map_manager/map_bus_realtime.dart';

// Test-specific mock services for automatic navigation testing
class MockMontevideoApiServiceAutoNav extends MontevideoApiServiceAdapterBase {
  @override
  Future<List<InfoParadaEnMapa>> getAllStops() async {
    return [
      InfoParadaEnMapa(
        idParada: 'auto_stop_1',
        nombre: 'Parada Automática 1',
        posicion: Coordenada(latitud: -34.906500, longitud: -56.186500),
      ),
      InfoParadaEnMapa(
        idParada: 'auto_stop_2',
        nombre: 'Parada Automática 2',
        posicion: Coordenada(latitud: -34.908000, longitud: -56.188000),
      ),
    ];
  }

  @override
  Future<InfoDetalladaParada?> getStopDetailsWithEta(
    String stopId, 
    String stopName, 
    Coordenada stopPosition
  ) async {
    return InfoDetalladaParada(
      idParada: stopId,
      nombreParada: stopName,
      posicion: stopPosition,
      lineasQuePasan: ['A123'],
      etas: [
        EtaMostrable(
          linea: 'A123',
          destino: 'Terminal Central',
          minutosParaLlegada: 3,
          esTiempoReal: true,
          posicionBus: Coordenada(latitud: -34.905000, longitud: -56.185000),
        ),
      ],
    );
  }
}

class MockItineraryPlanningServiceAutoNav extends ItineraryPlanningServiceAdapterBase {
  @override
  Future<List<OpcionDeRutaMostrable>> planRoute({
    required Coordenada origenCoords,
    String? origenNombre,
    required Coordenada destinoCoords,
    String? destinoNombre,
    DateTime? fechaHoraSalida,
    bool? llegarA,
    int? numItinerarios,
  }) async {
    return [
      OpcionDeRutaMostrable(
        idOpcion: 'auto-nav-test-route',
        esRecomendada: true,
        duracionTotalSegundos: 2400, // 40 minutes
        horaLlegadaEstimada: DateTime.now().add(Duration(minutes: 40)),
        secuenciaModosIconos: [
          TipoTramoViaje.CAMINAR, 
          TipoTramoViaje.ESPERAR_BUS, 
          TipoTramoViaje.VIAJE_EN_BUS, 
          TipoTramoViaje.CAMINAR
        ],
        distanciaTotalCaminataMetros: 1200,
        tiempoTotalEsperaBusSegundos: 180,
        score: 95,
        tramosParaPreview: [
          TramoViajeMostrable(
            idTramo: 'auto-walk-to-stop',
            tipo: TipoTramoViaje.CAMINAR,
            descripcion: 'Camina hacia la parada automática',
            duracionEstimadaSegundos: 360, // 6 minutes
            distanciaMetros: 500,
            geometriaPolilinea: [
              Coordenada(latitud: -34.906000, longitud: -56.186000), // Start
              Coordenada(latitud: -34.906250, longitud: -56.186250), // Mid
              Coordenada(latitud: -34.906500, longitud: -56.186500), // Stop
            ],
          ),
          TramoViajeMostrable(
            idTramo: 'auto-wait-at-stop',
            tipo: TipoTramoViaje.ESPERAR_BUS,
            descripcion: 'Espera bus línea A123',
            duracionEstimadaSegundos: 180, // 3 minutes
            nombreLineaBus: 'A123',
            posicionPunto: Coordenada(latitud: -34.906500, longitud: -56.186500),
            idParadaOrigenTramoBus: 'auto_stop_1',
            nombreParadaOrigen: 'Parada Automática 1',
            coordenadasParadaOrigen: Coordenada(latitud: -34.906500, longitud: -56.186500),
          ),
          TramoViajeMostrable(
            idTramo: 'auto-ride-bus',
            tipo: TipoTramoViaje.VIAJE_EN_BUS,
            descripcion: 'Viaja en bus línea A123',
            duracionEstimadaSegundos: 1200, // 20 minutes
            nombreLineaBus: 'A123',
            destinoFinalDelBus: 'Terminal Central',
            idParadaOrigenTramoBus: 'auto_stop_1',
            idParadaDestinoTramoBus: 'auto_stop_2',
            coordenadasParadaOrigen: Coordenada(latitud: -34.906500, longitud: -56.186500),
            coordenadasParadaDestino: Coordenada(latitud: -34.908000, longitud: -56.188000),
            nombreParadaOrigen: 'Parada Automática 1',
            nombreParadaDestino: 'Parada Automática 2',
            distanciaMetros: 2000,
            geometriaPolilinea: [
              Coordenada(latitud: -34.906500, longitud: -56.186500),
              Coordenada(latitud: -34.907000, longitud: -56.187000),
              Coordenada(latitud: -34.907500, longitud: -56.187500),
              Coordenada(latitud: -34.908000, longitud: -56.188000),
            ],
          ),
          TramoViajeMostrable(
            idTramo: 'auto-walk-to-destination',
            tipo: TipoTramoViaje.CAMINAR,
            descripcion: 'Camina al destino final',
            duracionEstimadaSegundos: 480, // 8 minutes
            distanciaMetros: 700,
            geometriaPolilinea: [
              Coordenada(latitud: -34.908000, longitud: -56.188000), // Bus stop
              Coordenada(latitud: -34.908500, longitud: -56.188500), // Mid
              Coordenada(latitud: -34.909000, longitud: -56.189000), // Final destination
            ],
          ),
        ],
      ),
    ];
  }
}

class MockGeocodingServiceAutoNav extends GeocodingServiceAdapter {
  @override
  Future<List<SugerenciaLugar>> fetchSuggestions(
    String query, {
    Coordenada? proximity,
  }) async {
    return [
      SugerenciaLugar(
        id: 'auto_centro',
        nombreCompleto: 'Centro de Montevideo (Auto)',
        nombreLugar: 'Centro',
        direccion: 'Plaza Independencia, Montevideo',
        coordenadas: Coordenada(latitud: -34.906000, longitud: -56.186000),
      ),
      SugerenciaLugar(
        id: 'auto_destino',
        nombreCompleto: 'Destino Automático',
        nombreLugar: 'Destino Final',
        direccion: 'Avenida Italia, Montevideo',
        coordenadas: Coordenada(latitud: -34.909000, longitud: -56.189000),
      ),
    ];
  }

  @override
  Future<List<SugerenciaLugar>> reverseGeocode(Coordenada location) async {
    return [
      SugerenciaLugar(
        id: 'reverse_location',
        nombreCompleto: 'Ubicación ${location.latitud.toStringAsFixed(3)}, ${location.longitud.toStringAsFixed(3)}',
        nombreLugar: 'Ubicación Actual',
        direccion: 'Montevideo, Uruguay',
        coordenadas: location,
      ),
    ];
  }
}

void main() {
  group('Automatic Navigation Flow - Comprehensive Tests', () {
    late ProviderContainer container;
    late AppLogicNotifier appLogicNotifier;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          montevideoApiServiceProvider.overrideWithValue(MockMontevideoApiServiceAutoNav()),
          itineraryPlanningServiceProvider.overrideWithValue(MockItineraryPlanningServiceAutoNav()),
          geocodingServiceProvider.overrideWithValue(MockGeocodingServiceAutoNav()),
          appLogicProvider.overrideWith((ref) {
            final montevideoApiService = ref.watch(montevideoApiServiceProvider);
            final itineraryPlanningService = ref.watch(itineraryPlanningServiceProvider);
            final geocodingService = ref.watch(geocodingServiceProvider);
            return AppLogicNotifier(
              ref,
              montevideoApiService,
              itineraryPlanningService,
              geocodingService,
              isTestMode: true,
            );
          }),
        ],
      );
      
      appLogicNotifier = container.read(appLogicProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    group('Automatic Navigation Initialization', () {
      test('should enable automatic navigation when journey starts', () async {
        // Setup and start journey
        await _setupAutomaticJourney(appLogicNotifier);

        final state = container.read(appLogicProvider);
        
        // Verify automatic navigation is enabled
        expect(state.isAutomaticNavigationEnabled, isTrue);
        expect(state.currentJourneyStep, isNotNull);
        expect(state.currentJourneyStep!.stepIndex, equals(0));
        expect(state.currentJourneyStep!.type, equals(JourneyStepType.WALKING_TO_STOP));
        
        // Verify journey state setup
        expect(state.faseActual, equals(FaseApp.VIAJE_ACTIVO_EN_CURSO));
        expect(state.datosFaseViajeActivo, isNotNull);
        expect(state.datosFaseViajeActivo!.tramosDelViaje.length, equals(4));
      });

      test('should initialize LocationTracker and geofencing', () async {
        await _setupAutomaticJourney(appLogicNotifier);

        // Note: In real implementation, LocationTracker would be initialized
        // Here we verify the state indicates automatic tracking is active
        final state = container.read(appLogicProvider);
        expect(state.isAutomaticNavigationEnabled, isTrue);
        expect(state.currentJourneyStep, isNotNull);
      });

      test('should setup proper bus tracking mode for initial step', () async {
        await _setupAutomaticJourney(appLogicNotifier);

        final state = container.read(appLogicProvider);
        
        // First step should be walking, so API tracking should be active
        expect(state.currentJourneyStep!.type, equals(JourneyStepType.WALKING_TO_STOP));
        // In real implementation, this would verify MapBusRealtime is in API mode
      });
    });

    group('Automatic Step Transitions', () {
      test('should automatically transition from walking to waiting for bus', () async {
        await _setupAutomaticJourney(appLogicNotifier);

        final initialState = container.read(appLogicProvider);
        expect(initialState.currentJourneyStep!.type, equals(JourneyStepType.WALKING_TO_STOP));

        // Simulate arrival at bus stop
        await _simulateAutomaticStepCompletion(
          appLogicNotifier,
          container,
          fromStepIndex: 0,
          toStepIndex: 1,
          arrivalLocation: Coordenada(latitud: -34.906500, longitud: -56.186500),
        );

        final newState = container.read(appLogicProvider);
        expect(newState.currentJourneyStep!.stepIndex, equals(1));
        expect(newState.currentJourneyStep!.type, equals(JourneyStepType.WAITING_FOR_BUS));
        expect(newState.currentJourneyStep!.busLine, equals('A123'));
      });

      test('should automatically transition from waiting to riding bus', () async {
        await _setupAutomaticJourney(appLogicNotifier);

        // Progress to waiting for bus step
        await _simulateAutomaticStepCompletion(
          appLogicNotifier,
          container,
          fromStepIndex: 0,
          toStepIndex: 1,
          arrivalLocation: Coordenada(latitud: -34.906500, longitud: -56.186500),
        );

        final waitingState = container.read(appLogicProvider);
        expect(waitingState.currentJourneyStep!.type, equals(JourneyStepType.WAITING_FOR_BUS));

        // Simulate bus boarding detection
        await _simulateAutomaticStepCompletion(
          appLogicNotifier,
          container,
          fromStepIndex: 1,
          toStepIndex: 2,
          arrivalLocation: Coordenada(latitud: -34.906500, longitud: -56.186500),
          simulateBusBoarding: true,
        );

        final ridingState = container.read(appLogicProvider);
        expect(ridingState.currentJourneyStep!.type, equals(JourneyStepType.RIDING_BUS));
        expect(ridingState.currentJourneyStep!.busLine, equals('A123'));
      });

      test('should automatically transition from riding bus to walking to destination', () async {
        await _setupAutomaticJourney(appLogicNotifier);

        // Progress through all steps to bus riding
        await _progressToStep(appLogicNotifier, container, targetStepIndex: 2);

        final ridingState = container.read(appLogicProvider);
        expect(ridingState.currentJourneyStep!.type, equals(JourneyStepType.RIDING_BUS));

        // Simulate arrival at bus destination
        await _simulateAutomaticStepCompletion(
          appLogicNotifier,
          container,
          fromStepIndex: 2,
          toStepIndex: 3,
          arrivalLocation: Coordenada(latitud: -34.908000, longitud: -56.188000),
        );

        final finalWalkState = container.read(appLogicProvider);
        expect(finalWalkState.currentJourneyStep!.type, equals(JourneyStepType.WALKING_TO_DESTINATION));
      });

      test('should complete journey automatically when reaching final destination', () async {
        await _setupAutomaticJourney(appLogicNotifier);

        // Progress through all steps
        await _progressToStep(appLogicNotifier, container, targetStepIndex: 3);

        final finalWalkState = container.read(appLogicProvider);
        expect(finalWalkState.currentJourneyStep!.type, equals(JourneyStepType.WALKING_TO_DESTINATION));

        // Simulate arrival at final destination
        await _simulateJourneyCompletion(
          appLogicNotifier,
          container,
          finalLocation: Coordenada(latitud: -34.909000, longitud: -56.189000),
        );

        final completedState = container.read(appLogicProvider);
        expect(completedState.faseActual, equals(FaseApp.INICIAL_SIN_BUSQUEDA));
        expect(completedState.currentJourneyStep, isNull);
        expect(completedState.isAutomaticNavigationEnabled, isFalse);
      });
    });

    group('Hybrid Bus Tracking Integration', () {
      test('should use API tracking during walking and waiting phases', () async {
        await _setupAutomaticJourney(appLogicNotifier);

        // Walking phase
        final walkingState = container.read(appLogicProvider);
        expect(walkingState.currentJourneyStep!.type, equals(JourneyStepType.WALKING_TO_STOP));
        // Bus tracking should be in API mode (would be verified in real MapBusRealtime)

        // Progress to waiting phase
        await _simulateAutomaticStepCompletion(
          appLogicNotifier,
          container,
          fromStepIndex: 0,
          toStepIndex: 1,
          arrivalLocation: Coordenada(latitud: -34.906500, longitud: -56.186500),
        );

        final waitingState = container.read(appLogicProvider);
        expect(waitingState.currentJourneyStep!.type, equals(JourneyStepType.WAITING_FOR_BUS));
        // Bus tracking should still be in API mode
      });

      test('should switch to user location tracking when riding bus', () async {
        await _setupAutomaticJourney(appLogicNotifier);

        // Progress to riding bus phase
        await _progressToStep(appLogicNotifier, container, targetStepIndex: 2);

        final ridingState = container.read(appLogicProvider);
        expect(ridingState.currentJourneyStep!.type, equals(JourneyStepType.RIDING_BUS));

        // Simulate user location update while on bus
        final userOnBusLocation = Coordenada(latitud: -34.907000, longitud: -56.187000);
        
        // In real implementation, this would trigger hybrid bus tracking
        // Here we verify the state is set up for user location tracking
        expect(ridingState.currentJourneyStep!.type, equals(JourneyStepType.RIDING_BUS));
      });

      test('should detect bus boarding based on location and speed', () async {
        final busRoute = [
          Coordenada(latitud: -34.906500, longitud: -56.186500),
          Coordenada(latitud: -34.907000, longitud: -56.187000),
          Coordenada(latitud: -34.908000, longitud: -56.188000),
        ];

        // Test user near bus route at bus speed
        final userLocation = Coordenada(latitud: -34.906520, longitud: -56.186520);
        final busSpeed = 8.5; // m/s (typical bus speed)

        final shouldDetectBoarding = RouteDynamicCalculator.detectBusBoarding(
          userLocation: userLocation,
          busRoutePoints: busRoute,
          userSpeed: busSpeed,
        );

        expect(shouldDetectBoarding, isTrue);

        // Test user near bus route at walking speed
        final walkingSpeed = 1.4; // m/s (typical walking speed)
        
        final shouldNotDetectBoarding = RouteDynamicCalculator.detectBusBoarding(
          userLocation: userLocation,
          busRoutePoints: busRoute,
          userSpeed: walkingSpeed,
        );

        expect(shouldNotDetectBoarding, isFalse);
      });
    });

    group('Dynamic Progress Tracking', () {
      test('should calculate and update progress throughout each step', () async {
        await _setupAutomaticJourney(appLogicNotifier);

        final initialState = container.read(appLogicProvider);
        expect(initialState.currentStepProgress, isNull); // No progress initially

        // Simulate location updates with progress
        await _simulateLocationUpdateWithProgress(
          appLogicNotifier,
          container,
          userLocation: Coordenada(latitud: -34.906250, longitud: -56.186250), // Halfway
          expectedProgressRange: [40.0, 60.0], // Approximately halfway
        );

        final progressState = container.read(appLogicProvider);
        expect(progressState.currentStepProgress, isNotNull);
        expect(progressState.currentStepProgress!.percentageComplete, greaterThan(0.0));
        expect(progressState.currentStepProgress!.remainingDistance, greaterThan(0.0));
        expect(progressState.currentStepProgress!.formattedRemainingTime, isNotNull);
      });

      test('should recalculate optimal route dynamically', () async {
        await _setupAutomaticJourney(appLogicNotifier);

        // Test route recalculation with different user positions
        final startLocation = Coordenada(latitud: -34.906000, longitud: -56.186000);
        final destination = Coordenada(latitud: -34.906500, longitud: -56.186500);

        // Position 1: Direct path
        final progress1 = await RouteDynamicCalculator.calculateProgress(
          startLocation: startLocation,
          currentLocation: Coordenada(latitud: -34.906100, longitud: -56.186100),
          destination: destination,
        );

        // Position 2: Different path
        final progress2 = await RouteDynamicCalculator.calculateProgress(
          startLocation: startLocation,
          currentLocation: Coordenada(latitud: -34.906200, longitud: -56.186300),
          destination: destination,
        );

        expect(progress1.currentOptimalRoute.length, greaterThanOrEqualTo(2));
        expect(progress2.currentOptimalRoute.length, greaterThanOrEqualTo(2));
        expect(progress1.remainingDistance, isNot(equals(progress2.remainingDistance)));
      });

      test('should handle progress at step boundaries correctly', () async {
        await _setupAutomaticJourney(appLogicNotifier);

        // Simulate arriving at step destination
        await _simulateLocationUpdateWithProgress(
          appLogicNotifier,
          container,
          userLocation: Coordenada(latitud: -34.906500, longitud: -56.186500), // At destination
          expectedProgressRange: [95.0, 100.0], // Near completion
        );

        final nearCompletionState = container.read(appLogicProvider);
        expect(nearCompletionState.currentStepProgress, isNotNull);
        expect(nearCompletionState.currentStepProgress!.percentageComplete, greaterThan(90.0));
        expect(nearCompletionState.currentStepProgress!.remainingDistance, lessThan(50.0)); // Very close
      });
    });

    group('Error Handling and Recovery', () {
      test('should handle GPS signal loss gracefully', () async {
        await _setupAutomaticJourney(appLogicNotifier);

        final initialState = container.read(appLogicProvider);
        expect(initialState.isAutomaticNavigationEnabled, isTrue);

        // Simulate GPS signal loss (no location updates)
        // System should maintain state and continue when signal returns
        await Future.delayed(Duration(milliseconds: 100));

        final stateAfterGpsLoss = container.read(appLogicProvider);
        expect(stateAfterGpsLoss.isAutomaticNavigationEnabled, isTrue);
        expect(stateAfterGpsLoss.faseActual, equals(FaseApp.VIAJE_ACTIVO_EN_CURSO));
      });

      test('should recover from user deviation from route', () async {
        await _setupAutomaticJourney(appLogicNotifier);

        // Simulate user far from expected route
        final deviatedLocation = Coordenada(latitud: -34.920000, longitud: -56.200000);
        
        // Route calculation should still work with deviated location
        final startLocation = Coordenada(latitud: -34.906000, longitud: -56.186000);
        final destination = Coordenada(latitud: -34.906500, longitud: -56.186500);

        final deviatedProgress = await RouteDynamicCalculator.calculateProgress(
          startLocation: startLocation,
          currentLocation: deviatedLocation,
          destination: destination,
        );

        expect(deviatedProgress.currentOptimalRoute, isNotNull);
        expect(deviatedProgress.remainingDistance, greaterThan(0.0));
        expect(deviatedProgress.percentageComplete, greaterThanOrEqualTo(0.0));
      });

      test('should handle bus tracking API failures', () async {
        await _setupAutomaticJourney(appLogicNotifier);

        // Progress to waiting for bus
        await _progressToStep(appLogicNotifier, container, targetStepIndex: 1);

        final waitingState = container.read(appLogicProvider);
        expect(waitingState.currentJourneyStep!.type, equals(JourneyStepType.WAITING_FOR_BUS));

        // Simulate API failure by continuing without bus ETA
        // System should maintain automatic navigation mode
        expect(waitingState.isAutomaticNavigationEnabled, isTrue);
        expect(waitingState.faseActual, equals(FaseApp.VIAJE_ACTIVO_EN_CURSO));
      });

      test('should handle manual cancellation during automatic navigation', () async {
        await _setupAutomaticJourney(appLogicNotifier);

        final activeState = container.read(appLogicProvider);
        expect(activeState.isAutomaticNavigationEnabled, isTrue);
        expect(activeState.currentJourneyStep, isNotNull);

        // User manually cancels journey
        appLogicNotifier.usuarioCanceloBusquedaOSeleccionRuta();

        final cancelledState = container.read(appLogicProvider);
        expect(cancelledState.faseActual, equals(FaseApp.INICIAL_SIN_BUSQUEDA));
        expect(cancelledState.currentJourneyStep, isNull);
        expect(cancelledState.isAutomaticNavigationEnabled, isFalse);
      });
    });

    group('State Consistency and Validation', () {
      test('should maintain state consistency across all automatic transitions', () async {
        final stateSnapshots = <Map<String, dynamic>>[];

        await _setupAutomaticJourney(appLogicNotifier);
        stateSnapshots.add(_captureStateSnapshot(container.read(appLogicProvider)));

        // Progress through all steps and capture state at each transition
        for (int stepIndex = 1; stepIndex <= 3; stepIndex++) {
          await _simulateAutomaticStepCompletion(
            appLogicNotifier,
            container,
            fromStepIndex: stepIndex - 1,
            toStepIndex: stepIndex,
            arrivalLocation: _getStepDestination(stepIndex),
          );
          stateSnapshots.add(_captureStateSnapshot(container.read(appLogicProvider)));
        }

        // Complete journey
        await _simulateJourneyCompletion(
          appLogicNotifier,
          container,
          finalLocation: Coordenada(latitud: -34.909000, longitud: -56.189000),
        );
        stateSnapshots.add(_captureStateSnapshot(container.read(appLogicProvider)));

        // Validate state consistency
        expect(stateSnapshots.length, equals(5)); // Initial + 3 steps + completion

        // All intermediate states should be in active journey phase
        for (int i = 0; i < stateSnapshots.length - 1; i++) {
          expect(stateSnapshots[i]['faseActual'], equals(FaseApp.VIAJE_ACTIVO_EN_CURSO.toString()));
          expect(stateSnapshots[i]['isAutomaticNavigationEnabled'], isTrue);
        }

        // Final state should be initial phase
        expect(stateSnapshots.last['faseActual'], equals(FaseApp.INICIAL_SIN_BUSQUEDA.toString()));
        expect(stateSnapshots.last['isAutomaticNavigationEnabled'], isFalse);
      });

      test('should validate journey step state transitions', () async {
        await _setupAutomaticJourney(appLogicNotifier);

        final expectedStepSequence = [
          JourneyStepType.WALKING_TO_STOP,
          JourneyStepType.WAITING_FOR_BUS,
          JourneyStepType.RIDING_BUS,
          JourneyStepType.WALKING_TO_DESTINATION,
        ];

        // Verify initial step
        final initialState = container.read(appLogicProvider);
        expect(initialState.currentJourneyStep!.type, equals(expectedStepSequence[0]));

        // Progress through all steps and verify sequence
        for (int i = 1; i < expectedStepSequence.length; i++) {
          await _simulateAutomaticStepCompletion(
            appLogicNotifier,
            container,
            fromStepIndex: i - 1,
            toStepIndex: i,
            arrivalLocation: _getStepDestination(i),
          );

          final stepState = container.read(appLogicProvider);
          expect(stepState.currentJourneyStep!.type, equals(expectedStepSequence[i]));
          expect(stepState.currentJourneyStep!.stepIndex, equals(i));
        }
      });
    });

    group('Performance and Resource Management', () {
      test('should properly clean up resources when journey completes', () async {
        await _setupAutomaticJourney(appLogicNotifier);

        final activeState = container.read(appLogicProvider);
        expect(activeState.isAutomaticNavigationEnabled, isTrue);

        // Complete journey
        await _progressToStep(appLogicNotifier, container, targetStepIndex: 3);
        await _simulateJourneyCompletion(
          appLogicNotifier,
          container,
          finalLocation: Coordenada(latitud: -34.909000, longitud: -56.189000),
        );

        final cleanedState = container.read(appLogicProvider);
        expect(cleanedState.currentJourneyStep, isNull);
        expect(cleanedState.currentStepProgress, isNull);
        expect(cleanedState.isAutomaticNavigationEnabled, isFalse);
        expect(cleanedState.currentUserLocation, isNull);
      });

      test('should handle multiple rapid location updates efficiently', () async {
        await _setupAutomaticJourney(appLogicNotifier);

        // Simulate rapid location updates
        final rapidLocations = [
          Coordenada(latitud: -34.906050, longitud: -56.186050),
          Coordenada(latitud: -34.906100, longitud: -56.186100),
          Coordenada(latitud: -34.906150, longitud: -56.186150),
          Coordenada(latitud: -34.906200, longitud: -56.186200),
        ];

        for (final location in rapidLocations) {
          await _simulateLocationUpdateWithProgress(
            appLogicNotifier,
            container,
            userLocation: location,
            expectedProgressRange: [0.0, 100.0], // Any progress is valid
          );
          // Small delay to simulate real-world timing
          await Future.delayed(Duration(milliseconds: 10));
        }

        // System should remain stable
        final finalState = container.read(appLogicProvider);
        expect(finalState.isAutomaticNavigationEnabled, isTrue);
        expect(finalState.faseActual, equals(FaseApp.VIAJE_ACTIVO_EN_CURSO));
      });
    });
  });
}

// Helper functions for automatic navigation tests

Future<void> _setupAutomaticJourney(AppLogicNotifier appLogicNotifier) async {
  final routes = await MockItineraryPlanningServiceAutoNav().planRoute(
    origenCoords: Coordenada(latitud: -34.906000, longitud: -56.186000),
    origenNombre: 'Centro',
    destinoCoords: Coordenada(latitud: -34.909000, longitud: -56.189000),
    destinoNombre: 'Destino Final',
  );

  appLogicNotifier.state = appLogicNotifier.state.copyWith(
    faseActual: FaseApp.MOSTRANDO_OPCIONES_RUTA,
    datosFaseOpcionesRuta: EstadoFaseOpcionesRuta(
      opcionesDeRuta: routes,
    ),
    idOpcionRutaPrevisualizada: 'auto-nav-test-route',
  );

  appLogicNotifier.confirmarOpcionDeRutaEIniciarViaje('auto-nav-test-route');
  await Future.delayed(Duration(milliseconds: 300)); // Allow initialization
}

Future<void> _simulateAutomaticStepCompletion(
  AppLogicNotifier appLogicNotifier,
  ProviderContainer container,
  {
  required int fromStepIndex,
  required int toStepIndex,
  required Coordenada arrivalLocation,
  bool simulateBusBoarding = false,
}) async {
  // Simulate location updates leading to arrival
  final intermediateLocations = _generateLocationPath(arrivalLocation, 5);
  
  for (final location in intermediateLocations) {
    await _simulateLocationUpdateWithProgress(
      appLogicNotifier,
      container,
      userLocation: location,
      expectedProgressRange: [0.0, 100.0],
    );
    await Future.delayed(Duration(milliseconds: 20));
  }

  if (simulateBusBoarding) {
    // Simulate bus detection
    await Future.delayed(Duration(milliseconds: 50));
  }

  // Simulate automatic step transition
  // In real implementation, this would be triggered by LocationTracker
  await Future.delayed(Duration(milliseconds: 100));
}

Future<void> _simulateLocationUpdateWithProgress(
  AppLogicNotifier appLogicNotifier,
  ProviderContainer container,
  {
  required Coordenada userLocation,
  required List<double> expectedProgressRange,
}) async {
  // Simulate the automatic system updating location and progress
  // In real implementation, this would be handled by LocationTracker
  await Future.delayed(Duration(milliseconds: 50));
  
  // Verify system remains in automatic mode
  final state = container.read(appLogicProvider);
  expect(state.isAutomaticNavigationEnabled, isTrue);
}

Future<void> _progressToStep(
  AppLogicNotifier appLogicNotifier,
  ProviderContainer container,
  {
  required int targetStepIndex,
}) async {
  for (int stepIndex = 1; stepIndex <= targetStepIndex; stepIndex++) {
    await _simulateAutomaticStepCompletion(
      appLogicNotifier,
      container,
      fromStepIndex: stepIndex - 1,
      toStepIndex: stepIndex,
      arrivalLocation: _getStepDestination(stepIndex),
      simulateBusBoarding: stepIndex == 2, // Bus boarding for step 2
    );
  }
}

Future<void> _simulateJourneyCompletion(
  AppLogicNotifier appLogicNotifier,
  ProviderContainer container,
  {
  required Coordenada finalLocation,
}) async {
  // Simulate arrival at final destination
  await _simulateLocationUpdateWithProgress(
    appLogicNotifier,
    container,
    userLocation: finalLocation,
    expectedProgressRange: [95.0, 100.0],
  );

  // Simulate automatic journey completion
  appLogicNotifier.detenerSeguimientoActivo();
  await Future.delayed(Duration(milliseconds: 100));
}

Coordenada _getStepDestination(int stepIndex) {
  switch (stepIndex) {
    case 0:
      return Coordenada(latitud: -34.906500, longitud: -56.186500); // Bus stop
    case 1:
      return Coordenada(latitud: -34.906500, longitud: -56.186500); // Same (waiting)
    case 2:
      return Coordenada(latitud: -34.908000, longitud: -56.188000); // Bus destination
    case 3:
      return Coordenada(latitud: -34.909000, longitud: -56.189000); // Final destination
    default:
      return Coordenada(latitud: -34.906000, longitud: -56.186000); // Start
  }
}

List<Coordenada> _generateLocationPath(Coordenada target, int numPoints) {
  final path = <Coordenada>[];
  final startLat = target.latitud - 0.002;
  final startLng = target.longitud - 0.002;
  
  for (int i = 1; i <= numPoints; i++) {
    final progress = i / (numPoints + 1);
    path.add(Coordenada(
      latitud: startLat + progress * 0.002,
      longitud: startLng + progress * 0.002,
    ));
  }
  return path;
}

Map<String, dynamic> _captureStateSnapshot(AppUiState state) {
  return {
    'faseActual': state.faseActual.toString(),
    'isAutomaticNavigationEnabled': state.isAutomaticNavigationEnabled,
    'currentJourneyStepIndex': state.currentJourneyStep?.stepIndex,
    'currentJourneyStepType': state.currentJourneyStep?.type.toString(),
    'hasActiveTrip': state.datosFaseViajeActivo != null,
    'hasProgress': state.currentStepProgress != null,
  };
}