import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/material.dart'; // Necesario para Colors
import 'dart:convert'; // Necesario para json.encode
// AÑADIDO: Importar utilidades de geometría
import '../utils/geometry_utils.dart';
import '../models/point_dart.dart'; // Necesario para Point_dart en drawIncomingBusSegment
import '../models/route_leg.dart'; // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< IMPORTAR ROUTELEG
import 'dart:math' as math;
import 'package:flutter_polyline_points/flutter_polyline_points.dart'; // AÑADIDO PARA PointLatLng EN UTILS
import 'dart:async'; // AÑADIDO PARA TIMER

// Constantes que podrían ser movidas/referenciadas desde otro lugar en el futuro
// const String STOPS_SOURCE_ID = "stops-source"; // Movida adentro de la clase
// const String STOPS_LAYER_ID = "stops-layer"; // Movida adentro de la clase
// const String REALTIME_BUS_ICON_ID = "realtime-bus-icon"; // Movida adentro de la clase

class MapboxService {
  static const String STOPS_SOURCE_ID = "stops-source";
  static const String STOPS_LAYER_ID = "stops-layer";
  static const String REALTIME_BUS_ICON_ID = "realtime-bus-icon";

  // AÑADIDO: Constantes para capas/fuentes de ruta específicas, movidas de _MapScreenState
  static const String ROUTE_STOPS_SOURCE_ID = "route-stops-source";
  static const String ROUTE_MAIN_STOPS_LAYER_ID = "route-main-stops-layer";
  static const String ROUTE_INTERMEDIATE_STOPS_LAYER_ID =
      "route-intermediate-stops-layer";
  // AÑADIDO: Constantes para el segmento del bus en aproximación
  static const String INCOMING_BUS_SEGMENT_SOURCE_ID =
      "incoming-bus-segment-source";
  static const String INCOMING_BUS_SEGMENT_LAYER_ID =
      "incoming-bus-segment-layer";

  // AÑADIDO: Constantes faltantes para iconos y capa de tooltip
  static const String INCOMING_BUS_ICON_ID = "incoming-bus";
  static const String INCOMING_BUS_TOOLTIP_ICON_ID = "incoming-bus-tooltip";
  static const String INCOMING_BUS_TOOLTIP_LAYER_ID =
      "incoming-bus-tooltip-layer";

  final MapboxMap mapboxMap;
  bool _styleImagesAdded = false;
  bool _stopsAdded = false; // Para evitar recargar paradas

  // AÑADIDO: Campos para rastrear elementos de ruta dinámicos
  final List<String> _dynamicRouteSourceIds = [];
  final List<String> _dynamicRouteLayerIds = [];
  final Map<int, List<String>> _legLayerIds =
      {}; // Maps legIndex to [mainLayerId, shadowLayerId]

  // AÑADIDO: Campos para la animación del tooltip flotante
  Timer? _tooltipFloatTimer;
  double _tooltipFloatPhase = 0.0;
  double _lastTooltipOffset =
      0.0; // Aunque no se use externamente, se mantiene por consistencia con la lógica original

  MapboxService(this.mapboxMap);

  Future<void> handleStyleLoaded() async {
    print("[MapboxService_Debug] Estilo cargado.");
    if (_styleImagesAdded) {
      print("[MapboxService_Debug] Imágenes de estilo ya añadidas.");
      // Si las imágenes ya están, pero las paradas no (podría pasar si el estilo se recarga),
      // igualmente intentar cargar las paradas.
      if (!_stopsAdded) {
        print(
          "[MapboxService_Debug] Imágenes añadidas, pero paradas no. Intentando cargar paradas...",
        );
        await loadStopsData();
      }
      return;
    }

    try {
      print(
        "[MapboxService_Debug] Añadiendo imágenes personalizadas al estilo...",
      );

      final ByteData busIconByteData = await rootBundle.load(
        'assets/icons/bus_icon.png',
      );
      final Uint8List busIconImageData = busIconByteData.buffer.asUint8List();
      await mapboxMap.style.addStyleImage(
        "bus-icon",
        1.0,
        MbxImage(width: 64, height: 64, data: busIconImageData),
        false,
        [],
        [],
        null,
      );
      print(
        "[MapboxService_Debug] Imagen 'bus-icon' (64x64) añadida al estilo.",
      );

      try {
        final ByteData realtimeBusIconByteData = await rootBundle.load(
          'assets/icons/realtime_bus_icon.png',
        );
        final Uint8List realtimeBusIconImageData =
            realtimeBusIconByteData.buffer.asUint8List();
        await mapboxMap.style.addStyleImage(
          REALTIME_BUS_ICON_ID,
          1.0,
          MbxImage(width: 64, height: 64, data: realtimeBusIconImageData),
          false,
          [],
          [],
          null,
        );
        // _realtimeBusIconLoaded = true; // Esta bandera es de MapScreenState, decidir si se necesita aquí o pasarla.
        print(
          "[MapboxService_Debug] Imagen '$REALTIME_BUS_ICON_ID' (64x64) para buses en tiempo real añadida al estilo.",
        );
      } catch (e) {
        print(
          "[MapboxService_Debug] No se pudo cargar 'assets/icons/realtime_bus_icon.png' (64x64). Se usará 'bus-icon' como fallback. Error: $e",
        );
      }

      try {
        final ByteData highlightedBusIconByteData = await rootBundle.load(
          'assets/icons/incoming_bus.png',
        );
        final Uint8List highlightedBusIconImageData =
            highlightedBusIconByteData.buffer.asUint8List();
        await mapboxMap.style.addStyleImage(
          INCOMING_BUS_ICON_ID,
          1.5,
          MbxImage(width: 256, height: 256, data: highlightedBusIconImageData),
          false,
          [],
          [],
          null,
        );
        print(
          "[MapboxService_Debug] Imagen 'incoming-bus' (256x256) para bus resaltado añadida al estilo.",
        );
      } catch (e) {
        print(
          "[MapboxService_Debug] No se pudo cargar 'assets/icons/incoming_bus.png' (256x256). Error: $e",
        );
      }

      try {
        final ByteData tooltipIconByteData = await rootBundle.load(
          'assets/icons/incoming_bus_tooltip.png',
        );
        final Uint8List tooltipIconImageData =
            tooltipIconByteData.buffer.asUint8List();
        await mapboxMap.style.addStyleImage(
          INCOMING_BUS_TOOLTIP_ICON_ID,
          1.5,
          MbxImage(width: 256, height: 256, data: tooltipIconImageData),
          false,
          [],
          [],
          null,
        );
        print(
          "[MapboxService_Debug] Imagen '${INCOMING_BUS_TOOLTIP_ICON_ID}' (256x256) para tooltip añadida al estilo.",
        );
      } catch (e) {
        print(
          "[MapboxService_Debug] No se pudo cargar 'assets/icons/incoming_bus_tooltip.png' (256x256). Error: $e",
        );
      }

      _styleImagesAdded = true;
      print(
        "[MapboxService_Debug] Llamando a loadStopsData después de añadir imágenes...",
      );
      await loadStopsData();

      // Ocultar la barra de escala del mapa
      try {
        final scaleBar = mapboxMap.scaleBar;
        await scaleBar.updateSettings(ScaleBarSettings(enabled: false));
        print(
          "[MapboxService_Debug] Barra de escala configurada para estar oculta.",
        );
      } catch (e_scale) {
        print(
          "[MapboxService_Debug] Error al intentar ocultar la barra de escala: $e_scale",
        );
      }
    } catch (e, s) {
      print(
        "[MapboxService_Debug] Error añadiendo imagen de estilo o cargando datos: $e",
      );
      print(s);
    }
  }

  Future<void> loadStopsData() async {
    if (_stopsAdded) {
      print(
        "[MapboxService_Debug] Paradas ya cargadas (flag _stopsAdded), ignorando.",
      );
      return;
    }
    print("[MapboxService_Debug] Iniciando loadStopsData...");

    try {
      final String geoJsonData = await rootBundle.loadString(
        'assets/data/stops.geojson',
      );

      final sourceExists = await mapboxMap.style.styleSourceExists(
        MapboxService.STOPS_SOURCE_ID,
      );
      if (!sourceExists) {
        await mapboxMap.style.addSource(
          GeoJsonSource(id: MapboxService.STOPS_SOURCE_ID, data: geoJsonData),
        );
        print(
          "[MapboxService_Debug] GeoJsonSource '${MapboxService.STOPS_SOURCE_ID}' añadida al estilo.",
        );
      } else {
        print(
          "[MapboxService_Debug] GeoJsonSource '${MapboxService.STOPS_SOURCE_ID}' ya existe.",
        );
        // Podríamos actualizar la fuente si es necesario, pero para paradas estáticas usualmente no.
        // GeoJsonSource source = await mapboxMap.style.getSource(STOPS_SOURCE_ID) as GeoJsonSource;
        // await source.updateGeoJSON(geoJsonData);
      }

      final layerExists = await mapboxMap.style.styleLayerExists(
        MapboxService.STOPS_LAYER_ID,
      );
      if (!layerExists) {
        await mapboxMap.style.addLayer(
          SymbolLayer(
            id: MapboxService.STOPS_LAYER_ID,
            sourceId: MapboxService.STOPS_SOURCE_ID,
            iconImage: "bus-icon",
            iconSize: 0.4,
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
            minZoom: 13.5,
          ),
        );
        // await _printLayerOrder(); // _printLayerOrder es de _MapScreenState, se necesitaría una referencia o moverlo
        print(
          "[MapboxService_Debug] SymbolLayer '${MapboxService.STOPS_LAYER_ID}' para paradas generales añadida.",
        );
      } else {
        print(
          "[MapboxService_Debug] SymbolLayer '${MapboxService.STOPS_LAYER_ID}' ya existe.",
        );
      }
      _stopsAdded =
          true; // Marcar que las paradas se intentaron cargar/verificar
    } catch (e, s) {
      print("[MapboxService_Debug] Error en loadStopsData: $e");
      print("[MapboxService_Debug] Stack trace: $s");
    }
  }

  // AÑADIDO: Método _printLayerOrder movido desde _MapScreenState
  Future<void> _printLayerOrder() async {
    // if (mapboxMap == null) return; // mapboxMap es final y non-null aquí
    try {
      final layers = await mapboxMap.style.getStyleLayers();
      // print('[MapboxService_Debug] Orden actual de capas:');
      for (final l in layers) {
        // Corrección para ANSI escape codes
        print('  - \x1B[36m${l?.id ?? "(null)"}\x1B[0m');
      }
    } catch (e) {
      print('[MapboxService_Debug] Error obteniendo el orden de capas: $e');
    }
  }

  // AÑADIDO: Método drawRouteSegment movido y adaptado desde _MapScreenState
  Future<void> drawRouteSegment(
    List<Position> positions,
    String sourceId,
    String layerId,
    Color lineColor,
    int legIndex, {
    double lineWidth = 4.0,
    double shadowWidth = 6.0,
  }) async {
    if (positions.length < 2) return;

    final Map<String, dynamic> geometry = {
      'type': 'LineString',
      'coordinates': positions.map((p) => [p.lng, p.lat]).toList(),
    };

    final Map<String, dynamic> geoJsonFeature = {
      "type": "FeatureCollection",
      "features": [
        {"type": "Feature", "geometry": geometry, "properties": {}},
      ],
    };
    final String geoJsonData = json.encode(geoJsonFeature);

    try {
      final sourceExists = await mapboxMap.style.styleSourceExists(sourceId);
      if (!sourceExists) {
        await mapboxMap.style.addSource(
          GeoJsonSource(id: sourceId, data: geoJsonData),
        );
      } else {
        final source =
            await mapboxMap.style.getSource(sourceId) as GeoJsonSource?;
        await source?.updateGeoJSON(geoJsonData);
      }
      _dynamicRouteSourceIds.add(sourceId);

      final shadowLayerId = "$layerId-shadow";
      final shadowLayerExists = await mapboxMap.style.styleLayerExists(
        shadowLayerId,
      );
      if (!shadowLayerExists) {
        await mapboxMap.style.addLayer(
          LineLayer(
            id: shadowLayerId,
            sourceId: sourceId,
            lineColor: Colors.black.withOpacity(0.4).value,
            lineWidth: shadowWidth,
            lineOpacity: 0.7,
            lineJoin: LineJoin.ROUND,
            lineCap: LineCap.ROUND,
          ),
        );
        await _printLayerOrder();
        _dynamicRouteLayerIds.add(shadowLayerId);
      }

      final mainLayerId = layerId;
      final mainLayerExists = await mapboxMap.style.styleLayerExists(
        mainLayerId,
      );
      if (!mainLayerExists) {
        await mapboxMap.style.addLayer(
          LineLayer(
            id: mainLayerId,
            sourceId: sourceId,
            lineColor: lineColor.value,
            lineWidth: lineWidth,
            lineOpacity: 0.9,
            lineJoin: LineJoin.ROUND,
            lineCap: LineCap.ROUND,
          ),
        );
        await _printLayerOrder();
        _dynamicRouteLayerIds.add(mainLayerId);
      }

      if (legIndex != 9999) {
        // Solo añade a _legLayerIds si NO es la capa especial del bus en aproximación
        _legLayerIds[legIndex] = [mainLayerId, shadowLayerId];
      }
      print(
        "[MapboxService_Debug] Segmento de ruta ($mainLayerId) dibujado (con sombra) por MapboxService.",
      );
    } catch (e) {
      print(
        "[MapboxService_Debug] Error añadiendo fuente/capa para segmento $layerId: $e",
      );
    }
  }

  // AÑADIDO: Método updateMapRouteHighlight movido y adaptado desde _MapScreenState
  Future<void> updateMapRouteHighlight(int? selectedLegIndex) async {
    if (_legLayerIds.isEmpty) return; // No hay capas de tramos para actualizar

    for (final entry in _legLayerIds.entries) {
      final legIndex = entry.key;
      final layerIds = entry.value; // [mainLayerId, shadowLayerId]
      if (layerIds.length != 2) continue; // Asegurar que tenemos ambos IDs
      final mainLayerId = layerIds[0];
      final shadowLayerId = layerIds[1];

      final bool isSelected = legIndex == selectedLegIndex;

      final mainOpacity = isSelected ? 0.9 : 0.35;
      final mainWidth = isSelected ? 6.0 : 3.0;
      final shadowOpacity = isSelected ? 0.7 : 0.25;
      final shadowWidth = isSelected ? 8.0 : 5.0;

      try {
        // Actualizar capa principal
        if (await mapboxMap.style.styleLayerExists(mainLayerId)) {
          await mapboxMap.style.setStyleLayerProperty(
            mainLayerId,
            "line-opacity",
            mainOpacity,
          );
          await mapboxMap.style.setStyleLayerProperty(
            mainLayerId,
            "line-width",
            mainWidth,
          );
        }

        // Actualizar capa de sombra
        if (await mapboxMap.style.styleLayerExists(shadowLayerId)) {
          await mapboxMap.style.setStyleLayerProperty(
            shadowLayerId,
            "line-opacity",
            shadowOpacity,
          );
          await mapboxMap.style.setStyleLayerProperty(
            shadowLayerId,
            "line-width",
            shadowWidth,
          );
        }
      } catch (e) {
        print(
          "[MapboxService_Debug] Error actualizando propiedades de capa para el tramo $legIndex: $e",
        );
      }
    }
    print(
      "[MapboxService_Debug] Resaltado de ruta actualizado por MapboxService. Tramo seleccionado: $selectedLegIndex",
    );
  }

  // AÑADIDO: Método clearAllRouteLayersAndSources movido y adaptado desde _MapScreenState._clearPreviousRouteLayers
  Future<void> clearAllRouteLayersAndSources() async {
    print(
      "[MapboxService_Debug] Limpiando capas y fuentes de ruta anteriores (desde MapboxService)...",
    );

    // Limpiar capas y fuentes de los segmentos de la ruta (usando listas internas del servicio)
    for (String layerId in _dynamicRouteLayerIds) {
      try {
        await mapboxMap.style.removeStyleLayer(layerId);
      } catch (e) {
        print(
          "[MapboxService_Debug] Advertencia: No se pudo remover la capa de segmento $layerId: $e",
        );
      }
    }
    _dynamicRouteLayerIds.clear();

    for (String sourceId in _dynamicRouteSourceIds) {
      try {
        await mapboxMap.style.removeStyleSource(sourceId);
      } catch (e) {
        print(
          "[MapboxService_Debug] Advertencia: No se pudo remover la fuente de segmento $sourceId: $e",
        );
      }
    }
    _dynamicRouteSourceIds.clear();
    _legLayerIds.clear(); // Limpiar mapeo de capas de tramos

    // Limpiar también la capa y fuente de las paradas de ruta específicas
    try {
      if (await mapboxMap.style.styleLayerExists(ROUTE_MAIN_STOPS_LAYER_ID)) {
        await mapboxMap.style.removeStyleLayer(ROUTE_MAIN_STOPS_LAYER_ID);
        print(
          "[MapboxService_Debug] Capa de paradas principales de ruta ($ROUTE_MAIN_STOPS_LAYER_ID) eliminada.",
        );
      }
      if (await mapboxMap.style.styleLayerExists(
        ROUTE_INTERMEDIATE_STOPS_LAYER_ID,
      )) {
        await mapboxMap.style.removeStyleLayer(
          ROUTE_INTERMEDIATE_STOPS_LAYER_ID,
        );
        print(
          "[MapboxService_Debug] Capa de paradas intermedias de ruta ($ROUTE_INTERMEDIATE_STOPS_LAYER_ID) eliminada.",
        );
      }
    } catch (e) {
      print(
        "[MapboxService_Debug] Adv: No se pudo remover alguna de las capas de paradas de ruta: $e",
      );
    }
    try {
      if (await mapboxMap.style.styleSourceExists(ROUTE_STOPS_SOURCE_ID)) {
        await mapboxMap.style.removeStyleSource(ROUTE_STOPS_SOURCE_ID);
        print(
          "[MapboxService_Debug] Fuente de paradas de ruta ($ROUTE_STOPS_SOURCE_ID) eliminada.",
        );
      }
    } catch (e) {
      // No es crítico
    }

    // Asegurar que la capa de paradas generales (STOPS_LAYER_ID) sea visible
    try {
      if (await mapboxMap.style.styleLayerExists(STOPS_LAYER_ID)) {
        await mapboxMap.style.setStyleLayerProperty(
          STOPS_LAYER_ID,
          "visibility",
          "visible",
        );
        print(
          "[MapboxService_Debug] Capa de paradas generales ($STOPS_LAYER_ID) restaurada a visible.",
        );
      }
    } catch (e) {
      print(
        "[MapboxService_Debug] Error restaurando visibilidad de capa $STOPS_LAYER_ID: $e",
      );
    }
  }

  // AÑADIDO: Método displayRelevantStops movido y adaptado desde _MapScreenState
  Future<void> displayRelevantStops(
    List<RouteLeg> legs, {
    String? busIconName = "bus-icon",
  }) async {
    List<Map<String, dynamic>> relevantStopFeatures = [];
    Set<String> addedStopFeatureIds =
        {}; // Para evitar duplicados usando un ID único de feature

    for (var leg in legs) {
      final String mode = leg.mode.toUpperCase();
      if (mode == 'BUS' || mode == 'TRANSIT') {
        // Parada de inicio del tramo de bus (leg.from)
        final LegEndpoint fromPlace = leg.from;
        if (fromPlace.lat != 0.0 || fromPlace.lon != 0.0) {
          // Evitar puntos (0,0) si son inválidos
          // Usar lat,lon para un ID único si no hay stopId específico del endpoint
          final String featureId = "from-${fromPlace.lat}-${fromPlace.lon}";
          if (!addedStopFeatureIds.contains(featureId)) {
            relevantStopFeatures.add({
              "type": "Feature",
              // "id": featureId, // Opcional: Mapbox puede generar IDs si no se proveen
              "geometry": {
                "type": "Point",
                "coordinates": [fromPlace.lon, fromPlace.lat],
              },
              "properties": {
                "name": fromPlace.name ?? 'Parada de subida',
                "type": "route_stop",
                "stop_type": "main_stop",
                // "stop_id": null, // LegEndpoint no tiene stopId directamente
              },
            });
            addedStopFeatureIds.add(featureId);
          }
        }

        // Parada de fin del tramo de bus (leg.to)
        final LegEndpoint toPlace = leg.to;
        if (toPlace.lat != 0.0 || toPlace.lon != 0.0) {
          final String featureId = "to-${toPlace.lat}-${toPlace.lon}";
          if (!addedStopFeatureIds.contains(featureId)) {
            relevantStopFeatures.add({
              "type": "Feature",
              // "id": featureId,
              "geometry": {
                "type": "Point",
                "coordinates": [toPlace.lon, toPlace.lat],
              },
              "properties": {
                "name": toPlace.name ?? 'Parada de bajada',
                "type": "route_stop",
                "stop_type": "main_stop",
                // "stop_id": null,
              },
            });
            addedStopFeatureIds.add(featureId);
          }
        }

        // La lógica para intermediateStops se elimina porque RouteLeg no tiene intermediateStops definido
        // y LegEndpoint no tiene el GTFS ID de la parada.
      }
    }

    if (relevantStopFeatures.isEmpty) {
      print(
        "[MapboxService_Debug] No se encontraron paradas principales (from/to) en la ruta para mostrar.",
      );
      await _removeRouteStopsLayersAndSource(); // Método helper para limpiar capas previas
      return;
    }

    final Map<String, dynamic> geoJsonFeatureCollection = {
      "type": "FeatureCollection",
      "features": relevantStopFeatures,
    };
    final String geoJsonData = json.encode(geoJsonFeatureCollection);

    try {
      final sourceExists = await mapboxMap.style.styleSourceExists(
        ROUTE_STOPS_SOURCE_ID,
      );
      if (!sourceExists) {
        await mapboxMap.style.addSource(
          GeoJsonSource(id: ROUTE_STOPS_SOURCE_ID, data: geoJsonData),
        );
      } else {
        final source =
            await mapboxMap.style.getSource(ROUTE_STOPS_SOURCE_ID)
                as GeoJsonSource?;
        await source?.updateGeoJSON(geoJsonData);
      }

      // Ya no hay capa de paradas intermedias, solo principales.
      // Asegurar que la capa de paradas principales exista y tenga el filtro correcto
      final mainLayerExists = await mapboxMap.style.styleLayerExists(
        ROUTE_MAIN_STOPS_LAYER_ID,
      );
      final mainStopsFilter = [
        '==',
        ['get', 'stop_type'],
        'main_stop',
      ];

      if (!mainLayerExists) {
        await mapboxMap.style.addLayer(
          SymbolLayer(
            id: ROUTE_MAIN_STOPS_LAYER_ID,
            sourceId: ROUTE_STOPS_SOURCE_ID,
            filter: mainStopsFilter,
            iconImage: busIconName,
            iconSize: 0.5,
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
            minZoom: 10.0,
          ),
        );
      } else {
        await mapboxMap.style.setStyleLayerProperty(
          ROUTE_MAIN_STOPS_LAYER_ID,
          "filter",
          mainStopsFilter,
        );
      }

      // Eliminar la capa de paradas intermedias si existía de una versión anterior
      if (await mapboxMap.style.styleLayerExists(
        ROUTE_INTERMEDIATE_STOPS_LAYER_ID,
      )) {
        await mapboxMap.style.removeStyleLayer(
          ROUTE_INTERMEDIATE_STOPS_LAYER_ID,
        );
      }
    } catch (e) {
      print(
        "[MapboxService_Debug] Error añadiendo/actualizando fuente/capa para paradas de ruta: $e",
      );
    }
  }

  Future<void> _removeRouteStopsLayersAndSource() async {
    try {
      if (await mapboxMap.style.styleLayerExists(ROUTE_MAIN_STOPS_LAYER_ID)) {
        await mapboxMap.style.removeStyleLayer(ROUTE_MAIN_STOPS_LAYER_ID);
      }
      if (await mapboxMap.style.styleLayerExists(
        ROUTE_INTERMEDIATE_STOPS_LAYER_ID,
      )) {
        await mapboxMap.style.removeStyleLayer(
          ROUTE_INTERMEDIATE_STOPS_LAYER_ID,
        );
      }
      if (await mapboxMap.style.styleSourceExists(ROUTE_STOPS_SOURCE_ID)) {
        await mapboxMap.style.removeStyleSource(ROUTE_STOPS_SOURCE_ID);
      }
    } catch (e) {
      print(
        "[MapboxService_Debug] Error limpiando capas/fuente de paradas de ruta: $e",
      );
    }
  }

  // AÑADIDO: Método applyOverviewRouteStyle movido y adaptado desde _MapScreenState
  Future<void> applyOverviewRouteStyle() async {
    if (_legLayerIds.isEmpty) return; // No hay capas de tramos para actualizar

    const overviewOpacity = 0.8;
    const overviewWidth = 5.0;
    const overviewShadowOpacity = 0.6;
    const overviewShadowWidth = 7.0;

    for (final entry in _legLayerIds.entries) {
      final legIndex = entry.key; // Solo para logging en caso de error
      final layerIds = entry.value; // [mainLayerId, shadowLayerId]
      if (layerIds.length != 2) continue;
      final mainLayerId = layerIds[0];
      final shadowLayerId = layerIds[1];

      try {
        // Actualizar capa principal
        if (await mapboxMap.style.styleLayerExists(mainLayerId)) {
          await mapboxMap.style.setStyleLayerProperty(
            mainLayerId,
            "line-opacity",
            overviewOpacity,
          );
          await mapboxMap.style.setStyleLayerProperty(
            mainLayerId,
            "line-width",
            overviewWidth,
          );
        }

        // Actualizar capa de sombra
        if (await mapboxMap.style.styleLayerExists(shadowLayerId)) {
          await mapboxMap.style.setStyleLayerProperty(
            shadowLayerId,
            "line-opacity",
            overviewShadowOpacity,
          );
          await mapboxMap.style.setStyleLayerProperty(
            shadowLayerId,
            "line-width",
            overviewShadowWidth,
          );
        }
      } catch (e) {
        print(
          "[MapboxService_Debug] Error aplicando estilo de vista general a capas del tramo $legIndex: $e",
        );
      }
    }
    print(
      "[MapboxService_Debug] Estilo de vista general aplicado a la ruta por MapboxService.",
    );
  }

  // AÑADIDO: Método drawFullBusLineShape movido y adaptado desde _MapScreenState
  Future<void> drawFullBusLineShape(
    List<Position> positions,
    String sourceId,
    String layerId,
    Color lineColor,
    double lineWidth,
  ) async {
    print(
      "[MapboxService_Debug] drawFullBusLineShape called for source: $sourceId, layer: $layerId",
    );
    if (positions.length < 2) {
      print(
        "[MapboxService_Debug] drawFullBusLineShape: Not enough positions (<2). Aborting.",
      );
      return;
    }

    final Map<String, dynamic> geometry = {
      'type': 'LineString',
      'coordinates': positions.map((p) => [p.lng, p.lat]).toList(),
    };

    final Map<String, dynamic> geoJsonFeature = {
      "type": "FeatureCollection",
      "features": [
        {"type": "Feature", "geometry": geometry, "properties": {}},
      ],
    };
    final String geoJsonDataString = json.encode(geoJsonFeature);

    try {
      final sourceExists = await mapboxMap.style.styleSourceExists(sourceId);
      if (!sourceExists) {
        print(
          "[MapboxService_Debug] drawFullBusLineShape: Adding source $sourceId.",
        );
        await mapboxMap.style.addSource(
          GeoJsonSource(id: sourceId, data: geoJsonDataString),
        );
      } else {
        print(
          "[MapboxService_Debug] drawFullBusLineShape: Updating source $sourceId.",
        );
        final source =
            await mapboxMap.style.getSource(sourceId) as GeoJsonSource?;
        await source?.updateGeoJSON(geoJsonDataString);
      }

      final layerExists = await mapboxMap.style.styleLayerExists(layerId);
      if (!layerExists) {
        print(
          "[MapboxService_Debug] drawFullBusLineShape: Adding layer $layerId.",
        );
        await mapboxMap.style.addLayer(
          LineLayer(
            id: layerId,
            sourceId: sourceId,
            lineColor: lineColor.value,
            lineWidth: lineWidth,
            lineOpacity: 0.65,
            lineJoin: LineJoin.ROUND,
            lineCap: LineCap.ROUND,
          ),
        );

        String? determinedBelowLayerId;
        if (_legLayerIds.containsKey(0) && _legLayerIds[0]!.length == 2) {
          // Asumimos que el primer tramo de la ruta del usuario es _legLayerIds[0]
          // y su capa de sombra es _legLayerIds[0]![1]
          final firstUserRouteLegShadowLayer = _legLayerIds[0]![1];
          if (await mapboxMap.style.styleLayerExists(
            firstUserRouteLegShadowLayer,
          )) {
            determinedBelowLayerId = firstUserRouteLegShadowLayer;
          }
        }

        if (determinedBelowLayerId != null) {
          try {
            print(
              "[MapboxService_Debug] drawFullBusLineShape: Moving layer $layerId below $determinedBelowLayerId.",
            );
            await mapboxMap.style.moveStyleLayer(
              layerId,
              LayerPosition(below: determinedBelowLayerId),
            );
          } catch (e) {
            print(
              '[MapboxService_Debug] drawFullBusLineShape: Error moving layer $layerId: $e',
            );
          }
        } else {
          print(
            "[MapboxService_Debug] drawFullBusLineShape: Layer $layerId added without specific positioning.",
          );
        }
      } else {
        print(
          "[MapboxService_Debug] drawFullBusLineShape: Layer $layerId already exists.",
        );
      }
    } catch (e) {
      print(
        "[MapboxService_Debug] drawFullBusLineShape: Error adding source/layer $layerId: $e",
      );
    }
  }

  // AÑADIDO: Método drawIncomingBusSegment movido y adaptado desde _MapScreenState
  Future<void> drawIncomingBusSegment(
    Position? highlightedBusPosition,
    List<Position>? currentFullShapeForBusLeg,
    int? originStopIndexOnShape,
  ) async {
    print(
      "[MapboxService_Debug] drawIncomingBusSegment called. BusPos: $highlightedBusPosition, HasShape: ${currentFullShapeForBusLeg != null}, OriginIndex: $originStopIndexOnShape",
    );
    // Definir IDs únicos para la fuente y capa ya están como constantes de clase

    // Limpiar capa/fuente anterior si existen
    try {
      bool segmentLayerExists = await mapboxMap.style.styleLayerExists(
        INCOMING_BUS_SEGMENT_LAYER_ID,
      );
      if (segmentLayerExists) {
        print(
          "[MapboxService_Debug] drawIncomingBusSegment: Removing existing layer $INCOMING_BUS_SEGMENT_LAYER_ID.",
        );
        await mapboxMap.style.removeStyleLayer(INCOMING_BUS_SEGMENT_LAYER_ID);
      }
      bool shadowLayerExists = await mapboxMap.style.styleLayerExists(
        "$INCOMING_BUS_SEGMENT_LAYER_ID-shadow",
      );
      if (shadowLayerExists) {
        print(
          "[MapboxService_Debug] drawIncomingBusSegment: Removing existing shadow layer.",
        );
        await mapboxMap.style.removeStyleLayer(
          "$INCOMING_BUS_SEGMENT_LAYER_ID-shadow",
        );
      }
      bool sourceExists = await mapboxMap.style.styleSourceExists(
        INCOMING_BUS_SEGMENT_SOURCE_ID,
      );
      if (sourceExists) {
        print(
          "[MapboxService_Debug] drawIncomingBusSegment: Removing existing source $INCOMING_BUS_SEGMENT_SOURCE_ID.",
        );
        await mapboxMap.style.removeStyleSource(INCOMING_BUS_SEGMENT_SOURCE_ID);
      }
    } catch (e) {
      print(
        "[MapboxService_Debug] drawIncomingBusSegment: Error during cleanup: $e",
      );
      // Ignorar errores durante la limpieza, pero loguearlos
    }

    if (highlightedBusPosition == null ||
        currentFullShapeForBusLeg == null ||
        originStopIndexOnShape == null) {
      print(
        "[MapboxService_Debug] drawIncomingBusSegment: Missing data. Not drawing segment.",
      );
      return;
    }

    final busIndex = findClosestPointIndexOnShape(
      currentFullShapeForBusLeg,
      Point_dart(
        lat: (highlightedBusPosition.lat as num).toDouble(),
        lng: (highlightedBusPosition.lng as num).toDouble(),
      ),
    );
    final originIndex = originStopIndexOnShape;
    print(
      "[MapboxService_Debug] drawIncomingBusSegment: Calculated busIndex=$busIndex, originIndex=$originIndex",
    );
    if (busIndex == -1) {
      print(
        "[MapboxService_Debug] drawIncomingBusSegment: Bus not found on shape (busIndex=-1). Not drawing segment.",
      );
      return;
    }

    final start = math.min(busIndex, originIndex);
    final end = math.max(busIndex, originIndex);

    if (start < 0 || end >= currentFullShapeForBusLeg.length || start > end) {
      print(
        "[MapboxService_Debug] drawIncomingBusSegment: Invalid segment indices (start=$start, end=$end, shapeLength=${currentFullShapeForBusLeg.length}). Not drawing segment.",
      );
      return;
    }

    final segment = currentFullShapeForBusLeg.sublist(start, end + 1);
    print(
      "[MapboxService_Debug] drawIncomingBusSegment: Calculated segment length: ${segment.length}",
    );
    if (segment.length < 2) {
      print(
        "[MapboxService_Debug] drawIncomingBusSegment: Segment too short (<2). Not drawing.",
      );
      return;
    }

    print(
      "[MapboxService_Debug] drawIncomingBusSegment: Calling internal drawRouteSegment to draw green line.",
    );
    await drawRouteSegment(
      segment,
      INCOMING_BUS_SEGMENT_SOURCE_ID,
      INCOMING_BUS_SEGMENT_LAYER_ID,
      Colors.green,
      9999,
      lineWidth: 6.0,
      shadowWidth: 8.0,
    );

    try {
      print(
        "[MapboxService_Debug] drawIncomingBusSegment: Attempting to move segment layers below $ROUTE_MAIN_STOPS_LAYER_ID.",
      );
      if (await mapboxMap.style.styleLayerExists(ROUTE_MAIN_STOPS_LAYER_ID)) {
        if (await mapboxMap.style.styleLayerExists(
          "$INCOMING_BUS_SEGMENT_LAYER_ID-shadow",
        )) {
          await mapboxMap.style.moveStyleLayer(
            "$INCOMING_BUS_SEGMENT_LAYER_ID-shadow",
            LayerPosition(below: ROUTE_MAIN_STOPS_LAYER_ID),
          );
        }
        if (await mapboxMap.style.styleLayerExists(
          INCOMING_BUS_SEGMENT_LAYER_ID,
        )) {
          await mapboxMap.style.moveStyleLayer(
            INCOMING_BUS_SEGMENT_LAYER_ID,
            LayerPosition(below: ROUTE_MAIN_STOPS_LAYER_ID),
          );
        }
        print(
          "[MapboxService_Debug] drawIncomingBusSegment: Segment layers moved.",
        );
      } else {
        print(
          "[MapboxService_Debug] drawIncomingBusSegment: Layer $ROUTE_MAIN_STOPS_LAYER_ID not found, segment layers not moved.",
        );
      }
    } catch (e) {
      print(
        "[MapboxService_Debug] drawIncomingBusSegment: Error moving segment layers: $e",
      );
    }
  }

  // AÑADIDO: Método para hacer zoom y centrar el mapa en la ruta calculada.
  Future<bool> zoomToRouteBounds(List<RouteLeg> legs) async {
    if (mapboxMap == null || legs.isEmpty) return false;

    final CoordinateBounds? routeBounds = await calculateBoundsForRoute(
      legs,
    ); // Usa la función de utils

    if (routeBounds != null) {
      try {
        final MbxEdgeInsets padding = MbxEdgeInsets(
          top: 60.0,
          left: 40.0,
          bottom: 60.0,
          right: 40.0,
        );

        final CameraOptions cameraOptions = await mapboxMap
            .cameraForCoordinateBounds(
              routeBounds,
              padding,
              null,
              null,
              null,
              null,
            );

        await mapboxMap.flyTo(
          cameraOptions,
          MapAnimationOptions(duration: 1500),
        );
        print(
          "[MapboxService_Debug] Cámara ajustada para mostrar la ruta completa.",
        );
        return true; // Indica éxito
      } catch (e) {
        print(
          "[MapboxService_Debug] Error al calcular o volar a los límites de la ruta: $e",
        );
        return false; // Indica fallo
      }
    } else {
      print(
        "[MapboxService_Debug] No se pudieron calcular los límites para la ruta.",
      );
      return false; // Indica fallo
    }
  }

  // MODIFICADO: Devolver Future<bool>
  Future<bool> zoomToLeg(
    List<RouteLeg> legs,
    int legIndex,
    Position? busToInclude,
    bool isInstructionsCollapsed,
  ) async {
    if (mapboxMap == null || legIndex < 0 || legIndex >= legs.length) {
      print(
        "[MapboxService_Debug] zoomToLeg: Condiciones no cumplidas (mapa nulo o índice de tramo inválido). No se inició el zoom.",
      );
      return false; // No se inició el zoom
    }

    final RouteLeg leg = legs[legIndex];
    final String mode = leg.mode.toUpperCase();

    CoordinateBounds? legBounds;

    if ((mode == 'BUS' || mode == 'TRANSIT') && busToInclude != null) {
      final LegEndpoint fromPlace = leg.from;
      if (fromPlace.lat != 0.0 && fromPlace.lon != 0.0) {
        // Verificar validez de coordenadas
        final Position paradaOrigen = Position(fromPlace.lon, fromPlace.lat);
        final Position busPos = busToInclude;

        const double paddingGrados = 0.002;
        final double minLat =
            math.min(paradaOrigen.lat, busPos.lat) - paddingGrados;
        final double maxLat =
            math.max(paradaOrigen.lat, busPos.lat) + paddingGrados;
        final double minLon =
            math.min(paradaOrigen.lng, busPos.lng) - paddingGrados;
        final double maxLon =
            math.max(paradaOrigen.lng, busPos.lng) + paddingGrados;

        final Point southwestPoint = Point(
          coordinates: Position(minLon, minLat),
        );
        final Point northeastPoint = Point(
          coordinates: Position(maxLon, maxLat),
        );
        legBounds = CoordinateBounds(
          southwest: southwestPoint,
          northeast: northeastPoint,
          infiniteBounds: false,
        );
      } else {
        legBounds = await calculateBoundsForLeg(
          legs,
          legIndex,
          additionalPoint: busToInclude,
        );
      }
    } else {
      legBounds = await calculateBoundsForLeg(
        legs,
        legIndex,
        additionalPoint:
            (mode == 'BUS' || mode == 'TRANSIT') ? busToInclude : null,
      );
    }

    if (legBounds != null) {
      try {
        final MbxEdgeInsets padding = MbxEdgeInsets(
          top: 80.0,
          left: 50.0,
          bottom: isInstructionsCollapsed ? 100.0 : 80.0,
          right: 50.0,
        );
        final CameraOptions cameraOptions = await mapboxMap
            .cameraForCoordinateBounds(
              legBounds,
              padding,
              null,
              null,
              null,
              null,
            );
        await mapboxMap.flyTo(
          cameraOptions,
          MapAnimationOptions(duration: 1200),
        );
        print(
          "[MapboxService_Debug] Cámara ajustada para mostrar el tramo $legIndex.",
        );
        return true;
      } catch (e) {
        print(
          "[MapboxService_Debug] Error al calcular o volar a los límites del tramo $legIndex: $e",
        );
        return false;
      }
    } else {
      print(
        "[MapboxService_Debug] No se pudieron calcular los límites para el tramo $legIndex.",
      );
      return false;
    }
  }

  // MODIFICADO: Devolver Future<bool>
  Future<bool> zoomToFitPositions(
    List<Position> positions,
    EdgeInsets flutterPadding, {
    Duration? animationDuration,
  }) async {
    print(
      "[MapboxService_Debug] zoomToFitPositions llamado con ${positions.length} posiciones.",
    );
    if (mapboxMap == null || positions.isEmpty) {
      print(
        "[MapboxService_Debug] zoomToFitPositions: MapboxMap es null o no hay posiciones. Abortando. No se inició el zoom.",
      );
      return false; // No se inició el zoom
    }

    final MbxEdgeInsets mapboxPadding = MbxEdgeInsets(
      top: flutterPadding.top,
      left: flutterPadding.left,
      bottom: flutterPadding.bottom,
      right: flutterPadding.right,
    );

    final MapAnimationOptions animationOptions = MapAnimationOptions(
      duration:
          (animationDuration ?? const Duration(milliseconds: 1200))
              .inMilliseconds
              .toInt(),
      startDelay: 0,
    );

    try {
      if (positions.length == 1) {
        final CameraOptions cameraOptions = CameraOptions(
          center: Point(coordinates: positions.first),
          padding: mapboxPadding,
          zoom: 16.0,
        );
        await mapboxMap!.flyTo(cameraOptions, animationOptions);
        print(
          "[MapboxService_Debug] zoomToFitPositions (single): flyTo ejecutado.",
        );
        return true; // Zoom iniciado
      } else {
        // Para múltiples posiciones, Mapbox espera una lista de Point, no List<List<double>> para cameraForCoordinates
        final List<Point> mapboxPoints =
            positions
                .map((p) => Point(coordinates: p)) // Convertir Position a Point
                .toList();

        final CameraOptions cameraOptions = await mapboxMap!
            .cameraForCoordinates(
              mapboxPoints, // Usar la lista de Point
              mapboxPadding,
              null, // bearing
              null, // pitch
            );
        await mapboxMap!.flyTo(cameraOptions, animationOptions);
        print(
          "[MapboxService_Debug] zoomToFitPositions (multiple): flyTo ejecutado.",
        );
        return true; // Zoom iniciado
      }
    } catch (e) {
      print("[MapboxService_Debug] zoomToFitPositions: Excepción: $e");
      return false; // No se inició el zoom
    }
  }

  // AÑADIDO: Método para iniciar la animación flotante del tooltip
  void startTooltipFloatingAnimation() {
    print("[MapboxService_Debug] startTooltipFloatingAnimation called.");
    _tooltipFloatTimer?.cancel();
    // 60 FPS aprox
    _tooltipFloatTimer = Timer.periodic(const Duration(milliseconds: 16), (
      timer,
    ) async {
      // Un ciclo cada 3 segundos (o el periodo que elijas)
      final double amplitude = 5.0; // píxeles
      final double period = 3.0; // segundos
      final double baseOffset = -5.0; // offset fijo para llevarlo más arriba
      _tooltipFloatPhase += (2 * math.pi) / (period * 1000 / 16);
      if (_tooltipFloatPhase > 2 * math.pi) _tooltipFloatPhase -= 2 * math.pi;
      final double offsetY =
          baseOffset - amplitude * math.sin(_tooltipFloatPhase);
      _lastTooltipOffset = offsetY;
      // Actualiza el iconOffset del tooltip layer
      // mapboxMap está disponible directamente en la clase
      try {
        // Log reducido para evitar spam
        // print("[MapboxService_Debug] Updating tooltip offset: $offsetY");
        await mapboxMap.style.setStyleLayerProperty(
          INCOMING_BUS_TOOLTIP_LAYER_ID,
          'icon-offset',
          [0.0, offsetY],
        );
      } catch (e) {
        print("[MapboxService_Debug] Error updating tooltip offset: $e");
        // Considerar cancelar timer si hay error persistente?
      }
    });
  }

  // AÑADIDO: Método para detener la animación flotante del tooltip
  void stopTooltipFloatingAnimation() {
    print("[MapboxService_Debug] stopTooltipFloatingAnimation called.");
    _tooltipFloatTimer?.cancel();
    _tooltipFloatTimer = null;
    _tooltipFloatPhase = 0.0;
    try {
      mapboxMap.style
          .styleLayerExists(INCOMING_BUS_TOOLTIP_LAYER_ID)
          .then((exists) {
            if (exists) {
              print(
                "[MapboxService_Debug] Resetting tooltip offset to [0.0, 0.0].",
              );
              mapboxMap.style.setStyleLayerProperty(
                INCOMING_BUS_TOOLTIP_LAYER_ID,
                'icon-offset',
                [0.0, 0.0],
              );
            } else {
              print(
                "[MapboxService_Debug] Tooltip layer doesn't exist, cannot reset offset.",
              );
            }
          })
          .catchError((e) {
            print(
              "[MapboxService_Debug] Error checking/resetting tooltip offset: $e",
            );
          });
    } catch (e) {
      print(
        "[MapboxService_Debug] Exception in stopTooltipFloatingAnimation catch block: $e",
      );
    }
  }

  // MODIFICADO: Método para obtener el valor de una propiedad como String (público y estático)
  static String? getStringValue(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  // AÑADIDO: Método para manejar los taps en el mapa y detectar si se tocó una parada
  Future<void> handleMapTap(
    MapContentGestureContext context,
    Function(String stopId, String stopName) onStopTappedCallback,
  ) async {
    final ScreenCoordinate screenCoordinate = context.touchPosition;

    final options = RenderedQueryOptions(
      layerIds: [STOPS_LAYER_ID], // Usar la constante de la clase
      filter: null,
    );

    final List<QueriedRenderedFeature?> queriedFeaturesNullable =
        await mapboxMap.queryRenderedFeatures(
          RenderedQueryGeometry.fromScreenCoordinate(screenCoordinate),
          options,
        );

    final List<QueriedRenderedFeature> features =
        queriedFeaturesNullable.whereType<QueriedRenderedFeature>().toList();

    if (features.isNotEmpty) {
      for (var queriedFeature in features) {
        final innerQueriedFeature = queriedFeature.queriedFeature;
        final featureMap =
            innerQueriedFeature.feature; // Este es el Map<String?, Object?>

        final Map<String?, dynamic>? stopProperties;
        final rawProperties = featureMap['properties'];

        if (rawProperties is Map<String?, dynamic>) {
          stopProperties = rawProperties;
        } else if (rawProperties is Map) {
          stopProperties = Map<String?, dynamic>.from(rawProperties);
        } else {
          print(
            "[MapboxService_Error] 'properties' no es un Map o es nulo para la feature: $featureMap",
          );
          stopProperties = null;
        }

        if (stopProperties != null) {
          final stopId = getStringValue(stopProperties['stop_id']);
          final stopName = getStringValue(stopProperties['stop_name']);

          if (stopId != null && stopId.isNotEmpty) {
            print(
              "[MapboxService_Debug] Parada tocada: ID=$stopId, Nombre=$stopName",
            );
            // Invocar el callback pasado desde _MapScreenState
            onStopTappedCallback(stopId, stopName ?? "Parada sin nombre");
            // Salir después de procesar la primera parada encontrada, si es la intención.
            // Si se pueden superponer paradas y quieres procesar todas, quita el break.
            break;
          }
        }
      }
    }
  }

  Future<void> drawRouteLegs(List<RouteLeg> legs, int? selectedLegIndex) async {
    // ... existing code ...
  }
}
