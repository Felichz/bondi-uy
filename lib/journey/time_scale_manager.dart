/// Gestiona la escala de tiempo para simulación
///
/// Este servicio centraliza el manejo del tiempo, permitiendo que la app
/// funcione correctamente tanto en modo normal como en modo simulación acelerada.
///
/// En modo simulación, todos los cálculos dependientes de tiempo se ajustan
/// automáticamente según el factor de velocidad del simulador.
class TimeScaleManager {
  static final TimeScaleManager _instance = TimeScaleManager._internal();
  factory TimeScaleManager() => _instance;
  TimeScaleManager._internal();

  /// Factor de escala de tiempo (1.0 = tiempo real, 10.0 = 10x más rápido)
  double _timeScale = 1.0;

  /// Tiempo de inicio de la simulación (para cálculos relativos)
  DateTime? _simulationStartTime;

  /// Duración simulada acumulada
  Duration _simulatedDuration = Duration.zero;

  /// Activar modo simulación con un factor de velocidad
  void startSimulation(double speedFactor) {
    _timeScale = speedFactor;
    _simulationStartTime = DateTime.now();
    _simulatedDuration = Duration.zero;
    print('[TIME_SCALE] 🕐 Simulación iniciada: ${speedFactor}x');
  }

  /// Detener simulación y volver a tiempo real
  void stopSimulation() {
    _timeScale = 1.0;
    _simulationStartTime = null;
    _simulatedDuration = Duration.zero;
    print('[TIME_SCALE] 🕐 Simulación detenida, volviendo a tiempo real');
  }

  /// Obtener el tiempo actual ajustado por la escala de simulación
  DateTime get now {
    if (_timeScale == 1.0 || _simulationStartTime == null) {
      return DateTime.now();
    }

    // En simulación: calcular tiempo virtual basado en cuánto tiempo real ha pasado
    final realElapsed = DateTime.now().difference(_simulationStartTime!);
    final virtualElapsed = Duration(
      microseconds: (realElapsed.inMicroseconds * _timeScale).round(),
    );

    return _simulationStartTime!.add(virtualElapsed);
  }

  /// Calcular duración ajustada por escala de tiempo
  Duration scaledDuration(Duration realDuration) {
    if (_timeScale == 1.0) return realDuration;

    return Duration(
      microseconds: (realDuration.inMicroseconds / _timeScale).round(),
    );
  }

  /// Calcular intervalo de tiempo entre dos timestamps, ajustado por escala
  Duration timeBetween(DateTime start, DateTime end) {
    final realDuration = end.difference(start);

    if (_timeScale == 1.0) return realDuration;

    // En simulación, el tiempo "percibido" es más rápido
    return Duration(
      microseconds: (realDuration.inMicroseconds * _timeScale).round(),
    );
  }

  /// Factor de velocidad actual
  double get timeScale => _timeScale;

  /// ¿Está en modo simulación?
  bool get isSimulating => _timeScale > 1.0;

  /// Ajustar threshold de distancia según velocidad de simulación
  /// Útil para detecciones que usan distancia como proxy de tiempo
  double adjustThreshold(double baseThreshold) {
    if (_timeScale == 1.0) return baseThreshold;

    // A mayor velocidad, necesitamos thresholds más amplios para compensar
    // el menor número de samples por unidad de distancia real
    return baseThreshold * _timeScale;
  }

  /// Ajustar número de detecciones consecutivas requeridas
  /// En simulación rápida, hay menos ticks por segundo real
  int adjustConsecutiveCount(int baseCount) {
    if (_timeScale == 1.0) return baseCount;

    // Reducir count proporcionalmente a la velocidad
    // A 10x velocidad, 3 detecciones → 1 detección
    final adjusted = (baseCount / _timeScale).round();
    return adjusted.clamp(1, baseCount); // Mínimo 1, máximo el original
  }
}
