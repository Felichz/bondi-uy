# compose_with_origin.dart

**Ruta:** lib/widgets/compose_with_origin.dart

**Responsabilidad:**
Este widget `ComposeWithOrigin` proporciona un campo de texto (`TextField`) con funcionalidad de autocompletado avanzada, diseñado específicamente para la entrada de ubicaciones (origen o destino) en la aplicación. Se integra con un servicio de geocodificación para ofrecer sugerencias en tiempo real mientras el usuario escribe. Muestra las sugerencias en un overlay y permite al usuario seleccionar una, actualizando el campo de texto y notificando al widget padre sobre la ubicación seleccionada.

**Propiedades:**

- `controller`: `TextEditingController` para gestionar el texto del campo.
- `focusNode`: `FocusNode` para gestionar el foco del campo.
- `labelText`: Etiqueta para el campo de texto (por defecto 'Origen').
- `hintText`: Texto de sugerencia dentro del campo de texto.
- `onLocationSelected`: Callback que se ejecuta cuando una sugerencia es seleccionada, pasando el nombre completo del lugar y sus coordenadas (`[lng, lat]`).
- `geocodingService`: Instancia del servicio de geocodificación (`GeocodingService`) utilizado para obtener sugerencias.

**Estado Local:**

- `_layerLink`: `LayerLink` para posicionar el overlay de sugerencias correctamente.
- `_overlayEntry`: `OverlayEntry` que representa el overlay actualmente mostrado.
- `_debounceTimer`: `Timer` para implementar un retardo (debounce) en las llamadas al servicio de geocodificación.
- `_suggestions`: Lista de mapas (`List<Map<String, dynamic>>`) que almacena las sugerencias obtenidas del servicio de geocodificación.
- `_isLoading`: Booleano para indicar si se está cargando la lista de sugerencias (para mostrar un indicador).

**Entradas:**

- Entrada de texto del usuario en el `TextField`.
- Cambios en el foco del campo.
- Selección de una sugerencia de la lista.
- Resultados asíncronos del servicio de geocodificación.

**Salidas:**

- Actualizaciones en el `TextField` con el texto seleccionado.
- Visualización/ocultación del overlay de sugerencias.
- Llamada al callback `onLocationSelected` con los detalles de la ubicación seleccionada.
- Manejo del estado de carga.

**Dependencias Principales:**

- `package:flutter/material.dart`
- `dart:async`
- El servicio de geocodificación proporcionado a través de `geocodingService`.
