/// Helpers de logging para AppLogicProvider
///
/// Centraliza todos los prints verbosos para mantener el código principal limpio.

import '../../contrato_ui/app_ui_state.dart';

class LoggingHelpers {
  static const String _prefix = "[AppLogic]";

  /// Log inicio de búsqueda de rutas
  static void logSearchStart({
    required FaseApp currentPhase,
    required Coordenada? currentLocation,
    required Coordenada? destination,
  }) {
    print("$_prefix 🔍 === INICIO BÚSQUEDA DE RUTAS ====");
    print("$_prefix 🔍 Usuario presionó buscar");
    print("$_prefix 🔍 Estado actual: $currentPhase");
    print("$_prefix 📍 Ubicación actual: $currentLocation");
    print("$_prefix 📍 Destino: $destination");
  }

  /// Log validación fallida
  static void logValidationFailed({
    required bool locationNull,
    required bool destinationNull,
  }) {
    print("$_prefix ❌ Validación fallida - ubicación o destino nulos");
    print("$_prefix ❌ Ubicación actual nula: $locationNull");
    print("$_prefix ❌ Destino nulo: $destinationNull");
  }

  /// Log búsqueda exitosa
  static void logSearchSuccess(int routeCount) {
    print("$_prefix ✅ Búsqueda completada: $routeCount opciones encontradas");
  }

  /// Log inicio de viaje
  static void logTripStart(String routeId) {
    print("$_prefix 🚀 === INICIANDO VIAJE ===");
    print("$_prefix 🚀 Ruta seleccionada: $routeId");
  }

  /// Log evento de Journey
  static void logJourneyEvent(String eventType, Map<String, dynamic>? data) {
    print("$_prefix 📡 Journey Event: $eventType");
    if (data != null && data.isNotEmpty) {
      print("$_prefix 📡 Data: $data");
    }
  }

  /// Log transición de paso
  static void logStepTransition({
    required int fromIndex,
    required int toIndex,
    required String stepType,
  }) {
    print("$_prefix 🔄 Transición de paso: #$fromIndex → #$toIndex ($stepType)");
  }

  /// Log actualización de bus
  static void logBusUpdate({
    required String busLine,
    required int eta,
    required Coordenada position,
  }) {
    print("$_prefix 🚌 Bus actualizado: Línea $busLine, ETA: ${eta}min");
    print("$_prefix 🚌 Posición: ${position.latitud},${position.longitud}");
  }

  /// Log error general
  static void logError(String context, dynamic error, [StackTrace? stack]) {
    print("$_prefix ❌ Error en $context: $error");
    if (stack != null) {
      print("$_prefix ❌ Stack: $stack");
    }
  }

  /// Log cambio de fase
  static void logPhaseChange(FaseApp from, FaseApp to) {
    print("$_prefix 🔄 Cambio de fase: $from → $to");
  }

  /// Log detección de llegada
  static void logArrivalDetected(String stepType) {
    print("$_prefix 🎯 Llegada detectada a: $stepType");
  }

  /// Log detección de subida al bus
  static void logBoardingDetected(String busInfo) {
    print("$_prefix 🚌 Subida al bus detectada: $busInfo");
  }
}
