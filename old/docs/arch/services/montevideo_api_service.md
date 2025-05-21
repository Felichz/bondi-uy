# lib/services/montevideo_api_service.dart

Este archivo define el servicio (`MontevideoApiService`) que interactúa con la API de transporte público de la Intendencia de Montevideo para obtener datos de autobuses. Implementa la interfaz `ETAFetcherService`.

## `MontevideoApiService` (Clase):

Encapsula la lógica para comunicarse con la API de Montevideo, incluyendo la gestión de la autenticación (tokens) y la obtención de datos de transporte.

### Responsabilidades:

- Obtener y gestionar tokens de acceso para la API de Montevideo, manejando su expiración y refresco.
- Implementar la interfaz `ETAFetcherService` para proveer información de llegada de buses (`getUpcomingBusesForStop`).
- Obtener la lista de líneas de bus que pasan por una parada específica (`fetchBusLinesForStop`).
- Obtener información detallada de llegadas de buses para una parada específica, incluyendo datos en tiempo real y posición (`_fetchArrivalsForStop`).
- Obtener la ubicación en tiempo real de los buses de una línea específica (`fetchRealtimeBusLocations`).
- Manejar errores de la API (ej. 401, 403, 404, 429) y realizar reintentos cuando sea apropiado.
- Parsear las respuestas JSON de la API a formatos utilizables por la aplicación (Listas de Mapas o `BusArrivalInfo`).

### Propiedades Internas:

- `_accessToken`: Almacena el token de acceso actual (String, opcional).
- `_tokenExpiration`: Almacena la fecha y hora de expiración del token (`DateTime`, opcional), utilizada para determinar si se necesita obtener un nuevo token.

### Métodos:

- `getApiToken()`:

  - **Descripción**: Gestiona la obtención de un token de acceso de la API. Si el token existente es válido y no ha expirado, lo devuelve. De lo contrario, realiza una solicitud POST para obtener un nuevo token y actualiza las propiedades internas.
  - **Entradas**: Ninguna explícita, utiliza las constantes de autenticación definidas en `api_constants.dart` (`CLIENT_ID`, `CLIENT_SECRET`, `ACCESS_TOKEN_URL`).
  - **Salidas**: Un `Future<String?>` que resuelve al token de acceso válido o null si falla la obtención.
  - **Efectos**: Realiza una solicitud HTTP POST a la URL de autenticación. Actualiza `_accessToken` y `_tokenExpiration`. Puede imprimir mensajes de depuración o error.

- `fetchBusLinesForStop(String stopId)`:

  - **Descripción**: Consulta la API para obtener la lista de líneas de bus asociadas a una parada específica (`/busservice/lines/{stopId}`).
  - **Entradas**: `stopId` (String), el identificador de la parada.
  - **Salidas**: Un `Future<List<Map<String, dynamic>>>` que resuelve a una lista de mapas (representando líneas de bus) o una lista vacía en caso de error o no encontrar líneas.
  - **Efectos**: Realiza una solicitud HTTP GET autenticada utilizando el token obtenido por `getApiToken`. Incluye lógica de reintento en caso de token inválido/expirado. Depende de `BASE_URL` de `api_constants.dart` para la URL base del endpoint.

- `getUpcomingBusesForStop(String stopId)` (Implementación de `ETAFetcherService`):

  - **Descripción**: Obtiene y procesa la información de próximas llegadas de buses para una parada específica. Este método implementa el contrato definido en `ETAFetcherService`.
  - **Entradas**: `stopId` (String).
  - **Salidas**: Un `Future<List<BusArrivalInfo>>` que resuelve a una lista de objetos `BusArrivalInfo`, conteniendo detalles como minutos para llegar, si es en tiempo real, línea y posición.
  - **Efectos**: Internamente llama a `_fetchArrivalsForStop` para obtener los datos crudos y luego los mapea a la lista de `BusArrivalInfo`. Incluye lógica robusta para parsear las coordenadas de posición desde diferentes posibles formatos de la API y maneja los tipos de datos de la respuesta.

- `_fetchArrivalsForStop(String stopId)` (Método Privado):

  - **Descripción**: Realiza la llamada HTTP directa al endpoint de la API de Montevideo para obtener los datos de próximas llegadas a una parada específica (`/transporteRest/siguientesParada/{stopId}`). Este endpoint parece ser una excepción en la estructura de URLs base.
  - **Entradas**: `stopId` (String).
  - **Salidas**: Un `Future<List<Map<String, dynamic>>>` con la respuesta cruda de la API (una lista de mapas) o una lista vacía en caso de error o formato inesperado.
  - **Efectos**: Realiza una solicitud HTTP GET autenticada. Maneja errores de red, errores HTTP (incluyendo 401/403 con reintento), y verifica que el cuerpo de la respuesta sea una lista JSON. Imprime mensajes de depuración/error.

- `fetchRealtimeBusLocations(String lineShortName)`:
  - **Descripción**: Obtiene la ubicación en tiempo real de los buses que están actualmente en operación para una línea específica (`/busservice/realtimelocations/{lineShortName}`).
  - **Entradas**: `lineShortName` (String), el nombre corto de la línea de bus.
  - **Salidas**: Un `Future<Map<String, dynamic>?>` que resuelve a un mapa (representando los datos de ubicación en tiempo real) o null si falla o no hay datos para esa línea.
  - **Efectos**: Realiza una solicitud HTTP GET autenticada. Incluye lógica de reintento en caso de token inválido/expirado y manejo de otros errores HTTP. Espera un objeto JSON como respuesta.

## Entradas:

- Depende de `api_constants.dart` para las URLs base y credenciales de autenticación.
- Utiliza la librería `http` para todas las operaciones de red.
- Depende de los modelos `BusArrivalInfo` y `Position` (de mapbox_maps_flutter) para procesar los datos de llegada.

## Salidas/Efectos:

- Provee acceso a los datos de transporte público de la API de Montevideo a otras partes de la aplicación.
- Abstracta la complejidad de la autenticación y la estructura específica de los endpoints de la API de Montevideo.
- Los datos de llegada procesados (`List<BusArrivalInfo>`) y la información de ubicación en tiempo real pueden ser consumidos por servicios de planificación de itinerarios (como `ItineraryPlanningService`) o directamente por la UI que necesite mostrar esta información.
