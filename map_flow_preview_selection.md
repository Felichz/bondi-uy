# Flujo de Información en el Mapa: Preview y Selección de Ruta

Este documento describe el flujo de llamadas a funciones y el dibujado de elementos en el mapa cuando el usuario realiza las siguientes acciones, según lo detallado en la documentación de `lib/ui` y `lib/map_manager`.

## 1. El usuario entra en la fase de opciones de viaje y ve la preview de la primera opción de trip (con ETA)

Cuando el usuario entra en esta fase, se espera que se llame a la función `MapManager.showRoutePreview`.

**Llamada principal:** `MapManager.showRoutePreview`

- **Input:** `route: OpcionDeRutaMostrable` (la primera opción de ruta)

**Flujo de llamadas desde `showRoutePreview`:**

1.  **Inicialización (si es necesario):**

    - Llama a `MapManager.initialize`
    - **Condición:** Si `_isInitialized` es falso.

2.  **Limpieza de preview anterior (si se muestra una opción diferente):**

    - Llama a `MapCleanup.clearRoutePreview`
    - **Condición:** Si `_currentPreviewOptionId` es diferente a `route.idOpcion`.
    - **Detalle de `clearRoutePreview`:**
      - Llama a `_clearLayersWithPrefix` varias veces con prefijos dinámicos ('preview-walk-layer-', 'preview-bus-layer-', etc.).
      - Llama a `_clearSourcesWithPrefix` varias veces con prefijos dinámicos ('preview-walk-source-', 'preview-bus-source-', etc.).
      - Llama a `_removeLayerSafely` dentro de un bucle para capas predefinidas (`previewLayerIds`).
      - Llama a `_removeSourceSafely` dentro de un bucle para fuentes predefinidas (`previewSourceIds`).

3.  **Renderizado de la ruta de preview:**
    - Llama a `MapRouteRenderer.renderRoutePreview`
    - **Input:** `ruta: OpcionDeRutaMostrable` (la misma ruta pasada a `showRoutePreview`).
    - **Condición:** Si `needsRedraw` es verdadero O `_activeLayers` está vacío.
    - **Detalle de `renderRoutePreview`:**
      - Itera sobre `ruta.tramosParaPreview`.
      - Si `tramo.tipo` es `TipoTramoViaje.CAMINAR`: Llama a `_drawWalkSegmentPreview(tramo, i)`.
      - Si `tramo.tipo` es `TipoTramoViaje.VIAJE_EN_BUS`: Llama a `_drawBusSegmentPreview(tramo, i)`.
      - Si `tramo.tipo` es `TipoTramoViaje.ESPERAR_BUS`: Llama a `_drawWaitPointPreview(tramo, i)`.
      - Itera de nuevo sobre `ruta.tramosParaPreview`.
      - Si `tramo.tipo` es `TipoTramoViaje.VIAJE_EN_BUS`: Llama a `_addBusStopsForSegmentPreview(tramo, i)`.
      - Después de los bucles, si `mapboxMap` no es nulo, llama a `_startArrowAnimation()`.

## 2. El usuario selecciona esta primera opción mostrada

Cuando el usuario selecciona la opción de ruta, se espera que la fase del mapa cambie y se llame a `MapManager.showActiveTrip`.

**Llamada principal:** `MapManager.showActiveTrip`

- **Input:** `activeTripState: EstadoFaseViajeActivo` (el estado del viaje activo basado en la ruta seleccionada).

**Flujo de llamadas desde `showActiveTrip`:**

1.  **Transición desde Preview:**

    - Llama a `_convertPreviewToActiveTrip`
    - **Input:** `activeTripState: EstadoFaseViajeActivo`.
    - **Condición:** Si `_currentPhase` es 'route_preview' (que es el caso en este escenario).
    - **Detalle de `_convertPreviewToActiveTrip` (dentro de un bloque try/catch):**
      - **Bloque `try`:**
        - Si `mapboxMap` no es nulo:
          - Llama a `MapBusRealtime.stopPreviewAnimations()`.
          - Llama a `MapCleanup.clearPreviewBusElements()`.
          - Llama a `MapRouteRenderer.convertPreviewStylesToActiveTrip(activeTripState.tramosDelViaje)`.
          - Llama a `MapBusRealtime.initializeActiveTripTracking(activeTripState)`.
          - Llama a `MapCameraController.zoomToActiveTrip(activeTripState.tramosDelViaje)`.
      - **Bloque `catch` (si ocurre un error en `try`):**
        - Llama a `MapCleanup.clearAll()`.
        - Llama a `MapRouteRenderer.renderActiveTrip(activeTripState.tramosDelViaje)`.
        - Llama a `MapBusRealtime.initializeActiveTripTracking(activeTripState)`.

2.  **Limpieza general (si NO se vino de Preview, que no es el caso aquí):**

    - Llama a `MapCleanup.clearAll()`.
    - **Condición:** Si `_currentPhase` NO es 'route*preview'. *(Esta condición no se cumple en este escenario, por lo que `clearAll` no se llama aquí en el flujo descrito).\_

3.  **Renderizado del viaje activo (si NO se vino de Preview, que no es el caso aquí):**

    - Llama a `MapRouteRenderer.renderActiveTrip`
    - **Input:** `activeTripState.tramosDelViaje: List<TramoViajeMostrable>`.
    - **Condición:** Si `_currentPhase` NO es 'route*preview'. *(Esta condición no se cumple en este escenario, por lo que `renderActiveTrip` no se llama aquí en el flujo descrito, ya que el renderizado se maneja dentro de `_convertPreviewToActiveTrip` si hay un error).\_

4.  **Inicialización del tracking del bus en viaje activo (si NO se vino de Preview, que no es el caso aquí):**
    - Llama a `MapBusRealtime.initializeActiveTripTracking`
    - **Input:** `activeTripState: EstadoFaseViajeActivo`.
    - **Condición:** Si `_currentPhase` NO es 'route*preview'. *(Esta condición no se cumple en este escenario, por lo que `initializeActiveTripTracking` no se llama aquí directamente, ya que se llama dentro de `_convertPreviewToActiveTrip`).\_

**Resumen para la Acción 2 (Selección):** Dado que el usuario _viene_ de la fase de preview, el flujo principal se dirige a través de `_convertPreviewToActiveTrip`. Esto intenta una transición suave (detener animaciones de preview, limpiar elementos específicos de preview, potencialmente actualizar estilos de los elementos existentes) y luego inicializa el tracking del bus y centra la cámara en el viaje activo. Si esa transición falla, se realiza una limpieza completa (`clearAll`) y se renderiza el viaje activo desde cero (`renderActiveTrip`, `initializeActiveTripTracking`).
