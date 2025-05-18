# search_panel.dart

**Ruta:** lib/widgets/search_panel.dart

**Responsabilidad:**
Este widget proporciona la interfaz de usuario para que el usuario ingrese el origen y el destino de su viaje. Tiene dos estados: colapsado (mostrando solo el origen y destino seleccionados) y expandido (mostrando campos de entrada interactivos con sugerencias de geocodificación y un botón para buscar ruta). Gestiona la interacción con los campos de texto, integra el servicio de geocodificación para autocompletar y notifica al padre (MapScreen) sobre las selecciones de ubicación y el inicio de la búsqueda de ruta.

**Propiedades:**

- `origenController`, `destinoController`: `TextEditingController` para los campos de entrada de texto.
- `origenFocusNode`, `destinoFocusNode`: `FocusNode` para gestionar el foco de los campos de texto.
- `origenCoordinates`, `destinoCoordinates`: Coordenadas (`Point_dart`) de las ubicaciones seleccionadas.
- `geocodingService`: Instancia del servicio de geocodificación para obtener sugerencias.
- `isCalculatingRoute`: Booleano que indica si el proceso de búsqueda de ruta está en curso (para deshabilitar el botón).
- `onSearchRoute`: Callback que se ejecuta cuando el usuario presiona el botón "Buscar Ruta".
- `onOrigenSelected`, `onDestinoSelected`: Callbacks que se ejecutan cuando el usuario selecciona una sugerencia para el origen o destino, pasando las coordenadas (`Point_dart`) y el nombre de la dirección.
- `initialExpandedState`: Booleano para establecer el estado inicial de expansión del panel.
- `onOrigenClear`, `onDestinoClear`: Callbacks para manejar la limpieza de los campos de origen y destino.
- `onSwap`: Callback opcional para intercambiar origen y destino.
- `onToggleExpansion`: Callback opcional que se llama cuando el panel cambia su estado de expansión.

**Estado Local:**

- `_isSearchPanelExpanded`: Booleano para controlar el estado actual de expansión del panel.

**Entradas:**

- Entrada de texto del usuario en los campos de origen y destino.
- Selección de sugerencias de la lista desplegable.
- Tap en el botón "Buscar Ruta".
- Tap para colapsar/expandir el panel.
- Estado de carga del proceso de búsqueda de ruta (`isCalculatingRoute`).

**Salidas:**

- Actualizaciones en los campos de texto y la lista de sugerencias.
- Llamadas a los callbacks (`onOrigenSelected`, `onDestinoSelected`, `onSearchRoute`, `onOrigenClear`, `onDestinoClear`, `onSwap`, `onToggleExpansion`) para comunicar las acciones y selecciones al widget padre.
- Cambios visuales entre el estado colapsado y expandido.

**Dependencias Principales:**

- `package:flutter/material.dart`
- `package:flutter_typeahead/flutter_typeahead.dart`
- `../services/geocoding_service.dart`
- `../models/point_dart.dart`
- `package:flutter_riverpod/flutter_riverpod.dart`
- `../providers/service_providers.dart`

```

```
