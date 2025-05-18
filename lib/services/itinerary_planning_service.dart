// lib/services/itinerary_planning_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart'; // Para kDebugMode
import 'package:collection/collection.dart'; // Para firstWhereOrNull y groupBy
import 'package:graphql_flutter/graphql_flutter.dart'; // Para QueryResult
import 'package:flutter/material.dart'; // Para IconData (usado en comentarios)

// Importaciones de Modelos (individuales ya que no hay models.dart barril)
import 'package:bondi_uy/models/itinerary.dart';
import 'package:bondi_uy/models/route_leg.dart'; // Contiene Leg, LegEndpoint, etc.
import 'package:bondi_uy/models/bus_arrival_info.dart';
import 'package:bondi_uy/models/processed_itinerary.dart';
import 'package:bondi_uy/models/consolidated_itinerary.dart';
import 'package:bondi_uy/models/consolidated_itinerary_leg.dart';
import 'package:bondi_uy/models/itinerary_warning.dart';
import 'package:bondi_uy/models/leg_mode_constants.dart';
import 'package:bondi_uy/models/point_dart.dart'; // Asumiendo que esto es lo que se usa como LatLng

// Importaciones de Servicios
import 'package:bondi_uy/services/eta_fetcher_service.dart';
import 'package:bondi_uy/services/otp_service.dart';

// TODO: Implementar o encontrar TimeUtils.formatDuration para un mejor formato de duración.

class ItineraryPlanningException implements Exception {
  final String message;
  ItineraryPlanningException(this.message);

  @override
  String toString() => message;
}

class ItineraryPlanningService {
  final OtpService _otpService;
  final ETAFetcherService _etaFetcherService;

  // Margen de seguridad para llegar al bus (ej. 5 minutos en segundos)
  static const int REACH_BUS_SAFETY_MARGIN_SECONDS = 5 * 60;
  static const int MAX_UNIQUE_STOPS_FOR_ETA_LOOKUP = 3;

  ItineraryPlanningService({
    required OtpService otpService,
    required ETAFetcherService etaFetcherService,
  }) : _otpService = otpService,
       _etaFetcherService = etaFetcherService;

  Future<List<ConsolidatedItinerary>> planAndConsolidateItineraries({
    required Point_dart fromPlace,
    required Point_dart toPlace,
    required DateTime dateTime,
    required bool arriveBy,
    int? numItineraries,
  }) async {
    if (kDebugMode) {
      print(
        "[ItineraryPlanningService_DEBUG] planAndConsolidateItineraries llamado.",
      );
    }
    final List<ProcessedItinerary> processedItineraries =
        await getProcessedItineraries(
          fromPlace: fromPlace,
          toPlace: toPlace,
          dateTime: dateTime,
          arriveBy: arriveBy,
          numItineraries: numItineraries,
        );
    if (kDebugMode) {
      print(
        "[ItineraryPlanningService_DEBUG] planAndConsolidateItineraries: getProcessedItineraries completado. Número de itinerarios procesados: ${processedItineraries.length}",
      );
    }

    if (processedItineraries.isEmpty) {
      return [];
    }

    final List<ConsolidatedItinerary> consolidated = _consolidateItineraries(
      processedItineraries,
    );
    if (kDebugMode) {
      print(
        "[ItineraryPlanningService_DEBUG] planAndConsolidateItineraries: _consolidateItineraries completado. Número de itinerarios consolidados: ${consolidated.length}",
      );
    }
    return consolidated;
  }

  Future<List<ProcessedItinerary>> getProcessedItineraries({
    required Point_dart fromPlace,
    required Point_dart toPlace,
    required DateTime dateTime,
    required bool arriveBy,
    int? numItineraries,
  }) async {
    if (kDebugMode) {
      print(
        "[ItineraryPlanningService_DEBUG] getProcessedItineraries llamado.",
      );
    }

    // Formatear fecha y hora para OTP
    // Nota: OTP normalmente espera yyyy-MM-dd para la fecha y HH:mm:ss para la hora.
    // Ajustar el formato si es necesario según la implementación exacta de OTP.
    final String dateFormatted =
        "${dateTime.year.toString().padLeft(4, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}";
    final String timeFormatted =
        "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}";

    final QueryResult otpResult = await _otpService.planRoute(
      fromLat: fromPlace.lat,
      fromLon: fromPlace.lng,
      toLat: toPlace.lat,
      toLon: toPlace.lng,
      date: dateFormatted,
      time: timeFormatted,
      numItineraries: numItineraries ?? 7,
    );

    if (otpResult.hasException) {
      if (kDebugMode) {
        print(
          "[ItineraryPlanningService_ERROR] Error en la consulta OTP: ${otpResult.exception.toString()}",
        );
      }
      // Podríamos lanzar una excepción específica o devolver una lista vacía con advertencias.
      // Por ahora, devolvemos lista vacía, MapNotifier debería manejar esto.
      return [];
    }

    List<Itinerary> otpItineraries = [];
    if (otpResult.data != null &&
        otpResult.data!['plan']?['itineraries'] != null) {
      final List<dynamic> itinerariesJson =
          otpResult.data!['plan']['itineraries'];
      try {
        otpItineraries =
            itinerariesJson
                .map(
                  (dynamic item) =>
                      Itinerary.fromJson(item as Map<String, dynamic>),
                )
                .toList();
      } catch (e, s) {
        if (kDebugMode) {
          print(
            "[ItineraryPlanningService_ERROR] Error parseando itinerarios de OTP: $e\n$s",
          );
        }
        return []; // Error en parseo, devolver vacío
      }
    } else {
      if (kDebugMode) {
        print(
          "[ItineraryPlanningService_WARN] No se encontraron itinerarios en la respuesta de OTP o la estructura de datos es inesperada.",
        );
      }
    }

    if (kDebugMode) {
      print(
        "[ItineraryPlanningService_DEBUG] getProcessedItineraries: Itinerarios parseados de OTP: ${otpItineraries.length}",
      );
    }

    if (otpItineraries.isEmpty) {
      return [];
    }

    List<ProcessedItinerary> processedItineraries = [];
    final Map<String, List<BusArrivalInfo>?> stopETAsCache = {};
    final Set<String> stopIdsFetchedForETA = {};

    for (var itinerary in otpItineraries) {
      final RouteLeg? firstBusLeg = itinerary.legs.firstWhereOrNull(
        (leg) => leg.mode == LegModeConstants.bus && leg.trip?.gtfsId != null,
      );

      String? stopIdForETA;
      String? lineShortNameForETA;
      List<BusArrivalInfo>? arrivalsForThisStop;
      bool etaLookupAttempted = false;

      if (firstBusLeg != null) {
        stopIdForETA = firstBusLeg.from.stopId ?? firstBusLeg.from.stopGtfsId;
        if (stopIdForETA != null && stopIdForETA.contains(':')) {
          stopIdForETA = stopIdForETA.split(':').last;
        }
        lineShortNameForETA = firstBusLeg.route?.shortName;
      }

      if (stopIdForETA != null && stopIdForETA.isNotEmpty) {
        if (stopETAsCache.containsKey(stopIdForETA)) {
          arrivalsForThisStop = stopETAsCache[stopIdForETA];
          etaLookupAttempted = true;
          if (kDebugMode) {
            print(
              "[ItineraryPlanningService_DEBUG_CACHE] Cache hit for stop $stopIdForETA.",
            );
          }
        } else if (stopIdsFetchedForETA.length <
            MAX_UNIQUE_STOPS_FOR_ETA_LOOKUP) {
          if (kDebugMode) {
            print(
              "[ItineraryPlanningService_DEBUG_ETA_LIMIT] Attempting API fetch for new stop '$stopIdForETA'. Fetched unique stops count: ${stopIdsFetchedForETA.length} (Limit: $MAX_UNIQUE_STOPS_FOR_ETA_LOOKUP)",
            );
          }
          try {
            arrivalsForThisStop = await _etaFetcherService
                .getUpcomingBusesForStop(stopIdForETA);
            stopETAsCache[stopIdForETA] = arrivalsForThisStop;
          } catch (e, s) {
            if (kDebugMode) {
              print(
                "[ItineraryPlanningService_ERROR] Error fetching ETAs for stop '$stopIdForETA' (within limit): $e\\n$s",
              );
            }
            stopETAsCache[stopIdForETA] = null;
            arrivalsForThisStop = null;
          }
          stopIdsFetchedForETA.add(stopIdForETA);
          etaLookupAttempted = true;
        } else {
          if (kDebugMode) {
            print(
              "[ItineraryPlanningService_DEBUG_ETA_LIMIT] MAX_UNIQUE_STOPS_FOR_ETA_LOOKUP ($MAX_UNIQUE_STOPS_FOR_ETA_LOOKUP) reached. Skipping API fetch for new stop '$stopIdForETA'.",
            );
          }
          arrivalsForThisStop = null;
          etaLookupAttempted = false;
        }
      } else {
        arrivalsForThisStop = null;
        etaLookupAttempted = false;
      }

      final ProcessedItinerary processedItinerary = _processSingleItinerary(
        itinerary,
        firstBusLeg,
        stopIdForETA,
        lineShortNameForETA,
        arrivalsForThisStop,
        etaLookupAttempted,
      );
      processedItineraries.add(processedItinerary);
    }
    return processedItineraries;
  }

  ProcessedItinerary _processSingleItinerary(
    Itinerary itinerary,
    RouteLeg? firstBusLeg,
    String? stopIdForETA,
    String? lineShortNameForETA,
    List<BusArrivalInfo>? upcomingBusesAtStop,
    bool etaLookupAttempted,
  ) {
    List<ItineraryWarning> warningsObjects = [];
    int? realTimeEtaMinutes;
    String? etaMessage;
    bool canReachFirstBus = true;
    int estimatedWalkTimeToFirstBusStopSeconds = 0;
    BusArrivalInfo? targetBusArrivalInfo;

    if (firstBusLeg != null) {
      for (var leg in itinerary.legs) {
        if (leg.mode == LegModeConstants.walk) {
          estimatedWalkTimeToFirstBusStopSeconds += leg.duration.toInt();
        }
        if (leg == firstBusLeg) break;
      }
    }

    if (firstBusLeg != null &&
        stopIdForETA != null &&
        stopIdForETA.isNotEmpty &&
        lineShortNameForETA != null &&
        lineShortNameForETA.isNotEmpty) {
      if (etaLookupAttempted) {
        if (upcomingBusesAtStop == null) {
          warningsObjects.add(
            ItineraryWarning(
              type: ItineraryWarningType.ETA_API_ERROR,
              message: "Error al consultar ETA para parada $stopIdForETA.",
            ),
          );
          etaMessage = "Error al consultar ETA.";
        } else if (upcomingBusesAtStop.isEmpty) {
          warningsObjects.add(
            ItineraryWarning(
              type: ItineraryWarningType.NO_BUS_ETA_FOUND,
              message:
                  "No hay arribos disponibles en este momento para la parada $stopIdForETA.",
            ),
          );
          etaMessage = "No hay buses próximos en parada $stopIdForETA.";
        } else {
          targetBusArrivalInfo = upcomingBusesAtStop.firstWhereOrNull(
            (arrival) =>
                arrival.lineShortName == lineShortNameForETA &&
                arrival.isReal &&
                arrival.position != null,
          );
          targetBusArrivalInfo ??= upcomingBusesAtStop.firstWhereOrNull(
            (arrival) =>
                arrival.lineShortName == lineShortNameForETA && arrival.isReal,
          );
          targetBusArrivalInfo ??= upcomingBusesAtStop.firstWhereOrNull(
            (arrival) =>
                arrival.lineShortName == lineShortNameForETA &&
                arrival.position != null,
          );
          targetBusArrivalInfo ??= upcomingBusesAtStop.firstWhereOrNull(
            (arrival) => arrival.lineShortName == lineShortNameForETA,
          );

          if (targetBusArrivalInfo != null) {
            realTimeEtaMinutes = targetBusArrivalInfo!.minutesToArrival;
            final int etaSeconds = realTimeEtaMinutes * 60;
            final int timeToReachWithSafety =
                estimatedWalkTimeToFirstBusStopSeconds +
                REACH_BUS_SAFETY_MARGIN_SECONDS;

            if (timeToReachWithSafety > etaSeconds) {
              canReachFirstBus = false;
              warningsObjects.add(
                ItineraryWarning(
                  type: ItineraryWarningType.WALK_TIME_EXCEEDS_ETA,
                  message:
                      "Llegar a la parada (${Duration(seconds: estimatedWalkTimeToFirstBusStopSeconds).toString().substring(2, 7)}) + margen (${Duration(seconds: REACH_BUS_SAFETY_MARGIN_SECONDS).toString().substring(2, 7)}) toma más que el ETA del bus (${realTimeEtaMinutes} min).",
                ),
              );
              etaMessage = "Quizás no llegues al primer bus.";
            } else {
              etaMessage =
                  "Llegas bien al bus (ETA: ${realTimeEtaMinutes} min).";
            }

            if (!targetBusArrivalInfo!.isReal) {
              warningsObjects.add(
                ItineraryWarning(
                  type: ItineraryWarningType.NO_REALTIME_ETA_AVAILABLE,
                  message:
                      "ETA para línea $lineShortNameForETA es programado, no en tiempo real.",
                ),
              );
            }
          } else {
            warningsObjects.add(
              ItineraryWarning(
                type: ItineraryWarningType.NO_BUS_ETA_FOUND,
                message:
                    "No se encontró ETA para el bus ${lineShortNameForETA} en la parada ${stopIdForETA} (entre los ${upcomingBusesAtStop.length} arribos encontrados para la parada).",
              ),
            );
            etaMessage = "Verificar horarios para línea $lineShortNameForETA.";
          }
        }
      } else {
        warningsObjects.add(
          ItineraryWarning(
            type: ItineraryWarningType.ETA_LOOKUP_SKIPPED_LIMIT_REACHED,
            message:
                "Consulta de ETA omitida para parada $stopIdForETA (límite de API alcanzado).",
          ),
        );
        etaMessage = "ETA no consultado (límite API).";
      }
    } else if (firstBusLeg != null) {
      etaMessage = "Información de bus/parada incompleta para obtener ETA.";
    }

    double score = itinerary.duration.toDouble();
    if (!canReachFirstBus) {
      score += 30 * 60;
    }
    if (realTimeEtaMinutes == null && firstBusLeg != null) {
      bool skipPenalty = warningsObjects.any(
        (w) =>
            w.type == ItineraryWarningType.ETA_LOOKUP_SKIPPED_LIMIT_REACHED ||
            w.type == ItineraryWarningType.ETA_API_ERROR,
      );
      if (!skipPenalty) {
        score += 5 * 60;
      }
    }
    for (var warning in warningsObjects) {
      if (warning.type == ItineraryWarningType.NO_REALTIME_ETA_AVAILABLE)
        score += 2 * 60;
      if (warning.type == ItineraryWarningType.ETA_LOOKUP_SKIPPED_LIMIT_REACHED)
        score += 1 * 60;
      if (warning.type == ItineraryWarningType.ETA_API_ERROR) score += 4 * 60;
      if (warning.type == ItineraryWarningType.NO_BUS_ETA_FOUND)
        score += 3 * 60;
    }
    score -= itinerary.walkTime.toDouble() / 2;

    final Duration totalWalkDuration = Duration(seconds: itinerary.walkTime);
    final Duration walkToFirstBusStopDuration = Duration(
      seconds: estimatedWalkTimeToFirstBusStopSeconds,
    );

    Duration firstBusWaitDuration = Duration.zero;
    if (firstBusLeg != null &&
        targetBusArrivalInfo != null &&
        realTimeEtaMinutes != null) {
      final int etaSeconds = realTimeEtaMinutes * 60;
      final int waitSeconds =
          etaSeconds - estimatedWalkTimeToFirstBusStopSeconds;
      if (waitSeconds > 0) {
        firstBusWaitDuration = Duration(seconds: waitSeconds);
      }
    } else if (firstBusLeg != null) {
      // Si no hay ETA real, podemos estimar la espera basándonos en el startTime del leg de OTP
      // Esto es más complejo: necesitaríamos la hora actual de planificación + tiempo de caminata
      // Por ahora, si no hay ETA real, la espera podría ser incierta o basada en OTP.
      // Dejaremos Duration.zero o podríamos tomar leg.startTime - (planTime.millisecondsSinceEpoch + walkDuration)
      // Para simplificar, la dejamos en zero si no hay ETA real.
    }

    Duration estimatedTotalDuration = Duration(seconds: itinerary.duration);
    // Podríamos refinar esto: estimatedTotalDuration = walkToFirstBusStopDuration + firstBusWaitDuration + (tiempo de tramos de bus y otras caminatas/esperas de OTP)

    return ProcessedItinerary(
      originalOtpItinerary: itinerary,
      warnings: warningsObjects.map((w) => w.type).toList(),
      score: score,
      representativeFirstBusETAInfo: targetBusArrivalInfo,
      canReachFirstBus: canReachFirstBus,
      walkToFirstBusStopDuration: walkToFirstBusStopDuration,
      totalWalkDuration: totalWalkDuration,
      firstBusWaitDuration: firstBusWaitDuration,
      estimatedTotalDuration: estimatedTotalDuration,
    );
  }

  String _getNormalizedStopId(LegEndpoint endpoint) {
    // Priorizar GTFS ID si está disponible y parece un GTFS ID completo (contiene ':')
    // o si es el único disponible de los dos principales.
    if (endpoint.stopGtfsId != null && endpoint.stopGtfsId!.isNotEmpty) {
      if (endpoint.stopGtfsId!.contains(':')) {
        return endpoint.stopGtfsId!;
      } // Si no contiene ':', podría ser un ID corto de GTFS o similar al stopId de agencia
      // En este caso, si stopId también existe y es diferente (y más completo), preferir stopId.
      // Pero si stopId no existe o es igual, usar este stopGtfsId.
      if (endpoint.stopId == null ||
          endpoint.stopId!.isEmpty ||
          endpoint.stopId == endpoint.stopGtfsId) {
        return endpoint.stopGtfsId!;
      }
      // Si llegamos aquí, stopGtfsId existe pero no es completo (sin ':'), y stopId existe y es diferente.
      // Podríamos tener una heurística, pero por ahora, si stopId parece más un ID de agencia (ej. contiene ':'), usarlo.
      // Esta lógica puede necesitar ajuste basado en los datos reales.
      if (endpoint.stopId != null && endpoint.stopId!.contains(':')) {
        return endpoint.stopId!;
      }
      return endpoint
          .stopGtfsId!; // Fallback al gtfsId corto si stopId no es mejor
    }
    // Si no hay stopGtfsId, usar stopId (que podría ser el ID de agencia)
    if (endpoint.stopId != null && endpoint.stopId!.isNotEmpty) {
      return endpoint.stopId!;
    }
    // Fallback si ninguno está
    return "unknown_stop_id"; // Cambiado para más claridad
  }

  List<ConsolidatedItineraryLeg> _createFusedConsolidatedLegs(
    ProcessedItinerary representativeItinerary,
    List<ProcessedItinerary> allItinerariesInGroup,
    String?
    busSegmentKey, // Formato "SEGMENT:fromStopId>toStopId" o null si no hay bus clave
  ) {
    List<ConsolidatedItineraryLeg> finalLegs = [];

    for (RouteLeg repLeg in representativeItinerary.originalOtpItinerary.legs) {
      String? currentLegSegmentKeyForRepLeg;
      if (repLeg.mode == LegModeConstants.bus) {
        final fromStopId = _getNormalizedStopId(repLeg.from);
        final toStopId = _getNormalizedStopId(repLeg.to);
        currentLegSegmentKeyForRepLeg = "SEGMENT:$fromStopId>$toStopId";
      }

      if (repLeg.mode == LegModeConstants.bus &&
          busSegmentKey != null &&
          currentLegSegmentKeyForRepLeg == busSegmentKey) {
        // Este es el tramo de bus que se debe fusionar
        Set<String> uniqueLineNames = {};
        List<RouteLeg> collectedOriginalBusLegs = [];

        for (ProcessedItinerary procItinerary in allItinerariesInGroup) {
          // Encontrar el RouteLeg correspondiente en este procItinerary para el segmento clave
          final matchingLeg = procItinerary.originalOtpItinerary.legs
              .firstWhereOrNull(
                (l) =>
                    l.mode == LegModeConstants.bus &&
                    _getNormalizedStopId(l.from) ==
                        _getNormalizedStopId(repLeg.from) &&
                    _getNormalizedStopId(l.to) ==
                        _getNormalizedStopId(repLeg.to) &&
                    l.route?.shortName != null,
              );
          if (matchingLeg != null && matchingLeg.route?.shortName != null) {
            uniqueLineNames.add(matchingLeg.route!.shortName!);
            collectedOriginalBusLegs.add(matchingLeg);
          }
        }

        List<String> altNames = uniqueLineNames.toList()..sort();

        finalLegs.add(
          ConsolidatedItineraryLeg(
            mode: repLeg.mode,
            duration: Duration(
              seconds: repLeg.duration.toInt(),
            ), // Del representativo
            distance: repLeg.distance, // Del representativo
            from: repLeg.from, // Del representativo
            to: repLeg.to, // Del representativo
            alternativeLineShortNames: altNames.isNotEmpty ? altNames : null,
            originalBusLegs:
                collectedOriginalBusLegs.isNotEmpty
                    ? collectedOriginalBusLegs
                    : [
                      repLeg,
                    ], // Fallback al repLeg si no se colectó nada (no debería pasar si se agrupo por este segmento)
            headsign:
                repLeg.route?.shortName ??
                repLeg.route?.longName, // Del representativo
            routeColor:
                null, // TODO: Considerar lógica para el color si es necesario
          ),
        );
      } else {
        // Tramo de caminata, espera, o un tramo de bus que no es el fusionado
        // (o si busSegmentKey es null, ej. para itinerarios "NO_BUS_LEG")
        List<String>? alternativeNamesForNonFusedBusLeg;
        List<RouteLeg> originalLegsForNonFusedBusLeg = [];

        if (repLeg.mode == LegModeConstants.bus) {
          originalLegsForNonFusedBusLeg.add(repLeg);
          if (repLeg.route?.shortName != null) {
            alternativeNamesForNonFusedBusLeg = [repLeg.route!.shortName!];
          }
        }

        finalLegs.add(
          ConsolidatedItineraryLeg(
            mode: repLeg.mode,
            duration: Duration(seconds: repLeg.duration.toInt()),
            distance: repLeg.distance,
            from: repLeg.from,
            to: repLeg.to,
            headsign:
                repLeg.route?.shortName ??
                repLeg.route?.longName, // Para tramos de bus
            originalBusLegs: originalLegsForNonFusedBusLeg,
            alternativeLineShortNames: alternativeNamesForNonFusedBusLeg,
            routeColor: null,
          ),
        );
      }
    }
    return finalLegs;
  }

  List<ConsolidatedItinerary> _consolidateItineraries(
    List<ProcessedItinerary> processedItineraries,
  ) {
    if (processedItineraries.isEmpty) return [];

    var groupedByFirstBusSegment = groupBy<ProcessedItinerary, String>(
      processedItineraries,
      (itinerary) {
        final firstBusLeg = itinerary.originalOtpItinerary.legs
            .firstWhereOrNull((leg) => leg.mode == LegModeConstants.bus);
        if (firstBusLeg != null) {
          final fromStopId = _getNormalizedStopId(firstBusLeg.from);
          final toStopId = _getNormalizedStopId(firstBusLeg.to);
          return "SEGMENT:$fromStopId>$toStopId";
        }
        return "NO_BUS_LEG:${itinerary.originalOtpItinerary.hashCode}";
      },
    );

    List<ConsolidatedItinerary> consolidatedItineraries = [];

    groupedByFirstBusSegment.forEach((key, itinerariesInGroup) {
      if (itinerariesInGroup.isEmpty) return;

      itinerariesInGroup.sort((a, b) => a.score.compareTo(b.score));
      ProcessedItinerary representativeProcessedItineraryForGroup =
          itinerariesInGroup.first;

      List<ConsolidatedItineraryLeg> finalConsolidatedLegs;
      List<BusArrivalInfo> etasForFusedSegment = [];

      if (key.startsWith("NO_BUS_LEG:")) {
        finalConsolidatedLegs = _createFusedConsolidatedLegs(
          representativeProcessedItineraryForGroup,
          itinerariesInGroup,
          null,
        );
        if (representativeProcessedItineraryForGroup
                .representativeFirstBusETAInfo !=
            null) {
          etasForFusedSegment.add(
            representativeProcessedItineraryForGroup
                .representativeFirstBusETAInfo!,
          );
        }
      } else {
        finalConsolidatedLegs = _createFusedConsolidatedLegs(
          representativeProcessedItineraryForGroup,
          itinerariesInGroup,
          key,
        );
        for (var procItin in itinerariesInGroup) {
          final firstBusLegOfProcItin = procItin.originalOtpItinerary.legs
              .firstWhereOrNull((l) => l.mode == LegModeConstants.bus);
          if (firstBusLegOfProcItin != null &&
              procItin.representativeFirstBusETAInfo != null) {
            final fromStopIdProc = _getNormalizedStopId(
              firstBusLegOfProcItin.from,
            );
            final toStopIdProc = _getNormalizedStopId(firstBusLegOfProcItin.to);
            if (key == "SEGMENT:$fromStopIdProc>$toStopIdProc") {
              etasForFusedSegment.add(procItin.representativeFirstBusETAInfo!);
            }
          }
        }
        etasForFusedSegment = etasForFusedSegment.toSet().toList();
        etasForFusedSegment.sort(
          (a, b) => a.minutesToArrival.compareTo(b.minutesToArrival),
        );
      }

      consolidatedItineraries.add(
        ConsolidatedItinerary(
          id: key,
          legs: finalConsolidatedLegs,
          representativeProcessedItinerary:
              representativeProcessedItineraryForGroup,
          originalProcessedItineraries: itinerariesInGroup,
          estimatedTotalDuration:
              representativeProcessedItineraryForGroup.estimatedTotalDuration,
          totalWalkDuration:
              representativeProcessedItineraryForGroup.totalWalkDuration,
          walkToFirstBusStopDuration:
              representativeProcessedItineraryForGroup
                  .walkToFirstBusStopDuration,
          firstBusWaitDuration:
              representativeProcessedItineraryForGroup.firstBusWaitDuration,
          representativeFirstBusETAInfo:
              representativeProcessedItineraryForGroup
                  .representativeFirstBusETAInfo,
          alternativeFirstBusETAs: etasForFusedSegment,
          canReachFirstBus:
              representativeProcessedItineraryForGroup.canReachFirstBus,
          warnings: representativeProcessedItineraryForGroup.warnings,
          score: representativeProcessedItineraryForGroup.score,
        ),
      );
    });

    consolidatedItineraries.sort(
      (a, b) => a.representativeProcessedItinerary.score.compareTo(
        b.representativeProcessedItinerary.score,
      ),
    );

    return consolidatedItineraries;
  }
}
