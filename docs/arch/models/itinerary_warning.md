# lib/models/itinerary_warning.dart

Este archivo define estructuras de datos para representar advertencias relacionadas con los itinerarios de viaje.

## Responsabilidades:

- Definir los posibles tipos de advertencias que pueden ocurrir en un itinerario (`ItineraryWarningType`).
- Representar una advertencia específica con su tipo y un mensaje descriptivo (`ItineraryWarning`).

## `ItineraryWarningType` (Enum):

Enumera las posibles condiciones de advertencia, como tiempo de caminata excesivo, problemas con la información de llegada en tiempo real, errores de API, etc.

## `ItineraryWarning` (Clase):

### Propiedades:

- `type`: El tipo de advertencia, tomado del enum `ItineraryWarningType` (requerido).
- `message`: Un mensaje descriptivo detallando la advertencia (String, requerido).

### Entradas:

- El constructor requiere un `type` y un `message`.

### Salidas/Efectos:

- Provee una estructura estandarizada para reportar y manejar advertencias dentro de la lógica de procesamiento de itinerarios.
- La implementación de `toString`, `==`, y `hashCode` facilita la depuración y comparación de advertencias.
