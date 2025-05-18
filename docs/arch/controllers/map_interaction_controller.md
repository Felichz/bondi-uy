# lib/controllers/map_interaction_controller.dart

Este archivo define la clase `MapInteractionController`, responsable de manejar y responder a las interacciones del usuario con el mapa de Mapbox (movimiento de cámara, taps, long presses).

## `MapInteractionController` (Clase):

Actúa como un intermediario entre los eventos de interacción crudos del mapa y la lógica de la aplicación. Notifica a `MapNotifier` sobre el inicio y fin de la interacción del usuario y gestiona acciones específicas como la identificación de paradas de bus al hacer tap y la presentación de información relevante en modales.

### Responsabilidades:

- Escuchar y procesar los eventos de cambio de cámara (`onMapCameraChangeListener`) e inactividad del mapa (`onMapIdleListener`).
- Notificar a `MapNotifier` cuando el usuario comienza o deja de interactuar manualmente con el mapa, actualizando el estado `userMapInteraction`.
- Manejar eventos de tap en el mapa (`handleMapTapEvent`), delegando la identificación de elementos (como paradas de bus) a `MapboxService`.
- Si se identifica una parada de bus al hacer tap, obtener las líneas de bus que pasan por esa parada utilizando `MontevideoApiService` y mostrar un bottom sheet modal con la información de las líneas y sus próximas llegadas (`_requestBusLinesForStopModal`).
- Manejar eventos de pulsación larga en el mapa (`handleMapLongPressEvent`) (funcionalidad placeholder por ahora).
- Proporcionar un listener para errores de carga del mapa (`onMapLoadErrorListener`).
- Integrarse con `MapboxService` para operaciones relacionadas con la interacción con elementos del mapa.
- Acceder a servicios (como `MontevideoApiService`) y notifiers (como `MapNotifier`) a través de Riverpod.

### Propiedades Internas:

- `mapboxService`: Instancia de `MapboxService` para interactuar con el mapa.
- `ref`: Referencia a `WidgetRef` de Riverpod para acceder a otros providers.

### Constructor:

- `MapInteractionController({required this.mapboxService, required this.ref})`:
  - **Descripción**: Inicializa el controlador inyectando las dependencias necesarias: una instancia de `MapboxService` y una referencia a `WidgetRef` de Riverpod.
  - **Entradas**: `mapboxService` (instancia de `MapboxService`), `ref` (referencia a `WidgetRef`).
  - **Salidas/Efectos**: Crea una instancia del controlador lista para manejar interacciones.

### Métodos:

- `onMapCameraChangeListener(CameraChangedEventData eventData)`:

  - **Descripción**: Callback llamado cuando la cámara del mapa cambia. Si el estado actual indica que el usuario estaba inactivo, asume que el cambio fue iniciado manualmente por el usuario y notifica a `MapNotifier` que la interacción ha comenzado.
  - **Entradas**: `eventData` (Datos del evento de cambio de cámara).
  - **Salidas**: Ninguna.
  - **Efectos**: Lee el estado de `MapNotifier`. Llama a `mapInteractionStarted` en `MapNotifier` si el estado es inactivo.

- `onMapIdleListener(MapIdleEventData data)`:

  - **Descripción**: Callback llamado cuando el mapa se vuelve inactivo (después de un movimiento o animación). Notifica a `MapNotifier` que la interacción ha terminado.
  - **Entradas**: `data` (Datos del evento de inactividad del mapa).
  - **Salidas**: Ninguna.
  - **Efectos**: Llama a `mapInteractionEnded` en `MapNotifier`.

- `handleMapTapEvent(MapContentGestureContext mapTapContext, BuildContext uiContext)`:

  - **Descripción**: Maneja un evento de tap en el mapa. Notifica a `MapNotifier` sobre el inicio y fin de la interacción. Llama a `MapboxService.handleMapTap` para identificar si se ha tocado un elemento interactivo (como una parada) y, si es así, ejecuta un callback proporcionado que a su vez llama a `_requestBusLinesForStopModal` para mostrar información de la parada.
  - **Entradas**: `mapTapContext` (Contexto del gesto de tap en el mapa), `uiContext` (Contexto del widget de la UI necesario para mostrar modales).
  - **Salidas**: Un `Future<void>`.
  - **Efectos**: Llama a `mapInteractionStarted` y `mapInteractionEnded` en `MapNotifier`. Llama a `MapboxService.handleMapTap`. Puede desencadenar la presentación de un modal.

- `handleMapLongPressEvent(MapContentGestureContext context)`:

  - **Descripción**: Maneja un evento de pulsación larga en el mapa. Actualmente solo registra las coordenadas y notifica el inicio/fin de la interacción. Es un placeholder para futuras funcionalidades (ej. colocar un pin de ubicación).
  - **Entradas**: `context` (Contexto del gesto de pulsación larga).
  - **Salidas**: Un `Future<void>`.
  - **Efectos**: Imprime mensajes de depuración. Llama a `mapInteractionStarted` y `mapInteractionEnded` en `MapNotifier`.

- `onMapLoadErrorListener(MapLoadingErrorEventData data)`:

  - **Descripción**: Callback para manejar errores durante la carga del mapa. Actualmente solo imprime detalles del error en la consola.
  - **Entradas**: `data` (Datos del evento de error de carga del mapa).
  - **Salidas**: Ninguna.
  - **Efectos**: Imprime un mensaje de error.

- `_requestBusLinesForStopModal(String stopId, String stopName, BuildContext uiContext)` (Método Privado):

  - **Descripción**: Obtiene la lista de líneas de bus para una parada específica utilizando `MontevideoApiService` y muestra un `showModalBottomSheet` para presentar esta información al usuario. Dentro del modal, permite expandir cada línea para ver las próximas llegadas (ETAs), obteniendo estos datos también a través del servicio de ETA. Gestiona el estado de carga y los mensajes de error dentro del modal.
  - **Entradas**: `stopId` (ID de la parada), `stopName` (Nombre de la parada), `uiContext` (Contexto del widget de la UI necesario para mostrar el modal).
  - **Salidas**: Un `Future<void>`.
  - **Efectos**: Llama a `MontevideoApiService.fetchBusLinesForStop`. Llama a `ETAFetcherService.getUpcomingBusesForStop`. Muestra un `showModalBottomSheet`. Gestiona el estado y la visualización dentro del modal (carga, lista de líneas, lista de ETAs). Puede imprimir mensajes de depuración/error.

- `dispose()`:
  - **Descripción**: Método para liberar recursos si fuera necesario. Actualmente no realiza ninguna acción específica.
  - **Entradas**: Ninguna.
  - **Salidas**: Ninguna.
  - **Efectos**: Ninguno significativo en la implementación actual.

## Entradas:

- Depende de una instancia de `MapboxService` y una referencia a `WidgetRef` (Riverpod) inyectadas en el constructor.
- Recibe eventos de interacción del mapa (cambio de cámara, idle, tap, long press).
- Recibe un `BuildContext` para mostrar modales (`handleMapTapEvent`, `_requestBusLinesForStopModal`).

## Salidas/Efectos:

- Notifica a `MapNotifier` sobre el estado de interacción del usuario (`userMapInteraction`).
- Puede desencadenar la identificación de elementos del mapa (`MapboxService.handleMapTap`).
- Muestra un bottom sheet modal con información de paradas y ETAs de buses (`_requestBusLinesForStopModal`).
- Imprime mensajes de depuración y error.
