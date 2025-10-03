import 'package:flutter_test/flutter_test.dart';
import 'package:bondi_uy/journey/core/trip_state_machine.dart';
import 'package:bondi_uy/journey/core/trip_step.dart';
import 'package:bondi_uy/journey/core/step_detector.dart';
import 'package:bondi_uy/journey/core/trip_orchestrator.dart';

void main() {
  group('Trip Multi-Leg Test - Viajes con múltiples paradas (trasbordos)', () {
    test('Viaje con TRASBORDO: Walk → Wait → Bus1 → Walk → Wait → Bus2 → Walk', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🚌 TEST: Viaje con Trasbordo (2 buses)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      // FLUJO ESPERADO:
      // 1. Caminar a parada 1 (para bus línea 64)
      // 2. Esperar bus línea 64
      // 3. En bus 64 hasta parada 2
      // 4. Caminar de parada 2 a parada 3 (trasbordo)
      // 5. Esperar bus línea 180
      // 6. En bus 180 hasta parada 4
      // 7. Caminar al destino final

      final steps = [
        // ============ PRIMER BUS (Línea 64) ============
        TripStep(
          id: 'walk_to_stop1',
          type: TripStepType.walkToStop,
          description: 'Caminar a parada 1 (Bus 64)',
          metadata: const TripStepMetadata(
            destinationStopId: 'stop1',
            totalDistanceMeters: 300,
          ),
        ),
        TripStep(
          id: 'wait_bus64',
          type: TripStepType.waitForBus,
          description: 'Esperar bus línea 64',
          metadata: const TripStepMetadata(
            originStopId: 'stop1',
            busLine: '64',
            hasEta: true,
          ),
        ),
        TripStep(
          id: 'on_bus64',
          type: TripStepType.onBus,
          description: 'En bus 64 hasta parada 2',
          metadata: const TripStepMetadata(
            originStopId: 'stop1',
            destinationStopId: 'stop2',
            busLine: '64',
          ),
        ),

        // ============ TRASBORDO ============
        TripStep(
          id: 'walk_trasbordo',
          type: TripStepType.walkToStop,
          description: 'Caminar a parada 3 (Trasbordo a Bus 180)',
          metadata: const TripStepMetadata(
            destinationStopId: 'stop3',
            totalDistanceMeters: 150,
          ),
        ),

        // ============ SEGUNDO BUS (Línea 180) ============
        TripStep(
          id: 'wait_bus180',
          type: TripStepType.waitForBus,
          description: 'Esperar bus línea 180',
          metadata: const TripStepMetadata(
            originStopId: 'stop3',
            busLine: '180',
            hasEta: false, // Este no tiene ETA
          ),
        ),
        TripStep(
          id: 'on_bus180',
          type: TripStepType.onBus,
          description: 'En bus 180 hasta parada 4',
          metadata: const TripStepMetadata(
            originStopId: 'stop3',
            destinationStopId: 'stop4',
            busLine: '180',
          ),
        ),

        // ============ DESTINO FINAL ============
        TripStep(
          id: 'walk_to_destination',
          type: TripStepType.walkToDestination,
          description: 'Caminar al destino final',
          metadata: const TripStepMetadata(
            totalDistanceMeters: 200,
          ),
        ),
      ];

      final stateMachine = TripStateMachine(
        tripId: 'multi_leg_trip',
        steps: steps,
      );

      // Mock del GeometryAdapter
      var simulatedDistance = 300.0;
      var simulatedGeofence = false;
      var simulatedOnBusRoute = false;
      var simulatedSpeed = 0.0;
      var simulatedMoving = false;

      final Map<String, double> initialDistances = {};

      Future<StepDetectionContext> mockAdapter(TripStep step) async {
        final initialDistance = initialDistances.putIfAbsent(
          step.id,
          () => step.metadata.totalDistanceMeters ?? simulatedDistance,
        );

        return StepDetectionContext(
          distanceToTarget: simulatedDistance,
          initialDistanceToTarget: initialDistance,
          isWithinGeofence: simulatedGeofence,
          isOnBusRoute: simulatedOnBusRoute,
          userSpeed: simulatedSpeed,
          isUserMoving: simulatedMoving,
          timestamp: DateTime.now(),
        );
      }

      // Callbacks
      var tripCompleted = false;
      var stepsCompleted = <String>[];

      final orchestrator = createDefaultOrchestrator(
        stateMachine: stateMachine,
        getContextForStep: mockAdapter,
        onTripCompleted: () {
          tripCompleted = true;
        },
        onStepChanged: (newStep) {
          stepsCompleted.add(newStep.id);
        },
      );

      orchestrator.start();

      // ═══════════════════════════════════════════════════════
      // PASO 1: Caminar a parada 1
      // ═══════════════════════════════════════════════════════
      print('🚶‍♂️ PASO 1: Caminando a parada 1...');

      expect(stateMachine.currentStep.id, 'walk_to_stop1');
      expect(stateMachine.currentStepIndex, 0);

      simulatedDistance = 150.0; // Mitad de camino
      await orchestrator.updateNow();
      expect(stateMachine.currentStep.progress, closeTo(0.5, 0.1));

      simulatedDistance = 10.0; // Llegó a la parada
      simulatedGeofence = true;
      await orchestrator.updateNow(); // Conf 1
      await orchestrator.updateNow(); // Conf 2 - avanza

      expect(stateMachine.currentStepIndex, 1);
      expect(stepsCompleted.last, 'wait_bus64');
      print('✅ Llegó a parada 1\n');

      // ═══════════════════════════════════════════════════════
      // PASO 2: Esperar bus 64
      // ═══════════════════════════════════════════════════════
      print('🚏 PASO 2: Esperando bus 64...');

      expect(stateMachine.currentStep.id, 'wait_bus64');

      simulatedDistance = 5.0;
      simulatedGeofence = true;
      simulatedOnBusRoute = false;
      simulatedSpeed = 0.0;
      simulatedMoving = false;

      await orchestrator.updateNow();
      expect(stateMachine.currentStepIndex, 1); // Aún esperando

      // Usuario se sube al bus
      simulatedOnBusRoute = true;
      simulatedMoving = true;
      simulatedSpeed = 5.0; // Bus moviéndose

      await orchestrator.updateNow(); // Conf 1
      await orchestrator.updateNow(); // Conf 2
      await orchestrator.updateNow(); // Conf 3 - avanza

      expect(stateMachine.currentStepIndex, 2);
      expect(stepsCompleted.last, 'on_bus64');
      print('✅ Subió al bus 64\n');

      // ═══════════════════════════════════════════════════════
      // PASO 3: En bus 64 hasta parada 2
      // ═══════════════════════════════════════════════════════
      print('🚌 PASO 3: En bus 64...');

      expect(stateMachine.currentStep.id, 'on_bus64');

      simulatedDistance = 1000.0; // 1km a parada 2
      simulatedGeofence = false;

      await orchestrator.updateNow();

      simulatedDistance = 500.0; // Mitad del camino
      await orchestrator.updateNow();

      simulatedDistance = 20.0; // Llegando a parada 2
      simulatedGeofence = true;

      await orchestrator.updateNow(); // Conf 1
      await orchestrator.updateNow(); // Conf 2 - avanza

      expect(stateMachine.currentStepIndex, 3);
      expect(stepsCompleted.last, 'walk_trasbordo');
      print('✅ Llegó a parada 2 (bajó del bus 64)\n');

      // ═══════════════════════════════════════════════════════
      // PASO 4: TRASBORDO - Caminar a parada 3
      // ═══════════════════════════════════════════════════════
      print('🚶‍♂️ PASO 4: TRASBORDO - Caminando a parada 3...');

      expect(stateMachine.currentStep.id, 'walk_trasbordo');

      simulatedDistance = 150.0; // Distancia total al trasbordo
      simulatedGeofence = false;
      simulatedOnBusRoute = false;
      simulatedMoving = true;
      simulatedSpeed = 1.5;

      await orchestrator.updateNow();

      simulatedDistance = 75.0; // Mitad del camino
      await orchestrator.updateNow();
      expect(stateMachine.currentStep.progress, closeTo(0.5, 0.1));

      simulatedDistance = 10.0; // Llegó a parada 3
      simulatedGeofence = true;

      await orchestrator.updateNow(); // Conf 1
      await orchestrator.updateNow(); // Conf 2 - avanza

      expect(stateMachine.currentStepIndex, 4);
      expect(stepsCompleted.last, 'wait_bus180');
      print('✅ Llegó a parada 3 (lista para bus 180)\n');

      // ═══════════════════════════════════════════════════════
      // PASO 5: Esperar bus 180
      // ═══════════════════════════════════════════════════════
      print('🚏 PASO 5: Esperando bus 180 (sin ETA)...');

      expect(stateMachine.currentStep.id, 'wait_bus180');

      simulatedDistance = 5.0;
      simulatedGeofence = true;
      simulatedOnBusRoute = false;
      simulatedSpeed = 0.0;
      simulatedMoving = false;

      await orchestrator.updateNow();

      // Usuario se sube al bus 180
      simulatedOnBusRoute = true;
      simulatedMoving = true;
      simulatedSpeed = 6.0;

      await orchestrator.updateNow(); // Conf 1
      await orchestrator.updateNow(); // Conf 2
      await orchestrator.updateNow(); // Conf 3 - avanza

      expect(stateMachine.currentStepIndex, 5);
      expect(stepsCompleted.last, 'on_bus180');
      print('✅ Subió al bus 180\n');

      // ═══════════════════════════════════════════════════════
      // PASO 6: En bus 180 hasta parada 4
      // ═══════════════════════════════════════════════════════
      print('🚌 PASO 6: En bus 180...');

      expect(stateMachine.currentStep.id, 'on_bus180');

      simulatedDistance = 2000.0; // 2km a parada 4
      simulatedGeofence = false;

      await orchestrator.updateNow();

      simulatedDistance = 1000.0; // Mitad
      await orchestrator.updateNow();

      simulatedDistance = 25.0; // Llegando
      simulatedGeofence = true;

      await orchestrator.updateNow(); // Conf 1
      await orchestrator.updateNow(); // Conf 2 - avanza

      expect(stateMachine.currentStepIndex, 6);
      expect(stepsCompleted.last, 'walk_to_destination');
      print('✅ Llegó a parada 4 (bajó del bus 180)\n');

      // ═══════════════════════════════════════════════════════
      // PASO 7: Caminar al destino final
      // ═══════════════════════════════════════════════════════
      print('🚶‍♂️ PASO 7: Caminando al destino final...');

      expect(stateMachine.currentStep.id, 'walk_to_destination');

      simulatedDistance = 200.0;
      simulatedGeofence = false;
      simulatedOnBusRoute = false;

      await orchestrator.updateNow();

      simulatedDistance = 100.0;
      await orchestrator.updateNow();
      expect(stateMachine.currentStep.progress, closeTo(0.5, 0.1));

      simulatedDistance = 10.0;
      simulatedGeofence = true;

      await orchestrator.updateNow(); // Conf 1
      await orchestrator.updateNow(); // Conf 2 - completa

      expect(tripCompleted, true);
      expect(stateMachine.isCompleted, true);
      print('✅ LLEGÓ AL DESTINO FINAL!\n');

      // ═══════════════════════════════════════════════════════
      // VERIFICACIÓN FINAL
      // ═══════════════════════════════════════════════════════
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📊 VERIFICACIÓN FINAL');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      expect(stateMachine.steps.length, 7);
      expect(stepsCompleted.length, 6); // 6 cambios de paso

      // Verificar que todos los pasos están completados
      for (final step in stateMachine.steps) {
        expect(step.state, TripStepState.completed, reason: 'Step ${step.id} should be completed');
        expect(step.progress, 1.0, reason: 'Step ${step.id} should have 100% progress');
      }

      // Verificar progreso total
      expect(stateMachine.overallProgress, 1.0);

      // Verificar orden de pasos completados
      expect(stepsCompleted, [
        'wait_bus64',
        'on_bus64',
        'walk_trasbordo',
        'wait_bus180',
        'on_bus180',
        'walk_to_destination',
      ]);

      print('✅ Viaje con trasbordo completado exitosamente');
      print('✅ 7 pasos: Walk → Wait → Bus → Walk → Wait → Bus → Walk');
      print('✅ Todos los pasos al 100%');
      print('✅ Orden de pasos correcto');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      orchestrator.dispose();
    });

    test('Viaje con 3 BUSES (2 trasbordos): Walk → Bus1 → Walk → Bus2 → Walk → Bus3 → Walk', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🚌 TEST: Viaje con 2 Trasbordos (3 buses)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      final steps = [
        // Bus 1
        TripStep(
          id: 'walk1',
          type: TripStepType.walkToStop,
          description: 'Parada 1',
          metadata: const TripStepMetadata(destinationStopId: 'stop1', totalDistanceMeters: 100),
        ),
        TripStep(
          id: 'wait1',
          type: TripStepType.waitForBus,
          description: 'Esperar Bus 64',
          metadata: const TripStepMetadata(originStopId: 'stop1', busLine: '64'),
        ),
        TripStep(
          id: 'bus1',
          type: TripStepType.onBus,
          description: 'Bus 64',
          metadata: const TripStepMetadata(originStopId: 'stop1', destinationStopId: 'stop2', busLine: '64'),
        ),

        // Trasbordo 1
        TripStep(
          id: 'walk2',
          type: TripStepType.walkToStop,
          description: 'Trasbordo 1 a Parada 3',
          metadata: const TripStepMetadata(destinationStopId: 'stop3', totalDistanceMeters: 50),
        ),
        TripStep(
          id: 'wait2',
          type: TripStepType.waitForBus,
          description: 'Esperar Bus 180',
          metadata: const TripStepMetadata(originStopId: 'stop3', busLine: '180'),
        ),
        TripStep(
          id: 'bus2',
          type: TripStepType.onBus,
          description: 'Bus 180',
          metadata: const TripStepMetadata(originStopId: 'stop3', destinationStopId: 'stop4', busLine: '180'),
        ),

        // Trasbordo 2
        TripStep(
          id: 'walk3',
          type: TripStepType.walkToStop,
          description: 'Trasbordo 2 a Parada 5',
          metadata: const TripStepMetadata(destinationStopId: 'stop5', totalDistanceMeters: 75),
        ),
        TripStep(
          id: 'wait3',
          type: TripStepType.waitForBus,
          description: 'Esperar Bus CA1',
          metadata: const TripStepMetadata(originStopId: 'stop5', busLine: 'CA1'),
        ),
        TripStep(
          id: 'bus3',
          type: TripStepType.onBus,
          description: 'Bus CA1',
          metadata: const TripStepMetadata(originStopId: 'stop5', destinationStopId: 'stop6', busLine: 'CA1'),
        ),

        // Final
        TripStep(
          id: 'walk_final',
          type: TripStepType.walkToDestination,
          description: 'Destino',
          metadata: const TripStepMetadata(totalDistanceMeters: 80),
        ),
      ];

      final stateMachine = TripStateMachine(tripId: '3buses', steps: steps);

      var dist = 100.0;
      var geo = false;
      var onRoute = false;
      var speed = 0.0;
      var moving = false;
      final Map<String, double> cache = {};

      Future<StepDetectionContext> mock(TripStep s) async {
        return StepDetectionContext(
          distanceToTarget: dist,
          initialDistanceToTarget: cache.putIfAbsent(s.id, () => s.metadata.totalDistanceMeters ?? dist),
          isWithinGeofence: geo,
          isOnBusRoute: onRoute,
          userSpeed: speed,
          isUserMoving: moving,
          timestamp: DateTime.now(),
        );
      }

      var completed = false;
      final orchestrator = createDefaultOrchestrator(
        stateMachine: stateMachine,
        getContextForStep: mock,
        onTripCompleted: () => completed = true,
      );

      orchestrator.start();

      // Helper para avanzar pasos
      Future<void> completeWalkStep() async {
        dist = 10.0;
        geo = true;
        await orchestrator.updateNow();
        await orchestrator.updateNow();
      }

      Future<void> completeWaitStep() async {
        onRoute = true;
        moving = true;
        speed = 5.0;
        await orchestrator.updateNow();
        await orchestrator.updateNow();
        await orchestrator.updateNow();
      }

      Future<void> completeBusStep() async {
        dist = 20.0;
        geo = true;
        onRoute = true;
        await orchestrator.updateNow();
        await orchestrator.updateNow();
      }

      // BUS 1
      print('🚶‍♂️ Walk 1...');
      await completeWalkStep();
      expect(stateMachine.currentStepIndex, 1);

      print('🚏 Wait 1...');
      await completeWaitStep();
      expect(stateMachine.currentStepIndex, 2);

      print('🚌 Bus 1...');
      await completeBusStep();
      expect(stateMachine.currentStepIndex, 3);

      // TRASBORDO 1
      print('🚶‍♂️ Trasbordo 1...');
      onRoute = false;
      moving = true;
      speed = 1.5;
      await completeWalkStep();
      expect(stateMachine.currentStepIndex, 4);

      print('🚏 Wait 2...');
      await completeWaitStep();
      expect(stateMachine.currentStepIndex, 5);

      print('🚌 Bus 2...');
      await completeBusStep();
      expect(stateMachine.currentStepIndex, 6);

      // TRASBORDO 2
      print('🚶‍♂️ Trasbordo 2...');
      onRoute = false;
      await completeWalkStep();
      expect(stateMachine.currentStepIndex, 7);

      print('🚏 Wait 3...');
      await completeWaitStep();
      expect(stateMachine.currentStepIndex, 8);

      print('🚌 Bus 3...');
      await completeBusStep();
      expect(stateMachine.currentStepIndex, 9);

      // FINAL
      print('🚶‍♂️ Destino final...');
      onRoute = false;
      await completeWalkStep();

      expect(completed, true);
      expect(stateMachine.isCompleted, true);
      expect(stateMachine.steps.length, 10);

      print('✅ Viaje con 3 buses completado exitosamente');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      orchestrator.dispose();
    });
  });
}
