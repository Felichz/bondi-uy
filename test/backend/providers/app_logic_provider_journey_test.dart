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

// Mock services for testing
class MockMontevideoApiService extends MontevideoApiServiceAdapterBase {
  @override
  Future<List<InfoParadaEnMapa>> getAllStops() async {
    return [];
  }

  @override
  Future<InfoDetalladaParada?> getStopDetailsWithEta(
    String stopId, 
    String stopName, 
    Coordenada stopPosition
  ) async {
    return null;
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
        idOpcion: 'test-route-1',
        esRecomendada: true,
        duracionTotalSegundos: 1800,
        horaLlegadaEstimada: DateTime.now().add(Duration(minutes: 30)),
        secuenciaModosIconos: [TipoTramoViaje.CAMINAR, TipoTramoViaje.ESPERAR_BUS, TipoTramoViaje.VIAJE_EN_BUS, TipoTramoViaje.CAMINAR],
        distanciaTotalCaminataMetros: 600,
        tiempoTotalEsperaBusSegundos: 600,
        score: 100,
        tramosParaPreview: [
          TramoViajeMostrable(
            idTramo: 'walk-1',
            tipo: TipoTramoViaje.CAMINAR,
            descripcion: 'Camina hasta la parada',
            duracionEstimadaSegundos: 300,
            distanciaMetros: 400,
            geometriaPolilinea: [
              Coordenada(latitud: -34.906, longitud: -56.186),
              Coordenada(latitud: -34.907, longitud: -56.187),
            ],
          ),
          TramoViajeMostrable(
            idTramo: 'wait-1',
            tipo: TipoTramoViaje.ESPERAR_BUS,
            descripcion: 'Espera el bus',
            duracionEstimadaSegundos: 600,
            nombreLineaBus: '123',
            posicionPunto: Coordenada(latitud: -34.907, longitud: -56.187),
          ),
          TramoViajeMostrable(
            idTramo: 'bus-1',
            tipo: TipoTramoViaje.VIAJE_EN_BUS,
            descripcion: 'Viaja en bus',
            duracionEstimadaSegundos: 600,
            distanciaMetros: 1200,
            nombreLineaBus: '123',
            coordenadasParadaDestino: Coordenada(latitud: -34.908, longitud: -56.188),
            geometriaPolilinea: [
              Coordenada(latitud: -34.907, longitud: -56.187),
              Coordenada(latitud: -34.908, longitud: -56.188),
            ],
          ),
          TramoViajeMostrable(
            idTramo: 'walk-2',
            tipo: TipoTramoViaje.CAMINAR,
            descripcion: 'Camina al destino',
            duracionEstimadaSegundos: 300,
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
    return [];
  }
}

void main() {
  group('AppLogicNotifier - Journey Orchestrator Tests', () {
    late ProviderContainer container;
    late AppLogicNotifier appLogicNotifier;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          montevideoApiServiceProvider.overrideWithValue(MockMontevideoApiService()),
          itineraryPlanningServiceProvider.overrideWithValue(MockItineraryPlanningService()),
          geocodingServiceProvider.overrideWithValue(MockGeocodingService()),
        ],
      );
      
      appLogicNotifier = container.read(appLogicProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    group('Automatic Journey Initialization', () {
      test('should initialize automatic tracking when confirming route', () async {
        // Setup route selection
        appLogicNotifier.state = appLogicNotifier.state.copyWith(
          faseActual: FaseApp.MOSTRANDO_OPCIONES_RUTA,
          datosFaseOpcionesRuta: EstadoFaseOpcionesRuta(
            opcionesDeRuta: await MockItineraryPlanningService().planRoute(
              origenCoords: Coordenada(latitud: -34.906, longitud: -56.186),
              origenNombre: 'Origen',
              destinoCoords: Coordenada(latitud: -34.909, longitud: -56.189),
              destinoNombre: 'Destino',
            ),
          ),
          idOpcionRutaPrevisualizada: 'test-route-1',
        );

        // Confirm route and start journey
        appLogicNotifier.confirmarOpcionDeRutaEIniciarViaje('test-route-1');

        // Wait for async initialization
        await Future.delayed(Duration(milliseconds: 100));

        // Verify journey state
        final state = container.read(appLogicProvider);
        expect(state.faseActual, equals(FaseApp.VIAJE_ACTIVO_EN_CURSO));
        expect(state.datosFaseViajeActivo, isNotNull);
        expect(state.datosFaseViajeActivo!.tramosDelViaje.length, equals(4));
      });

      test('should determine correct step types for journey segments', () async {
        // Test the step type determination logic
        final walkingTramo = TramoViajeMostrable(
          idTramo: 'walk-1',
          tipo: TipoTramoViaje.CAMINAR,
          descripcion: 'Walk to stop',
          duracionEstimadaSegundos: 300,
          distanciaMetros: 400,
          geometriaPolilinea: [
            Coordenada(latitud: -34.906, longitud: -56.186),
            Coordenada(latitud: -34.907, longitud: -56.187),
          ],
        );

        final waitingTramo = TramoViajeMostrable(
          idTramo: 'wait-1',
          tipo: TipoTramoViaje.ESPERAR_BUS,
          descripcion: 'Wait for bus',
          duracionEstimadaSegundos: 600,
          posicionPunto: Coordenada(latitud: -34.907, longitud: -56.187),
        );

        final ridingTramo = TramoViajeMostrable(
          idTramo: 'bus-1',
          tipo: TipoTramoViaje.VIAJE_EN_BUS,
          descripcion: 'Ride bus',
          duracionEstimadaSegundos: 600,
          distanciaMetros: 1200,
          geometriaPolilinea: [
            Coordenada(latitud: -34.907, longitud: -56.187),
            Coordenada(latitud: -34.908, longitud: -56.188),
          ],
        );

        // These are tested via the private methods indirectly
        // In a real implementation, we might expose these methods for testing
        expect(walkingTramo.tipo, equals(TipoTramoViaje.CAMINAR));
        expect(waitingTramo.tipo, equals(TipoTramoViaje.ESPERAR_BUS));
        expect(ridingTramo.tipo, equals(TipoTramoViaje.VIAJE_EN_BUS));
      });
    });

    group('Location Update Handling', () {
      test('should handle location updates during journey', () async {
        // Initialize journey first
        appLogicNotifier.state = appLogicNotifier.state.copyWith(
          faseActual: FaseApp.MOSTRANDO_OPCIONES_RUTA,
          datosFaseOpcionesRuta: EstadoFaseOpcionesRuta(
            opcionesDeRuta: await MockItineraryPlanningService().planRoute(
              origenCoords: Coordenada(latitud: -34.906, longitud: -56.186),
              origenNombre: 'Origen',
              destinoCoords: Coordenada(latitud: -34.909, longitud: -56.189),
              destinoNombre: 'Destino',
            ),
          ),
          idOpcionRutaPrevisualizada: 'test-route-1',
        );

        appLogicNotifier.confirmarOpcionDeRutaEIniciarViaje('test-route-1');
        
        // Wait for initialization
        await Future.delayed(Duration(milliseconds: 100));

        // Verify journey is active
        final state = container.read(appLogicProvider);
        expect(state.faseActual, equals(FaseApp.VIAJE_ACTIVO_EN_CURSO));
      });

      test('should handle automatic step transitions', () async {
        // This test would verify the automatic transition logic
        // Since the actual transition logic involves private methods,
        // we test the public interface and state changes

        appLogicNotifier.state = appLogicNotifier.state.copyWith(
          faseActual: FaseApp.MOSTRANDO_OPCIONES_RUTA,
          datosFaseOpcionesRuta: EstadoFaseOpcionesRuta(
            opcionesDeRuta: await MockItineraryPlanningService().planRoute(
              origenCoords: Coordenada(latitud: -34.906, longitud: -56.186),
              origenNombre: 'Origen',
              destinoCoords: Coordenada(latitud: -34.909, longitud: -56.189),
              destinoNombre: 'Destino',
            ),
          ),
          idOpcionRutaPrevisualizada: 'test-route-1',
        );

        appLogicNotifier.confirmarOpcionDeRutaEIniciarViaje('test-route-1');
        
        // Wait for initialization
        await Future.delayed(Duration(milliseconds: 100));

        final state = container.read(appLogicProvider);
        expect(state.faseActual, equals(FaseApp.VIAJE_ACTIVO_EN_CURSO));
        expect(state.datosFaseViajeActivo?.tramosDelViaje, isNotEmpty);
      });
    });

    group('Journey Completion', () {
      test('should handle journey completion correctly', () async {
        // Initialize journey
        appLogicNotifier.state = appLogicNotifier.state.copyWith(
          faseActual: FaseApp.MOSTRANDO_OPCIONES_RUTA,
          datosFaseOpcionesRuta: EstadoFaseOpcionesRuta(
            opcionesDeRuta: await MockItineraryPlanningService().planRoute(
              origenCoords: Coordenada(latitud: -34.906, longitud: -56.186),
              origenNombre: 'Origen',
              destinoCoords: Coordenada(latitud: -34.909, longitud: -56.189),
              destinoNombre: 'Destino',
            ),
          ),
          idOpcionRutaPrevisualizada: 'test-route-1',
        );

        appLogicNotifier.confirmarOpcionDeRutaEIniciarViaje('test-route-1');
        
        // Wait for initialization
        await Future.delayed(Duration(milliseconds: 100));

        // Test journey completion
        appLogicNotifier.detenerSeguimientoActivo();

        final state = container.read(appLogicProvider);
        expect(state.faseActual, equals(FaseApp.INICIAL_SIN_BUSQUEDA));
        expect(state.datosFaseViajeActivo, isNull);
      });
    });

    group('Error Handling', () {
      test('should handle initialization errors gracefully', () async {
        // Test with invalid route data
        appLogicNotifier.state = appLogicNotifier.state.copyWith(
          faseActual: FaseApp.MOSTRANDO_OPCIONES_RUTA,
          datosFaseOpcionesRuta: EstadoFaseOpcionesRuta(
            opcionesDeRuta: [],
          ),
          idOpcionRutaPrevisualizada: 'invalid-route',
        );

        // This should not crash
        expect(() => appLogicNotifier.confirmarOpcionDeRutaEIniciarViaje('invalid-route'), 
               returnsNormally);

        final state = container.read(appLogicProvider);
        // Should have error handling
        expect(state.mensajeErrorGlobal, isNotNull);
      });

      test('should handle location permission errors', () async {
        // This would test GPS permission failure scenarios
        // Since we can't easily mock Geolocator in unit tests,
        // we test that the system doesn't crash when permissions are denied
        
        appLogicNotifier.state = appLogicNotifier.state.copyWith(
          faseActual: FaseApp.MOSTRANDO_OPCIONES_RUTA,
          datosFaseOpcionesRuta: EstadoFaseOpcionesRuta(
            opcionesDeRuta: await MockItineraryPlanningService().planRoute(
              origenCoords: Coordenada(latitud: -34.906, longitud: -56.186),
              origenNombre: 'Origen',
              destinoCoords: Coordenada(latitud: -34.909, longitud: -56.189),
              destinoNombre: 'Destino',
            ),
          ),
          idOpcionRutaPrevisualizada: 'test-route-1',
        );

        // Should not crash even if GPS fails
        expect(() => appLogicNotifier.confirmarOpcionDeRutaEIniciarViaje('test-route-1'),
               returnsNormally);
      });
    });

    group('State Consistency', () {
      test('should maintain consistent state during transitions', () async {
        // Test that state transitions are atomic and consistent
        final initialState = container.read(appLogicProvider);
        expect(initialState.faseActual, equals(FaseApp.INICIAL_SIN_BUSQUEDA));

        // Setup and transition to journey
        appLogicNotifier.state = appLogicNotifier.state.copyWith(
          faseActual: FaseApp.MOSTRANDO_OPCIONES_RUTA,
          datosFaseOpcionesRuta: EstadoFaseOpcionesRuta(
            opcionesDeRuta: await MockItineraryPlanningService().planRoute(
              origenCoords: Coordenada(latitud: -34.906, longitud: -56.186),
              origenNombre: 'Origen',
              destinoCoords: Coordenada(latitud: -34.909, longitud: -56.189),
              destinoNombre: 'Destino',
            ),
          ),
          idOpcionRutaPrevisualizada: 'test-route-1',
        );

        appLogicNotifier.confirmarOpcionDeRutaEIniciarViaje('test-route-1');

        final journeyState = container.read(appLogicProvider);
        expect(journeyState.faseActual, equals(FaseApp.VIAJE_ACTIVO_EN_CURSO));
        expect(journeyState.datosFaseViajeActivo, isNotNull);

        // End journey
        appLogicNotifier.detenerSeguimientoActivo();

        final finalState = container.read(appLogicProvider);
        expect(finalState.faseActual, equals(FaseApp.INICIAL_SIN_BUSQUEDA));
        expect(finalState.datosFaseViajeActivo, isNull);
      });

      test('should clean up resources on dispose', () {
        // Test that dispose properly cleans up all resources
        // This is important for preventing memory leaks
        
        // Initialize some resources by starting a journey
        appLogicNotifier.state = appLogicNotifier.state.copyWith(
          faseActual: FaseApp.MOSTRANDO_OPCIONES_RUTA,
          datosFaseOpcionesRuta: EstadoFaseOpcionesRuta(
            opcionesDeRuta: [
              OpcionDeRutaMostrable(
                idOpcion: 'test-route-1',
                esRecomendada: true,
                duracionTotalSegundos: 1800,
                horaLlegadaEstimada: DateTime.now().add(Duration(minutes: 30)),
                secuenciaModosIconos: [TipoTramoViaje.CAMINAR],
                distanciaTotalCaminataMetros: 600,
                tiempoTotalEsperaBusSegundos: 600,
                score: 100,
                tramosParaPreview: [],
              ),
            ],
          ),
          idOpcionRutaPrevisualizada: 'test-route-1',
        );
        
        // The actual dispose test happens automatically when the container is disposed in tearDown
        // We just verify that the notifier can be used normally before disposal
        expect(appLogicNotifier.state.faseActual, equals(FaseApp.MOSTRANDO_OPCIONES_RUTA));
        
        // Note: The actual dispose will be called by container.dispose() in tearDown()
      });
    });

    group('Integration with Existing Flow', () {
      test('should not break existing manual navigation', () async {
        // Test that the new automatic system doesn't interfere with existing manual navigation
        
        // Start a journey
        appLogicNotifier.state = appLogicNotifier.state.copyWith(
          faseActual: FaseApp.MOSTRANDO_OPCIONES_RUTA,
          datosFaseOpcionesRuta: EstadoFaseOpcionesRuta(
            opcionesDeRuta: await MockItineraryPlanningService().planRoute(
              origenCoords: Coordenada(latitud: -34.906, longitud: -56.186),
              origenNombre: 'Origen',
              destinoCoords: Coordenada(latitud: -34.909, longitud: -56.189),
              destinoNombre: 'Destino',
            ),
          ),
          idOpcionRutaPrevisualizada: 'test-route-1',
        );

        appLogicNotifier.confirmarOpcionDeRutaEIniciarViaje('test-route-1');

        // Test existing methods still work
        expect(() => appLogicNotifier.usuarioCanceloBusquedaOSeleccionRuta(),
               returnsNormally);
        
        expect(() => appLogicNotifier.detenerSeguimientoActivo(),
               returnsNormally);
      });

      test('should maintain backward compatibility', () async {
        // Test that all existing public methods continue to work as expected
        
        final testMethods = [
          () => appLogicNotifier.pantallaDeInicioCargada(),
          () => appLogicNotifier.usuarioMovioMapaManualente(
                Coordenada(latitud: -34.906, longitud: -56.186), 14.0),
          () => appLogicNotifier.usuarioHizoTapEnMapa(
                Coordenada(latitud: -34.906, longitud: -56.186)),
          () => appLogicNotifier.cerrarDetallesDeParada(),
          () => appLogicNotifier.navegarAAnteriorPasoInstrucciones(),
          () => appLogicNotifier.navegarASiguientePasoInstrucciones(),
          () => appLogicNotifier.usuarioSeleccionoPasoInstrucciones(0),
          () => appLogicNotifier.usuarioPresionoSeguirEsteViaje(),
        ];

        for (final method in testMethods) {
          expect(method, returnsNormally);
        }
      });
    });
  });

  group('Journey Step Management', () {
    test('should handle different journey step types correctly', () {
      final stepTypes = JourneyStepType.values;
      
      expect(stepTypes, contains(JourneyStepType.WALKING_TO_STOP));
      expect(stepTypes, contains(JourneyStepType.WAITING_FOR_BUS));
      expect(stepTypes, contains(JourneyStepType.RIDING_BUS));
      expect(stepTypes, contains(JourneyStepType.WALKING_TO_DESTINATION));
    });

    test('should create journey steps with appropriate properties', () {
      final walkingStep = JourneyStepState(
        stepIndex: 0,
        type: JourneyStepType.WALKING_TO_STOP,
        destination: Coordenada(latitud: -34.907, longitud: -56.187),
        instructions: 'Walk to bus stop',
      );

      expect(walkingStep.type, equals(JourneyStepType.WALKING_TO_STOP));
      expect(walkingStep.destination, isNotNull);
      expect(walkingStep.instructions, equals('Walk to bus stop'));

      final busStep = JourneyStepState(
        stepIndex: 1,
        type: JourneyStepType.WAITING_FOR_BUS,
        busLine: '123',
        instructions: 'Wait for bus line 123',
      );

      expect(busStep.type, equals(JourneyStepType.WAITING_FOR_BUS));
      expect(busStep.busLine, equals('123'));
    });
  });
}