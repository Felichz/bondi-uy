# lib/services/otp_service.dart

Este archivo define un servicio (`OtpService`) encargado de interactuar con un servidor OpenTripPlanner (OTP) utilizando consultas GraphQL para planificar rutas de viaje.

## `OtpService` (Clase):

Encapsula la lógica para enviar consultas de planificación de rutas al servidor OTP.

### Responsabilidades:

- Realizar consultas GraphQL al endpoint de planificación de un servidor OTP.
- Manejar la comunicación con el cliente GraphQL.

### Constructor:

- `OtpService(this.client)`:
  - **Descripción**: Inicializa el servicio con una instancia de `GraphQLClient`.
  - **Entradas**: `client` (GraphQLClient), un cliente configurado para comunicarse con el servidor GraphQL de OTP.
  - **Salidas/Efectos**: Crea una instancia del servicio lista para realizar consultas.

### Métodos:

- `planRoute({required double fromLat, required double fromLon, required double toLat, required double toLon, required String date, required String time, int numItineraries = 3})`:
  - **Descripción**: Envía una consulta GraphQL al servidor OTP para encontrar itinerarios entre dos puntos en una fecha y hora específicas.
  - **Entradas**:
    - `fromLat` (double): Latitud del punto de origen.
    - `fromLon` (double): Longitud del punto de origen.
    - `toLat` (double): Latitud del punto de destino.
    - `toLon` (double): Longitud del punto de destino.
    - `date` (String): Fecha del viaje (formato YYYY-MM-DD).
    - `time` (String): Hora del viaje (formato HH:MM).
    - `numItineraries` (int, opcional, por defecto 3): Número máximo de itinerarios a solicitar.
  - **Salidas**: Un `Future<QueryResult>` que contiene la respuesta del servidor OTP, incluyendo los itinerarios encontrados o información de errores.
  - **Efectos**: Ejecuta una operación de consulta GraphQL. Depende de la configuración del `GraphQLClient` provisto en el constructor (que a su vez depende de la URL del servidor OTP, probablemente de `otp_constants.dart`). Puede imprimir mensajes de depuración o error en la consola.

## Entradas:

- Depende de `graphql_flutter` para la funcionalidad de cliente GraphQL.
- Recibe parámetros de ubicación, fecha y hora para la planificación.

## Salidas/Efectos:

- Provee la funcionalidad central para obtener opciones de rutas de transporte público y/o a pie desde el servidor OTP.
- El resultado (`QueryResult`) contiene los datos estructurados de los itinerarios que deben ser procesados por otras partes de la aplicación (ej. `ItineraryPlanningService`).
