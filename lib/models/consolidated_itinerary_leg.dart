import 'package:flutter/material.dart' show Color; // Solo importar Color
import 'route_leg.dart'; // Contiene LegEndpoint, LegRoute y la clase RouteLeg que tiene mode como String
import 'leg_mode_constants.dart'; // Importar la definición centralizada

// Representa un tramo en un itinerario consolidado.
// Puede ser un tramo de caminata/espera igual al original,
// o un tramo de bus que agrupa varias líneas alternativas.
class ConsolidatedItineraryLeg {
  final String mode; // Cambiado a String
  final Duration
  duration; // Duración original del primer itinerario que forma este tramo
  final double distance; // Distancia original

  // Campos específicos para tramos de BUS
  final List<String>? alternativeLineShortNames; // Ej: ["121", "D1", "CE1"]
  final List<RouteLeg>
  originalBusLegs; // Lista de los tramos de bus originales (uno por cada línea alternativa) que este tramo consolida.
  // Esto es útil para acceder a detalles específicos si es necesario (ej. color de la línea principal, nombre exacto de la ruta)

  // Campos comunes (tomados del primer RouteLeg representativo o calculados)
  final LegEndpoint from;
  final LegEndpoint to;
  final String?
  headsign; // Podría ser el de la línea más frecuente o el primero
  final Color?
  routeColor; // Color de la línea principal o más frecuente. Flutter Color.

  ConsolidatedItineraryLeg({
    required this.mode,
    required this.duration,
    required this.distance,
    required this.from,
    required this.to,
    this.alternativeLineShortNames,
    this.originalBusLegs = const [],
    this.headsign,
    this.routeColor, // Este es Flutter Color
  });

  bool get isConsolidatedBusLeg =>
      mode == LegModeConstants.bus && // Usar la constante en minúscula: .bus
      alternativeLineShortNames != null &&
      alternativeLineShortNames!.length > 1;

  // Helper para obtener la línea representativa (ej. la primera de las originales)
  // Esto podría usarse para mostrar un nombre de línea o color por defecto en la UI.
  LegRoute? get representativeRoute {
    // Corregido el tipo de retorno a LegRoute?
    if (originalBusLegs.isNotEmpty && originalBusLegs.first.route != null) {
      return originalBusLegs.first.route; // Esto es de tipo LegRoute?
    }
    return null;
  }
}
