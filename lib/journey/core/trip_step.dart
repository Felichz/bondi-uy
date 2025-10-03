/// Representa un paso individual en un viaje
///
/// Esta es una estructura unidimensional que NO conoce coordenadas reales.
/// Cada paso tiene un progreso de 0.0 (inicio) a 1.0 (completado).
class TripStep {
  final String id;
  final TripStepType type;
  final String description; // Para debugging y UI
  final TripStepMetadata metadata;

  /// Progreso actual del paso (0.0 = no iniciado, 1.0 = completado)
  double progress;

  /// Estado del paso
  TripStepState state;

  TripStep({
    required this.id,
    required this.type,
    required this.description,
    required this.metadata,
    this.progress = 0.0,
    this.state = TripStepState.notStarted,
  });

  /// Crea una copia del paso con valores actualizados
  TripStep copyWith({
    double? progress,
    TripStepState? state,
  }) {
    return TripStep(
      id: id,
      type: type,
      description: description,
      metadata: metadata,
      progress: progress ?? this.progress,
      state: state ?? this.state,
    );
  }

  /// Verifica si el paso está completado (progreso >= 1.0)
  bool get isCompleted => progress >= 1.0;

  /// Verifica si el paso está en progreso
  bool get isInProgress => state == TripStepState.inProgress;

  @override
  String toString() => 'TripStep($id, $type, progress: ${(progress * 100).toStringAsFixed(0)}%, state: $state)';
}

/// Tipos de pasos en un viaje
enum TripStepType {
  walkToStop,     // Caminar a una parada
  waitForBus,     // Esperar el bus en una parada
  onBus,          // Dentro del bus (de parada origen a parada destino)
  walkToDestination, // Caminar al destino final
}

/// Estados de un paso
enum TripStepState {
  notStarted,   // Aún no comenzado
  inProgress,   // En progreso actualmente
  completed,    // Completado
}

/// Metadata del paso (agnostica a coordenadas)
///
/// Esta estructura contiene IDs de referencia, NO coordenadas directas.
/// El GeometryAdapter usará estos IDs para buscar las coordenadas reales.
class TripStepMetadata {
  /// ID de la parada origen (si aplica)
  final String? originStopId;

  /// ID de la parada destino (si aplica)
  final String? destinationStopId;

  /// Línea de bus (si aplica)
  final String? busLine;

  /// Tiene ETA disponible (para waitForBus)
  final bool hasEta;

  /// Distancia total del paso en metros (calculada inicialmente)
  final double? totalDistanceMeters;

  const TripStepMetadata({
    this.originStopId,
    this.destinationStopId,
    this.busLine,
    this.hasEta = false,
    this.totalDistanceMeters,
  });
}
