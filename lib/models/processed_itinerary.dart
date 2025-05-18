import 'package:flutter/foundation.dart'; // Para @immutable
import 'package:bondi_uy/models/itinerary.dart';
import 'package:bondi_uy/models/route_leg.dart';
import 'package:bondi_uy/models/bus_arrival_info.dart';
import 'package:bondi_uy/models/itinerary_warning.dart';

// Para representar información de una línea de bus alternativa en un tramo fusionado
@immutable
class AlternativeBusLineInfo {
  final String lineShortName;
  final BusArrivalInfo?
  etaInfo; // ETA específica de esta línea alternativa (si se obtuvo)
  // Podría tener el route.gtfsId o longName si es útil para la UI.

  const AlternativeBusLineInfo({required this.lineShortName, this.etaInfo});
}

// Información detallada para un tramo de bus dentro de un ProcessedItinerary
@immutable
class ProcessedBusLegInfo {
  final String originalLegIdentifier; // Para mapear al RouteLeg original de OTP
  final String principalLineShortName;
  final BusArrivalInfo?
  principalLineETAInfo; // La ETA "seleccionada" para este tramo si es el primero
  final List<AlternativeBusLineInfo> alternatives;

  const ProcessedBusLegInfo({
    required this.originalLegIdentifier,
    required this.principalLineShortName,
    this.principalLineETAInfo,
    this.alternatives = const [],
  });
}

@immutable
class ProcessedItinerary {
  final Itinerary originalOtpItinerary;

  // Métricas y Datos Clave Calculados:
  final Duration totalWalkDuration;
  final Duration walkToFirstBusStopDuration;

  final BusArrivalInfo? representativeFirstBusETAInfo;
  final Duration firstBusWaitDuration;

  final bool canReachFirstBus;
  final List<ItineraryWarningType> warnings;

  final double score;

  final Map<String, ProcessedBusLegInfo>? processedBusLegsMap; // Para Fase 2

  final Duration estimatedTotalDuration;

  const ProcessedItinerary({
    required this.originalOtpItinerary,
    required this.totalWalkDuration,
    required this.walkToFirstBusStopDuration,
    this.representativeFirstBusETAInfo,
    required this.firstBusWaitDuration,
    required this.canReachFirstBus,
    this.warnings = const [],
    required this.score,
    this.processedBusLegsMap,
    required this.estimatedTotalDuration,
  });

  // Helper para facilitar la creación de una copia con algunos campos modificados
  // similar a como lo hace freezed o el copyWith de MapState
  ProcessedItinerary copyWith({
    Itinerary? originalOtpItinerary,
    Duration? totalWalkDuration,
    Duration? walkToFirstBusStopDuration,
    BusArrivalInfo?
    representativeFirstBusETAInfo, // Podría necesitar un wrapper si se quiere setear a null explicitamente
    Duration? firstBusWaitDuration,
    bool? canReachFirstBus,
    List<ItineraryWarningType>? warnings,
    double? score,
    Map<String, ProcessedBusLegInfo>?
    processedBusLegsMap, // Podría necesitar un wrapper
    Duration? estimatedTotalDuration,
  }) {
    return ProcessedItinerary(
      originalOtpItinerary: originalOtpItinerary ?? this.originalOtpItinerary,
      totalWalkDuration: totalWalkDuration ?? this.totalWalkDuration,
      walkToFirstBusStopDuration:
          walkToFirstBusStopDuration ?? this.walkToFirstBusStopDuration,
      representativeFirstBusETAInfo:
          representativeFirstBusETAInfo ?? this.representativeFirstBusETAInfo,
      firstBusWaitDuration: firstBusWaitDuration ?? this.firstBusWaitDuration,
      canReachFirstBus: canReachFirstBus ?? this.canReachFirstBus,
      warnings: warnings ?? this.warnings,
      score: score ?? this.score,
      processedBusLegsMap: processedBusLegsMap ?? this.processedBusLegsMap,
      estimatedTotalDuration:
          estimatedTotalDuration ?? this.estimatedTotalDuration,
    );
  }
}
