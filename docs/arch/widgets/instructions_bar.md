# instructions_bar.dart

**Ruta:** lib/widgets/instructions_bar.dart

**Responsabilidad:**
Este widget es responsable de mostrar la barra de instrucciones de viaje en la parte inferior de la pantalla del mapa cuando una ruta ha sido planificada y un tramo específico está seleccionado. Proporciona una interfaz colapsada para navegar entre los tramos de la ruta y un bottom sheet expandido que muestra la lista completa de instrucciones del itinerario seleccionado. También muestra información de ETA en tiempo real si está disponible para el tramo de autobús actual.

**Propiedades:**

- `currentRouteLegs`: Lista de objetos `RouteLeg` que representan los tramos de la ruta actual.
- `selectedLegIndex`: El índice del tramo de ruta actualmente seleccionado/resaltado.
- `showCollapsedInstructionsBar`: Booleano para controlar la visibilidad de la barra colapsada.
- `origenControllerText`, `destinoControllerText`: Texto de los controladores de origen y destino para mostrar nombres de lugares ingresados por el usuario si no hay nombres disponibles en los datos de la ruta.
- `isInOverviewMode`: Booleano que indica si el mapa está en modo de vista general de la ruta completa.
- `onLegSelectedInBottomSheet`: Callback que se llama cuando un tramo es seleccionado en el bottom sheet expandido.
- `onNavigateToPreviousLeg`: Callback para navegar al tramo anterior.
- `onNavigateToNextLeg`: Callback para navegar al tramo siguiente.
- `onExpandInstructionsTap`: Callback opcional que se llama al tocar la barra colapsada (alternativa a abrir el bottom sheet).
- `realtimeEtaMinutes`: Minutos estimados de llegada en tiempo real para el tramo de autobús seleccionado (si aplica).
- `trackedBusLineShortNameForEta`: Nombre corto de la línea de autobús para la que se muestra la ETA (para asegurar que la ETA corresponde al tramo actual).
- `isHighlightedBusReal`: Booleano que indica si el autobús del ETA es un vehículo real rastreado o una estimación programada.

**Entradas:**

- Interacciones del usuario (tap en la barra, tap en los botones de navegación, tap en los ítems de la lista en el bottom sheet).
- Datos de la ruta (`currentRouteLegs`, `selectedLegIndex`).
- Estado de visualización del mapa (`showCollapsedInstructionsBar`, `isInOverviewMode`).
- Información de ETA en tiempo real.

**Salidas:**

- Llamadas a los callbacks proporcionados para navegar entre tramos o seleccionar un tramo desde la lista.
- Presentación del bottom sheet con la lista completa de instrucciones.

**Dependencias Principales:**

- `package:flutter/material.dart`
- `dart:math`
- `../models/route_leg.dart`
