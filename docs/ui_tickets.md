# Tickets MVP: Reconstrucción de la Capa de UI ("Abuelita First")

Este documento lista los tickets necesarios para rehacer completamente la capa de Interfaz de Usuario (UI) de la aplicación BondiUy, basándonos en la nueva arquitectura donde la UI es puramente presentacional y consume el estado definido en `AppUiState` (`lib/backend/contrato_ui/app_ui_state.dart`) y emite acciones a través de la interfaz `IAppLogic` (implementada por la capa de lógica).

La estrategia clave es **reutilizar al máximo los componentes visuales (widgets) del código antiguo**, limpiándolos de toda lógica de negocio y adaptándolos para que funcionen únicamente en base al `AppUiState` que reciben y llamando a las acciones de `IAppLogic` cuando el usuario interactúa.

Cada ticket incluirá referencias a las partes relevantes del código antiguo (`docs/arch/index.md` y los archivos descritos en él, como `MapScreen`, `SearchPanel`, etc.) para guiar la implementación.

**Instrucciones para completar tickets:** Una vez que hayas trabajado en un ticket y lo consideres completado, por favor, marca la casilla `[x]` del ticket correspondiente. Debajo del ticket, añade una sección de "Resumen y Comentarios" donde describas brevemente lo que se hizo y cualquier nota o comentario relevante para futuros tickets o para referencia.

---

## Tickets de UI - Fase 1 (MVP)

### 1. Configuración Inicial del Proyecto y Arquitectura Básica

- [ ] Tarea: Configurar la estructura inicial del proyecto Flutter para la capa de UI, asegurando que pueda recibir el `AppUiState` de la capa de lógica y enviar acciones.
  - Referencia código antiguo: Estructura general del proyecto y cómo se manejaba el estado global (ver `docs/arch/index.md`). Adaptar para la nueva arquitectura presentacional.
  - Comentarios:

### 2. Implementación de la Pantalla Principal (MapScreen Base)

- [ ] Tarea: Crear el widget base de la pantalla principal (`MapScreen`) que contendrá el mapa y los demás componentes de UI.
  - Referencia código antiguo: `lib/ui/screens/map/map_screen.dart`. Reutilizar la estructura visual pero eliminar toda lógica de negocio.
  - Comentarios:

### 3. Integración del Mapa

- [ ] Tarea: Integrar el widget del mapa en `MapScreen`. Este mapa debe ser puramente presentacional y mostrar la información (posición actual, ruta, paradas, etc.) según lo indique el `AppUiState`.
  - Referencia código antiguo: La implementación existente del mapa en `lib/ui/screens/map/map_screen.dart` y widgets relacionados. Adaptar para depender únicamente del estado de UI.
  - Comentarios:

### 4. Desarrollo del Panel de Búsqueda (SearchPanel)

- [ ] Tarea: Implementar el panel inferior (`SearchPanel`) que permite al usuario buscar destinos.
  - Referencia código antiguo: `lib/ui/components/search_panel.dart`. Reutilizar y adaptar para que solo emita eventos de búsqueda y muestre sugerencias según `AppUiState.searchResults`.
  - Comentarios:

### 5. Visualización de Resultados de Búsqueda y Sugerencias

- [ ] Tarea: Mostrar los resultados de búsqueda y sugerencias en el `SearchPanel` basándose en `AppUiState.searchResults`.
  - Referencia código antiguo: Lógica y widgets para mostrar sugerencias en `lib/ui/components/search_panel.dart`.
  - Comentarios:

### 6. Interacción con Resultados de Búsqueda (Selección de Destino)

- [ ] Tarea: Implementar la lógica de UI para seleccionar un destino de la lista de resultados de búsqueda, emitiendo la acción correspondiente a la capa de lógica.
  - Referencia código antiguo: Cómo se manejaba la selección de un destino en `lib/ui/components/search_panel.dart`.
  - Comentarios:

### 7. Visualización de la Ruta Sugerida (Preview del Trip)

- [ ] Tarea: Mostrar la ruta sugerida en el mapa y un resumen en la UI, basándose en `AppUiState.suggestedTrip`.
  - Referencia código antiguo: Cómo se visualizaba la ruta y el resumen del viaje (ver `docs/arch/index.md` para componentes relacionados con la visualización del trip).
  - Comentarios:

### 8. Botón "Comenzar Viaje"

- [ ] Tarea: Implementar el botón "Comenzar Viaje" que se activa cuando hay un `suggestedTrip` válido y emite la acción para iniciar el viaje.
  - Referencia código antiguo: El botón de inicio de viaje y su comportamiento.
  - Comentarios:

### 9. Transición a la Fase de Viaje Activo

- [ ] Tarea: Asegurar que la UI cambia al estado de "viaje activo" cuando `AppUiState.currentTrip` no es nulo, mostrando la información relevante del viaje en curso.
  - Referencia código antiguo: La UI durante un viaje activo.
  - Comentarios:

### 10. Visualización del Viaje Activo en el Mapa y UI

- [ ] Tarea: Mostrar el progreso del viaje actual en el mapa (posición del usuario, próximo punto clave, etc.) y actualizar la UI con información en tiempo real basándose en `AppUiState.currentTrip`.
  - Referencia código antiguo: Cómo se visualizaba un viaje en curso.
  - Comentarios:

### 11. Notificaciones y Alertas durante el Viaje

- [ ] Tarea: Implementar la visualización de notificaciones o alertas (ej: "próxima parada") basándose en el estado de `AppUiState`.
  - Referencia código antiguo: Sistema de notificaciones si existía.
  - Comentarios:

### 12. Botón "Finalizar Viaje"

- [ ] Tarea: Implementar el botón para finalizar el viaje activo.
  - Referencia código antiguo: Botón de finalizar viaje.
  - Comentarios:

### 13. Manejo de Errores y Estados Vacíos

- [ ] Tarea: Mostrar mensajes de error o estados vacíos claros en la UI basándose en el `AppUiState` (ej: no hay resultados de búsqueda, error al cargar mapa).
  - Referencia código antiguo: Cómo se manejaban los errores.
  - Comentarios:

### 14. Refinamiento de UX/UI General

- [ ] Tarea: Iterar sobre la UI implementada para asegurar que cumple con la filosofía "Abuelita First": minimalismo, claridad, facilidad de uso. Ajustar estilos, animaciones y flujos según sea necesario.
  - Referencia código antiguo: Aspectos visuales del proyecto anterior que se consideraban bien logrados.
  - Comentarios:

---

Esta lista cubre los componentes principales necesarios para el MVP. A medida que trabajemos en cada ticket, actualizaremos este documento con el estado de finalización y los comentarios relevantes.

---

## Tickets de UI (MVP)

### Ticket 1: Estructura Principal de la Aplicación y Manejo de Fases

**Objetivo:** Crear el widget raíz de la UI que observe el `AppUiState` global (probablemente a través de Riverpod) y renderice dinámicamente la pantalla o los componentes necesarios según la `faseActual` (`FaseApp`).

**Estado relevante en `AppUiState`:** `faseActual`, `mostrandoSpinnerGlobal`, `mensajeErrorGlobal`, `mensajeInfoGlobal`.

**Referencia código antiguo:** `lib/ui/screens/map_screen.dart` (`MapScreen` probablemente sea el punto de partida principal que contenía la estructura general de la pantalla). El manejo del estado global en el viejo `MapScreen` servirá como ejemplo de cómo reaccionar a cambios, pero _toda la lógica_ de cómo se calculan esos estados debe residir ahora en la capa de lógica y exponerse vía `AppUiState`.

**Detalles:**

- Configurar Riverpod en el nivel más alto (probablemente en `main.dart` o `lib/app.dart` envolviendo el widget principal con `ProviderScope`).
- Crear un widget principal (ej. `AppHost`, `MainScreen`) que observe el `mapNotifierProvider` (o como se defina el provider del `AppUiState`).
- Implementar un `Builder` o lógica condicional (`if/else` o `switch`) basada en `state.faseActual` para mostrar diferentes conjuntos de widgets (o pantallas) para cada fase: `INICIAL_SIN_BUSQUEDA`, `MOSTRANDO_OPCIONES_RUTA`, `VIAJE_ACTIVO_EN_CURSO`.
- Asegurar que se muestre un indicador de carga global (`mostrandoSpinnerGlobal`) y mensajes de error/información (`mensajeErrorGlobal`, `mensajeInfoGlobal`) según el estado.
- Integrar la inicialización del mapa base (Mapbox) en esta estructura.

---

### Ticket 2: Implementación de la Fase `INICIAL_SIN_BUSQUEDA` (Mapa Base y Búsqueda)

**Objetivo:** Implementar la UI de la fase inicial: mostrar el mapa con paradas (si las hay en el estado), y integrar el panel de búsqueda de Origen/Destino.

**Estado relevante en `AppUiState`:** `faseActual` (cuando es `INICIAL_SIN_BUSQUEDA`), `datosFaseInicial` (para `paradasVisiblesEnMapa`), `textoInputOrigenActual`, `sugerenciasOrigen`, `estadoSugerenciasOrigen`, `textoInputDestinoActual`, `sugerenciasDestino`, `estadoSugerenciasDestino`, `puntoOrigenParaBusqueda`, `nombreLugarOrigenSeleccionado`, `puntoDestinoParaBusqueda`, `nombreLugarDestinoSeleccionado`, `infoParadaConsultada`, `estadoInfoParadaConsultada`.

**Referencia código antiguo:**

- `lib/ui/screens/map_screen.dart` (estructura general del mapa y cómo se integraban otros widgets).
- `lib/widgets/search_panel.dart` (`SearchPanel` widget para la UI del panel superior).
- `lib/widgets/compose_with_origin.dart` (`ComposeWithOrigin` widget para los campos de entrada con sugerencias).
- Lógica en `MapInteractionController` y `MapboxService` del viejo código para mostrar paradas y manejar taps en ellas; esta lógica debe ser leída para entender _qué_ se mostraba, pero la _decisión_ de mostrar y la _información_ a mostrar vendrá del `AppUiState`.

**Detalles:**

- Reutilizar o adaptar el widget `SearchPanel` para que:
  - Lea `textoInputOrigenActual`, `textoInputDestinoActual` del `AppUiState`.
  - Reaccione a los cambios en `sugerenciasOrigen` y `sugerenciasDestino` para mostrar la lista de sugerencias (reutilizar `ComposeWithOrigin` y su lógica de suggestions overlay).
  - Cuando el usuario escriba, llame a las acciones `usuarioEscribioEnCampoOrigen`/`usuarioEscribioEnCampoDestino` de `IAppLogic`.
  - Cuando el usuario seleccione una sugerencia, llame a `seleccionarSugerenciaOrigen`/`seleccionarSugerenciaDestino`.
  - Cuando se toque "Buscar Ruta", verifique si `puntoOrigenParaBusqueda` y `puntoDestinoParaBusqueda` no son nulos en el estado y, si lo son, llame a `iniciarBusquedaDeRutas`. El estado `estadoSugerenciasOrigen`/`Destino` puede usarse para mostrar carga en los campos de búsqueda si la lógica lo actualiza.
  - Implementar la funcionalidad de limpiar campos (`onOrigenClear`, `onDestinoClear` llamando a `limpiarOrigenSeleccionado`/`limpiarDestinoSeleccionado`).
  - Implementar la funcionalidad de swap (`onSwap`).
  - Manejar el estado colapsado/expandido del panel (esto puede ser state interno del widget o manejarse via AppUiState si se considera relevante globalmente, aunque state local es más simple si solo afecta al panel).
- Integrar la visualización del mapa base.
- Integrar la visualización de las paradas (`datosFaseInicial.paradasVisiblesEnMapa`). La lógica de _cómo_ dibujar estas paradas en el mapa (usando la API de Mapbox) puede inspirarse en el código antiguo (`MapboxService`), pero los _datos_ y la _decisión_ de mostrar provienen del estado.
- Implementar el manejo del tap en una parada en el mapa. Esto debe llamar a `usuarioHizoTapEnParadaDelMapa(idParada)` en `IAppLogic`.
- Implementar la visualización de los detalles de una parada cuando `infoParadaConsultada` en el `AppUiState` no es nulo y `estadoInfoParadaConsultada` es `EXITO`. Esto probablemente implique un `showModalBottomSheet` reutilizando o adaptando la UI que se mostraba en el código antiguo para los detalles de parada. El modal debe poder cerrarse llamando a `usuarioDeseleccionoInformacionDeParada` o `cerrarDetallesDeParada`.

---

### Ticket 3: Implementación de la Fase `MOSTRANDO_OPCIONES_RUTA` (Panel de Opciones y Previsualización)

**Objetivo:** Mostrar la lista de opciones de ruta encontradas y permitir al usuario previsualizarlas en el mapa y seleccionar una para iniciar el viaje.

**Estado relevante en `AppUiState`:** `faseActual` (cuando es `MOSTRANDO_OPCIONES_RUTA`), `datosFaseOpcionesRuta` (para `opcionesDeRuta`), `idOpcionRutaPrevisualizada`.

**Referencia código antiguo:**

- `lib/widgets/route_options_panel.md` (`showRouteOptionsModal` y widgets relacionados para la UI de la lista de opciones).
- Lógica en `RouteDisplayController` y `MapboxService` del viejo código para dibujar rutas en el mapa.
- Lógica en `MapZoomController` para ajustar el zoom a la ruta.

**Detalles:**

- Cuando `faseActual` cambie a `MOSTRANDO_OPCIONES_RUTA` y `datosFaseOpcionesRuta.opcionesDeRuta` no esté vacío, mostrar un bottom sheet modal (o componente similar) con la lista de opciones.
- Reutilizar o adaptar la UI de `showRouteOptionsModal` para mostrar cada `OpcionDeRutaMostrable` de `datosFaseOpcionesRuta.opcionesDeRuta`. Adaptar la visualización para usar las propiedades del nuevo modelo (`duracionTotalSegundos`, `secuenciaModosIconos`, `distanciaTotalCaminataMetros`, `tiempoTotalEsperaBusSegundos`, `advertenciaPrincipal`, `esRecomendada`, `etaProximoBus`).
- Cuando el usuario toque una opción en la lista, llamar a `seleccionarOpcionDeRutaParaPrevisualizar(idOpcionRuta)` en `IAppLogic`.
- Observar `idOpcionRutaPrevisualizada` en el `AppUiState`. Cuando cambie (es decir, el usuario seleccionó una opción para preview), la UI del mapa debe dibujar los `tramosParaPreview` de la `OpcionDeRutaMostrable` correspondiente dentro de `datosFaseOpcionesRuta.opcionesDeRuta`. La lógica de _cómo_ dibujar las polilíneas y puntos en el mapa debe reutilizar partes de `MapboxService` y `RouteDisplayController`, pero la _fuente de los datos_ es el `AppUiState`.
- Implementar la acción de confirmar una opción de ruta (ej. un botón "Iniciar Viaje" dentro del modal o al seleccionar una opción previsualizada). Esto debe llamar a `confirmarOpcionDeRutaEIniciarViaje(idOpcionRuta)` en `IAppLogic`.
- Implementar la acción de cancelar la búsqueda de ruta o cerrar el modal, volviendo a la fase inicial. Esto debe llamar a `usuarioCanceloBusquedaOSeleccionRuta` en `IAppLogic`.

---

### Ticket 4: Implementación de la Fase `VIAJE_ACTIVO_EN_CURSO` (Instrucciones y Seguimiento)

**Objetivo:** Mostrar la UI cuando el usuario ha iniciado un viaje, presentando las instrucciones paso a paso, permitiendo navegar entre tramos y mostrando información de seguimiento en tiempo real si aplica.

**Estado relevante en `AppUiState`:** `faseActual` (cuando es `VIAJE_ACTIVO_EN_CURSO`), `datosFaseViajeActivo` (para `tramosDelViaje`, `opcionDeRutaSeleccionada`, `idTramoBusEnSeguimiento`, `posicionActualBusReal`, `minutosParaLlegadaBusReal`, `seguimientoBusRealDisponibleEnTramoActual`).

**Referencia código antiguo:**

- `lib/widgets/instructions_bar.dart` (barra de instrucciones colapsada con navegación).
- `lib/widgets/trip_instructions_sheet.md` (bottom sheet con lista completa de instrucciones).
- Lógica en `RouteDisplayController` para resaltar el tramo actual.
- Lógica en `BusTrackingController` para visualizar el bus en tiempo real.

**Detalles:**

- Cuando `faseActual` cambie a `VIAJE_ACTIVO_EN_CURSO`, mostrar la ruta completa en el mapa usando los `tramosDelViaje` de `datosFaseViajeActivo`.
- Implementar un panel de instrucciones inferior (puede ser una barra colapsada y un bottom sheet expandible) para mostrar la información del tramo actual.
- Reutilizar o adaptar `InstructionsBar` y `TripInstructionsSheet`.
- La barra colapsada debe mostrar información del tramo actual (ej. tipo, duración, descripción) y botones para navegar al tramo anterior/siguiente. Estos botones deben llamar a `navegarAAnteriorPasoInstrucciones`/`navegarASiguientePasoInstrucciones` en `IAppLogic`.
- La barra colapsada debe indicar el ETA del bus y si es en tiempo real, usando `minutosParaLlegadaBusReal` y `seguimientoBusRealDisponibleEnTramoActual` del estado (si `idTramoBusEnSeguimiento` no es nulo).
- Al tocar la barra colapsada, mostrar el bottom sheet con la lista completa de `tramosDelViaje`.
- El bottom sheet debe mostrar la lista detallada de los `TramoViajeMostrable` (`tipo`, `descripcion`, `duracionEstimadaSegundos`, `distanciaMetros`, etc.).
- Al seleccionar un tramo en la lista del bottom sheet, llamar a `usuarioSeleccionoPasoInstrucciones(indicePaso)` en `IAppLogic`.
- El mapa debe resaltar el tramo actualmente seleccionado, basado en el índice que la capa de lógica mantenga internamente (quizás necesitemos un campo `indiceTramoActual` en `EstadoFaseViajeActivo` o la lógica lo infiera del tramo seleccionado). La lógica de _cómo_ resaltar en el mapa reutiliza `MapboxService` y `RouteDisplayController`.
- Si `posicionActualBusReal` y `idTramoBusEnSeguimiento` están presentes en el estado, el mapa debe mostrar la posición del bus en tiempo real para ese tramo. Reutilizar lógica de `BusTrackingController` y `MapboxService` para dibujar y actualizar el marcador/segmento.
- Implementar una forma de "Finalizar Viaje" o "Cancelar Seguimiento" que llame a `detenerSeguimientoActivo` en `IAppLogic`.

---

### Ticket 5: Manejo de Interacciones del Mapa y Zoom

**Objetivo:** Conectar las interacciones del usuario con el mapa (mover, zoom) con la capa de lógica y asegurar que la UI del mapa reaccione correctamente a los objetivos de zoom definidos por el estado.

**Estado relevante en `AppUiState`:** `userMapInteraction`, `currentZoomTarget`, `currentCameraOptions`. (Aunque `currentCameraOptions` es más para la lógica/servicio, la UI debe poder leerlo o recibir los parámetros de zoom).

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

---

### Ticket 6: Refinamiento Visual y UX General

**Objetivo:** Asegurar que la UI tenga un acabado pulido, animaciones suaves, feedback adecuado al usuario y se adhiera estrictamente a los principios de UX "Abuelita First" en todos los flujos.

**Estado relevante en `AppUiState`:** General, aplicación de `mostrandoSpinnerGlobal`, `mensajeErrorGlobal`, `mensajeInfoGlobal`.

**Referencia código antiguo:** Estilos visuales, animaciones y transiciones presentes en los widgets existentes (`MapScreen`, `SearchPanel`, `RouteOptionsModal`, etc.).

**Detalles:**

- Revisar todas las transiciones entre fases y estados para asegurar que sean fluidas y no abruptas.
- Implementar feedback visual claro para los estados de carga (`mostrandoSpinnerGlobal`) y errores (`mensajeErrorGlobal`). Mostrar mensajes informativos (`mensajeInfoGlobal`) de forma no intrusiva.
- Ajustar estilos, paddings, tipografías y colores para maximizar la legibilidad y la claridad visual.
- Asegurar que los elementos interactivos (botones, ítems de lista) tengan estados visuales claros al ser presionados.
- Revisar los flujos de interacción (ej. seleccionar origen/destino, buscar, seleccionar ruta, navegar instrucciones) para simplificarlos aún más si es posible, eliminando pasos innecesarios o información redundante, siempre pensando en la "abuelita".
- Implementar animaciones sutiles donde sea apropiado para mejorar la sensación de respuesta (ej. al expandir/colapsar paneles, al seleccionar opciones).
- Realizar pruebas manuales exhaustivas en dispositivos reales para verificar la usabilidad en condiciones de la vida real (ej. en la calle, con una mano, bajo el sol).
