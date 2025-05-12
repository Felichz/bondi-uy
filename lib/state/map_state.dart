import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'; // Para Position
// import 'package:geojson_dart/geojson_dart.dart'; // Incorrecto
// import 'package:geojson_vt_dart/geojson_vt_dart.dart'; // Innecesario aquí
import 'package:bondi_uy/models/point_dart.dart'; // Para Point_dart
import 'package:bondi_uy/models/itinerary.dart'; // Importar Itinerary
import 'package:bondi_uy/models/route_leg.dart'; // Importar RouteLeg

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
  final Position? highlightedBusPosition;
  final bool userManuallyMovedMap;
  final String? errorMessage;
  // Añade otros estados relevantes si es necesario

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
    this.userManuallyMovedMap = false,
    this.errorMessage,
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
    bool? userManuallyMovedMap,
    ValueGetter<String?>? errorMessage,
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
      userManuallyMovedMap: userManuallyMovedMap ?? this.userManuallyMovedMap,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}
