import 'dart:convert';
import 'dart:async';
import 'dart:math' show sin, pi;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import 'package:bondi_uy/ui/map_style_constants.dart';
import 'package:bondi_uy/utils/geometry_utils.dart';
import 'map_manager.dart';
import 'map_icons_loader.dart';

/// Módulo especializado en renderizar rutas y tramos en el mapa
class MapRouteRenderer {
  final MapboxMap? mapboxMap;
  final MapManager mapManager;

  // Sistema de animación de flechas
  Timer? _arrowAnimationTimer;
  double _arrowAnimationPhase = 0.0;
  List<String> _animatedArrowLayerIds = [];

  // DIFF: Flag para controlar animaciones
  bool _animationsEnabled = true;

  // Constantes para IDs de capas y fuentes unificadas
  static const String WALK_SOURCE_PREFIX = 'route-walk-source-';
  static const String WALK_LAYER_PREFIX = 'route-walk-layer-';
  static const String BUS_SOURCE_PREFIX = 'route-bus-source-';
  static const String BUS_LAYER_PREFIX = 'route-bus-layer-';
  static const String WAIT_SOURCE_PREFIX = 'route-wait-source-';
  static const String WAIT_LAYER_PREFIX = 'route-wait-layer-';

  MapRouteRenderer(this.mapboxMap, this.mapManager);

  /// Renderizar ruta completa (unificado para preview y active trip)
  Future<void> renderRoute(List<TramoViajeMostrable> tramos) async {
    if (mapboxMap == null) return;

    print("[MapRouteRenderer] Rendering route with ${tramos.length} segments");

    try {
      // FASE 1: Dibujar todas las líneas de ruta (walk, bus, wait) primero
      for (int i = 0; i < tramos.length; i++) {
        final tramo = tramos[i];

        switch (tramo.tipo) {
          case TipoTramoViaje.CAMINAR:
            await _drawWalkSegment(tramo, i);
            break;

          case TipoTramoViaje.VIAJE_EN_BUS:
            await _drawBusSegment(tramo, i);
            break;

          case TipoTramoViaje.ESPERAR_BUS:
            await _drawWaitPoint(tramo, i);
            break;
        }
      }

      // FASE 2: Agregar todas las paradas de bus encima de las líneas
      for (int i = 0; i < tramos.length; i++) {
        final tramo = tramos[i];

        if (tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS) {
          await _addBusStopsForSegment(tramo, i);
        }
      }

      // FASE 3: Iniciar animación de flechas
      _startArrowAnimation();

      print("[MapRouteRenderer] Route rendered successfully");
    } catch (e) {
      print("[MapRouteRenderer] Error rendering route: $e");
    }
  }

  /// Resaltar tramo actual en viaje activo
  Future<void> highlightCurrentLeg(
    int legIndex,
    List<TramoViajeMostrable> tramos,
  ) async {
    if (mapboxMap == null) return;

    print("[MapRouteRenderer] Highlighting current leg: $legIndex");

    for (int i = 0; i < tramos.length; i++) {
      final tramo = tramos[i];
      bool isCurrent = i == legIndex;
      String layerId;
      double? lineWidth;
      double? circleRadius;

      switch (tramo.tipo) {
        case TipoTramoViaje.CAMINAR:
          layerId = '$WALK_LAYER_PREFIX$i';
          lineWidth = isCurrent ? 6.0 : 4.0;
          break;
        case TipoTramoViaje.VIAJE_EN_BUS:
          layerId = '$BUS_LAYER_PREFIX$i';
          lineWidth = isCurrent ? 7.0 : 5.0;
          break;
        case TipoTramoViaje.ESPERAR_BUS:
          layerId = '$WAIT_LAYER_PREFIX$i';
          circleRadius = isCurrent ? 10.0 : 8.0;
          break;
        default:
          continue;
      }

      try {
        if (await mapboxMap!.style.styleLayerExists(layerId)) {
          switch (tramo.tipo) {
            case TipoTramoViaje.CAMINAR:
            case TipoTramoViaje.VIAJE_EN_BUS:
              if (lineWidth != null) {
                await mapboxMap!.style.setStyleLayerProperty(
                  layerId,
                  'line-width',
                  lineWidth,
                );
              }
              break;
            case TipoTramoViaje.ESPERAR_BUS:
              if (circleRadius != null) {
                await mapboxMap!.style.setStyleLayerProperty(
                  layerId,
                  'circle-radius',
                  circleRadius,
                );
              }
              break;
          }
        }
      } catch (e) {
        print(
          '[MapRouteRenderer] Error setting layer properties for $layerId: $e',
        );
      }
    }
  }

  // ========== MÉTODOS UNIFICADOS DE DIBUJADO ==========

  Future<void> _drawWalkSegment(TramoViajeMostrable tramo, int index) async {
    if (tramo.geometriaPolilinea == null || tramo.geometriaPolilinea!.isEmpty) {
      return;
    }

    final sourceId = '$WALK_SOURCE_PREFIX$index';
    final shadowLayerId = '$WALK_LAYER_PREFIX$index-shadow';
    final mainLayerId = '$WALK_LAYER_PREFIX$index';

    final geoJsonFeature = {
      "type": "Feature",
      "geometry": {
        "type": "LineString",
        "coordinates": _coordenadasToGeoJsonPositionList(
          tramo.geometriaPolilinea!,
        ),
      },
    };

    // Agregar fuente
    await mapboxMap!.style.addSource(
      GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)),
    );
    mapManager.registerSource(sourceId);

    // Agregar capa de borde
    await mapboxMap!.style.addLayer(
      LineLayer(
        id: shadowLayerId,
        sourceId: sourceId,
        lineColor: MapStyleConstants.BORDER_PROPERTIES['line-color'] as int,
        lineWidth:
            (MapStyleConstants.BORDER_PROPERTIES['line-width'] as num)
                .toDouble(),
        lineOpacity:
            (MapStyleConstants.BORDER_PROPERTIES['line-opacity'] as num)
                .toDouble(),
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      ),
    );
    mapManager.registerLayer(shadowLayerId);

    // Agregar capa principal - WALK es línea SÓLIDA
    await mapboxMap!.style.addLayer(
      LineLayer(
        id: mainLayerId,
        sourceId: sourceId,
        lineColor: MapStyleConstants.WALK_LINE_PROPERTIES['line-color'] as int,
        lineWidth:
            (MapStyleConstants.WALK_LINE_PROPERTIES['line-width'] as num)
                .toDouble(),
        lineOpacity:
            (MapStyleConstants.WALK_LINE_PROPERTIES['line-opacity'] as num)
                .toDouble(),
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      ),
    );
    mapManager.registerLayer(mainLayerId);
  }

  Future<void> _drawBusSegment(TramoViajeMostrable tramo, int index) async {
    if (tramo.geometriaPolilinea == null || tramo.geometriaPolilinea!.isEmpty) {
      return;
    }

    final sourceId = '$BUS_SOURCE_PREFIX$index';
    final shadowLayerId = '$BUS_LAYER_PREFIX$index-shadow';
    final mainLayerId = '$BUS_LAYER_PREFIX$index';

    final geoJsonFeature = {
      "type": "Feature",
      "geometry": {
        "type": "LineString",
        "coordinates": _coordenadasToGeoJsonPositionList(
          tramo.geometriaPolilinea!,
        ),
      },
    };

    // Agregar fuente
    await mapboxMap!.style.addSource(
      GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)),
    );
    mapManager.registerSource(sourceId);

    // Agregar capa de borde
    await mapboxMap!.style.addLayer(
      LineLayer(
        id: shadowLayerId,
        sourceId: sourceId,
        lineColor: MapStyleConstants.BORDER_PROPERTIES['line-color'] as int,
        lineWidth:
            (MapStyleConstants.BORDER_PROPERTIES['line-width'] as num)
                .toDouble(),
        lineOpacity:
            (MapStyleConstants.BORDER_PROPERTIES['line-opacity'] as num)
                .toDouble(),
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      ),
    );
    mapManager.registerLayer(shadowLayerId);

    // Agregar capa principal
    await mapboxMap!.style.addLayer(
      LineLayer(
        id: mainLayerId,
        sourceId: sourceId,
        lineColor: MapStyleConstants.BUS_LINE_PROPERTIES['line-color'] as int,
        lineWidth:
            (MapStyleConstants.BUS_LINE_PROPERTIES['line-width'] as num)
                .toDouble(),
        lineOpacity:
            (MapStyleConstants.BUS_LINE_PROPERTIES['line-opacity'] as num)
                .toDouble(),
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      ),
    );
    mapManager.registerLayer(mainLayerId);
  }

  Future<void> _drawWaitPoint(TramoViajeMostrable tramo, int index) async {
    if (tramo.posicionPunto == null) return;

    final sourceId = '$WAIT_SOURCE_PREFIX$index';
    final layerId = '$WAIT_LAYER_PREFIX$index';

    final geoJsonFeature = {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [
          tramo.posicionPunto!.longitud,
          tramo.posicionPunto!.latitud,
        ],
      },
    };

    await mapboxMap!.style.addSource(
      GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)),
    );
    mapManager.registerSource(sourceId);

    await mapboxMap!.style.addLayer(
      CircleLayer(
        id: layerId,
        sourceId: sourceId,
        circleColor:
            MapStyleConstants.WAIT_CIRCLE_PROPERTIES['circle-color'] as int,
        circleRadius:
            (MapStyleConstants.WAIT_CIRCLE_PROPERTIES['circle-radius'] as num)
                .toDouble(),
        circleStrokeWidth:
            (MapStyleConstants.WAIT_CIRCLE_PROPERTIES['circle-stroke-width']
                    as num)
                .toDouble(),
        circleStrokeColor:
            MapStyleConstants.WAIT_CIRCLE_PROPERTIES['circle-stroke-color']
                as int,
        circleOpacity:
            (MapStyleConstants.WAIT_CIRCLE_PROPERTIES['circle-opacity'] as num)
                .toDouble(),
      ),
    );
    mapManager.registerLayer(layerId);
  }

  Future<void> _addBusStopsForSegment(
    TramoViajeMostrable tramo,
    int segmentIndex,
  ) async {
    if (!mapManager.iconsLoader.areIconsLoaded ||
        tramo.geometriaPolilinea == null ||
        tramo.geometriaPolilinea!.isEmpty) {
      return;
    }

    final polyline = tramo.geometriaPolilinea!;

    // Parada de subida (primer punto del tramo de bus)
    if (polyline.isNotEmpty) {
      final boardingStop = polyline.first;
      await _addBusStopMarker(
        'bus-boarding-stop-$segmentIndex',
        'bus-boarding-layer-$segmentIndex',
        boardingStop.latitud,
        boardingStop.longitud,
        'Subir al bus',
      );
    }

    // Parada de bajada (último punto del tramo de bus)
    if (polyline.length > 1) {
      final alightingStop = polyline.last;
      await _addBusStopMarker(
        'bus-alighting-stop-$segmentIndex',
        'bus-alighting-layer-$segmentIndex',
        alightingStop.latitud,
        alightingStop.longitud,
        'Bajar del bus',
      );
    }
  }

  Future<void> _addBusStopMarker(
    String sourceId,
    String layerId,
    double lat,
    double lng,
    String label,
  ) async {
    if (mapboxMap == null) return;

    await mapboxMap!.style.addSource(
      GeoJsonSource(
        id: sourceId,
        data: jsonEncode({
          "type": "Feature",
          "geometry": {
            "type": "Point",
            "coordinates": [lng, lat],
          },
          "properties": {"label": label, "isBoarding": label.contains('Subir')},
        }),
      ),
    );
    mapManager.registerSource(sourceId);

    await mapboxMap!.style.addLayer(
      SymbolLayer(
        id: layerId,
        sourceId: sourceId,
        iconImage: MapIconsLoader.STOP_ICON_IMAGE_ID,
        iconAllowOverlap: true,
        iconSize: 0.5,
        textField:
            label.contains('Subir') ? '↑' : '↓', // Flechas para subir/bajar
        textColor:
            label.contains('Subir')
                ? 0xFF4CAF50
                : 0xFFF44336, // Verde para subir, rojo para bajar
        textSize: 28,
        textOffset:
            label.contains('Subir')
                ? [0.0, -1.25]
                : [0.0, 1.25], // Subir arriba (-), bajar abajo (+)
        textHaloColor: 0xFF000000,
        textHaloWidth: 1.2,
        textAllowOverlap: true,
      ),
    );
    mapManager.registerLayer(layerId);

    // Agregar a la lista de capas animadas
    _animatedArrowLayerIds.add(layerId);
  }

  // ========== MÉTODOS DE ANIMACIÓN ==========

  void _startArrowAnimation() {
    // DIFF: Solo iniciar animaciones si están habilitadas
    if (!_animationsEnabled) {
      print(
        "[MapRouteRenderer] 🎭 Animaciones deshabilitadas - no iniciando timer",
      );
      return;
    }

    _stopArrowAnimation(); // Asegurar que no hay timer previo

    _arrowAnimationTimer = Timer.periodic(
      const Duration(milliseconds: 100), // 100ms para animación suave
      (timer) => _updateArrowAnimation(),
    );
    print("[MapRouteRenderer] 🎭 Arrow animation timer started");
  }

  void _stopArrowAnimation() {
    _arrowAnimationTimer?.cancel();
    _arrowAnimationTimer = null;
  }

  // DIFF: Método para controlar animaciones
  void setAnimationsEnabled(bool enabled) {
    print("[MapRouteRenderer] 🎭 Setting animations enabled: $enabled");
    _animationsEnabled = enabled;

    if (enabled) {
      // Si se habilitan las animaciones, reiniciar si hay capas animadas
      if (_animatedArrowLayerIds.isNotEmpty) {
        _startArrowAnimation();
      }
    } else {
      // Si se deshabilitan, detener animaciones
      _stopArrowAnimation();
    }
  }

  Future<void> _updateArrowAnimation() async {
    if (mapboxMap == null || _animatedArrowLayerIds.isEmpty) return;

    _arrowAnimationPhase += 0.15; // Velocidad más lenta para mejor fluidez
    if (_arrowAnimationPhase > 2 * 3.14159) {
      _arrowAnimationPhase -= 2 * 3.14159; // Reset cada ciclo completo
    }

    // Calcular offset flotante más sutil (seno para movimiento suave)
    final floatOffset =
        (sin(_arrowAnimationPhase) * 0.15); // Amplitud reducida de 0.3 a 0.15

    // Crear una copia de la lista para evitar concurrent modification
    final layerIdsCopy = List<String>.from(_animatedArrowLayerIds);

    // Actualizar todas las capas de flechas animadas de forma sincronizada
    for (String layerId in layerIdsCopy) {
      try {
        if (await mapboxMap!.style.styleLayerExists(layerId)) {
          final isUpArrow =
              layerId.contains('boarding') ||
              layerId.contains('origin'); // Los boarding/origin son ↑
          final baseOffset = isUpArrow ? -1.25 : 1.25;

          // SINCRONIZAR: ambas flechas se mueven en la misma dirección relativa
          final animatedOffset =
              isUpArrow
                  ? (baseOffset - floatOffset)
                  : (baseOffset + floatOffset);

          await mapboxMap!.style.setStyleLayerProperty(layerId, 'text-offset', [
            0.0,
            animatedOffset,
          ]);
        }
      } catch (e) {
        print(
          "[MapRouteRenderer] Error updating arrow animation for $layerId: $e",
        );
      }
    }
  }

  // ========== MÉTODOS HELPER ==========

  List<List<double>> _coordenadasToGeoJsonPositionList(
    List<Coordenada> coordenadas,
  ) {
    return coordenadas.map((c) => [c.longitud, c.latitud]).toList();
  }

  /// Limpiar animaciones y estado interno
  void dispose() {
    _stopArrowAnimation();
    _animatedArrowLayerIds.clear();
  }

  // ========== MÉTODOS PARA JOURNEY MANAGER ==========

  /// Actualizar segmento de caminata con nueva ruta recalculada
  Future<void> updateWalkingSegment(List<Coordenada> route) async {
    if (mapboxMap == null || route.isEmpty) return;

    print("[MapRouteRenderer] Updating walking segment with ${route.length} points");

    // ID estándar para el segmento de caminata activo
    const sourceId = 'active-walk-segment-source';
    const shadowLayerId = 'active-walk-segment-shadow';
    const mainLayerId = 'active-walk-segment-main';

    try {
      // Verificar si ya existe y actualizar o crear nuevo
      final sourceExists = await mapboxMap!.style.styleSourceExists(sourceId);

      final geoJsonFeature = {
        "type": "Feature",
        "geometry": {
          "type": "LineString",
          "coordinates": _coordenadasToGeoJsonPositionList(route),
        },
      };

      if (sourceExists) {
        // Actualizar fuente existente
        final source = await mapboxMap!.style.getSource(sourceId) as GeoJsonSource;
        await source.updateGeoJSON(jsonEncode(geoJsonFeature));
      } else {
        // Crear nueva fuente
        await mapboxMap!.style.addSource(
          GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)),
        );
        mapManager.registerSource(sourceId);

        // Agregar capa de borde
        await mapboxMap!.style.addLayer(
          LineLayer(
            id: shadowLayerId,
            sourceId: sourceId,
            lineColor: MapStyleConstants.BORDER_PROPERTIES['line-color'] as int,
            lineWidth:
                (MapStyleConstants.BORDER_PROPERTIES['line-width'] as num)
                    .toDouble(),
            lineOpacity:
                (MapStyleConstants.BORDER_PROPERTIES['line-opacity'] as num)
                    .toDouble(),
            lineJoin: LineJoin.ROUND,
            lineCap: LineCap.ROUND,
          ),
        );
        mapManager.registerLayer(shadowLayerId);

        // Agregar capa principal con color azul distintivo
        await mapboxMap!.style.addLayer(
          LineLayer(
            id: mainLayerId,
            sourceId: sourceId,
            lineColor: 0xFF2196F3, // Azul distintivo para tramo activo
            lineWidth: 6.0,
            lineOpacity: 1.0,
            lineJoin: LineJoin.ROUND,
            lineCap: LineCap.ROUND,
          ),
        );
        mapManager.registerLayer(mainLayerId);
      }

      print("[MapRouteRenderer] Walking segment updated successfully");
    } catch (e) {
      print("[MapRouteRenderer] Error updating walking segment: $e");
    }
  }

  /// Dibujar línea verde desde bus hasta parada (bus approach)
  Future<void> drawBusApproachLine(
    Coordenada busPosition,
    Coordenada stopPosition,
  ) async {
    if (mapboxMap == null) return;

    print("[MapRouteRenderer] Drawing bus approach line");

    const sourceId = 'bus-approach-line-source';
    const shadowLayerId = 'bus-approach-line-shadow';
    const mainLayerId = 'bus-approach-line-main';

    try {
      final geoJsonFeature = {
        "type": "Feature",
        "geometry": {
          "type": "LineString",
          "coordinates": [
            [busPosition.longitud, busPosition.latitud],
            [stopPosition.longitud, stopPosition.latitud],
          ],
        },
      };

      // Verificar si ya existe y actualizar o crear nuevo
      final sourceExists = await mapboxMap!.style.styleSourceExists(sourceId);

      if (sourceExists) {
        // Actualizar fuente existente
        final source = await mapboxMap!.style.getSource(sourceId) as GeoJsonSource;
        await source.updateGeoJSON(jsonEncode(geoJsonFeature));
      } else {
        // Crear nueva fuente
        await mapboxMap!.style.addSource(
          GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)),
        );
        mapManager.registerSource(sourceId);

        // Agregar capa de borde
        await mapboxMap!.style.addLayer(
          LineLayer(
            id: shadowLayerId,
            sourceId: sourceId,
            lineColor: MapStyleConstants.BORDER_PROPERTIES['line-color'] as int,
            lineWidth:
                (MapStyleConstants.BORDER_PROPERTIES['line-width'] as num)
                    .toDouble(),
            lineOpacity:
                (MapStyleConstants.BORDER_PROPERTIES['line-opacity'] as num)
                    .toDouble(),
            lineJoin: LineJoin.ROUND,
            lineCap: LineCap.ROUND,
          ),
        );
        mapManager.registerLayer(shadowLayerId);

        // Agregar capa principal con color verde distintivo
        await mapboxMap!.style.addLayer(
          LineLayer(
            id: mainLayerId,
            sourceId: sourceId,
            lineColor: 0xFF4CAF50, // Verde para indicar llegada del bus
            lineWidth: 5.0,
            lineOpacity: 0.8,
            lineJoin: LineJoin.ROUND,
            lineCap: LineCap.ROUND,
            lineDasharray: [2.0, 2.0], // Línea punteada
          ),
        );
        mapManager.registerLayer(mainLayerId);
      }

      print("[MapRouteRenderer] Bus approach line drawn successfully");
    } catch (e) {
      print("[MapRouteRenderer] Error drawing bus approach line: $e");
    }
  }

  /// Limpiar línea verde de acercamiento del bus
  Future<void> clearBusApproachLine() async {
    if (mapboxMap == null) return;

    print("[MapRouteRenderer] Clearing bus approach line");

    const sourceId = 'bus-approach-line-source';
    const shadowLayerId = 'bus-approach-line-shadow';
    const mainLayerId = 'bus-approach-line-main';

    try {
      // Remover capas
      if (await mapboxMap!.style.styleLayerExists(mainLayerId)) {
        await mapboxMap!.style.removeStyleLayer(mainLayerId);
        mapManager.unregisterLayer(mainLayerId);
      }

      if (await mapboxMap!.style.styleLayerExists(shadowLayerId)) {
        await mapboxMap!.style.removeStyleLayer(shadowLayerId);
        mapManager.unregisterLayer(shadowLayerId);
      }

      // Remover fuente
      if (await mapboxMap!.style.styleSourceExists(sourceId)) {
        await mapboxMap!.style.removeStyleSource(sourceId);
        mapManager.unregisterSource(sourceId);
      }

      print("[MapRouteRenderer] Bus approach line cleared successfully");
    } catch (e) {
      print("[MapRouteRenderer] Error clearing bus approach line: $e");
    }
  }
}
