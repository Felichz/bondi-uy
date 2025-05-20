// lib/state/map_state.dart
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:bondi_uy/models/consolidated_itinerary.dart';
import 'package:bondi_uy/models/itinerary.dart';
import 'package:bondi_uy/models/route_leg.dart';
import 'package:flutter/foundation.dart'; // Para ValueGetter
import 'package:bondi_uy/models/bus_arrival_info.dart'; // Importar BusArrivalInfo

// TODO: Mover a un archivo separado si se usa en más lugares.
enum UserMapInteractionState {
  idle, // El usuario no está interactuando con el mapa
  manualMoveInProgress, // El usuario está moviendo/haciendo zoom en el mapa
  manualMoveCooldown, // Pequeño cooldown después de que el usuario deja de interactuar
}

enum PlanningStatus { idle, loading, success, error }

enum ZoomTargetType {
  initial, // Zoom inicial al cargar la app
  origenSelection, // Zoom al origen cuando se selecciona
  destinationSelection, // Zoom al destino cuando se selecciona
  points, // Zoom para encuadrar origen y destino
  overview, // Zoom para mostrar toda la ruta seleccionada
  leg, // Zoom a un tramo específico de la ruta
  none, // No hay un objetivo de zoom específico, control manual
}

enum MapDisplayMode {
  blank,
  originSelected,
  destinationSelected,
  routeOverview,
  legTracking,
  legHighlight,
  routeStaticWithInstructions,
}

class MapState {
  final Position? origin;
  final Position? destination;
  final String? originAddress;
  final String? destinationAddress;
  final UserMapInteractionState userMapInteraction;
  final MapDisplayMode currentDisplayMode;
  final ZoomTargetType currentZoomTarget;
  final CameraOptions? currentCameraOptions;
  final List<ConsolidatedItinerary> consolidatedItineraries;
  final ConsolidatedItinerary? selectedConsolidatedItinerary;
  final Itinerary? representativeItinerary;
  final BusArrivalInfo? representativeFirstBusETAInfo;
  final PlanningStatus planningStatus;
  final int? currentLegIndex;
  final bool showInstructionsPanel;
  final String? trackedBusLineShortName;
  final Position? realDebugBusPosition;
  final int? realDebugEtaMinutes;
  final bool? realDebugIsReal;
  final Position? simulatedBusPosition;
  final double? busSpeedMetersPerSecond;
  final DateTime? lastSpeedCalculationTime;
  final Position? simulationSegmentOriginPoint;
  final double? maxSimulationTravelDistance;
  final bool realtimeTrackingAvailable;
  final bool realtimeTrackingAttempted;
  final bool isPerformingProgrammaticZoom;

  MapState({
    this.origin,
    this.destination,
    this.originAddress,
    this.destinationAddress,
    this.userMapInteraction = UserMapInteractionState.idle,
    this.currentDisplayMode = MapDisplayMode.blank,
    this.currentZoomTarget = ZoomTargetType.initial,
    this.currentCameraOptions,
    this.consolidatedItineraries = const [],
    this.selectedConsolidatedItinerary,
    this.representativeItinerary,
    this.representativeFirstBusETAInfo,
    this.planningStatus = PlanningStatus.idle,
    this.currentLegIndex,
    this.showInstructionsPanel = false,
    this.trackedBusLineShortName,
    this.realDebugBusPosition,
    this.realDebugEtaMinutes,
    this.realDebugIsReal,
    this.simulatedBusPosition,
    this.busSpeedMetersPerSecond,
    this.lastSpeedCalculationTime,
    this.simulationSegmentOriginPoint,
    this.maxSimulationTravelDistance,
    this.realtimeTrackingAvailable = false,
    this.realtimeTrackingAttempted = false,
    this.isPerformingProgrammaticZoom = false,
  });

  MapState copyWith({
    Position? origin,
    bool clearOrigin = false,
    Position? destination,
    bool clearDestination = false,
    String? originAddress,
    bool clearOriginAddress = false,
    String? destinationAddress,
    bool clearDestinationAddress = false,
    UserMapInteractionState? userMapInteraction,
    MapDisplayMode? currentDisplayMode,
    ZoomTargetType? currentZoomTarget,
    CameraOptions? currentCameraOptions,
    List<ConsolidatedItinerary>? consolidatedItineraries,
    ConsolidatedItinerary? selectedConsolidatedItinerary,
    bool clearSelectedConsolidatedItinerary = false,
    Itinerary? representativeItinerary,
    bool clearRepresentativeItinerary = false,
    BusArrivalInfo? representativeFirstBusETAInfo,
    bool clearRepresentativeFirstBusETAInfo = false,
    PlanningStatus? planningStatus,
    int? currentLegIndex,
    bool clearCurrentLegIndex = false,
    bool? showInstructionsPanel,
    String? trackedBusLineShortName,
    bool clearTrackedBusLineShortName = false,
    Position? realDebugBusPosition,
    bool clearRealDebugBusPosition = false,
    int? realDebugEtaMinutes,
    bool clearRealDebugEtaMinutes = false,
    bool? realDebugIsReal,
    bool clearRealDebugIsReal = false,
    Position? simulatedBusPosition,
    bool clearSimulatedBusPosition = false,
    double? busSpeedMetersPerSecond,
    bool clearBusSpeedMetersPerSecond = false,
    DateTime? lastSpeedCalculationTime,
    bool clearLastSpeedCalculationTime = false,
    Position? simulationSegmentOriginPoint,
    bool clearSimulationSegmentOriginPoint = false,
    double? maxSimulationTravelDistance,
    bool clearMaxSimulationTravelDistance = false,
    bool? realtimeTrackingAvailable,
    bool? realtimeTrackingAttempted,
    bool? isPerformingProgrammaticZoom,
  }) {
    return MapState(
      origin: clearOrigin ? null : origin ?? this.origin,
      destination: clearDestination ? null : destination ?? this.destination,
      originAddress:
          clearOriginAddress ? null : originAddress ?? this.originAddress,
      destinationAddress:
          clearDestinationAddress
              ? null
              : destinationAddress ?? this.destinationAddress,
      userMapInteraction: userMapInteraction ?? this.userMapInteraction,
      currentDisplayMode: currentDisplayMode ?? this.currentDisplayMode,
      currentZoomTarget: currentZoomTarget ?? this.currentZoomTarget,
      currentCameraOptions: currentCameraOptions ?? this.currentCameraOptions,
      consolidatedItineraries:
          consolidatedItineraries ?? this.consolidatedItineraries,
      selectedConsolidatedItinerary:
          clearSelectedConsolidatedItinerary
              ? null
              : selectedConsolidatedItinerary ??
                  this.selectedConsolidatedItinerary,
      representativeItinerary:
          clearRepresentativeItinerary
              ? null
              : representativeItinerary ?? this.representativeItinerary,
      representativeFirstBusETAInfo:
          clearRepresentativeFirstBusETAInfo
              ? null
              : representativeFirstBusETAInfo ??
                  this.representativeFirstBusETAInfo,
      planningStatus: planningStatus ?? this.planningStatus,
      currentLegIndex:
          clearCurrentLegIndex ? null : currentLegIndex ?? this.currentLegIndex,
      showInstructionsPanel:
          showInstructionsPanel ?? this.showInstructionsPanel,
      trackedBusLineShortName:
          clearTrackedBusLineShortName
              ? null
              : trackedBusLineShortName ?? this.trackedBusLineShortName,
      realDebugBusPosition:
          clearRealDebugBusPosition
              ? null
              : realDebugBusPosition ?? this.realDebugBusPosition,
      realDebugEtaMinutes:
          clearRealDebugEtaMinutes
              ? null
              : realDebugEtaMinutes ?? this.realDebugEtaMinutes,
      realDebugIsReal:
          clearRealDebugIsReal ? null : realDebugIsReal ?? this.realDebugIsReal,
      simulatedBusPosition:
          clearSimulatedBusPosition
              ? null
              : simulatedBusPosition ?? this.simulatedBusPosition,
      busSpeedMetersPerSecond:
          clearBusSpeedMetersPerSecond
              ? null
              : busSpeedMetersPerSecond ?? this.busSpeedMetersPerSecond,
      lastSpeedCalculationTime:
          clearLastSpeedCalculationTime
              ? null
              : lastSpeedCalculationTime ?? this.lastSpeedCalculationTime,
      simulationSegmentOriginPoint:
          clearSimulationSegmentOriginPoint
              ? null
              : simulationSegmentOriginPoint ??
                  this.simulationSegmentOriginPoint,
      maxSimulationTravelDistance:
          clearMaxSimulationTravelDistance
              ? null
              : maxSimulationTravelDistance ?? this.maxSimulationTravelDistance,
      realtimeTrackingAvailable:
          realtimeTrackingAvailable ?? this.realtimeTrackingAvailable,
      realtimeTrackingAttempted:
          realtimeTrackingAttempted ?? this.realtimeTrackingAttempted,
      isPerformingProgrammaticZoom:
          isPerformingProgrammaticZoom ?? this.isPerformingProgrammaticZoom,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MapState &&
        other.origin == origin &&
        other.destination == destination &&
        other.originAddress == originAddress &&
        other.destinationAddress == destinationAddress &&
        other.userMapInteraction == userMapInteraction &&
        other.currentDisplayMode == currentDisplayMode &&
        other.currentZoomTarget == currentZoomTarget &&
        other.currentCameraOptions == currentCameraOptions &&
        listEquals(other.consolidatedItineraries, consolidatedItineraries) &&
        other.selectedConsolidatedItinerary == selectedConsolidatedItinerary &&
        other.representativeItinerary == representativeItinerary &&
        other.representativeFirstBusETAInfo == representativeFirstBusETAInfo &&
        other.planningStatus == planningStatus &&
        other.currentLegIndex == currentLegIndex &&
        other.showInstructionsPanel == showInstructionsPanel &&
        other.trackedBusLineShortName == trackedBusLineShortName &&
        other.realDebugBusPosition == realDebugBusPosition &&
        other.realDebugEtaMinutes == realDebugEtaMinutes &&
        other.realDebugIsReal == realDebugIsReal &&
        other.simulatedBusPosition == simulatedBusPosition &&
        other.busSpeedMetersPerSecond == busSpeedMetersPerSecond &&
        other.lastSpeedCalculationTime == lastSpeedCalculationTime &&
        other.simulationSegmentOriginPoint == simulationSegmentOriginPoint &&
        other.maxSimulationTravelDistance == maxSimulationTravelDistance &&
        other.realtimeTrackingAvailable == realtimeTrackingAvailable &&
        other.realtimeTrackingAttempted == realtimeTrackingAttempted &&
        other.isPerformingProgrammaticZoom == isPerformingProgrammaticZoom;
  }

  @override
  int get hashCode {
    return origin.hashCode ^
        destination.hashCode ^
        originAddress.hashCode ^
        destinationAddress.hashCode ^
        userMapInteraction.hashCode ^
        currentDisplayMode.hashCode ^
        currentZoomTarget.hashCode ^
        currentCameraOptions.hashCode ^
        consolidatedItineraries.hashCode ^
        selectedConsolidatedItinerary.hashCode ^
        representativeItinerary.hashCode ^
        representativeFirstBusETAInfo.hashCode ^
        planningStatus.hashCode ^
        currentLegIndex.hashCode ^
        showInstructionsPanel.hashCode ^
        trackedBusLineShortName.hashCode ^
        realDebugBusPosition.hashCode ^
        realDebugEtaMinutes.hashCode ^
        realDebugIsReal.hashCode ^
        simulatedBusPosition.hashCode ^
        busSpeedMetersPerSecond.hashCode ^
        lastSpeedCalculationTime.hashCode ^
        simulationSegmentOriginPoint.hashCode ^
        maxSimulationTravelDistance.hashCode ^
        realtimeTrackingAvailable.hashCode ^
        realtimeTrackingAttempted.hashCode ^
        isPerformingProgrammaticZoom.hashCode;
  }
}
