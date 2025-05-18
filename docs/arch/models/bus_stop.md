# lib/models/bus_stop.dart

Este archivo define el modelo de datos para una parada de autobús.

## Responsabilidades:

- Representar la información de una parada de autobús, incluyendo su identificador, nombre, latitud y longitud.
- Proveer un método `fromJson` para deserializar datos JSON en un objeto `BusStop`.

## Propiedades:

- `id`: Identificador único de la parada (String).
- `name`: Nombre de la parada (String).
- `lat`: Latitud de la parada (double).
- `lon`: Longitud de la parada (double).

## Entradas:

- El constructor requiere `id`, `name`, `lat`, y `lon`.
- El factory constructor `fromJson` toma un `Map<String, dynamic>` (generalmente de una respuesta API).

## Salidas/Efectos:

- Provee una estructura de datos para manejar información de paradas de autobús.
- Permite la creación de objetos `BusStop` a partir de datos JSON, facilitando la integración con APIs que retornan esta estructura.
