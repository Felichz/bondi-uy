import 'dart:convert';
import 'dart:async';
import 'dart:math' show sin, pi;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import 'package:bondi_uy/utils/geometry_utils.dart';
import 'map_manager.dart';
import 'map_icons_loader.dart';
import '../backend/providers/app_logic_provider.dart';
import 'package:bondi_uy/journey/journey_step_state.dart';

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

  // DIFF: Agregar estado para tracking híbrido
  BusTrackingMode _trackingMode = BusTrackingMode.INACTIVE;
  // Eliminado: no es necesario mantener una copia local persistente

  // Variables para almacenar información necesaria para actualizar la línea de aproximación
  TramoViajeMostrable? _currentTrackedSegment;
  Coordenada? _currentStopPosition;

  // Variables para la animación del tooltip flotante
  Timer? _tooltipFloatTimer;
  double _tooltipFloatPhase = 0.0;
  double _lastTooltipOffset = -5.0;

  // Constantes para buses en tiempo real (unificadas para preview y active trip)
  static const String BUS_REALTIME_SOURCE_PREFIX = 'bus-realtime-source-';
  static const String BUS_REALTIME_LAYER_PREFIX = 'bus-realtime-layer-';
  static const String BUS_TOOLTIP_LAYER_PREFIX = 'bus-tooltip-layer-';
  static const String BUS_APPROACH_SOURCE_PREFIX = 'bus-approach-source-';
  static const String BUS_APPROACH_LAYER_PREFIX = 'bus-approach-layer-';

  // DIFF: Constantes para tracking de usuario
  static const String USER_BUS_SOURCE_ID = 'user-bus-source';
  static const String USER_BUS_LAYER_ID = 'user-bus-layer';
  static const String USER_BUS_ICON_ID = 'user-bus-icon';

  MapBusRealtime(this.mapboxMap, this.mapManager);

  // DIFF: Getter para obtener modo de tracking actual
  BusTrackingMode get trackingMode => _trackingMode;

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
    // No iniciar/actualizar tracking API si estamos en modo USER_LOCATION (usuario a bordo)
    if (_trackingMode == BusTrackingMode.USER_LOCATION) {
      print(
        "[MapBusRealtime] Skipping updateBusTrackingForLeg because tracking mode is USER_LOCATION",
      );
      return;
    }
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

      // ELIMINADO: Ya no mostramos datos antiguos del tramo automáticamente
      // El sistema de sondeo centralizado se encarga de actualizar con datos frescos
      // if (proximoTramoBus.posicionActualBus != null) {
      //   await updateBusPosition(...)
      // }
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

    // Política de escritura de capas FUERTEMENTE definida por fase:
    // - active_trip: escribir SIEMPRE en las fuentes/capas "main" del viaje activo
    //                (nunca tocar elementos de preview).
    // - otras fases (preview): intentar actualizar elementos de preview si existen.
    final isActiveTrip = mapManager.currentPhase == 'active_trip';

    if (isActiveTrip) {
      // Active trip: no intentar escribir en elementos de preview.
      await _displayBusOnMap(position);
    } else {
      // Preview: actualizar elementos de preview si existen; si no, usar main.
      bool usingPreviewElements = await _tryUpdatePreviewBusElements(
        position,
        etaMinutes,
        isRealTime,
      );
      if (!usingPreviewElements) {
        await _displayBusOnMap(position);
      }
    }

    // Actualizar línea de aproximación verde
    if (_currentStopPosition != null && _currentTrackedSegment != null) {
      await _updateBusApproachLineForActiveTrip(
        position,
        _currentStopPosition!,
      );
    }
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

    // NUEVO: Almacenar información para actualizar la línea de aproximación
    _currentTrackedSegment = tramo;

    // FIX: Decidir qué parada trackear según el modo
    // - USER_LOCATION (usuario a bordo): trackear parada de DESTINO (donde bajar)
    // - API_REALTIME (esperando bus): trackear parada de ORIGEN (donde subir)
    if (_trackingMode == BusTrackingMode.USER_LOCATION) {
      _currentStopPosition = tramo.coordenadasParadaDestino; // Parada donde el usuario debe BAJAR
      print("[MapBusRealtime] USER_LOCATION mode: tracking destination stop (where to get off)");
    } else {
      _currentStopPosition = tramo.coordenadasParadaOrigen; // Parada donde el usuario debe SUBIR
      print("[MapBusRealtime] API_REALTIME mode: tracking origin stop (where to board)");
    }

    // ELIMINADO: Ya no mostramos datos antiguos del tramo automáticamente
    // El sistema de sondeo en tiempo real se encargará de actualizar con datos frescos
    // if (tramo.posicionActualBus != null) {
    //   updateBusPosition(...)
    // }

    // Iniciar timer de actualización cada 15 segundos
    _busTrackingTimer?.cancel();
    _busTrackingTimer = Timer.periodic(
      const Duration(seconds: 15),
      (timer) => _fetchBusUpdate(tramo),
    );

    print(
      "[MapBusRealtime] Bus tracking started for line: $_currentBusLine (type: ${tramo.tipo}) - waiting for real-time updates",
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

    // NUEVO: Limpiar información de tracking
    _currentTrackedSegment = null;
    _currentStopPosition = null;

    print("[MapBusRealtime] Bus tracking stopped");
  }

  /// Obtener actualización del bus (placeholder para futuras implementaciones)
  Future<void> _fetchBusUpdate(TramoViajeMostrable tramo) async {
    print("[MapBusRealtime] _fetchBusUpdate called - fetching real ETA data");

    // IMPLEMENTACIÓN REAL: Conectar con el sistema de ETA que funciona
    try {
      // Obtener el AppLogicProvider para acceder al sistema de ETA
      if (mapManager.ref == null) {
        print("[MapBusRealtime] WidgetRef no disponible en MapManager");
        return;
      }

      // final appLogicNotifier = mapManager.ref!.read(appLogicProvider.notifier); // no usado
      final appUiState = mapManager.ref!.read(appLogicProvider);

      // Obtener datos actualizados del estado del viaje activo
      final activeTripState = appUiState.datosFaseViajeActivo;
      if (activeTripState == null) {
        print("[MapBusRealtime] No hay viaje activo");
        return;
      }

      // Verificar si hay datos de bus en tiempo real disponibles
      if (activeTripState.seguimientoBusRealDisponibleEnTramoActual &&
          activeTripState.posicionActualBusReal != null &&
          activeTripState.minutosParaLlegadaBusReal != null) {
        print("[MapBusRealtime] Datos de ETA real encontrados:");
        print("  - Posición: ${activeTripState.posicionActualBusReal}");
        print("  - ETA: ${activeTripState.minutosParaLlegadaBusReal} min");

        // Actualizar la posición del bus en el mapa
        await updateBusPosition(
          activeTripState.posicionActualBusReal!,
          activeTripState.minutosParaLlegadaBusReal!,
          true, // Es tiempo real
        );
      } else {
        print(
          "[MapBusRealtime] No hay datos de ETA real en este ciclo (active_trip) - mantener última posición válida",
        );
        // Active trip: NO usar fallback del tramo (evita saltos a buses lejanos).
        // Conservamos la última posición válida en pantalla.
      }
    } catch (e) {
      print("[MapBusRealtime] Error obteniendo actualización de ETA: $e");

      // Fallback: usar datos del tramo
      if (tramo.posicionActualBus != null &&
          tramo.minutosEstimadosLlegadaBus != null) {
        print(
          "[MapBusRealtime] Usando datos del tramo como fallback por error",
        );
        await updateBusPosition(
          tramo.posicionActualBus!,
          tramo.minutosEstimadosLlegadaBus!,
          tramo.esTiempoRealBus ?? false,
        );
      }
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
        if (await mapboxMap!.style.styleSourceExists(
          'bus-realtime-source-main',
        )) {
          final source =
              await mapboxMap!.style.getSource('bus-realtime-source-main')
                  as GeoJsonSource;
          await source.updateGeoJSON(json.encode(sourceData));
        } else {
          await mapboxMap!.style.addSource(
            GeoJsonSource(
              id: 'bus-realtime-source-main',
              data: json.encode(sourceData),
            ),
          );
          mapManager.registerSource('bus-realtime-source-main');
        }
      } catch (e) {
        print("[MapBusRealtime] Error updating bus source: $e");
        return;
      }

      // Crear capa del bus si no existe
      if (!await mapboxMap!.style.styleLayerExists('bus-realtime-layer-main')) {
        await mapboxMap!.style.addLayer(
          SymbolLayer(
            id: 'bus-realtime-layer-main',
            sourceId: 'bus-realtime-source-main',
            iconImage: MapIconsLoader.BUS_ICON_IMAGE_ID,
            iconSize: 0.5, // Más pequeño para viaje activo (antes era 0.6)
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
          ),
        );
        mapManager.registerLayer('bus-realtime-layer-main');
      }

      // Crear capa del tooltip si no existe
      if (!await mapboxMap!.style.styleLayerExists('bus-tooltip-layer-main')) {
        await mapboxMap!.style.addLayer(
          SymbolLayer(
            id: 'bus-tooltip-layer-main',
            sourceId:
                'bus-realtime-source-main', // Usar la misma fuente que el bus
            iconImage: MapIconsLoader.BUS_TOOLTIP_ICON_ID,
            iconSize: 0.5, // Mismo tamaño que el bus (antes era 0.6)
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
            iconOffset: [0.0, -5.0], // Posición base arriba del bus
          ),
        );
        mapManager.registerLayer('bus-tooltip-layer-main');
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
      if (await mapboxMap!.style.styleLayerExists('bus-tooltip-layer-main')) {
        await mapboxMap!.style.removeStyleLayer('bus-tooltip-layer-main');
      }

      // Remover capa del bus
      if (await mapboxMap!.style.styleLayerExists('bus-realtime-layer-main')) {
        await mapboxMap!.style.removeStyleLayer('bus-realtime-layer-main');
      }

      // Remover fuente (compartida por bus y tooltip)
      if (await mapboxMap!.style.styleSourceExists(
        'bus-realtime-source-main',
      )) {
        await mapboxMap!.style.removeStyleSource('bus-realtime-source-main');
      }

      // NUEVO: Limpiar línea de aproximación verde
      if (await mapboxMap!.style.styleLayerExists('bus-approach-layer-main')) {
        await mapboxMap!.style.removeStyleLayer('bus-approach-layer-main');
      }

      if (await mapboxMap!.style.styleLayerExists(
        'bus-approach-layer-main-shadow',
      )) {
        await mapboxMap!.style.removeStyleLayer(
          'bus-approach-layer-main-shadow',
        );
      }

      if (await mapboxMap!.style.styleSourceExists(
        'bus-approach-source-main',
      )) {
        await mapboxMap!.style.removeStyleSource('bus-approach-source-main');
      }

      print("[MapBusRealtime] Bus display, tooltip and approach line cleared");
    } catch (e) {
      print("[MapBusRealtime] Error clearing bus display: $e");
    }
  }

  /// Actualizar línea de aproximación verde para viaje activo
  Future<void> _updateBusApproachLineForActiveTrip(
    Coordenada busPosition,
    Coordenada stopPosition,
  ) async {
    if (mapboxMap == null || _currentTrackedSegment == null) return;

    print("[MapBusRealtime] Updating bus approach line:");
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
    if (_currentTrackedSegment!.shapeId != null) {
      fullLineGeometry = getFullShapeGeometry(_currentTrackedSegment!.shapeId);
    }

    // Si no tenemos geometría completa, usar la del tramo como fallback
    if (fullLineGeometry == null || fullLineGeometry.isEmpty) {
      fullLineGeometry = _currentTrackedSegment!.geometriaPolilinea;
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
      // NUEVO: Intentar actualizar líneas de aproximación del preview primero
      bool updatedPreviewLine = await _tryUpdatePreviewApproachLine(
        geoJsonFeatureCollection,
      );

      if (!updatedPreviewLine) {
        // Si no hay líneas del preview, usar las del viaje activo
        await _updateOrCreateActiveTripApproachLine(geoJsonFeatureCollection);
      }
    } catch (e) {
      print("[MapBusRealtime] Error updating bus approach line: $e");
    }
  }

  /// Intentar actualizar líneas de aproximación del preview (durante transición optimizada)
  Future<bool> _tryUpdatePreviewApproachLine(
    Map<String, dynamic> geoJsonFeatureCollection,
  ) async {
    if (mapboxMap == null) return false;

    // Buscar líneas de aproximación del preview que puedan existir
    final previewApproachSourceIds = [
      '${BUS_APPROACH_SOURCE_PREFIX}0',
      '${BUS_APPROACH_SOURCE_PREFIX}1',
      '${BUS_APPROACH_SOURCE_PREFIX}2',
      '${BUS_APPROACH_SOURCE_PREFIX}3',
      '${BUS_APPROACH_SOURCE_PREFIX}4',
    ];

    for (String sourceId in previewApproachSourceIds) {
      try {
        if (await mapboxMap!.style.styleSourceExists(sourceId)) {
          final source =
              await mapboxMap!.style.getSource(sourceId) as GeoJsonSource;
          await source.updateGeoJSON(json.encode(geoJsonFeatureCollection));
          print(
            "[MapBusRealtime] Updated preview approach line source: $sourceId",
          );
          return true; // Éxito actualizando línea del preview
        }
      } catch (e) {
        print(
          "[MapBusRealtime] Error updating preview approach line $sourceId: $e",
        );
        continue; // Intentar con el siguiente
      }
    }

    return false; // No se encontraron líneas del preview para actualizar
  }

  /// Actualizar o crear líneas de aproximación para viaje activo
  Future<void> _updateOrCreateActiveTripApproachLine(
    Map<String, dynamic> geoJsonFeatureCollection,
  ) async {
    if (mapboxMap == null) return;

    // Ajustar estilo según el tipo de paso actual (menor énfasis al CAMINAR)
    double shadowWidth = 8.0;
    double shadowOpacity = 1.0;
    double mainWidth = 5.0;
    double mainOpacity = 0.9;

    // GRANDMA FIRST: JourneyStep ya no está en AppUiState
    // Usar valores por defecto razonables para WAITING_FOR_BUS/RIDING_BUS
    try {
      // TODO: Si necesario, exponer paso actual desde JourneyManager
      final currentType = JourneyStepType.WAITING_FOR_BUS; // Valor por defecto
      if (currentType != null) {
        switch (currentType) {
          case JourneyStepType.WALKING_TO_STOP:
            shadowWidth = 6.0;
            shadowOpacity = 0.6;
            mainWidth = 3.5;
            mainOpacity = 0.55;
            break;
          case JourneyStepType.WAITING_FOR_BUS:
          case JourneyStepType.RIDING_BUS:
          case JourneyStepType.WALKING_TO_DESTINATION:
            // Usar valores por defecto (más énfasis)
            break;
        }
      }
    } catch (_) {
      // Si falla, usar valores por defecto
    }

    // Actualizar o crear fuente de la línea verde para viaje activo
    final sourceExists = await mapboxMap!.style.styleSourceExists(
      'bus-approach-source-main',
    );
    if (sourceExists) {
      final source =
          await mapboxMap!.style.getSource('bus-approach-source-main')
              as GeoJsonSource;
      await source.updateGeoJSON(json.encode(geoJsonFeatureCollection));

      // Asegurar estilo actualizado según el paso actual (ajustar pesos/opacidades)
      try {
        if (await mapboxMap!.style.styleLayerExists(
          'bus-approach-layer-main-shadow',
        )) {
          await mapboxMap!.style.setStyleLayerProperty(
            'bus-approach-layer-main-shadow',
            'line-width',
            shadowWidth,
          );
          await mapboxMap!.style.setStyleLayerProperty(
            'bus-approach-layer-main-shadow',
            'line-opacity',
            shadowOpacity,
          );
        }
        if (await mapboxMap!.style.styleLayerExists(
          'bus-approach-layer-main',
        )) {
          await mapboxMap!.style.setStyleLayerProperty(
            'bus-approach-layer-main',
            'line-width',
            mainWidth,
          );
          await mapboxMap!.style.setStyleLayerProperty(
            'bus-approach-layer-main',
            'line-opacity',
            mainOpacity,
          );
        }
      } catch (_) {}
    } else {
      // Crear fuente nueva
      await mapboxMap!.style.addSource(
        GeoJsonSource(
          id: 'bus-approach-source-main',
          data: json.encode(geoJsonFeatureCollection),
        ),
      );
      mapManager.registerSource('bus-approach-source-main');

      // 1. Agregar capa de borde (más gruesa, negra, debajo)
      await mapboxMap!.style.addLayer(
        LineLayer(
          id: 'bus-approach-layer-main-shadow',
          sourceId: 'bus-approach-source-main',
          lineColor: 0xFF000000, // Negro para el borde
          lineWidth: shadowWidth,
          lineOpacity: shadowOpacity,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
        ),
      );
      mapManager.registerLayer('bus-approach-layer-main-shadow');

      // 2. Agregar capa de línea verde principal (encima del borde)
      await mapboxMap!.style.addLayer(
        LineLayer(
          id: 'bus-approach-layer-main',
          sourceId: 'bus-approach-source-main',
          lineColor: 0xFF4CAF50, // Verde como en el código anterior
          lineWidth: mainWidth,
          lineOpacity: mainOpacity,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
        ),
      );
      mapManager.registerLayer('bus-approach-layer-main');

      print(
        "[MapBusRealtime] Created bus approach line with border for active trip",
      );
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

    final sourceId = '$BUS_REALTIME_SOURCE_PREFIX$segmentIndex';
    final layerId = '$BUS_REALTIME_LAYER_PREFIX$segmentIndex';

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
      final tooltipLayerId = '$BUS_TOOLTIP_LAYER_PREFIX$segmentIndex';
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

    final sourceId = '$BUS_APPROACH_SOURCE_PREFIX$segmentIndex';
    final shadowLayerId = '$BUS_APPROACH_LAYER_PREFIX$segmentIndex-shadow';
    final mainLayerId = '$BUS_APPROACH_LAYER_PREFIX$segmentIndex';

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

    final sourceId = '$BUS_REALTIME_SOURCE_PREFIX$index';
    final layerId = '$BUS_REALTIME_LAYER_PREFIX$index';

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
      final tooltipLayerId = '$BUS_TOOLTIP_LAYER_PREFIX$index';
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
          'bus-tooltip-layer-main',
        );
        if (layerExists) {
          await mapboxMap!.style.setStyleLayerProperty(
            'bus-tooltip-layer-main',
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
          final layerId = '$BUS_TOOLTIP_LAYER_PREFIX$i';
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
          .styleLayerExists('bus-tooltip-layer-main')
          .then((exists) {
            if (exists) {
              mapboxMap!.style.setStyleLayerProperty(
                'bus-tooltip-layer-main',
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
        final layerId = '$BUS_TOOLTIP_LAYER_PREFIX$i';
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

  /// Intentar actualizar elementos del preview si existen (durante transición optimizada)
  Future<bool> _tryUpdatePreviewBusElements(
    Coordenada position,
    int etaMinutes,
    bool isRealTime,
  ) async {
    if (mapboxMap == null) return false;

    // Buscar fuentes de bus del preview que puedan existir
    final previewBusSourceIds = [
      '${BUS_REALTIME_SOURCE_PREFIX}0',
      '${BUS_REALTIME_SOURCE_PREFIX}1',
      '${BUS_REALTIME_SOURCE_PREFIX}2',
      '${BUS_REALTIME_SOURCE_PREFIX}3',
      '${BUS_REALTIME_SOURCE_PREFIX}4',
    ];

    for (String sourceId in previewBusSourceIds) {
      try {
        if (await mapboxMap!.style.styleSourceExists(sourceId)) {
          // Actualizar la fuente del bus del preview con nueva posición
          final busFeature = {
            "type": "Feature",
            "geometry": {
              "type": "Point",
              "coordinates": [position.longitud, position.latitud],
            },
            "properties": {
              "linea": _currentBusLine,
              "eta": etaMinutes,
              "isRealTime": isRealTime,
              "destino": _currentBusDestination,
            },
          };

          final sourceData = {
            "type": "FeatureCollection",
            "features": [busFeature],
          };

          final source =
              await mapboxMap!.style.getSource(sourceId) as GeoJsonSource;
          await source.updateGeoJSON(json.encode(sourceData));

          print(
            "[MapBusRealtime] Updated preview bus source: $sourceId with new position (${position.latitud}, ${position.longitud})",
          );
          return true; // Éxito actualizando elemento del preview
        }
      } catch (e) {
        print(
          "[MapBusRealtime] Error updating preview bus source $sourceId: $e",
        );
        continue; // Intentar con el siguiente
      }
    }

    return false; // No se encontraron elementos del preview para actualizar
  }

  /// Obtener posición actual del bus en tiempo real (getter público)
  Coordenada? get currentBusPosition => _currentBusPosition;

  /// Obtener la parada actual que se está trackeando (getter público para testing)
  Coordenada? get currentStopPosition => _currentStopPosition;

  /// Detener animaciones y limpiar recursos del preview
  /// Usado específicamente durante transición a active trip
  void stopPreviewAnimations() {
    print("[MapBusRealtime] Stopping preview animations and resources");
    _stopTooltipFloatingAnimation();
  }

  // DIFF: Nuevo método para cambiar a modo de tracking del usuario
  Future<void> switchToUserLocationMode() async {
    print('[MapBusRealtime] Switching to user location tracking mode');

    _trackingMode = BusTrackingMode.USER_LOCATION;

    // Detener sondeo de API
    _busTrackingTimer?.cancel();
    _busTrackingTimer = null;

    // FIX: Al cambiar a USER_LOCATION, actualizar la parada trackeada a DESTINO
    if (_currentTrackedSegment != null &&
        _currentTrackedSegment!.tipo == TipoTramoViaje.VIAJE_EN_BUS) {
      _currentStopPosition = _currentTrackedSegment!.coordenadasParadaDestino;
      print(
        '[MapBusRealtime] Updated stop position to DESTINATION (user is now on board)',
      );
    }

    // El bus ahora será renderizado usando la ubicación del usuario
    // Esto se manejará desde el LocationTracker
    print(
      '[MapBusRealtime] Switched to user location mode - API polling stopped',
    );
  }

  // DIFF: Nuevo método para renderizar bus en ubicación del usuario
  Future<void> updateBusToUserLocation(Coordenada userLocation) async {
    print(
      '[MapBusRealtime] updateBusToUserLocation called - Mode: $_trackingMode',
    );

    if (_trackingMode != BusTrackingMode.USER_LOCATION) {
      print(
        '[MapBusRealtime] ⚠️ IGNORING updateBusToUserLocation - not in USER_LOCATION mode (current: $_trackingMode)',
      );
      return;
    }

    if (mapboxMap == null) {
      print(
        '[MapBusRealtime] ⚠️ IGNORING updateBusToUserLocation - mapboxMap is null',
      );
      return;
    }

    // No persistimos la ubicación aquí; el dibujo usa el parámetro directamente
    print(
      '[MapBusRealtime] ✅ Updating bus to user location: ${userLocation.latitud}, ${userLocation.longitud}',
    );

    // Renderizar icono de bus en la ubicación del usuario
    await _displayBusAtUserLocation(userLocation);

    // Actualizar línea hacia parada de destino
    if (_currentStopPosition != null) {
      await _updateBusApproachLineForActiveTrip(
        userLocation,
        _currentStopPosition!,
      );
    }
  }

  // DIFF: Método para renderizar bus en ubicación del usuario
  Future<void> _displayBusAtUserLocation(Coordenada userLocation) async {
    if (mapboxMap == null) return;

    try {
      final busFeature = {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [userLocation.longitud, userLocation.latitud],
        },
        'properties': {'type': 'user-bus', 'line': _currentBusLine ?? 'Bus'},
      };

      final sourceData = {
        'type': 'FeatureCollection',
        'features': [busFeature],
      };

      // Actualizar o crear fuente
      if (await mapboxMap!.style.styleSourceExists(USER_BUS_SOURCE_ID)) {
        final source =
            await mapboxMap!.style.getSource(USER_BUS_SOURCE_ID)
                as GeoJsonSource;
        await source.updateGeoJSON(jsonEncode(sourceData));
      } else {
        await mapboxMap!.style.addSource(
          GeoJsonSource(id: USER_BUS_SOURCE_ID, data: jsonEncode(sourceData)),
        );
        mapManager.registerSource(USER_BUS_SOURCE_ID);

        // Agregar capa del bus
        await mapboxMap!.style.addLayer(
          SymbolLayer(
            id: USER_BUS_LAYER_ID,
            sourceId: USER_BUS_SOURCE_ID,
            iconImage: MapIconsLoader.BUS_ICON_IMAGE_ID,
            iconAllowOverlap: true,
            iconSize: 0.8, // Slightly larger to indicate it's the user
            iconAnchor: IconAnchor.CENTER,
          ),
        );
        mapManager.registerLayer(USER_BUS_LAYER_ID);
      }

      print('[MapBusRealtime] Updated bus icon at user location');
    } catch (e) {
      print('[MapBusRealtime] Error displaying bus at user location: $e');
    }
  }

  // DIFF: Método para iniciar tracking de API
  Future<void> startApiTracking() async {
    print('[MapBusRealtime] Starting API tracking mode');
    _trackingMode = BusTrackingMode.API_REALTIME;

    // IMPORTANTE: Limpiar cualquier elemento de bus del usuario que pueda estar visible
    await _clearUserBusDisplay();

    print(
      '[MapBusRealtime] API tracking mode activated - user bus elements cleared',
    );
    // La lógica de tracking de API ya existe en los métodos actuales
  }

  // DIFF: Método para detener todos los tipos de tracking
  void stopAllTracking() {
    _trackingMode = BusTrackingMode.INACTIVE;
    _busTrackingTimer?.cancel();
    _busTrackingTimer = null;
    // Sin estado local que limpiar para ubicación de usuario

    // Limpiar elementos de usuario del mapa
    _clearUserBusDisplay();

    print('[MapBusRealtime] All tracking stopped');
  }

  // DIFF: Método para limpiar elementos de bus del usuario
  Future<void> _clearUserBusDisplay() async {
    if (mapboxMap == null) return;

    try {
      if (await mapboxMap!.style.styleLayerExists(USER_BUS_LAYER_ID)) {
        await mapboxMap!.style.removeStyleLayer(USER_BUS_LAYER_ID);
      }
      if (await mapboxMap!.style.styleSourceExists(USER_BUS_SOURCE_ID)) {
        await mapboxMap!.style.removeStyleSource(USER_BUS_SOURCE_ID);
      }
    } catch (e) {
      print('[MapBusRealtime] Error clearing user bus display: $e');
    }
  }

  /// Limpiar recursos y detener animaciones
  void dispose() {
    stopAllTracking();
    _stopTooltipFloatingAnimation();
  }
}

// DIFF: Enum para modos de tracking
enum BusTrackingMode { INACTIVE, API_REALTIME, USER_LOCATION }
