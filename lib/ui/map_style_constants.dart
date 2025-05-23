/// Constantes de estilos para elementos de mapas basados en el código original
/// Mantiene consistencia visual entre RouteOptionsOverlay y ActiveTripOverlay

import 'package:flutter/material.dart';

class MapStyleConstants {
  // === ESTILOS BASE (para preview de rutas) ===
  // EXACTOS del código viejo - old/lib/services/mapbox_service.dart

  // Estilos para WALK (caminar) - líneas SÓLIDAS azul claro (NO dashed!)
  static const Map<String, dynamic> WALK_LINE_PROPERTIES = {
    'line-color':
        0xFF448AFF, // Colors.blueAccent.value - EXACTO del código viejo
    'line-width': 4.0, // AUMENTADO de 3.0 a 4.0 para más visibilidad
    'line-opacity': 0.9,
    'line-join': 'round',
    'line-cap': 'round',
    // NO line-dasharray - líneas sólidas como en el código viejo
  };

  // Estilos para BUS - líneas sólidas naranja (deepOrangeAccent)
  static const Map<String, dynamic> BUS_LINE_PROPERTIES = {
    'line-color':
        0xFFFF5722, // Colors.deepOrangeAccent.value - EXACTO del código viejo
    'line-width': 5.0, // AUMENTADO de 4.0 a 5.0 para más visibilidad
    'line-opacity': 0.9,
    'line-join': 'round',
    'line-cap': 'round',
  };

  // Estilos para WAIT - círculos naranjas
  static const Map<String, dynamic> WAIT_CIRCLE_PROPERTIES = {
    'circle-color': 0xFFFFA500, // Colors.orange.value - EXACTO del código viejo
    'circle-radius': 8.0,
    'circle-stroke-width': 2.0,
    'circle-stroke-color':
        0xFFFFFFFF, // Colors.white.value - EXACTO del código viejo
    'circle-opacity': 0.9,
  };

  // === ESTADOS DE HIGHLIGHTING (para viaje activo) ===
  // Basados en updateMapRouteHighlight del código viejo

  // Estados normales/transparentados (cuando otro tramo está highlighted)
  static const Map<String, dynamic> DIMMED_WALK_PROPERTIES = {
    'line-color': 0xFF448AFF, // Colors.blueAccent.value
    'line-width': 4.0, // Mantiene grosor original
    'line-opacity': 0.35, // Transparentado
    'line-join': 'round',
    'line-cap': 'round',
    // NO line-dasharray - sólidas
  };

  static const Map<String, dynamic> DIMMED_BUS_PROPERTIES = {
    'line-color': 0xFFFF5722, // Colors.deepOrangeAccent.value
    'line-width': 5.0, // Mantiene grosor original
    'line-opacity': 0.35, // Transparentado
    'line-join': 'round',
    'line-cap': 'round',
  };

  static const Map<String, dynamic> DIMMED_WAIT_PROPERTIES = {
    'circle-color': 0xFFFFA500, // Colors.orange.value
    'circle-radius': 8.0,
    'circle-opacity': 0.35, // Transparentado
    'circle-stroke-color': 0xFFFFFFFF, // Colors.white.value
    'circle-stroke-width': 2.0,
  };

  // Estados destacados/highlighted (tramo activo)
  // Del código viejo: mainWidth = isSelected ? 6.0 : 3.0;
  static const Map<String, dynamic> HIGHLIGHTED_WALK_PROPERTIES = {
    'line-color': 0xFF448AFF, // Colors.blueAccent.value
    'line-width': 7.0, // Más grueso cuando highlighted
    'line-opacity': 0.9, // Opaco total
    'line-join': 'round',
    'line-cap': 'round',
    // NO line-dasharray - sólidas
  };

  static const Map<String, dynamic> HIGHLIGHTED_BUS_PROPERTIES = {
    'line-color': 0xFFFF5722, // Colors.deepOrangeAccent.value
    'line-width': 8.0, // Más grueso cuando highlighted
    'line-opacity': 0.9, // Opaco total
    'line-join': 'round',
    'line-cap': 'round',
  };

  static const Map<String, dynamic> HIGHLIGHTED_WAIT_PROPERTIES = {
    'circle-color': 0xFFFFA500, // Colors.orange.value
    'circle-radius': 10.0,
    'circle-opacity': 0.9, // Opaco total
    'circle-stroke-color': 0xFFFFFFFF, // Colors.white.value
    'circle-stroke-width': 2.5,
  };

  // Estados de borde para highlighting
  static const Map<String, dynamic> DIMMED_BORDER_PROPERTIES = {
    'line-color': 0xFF000000, // Negro sólido
    'line-width': 8.0, // Borde para líneas normales
    'line-opacity': 0.4, // Menos visible cuando dimmed
    'line-join': 'round',
    'line-cap': 'round',
  };

  static const Map<String, dynamic> HIGHLIGHTED_BORDER_PROPERTIES = {
    'line-color': 0xFF000000, // Negro sólido
    'line-width': 12.0, // Borde más grueso para highlighting
    'line-opacity': 1.0, // Completamente visible
    'line-join': 'round',
    'line-cap': 'round',
  };

  // === ESTILOS ESPECIALES ===

  // Línea verde para bus en aproximación (incoming bus segment)
  static const Map<String, dynamic> INCOMING_BUS_PROPERTIES = {
    'line-color': 0xFF4CAF50, // Colors.green.value - EXACTO del código viejo
    'line-width': 6.0,
    'line-opacity': 0.9,
    'line-join': 'round',
    'line-cap': 'round',
  };

  static const Map<String, dynamic> INCOMING_BUS_SHADOW_PROPERTIES = {
    'line-color':
        0x66000000, // Colors.black.withOpacity(0.4) - borde negro opaco
    'line-width': 8.0,
    'line-opacity': 0.4, // Opacidad para simular conOpacity(0.4)
    'line-join': 'round',
    'line-cap': 'round',
  };

  // Marcadores de origen y destino
  static const Map<String, dynamic> ORIGIN_MARKER_PROPERTIES = {
    'circle-color': 0xFF4CAF50, // Colors.green.value para origen
    'circle-radius': 10.0,
    'circle-stroke-color': 0xFFFFFFFF, // Colors.white.value border
    'circle-stroke-width': 3.0,
    'circle-opacity': 0.9,
  };

  static const Map<String, dynamic> DESTINATION_MARKER_PROPERTIES = {
    'circle-color': 0xFFF44336, // Colors.red.value para destino
    'circle-radius': 10.0,
    'circle-stroke-color': 0xFFFFFFFF, // Colors.white.value border
    'circle-stroke-width': 3.0,
    'circle-opacity': 0.9,
  };

  // Paradas de bus
  static const Map<String, dynamic> BUS_STOP_MARKER_PROPERTIES = {
    'circle-color': 0xFF2196F3, // Colors.blue.value para paradas
    'circle-radius': 8.0,
    'circle-stroke-color': 0xFFFFFFFF, // Colors.white.value border
    'circle-stroke-width': 2.0,
    'circle-opacity': 0.9,
  };

  // Líneas de borde (border layers) - líneas más gruesas y opacas por debajo para crear efecto de borde
  static const Map<String, dynamic> BORDER_PROPERTIES = {
    'line-color': 0xFF000000, // Negro completamente opaco para borde sólido
    'line-width': 8.0, // Más gruesa que la línea principal
    'line-opacity': 1.0, // Completamente opaca para borde sólido
    'line-join': 'round',
    'line-cap': 'round',
  };

  // === MÉTODOS HELPER ===

  /// Obtiene propiedades para un tipo de tramo en estado normal (para preview)
  static Map<String, dynamic> getPropertiesForSegmentType(String segmentType) {
    switch (segmentType.toUpperCase()) {
      case 'WALK':
        return WALK_LINE_PROPERTIES;
      case 'BUS':
        return BUS_LINE_PROPERTIES;
      case 'WAIT':
        return WAIT_CIRCLE_PROPERTIES;
      default:
        return WALK_LINE_PROPERTIES;
    }
  }

  /// Obtiene propiedades para un tipo de tramo según su estado de highlighting
  static Map<String, dynamic> getPropertiesForHighlightState(
    String segmentType,
    bool isHighlighted,
  ) {
    final type = segmentType.toUpperCase();

    if (isHighlighted) {
      switch (type) {
        case 'WALK':
          return HIGHLIGHTED_WALK_PROPERTIES;
        case 'BUS':
          return HIGHLIGHTED_BUS_PROPERTIES;
        case 'WAIT':
          return HIGHLIGHTED_WAIT_PROPERTIES;
        default:
          return HIGHLIGHTED_WALK_PROPERTIES;
      }
    } else {
      switch (type) {
        case 'WALK':
          return DIMMED_WALK_PROPERTIES;
        case 'BUS':
          return DIMMED_BUS_PROPERTIES;
        case 'WAIT':
          return DIMMED_WAIT_PROPERTIES;
        default:
          return DIMMED_WALK_PROPERTIES;
      }
    }
  }

  /// Obtiene propiedades de borde según el estado de highlighting
  static Map<String, dynamic> getBorderPropertiesForHighlightState(
    bool isHighlighted,
  ) {
    return isHighlighted
        ? HIGHLIGHTED_BORDER_PROPERTIES
        : DIMMED_BORDER_PROPERTIES;
  }
}
