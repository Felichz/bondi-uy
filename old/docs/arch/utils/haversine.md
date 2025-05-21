# lib/utils/haversine.dart

Este archivo contiene una función de utilidad para calcular la distancia geodésica entre dos puntos en la superficie de la Tierra utilizando la fórmula de Haversine.

## Función:

- `calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2)`:
  - **Descripción**: Calcula la distancia en metros entre dos puntos geográficos especificados por sus coordenadas de latitud y longitud, aplicando la fórmula de Haversine. Esta fórmula es comúnmente utilizada para calcular distancias de "gran círculo" entre dos puntos en una esfera, lo cual es una buena aproximación para la distancia en la superficie de la Tierra.
  - **Entradas**: `lat1`, `lon1` (Latitud y longitud del primer punto en grados decimales), `lat2`, `lon2` (Latitud y longitud del segundo punto en grados decimales).
  - **Salidas**: Un `double` que representa la distancia calculada entre los dos puntos en metros.
  - **Efectos**: Realiza cálculos matemáticos utilizando trigonometría y constantes geográficas (radio de la Tierra). Convierte grados a radianes internamente para los cálculos trigonométricos.

## Dependencias:

- Utiliza la librería `dart:math` (importada como `math`) para funciones matemáticas como `sin`, `cos`, `atan2`, y `sqrt`, así como para la constante `math.pi`.

## Utilización:

- Esta función es utilizada por otras partes de la aplicación, particularmente en las utilidades geométricas (`geometry_utils.dart`), para calcular distancias entre puntos, como la distancia entre paradas de bus o la distancia a lo largo de un tramo de polilínea. Es fundamental para funcionalidades como encontrar puntos cercanos en formas o calcular la distancia recorrida.
