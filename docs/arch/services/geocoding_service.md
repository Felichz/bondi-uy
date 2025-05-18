# lib/services/geocoding_service.dart

Este archivo define un servicio para realizar operaciones de geocodificación, específicamente para obtener sugerencias de lugares utilizando la API de Mapbox Geocoding.

## `GeocodingService` (Clase):

Encapsula la lógica para interactuar con el servicio de geocodificación de Mapbox.

### Responsabilidades:

- Realizar llamadas a la API de Mapbox Geocoding para obtener sugerencias de lugares.
- Procesar la respuesta de la API y retornar una lista de resultados.

### Métodos:

- `fetchSuggestions(String query)`:
  - **Descripción**: Busca sugerencias de lugares (direcciones, puntos de interés, etc.) basándose en una cadena de texto de consulta.
  - **Entradas**: `query` (String), la cadena de texto a buscar.
  - **Salidas**: Un `Future` que resuelve a una `List<Map<String, dynamic>>`, donde cada mapa representa una sugerencia de lugar con sus detalles. Retorna una lista vacía en caso de error o no encontrar resultados.
  - **Efectos**: Realiza una solicitud HTTP GET a la API de Mapbox Geocoding. Depende de `MAPBOX_ACCESS_TOKEN` de `mapbox_constants.dart` para la autenticación.

## Entradas:

- Depende de `mapbox_constants.dart` para el token de acceso a Mapbox.
- Utiliza la librería `http` para realizar solicitudes web.

## Salidas/Efectos:

- Provee una funcionalidad para autocompletar entradas de ubicación o buscar puntos geográficos.
- Los resultados obtenidos (`List<Map<String, dynamic>>`) contienen información estructurada sobre los lugares encontrados (nombre, coordenadas, etc.), que puede ser utilizada por otras partes de la aplicación (ej. la UI o servicios de planificación de rutas).
