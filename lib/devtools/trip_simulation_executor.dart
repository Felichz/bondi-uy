import 'dart:async';
import 'package:bondi_uy/devtools/trip_simulation_spec.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart' show Coordenada;

/// Ejecuta una simulación de viaje basada en una especificación
///
/// Responsabilidades:
/// - Ejecutar las fases de la simulación en orden
/// - Interpolar posiciones basadas en progreso
/// - Emitir eventos para testing/observabilidad
/// - Inyectar ubicaciones mock al sistema
///
/// NO es responsable de:
/// - Construir las rutas/geometrías (eso es TripSimulationBuilder)
/// - Lógica de negocio del viaje (eso es JourneyManager)
class TripSimulationExecutor {
  final TripSimulationSpec spec;
  final Function(Coordenada) onUserLocationUpdate;
  final Function(Coordenada, int)? onBusLocationUpdate;
  final Function(SimulationEvent)? onEvent;

  Timer? _timer;
  DateTime? _startTime;
  int _currentPhaseIndex = 0;

  TripSimulationExecutor({
    required this.spec,
    required this.onUserLocationUpdate,
    this.onBusLocationUpdate,
    this.onEvent,
  });

  bool get isRunning => _timer != null;

  /// Inicia la simulación
  void start() {
    if (isRunning) return;

    _startTime = DateTime.now();
    _currentPhaseIndex = 0;

    _emitEvent(SimulationEvent(
      type: SimulationEventType.simulationStarted,
      timestamp: 0.0,
      data: {'totalPhases': spec.phases.length},
    ));

    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  /// Detiene la simulación
  void stop() {
    final elapsed = _getElapsedSeconds();
    _timer?.cancel();
    _timer = null;
    _startTime = null;

    _emitEvent(SimulationEvent(
      type: SimulationEventType.simulationStopped,
      timestamp: elapsed,
      data: {'finalPhase': _currentPhaseIndex},
    ));
  }

  void _tick() {
    final elapsed = _getElapsedSeconds();
    final adjustedElapsed = elapsed * spec.config.speed;

    // Encontrar la fase actual basada en tiempo acumulado
    double phaseStartTime = 0.0;
    SimulationPhase? currentPhase;
    int phaseIndex = 0;

    for (int i = 0; i < spec.phases.length; i++) {
      final phase = spec.phases[i];
      final phaseEndTime = phaseStartTime + phase.duration;

      if (adjustedElapsed >= phaseStartTime && adjustedElapsed < phaseEndTime) {
        currentPhase = phase;
        phaseIndex = i;
        break;
      }

      phaseStartTime = phaseEndTime;
    }

    // Si no hay fase actual, la simulación terminó
    if (currentPhase == null) {
      stop();
      return;
    }

    // Cambio de fase - emitir evento
    if (phaseIndex != _currentPhaseIndex) {
      _currentPhaseIndex = phaseIndex;
      _emitEvent(SimulationEvent(
        type: SimulationEventType.phaseChanged,
        timestamp: elapsed,
        data: {
          'phaseIndex': phaseIndex,
          'phaseType': currentPhase.type.name,
          'description': currentPhase.description,
        },
      ));
    }

    // Calcular progreso dentro de la fase actual (0.0 - 1.0)
    final phaseElapsed = adjustedElapsed - phaseStartTime;
    final phaseProgress = (phaseElapsed / currentPhase.duration).clamp(0.0, 1.0);

    // Interpolar posición del usuario
    final userPos = _interpolatePosition(currentPhase.userPath, phaseProgress);
    onUserLocationUpdate(userPos);

    // Interpolar posición del bus (si existe)
    if (currentPhase.busPath != null && onBusLocationUpdate != null) {
      final busPos = _interpolatePosition(currentPhase.busPath!, phaseProgress);

      // Calcular ETA basado en tiempo restante
      final remainingTime = currentPhase.duration - phaseElapsed;
      final etaMinutes = (remainingTime / 60.0).ceil().clamp(0, 99);

      onBusLocationUpdate!(busPos, etaMinutes);
    }

    // Emitir evento de progreso (cada segundo)
    if (elapsed % 1.0 < 0.1) {
      _emitEvent(SimulationEvent(
        type: SimulationEventType.progress,
        timestamp: elapsed,
        data: {
          'phase': phaseIndex,
          'phaseProgress': phaseProgress,
          'totalProgress': adjustedElapsed / spec.totalDuration,
        },
      ));
    }
  }

  double _getElapsedSeconds() {
    if (_startTime == null) return 0.0;
    return DateTime.now().difference(_startTime!).inMilliseconds / 1000.0;
  }

  Coordenada _interpolatePosition(List<Coordenada> route, double progress) {
    if (route.isEmpty) {
      return Coordenada(latitud: 0, longitud: 0);
    }
    if (route.length == 1 || progress <= 0.0) {
      return route.first;
    }
    if (progress >= 1.0) {
      return route.last;
    }

    final exactIndex = progress * (route.length - 1);
    final index = exactIndex.floor();
    final nextIndex = (index + 1).clamp(0, route.length - 1);
    final t = exactIndex - index;

    final p1 = route[index];
    final p2 = route[nextIndex];

    final lat = p1.latitud + (p2.latitud - p1.latitud) * t;
    final lng = p1.longitud + (p2.longitud - p1.longitud) * t;

    return Coordenada(latitud: lat, longitud: lng);
  }

  void _emitEvent(SimulationEvent event) {
    if (spec.config.emitEvents) {
      onEvent?.call(event);
    }
  }
}

/// Evento de simulación (para testing y observabilidad)
class SimulationEvent {
  final SimulationEventType type;
  final double timestamp; // Segundos desde inicio
  final Map<String, dynamic> data;

  SimulationEvent({
    required this.type,
    required this.timestamp,
    this.data = const {},
  });

  @override
  String toString() =>
      '[SimEvent @${timestamp.toStringAsFixed(1)}s] $type: $data';
}

enum SimulationEventType {
  simulationStarted,
  simulationStopped,
  phaseChanged,
  progress,
  cameraZoomExpected, // Esperamos que la cámara haga zoom
}
