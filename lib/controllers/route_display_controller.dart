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
        double lineWidth = 4.0;
        double shadowWidth = 6.0;
        if (mode == 'WALK') {
          legColor = Colors.blueAccent;
        } else if (mode == 'BUS' || mode == 'TRANSIT') {
          legColor = Colors.deepOrangeAccent;
          lineWidth = 5.0;
          shadowWidth = 7.0;
        } else {
          legColor = Colors.grey;
        }
        await mapboxService.drawRouteSegment(
          positions,
          "${RouteDisplayController.OTP_ROUTE_SOURCE_PREFIX}$i",
          "${RouteDisplayController.OTP_ROUTE_LAYER_PREFIX}$i",
          legColor,
          i,
          lineWidth: lineWidth,
          shadowWidth: shadowWidth,
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

  Future<void> updateMapRouteHighlight() async {
    // No necesitamos mapboxMap directamente aquí si mapboxService lo maneja.
    // if (mapboxMap == null || mapboxService == null) return;
    final selectedLegIndex = ref.read(mapNotifierProvider).selectedLegIndex;
    // Asegurarse que mapboxService está disponible, aunque el constructor lo requiere.
    await mapboxService.updateMapRouteHighlight(selectedLegIndex);
  }
}
