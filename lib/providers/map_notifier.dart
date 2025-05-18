// lib/providers/map_notifier.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:bondi_uy/models/consolidated_itinerary.dart';
import 'package:bondi_uy/models/consolidated_itinerary_leg.dart';
import 'package:bondi_uy/models/itinerary.dart';
import 'package:bondi_uy/models/route_leg.dart';
import 'package:bondi_uy/models/leg_mode_constants.dart';
import 'package:bondi_uy/services/itinerary_planning_service.dart';
import 'package:bondi_uy/services/mapbox_service.dart'; // Necesario para los parámetros de método
import 'package:bondi_uy/state/map_state.dart';
import 'package:bondi_uy/providers/service_providers.dart';
import 'package:bondi_uy/controllers/bus_tracking_controller.dart'; // Necesario para los parámetros de método
import 'package:bondi_uy/models/point_dart.dart';
import 'package:bondi_uy/models/bus_arrival_info.dart'; // Asegurar importación

// Riverpod provider para el MapNotifier
final mapNotifierProvider = StateNotifierProvider<MapNotifier, MapState>((ref) {
  final itineraryPlanningService = ref.watch(itineraryPlanningServiceProvider);
  return MapNotifier(ref, itineraryPlanningService);
});

class MapNotifier extends StateNotifier<MapState> {
  final Ref _ref;
  final ItineraryPlanningService _itineraryPlanningService;
  Timer? _manualMoveCooldownTimer;

  MapNotifier(this._ref, this._itineraryPlanningService) : super(MapState());

  // --- Gestión de estado de interacción del mapa ---
  void mapInteractionStarted() {
    _manualMoveCooldownTimer?.cancel();
    if (state.userMapInteraction !=
        UserMapInteractionState.manualMoveInProgress) {
      print(
        "[MapNotifier_DEBUG] mapInteractionStarted: Setting state to manualMoveInProgress",
      );
      state = state.copyWith(
        userMapInteraction: UserMapInteractionState.manualMoveInProgress,
      );
    }
  }

  void mapInteractionEnded() {
    _manualMoveCooldownTimer?.cancel();
    print(
      "[MapNotifier_DEBUG] mapInteractionEnded: Setting state to manualMoveCooldown and starting timer",
    );
    state = state.copyWith(
      userMapInteraction: UserMapInteractionState.manualMoveCooldown,
    );
    _manualMoveCooldownTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted &&
          state.userMapInteraction ==
              UserMapInteractionState.manualMoveCooldown) {
        print("[MapNotifier_DEBUG] Cooldown ended. Setting state to idle.");
        state = state.copyWith(
          userMapInteraction: UserMapInteractionState.idle,
        );
        _triggerAutoZoomLogic();
      }
    });
  }

  void _triggerAutoZoomLogic() {
    print("[MapNotifier_DEBUG] _triggerAutoZoomLogic called.");
    if (state.userMapInteraction == UserMapInteractionState.idle) {
      if (state.selectedConsolidatedItinerary != null) {
        if (state.currentLegIndex != null &&
            state.currentDisplayMode == MapDisplayMode.legTracking) {
          print("[MapNotifier_DEBUG] AutoZoom: Leg selected, target: leg");
          state = state.copyWith(currentZoomTarget: ZoomTargetType.leg);
        } else if (state.currentDisplayMode == MapDisplayMode.routeOverview) {
          print(
            "[MapNotifier_DEBUG] AutoZoom: Route overview, target: overview",
          );
          state = state.copyWith(currentZoomTarget: ZoomTargetType.overview);
        } else {
          if (state.currentLegIndex != null) {
            state = state.copyWith(currentZoomTarget: ZoomTargetType.leg);
          } else {
            state = state.copyWith(currentZoomTarget: ZoomTargetType.overview);
          }
        }
      } else if (state.origin != null && state.destination != null) {
        if (state.currentDisplayMode != MapDisplayMode.blank &&
            state.currentZoomTarget != ZoomTargetType.points) {
          print(
            "[MapNotifier_DEBUG] AutoZoom: Origin and Destino set, target: points",
          );
          state = state.copyWith(currentZoomTarget: ZoomTargetType.points);
        }
      } else if (state.origin != null) {
        // No hacer zoom a origenSelection automáticamente aquí para evitar zoom al escribir/seleccionar.
        // Este tipo de zoom debería ser más explícito.
        // print(
        //   "[MapNotifier_DEBUG] AutoZoom: Origin set, target: origenSelection",
        // );
        // state = state.copyWith(
        //   currentZoomTarget: ZoomTargetType.origenSelection,
        // );
      } else if (state.destination != null) {
        // No hacer zoom a destinationSelection automáticamente aquí.
        // print(
        //   "[MapNotifier_DEBUG] AutoZoom: Destino set, target: destinationSelection",
        // );
        // state = state.copyWith(
        //   currentZoomTarget: ZoomTargetType.destinationSelection,
        // );
      } else {
        print(
          "[MapNotifier_DEBUG] AutoZoom: No specific state, target: initial",
        );
        state = state.copyWith(currentZoomTarget: ZoomTargetType.initial);
      }
    } else {
      print(
        "[MapNotifier_DEBUG] _triggerAutoZoomLogic: User is interacting (state: ${state.userMapInteraction}), no auto zoom.",
      );
    }
  }

  // --- Gestión de Origen y Destino ---
  void setOrigin(
    Position? position,
    String? address,
    MapboxService mapboxService,
    BusTrackingController busTrackingController,
  ) {
    final bool hadDestination = state.destination != null;
    state = state.copyWith(
      origin: position,
      originAddress: address,
      currentDisplayMode:
          position == null
              ? (state.destination == null
                  ? MapDisplayMode.blank
                  : MapDisplayMode.destinationSelected)
              : (hadDestination
                  ? MapDisplayMode.routeOverview
                  : MapDisplayMode.originSelected),
    );
    if (position == null && state.selectedConsolidatedItinerary != null) {
      clearRouteState(
        mapboxService,
        busTrackingController,
        preserveOriginAndDestination: state.destination != null,
      );
    }
    _triggerAutoZoomLogic();
  }

  void setDestination(
    Position? position,
    String? address,
    MapboxService mapboxService,
    BusTrackingController busTrackingController,
  ) {
    final bool hadOrigin = state.origin != null;
    state = state.copyWith(
      destination: position,
      destinationAddress: address,
      currentDisplayMode:
          position == null
              ? (state.origin == null
                  ? MapDisplayMode.blank
                  : MapDisplayMode.originSelected)
              : (hadOrigin
                  ? MapDisplayMode.routeOverview
                  : MapDisplayMode.destinationSelected),
    );
    if (position == null && state.selectedConsolidatedItinerary != null) {
      clearRouteState(
        mapboxService,
        busTrackingController,
        preserveOriginAndDestination: state.origin != null,
      );
    }
    _triggerAutoZoomLogic();
  }

  void clearOrigin(
    MapboxService mapboxService,
    BusTrackingController busTrackingController,
  ) {
    state = state.copyWith(
      clearOrigin: true,
      clearOriginAddress: true,
      currentDisplayMode:
          state.destination == null
              ? MapDisplayMode.blank
              : MapDisplayMode.destinationSelected,
      currentZoomTarget:
          state.destination == null
              ? ZoomTargetType.initial
              : ZoomTargetType.destinationSelection,
    );
    if (state.destination == null) {
      clearRouteState(mapboxService, busTrackingController);
    }
    _triggerAutoZoomLogic();
  }

  void clearDestination(
    MapboxService mapboxService,
    BusTrackingController busTrackingController,
  ) {
    state = state.copyWith(
      clearDestination: true,
      clearDestinationAddress: true,
      currentDisplayMode:
          state.origin == null
              ? MapDisplayMode.blank
              : MapDisplayMode.originSelected,
      currentZoomTarget:
          state.origin == null
              ? ZoomTargetType.initial
              : ZoomTargetType.origenSelection,
    );
    if (state.origin == null) {
      clearRouteState(mapboxService, busTrackingController);
    }
    _triggerAutoZoomLogic();
  }

  void swapOriginAndDestination(
    MapboxService mapboxService,
    BusTrackingController busTrackingController,
  ) {
    if (state.origin != null && state.destination != null) {
      final Position tempOrigin = state.origin!;
      final String? tempOriginAddress = state.originAddress;

      state = state.copyWith(
        origin: state.destination,
        originAddress: state.destinationAddress,
        destination: tempOrigin,
        destinationAddress: tempOriginAddress,
        currentDisplayMode: MapDisplayMode.routeOverview,
        currentZoomTarget: ZoomTargetType.points,
      );
      planRoute(
        mapboxService,
        busTrackingController,
        from: state.origin,
        to: state.destination,
      );
    }
  }

  // --- Planificación de Rutas ---
  Future<void> planRoute(
    MapboxService mapboxService,
    BusTrackingController busTrackingController, {
    Position? from,
    Position? to,
    bool avoidRecentClear = false,
  }) async {
    final originPos = from ?? state.origin;
    final destinationPos = to ?? state.destination;

    if (originPos == null || destinationPos == null) {
      print("[MapNotifier_ERROR] planRoute: Origen o destino nulos.");
      state = state.copyWith(planningStatus: PlanningStatus.error);
      return;
    }

    if (!avoidRecentClear) {
      clearRouteState(
        mapboxService,
        busTrackingController,
        preserveOriginAndDestination: true,
      );
    }

    state = state.copyWith(planningStatus: PlanningStatus.loading);

    try {
      print(
        "[MapNotifier_DEBUG] planRoute: Preparando puntos y DateTime para ItineraryPlanningService...",
      );
      final fromPoint = Point_dart(
        lat: originPos.lat!.toDouble(),
        lng: originPos.lng!.toDouble(),
      );
      final toPoint = Point_dart(
        lat: destinationPos.lat!.toDouble(),
        lng: destinationPos.lng!.toDouble(),
      );
      final dateTime = DateTime.now();

      print(
        "[MapNotifier_DEBUG] planRoute: Llamando a _itineraryPlanningService.planAndConsolidateItineraries...",
      );
      final consolidatedItineraries = await _itineraryPlanningService
          .planAndConsolidateItineraries(
            fromPlace: fromPoint,
            toPlace: toPoint,
            dateTime: dateTime,
            arriveBy: false,
          );

      // ----- INICIO: PRINT DETALLADO DE CONSOLIDATED ITINERARIES -----
      if (consolidatedItineraries.isNotEmpty) {
        print(
          "[MapNotifier_USER_ANALYSIS] ---- INICIO OPCIONES DE RUTA CONSOLIDADAS ----",
        );
        for (int i = 0; i < consolidatedItineraries.length; i++) {
          final ci = consolidatedItineraries[i];
          print("[MapNotifier_USER_ANALYSIS] Opción Consolidada #${i + 1}:");
          print("[MapNotifier_USER_ANALYSIS]   ID: ${ci.id}");
          print("[MapNotifier_USER_ANALYSIS]   Score: ${ci.score}");
          print(
            "[MapNotifier_USER_ANALYSIS]   Estimated Total Duration: ${ci.estimatedTotalDuration}",
          );
          print(
            "[MapNotifier_USER_ANALYSIS]   Total Walk Duration: ${ci.totalWalkDuration}",
          );
          print(
            "[MapNotifier_USER_ANALYSIS]   Walk to First Bus Stop: ${ci.walkToFirstBusStopDuration}",
          );
          print(
            "[MapNotifier_USER_ANALYSIS]   First Bus Wait Duration: ${ci.firstBusWaitDuration}",
          );
          print(
            "[MapNotifier_USER_ANALYSIS]   Can Reach First Bus: ${ci.canReachFirstBus}",
          );
          print(
            "[MapNotifier_USER_ANALYSIS]   Warnings: ${ci.warnings.map((w) => w.name).toList()}",
          );
          if (ci.representativeFirstBusETAInfo != null) {
            final eta = ci.representativeFirstBusETAInfo!;
            print(
              "[MapNotifier_USER_ANALYSIS]   Rep. First Bus ETA: ${eta.minutesToArrival} min, Real: ${eta.isReal}, Line: ${eta.lineShortName}",
            );
          } else {
            print("[MapNotifier_USER_ANALYSIS]   Rep. First Bus ETA: N/A");
          }
          print("[MapNotifier_USER_ANALYSIS]   Legs (${ci.legs.length}):");
          for (int j = 0; j < ci.legs.length; j++) {
            final leg = ci.legs[j];
            print(
              "[MapNotifier_USER_ANALYSIS]     Leg #${j + 1}: Mode: ${leg.mode}, Duration: ${leg.duration}, Distance: ${leg.distance}",
            );
            print(
              "[MapNotifier_USER_ANALYSIS]       From: ${leg.from.name} (StopID: ${leg.from.stopId ?? leg.from.stopGtfsId ?? 'N/A'}) To: ${leg.to.name} (StopID: ${leg.to.stopId ?? leg.to.stopGtfsId ?? 'N/A'})",
            );
            if (leg.mode == LegModeConstants.bus) {
              print(
                "[MapNotifier_USER_ANALYSIS]         Headsign: ${leg.headsign ?? 'N/A'}",
              );
              print(
                "[MapNotifier_USER_ANALYSIS]         Alternative Lines: ${leg.alternativeLineShortNames}",
              );
              print(
                "[MapNotifier_USER_ANALYSIS]         Original Bus Legs Count: ${leg.originalBusLegs.length}",
              );
            }
          }
          print(
            "[MapNotifier_USER_ANALYSIS]   Representative Processed Itinerary OTP StartTime: ${DateTime.fromMillisecondsSinceEpoch(ci.representativeProcessedItinerary.originalOtpItinerary.startTime)}",
          );
        }
        print(
          "[MapNotifier_USER_ANALYSIS] ---- FIN OPCIONES DE RUTA CONSOLIDADAS ----",
        );
      } else {
        print(
          "[MapNotifier_USER_ANALYSIS] No se generaron opciones de ruta consolidadas.",
        );
      }
      // ----- FIN: PRINT DETALLADO DE CONSOLIDATED ITINERARIES ------

      if (consolidatedItineraries.isEmpty) {
        print(
          "[MapNotifier_WARN] planRoute: No se encontraron itinerarios consolidados.",
        );
        state = state.copyWith(
          planningStatus: PlanningStatus.error,
          consolidatedItineraries: [],
          currentDisplayMode: MapDisplayMode.routeOverview,
          realtimeTrackingAvailable: true,
          realtimeTrackingAttempted: false,
        );
      } else {
        state = state.copyWith(
          consolidatedItineraries: consolidatedItineraries,
          planningStatus: PlanningStatus.success,
          currentDisplayMode: MapDisplayMode.routeOverview,
          currentZoomTarget: ZoomTargetType.points,
          realtimeTrackingAvailable: true,
          realtimeTrackingAttempted: false,
        );
      }
    } catch (e, s) {
      print("[MapNotifier_ERROR] Error CATCH en planRoute: $e\n$s");
      state = state.copyWith(
        planningStatus: PlanningStatus.error,
        realtimeTrackingAvailable: true,
        realtimeTrackingAttempted: false,
      );
    }
    _triggerAutoZoomLogic();
  }

  void clearRouteState(
    MapboxService mapboxService,
    BusTrackingController busTrackingController, {
    bool preserveOriginAndDestination = false,
  }) {
    print("[MapNotifier_DEBUG] clearRouteState llamado.");

    mapboxService.clearRoute();
    mapboxService.clearHighlightedStop();
    mapboxService.toggleGeneralStopsVisibility(true);
    busTrackingController.stopTrackingBusLine();

    state = state.copyWith(
      consolidatedItineraries: [],
      clearSelectedConsolidatedItinerary: true,
      clearRepresentativeItinerary: true,
      clearRepresentativeFirstBusETAInfo: true,
      planningStatus: PlanningStatus.idle,
      clearCurrentLegIndex: true,
      showInstructionsPanel: false,
      clearTrackedBusLineShortName: true,
      currentDisplayMode:
          (preserveOriginAndDestination &&
                  state.origin != null &&
                  state.destination != null)
              ? MapDisplayMode.routeOverview
              : MapDisplayMode.blank,
      currentZoomTarget:
          (preserveOriginAndDestination &&
                  state.origin != null &&
                  state.destination != null)
              ? ZoomTargetType.points
              : ZoomTargetType.initial,
      realtimeTrackingAvailable: false,
      realtimeTrackingAttempted: false,
    );

    if (!preserveOriginAndDestination) {
      state = state.copyWith(
        clearOrigin: true,
        clearDestination: true,
        clearOriginAddress: true,
        clearDestinationAddress: true,
      );
    }
    print(
      "[MapNotifier_DEBUG] clearRouteState: Estado final: displayMode=${state.currentDisplayMode}, zoomTarget=${state.currentZoomTarget}",
    );
    _triggerAutoZoomLogic();
  }

  void processSelectedItinerary(
    ConsolidatedItinerary selectedItinerary,
    MapboxService mapboxService,
    BusTrackingController? busTrackingController,
  ) {
    print(
      "[MapNotifier_DEBUG] processSelectedItinerary called with ConsolidatedItinerary ID: ${selectedItinerary.id}",
    );
    final Itinerary? itinerary =
        selectedItinerary
            .representativeProcessedItinerary
            ?.originalOtpItinerary;

    if (itinerary == null) {
      print(
        "[MapNotifier_ERROR] Itinerario representativo es nulo en ConsolidatedItinerary.",
      );
      state = state.copyWith(planningStatus: PlanningStatus.error);
      return;
    }

    mapboxService.drawRoute(itinerary, isOverview: true);

    final BusArrivalInfo? representativeETA =
        selectedItinerary.representativeFirstBusETAInfo;

    // Encuentra el primer ConsolidatedItineraryLeg de tipo BUS
    ConsolidatedItineraryLeg? firstConsolidatedBusLeg;
    try {
      firstConsolidatedBusLeg = selectedItinerary.legs.firstWhere(
        (leg) => leg.mode == LegModeConstants.bus,
      );
    } catch (e) {
      firstConsolidatedBusLeg = null; // No se encontró o la lista estaba vacía
    }

    // De ese tramo consolidado, obtén el primer RouteLeg original (si existe)
    final RouteLeg? actualFirstRouteLegForTracking =
        firstConsolidatedBusLeg?.originalBusLegs.isNotEmpty == true
            ? firstConsolidatedBusLeg!.originalBusLegs.first
            : null;

    state = state.copyWith(
      selectedConsolidatedItinerary: selectedItinerary,
      representativeItinerary: itinerary,
      representativeFirstBusETAInfo: representativeETA,
      currentDisplayMode: MapDisplayMode.routeOverview,
      currentZoomTarget: ZoomTargetType.overview,
      showInstructionsPanel: false,
      clearCurrentLegIndex: true,
      realtimeTrackingAvailable: representativeETA?.isReal ?? false,
      realtimeTrackingAttempted: true,
      clearTrackedBusLineShortName: true,
    );
    print(
      "[MapNotifier_DEBUG] processSelectedItinerary: Updated state. TrackedLineName: ${state.trackedBusLineShortName}, ZoomTarget: ${state.currentZoomTarget}, RealtimeAvailable: ${state.realtimeTrackingAvailable}, RealtimeAttempted: ${state.realtimeTrackingAttempted}, RepETA: ${state.representativeFirstBusETAInfo?.minutesToArrival} min, Real: ${state.representativeFirstBusETAInfo?.isReal}",
    );

    if (busTrackingController == null) {
      print(
        "[MapNotifier_DEBUG_TRACKING] processSelectedItinerary: busTrackingController is NULL. Cannot start/stop tracking.",
      );
    } else {
      print(
        "[MapNotifier_DEBUG_TRACKING] processSelectedItinerary: busTrackingController is available. Stopping previous tracking (if any).",
      );
      busTrackingController.stopTrackingBusLine();

      // Condición más explícita para iniciar el seguimiento
      if (state.realtimeTrackingAvailable &&
          actualFirstRouteLegForTracking != null && // USA EL RouteLeg OBTENIDO
          representativeETA != null &&
          representativeETA.isReal &&
          representativeETA.position != null) {
        // Asegurarse que hay posición
        print(
          "[MapNotifier_DEBUG_TRACKING] processSelectedItinerary: Realtime available. Attempting to start tracking. FirstBusLeg from: ${actualFirstRouteLegForTracking.from.name} to ${actualFirstRouteLegForTracking.to.name}, Line: ${representativeETA.lineShortName}, ETA: ${representativeETA.minutesToArrival} mins, Real: ${representativeETA.isReal}, Pos: ${representativeETA.position?.toJson()}",
        );
        busTrackingController.startTrackingBusLine(
          actualFirstRouteLegForTracking, // USA EL RouteLeg OBTENIDO
          representativeETA,
        );
      } else {
        print(
          "[MapNotifier_DEBUG_TRACKING] processSelectedItinerary: Realtime NOT available or missing critical data to start tracking.",
        );
        print(
          "[MapNotifier_DEBUG_TRACKING]   - state.realtimeTrackingAvailable: ${state.realtimeTrackingAvailable}",
        );
        print(
          "[MapNotifier_DEBUG_TRACKING]   - actualFirstRouteLegForTracking is null: ${actualFirstRouteLegForTracking == null}",
        );
        if (actualFirstRouteLegForTracking != null) {
          print(
            "[MapNotifier_DEBUG_TRACKING]     - actualFirstRouteLegForTracking from: ${actualFirstRouteLegForTracking.from.name} to ${actualFirstRouteLegForTracking.to.name}",
          );
        }
        print(
          "[MapNotifier_DEBUG_TRACKING]   - representativeETA is null: ${representativeETA == null}",
        );
        if (representativeETA != null) {
          print(
            "[MapNotifier_DEBUG_TRACKING]     - representativeETA.isReal: ${representativeETA.isReal}",
          );
          print(
            "[MapNotifier_DEBUG_TRACKING]     - representativeETA.lineShortName: ${representativeETA.lineShortName}",
          );
          print(
            "[MapNotifier_DEBUG_TRACKING]     - representativeETA.minutesToArrival: ${representativeETA.minutesToArrival}",
          );
          print(
            "[MapNotifier_DEBUG_TRACKING]     - representativeETA.position: ${representativeETA.position?.toJson()}",
          );
        }
      }
    }

    _triggerAutoZoomLogic();
  }

  // --- Interacción con Tramos de la Ruta (Legs) ---
  void setSelectedLegIndex(
    int index,
    MapboxService mapboxService,
    BusTrackingController busTrackingController, {
    bool isFromTap = false,
  }) {
    if (state.representativeItinerary == null ||
        index < 0 ||
        index >= state.representativeItinerary!.legs.length) {
      return;
    }

    final currentLeg = state.representativeItinerary!.legs[index];

    if (isFromTap &&
        state.currentDisplayMode == MapDisplayMode.routeOverview &&
        currentLeg.mode == LegModeConstants.bus) {
      switchToLegTracking(index, mapboxService, busTrackingController);
    } else {
      mapboxService.highlightLeg(state.representativeItinerary!, index);
      state = state.copyWith(
        currentLegIndex: index,
        currentZoomTarget: ZoomTargetType.leg,
      );
      if (state.currentDisplayMode != MapDisplayMode.legTracking &&
          state.currentDisplayMode !=
              MapDisplayMode.routeStaticWithInstructions) {}
      _triggerAutoZoomLogic();
    }
  }

  void switchToLegTracking(
    int legIndex,
    MapboxService mapboxService,
    BusTrackingController busTrackingController,
  ) {
    print(
      "[MapNotifier_DEBUG] switchToLegTracking llamado para el índice: $legIndex",
    );
    if (state.representativeItinerary == null ||
        legIndex < 0 ||
        legIndex >= state.representativeItinerary!.legs.length) {
      print(
        "[MapNotifier_ERROR] switchToLegTracking: Itinerario no seleccionado o índice fuera de rango.",
      );
      return;
    }

    final leg = state.representativeItinerary!.legs[legIndex];

    mapboxService.highlightLeg(state.representativeItinerary!, legIndex);

    if (leg.mode == LegModeConstants.bus && leg.route != null) {
      if (state.realtimeTrackingAttempted && !state.realtimeTrackingAvailable) {
        print(
          "[MapNotifier_INFO] switchToLegTracking: Seguimiento en tiempo real NO disponible para este tramo de bus (previamente intentado y fallido).",
        );
        busTrackingController.stopTrackingBusLine();
        state = state.copyWith(
          currentLegIndex: legIndex,
          currentDisplayMode: MapDisplayMode.routeStaticWithInstructions,
          showInstructionsPanel: true,
          currentZoomTarget: ZoomTargetType.leg,
          clearTrackedBusLineShortName: true,
        );
        _triggerAutoZoomLogic();
        return;
      }

      print(
        "[MapNotifier_INFO] switchToLegTracking: Intentando iniciar seguimiento para tramo de bus.",
      );
      busTrackingController.startTrackingBusLine(
        leg,
        state.representativeFirstBusETAInfo,
      );

      state = state.copyWith(
        currentLegIndex: legIndex,
        currentDisplayMode: MapDisplayMode.legTracking,
        currentZoomTarget: ZoomTargetType.leg,
        showInstructionsPanel: true,
      );
    } else {
      print(
        "[MapNotifier_INFO] switchToLegTracking: Tramo no es de bus. Deteniendo seguimiento y mostrando como estático.",
      );
      busTrackingController.stopTrackingBusLine();
      state = state.copyWith(
        currentLegIndex: legIndex,
        currentDisplayMode: MapDisplayMode.routeStaticWithInstructions,
        currentZoomTarget: ZoomTargetType.leg,
        showInstructionsPanel: true,
        clearTrackedBusLineShortName: true,
        realtimeTrackingAvailable: false,
        realtimeTrackingAttempted: true,
      );
    }
    _triggerAutoZoomLogic();
  }

  // --- Gestión de Seguimiento en Tiempo Real (Actualizado por BusTrackingController) ---
  void updateRealtimeTrackingStatus(bool available, bool attempted) {
    if (state.realtimeTrackingAvailable != available ||
        state.realtimeTrackingAttempted != attempted) {
      state = state.copyWith(
        realtimeTrackingAvailable: available,
        realtimeTrackingAttempted: attempted,
      );
      print(
        "[MapNotifier_DEBUG] updateRealtimeTrackingStatus: available=$available, attempted=$attempted",
      );
    }
  }

  void setTrackedBusLineShortName(String? lineShortName) {
    if (state.trackedBusLineShortName != lineShortName) {
      state = state.copyWith(
        trackedBusLineShortName: lineShortName,
        clearTrackedBusLineShortName: lineShortName == null,
      );
      print(
        "[MapNotifier_DEBUG] setTrackedBusLineShortName called with: $lineShortName",
      );
    }
  }

  // --- Simulación de Bus y Actualización de UI ---
  void updateBusSimulationState({
    Position? newRealDebugBusPosition,
    bool clearRealDebugBusPosition = false,
    int? newEtaMinutes,
    bool clearEtaMinutes = false,
    Position? newSimulatedBusPosition,
    bool clearSimulatedBusPosition = false,
    double? newBusSpeedMetersPerSecond,
    bool clearBusSpeedMetersPerSecond = false,
    DateTime? newLastSpeedCalculationTime,
    bool clearLastSpeedCalculationTime = false,
    Position? newSimulationSegmentOriginPoint,
    bool clearSimulationSegmentOriginPoint = false,
    double? newMaxSimulationTravelDistance,
    bool clearMaxSimulationTravelDistance = false,
  }) {
    state = state.copyWith(
      realDebugBusPosition:
          clearRealDebugBusPosition ? null : newRealDebugBusPosition,
      realDebugEtaMinutes: clearEtaMinutes ? null : newEtaMinutes,
      simulatedBusPosition:
          clearSimulatedBusPosition ? null : newSimulatedBusPosition,
      busSpeedMetersPerSecond:
          clearBusSpeedMetersPerSecond ? null : newBusSpeedMetersPerSecond,
      lastSpeedCalculationTime:
          clearLastSpeedCalculationTime ? null : newLastSpeedCalculationTime,
      simulationSegmentOriginPoint:
          clearSimulationSegmentOriginPoint
              ? null
              : newSimulationSegmentOriginPoint,
      maxSimulationTravelDistance:
          clearMaxSimulationTravelDistance
              ? null
              : newMaxSimulationTravelDistance,
    );
  }

  void clearHighlightedBusMarkerAndSegment() {
    state = state.copyWith(
      clearRealDebugBusPosition: true,
      clearRealDebugEtaMinutes: true,
    );
  }

  // --- Otros ---
  void forceMapIdleAndZoomTo(
    ZoomTargetType target, {
    CameraOptions? cameraOptions,
  }) {
    mapInteractionEnded();
    _manualMoveCooldownTimer?.cancel();
    state = state.copyWith(
      userMapInteraction: UserMapInteractionState.idle,
      currentZoomTarget: target,
      currentCameraOptions: cameraOptions ?? state.currentCameraOptions,
    );
    print(
      "[MapNotifier_DEBUG] forceMapIdleAndZoomTo called with target: $target",
    );
  }

  void storeCurrentCameraOptions(CameraOptions options) {
    state = state.copyWith(currentCameraOptions: options);
  }

  void toggleInstructionsPanel(bool show) {
    state = state.copyWith(showInstructionsPanel: show);
    if (show &&
        state.currentDisplayMode != MapDisplayMode.legTracking &&
        state.currentDisplayMode !=
            MapDisplayMode.routeStaticWithInstructions) {
      state = state.copyWith(
        currentDisplayMode: MapDisplayMode.routeStaticWithInstructions,
      );
      if (state.currentLegIndex != null) {
        state = state.copyWith(currentZoomTarget: ZoomTargetType.leg);
      } else {
        state = state.copyWith(currentZoomTarget: ZoomTargetType.overview);
      }
      _triggerAutoZoomLogic();
    }
  }

  // LLAMADO DESDE BusTrackingController cuando obtiene un nuevo ETA en tiempo real
  void updateRepresentativeETA(BusArrivalInfo newEtaInfo) {
    print(
      "[MapNotifier_DEBUG] updateRepresentativeETA llamado. Nueva ETA para línea ${newEtaInfo.lineShortName}: ${newEtaInfo.minutesToArrival} min",
    );
    // Actualizar el ETA representativo en el estado general
    state = state.copyWith(representativeFirstBusETAInfo: newEtaInfo);

    if (state.selectedConsolidatedItinerary != null) {
      final oldConsolidated = state.selectedConsolidatedItinerary!;
      final newConsolidated = ConsolidatedItinerary(
        id: oldConsolidated.id,
        legs: oldConsolidated.legs,
        representativeProcessedItinerary:
            oldConsolidated.representativeProcessedItinerary,
        score: oldConsolidated.score,
        estimatedTotalDuration: oldConsolidated.estimatedTotalDuration,
        totalWalkDuration: oldConsolidated.totalWalkDuration,
        walkToFirstBusStopDuration: oldConsolidated.walkToFirstBusStopDuration,
        firstBusWaitDuration: oldConsolidated.firstBusWaitDuration,
        canReachFirstBus: oldConsolidated.canReachFirstBus,
        warnings: oldConsolidated.warnings,
        representativeFirstBusETAInfo: newEtaInfo,
        alternativeFirstBusETAs: oldConsolidated.alternativeFirstBusETAs,
        originalProcessedItineraries:
            oldConsolidated.originalProcessedItineraries,
      );
      state = state.copyWith(selectedConsolidatedItinerary: newConsolidated);
      print(
        "[MapNotifier_DEBUG] selectedConsolidatedItinerary también actualizado con el nuevo ETA.",
      );
    }
  }

  @override
  void dispose() {
    _manualMoveCooldownTimer?.cancel();
    super.dispose();
  }
}
