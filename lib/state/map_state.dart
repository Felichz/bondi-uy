import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'; // Para Position
// import 'package:geojson_dart/geojson_dart.dart'; // Incorrecto
// import 'package:geojson_vt_dart/geojson_vt_dart.dart'; // Innecesario aquí
import 'package:bondi_uy/models/point_dart.dart'; // Para Point_dart
import 'package:bondi_uy/models/itinerary.dart'; // Importar Itinerary
import 'package:bondi_uy/models/route_leg.dart'; // Importar RouteLeg

// Nuevo: Define el objetivo actual del zoom del mapa.
enum ZoomTargetType {
  none, // Sin objetivo de zoom específico, el usuario tiene control total o es el estado inicial.
  initial, // Cámara inicial al cargar el mapa
  overview, // Zoom para ver la ruta completa.
  leg, // Zoom a un tramo específico.
  busAndLegOrigin, // Zoom para ver el bus y el origen del tramo actual.
  points, // Zoom para encajar un conjunto de puntos.
  origenSelection, // Zoom al origen cuando se selecciona.
  destinoSelection, // Zoom al destino cuando se selecciona.
}

// Nuevo: Contiene los detalles para un objetivo de zoom específico.
@immutable
class ZoomTarget {
  final ZoomTargetType type;
  final int?
  legIndex; // Para ZoomTargetType.leg y ZoomTargetType.busAndLegOrigin
  final List<Position>? points; // Para ZoomTargetType.points
  final Position?
  singlePoint; // Para ZoomTargetType.origenSelection o ZoomTargetType.destinoSelection

  const ZoomTarget({
    required this.type,
    this.legIndex,
    this.points,
    this.singlePoint,
  });

  static const ZoomTarget none = ZoomTarget(type: ZoomTargetType.none);
  static const ZoomTarget initial = ZoomTarget(type: ZoomTargetType.initial);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZoomTarget &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          legIndex == other.legIndex &&
          listEquals(points, other.points) &&
          singlePoint == other.singlePoint;

  @override
  int get hashCode =>
      type.hashCode ^
      legIndex.hashCode ^
      (points != null ? Object.hashAll(points!) : 0) ^
      singlePoint.hashCode;

  ZoomTarget copyWith({
    ZoomTargetType? type,
    int? legIndex,
    List<Position>? points,
    Position? singlePoint,
  }) {
    return ZoomTarget(
      type: type ?? this.type,
      legIndex: legIndex ?? this.legIndex,
      points: points ?? this.points,
      singlePoint: singlePoint ?? this.singlePoint,
    );
  }
}

// Nuevo: Estado de la interacción del usuario con el mapa.
enum UserMapInteractionState {
  idle, // El sistema puede controlar el zoom.
  manualMoveInProgress, // El usuario está moviendo activamente el mapa. El sistema NO debe hacer zoom.
  manualMoveCooldown, // El usuario acaba de mover el mapa. El sistema NO debe auto-zoom por un corto periodo.
}

// Usar freezed podría ser una buena mejora aquí para inmutabilidad y copyWith
@immutable
class MapState {
  final Point_dart? origenCoordinates;
  final Point_dart? destinoCoordinates;
  final bool isCalculatingRoute;
  final bool showCollapsedInstructionsBar;
  final List<RouteLeg> currentRouteLegs; // Usar List<RouteLeg>
  final int? selectedLegIndex;
  final bool isInOverviewMode;
  final List<Itinerary> availableItineraries; // Usar List<Itinerary>
  final String? trackedBusLineShortName;
  final Position?
  highlightedBusPosition; // Posición principal del bus para UI (puede ser simulada o real)
  final int? highlightedBusEtaMinutes;
  final String? errorMessage;
  final RouteLeg? legToTrackInRealtime;
  final bool? isHighlightedBusReal;

  // Campos para la simulación de movimiento del bus
  final Position? simulatedBusPosition; // Posición calculada por la simulación
  final double?
  busSpeedMetersPerSecond; // Velocidad calculada para la simulación
  final DateTime?
  lastSpeedCalculationTime; // Cuándo se calculó la velocidad por última vez
  final Position?
  simulationSegmentOriginPoint; // Desde dónde empezó el segmento actual de simulación
  final Position?
  realDebugBusPosition; // Posición real del bus según API (para depuración)
  final double?
  maxSimulationTravelDistance; // Máxima distancia a simular antes de nueva data API

  // NUEVOS CAMPOS
  final ZoomTarget currentZoomTarget;
  final UserMapInteractionState userMapInteraction;
  final DateTime? lastManualMoveTimestamp;

  const MapState({
    this.origenCoordinates,
    this.destinoCoordinates,
    this.isCalculatingRoute = false,
    this.showCollapsedInstructionsBar = false,
    this.currentRouteLegs = const [], // Lista vacía de RouteLeg
    this.selectedLegIndex,
    this.isInOverviewMode = false,
    this.availableItineraries = const [], // Lista vacía de Itinerary
    this.trackedBusLineShortName,
    this.highlightedBusPosition,
    this.highlightedBusEtaMinutes,
    this.errorMessage,
    this.legToTrackInRealtime,
    this.isHighlightedBusReal,
    this.simulatedBusPosition,
    this.busSpeedMetersPerSecond,
    this.lastSpeedCalculationTime,
    this.simulationSegmentOriginPoint,
    this.realDebugBusPosition,
    this.maxSimulationTravelDistance,
    this.currentZoomTarget = ZoomTarget.initial, // NUEVO
    this.userMapInteraction = UserMapInteractionState.idle, // NUEVO
    this.lastManualMoveTimestamp, // NUEVO
  });

  MapState copyWith({
    // Usa ValueGetter para permitir establecer explícitamente a null
    ValueGetter<Point_dart?>? origenCoordinates,
    ValueGetter<Point_dart?>? destinoCoordinates,
    bool? isCalculatingRoute,
    bool? showCollapsedInstructionsBar,
    List<RouteLeg>? currentRouteLegs, // Usar List<RouteLeg>
    ValueGetter<int?>? selectedLegIndex,
    bool? isInOverviewMode,
    List<Itinerary>? availableItineraries, // Usar List<Itinerary>
    ValueGetter<String?>? trackedBusLineShortName,
    ValueGetter<Position?>? highlightedBusPosition,
    ValueGetter<int?>? highlightedBusEtaMinutes,
    ValueGetter<String?>? errorMessage,
    ValueGetter<RouteLeg?>? legToTrackInRealtime,
    ValueGetter<Position?>? simulatedBusPosition,
    ValueGetter<double?>? busSpeedMetersPerSecond,
    ValueGetter<DateTime?>? lastSpeedCalculationTime,
    ValueGetter<Position?>? simulationSegmentOriginPoint,
    ValueGetter<Position?>? realDebugBusPosition,
    ValueGetter<double?>? maxSimulationTravelDistance,
    ValueGetter<bool?>? isHighlightedBusReal,
    // NUEVOS CAMPOS
    ZoomTarget? currentZoomTarget,
    UserMapInteractionState? userMapInteraction,
    ValueGetter<DateTime?>? lastManualMoveTimestamp,
  }) {
    return MapState(
      origenCoordinates:
          origenCoordinates != null
              ? origenCoordinates()
              : this.origenCoordinates,
      destinoCoordinates:
          destinoCoordinates != null
              ? destinoCoordinates()
              : this.destinoCoordinates,
      isCalculatingRoute: isCalculatingRoute ?? this.isCalculatingRoute,
      showCollapsedInstructionsBar:
          showCollapsedInstructionsBar ?? this.showCollapsedInstructionsBar,
      currentRouteLegs: currentRouteLegs ?? this.currentRouteLegs,
      selectedLegIndex:
          selectedLegIndex != null ? selectedLegIndex() : this.selectedLegIndex,
      isInOverviewMode: isInOverviewMode ?? this.isInOverviewMode,
      availableItineraries: availableItineraries ?? this.availableItineraries,
      trackedBusLineShortName:
          trackedBusLineShortName != null
              ? trackedBusLineShortName()
              : this.trackedBusLineShortName,
      highlightedBusPosition:
          highlightedBusPosition != null
              ? highlightedBusPosition()
              : this.highlightedBusPosition,
      highlightedBusEtaMinutes:
          highlightedBusEtaMinutes != null
              ? highlightedBusEtaMinutes()
              : this.highlightedBusEtaMinutes,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      legToTrackInRealtime:
          legToTrackInRealtime != null
              ? legToTrackInRealtime()
              : this.legToTrackInRealtime,
      simulatedBusPosition:
          simulatedBusPosition != null
              ? simulatedBusPosition()
              : this.simulatedBusPosition,
      busSpeedMetersPerSecond:
          busSpeedMetersPerSecond != null
              ? busSpeedMetersPerSecond()
              : this.busSpeedMetersPerSecond,
      lastSpeedCalculationTime:
          lastSpeedCalculationTime != null
              ? lastSpeedCalculationTime()
              : this.lastSpeedCalculationTime,
      simulationSegmentOriginPoint:
          simulationSegmentOriginPoint != null
              ? simulationSegmentOriginPoint()
              : this.simulationSegmentOriginPoint,
      realDebugBusPosition:
          realDebugBusPosition != null
              ? realDebugBusPosition()
              : this.realDebugBusPosition,
      maxSimulationTravelDistance:
          maxSimulationTravelDistance != null
              ? maxSimulationTravelDistance()
              : this.maxSimulationTravelDistance,
      isHighlightedBusReal:
          isHighlightedBusReal != null
              ? isHighlightedBusReal()
              : this.isHighlightedBusReal,
      currentZoomTarget: currentZoomTarget ?? this.currentZoomTarget,
      userMapInteraction: userMapInteraction ?? this.userMapInteraction,
      lastManualMoveTimestamp:
          lastManualMoveTimestamp != null
              ? lastManualMoveTimestamp()
              : this.lastManualMoveTimestamp,
    );
  }
}
