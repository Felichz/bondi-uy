import '../backend/contrato_ui/app_ui_state.dart';

enum JourneyStepType {
  WALKING_TO_STOP,
  WAITING_FOR_BUS,
  RIDING_BUS,
  WALKING_TO_DESTINATION,
}

class JourneyStepState {
  final int stepIndex;
  final JourneyStepType type;
  final Coordenada? destination;
  final Coordenada? startLocation;
  final String? busLine;
  final double? remainingDistance;
  final int? remainingTimeSeconds;
  final double? progressPercentage;
  final String? instructions;
  final DateTime? startTime;
  final List<Coordenada>? currentRoute;

  JourneyStepState({
    required this.stepIndex,
    required this.type,
    this.destination,
    this.startLocation,
    this.busLine,
    this.remainingDistance,
    this.remainingTimeSeconds,
    this.progressPercentage,
    this.instructions,
    this.startTime,
    this.currentRoute,
  });

  JourneyStepState copyWith({
    int? stepIndex,
    JourneyStepType? type,
    Coordenada? destination,
    Coordenada? startLocation,
    String? busLine,
    double? remainingDistance,
    int? remainingTimeSeconds,
    double? progressPercentage,
    String? instructions,
    DateTime? startTime,
    List<Coordenada>? currentRoute,
  }) {
    return JourneyStepState(
      stepIndex: stepIndex ?? this.stepIndex,
      type: type ?? this.type,
      destination: destination ?? this.destination,
      startLocation: startLocation ?? this.startLocation,
      busLine: busLine ?? this.busLine,
      remainingDistance: remainingDistance ?? this.remainingDistance,
      remainingTimeSeconds: remainingTimeSeconds ?? this.remainingTimeSeconds,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      instructions: instructions ?? this.instructions,
      startTime: startTime ?? this.startTime,
      currentRoute: currentRoute ?? this.currentRoute,
    );
  }

  String get typeDisplayName {
    switch (type) {
      case JourneyStepType.WALKING_TO_STOP:
        return 'Camina hacia la parada';
      case JourneyStepType.WAITING_FOR_BUS:
        return 'Espera el bus';
      case JourneyStepType.RIDING_BUS:
        return 'En el bus';
      case JourneyStepType.WALKING_TO_DESTINATION:
        return 'Camina al destino';
    }
  }

  String? get formattedRemainingTime {
    if (remainingTimeSeconds == null) return null;

    final minutes = remainingTimeSeconds! ~/ 60;
    final seconds = remainingTimeSeconds! % 60;

    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String? get formattedRemainingDistance {
    if (remainingDistance == null) return null;

    if (remainingDistance! >= 1000) {
      final km = remainingDistance! / 1000;
      return '${km.toStringAsFixed(1)} km';
    } else {
      return '${remainingDistance!.round()} m';
    }
  }

  bool get isCompleted =>
      progressPercentage != null && progressPercentage! >= 100.0;

  bool get isInProgress =>
      progressPercentage != null &&
      progressPercentage! > 0.0 &&
      progressPercentage! < 100.0;

  @override
  String toString() {
    return 'JourneyStepState('
        'stepIndex: $stepIndex, '
        'type: $type, '
        'destination: $destination, '
        'busLine: $busLine, '
        'remainingDistance: $remainingDistance, '
        'remainingTimeSeconds: $remainingTimeSeconds, '
        'progressPercentage: $progressPercentage'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is JourneyStepState &&
        other.stepIndex == stepIndex &&
        other.type == type &&
        other.destination == destination &&
        other.startLocation == startLocation &&
        other.busLine == busLine &&
        other.remainingDistance == remainingDistance &&
        other.remainingTimeSeconds == remainingTimeSeconds &&
        other.progressPercentage == progressPercentage;
  }

  @override
  int get hashCode {
    return stepIndex.hashCode ^
        type.hashCode ^
        destination.hashCode ^
        startLocation.hashCode ^
        busLine.hashCode ^
        remainingDistance.hashCode ^
        remainingTimeSeconds.hashCode ^
        progressPercentage.hashCode;
  }
}
