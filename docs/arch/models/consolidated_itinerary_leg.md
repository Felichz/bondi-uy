# lib/models/consolidated_itinerary_leg.dart

Este archivo define el modelo de datos para un tramo individual (`ConsolidatedItineraryLeg`) dentro de un itinerario consolidado. Estos tramos son componentes de un `ConsolidatedItinerary` y pueden representar segmentos simples (como caminar o esperar) o segmentos más complejos (como un tramo de bus que agrupa múltiples líneas).

## `ConsolidatedItineraryLeg` (Clase):

Representa un segmento consolidado de un viaje, diseñado para la presentación en la interfaz de usuario de un itinerario consolidado.

### Responsabilidades:

- Representar un tramo del itinerario que puede ser de diferentes modos (caminata, bus, espera, etc.).
- Para tramos de bus consolidados, agrupar información de las líneas alternativas y mantener referencias a los tramos originales.
- Almacenar la duración y distancia del tramo.
- Contener los puntos de inicio y fin del tramo.
- Proveer información relevante para la UI, como el nombre de la línea (si aplica) y el color de la ruta.

### Propiedades:

- `mode`: El modo de transporte o tipo de tramo (String, ej. 'WALK', 'BUS', utilizando constantes de `LegModeConstants`).
- `duration`: Duración del tramo (`Duration`, requerido).
- `distance`: Distancia cubierta en el tramo (double, requerido).
- `from`: Punto de inicio del tramo (`LegEndpoint`, requerido).
- `to`: Punto de fin del tramo (`LegEndpoint`, requerido).
- `alternativeLineShortNames`: Lista de nombres cortos de líneas alternativas para tramos de bus consolidados (`List<String>`, opcional).
- `originalBusLegs`: Lista de los objetos `RouteLeg` originales que este tramo consolida (solo para tramos de bus) (`List<RouteLeg>`, por defecto vacía).
- `headsign`: El destino o dirección principal del tramo de bus (String, opcional).
- `routeColor`: Color asociado a la ruta principal del tramo (Color de Flutter, opcional).

### Getters:

- `isConsolidatedBusLeg`: Indica si este tramo es un tramo de bus consolidado (tiene múltiples líneas alternativas).
- `representativeRoute`: Devuelve el objeto `LegRoute` del primer `originalBusLeg`, útil para obtener información de la línea representativa.

### Entradas:

- El constructor requiere `mode`, `duration`, `distance`, `from`, y `to`. Las propiedades específicas de bus y `headsign`/`routeColor` son opcionales o tienen valores por defecto.

### Salidas/Efectos:

- Provee una representación simplificada y agrupada de un tramo de viaje, adecuada para mostrar en la interfaz de usuario.
- Permite el acceso a detalles subyacentes (via `originalBusLegs`) si es necesario.
