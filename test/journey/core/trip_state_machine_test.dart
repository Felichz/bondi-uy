import 'package:flutter_test/flutter_test.dart';
import 'package:bondi_uy/journey/core/trip_state_machine.dart';
import 'package:bondi_uy/journey/core/trip_step.dart';

void main() {
  group('TripStateMachine', () {
    late List<TripStep> sampleSteps;

    setUp(() {
      sampleSteps = [
        TripStep(
          id: 'step1',
          type: TripStepType.walkToStop,
          description: 'Caminar a parada 1',
          metadata: const TripStepMetadata(
            destinationStopId: 'stop1',
            totalDistanceMeters: 500,
          ),
        ),
        TripStep(
          id: 'step2',
          type: TripStepType.waitForBus,
          description: 'Esperar bus línea 64',
          metadata: const TripStepMetadata(
            originStopId: 'stop1',
            busLine: '64',
            hasEta: true,
          ),
        ),
        TripStep(
          id: 'step3',
          type: TripStepType.onBus,
          description: 'En bus hasta parada 2',
          metadata: const TripStepMetadata(
            originStopId: 'stop1',
            destinationStopId: 'stop2',
            busLine: '64',
          ),
        ),
        TripStep(
          id: 'step4',
          type: TripStepType.walkToDestination,
          description: 'Caminar a destino',
          metadata: const TripStepMetadata(
            totalDistanceMeters: 200,
          ),
        ),
      ];
    });

    test('debe inicializar correctamente', () {
      final machine = TripStateMachine(
        tripId: 'trip123',
        steps: sampleSteps,
      );

      expect(machine.tripId, 'trip123');
      expect(machine.steps.length, 4);
      expect(machine.currentStepIndex, 0);
      expect(machine.status, TripStatus.notStarted);
      expect(machine.isCompleted, false);
      expect(machine.hasNextStep, true);
    });

    test('debe fallar si no hay pasos', () {
      expect(
        () => TripStateMachine(tripId: 'trip123', steps: []),
        throwsArgumentError,
      );
    });

    test('start() debe activar el primer paso', () {
      final machine = TripStateMachine(
        tripId: 'trip123',
        steps: sampleSteps,
      );

      machine.start();

      expect(machine.status, TripStatus.inProgress);
      expect(machine.currentStep.state, TripStepState.inProgress);
    });

    test('updateCurrentStepProgress() debe actualizar el progreso', () {
      final machine = TripStateMachine(
        tripId: 'trip123',
        steps: sampleSteps,
      );
      machine.start();

      machine.updateCurrentStepProgress(0.5);
      expect(machine.currentStep.progress, 0.5);

      machine.updateCurrentStepProgress(0.75);
      expect(machine.currentStep.progress, 0.75);
    });

    test('updateCurrentStepProgress() debe clampear valores fuera de rango', () {
      final machine = TripStateMachine(
        tripId: 'trip123',
        steps: sampleSteps,
      );
      machine.start();

      machine.updateCurrentStepProgress(1.5);
      expect(machine.currentStep.progress, 1.0);

      machine.updateCurrentStepProgress(-0.5);
      expect(machine.currentStep.progress, 0.0);
    });

    test('advanceToNextStep() debe avanzar correctamente', () {
      final machine = TripStateMachine(
        tripId: 'trip123',
        steps: sampleSteps,
      );
      machine.start();

      expect(machine.currentStepIndex, 0);

      final advanced = machine.advanceToNextStep();

      expect(advanced, true);
      expect(machine.currentStepIndex, 1);
      expect(machine.steps[0].state, TripStepState.completed);
      expect(machine.steps[0].progress, 1.0);
      expect(machine.steps[1].state, TripStepState.inProgress);
    });

    test('advanceToNextStep() debe completar el viaje al final', () {
      final machine = TripStateMachine(
        tripId: 'trip123',
        steps: sampleSteps,
      );
      machine.start();

      // Avanzar hasta el último paso
      machine.advanceToNextStep(); // step 1
      machine.advanceToNextStep(); // step 2
      machine.advanceToNextStep(); // step 3

      expect(machine.currentStepIndex, 3);
      expect(machine.status, TripStatus.inProgress);

      // Avanzar desde el último paso debe completar el viaje
      final advanced = machine.advanceToNextStep();

      expect(advanced, false);
      expect(machine.status, TripStatus.completed);
      expect(machine.isCompleted, true);
      expect(machine.steps[3].state, TripStepState.completed);
    });

    test('overallProgress debe calcular correctamente', () {
      final machine = TripStateMachine(
        tripId: 'trip123',
        steps: sampleSteps,
      );
      machine.start();

      // Al inicio: paso 0, progreso 0%
      expect(machine.overallProgress, 0.0);

      // Paso 0 al 50%
      machine.updateCurrentStepProgress(0.5);
      expect(machine.overallProgress, closeTo(0.125, 0.01)); // 0.5 / 4 = 0.125

      // Avanzar al paso 1
      machine.advanceToNextStep();
      expect(machine.overallProgress, 0.25); // 1 / 4 = 0.25

      // Paso 1 al 50%
      machine.updateCurrentStepProgress(0.5);
      expect(machine.overallProgress, closeTo(0.375, 0.01)); // (1 + 0.5) / 4 = 0.375

      // Avanzar al paso 2
      machine.advanceToNextStep();
      expect(machine.overallProgress, 0.5); // 2 / 4 = 0.5

      // Completar todos los pasos
      machine.advanceToNextStep(); // paso 3
      machine.advanceToNextStep(); // completar
      expect(machine.overallProgress, 1.0);
    });

    test('cancel() debe cancelar el viaje', () {
      final machine = TripStateMachine(
        tripId: 'trip123',
        steps: sampleSteps,
      );
      machine.start();

      machine.cancel();

      expect(machine.status, TripStatus.cancelled);
    });

    test('no se puede avanzar si el viaje está completado', () {
      final machine = TripStateMachine(
        tripId: 'trip123',
        steps: sampleSteps,
      );
      machine.start();

      // Completar el viaje
      machine.advanceToNextStep();
      machine.advanceToNextStep();
      machine.advanceToNextStep();
      machine.advanceToNextStep();

      expect(machine.isCompleted, true);

      // Intentar avanzar nuevamente
      final advanced = machine.advanceToNextStep();

      expect(advanced, false);
      expect(machine.currentStepIndex, 3); // No cambió
    });

    test('hasNextStep debe retornar correctamente', () {
      final machine = TripStateMachine(
        tripId: 'trip123',
        steps: sampleSteps,
      );
      machine.start();

      expect(machine.hasNextStep, true);

      machine.advanceToNextStep();
      expect(machine.hasNextStep, true);

      machine.advanceToNextStep();
      expect(machine.hasNextStep, true);

      machine.advanceToNextStep();
      expect(machine.hasNextStep, false); // Último paso
    });
  });
}
