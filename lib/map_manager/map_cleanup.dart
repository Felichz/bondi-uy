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

    print("[MapCleanup] === LIMPIANDO TODOS LOS ELEMENTOS DEL MAPA ===");
    print("[MapCleanup] Llamado desde: ${StackTrace.current}");

    print("[MapCleanup] 🗑️ Limpiando rutas...");
    await clearRoute();
    print("[MapCleanup] 🗑️ Limpiando elementos de fase inicial...");
    await clearInitialPhaseElements();
    print("[MapCleanup] 🗑️ Limpiando ubicación del usuario...");
    await clearUserLocation();

    // Limpiar registros del manager
    print("[MapCleanup] 🗑️ Limpiando registros del manager...");
    mapManager.clearRegistrations();

    print("[MapCleanup] ✅ === TODOS LOS ELEMENTOS LIMPIADOS ===");
  }

  /// Limpiar elementos de ruta (unificado para preview y active trip)
  Future<void> clearRoute() async {
    if (mapboxMap == null) return;

    print("[MapCleanup] Clearing route elements");

    // Limpiar capas dinámicas con prefijos unificados
    await _clearLayersWithPrefix('route-walk-layer-');
    await _clearLayersWithPrefix('route-bus-layer-');
    await _clearLayersWithPrefix('route-wait-layer-');
    await _clearLayersWithPrefix('bus-boarding-layer-');
    await _clearLayersWithPrefix('bus-alighting-layer-');

    await _clearSourcesWithPrefix('route-walk-source-');
    await _clearSourcesWithPrefix('route-bus-source-');
    await _clearSourcesWithPrefix('route-wait-source-');
    await _clearSourcesWithPrefix('bus-boarding-stop-');
    await _clearSourcesWithPrefix('bus-alighting-stop-');

    // También limpiar elementos de buses en tiempo real
    await clearBusElements();

    print("[MapCleanup] Route elements cleared");
  }

  /// Limpiar elementos de preview de ruta (DEPRECATED - usar clearRoute)
  Future<void> clearRoutePreview() async {
    print("[MapCleanup] clearRoutePreview is deprecated, using clearRoute");
    await clearRoute();
  }

  /// Limpiar elementos de viaje activo (DEPRECATED - usar clearRoute)
  Future<void> clearActiveTrip() async {
    print("[MapCleanup] clearActiveTrip is deprecated, using clearRoute");
    await clearRoute();
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

  /// Limpiar elementos de buses en tiempo real (unificado para preview y active trip)
  Future<void> clearBusElements() async {
    if (mapboxMap == null) return;

    print("[MapCleanup] Clearing bus elements");

    // Limpiar elementos de buses con prefijos unificados
    await _clearLayersWithPrefix('bus-realtime-layer-');
    await _clearLayersWithPrefix('bus-tooltip-layer-');
    await _clearLayersWithPrefix('bus-approach-layer-');
    await _clearSourcesWithPrefix('bus-realtime-source-');
    await _clearSourcesWithPrefix('bus-approach-source-');

    print("[MapCleanup] Bus elements cleared");
  }

  /// Limpiar SOLO elementos de buses en tiempo real del preview
  /// Usado para evitar duplicación durante transición optimizada a active trip
  Future<void> clearPreviewBusElements() async {
    if (mapboxMap == null) return;

    print("[MapCleanup] Clearing preview bus elements to avoid duplication");

    // Con los prefijos unificados, simplemente limpiamos todos los elementos de buses
    // ya que no hay distinción entre preview y active trip
    await clearBusElements();

    print("[MapCleanup] Preview bus elements cleared successfully");
  }

  /// Limpiar ubicación del usuario
  Future<void> clearUserLocation() async {
    if (mapboxMap == null) return;

    print("[MapCleanup] === LIMPIANDO UBICACIÓN DEL USUARIO ===");
    print("[MapCleanup] Stack trace: ${StackTrace.current}");

    const String sourceId = 'user-location-source';
    const String layerId = 'user-location-layer';

    print("[MapCleanup] 🗑️ Eliminando capa '$layerId'...");
    await _removeLayerSafely(layerId);
    print("[MapCleanup] 🗑️ Eliminando fuente '$sourceId'...");
    await _removeSourceSafely(sourceId);

    print("[MapCleanup] ✅ === UBICACIÓN DEL USUARIO LIMPIADA ===");
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
      final layerExists = await mapboxMap!.style.styleLayerExists(layerId);

      if (layerExists) {
        await mapboxMap!.style.removeStyleLayer(layerId);
        print("[MapCleanup] Removed layer: $layerId");
      }
    } catch (e) {
      print("[MapCleanup] ❌ Error eliminando capa '$layerId': $e");
    }
  }

  /// Remover fuente de forma segura
  Future<void> _removeSourceSafely(String sourceId) async {
    if (mapboxMap == null) return;

    try {
      final sourceExists = await mapboxMap!.style.styleSourceExists(sourceId);

      if (sourceExists) {
        await mapboxMap!.style.removeStyleSource(sourceId);
        print("[MapCleanup] Removed source: $sourceId");
      }
    } catch (e) {
      print("[MapCleanup] ❌ Error eliminando fuente '$sourceId': $e");
    }
  }
}
