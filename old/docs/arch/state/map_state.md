# lib/state/map_state.dart

Este archivo define el estado global relacionado con el mapa y la planificación de itinerarios en la aplicación. Utiliza una clase inmutable (`MapState`) y varios enums para representar los diferentes aspectos del estado.

## `MapState` (Clase):

Es una clase inmutable que contiene todas las propiedades relevantes para describir el estado actual del mapa, la interacción del usuario, las opciones de ruta, la planificación y el seguimiento en tiempo real. Se utiliza junto con un `StateNotifier` (como `MapNotifier`) en Riverpod para gestionar y propagar los cambios de estado.

### Propiedades:

- `origin`: `Position?` - La ubicación de origen seleccionada por el usuario.
- `destination`: `Position?` - La ubicación de destino seleccionada por el usuario.
- `originAddress`: `String?` - El nombre de la dirección del origen.
- `destinationAddress`: `String?` - El nombre de la dirección del destino.
- `userMapInteraction`: `UserMapInteractionState` - Indica si el usuario está interactuando con el mapa (idle, manualMoveInProgress, manualMoveCooldown).
- `currentDisplayMode`: `MapDisplayMode` - Define el modo de visualización actual del mapa (ej. blank, originSelected, routeOverview, legTracking).
- `currentZoomTarget`: `ZoomTargetType` - Indica el objetivo de zoom actual que el controlador de zoom debería intentar alcanzar.
- `currentCameraOptions`: `CameraOptions?` - Las opciones de cámara actuales del mapa (puede ser útil para guardar el estado).
- `consolidatedItineraries`: `List<ConsolidatedItinerary>` - La lista de opciones de ruta consolidadas obtenidas del servicio de planificación.
- `selectedConsolidatedItinerary`: `ConsolidatedItinerary?` - La opción de ruta consolidada que el usuario ha seleccionado para visualizar en detalle.
- `representativeItinerary`: `Itinerary?` - El itinerario representativo del `selectedConsolidatedItinerary` (el que tiene el mejor score).
- `representativeFirstBusETAInfo`: `BusArrivalInfo?` - La información de ETA (real o programada) para el primer tramo de bus del `representativeItinerary`.
- `planningStatus`: `PlanningStatus` - El estado actual del proceso de planificación de rutas (idle, loading, success, error).
- `currentLegIndex`: `int?` - El índice del tramo de ruta (`RouteLeg`) actualmente seleccionado o resaltado dentro del `representativeItinerary`.
- `showInstructionsPanel`: `bool` - Indica si el panel de instrucciones de la ruta debe estar visible.
- `trackedBusLineShortName`: `String?` - El nombre corto de la línea de bus que se está rastreando en tiempo real (si aplica).
- `realDebugBusPosition`: `Position?` - Posición de depuración de un bus real (usado en desarrollo/depuración).
- `realDebugEtaMinutes`: `int?` - Minutos de depuración para la ETA real (usado en desarrollo/depuración).
- `realDebugIsReal`: `bool?` - Indica si la ETA de depuración es real (usado en desarrollo/depuración).
- `simulatedBusPosition`: `Position?` - Posición actual de un bus simulado (usado en desarrollo/depuración).
- `busSpeedMetersPerSecond`: `double?` - Velocidad calculada del bus simulado (usado en desarrollo/depuración).
- `lastSpeedCalculationTime`: `DateTime?` - Marca de tiempo de la última vez que se calculó la velocidad simulada (usado en desarrollo/depuración).
- `simulationSegmentOriginPoint`: `Position?` - Punto de origen del segmento de simulación actual (usado en desarrollo/depuración).
- `maxSimulationTravelDistance`: `double?` - Distancia máxima que el bus simulado puede recorrer en su segmento actual (usado en desarrollo/depuración).
- `realtimeTrackingAvailable`: `bool` - Indica si el seguimiento en tiempo real está disponible para el tramo seleccionado.
- `realtimeTrackingAttempted`: `bool` - Indica si se ha intentado iniciar el seguimiento en tiempo real para el tramo seleccionado.

### Constructor:

- `MapState({...})`:
  - **Descripción**: Constructor que permite inicializar el estado con valores específicos. Define valores por defecto para la mayoría de las propiedades.
  - **Entradas**: Valores opcionales para todas las propiedades de la clase.
  - **Salidas/Efectos**: Crea una nueva instancia inmutable de `MapState`.

### Método `copyWith`:

- `copyWith({...})`:
  - **Descripción**: Crea una nueva instancia de `MapState` copiando las propiedades de la instancia actual y aplicando las modificaciones proporcionadas. Incluye parámetros `clearX` para poder establecer propiedades opcionales a `null` explícitamente.
  - **Entradas**: Valores opcionales para las propiedades a modificar, y booleanos `clearX`.
  - **Salidas**: Una nueva instancia inmutable de `MapState` con los valores actualizados.
  - **Efectos**: Facilita la creación de nuevos estados a partir del actual con cambios específicos.

### Operadores `==` y `hashCode`:

- `@override bool operator ==(Object other)`:
  - **Descripción**: Implementa la comparación de igualdad entre dos objetos `MapState`, comparando todas sus propiedades para determinar si son lógicamente iguales.
- `@override int get hashCode`:
  - **Descripción**: Implementa el cálculo del código hash para un objeto `MapState`, combinando los códigos hash de todas sus propiedades. Es necesario para que `==` funcione correctamente en conjuntos y mapas.

## Enums:

- `UserMapInteractionState`: Define los posibles estados de interacción del usuario con el mapa (idle, manualMoveInProgress, manualMoveCooldown).
- `PlanningStatus`: Define los posibles estados del proceso de planificación de rutas (idle, loading, success, error).
- `ZoomTargetType`: Define los posibles objetivos de zoom que el controlador de zoom puede manejar (initial, origenSelection, destinationSelection, points, overview, leg, none).
- `MapDisplayMode`: Define los diferentes modos de visualización en los que puede estar el mapa, afectando qué elementos se muestran y cómo se comporta la UI (blank, originSelected, destinationSelected, routeOverview, legTracking, legHighlight, routeStaticWithInstructions).

## Dependencias:

- Depende de los modelos `ConsolidatedItinerary`, `Itinerary`, `RouteLeg`, `BusArrivalInfo` y `Point_dart` para representar los datos.
- Utiliza `mapbox_maps_flutter` para el tipo `Position` y `CameraOptions`.
- Utiliza `package:flutter/foundation.dart` para `listEquals` (usado en `==`).

## Utilización:

- Esta clase es típicamente observada por widgets de UI a través de Riverpod para actualizar su presentación en respuesta a los cambios en el estado del mapa y la ruta.
- Los `StateNotifier`s (como `MapNotifier`) son responsables de crear y emitir nuevas instancias de `MapState` cuando ocurren eventos o se completan operaciones asíncronas (como la planificación de rutas o las actualizaciones de ETA).
- Otras partes de la lógica de la aplicación (como controladores o servicios) pueden leer el estado actual a través del `StateNotifier` para tomar decisiones.
