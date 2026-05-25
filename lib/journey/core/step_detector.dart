import 'trip_step.dart';

/// Interfaz abstracta para detectar si un paso debe avanzar
///
/// Esta es la clave de la arquitectura: el detector NO conoce coordenadas.
/// Recibe un "contexto" genérico que contiene la información necesaria,
/// y retorna decisiones simples (bool, double).
abstract class StepDetector {
  /// Verifica si el paso debe avanzar al siguiente
  ///
  /// [currentStep] - El paso actual del viaje
  /// [context] - Contexto con información calculada (sin coordenadas directas)
  ///
  /// Retorna true si se debe avanzar al siguiente paso
  bool shouldAdvanceToNextStep(
    TripStep currentStep,
    StepDetectionContext context,
  );

  /// Calcula el progreso del paso actual
  ///
  /// [currentStep] - El paso actual del viaje
  /// [context] - Contexto con información calculada
  ///
  /// Retorna un valor entre 0.0 y 1.0 representando el progreso
  double calculateProgress(
    TripStep currentStep,
    StepDetectionContext context,
  );
}

/// Contexto para detección de pasos
///
/// Esta estructura contiene información procesada y simplificada,
/// NO coordenadas GPS directas. Es la salida del GeometryAdapter.
class StepDetectionContext {
  /// Distancia actual al objetivo en metros
  final double distanceToTarget;

  /// Distancia inicial al objetivo (para calcular progreso)
  final double initialDistanceToTarget;

  /// ¿El usuario está en movimiento?
  final bool isUserMoving;

  /// ¿El usuario está dentro de un geofence?
  final bool isWithinGeofence;

  /// ¿El usuario está en la ruta del bus?
  final bool isOnBusRoute;

  /// Velocidad del usuario en m/s
  final double userSpeed;

  /// Timestamp del último update
  final DateTime timestamp;

  /// Datos adicionales específicos del paso
  final Map<String, dynamic> extras;

  const StepDetectionContext({
    required this.distanceToTarget,
    required this.initialDistanceToTarget,
    this.isUserMoving = false,
    this.isWithinGeofence = false,
    this.isOnBusRoute = false,
    this.userSpeed = 0.0,
    required this.timestamp,
    this.extras = const {},
  });

  /// Calcula el progreso basado en distancia (0.0 - 1.0)
  double get distanceProgress {
    if (initialDistanceToTarget == 0) return 1.0;

    final distanceTraveled = initialDistanceToTarget - distanceToTarget;
    final progress = distanceTraveled / initialDistanceToTarget;

    return progress.clamp(0.0, 1.0);
  }

  @override
  String toString() => 'Context(distance: ${distanceToTarget.toStringAsFixed(0)}m, moving: $isUserMoving, geofence: $isWithinGeofence)';
}

/// Detector para pasos de caminata (walk_to_stop, walk_to_destination)
class WalkStepDetector implements StepDetector {
  /// Distancia en metros para considerar que el usuario llegó
  final double arrivalThresholdMeters;

  /// Número de confirmaciones consecutivas requeridas (histéresis)
  final int consecutiveConfirmationsRequired;

  int _consecutiveConfirmations = 0;

  WalkStepDetector({
    this.arrivalThresholdMeters = 20.0,
    this.consecutiveConfirmationsRequired = 2,
  });

  @override
  bool shouldAdvanceToNextStep(
    TripStep currentStep,
    StepDetectionContext context,
  ) {
    // Verificar si el usuario está dentro del geofence de la parada/destino
    if (context.isWithinGeofence || context.distanceToTarget <= arrivalThresholdMeters) {
      _consecutiveConfirmations++;

      print('[WalkDetector] ✅ Confirmación ${_consecutiveConfirmations}/${consecutiveConfirmationsRequired} - Distancia: ${context.distanceToTarget.toStringAsFixed(0)}m');

      if (_consecutiveConfirmations >= consecutiveConfirmationsRequired) {
        _consecutiveConfirmations = 0; // Reset para próximo paso
        return true;
      }
    } else {
      if (_consecutiveConfirmations > 0) {
        print('[WalkDetector] ⚠️ Reset confirmaciones - Usuario se alejó');
      }
      _consecutiveConfirmations = 0;
    }

    return false;
  }

  @override
  double calculateProgress(
    TripStep currentStep,
    StepDetectionContext context,
  ) {
    return context.distanceProgress;
  }
}

/// Detector para esperar el bus (wait_for_bus)
class WaitForBusDetector implements StepDetector {
  /// Velocidad mínima para considerar que el usuario está en el bus (m/s)
  final double minimumBusSpeedMps;

  /// Distancia máxima de la parada para considerar que está en el bus (metros)
  final double maxDistanceFromStopMeters;

  /// Número de confirmaciones consecutivas requeridas
  final int consecutiveConfirmationsRequired;

  int _consecutiveConfirmations = 0;

  WaitForBusDetector({
    this.minimumBusSpeedMps = 2.0, // ~7 km/h
    this.maxDistanceFromStopMeters = 50.0,
    this.consecutiveConfirmationsRequired = 2, // Reducido de 3 a 2 para funcionar con GPS real (~1Hz)
  });

  @override
  bool shouldAdvanceToNextStep(
    TripStep currentStep,
    StepDetectionContext context,
  ) {
    // El usuario se subió al bus si:
    // 1. Está en la parada (geofence) O en la ruta del bus
    // 2. Está en movimiento
    // 3. Su velocidad indica que está en un vehículo
    //
    // Usamos OR entre geofence y busRoute para ser más tolerante:
    // - Al inicio está en geofence esperando
    // - Luego se mueve y puede temporalmente salir de ambos
    // - Pero si está moviéndose rápido, es señal de boarding
    final isNearStopOrRoute = context.isWithinGeofence || context.isOnBusRoute;
    final isMovingFast = context.isUserMoving && context.userSpeed >= minimumBusSpeedMps;
    final isOnBus = isNearStopOrRoute && isMovingFast;

    if (isOnBus) {
      _consecutiveConfirmations++;

      print('[WaitBusDetector] 🚌 Confirmación ${_consecutiveConfirmations}/${consecutiveConfirmationsRequired} - Velocidad: ${context.userSpeed.toStringAsFixed(1)}m/s, Geofence: ${context.isWithinGeofence}, OnRoute: ${context.isOnBusRoute}');

      if (_consecutiveConfirmations >= consecutiveConfirmationsRequired) {
        _consecutiveConfirmations = 0;
        return true;
      }
    } else {
      if (_consecutiveConfirmations > 0) {
        print('[WaitBusDetector] ⚠️ Reset confirmaciones (velocidad: ${context.userSpeed.toStringAsFixed(1)}m/s, moving: ${context.isUserMoving}, geofence: ${context.isWithinGeofence}, onRoute: ${context.isOnBusRoute})');
      }
      _consecutiveConfirmations = 0;
    }

    return false;
  }

  @override
  double calculateProgress(
    TripStep currentStep,
    StepDetectionContext context,
  ) {
    // En espera del bus, el progreso es indeterminado
    // Podríamos usar el tiempo transcurrido si tenemos ETA
    return 0.0;
  }
}

/// Detector para estar en el bus (on_bus)
class OnBusDetector implements StepDetector {
  /// Distancia para considerar que llegó a la parada destino
  final double arrivalThresholdMeters;

  /// Número de confirmaciones consecutivas requeridas
  final int consecutiveConfirmationsRequired;

  int _consecutiveConfirmations = 0;

  OnBusDetector({
    this.arrivalThresholdMeters = 30.0,
    this.consecutiveConfirmationsRequired = 2,
  });

  @override
  bool shouldAdvanceToNextStep(
    TripStep currentStep,
    StepDetectionContext context,
  ) {
    // El usuario llegó a la parada destino
    if (context.isWithinGeofence || context.distanceToTarget <= arrivalThresholdMeters) {
      _consecutiveConfirmations++;

      print('[OnBusDetector] 🚏 Confirmación ${_consecutiveConfirmations}/${consecutiveConfirmationsRequired} - Distancia: ${context.distanceToTarget.toStringAsFixed(0)}m');

      if (_consecutiveConfirmations >= consecutiveConfirmationsRequired) {
        _consecutiveConfirmations = 0;
        return true;
      }
    } else {
      _consecutiveConfirmations = 0;
    }

    return false;
  }

  @override
  double calculateProgress(
    TripStep currentStep,
    StepDetectionContext context,
  ) {
    return context.distanceProgress;
  }
}
