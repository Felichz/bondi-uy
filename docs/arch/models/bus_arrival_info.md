# lib/models/bus_arrival_info.dart

Este archivo define un modelo de datos detallado para la información de llegada de un autobús.

## Responsabilidades:

- Representar toda la información relevante sobre la llegada de un autobús a una parada, incluyendo tiempo estimado, si es en tiempo real, información de la línea, posición, etc.
- Proveer métodos para convertir la información desde y hacia formato JSON (`fromJson`, `toJson`).
- Permitir la creación de copias del objeto con propiedades modificadas (`copyWith`).

## Propiedades:

- `minutesToArrival`: Minutos estimados para la llegada (int, requerido).
- `isReal`: Indica si la información es en tiempo real (bool, requerido).
- `lineShortName`: Nombre corto de la línea de autobús (String, requerido).
- `destination`: Destino del autobús (String, opcional).
- `position`: Posición geográfica actual del autobús (Position de mapbox_maps_flutter, opcional).
- `requestTime`: Momento en que se solicitó la información (DateTime, opcional).
- `arrivalTime`: Momento estimado de llegada (DateTime, opcional).
- `lineVariantCode`: Código de variante de la línea (String, opcional).
- `isClosestUpcoming`: Indica si es la llegada más próxima (bool, opcional).

## Entradas:

- El constructor principal requiere `minutesToArrival`, `isReal`, y `lineShortName`.
- El factory constructor `fromJson` toma un `Map<String, dynamic>` que generalmente proviene de una fuente externa (e.g., API).
- El método `copyWith` toma parámetros opcionales para sobreescribir las propiedades existentes.

## Salidas/Efectos:

- Provee una estructura de datos comprensiva para manejar información de llegadas de autobuses.
- El método `toJson` permite exportar los datos del objeto a formato JSON, útil para depuración, almacenamiento o comunicación.
- El método `copyWith` devuelve una nueva instancia de `BusArrivalInfo`.
