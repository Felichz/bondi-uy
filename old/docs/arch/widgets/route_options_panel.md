# route_options_panel.dart

**Ruta:** lib/widgets/route_options_panel.dart

**Responsabilidad:**
Este archivo contiene la función `showRouteOptionsModal` que presenta un bottom sheet modal al usuario con las diferentes opciones de ruta (itinerarios consolidados) encontradas por el servicio de planificación. Muestra un resumen de cada opción, incluyendo la duración total, los modos de transporte utilizados, información de ETA para el primer bus (si aplica) y advertencias relevantes. Permite al usuario seleccionar una de las opciones para visualizarla en el mapa.

**Función Principal (`showRouteOptionsModal`):**

- Recibe el `BuildContext` y un callback `processAndDisplaySelectedItinerary`.
- Utiliza `showModalBottomSheet` para mostrar el modal.
- Dentro del modal, usa un `Consumer` de Riverpod para observar el estado de planificación (`planningStatus`) y la lista de itinerarios consolidados (`consolidatedItineraries`) desde `mapNotifierProvider`.
- Muestra un indicador de carga, un mensaje de error o la lista de itinerarios según el estado de planificación.
- La lista de itinerarios se construye utilizando el widget helper `_buildContent`.

**Función Helper (`_buildContent`):**

- Recibe el contexto, el estado de planificación, la lista de itinerarios consolidados y el callback de selección.
- Construye la lista de `ListTile` para cada itinerario consolidado.
- Cada `ListTile` muestra un resumen visual del itinerario con iconos de modo de transporte, duración, y información adicional como tiempo de caminata, espera del primer bus, ETAs alternativos y advertencias.
- Llama al callback `processAndDisplaySelectedItinerary` cuando se selecciona un itinerario de la lista.

**Función Helper (`_getWarningMessage`):**

- Traduce los tipos de advertencia (`ItineraryWarningType`) a mensajes de texto amigables para el usuario.

**Entradas:**

- `BuildContext`.
- Callback `processAndDisplaySelectedItinerary`.
- Estado de Riverpod (`PlanningStatus`, `consolidatedItineraries`, `representativeFirstBusETAInfo`, `alternativeFirstBusETAs`, `warnings`).

**Salidas:**

- Presentación del modal de opciones de ruta.
- Llamada al callback `processAndDisplaySelectedItinerary` con el itinerario seleccionado por el usuario.

**Dependencias Principales:**

- `package:flutter/material.dart`
- `package:flutter_riverpod/flutter_riverpod.dart`
- `../models/processed_itinerary.dart`
- `../models/consolidated_itinerary.dart`
- `../models/consolidated_itinerary_leg.dart`
- `../models/route_leg.dart`
- `../models/leg_mode_constants.dart`
- `../providers/map_notifier.dart`
- `../state/map_state.dart`
- `../models/itinerary_warning.dart`

```

```
