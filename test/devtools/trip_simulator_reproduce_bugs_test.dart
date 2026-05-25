import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bondi_uy/backend/providers/app_logic_provider.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import 'package:bondi_uy/backend/services/montevideo_api_service_adapter.dart';
import 'package:bondi_uy/backend/services/itinerary_planning_service_adapter.dart';
import 'package:bondi_uy/backend/services/geocoding_service_adapter.dart';

/// Test para REPRODUCIR los bugs del simulador antes de fixear
///
/// Bugs a reproducir:
/// 1. Velocidades NO normalizadas (1415 km/h en vez de ~50 km/h)
/// 2. Bus approach line siempre apunta a parada origen
/// 3. TripOrchestrator muestra step incorrecto durante RIDE
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TripSimulator Bug Reproduction', () {
    late ProviderContainer container;
    late AppLogicNotifier notifier;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          montevideoApiServiceProvider.overrideWithValue(_MockMontevideoApi()),
          itineraryPlanningServiceProvider.overrideWithValue(_MockItineraryService()),
          geocodingServiceProvider.overrideWithValue(_MockGeocodingService()),
        ],
      );

      notifier = container.read(appLogicProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('REPRODUCE: Velocidades NO normalizadas y otros bugs', () async {
      print('\n╔════════════════════════════════════════════════════════════╗');
      print('║  TEST: REPRODUCIR BUGS DEL SIMULADOR                      ║');
      print('╚════════════════════════════════════════════════════════════╝\n');

      // 1. Setup route selection state (simular que el usuario ya tiene opciones)
      final mockRoutes = await _MockItineraryService().planRoute(
        origenCoords: Coordenada(latitud: -34.906, longitud: -56.186),
        destinoCoords: Coordenada(latitud: -34.909, longitud: -56.189),
      );

      notifier.state = notifier.state.copyWith(
        faseActual: FaseApp.MOSTRANDO_OPCIONES_RUTA,
        datosFaseOpcionesRuta: EstadoFaseOpcionesRuta(
          opcionesDeRuta: mockRoutes,
        ),
        idOpcionRutaPrevisualizada: 'test-route-1',
      );

      // 2. Iniciar viaje
      await notifier.confirmarOpcionDeRutaEIniciarViaje('test-route-1');

      print('\n--- VIAJE INICIADO, ARRANCANDO SIMULADOR ---\n');

      // 3. Iniciar simulador a 10x (como en producción)
      await notifier.devStartTripSimulation(speed: 10.0);

      print('\n--- SIMULADOR CORRIENDO POR 30 SEGUNDOS ---\n');

      // 4. Esperar que el simulador complete todo el viaje
      // Con velocidades realistas y simulador a 10x, puede tomar más tiempo
      await Future.delayed(Duration(seconds: 30));

      print('\n--- DETENIENDO SIMULADOR ---\n');

      // 5. Detener simulador
      notifier.devStopTripSimulation();

      print('\n╔════════════════════════════════════════════════════════════╗');
      print('║  TEST COMPLETADO                                           ║');
      print('╚════════════════════════════════════════════════════════════╝\n');
      print('NOTA: Revisa los logs arriba para identificar los bugs:');
      print('  1. Busca "Velocidad calculada" sin [SIM 10x] y con >100 km/h');
      print('  2. Busca "Updating bus approach line" y verifica si usa misma parada');
      print('  3. Busca "[TRIP_SIM] FASE 3" con [TripOrchestrator] waitForBus');
      print('\n✅ Test de reproducción completado');
    });
  });
}

// ============================================================================
// MOCK SERVICES (mínimos para que el test funcione)
// ============================================================================

class _MockMontevideoApi extends MontevideoApiServiceAdapterBase {
  @override
  Future<List<InfoParadaEnMapa>> getAllStops() async => [];

  @override
  Future<InfoDetalladaParada?> getStopDetailsWithEta(
    String stopId,
    String stopName,
    Coordenada stopPosition,
  ) async => null;
}

class _MockItineraryService extends ItineraryPlanningServiceAdapterBase {
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
        secuenciaModosIconos: [
          TipoTramoViaje.CAMINAR,
          TipoTramoViaje.ESPERAR_BUS,
          TipoTramoViaje.VIAJE_EN_BUS,
          TipoTramoViaje.CAMINAR
        ],
        distanciaTotalCaminataMetros: 600,
        tiempoTotalEsperaBusSegundos: 180,
        score: 100,
        tramosParaPreview: [
          // Tramo 0: Caminar a parada
          TramoViajeMostrable(
            idTramo: 'walk-to-stop',
            tipo: TipoTramoViaje.CAMINAR,
            descripcion: 'Camina a la parada',
            duracionEstimadaSegundos: 300,
            distanciaMetros: 400,
            geometriaPolilinea: [
              Coordenada(latitud: -34.906, longitud: -56.186),
              Coordenada(latitud: -34.9065, longitud: -56.1865),
              Coordenada(latitud: -34.907, longitud: -56.187),
            ],
            // ✅ Añadir destino de este tramo (la parada de bus)
            coordenadasParadaDestino: Coordenada(latitud: -34.907, longitud: -56.187),
          ),

          // Tramo 1: Esperar bus
          TramoViajeMostrable(
            idTramo: 'wait-bus',
            tipo: TipoTramoViaje.ESPERAR_BUS,
            descripcion: 'Espera el bus 123',
            duracionEstimadaSegundos: 180,
            nombreLineaBus: '123',
            posicionPunto: Coordenada(latitud: -34.907, longitud: -56.187),
            // ✅ Añadir ID y nombre de parada
            idParadaOrigenTramoBus: '5296',
            nombreParadaOrigen: 'Parada Test Origen',
            coordenadasParadaOrigen: Coordenada(latitud: -34.907, longitud: -56.187),
          ),

          // Tramo 2: Viaje en bus (con paradas origen y destino)
          TramoViajeMostrable(
            idTramo: 'bus-ride',
            tipo: TipoTramoViaje.VIAJE_EN_BUS,
            descripcion: 'Viaja en bus 123',
            duracionEstimadaSegundos: 900,
            distanciaMetros: 2000,
            nombreLineaBus: '123',
            coordenadasParadaOrigen: Coordenada(latitud: -34.907, longitud: -56.187),
            coordenadasParadaDestino: Coordenada(latitud: -34.908, longitud: -56.188),
            idParadaOrigenTramoBus: '5296',
            nombreParadaOrigen: 'Parada Test Origen',
            // ✅ Añadir ID y nombre de parada destino
            idParadaDestinoTramoBus: '5297',
            nombreParadaDestino: 'Parada Test Destino',
            geometriaPolilinea: [
              Coordenada(latitud: -34.907, longitud: -56.187),
              Coordenada(latitud: -34.9075, longitud: -56.1875),
              Coordenada(latitud: -34.908, longitud: -56.188),
            ],
          ),

          // Tramo 3: Caminar a destino
          TramoViajeMostrable(
            idTramo: 'walk-to-dest',
            tipo: TipoTramoViaje.CAMINAR,
            descripcion: 'Camina al destino',
            duracionEstimadaSegundos: 200,
            distanciaMetros: 300,
            geometriaPolilinea: [
              Coordenada(latitud: -34.908, longitud: -56.188),
              Coordenada(latitud: -34.9085, longitud: -56.1885),
              Coordenada(latitud: -34.909, longitud: -56.189),
            ],
            coordenadasParadaDestino: Coordenada(latitud: -34.909, longitud: -56.189),
          ),
        ],
      ),
    ];
  }
}

class _MockGeocodingService extends GeocodingServiceAdapter {
  @override
  Future<List<SugerenciaLugar>> fetchSuggestions(
    String query, {
    Coordenada? proximity,
  }) async => [];

  @override
  Future<List<SugerenciaLugar>> reverseGeocode(Coordenada coords) async => [];
}
