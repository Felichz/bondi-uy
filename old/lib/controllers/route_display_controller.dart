import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/material.dart'; // Para Colors
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

import '../services/mapbox_service.dart';
import '../state/map_state.dart';
import '../providers/map_notifier.dart';
import '../models/route_leg.dart';
// Ajustar las rutas de importación según la nueva ubicación
import '../models/point_dart.dart'
    as models; // Alias para evitar colisión y usar models.Point_dart

// ELIMINADAS: Constantes a nivel de archivo, se mueven a la clase
// const String OTP_ROUTE_SOURCE_PREFIX = "otp-route-source-";
// const String OTP_ROUTE_LAYER_PREFIX = "otp-route-layer-";

class RouteDisplayController {
  // AÑADIDO: Constantes como miembros estáticos de la clase
  static const String OTP_ROUTE_SOURCE_PREFIX = "otp-route-source-";
  static const String OTP_ROUTE_LAYER_PREFIX = "otp-route-layer-";

  final MapboxService mapboxService;
  final WidgetRef ref; // Para acceder a MapState y MapNotifier

  RouteDisplayController({required this.mapboxService, required this.ref});

  // Los métodos se moverán aquí
  Future<void> clearPreviousRouteLayers() async {
    // El MapboxMap se accede a través del mapboxService
    await mapboxService.clearAllRouteLayersAndSources();
    try {
      if (await mapboxService.mapboxMap.style.styleLayerExists(
        MapboxService.STOPS_LAYER_ID,
      )) {
        await mapboxService.mapboxMap.style.setStyleLayerProperty(
          MapboxService.STOPS_LAYER_ID,
          "visibility",
          "visible",
        );
      }
    } catch (e) {
      print(
        "[RouteDisplayController_Debug] Error restaurando visibilidad de capa ${MapboxService.STOPS_LAYER_ID}: $e",
      );
    }
  }

  void dispose() {
    // No hay nada que liberar específicamente para este controlador aún,
    // pero es buena práctica tener el método.
  }

  Future<bool> processAndDisplaySelectedItineraryUI(List<RouteLeg> legs) async {
    if (legs.isEmpty) {
      // Devuelve false para que MapScreenState muestre el mensaje
      return false;
    }

    // El mapboxMap se accede a través del mapboxService
    // if (mapboxService.mapboxMap == null) return false; // mapboxService siempre tiene mapboxMap

    for (int i = 0; i < legs.length; i++) {
      final RouteLeg leg = legs[i];
      final String mode = leg.mode.toUpperCase();
      final String polylineString = leg.legGeometry.points;

      if (polylineString.isNotEmpty) {
        List<PointLatLng> decodedPoints = PolylinePoints().decodePolyline(
          polylineString,
        );
        List<Position> positions =
            decodedPoints
                .map((p) => Position(p.longitude, p.latitude))
                .toList();
        Color legColor;
        double lineWidthValue = 4.0;
        double shadowWidth = 6.0;
        List<double>? lineDasharrayValue;
        if (mode == 'WALK') {
          legColor = Colors.blueAccent;
        } else if (mode == 'BUS' || mode == 'TRANSIT') {
          // TODO: TECH_DEBT - Obtener el color real de la ruta desde el Itinerary/ProcessedItinerary.
          // Actualmente leg.route no tiene gtfsRouteColor. Usamos un color por defecto.
          legColor = Colors.deepOrangeAccent;
          lineDasharrayValue = null; // Línea sólida
          lineWidthValue = 4.0;
        } else {
          legColor = Colors.grey;
          lineDasharrayValue = null;
          lineWidthValue = 4.0;
        }
        await mapboxService.drawRouteSegment(
          positions,
          "${RouteDisplayController.OTP_ROUTE_SOURCE_PREFIX}$i",
          "${RouteDisplayController.OTP_ROUTE_LAYER_PREFIX}$i",
          legColor,
          i,
          lineWidth: lineWidthValue,
          shadowWidth: shadowWidth,
          lineDasharray: lineDasharrayValue,
        );
      }
    }

    await mapboxService.displayRelevantStops(legs);
    await applyOverviewRouteStyle(); // Este método también se moverá al controlador

    try {
      if (await mapboxService.mapboxMap.style.styleLayerExists(
        MapboxService.STOPS_LAYER_ID,
      )) {
        await mapboxService.mapboxMap.style.setStyleLayerProperty(
          MapboxService.STOPS_LAYER_ID,
          "visibility",
          "none",
        );
      }
    } catch (e) {
      print(
        "[RouteDisplayController_Debug] Error ocultando capa ${MapboxService.STOPS_LAYER_ID}: $e",
      );
    }
    return true;
  }

  // _applyOverviewRouteStyle se moverá aquí también
  Future<void> applyOverviewRouteStyle() async {
    // if (mapboxService.mapboxMap == null) return; // mapboxService siempre tiene mapboxMap
    await mapboxService.applyOverviewRouteStyle();
  }

  // AÑADIDO: Método updateMapRouteHighlight movido y adaptado desde _MapScreenState
  Future<void> updateMapRouteHighlight() async {
    // MODIFICADO: No usar el parámetro, leer directamente del estado
    final mapState = ref.read(mapNotifierProvider);
    final currentSelectedLegIndex = mapState.currentLegIndex;

    print(
      "[RouteDisplayController_Debug] updateMapRouteHighlight called. Reading selectedLegIndex from state: $currentSelectedLegIndex",
    );
    if (currentSelectedLegIndex == null)
      return; // No hay capas de tramos para actualizar

    print(
      "[RouteDisplayController_Debug] Calling mapboxService.updateMapRouteHighlight with selectedLegIndex from state: $currentSelectedLegIndex",
    );
    await mapboxService.updateMapRouteHighlight(currentSelectedLegIndex);
  }
}
