import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'map_manager.dart';

/// Módulo especializado en limpiar elementos del mapa
class MapCleanup {
  final MapboxMap? mapboxMap;
  final MapManager mapManager;

  MapCleanup(this.mapboxMap, this.mapManager);

  /// Limpiar todos los elementos del mapa
  Future<void> clearAll() async {
    if (mapboxMap == null) return;

    print("[MapCleanup] Clearing all map elements");

    await clearRoutePreview();
    await clearActiveTrip();
    await clearInitialPhaseElements();

    // Limpiar registros del manager
    mapManager.clearRegistrations();

    print("[MapCleanup] All map elements cleared");
  }

  /// Limpiar elementos de preview de ruta
  Future<void> clearRoutePreview() async {
    if (mapboxMap == null) return;

    print("[MapCleanup] Clearing route preview elements");

    // IDs de capas y fuentes de preview
    final previewLayerIds = [
      // Preview layers de route options
      'route-preview-walk-border',
      'route-preview-walk',
      'route-preview-bus-border',
      'route-preview-bus',
      'route-preview-wait',
      'route-preview-boarding',
      'route-preview-alighting',
      // Bus real-time layers de preview
      'preview-bus-realtime',
      'preview-bus-approach-line',
      'preview-bus-approach-line-border',
      'preview-bus-tooltip',
      // Animated arrow layers
      'preview-bus-stop-boarding-0',
      'preview-bus-stop-alighting-0',
      'preview-bus-stop-boarding-1',
      'preview-bus-stop-alighting-1',
      'preview-bus-stop-boarding-2',
      'preview-bus-stop-alighting-2',
      'preview-bus-stop-boarding-3',
      'preview-bus-stop-alighting-3',
      'preview-bus-stop-boarding-4',
      'preview-bus-stop-alighting-4',
    ];

    final previewSourceIds = [
      // Preview sources de route options
      'route-preview-walk-source',
      'route-preview-bus-source',
      'route-preview-wait-source',
      'route-preview-boarding-source',
      'route-preview-alighting-source',
      // Bus real-time sources de preview
      'preview-bus-realtime-source',
      'preview-bus-approach-line-source',
      'preview-bus-tooltip-source',
      // Animated arrow sources
      'preview-bus-stop-boarding-source-0',
      'preview-bus-stop-alighting-source-0',
      'preview-bus-stop-boarding-source-1',
      'preview-bus-stop-alighting-source-1',
      'preview-bus-stop-boarding-source-2',
      'preview-bus-stop-alighting-source-2',
      'preview-bus-stop-boarding-source-3',
      'preview-bus-stop-alighting-source-3',
      'preview-bus-stop-boarding-source-4',
      'preview-bus-stop-alighting-source-4',
    ];

    // También limpiar las capas dinámicas que usan prefijos
    await _clearLayersWithPrefix('preview-walk-layer-');
    await _clearLayersWithPrefix('preview-bus-layer-');
    await _clearLayersWithPrefix('preview-wait-layer-');
    await _clearLayersWithPrefix('preview-bus-realtime-layer-');
    await _clearLayersWithPrefix('preview-bus-tooltip-layer-');
    await _clearLayersWithPrefix('preview-bus-approach-layer-');
    await _clearLayersWithPrefix('bus-boarding-layer-');
    await _clearLayersWithPrefix('bus-alighting-layer-');

    await _clearSourcesWithPrefix('preview-walk-source-');
    await _clearSourcesWithPrefix('preview-bus-source-');
    await _clearSourcesWithPrefix('preview-wait-source-');
    await _clearSourcesWithPrefix('preview-bus-realtime-source-');
    await _clearSourcesWithPrefix('preview-bus-approach-source-');
    await _clearSourcesWithPrefix('bus-boarding-stop-');
    await _clearSourcesWithPrefix('bus-alighting-stop-');

    // Limpiar capas específicas
    for (String layerId in previewLayerIds) {
      await _removeLayerSafely(layerId);
    }

    // Limpiar fuentes específicas
    for (String sourceId in previewSourceIds) {
      await _removeSourceSafely(sourceId);
    }
  }

  /// Limpiar elementos de viaje activo
  Future<void> clearActiveTrip() async {
    if (mapboxMap == null) return;

    print("[MapCleanup] Clearing active trip elements");

    final activeTripLayerIds = [
      // Active trip layers
      'active-walk-layer-0',
      'active-walk-layer-0-shadow',
      'active-bus-layer-0',
      'active-bus-layer-0-shadow',
      'active-wait-layer-0',
      'user-location-layer',
      'incoming-bus-layer',
      'bus-tooltip-layer',
      'realtime-bus-layer',
      'bus-approach-line-layer',
      'bus-approach-line-border-layer',
    ];

    final activeTripSourceIds = [
      // Active trip sources
      'active-walk-source-0',
      'active-bus-source-0',
      'active-wait-source-0',
      'user-location-source',
      'incoming-bus-source',
      'bus-tooltip-source',
      'realtime-bus-source',
      'bus-approach-line-source',
    ];

    // Limpiar capas dinámicas con prefijos
    await _clearLayersWithPrefix('active-walk-layer-');
    await _clearLayersWithPrefix('active-bus-layer-');
    await _clearLayersWithPrefix('active-wait-layer-');
    await _clearLayersWithPrefix('active-bus-origin-layer-');
    await _clearLayersWithPrefix('active-bus-destination-layer-');

    await _clearSourcesWithPrefix('active-walk-source-');
    await _clearSourcesWithPrefix('active-bus-source-');
    await _clearSourcesWithPrefix('active-wait-source-');
    await _clearSourcesWithPrefix('active-bus-origin-');
    await _clearSourcesWithPrefix('active-bus-destination-');

    // Limpiar capas específicas
    for (String layerId in activeTripLayerIds) {
      await _removeLayerSafely(layerId);
    }

    // Limpiar fuentes específicas
    for (String sourceId in activeTripSourceIds) {
      await _removeSourceSafely(sourceId);
    }
  }

  /// Limpiar elementos de fase inicial
  Future<void> clearInitialPhaseElements() async {
    if (mapboxMap == null) return;

    print("[MapCleanup] Clearing initial phase elements");

    final initialPhaseLayerIds = ['stops-layer', 'highlighted-stops-layer'];

    final initialPhaseSourceIds = ['stops-source', 'highlighted-stops-source'];

    // Limpiar capas específicas
    for (String layerId in initialPhaseLayerIds) {
      await _removeLayerSafely(layerId);
    }

    // Limpiar fuentes específicas
    for (String sourceId in initialPhaseSourceIds) {
      await _removeSourceSafely(sourceId);
    }
  }

  /// Limpiar SOLO elementos de buses en tiempo real del preview
  /// Usado para evitar duplicación durante transición optimizada a active trip
  Future<void> clearPreviewBusElements() async {
    if (mapboxMap == null) return;

    print("[MapCleanup] Clearing preview bus elements to avoid duplication");

    // Limpiar SOLO los elementos que se duplican:
    // - Iconos de buses (preview-bus-realtime-layer-)
    // - Tooltips animados (preview-bus-tooltip-layer-)
    //
    // NO limpiar líneas verdes (preview-bus-approach-layer-) porque forman
    // parte de la visualización de la ruta y deben mantenerse

    // Limpiar iconos de buses en tiempo real del preview
    await _clearLayersWithPrefix('preview-bus-realtime-layer-');

    // Limpiar tooltips animados del preview
    await _clearLayersWithPrefix('preview-bus-tooltip-layer-');

    // Limpiar fuentes de iconos de buses (pero NO de approach lines)
    await _clearSourcesWithPrefix('preview-bus-realtime-source-');

    // También limpiar versiones que puedan usar sufijos como 'eta_X'
    await _clearLayersWithPrefix('preview-bus-realtime-layer-eta_');
    await _clearLayersWithPrefix('preview-bus-tooltip-layer-eta_');
    await _clearSourcesWithPrefix('preview-bus-realtime-source-eta_');

    print(
      "[MapCleanup] Preview bus elements cleared successfully (kept approach lines)",
    );
  }

  /// Limpiar capas que empiecen con un prefijo específico
  Future<void> _clearLayersWithPrefix(String prefix) async {
    if (mapboxMap == null) return;

    // Usar las capas registradas en el manager para mayor eficiencia
    final registeredLayers = mapManager.activeLayers;

    for (String layerId in registeredLayers) {
      if (layerId.startsWith(prefix)) {
        await _removeLayerSafely(layerId);
      }
    }

    // También intentar con índices comunes (0-10) por si hay capas no registradas
    for (int i = 0; i < 10; i++) {
      await _removeLayerSafely('$prefix$i');
      await _removeLayerSafely('$prefix$i-shadow');
      await _removeLayerSafely('$prefix$i-border');
    }
  }

  /// Limpiar fuentes que empiecen con un prefijo específico
  Future<void> _clearSourcesWithPrefix(String prefix) async {
    if (mapboxMap == null) return;

    // Usar las fuentes registradas en el manager para mayor eficiencia
    final registeredSources = mapManager.activeSources;

    for (String sourceId in registeredSources) {
      if (sourceId.startsWith(prefix)) {
        await _removeSourceSafely(sourceId);
      }
    }

    // También intentar con índices comunes (0-10) por si hay fuentes no registradas
    for (int i = 0; i < 10; i++) {
      await _removeSourceSafely('$prefix$i');
    }
  }

  /// Remover capa de forma segura
  Future<void> _removeLayerSafely(String layerId) async {
    if (mapboxMap == null) return;

    try {
      if (await mapboxMap!.style.styleLayerExists(layerId)) {
        await mapboxMap!.style.removeStyleLayer(layerId);
        print("[MapCleanup] Removed layer: $layerId");
      }
    } catch (e) {
      print("[MapCleanup] Error removing layer $layerId: $e");
    }
  }

  /// Remover fuente de forma segura
  Future<void> _removeSourceSafely(String sourceId) async {
    if (mapboxMap == null) return;

    try {
      if (await mapboxMap!.style.styleSourceExists(sourceId)) {
        await mapboxMap!.style.removeStyleSource(sourceId);
        print("[MapCleanup] Removed source: $sourceId");
      }
    } catch (e) {
      print("[MapCleanup] Error removing source $sourceId: $e");
    }
  }
}
