# lib/controllers/route_display_controller.dart

Este archivo define la clase `RouteDisplayController`, responsable de gestionar la visualización de rutas de transporte público en el mapa utilizando la API de Mapbox.

## `RouteDisplayController` (Clase):

Encapsula la lógica para dibujar, actualizar y limpiar las capas de ruta en el mapa, basándose en los itinerarios planificados. Trabaja en conjunto con `MapboxService` para las operaciones de bajo nivel de Mapbox y con `MapNotifier` para acceder al estado actual de la aplicación.

### Responsabilidades:

- Limpiar cualquier capa de ruta previamente mostrada en el mapa.
- Procesar una lista de `RouteLeg`s (tramos de ruta) y dibujar cada segmento en el mapa con el estilo apropiado según el modo de transporte (caminar, bus, etc.).
- Decodificar las polilíneas de los tramos para obtener las coordenadas geográficas.
- Ocultar/mostrar las paradas relevantes en el mapa en función de la visualización de la ruta.
- Aplicar estilos de visualización de ruta (ej. vista general).
- Resaltar un tramo específico de la ruta seleccionada en el mapa.
- Integrarse con `MapboxService` para las interacciones directas con el mapa.
- Acceder al estado global de la aplicación a través de Riverpod (`MapNotifier`) para determinar qué ruta y qué tramo deben ser visualizados o resaltados.

### Propiedades Internas:

- `mapboxService`: Instancia de `MapboxService` para interactuar con la API de Mapbox.
- `ref`: Referencia a `WidgetRef` de Riverpod, utilizada para leer el estado (`MapState`) a través de `mapNotifierProvider`.
- Constantes estáticas (`OTP_ROUTE_SOURCE_PREFIX`, `OTP_ROUTE_LAYER_PREFIX`) para nombrar las fuentes y capas de datos de la ruta en Mapbox.

### Constructor:

- `RouteDisplayController({required this.mapboxService, required this.ref})`:
  - **Descripción**: Inicializa el controlador inyectando las dependencias necesarias: una instancia de `MapboxService` y una referencia a `WidgetRef` de Riverpod.
  - **Entradas**: `mapboxService` (instancia de `MapboxService`), `ref` (referencia a `WidgetRef`).
  - **Salidas/Efectos**: Crea una instancia del controlador lista para gestionar la visualización de rutas.

### Métodos:

- `clearPreviousRouteLayers()`:

  - **Descripción**: Elimina todas las capas y fuentes de datos de ruta previamente añadidas al mapa y restaura la visibilidad de la capa de paradas (si existe).
  - **Entradas**: Ninguna.
  - **Salidas**: Un `Future<void>` que completa cuando las capas han sido eliminadas.
  - **Efectos**: Llama a métodos de `MapboxService` para interactuar con el estilo del mapa. Puede imprimir errores de depuración.

- `dispose()`:

  - **Descripción**: Método para liberar recursos si fuera necesario. Actualmente no realiza ninguna acción específica.
  - **Entradas**: Ninguna.
  - **Salidas**: Ninguna.
  - **Efectos**: Ninguno significativo en la implementación actual.

- `processAndDisplaySelectedItineraryUI(List<RouteLeg> legs)`:

  - **Descripción**: Dibuja los tramos de una lista de `RouteLeg`s en el mapa. Itera sobre cada tramo, decodifica su polilínea, determina el color y estilo de la línea según el modo de transporte y utiliza `MapboxService` para dibujar el segmento correspondiente. También oculta la capa general de paradas y muestra las paradas relevantes para la ruta.
  - **Entradas**: `legs` (Una lista de objetos `RouteLeg`).
  - **Salidas**: Un `Future<bool>` que resuelve a `true` si la ruta fue procesada y dibujada con éxito, `false` si la lista de tramos está vacía.
  - **Efectos**: Interactúa extensivamente con `MapboxService` para dibujar líneas y gestionar la visibilidad de capas. Decodifica polilíneas. Aplica estilos de línea.

- `applyOverviewRouteStyle()`:

  - **Descripción**: Aplica un estilo de visualización que muestra la ruta completa (vista general).
  - **Entradas**: Ninguna.
  - **Salidas**: Un `Future<void>`.
  - **Efectos**: Llama a `mapboxService.applyOverviewRouteStyle()`.

- `updateMapRouteHighlight()`:
  - **Descripción**: Resalta el tramo de ruta actualmente seleccionado en el mapa. Lee el índice del tramo seleccionado del estado de Riverpod (`mapNotifierProvider`) y llama a `MapboxService` para aplicar el resaltado visual.
  - **Entradas**: Ninguna (lee el estado directamente).
  - **Salidas**: Un `Future<void>`.
  - **Efectos**: Lee el estado global. Llama a `mapboxService.updateMapRouteHighlight()` para modificar el estilo visual de las capas de ruta.

## Entradas:

- Depende de una instancia de `MapboxService` y una referencia a `WidgetRef` (Riverpod) inyectadas en el constructor.
- Recibe una lista de `RouteLeg`s para dibujar (`processAndDisplaySelectedItineraryUI`).
- Lee el estado global de la aplicación (`MapState`) a través de Riverpod para determinar qué tramo resaltar (`updateMapRouteHighlight`).

## Salidas/Efectos:

- Modifica visualmente el mapa de Mapbox añadiendo, eliminando, o actualizando capas de línea y puntos.
- Oculta o muestra capas existentes (ej. capa de paradas).
- Abstracta la complejidad de la interacción de bajo nivel con la API de Mapbox para la visualización de rutas.
- Proporciona métodos para controlar la apariencia de la ruta en respuesta a las acciones del usuario (selección de itinerario, selección de tramo).
