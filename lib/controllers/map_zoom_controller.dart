import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../services/mapbox_service.dart';
import '../state/map_state.dart'; // Para ZoomTarget y MapState
import '../providers/map_notifier.dart'; // Para leer MapState

// Podríamos mover _initialCameraOptions aquí si es puramente de zoom inicial.
// Por ahora, lo mantenemos en MapScreen y lo pasamos si es necesario,
// o el MapZoomController lo reconstruye si es una constante fija.

class MapZoomController {
  final MapboxMap mapboxMap;
  final MapboxService mapboxService;
  final WidgetRef ref; // Para acceder a MapState

  // Constantes que podrían ser necesarias para el zoom, o pasadas como parámetros
  static final CameraOptions initialCameraOptions = CameraOptions(
    center: Point(
      coordinates: Position(
        -56.164532, // Longitud de Montevideo
        -34.901112, // Latitud de Montevideo
      ),
    ),
    zoom: 12.0,
  );

  MapZoomController({
    required this.mapboxMap,
    required this.mapboxService,
    required this.ref,
  });

  void handleZoomTarget(ZoomTarget zoomTarget) {
    // La lógica del switch irá aquí
    print("[MapZoomController_DEBUG] Handling zoom target: ${zoomTarget.type}");
    final mapState = ref.read(mapNotifierProvider);

    switch (zoomTarget.type) {
      case ZoomTargetType.initial:
        print("[MapZoomController_DEBUG] Zooming to initial camera options.");
        mapboxMap.flyTo(
          initialCameraOptions, // Usar la constante local o una pasada
          MapAnimationOptions(duration: 1000),
        );
        break;
      case ZoomTargetType.overview:
        if (mapState.currentRouteLegs.isNotEmpty) {
          print("[MapZoomController_DEBUG] Zooming to route overview.");
          mapboxService.zoomToRouteBounds(mapState.currentRouteLegs);
        }
        break;
      case ZoomTargetType.leg:
        if (zoomTarget.legIndex != null &&
            mapState.currentRouteLegs.isNotEmpty) {
          print(
            "[MapZoomController_DEBUG] Zooming to leg ${zoomTarget.legIndex}.",
          );
          _zoomToLeg(
            zoomTarget.legIndex!,
            mapState, // Pasar mapState para acceder a highlightedBusPosition si es necesario
          );
        }
        break;
      case ZoomTargetType.busAndLegOrigin:
        if (zoomTarget.legIndex != null &&
            mapState.currentRouteLegs.isNotEmpty) {
          print(
            "[MapZoomController_DEBUG] Zooming to bus and leg origin for leg ${zoomTarget.legIndex}.",
          );
          _zoomToLeg(
            zoomTarget.legIndex!,
            mapState, // Pasar mapState para acceder a highlightedBusPosition
          );
        }
        break;
      case ZoomTargetType.points:
        if (zoomTarget.points != null && zoomTarget.points!.isNotEmpty) {
          print(
            "[MapZoomController_DEBUG] Zooming to fit points: ${zoomTarget.points}.",
          );
          mapboxService.zoomToFitPositions(
            zoomTarget.points!,
            const EdgeInsets.all(70.0), // Considerar hacer esto configurable
          );
        }
        break;
      case ZoomTargetType.origenSelection:
      case ZoomTargetType.destinoSelection:
        if (zoomTarget.singlePoint != null) {
          print(
            "[MapZoomController_DEBUG] Zooming to single point: ${zoomTarget.singlePoint}.",
          );
          mapboxMap.flyTo(
            CameraOptions(
              center: Point(coordinates: zoomTarget.singlePoint!),
              zoom: 15.0, // Considerar hacer esto configurable
              padding: MbxEdgeInsets(
                top: 100.0,
                bottom: 100.0,
                left: 50.0,
                right: 50.0,
              ), // Considerar hacer esto configurable
            ),
            MapAnimationOptions(duration: 1200), // Configurable
          );
        }
        break;
      case ZoomTargetType.none:
        print(
          "[MapZoomController_DEBUG] Zoom target is none. No specific zoom action.",
        );
        break;
    }
  }

  // Método _zoomToLeg adaptado de _MapScreenState
  Future<void> _zoomToLeg(int legIndex, MapState mapState) async {
    print(
      "[MapZoomController_DEBUG] _zoomToLeg llamado para el tramo: $legIndex",
    );

    if (legIndex < 0 || legIndex >= mapState.currentRouteLegs.length) {
      print("[MapZoomController_DEBUG] _zoomToLeg: Invalid legIndex.");
      return;
    }

    Position? busPositionToInclude;
    // Accedemos a mapState.currentZoomTarget de forma segura
    final currentZoomTarget = mapState.currentZoomTarget;
    if (currentZoomTarget.type == ZoomTargetType.busAndLegOrigin &&
        currentZoomTarget.legIndex == legIndex) {
      busPositionToInclude = mapState.highlightedBusPosition;
    }

    try {
      await mapboxService.zoomToLeg(
        mapState.currentRouteLegs,
        legIndex,
        busPositionToInclude,
        mapState.showCollapsedInstructionsBar,
      );
    } catch (e) {
      print(
        "[MapZoomController_DEBUG] _zoomToLeg: Exception calling mapboxService.zoomToLeg: $e",
      );
    }
  }

  void dispose() {
    // Aquí deberías cancelar Timers, StreamSubscriptions o cualquier otro recurso
    // que el MapZoomController pueda estar utilizando.
    // Ejemplo: _myTimer?.cancel();
    print("[MapZoomController_DEBUG] dispose called.");
  }
}
