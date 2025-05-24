import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import 'map_manager.dart';

/// Módulo especializado en controlar la cámara y zoom del mapa
class MapCameraController {
  final MapboxMap? mapboxMap;
  final MapManager mapManager;

  MapCameraController(this.mapboxMap, this.mapManager);

  /// Hacer zoom a preview de ruta completa
  Future<void> zoomToRoutePreview(OpcionDeRutaMostrable route) async {
    if (mapboxMap == null) return;

    print("[MapCameraController] Zooming to route preview");

    // Recolectar todas las coordenadas de la ruta
    List<Coordenada> allCoordinates = [];

    for (final tramo in route.tramosParaPreview) {
      if (tramo.geometriaPolilinea != null &&
          tramo.geometriaPolilinea!.isNotEmpty) {
        allCoordinates.addAll(tramo.geometriaPolilinea!);
      } else if (tramo.posicionPunto != null) {
        allCoordinates.add(tramo.posicionPunto!);
      }
    }

    // Agregar coordenadas del bus en tiempo real si existe
    _addBusCoordinatesToZoom(route, allCoordinates);

    if (allCoordinates.isNotEmpty) {
      await _zoomToCoordinates(allCoordinates, _getPreviewPadding());
    }
  }

  /// Hacer zoom a viaje activo
  Future<void> zoomToActiveTrip(List<TramoViajeMostrable> tramos) async {
    if (mapboxMap == null || tramos.isEmpty) return;

    print("[MapCameraController] Zooming to active trip");

    // Recolectar todas las coordenadas del viaje
    List<Coordenada> allCoordinates = [];

    for (final tramo in tramos) {
      if (tramo.geometriaPolilinea != null &&
          tramo.geometriaPolilinea!.isNotEmpty) {
        allCoordinates.addAll(tramo.geometriaPolilinea!);
      } else if (tramo.posicionPunto != null) {
        allCoordinates.add(tramo.posicionPunto!);
      }
    }

    if (allCoordinates.isNotEmpty) {
      await _zoomToCoordinates(allCoordinates, _getActiveTripPadding());
    }
  }

  /// Hacer zoom a tramo actual del viaje activo
  Future<void> zoomToCurrentLeg(
    int legIndex,
    List<TramoViajeMostrable> tramos,
  ) async {
    if (mapboxMap == null || legIndex >= tramos.length) return;

    print("[MapCameraController] Zooming to current leg: $legIndex");

    final tramo = tramos[legIndex];
    List<Coordenada> coordinatesForZoom = [];

    try {
      // Agregar coordenadas del tramo actual
      if (tramo.geometriaPolilinea != null &&
          tramo.geometriaPolilinea!.isNotEmpty) {
        coordinatesForZoom.addAll(tramo.geometriaPolilinea!);
      } else if (tramo.posicionPunto != null) {
        coordinatesForZoom.add(tramo.posicionPunto!);
      }

      // Si es un tramo ESPERAR_BUS, incluir coordenadas del bus en tiempo real
      if (tramo.tipo == TipoTramoViaje.ESPERAR_BUS) {
        _addBusCoordinatesForWaitingLeg(tramos, legIndex, coordinatesForZoom);
      }

      // Hacer zoom según las coordenadas disponibles
      if (coordinatesForZoom.length > 1) {
        // Múltiples coordenadas: usar zoom a región
        await _zoomToCoordinates(coordinatesForZoom, _getCurrentLegPadding());
      } else if (coordinatesForZoom.length == 1) {
        // Una sola coordenada: zoom centrado
        final punto = coordinatesForZoom.first;
        await mapboxMap!.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(punto.longitud, punto.latitud)),
            zoom: 16.0,
          ),
          MapAnimationOptions(duration: 1200),
        );
      }
    } catch (e) {
      print("[MapCameraController] Error zooming to current leg: $e");
    }
  }

  /// Agregar coordenadas del bus en tiempo real para el zoom
  void _addBusCoordinatesToZoom(
    OpcionDeRutaMostrable route,
    List<Coordenada> allCoordinates,
  ) {
    print("[MapCameraController] Adding bus coordinates for zoom calculation");

    int busesAddedToZoom = 0;

    // Buscar el primer tramo de bus con posición en tiempo real
    for (int i = 0; i < route.tramosParaPreview.length; i++) {
      final tramo = route.tramosParaPreview[i];

      if ((tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS ||
              tramo.tipo == TipoTramoViaje.ESPERAR_BUS) &&
          tramo.posicionActualBus != null) {
        allCoordinates.add(tramo.posicionActualBus!);
        busesAddedToZoom++;

        print(
          "[MapCameraController] Added bus coordinates for line ${tramo.nombreLineaBus}: "
          "(${tramo.posicionActualBus!.latitud}, ${tramo.posicionActualBus!.longitud})",
        );

        // Solo agregar el primer bus encontrado (más relevante para preview)
        break;
      }
    }

    // Si no encontramos bus en los tramos, intentar con el ETA general
    if (busesAddedToZoom == 0 &&
        route.etaProximoBus != null &&
        route.etaProximoBus!.posicionBus != null) {
      allCoordinates.add(route.etaProximoBus!.posicionBus!);
      busesAddedToZoom++;

      print(
        "[MapCameraController] Added bus coordinates from general ETA for line ${route.etaProximoBus!.linea}: "
        "(${route.etaProximoBus!.posicionBus!.latitud}, ${route.etaProximoBus!.posicionBus!.longitud})",
      );
    }

    print(
      "[MapCameraController] Total bus coordinates added to zoom: $busesAddedToZoom",
    );
  }

  /// Hacer zoom a lista de coordenadas con padding específico
  Future<void> _zoomToCoordinates(
    List<Coordenada> coordinates,
    MbxEdgeInsets padding,
  ) async {
    if (mapboxMap == null || coordinates.isEmpty) return;

    try {
      // Convertir coordenadas a puntos de Mapbox
      final mapboxPoints =
          coordinates
              .map((c) => Point(coordinates: Position(c.longitud, c.latitud)))
              .toList();

      // Calcular opciones de cámara para mostrar todas las coordenadas
      final cameraOptions = await mapboxMap!.cameraForCoordinates(
        mapboxPoints,
        padding,
        null,
        null,
      );

      // Hacer el zoom con animación
      await mapboxMap!.flyTo(
        cameraOptions,
        MapAnimationOptions(duration: 1200),
      );
    } catch (e) {
      print("[MapCameraController] Error zooming to coordinates: $e");
    }
  }

  /// Obtener padding para preview de ruta
  MbxEdgeInsets _getPreviewPadding() {
    // Padding aumentado para considerar la card de opciones en la parte inferior
    return MbxEdgeInsets(
      top: 100.0,
      left: 50.0,
      bottom: 400.0, // Espacio generoso para el carousel
      right: 50.0,
    );
  }

  /// Obtener padding para viaje activo
  MbxEdgeInsets _getActiveTripPadding() {
    return MbxEdgeInsets(
      top: 250.0, // Espacio para la card de instrucciones
      left: 40.0,
      bottom: 100.0, // Espacio para panel de navegación
      right: 40.0,
    );
  }

  /// Obtener padding para tramo actual
  MbxEdgeInsets _getCurrentLegPadding() {
    return MbxEdgeInsets(
      top: 250.0,
      left: 40.0,
      bottom: 120.0, // Un poco más de espacio inferior
      right: 40.0,
    );
  }

  /// Agregar coordenadas del bus en tiempo real para tramo de espera
  void _addBusCoordinatesForWaitingLeg(
    List<TramoViajeMostrable> tramos,
    int currentLegIndex,
    List<Coordenada> coordinatesForZoom,
  ) {
    print(
      "[MapCameraController] Looking for bus coordinates for waiting leg $currentLegIndex",
    );

    // Primero, intentar obtener coordenadas del sistema centralizado de tracking
    final busPosition = mapManager.getCurrentBusPosition();
    if (busPosition != null) {
      coordinatesForZoom.add(busPosition);
      print(
        "[MapCameraController] Added bus coordinates from centralized tracking: "
        "(${busPosition.latitud}, ${busPosition.longitud})",
      );
      return;
    }

    // Si no hay tracking activo, buscar en los tramos información estática
    // 1. Verificar si el tramo actual tiene información de bus
    final tramoActual = tramos[currentLegIndex];
    if (tramoActual.posicionActualBus != null) {
      coordinatesForZoom.add(tramoActual.posicionActualBus!);
      print(
        "[MapCameraController] Added bus coordinates from current waiting leg: "
        "(${tramoActual.posicionActualBus!.latitud}, ${tramoActual.posicionActualBus!.longitud})",
      );
      return;
    }

    // 2. Buscar el siguiente tramo VIAJE_EN_BUS que tenga información de bus
    for (int i = currentLegIndex + 1; i < tramos.length; i++) {
      final tramo = tramos[i];

      if (tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS &&
          tramo.posicionActualBus != null) {
        coordinatesForZoom.add(tramo.posicionActualBus!);
        print(
          "[MapCameraController] Added bus coordinates from next bus leg $i: "
          "(${tramo.posicionActualBus!.latitud}, ${tramo.posicionActualBus!.longitud})",
        );
        return;
      }
    }

    print(
      "[MapCameraController] No bus coordinates available for waiting leg zoom",
    );
  }
}
