/// Detector de salida prematura del bus
///
/// Detecta cuando el usuario se baja del bus antes de llegar a su parada objetivo.
/// Usa histéresis para evitar falsos positivos.

import '../../backend/contrato_ui/app_ui_state.dart';
import '../../utils/geometry_utils.dart';

class BusExitDetector {
  // Configuración de histéresis
  static const int _requiredConsecutiveNegatives = 3; // 3 confirmaciones de estar lejos
  static const double _proximityThreshold = 50.0; // metros

  // Estado interno
  int _negativeCount = 0;

  /// Evalúa si el usuario salió prematuramente del bus
  /// Retorna true solo después de N confirmaciones consecutivas de estar lejos
  bool evaluateEarlyExit({
    required Coordenada userLocation,
    required Coordenada busLocation,
  }) {
    // Calcular distancia entre usuario y bus
    final distance = calculateHaversineDistance(
      userLocation.latitud,
      userLocation.longitud,
      busLocation.latitud,
      busLocation.longitud,
    );

    // Verificar si está lejos del bus
    final isFarFromBus = distance > _proximityThreshold;

    if (isFarFromBus) {
      _negativeCount++;
    } else {
      // Reset si vuelve a estar cerca del bus
      _negativeCount = 0;
    }

    // Detectar salida solo después de N confirmaciones consecutivas
    if (_negativeCount >= _requiredConsecutiveNegatives) {
      return true;
    }

    return false;
  }

  /// Resetea el estado del detector
  void reset() {
    _negativeCount = 0;
  }

  /// Obtiene el conteo actual de confirmaciones negativas
  int get currentNegativeCount => _negativeCount;

  /// Verifica si está en proceso de detección
  bool get isEvaluating => _negativeCount > 0 && _negativeCount < _requiredConsecutiveNegatives;

  /// Obtiene el progreso de detección (0.0 a 1.0)
  double get detectionProgress {
    return _negativeCount / _requiredConsecutiveNegatives;
  }
}
