# Tech Debt Log

Este archivo rastrea la deuda técnica identificada durante el desarrollo.

## Refactorización de Planificación de Itinerarios (Post Mod_ItineraryPlanning)

Fecha Identificada: 2024-07-26

### 1. Funcionalidad en `_onMapCreated` (`lib/screens/map_screen.dart`) - RESUELTO/CLARIFICADO

- **Descripción Original:** Durante la refactorización para estabilizar `map_screen.dart` y eliminar errores de linter, se comentaron las siguientes líneas en la función `_onMapCreated`:
  ```dart
  // await _mapboxService!.loadInitialStyle();
  // await _mapboxService!.initTooltipLayer();
  ```
  Además, la inicialización de `MapInteractionController` se simplificó a `_mapInteractionController = MapInteractionController(ref: ref, mapboxService: _mapboxService!);`.
- **Impacto Potencial Original:** Si `loadInitialStyle()` o `initTooltipLayer()` eran responsables de configuraciones visuales importantes del mapa o de la capa de tooltips, estas podrían no estar funcionando como antes. De manera similar, si `MapInteractionController` requiere una inicialización más compleja o parámetros adicionales que fueron eliminados/alterados durante los intentos de corrección de la IA, algunas interacciones avanzadas del mapa podrían estar afectadas.
- **Resolución (2024-07-27):**
  - Se investigó `MapboxService` y se determinó que los métodos `loadInitialStyle()` e `initTooltipLayer()` ya no existen con esos nombres.
  - La funcionalidad de carga inicial de estilo es manejada por `MapboxService.handleStyleLoaded()`, invocado a través de `_onStyleLoadedListener` en `MapScreen`.
  - La funcionalidad de la capa de tooltip parece estar encapsulada dentro de `MapboxService` (manejo de `INCOMING_BUS_TOOLTIP_LAYER_ID` y sus animaciones asociadas).
  - Las líneas comentadas fueron eliminadas de `_onMapCreated` ya que no correspondían a funcionalidad existente.
  - Se revisó el constructor de `MapInteractionController` y se confirmó que la inicialización actual en `_onMapCreated` es completa y correcta.
- **Estado:** Considerado resuelto/clarificado. La funcionalidad esencial está cubierta por otros mecanismos o la inicialización es correcta.

### 2. Función `_fetchUpcomingBuses` en `MapScreen` (`lib/screens/map_screen.dart`) - RESUELTO

- **Descripción Original:** La función `_fetchUpcomingBuses` en `lib/screens/map_screen.dart` fue originalmente utilizada por `RouteOptionsPanel` para obtener ETAs. Con la introducción de `ProcessedItinerary` y `ItineraryPlanningService`, los itinerarios procesados ya incluyen la información de ETA necesaria para el panel de opciones.
- **Impacto Potencial Original:** La función `_fetchUpcomingBuses` podría ser código muerto o no utilizado. Mantenerla podría llevar a confusiones o a que se use incorrectamente en el futuro.
- **Resolución (2024-07-27):**
  - Se verificó mediante análisis de código y búsqueda (`grep`) que la función `_fetchUpcomingBuses` no estaba siendo llamada desde ninguna parte en `MapScreen`.
  - La función `_fetchUpcomingBuses` fue eliminada de `lib/screens/map_screen.dart`.
- **Estado:** Resuelto. El código muerto ha sido eliminado.

### 3. Refactorización de UI en `RouteOptionsPanel` (`lib/widgets/route_options_panel.dart`) - PENDIENTE

- **Descripción:** El widget `_buildContent` dentro de `lib/widgets/route_options_panel.dart` es responsable de construir la UI para cada opción de itinerario en el modal. Actualmente, es una función relativamente larga.
- **Impacto Potencial:** Un widget de construcción grande puede ser más difícil de leer, mantener y probar.
- **Acción Sugerida:**
  - Descomponer `_buildContent` en varios sub-widgets privados más pequeños y enfocados. Por ejemplo:
    - `_ItineraryLegIconsWidget(legs: itinerary.legs)`
    - `_ItineraryTimingDetailsWidget(processedItinerary: processedItinerary)`
    - `_ItineraryWarningsWidget(processedItinerary: processedItinerary)`
  - Esto mejorará la legibilidad y la organización del código en `RouteOptionsPanel`.
- **Estado:** Pendiente. Es una mejora deseable para la mantenibilidad.

## Fase 2: Fusión de Itinerarios (`ItineraryPlanningService`)

Fecha Identificada: 2024-07-27

### 4. Mejoras en la Lógica de Consolidación de Itinerarios (`_createConsolidatedItineraryFromGroup`)

- **Descripción:** La función `_createConsolidatedItineraryFromGroup` en `lib/services/itinerary_planning_service.dart` implementa la lógica inicial para fusionar un grupo de `ProcessedItinerary` en un único `ConsolidatedItinerary`. La versión actual utiliza varias simplificaciones, tomando muchos valores (duraciones, ETAs, advertencias) directamente del itinerario "representativo" del grupo.
- **Impacto Potencial:** Las simplificaciones pueden llevar a que la información presentada para un itinerario consolidado no sea la óptima (ej. no reflejar la mejor ETA posible entre las alternativas) o que el `score` no represente fielmente la calidad de la opción consolidada.
- **Acciones Sugeridas/Refinamientos Futuros:**
  - **Color de Ruta (`routeColor`):** Implementar lógica para obtener/asignar un color de ruta representativo en `ConsolidatedItineraryLeg`.
  - **Cálculo de Campos Clave para el Consolidado:**
    - `firstBusWaitDuration`: Recalcular considerando la ETA más temprana y alcanzable entre todas las alternativas del primer tramo de bus consolidado.
    - `representativeFirstBusETAInfo`: Debe reflejar la ETA más temprana/mejor del grupo consolidado.
    - `canReachFirstBus`: Debe ser `true` si _alguna_ de las alternativas del primer tramo de bus es alcanzable.
    - `estimatedTotalDuration`: Ajustar basado en los posibles cambios de `firstBusWaitDuration` y ETAs reales de las alternativas.
  - **Consolidación de `warnings`:** En lugar de tomar solo las del representativo, generar una lista unificada de advertencias relevantes para el grupo.
  - **Lógica de Puntuación (`score`):** Desarrollar un algoritmo de puntuación más sofisticado para `ConsolidatedItinerary` que valore adecuadamente la presencia y calidad de las alternativas (ej. número de alternativas, fiabilidad de sus ETAs).
  - **Consolidación de Tramos Subsecuentes:** Explorar la posibilidad de consolidar tramos posteriores al primer bus si son idénticos o muy similares entre los itinerarios del grupo.
  - **Manejo de `headsign`:** Para el tramo de bus consolidado, si las alternativas tienen diferentes `headsigns` (destinos), considerar cómo presentar esta información (ej. "Varias líneas hacia X, Y, Z" o el más común).
- **Estado:** Pendiente. Mejoras necesarias para robustecer la lógica y la precisión de los datos consolidados.

## Lógica de Fusión y Consolidación de Itinerarios (`ItineraryPlanningService`)

### 1. Valores Agregados/Representativos en `ConsolidatedItinerary` para Grupos Fusionados

- **Problema**: Actualmente, cuando se fusionan múltiples `ProcessedItinerary` en un `ConsolidatedItinerary`, muchos de los campos principales de este último (como `estimatedTotalDuration`, `totalWalkDuration`, `firstBusWaitDuration`, `representativeFirstBusETAInfo`, `score`) se toman _directamente_ del `representativeProcessedItineraryForGroup` (el que tiene el mejor score individual dentro del grupo).
- **Impacto**: La información mostrada al usuario para una opción fusionada refleja solo una de las posibles sub-opciones (la "mejor" según el score individual). No ofrece un rango (ej. duración total: 30-35 min) ni promedios, ni indica la variabilidad dentro del grupo fusionado.
- **Posible Mejora**:
  - Para duraciones y scores, considerar almacenar/mostrar rangos (min-max del grupo) o un valor representativo calculado (ej. promedio ponderado, o el del representativo actual pero indicando que es de una variante).
  - Para `representativeFirstBusETAInfo`, si se fusionan múltiples líneas, el ETA mostrado es solo el del `representativeProcessedItinerary`. Ya se añadió `alternativeFirstBusETAs` para mostrar todos, lo cual es bueno. Asegurar que la UI lo use bien.

### 2. Complejidad y Precisión de la Fusión de Tramos de Bus (`_createFusedConsolidatedLegs`)

- **Problema**: La lógica actual fusiona basándose en el _primer_ segmento de bus compartido (`SEGMENT:fromStop>toStop`). Si hay itinerarios con múltiples tramos de bus (transbordos), la fusión solo considera el primero para agrupar. Los tramos de bus subsecuentes se toman del itinerario representativo del grupo.
- **Impacto**: Podría haber oportunidades de fusión más profundas no aprovechadas si dos itinerarios comparten el primer segmento, pero luego difieren, y más adelante vuelven a coincidir en un segundo segmento de bus que también podría fusionar líneas.
- **Posible Mejora (Compleja)**:
  - Explorar claves de agrupación más sofisticadas que consideren la secuencia completa de segmentos de bus (ej. `SEGMENT:A>B|SEGMENT:C>D`).
  - Modificar `_createFusedConsolidatedLegs` para que, dada dicha clave, pueda fusionar líneas para _cada_ segmento de bus compartido en la secuencia, no solo el primero.
  - Esto aumentaría significativamente la complejidad pero podría llevar a una consolidación más "inteligente" en casos de múltiples transbordos. (Nota: Se discutió y se optó por la estrategia actual por simplicidad inicial).

### 3. Manejo de Caminatas en Itinerarios Fusionados

- **Problema**: Los tramos de caminata en un `ConsolidatedItinerary` se toman directamente del `representativeProcessedItineraryForGroup`.
- **Impacto**: Si los itinerarios dentro de un grupo fusionado tuvieran variaciones significativas en sus tramos de caminata (especialmente caminatas intermedias en transbordos complejos), la representación no sería precisa para todas las sub-opciones.
- **Consideración**: El usuario indicó que asume que las caminatas son iguales si las paradas son las mismas. Si esta premisa se mantiene, el enfoque actual es aceptable. Si se descubren casos donde las caminatas varían significativamente para itinerarios que _deberían_ fusionarse, se necesitaría reevaluar.

### 4. Normalización de IDs de Parada (`_getNormalizedStopId`)

- **Problema**: La función `_getNormalizedStopId` utiliza heurísticas para intentar obtener un ID de parada consistente (`stopId` vs. `stopGtfsId`). Su efectividad depende de la consistencia y patrones de los datos provistos por la API de OTP.
- **Impacto**: Si las heurísticas no cubren todos los casos o si los datos de OTP son inconsistentes de formas no previstas, la clave de agrupación podría seguir siendo inestable, llevando a fusiones incorrectas o ausentes.
- **Posible Mejora**:
  - **Investigar Especificaciones de OTP**: Confirmar con la documentación de la instancia de OTP utilizada (o mediante experimentación y análisis de datos crudos) el significado exacto, formato esperado y relación entre `LegEndpoint.stopId` y `LegEndpoint.stopGtfsId`.
  - **Refinar Heurísticas**: Basándose en un mejor entendimiento, refinar o simplificar la lógica de `_getNormalizedStopId`. Considerar añadir logging detallado (en modo debug) de los IDs originales y el ID normalizado resultante cuando se sospeche de problemas de fusión.
  - **Perfil de Datos**: Si es posible, analizar un conjunto de respuestas de OTP para entender la variabilidad real de estos IDs y construir reglas de normalización más basadas en datos.

## Visualización y Lógica de UI/Mapa

### Problema con Visualización de Bus en Tiempo Real (Identificado 2024-07-30)

- **Descripción:** Actualmente, aunque se selecciona una opción de ruta con información de bus en tiempo real (coordenadas y estado `isReal`), el bus no se visualiza en el mapa con el marcador y el tramo verde hacia la parada correspondiente.
- **Causa Raíz Sospechada:** La información del `BusArrivalInfo` (específicamente `position` y `isReal`) del `ConsolidatedItinerary` seleccionado no se propaga o utiliza correctamente a través de `MapNotifier` hacia `BusTrackingController` y, subsecuentemente, a `MapboxService` para el dibujo.
- **Componentes Afectados y Pasos de Corrección Necesarios:**
  1.  **`MapNotifier.processSelectedItinerary`**:
      - Asegurar que `state.representativeFirstBusETAInfo` se actualice correctamente con el `etaInfo` del `ConsolidatedItinerary`.
      - Asegurar que `state.realtimeTrackingAvailable` y `state.realtimeTrackingAttempted` se establezcan correctamente basados en este `etaInfo`.
      - La llamada a `busTrackingController.startTrackingBusLine` debe pasar tanto el `RouteLeg` como el `BusArrivalInfo?`.
  2.  **`BusTrackingController.startTrackingBusLine(RouteLeg busLegToTrack, BusArrivalInfo? etaInfo)`**:
      - Modificar la firma para aceptar `BusArrivalInfo? etaInfo`.
      - Utilizar este `etaInfo` para determinar si el bus es rastreable en tiempo real (tiene `isReal == true` y `position != null`).
      - Si es rastreable, llamar a un nuevo método en `MapboxService` (ej. `updateRealtimeBusMarkerAndSegment`) pasando la información necesaria.
      - Si no es rastreable, llamar a un método en `MapboxService` para limpiar cualquier marcador/segmento de bus en tiempo real (ej. `clearRealtimeBusMarkerAndSegment`).
      - Revisar/simplificar la lógica del `_realtimeBusTimer`. Idealmente, este timer debería re-solicitar la información de ETA más reciente para la línea y parada, en lugar de solo ser un placeholder.
  3.  **`MapboxService`**:
      - Añadir método: `Future<void> updateRealtimeBusMarkerAndSegment(BusArrivalInfo etaInfo, List<Position>? fullBusLineShape, int? upcomingStopIndexOnShape)`.
        - Este método será responsable de:
          - Crear/actualizar un `GeoJsonSource` y `SymbolLayer` para el ícono del bus en `etaInfo.position`.
          - Si `fullBusLineShape` y `upcomingStopIndexOnShape` están disponibles, y la posición del bus está en el shape antes de la parada, calcular y dibujar el segmento de línea verde desde la posición del bus hasta la parada (`upcomingStopIndexOnShape`) sobre el `fullBusLineShape`.
      - Añadir método: `Future<void> clearRealtimeBusMarkerAndSegment()`.
        - Limpia el source y layer del marcador del bus y cualquier capa de segmento verde.
      - Añadir método: `Future<void> removeLayerAndSource({required String layerId, required String sourceId})` o una variante similar.
        - Necesario para eliminar capas y fuentes genéricas, como la capa de la forma completa de la línea de bus (`FULL_BUS_LINE_SHAPE_LAYER_ID_PREFIX`) cuando se llama a `BusTrackingController.stopTrackingBusLine()`.
- **Estado:** Pendiente. Requiere refactorización coordinada de `MapNotifier`, `BusTrackingController`, y `MapboxService`.

## Pequeñas Mejoras y Puntos de Revisión Futura

Esta sección es para ítems de menor prioridad, ideas de refinamiento o puntos que merecen una segunda revisión una vez que la funcionalidad principal esté estable.

Fecha Identificada: 2024-07-28 (Inicio de la sección)

### 5. `MapboxService`: Consistencia y Refinamientos Potenciales

- **Nombres de Métodos:** Algunos nombres de métodos en `MapboxService` son bastante largos (ej. `clearAllRouteLayersAndSources`). Aunque descriptivos, evaluar si existen alternativas más concisas sin perder claridad (baja prioridad).
- **Manejo de Errores/Logging:** `MapboxService` utiliza `print` para errores y depuración. Considerar un sistema de logging más estructurado o la propagación de ciertos errores para que la UI pueda reaccionar de forma más elegante.
- **Configurabilidad del Padding en Zoom:** Los métodos de zoom (`zoomToRouteBounds`, `zoomToLeg`, `zoomToFitPositions`) usan valores de padding fijos. Evaluar si sería beneficioso hacerlos configurables o dependientes del contexto/tamaño de la UI.
- **Interacción de Capas de Seguimiento en Tiempo Real:** Para `drawFullBusLineShape` y `drawIncomingBusSegment`, asegurar que el orden de capas y la interacción visual con las capas de la ruta del usuario planificada sea siempre la correcta y visualmente clara.

### 6. `MapboxService`: Mantenimiento Futuro de `displayRelevantStops`

- **Descripción:** El método `displayRelevantStops` actualmente maneja correctamente las paradas `from` y `to` de `RouteLeg`. Si el modelo `RouteLeg` se enriquece en el futuro para incluir paradas intermedias detalladas (ej. con `stopId`), este método necesitará ser actualizado para visualizarlas. (Nota de mantenimiento preventivo).

### 7. `MapboxService`: Color de Rutas de Bus en `drawRoute`

- **Fecha Identificada:** 2024-07-28
- **Descripción:** El método `drawRoute` en `MapboxService` actualmente usa un color rojo por defecto para todos los tramos de bus. El color real de la ruta (GTFS `route_color`) está disponible en los datos de OTP pero no se propaga a `LegRoute` de forma que `MapboxService` pueda accederlo directamente al dibujar el tramo.
- **Impacto Potencial:** Todas las rutas de bus se ven iguales, perdiendo la diferenciación visual que proveen los colores GTFS.
- **Acción Sugerida:** Modificar los modelos (`Itinerary`, `ProcessedItinerary`, `ConsolidatedItinerary`, `RouteLeg` y/o `LegRoute`) para que el `gtfsRouteColor` original del itinerario de OTP esté accesible para `MapboxService` cuando dibuja un tramo de bus. Esto podría implicar añadir un campo `routeColorHex` (o similar) a `LegRoute` o `RouteLeg`.
- **Estado:** Pendiente.

### 8. Manejo de Errores Específicos en `_fetchArrivalsForStop` (`MontevideoApiService`)

- **Fecha Identificada:** 2024-07-29
- **Descripción:** Cuando `_fetchArrivalsForStop` en `MontevideoApiService` encuentra errores (ej. HTTP 404 si la parada no existe, 429 si aún ocurre el rate limiting, o un formato de respuesta inesperado), actualmente retorna una lista vacía `[]`.
- **Impacto Potencial:** Si bien esto es manejado por `ItineraryPlanningService` como "ETA no disponible", se pierde la especificidad del error, lo que podría ser útil para depuración o para mostrar mensajes más informativos al usuario.
- **Acción Sugerida:** Considerar la posibilidad de que `ETAFetcherService` (y sus implementaciones) devuelvan un objeto resultado más rico (conteniendo datos o un error específico) o lancen excepciones más específicas (ej. `StopNotFoundException`, `RateLimitException`, `UnexpectedResponseFormatException`). Esto permitiría a los llamadores reaccionar de forma más granular. Por ahora, el comportamiento de retornar lista vacía es funcional.
- **Estado:** Pendiente (Prioridad: Baja/Media).

### 9. Cache de ETAs a Nivel de Servicio (`ETAFetcherService` / `MontevideoApiService`)

- **Fecha Identificada:** 2024-07-29
- **Descripción:** El cache actual `stopETAsCache` en `ItineraryPlanningService` es local a cada llamada de `getProcessedItineraries`, optimizando llamadas para la misma parada _dentro de una única planificación_.
- **Impacto Potencial:** Llamadas repetidas a la API de STM para las mismas paradas podrían ocurrir si el usuario realiza múltiples planificaciones (incluso diferentes) en un corto período.
- **Acción Sugerida:** Considerar implementar un cache a nivel de `MontevideoApiService` (o una capa de servicio de cacheo que envuelva a `ETAFetcherService`) con una política de expiración adecuada (ej. ETAs válidos por 30-60 segundos). Esto reduciría aún más las llamadas a la API de STM entre diferentes operaciones de planificación, mejorando el rendimiento y la robustez contra el rate limiting.
- **Estado:** Pendiente (Prioridad: Media).

### 10. Selección de ETA Específico y Orden de Arribos en `_processSingleItinerary`

- **Fecha Identificada:** 2024-07-29
- **Descripción:** `_processSingleItinerary` toma el primer (`specificLineEtas.first`) arribo que coincide con la línea de bus deseada después de obtener todos los arribos para una parada.
- **Impacto Potencial:** Generalmente correcto, pero asume que la API (`/siguientesParada/{stopId}`) devuelve los arribos ordenados cronológicamente. Si no es así, o si múltiples arribos para la misma línea exacta requieren desambiguación (ej. por destino de variante), la selección podría no ser la óptima.
- **Acción Sugerida:** Confirmar (si es posible, mediante documentación de la API) que los arribos de `/siguientesParada/{stopId}` vienen pre-ordenados por tiempo. Si no, añadir un paso de ordenamiento por `minutos` antes de seleccionar `.first`. Evaluar si se necesita una lógica de desambiguación más compleja si una línea puede tener múltiples arribos simultáneos con diferentes destinos/variantes.
- **Estado:** Pendiente (Prioridad: Baja).

### 11. Claridad del Campo `position` en `BusArrivalInfo` y su Manejo

- **Fecha Identificada:** 2024-07-29
- **Descripción:** `BusArrivalInfo.position` puede ser `null` si la API no provee coordenadas válidas.
- **Impacto Potencial:** Es crucial que los consumidores de `BusArrivalInfo.position` (ej. `BusTrackingController`, UI) manejen correctamente esta nulidad.
- **Acción Sugerida:** Asegurar mediante revisión de código, comentarios y posiblemente aserciones, que los consumidores de `BusArrivalInfo.position` están preparados para manejar valores nulos. Esto indica que la ubicación en tiempo real no está disponible para ese arribo específico, incluso si el campo `isReal` es verdadero (ya que `isReal` podría referirse solo a la predicción de tiempo).
- **Estado:** Pendiente (Prioridad: Baja).
