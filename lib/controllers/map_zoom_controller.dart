import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../services/mapbox_service.dart';
import '../state/map_state.dart'; // Para ZoomTarget y MapState
import '../providers/map_notifier.dart'; // Para leer MapState
import '../models/route_leg.dart'; // AÑADIDO: Para el tipo RouteLeg
import 'dart:async';
import 'package:bondi_uy/models/leg_mode_constants.dart'; // Añadir esta línea

// Podríamos mover _initialCameraOptions aquí si es puramente de zoom inicial.
// Por ahora, lo mantenemos en MapScreen y lo pasamos si es necesario,
// o el MapZoomController lo reconstruye si es una constante fija.

class MapZoomController {
  final MapboxMap mapboxMap;
  final MapboxService mapboxService;
  final WidgetRef ref; // Para acceder a MapState
  Timer? _zoomDebounceTimer;

  // Cámara inicial por defecto si no hay otra definida en MapState
  static final CameraOptions initialCameraOptions = CameraOptions(
    center: Point(coordinates: Position(-56.164532, -34.901112)), // Montevideo
    zoom: 12.0,
  );

  MapZoomController({
    required this.mapboxMap,
    required this.mapboxService,
    required this.ref,
  });

  void handleZoomTarget(ZoomTargetType zoomTargetType) {
    _debounceZoom(() {
      print(
        "[MapZoomController_DEBUG] Debounced zoom. Target: $zoomTargetType",
      );
      _performZoom(zoomTargetType);
    });
  }

  void _debounceZoom(VoidCallback zoomAction) {
    _zoomDebounceTimer?.cancel();
    _zoomDebounceTimer = Timer(const Duration(milliseconds: 300), zoomAction);
  }

  Future<void> _performZoom(ZoomTargetType zoomTargetType) async {
    final mapState = ref.read(mapNotifierProvider);

    // No hacer zoom automático si el usuario está interactuando o en cooldown
    if (mapState.userMapInteraction != UserMapInteractionState.idle) {
      print(
        "[MapZoomController_DEBUG] User is interacting with the map. Auto-zoom skipped. Interaction state: ${mapState.userMapInteraction}",
      );
      return;
    }

    switch (zoomTargetType) {
      case ZoomTargetType.initial:
        await mapboxMap.flyTo(
          initialCameraOptions,
          MapAnimationOptions(duration: 1000),
        );
        break;
      case ZoomTargetType.origenSelection:
        if (mapState.origin != null) {
          await mapboxService.zoomToFitPositions([
            mapState.origin!,
          ], const EdgeInsets.all(100));
        }
        break;
      case ZoomTargetType.destinationSelection:
        if (mapState.destination != null) {
          await mapboxService.zoomToFitPositions([
            mapState.destination!,
          ], const EdgeInsets.all(100));
        }
        break;
      case ZoomTargetType.points:
        if (mapState.origin != null && mapState.destination != null) {
          await mapboxService.zoomToFitPositions([
            mapState.origin!,
            mapState.destination!,
          ], const EdgeInsets.symmetric(vertical: 120, horizontal: 60));
        }
        break;
      case ZoomTargetType.overview:
        final legs = mapState.representativeItinerary?.legs ?? [];
        if (legs.isNotEmpty) {
          await mapboxService.zoomToRouteBounds(legs);
        }
        break;
      case ZoomTargetType.leg:
        final legs = mapState.representativeItinerary?.legs ?? [];
        final legIndex = mapState.currentLegIndex;
        if (legs.isNotEmpty && legIndex != null) {
          final leg = legs[legIndex];
          if (leg.mode == LegModeConstants.bus &&
              mapState.realtimeTrackingAvailable) {
            // Si es un tramo de bus y el seguimiento en tiempo real está disponible, pasamos la posición del bus.
            await _zoomToLeg(legs, legIndex, mapState.realDebugBusPosition);
          } else {
            await _zoomToLeg(legs, legIndex, null);
          }
        }
        break;
      case ZoomTargetType.none:
        print(
          "[MapZoomController_DEBUG] ZoomTargetType.none: No specific zoom action taken.",
        );
        break;
      default:
        print(
          "[MapZoomController_WARN] Unhandled ZoomTargetType: $zoomTargetType",
        );
        break;
    }
  }

  Future<void> _zoomToLeg(
    List<RouteLeg> legs,
    int legIndex,
    Position? busToInclude,
  ) async {
    final bool isInstructionsCollapsed =
        !ref.read(mapNotifierProvider).showInstructionsPanel;

    if (legIndex < 0 || legIndex >= legs.length) {
      print(
        "[MapZoomController_ERROR] _zoomToLeg: Invalid legIndex $legIndex for ${legs.length} legs.",
      );
      return;
    }

    await mapboxService.zoomToLeg(
      legs,
      legIndex,
      busToInclude,
      isInstructionsCollapsed,
    );
  }

  void dispose() {
    _zoomDebounceTimer?.cancel();
  }
}
