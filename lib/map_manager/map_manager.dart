import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import 'map_route_renderer.dart';
import 'map_bus_realtime.dart';
import 'map_icons_loader.dart';
import 'map_camera_controller.dart';
import 'map_cleanup.dart';

/// Módulo unificado para el manejo completo del estado del mapa
/// Centraliza toda la lógica de renderizado, animaciones y estado
class MapManager {
  final MapboxMap? mapboxMap;

  // Submódulos especializados
  late final MapRouteRenderer _routeRenderer;
  late final MapBusRealtime _busRealtime;
  late final MapIconsLoader _iconsLoader;
  late final MapCameraController _cameraController;
  late final MapCleanup _cleanup;

  // Estado interno
  bool _isInitialized = false;
  String? _currentPhase;
  List<String> _activeSources = [];
  List<String> _activeLayers = [];

  // Trackear la opción actualmente en preview para optimizar transiciones
  String? _currentPreviewOptionId;

  MapManager(this.mapboxMap) {
    _routeRenderer = MapRouteRenderer(mapboxMap, this);
    _busRealtime = MapBusRealtime(mapboxMap, this);
    _iconsLoader = MapIconsLoader(mapboxMap, this);
    _cameraController = MapCameraController(mapboxMap, this);
    _cleanup = MapCleanup(mapboxMap, this);
  }

  /// Inicializar el manager (cargar iconos, configurar mapa)
  Future<void> initialize() async {
    if (_isInitialized || mapboxMap == null) return;

    print("[MapManager] Initializing map manager");

    try {
      await _iconsLoader.loadAllIcons();
      await _hideCityLabels();
      _isInitialized = true;
      print("[MapManager] Map manager initialized successfully");
    } catch (e) {
      print("[MapManager] Error initializing: $e");
      rethrow;
    }
  }

  /// Mostrar preview de ruta (para RouteOptionsOverlay)
  Future<void> showRoutePreview(OpcionDeRutaMostrable route) async {
    if (!_isInitialized) await initialize();

    print("[MapManager] Showing route preview for: ${route.idOpcion}");
    print("[MapManager] Current preview option: $_currentPreviewOptionId");
    print("[MapManager] Current phase: $_currentPhase");

    // Solo limpiar si es una opción diferente a la actual
    bool needsRedraw = false;
    if (_currentPreviewOptionId != route.idOpcion) {
      print(
        "[MapManager] Different option ($_currentPreviewOptionId → ${route.idOpcion}), clearing previous preview",
      );
      await _cleanup.clearRoutePreview();
      needsRedraw = true;
    } else {
      print(
        "[MapManager] Same option (${route.idOpcion}), keeping existing preview",
      );
    }

    _currentPhase = 'route_preview';
    _currentPreviewOptionId = route.idOpcion;

    // Renderizar nueva ruta (solo si cambió o no hay capas)
    if (needsRedraw || _activeLayers.isEmpty) {
      print(
        "[MapManager] Rendering route (needsRedraw: $needsRedraw, activeLayers: ${_activeLayers.length})",
      );
      await _routeRenderer.renderRoutePreview(route);

      // Mostrar buses en tiempo real
      await _busRealtime.displayRealtimeBusesForPreview(route);
    } else {
      print("[MapManager] Skipping route rendering (already displayed)");
    }

    // Ajustar zoom
    await _cameraController.zoomToRoutePreview(route);
  }

  /// Mostrar viaje activo (para ActiveTripOverlay)
  Future<void> showActiveTrip(EstadoFaseViajeActivo activeTripState) async {
    if (!_isInitialized) await initialize();

    print("[MapManager] Showing active trip");
    print("[MapManager] Current phase: $_currentPhase");

    // OPTIMIZACIÓN: Si venimos del preview, no limpiar (siempre es la misma opción)
    final isTransitionFromPreview = _currentPhase == 'route_preview';

    if (isTransitionFromPreview) {
      print(
        "[MapManager] ✅ OPTIMIZED TRANSITION: Keeping preview elements (route_preview → active_trip)",
      );
      // Solo convertir de preview a active trip sin limpiar
      await _convertPreviewToActiveTrip(activeTripState);
    } else {
      print(
        "[MapManager] 🔄 FULL REDRAW: Coming from different phase ($_currentPhase → active_trip)",
      );

      // Limpiar elementos anteriores
      await _cleanup.clearAll();

      // Renderizar ruta activa desde cero
      await _routeRenderer.renderActiveTrip(activeTripState.tramosDelViaje);

      // Configurar tracking inicial
      await _busRealtime.initializeActiveTripTracking(activeTripState);
    }

    _currentPhase = 'active_trip';
    _currentPreviewOptionId = null; // Limpiar preview tracking
  }

  /// Convertir elementos de preview a active trip sin limpiar
  Future<void> _convertPreviewToActiveTrip(
    EstadoFaseViajeActivo activeTripState,
  ) async {
    print("[MapManager] Converting preview elements to active trip style");

    try {
      // 1. Actualizar estilos de líneas y elementos existentes para active trip
      await _routeRenderer.convertPreviewStylesToActiveTrip(
        activeTripState.tramosDelViaje,
      );

      // 2. Configurar tracking de bus manteniendo los elementos visuales existentes
      await _busRealtime.initializeActiveTripTracking(activeTripState);

      // 3. Ajustar zoom para active trip
      await _cameraController.zoomToActiveTrip(activeTripState.tramosDelViaje);

      print("[MapManager] Successfully converted preview to active trip");
    } catch (e) {
      print("[MapManager] Error converting preview to active trip: $e");
      // Si falla la conversión, hacer fallback a cleanup completo
      print("[MapManager] Falling back to full cleanup and redraw");
      await _cleanup.clearAll();
      await _routeRenderer.renderActiveTrip(activeTripState.tramosDelViaje);
      await _busRealtime.initializeActiveTripTracking(activeTripState);
    }
  }

  /// Actualizar tramo actual en viaje activo
  Future<void> updateCurrentLeg(
    int legIndex,
    List<TramoViajeMostrable> tramos,
  ) async {
    if (_currentPhase != 'active_trip') return;

    print("[MapManager] Updating current leg to: $legIndex");

    await _routeRenderer.highlightCurrentLeg(legIndex, tramos);
    await _cameraController.zoomToCurrentLeg(legIndex, tramos);
    await _busRealtime.updateBusTrackingForLeg(legIndex, tramos);
  }

  /// Actualizar posición de bus en tiempo real
  Future<void> updateBusPosition(
    Coordenada position,
    int etaMinutes,
    bool isRealTime,
  ) async {
    await _busRealtime.updateBusPosition(position, etaMinutes, isRealTime);
  }

  /// Mostrar fase inicial (para InitialPhaseOverlay)
  Future<void> showInitialPhase() async {
    if (!_isInitialized) await initialize();

    print("[MapManager] Showing initial phase");

    await _cleanup.clearAll();
    _currentPhase = 'initial';
    _currentPreviewOptionId = null;

    // TODO: Implementar renderizado de paradas de bus para fase inicial
    // await _routeRenderer.renderBusStops();
  }

  /// Limpiar todo el contenido del mapa
  Future<void> clearAll() async {
    print("[MapManager] Clearing all map content");
    await _cleanup.clearAll();
    _currentPhase = null;
    _currentPreviewOptionId = null;
  }

  /// Registrar fuente activa para tracking
  void registerSource(String sourceId) {
    if (!_activeSources.contains(sourceId)) {
      _activeSources.add(sourceId);
    }
  }

  /// Registrar capa activa para tracking
  void registerLayer(String layerId) {
    if (!_activeLayers.contains(layerId)) {
      _activeLayers.add(layerId);
    }
  }

  /// Obtener todas las fuentes activas
  List<String> get activeSources => List.unmodifiable(_activeSources);

  /// Obtener todas las capas activas
  List<String> get activeLayers => List.unmodifiable(_activeLayers);

  /// Limpiar registros de fuentes y capas
  void clearRegistrations() {
    _activeSources.clear();
    _activeLayers.clear();
  }

  /// Ocultar etiquetas de ciudad que interfieren
  Future<void> _hideCityLabels() async {
    if (mapboxMap == null) return;

    try {
      final labelLayerIds = [
        'settlement-major-label',
        'settlement-minor-label',
        'state-label',
        'country-label',
        'place-city-large-s',
        'place-city-medium-s',
        'place-city-small-s',
        'admin-1-boundary-label',
        'admin-0-boundary-label',
      ];

      for (String layerId in labelLayerIds) {
        try {
          if (await mapboxMap!.style.styleLayerExists(layerId)) {
            await mapboxMap!.style.setStyleLayerProperty(
              layerId,
              'visibility',
              'none',
            );
          }
        } catch (e) {
          // Continuar con el siguiente si este falla
        }
      }
    } catch (e) {
      print("[MapManager] Error hiding city labels: $e");
    }
  }

  /// Verificar si el manager está inicializado
  bool get isInitialized => _isInitialized;

  /// Obtener la fase actual
  String? get currentPhase => _currentPhase;

  /// Acceso directo a submódulos para casos específicos
  MapRouteRenderer get routeRenderer => _routeRenderer;
  MapBusRealtime get busRealtime => _busRealtime;
  MapIconsLoader get iconsLoader => _iconsLoader;
  MapCameraController get cameraController => _cameraController;
  MapCleanup get cleanup => _cleanup;
}
