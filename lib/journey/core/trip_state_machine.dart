import 'trip_step.dart';

/// Máquina de estados para un viaje completo
///
/// Esta clase maneja la progresión lineal a través de los pasos del viaje.
/// NO conoce coordenadas, geometrías, ni GPS - solo progresión unidimensional.
class TripStateMachine {
  final String tripId;
  final List<TripStep> steps;
  int currentStepIndex;
  TripStatus status;

  TripStateMachine({
    required this.tripId,
    required this.steps,
    this.currentStepIndex = 0,
    this.status = TripStatus.notStarted,
  }) {
    if (steps.isEmpty) {
      throw ArgumentError('Trip must have at least one step');
    }
  }

  /// Obtiene el paso actual
  TripStep get currentStep => steps[currentStepIndex];

  /// Verifica si hay un siguiente paso
  bool get hasNextStep => currentStepIndex < steps.length - 1;

  /// Verifica si el viaje está completado
  bool get isCompleted => status == TripStatus.completed;

  /// Progreso total del viaje (0.0 - 1.0)
  double get overallProgress {
    if (steps.isEmpty) return 0.0;

    double completedSteps = currentStepIndex.toDouble();
    double currentStepProgress = currentStep.progress;

    return (completedSteps + currentStepProgress) / steps.length;
  }

  /// Inicia el viaje
  void start() {
    if (status == TripStatus.notStarted) {
      status = TripStatus.inProgress;
      steps[0] = steps[0].copyWith(state: TripStepState.inProgress);
      print('[TripStateMachine] 🎯 Viaje iniciado: $tripId');
      print('[TripStateMachine] 🚶‍♂️ Paso actual: ${currentStep.description}');
    }
  }

  /// Actualiza el progreso del paso actual
  ///
  /// [progress] debe estar entre 0.0 y 1.0
  void updateCurrentStepProgress(double progress) {
    if (isCompleted) return;

    // Clamp progress entre 0.0 y 1.0
    final clampedProgress = progress.clamp(0.0, 1.0);

    steps[currentStepIndex] = steps[currentStepIndex].copyWith(
      progress: clampedProgress,
    );

    print('[TripStateMachine] 📊 Progreso: ${(clampedProgress * 100).toStringAsFixed(0)}% - ${currentStep.description}');
  }

  /// Avanza al siguiente paso del viaje
  ///
  /// Retorna true si se avanzó exitosamente, false si ya no hay más pasos.
  bool advanceToNextStep() {
    if (isCompleted) {
      print('[TripStateMachine] ⚠️ Viaje ya completado, no se puede avanzar');
      return false;
    }

    // Marcar paso actual como completado
    steps[currentStepIndex] = steps[currentStepIndex].copyWith(
      progress: 1.0,
      state: TripStepState.completed,
    );

    print('[TripStateMachine] ✅ Paso completado: ${currentStep.description}');

    // Verificar si hay siguiente paso
    if (!hasNextStep) {
      _completeTrip();
      return false;
    }

    // Avanzar al siguiente paso
    currentStepIndex++;
    steps[currentStepIndex] = steps[currentStepIndex].copyWith(
      state: TripStepState.inProgress,
    );

    print('[TripStateMachine] ➡️ Avanzando al paso ${currentStepIndex + 1}/${steps.length}');
    print('[TripStateMachine] 🚶‍♂️ Nuevo paso: ${currentStep.description}');

    return true;
  }

  /// Completa el viaje
  void _completeTrip() {
    status = TripStatus.completed;
    print('[TripStateMachine] 🎉 ¡Viaje completado! $tripId');
  }

  /// Cancela el viaje
  void cancel() {
    status = TripStatus.cancelled;
    print('[TripStateMachine] ❌ Viaje cancelado: $tripId');
  }

  /// Crea una copia del state machine
  TripStateMachine copyWith({
    int? currentStepIndex,
    TripStatus? status,
    List<TripStep>? steps,
  }) {
    return TripStateMachine(
      tripId: tripId,
      steps: steps ?? this.steps.map((s) => s).toList(),
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      status: status ?? this.status,
    );
  }

  /// Debug: Imprime el estado actual del viaje
  void printStatus() {
    print('[TripStateMachine] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('[TripStateMachine] 📍 Trip ID: $tripId');
    print('[TripStateMachine] 📊 Status: $status');
    print('[TripStateMachine] 🔢 Paso actual: ${currentStepIndex + 1}/${steps.length}');
    print('[TripStateMachine] 📈 Progreso total: ${(overallProgress * 100).toStringAsFixed(0)}%');
    print('[TripStateMachine] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      final indicator = i == currentStepIndex ? '👉' : '  ';
      print('[TripStateMachine] $indicator $i: ${step.description} (${step.state}, ${(step.progress * 100).toStringAsFixed(0)}%)');
    }
    print('[TripStateMachine] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
}

/// Estados del viaje completo
enum TripStatus {
  notStarted,  // Aún no iniciado
  inProgress,  // En progreso
  completed,   // Completado exitosamente
  cancelled,   // Cancelado por el usuario
}
