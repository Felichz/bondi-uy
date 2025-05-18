# lib/utils/geometry_utils.dart

Este archivo contiene funciones de utilidad relacionadas con cálculos geométricos y geográficos, principalmente utilizadas para procesar y manipular datos de polilíneas y coordenadas en el contexto de la visualización de rutas y el seguimiento de vehículos.

## Funciones:

- `findClosestPointIndexOnShape(List<Position> shapePoints, Point_dart targetPoint)`:

  - **Descripción**: Encuentra el índice del punto más cercano a un `targetPoint` dado dentro de una lista de puntos que definen una forma (polilínea), calculando la distancia utilizando la fórmula de Haversine.
  - **Entradas**: `shapePoints` (Lista de `Position` que forman la polilínea), `targetPoint` (Un objeto `Point_dart` con las coordenadas del punto objetivo).
  - **Salidas**: Un `int` que representa el índice (base 0) del punto más cercano en `shapePoints`, o -1 si la lista `shapePoints` está vacía.
  - **Efectos**: Realiza un cálculo iterativo de distancias Haversine.

- `calculateBoundsForPositions(List<Position> positions)`:

  - **Descripción**: Calcula los límites geográficos mínimos y máximos (`CoordinateBounds`) que engloban una lista de `Position`s. Ajusta los límites mínimamente si todos los puntos coinciden para asegurar un área visible.
  - **Entradas**: `positions` (Lista de `Position`).
  - **Salidas**: Un `Future<CoordinateBounds?>` que resuelve a los límites calculados, o `null` si la lista de posiciones está vacía.
  - **Efectos**: Itera sobre la lista de posiciones para encontrar los valores mínimos y máximos de latitud y longitud.

- `calculateBoundsForLeg(List<RouteLeg> currentRouteLegs, int legIndex, {Position? additionalPoint})`:

  - **Descripción**: Calcula los límites geográficos (`CoordinateBounds`) necesarios para mostrar un tramo de ruta específico (`RouteLeg`) en el mapa. Decodifica la polilínea del tramo y opcionalmente incluye un punto adicional (ej. la posición de un bus en tiempo real) en el cálculo de los límites. Utiliza `calculateBoundsForPositions` internamente.
  - **Entradas**: `currentRouteLegs` (Lista de `RouteLeg`s), `legIndex` (Índice del tramo a calcular los límites), `additionalPoint` (Opcional, una `Position` a incluir en los límites).
  - **Salidas**: Un `Future<CoordinateBounds?>` que resuelve a los límites calculados para el tramo y el punto adicional (si se proporcionó), o `null` si el índice del tramo es inválido o el tramo no contiene información de posición.
  - **Efectos**: Decodifica polilíneas. Llama a `calculateBoundsForPositions`.

- `calculateBoundsForRoute(List<RouteLeg> legs)`:

  - **Descripción**: Calcula los límites geográficos (`CoordinateBounds`) necesarios para mostrar una ruta completa compuesta por una lista de `RouteLeg`s. Itera sobre todos los tramos, decodifica sus polilíneas (o usa los puntos de inicio/fin si no hay polilínea) y calcula los límites mínimos y máximos que engloban todos los puntos de la ruta. Utiliza `calculateBoundsForPositions` internamente.
  - **Entradas**: `legs` (Lista de `RouteLeg`s).
  - **Salidas**: Un `Future<CoordinateBounds?>` que resuelve a los límites calculados para la ruta completa, o `null` si la lista de tramos está vacía.
  - **Efectos**: Itera sobre los tramos. Decodifica polilíneas. Llama a `calculateBoundsForPositions`.

- `getDistanceAlongPolylineSegment(List<Position> polyline, int startIndex, int endIndex)`:

  - **Descripción**: Calcula la distancia total a lo largo de un segmento de una polilínea, definido por un índice de inicio y un índice de fin. Utiliza la fórmula de Haversine para sumar las distancias entre puntos consecutivos dentro del segmento.
  - **Entradas**: `polyline` (Lista de `Position` que forman la polilínea completa), `startIndex` (Índice del punto de inicio del segmento), `endIndex` (Índice del punto de fin del segmento).
  - **Salidas**: Un `double` que representa la distancia total en metros del segmento de la polilínea.
  - **Efectos**: Itera sobre los puntos del segmento y suma las distancias Haversine.

- `getPointAtDistanceAlongPolyline(List<Position> polyline, int startIndexOnPolyline, double distanceToTravel)`:
  - **Descripción**: Encuentra una `Position` específica a lo largo de una polilínea, comenzando desde un `startIndexOnPolyline` dado y avanzando una `distanceToTravel` especificada en metros. Si la distancia excede la longitud restante de la polilínea desde el índice de inicio, devuelve el último punto. Realiza interpolación lineal entre los puntos de la polilínea.
  - **Entradas**: `polyline` (Lista de `Position` que forman la polilínea completa), `startIndexOnPolyline` (Índice del punto en la polilínea desde donde comenzar a medir), `distanceToTravel` (Distancia en metros a avanzar).
  - **Salidas**: Una `Position` que representa el punto en la polilínea a la distancia especificada del punto de inicio del segmento.
  - **Efectos**: Itera sobre los segmentos de la polilínea, calcula distancias Haversine, realiza interpolación.

## Dependencias:

- Depende de `mapbox_maps_flutter` para el tipo `Position` y `CoordinateBounds`.
- Depende del modelo `Point_dart` para representar puntos.
- Depende de la función `calculateHaversineDistance` definida en `haversine.dart`.
- Utiliza `flutter_polyline_points` para decodificar polilíneas.
- Utiliza `dart:math` para `math.min`/`max` (aunque no directamente visible en los snippets proporcionados, es común en utilidades geométricas).
- Depende del modelo `RouteLeg`.

## Utilización:

- Estas funciones son utilizadas por controladores (como `MapZoomController`, `BusTrackingController`) y servicios (`MapboxService`) para realizar cálculos necesarios para la visualización precisa y el control del mapa.
