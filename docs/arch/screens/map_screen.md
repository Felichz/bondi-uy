# map_screen.dart

**Ruta:** lib/screens/map_screen.dart

**Responsabilidad:**
Este archivo define la pantalla principal de la aplicación que muestra el mapa interactivo. Es responsable de inicializar y gestionar el mapa de Mapbox, manejar las interacciones del usuario (taps, long presses, cambios de cámara), mostrar la barra de búsqueda y los paneles de instrucciones, e integrar los servicios y proveedores de estado para la planificación de rutas y el seguimiento de autobuses en tiempo real.

**Propiedades/Estado (gestionado a través de Riverpod y estado local):**

- `mapboxMap`: Instancia del controlador del mapa de Mapbox.
- `_mapZoomController`: Controlador para gestionar los diferentes niveles de zoom y objetivos de la cámara.
- `_busTrackingController`: Controlador para el seguimiento de autobuses en tiempo real.
- `_routeDisplayController`: Controlador para la visualización de rutas en el mapa.
- `_mapInteractionController`: Controlador para manejar las interacciones del usuario con el mapa.
- `_origenController`, `_destinoController`: Controladores para los campos de texto de origen y destino en la barra de búsqueda.
- `_origenFocusNode`, `_destinoFocusNode`: Focus nodes para los campos de texto.
- `_mapboxService`: Instancia del servicio de Mapbox para operaciones de bajo nivel.
- `isSearchPanelExpanded`: `ValueNotifier` para controlar la expansión del panel de búsqueda.
- `_realtimeSnackbarShown`: Bandera para evitar mostrar repetidamente el snackbar de no disponibilidad de tiempo real.
- Estado reactivo de Riverpod (`mapState`) que incluye: `planningStatus`, `currentZoomTarget`, `currentDisplayMode`, `consolidatedItineraries`, `selectedConsolidatedItinerary`, `representativeItinerary`, `currentLegIndex`, `realtimeTrackingAttempted`, `realtimeTrackingAvailable`, `origin`, `destination`, `showInstructionsPanel`, `currentCameraOptions`.

**Entradas:**

- Interacciones del usuario en el mapa (tap, long press, movimiento).
- Entrada de texto en los campos de origen y destino.
- Selección de sugerencias de geocodificación.
- Selección de opciones de ruta.
- Cambios en el estado global de la aplicación a través de los proveedores de Riverpod.

**Salidas:**

- Actualizaciones visuales en el mapa (cámara, capas de ruta, marcadores).
- Disparo de procesos de planificación de ruta y geocodificación.
- Actualizaciones del estado global de la aplicación a través de `MapNotifier`.
- Visualización de modales y snackbars.

**Dependencias Principales:**

- `package:flutter/material.dart`
- `package:mapbox_maps_flutter/mapbox_maps_flutter.dart`
- `package:flutter_riverpod/flutter_riverpod.dart`
- `../models/itinerary.dart`
- `../models/route_leg.dart`
- `../widgets/search_panel.dart`
- `../widgets/instructions_bar.dart`
- `../widgets/route_options_panel.dart`
- `../widgets/trip_instructions_sheet.dart`
- `../services/mapbox_service.dart`
- `../services/geocoding_service.dart`
- `../providers/service_providers.dart`
- `../providers/map_notifier.dart`
- `../state/map_state.dart`
- `../controllers/map_zoom_controller.dart`
- `../controllers/bus_tracking_controller.dart`
- `../controllers/route_display_controller.dart`
- `../controllers/map_interaction_controller.dart`
- `../models/processed_itinerary.dart`
- `../models/point_dart.dart`
- `../models/bus_arrival_info.dart`
- `../models/consolidated_itinerary.dart`
- `../models/leg_mode_constants.dart`
