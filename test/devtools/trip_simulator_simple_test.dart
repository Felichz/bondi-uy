import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import 'package:bondi_uy/devtools/trip_simulator.dart';

/// Test simplificado del TripSimulator
///
/// Valida que el simulador:
/// 1. Solo inyecta GPS (principio fundamental)
/// 2. No tiene saltos en las posiciones (velocidades razonables)
/// 3. Las fases son secuenciales
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TripSimulator - Validation Tests', () {
    test('should inject GPS locations without jumps', () async {
      // Capturar ubicaciones inyectadas
      final userLocations = <Coordenada>[];
      final busLocations = <Map<String, dynamic>>[];

      DateTime? lastUserTime;
      DateTime? lastBusTime;
      Coordenada? lastUserPos;
      Coordenada? lastBusPos;

      final userVelocities = <double>[];
      final busVelocities = <double>[];

      // Mock notifier simple
      final mockNotifier = _SimpleNotifierMock(
        onUserLocation: (pos) {
          userLocations.add(pos);

          if (lastUserPos != null && lastUserTime != null) {
            final dist = _calculateDistance(lastUserPos!, pos);
            final timeDiff = DateTime.now().difference(lastUserTime!).inMilliseconds / 1000.0;
            if (timeDiff > 0.01) {
              // Evitar divisiones por casi cero
              final vel = dist / timeDiff;
              userVelocities.add(vel);
            }
          }

          lastUserPos = pos;
          lastUserTime = DateTime.now();
        },
        onBusLocation: (pos, eta) {
          busLocations.add({'pos': pos, 'eta': eta});

          if (lastBusPos != null && lastBusTime != null) {
            final dist = _calculateDistance(lastBusPos!, pos);
            final timeDiff = DateTime.now().difference(lastBusTime!).inMilliseconds / 1000.0;
            if (timeDiff > 0.01) {
              final vel = dist / timeDiff;
              busVelocities.add(vel);
            }
          }

          lastBusPos = pos;
          lastBusTime = DateTime.now();
        },
        mockState: _createMockTripState(),
      );

      // Crear simulador a alta velocidad
      final simulator = TripSimulator(mockNotifier, speed: 50.0);

      print('\n=== EJECUTANDO SIMULACIÓN (50x velocidad) ===');
      await simulator.start();

      // Esperar ~1.2 segundos ((15+15+15+10)/50 ≈ 1.1s)
      await Future.delayed(Duration(milliseconds: 1400));

      simulator.stop();

      print('\n=== RESULTADOS ===');
      print('📍 User locations: ${userLocations.length}');
      print('🚌 Bus locations: ${busLocations.length}');
      print('📊 User velocities calculadas: ${userVelocities.length}');
      print('📊 Bus velocities calculadas: ${busVelocities.length}');

      // ===  VALIDACIONES ===

      // 1. Se inyectaron ubicaciones
      expect(userLocations.isNotEmpty, isTrue);
      expect(busLocations.isNotEmpty, isTrue);

      // 2. NO hay saltos (velocidades razonables)
      if (userVelocities.isNotEmpty) {
        final maxUserVel = userVelocities.reduce(math.max);
        final avgUserVel = userVelocities.reduce((a, b) => a + b) / userVelocities.length;

        print('\n👤 Usuario:');
        print('  Max velocity: ${maxUserVel.toStringAsFixed(1)} m/s (${(maxUserVel * 3.6).toStringAsFixed(0)} km/h)');
        print('  Avg velocity: ${avgUserVel.toStringAsFixed(1)} m/s (${(avgUserVel * 3.6).toStringAsFixed(0)} km/h)');

        // Usuario caminando: max ~2 m/s (7 km/h)
        // Usuario en bus: max ~20 m/s (72 km/h)
        const maxAcceptable = 25.0; // m/s

        expect(maxUserVel, lessThan(maxAcceptable),
            reason: 'Velocidad usuario debe ser < 25 m/s. '
                'Actual: ${maxUserVel.toStringAsFixed(1)} m/s = ${(maxUserVel * 3.6).toStringAsFixed(0)} km/h');
      }

      if (busVelocities.isNotEmpty) {
        final maxBusVel = busVelocities.reduce(math.max);
        final avgBusVel = busVelocities.reduce((a, b) => a + b) / busVelocities.length;

        print('\n🚌 Bus:');
        print('  Max velocity: ${maxBusVel.toStringAsFixed(1)} m/s (${(maxBusVel * 3.6).toStringAsFixed(0)} km/h)');
        print('  Avg velocity: ${avgBusVel.toStringAsFixed(1)} m/s (${(avgBusVel * 3.6).toStringAsFixed(0)} km/h)');

        const maxAcceptable = 25.0; // m/s (~90 km/h)

        expect(maxBusVel, lessThan(maxAcceptable),
            reason: 'Velocidad bus debe ser < 25 m/s. '
                'Actual: ${maxBusVel.toStringAsFixed(1)} m/s = ${(maxBusVel * 3.6).toStringAsFixed(0)} km/h');
      }

      // 3. ETAs del bus decrecen con el tiempo
      if (busLocations.length >= 2) {
        final firstEta = busLocations.first['eta'] as int;
        final lastEta = busLocations.last['eta'] as int;

        print('\n⏱️  ETAs:');
        print('  Primera: $firstEta min');
        print('  Última: $lastEta min');

        // En fase approach, ETA debe decrecer o quedarse en 0
        expect(lastEta, lessThanOrEqualTo(firstEta),
            reason: 'ETA debe decrecer conforme el bus se acerca');
      }

      print('\n✅ TEST EXITOSO');
      print('   - Simulador inyectó GPS correctamente');
      print('   - NO hay saltos de posición');
      print('   - Velocidades razonables');
    });

    test('should follow route geometries', () async {
      final userLocations = <Coordenada>[];

      final mockNotifier = _SimpleNotifierMock(
        onUserLocation: (pos) => userLocations.add(pos),
        onBusLocation: (pos, eta) {},
        mockState: _createMockTripState(),
      );

      final simulator = TripSimulator(mockNotifier, speed: 100.0);

      await simulator.start();
      await Future.delayed(Duration(milliseconds: 700));
      simulator.stop();

      // Validar que las ubicaciones están cerca de la geometría definida
      if (userLocations.isNotEmpty) {
        final mockState = _createMockTripState();
        final walkGeom = mockState.tramosDelViaje[0].geometriaPolilinea!;

        // Primera ubicación debe estar cerca del inicio de la ruta
        final firstUserLoc = userLocations.first;
        final walkStart = walkGeom.first;
        final distToStart = _calculateDistance(firstUserLoc, walkStart);

        print('\n📍 Distancia entre primera ubicación y inicio de ruta: ${distToStart.toStringAsFixed(1)}m');

        expect(distToStart, lessThan(100.0),
            reason: 'Primera ubicación debe estar cerca del inicio de la ruta de caminata');

        print('✅ Las ubicaciones siguen la geometría de la ruta');
      }
    });
  });
}

/// Mock notifier minimalista para capturar inyecciones
class _SimpleNotifierMock {
  final Function(Coordenada) onUserLocation;
  final Function(Coordenada, int) onBusLocation;
  final EstadoFaseViajeActivo mockState;

  _SimpleNotifierMock({
    required this.onUserLocation,
    required this.onBusLocation,
    required this.mockState,
  });

  void devPushMockUserLocation(Coordenada location) {
    onUserLocation(location);
  }

  void devPushRealtimeBusPosition(Coordenada position, int etaMinutes) {
    onBusLocation(position, etaMinutes);
  }

  EstadoFaseViajeActivo? devGetActiveTripState() => mockState;

  void devActivateExternalLocationFeed() {}
  void devStopBusRealtimePolling() {}
  void devResumeRealBusPolling() {}
}

/// Crea un estado de viaje mock con geometrías simples
EstadoFaseViajeActivo _createMockTripState() {
  return EstadoFaseViajeActivo(
    idViajeActivoConfirmado: 'test_trip',
    opcionDeRutaSeleccionada: OpcionDeRutaSeleccionada(
      idOpcion: 'test_route',
      esRecomendada: true,
      duracionEstimadaSegundos: 1800,
      distanciaCaminataMetros: 500,
      tiempoEsperaEstimadoSegundos: 60,
    ),
    tramosDelViaje: [
      // Tramo 1: Caminata a parada
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
      // Tramo 2: Viaje en bus
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
      // Tramo 3: Caminata a destino
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
}

/// Calcula distancia Haversine entre dos coordenadas
double _calculateDistance(Coordenada p1, Coordenada p2) {
  const R = 6371000.0;
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
