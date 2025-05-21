# Tickets MVP: Reconstrucción de la Capa de UI ("Abuelita First")

Este documento lista los tickets necesarios para rehacer completamente la capa de Interfaz de Usuario (UI) de la aplicación BondiUy, basándonos en la nueva arquitectura donde la UI es puramente presentacional y consume el estado definido en `AppUiState` (`lib/backend/contrato_ui/app_ui_state.dart`) y emite acciones a través de la interfaz `IAppLogic` (implementada por la capa de lógica).

La estrategia clave es **reutilizar al máximo los componentes visuales (widgets) del código antiguo**, limpiándolos de toda lógica de negocio y adaptándolos para que funcionen únicamente en base al `AppUiState` que reciben y llamando a las acciones de `IAppLogic` cuando el usuario interactúa.

Cada ticket incluirá referencias a las partes relevantes del código antiguo (`docs/arch/index.md` y los archivos descritos en él, como `MapScreen`, `SearchPanel`, etc.) para guiar la implementación.

---

## Tickets de Desarrollo - BondiUY Flutter Refactor UI Presentacional

**Prioridad:**

1.  Estructura Principal y Navegación entre Fases (Ticket 1)
2.  Fase `INICIAL_SIN_BUSQUEDA` (Mapa Base y Búsqueda) (Ticket 2)
3.  Interacciones del Mapa y Zoom (Ticket 5)
4.  Fase `MOSTRANDO_OPCIONES_RUTA` (Ticket 3)
5.  Fase `VIAJE_ACTIVO_EN_CURSO` (Ticket 4)
6.  UX: Animaciones y Transiciones (Ticket 6)
7.  UX: Manejo de Errores Detallado (Ticket 7)
8.  Pruebas y Refinamiento (Ticket 8)

---

### Ticket 1: Estructura Principal y Navegación entre Fases

- **Descripción:** Crear el widget principal de la UI (`AppHost`) que observe el `AppUiState` global y cambie la vista según `AppUiState.faseActual`. Implementar la estructura básica para el manejo de `mostrandoSpinnerGlobal` y mensajes globales.
- **Archivos Clave:**
  - `lib/ui/app_host.dart` (Nuevo)
  - `lib/main.dart` (para integrar `AppHost`)
  - `lib/backend/contrato_ui/app_ui_state.dart` (para `faseActual`, `mostrandoSpinnerGlobal`, `mensajeErrorGlobal`, `mensajeInfoGlobal`)
- **Estado:** `COMPLETADO`
- **Notas:** `AppHost` implementado. Maneja cambio de vistas (aunque las vistas en sí están vacías o son placeholders), spinner global y mensajes globales.

---

### Ticket 2: Implementación de la Fase `INICIAL_SIN_BUSQUEDA` (Mapa Base y Búsqueda)

- **Descripción:** Desarrollar la UI para la fase inicial, que incluye el mapa de fondo y el panel de búsqueda de origen/destino. El mapa mostrará paradas cercanas y permitirá interactuar con ellas. El panel de búsqueda permitirá al usuario ingresar origen y destino, mostrando sugerencias.
- **Archivos Clave:**
  - `lib/ui/initial_phase_view.dart` (Nuevo)
  - `lib/ui/widgets/app_search_panel.dart` (Adaptar de `old/lib/widgets/search_panel.dart`)
  - `lib/ui/widgets/app_compose_with_origin.dart` (Adaptar de `old/lib/widgets/compose_with_origin.dart`)
  - `lib/backend/contrato_ui/app_ui_state.dart` (para `datosFaseInicial`, `textoInputOrigenActual`, `sugerenciasOrigen`, `estadoSugerenciasOrigen`, etc.)
  - Interfaz `IAppLogic` (para acciones como `usuarioEscribioEnCampoOrigen`, `seleccionarSugerenciaOrigen`, `iniciarBusquedaDeRutas`, `usuarioHizoTapEnParadaDelMapa`, etc.)
- **Estado:** `COMPLETADO`
- **Sub-tareas (todas completadas):**
  - **Panel de Búsqueda (`AppSearchPanel` y `AppComposeWithOrigin`):** `COMPLETADO`
    - Adaptados del código antiguo para leer estado de `AppUiState` y llamar a `IAppLogic`.
    - Manejo de expansión del panel (`panelDeBusquedaExpandido`) globalmente a través de `AppUiState`.
    - Campos de origen/destino usan `AppComposeWithOrigin`.
    - `AppComposeWithOrigin` adaptado para funcionar con `AppUiState` (texto, sugerencias, estado de sugerencias) y callbacks a `IAppLogic`.
    - Botones de "intercambiar" y "buscar ruta" funcionales.
    - Indicador de carga para `estadoCalculoRuta` implementado.
    - Corrección de errores de linter relacionados.
  - **Mapa (Mapbox):** `COMPLETADO`
    - Integrar `MapboxMap` en `InitialPhaseView`.
    - Configurar cámara inicial (Montevideo).
    - Cargar íconos para paradas, origen y destino desde assets (con fallbacks).
    - Listener `onMapLoadErrorListener` para actualizar `AppUiState.mensajeErrorGlobal`.
    - Visualizar paradas (`InfoParadaEnMapa`) del `AppUiState` como capa de símbolos GeoJSON.
    - Manejar tap en paradas (`onTapListener`): consultar features, extraer ID, llamar a `appLogic.usuarioHizoTapEnParadaDelMapa()`. Si no es parada, llamar a `appLogic.usuarioDeseleccionoInformacionDeParada()`.
    - Visualizar marcadores de origen (`appUiState.puntoOrigenParaBusqueda`) y destino (`appUiState.puntoDestinoParaBusqueda`) con íconos/estilos diferenciados.
    - Lógica de zoom (`_zoomToFitPoints`) para centrar en origen/destino cuando cambian.
    - Listener `onMapIdleListener` para llamar a `appLogic.usuarioMovioMapaManualente()`.
  - **Modal de Detalles de Parada:** `COMPLETADO`
    - Mostrar `showModalBottomSheet` con `InfoDetalladaParada` cuando `appUiState.infoParadaConsultada` no es nulo.
    - El modal debe mostrar nombre, líneas, ETAs (diferenciando tiempo real) y botón de cerrar (`appLogic.usuarioDeseleccionoInformacionDeParada()`).
  - **Widgets Globales en `InitialPhaseView`:** `PARCIALMENTE COMPLETADO` (Existen en `AppHost`, verificar si se necesitan específicamente dentro de `InitialPhaseView` o si los de `AppHost` son suficientes).
- **Notas:** Todas las sub-tareas funcionales de UI para la fase inicial (panel de búsqueda, mapa base con marcadores e interacciones, modal de parada) están implementadas y conectadas a `AppUiState` y `IAppLogic`.

---

### Ticket 3: Implementación de la Fase `MOSTRANDO_OPCIONES_RUTA`

- **Descripción:** Desarrollar la UI que muestra las diferentes opciones de ruta encontradas. Esto incluirá un mapa con la ruta previsualizada y un panel inferior con la lista de opciones.
- **Archivos Clave:**
  - `lib/ui/route_options_view.dart` (Nuevo)
  - `lib/ui/widgets/route_option_list_item.dart` (Nuevo o adaptar)
  - `lib/backend/contrato_ui/app_ui_state.dart` (para `datosFaseOpcionesRuta`, `idOpcionRutaPrevisualizada`)
  - Interfaz `IAppLogic` (para `seleccionarOpcionDeRutaParaPrevisualizar`, `confirmarOpcionDeRutaEIniciarViaje`, `usuarioCanceloBusquedaOSeleccionRuta`)
- **Estado:** `COMPLETADO`
- **Sub-tareas (todas completadas):**
  - **Mapa en `RouteOptionsView`:** `COMPLETADO`
    - Integrar `MapboxMap`.
    - Cámara inicial centrada entre origen y destino.
    - `_displayRoutePreview()`: dibujar ruta preseleccionada (`appUiState.idOpcionRutaPrevisualizada`) con tramos de caminar (discontinua azul grisáceo), bus (sólida color primario), espera (círculo naranja).
    - `_clearRoutePreview()`: limpiar ruta.
    - Zoom a ruta previsualizada, considerando altura del panel.
    - `ref.listen` a `idOpcionRutaPrevisualizada` para actualizar mapa.
  - **Panel de Opciones (`_RouteOptionsPanel`):** `COMPLETADO`
    - Implementar como `DraggableScrollableSheet`.
    - Listar `OpcionDeRutaMostrable` usando `_RouteOptionListItem`.
    - `_RouteOptionListItem`: mostrar duración, llegada, secuencia íconos, advertencias, costo, ETA próximo bus. Destacar opción recomendada.
    - Seleccionar opción llama a `appLogic.seleccionarOpcionDeRutaParaPrevisualizar()`.
    - Botón "Confirmar y Seguir Viaje" (visible si opción seleccionada) llama a `appLogic.confirmarOpcionDeRutaEIniciarViaje()`.
    - Botón "Cancelar" llama a `appLogic.usuarioCanceloBusquedaOSeleccionRuta()`.
- **Notas:** La UI para mostrar opciones de ruta, previsualizarlas en el mapa y permitir la selección/confirmación está implementada y conectada a `AppUiState` y `IAppLogic`.

---

### Ticket 4: Implementación de la Fase `VIAJE_ACTIVO_EN_CURSO`

- **Descripción:** UI para mostrar la ruta activa, las instrucciones paso a paso y, opcionalmente, la posición del bus en tiempo real.
- **Archivos Clave:**
  - `lib/ui/active_trip_view.dart` (Nuevo)
  - `lib/ui/widgets/trip_instruction_list_item.dart` (Nuevo o adaptar)
  - `lib/backend/contrato_ui/app_ui_state.dart` (para `datosFaseViajeActivo`)
  - Interfaz `IAppLogic` (para `detenerSeguimientoActivo`, manejo de pasos de instrucciones)
- **Estado:** `INICIADO` (según resumen previo, pendiente de revisión detallada)
- **Sub-tareas:**
  - **Mapa en `ActiveTripView`:** `EN PROGRESO`
    - Integrar `MapboxMap`.
    - `_displayActiveRoute()`: dibujar ruta confirmada (`activeTripState.tramosDelViaje`) con estilos similares a previsualización y zoom.
    - `_clearActiveRoute()`.
  - **Panel de Instrucciones (`_ActiveTripInstructionsPanel`):** `EN PROGRESO`
    - Implementar como `DraggableScrollableSheet`.
    - Usar `_TramoInstruccionListItem` para mostrar cada tramo (ícono, descripción, duración, distancia, detalles línea bus).
    - Botón "Finalizar" llama a `appLogic.detenerSeguimientoActivo()`.
    - **Pendiente:** Integración `indiceTramoActual`, resaltado tramo actual, navegación entre tramos, visualización seguimiento bus.

---

### Ticket 5: Manejo de Interacciones del Mapa y Zoom

**Objetivo:** Conectar las interacciones del usuario con el mapa (mover, zoom) con la capa de lógica y asegurar que la UI del mapa reaccione correctamente a los objetivos de zoom definidos por el estado.

**Estado relevante en `AppUiState`:** `permitirZoomAutomaticoMapa`, `userMapInteraction` (conceptual, a implementar su efecto en la lógica), `currentZoomTarget` (conceptual).

**Referencia código antiguo:**

- `lib/controllers/map_interaction_controller.dart` (manejo de `onMapCameraChangeListener`, `onMapIdleListener`, `handleMapTapEvent`).
- `lib/controllers/map_zoom_controller.dart` (manejo de `handleZoomTarget`, `_performZoom`).
- `lib/services/mapbox_service.dart` (métodos de bajo nivel para interactuar con la API de Mapbox, como `flyTo`, `zoomToFitPositions`, `zoomToRouteBounds`, `zoomToLeg`).

**Detalles:**

- Configurar listeners en el widget del mapa para `onCameraChange`, `onIdle`, `onMapTap`, `onMapLongPress`.
- Cuando la cámara cambie (`onCameraChange`), si no es un cambio programático (la vieja lógica de `userMapInteraction` es útil aquí), llamar a `usuarioMovioMapaManualente(nuevoCentro, nuevoZoom)` en `IAppLogic`.
- Cuando el mapa esté inactivo (`onIdle`), la vieja lógica de `MapInteractionController` (`mapInteractionEnded`) puede inspirar cómo la UI avisa a la lógica que la interacción manual terminó.
- Cuando se haga tap en el mapa (`onMapTap`), llamar a `usuarioHizoTapEnMapa(coordenadaTocada)` en `IAppLogic`. Si el tap es en una parada, `IAppLogic` se encargará de actualizar el estado (`infoParadaConsultada`).
- Observar `currentZoomTarget` en `AppUiState`. Cuando cambie, usar la lógica (probablemente extraída de `MapZoomController` y usando métodos de `MapboxService`) para realizar la transición de cámara (`flyTo`, `zoomToFitBounds`, etc.) según el `ZoomTargetType` y los datos relevantes del estado (ej. `puntoOrigenParaBusqueda`, `puntoDestinoParaBusqueda`, `datosFaseOpcionesRuta.opcionesDeRuta` o `datosFaseViajeActivo.tramosDelViaje` dependiendo del target). Asegurarse de que los zooms automáticos no interrumpan si `userMapInteraction` indica que el usuario está moviendo el mapa manualmente.

**Estado:** `EN PROGRESO`.

- Los listeners del mapa en `InitialPhaseView` (`onTapListener`, `onMapIdleListener`) ya están configurados para notificar a `IAppLogic` sobre las interacciones del usuario.
- Se añadió `permitirZoomAutomaticoMapa` a `AppUiState` y `setPermitirZoomAutomaticoMapa(bool permitir)` a `IAppLogic`.
- **Avances en la UI:**
  - **Completado:** La lógica en `InitialPhaseView` (`_zoomToFitPoints`) ahora respeta `appUiState.permitirZoomAutomaticoMapa`.
  - **Completado:** `_onMapIdleListener` en `InitialPhaseView` ahora llama a `appLogic.setPermitirZoomAutomaticoMapa(false)` después de que el usuario mueve el mapa.
- **Pendiente (Lógica de Aplicación - `AppLogic`):**
  - Implementar la gestión de `permitirZoomAutomaticoMapa`:
    - Ponerlo a `false` cuando `usuarioMovioMapaManualente` es llamado (esto ya se hace desde la UI indirectamente, pero `AppLogic` debe manejar el estado).
    - Ponerlo a `true` después de acciones como `seleccionarSugerenciaOrigen`, `seleccionarSugerenciaDestino`, o cuando se inicia una nueva búsqueda de ruta, para permitir que el mapa se centre en los nuevos puntos.
  - Implementar cómo la UI reacciona a los objetivos de zoom (`currentZoomTarget` conceptual) provenientes del `AppUiState`, más allá del zoom inicial a origen/destino.

---

### Ticket 6: UX - Mejoras Visuales y Animaciones

- **Descripción:** Refinar la UX con animaciones, transiciones suaves entre estados y fases, y asegurar una apariencia pulcra y profesional.
- **Archivos Clave:** Afecta a múltiples widgets de UI.
- **Estado:** `PENDIENTE` (Más allá de `AnimatedCrossFade` en `AppSearchPanel`)
- **Sub-tareas:**
  - Animación de expansión/colapso del `AppSearchPanel`. (`AnimatedCrossFade` implementado, revisar si es suficiente).
  - Transiciones entre fases (`AppHost`).
  - Animaciones en la aparición de modales/paneles.
  - Feedback visual al seleccionar elementos.

---

### Ticket 7: UX - Manejo de Errores Detallado y Mensajes al Usuario

- **Descripción:** Asegurar que todos los posibles errores (de red, de lógica, de datos) se manejen elegantemente y se muestren mensajes claros y útiles al usuario.
- **Archivos Clave:** `AppHost` (para mensajes globales), y cualquier vista/widget que pueda originar/mostrar un error específico.
- **Estado:** `PENDIENTE` (Más allá de `mensajeErrorGlobal` y `mensajeInfoGlobal` básicos).

---

### Ticket 8: Pruebas y Refinamiento General

- **Descripción:** Pruebas exhaustivas de todas las funcionalidades en diferentes escenarios. Refinamiento de la performance y la estabilidad.
- **Estado:** `PENDIENTE`

Estos tickets cubren las principales áreas de la capa de UI necesarias para el MVP, organizados de forma que podamos construir la estructura base y luego ir implementando cada fase del flujo de usuario, reutilizando el trabajo visual existente y conectándolo a la nueva capa de lógica a través del contrato `AppUiState`/`IAppLogic`.
