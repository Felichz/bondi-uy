# trip_instructions_sheet.dart

**Ruta:** lib/widgets/trip_instructions_sheet.dart

**Responsabilidad:**
Este widget define el contenido del bottom sheet que se muestra al usuario cuando se expanden las instrucciones de la ruta. Presenta una lista detallada de cada tramo del itinerario seleccionado, incluyendo el modo de transporte, la distancia, la duración y los puntos de origen/destino de cada tramo. Permite al usuario seleccionar un tramo de la lista para resaltarlo en el mapa.

**Propiedades:**

- `legs`: Lista de objetos `RouteLeg` que componen el itinerario.
- `origenControllerText`, `destinoControllerText`: Texto de los controladores de origen y destino para mejorar la visualización de los nombres de inicio y fin de la ruta.
- `routeDisplayController`: Instancia del controlador de visualización de rutas (aunque parece que su uso directo dentro de este widget es limitado, se pasa como propiedad).
- `onLegSelected`: Callback que se ejecuta cuando el usuario selecciona un tramo de la lista, pasando el índice del tramo seleccionado.

**Estado Local:**

- `_pageController`: `PageController` utilizado potencialmente para controlar el desplazamiento si se usara un `PageView` (aunque actualmente se usa un `ListView`).

**Entradas:**

- La lista de tramos de la ruta (`legs`).
- El texto ingresado en los campos de origen y destino.
- La selección de un tramo por parte del usuario en la lista.
- Cambios en el estado global del tramo seleccionado (`currentLegIndex`) a través de `mapNotifierProvider`.

**Salidas:**

- Llamada al callback `onLegSelected` con el índice del tramo elegido.
- Visualización de la lista de instrucciones del itinerario.

**Dependencias Principales:**

- `package:flutter/material.dart`
- `package:flutter_riverpod/flutter_riverpod.dart`
- `package:bondi_uy/models/route_leg.dart`
- `package:bondi_uy/providers/map_notifier.dart`
- `package:bondi_uy/controllers/route_display_controller.dart`
