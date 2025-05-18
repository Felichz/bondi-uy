import 'bus_arrival_info.dart'; // Corregido: Import directo
import 'itinerary_warning.dart'; // Corregido: Import directo
import 'processed_itinerary.dart'; // Para la clase ProcessedItinerary
import 'consolidated_itinerary_leg.dart';
import 'itinerary.dart'; // Para la clase Itinerary (usada por ProcessedItinerary)

// Representa un conjunto de opciones de viaje que comparten tramos clave
// y se presentan al usuario como una única opción principal con alternativas.
class ConsolidatedItinerary {
  // Lista de los tramos consolidados que componen este itinerario.
  final List<ConsolidatedItineraryLeg> legs;

  // Referencia al primer ProcessedItinerary que sirvió de base para esta consolidación.
  // Útil para heredar propiedades comunes como tiempos de inicio/fin, advertencias iniciales, etc.
  final ProcessedItinerary representativeProcessedItinerary;

  // Lista de todos los ProcessedItinerary que fueron agrupados bajo esta opción consolidada.
  // Podría ser útil para analíticas o para ofrecer al usuario "ver todas las X variantes exactas".
  final List<ProcessedItinerary> originalProcessedItineraries;

  // Campos calculados y resumidos para la opción consolidada
  final Duration
  estimatedTotalDuration; // Duración total estimada (podría ser un rango o el promedio/mejor caso)
  final Duration totalWalkDuration;
  final Duration walkToFirstBusStopDuration;
  final Duration
  firstBusWaitDuration; // Espera para el primer bus (considerando alternativas)

  final BusArrivalInfo?
  representativeFirstBusETAInfo; // ETA más representativa o próxima del primer tramo de bus
  final List<BusArrivalInfo> alternativeFirstBusETAs; // NUEVO CAMPO
  final bool
  canReachFirstBus; // ¿Se puede alcanzar el primer bus (considerando alternativas)?

  final List<ItineraryWarningType> warnings; // Advertencias consolidadas
  final double score; // Una puntuación recalculada para la opción consolidada

  // Podríamos necesitar un identificador único si vamos a seleccionar/deseleccionar estos.
  final String id;

  ConsolidatedItinerary({
    required this.id,
    required this.legs,
    required this.representativeProcessedItinerary,
    required this.originalProcessedItineraries,
    required this.estimatedTotalDuration,
    required this.totalWalkDuration,
    required this.walkToFirstBusStopDuration,
    required this.firstBusWaitDuration,
    this.representativeFirstBusETAInfo,
    this.alternativeFirstBusETAs = const [], // NUEVO CAMPO CON DEFAULT
    required this.canReachFirstBus,
    this.warnings = const [],
    required this.score,
  });

  DateTime get startTime => DateTime.fromMillisecondsSinceEpoch(
    representativeProcessedItinerary.originalOtpItinerary.startTime,
  );
  DateTime get endTime => DateTime.fromMillisecondsSinceEpoch(
    representativeProcessedItinerary.originalOtpItinerary.endTime,
  );

  // Helper para saber si es una opción de solo caminata
  bool get isWalkOnly =>
      legs.length == 1 && legs.first.mode.toUpperCase() == 'WALK';
}
