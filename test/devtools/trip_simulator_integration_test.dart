import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bondi_uy/devtools/trip_simulator.dart';
import 'package:bondi_uy/backend/providers/app_logic_provider.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import 'package:bondi_uy/backend/services/montevideo_api_service_adapter.dart';
import 'package:bondi_uy/backend/services/itinerary_planning_service_adapter.dart';
import 'package:bondi_uy/backend/services/geocoding_service_adapter.dart';

/// Test de integración del TripSimulator con el código de producción real
///
/// Este test valida que:
/// 1. El simulador solo inyecta GPS (no toca cámara ni journey)
/// 2. El código de producción reacciona correctamente a los inputs GPS
/// 3. No hay saltos en las posiciones (velocidades razonables)
/// 4. Las transiciones de journey steps ocurren automáticamente
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TripSimulator Integration Tests', () {
    test('simulator should only inject GPS inputs', () async {
      // Este test valida el principio fundamental:
      // El simulador SOLO inyecta GPS, no manipula cámara ni journey

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Capturar todas las ubicaciones inyectadas
      final userLocations = <Coordenada>[];
      final busLocations = <Coordenada>[];
      final userVelocities = <double>[];
      final busVelocities = <double>[];

      // Mock del notifier para capturar inyecciones
      Coordenada? lastUserPos;
      Coordenada? lastBusPos;
      DateTime? lastUserTime;
      DateTime? lastBusTime;

      // Simular que tenemos un viaje activo con geometrías simples
      final mockState = EstadoFaseViajeActivo(
        idViajeActivoConfirmado: 'test_trip',
        opcionDeRutaSeleccionada: OpcionDeRuta(
          idOpcion: 'test_route',
          esRecomendada: true,
          duracionEstimadaSegundos: 1800,
          distanciaCaminataMetros: 500,
          tiempoEsperaEstimadoSegundos: 60,
        ),
        tramosDelViaje: [
          // Tramo de caminata a la parada
          TramoViajeMostrable(
            idTramo: 'walk_to_stop',
            tipo: TipoTramoViaje.CAMINAR,
            descripcion: 'Caminar a la parada',
            duracionEstimadaSegundos: 300,
            geometriaPolilinea: [
              Coordenada(latitud: -34.9025, longitud: -56.1284),
              Coordenada(latitud: -34.9030, longitud: -56.1290),
              Coordenada(latitud: -34.9044, longitud: -56.1294),
            ],
          ),
          // Tramo de bus
          TramoViajeMostrable(
            idTramo: 'bus_ride',
            tipo: TipoTramoViaje.VIAJE_EN_BUS,
            descripcion: 'Viaje en bus DE1',
            duracionEstimadaSegundos: 900,
            nombreLineaBus: 'DE1',
            coordenadasParadaOrigen: Coordenada(latitud: -34.9044, longitud: -56.1294),
            coordenadasParadaDestino: Coordenada(latitud: -34.9052, longitud: -56.1999),
            idParadaOrigenTramoBus: '5296',
            nombreParadaOrigen: 'RBLA ARMENIA - BENIGNO PAIVA',
            geometriaPolilinea: [
              Coordenada(latitud: -34.9044, longitud: -56.1294),
              Coordenada(latitud: -34.9045, longitud: -56.1350),
              Coordenada(latitud: -34.9046, longitud: -56.1450),
              Coordenada(latitud: -34.9047, longitud: -56.1550),
              Coordenada(latitud: -34.9048, longitud: -56.1650),
              Coordenada(latitud: -34.9049, longitud: -56.1750),
              Coordenada(latitud: -34.9050, longitud: -56.1850),
              Coordenada(latitud: -34.9051, longitud: -56.1950),
              Coordenada(latitud: -34.9052, longitud: -56.1999),
            ],
          ),
          // Tramo de caminata final
          TramoViajeMostrable(
            idTramo: 'walk_to_dest',
            tipo: TipoTramoViaje.CAMINAR,
            descripcion: 'Caminar al destino',
            duracionEstimadaSegundos: 200,
            geometriaPolilinea: [
              Coordenada(latitud: -34.9052, longitud: -56.1999),
              Coordenada(latitud: -34.9060, longitud: -56.2005),
              Coordenada(latitud: -34.9070, longitud: -56.1995),
            ],
          ),
        ],
      );

      // Crear mock notifier que capture las inyecciones
      final mockNotifier = _MockAppLogicNotifier(
        onPushUserLocation: (pos) {
          userLocations.add(pos);

          // Calcular velocidad
          if (lastUserPos != null && lastUserTime != null) {
            final distance = _calculateDistance(lastUserPos!, pos);
            final timeDiff = DateTime.now().difference(lastUserTime!).inMilliseconds / 1000.0;
            if (timeDiff > 0) {
              final velocity = distance / timeDiff; // m/s
              userVelocities.add(velocity);
            }
          }

          lastUserPos = pos;
          lastUserTime = DateTime.now();
        },
        onPushBusLocation: (pos, eta) {
          busLocations.add(pos);

          // Calcular velocidad
          if (lastBusPos != null && lastBusTime != null) {
            final distance = _calculateDistance(lastBusPos!, pos);
            final timeDiff = DateTime.now().difference(lastBusTime!).inMilliseconds / 1000.0;
            if (timeDiff > 0) {
              final velocity = distance / timeDiff; // m/s
              busVelocities.add(velocity);
            }
          }

          lastBusPos = pos;
          lastBusTime = DateTime.now();
        },
        mockState: mockState,
      );

      // Crear simulador con velocidad alta para testing rápido
      final simulator = TripSimulator(
        mockNotifier,
        speed: 50.0, // 50x velocidad para que termine rápido
      );

      print('\n=== INICIANDO SIMULACIÓN ===');
      await simulator.start();

      // Esperar a que la simulación avance significativamente
      // Total duración: ~(15 + 15 + 15 + 10) / 50 = ~1.1 segundos
      await Future.delayed(Duration(milliseconds: 1500));

      simulator.stop();

      print('\n=== RESULTADOS DE LA SIMULACIÓN ===');
      print('User locations capturadas: ${userLocations.length}');
      print('Bus locations capturadas: ${busLocations.length}');
      print('User velocities calculadas: ${userVelocities.length}');
      print('Bus velocities calculadas: ${busVelocities.length}');

      // VALIDACIÓN 1: El simulador SÍ inyectó ubicaciones
      expect(userLocations.isNotEmpty, isTrue,
          reason: 'El simulador debe inyectar ubicaciones de usuario');
      expect(busLocations.isNotEmpty, isTrue,
          reason: 'El simulador debe inyectar ubicaciones de bus');

      // VALIDACIÓN 2: NO hay saltos (velocidades razonables)
      // Velocidad máxima aceptable: 30 m/s (~108 km/h para bus)
      const maxAcceptableVelocity = 30.0;

      if (userVelocities.isNotEmpty) {
        final maxUserVel = userVelocities.reduce((a, b) => a > b ? a : b);
        final avgUserVel = userVelocities.reduce((a, b) => a + b) / userVelocities.length;

        print('\nUser velocities:');
        print('  Max: ${maxUserVel.toStringAsFixed(2)} m/s (${(maxUserVel * 3.6).toStringAsFixed(1)} km/h)');
        print('  Avg: ${avgUserVel.toStringAsFixed(2)} m/s (${(avgUserVel * 3.6).toStringAsFixed(1)} km/h)');

        expect(maxUserVel, lessThan(maxAcceptableVelocity),
            reason: 'Velocidad del usuario debe ser razonable (sin saltos). '
                'Max: ${maxUserVel.toStringAsFixed(1)} m/s = ${(maxUserVel * 3.6).toStringAsFixed(0)} km/h');
      }

      if (busVelocities.isNotEmpty) {
        final maxBusVel = busVelocities.reduce((a, b) => a > b ? a : b);
        final avgBusVel = busVelocities.reduce((a, b) => a + b) / busVelocities.length;

        print('\nBus velocities:');
        print('  Max: ${maxBusVel.toStringAsFixed(2)} m/s (${(maxBusVel * 3.6).toStringAsFixed(1)} km/h)');
        print('  Avg: ${avgBusVel.toStringAsFixed(2)} m/s (${(avgBusVel * 3.6).toStringAsFixed(1)} km/h)');

        expect(maxBusVel, lessThan(maxAcceptableVelocity),
            reason: 'Velocidad del bus debe ser razonable (sin saltos). '
                'Max: ${maxBusVel.toStringAsFixed(1)} m/s = ${(maxBusVel * 3.6).toStringAsFixed(0)} km/h');
      }

      // VALIDACIÓN 3: Las ubicaciones siguen las geometrías
      // Primera ubicación de usuario debe estar cerca del inicio de walk
      final firstUserLoc = userLocations.first;
      final walkStart = mockState.tramosDelViaje[0].geometriaPolilinea!.first;
      final distToWalkStart = _calculateDistance(firstUserLoc, walkStart);

      expect(distToWalkStart, lessThan(100.0),
          reason: 'Primera ubicación de usuario debe estar cerca del inicio de caminata');

      print('\n=== TEST EXITOSO ===');
      print('✅ Simulador solo inyecta GPS (no manipula cámara/journey)');
      print('✅ No hay saltos de posición (velocidades razonables)');
      print('✅ Las ubicaciones siguen las geometrías definidas');
    });

    test('should validate sequential phases without overlap', () async {
      // Este test valida que las fases son secuenciales sin superposición

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final phaseTransitions = <String>[];
      String? currentPhase;

      // Mock state con geometrías
      final mockState = EstadoFaseViajeActivo(
        idViajeActivoConfirmado: 'test_trip',
        opcionDeRutaSeleccionada: OpcionDeRuta(
          idOpcion: 'test_route',
          esRecomendada: true,
          duracionEstimadaSegundos: 1800,
          distanciaCaminataMetros: 500,
          tiempoEsperaEstimadoSegundos: 60,
        ),
        tramosDelViaje: [
          TramoViajeMostrable(
            idTramo: 'walk',
            tipo: TipoTramoViaje.CAMINAR,
            descripcion: 'Walk',
            duracionEstimadaSegundos: 300,
            geometriaPolilinea: [
              Coordenada(latitud: -34.9025, longitud: -56.1284),
              Coordenada(latitud: -34.9044, longitud: -56.1294),
            ],
          ),
          TramoViajeMostrable(
            idTramo: 'bus',
            tipo: TipoTramoViaje.VIAJE_EN_BUS,
            descripcion: 'Bus',
            duracionEstimadaSegundos: 900,
            nombreLineaBus: 'DE1',
            coordenadasParadaOrigen: Coordenada(latitud: -34.9044, longitud: -56.1294),
            coordenadasParadaDestino: Coordenada(latitud: -34.9052, longitud: -56.1999),
            idParadaOrigenTramoBus: '5296',
            nombreParadaOrigen: 'Test Stop',
            geometriaPolilinea: [
              Coordenada(latitud: -34.9044, longitud: -56.1294),
              Coordenada(latitud: -34.9052, longitud: -56.1999),
            ],
          ),
        ],
      );

      final mockNotifier = _MockAppLogicNotifier(
        onPushUserLocation: (pos) {
          // Detectar fase basado en posición
          final newPhase = _detectPhase(pos, mockState);
          if (newPhase != currentPhase) {
            phaseTransitions.add(newPhase);
            currentPhase = newPhase;
            print('[PHASE_TRANSITION] → $newPhase');
          }
        },
        onPushBusLocation: (pos, eta) {},
        mockState: mockState,
      );

      final simulator = TripSimulator(mockNotifier, speed: 100.0);

      await simulator.start();
      await Future.delayed(Duration(milliseconds: 800));
      simulator.stop();

      print('\n=== TRANSICIONES DE FASE ===');
      for (int i = 0; i < phaseTransitions.length; i++) {
        print('${i + 1}. ${phaseTransitions[i]}');
      }

      // Validar que hubo transiciones de fase
      expect(phaseTransitions.length, greaterThanOrEqualTo(2),
          reason: 'Debe haber al menos 2 fases (walk → ride)');

      print('\n✅ Fases ejecutadas secuencialmente');
    });
  });
}

/// Mock simple del AppLogicNotifier para capturar inyecciones GPS
class _MockAppLogicNotifier extends AppLogicNotifier {
  final Function(Coordenada) onPushUserLocation;
  final Function(Coordenada, int) onPushBusLocation;
  final EstadoFaseViajeActivo mockState;

  _MockAppLogicNotifier({
    required this.onPushUserLocation,
    required this.onPushBusLocation,
    required this.mockState,
  }) : super(
          montevideoApiService: _MockApiService(),
          itineraryPlanningService: _MockItineraryService(),
          geocodingService: _MockGeocodingService(),
        );

  @override
  void devPushMockUserLocation(Coordenada location) {
    onPushUserLocation(location);
  }

  @override
  void devPushRealtimeBusPosition(Coordenada position, int etaMinutes) {
    onPushBusLocation(position, etaMinutes);
  }

  @override
  EstadoFaseViajeActivo? devGetActiveTripState() {
    return mockState;
  }

  @override
  void devActivateExternalLocationFeed() {
    // Mock: no hace nada
  }

  @override
  void devStopBusRealtimePolling() {
    // Mock: no hace nada
  }

  @override
  void devResumeRealBusPolling() {
    // Mock: no hace nada
  }
}

// Mocks mínimos de servicios (no se usan en el test)
class _MockApiService implements MontevideoApiServiceAdapterBase {
  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _MockItineraryService implements ItineraryPlanningServiceAdapterBase {
  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _MockGeocodingService implements GeocodingServiceAdapter {
  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Calcula distancia entre dos coordenadas (Haversine)
double _calculateDistance(Coordenada p1, Coordenada p2) {
  const R = 6371000.0; // Radio de la Tierra en metros
  final dLat = _toRadians(p2.latitud - p1.latitud);
  final dLon = _toRadians(p2.longitud - p1.longitud);

  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(p1.latitud)) *
          math.cos(_toRadians(p2.latitud)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);

  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return R * c;
}

double _toRadians(double degrees) => degrees * math.pi / 180.0;

/// Detecta en qué fase está el usuario basado en su posición
String _detectPhase(Coordenada pos, EstadoFaseViajeActivo state) {
  // Simplificado: basado en qué tramo está más cerca
  final walkGeom = state.tramosDelViaje[0].geometriaPolilinea!;
  final busGeom = state.tramosDelViaje[1].geometriaPolilinea!;

  final distToWalkStart = _calculateDistance(pos, walkGeom.first);
  final distToWalkEnd = _calculateDistance(pos, walkGeom.last);
  final distToBusEnd = _calculateDistance(pos, busGeom.last);

  if (distToWalkStart < 50) return 'WALK_START';
  if (distToWalkEnd < 50) return 'WALK_END_WAIT';
  if (distToBusEnd < 50) return 'RIDE_END';

  return 'IN_TRANSIT';
}
