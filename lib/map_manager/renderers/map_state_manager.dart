/// Gestión de estado del mapa (fuentes y capas activas)
///
/// Encapsula el tracking de fuentes y capas de Mapbox para mantener
/// MapManager enfocado en lógica de alto nivel.

class MapStateManager {
  final List<String> _activeSources = [];
  final List<String> _activeLayers = [];

  /// Registra una fuente activa
  void registerSource(String sourceId) {
    if (!_activeSources.contains(sourceId)) {
      _activeSources.add(sourceId);
    }
  }

  /// Registra una capa activa
  void registerLayer(String layerId) {
    if (!_activeLayers.contains(layerId)) {
      _activeLayers.add(layerId);
    }
  }

  /// Desregistra una fuente
  void unregisterSource(String sourceId) {
    _activeSources.remove(sourceId);
  }

  /// Desregistra una capa
  void unregisterLayer(String layerId) {
    _activeLayers.remove(layerId);
  }

  /// Obtiene lista inmutable de fuentes activas
  List<String> get activeSources => List.unmodifiable(_activeSources);

  /// Obtiene lista inmutable de capas activas
  List<String> get activeLayers => List.unmodifiable(_activeLayers);

  /// Limpia todos los registros
  void clearAll() {
    _activeSources.clear();
    _activeLayers.clear();
  }

  /// Verifica si una fuente está registrada
  bool hasSource(String sourceId) {
    return _activeSources.contains(sourceId);
  }

  /// Verifica si una capa está registrada
  bool hasLayer(String layerId) {
    return _activeLayers.contains(layerId);
  }

  /// Obtiene el conteo de elementos activos
  int get activeCount => _activeSources.length + _activeLayers.length;

  /// Verifica si hay elementos activos
  bool get hasActiveElements => activeCount > 0;
}
