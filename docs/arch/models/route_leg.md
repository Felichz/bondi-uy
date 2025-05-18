# lib/models/route_leg.dart

Este archivo define el modelo de datos para un tramo individual (`RouteLeg`) dentro de un itinerario de viaje. Incluye detalles sobre el origen, destino, modo de transporte, duración, distancia, geometría, pasos (para caminatas) y lugares intermedios.

## `RouteLeg` (Clase Principal):

Representa un segmento único de un viaje, como caminar de A a B o tomar un bus de C a D.

### Responsabilidades:

- Almacenar toda la información detallada sobre un tramo específico del itinerario.
- Facilitar la deserialización de un tramo desde formato JSON.

### Propiedades:

- `mode`: Modo de transporte o tipo de tramo (String, ej. 'WALK', 'BUS', usando constantes de `LegModeConstants`).
- `startTime`: Marca de tiempo de inicio del tramo (int, en milisegundos).
- `endTime`: Marca de tiempo de fin del tramo (int, en milisegundos).
- `duration`: Duración del tramo (double, en segundos).
- `distance`: Distancia cubierta en el tramo (double, en metros).
- `from`: Punto de inicio del tramo (`LegEndpoint`).
- `to`: Punto de fin del tramo (`LegEndpoint`).
- `route`: Información de la ruta para tramos de transporte público (`LegRoute`, opcional).
- `trip`: Información específica del viaje (ej. identificador GTFS del vehículo) para tramos de transporte público (`LegTrip`, opcional).
- `legGeometry`: Geometría del tramo, generalmente como una cadena codificada de puntos (`LegGeometry`).
- `steps`: Lista de pasos individuales para tramos de caminata (`List<LegStep>`).
- `intermediatePlaces`: Lista de puntos intermedios o paradas por las que pasa el tramo (`List<IntermediatePlace>`).

### Entradas:

- El constructor requiere todas las propiedades principales (`mode`, `startTime`, `endTime`, `duration`, `distance`, `from`, `to`, `legGeometry`, `steps`). `route`, `trip` e `intermediatePlaces` son opcionales.
- El factory constructor `fromJson` toma un `Map<String, dynamic>` que contiene los datos del tramo en formato JSON.
- El método estático `listFromJson` toma una lista de objetos JSON y devuelve una lista de objetos `RouteLeg`.

### Salidas/Efectos:

- Provee una estructura de datos granular para analizar y visualizar cada parte de un itinerario.
- La información detallada (como steps y geometry) es crucial para la representación en el mapa y la navegación.

## Clases Anidadas:

Este archivo también define las siguientes clases de soporte:

### `LegEndpoint`:

- **Responsabilidades**: Representar el punto de inicio o fin de un tramo.
- **Propiedades**: `name` (String), `lon` (double), `lat` (double), `arrival` (DateTime, opcional), `departure` (DateTime, opcional), `stopId` (String, opcional, para paradas), `stopGtfsId` (String, opcional, para paradas GTFS).
- **Entradas**: Constructor, `fromJson` (Map<String, dynamic>).
- **Salidas/Efectos**: Provee detalles de ubicación y tiempo en los extremos de un tramo.

### `LegRoute`:

- **Responsabilidades**: Representar información de la ruta de transporte público (ej. nombre corto/largo).
- **Propiedades**: `gtfsId` (String, opcional), `longName` (String, opcional), `shortName` (String, opcional).
- **Entradas**: Constructor, `fromJson` (Map<String, dynamic>).
- **Salidas/Efectos**: Provee metadatos sobre la ruta de transporte utilizada en el tramo.

### `LegTrip`:

- **Responsabilidades**: Representar información específica del viaje de transporte público (ej. identificador de viaje).
- **Propiedades**: `gtfsId` (String, opcional), `shapeId` (String, opcional).
- **Entradas**: Constructor, `fromJson` (Map<String, dynamic>).
- **Salidas/Efectos**: Provee identificadores para el viaje específico, útil para rastreo o información en tiempo real.

### `LegGeometry`:

- **Responsabilidades**: Representar la forma geográfica del tramo.
- **Propiedades**: `points` (String, requerido, típicamente codificado), `length` (int, opcional).
- **Entradas**: Constructor, `fromJson` (Map<String, dynamic>).
- **Salidas/Efectos**: Provee los datos necesarios para dibujar el tramo en un mapa.

### `LegStep`:

- **Responsabilidades**: Representar un paso individual dentro de un tramo de caminata, incluyendo instrucciones de navegación.
- **Propiedades**: `distance` (double), `relativeDirection` (String, opcional), `streetName` (String, opcional), `absoluteDirection` (String, opcional), `stayOn` (bool, opcional), `area` (bool, opcional), `bogusName` (bool, opcional), `lon` (double), `lat` (double), `elevation` (String, opcional).
- **Entradas**: Constructor, `fromJson` (Map<String, dynamic>).
- **Salidas/Efectos**: Provee instrucciones detalladas para la navegación a pie.

### `IntermediatePlace`:

- **Responsabilidades**: Representar un punto intermedio por el que pasa el tramo, como una parada de autobús.
- **Propiedades**: `name` (String, opcional), `lon` (double), `lat` (double), `stopId` (String, opcional), `stopGtfsId` (String, opcional), `arrival` (DateTime, opcional), `departure` (DateTime, opcional).
- **Entradas**: Constructor, `fromJson` (Map<String, dynamic>).
- **Salidas/Efectos**: Provee detalles sobre los puntos de paso en el tramo, relevante para tramos de transporte público con múltiples paradas.
