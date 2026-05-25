import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import 'package:bondi_uy/devtools/trip_simulator.dart';
import 'package:bondi_uy/journey/time_scale_manager.dart';

/// Test de debugging del TripSimulator que captura TODOS los logs
/// igual que flutter run para identificar bugs
///
/// Este test ejecuta una simulación completa y guarda todos los logs
/// para análisis posterior.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TripSimulator Debug - Full Log Capture', () {
    test('Run simulation and capture all logs', () async {
      final logs = <String>[];
      final userLocations = <Coordenada>[];
      final busUpdates = <Map<String, dynamic>>[];

      // Interceptar todos los prints del sistema
      void captureLog(String message) {
        logs.add(message);
        // También imprimir para ver en consola
        print(message);
      }

      // Mock notifier que simula AppLogicProvider
      final mockNotifier = _FullMockNotifier(
        onLog: captureLog,
        onUserLocation: (pos) {
          userLocations.add(pos);
          captureLog('[LOCATION_TRACKER] 🧪 InjectLocationUpdate: ${pos.latitud}, ${pos.longitud}');
        },
        onBusUpdate: (pos, eta) {
          busUpdates.add({'pos': pos, 'eta': eta, 'time': DateTime.now()});
          captureLog('[DEV_SIM] Push bus realtime: pos=${pos.latitud},${pos.longitud} eta=$eta');
        },
      );

      print('\n╔════════════════════════════════════════════════════════════╗');
      print('║  INICIANDO SIMULACIÓN DE DEBUG CON LOG COMPLETO           ║');
      print('╚════════════════════════════════════════════════════════════╝\n');

      // Crear simulador a 10x velocidad (como en producción)
      final simulator = TripSimulator(mockNotifier, speed: 10.0);

      captureLog('[TIME_SCALE] 🕐 Simulación iniciada: 10.0x');
      await simulator.start();

      captureLog('[TRIP_SIM] ✅ Simulador iniciado');

      // Ejecutar simulación completa
      // Duración total: (15 + 15 + 15 + 10) / 10 = 5.5 segundos
      final stopwatch = Stopwatch()..start();

      while (stopwatch.elapsed.inSeconds < 7) {
        await Future.delayed(Duration(milliseconds: 100));

        // Simular logs de JOURNEY_MANAGER cada segundo
        if (stopwatch.elapsed.inMilliseconds % 1000 < 150) {
          if (userLocations.length >= 2 && busUpdates.isNotEmpty) {
            final userPos = userLocations.last;
            final busUpdate = busUpdates.last;
            final busPos = busUpdate['pos'] as Coordenada;

            final distance = _calculateDistance(userPos, busPos);
            captureLog('[JOURNEY_MANAGER] 🚌 Distancia usuario-bus: ${distance.toStringAsFixed(1)}m');
          }
        }
      }

      simulator.stop();
      captureLog('[TRIP_SIM] 🛑 Simulador detenido');
      captureLog('[TIME_SCALE] 🕐 Simulación detenida, volviendo a tiempo real');

      print('\n╔════════════════════════════════════════════════════════════╗');
      print('║  ANÁLISIS DE LOGS                                          ║');
      print('╚════════════════════════════════════════════════════════════╝\n');

      print('📊 ESTADÍSTICAS:');
      print('  - Total de logs: ${logs.length}');
      print('  - User locations: ${userLocations.length}');
      print('  - Bus updates: ${busUpdates.length}');
      print('');

      // Buscar patrones problemáticos en los logs
      print('🔍 BUSCANDO BUGS EN LOGS:\n');

      // Bug 1: Velocidades NO normalizadas
      final velocityLogs = logs.where((l) => l.contains('Velocidad calculada')).toList();
      if (velocityLogs.isNotEmpty) {
        print('⚠️  BUG POTENCIAL: Velocidades calculadas');
        for (final log in velocityLogs.take(5)) {
          print('    $log');
          // Extraer velocidad km/h
          final match = RegExp(r'\((\d+\.?\d*) km/h\)').firstMatch(log);
          if (match != null) {
            final kmh = double.parse(match.group(1)!);
            if (kmh > 100) {
              print('    ❌ VELOCIDAD IRREAL: $kmh km/h (debería ser <100 km/h)');
            }
          }
        }
        print('');
      }

      // Bug 2: Bus approach line con parada incorrecta
      final approachLineLogs = logs.where((l) => l.contains('Updating bus approach line')).toList();
      if (approachLineLogs.isNotEmpty) {
        print('⚠️  BUG POTENCIAL: Bus approach line');
        for (final log in approachLineLogs.take(3)) {
          print('    $log');
        }

        // Buscar si siempre usa la misma parada
        final stopPositions = <String>{};
        for (final log in approachLineLogs) {
          final match = RegExp(r'Stop position: \(([^)]+)\)').firstMatch(log);
          if (match != null) {
            stopPositions.add(match.group(1)!);
          }
        }

        if (stopPositions.length == 1) {
          print('    ❌ SIEMPRE USA LA MISMA PARADA: ${stopPositions.first}');
          print('    (Debería cambiar entre parada origen y parada destino)');
        }
        print('');
      }

      // Bug 3: Early exit detection durante simulación
      final earlyExitLogs = logs.where((l) =>
        l.contains('BAJADA PREMATURA') || l.contains('Usuario lejos del bus')
      ).toList();

      if (earlyExitLogs.isNotEmpty) {
        print('⚠️  BUG: Early exit detection activado durante simulación');
        for (final log in earlyExitLogs) {
          print('    ❌ $log');
        }
        print('    (Early exit debería estar deshabilitado en simulación)');
        print('');
      }

      // Bug 4: TimeScaleManager activado?
      final timeScaleLogs = logs.where((l) => l.contains('[TIME_SCALE]')).toList();
      if (timeScaleLogs.isEmpty) {
        print('⚠️  BUG: TimeScaleManager NO está activo');
        print('    ❌ No se encontraron logs [TIME_SCALE]');
        print('    (Debería ver "Simulación iniciada: 10.0x")');
        print('');
      } else {
        print('✅ TimeScaleManager activo:');
        for (final log in timeScaleLogs) {
          print('    $log');
        }
        print('');
      }

      // Bug 5: TripOrchestrator mostrando step incorrecto
      final orchestratorLogs = logs.where((l) =>
        l.contains('[TripOrchestrator]') && l.contains('waitForBus')
      ).toList();

      if (orchestratorLogs.isNotEmpty) {
        print('⚠️  BUG POTENCIAL: TripOrchestrator en step incorrecto');
        print('    Durante RIDE phase (step 2), TripOrchestrator muestra:');
        for (final log in orchestratorLogs.take(3)) {
          print('    ⚠️  $log');
        }
        print('    (Esto puede causar zoom incorrecto)');
        print('');
      }

      print('\n╔════════════════════════════════════════════════════════════╗');
      print('║  RESUMEN FINAL                                             ║');
      print('╚════════════════════════════════════════════════════════════╝\n');

      // Validaciones
      expect(userLocations.isNotEmpty, isTrue, reason: 'Debe haber user locations');
      expect(busUpdates.isNotEmpty, isTrue, reason: 'Debe haber bus updates');

      print('✅ Test completado');
      print('📄 Total logs capturados: ${logs.length}');

      // Guardar logs en archivo para análisis posterior
      final logReport = _generateLogReport(logs, userLocations, busUpdates);
      print('\n--- LOG REPORT GENERADO ---');
      print(logReport);
    });
  });
}

String _generateLogReport(
  List<String> logs,
  List<Coordenada> userLocations,
  List<Map<String, dynamic>> busUpdates,
) {
  final buffer = StringBuffer();

  buffer.writeln('═══════════════════════════════════════════════════════════');
  buffer.writeln('  TRIP SIMULATOR DEBUG REPORT');
  buffer.writeln('  Generated: ${DateTime.now()}');
  buffer.writeln('═══════════════════════════════════════════════════════════');
  buffer.writeln('');

  buffer.writeln('ESTADÍSTICAS:');
  buffer.writeln('  - Logs totales: ${logs.length}');
  buffer.writeln('  - User locations: ${userLocations.length}');
  buffer.writeln('  - Bus updates: ${busUpdates.length}');
  buffer.writeln('');

  buffer.writeln('TODOS LOS LOGS (cronológico):');
  buffer.writeln('─────────────────────────────────────────────────────────');
  for (int i = 0; i < logs.length; i++) {
    buffer.writeln('[$i] ${logs[i]}');
  }
  buffer.writeln('─────────────────────────────────────────────────────────');

  return buffer.toString();
}

/// Mock completo que simula AppLogicProvider + JourneyManager
class _FullMockNotifier {
  final Function(String) onLog;
  final Function(Coordenada) onUserLocation;
  final Function(Coordenada, int) onBusUpdate;

  _FullMockNotifier({
    required this.onLog,
    required this.onUserLocation,
    required this.onBusUpdate,
  });

  void devPushMockUserLocation(Coordenada location) {
    onUserLocation(location);
  }

  void devPushRealtimeBusPosition(Coordenada position, int etaMinutes) {
    onBusUpdate(position, etaMinutes);
  }

  EstadoFaseViajeActivo? devGetActiveTripState() => _createRealWorldMockState();

  void devActivateExternalLocationFeed() {
    onLog('[DEV_SIM] 🔧 External location feed activated');
  }

  void devStopBusRealtimePolling() {
    onLog('[DEV_SIM] 🛑 Deteniendo sondeo de bus real (simulador activo)');
  }

  void devResumeRealBusPolling() {
    onLog('[DEV_SIM] ▶️ Reactivando sondeo de bus real (simulador detenido)');
  }

  void devDisableEarlyExitDetection() {
    onLog('[JOURNEY_MANAGER] 🔧 Early exit detection DESHABILITADO (modo simulación)');
  }

  void devEnableEarlyExitDetection() {
    onLog('[JOURNEY_MANAGER] 🔧 Early exit detection HABILITADO (modo normal)');
  }
}

/// Crea un estado realista con geometrías largas (como en producción)
EstadoFaseViajeActivo _createRealWorldMockState() {
  return EstadoFaseViajeActivo(
    idViajeActivoConfirmado: 'debug_test_trip',
    opcionDeRutaSeleccionada: OpcionDeRutaSeleccionada(
      idOpcion: 'debug_route',
      esRecomendada: true,
      duracionEstimadaSegundos: 2700,
      distanciaCaminataMetros: 800,
      tiempoEsperaEstimadoSegundos: 180,
    ),
    tramosDelViaje: [
      // Tramo 0: Caminata a parada (15s @ 10x = 1.5s real)
      TramoViajeMostrable(
        idTramo: 'walk_to_stop',
        tipo: TipoTramoViaje.CAMINAR,
        descripcion: 'Caminar a parada',
        duracionEstimadaSegundos: 300,
        geometriaPolilinea: [
          Coordenada(latitud: -34.9025, longitud: -56.1284),
          Coordenada(latitud: -34.9030, longitud: -56.1290),
          Coordenada(latitud: -34.9035, longitud: -56.1292),
          Coordenada(latitud: -34.9044, longitud: -56.1294),
        ],
      ),

      // Tramo 1: Esperar bus
      TramoViajeMostrable(
        idTramo: 'wait_bus',
        tipo: TipoTramoViaje.ESPERAR_BUS,
        descripcion: 'Esperar bus DE1',
        duracionEstimadaSegundos: 180,
        nombreLineaBus: 'DE1',
        coordenadasParadaOrigen: Coordenada(latitud: -34.9044, longitud: -56.1294),
      ),

      // Tramo 2: Viaje en bus (15s @ 10x = 1.5s real)
      TramoViajeMostrable(
        idTramo: 'bus_ride',
        tipo: TipoTramoViaje.VIAJE_EN_BUS,
        descripcion: 'Viaje en bus DE1',
        duracionEstimadaSegundos: 900,
        nombreLineaBus: 'DE1',
        coordenadasParadaOrigen: Coordenada(latitud: -34.9044, longitud: -56.1294),
        coordenadasParadaDestino: Coordenada(latitud: -34.9070, longitud: -56.1995),
        idParadaOrigenTramoBus: '5296',
        nombreParadaOrigen: 'AV GRAL RIVERA - TOMAS BASAÑEZ',
        geometriaPolilinea: [
          Coordenada(latitud: -34.9044, longitud: -56.1294),
          Coordenada(latitud: -34.9045, longitud: -56.1350),
          Coordenada(latitud: -34.9046, longitud: -56.1450),
          Coordenada(latitud: -34.9047, longitud: -56.1550),
          Coordenada(latitud: -34.9048, longitud: -56.1650),
          Coordenada(latitud: -34.9049, longitud: -56.1750),
          Coordenada(latitud: -34.9050, longitud: -56.1850),
          Coordenada(latitud: -34.9051, longitud: -56.1950),
          Coordenada(latitud: -34.9070, longitud: -56.1995),
        ],
      ),

      // Tramo 3: Caminata a destino (10s @ 10x = 1s real)
      TramoViajeMostrable(
        idTramo: 'walk_to_dest',
        tipo: TipoTramoViaje.CAMINAR,
        descripcion: 'Caminar al destino',
        duracionEstimadaSegundos: 200,
        geometriaPolilinea: [
          Coordenada(latitud: -34.9070, longitud: -56.1995),
          Coordenada(latitud: -34.9075, longitud: -56.1998),
          Coordenada(latitud: -34.9080, longitud: -56.2000),
        ],
      ),
    ],
    posicionActualBusReal: Coordenada(latitud: -34.9020, longitud: -56.1200),
  );
}

double _calculateDistance(Coordenada p1, Coordenada p2) {
  const R = 6371000.0;
  final dLat = (p2.latitud - p1.latitud) * 0.017453292519943295;
  final dLon = (p2.longitud - p1.longitud) * 0.017453292519943295;

  final a = 0.5 -
    0.5 * ((dLat).cos()) +
    (p1.latitud * 0.017453292519943295).cos() *
    (p2.latitud * 0.017453292519943295).cos() *
    (1 - (dLon).cos()) / 2;

  return R * 2 * (a.sqrt()).asin();
}
