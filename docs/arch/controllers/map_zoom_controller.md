# lib/controllers/map_zoom_controller.dart

Este archivo define la clase `MapZoomController`, encargada de gestionar los diferentes niveles y objetivos de zoom del mapa en la aplicación, basándose en el estado de la UI y las interacciones del usuario.

## `MapZoomController` (Clase):

Coordina las acciones de zoom del mapa para centrar la vista en puntos específicos (origen/destino), la ruta completa, un tramo individual de la ruta, o volver a la vista inicial. Utiliza `MapboxService` para las operaciones de zoom de bajo nivel y `MapNotifier` para leer el estado relevante del mapa.

### Responsabilidades:

- Manejar diferentes tipos de objetivos de zoom (`ZoomTargetType`).
- Implementar un mecanismo de "debounce" para agrupar múltiples solicitudes de zoom consecutivas y ejecutar solo la última, mejorando el rendimiento.
- Realizar transiciones de cámara suaves (flyTo) a las ubicaciones o rutas deseadas.
- Ajustar el zoom para que se ajusten a la pantalla puntos específicos (origen, destino, ambos) o la extensión de la ruta.
- Gestionar el zoom a un tramo individual de la ruta, potencialmente incluyendo la posición actual de un bus rastreado si aplica.
- Evitar realizar zooms automáticos si el usuario está interactuando manualmente con el mapa.
- Acceder al estado global del mapa (`MapState`) a través de Riverpod para obtener la información necesaria (ubicaciones de origen/destino, itinerarios, índice del tramo seleccionado, estado de interacción del usuario, posición del bus en tiempo real).

### Propiedades Internas:

- `mapboxMap`: Instancia del controlador del mapa de Mapbox para ejecutar comandos de cámara.
- `mapboxService`: Instancia de `MapboxService`, utilizada para métodos de zoom y ajuste a límites más complejos (`zoomToFitPositions`, `zoomToRouteBounds`, `zoomToLeg`).
- `ref`: Referencia a `WidgetRef` de Riverpod para leer el estado de la aplicación.
- `_zoomDebounceTimer`: Un `Timer` para implementar el retardo (debounce) en las acciones de zoom.
- `initialCameraOptions`: Una constante estática que define la vista de cámara inicial por defecto (centrada en Montevideo).

### Constructor:

- `MapZoomController({required this.mapboxMap, required this.mapboxService, required this.ref})`:
  - **Descripción**: Inicializa el controlador inyectando las dependencias necesarias: la instancia del mapa de Mapbox, una instancia de `MapboxService`, y una referencia a `WidgetRef` de Riverpod.
  - **Entradas**: `mapboxMap` (instancia de `MapboxMap`), `mapboxService` (instancia de `MapboxService`), `ref` (referencia a `WidgetRef`).
  - **Salidas/Efectos**: Crea una instancia del controlador lista para gestionar el zoom.

### Métodos:

- `handleZoomTarget(ZoomTargetType zoomTargetType)`:

  - **Descripción**: Es el punto de entrada principal para solicitar una acción de zoom. Aplica un retardo (`_debounceZoom`) antes de ejecutar la acción de zoom real (`_performZoom`) para evitar zooms excesivos si el estado cambia rápidamente.
  - **Entradas**: `zoomTargetType` (Un valor del enum `ZoomTargetType` que indica el objetivo del zoom).
  - **Salidas**: Ninguna (la acción es asíncrona y no retorna un valor directamente).
  - **Efectos**: Inicia o cancela un `Timer`. Llama a `_performZoom` después del retardo.

- `_debounceZoom(VoidCallback zoomAction)` (Método Privado):

  - **Descripción**: Implementa la lógica del debounce. Cancela cualquier timer anterior y programa una nueva ejecución de `zoomAction` después de un corto retraso.
  - **Entradas**: `zoomAction` (La función a ejecutar después del debounce).
  - **Salidas**: Ninguna.
  - **Efectos**: Manipula el `_zoomDebounceTimer`.

- `_performZoom(ZoomTargetType zoomTargetType)` (Método Privado):

  - **Descripción**: Ejecuta la acción de zoom real basada en el `zoomTargetType` proporcionado. Lee el estado actual del mapa desde Riverpod y utiliza `MapboxMap` o `MapboxService` para realizar la transición de cámara correspondiente (zoom a puntos, zoom a ruta, zoom a tramo, etc.). Incluye lógica para evitar el zoom automático si el usuario está interactuando y para incluir la posición del bus si se hace zoom a un tramo de bus con seguimiento en tiempo real disponible.
  - **Entradas**: `zoomTargetType` (Un valor del enum `ZoomTargetType`).
  - **Salidas**: Un `Future<void>` que completa cuando la acción de zoom ha terminado.
  - **Efectos**: Lee el estado global (`MapState`). Llama a métodos de `MapboxMap` (`flyTo`) o `MapboxService` (`zoomToFitPositions`, `zoomToRouteBounds`, `zoomToLeg`) para modificar la vista del mapa.

- `_zoomToLeg(List<RouteLeg> legs, int legIndex, Position? busToInclude)` (Método Privado):

  - **Descripción**: Método helper para hacer zoom específicamente a un tramo de ruta. Calcula los límites del tramo y llama a `MapboxService.zoomToLeg` para ajustar la cámara. Considera si se debe incluir la posición de un bus (`busToInclude`) en el cálculo de los límites y ajusta el padding en función de si el panel de instrucciones está colapsado o expandido.
  - **Entradas**: `legs` (Lista de `RouteLeg`s del itinerario), `legIndex` (Índice del tramo a enfocar), `busToInclude` (Posición opcional de un bus a incluir en la vista).
  - **Salidas**: Un `Future<void>`.
  - **Efectos**: Lee el estado del panel de instrucciones. Llama a `mapboxService.zoomToLeg`.

- `dispose()`:
  - **Descripción**: Cancela el timer de debounce para evitar fugas de memoria.
  - **Entradas**: Ninguna.
  - **Salidas**: Ninguna.
  - **Efectos**: Cancela `_zoomDebounceTimer`.

## Entradas:

- Depende de instancias de `MapboxMap`, `MapboxService`, y `WidgetRef` (Riverpod) inyectadas en el constructor.
- Recibe el tipo de objetivo de zoom (`ZoomTargetType`) a través de `handleZoomTarget`.
- Lee el estado global del mapa (`MapState`) desde Riverpod.

## Salidas/Efectos:

- Controla la vista de la cámara del mapa de Mapbox (posición, zoom, animación).
- Ajusta los límites visibles del mapa para incluir puntos o rutas específicas.
- Se adapta a la interacción del usuario para evitar zooms automáticos intrusivos.
- Utiliza el estado de la aplicación para determinar el objetivo de zoom adecuado y los datos necesarios (ubicaciones, ruta, tramo seleccionado).
