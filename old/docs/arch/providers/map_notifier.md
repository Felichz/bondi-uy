# lib/providers/map_notifier.dart

Este archivo define `MapNotifier`, un `StateNotifier` de Riverpod encargado de gestionar el estado del mapa, la interacción del usuario, la planificación de itinerarios y la visualización de rutas y datos de transporte en el mapa.

## `MapNotifier` (Clase):

Extiende `StateNotifier<MapState>` y utiliza Riverpod para notificar a los listeners sobre los cambios en el estado del mapa (`MapState`). Orquesta diversas acciones como la planificación de rutas, la gestión de la interacción del usuario con el mapa, la selección y visualización de itinerarios, y la integración con el seguimiento de buses en tiempo real.

### Responsabilidades:

- Gestionar el estado actual del mapa, incluyendo la ubicación de origen y destino, la lista de itinerarios disponibles, el itinerario seleccionado, el tramo actual, y el estado de la planificación y seguimiento en tiempo real (`MapState`).
- Responder a eventos de interacción del usuario con el mapa (inicio y fin de movimiento manual) e implementar lógica de auto-zoom basada en el estado de la aplicación (`mapInteractionStarted`, `mapInteractionEnded`, `_triggerAutoZoomLogic`).
- Gestionar la configuración y limpieza de los puntos de origen y destino (`setOrigin`, `setDestination`, `clearOrigin`, `clearDestination`, `swapOriginAndDestination`).
- Iniciar el proceso de planificación de rutas llamando a `ItineraryPlanningService` (`planRoute`).
- Procesar los resultados de la planificación de rutas, actualizando el estado con los itinerarios consolidados y controlando el modo de visualización del mapa.
- Limpiar el estado relacionado con las rutas y el seguimiento de buses (`clearRouteState`).
- Manejar la selección de un itinerario consolidado por parte del usuario (`processSelectedItinerary`), preparando los datos para su visualización detallada y, si aplica, iniciando el seguimiento en tiempo real del primer bus.
- Gestionar la selección de tramos individuales de un itinerario (`setSelectedLegIndex`), incluyendo la lógica para cambiar al modo de seguimiento por tramo (`switchToLegTracking`) si se selecciona un tramo de bus.
- Integrarse con `BusTrackingController` para iniciar o detener el seguimiento en tiempo real y recibir actualizaciones de estado (`updateRealtimeTrackingStatus`, `setTrackedBusLineShortName`, `updateRepresentativeETA`).
- Manejar la lógica de simulación de bus (usada en desarrollo/depuración) (`updateBusSimulationState`, `clearHighlightedBusMarkerAndSegment`).
- Forzar el estado de inactividad del mapa y controlar el objetivo de zoom programáticamente (`forceMapIdleAndZoomTo`).
- Almacenar las opciones actuales de la cámara del mapa (`storeCurrentCameraOptions`).
- Controlar la visibilidad del panel de instrucciones (`toggleInstructionsPanel`).
- Actualizar la información de ETA representativa cuando `BusTrackingController` notifica nuevos datos.

### Constructor:

- `MapNotifier(this._ref, this._itineraryPlanningService) : super(MapState())`:
  - **Descripción**: Inicializa el `MapNotifier` con una referencia a Riverpod (`Ref`) y una instancia de `ItineraryPlanningService`. Establece el estado inicial a `MapState()`.
  - **Entradas**: Una instancia de `Ref` (para poder leer otros providers si es necesario) y una instancia de `ItineraryPlanningService`.
  - **Salidas/Efectos**: Crea una instancia del notificador de estado con el estado inicial del mapa.

### Propiedades Internas Clave:

- `_ref`: Referencia a Riverpod, utilizada para leer otros providers (ej. servicios) declarados en `service_providers.dart`.
- `_itineraryPlanningService`: Instancia del servicio principal de planificación de itinerarios, utilizada para obtener las opciones de ruta.
- `_manualMoveCooldownTimer`: Timer utilizado para implementar un retraso después de que el usuario deja de interactuar manualmente con el mapa antes de activar la lógica de auto-zoom.

### Métodos de Interacción con Servicios y Otros Controladores:

- `planRoute`: Llama a `_itineraryPlanningService.planAndConsolidateItineraries`.
- `processSelectedItinerary`: Interactúa con `MapboxService` para dibujar la ruta y con `BusTrackingController` para iniciar el seguimiento.
- `clearRouteState`: Interactúa con `MapboxService` para limpiar capas del mapa y con `BusTrackingController` para detener el seguimiento.
- `setSelectedLegIndex`: Interactúa con `MapboxService` para resaltar tramos.
- `switchToLegTracking`: Interactúa con `MapboxService` y `BusTrackingController` para gestionar el seguimiento por tramo.
- `updateRealtimeTrackingStatus`, `setTrackedBusLineShortName`, `updateRepresentativeETA`: Métodos llamados por `BusTrackingController` para actualizar el estado de seguimiento en tiempo real.

### Entradas Generales del Notificador:

- Recibe instancias de `Ref` e `ItineraryPlanningService` en su constructor.
- Recibe eventos de interacción del usuario (movimiento del mapa, selección de itinerarios/tramos).
- Recibe datos de ubicación (origen/destino) y opcionalmente información de ETA/ubicación de `BusTrackingController`.
- Recibe instancias de `MapboxService` y `BusTrackingController` como parámetros en varios métodos, ya que estos servicios/controladores están asociados a la UI del mapa y no son proveedores directos que el Notifier observaría globalmente.

## Salidas/Efectos Generales del Notificador:

- Emite nuevos estados (`MapState`) a través de Riverpod, notificando a los widgets que observan `mapNotifierProvider` para que reconstruyan su UI en consecuencia.
- Controla qué itinerarios o tramos se muestran en el mapa.
- Activa o desactiva el seguimiento de buses en tiempo real a través de `BusTrackingController`.
- Ajusta el objetivo de zoom del mapa (`currentZoomTarget`) para guiar la visualización del usuario.
- Gestiona el estado visual de la aplicación relacionado con el mapa (modos de visualización, visibilidad de paneles).

## Integración con Riverpod:

- `mapNotifierProvider`: `StateNotifierProvider` que provee una instancia de `MapNotifier`, dependiendo de `itineraryPlanningServiceProvider`.
