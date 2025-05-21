# lib/services/eta_fetcher_service.dart

Este archivo define una interfaz (clase abstracta) para los servicios encargados de obtener la información de llegada estimada (ETA) de los autobuses.

## `ETAFetcherService` (Clase Abstracta):

Define el contrato que cualquier implementador de un servicio de obtención de ETAs debe seguir.

### Responsabilidades:

- Especificar la funcionalidad principal para obtener información de llegadas de autobuses.

### Métodos:

- `getUpcomingBusesForStop(String stopId)`:
  - **Descripción**: Obtiene una lista de información de llegadas de autobuses (`BusArrivalInfo`) para una parada específica identificada por `stopId`.
  - **Entradas**: `stopId` (String), el identificador de la parada de autobús.
  - **Salidas**: Un `Future` que resuelve a una `List<BusArrivalInfo>` con la información de las próximas llegadas a esa parada.
  - **Efectos**: Interactúa con una fuente externa (API, base de datos, etc.) para obtener los datos de ETA.

## Entradas:

- Depende del modelo `BusArrivalInfo`.

## Salidas/Efectos:

- Define una interfaz estándar para la funcionalidad de obtención de ETA, permitiendo diferentes implementaciones (ej. un servicio que llama a una API real, un mock para pruebas).
