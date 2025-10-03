/// Validaciones reutilizables para AppLogicProvider
///
/// Centraliza toda la lógica de validación para mantener app_logic_provider.dart
/// enfocado en orquestación de alto nivel.

import '../../contrato_ui/app_ui_state.dart';

class ValidationHelpers {
  /// Valida que existan los requisitos mínimos para búsqueda de rutas
  /// Retorna mensaje de error si falla, null si pasa
  static String? validateSearchRequirements({
    required Coordenada? currentLocation,
    required Coordenada? destination,
  }) {
    if (currentLocation == null) {
      return "No pudimos obtener tu ubicación actual. Verifica que el GPS esté activado.";
    }

    if (destination == null) {
      return "Debes ingresar un destino para buscar rutas.";
    }

    return null; // Validación exitosa
  }

  /// Valida que la fase actual permite iniciar un viaje
  static bool canStartTrip(FaseApp currentPhase) {
    return currentPhase == FaseApp.MOSTRANDO_OPCIONES_RUTA;
  }

  /// Valida que exista información de parada básica
  static bool hasStopInfo(InfoParadaEnMapa? stopInfo) {
    return stopInfo != null;
  }

  /// Valida que un texto de búsqueda sea válido para geocoding
  static bool isValidSearchText(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    if (text.trim().length < 3) return false; // Mínimo 3 caracteres
    return true;
  }
}
