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
  - `lib/ui/overlays/route_options_overlay.dart` (Implementado - reemplaza RouteOptionsView)
  - `lib/ui/widgets/route_option_list_item.dart` (Integrado en overlay)
  - `lib/backend/contrato_ui/app_ui_state.dart` (para `datosFaseOpcionesRuta`, `idOpcionRutaPrevisualizada`)
  - Interfaz `IAppLogic` (para `seleccionarOpcionDeRutaParaPrevisualizar`, `confirmarOpcionDeRutaEIniciarViaje`, `usuarioCanceloBusquedaOSeleccionRuta`)
- **Estado:** ✅ **COMPLETADO**
- **Sub-tareas (todas completadas):**
  - **Mapa en `RouteOptionsOverlay`:** ✅ **COMPLETADO**
    - ✅ Integrar `MapboxMap` en overlay sobre mapa persistente de `AppHost`.
    - ✅ `_displayRoutePreview()`: dibujar ruta preseleccionada con estilos originales exactos (WALK sólido azul, BUS sólido naranja, WAIT círculos naranjas).
    - ✅ `_clearRoutePreview()`: limpiar ruta correctamente evitando errores concurrentes.
    - ✅ Zoom automático a ruta con padding ajustado (400px bottom) considerando altura del panel.
    - ✅ **`ref.listen` implementado**: escucha cambios en `idOpcionRutaPrevisualizada` para actualizar preview automáticamente.
    - ✅ **Error de cast corregido**: propiedades de color de `MapStyleConstants` usadas correctamente.
    - ✅ **Preview interactivo funcional**: cambia automáticamente al navegar entre opciones.
  - **Panel de Opciones (Carousel Moderno):** ✅ **COMPLETADO**
    - ✅ Implementado como panel fijo con `PageView` horizontal.
    - ✅ Cards modernas estilo Material Design con información completa.
    - ✅ Navegación por `PageController` sincronizada con preview del mapa.
    - ✅ Destacado visual de opción recomendada y seleccionada.
    - ✅ Información detallada: duración, llegada, ETA tiempo real, distancia caminata.
    - ✅ Iconografía clara de modos de transporte con conectores visuales.
    - ✅ Layout responsivo para pantallas pequeñas y medianas.
    - ✅ Botón "Confirmar" llama a `appLogic.confirmarOpcionDeRutaEIniciarViaje()`.
    - ✅ Botón "Cancelar" (X) llama a `appLogic.usuarioCanceloBusquedaOSeleccionRuta()`.
    - ✅ Indicadores de página modernos con dots animados.
- **Notas:** ✅ **Preview interactivo completamente funcional**. La UI muestra opciones de ruta con preview automático en el mapa, navegación fluida entre opciones, y confirmación de selección. El sistema de `ref.listen` asegura sincronización entre UI y backend.

---

### Ticket 4: Implementación de la Fase `VIAJE_ACTIVO_EN_CURSO`

- **Descripción:** UI para mostrar la ruta activa, las instrucciones paso a paso y, opcionalmente, la posición del bus en tiempo real.
- **Archivos Clave:**
  - `lib/ui/active_trip_view.dart` (Nuevo)
  - `lib/ui/widgets/trip_instruction_list_item.dart` (Nuevo o adaptar)
  - `lib/backend/contrato_ui/app_ui_state.dart` (para `datosFaseViajeActivo`)
  - Interfaz `IAppLogic` (para `detenerSeguimientoActivo`, manejo de pasos de instrucciones)
- **Estado:** `COMPLETADO`
  - **Sub-tareas (todas completadas):**
    - **Mapa en `ActiveTripView`:** `COMPLETADO`
      - Integrar `MapboxMap`: `COMPLETADO`.
      - `_displayActiveRoute()`: dibujar ruta confirmada (`activeTripState.tramosDelViaje`) con estilos diferenciados por tipo (caminar, bus, esperar): `COMPLETADO`.
      - `_clearActiveRoute()`: `COMPLETADO`.
      - Zoom inicial automático a la ruta completa: `COMPLETADO`.
      - Seguimiento de ubicación del usuario con FloatingActionButton toggle: `COMPLETADO`.
      - Visualización de marcador de ubicación del usuario en tiempo real: `COMPLETADO`.
      - Gestión de interacción manual vs. seguimiento automático: `COMPLETADO`.
  - **Panel de Instrucciones (`_ActiveTripInstructionsPanel`):** `COMPLETADO`
    - Implementar como `DraggableScrollableSheet`: `COMPLETADO`.
    - Usar `_TramoInstruccionListItem` para mostrar cada tramo (ícono, descripción, duración, distancia, detalles línea bus): `COMPLETADO`.
    - Botón "Finalizar" llama a `appLogic.detenerSeguimientoActivo()`: `COMPLETADO`.
    - Navegación entre tramos (botones siguiente/anterior, selección directa): `COMPLETADO`.
    - Indicador de progreso visual (paso X de Y): `COMPLETADO`.
    - Visualización de ETA del bus con indicador de tiempo real: `COMPLETADO`.
    - Resaltado tramo actual en el mapa con `_highlightCurrentLegOnMap`: `COMPLETADO`.
    - **Nota:** El `indiceTramoActual` se mantiene como estado interno de la UI (`_currentLegIndex`) siguiendo la arquitectura presentacional, no como parte del `AppUiState`.

---

### Ticket 5: Manejo de Interacciones del Mapa y Zoom (`REFACTORIZADO`)

**Descripción:** La lógica de zoom automático y la gestión de interacciones manuales con el mapa ahora residen completamente en la capa de UI. Cada vista (`InitialPhaseView`, `RouteOptionsView`, `ActiveTripView`) es responsable de observar los cambios relevantes en `AppUiState` (ej: selección de origen/destino, disponibilidad de opciones de ruta, inicio de viaje) y decidir localmente cómo y cuándo ajustar el zoom del mapa. La capa de lógica (`AppLogicNotifier`) ya no dicta el comportamiento del zoom.

**Estado Actual:** `COMPLETADO`

**Avances Completados:**

- **Backend (`app_ui_state.dart`)**:
  - ✅ Eliminado `bool permitirZoomAutomaticoMapa` de `AppUiState`.
  - ✅ Eliminado `ZoomTarget? zoomTargetActual` de `AppUiState`.
  - ✅ Eliminada la clase `ZoomTarget` y el enum `ZoomTargetType`.
  - ✅ Actualizado constructor y `copyWith` en `AppUiState` para reflejar estas eliminaciones.
- **Backend (`app_logic_provider.dart` e `IAppLogic`)**:
  - ✅ Eliminadas todas las asignaciones a `permitirZoomAutomaticoMapa` y `zoomTargetActual`.
  - ✅ Eliminado el método `setPermitirZoomAutomaticoMapa(bool permitir)` de `IAppLogic` y su implementación en `AppLogicNotifier`.
  - ✅ Implementado el método `setErrorGlobal` que faltaba en `AppLogicNotifier`.
- **UI (`InitialPhaseView`)**:
  - ✅ Eliminado el listener de `zoomTargetActual` en `initState`.
  - ✅ Eliminada la función `_performAutomaticZoom` obsoleta.
  - ✅ Limpieza de referencias a `permitirZoomAutomaticoMapa` en `_zoomToFitPoints`.
  - ✅ El zoom ahora se basa únicamente en cambios relevantes del estado (selección de origen/destino).

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

**Notas de Implementación:**

- ✅ **Refactorización Completada:** Todas las vistas (`InitialPhaseView`, `RouteOptionsView`, `ActiveTripView`) ahora implementan su propia lógica de zoom basada en cambios relevantes del `AppUiState`.
- ✅ **Dependencias Eliminadas:** Se eliminaron todas las referencias a `ZoomTarget`, `ZoomTargetType`, y `permitirZoomAutomaticoMapa` del codebase.
- ✅ **Compilación Exitosa:** La aplicación compila correctamente después del refactor.
- ✅ **Testing Básico:** La aplicación mantiene su funcionalidad de zoom automático al seleccionar origen/destino en `InitialPhaseView`.

**Consideraciones Adicionales:**

- Cada vista que contenga un mapa probablemente gestionará su propio `MapController`.
- La lógica para determinar los parámetros de cámara (bounds, centro/zoom) se basará en los datos del `AppUiState` y el contexto de la vista actual.
- **Referencia código antiguo para UI:** Aunque `MapZoomController` y la lógica de zoom en `MapboxService` ya no se usarán directamente debido al cambio de responsabilidades, los algoritmos de cálculo de bounds o ajustes de cámara podrían seguir siendo referencias útiles para implementar en la capa de UI.

---

### Ticket 6: UX - Mejoras Visuales y Animaciones

- **Descripción:** Refinar la UX con animaciones, transiciones suaves entre estados y fases, y asegurar una apariencia pulcra y profesional.
- **Archivos Clave:** Afecta a múltiples widgets de UI.
- **Estado:** `COMPLETADO`
- **Sub-tareas Completadas:**
  - ✅ **Transiciones entre fases (`AppHost`):** Implementado `AnimatedSwitcher` con slide + fade para cambios de vista, overlay animado para spinner global y mensajes de error/info con `TweenAnimationBuilder`.
  - ✅ **Animación mejorada del `AppSearchPanel`:** Añadido `AnimatedSize` para transiciones más fluidas entre estado compacto/expandido, mejores animaciones de opacidad.
  - ✅ **Feedback visual en botones:** Botón de intercambio origen/destino con estilo y animaciones, botón "Buscar Rutas" con `AnimatedContainer`, `AnimatedSwitcher` para ícono de carga, y estados visuales dinámicos.
  - ✅ **Animaciones en modales:** Modal de información de parada con `backgroundColor: Colors.transparent` y mejores transiciones.
  - ✅ **Animaciones en navegación de viaje activo:** Botones de navegación entre tramos con `AnimatedScale` y estados visuales, barra de progreso animada con `AnimatedFractionallySizedBox`.
  - ✅ **Tema cohesivo:** Implementado Material 3 con `ColorScheme.fromSeed` y colores característicos de transporte público.

**Mejoras implementadas:**

- Transiciones suaves entre todas las fases de la aplicación
- Feedback visual inmediato en interacciones del usuario
- Animaciones de carga y estados de botones
- Overlay global para mensajes y spinners con animaciones de entrada
- Navegación fluida entre tramos en viaje activo
- Estilo consistente y profesional en toda la aplicación
