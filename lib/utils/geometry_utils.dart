import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../backend/contrato_ui/app_ui_state.dart'; // Para Coordenada

// Cache global para las geometrías de shapes
Map<String, List<Coordenada>> _shapeGeometries = {};
bool _shapesLoaded = false;

// Función para cargar las geometrías completas desde shapes.geojson
Future<void> loadShapeGeometries() async {
  if (_shapesLoaded) return;

  try {
    print(
      "[GeometryUtils] Cargando geometrías de shapes desde assets/data/shapes.geojson",
    );
    final String geoJsonString = await rootBundle.loadString(
      'assets/data/shapes.geojson',
    );
    final Map<String, dynamic> geoJsonData = json.decode(geoJsonString);
    final List<dynamic> features = geoJsonData['features'] ?? [];

    for (var feature in features) {
      final properties = feature['properties'];
      final geometry = feature['geometry'];

      if (properties != null && geometry != null) {
        final String? shapeId = properties['shape_id'] as String?;

        if (shapeId != null &&
            shapeId.isNotEmpty &&
            geometry['type'] == 'LineString') {
          final List<dynamic> coordinates = geometry['coordinates'] ?? [];
          List<Coordenada> coordenadas =
              coordinates
                  .map(
                    (coord) => Coordenada(
                      latitud: (coord[1] as num).toDouble(),
                      longitud: (coord[0] as num).toDouble(),
                    ),
                  )
                  .toList();

          if (coordenadas.length >= 2) {
            _shapeGeometries[shapeId] = coordenadas;
          }
        }
      }
    }

    _shapesLoaded = true;
    print(
      "[GeometryUtils] Cargadas ${_shapeGeometries.length} geometrías de shapes",
    );
  } catch (e, s) {
    print("[GeometryUtils] Error cargando shapes.geojson: $e\n$s");
  }
}

// Función para obtener la geometría completa de una línea por shapeId
List<Coordenada>? getFullShapeGeometry(String? shapeId) {
  if (shapeId == null || shapeId.isEmpty) return null;

  // Normalizar shapeId si contiene ':'
  String normalizedShapeId = shapeId;
  if (shapeId.contains(':')) {
    normalizedShapeId = shapeId.split(':').last;
  }

  return _shapeGeometries[normalizedShapeId];
}

// Función para calcular distancia Haversine entre dos puntos
double calculateHaversineDistance(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const double R = 6371000; // Radio de la Tierra en metros

  double lat1Rad = math.pi * lat1 / 180;
  double lon1Rad = math.pi * lon1 / 180;
  double lat2Rad = math.pi * lat2 / 180;
  double lon2Rad = math.pi * lon2 / 180;

  double dLat = lat2Rad - lat1Rad;
  double dLon = lon2Rad - lon1Rad;

  double a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1Rad) *
          math.cos(lat2Rad) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

  return R * c; // Distancia en metros
}

// Encuentra el índice del punto más cercano en una lista de coordenadas
int findClosestPointIndexOnShape(
  List<Coordenada> shapePoints,
  Coordenada targetPoint,
) {
  if (shapePoints.isEmpty) return -1;

  int closestIndex = -1;
  double minDistance = double.infinity;

  for (int i = 0; i < shapePoints.length; i++) {
    final shapePoint = shapePoints[i];

    final distance = calculateHaversineDistance(
      targetPoint.latitud,
      targetPoint.longitud,
      shapePoint.latitud,
      shapePoint.longitud,
    );

    if (distance < minDistance) {
      minDistance = distance;
      closestIndex = i;
    }
  }

  return closestIndex;
}

// Calcula un segmento de la geometría entre dos índices
List<Coordenada> getGeometrySegment(
  List<Coordenada> fullGeometry,
  int startIndex,
  int endIndex,
) {
  if (fullGeometry.isEmpty ||
      startIndex < 0 ||
      endIndex < 0 ||
      startIndex >= fullGeometry.length ||
      endIndex >= fullGeometry.length) {
    return [];
  }

  // Usar min/max para garantizar orden correcto, igual que en el código viejo
  final start = math.min(startIndex, endIndex);
  final end = math.max(startIndex, endIndex);

  return fullGeometry.sublist(start, end + 1);
}

// Calcula la distancia mínima de un punto a un segmento de línea
double distanceToLineSegment(
  Coordenada point,
  Coordenada lineStart,
  Coordenada lineEnd,
) {
  // Convertir coordenadas a radianes para cálculos precisos
  final pointLat = point.latitud * math.pi / 180;
  final pointLon = point.longitud * math.pi / 180;
  final startLat = lineStart.latitud * math.pi / 180;
  final startLon = lineStart.longitud * math.pi / 180;
  final endLat = lineEnd.latitud * math.pi / 180;
  final endLon = lineEnd.longitud * math.pi / 180;

  // Calcular vectores
  final A = pointLat - startLat;
  final B = pointLon - startLon;
  final C = endLat - startLat;
  final D = endLon - startLon;

  final dot = A * C + B * D;
  final lenSq = C * C + D * D;

  Coordenada closestPoint;

  if (lenSq == 0) {
    // El segmento es un punto
    closestPoint = lineStart;
  } else {
    final param = dot / lenSq;

    if (param < 0) {
      closestPoint = lineStart;
    } else if (param > 1) {
      closestPoint = lineEnd;
    } else {
      closestPoint = Coordenada(
        latitud:
            lineStart.latitud + param * (endLat - startLat) * 180 / math.pi,
        longitud:
            lineStart.longitud + param * (endLon - startLon) * 180 / math.pi,
      );
    }
  }

  return calculateHaversineDistance(
    point.latitud,
    point.longitud,
    closestPoint.latitud,
    closestPoint.longitud,
  );
}
