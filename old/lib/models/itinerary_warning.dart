// lib/models/itinerary_warning.dart

// Para definir claramente el tipo de advertencia
enum ItineraryWarningType {
  WALK_TIME_EXCEEDS_ETA, // El tiempo de caminata estimado para llegar a la parada supera el ETA del bus.
  NO_BUS_ETA_FOUND, // El servicio de ETA respondió, pero no encontró un próximo arribo para la línea/ruta específica en esa parada.
  NO_REALTIME_ETA_AVAILABLE, // El servicio de ETA no tiene información en tiempo real para el bus, solo programada.
  FIRST_LEG_TOO_SHORT_FOR_REALTIME, // El primer tramo de bus es demasiado corto como para que la información de ETA en tiempo real sea significativamente útil o precisa.
  ETA_API_ERROR, // Hubo un error al contactar el servicio de ETA para la parada.
  ETA_LOOKUP_SKIPPED_LIMIT_REACHED, // La consulta de ETA para la parada de origen de este itinerario se omitió porque se alcanzó el límite de consultas a la API por planificación.
  LONG_WALK, // Advertencia general si la caminata total es larga.
  LONG_WAIT, // Advertencia general si la espera total es larga.
  UNKNOWN_OTP_ERROR, // Error desconocido de OTP
}

class ItineraryWarning {
  final ItineraryWarningType type;
  final String message;

  const ItineraryWarning({required this.type, required this.message});

  @override
  String toString() => 'ItineraryWarning(type: $type, message: $message)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ItineraryWarning &&
        other.type == type &&
        other.message == message;
  }

  @override
  int get hashCode => type.hashCode ^ message.hashCode;
}
