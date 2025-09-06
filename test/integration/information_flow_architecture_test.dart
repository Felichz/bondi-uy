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
import 'package:bondi_uy/map_manager/map_manager.dart';

/// Integration tests specifically for the Information Flow Architecture
/// as described in docs/flujos/flujo-principal/3-flujo-informacion.md
/// 
/// These tests verify the coordination between all subsystems:
/// - UserJourneyOrchestrator (AppLogicNotifier)
/// - LocationTracker
/// - BusTrackingManager (MapBusRealtime)  
/// - RouteDynamicCalculator
/// - SmartCameraController (not fully implemented, but tested where possible)

// Mock services for architecture testing
class MockMontevideoApiService extends MontevideoApiServiceAdapterBase {
  int apiCallCount = 0;
  
  @override
  Future<List<InfoParadaEnMapa>> getAllStops() async {
    apiCallCount++;
    return [
      InfoParadaEnMapa(
        idParada: 'stop_architecture_test',
        nombre: 'Parada Arquitectura Test',
        posicion: Coordenada(latitud: -34.907, longitud: -56.187),
      ),
    ];
  }

  @override
  Future<InfoDetalladaParada?> getStopDetailsWithEta(
    String stopId, 
    String stopName, 
    Coordenada stopPosition
  ) async {
    apiCallCount++;
    return InfoDetalladaParada(
      idParada: stopId,
      nombreParada: stopName,
      posicion: stopPosition,
      lineasQuePasan: ['123'],
      etas: [
        EtaMostrable(
          linea: '123',
          destino: 'Centro',
          minutosParaLlegada: 3,
          esTiempoReal: true,
        ),
      ],
    );
  }
}

class MockItineraryPlanningService extends ItineraryPlanningServiceAdapterBase {
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
        idOpcion: 'architecture-test-route',
        esRecomendada: true,
        duracionTotalSegundos: 1200, // 20 minutes
        horaLlegadaEstimada: DateTime.now().add(Duration(minutes: 20)),
        secuenciaModosIconos: [TipoTramoViaje.CAMINAR, TipoTramoViaje.ESPERAR_BUS, TipoTramoViaje.VIAJE_EN_BUS, TipoTramoViaje.CAMINAR],
        distanciaTotalCaminataMetros: 600,
        tiempoTotalEsperaBusSegundos: 180,
        score: 100,
        tramosParaPreview: [
          // Step 1: WALKING_TO_STOP
          TramoViajeMostrable(
            idTramo: 'walk-to-stop-arch',
            tipo: TipoTramoViaje.CAMINAR,
            descripcion: 'Camina hacia parada',
            duracionEstimadaSegundos: 240, // 4 minutes
            distanciaMetros: 300,
            geometriaPolilinea: [
              Coordenada(latitud: -34.906, longitud: -56.186),
              Coordenada(latitud: -34.907, longitud: -56.187),
            ],
          ),
          // Step 2: WAITING_FOR_BUS
          TramoViajeMostrable(
            idTramo: 'wait-bus-arch',
            tipo: TipoTramoViaje.ESPERAR_BUS,
            descripcion: 'Espera bus línea 123',
            duracionEstimadaSegundos: 180, // 3 minutes
            nombreLineaBus: '123',
            posicionPunto: Coordenada(latitud: -34.907, longitud: -56.187),
          ),
          // Step 3: RIDING_BUS
          TramoViajeMostrable(
            idTramo: 'ride-bus-arch',
            tipo: TipoTramoViaje.VIAJE_EN_BUS,
            descripcion: 'Viaja en bus',
            duracionEstimadaSegundos: 480, // 8 minutes
            nombreLineaBus: '123',
            coordenadasParadaDestino: Coordenada(latitud: -34.908, longitud: -56.188),
            distanciaMetros: 1200,
            geometriaPolilinea: [
              Coordenada(latitud: -34.907, longitud: -56.187),
              Coordenada(latitud: -34.908, longitud: -56.188),
            ],
          ),
          // Step 4: WALKING_TO_DESTINATION
          TramoViajeMostrable(
            idTramo: 'walk-to-dest-arch',
            tipo: TipoTramoViaje.CAMINAR,
            descripcion: 'Camina al destino',
            duracionEstimadaSegundos: 300, // 5 minutes
            distanciaMetros: 300,
            geometriaPolilinea: [
              Coordenada(latitud: -34.908, longitud: -56.188),
              Coordenada(latitud: -34.909, longitud: -56.189),
            ],
          ),
        ],
      ),
    ];
  }
}

class MockGeocodingService extends GeocodingServiceAdapter {
  @override
  Future<List<SugerenciaLugar>> fetchSuggestions(
    String query, {
    Coordenada? proximity,
  }) async {
    return [];
  }
}

class MockMapManager extends MapManager {
  MockMapManager() : super(null);
  
  @override
  void dispose() {}
}

void main() {
  group('Information Flow Architecture - Integration Tests', () {
    late ProviderContainer container;
    late AppLogicNotifier userJourneyOrchestrator;
    late MockMontevideoApiService mockApiService;

    setUp(() {
      mockApiService = MockMontevideoApiService();
      container = ProviderContainer(
        overrides: [
          montevideoApiServiceProvider.overrideWithValue(mockApiService),
          itineraryPlanningServiceProvider.overrideWithValue(MockItineraryPlanningService()),
          geocodingServiceProvider.overrideWithValue(MockGeocodingService()),
        ],
      );
      
      userJourneyOrchestrator = container.read(appLogicProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    group('Architecture Component Integration', () {
      test('should verify UserJourneyOrchestrator coordinates all subsystems', () async {
        // Phase 1: Journey Initialization
        final routes = await MockItineraryPlanningService().planRoute(
          origenCoords: Coordenada(latitud: -34.906, longitud: -56.186),
          origenNombre: 'Origen Test',
          destinoCoords: Coordenada(latitud: -34.909, longitud: -56.189),
          destinoNombre: 'Destino Test',
        );

        userJourneyOrchestrator.state = userJourneyOrchestrator.state.copyWith(
          faseActual: FaseApp.MOSTRANDO_OPCIONES_RUTA,
          datosFaseOpcionesRuta: EstadoFaseOpcionesRuta(
            opcionesDeRuta: routes,
          ),
          idOpcionRutaPrevisualizada: 'architecture-test-route',
        );

        // Verify UserJourneyOrchestrator.initializeJourney() functionality
        userJourneyOrchestrator.confirmarOpcionDeRutaEIniciarViaje('architecture-test-route');
        await Future.delayed(Duration(milliseconds: 200));

        final state = container.read(appLogicProvider);
        
        // Verify journey initialization per architecture document:
        // 1. Configure first step (WALKING_TO_STOP)
        expect(state.faseActual, equals(FaseApp.VIAJE_ACTIVO_EN_CURSO));
        expect(state.datosFaseViajeActivo, isNotNull);
        expect(state.datosFaseViajeActivo!.tramosDelViaje.length, equals(4));
        expect(state.datosFaseViajeActivo!.tramosDelViaje[0].tipo, equals(TipoTramoViaje.CAMINAR));
        
        // 2. LocationTracker would be started (verified in separate test)
        // 3. RouteDynamicCalculator would calculate initial route
        // 4. BusTrackingManager would start API tracking if ETA available
        // 5. SmartCameraController would update camera (not fully implemented)
      });

      test('should verify LocationTracker integration with 5-second updates', () async {
        final locationUpdates = <Coordenada>[];
        final arrivalDetections = <String>[];

        final locationTracker = LocationTracker(
          onLocationUpdate: (location) => locationUpdates.add(location),
          onArrivalDetected: (geofenceId) => arrivalDetections.add(geofenceId),
        );

        // Verify LocationTracker configuration per architecture document:
        expect(LocationTracker.UPDATE_INTERVAL_MS, equals(5000)); // 5 seconds
        expect(LocationTracker.ARRIVAL_THRESHOLD_METERS, equals(50.0)); // 50m threshold

        // Test geofencing setup for automatic detection
        final destinations = [
          Coordenada(latitud: -34.907, longitud: -56.187), // Bus stop
          Coordenada(latitud: -34.908, longitud: -56.188), // Bus destination
          Coordenada(latitud: -34.909, longitud: -56.189), // Final destination
        ];
        final geofenceIds = ['stop_1', 'stop_2', 'final_dest'];

        locationTracker.setupGeofencesForStep(destinations, geofenceIds);

        // Verify geofences are configured correctly
        expect(locationTracker.activeGeofences.length, equals(3));
        for (int i = 0; i < destinations.length; i++) {
          expect(locationTracker.activeGeofences[i].center, equals(destinations[i]));
          expect(locationTracker.activeGeofences[i].radius, equals(50.0));
          expect(locationTracker.activeGeofences[i].id, equals(geofenceIds[i]));
        }

        locationTracker.dispose();
      });

      test('should verify BusTrackingManager hybrid system integration', () async {
        // Test BusTrackingManager states per architecture document
        final mapBusRealtime = MapBusRealtime(null, MockMapManager());

        // Initial state should be INACTIVE
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.INACTIVE));

        // Test API_REALTIME mode (sondeo API cada 10 segundos)
        await mapBusRealtime.startApiTracking();
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.API_REALTIME));

        // Test transition to USER_LOCATION mode (when user boards bus)
        await mapBusRealtime.switchToUserLocationMode();
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.USER_LOCATION));

        // Test user location updates while on bus
        final userLocation = Coordenada(latitud: -34.907, longitud: -56.187);
        await mapBusRealtime.updateBusToUserLocation(userLocation);
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.USER_LOCATION));

        // Test bus boarding detection logic
        final busRoute = [
          Coordenada(latitud: -34.906, longitud: -56.186),
          Coordenada(latitud: -34.907, longitud: -56.187),
          Coordenada(latitud: -34.908, longitud: -56.188),
        ];
        final busSpeed = 8.0; // m/s (above walking speed)

        final shouldBoard = RouteDynamicCalculator.detectBusBoarding(
          userLocation: userLocation,
          busRoutePoints: busRoute,
          userSpeed: busSpeed,
        );
        expect(shouldBoard, isTrue);

        mapBusRealtime.dispose();
      });

      test('should verify RouteDynamicCalculator live route calculations', () async {
        final startLocation = Coordenada(latitud: -34.906, longitud: -56.186);
        final currentLocation = Coordenada(latitud: -34.9065, longitud: -56.1865);
        final destination = Coordenada(latitud: -34.907, longitud: -56.187);

        // Test dynamic route calculation per architecture document
        final progress = await RouteDynamicCalculator.calculateProgress(
          startLocation: startLocation,
          currentLocation: currentLocation,
          destination: destination,
        );

        // Verify progress calculation components
        expect(progress.percentageComplete, greaterThan(0.0));
        expect(progress.percentageComplete, lessThanOrEqualTo(100.0));
        expect(progress.remainingDistance, greaterThan(0.0));
        expect(progress.remainingTimeSeconds, greaterThan(0));
        expect(progress.currentOptimalRoute, isNotEmpty);
        expect(progress.totalDistance, greaterThan(progress.remainingDistance));

        // Test bus progress calculation (different speed assumptions)
        final busProgress = await RouteDynamicCalculator.calculateBusProgress(
          startLocation: startLocation,
          currentLocation: currentLocation,
          destination: destination,
        );

        // Bus should be faster than walking
        expect(busProgress.remainingTimeSeconds, lessThan(progress.remainingTimeSeconds));

        // Test route deviation detection
        final farLocation = Coordenada(latitud: -34.920, longitud: -56.200);
        final routePoints = [startLocation, destination];
        
        final isNearRoute = RouteDynamicCalculator.isLocationNearRoute(
          userLocation: farLocation,
          routePoints: routePoints,
          thresholdMeters: 100.0,
        );
        expect(isNearRoute, isFalse);
      });
    });

    group('Step Transition Flow Integration', () {
      test('should verify automatic step transitions per architecture flow', () async {
        // Initialize complete journey
        await _initializeArchitectureTestJourney(userJourneyOrchestrator);

        final initialState = container.read(appLogicProvider);
        expect(initialState.faseActual, equals(FaseApp.VIAJE_ACTIVO_EN_CURSO));
        
        final tramos = initialState.datosFaseViajeActivo!.tramosDelViaje;
        
        // Verify step sequence per architecture document:
        // WALKING_TO_STOP → WAITING_FOR_BUS → RIDING_BUS → WALKING_TO_DESTINATION
        expect(tramos[0].tipo, equals(TipoTramoViaje.CAMINAR));
        expect(tramos[1].tipo, equals(TipoTramoViaje.ESPERAR_BUS));
        expect(tramos[2].tipo, equals(TipoTramoViaje.VIAJE_EN_BUS));
        expect(tramos[3].tipo, equals(TipoTramoViaje.CAMINAR));

        // Test journey step state management
        final walkingStep = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
          destination: Coordenada(latitud: -34.907, longitud: -56.187),
          instructions: 'Camina hacia parada',
        );

        expect(walkingStep.type, equals(JourneyStepType.WALKING_TO_STOP));
        expect(walkingStep.typeDisplayName, equals('Camina hacia la parada'));

        final waitingStep = walkingStep.copyWith(
          stepIndex: 1,
          type: JourneyStepType.WAITING_FOR_BUS,
          busLine: '123',
          instructions: 'Espera bus línea 123',
        );

        expect(waitingStep.type, equals(JourneyStepType.WAITING_FOR_BUS));
        expect(waitingStep.busLine, equals('123'));
        expect(waitingStep.typeDisplayName, equals('Espera el bus'));
      });

      test('should verify 5-second update loop coordination', () async {
        // This test verifies the main loop described in the architecture:
        // LocationTracker detecta nueva ubicación → UserJourneyOrchestrator.onLocationUpdate()
        
        await _initializeArchitectureTestJourney(userJourneyOrchestrator);

        // Simulate location updates that would trigger the main loop
        final userLocations = [
          Coordenada(latitud: -34.9060, longitud: -56.1860), // Starting point
          Coordenada(latitud: -34.9065, longitud: -56.1865), // Moving toward stop
          Coordenada(latitud: -34.9070, longitud: -56.1870), // Near stop
          Coordenada(latitud: -34.907, longitud: -56.187),   // At stop (should trigger transition)
        ];

        for (final location in userLocations) {
          // In real implementation, this would be triggered by LocationTracker
          // Here we simulate the location update processing
          
          // Verify progress calculation would be called
          final progress = await RouteDynamicCalculator.calculateProgress(
            startLocation: userLocations.first,
            currentLocation: location,
            destination: Coordenada(latitud: -34.907, longitud: -56.187),
          );

          expect(progress.percentageComplete, greaterThanOrEqualTo(0.0));
          expect(progress.percentageComplete, lessThanOrEqualTo(100.0));

          // Verify arrival detection logic
          if (location.latitud == -34.907 && location.longitud == -56.187) {
            // At destination - should trigger step transition
            // This would happen automatically in the real system
            expect(progress.remainingDistance, lessThan(50.0)); // Within threshold
          }
        }

        final state = container.read(appLogicProvider);
        expect(state.faseActual, equals(FaseApp.VIAJE_ACTIVO_EN_CURSO));
      });
    });

    group('Hybrid Bus Tracking Flow', () {
      test('should verify API tracking to user tracking transition', () async {
        // Test the hybrid tracking flow described in architecture:
        // API_REALTIME → USER_LOCATION when user boards bus

        final mapBusRealtime = MapBusRealtime(null, MockMapManager());
        
        // Phase 1: Start with API tracking (while waiting for bus)
        await mapBusRealtime.startApiTracking();
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.API_REALTIME));

        // Phase 2: Detect bus boarding
        final userLocation = Coordenada(latitud: -34.907, longitud: -56.187);
        final busRoute = [
          Coordenada(latitud: -34.906, longitud: -56.186),
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

        // Phase 3: Switch to user location tracking
        await mapBusRealtime.switchToUserLocationMode();
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.USER_LOCATION));

        // Phase 4: Update bus position to user location
        await mapBusRealtime.updateBusToUserLocation(userLocation);
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.USER_LOCATION));

        mapBusRealtime.dispose();
      });

      test('should verify ETA management integration', () async {
        // Test ETA integration with bus tracking as described in architecture
        
        await _initializeArchitectureTestJourney(userJourneyOrchestrator);
        
        // Verify API service is called for ETA information
        final initialCallCount = mockApiService.apiCallCount;
        
        // Simulate ETA request
        final etaInfo = await mockApiService.getStopDetailsWithEta(
          'stop_architecture_test',
          'Parada Test',
          Coordenada(latitud: -34.907, longitud: -56.187),
        );

        expect(mockApiService.apiCallCount, greaterThan(initialCallCount));
        expect(etaInfo, isNotNull);
        expect(etaInfo!.etas!.isNotEmpty, isTrue);
        expect(etaInfo.etas!.first.minutosParaLlegada, equals(3)); // 3 minutes
        expect(etaInfo.etas!.first.linea, equals('123'));
      });
    });

    group('Progress and State Management', () {
      test('should verify journey progress tracking per architecture', () {
        // Test progress tracking as defined in architecture document
        
        final step = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
          remainingDistance: 150.5,
          remainingTimeSeconds: 120,
          progressPercentage: 65.5,
        );

        // Verify progress display formatting
        expect(step.formattedRemainingDistance, equals('151 m'));
        expect(step.formattedRemainingTime, equals('2m 0s'));
        expect(step.isInProgress, isTrue);
        expect(step.isCompleted, isFalse);

        // Test completion state
        final completedStep = step.copyWith(progressPercentage: 100.0);
        expect(completedStep.isCompleted, isTrue);
        expect(completedStep.isInProgress, isFalse);
      });

      test('should verify route information structure per architecture', () async {
        // Test RouteInfo structure as defined in architecture
        
        final startLocation = Coordenada(latitud: -34.906, longitud: -56.186);
        final destination = Coordenada(latitud: -34.907, longitud: -56.187);
        
        final progress = await RouteDynamicCalculator.calculateProgress(
          startLocation: startLocation,
          currentLocation: startLocation,
          destination: destination,
        );

        // Verify RouteProgress contains required information
        expect(progress.currentOptimalRoute, isNotEmpty);
        expect(progress.totalDistance, greaterThan(0.0));
        expect(progress.remainingDistance, greaterThan(0.0));
        expect(progress.remainingTimeSeconds, greaterThan(0));
        expect(progress.percentageComplete, greaterThanOrEqualTo(0.0));

        // Test formatted output
        expect(progress.formattedTotalDistance, isNotNull);
        expect(progress.formattedRemainingDistance, isNotNull);
        expect(progress.formattedRemainingTime, isNotNull);
      });
    });

    group('Error Handling and Robustness', () {
      test('should handle system errors gracefully', () async {
        // Test robustness as mentioned in architecture advantages
        
        await _initializeArchitectureTestJourney(userJourneyOrchestrator);

        // Test invalid route handling
        expect(
          () => userJourneyOrchestrator.confirmarOpcionDeRutaEIniciarViaje('invalid-route'),
          returnsNormally,
        );

        // Test journey cancellation
        expect(
          () => userJourneyOrchestrator.usuarioCanceloBusquedaOSeleccionRuta(),
          returnsNormally,
        );

        // Test stop tracking
        expect(
          () => userJourneyOrchestrator.detenerSeguimientoActivo(),
          returnsNormally,
        );
      });
    });
  });
}

// Helper function to initialize a complete journey for architecture testing
Future<void> _initializeArchitectureTestJourney(AppLogicNotifier orchestrator) async {
  final routes = await MockItineraryPlanningService().planRoute(
    origenCoords: Coordenada(latitud: -34.906, longitud: -56.186),
    origenNombre: 'Origen Arquitectura',
    destinoCoords: Coordenada(latitud: -34.909, longitud: -56.189),
    destinoNombre: 'Destino Arquitectura',
  );

  orchestrator.state = orchestrator.state.copyWith(
    faseActual: FaseApp.MOSTRANDO_OPCIONES_RUTA,
    datosFaseOpcionesRuta: EstadoFaseOpcionesRuta(
      opcionesDeRuta: routes,
    ),
    idOpcionRutaPrevisualizada: 'architecture-test-route',
  );

  orchestrator.confirmarOpcionDeRutaEIniciarViaje('architecture-test-route');
  await Future.delayed(Duration(milliseconds: 200));
}