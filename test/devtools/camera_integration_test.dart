import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bondi_uy/backend/providers/app_logic_provider.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import 'package:bondi_uy/backend/services/montevideo_api_service_adapter.dart';
import 'package:bondi_uy/backend/services/itinerary_planning_service_adapter.dart';
import 'package:bondi_uy/backend/services/geocoding_service_adapter.dart';
import 'package:bondi_uy/map_manager/map_manager.dart';
import 'package:bondi_uy/map_manager/map_camera_controller.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Integration tests de comportamiento de cámara durante trip simulado
///
/// Estos tests verifican el flujo completo:
/// TripSimulator → JourneyManager → MapManager → MapCameraController
///
/// Objetivo: Reproducir bugs de zoom en contexto real de simulación

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Camera Integration Tests - Trip Simulation', () {
    late ProviderContainer container;
    late AppLogicNotifier notifier;
    late MockMapboxMap mockMapbox;
    late MockMapManager mockMapManager;

    setUp(() {
      mockMapbox = MockMapboxMap();
      mockMapManager = MockMapManager(mockMapbox);

      container = ProviderContainer(
        overrides: [
          montevideoApiServiceProvider.overrideWithValue(_MockMontevideoApi()),
          itineraryPlanningServiceProvider.overrideWithValue(_MockItineraryService()),
          geocodingServiceProvider.overrideWithValue(_MockGeocodingService()),
          // TODO: Override mapManagerProvider para inyectar mock
        ],
      );

      notifier = container.read(appLogicProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('INTEGRATION: Zoom sequence durante trip completo', () async {
      print('\n╔════════════════════════════════════════════════════════════╗');
      print('║  TEST: Verificar secuencia de zooms durante trip          ║');
      print('╚════════════════════════════════════════════════════════════╝\n');

      // 1. Setup: Crear ruta con 4 pasos típicos
      final mockRoutes = await _Mock ItineraryService().planRoute(
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

      print('✅ Viaje iniciado');
      print('📊 Estado esperado:');
      print('   - 1 zoom a vista completa del trip (zoomToActiveTrip)');
      print('');

      // Verificar zoom inicial
      expect(mockMapbox.flyToCalls.length, greaterThanOrEqualTo(1),
        reason: 'Debe haber zoom inicial al trip completo');

      final initialZoomCall = mockMapbox.flyToCalls.first;
      print('🎯 Zoom inicial capturado:');
      print('   - Coordenadas: ${initialZoomCall.coordinates.length}');
      print('   - Padding: ${initialZoomCall.padding?.top}/${initialZoomCall.padding?.left}/${initialZoomCall.padding?.bottom}/${initialZoomCall.padding?.right}');
      print('');

      // Según spec: debe incluir TODAS las coordenadas de TODOS los tramos + usuario
      expect(initialZoomCall.coordinates.length, greaterThan(5),
        reason: 'Zoom inicial debe incluir geometría completa del viaje');

      // Según spec: padding de active trip (250/40/100/40)
      expect(initialZoomCall.padding?.top, 250.0, reason: 'Padding top incorrecto');
      expect(initialZoomCall.padding?.bottom, 100.0, reason: 'Padding bottom incorrecto');

      mockMapbox.flyToCalls.clear();
      mockMapbox.cameraForCoordinatesCalls.clear();

      // 3. Iniciar simulador a alta velocidad (50x)
      await notifier.devStartTripSimulation(speed: 50.0);

      print('🚀 Simulador iniciado a 50x');
      print('⏱️  Esperando progreso del simulador...\n');

      // 4. Esperar que simulador avance por las fases
      // Con 50x speed, un trip de ~5 min real = 6 segundos simulados
      // Pero updates cada 1s → 6 updates totales

      // FASE 1: Usuario caminando a parada (primeros 2s ~ 100s simulados)
      await Future.delayed(Duration(seconds: 2));

      print('--- FASE 1: Caminando a parada ---');
      print('🎯 Zooms capturados: ${mockMapbox.flyToCalls.length}');

      // Según spec: Debe haber zoom a paso CAMINAR con override de cooldown
      expect(mockMapbox.flyToCalls.length, greaterThanOrEqualTo(1),
        reason: 'Debe haber zoom al entrar a FASE 1 (caminar a parada)');

      if (mockMapbox.flyToCalls.isNotEmpty) {
        final fase1Zoom = mockMapbox.flyToCalls.first;
        print('   - Coordenadas: ${fase1Zoom.coordinates.length}');
        print('   - Debe incluir: geometría caminata + parada + usuario');

        // Verificar que incluye geometría (>= 3 puntos) + parada + usuario
        expect(fase1Zoom.coordinates.length, greaterThanOrEqualTo(3),
          reason: 'FASE 1: Debe incluir geometría + parada + usuario');
      }
      print('');

      mockMapbox.flyToCalls.clear();

      // FASE 2: Esperando bus (siguientes 2s)
      await Future.delayed(Duration(seconds: 2));

      print('--- FASE 2: Esperando bus ---');
      print('🎯 Zooms capturados: ${mockMapbox.flyToCalls.length}');

      // Según spec: Zoom al entrar + posibles updates durante espera
      expect(mockMapbox.flyToCalls.length, greaterThanOrEqualTo(1),
        reason: 'Debe haber zoom al entrar a FASE 2 (esperar bus)');

      if (mockMapbox.flyToCalls.isNotEmpty) {
        final fase2Zoom = mockMapbox.flyToCalls.first;
        print('   - Coordenadas: ${fase2Zoom.coordinates.length}');
        print('   - Debe incluir: parada + bus + usuario');

        // Verificar que incluye parada + bus + usuario (>= 3)
        expect(fase2Zoom.coordinates.length, greaterThanOrEqualTo(3),
          reason: 'FASE 2: Debe incluir parada + bus + usuario');
      }
      print('');

      mockMapbox.flyToCalls.clear();

      // FASE 3: Viajando en bus (siguientes 2s)
      await Future.delayed(Duration(seconds: 2));

      print('--- FASE 3: Viajando en bus ---');
      print('🎯 Zooms capturados: ${mockMapbox.flyToCalls.length}');

      // Según spec: Zoom al entrar
      expect(mockMapbox.flyToCalls.length, greaterThanOrEqualTo(1),
        reason: 'Debe haber zoom al entrar a FASE 3 (ride en bus)');

      if (mockMapbox.flyToCalls.isNotEmpty) {
        final fase3Zoom = mockMapbox.flyToCalls.first;
        print('   - Coordenadas: ${fase3Zoom.coordinates.length}');
        print('   - Debe incluir: bus + parada destino (NO geometría completa)');

        // BUG CRÍTICO: NO debe incluir geometría completa (100+ puntos)
        expect(fase3Zoom.coordinates.length, lessThan(10),
          reason: 'FASE 3: NO debe incluir geometría completa de línea bus');

        // Debe incluir al menos bus + parada destino
        expect(fase3Zoom.coordinates.length, greaterThanOrEqualTo(2),
          reason: 'FASE 3: Debe incluir bus + parada destino');
      }
      print('');

      mockMapbox.flyToCalls.clear();

      // FASE 4: Caminando a destino (siguientes 2s)
      await Future.delayed(Duration(seconds: 2));

      print('--- FASE 4: Caminando a destino ---');
      print('🎯 Zooms capturados: ${mockMapbox.flyToCalls.length}');

      // BUG REPORTADO: "no se hizo zoom hacia el tramo de caminata" en paso 4
      expect(mockMapbox.flyToCalls.length, greaterThanOrEqualTo(1),
        reason: 'BUG: Debe haber zoom al entrar a FASE 4 (caminar a destino)');

      if (mockMapbox.flyToCalls.isNotEmpty) {
        final fase4Zoom = mockMapbox.flyToCalls.first;
        print('   - Coordenadas: ${fase4Zoom.coordinates.length}');
        print('   - Debe incluir: geometría caminata + destino + usuario');

        // Verificar que incluye geometría + destino
        expect(fase4Zoom.coordinates.length, greaterThanOrEqualTo(2),
          reason: 'FASE 4: Debe incluir geometría + destino final');
      }
      print('');

      // 5. Detener simulador
      notifier.devStopTripSimulation();

      print('╔════════════════════════════════════════════════════════════╗');
      print('║  RESUMEN: Secuencia de zooms verificada                   ║');
      print('╚════════════════════════════════════════════════════════════╝');
      print('✅ Zoom inicial: Trip completo');
      print('✅ FASE 1: Caminar a parada');
      print('✅ FASE 2: Esperar bus');
      print('✅ FASE 3: Ride en bus (SIN geometría completa)');
      print('✅ FASE 4: Caminar a destino (BUG ORIGINAL)');
      print('');
    });

    test('INTEGRATION: Auto-follow respeta interacción manual', () async {
      print('\n╔════════════════════════════════════════════════════════════╗');
      print('║  TEST: Auto-follow pausa con interacción manual           ║');
      print('╚════════════════════════════════════════════════════════════╝\n');

      // Setup viaje
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

      await notifier.confirmarOpcionDeRutaEIniciarViaje('test-route-1');
      await notifier.devStartTripSimulation(speed: 50.0);

      mockMapbox.flyToCalls.clear();

      // Esperar que llegue a FASE 2 (esperar bus)
      await Future.delayed(Duration(seconds: 3));

      print('📍 Simulador en FASE 2 (esperando bus)');
      print('🎯 Zooms antes de interacción: ${mockMapbox.flyToCalls.length}\n');

      mockMapbox.flyToCalls.clear();

      // Simular interacción manual del usuario
      // TODO: Necesitamos acceso al MapCameraController para llamar notifyManualInteraction()
      // Por ahora, este test es un placeholder

      print('⚠️  Test pendiente: Requiere inyección de MapCameraController mock');
      print('   Para verificar:');
      print('   1. Usuario mueve cámara → auto-follow se pausa');
      print('   2. NO hay zooms automáticos por 6 segundos');
      print('   3. Después de 6s → auto-follow se reactiva');
      print('   4. Siguiente transición de paso → zoom se ejecuta');
      print('');
    });

    test('INTEGRATION: Cooldown entre zooms se respeta', () async {
      print('\n╔════════════════════════════════════════════════════════════╗');
      print('║  TEST: Cooldown de 3s entre zooms                         ║');
      print('╚════════════════════════════════════════════════════════════╝\n');

      // Setup viaje
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

      await notifier.confirmarOpcionDeRutaEIniciarViaje('test-route-1');
      await notifier.devStartTripSimulation(speed: 50.0);

      // Esperar a FASE 2 (esperar bus) donde hay updates dinámicos
      await Future.delayed(Duration(seconds: 3));

      mockMapbox.flyToCalls.clear();

      // Durante FASE 2, updateWaitingBusViewport() se llama frecuentemente
      // pero debe respetar cooldown de 3s

      print('📍 En FASE 2: Monitoreando updates de viewport');
      print('⏱️  Contando zooms en ventana de 5 segundos...\n');

      // Monitorear por 5 segundos
      final startTime = DateTime.now();
      final timestamps = <DateTime>[];

      while (DateTime.now().difference(startTime).inSeconds < 5) {
        final currentCount = mockMapbox.flyToCalls.length;
        if (currentCount > timestamps.length) {
          timestamps.add(DateTime.now());
        }
        await Future.delayed(Duration(milliseconds: 100));
      }

      print('🎯 Zooms ejecutados: ${timestamps.length}');
      print('📊 Timestamps:');
      for (int i = 0; i < timestamps.length; i++) {
        if (i == 0) {
          print('   [$i] Inicial');
        } else {
          final diff = timestamps[i].difference(timestamps[i - 1]);
          print('   [$i] +${diff.inMilliseconds}ms desde anterior');

          // Verificar que respeta cooldown de 3s (excepto primera transición con override)
          if (i > 1) {
            expect(diff.inMilliseconds, greaterThanOrEqualTo(2900),
              reason: 'Cooldown de 3s debe respetarse entre zooms');
          }
        }
      }
      print('');

      // En 5 segundos con cooldown de 3s, máximo 2 zooms (inicial + 1 más)
      expect(timestamps.length, lessThanOrEqualTo(3),
        reason: 'Con cooldown de 3s, no debe haber más de 2-3 zooms en 5s');

      print('✅ Cooldown respetado');
      print('');

      notifier.devStopTripSimulation();
    });
  });
}

// ============================================================================
// MOCKS
// ============================================================================

class MockMapboxMap implements MapboxMap {
  final List<FlyToCall> flyToCalls = [];
  final List<CameraForCoordinatesCall> cameraForCoordinatesCalls = [];

  @override
  Future<void> flyTo(CameraOptions cameraOptions, MapAnimationOptions? animationOptions) async {
    if (cameraForCoordinatesCalls.isNotEmpty) {
      final lastCameraCall = cameraForCoordinatesCalls.last;
      flyToCalls.add(FlyToCall(
        cameraOptions: cameraOptions,
        animationOptions: animationOptions,
        coordinates: lastCameraCall.coordinates,
        padding: lastCameraCall.padding,
      ));
    } else {
      flyToCalls.add(FlyToCall(
        cameraOptions: cameraOptions,
        animationOptions: animationOptions,
        coordinates: [],
        padding: null,
      ));
    }
  }

  @override
  Future<CameraOptions> cameraForCoordinates(
    List<Point> coordinates,
    MbxEdgeInsets padding,
    double? bearing,
    double? pitch,
  ) async {
    cameraForCoordinatesCalls.add(CameraForCoordinatesCall(
      coordinates: coordinates.map((p) => Coordenada(
        latitud: p.coordinates.lat.toDouble(),
        longitud: p.coordinates.lng.toDouble(),
      )).toList(),
      padding: padding,
    ));

    return CameraOptions(
      center: coordinates.isNotEmpty ? coordinates.first : null,
      zoom: 14.0,
      bearing: bearing,
      pitch: pitch,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FlyToCall {
  final CameraOptions cameraOptions;
  final MapAnimationOptions? animationOptions;
  final List<Coordenada> coordinates;
  final MbxEdgeInsets? padding;

  FlyToCall({
    required this.cameraOptions,
    this.animationOptions,
    this.coordinates = const [],
    this.padding,
  });
}

class CameraForCoordinatesCall {
  final List<Coordenada> coordinates;
  final MbxEdgeInsets padding;

  CameraForCoordinatesCall({
    required this.coordinates,
    required this.padding,
  });
}

class MockMapManager {
  final MockMapboxMap mapboxMap;

  MockMapManager(this.mapboxMap);

  // TODO: Implementar mock completo de MapManager para integration tests
}

// ============================================================================
// MOCK SERVICES
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

  @override
  Future<List<BusEnTiempoReal>> getBusesForRoute(String routeId) async => [];
}

class _MockItineraryService extends ItineraryPlanningServiceAdapterBase {
  @override
  Future<List<OpcionDeRutaMostrable>> planRoute({
    required Coordenada origenCoords,
    required Coordenada destinoCoords,
  }) async {
    // Ruta mock con 4 pasos típicos: CAMINAR → ESPERAR_BUS → VIAJE_EN_BUS → CAMINAR
    return [
      OpcionDeRutaMostrable(
        idOpcion: 'test-route-1',
        duracionTotalSegundos: 300, // 5 minutos
        horaLlegadaEstimada: DateTime.now().add(Duration(minutes: 5)),
        secuenciaModosIconos: [TipoTramoViaje.CAMINAR, TipoTramoViaje.ESPERAR_BUS, TipoTramoViaje.VIAJE_EN_BUS, TipoTramoViaje.CAMINAR],
        distanciaTotalCaminataMetros: 800,
        tiempoTotalEsperaBusSegundos: 60,
        esRecomendada: true,
        score: 90,
        tramosParaPreview: [
          // Paso 0: CAMINAR a parada
          TramoViajeMostrable(
            idTramo: 'walk-1',
            tipo: TipoTramoViaje.CAMINAR,
            descripcion: 'Caminar a parada',
            duracionEstimadaSegundos: 80,
            distanciaMetros: 400,
            geometriaPolilinea: _generateLine(origenCoords, Coordenada(latitud: -34.907, longitud: -56.187), 10),
            coordenadasParadaDestino: Coordenada(latitud: -34.907, longitud: -56.187),
          ),
          // Paso 1: ESPERAR_BUS
          TramoViajeMostrable(
            idTramo: 'wait-1',
            tipo: TipoTramoViaje.ESPERAR_BUS,
            descripcion: 'Esperar bus',
            duracionEstimadaSegundos: 60,
            posicionPunto: Coordenada(latitud: -34.907, longitud: -56.187),
            nombreLineaBus: '123',
          ),
          // Paso 2: VIAJE_EN_BUS
          TramoViajeMostrable(
            idTramo: 'bus-1',
            tipo: TipoTramoViaje.VIAJE_EN_BUS,
            descripcion: 'Viajar en bus 123',
            duracionEstimadaSegundos: 120,
            distanciaMetros: 2000,
            geometriaPolilinea: _generateLine(Coordenada(latitud: -34.907, longitud: -56.187), Coordenada(latitud: -34.908, longitud: -56.188), 50),
            coordenadasParadaOrigen: Coordenada(latitud: -34.907, longitud: -56.187),
            coordenadasParadaDestino: Coordenada(latitud: -34.908, longitud: -56.188),
            nombreLineaBus: '123',
          ),
          // Paso 3: CAMINAR a destino
          TramoViajeMostrable(
            idTramo: 'walk-2',
            tipo: TipoTramoViaje.CAMINAR,
            descripcion: 'Caminar a destino',
            duracionEstimadaSegundos: 40,
            distanciaMetros: 400,
            geometriaPolilinea: _generateLine(Coordenada(latitud: -34.908, longitud: -56.188), destinoCoords, 10),
            coordenadasParadaDestino: destinoCoords,
          ),
        ],
      ),
    ];
  }

  List<Coordenada> _generateLine(Coordenada start, Coordenada end, int points) {
    final result = <Coordenada>[];
    for (int i = 0; i < points; i++) {
      final t = i / (points - 1);
      result.add(Coordenada(
        latitud: start.latitud + (end.latitud - start.latitud) * t,
        longitud: start.longitud + (end.longitud - start.longitud) * t,
      ));
    }
    return result;
  }
}

class _MockGeocodingService extends GeocodingServiceAdapterBase {
  @override
  Future<List<LocationSearchResult>> searchLocation(String query) async => [];

  @override
  Future<String> reverseGeocode(Coordenada coords) async => 'Mock Address';
}
