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
import 'package:bondi_uy/controllers/route_display_controller.dart';

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
        "[MapNotifier_DEBUG] mapInteractionStarted: Setting state to manualMoveInProgress (from ${state.userMapInteraction})",
      );
      state = state.copyWith(
        userMapInteraction: UserMapInteractionState.manualMoveInProgress,
      );
    } else {
      print(
        "[MapNotifier_DEBUG] mapInteractionStarted: State already manualMoveInProgress. No change.",
      );
    }
  }

  void mapInteractionEnded() {
    if (state.isPerformingProgrammaticZoom) {
      print(
        "[MapNotifier_DEBUG] mapInteractionEnded: Programmatic zoom active. Skipping setting state to manualMoveCooldown.",
      );
      return;
    }

    _manualMoveCooldownTimer?.cancel();
    print(
      "[MapNotifier_DEBUG] mapInteractionEnded: Setting state to manualMoveCooldown and starting timer (from ${state.userMapInteraction})",
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
        reEvaluateAutoZoom();
      } else {
        print(
          "[MapNotifier_DEBUG] Cooldown ended. State changed during cooldown (${state.userMapInteraction}). Not setting to idle.",
        );
      }
    });
  }

  void reEvaluateAutoZoom() {
    print(
      "[MapNotifier_DEBUG] reEvaluateAutoZoom called. Current state: ${state.userMapInteraction}, Target: ${state.currentZoomTarget}, Programmatic Zoom: ${state.isPerformingProgrammaticZoom}",
    );
    if (state.isPerformingProgrammaticZoom) {
      print(
        "[MapNotifier_DEBUG] reEvaluateAutoZoom: Programmatic zoom is active. Skipping auto zoom logic.",
      );
      return;
    }

    if (state.userMapInteraction == UserMapInteractionState.idle) {
      if (state.selectedConsolidatedItinerary != null) {
        if (state.currentLegIndex != null &&
            state.currentDisplayMode == MapDisplayMode.legTracking) {
          print(
            "[MapNotifier_DEBUG] AutoZoom: Leg selected, target: leg. Setting currentZoomTarget.",
          );
          state = state.copyWith(currentZoomTarget: ZoomTargetType.leg);
        } else if (state.currentDisplayMode == MapDisplayMode.routeOverview) {
          print(
            "[MapNotifier_DEBUG] AutoZoom: Route overview, target: overview. Setting currentZoomTarget.",
          );
          state = state.copyWith(currentZoomTarget: ZoomTargetType.overview);
        } else {
          if (state.currentLegIndex != null) {
            print(
              "[MapNotifier_DEBUG] AutoZoom: Itinerary selected, leg index set, not tracking. Target: leg. Setting currentZoomTarget.",
            );
            state = state.copyWith(currentZoomTarget: ZoomTargetType.leg);
          } else {
            print(
              "[MapNotifier_DEBUG] AutoZoom: Itinerary selected, no leg index set. Target: overview. Setting currentZoomTarget.",
            );
            state = state.copyWith(currentZoomTarget: ZoomTargetType.overview);
          }
        }
      } else if (state.origin != null && state.destination != null) {
        if (state.currentDisplayMode != MapDisplayMode.blank &&
            state.currentZoomTarget != ZoomTargetType.points) {
          print(
            "[MapNotifier_DEBUG] AutoZoom: Origin and Destino set, target: points. Setting currentZoomTarget.",
          );
          state = state.copyWith(currentZoomTarget: ZoomTargetType.points);
        } else {
          print(
            "[MapNotifier_DEBUG] AutoZoom: Origin and Destino set, but current state/target doesn't require points zoom. No change.",
          );
        }
      } else if (state.origin != null) {
        print(
          "[MapNotifier_DEBUG] AutoZoom: Origin set, but no auto-zoom target for origin selection.",
        );
      } else if (state.destination != null) {
        print(
          "[MapNotifier_DEBUG] AutoZoom: Destination set, but no auto-zoom target for destination selection.",
        );
      } else {
        print(
          "[MapNotifier_DEBUG] AutoZoom: No specific state, target: initial. Setting currentZoomTarget.",
        );
        state = state.copyWith(currentZoomTarget: ZoomTargetType.initial);
      }
    } else {
      print(
        "[MapNotifier_DEBUG] reEvaluateAutoZoom: User is interacting (state: ${state.userMapInteraction}), no auto zoom. Skipping.",
      );
    }
  }

  void setIsPerformingProgrammaticZoom(bool isPerforming) {
    print(
      "[MapNotifier_DEBUG] setIsPerformingProgrammaticZoom called with: $isPerforming. Current state: ${state.isPerformingProgrammaticZoom}",
    );
    if (state.isPerformingProgrammaticZoom != isPerforming) {
      state = state.copyWith(isPerformingProgrammaticZoom: isPerforming);
      print(
        "[MapNotifier_DEBUG] setIsPerformingProgrammaticZoom: State updated to $isPerforming.",
      );
    } else {
      print(
        "[MapNotifier_DEBUG] setIsPerformingProgrammaticZoom: State already $isPerforming. No change.",
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
    reEvaluateAutoZoom();
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
    reEvaluateAutoZoom();
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
    reEvaluateAutoZoom();
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
    reEvaluateAutoZoom();
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
    reEvaluateAutoZoom();
  }

  Future<void> processSelectedItinerary(
    ConsolidatedItinerary consolidatedItinerary,
    MapboxService mapboxService,
    BusTrackingController busTrackingController,
    RouteDisplayController routeDisplayController,
  ) async {
    print(
      "[MapNotifier_DEBUG] processSelectedItinerary called with ConsolidatedItinerary ID: ${consolidatedItinerary.id}",
    );

    final representativeItinerary =
        consolidatedItinerary
            .representativeProcessedItinerary
            .originalOtpItinerary;

    // Dibujar la nueva ruta
    bool routeDrawn = await routeDisplayController
        .processAndDisplaySelectedItineraryUI(representativeItinerary.legs);

    if (!routeDrawn) {
      print("[MapNotifier_ERROR] Error al dibujar la ruta seleccionada.");
      state = state.copyWith(planningStatus: PlanningStatus.error);
      return;
    }

    bool realtimeAvailableForFirstLeg = false;
    bool realtimeAttemptedForFirstLeg = false;
    BusArrivalInfo? representativeETAForFirstLeg =
        consolidatedItinerary.representativeFirstBusETAInfo;
    RouteLeg? actualFirstRouteLegForTracking;

    if (representativeItinerary.legs.isNotEmpty) {
      final firstLeg = representativeItinerary.legs.firstWhere(
        (leg) => leg.mode.toUpperCase() == LegModeConstants.bus.toUpperCase(),
        orElse: () => representativeItinerary.legs.first,
      );
      actualFirstRouteLegForTracking = firstLeg;
      if (firstLeg.mode.toUpperCase() == LegModeConstants.bus.toUpperCase() &&
          representativeETAForFirstLeg != null) {
        realtimeAvailableForFirstLeg =
            representativeETAForFirstLeg.isReal &&
            representativeETAForFirstLeg.position != null;
        realtimeAttemptedForFirstLeg = true;
      } else if (firstLeg.mode.toUpperCase() ==
          LegModeConstants.bus.toUpperCase()) {
        realtimeAttemptedForFirstLeg = true;
      }
    }

    state = state.copyWith(
      selectedConsolidatedItinerary: consolidatedItinerary,
      representativeItinerary: representativeItinerary,
      currentDisplayMode: MapDisplayMode.routeStaticWithInstructions,
      currentLegIndex: 0,
      currentZoomTarget: ZoomTargetType.leg,
      showInstructionsPanel: true,
      realtimeTrackingAvailable: realtimeAvailableForFirstLeg,
      realtimeTrackingAttempted: realtimeAttemptedForFirstLeg,
      clearTrackedBusLineShortName: true,
      representativeFirstBusETAInfo: representativeETAForFirstLeg,
    );

    await routeDisplayController.updateMapRouteHighlight();

    print(
      "[MapNotifier_DEBUG] processSelectedItinerary: Updated state. TrackedLineName: ${state.trackedBusLineShortName}, ZoomTarget: ${state.currentZoomTarget}, RealtimeAvailable: ${state.realtimeTrackingAvailable}, RealtimeAttempted: ${state.realtimeTrackingAttempted}, RepETA: ${state.representativeFirstBusETAInfo?.minutesToArrival} min, Real: ${state.representativeFirstBusETAInfo?.isReal}",
    );

    await busTrackingController.stopTrackingBusLine();

    if (state.realtimeTrackingAvailable &&
        actualFirstRouteLegForTracking != null &&
        representativeETAForFirstLeg != null) {
      print(
        "[MapNotifier_DEBUG_TRACKING] processSelectedItinerary: Realtime available. Starting tracking for leg: ${actualFirstRouteLegForTracking.from.name} -> ${actualFirstRouteLegForTracking.to.name}, Line: ${representativeETAForFirstLeg.lineShortName}, ETA: ${representativeETAForFirstLeg.minutesToArrival} min",
      );
      await busTrackingController.startTrackingBusLine(
        actualFirstRouteLegForTracking,
        representativeETAForFirstLeg,
      );
      state = state.copyWith(currentDisplayMode: MapDisplayMode.legTracking);
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
        "[MapNotifier_DEBUG_TRACKING]   - representativeETA is null: ${representativeETAForFirstLeg == null}",
      );
    }
    reEvaluateAutoZoom();
  }

  // --- Gestión de la selección de tramos ---
  void setSelectedLegIndex(
    int index,
    MapboxService mapboxService,
    RouteDisplayController routeDisplayController,
  ) async {
    if (state.representativeItinerary == null ||
        index < 0 ||
        index >= state.representativeItinerary!.legs.length) {
      return;
    }

    final selectedLeg = state.representativeItinerary!.legs[index];
    bool isBusLeg =
        selectedLeg.mode.toUpperCase() == LegModeConstants.bus.toUpperCase();

    print(
      "[MapNotifier_DEBUG] setSelectedLegIndex: Highlighting leg $index. Forcing map to IDLE before setting zoom target.",
    );

    forceMapIdleAndZoomTo(ZoomTargetType.none);

    state = state.copyWith(
      currentLegIndex: index,
      currentDisplayMode:
          isBusLeg && state.realtimeTrackingAvailable
              ? MapDisplayMode.legTracking
              : MapDisplayMode.routeStaticWithInstructions,
      currentZoomTarget: ZoomTargetType.leg,
      showInstructionsPanel: true,
    );

    await routeDisplayController.updateMapRouteHighlight();

    reEvaluateAutoZoom();
  }

  // --- Cambio de modo de visualización ---
  void switchToOverview(MapboxService mapboxService) {
    // ... existing code ...
  }

  void switchToLegTracking(
    MapboxService mapboxService,
    BusTrackingController busTrackingController,
    RouteDisplayController routeDisplayController,
  ) async {
    if (state.currentLegIndex != null &&
        state.selectedConsolidatedItinerary != null &&
        state.representativeItinerary != null) {
      // ... existing code ...
      state = state.copyWith(
        currentDisplayMode: MapDisplayMode.legTracking,
        currentZoomTarget: ZoomTargetType.leg,
      );
      await routeDisplayController.updateMapRouteHighlight();

      final currentLeg =
          state.representativeItinerary!.legs[state.currentLegIndex!];
      // ... existing code ...
    }
  }

  void updateRealtimeTrackingStatus(bool isTracking) {
    print(
      "[MapNotifier_DEBUG_TRACKING] updateRealtimeTrackingStatus called with isTracking: $isTracking",
    );
    if (!isTracking && state.currentDisplayMode == MapDisplayMode.legTracking) {
      // Si el seguimiento se detiene (ej. el bus llegó o se perdió la señal),
      // volvemos al modo de instrucciones estáticas para el tramo actual.
      state = state.copyWith(
        currentDisplayMode: MapDisplayMode.routeStaticWithInstructions,
        realtimeTrackingAvailable: false, // Marcar como no disponible ahora
        // No necesariamente limpiamos el trackedBusLineShortName aquí,
        // podría ser útil mantenerlo visible hasta que se seleccione otro tramo/ruta.
        // clearTrackedBusLineShortName: true,
      );
      // No necesitamos llamar a updateMapRouteHighlight aquí si el índice no cambió.
    } else if (isTracking &&
        state.currentDisplayMode != MapDisplayMode.legTracking) {
      // Si el seguimiento comienza y no estábamos en modo legTracking, cambiamos.
      state = state.copyWith(currentDisplayMode: MapDisplayMode.legTracking);
    }
    // Si el seguimiento se detiene, realtimeTrackingAvailable debe ser false.
    if (!isTracking) {
      state = state.copyWith(realtimeTrackingAvailable: false);
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
    print(
      "[MapNotifier_DEBUG] forceMapIdleAndZoomTo called with target: $target. Current state: ${state.userMapInteraction}, Programmatic Zoom: ${state.isPerformingProgrammaticZoom}",
    );
    setIsPerformingProgrammaticZoom(true);

    state = state.copyWith(
      userMapInteraction: UserMapInteractionState.idle,
      currentZoomTarget: target,
      currentCameraOptions: cameraOptions ?? state.currentCameraOptions,
    );
    print(
      "[MapNotifier_DEBUG] forceMapIdleAndZoomTo: State updated to idle and target $target.",
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
      reEvaluateAutoZoom();
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

  void clearRouteState(
    MapboxService mapboxService,
    BusTrackingController busTrackingController, {
    bool preserveOriginAndDestination = false,
    bool resetToInitialZoom = true,
  }) async {
    print("[MapNotifier_DEBUG] clearRouteState llamado.");
    await mapboxService
        .clearRoute(); // Esto llama a clearPreviousRouteLayers en el servicio
    await mapboxService.clearHighlightedStop();
    await mapboxService.toggleGeneralStopsVisibility(true);
    await busTrackingController.stopTrackingBusLine();

    MapDisplayMode newDisplayMode;
    ZoomTargetType newZoomTarget;

    if (preserveOriginAndDestination &&
        state.origin != null &&
        state.destination != null) {
      newDisplayMode =
          MapDisplayMode
              .routeOverview; // Aunque no hay ruta, es el modo "listo para planificar"
      newZoomTarget = ZoomTargetType.points;
    } else if (preserveOriginAndDestination && state.origin != null) {
      newDisplayMode = MapDisplayMode.originSelected;
      newZoomTarget = ZoomTargetType.origenSelection;
    } else if (preserveOriginAndDestination && state.destination != null) {
      newDisplayMode = MapDisplayMode.destinationSelected;
      newZoomTarget = ZoomTargetType.destinationSelection;
    } else {
      newDisplayMode = MapDisplayMode.blank;
      newZoomTarget = ZoomTargetType.initial;
    }

    setIsPerformingProgrammaticZoom(false);

    state = state.copyWith(
      clearSelectedConsolidatedItinerary: true,
      clearRepresentativeItinerary: true,
      clearRepresentativeFirstBusETAInfo: true,
      planningStatus: PlanningStatus.idle,
      clearCurrentLegIndex: true,
      showInstructionsPanel: false,
      clearTrackedBusLineShortName: true,
      clearRealDebugBusPosition: true,
      clearRealDebugEtaMinutes: true,
      clearRealDebugIsReal: true,
      clearSimulatedBusPosition: true,
      clearBusSpeedMetersPerSecond: true,
      clearLastSpeedCalculationTime: true,
      clearSimulationSegmentOriginPoint: true,
      clearMaxSimulationTravelDistance: true,
      realtimeTrackingAvailable: false,
      realtimeTrackingAttempted: false,
      currentDisplayMode: newDisplayMode,
      currentZoomTarget: newZoomTarget,
    );
    print(
      "[MapNotifier_DEBUG] clearRouteState: Estado final: displayMode=${state.currentDisplayMode}, zoomTarget=${state.currentZoomTarget}",
    );
    reEvaluateAutoZoom();
  }

  @override
  void dispose() {
    _manualMoveCooldownTimer?.cancel();
    super.dispose();
  }
}
