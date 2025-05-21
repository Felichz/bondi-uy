# lib/models/bus_realtime.dart

Este archivo define el modelo de datos para la información de llegada de autobuses en tiempo real.

## Responsabilidades:

- Representar la información en tiempo real de un autobús, incluyendo su línea, destino y tiempo estimado de llegada.
- Proveer un método `fromJson` para deserializar datos JSON en un objeto `BusRealtime`.

## Propiedades:

- `line`: Número o identificador de la línea de autobús (String).
- `destination`: Destino del autobús (String).
- `minutesToArrival`: Minutos estimados para la llegada del autobús (int).

## Entradas:

- El constructor requiere `line`, `destination`, y `minutesToArrival`.
- El factory constructor `fromJson` toma un `Map<String, dynamic>` que contiene los datos en formato JSON.

## Salidas/Efectos:

- Provee una estructura de datos para manejar la información de llegadas de autobuses en tiempo real.
- Permite la creación de objetos `BusRealtime` a partir de respuestas de APIs que proporcionan estos datos.
