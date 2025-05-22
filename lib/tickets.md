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
- **Estado:** `EN PROGRESO`
- **Sub-tareas:**
  - **Mapa en `ActiveTripView`:** `EN PROGRESO`
    - Integrar `MapboxMap`: `COMPLETADO`.
    - `_displayActiveRoute()`: dibujar ruta confirmada (`activeTripState.tramosDelViaje`) con estilos similares a previsualización: `EN PROGRESO` (dibujo básico implementado).
    - `_clearActiveRoute()`: `COMPLETADO`.
    - **Gestión de cámara y zoom por `ActiveTripView`:** `EN PROGRESO` (Adaptar a la nueva arquitectura UI-driven)
      - Resueltos errores de compilación en `ActiveTripView` relacionados con `CoordinateBounds` y `cameraForCoordinateBounds` del SDK de Mapbox v2.8.0.
        - Al iniciar el viaje (transición a `datosFaseViajeActivo`), `ActiveTripView` decidirá hacer zoom para mostrar la ruta completa y la ubicación del usuario, basándose en los datos de `AppUiState`.
        - `ActiveTripView` gestionará la opción de seguir la ubicación del usuario, actualizando la cámara del mapa según sea necesario. (`PENDIENTE`)
        - `ActiveTripView` ajustará el zoom/vista a medida que el usuario avanza (ej. al acercarse a la siguiente instrucción/parada), basándose en los datos de `AppUiState.datosFaseViajeActivo`. (`PENDIENTE`)
        - La interacción manual del usuario con el mapa en `ActiveTripView` pausará/modificará el comportamiento de seguimiento o zoom automático local.
  - **Panel de Instrucciones (`_ActiveTripInstructionsPanel`):** `EN PROGRESO`
    - Implementar como `DraggableScrollableSheet`: `COMPLETADO`.
    - Usar `_TramoInstruccionListItem` para mostrar cada tramo (ícono, descripción, duración, distancia, detalles línea bus): `EN PROGRESO` (listado básico y resaltado visual del tramo actual implementado, pero `indiceTramoActual` es un placeholder).
    - Botón "Finalizar" llama a `appLogic.detenerSeguimientoActivo()`: `COMPLETADO`.
    - **Pendiente:**
        - Integración `indiceTramoActual`: `BLOQUEADO` (requiere actualización de `EstadoFaseViajeActivo` en `app_ui_state.dart` para proveer el índice real).
        - Resaltado tramo actual (en el mapa, ej. con `_highlightCurrentLeg`): `PENDIENTE`.
        - Navegación entre tramos (botones siguiente/anterior, selección directa): `PENDIENTE`.
        - Visualización seguimiento bus en tiempo real (si aplica): `PENDIENTE`.

---

### Ticket 5: Manejo de Interacciones del Mapa y Zoom (`REFACTORIZADO`)

**Descripción:** La lógica de zoom automático y la gestión de interacciones manuales con el mapa ahora residen completamente en la capa de UI. Cada vista (`InitialPhaseView`, `RouteOptionsView`, `ActiveTripView`) es responsable de observar los cambios relevantes en `AppUiState` (ej: selección de origen/destino, disponibilidad de opciones de ruta, inicio de viaje) y decidir localmente cómo y cuándo ajustar el zoom del mapa. La capa de lógica (`AppLogicNotifier`) ya no dicta el comportamiento del zoom.

**Estado Actual:** `EN PROGRESO (Backend Completo, UI Mayormente Implementada)`

**Avances Backend (Realizados):**
- **`app_ui_state.dart`**:
    - Eliminado `bool permitirZoomAutomaticoMapa` de `AppUiState`.
    - Eliminado `ZoomTarget? zoomTargetActual` de `AppUiState`.
    - Eliminada la clase `ZoomTarget` y el enum `ZoomTargetType`.
    - Actualizado constructor y `copyWith` en `AppUiState` para reflejar estas eliminaciones.
- **`app_logic_provider.dart` (`AppLogicNotifier`) e `IAppLogic`**:
    - Eliminadas todas las asignaciones a `permitirZoomAutomaticoMapa` y `zoomTargetActual`.
    - Eliminado el método `setPermitirZoomAutomaticoMapa(bool permitir)` de `IAppLogic` y su implementación en `AppLogicNotifier`.
        - Si `true`: `permitirZoomAutomaticoMapa = true`.

**Estado Anterior de la UI (Pre-Refactorización - Conservado como referencia histórica):**
- **`InitialPhaseView.dart`**:
    - Implementado `_performAutomaticZoom(ZoomTarget target)` para manejar `ZoomTargetType.PARADA_ESPECIFICA` y `ZoomTargetType.PUNTOS_ORIGEN_DESTINO`.
    - Añadido listener en `initState` para `zoomTargetActual` que, si `permitirZoomAutomaticoMapa` es true, llama a `_performAutomaticZoom`.
    - `_onMapIdleListener` existente ya gestiona la desactivación de `permitirZoomAutomaticoMapa` en interacción manual.
- **`RouteOptionsView.dart`**:
    - Lógica de zoom desacoplada de `_displayRoutePreview()`.
    - Implementado `_performAutomaticZoom(ZoomTarget target)` para manejar `ZoomTargetType.RUTA_COMPLETA` y `ZoomTargetType.BOUNDS`, usando `cameraForBounds`.
    - Añadido listener en `initState` para `zoomTargetActual` que llama a `_performAutomaticZoom`.
    - Implementado `_handleMapIdle` (conectado a `onCameraIdleListener` del `MapWidget`) para gestionar interacciones manuales y llamar a `setPermitirZoomAutomaticoMapa(false)`.
- **`ActiveTripView.dart`**:
    - Implementado `_performAutomaticZoom(ZoomTarget target)` para manejar `ZoomTargetType.BOUNDS` (para la ruta completa al inicio) y `ZoomTargetType.UBICACION_USUARIO`.
    - Añadido listener en `initState` para `zoomTargetActual` que, si `permitirZoomAutomaticoMapa` es true, llama a `_performAutomaticZoom`.
    - Implementado `_handleMapIdle` (conectado a `addOnMapIdleListener`) para gestionar interacciones manuales y llamar a `setPermitirZoomAutomaticoMapa(false)`.

**Próximos Pasos (UI - Post-Refactorización):**
- **Revisión y Adaptación de Vistas:**
    - Cada vista (`InitialPhaseView`, `RouteOptionsView`, `ActiveTripView`) debe implementar su propia lógica para observar los cambios en `AppUiState` y determinar si se requiere un ajuste de zoom (ej: al seleccionar origen/destino, al recibir nuevas opciones de ruta, al iniciar un viaje).
      - `ActiveTripView` ha sido actualizada para usar los métodos correctos del SDK Mapbox v2.8.0 (`cameraForCoordinateBounds`, `CoordinateBounds` con `infiniteBounds`) para el cálculo de opciones de cámara.
    - La lógica para calcular los `LatLngBounds` o el centro/zoom específico para el mapa residirá dentro de cada vista o en helpers dedicados a la UI.
    - La interacción manual del usuario con el mapa en una vista específica pausará o modificará el comportamiento de zoom automático local de esa vista.
      - El manejo de eventos de inactividad del mapa (`onMapIdleListener`) ha sido refactorizado en `RouteOptionsView` y `ActiveTripView` para alinearse con el SDK v2.8.0, utilizando el parámetro `MapWidget.onMapIdleListener`.
- **Eliminar Dependencias de `ZoomTarget` y `permitirZoomAutomaticoMapa`:**
    - Remover cualquier uso restante de `ZoomTarget`, `ZoomTargetType`, y la lógica que dependía de `permitirZoomAutomaticoMapa` del `AppUiState` en todas las vistas.
- **Testing:**
    - Probar todos los escenarios de zoom automático (selección de O/D, previsualización de ruta, selección de parada).
    - Probar que el zoom manual interrumpe correctamente el zoom automático.
    - Asegurar transiciones suaves.

**Consideraciones Adicionales:**
- Cada vista que contenga un mapa probablemente gestionará su propio `MapController`.
- La lógica para determinar los parámetros de cámara (bounds, centro/zoom) se basará en los datos del `AppUiState` y el contexto de la vista actual.
- **Referencia código antiguo para UI:** Aunque `MapZoomController` y la lógica de zoom en `MapboxService` ya no se usarán directamente debido al cambio de responsabilidades, los algoritmos de cálculo de bounds o ajustes de cámara podrían seguir siendo referencias útiles para implementar en la capa de UI.

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
