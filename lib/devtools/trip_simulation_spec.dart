import '../backend/contrato_ui/app_ui_state.dart' show Coordenada;

/// Especificación de una simulación de viaje completa
///
/// Esta clase define TODOS los datos necesarios para ejecutar una simulación,
/// separando completamente la CONSTRUCCIÓN de datos de la EJECUCIÓN.
///
/// Puede ser construida desde:
/// - Estado actual de la app (EstadoFaseViajeActivo)
/// - JSON fixtures para testing
class TripSimulationSpec {
  final List<SimulationPhase> phases;
  final SimulationConfig config;

  TripSimulationSpec({
    required this.phases,
    SimulationConfig? config,
  }) : config = config ?? SimulationConfig();

  /// Construye spec desde JSON (para testing)
  factory TripSimulationSpec.fromJson(Map<String, dynamic> json) {
    return TripSimulationSpec(
      phases: (json['phases'] as List)
          .map((p) => SimulationPhase.fromJson(p))
          .toList(),
      config: json['config'] != null
          ? SimulationConfig.fromJson(json['config'])
          : SimulationConfig(),
    );
  }

  Map<String, dynamic> toJson() => {
        'phases': phases.map((p) => p.toJson()).toList(),
        'config': config.toJson(),
      };

  double get totalDuration {
    return phases.fold(0.0, (sum, phase) => sum + phase.duration);
  }
}

/// Configuración de la simulación (velocidad, eventos esperados, etc)
class SimulationConfig {
  final double speed;
  final bool emitEvents;

  /// Eventos de cámara que ESPERAMOS que el código de producción dispare
  /// cuando recibe estos inputs GPS del simulador.
  ///
  /// IMPORTANTE: El simulador NO dispara estos eventos. Solo inyecta GPS.
  /// Estos eventos son para VALIDAR en tests que MapManager/CameraController
  /// respondieron correctamente a los inputs.
  final List<ExpectedCameraEvent> expectedCameraEvents;

  SimulationConfig({
    this.speed = 1.0,
    this.emitEvents = true,
    this.expectedCameraEvents = const [],
  });

  factory SimulationConfig.fromJson(Map<String, dynamic> json) {
    return SimulationConfig(
      speed: json['speed']?.toDouble() ?? 1.0,
      emitEvents: json['emitEvents'] ?? true,
      expectedCameraEvents: (json['expectedCameraEvents'] as List?)
              ?.map((e) => ExpectedCameraEvent.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'speed': speed,
        'emitEvents': emitEvents,
        'expectedCameraEvents':
            expectedCameraEvents.map((e) => e.toJson()).toList(),
      };
}

/// Define un evento de cámara esperado en un momento específico del viaje
class ExpectedCameraEvent {
  final double atTime; // Segundos desde el inicio
  final CameraEventType type;
  final String description;
  final Map<String, dynamic>? expectedData;

  ExpectedCameraEvent({
    required this.atTime,
    required this.type,
    required this.description,
    this.expectedData,
  });

  factory ExpectedCameraEvent.fromJson(Map<String, dynamic> json) {
    return ExpectedCameraEvent(
      atTime: json['atTime'].toDouble(),
      type: CameraEventType.values.byName(json['type']),
      description: json['description'],
      expectedData: json['expectedData'],
    );
  }

  Map<String, dynamic> toJson() => {
        'atTime': atTime,
        'type': type.name,
        'description': description,
        if (expectedData != null) 'expectedData': expectedData,
      };
}

enum CameraEventType {
  zoomToUserAndStop, // Usuario caminando a parada
  zoomToBusAndStop, // Bus acercándose mientras usuario espera
  zoomToUserOnBus, // Usuario viajando en bus
  zoomToDestination, // Usuario caminando a destino final
}

/// Una fase de la simulación (walk, wait, ride, etc)
class SimulationPhase {
  final PhaseType type;
  final double duration; // Segundos (sin ajuste de speed)
  final List<Coordenada> userPath; // Ruta del usuario
  final List<Coordenada>? busPath; // Ruta del bus (si aplica)
  final int? busEtaMinutes; // ETA inicial del bus (si aplica)
  final String? description;

  SimulationPhase({
    required this.type,
    required this.duration,
    required this.userPath,
    this.busPath,
    this.busEtaMinutes,
    this.description,
  });

  factory SimulationPhase.fromJson(Map<String, dynamic> json) {
    return SimulationPhase(
      type: PhaseType.values.byName(json['type']),
      duration: json['duration'].toDouble(),
      userPath: (json['userPath'] as List)
          .map((c) => Coordenada(
                latitud: c['lat'].toDouble(),
                longitud: c['lng'].toDouble(),
              ))
          .toList(),
      busPath: json['busPath'] != null
          ? (json['busPath'] as List)
              .map((c) => Coordenada(
                    latitud: c['lat'].toDouble(),
                    longitud: c['lng'].toDouble(),
                  ))
              .toList()
          : null,
      busEtaMinutes: json['busEtaMinutes'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'duration': duration,
        'userPath': userPath
            .map((c) => {'lat': c.latitud, 'lng': c.longitud})
            .toList(),
        if (busPath != null)
          'busPath':
              busPath!.map((c) => {'lat': c.latitud, 'lng': c.longitud}).toList(),
        if (busEtaMinutes != null) 'busEtaMinutes': busEtaMinutes,
        if (description != null) 'description': description,
      };
}

enum PhaseType {
  walkToStop, // Usuario camina a parada mientras bus se acerca
  waitForBus, // Usuario espera en parada, bus termina de llegar
  rideOnBus, // Usuario y bus viajan juntos
  walkToDestination, // Usuario camina al destino final
}
