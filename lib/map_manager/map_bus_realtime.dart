import 'dart:convert';
import 'dart:async';
import 'dart:math' show sin, pi;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import 'package:bondi_uy/utils/geometry_utils.dart';
import 'map_manager.dart';
import 'map_icons_loader.dart';

/// Módulo especializado en manejar buses en tiempo real y tooltips
class MapBusRealtime {
  final MapboxMap? mapboxMap;
  final MapManager mapManager;

  // Sistema de bus en tiempo real para viaje activo
  Timer? _busTrackingTimer;
  String? _currentBusLine;
  String? _currentBusDestination;
  Coordenada? _currentBusPosition;
  int? _currentBusEta;
  bool? _currentBusIsRealTime;

  // Variables para la animación del tooltip flotante
  Timer? _tooltipFloatTimer;
  double _tooltipFloatPhase = 0.0;
  double _lastTooltipOffset = -5.0;

  // Constantes para el bus en tiempo real en viaje activo
  static const String INCOMING_BUS_SOURCE_ID = 'incoming-bus-source';
  static const String INCOMING_BUS_LAYER_ID = 'incoming-bus-layer';
  static const String BUS_TOOLTIP_LAYER_ID = "bus-tooltip-layer";
  static const String BUS_APPROACH_LINE_SOURCE_ID = 'bus-approach-line-source';
  static const String BUS_APPROACH_LINE_LAYER_ID = 'bus-approach-line-layer';
  static const String BUS_APPROACH_LINE_BORDER_LAYER_ID =
      'bus-approach-line-border-layer';

  // Constantes para buses en tiempo real en preview
  static const String PREVIEW_BUS_REALTIME_SOURCE_PREFIX =
      'preview-bus-realtime-source-';
  static const String PREVIEW_BUS_REALTIME_LAYER_PREFIX =
      'preview-bus-realtime-layer-';
  static const String PREVIEW_BUS_TOOLTIP_LAYER_PREFIX =
      'preview-bus-tooltip-layer-';
  static const String PREVIEW_BUS_APPROACH_SOURCE_PREFIX =
      'preview-bus-approach-source-';
  static const String PREVIEW_BUS_APPROACH_LAYER_PREFIX =
      'preview-bus-approach-layer-';

  MapBusRealtime(this.mapboxMap, this.mapManager);

  /// Mostrar buses en tiempo real para preview de ruta
  Future<void> displayRealtimeBusesForPreview(
    OpcionDeRutaMostrable ruta,
  ) async {
    if (mapboxMap == null || !mapManager.iconsLoader.areIconsLoaded) return;

    print("[MapBusRealtime] Displaying realtime buses for preview");

    // Buscar SOLO el primer tramo de bus (más relevante para el usuario en preview)
    TramoViajeMostrable? primerTramoBus;
    int indicePrimerTramoBus = -1;

    for (int i = 0; i < ruta.tramosParaPreview.length; i++) {
      final tramo = ruta.tramosParaPreview[i];

      // Solo considerar VIAJE_EN_BUS para información de bus en tiempo real
      // Los tramos ESPERAR_BUS son solo marcadores estáticos
      if (tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS) {
        primerTramoBus = tramo;
        indicePrimerTramoBus = i;
        print(
          "[MapBusRealtime] First bus segment found at index $i: line=${tramo.nombreLineaBus}",
        );
        break; // Solo el primer tramo de bus
      }
    }

    int busesAdded = 0;

    if (primerTramoBus != null) {
      // Verificar si tiene información de bus en tiempo real
      if (primerTramoBus.posicionActualBus != null &&
          primerTramoBus.minutosEstimadosLlegadaBus != null &&
          primerTramoBus.nombreLineaBus != null) {
        await _addRealtimeBusToPreview(primerTramoBus, indicePrimerTramoBus);
        busesAdded++;
        print(
          "[MapBusRealtime] Added realtime bus for first bus line ${primerTramoBus.nombreLineaBus}",
        );
      } else {
        // Si el tramo no tiene datos, usar el ETA general de la ruta como fallback
        if (ruta.etaProximoBus != null &&
            ruta.etaProximoBus!.posicionBus != null) {
          print(
            "[MapBusRealtime] Using general route ETA as fallback: line=${ruta.etaProximoBus!.linea}, eta=${ruta.etaProximoBus!.minutosParaLlegada}min",
          );
          await _addRealtimeBusFromEta(
            ruta.etaProximoBus!,
            indicePrimerTramoBus,
          );
          busesAdded++;
        }
      }
    } else {
      // Como último recurso, usar el ETA general si existe
      if (ruta.etaProximoBus != null &&
          ruta.etaProximoBus!.posicionBus != null) {
        print(
          "[MapBusRealtime] Using general route ETA as only option: line=${ruta.etaProximoBus!.linea}",
        );
        await _addRealtimeBusFromEta(
          ruta.etaProximoBus!,
          0, // Usar índice 0 como fallback
        );
        busesAdded++;
      }
    }

    print("[MapBusRealtime] Total buses added to preview: $busesAdded");
  }

  /// Inicializar tracking de bus para viaje activo
  Future<void> initializeActiveTripTracking(
    EstadoFaseViajeActivo activeTripState,
  ) async {
    print("[MapBusRealtime] Initializing active trip bus tracking");

    // TODO: Implementar lógica inicial de tracking si es necesario
    // Por ahora este método está preparado para futuras expansiones
  }

  /// Actualizar tracking de bus para tramo específico en viaje activo
  Future<void> updateBusTrackingForLeg(
    int legIndex,
    List<TramoViajeMostrable> tramos,
  ) async {
    if (tramos.isEmpty || legIndex >= tramos.length) {
      _stopBusTracking();
      return;
    }

    print("[MapBusRealtime] Updating bus tracking for leg $legIndex");

    // Determinar cuál es el próximo tramo de bus que necesitamos trackear
    TramoViajeMostrable? proximoTramoBus = _findNextBusSegment(
      tramos,
      legIndex,
    );

    if (proximoTramoBus != null) {
      print(
        "[MapBusRealtime] Next bus segment found: line=${proximoTramoBus.nombreLineaBus}, type=${proximoTramoBus.tipo}",
      );
      _startBusTracking(proximoTramoBus);

      // Si el tramo ya tiene información de bus, mostrarla inmediatamente
      if (proximoTramoBus.posicionActualBus != null) {
        await updateBusPosition(
          proximoTramoBus.posicionActualBus!,
          proximoTramoBus.minutosEstimadosLlegadaBus ?? 0,
          proximoTramoBus.esTiempoRealBus ?? false,
        );
      }
    } else {
      print(
        "[MapBusRealtime] No more bus segments to track, stopping bus tracking",
      );
      _stopBusTracking();
    }
  }

  /// Actualizar posición del bus en tiempo real
  Future<void> updateBusPosition(
    Coordenada position,
    int etaMinutes,
    bool isRealTime,
  ) async {
    _currentBusPosition = position;
    _currentBusEta = etaMinutes;
    _currentBusIsRealTime = isRealTime;

    await _displayBusOnMap(position);
  }

  /// Encontrar el próximo tramo de bus a trackear
  TramoViajeMostrable? _findNextBusSegment(
    List<TramoViajeMostrable> tramos,
    int currentLegIndex,
  ) {
    final tramoActual = tramos[currentLegIndex];

    // Lógica para determinar el próximo tramo de bus a trackear
    switch (tramoActual.tipo) {
      case TipoTramoViaje.CAMINAR:
        // Si estoy caminando, buscar el siguiente tramo de bus (solo VIAJE_EN_BUS)
        for (int i = currentLegIndex + 1; i < tramos.length; i++) {
          final tramo = tramos[i];
          if (tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS) {
            print("[MapBusRealtime] Walking phase: found next bus at index $i");
            return tramo;
          }
        }
        break;

      case TipoTramoViaje.ESPERAR_BUS:
        // Si estoy esperando el bus, buscar el siguiente tramo VIAJE_EN_BUS
        for (int i = currentLegIndex + 1; i < tramos.length; i++) {
          final tramo = tramos[i];
          if (tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS) {
            print(
              "[MapBusRealtime] Waiting phase: found bus to track at index $i",
            );
            return tramo;
          }
        }
        break;

      case TipoTramoViaje.VIAJE_EN_BUS:
        // Si ya estoy EN el bus viajando, buscar el siguiente tramo de bus (transbordo)
        for (int i = currentLegIndex + 1; i < tramos.length; i++) {
          final tramo = tramos[i];
          if (tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS) {
            print(
              "[MapBusRealtime] On bus phase: found next transfer bus at index $i",
            );
            return tramo;
          }
        }
        // Si no hay más buses, esto significa que estoy en el último/único bus
        print(
          "[MapBusRealtime] On bus phase: this is the last bus, no more tracking needed",
        );
        return null;
    }

    print("[MapBusRealtime] No next bus segment found");
    return null;
  }

  /// Iniciar tracking de bus
  void _startBusTracking(TramoViajeMostrable tramo) {
    // Solo trackear buses para tramos VIAJE_EN_BUS
    if (tramo.tipo != TipoTramoViaje.VIAJE_EN_BUS) {
      print(
        "[MapBusRealtime] Skipping tracking for non-bus segment type: ${tramo.tipo}",
      );
      return;
    }

    _currentBusLine = tramo.nombreLineaBus;
    _currentBusDestination = tramo.destinoFinalDelBus;

    // Obtener información inicial del bus si está disponible
    if (tramo.posicionActualBus != null) {
      updateBusPosition(
        tramo.posicionActualBus!,
        tramo.minutosEstimadosLlegadaBus ?? 0,
        tramo.esTiempoRealBus ?? false,
      );
    }

    // Iniciar timer de actualización cada 15 segundos
    _busTrackingTimer?.cancel();
    _busTrackingTimer = Timer.periodic(
      const Duration(seconds: 15),
      (timer) => _fetchBusUpdate(tramo),
    );

    print(
      "[MapBusRealtime] Bus tracking started for line: $_currentBusLine (type: ${tramo.tipo})",
    );
  }

  /// Detener tracking de bus
  void _stopBusTracking() {
    _busTrackingTimer?.cancel();
    _busTrackingTimer = null;
    _clearBusDisplay();

    _currentBusPosition = null;
    _currentBusEta = null;
    _currentBusIsRealTime = null;
    _currentBusLine = null;
    _currentBusDestination = null;

    print("[MapBusRealtime] Bus tracking stopped");
  }

  /// Obtener actualización del bus (placeholder para futuras implementaciones)
  Future<void> _fetchBusUpdate(TramoViajeMostrable tramo) async {
    // TODO: Implementar llamada al backend para obtener posición actualizada del bus
    // Por ahora usamos los datos del tramo si están disponibles
    if (tramo.posicionActualBus != null) {
      await updateBusPosition(
        tramo.posicionActualBus!,
        tramo.minutosEstimadosLlegadaBus ?? 0,
        tramo.esTiempoRealBus ?? false,
      );
    }
  }

  /// Mostrar bus en el mapa para viaje activo
  Future<void> _displayBusOnMap(Coordenada position) async {
    if (mapboxMap == null) return;

    try {
      // Crear feature del bus
      final busFeature = {
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [position.longitud, position.latitud],
        },
        "properties": {
          "line": _currentBusLine,
          "eta": _currentBusEta,
          "isRealTime": _currentBusIsRealTime,
        },
      };

      final sourceData = {
        "type": "FeatureCollection",
        "features": [busFeature],
      };

      // Agregar o actualizar fuente del bus
      try {
        if (await mapboxMap!.style.styleSourceExists(INCOMING_BUS_SOURCE_ID)) {
          final source =
              await mapboxMap!.style.getSource(INCOMING_BUS_SOURCE_ID)
                  as GeoJsonSource;
          await source.updateGeoJSON(json.encode(sourceData));
        } else {
          await mapboxMap!.style.addSource(
            GeoJsonSource(
              id: INCOMING_BUS_SOURCE_ID,
              data: json.encode(sourceData),
            ),
          );
          mapManager.registerSource(INCOMING_BUS_SOURCE_ID);
        }
      } catch (e) {
        print("[MapBusRealtime] Error updating bus source: $e");
        return;
      }

      // Crear capa del bus si no existe
      if (!await mapboxMap!.style.styleLayerExists(INCOMING_BUS_LAYER_ID)) {
        await mapboxMap!.style.addLayer(
          SymbolLayer(
            id: INCOMING_BUS_LAYER_ID,
            sourceId: INCOMING_BUS_SOURCE_ID,
            iconImage: MapIconsLoader.BUS_ICON_IMAGE_ID,
            iconSize: 0.5, // Más pequeño para viaje activo (antes era 0.6)
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
          ),
        );
        mapManager.registerLayer(INCOMING_BUS_LAYER_ID);
      }

      // Crear capa del tooltip si no existe
      if (!await mapboxMap!.style.styleLayerExists(BUS_TOOLTIP_LAYER_ID)) {
        await mapboxMap!.style.addLayer(
          SymbolLayer(
            id: BUS_TOOLTIP_LAYER_ID,
            sourceId: INCOMING_BUS_SOURCE_ID, // Usar la misma fuente que el bus
            iconImage: MapIconsLoader.BUS_TOOLTIP_ICON_ID,
            iconSize: 0.5, // Mismo tamaño que el bus (antes era 0.6)
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
            iconOffset: [0.0, -5.0], // Posición base arriba del bus
          ),
        );
        mapManager.registerLayer(BUS_TOOLTIP_LAYER_ID);
      }

      // Iniciar animación flotante del tooltip
      _startTooltipFloatingAnimation();

      print(
        "[MapBusRealtime] Bus and tooltip displayed at ${position.latitud}, ${position.longitud}",
      );
    } catch (e) {
      print("[MapBusRealtime] Error displaying bus on map: $e");
    }
  }

  /// Limpiar display del bus
  Future<void> _clearBusDisplay() async {
    if (mapboxMap == null) return;

    // Detener animación del tooltip
    _stopTooltipFloatingAnimation();

    try {
      // Remover capa del tooltip
      if (await mapboxMap!.style.styleLayerExists(BUS_TOOLTIP_LAYER_ID)) {
        await mapboxMap!.style.removeStyleLayer(BUS_TOOLTIP_LAYER_ID);
      }

      // Remover capa del bus
      if (await mapboxMap!.style.styleLayerExists(INCOMING_BUS_LAYER_ID)) {
        await mapboxMap!.style.removeStyleLayer(INCOMING_BUS_LAYER_ID);
      }

      // Remover fuente (compartida por bus y tooltip)
      if (await mapboxMap!.style.styleSourceExists(INCOMING_BUS_SOURCE_ID)) {
        await mapboxMap!.style.removeStyleSource(INCOMING_BUS_SOURCE_ID);
      }

      print("[MapBusRealtime] Bus display and tooltip cleared");
    } catch (e) {
      print("[MapBusRealtime] Error clearing bus display: $e");
    }
  }

  // ========== MÉTODOS PARA PREVIEW ==========

  Future<void> _addRealtimeBusToPreview(
    TramoViajeMostrable tramo,
    int segmentIndex,
  ) async {
    if (mapboxMap == null ||
        tramo.posicionActualBus == null ||
        tramo.geometriaPolilinea == null ||
        tramo.geometriaPolilinea!.isEmpty)
      return;

    final sourceId = '$PREVIEW_BUS_REALTIME_SOURCE_PREFIX$segmentIndex';
    final layerId = '$PREVIEW_BUS_REALTIME_LAYER_PREFIX$segmentIndex';

    // Coordenada del bus
    final busPosition = tramo.posicionActualBus!;

    // Parada de origen (donde el usuario debe subir)
    final paradaOrigen = tramo.geometriaPolilinea!.first;

    final geoJsonFeature = {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [busPosition.longitud, busPosition.latitud],
      },
      "properties": {
        "linea": tramo.nombreLineaBus,
        "eta": tramo.minutosEstimadosLlegadaBus,
        "isRealTime": tramo.esTiempoRealBus ?? false,
        "destino": tramo.destinoFinalDelBus,
      },
    };

    try {
      // 1. Agregar línea verde de aproximación PRIMERO (para que quede debajo del bus)
      await _addBusApproachLineToPreview(
        busPosition,
        paradaOrigen,
        segmentIndex,
        tramo,
      );

      // 2. Agregar fuente del bus
      await mapboxMap!.style.addSource(
        GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)),
      );
      mapManager.registerSource(sourceId);

      // 3. Agregar capa del bus con tamaño más pequeño para preview
      await mapboxMap!.style.addLayer(
        SymbolLayer(
          id: layerId,
          sourceId: sourceId,
          iconImage: MapIconsLoader.BUS_ICON_IMAGE_ID,
          iconAllowOverlap: true,
          iconSize: 0.6, // Más grande para preview (antes era 0.5)
          iconAnchor: IconAnchor.CENTER,
        ),
      );
      mapManager.registerLayer(layerId);

      // 4. Agregar capa del tooltip flotante
      final tooltipLayerId = '$PREVIEW_BUS_TOOLTIP_LAYER_PREFIX$segmentIndex';
      await mapboxMap!.style.addLayer(
        SymbolLayer(
          id: tooltipLayerId,
          sourceId: sourceId, // Usar la misma fuente que el bus
          iconImage: MapIconsLoader.PREVIEW_BUS_TOOLTIP_ICON_ID,
          iconAllowOverlap: true,
          iconSize: 0.6, // Mismo tamaño que el bus (antes era 0.5)
          iconAnchor: IconAnchor.CENTER,
          iconOffset: [
            0.0,
            _lastTooltipOffset,
          ], // Posición inicial arriba del bus
        ),
      );
      mapManager.registerLayer(tooltipLayerId);

      // 5. Iniciar animación flotante del tooltip para preview
      _startTooltipFloatingAnimationPreview();

      print(
        "[MapBusRealtime] Added realtime bus for line ${tramo.nombreLineaBus} with ETA ${tramo.minutosEstimadosLlegadaBus}min and tooltip",
      );
    } catch (e) {
      print("[MapBusRealtime] Error adding realtime bus: $e");
    }
  }

  Future<void> _addBusApproachLineToPreview(
    Coordenada busPosition,
    Coordenada stopPosition,
    int segmentIndex,
    TramoViajeMostrable tramo,
  ) async {
    if (mapboxMap == null) return;

    final sourceId = '$PREVIEW_BUS_APPROACH_SOURCE_PREFIX$segmentIndex';
    final shadowLayerId =
        '$PREVIEW_BUS_APPROACH_LAYER_PREFIX$segmentIndex-shadow';
    final mainLayerId = '$PREVIEW_BUS_APPROACH_LAYER_PREFIX$segmentIndex';

    print("[MapBusRealtime] Creating bus approach line:");
    print(
      "  - Bus position: (${busPosition.latitud}, ${busPosition.longitud})",
    );
    print(
      "  - Stop position: (${stopPosition.latitud}, ${stopPosition.longitud})",
    );

    // Cargar geometrías de shapes si no están cargadas
    await loadShapeGeometries();

    // Obtener la geometría completa de la línea usando el shapeId
    List<Coordenada>? fullLineGeometry;
    if (tramo.shapeId != null) {
      fullLineGeometry = getFullShapeGeometry(tramo.shapeId);
    }

    // Si no tenemos geometría completa, usar la del tramo como fallback
    if (fullLineGeometry == null || fullLineGeometry.isEmpty) {
      fullLineGeometry = tramo.geometriaPolilinea;
    }

    List<List<double>> coordinates;

    if (fullLineGeometry != null && fullLineGeometry.isNotEmpty) {
      // Encontrar índices en la geometría completa
      final busIndex = findClosestPointIndexOnShape(
        fullLineGeometry,
        busPosition,
      );
      final stopIndex = findClosestPointIndexOnShape(
        fullLineGeometry,
        stopPosition,
      );

      if (busIndex == -1 || stopIndex == -1) {
        // Usar línea recta como fallback
        coordinates = [
          [busPosition.longitud, busPosition.latitud],
          [stopPosition.longitud, stopPosition.latitud],
        ];
      } else {
        // Calcular segmento de la geometría entre bus y parada
        final segment = getGeometrySegment(
          fullLineGeometry,
          busIndex,
          stopIndex,
        );

        if (segment.length < 2) {
          coordinates = [
            [busPosition.longitud, busPosition.latitud],
            [stopPosition.longitud, stopPosition.latitud],
          ];
        } else {
          coordinates = segment.map((c) => [c.longitud, c.latitud]).toList();
        }
      }
    } else {
      // Sin geometría, usar línea recta
      coordinates = [
        [busPosition.longitud, busPosition.latitud],
        [stopPosition.longitud, stopPosition.latitud],
      ];
    }

    // Crear línea siguiendo la geometría de la ruta
    final geoJsonFeatureCollection = {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "geometry": {"type": "LineString", "coordinates": coordinates},
          "properties": {"type": "bus-approach"},
        },
      ],
    };

    try {
      // Agregar fuente de la línea verde
      await mapboxMap!.style.addSource(
        GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeatureCollection)),
      );
      mapManager.registerSource(sourceId);

      // 1. Agregar capa de borde (más gruesa, negra, debajo)
      await mapboxMap!.style.addLayer(
        LineLayer(
          id: shadowLayerId,
          sourceId: sourceId,
          lineColor: 0xFF000000, // Negro para el borde
          lineWidth: 8.0, // Consistencia con otros bordes
          lineOpacity: 0.9,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
        ),
      );
      mapManager.registerLayer(shadowLayerId);

      // 2. Agregar capa de línea verde principal (encima del borde)
      await mapboxMap!.style.addLayer(
        LineLayer(
          id: mainLayerId,
          sourceId: sourceId,
          lineColor: 0xFF4CAF50, // Verde como en el código anterior
          lineWidth: 5.0, // Consistencia con BUS
          lineOpacity: 0.9,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
        ),
      );
      mapManager.registerLayer(mainLayerId);

      print(
        "[MapBusRealtime] Added green approach line with border following bus route geometry",
      );
    } catch (e) {
      print("[MapBusRealtime] Error adding approach line: $e");
    }
  }

  Future<void> _addRealtimeBusFromEta(EtaMostrable eta, int index) async {
    if (mapboxMap == null || eta.posicionBus == null) return;

    final sourceId = '${PREVIEW_BUS_REALTIME_SOURCE_PREFIX}eta_$index';
    final layerId = '${PREVIEW_BUS_REALTIME_LAYER_PREFIX}eta_$index';

    final geoJsonFeature = {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [eta.posicionBus!.longitud, eta.posicionBus!.latitud],
      },
      "properties": {
        "linea": eta.linea,
        "eta": eta.minutosParaLlegada,
        "isRealTime": eta.esTiempoReal,
        "destino": eta.destino,
      },
    };

    try {
      // Agregar fuente del bus
      await mapboxMap!.style.addSource(
        GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)),
      );
      mapManager.registerSource(sourceId);

      // Agregar capa del bus
      await mapboxMap!.style.addLayer(
        SymbolLayer(
          id: layerId,
          sourceId: sourceId,
          iconImage: MapIconsLoader.BUS_ICON_IMAGE_ID,
          iconAllowOverlap: true,
          iconSize: 0.6, // Más grande para preview (antes era 0.7)
          iconAnchor: IconAnchor.CENTER,
        ),
      );
      mapManager.registerLayer(layerId);

      // Agregar capa del tooltip flotante
      final tooltipLayerId = '${PREVIEW_BUS_TOOLTIP_LAYER_PREFIX}eta_$index';
      await mapboxMap!.style.addLayer(
        SymbolLayer(
          id: tooltipLayerId,
          sourceId: sourceId, // Usar la misma fuente que el bus
          iconImage: MapIconsLoader.PREVIEW_BUS_TOOLTIP_ICON_ID,
          iconAllowOverlap: true,
          iconSize: 0.6, // Mismo tamaño que el bus (antes era 0.7)
          iconAnchor: IconAnchor.CENTER,
          iconOffset: [
            0.0,
            _lastTooltipOffset,
          ], // Posición inicial arriba del bus
        ),
      );
      mapManager.registerLayer(tooltipLayerId);

      // Iniciar animación flotante del tooltip
      _startTooltipFloatingAnimationPreview();

      print(
        "[MapBusRealtime] Added realtime bus from ETA for line ${eta.linea} with ${eta.minutosParaLlegada}min and tooltip",
      );
    } catch (e) {
      print("[MapBusRealtime] Error adding realtime bus from ETA: $e");
    }
  }

  // ========== MÉTODOS DE ANIMACIÓN ==========

  void _startTooltipFloatingAnimation() {
    print("[MapBusRealtime] Starting tooltip floating animation");
    _stopTooltipFloatingAnimation(); // Detener cualquier animación previa

    // Timer de 60 FPS para animación suave
    _tooltipFloatTimer = Timer.periodic(const Duration(milliseconds: 16), (
      timer,
    ) async {
      if (mapboxMap == null) return;

      // Parámetros de la animación
      const double amplitude = 5.0; // píxeles de movimiento
      const double period = 3.0; // segundos por ciclo completo
      const double baseOffset =
          -5.0; // offset base para llevarlo arriba del bus

      // Incrementar la fase de animación
      _tooltipFloatPhase += (2 * pi) / (period * 1000 / 16);
      if (_tooltipFloatPhase > 2 * pi) _tooltipFloatPhase -= 2 * pi;

      // Calcular el offset flotante usando función seno
      final double offsetY = baseOffset - amplitude * sin(_tooltipFloatPhase);
      _lastTooltipOffset = offsetY;

      try {
        // Verificar si la capa del tooltip existe antes de actualizarla
        final bool layerExists = await mapboxMap!.style.styleLayerExists(
          BUS_TOOLTIP_LAYER_ID,
        );
        if (layerExists) {
          await mapboxMap!.style.setStyleLayerProperty(
            BUS_TOOLTIP_LAYER_ID,
            'icon-offset',
            [0.0, offsetY],
          );
        }
      } catch (e) {
        print("[MapBusRealtime] Error updating tooltip animation: $e");
      }
    });
  }

  void _startTooltipFloatingAnimationPreview() {
    print("[MapBusRealtime] Starting tooltip floating animation for preview");
    _stopTooltipFloatingAnimation(); // Detener cualquier animación previa

    // Timer de 60 FPS para animación suave
    _tooltipFloatTimer = Timer.periodic(const Duration(milliseconds: 16), (
      timer,
    ) async {
      if (mapboxMap == null) return;

      // Parámetros de la animación
      const double amplitude =
          4.0; // píxeles de movimiento (más sutil para preview)
      const double period = 3.0; // segundos por ciclo completo
      const double baseOffset =
          -5.0; // offset base para llevarlo arriba del bus

      // Incrementar la fase de animación
      _tooltipFloatPhase += (2 * pi) / (period * 1000 / 16);
      if (_tooltipFloatPhase > 2 * pi) _tooltipFloatPhase -= 2 * pi;

      // Calcular el offset flotante usando función seno
      final double offsetY = baseOffset - amplitude * sin(_tooltipFloatPhase);
      _lastTooltipOffset = offsetY;

      try {
        // Actualizar todas las capas de tooltip que existan
        for (int i = 0; i < 10; i++) {
          // Máximo 10 opciones de ruta posibles
          final layerId = '$PREVIEW_BUS_TOOLTIP_LAYER_PREFIX$i';
          final bool layerExists = await mapboxMap!.style.styleLayerExists(
            layerId,
          );
          if (layerExists) {
            await mapboxMap!.style.setStyleLayerProperty(
              layerId,
              'icon-offset',
              [0.0, offsetY],
            );
          }
        }
      } catch (e) {
        print("[MapBusRealtime] Error updating tooltip animation: $e");
      }
    });
  }

  void _stopTooltipFloatingAnimation() {
    print("[MapBusRealtime] Stopping tooltip floating animation");
    _tooltipFloatTimer?.cancel();
    _tooltipFloatTimer = null;
    _tooltipFloatPhase = 0.0;

    // Resetear offset del tooltip a posición base
    if (mapboxMap != null) {
      // Para viaje activo
      mapboxMap!.style
          .styleLayerExists(BUS_TOOLTIP_LAYER_ID)
          .then((exists) {
            if (exists) {
              mapboxMap!.style.setStyleLayerProperty(
                BUS_TOOLTIP_LAYER_ID,
                'icon-offset',
                [0.0, -5.0], // Posición base arriba del bus
              );
            }
          })
          .catchError((e) {
            print("[MapBusRealtime] Error resetting tooltip offset: $e");
          });

      // Para preview
      for (int i = 0; i < 10; i++) {
        final layerId = '$PREVIEW_BUS_TOOLTIP_LAYER_PREFIX$i';
        mapboxMap!.style
            .styleLayerExists(layerId)
            .then((exists) {
              if (exists) {
                mapboxMap!.style.setStyleLayerProperty(
                  layerId,
                  'icon-offset',
                  [0.0, -5.0], // Posición base arriba del bus
                );
              }
            })
            .catchError((e) {
              print("[MapBusRealtime] Error resetting tooltip offset: $e");
            });
      }
    }
  }

  /// Obtener posición actual del bus en tiempo real (getter público)
  Coordenada? get currentBusPosition => _currentBusPosition;

  /// Detener animaciones y limpiar recursos del preview
  /// Usado específicamente durante transición a active trip
  void stopPreviewAnimations() {
    print("[MapBusRealtime] Stopping preview animations and resources");
    _stopTooltipFloatingAnimation();
  }

  /// Limpiar recursos y detener animaciones
  void dispose() {
    _stopBusTracking();
    _stopTooltipFloatingAnimation();
  }
}
