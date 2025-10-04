import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:bondi_uy/devtools/trip_simulation_spec.dart';
import 'package:bondi_uy/devtools/trip_simulation_executor.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';

void main() {
  group('TripSimulation', () {
    test('should load and parse JSON fixture', () async {
      // Cargar fixture
      final file = File('test/fixtures/trip_simulation_example.json');
      final json = jsonDecode(await file.readAsString());

      // Parsear spec
      final spec = TripSimulationSpec.fromJson(json);

      // Verificar estructura
      expect(spec.phases.length, equals(4));
      expect(spec.phases[0].type, equals(PhaseType.walkToStop));
      expect(spec.phases[1].type, equals(PhaseType.waitForBus));
      expect(spec.phases[2].type, equals(PhaseType.rideOnBus));
      expect(spec.phases[3].type, equals(PhaseType.walkToDestination));

      // Verificar eventos de cámara esperados
      expect(spec.config.expectedCameraEvents.length, equals(4));
      expect(
        spec.config.expectedCameraEvents[0].type,
        equals(CameraEventType.zoomToUserAndStop),
      );
      expect(
        spec.config.expectedCameraEvents[1].type,
        equals(CameraEventType.zoomToBusAndStop),
      );
    });

    test('should execute simulation and emit events', () async {
      // Cargar fixture
      final file = File('test/fixtures/trip_simulation_example.json');
      final json = jsonDecode(await file.readAsString());

      // Modificar config para acelerar
      json['config']['speed'] = 100.0;
      final spec = TripSimulationSpec.fromJson(json);

      // Capturar eventos
      final events = <SimulationEvent>[];
      final userLocations = <Coordenada>[];
      final busLocations = <Coordenada>[];

      // Crear executor
      final executor = TripSimulationExecutor(
        spec: spec,
        onUserLocationUpdate: (pos) => userLocations.add(pos),
        onBusLocationUpdate: (pos, eta) => busLocations.add(pos),
        onEvent: (event) => events.add(event),
      );

      // Ejecutar simulación
      executor.start();

      // Esperar a que complete (60s / 100 = 0.6s)
      await Future.delayed(Duration(milliseconds: 700));

      // Verificar que se ejecutó
      expect(executor.isRunning, isFalse);
      expect(events.isNotEmpty, isTrue);

      // Verificar eventos clave
      final startEvent = events.firstWhere(
        (e) => e.type == SimulationEventType.simulationStarted,
      );
      expect(startEvent, isNotNull);

      final phaseChanges = events
          .where((e) => e.type == SimulationEventType.phaseChanged)
          .toList();
      expect(phaseChanges.length, greaterThanOrEqualTo(3)); // Al menos 3 cambios

      // Verificar que se generaron ubicaciones
      expect(userLocations.length, greaterThan(0));
      expect(busLocations.length, greaterThan(0));

      // Imprimir resumen para debugging
      print('\n=== SIMULATION SUMMARY ===');
      print('Total events: ${events.length}');
      print('User locations: ${userLocations.length}');
      print('Bus locations: ${busLocations.length}');
      print('Phase changes: ${phaseChanges.length}');
      print('\nPhase transitions:');
      for (final change in phaseChanges) {
        print('  ${change.toString()}');
      }
    });

    test('should validate camera events match specifications', () async {
      // Cargar fixture
      final file = File('test/fixtures/trip_simulation_example.json');
      final json = jsonDecode(await file.readAsString());
      final spec = TripSimulationSpec.fromJson(json);

      // Verificar que los eventos de cámara están definidos según el flujo
      final expectedEvents = spec.config.expectedCameraEvents;

      // Fase 1: WalkToStop - debe enfocar usuario y parada
      final walkEvent = expectedEvents.firstWhere(
        (e) => e.type == CameraEventType.zoomToUserAndStop,
      );
      expect(walkEvent.expectedData!['shouldInclude'], contains('user'));
      expect(walkEvent.expectedData!['shouldInclude'], contains('stop'));
      expect(walkEvent.expectedData!['shouldDrawBlueLine'], isTrue);

      // Fase 2: WaitForBus - debe enfocar bus y parada
      final waitEvent = expectedEvents.firstWhere(
        (e) => e.type == CameraEventType.zoomToBusAndStop,
      );
      expect(waitEvent.expectedData!['shouldInclude'], contains('bus'));
      expect(waitEvent.expectedData!['shouldInclude'], contains('stop'));
      expect(waitEvent.expectedData!['shouldDrawGreenLine'], isTrue);
      expect(waitEvent.expectedData!['shouldAdjustZoomOnBusUpdate'], isTrue);

      // Fase 3: RideOnBus - usuario = bus
      final rideEvent = expectedEvents.firstWhere(
        (e) => e.type == CameraEventType.zoomToUserOnBus,
      );
      expect(rideEvent.expectedData!['userShouldEqualBus'], isTrue);
      expect(
        rideEvent.expectedData!['shouldInclude'],
        contains('destinationStop'),
      );

      // Fase 4: WalkToDestination - modo caminata normal
      final destEvent = expectedEvents.firstWhere(
        (e) => e.type == CameraEventType.zoomToDestination,
      );
      expect(destEvent.expectedData!['shouldInclude'], contains('user'));
      expect(destEvent.expectedData!['shouldInclude'], contains('destination'));
    });

    test('should serialize and deserialize spec to JSON', () async {
      // Cargar fixture original
      final file = File('test/fixtures/trip_simulation_example.json');
      final originalJson = jsonDecode(await file.readAsString());

      // Parsear y volver a serializar
      final spec = TripSimulationSpec.fromJson(originalJson);
      final regeneratedJson = spec.toJson();

      // Verificar que la estructura se mantiene
      expect(regeneratedJson['phases'].length, equals(4));
      expect(
        regeneratedJson['config']['expectedCameraEvents'].length,
        equals(4),
      );
    });
  });
}
