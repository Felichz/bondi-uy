# lib/main.dart

Este archivo es el punto de entrada principal de la aplicación Flutter.

## Responsabilidades:

- Inicialización de los bindings de Flutter (`WidgetsFlutterBinding.ensureInitialized`).
- Inicialización de la configuración de la aplicación, incluyendo el token de acceso de Mapbox (`initializeAppConfig`).
- Ejecución del widget raíz de la aplicación (`MyApp`), envuelto en un `ProviderScope` para la gestión del estado con Riverpod.

## Entradas:

- Depende de `MAPBOX_ACCESS_TOKEN` definido en `constants/mapbox_constants.dart` para la configuración de Mapbox.
- Importa y utiliza `initializeAppConfig` y `MyApp` desde `app.dart`.
- Utiliza `ProviderScope` de `flutter_riverpod`.

## Salidas/Efectos:

- Inicia el ciclo de vida de la aplicación Flutter.
- Establece el `ProviderScope` que estará disponible para toda la jerarquía de widgets, habilitando el uso de Riverpod.
