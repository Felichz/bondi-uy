/// Detector de subida al bus con histéresis
///
/// Usa un sistema de conteo de confirmaciones consecutivas para evitar
/// falsos positivos en la detección de subida al bus.

import '../../backend/contrato_ui/app_ui_state.dart';
import '../../utils/geometry_utils.dart';

class BusBoardingDetector {
  // Configuración de histéresis
  static const int _requiredConsecutivePositives = 5; // ~5 segundos de confirmación
  static const Duration _evalMinSpacing = Duration(milliseconds: 900);
  static const double _boardingProximityThreshold = 50.0; // metros

  // Estado interno
  int _positiveCount = 0;
  DateTime? _lastEvaluation;

  /// Evalúa si el usuario ha subido al bus
  /// Retorna true solo después de N confirmaciones consecutivas
  bool evaluateBoarding({
    required Coordenada userLocation,
    required Coordenada busLocation,
  }) {
    // Throttling - no evaluar muy seguido
    final now = DateTime.now();
    if (_lastEvaluation != null) {
      final elapsed = now.difference(_lastEvaluation!);
      if (elapsed < _evalMinSpacing) {
        return false; // Aún no es momento de evaluar
      }
    }

    _lastEvaluation = now;

    // Calcular distancia entre usuario y bus
    final distance = calculateHaversineDistance(
      userLocation.latitud,
      userLocation.longitud,
      busLocation.latitud,
      busLocation.longitud,
    );

    // Verificar proximidad
    final isNearBus = distance <= _boardingProximityThreshold;

    if (isNearBus) {
      _positiveCount++;
    } else {
      // Reset si se aleja del bus
      _positiveCount = 0;
    }

    // Detectar boarding solo después de N confirmaciones consecutivas
    if (_positiveCount >= _requiredConsecutivePositives) {
      return true;
    }

    return false;
  }

  /// Resetea el estado del detector
  void reset() {
    _positiveCount = 0;
    _lastEvaluation = null;
  }

  /// Obtiene el conteo actual de confirmaciones positivas
  int get currentPositiveCount => _positiveCount;

  /// Verifica si está en proceso de detección (tiene algunos positivos pero no suficientes)
  bool get isEvaluating => _positiveCount > 0 && _positiveCount < _requiredConsecutivePositives;

  /// Obtiene el progreso de detección (0.0 a 1.0)
  double get detectionProgress {
    return _positiveCount / _requiredConsecutivePositives;
  }
}
