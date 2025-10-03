import 'dart:async';
import 'trip_state_machine.dart';
import 'trip_step.dart';
import 'step_detector.dart';

/// Orquestador del viaje que coordina la máquina de estados y los detectores
///
/// Esta clase es la capa de coordinación entre:
/// - TripStateMachine (lógica de progresión)
/// - StepDetectors (decisiones de avance)
/// - GeometryAdapter (cálculo de contexto desde GPS)
///
/// NO conoce coordenadas directamente, solo orquesta.
class TripOrchestrator {
  final TripStateMachine stateMachine;
  final Map<TripStepType, StepDetector> detectors;

  /// Callback para obtener el contexto de detección
  ///
  /// Este callback será implementado por el GeometryAdapter.
  /// Recibe el paso actual y retorna el contexto calculado.
  final Future<StepDetectionContext> Function(TripStep step) getContextForStep;

  /// Callback cuando el viaje se completa
  final void Function()? onTripCompleted;

  /// Callback cuando hay un cambio de paso
  final void Function(TripStep newStep)? onStepChanged;

  /// Callback cuando hay actualización de progreso
  final void Function(double progress)? onProgressUpdated;

  Timer? _updateTimer;
  bool _isRunning = false;

  TripOrchestrator({
    required this.stateMachine,
    required this.detectors,
    required this.getContextForStep,
    this.onTripCompleted,
    this.onStepChanged,
    this.onProgressUpdated,
  });

  /// Inicia el viaje y el loop de actualizaciones
  void start({Duration updateInterval = const Duration(seconds: 5)}) {
    if (_isRunning) {
      print('[TripOrchestrator] ⚠️ Ya está corriendo');
      return;
    }

    _isRunning = true;
    stateMachine.start();

    print('[TripOrchestrator] 🚀 Iniciando orquestador con intervalo de ${updateInterval.inSeconds}s');

    // Iniciar timer de actualizaciones
    _updateTimer = Timer.periodic(updateInterval, (_) => _update());
  }

  /// Para el viaje y el loop de actualizaciones
  void stop() {
    _isRunning = false;
    _updateTimer?.cancel();
    _updateTimer = null;

    print('[TripOrchestrator] 🛑 Orquestador detenido');
  }

  /// Ciclo de actualización principal
  Future<void> _update() async {
    if (!_isRunning || stateMachine.isCompleted) {
      stop();
      return;
    }

    try {
      final currentStep = stateMachine.currentStep;

      // 1. Obtener contexto del GeometryAdapter
      final context = await getContextForStep(currentStep);

      print('[TripOrchestrator] 🔄 Update - Step: ${currentStep.type}, Context: $context');

      // 2. Obtener el detector apropiado para este tipo de paso
      final detector = detectors[currentStep.type];
      if (detector == null) {
        print('[TripOrchestrator] ⚠️ No hay detector para ${currentStep.type}');
        return;
      }

      // 3. Calcular progreso
      final progress = detector.calculateProgress(currentStep, context);
      stateMachine.updateCurrentStepProgress(progress);
      onProgressUpdated?.call(progress);

      // 4. Verificar si se debe avanzar
      final shouldAdvance = detector.shouldAdvanceToNextStep(currentStep, context);

      if (shouldAdvance) {
        print('[TripOrchestrator] ✅ Detector indica avanzar al siguiente paso');

        final hasNext = stateMachine.advanceToNextStep();

        if (hasNext) {
          onStepChanged?.call(stateMachine.currentStep);
        } else {
          // Viaje completado
          print('[TripOrchestrator] 🎉 Viaje completado!');
          onTripCompleted?.call();
          stop();
        }
      }
    } catch (e, stack) {
      print('[TripOrchestrator] ❌ Error en update: $e');
      print(stack);
    }
  }

  /// Actualización manual (útil para testing)
  Future<void> updateNow() async {
    await _update();
  }

  /// Cancela el viaje
  void cancel() {
    stateMachine.cancel();
    stop();
  }

  /// Debug: imprime el estado
  void printStatus() {
    stateMachine.printStatus();
  }

  void dispose() {
    stop();
  }
}

/// Factory para crear un TripOrchestrator con detectores por defecto
TripOrchestrator createDefaultOrchestrator({
  required TripStateMachine stateMachine,
  required Future<StepDetectionContext> Function(TripStep step) getContextForStep,
  void Function()? onTripCompleted,
  void Function(TripStep newStep)? onStepChanged,
  void Function(double progress)? onProgressUpdated,
}) {
  return TripOrchestrator(
    stateMachine: stateMachine,
    detectors: {
      TripStepType.walkToStop: WalkStepDetector(),
      TripStepType.waitForBus: WaitForBusDetector(),
      TripStepType.onBus: OnBusDetector(),
      TripStepType.walkToDestination: WalkStepDetector(),
    },
    getContextForStep: getContextForStep,
    onTripCompleted: onTripCompleted,
    onStepChanged: onStepChanged,
    onProgressUpdated: onProgressUpdated,
  );
}
