import 'package:flutter_test/flutter_test.dart';
import 'package:bondi_uy/journey/core/trip_state_machine.dart';
import 'package:bondi_uy/journey/core/trip_step.dart';
import 'package:bondi_uy/journey/core/step_detector.dart';
import 'package:bondi_uy/journey/core/trip_orchestrator.dart';

void main() {
  group('Trip Integration Test - Viaje completo simulado', () {
    test('Simular viaje completo: Walk → Wait → Bus → Walk', () async {
      // 1. SETUP: Crear viaje con 4 pasos
      final steps = [
        TripStep(
          id: 'walk1',
          type: TripStepType.walkToStop,
          description: 'Caminar a parada 1',
          metadata: const TripStepMetadata(
            destinationStopId: 'stop1',
            totalDistanceMeters: 500,
          ),
        ),
        TripStep(
          id: 'wait1',
          type: TripStepType.waitForBus,
          description: 'Esperar bus línea 64',
          metadata: const TripStepMetadata(
            originStopId: 'stop1',
            busLine: '64',
            hasEta: true,
          ),
        ),
        TripStep(
          id: 'bus1',
          type: TripStepType.onBus,
          description: 'En bus hasta parada 2',
          metadata: const TripStepMetadata(
            originStopId: 'stop1',
            destinationStopId: 'stop2',
            busLine: '64',
          ),
        ),
        TripStep(
          id: 'walk2',
          type: TripStepType.walkToDestination,
          description: 'Caminar a destino',
          metadata: const TripStepMetadata(
            totalDistanceMeters: 200,
          ),
        ),
      ];

      final stateMachine = TripStateMachine(
        tripId: 'test_trip_001',
        steps: steps,
      );

      // 2. SETUP: Mock del GeometryAdapter
      // Simulamos diferentes ubicaciones del usuario
      var simulatedDistanceToTarget = 500.0;
      var simulatedIsWithinGeofence = false;
      var simulatedIsOnBusRoute = false;
      var simulatedUserSpeed = 0.0;
      var simulatedIsUserMoving = false;

      // Cache de distancias iniciales por paso (simula GeometryAdapter)
      final Map<String, double> initialDistances = {};

      Future<StepDetectionContext> mockGeometryAdapter(TripStep step) async {
        // Obtener o calcular distancia inicial (primera vez que se ve este paso)
        final initialDistance = initialDistances.putIfAbsent(
          step.id,
          () => step.metadata.totalDistanceMeters ?? simulatedDistanceToTarget,
        );

        return StepDetectionContext(
          distanceToTarget: simulatedDistanceToTarget,
          initialDistanceToTarget: initialDistance,
          isWithinGeofence: simulatedIsWithinGeofence,
          isOnBusRoute: simulatedIsOnBusRoute,
          userSpeed: simulatedUserSpeed,
          isUserMoving: simulatedIsUserMoving,
          timestamp: DateTime.now(),
        );
      }

      // 3. SETUP: Callbacks para verificar eventos
      var tripCompletedCalled = false;
      var stepsChanged = 0;

      final orchestrator = createDefaultOrchestrator(
        stateMachine: stateMachine,
        getContextForStep: mockGeometryAdapter,
        onTripCompleted: () {
          tripCompletedCalled = true;
        },
        onStepChanged: (newStep) {
          stepsChanged++;
        },
      );

      // 4. INICIO DEL VIAJE
      orchestrator.start(updateInterval: const Duration(milliseconds: 100));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(stateMachine.status, TripStatus.inProgress);
      expect(stateMachine.currentStepIndex, 0);
      expect(stateMachine.currentStep.type, TripStepType.walkToStop);

      // 5. PASO 1: CAMINAR A LA PARADA (walk_to_stop)
      print('\n🚶‍♂️ FASE 1: Caminando a la parada...');

      // Usuario a 500m de la parada
      simulatedDistanceToTarget = 500.0;
      await orchestrator.updateNow();
      expect(stateMachine.currentStep.progress, closeTo(0.0, 0.1));

      // Usuario a 250m de la parada (50% progreso)
      simulatedDistanceToTarget = 250.0;
      await orchestrator.updateNow();
      expect(stateMachine.currentStep.progress, closeTo(0.5, 0.1));

      // Usuario a 100m de la parada
      simulatedDistanceToTarget = 100.0;
      await orchestrator.updateNow();
      expect(stateMachine.currentStep.progress, closeTo(0.8, 0.1));

      // Usuario llega a la parada (dentro del geofence)
      simulatedDistanceToTarget = 10.0;
      simulatedIsWithinGeofence = true;

      // Primera confirmación
      await orchestrator.updateNow();
      expect(stateMachine.currentStepIndex, 0); // Aún en el mismo paso

      // Segunda confirmación - debe avanzar
      await orchestrator.updateNow();
      expect(stateMachine.currentStepIndex, 1); // Avanzó al paso 2
      expect(stepsChanged, 1);

      // 6. PASO 2: ESPERAR EL BUS (wait_for_bus)
      print('\n🚏 FASE 2: Esperando el bus...');

      expect(stateMachine.currentStep.type, TripStepType.waitForBus);

      // Resetear estado - usuario en la parada esperando
      simulatedDistanceToTarget = 5.0;
      simulatedIsWithinGeofence = true;
      simulatedIsOnBusRoute = false;
      simulatedUserSpeed = 0.0;
      simulatedIsUserMoving = false;

      await orchestrator.updateNow();
      expect(stateMachine.currentStepIndex, 1); // No avanza todavía

      // Usuario se sube al bus y comienza a moverse
      simulatedIsOnBusRoute = true;
      simulatedIsUserMoving = true;
      simulatedUserSpeed = 5.0; // ~18 km/h

      // Confirmaciones para boarding
      await orchestrator.updateNow(); // Confirmación 1
      expect(stateMachine.currentStepIndex, 1);

      await orchestrator.updateNow(); // Confirmación 2
      expect(stateMachine.currentStepIndex, 1);

      await orchestrator.updateNow(); // Confirmación 3 - avanza
      expect(stateMachine.currentStepIndex, 2); // Avanzó al paso 3
      expect(stepsChanged, 2);

      // 7. PASO 3: EN EL BUS (on_bus)
      print('\n🚌 FASE 3: En el bus...');

      expect(stateMachine.currentStep.type, TripStepType.onBus);

      // Resetear para simular viaje en bus
      simulatedDistanceToTarget = 1000.0; // 1km a la parada destino
      simulatedIsWithinGeofence = false;
      simulatedIsOnBusRoute = true;
      simulatedUserSpeed = 8.0; // Bus moviéndose

      await orchestrator.updateNow();
      expect(stateMachine.currentStep.progress, closeTo(0.0, 0.1));

      // Bus a mitad de camino
      simulatedDistanceToTarget = 500.0;
      await orchestrator.updateNow();
      expect(stateMachine.currentStep.progress, closeTo(0.5, 0.1));

      // Bus llegando a la parada destino
      simulatedDistanceToTarget = 100.0;
      await orchestrator.updateNow();

      // Bus en la parada destino
      simulatedDistanceToTarget = 15.0;
      simulatedIsWithinGeofence = true;

      // Primera confirmación
      await orchestrator.updateNow();
      expect(stateMachine.currentStepIndex, 2); // Aún en el bus

      // Segunda confirmación - debe avanzar
      await orchestrator.updateNow();
      expect(stateMachine.currentStepIndex, 3); // Avanzó al paso 4
      expect(stepsChanged, 3);

      // 8. PASO 4: CAMINAR AL DESTINO (walk_to_destination)
      print('\n🚶‍♂️ FASE 4: Caminando al destino...');

      expect(stateMachine.currentStep.type, TripStepType.walkToDestination);

      // Resetear para caminata final
      simulatedDistanceToTarget = 200.0;
      simulatedIsWithinGeofence = false;
      simulatedIsOnBusRoute = false;
      simulatedUserSpeed = 1.5;
      simulatedIsUserMoving = true;

      await orchestrator.updateNow();
      expect(stateMachine.currentStep.progress, closeTo(0.0, 0.1));

      // Usuario a mitad de camino
      simulatedDistanceToTarget = 100.0;
      await orchestrator.updateNow();
      expect(stateMachine.currentStep.progress, closeTo(0.5, 0.1));

      // Usuario llega al destino
      simulatedDistanceToTarget = 10.0;
      simulatedIsWithinGeofence = true;

      // Primera confirmación
      await orchestrator.updateNow();
      expect(stateMachine.status, TripStatus.inProgress);

      // Segunda confirmación - viaje completo
      await orchestrator.updateNow();
      expect(stateMachine.status, TripStatus.completed);
      expect(tripCompletedCalled, true);
      expect(stepsChanged, 3);

      // 9. VERIFICAR ESTADO FINAL
      print('\n✅ VIAJE COMPLETADO');

      expect(stateMachine.isCompleted, true);
      expect(stateMachine.overallProgress, 1.0);

      for (final step in stateMachine.steps) {
        expect(step.state, TripStepState.completed);
        expect(step.progress, 1.0);
      }

      orchestrator.dispose();
    });

    test('Simular viaje simple: Solo caminata directa', () async {
      // Viaje con un solo paso: caminar al destino
      final steps = [
        TripStep(
          id: 'walk_direct',
          type: TripStepType.walkToDestination,
          description: 'Caminar directo al destino',
          metadata: const TripStepMetadata(
            totalDistanceMeters: 300,
          ),
        ),
      ];

      final stateMachine = TripStateMachine(
        tripId: 'simple_trip',
        steps: steps,
      );

      var simulatedDistance = 300.0;
      var simulatedGeofence = false;

      Future<StepDetectionContext> mockAdapter(TripStep step) async {
        return StepDetectionContext(
          distanceToTarget: simulatedDistance,
          initialDistanceToTarget: 300.0,
          isWithinGeofence: simulatedGeofence,
          timestamp: DateTime.now(),
        );
      }

      var completed = false;

      final orchestrator = createDefaultOrchestrator(
        stateMachine: stateMachine,
        getContextForStep: mockAdapter,
        onTripCompleted: () {
          completed = true;
        },
      );

      orchestrator.start();

      // Simular caminata
      simulatedDistance = 150.0;
      await orchestrator.updateNow();
      expect(stateMachine.currentStep.progress, closeTo(0.5, 0.1));

      simulatedDistance = 5.0;
      simulatedGeofence = true;

      await orchestrator.updateNow(); // Confirmación 1
      await orchestrator.updateNow(); // Confirmación 2 - completa

      expect(completed, true);
      expect(stateMachine.isCompleted, true);

      orchestrator.dispose();
    });
  });
}
