# lib/app.dart

Este archivo contiene la configuración inicial de la aplicación y el widget raíz `MyApp`.

## Responsabilidades:

- Configurar el token de acceso de Mapbox a través de `initializeAppConfig`.
- Definir el widget raíz `MyApp`, que establece el tema de la aplicación y la pantalla inicial (`MapScreen`).

## Entradas:

- La función `initializeAppConfig` recibe el token de acceso de Mapbox como un String.
- `MyApp` utiliza `MapScreen` como su pantalla principal.

## Salidas/Efectos:

- Configura globalmente el token de acceso para Mapbox SDK.
- Define la estructura visual inicial y el tema de la aplicación Flutter.
- Establece `MapScreen` como la pantalla que se muestra al iniciar la aplicación.
