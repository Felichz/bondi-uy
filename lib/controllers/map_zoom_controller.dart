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

  void handleZoomTarget(ZoomTargetType target) async {
    print(
      "[MapZoomController_DEBUG] Debounced zoom. Target: $target",
    ); // Keep this print for now
    final mapState = ref.read(mapNotifierProvider);

    // MODIFIED: Allow zoom if idle OR in cooldown (cooldown might be from programmatic zoom)
    if (mapState.userMapInteraction == UserMapInteractionState.idle ||
        mapState.userMapInteraction ==
            UserMapInteractionState.manualMoveCooldown) {
      print(
        "[MapZoomController_DEBUG] _performZoom attempting. Target: $target. Current interaction state: ${mapState.userMapInteraction}", // Keep this print
      );

      bool zoomPerformed = false;

      switch (target) {
        case ZoomTargetType.initial:
          // Podríamos tener una animación más suave para el zoom inicial
          await mapboxMap.flyTo(
            initialCameraOptions,
            MapAnimationOptions(duration: 1200), // Animación suave
          );
          print(
            "[MapZoomController_DEBUG] ZoomTargetType.initial zoom performed.",
          ); // Keep this
          zoomPerformed = true;
          break;
        case ZoomTargetType.origenSelection:
          // Lógica de zoom a origen seleccionado... (si aplica)
          // Considerar un zoom a un nivel adecuado para seleccionar un punto
          // Por ahora, puede que no haga nada o un zoom básico
          print(
            "[MapZoomController_DEBUG] ZoomTargetType.origenSelection - Not implemented yet.",
          ); // Keep this
          break;
        case ZoomTargetType.destinationSelection:
          // Lógica de zoom a destino seleccionado... (si aplica)
          print(
            "[MapZoomController_DEBUG] ZoomTargetType.destinationSelection - Not implemented yet.",
          ); // Keep this
          break;
        case ZoomTargetType.points:
          if (mapState.origin != null && mapState.destination != null) {
            final positions = [mapState.origin!, mapState.destination!];
            // Llama a zoomToFitPositions en MapboxService y pasa el callback
            zoomPerformed = await mapboxService.zoomToFitPositions(
              positions,
              const EdgeInsets.only(
                top: 120.0,
                bottom: 250.0,
                left: 40.0,
                right: 40.0,
              ), // Ajustar padding
              onAnimationEnd:
                  () => _handleProgrammaticZoomEnd(), // Pass callback
            );
            print(
              "[MapZoomController_DEBUG] ZoomTargetType.points zoom performed: $zoomPerformed.",
            ); // Keep this
          } else {
            // Keep this
            print(
              "[MapZoomController_DEBUG] ZoomTargetType.points - Origin or destination is null. Skipping.",
            ); // Keep this
          }
          break;
        case ZoomTargetType.overview:
          if (mapState.representativeItinerary != null) {
            // Llama a zoomToRouteBounds en MapboxService y pasa el callback
            zoomPerformed = await mapboxService.zoomToRouteBounds(
              mapState.representativeItinerary!.legs, // Pass the list of legs
              onAnimationEnd:
                  () => _handleProgrammaticZoomEnd(), // Pass callback
            );
            print(
              "[MapZoomController_DEBUG] ZoomTargetType.overview zoom performed: $zoomPerformed.",
            ); // Keep this
          } else {
            // Keep this
            print(
              "[MapZoomController_DEBUG] ZoomTargetType.overview - No representative itinerary. Skipping.",
            ); // Keep this
          }
          break;
        case ZoomTargetType.leg:
          if (mapState.representativeItinerary != null &&
              mapState.currentLegIndex != null) {
            // Llama a zoomToLeg en MapboxService y pasa el callback
            zoomPerformed = await mapboxService.zoomToLeg(
              mapState.representativeItinerary!.legs, // Pass the list of legs
              mapState.currentLegIndex!, // Pass leg index
              mapState.realDebugBusPosition ??
                  mapState
                      .simulatedBusPosition, // Pass bus position if available
              mapState
                  .showInstructionsPanel, // Pass instructions panel state for padding
              onAnimationEnd:
                  () => _handleProgrammaticZoomEnd(), // Pass callback
            );
            print(
              "[MapZoomController_DEBUG] ZoomTargetType.leg zoom performed: $zoomPerformed.",
            ); // Keep this
          } else {
            // Keep this
            print(
              "[MapZoomController_DEBUG] ZoomTargetType.leg - No representative itinerary or leg index. Skipping.",
            ); // Keep this
          }
          break;
        case ZoomTargetType.none:
          print(
            "[MapZoomController_DEBUG] ZoomTargetType.none - No zoom action needed.",
          ); // Keep this
          break;
      }

      // MODIFIED: Update programmatic zoom state in MapNotifier BEFORE initiating zoom animation
      if (zoomPerformed) {
        ref
            .read(mapNotifierProvider.notifier)
            .setIsPerformingProgrammaticZoom(true);
        print(
          "[MapZoomController_DEBUG] setIsPerformingProgrammaticZoom(true) called.",
        );
      }
    } else {
      // Keep this print
      print(
        "[MapZoomController_DEBUG] User is interacting with the map. Auto-zoom skipped. Interaction state: ${mapState.userMapInteraction}",
      );
    }
    // Siempre limpiar el target después de intentar manejarlo, independientemente del resultado del zoom.
    // El MapNotifier lo establecerá de nuevo si es necesario.
    // No limpiar aquí si el zoom fue skipped debido a interacción manual, el target se mantiene.
    // ref.read(mapNotifierProvider.notifier).clearZoomTarget(); // NO HACER ESTO AQUÍ!
  }

  // ADDED: Method to be called when a programmatic zoom animation finishes
  void _handleProgrammaticZoomEnd() {
    print("[MapZoomController_DEBUG] _handleProgrammaticZoomEnd called.");
    // Wait a very short delay to ensure MapboxMap's onMapIdleListener fires first
    Future.delayed(const Duration(milliseconds: 50), () {
      print(
        "[MapZoomController_DEBUG] _handleProgrammaticZoomEnd - Delay finished. Setting isPerformingProgrammaticZoom(false).",
      );
      ref
          .read(mapNotifierProvider.notifier)
          .setIsPerformingProgrammaticZoom(false);
      // After programmatic zoom ends, we might want to trigger auto-zoom logic again
      // to see if a new target was set while the animation was running.
      ref
          .read(mapNotifierProvider.notifier)
          .reEvaluateAutoZoom(); // Use the public method
    });
  }

  void dispose() {
    _zoomDebounceTimer?.cancel();
  }
}
