import 'package:flutter_test/flutter_test.dart';
import 'package:bondi_uy/journey/core/step_detector.dart';
import 'package:bondi_uy/journey/core/trip_step.dart';

void main() {
  group('WalkStepDetector', () {
    late WalkStepDetector detector;
    late TripStep walkStep;

    setUp(() {
      detector = WalkStepDetector(
        arrivalThresholdMeters: 20.0,
        consecutiveConfirmationsRequired: 2,
      );

      walkStep = TripStep(
        id: 'walk1',
        type: TripStepType.walkToStop,
        description: 'Caminar a parada',
        metadata: const TripStepMetadata(
          destinationStopId: 'stop1',
          totalDistanceMeters: 500,
        ),
      );
    });

    test('debe calcular progreso correctamente basado en distancia', () {
      final context = StepDetectionContext(
        distanceToTarget: 250.0,
        initialDistanceToTarget: 500.0,
        timestamp: DateTime.now(),
      );

      final progress = detector.calculateProgress(walkStep, context);

      expect(progress, 0.5); // 250/500 = 50%
    });

    test('debe retornar false si el usuario no llegó', () {
      final context = StepDetectionContext(
        distanceToTarget: 100.0, // Más de 20m
        initialDistanceToTarget: 500.0,
        isWithinGeofence: false,
        timestamp: DateTime.now(),
      );

      final shouldAdvance = detector.shouldAdvanceToNextStep(walkStep, context);

      expect(shouldAdvance, false);
    });

    test('debe requerir confirmaciones consecutivas', () {
      final context = StepDetectionContext(
        distanceToTarget: 10.0, // Dentro del threshold
        initialDistanceToTarget: 500.0,
        isWithinGeofence: true,
        timestamp: DateTime.now(),
      );

      // Primera confirmación
      var shouldAdvance = detector.shouldAdvanceToNextStep(walkStep, context);
      expect(shouldAdvance, false);

      // Segunda confirmación - debe avanzar
      shouldAdvance = detector.shouldAdvanceToNextStep(walkStep, context);
      expect(shouldAdvance, true);
    });

    test('debe resetear confirmaciones si el usuario se aleja', () {
      final closeContext = StepDetectionContext(
        distanceToTarget: 10.0,
        initialDistanceToTarget: 500.0,
        isWithinGeofence: true,
        timestamp: DateTime.now(),
      );

      final farContext = StepDetectionContext(
        distanceToTarget: 100.0,
        initialDistanceToTarget: 500.0,
        isWithinGeofence: false,
        timestamp: DateTime.now(),
      );

      // Primera confirmación
      detector.shouldAdvanceToNextStep(walkStep, closeContext);

      // Usuario se aleja - reset
      detector.shouldAdvanceToNextStep(walkStep, farContext);

      // Volver a acercarse - debería necesitar 2 confirmaciones nuevamente
      var shouldAdvance = detector.shouldAdvanceToNextStep(walkStep, closeContext);
      expect(shouldAdvance, false);

      shouldAdvance = detector.shouldAdvanceToNextStep(walkStep, closeContext);
      expect(shouldAdvance, true);
    });
  });

  group('WaitForBusDetector', () {
    late WaitForBusDetector detector;
    late TripStep waitStep;

    setUp(() {
      detector = WaitForBusDetector(
        minimumBusSpeedMps: 2.0,
        consecutiveConfirmationsRequired: 3,
      );

      waitStep = TripStep(
        id: 'wait1',
        type: TripStepType.waitForBus,
        description: 'Esperar bus',
        metadata: const TripStepMetadata(
          originStopId: 'stop1',
          busLine: '64',
          hasEta: true,
        ),
      );
    });

    test('debe retornar false si el usuario no se subió al bus', () {
      final context = StepDetectionContext(
        distanceToTarget: 10.0,
        initialDistanceToTarget: 500.0,
        isUserMoving: false, // No se está moviendo
        isOnBusRoute: false,
        userSpeed: 0.0,
        timestamp: DateTime.now(),
      );

      final shouldAdvance = detector.shouldAdvanceToNextStep(waitStep, context);

      expect(shouldAdvance, false);
    });

    test('debe detectar cuando el usuario se sube al bus', () {
      final onBusContext = StepDetectionContext(
        distanceToTarget: 100.0,
        initialDistanceToTarget: 500.0,
        isUserMoving: true,
        isOnBusRoute: true,
        userSpeed: 5.0, // Velocidad de bus
        timestamp: DateTime.now(),
      );

      // Requerir 3 confirmaciones consecutivas
      var shouldAdvance = detector.shouldAdvanceToNextStep(waitStep, onBusContext);
      expect(shouldAdvance, false);

      shouldAdvance = detector.shouldAdvanceToNextStep(waitStep, onBusContext);
      expect(shouldAdvance, false);

      shouldAdvance = detector.shouldAdvanceToNextStep(waitStep, onBusContext);
      expect(shouldAdvance, true); // Tercera confirmación
    });

    test('debe resetear confirmaciones si el usuario se detiene', () {
      final movingContext = StepDetectionContext(
        distanceToTarget: 100.0,
        initialDistanceToTarget: 500.0,
        isUserMoving: true,
        isOnBusRoute: true,
        userSpeed: 5.0,
        timestamp: DateTime.now(),
      );

      final stoppedContext = StepDetectionContext(
        distanceToTarget: 100.0,
        initialDistanceToTarget: 500.0,
        isUserMoving: false,
        isOnBusRoute: false,
        userSpeed: 0.0,
        timestamp: DateTime.now(),
      );

      // 2 confirmaciones
      detector.shouldAdvanceToNextStep(waitStep, movingContext);
      detector.shouldAdvanceToNextStep(waitStep, movingContext);

      // Se detiene - reset
      detector.shouldAdvanceToNextStep(waitStep, stoppedContext);

      // Necesita 3 confirmaciones nuevamente
      var shouldAdvance = detector.shouldAdvanceToNextStep(waitStep, movingContext);
      expect(shouldAdvance, false);

      shouldAdvance = detector.shouldAdvanceToNextStep(waitStep, movingContext);
      expect(shouldAdvance, false);

      shouldAdvance = detector.shouldAdvanceToNextStep(waitStep, movingContext);
      expect(shouldAdvance, true);
    });

    test('calculateProgress debe retornar 0 mientras espera', () {
      final context = StepDetectionContext(
        distanceToTarget: 100.0,
        initialDistanceToTarget: 500.0,
        timestamp: DateTime.now(),
      );

      final progress = detector.calculateProgress(waitStep, context);

      expect(progress, 0.0); // Progreso indeterminado
    });
  });

  group('OnBusDetector', () {
    late OnBusDetector detector;
    late TripStep onBusStep;

    setUp(() {
      detector = OnBusDetector(
        arrivalThresholdMeters: 30.0,
        consecutiveConfirmationsRequired: 2,
      );

      onBusStep = TripStep(
        id: 'bus1',
        type: TripStepType.onBus,
        description: 'En bus',
        metadata: const TripStepMetadata(
          originStopId: 'stop1',
          destinationStopId: 'stop2',
          busLine: '64',
        ),
      );
    });

    test('debe calcular progreso basado en distancia', () {
      final context = StepDetectionContext(
        distanceToTarget: 500.0,
        initialDistanceToTarget: 1000.0,
        timestamp: DateTime.now(),
      );

      final progress = detector.calculateProgress(onBusStep, context);

      expect(progress, 0.5); // 500/1000 = 50%
    });

    test('debe detectar llegada a la parada destino', () {
      final arrivedContext = StepDetectionContext(
        distanceToTarget: 15.0, // Dentro del threshold
        initialDistanceToTarget: 1000.0,
        isWithinGeofence: true,
        timestamp: DateTime.now(),
      );

      // Primera confirmación
      var shouldAdvance = detector.shouldAdvanceToNextStep(onBusStep, arrivedContext);
      expect(shouldAdvance, false);

      // Segunda confirmación - debe avanzar
      shouldAdvance = detector.shouldAdvanceToNextStep(onBusStep, arrivedContext);
      expect(shouldAdvance, true);
    });

    test('debe resetear confirmaciones si no está en geofence', () {
      final insideContext = StepDetectionContext(
        distanceToTarget: 15.0,
        initialDistanceToTarget: 1000.0,
        isWithinGeofence: true,
        timestamp: DateTime.now(),
      );

      final outsideContext = StepDetectionContext(
        distanceToTarget: 100.0,
        initialDistanceToTarget: 1000.0,
        isWithinGeofence: false,
        timestamp: DateTime.now(),
      );

      // Una confirmación
      detector.shouldAdvanceToNextStep(onBusStep, insideContext);

      // Sale del geofence - reset
      detector.shouldAdvanceToNextStep(onBusStep, outsideContext);

      // Necesita 2 confirmaciones nuevamente
      var shouldAdvance = detector.shouldAdvanceToNextStep(onBusStep, insideContext);
      expect(shouldAdvance, false);

      shouldAdvance = detector.shouldAdvanceToNextStep(onBusStep, insideContext);
      expect(shouldAdvance, true);
    });
  });

  group('StepDetectionContext', () {
    test('distanceProgress debe calcular correctamente', () {
      final context = StepDetectionContext(
        distanceToTarget: 250.0,
        initialDistanceToTarget: 500.0,
        timestamp: DateTime.now(),
      );

      expect(context.distanceProgress, 0.5);
    });

    test('distanceProgress debe retornar 1.0 si distancia inicial es 0', () {
      final context = StepDetectionContext(
        distanceToTarget: 0.0,
        initialDistanceToTarget: 0.0,
        timestamp: DateTime.now(),
      );

      expect(context.distanceProgress, 1.0);
    });

    test('distanceProgress debe clampear a [0.0, 1.0]', () {
      final context1 = StepDetectionContext(
        distanceToTarget: -50.0, // Negativo
        initialDistanceToTarget: 500.0,
        timestamp: DateTime.now(),
      );

      expect(context1.distanceProgress, greaterThanOrEqualTo(0.0));
      expect(context1.distanceProgress, lessThanOrEqualTo(1.0));

      final context2 = StepDetectionContext(
        distanceToTarget: 600.0, // Mayor que inicial
        initialDistanceToTarget: 500.0,
        timestamp: DateTime.now(),
      );

      expect(context2.distanceProgress, greaterThanOrEqualTo(0.0));
      expect(context2.distanceProgress, lessThanOrEqualTo(1.0));
    });
  });
}
