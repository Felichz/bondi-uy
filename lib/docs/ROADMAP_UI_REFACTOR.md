# Roadmap: Refactorización de la UI de Bondi UY

Este documento guía la refactorización de la interfaz de usuario de la aplicación Bondi UY, siguiendo una separación estricta entre la lógica de UI y la lógica de negocio, según la visión del producto.

## 0. Principios y Guías Generales

- **Separación Estricta de Capas:**
  - La capa de UI será completamente agnóstica a la lógica de negocio.
  - La UI consume un único `AppUiState` bien definido desde la capa de lógica.
  - La UI emite eventos a través de la interfaz `IAppLogic`.
  - Toda la interacción con SDKs de UI (Mapbox) es responsabilidad exclusiva de la capa UI.
  - La capa de lógica maneja todas las operaciones complejas y las interacciones con servicios externos (OTP, API de Montevideo).
- **Contrato Único:** El archivo `lib/backend/contrato_ui/app_ui_state.dart` (que define `AppUiState` y la interfaz conceptual `IAppLogic`) es el único punto de contacto entre la UI y la lógica.
- **Fases de la Aplicación (`FaseApp`):** El `AppUiState` se estructura en torno a `FaseApp` para representar estados semánticos de la aplicación. La UI reacciona a estos estados.
- **Datos Crudos:** La capa de lógica debe proveer datos lo más crudos posible (ej. duraciones en segundos, distancias en metros, sin colores predefinidos o texto formateado para la UI). La UI se encarga de la presentación.
- **Estado Interno de UI:** La UI puede manejar estados internos que no son relevantes para la lógica de negocio (ej. si un panel está expandido, qué opción de ruta se está previsualizando _localmente_ antes de confirmar, etc.).
- **Reutilización Inteligente:** Se analizará el código en `old/` para reutilizar lógica de UI, presentación o interacción con Mapbox que sea adaptable a la nueva arquitectura, siempre respetando la separación de capas.
- **Visión del Producto:** Las decisiones de UI se alinearán con las directrices de `@context.txt` y `REVIEW_GUIDELINES.md`.

## 1. Estado Actual del Proyecto (Nueva Arquitectura)

- **Contrato UI-Lógica (`lib/backend/contrato_ui/app_ui_state.dart`):**
  - [x] Definición de `AppUiState` (estructura general).
  - [x] Definición de `Coordenada`, `InfoParadaEnMapa`, `EtaMostrable`, `InfoDetalladaParada`, `EstadoSolicitud`.
  - [x] Definición de `TipoTramoViaje`, `TramoViajeMostrable`, `OpcionDeRutaMostrable`, `TipoAdvertenciaItinerario`.
  - [x] Definición de `FaseApp`: `INICIAL_SIN_BUSQUEDA`, `MOSTRANDO_OPCIONES_RUTA`, `VIAJE_ACTIVO_EN_CURSO`.
  - [x] Clases de estado para cada fase: `EstadoFaseInicial`, `EstadoFaseOpcionesRuta`, `EstadoFaseViajeActivo`.
  - [x] `AppUiState` contiene `faseActual` y datos de fase correspondientes, datos para consultas (`infoParadaConsultada`), y estados globales (errores, spinners).
  - [x] Interfaz conceptual `IAppLogic` definida con acciones para cada fase.
- **Capa de Lógica (`lib/backend/`):**
  - [x] `AppLogicNotifier` (`lib/backend/providers/app_logic_provider.dart`) implementa `IAppLogic` y gestiona `AppUiState`.
  - [x] Métodos de `IAppLogic` implementados con lógica simulada.
  - [x] Adaptadores de servicios simulados: `MontevideoApiServiceAdapter`, `ItineraryPlanningServiceAdapter`.
- **UI (`lib/ui/`):**
  - [x] `lib/main.dart` básico con `ProviderScope`.
  - [x] `lib/ui/app.dart` (contiene MaterialApp y configuración inicial).
  - [x] `lib/ui/screens/home_screen.dart`: Estructura principal implementada, reacciona a `AppUiState.faseActual` para mostrar vistas correspondientes (`InitialSearchView`, `RouteOptionsView`, `ActiveTripView`), integra `MainMapView` y maneja `mostrandoSpinnerGlobal`.
  - [~] `lib/ui/common/map/main_map_view.dart`: Inicialización básica de Mapbox (placeholder). Dibuja paradas (`paradasVisiblesEnMapa`), previsualización de ruta (`idOpcionRutaPrevisualizada`), y ruta de viaje activo. Interacciones de usuario y estilos avanzados pendientes.
  - [~] `lib/ui/features/initial_search/initial_search_view.dart` (incluye `search_input_panel.dart`): Implementados campos de texto para origen/destino. Llamadas a lógica para sugerencias y búsqueda. UI de sugerencias y otras funcionalidades (limpiar, intercambiar) pendientes o básicas.
  - [~] `lib/ui/features/route_options/route_options_view.dart`: Muestra lista de opciones de ruta con información básica. Confirmación de ruta implementada. Previsualización detallada en mapa, formato avanzado y carrusel pendientes.
  - [x] `lib/ui/features/active_trip/active_trip_display.dart` (usado dentro de `active_trip_view.dart`): Muestra lista de tramos del viaje activo con formato de duración. Funcionalidad de navegación entre tramos, resaltado de tramo actual y detalles de bus en tiempo real pendientes o en progreso.

## 2. Roadmap Detallado para la Capa de UI

### Fase 2.1: Pantalla Principal y Componentes Globales de UI (`home_screen.dart`)

- **Objetivo:** Establecer el layout principal de la aplicación que reacciona a `AppUiState` y coordina la visualización de los componentes de UI según la `FaseApp` actual.
- **Checklist:**
  - [x] **Layout General (`HomeScreen`):**
    - [x] Implementar un `Scaffold` principal.
    - [x] Integrar `MainMapView` (era `MapDisplay`) como el fondo principal.
    - [x] Condicionalmente mostrar diferentes "paneles" o "overlays" sobre el mapa según `AppUiState.faseActual`.
      - `FaseApp.INICIAL_SIN_BUSQUEDA`: Mostrar `InitialSearchView` (que contiene `SearchInputsPanel`). Panel para `InfoDetalladaParada` pendiente.
      - `FaseApp.MOSTRANDO_OPCIONES_RUTA`: Mostrar `RouteOptionsView`.
      - `FaseApp.VIAJE_ACTIVO_EN_CURSO`: Mostrar `ActiveTripView` (que contiene `ActiveTripDisplay`).
    - [x] Manejar `AppUiState.mostrandoSpinnerGlobal` para mostrar un indicador de carga global.
    - [ ] Manejar `AppUiState.mensajeErrorGlobal` y `AppUiState.mensajeInfoGlobal` para mostrar diálogos o snackbars.
  - [ ] **Componente de Mapa Interactivo (`MainMapView`):**
    - [~] Inicializar Mapbox SDK (responsabilidad de la UI - placeholder existe).
    - [~] Recibir y reaccionar a los datos del `AppUiState` relevantes para el mapa:
      - [x] `EstadoFaseInicial.paradasVisiblesEnMapa`: Dibujar marcadores de paradas (implementado).
      - [~] `OpcionDeRutaMostrable.tramosParaPreview` (cuando `idOpcionRutaPrevisualizada` está seteado): Dibujar la polilínea de la ruta previsualizada (mapa reacciona, UI para setearlo desde `RouteOptionsView` pendiente).
      - [~] `EstadoFaseViajeActivo.tramosDelViaje`: Dibujar la polilínea del viaje activo (implementado).
      - [ ] `EstadoFaseViajeActivo.posicionActualBusReal`: Dibujar marcador del bus en tiempo real.
      - [ ] `InfoDetalladaParada.posicion`: Potencialmente centrar o destacar la parada consultada.
    - [ ] Permitir interacciones del usuario con el mapa (pan, zoom, tap).
      - [ ] Notificar a `IAppLogic.viewportDelMapaCambio()` cuando el viewport cambie por acción del usuario.
      - [ ] Notificar a `IAppLogic.usuarioHizoTapEnParadaDelMapa()` al tocar un marcador de parada.
      - [ ] Notificar a `IAppLogic.usuarioHizoTapEnMapa()` al tocar un punto genérico (para deseleccionar paradas, etc.).
    - [ ] Implementar estilos de mapa (colores, grosor de líneas para rutas, etc.) definidos por la UI.
    - **Comparativa con `old/`:** Revisar `old/lib/widgets/map_widget.dart`, `old/lib/screens/map_screen.dart` y `MapboxService` para la lógica de interacción con Mapbox (dibujar polilíneas, marcadores, manejar taps, etc.). Adaptar esta lógica a la nueva arquitectura, asegurando que `MainMapView` solo consuma `AppUiState` y llame a `IAppLogic`.

### Fase 2.2: UI para Fase `INICIAL_SIN_BUSQUEDA`

- **Objetivo:** Implementar la UI para la búsqueda de origen y destino, y la visualización de información de paradas.
- **Checklist:**
  - [~] **Panel de Búsqueda de Origen/Destino (`SearchInputPanel` en `initial_search_view.dart`):**
    - [x] Dos campos de texto para "Origen" y "Destino".
    - [~] Integrar funcionalidad de autocompletado/sugerencias:
      - [x] Al escribir, llamar a `IAppLogic.usuarioEscribioEnCampoOrigen()` / `...Destino()`.
      - [ ] Mostrar `AppUiState.sugerenciasOrigen` / `...Destino` en una lista desplegable (UI de lista pendiente).
      - [~] Al seleccionar una sugerencia, llamar a `IAppLogic.seleccionarSugerenciaOrigen()` / `...Destino()` (Llamada existe, UI de selección pendiente).
      - [ ] Manejar `AppUiState.estadoSugerenciasOrigen` / `...Destino` para mostrar indicadores de carga/error en las sugerencias.
    - [ ] Botones para limpiar campos (`IAppLogic.limpiarOrigenSeleccionado()` / `...DestinoSeleccionado()`).
    - [ ] Botón para intercambiar origen y destino.
    - [~] Botón "Buscar Rutas":
      - [ ] Debe estar habilitado solo si hay origen y destino válidos (`AppUiState.puntoOrigenParaBusqueda` y `AppUiState.puntoDestinoParaBusqueda` no son nulos).
      - [x] Al presionarlo, llamar a `IAppLogic.iniciarBusquedaDeRutas()` (Implementado).
    - [ ] El panel debe poder colapsarse/expandirse (estado interno de UI).
    - **Comparativa con `old/`:** Revisar `old/lib/widgets/search_panel.dart` y `old/lib/widgets/compose_with_origin.dart` para la UI y lógica de los campos de texto, sugerencias (TypeAhead), y manejo de foco. Adaptar la UI manteniendo la funcionalidad, pero conectándola a `IAppLogic` y `AppUiState`.
  - [ ] **Visualización de Información de Parada (`StopInfoPanel` o similar):**
    - [ ] Mostrar cuando `AppUiState.infoParadaConsultada` no es nulo.
    - [ ] Mostrar `InfoDetalladaParada.nombreParada`, `InfoDetalladaParada.idParada`.
    - [ ] Listar `InfoDetalladaParada.lineasQuePasan`.
    - [ ] Listar `InfoDetalladaParada.etas` (cada `EtaMostrable`):
      - [ ] Formatear `minutosParaLlegada` (ej. "5 min", "Llegando").
      - [ ] Indicar si es `esTiempoReal`.
      - [ ] Mostrar `linea` y `destino`.
    - [ ] Botón para cerrar/deseleccionar (`IAppLogic.usuarioDeseleccionoInformacionDeParada()` o `cerrarDetallesDeParada()`).
    - [ ] Manejar `AppUiState.estadoInfoParadaConsultada` para mostrar carga/error.
    - **Comparativa con `old/`:** Revisar cómo se mostraban los detalles de la parada en `old/lib/controllers/map_interaction_controller.dart` (`_requestBusLinesForStopModal`) y adaptar el diseño del panel.

### Fase 2.3: UI para Fase `MOSTRANDO_OPCIONES_RUTA`

- **Objetivo:** Implementar la UI para mostrar las opciones de ruta al usuario, permitir la previsualización y la selección de una ruta para iniciar el viaje.
- **Checklist:**
  - [~] **Visualizador de Opciones de Ruta (`RouteOptionsView`):**
    - [x] Mostrar cuando `AppUiState.faseActual == FaseApp.MOSTRANDO_OPCIONES_RUTA` y `AppUiState.datosFaseOpcionesRuta` no es nulo.
    - [x] Listar cada `OpcionDeRutaMostrable` de `datosFaseOpcionesRuta.opcionesDeRuta`.
    - [~] Para cada opción:
      - [ ] Mostrar `secuenciaModosIconos` (ej. iconos de caminar, bus).
      - [x] Mostrar `duracionTotalSegundos` (formateada por UI).
      - [x] Mostrar `horaLlegadaEstimada` (formateada por UI).
      - [x] Mostrar `distanciaTotalCaminataMetros` (formateada por UI).
      - [ ] Mostrar `advertenciaPrincipal` (mapeada a texto/icono por UI).
      - [x] Indicar si `esRecomendada` (se muestra texto).
      - [x] Si tiene `etaProximoBus`, mostrarlo (se muestra texto).
    - [ ] Permitir al usuario seleccionar una opción para previsualizarla:
      - [ ] Al seleccionar, llamar a `IAppLogic.seleccionarOpcionDeRutaParaPrevisualizar()`.
      - [~] La UI (`MainMapView`) reaccionará a `AppUiState.idOpcionRutaPrevisualizada` para dibujar los `tramosParaPreview` de la opción seleccionada en el mapa (Mapa lo hace, pero `RouteOptionsView` no llama a `seleccionarOpcionDeRutaParaPrevisualizar` en hover/tap simple, solo confirma).
    - [ ] Implementar el flujo de "carrusel" o navegación entre opciones con una preseleccionada como recomendada (según `@context.txt`).
    - [x] Botón "Iniciar Viaje" para la opción previsualizada/seleccionada (Tap en item llama a `confirmarOpcionDeRutaEIniciarViaje`).
    - [x] Botón para cancelar/volver a la búsqueda (`IAppLogic.usuarioCanceloBusquedaOSeleccionRuta()` - implementado con botón de retroceso).
    - **Comparativa con `old/`:** Revisar `old/lib/widgets/route_options_panel.dart` (`showRouteOptionsModal`). Adaptar la presentación de las opciones y la lógica de selección. El manejo de previsualización en el mapa es nuevo y debe hacerse a través de `AppUiState.idOpcionRutaPrevisualizada`.

### Fase 2.4: UI para Fase `VIAJE_ACTIVO_EN_CURSO`

- **Objetivo:** Implementar la UI que muestra los detalles del viaje en curso, permite la navegación entre tramos y muestra información de seguimiento en tiempo real.
- **Checklist:**
  - [~] **Panel de Viaje Activo (`ActiveTripDisplay` en `active_trip_view.dart`):**
    - [x] Mostrar cuando `AppUiState.faseActual == FaseApp.VIAJE_ACTIVO_EN_CURSO` y `AppUiState.datosFaseViajeActivo` no es nulo.
    - [~] Mostrar un resumen del viaje (origen/destino general, basado en `datosFaseViajeActivo.opcionDeRutaSeleccionada`) (lista de tramos actual da idea general).
    - [x] Listar cada `TramoViajeMostrable` de `datosFaseViajeActivo.tramosDelViaje`.
      - [~] Para cada tramo:
        - [ ] Icono según `TipoTramoViaje`.
        - [x] `descripcion`.
        - [x] `duracionEstimadaSegundos` (formateada por UI).
        - [x] `distanciaMetros` (formateada por UI, si aplica).
        - [ ] Detalles específicos del tipo (nombre línea, paradas, etc.).
      - [ ] Resaltar visualmente el "tramo actual" (la UI debe determinar cuál es el tramo actual basado en `AppUiState.datosFaseViajeActivo.idTramoBusEnSeguimiento` o un estado interno de UI para el índice del tramo que el usuario está viendo).
    - [ ] Si `datosFaseViajeActivo.idTramoBusEnSeguimiento` está seteado y es un tramo de bus:
      - [ ] Mostrar `datosFaseViajeActivo.minutosParaLlegadaBusReal` (formateado, "En vivo").
      - [ ] Mostrar `datosFaseViajeActivo.posicionActualBusReal` (si la UI decide mostrarlo, ej. texto o en mapa).
      - [ ] Indicar si `datosFaseViajeActivo.seguimientoBusRealDisponibleEnTramoActual` es falso.
    - [ ] Permitir al usuario navegar entre tramos (botones "anterior"/"siguiente" o seleccionando de la lista).
      - [ ] Al cambiar de tramo, llamar a `IAppLogic.usuarioSeleccionoTramoDelViaje()`. Esto podría hacer que la lógica inicie/detenga el seguimiento en tiempo real si el nuevo tramo es un bus diferente.
      - [ ] El `MainMapView` se actualizará para resaltar el tramo correcto en el mapa (basado en el estado interno de UI que refleja el índice del tramo activo, y la lógica que actualiza `idTramoBusEnSeguimiento` en `AppUiState`).
    - [ ] Botón para detener/cancelar el viaje (`IAppLogic.detenerSeguimientoActivo()` o similar, que llevaría a `INICIAL_SIN_BUSQUEDA`).
    - **Comparativa con `old/`:** Revisar `old/lib/widgets/instructions_bar.dart` y `old/lib/widgets/trip_instructions_sheet.dart`. La idea es similar, pero ahora la lista de tramos y la información de ETA vienen directamente de `AppUiState.datosFaseViajeActivo`. La interacción para cambiar de tramo y el seguimiento de bus real debe coordinarse con `IAppLogic`.

## 3. Pendientes y Próximos Pasos Generales

- [ ] **Refinamiento de `AppUiState` y `IAppLogic`:** A medida que desarrollemos la UI, podríamos necesitar pequeños ajustes o adiciones al contrato. Siempre se discutirán primero.
- [ ] **Manejo Detallado de Errores y Estados de Carga:** Asegurar que la UI muestre feedback apropiado para todos los `EstadoSolicitud` y errores globales/específicos.
- [ ] **Estilos y Diseño Visual:** Aplicar un diseño visual coherente y atractivo, siguiendo la visión del producto.
- [ ] **Pruebas:** Planificar pruebas unitarias y de widgets para la UI.
- **Integración de Lógica Real:** Eventualmente, la capa de lógica reemplazará las implementaciones simuladas con las reales. La UI no debería cambiar debido a esto si el contrato se respeta.

---

Este es un borrador inicial. Podemos refinarlo y añadir más detalles a medida que avanzamos.
¿Te parece un buen punto de partida?
