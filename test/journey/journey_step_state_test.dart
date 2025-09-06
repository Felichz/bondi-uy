import 'package:flutter_test/flutter_test.dart';
import 'package:bondi_uy/journey/journey_step_state.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';

void main() {
  group('JourneyStepType', () {
    test('should have all required step types', () {
      expect(JourneyStepType.values.length, equals(4));
      expect(JourneyStepType.values, contains(JourneyStepType.WALKING_TO_STOP));
      expect(JourneyStepType.values, contains(JourneyStepType.WAITING_FOR_BUS));
      expect(JourneyStepType.values, contains(JourneyStepType.RIDING_BUS));
      expect(JourneyStepType.values, contains(JourneyStepType.WALKING_TO_DESTINATION));
    });
  });

  group('JourneyStepState', () {
    late Coordenada testDestination;
    late DateTime testStartTime;

    setUp(() {
      testDestination = Coordenada(latitud: -34.906, longitud: -56.186);
      testStartTime = DateTime(2024, 1, 15, 10, 30);
    });

    group('Constructor and Basic Properties', () {
      test('should create minimal journey step state', () {
        final step = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
        );

        expect(step.stepIndex, equals(0));
        expect(step.type, equals(JourneyStepType.WALKING_TO_STOP));
        expect(step.destination, isNull);
        expect(step.busLine, isNull);
        expect(step.remainingDistance, isNull);
        expect(step.remainingTimeSeconds, isNull);
        expect(step.progressPercentage, isNull);
        expect(step.instructions, isNull);
        expect(step.startTime, isNull);
        expect(step.currentRoute, isNull);
      });

      test('should create complete journey step state', () {
        final route = [
          Coordenada(latitud: -34.905, longitud: -56.185),
          testDestination,
        ];

        final step = JourneyStepState(
          stepIndex: 1,
          type: JourneyStepType.WAITING_FOR_BUS,
          destination: testDestination,
          busLine: '123',
          remainingDistance: 150.5,
          remainingTimeSeconds: 120,
          progressPercentage: 75.2,
          instructions: 'Espera el bus línea 123',
          startTime: testStartTime,
          currentRoute: route,
        );

        expect(step.stepIndex, equals(1));
        expect(step.type, equals(JourneyStepType.WAITING_FOR_BUS));
        expect(step.destination, equals(testDestination));
        expect(step.busLine, equals('123'));
        expect(step.remainingDistance, equals(150.5));
        expect(step.remainingTimeSeconds, equals(120));
        expect(step.progressPercentage, equals(75.2));
        expect(step.instructions, equals('Espera el bus línea 123'));
        expect(step.startTime, equals(testStartTime));
        expect(step.currentRoute, equals(route));
      });
    });

    group('copyWith', () {
      test('should create copy with updated values', () {
        final original = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
          remainingDistance: 200.0,
          progressPercentage: 50.0,
        );

        final updated = original.copyWith(
          remainingDistance: 100.0,
          progressPercentage: 75.0,
          remainingTimeSeconds: 60,
        );

        expect(updated.stepIndex, equals(0)); // Unchanged
        expect(updated.type, equals(JourneyStepType.WALKING_TO_STOP)); // Unchanged
        expect(updated.remainingDistance, equals(100.0)); // Changed
        expect(updated.progressPercentage, equals(75.0)); // Changed
        expect(updated.remainingTimeSeconds, equals(60)); // Changed
      });

      test('should preserve original values when not specified', () {
        final original = JourneyStepState(
          stepIndex: 2,
          type: JourneyStepType.RIDING_BUS,
          destination: testDestination,
          busLine: '456',
          instructions: 'Original instructions',
        );

        final updated = original.copyWith(
          remainingDistance: 50.0,
        );

        expect(updated.stepIndex, equals(2));
        expect(updated.type, equals(JourneyStepType.RIDING_BUS));
        expect(updated.destination, equals(testDestination));
        expect(updated.busLine, equals('456'));
        expect(updated.instructions, equals('Original instructions'));
        expect(updated.remainingDistance, equals(50.0));
      });
    });

    group('Display Names', () {
      test('should return correct display names for each step type', () {
        final walkingToStop = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
        );
        expect(walkingToStop.typeDisplayName, equals('Camina hacia la parada'));

        final waitingForBus = JourneyStepState(
          stepIndex: 1,
          type: JourneyStepType.WAITING_FOR_BUS,
        );
        expect(waitingForBus.typeDisplayName, equals('Espera el bus'));

        final ridingBus = JourneyStepState(
          stepIndex: 2,
          type: JourneyStepType.RIDING_BUS,
        );
        expect(ridingBus.typeDisplayName, equals('En el bus'));

        final walkingToDestination = JourneyStepState(
          stepIndex: 3,
          type: JourneyStepType.WALKING_TO_DESTINATION,
        );
        expect(walkingToDestination.typeDisplayName, equals('Camina al destino'));
      });
    });

    group('Time Formatting', () {
      test('should format remaining time correctly', () {
        final stepWithMinutes = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
          remainingTimeSeconds: 125, // 2 minutes 5 seconds
        );
        expect(stepWithMinutes.formattedRemainingTime, equals('2m 5s'));

        final stepWithSeconds = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
          remainingTimeSeconds: 45, // 45 seconds
        );
        expect(stepWithSeconds.formattedRemainingTime, equals('45s'));

        final stepExactMinutes = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
          remainingTimeSeconds: 180, // 3 minutes exactly
        );
        expect(stepExactMinutes.formattedRemainingTime, equals('3m 0s'));
      });

      test('should return null for null remaining time', () {
        final step = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
        );
        expect(step.formattedRemainingTime, isNull);
      });
    });

    group('Distance Formatting', () {
      test('should format distances correctly', () {
        final stepMeters = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
          remainingDistance: 250.7,
        );
        expect(stepMeters.formattedRemainingDistance, equals('251 m'));

        final stepKilometers = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
          remainingDistance: 1500.0,
        );
        expect(stepKilometers.formattedRemainingDistance, equals('1.5 km'));

        final stepExactKm = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
          remainingDistance: 2000.0,
        );
        expect(stepExactKm.formattedRemainingDistance, equals('2.0 km'));
      });

      test('should return null for null remaining distance', () {
        final step = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
        );
        expect(step.formattedRemainingDistance, isNull);
      });
    });

    group('Progress Status', () {
      test('should correctly identify completed steps', () {
        final completed = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
          progressPercentage: 100.0,
        );
        expect(completed.isCompleted, isTrue);
        expect(completed.isInProgress, isFalse);

        final overCompleted = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
          progressPercentage: 105.0,
        );
        expect(overCompleted.isCompleted, isTrue);
      });

      test('should correctly identify in-progress steps', () {
        final inProgress = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
          progressPercentage: 50.0,
        );
        expect(inProgress.isInProgress, isTrue);
        expect(inProgress.isCompleted, isFalse);

        final justStarted = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
          progressPercentage: 0.1,
        );
        expect(justStarted.isInProgress, isTrue);
      });

      test('should handle null progress percentage', () {
        final step = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
        );
        expect(step.isCompleted, isFalse);
        expect(step.isInProgress, isFalse);
      });

      test('should handle zero progress', () {
        final step = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
          progressPercentage: 0.0,
        );
        expect(step.isCompleted, isFalse);
        expect(step.isInProgress, isFalse);
      });
    });

    group('toString', () {
      test('should provide comprehensive string representation', () {
        final step = JourneyStepState(
          stepIndex: 1,
          type: JourneyStepType.WAITING_FOR_BUS,
          destination: testDestination,
          busLine: '123',
          remainingDistance: 150.5,
          remainingTimeSeconds: 120,
          progressPercentage: 75.2,
        );

        final string = step.toString();
        expect(string, contains('stepIndex: 1'));
        expect(string, contains('type: JourneyStepType.WAITING_FOR_BUS'));
        expect(string, contains('busLine: 123'));
        expect(string, contains('remainingDistance: 150.5'));
        expect(string, contains('remainingTimeSeconds: 120'));
        expect(string, contains('progressPercentage: 75.2'));
      });
    });

    group('Equality', () {
      test('should be equal when all properties match', () {
        final step1 = JourneyStepState(
          stepIndex: 1,
          type: JourneyStepType.WAITING_FOR_BUS,
          destination: testDestination,
          busLine: '123',
          remainingDistance: 150.5,
          remainingTimeSeconds: 120,
          progressPercentage: 75.2,
        );

        final step2 = JourneyStepState(
          stepIndex: 1,
          type: JourneyStepType.WAITING_FOR_BUS,
          destination: testDestination,
          busLine: '123',
          remainingDistance: 150.5,
          remainingTimeSeconds: 120,
          progressPercentage: 75.2,
        );

        expect(step1, equals(step2));
        expect(step1.hashCode, equals(step2.hashCode));
      });

      test('should not be equal when properties differ', () {
        final step1 = JourneyStepState(
          stepIndex: 1,
          type: JourneyStepType.WAITING_FOR_BUS,
          remainingDistance: 150.5,
        );

        final step2 = JourneyStepState(
          stepIndex: 1,
          type: JourneyStepType.WAITING_FOR_BUS,
          remainingDistance: 200.0, // Different
        );

        expect(step1, isNot(equals(step2)));
      });

      test('should handle identical references', () {
        final step = JourneyStepState(
          stepIndex: 0,
          type: JourneyStepType.WALKING_TO_STOP,
        );

        expect(step, equals(step));
      });
    });
  });
}