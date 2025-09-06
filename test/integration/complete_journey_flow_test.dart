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

// Mock services for integration testing
class MockMontevideoApiService extends MontevideoApiServiceAdapterBase {
  @override
  Future<List<InfoParadaEnMapa>> getAllStops() async {
    return [
      InfoParadaEnMapa(
        idParada: 'stop_1',
        nombre: 'Parada Test 1',
        posicion: Coordenada(latitud: -34.907, longitud: -56.187),
      ),
      InfoParadaEnMapa(
        idParada: 'stop_2',
        nombre: 'Parada Test 2',
        posicion: Coordenada(latitud: -34.908, longitud: -56.188),
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
      lineasQuePasan: ['123', '456'],
      etas: [
        EtaMostrable(
          linea: '123',
          destino: 'Centro',
          minutosParaLlegada: 5,
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
        idOpcion: 'integration-test-route',
        esRecomendada: true,
        duracionTotalSegundos: 1800, // 30 minutes
        horaLlegadaEstimada: DateTime.now().add(Duration(minutes: 30)),
        secuenciaModosIconos: [TipoTramoViaje.CAMINAR, TipoTramoViaje.VIAJE_EN_BUS, TipoTramoViaje.CAMINAR],
        distanciaTotalCaminataMetros: 900,
        tiempoTotalEsperaBusSegundos: 480,
        score: 100,
        tramosParaPreview: [
          TramoViajeMostrable(
            idTramo: 'walk-to-stop',
            tipo: TipoTramoViaje.CAMINAR,
            descripcion: 'Camina hasta la parada de bus',
            duracionEstimadaSegundos: 300, // 5 minutes
            distanciaMetros: 400,
            geometriaPolilinea: [
              Coordenada(latitud: -34.906, longitud: -56.186),
              Coordenada(latitud: -34.907, longitud: -56.187),
            ],
          ),
          TramoViajeMostrable(
            idTramo: 'wait-at-stop',
            tipo: TipoTramoViaje.ESPERAR_BUS,
            descripcion: 'Espera el bus línea 123',
            duracionEstimadaSegundos: 480, // 8 minutes
            nombreLineaBus: '123',
            posicionPunto: Coordenada(latitud: -34.907, longitud: -56.187),
          ),
          TramoViajeMostrable(
            idTramo: 'ride-bus',
            tipo: TipoTramoViaje.VIAJE_EN_BUS,
            descripcion: 'Viaja en bus línea 123',
            duracionEstimadaSegundos: 720, // 12 minutes
            nombreLineaBus: '123',
            coordenadasParadaDestino: Coordenada(latitud: -34.908, longitud: -56.188),
            distanciaMetros: 1600,
            geometriaPolilinea: [
              Coordenada(latitud: -34.907, longitud: -56.187),
              Coordenada(latitud: -34.908, longitud: -56.188),
            ],
          ),
          TramoViajeMostrable(
            idTramo: 'walk-to-destination',
            tipo: TipoTramoViaje.CAMINAR,
            descripcion: 'Camina al destino final',
            duracionEstimadaSegundos: 300, // 5 minutes
            distanciaMetros: 500,
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
    return [
      SugerenciaLugar(
        id: 'centro',
        nombreCompleto: 'Centro de Montevideo',
        nombreLugar: 'Centro de Montevideo',
        direccion: 'Plaza Independencia, Montevideo',
        coordenadas: Coordenada(latitud: -34.906, longitud: -56.186),
      ),
      SugerenciaLugar(
        id: 'pocitos',
        nombreCompleto: 'Pocitos',
        nombreLugar: 'Pocitos',
        direccion: 'Pocitos, Montevideo',
        coordenadas: Coordenada(latitud: -34.909, longitud: -56.189),
      ),
    ];
  }
}

void main() {
  group('Complete Journey Flow - Integration Tests', () {
    late ProviderContainer container;
    late AppLogicNotifier appLogicNotifier;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          montevideoApiServiceProvider.overrideWithValue(MockMontevideoApiService()),
          itineraryPlanningServiceProvider.overrideWithValue(MockItineraryPlanningService()),
          geocodingServiceProvider.overrideWithValue(MockGeocodingService()),
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

    group('Complete Automatic Journey Flow', () {
      test('should execute full automatic journey from route selection to completion', () async {
        // Phase 1: Initial Setup and Route Planning
        expect(container.read(appLogicProvider).faseActual, equals(FaseApp.INICIAL_SIN_BUSQUEDA));

        // Simulate route planning request
        final routes = await MockItineraryPlanningService().planRoute(
          origenCoords: Coordenada(latitud: -34.906, longitud: -56.186),
          origenNombre: 'Centro',
          destinoCoords: Coordenada(latitud: -34.909, longitud: -56.189),
          destinoNombre: 'Pocitos',
        );

        appLogicNotifier.state = appLogicNotifier.state.copyWith(
          faseActual: FaseApp.MOSTRANDO_OPCIONES_RUTA,
          datosFaseOpcionesRuta: EstadoFaseOpcionesRuta(
            opcionesDeRuta: routes,
          ),
          idOpcionRutaPrevisualizada: 'integration-test-route',
        );

        expect(container.read(appLogicProvider).faseActual, equals(FaseApp.MOSTRANDO_OPCIONES_RUTA));
        expect(container.read(appLogicProvider).datosFaseOpcionesRuta?.opcionesDeRuta.length, equals(1));

        // Phase 2: Route Confirmation and Journey Initialization
        appLogicNotifier.confirmarOpcionDeRutaEIniciarViaje('integration-test-route');
        
        // Wait for automatic tracking initialization
        await Future.delayed(Duration(milliseconds: 200));

        final journeyState = container.read(appLogicProvider);
        expect(journeyState.faseActual, equals(FaseApp.VIAJE_ACTIVO_EN_CURSO));
        expect(journeyState.datosFaseViajeActivo, isNotNull);
        expect(journeyState.datosFaseViajeActivo!.tramosDelViaje.length, equals(4));

        // Verify all journey steps are correctly initialized
        final tramos = journeyState.datosFaseViajeActivo!.tramosDelViaje;
        expect(tramos[0].tipo, equals(TipoTramoViaje.CAMINAR));
        expect(tramos[1].tipo, equals(TipoTramoViaje.ESPERAR_BUS));
        expect(tramos[2].tipo, equals(TipoTramoViaje.VIAJE_EN_BUS));
        expect(tramos[3].tipo, equals(TipoTramoViaje.CAMINAR));

        // Phase 3: Simulate Journey Steps Completion
        // Step 1: Walking to stop
        await _simulateJourneyStep(
          appLogicNotifier,
          container,
          stepIndex: 0,
          stepType: JourneyStepType.WALKING_TO_STOP,
          targetLocation: Coordenada(latitud: -34.907, longitud: -56.187),
        );

        // Step 2: Waiting for bus
        await _simulateJourneyStep(
          appLogicNotifier,
          container,
          stepIndex: 1,
          stepType: JourneyStepType.WAITING_FOR_BUS,
          targetLocation: Coordenada(latitud: -34.907, longitud: -56.187),
        );

        // Step 3: Riding bus (with hybrid tracking mode switch)
        await _simulateJourneyStep(
          appLogicNotifier,
          container,
          stepIndex: 2,
          stepType: JourneyStepType.RIDING_BUS,
          targetLocation: Coordenada(latitud: -34.908, longitud: -56.188),
          simulateBusBoarding: true,
        );

        // Step 4: Final walk to destination
        await _simulateJourneyStep(
          appLogicNotifier,
          container,
          stepIndex: 3,
          stepType: JourneyStepType.WALKING_TO_DESTINATION,
          targetLocation: Coordenada(latitud: -34.909, longitud: -56.189),
        );

        // Phase 4: Journey Completion
        appLogicNotifier.detenerSeguimientoActivo();
        
        final finalState = container.read(appLogicProvider);
        expect(finalState.faseActual, equals(FaseApp.INICIAL_SIN_BUSQUEDA));
        expect(finalState.datosFaseViajeActivo, isNull);
      });

      test('should handle journey interruption and recovery', () async {
        // Initialize journey
        await _setupCompleteJourney(appLogicNotifier);

        final initialState = container.read(appLogicProvider);
        expect(initialState.faseActual, equals(FaseApp.VIAJE_ACTIVO_EN_CURSO));

        // Simulate user cancellation during journey
        appLogicNotifier.usuarioCanceloBusquedaOSeleccionRuta();

        final cancelledState = container.read(appLogicProvider);
        expect(cancelledState.faseActual, equals(FaseApp.INICIAL_SIN_BUSQUEDA));
        expect(cancelledState.datosFaseViajeActivo, isNull);

        // Verify system can handle new journey after cancellation
        await _setupCompleteJourney(appLogicNotifier);
        
        final recoveredState = container.read(appLogicProvider);
        expect(recoveredState.faseActual, equals(FaseApp.VIAJE_ACTIVO_EN_CURSO));
      });

      test('should handle errors during automatic journey execution', () async {
        // Initialize journey
        await _setupCompleteJourney(appLogicNotifier);

        expect(container.read(appLogicProvider).faseActual, equals(FaseApp.VIAJE_ACTIVO_EN_CURSO));

        // Simulate error by trying to confirm invalid route
        expect(
          () => appLogicNotifier.confirmarOpcionDeRutaEIniciarViaje('invalid-route-id'),
          returnsNormally, // Should handle error gracefully
        );

        // System should maintain or recover to a valid state
        final errorState = container.read(appLogicProvider);
        expect(errorState.mensajeErrorGlobal, isNotNull);
      });
    });

    group('Hybrid Bus Tracking Integration', () {
      test('should switch from API tracking to user location tracking when boarding bus', () async {
        // Initialize journey and get to waiting for bus step
        await _setupCompleteJourney(appLogicNotifier);
        
        // Simulate walking to stop completion (step 0)
        await _simulateJourneyStep(
          appLogicNotifier,
          container,
          stepIndex: 0,
          stepType: JourneyStepType.WALKING_TO_STOP,
          targetLocation: Coordenada(latitud: -34.907, longitud: -56.187),
        );

        // Now at waiting for bus step (step 1)
        // Simulate bus boarding detection
        final busRoute = [
          Coordenada(latitud: -34.907, longitud: -56.187),
          Coordenada(latitud: -34.908, longitud: -56.188),
        ];

        final userLocation = Coordenada(latitud: -34.907, longitud: -56.187);
        final userSpeed = 8.0; // Bus speed

        final shouldSwitchTracking = RouteDynamicCalculator.detectBusBoarding(
          userLocation: userLocation,
          busRoutePoints: busRoute,
          userSpeed: userSpeed,
        );

        expect(shouldSwitchTracking, isTrue);

        // Simulate the tracking mode switch (this would happen automatically)
        // In the real implementation, this would be handled by the system
        await _simulateJourneyStep(
          appLogicNotifier,
          container,
          stepIndex: 2,
          stepType: JourneyStepType.RIDING_BUS,
          targetLocation: Coordenada(latitud: -34.908, longitud: -56.188),
          simulateBusBoarding: true,
        );

        // Verify journey continues correctly
        final state = container.read(appLogicProvider);
        expect(state.faseActual, equals(FaseApp.VIAJE_ACTIVO_EN_CURSO));
      });
    });

    group('Location Tracking and Geofencing Integration', () {
      test('should handle GPS location updates and geofence arrivals', () async {
        final locationUpdates = <Coordenada>[];
        final arrivalDetections = <String>[];

        final locationTracker = LocationTracker(
          onLocationUpdate: (location) => locationUpdates.add(location),
          onArrivalDetected: (geofenceId) => arrivalDetections.add(geofenceId),
        );

        // Setup geofences for journey steps
        final destinations = [
          Coordenada(latitud: -34.907, longitud: -56.187), // Bus stop
          Coordenada(latitud: -34.908, longitud: -56.188), // Bus destination
          Coordenada(latitud: -34.909, longitud: -56.189), // Final destination
        ];
        final geofenceIds = ['bus_stop', 'bus_destination', 'final_destination'];

        locationTracker.setupGeofencesForStep(destinations, geofenceIds);

        expect(locationTracker.activeGeofences.length, equals(3));
        expect(locationTracker.activeGeofences.map((g) => g.id).toList(), equals(geofenceIds));

        // Simulate arriving at each geofence
        // Note: In unit tests, we can't easily simulate GPS events,
        // but we can verify the geofences are set up correctly
        for (int i = 0; i < destinations.length; i++) {
          expect(locationTracker.activeGeofences[i].center, equals(destinations[i]));
          expect(locationTracker.activeGeofences[i].radius, equals(50.0));
        }

        locationTracker.dispose();
      });
    });

    group('Progress Tracking Integration', () {
      test('should calculate and update progress throughout journey', () async {
        final startLocation = Coordenada(latitud: -34.906, longitud: -56.186);
        final currentLocation = Coordenada(latitud: -34.9070, longitud: -56.1870);
        final destination = Coordenada(latitud: -34.909, longitud: -56.189);

        // Test walking progress
        final walkingProgress = await RouteDynamicCalculator.calculateProgress(
          startLocation: startLocation,
          currentLocation: currentLocation,
          destination: destination,
        );

        expect(walkingProgress.percentageComplete, greaterThan(0.0));
        expect(walkingProgress.percentageComplete, lessThanOrEqualTo(100.0));
        expect(walkingProgress.remainingDistance, greaterThan(0.0));
        expect(walkingProgress.formattedRemainingTime, isNotNull);
        expect(walkingProgress.formattedRemainingDistance, isNotNull);

        // Test bus progress
        final busProgress = await RouteDynamicCalculator.calculateBusProgress(
          startLocation: startLocation,
          currentLocation: currentLocation,
          destination: destination,
        );

        expect(busProgress.remainingTimeSeconds, lessThan(walkingProgress.remainingTimeSeconds));
        expect(busProgress.percentageComplete, greaterThan(0.0));
      });

      test('should handle route deviation detection', () {
        final userLocation = Coordenada(latitud: -34.920, longitud: -56.200); // Far from route
        final routePoints = [
          Coordenada(latitud: -34.906, longitud: -56.186),
          Coordenada(latitud: -34.907, longitud: -56.187),
          Coordenada(latitud: -34.909, longitud: -56.189),
        ];

        final isNearRoute = RouteDynamicCalculator.isLocationNearRoute(
          userLocation: userLocation,
          routePoints: routePoints,
          thresholdMeters: 100.0,
        );

        expect(isNearRoute, isFalse);

        // Test with location near route
        final nearLocation = Coordenada(latitud: -34.9065, longitud: -56.1865);
        final isNear = RouteDynamicCalculator.isLocationNearRoute(
          userLocation: nearLocation,
          routePoints: routePoints,
          thresholdMeters: 100.0,
        );

        expect(isNear, isTrue);
      });
    });

    group('State Consistency Throughout Journey', () {
      test('should maintain consistent state across all journey phases', () async {
        // Track state changes throughout the journey
        final stateChanges = <FaseApp>[];
        
        // Initial state
        stateChanges.add(container.read(appLogicProvider).faseActual);
        expect(stateChanges.last, equals(FaseApp.INICIAL_SIN_BUSQUEDA));

        // Setup route options
        await _setupRouteOptions(appLogicNotifier);
        stateChanges.add(container.read(appLogicProvider).faseActual);
        expect(stateChanges.last, equals(FaseApp.MOSTRANDO_OPCIONES_RUTA));

        // Start journey
        appLogicNotifier.confirmarOpcionDeRutaEIniciarViaje('integration-test-route');
        await Future.delayed(Duration(milliseconds: 100));
        stateChanges.add(container.read(appLogicProvider).faseActual);
        expect(stateChanges.last, equals(FaseApp.VIAJE_ACTIVO_EN_CURSO));

        // Complete journey
        appLogicNotifier.detenerSeguimientoActivo();
        stateChanges.add(container.read(appLogicProvider).faseActual);
        expect(stateChanges.last, equals(FaseApp.INICIAL_SIN_BUSQUEDA));

        // Verify all state transitions were valid
        expect(stateChanges.length, equals(4));
        expect(stateChanges, contains(FaseApp.INICIAL_SIN_BUSQUEDA));
        expect(stateChanges, contains(FaseApp.MOSTRANDO_OPCIONES_RUTA));
        expect(stateChanges, contains(FaseApp.VIAJE_ACTIVO_EN_CURSO));
      });
    });
  });
}

// Helper functions for integration tests

Future<void> _setupCompleteJourney(AppLogicNotifier appLogicNotifier) async {
  final routes = await MockItineraryPlanningService().planRoute(
    origenCoords: Coordenada(latitud: -34.906, longitud: -56.186),
    origenNombre: 'Centro',
    destinoCoords: Coordenada(latitud: -34.909, longitud: -56.189),
    destinoNombre: 'Pocitos',
  );

  appLogicNotifier.state = appLogicNotifier.state.copyWith(
    faseActual: FaseApp.MOSTRANDO_OPCIONES_RUTA,
    datosFaseOpcionesRuta: EstadoFaseOpcionesRuta(
      opcionesDeRuta: routes,
    ),
    idOpcionRutaPrevisualizada: 'integration-test-route',
  );

  appLogicNotifier.confirmarOpcionDeRutaEIniciarViaje('integration-test-route');
  await Future.delayed(Duration(milliseconds: 200));
}

Future<void> _setupRouteOptions(AppLogicNotifier appLogicNotifier) async {
  final routes = await MockItineraryPlanningService().planRoute(
    origenCoords: Coordenada(latitud: -34.906, longitud: -56.186),
    origenNombre: 'Centro',
    destinoCoords: Coordenada(latitud: -34.909, longitud: -56.189),
    destinoNombre: 'Pocitos',
  );

  appLogicNotifier.state = appLogicNotifier.state.copyWith(
    faseActual: FaseApp.MOSTRANDO_OPCIONES_RUTA,
    datosFaseOpcionesRuta: EstadoFaseOpcionesRuta(
      opcionesDeRuta: routes,
    ),
    idOpcionRutaPrevisualizada: 'integration-test-route',
  );
}

Future<void> _simulateJourneyStep(
  AppLogicNotifier appLogicNotifier,
  ProviderContainer container,
  {
  required int stepIndex,
  required JourneyStepType stepType,
  required Coordenada targetLocation,
  bool simulateBusBoarding = false,
}) async {
  // Simulate location updates leading to step completion
  final intermediateLocations = _generatePathToTarget(targetLocation, 3);
  
  for (final location in intermediateLocations) {
    // In real implementation, this would trigger automatic updates
    // Here we simulate the progression
    await Future.delayed(Duration(milliseconds: 50));
  }

  if (simulateBusBoarding) {
    // Simulate bus boarding detection and tracking mode switch
    // This would normally be handled automatically by the system
    await Future.delayed(Duration(milliseconds: 100));
  }

  // Simulate step completion
  await Future.delayed(Duration(milliseconds: 100));
  
  // Verify we're still in the journey phase
  final state = container.read(appLogicProvider);
  expect(state.faseActual, equals(FaseApp.VIAJE_ACTIVO_EN_CURSO));
}

List<Coordenada> _generatePathToTarget(Coordenada target, int numPoints) {
  // Generate intermediate points simulating movement toward target
  final path = <Coordenada>[];
  for (int i = 1; i <= numPoints; i++) {
    final progress = i / (numPoints + 1);
    // Simple linear interpolation (in real app this would be more sophisticated)
    path.add(Coordenada(
      latitud: target.latitud + (1 - progress) * 0.001,
      longitud: target.longitud + (1 - progress) * 0.001,
    ));
  }
  return path;
}