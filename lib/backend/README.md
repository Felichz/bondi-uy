# Capa de Lógica de Negocio (Backend)

Esta carpeta contiene toda la lógica de negocio y la gestión del estado para la aplicación Bondi UY. Su principal objetivo es mantener una separación clara con la capa de UI, proveyendo a esta última los datos necesarios para renderizar y las acciones que puede invocar.

## Principios de Diseño

- **Separación Estricta de UI y Lógica**: La UI es agnóstica a los detalles de implementación de la lógica.
- **Contrato UI-Lógica**: La interacción entre la UI y la lógica se define a través de una interfaz clara (`IAppLogic`) y un estado bien definido (`AppUiState`).
- **Datos Crudos**: La lógica provee datos crudos (ej. duraciones en segundos, coordenadas), y la UI se encarga de formatearlos para su presentación.
- **Gestión de Estado Centralizada**: Se utiliza Riverpod para la gestión del estado de la aplicación.

## Componentes Principales

### 1. `AppLogicNotifier`

- **Ubicación**: `lib/backend/providers/app_logic_provider.dart`
- **Rol**: Es el gestor de estado central de la aplicación, implementado como un `StateNotifier` de Riverpod.
- **Responsabilidades**:
  - Implementa la interfaz `IAppLogic`, que define todas las acciones que la UI puede invocar (ej. `cargarParadasInicialesDelViewport`, `iniciarBusquedaDeRutas`, `opcionDeRutaConfirmadaParaViaje`).
  - Gestiona y expone el `AppUiState`, que representa el estado completo de la aplicación que la UI debe consumir para dibujarse.
  - Orquesta las llamadas a los diferentes adaptadores de servicio para obtener datos externos o ejecutar operaciones.
  - Maneja los flujos de la aplicación, como la carga inicial de paradas, la planificación de rutas, la selección de una ruta y el seguimiento en tiempo real de un viaje.

### 2. Adaptadores de Servicio

- **Ubicación**: `lib/backend/services/`
- **Rol**: Abstraen las interacciones con servicios externos (APIs, bases de datos locales, etc.), convirtiendo los datos específicos del servicio en modelos entendibles por el resto de la capa de lógica y, eventualmente, por el contrato UI.
- **Componentes**:
  - `MontevideoApiServiceAdapter` (`montevideo_api_service_adapter.dart`): Encargado de interactuar con las APIs de Montevideo. Sus responsabilidades incluyen:
    - Obtener la lista completa de paradas de ómnibus (actualmente desde un archivo GeoJSON local).
    - Consultar los detalles de una parada específica, incluyendo los próximos arribos (ETAs) en tiempo real.
  - `ItineraryPlanningServiceAdapter` (`itinerary_planning_service_adapter.dart`): Encargado de la planificación de rutas. Sus responsabilidades incluyen:
    - Interactuar con un servidor OpenTripPlanner (OTP) para calcular rutas entre un origen y un destino.
    - Procesar las respuestas de OTP, convirtiéndolas al formato `OpcionDeRutaMostrable` definido en el contrato UI.
    - Enriquecer las opciones de ruta con información adicional, como ETAs para el primer tramo de bus (utilizando `MontevideoApiServiceAdapter`) y un score de recomendación.

### 3. Contrato UI-Lógica

- **Ubicación**: `lib/backend/contrato_ui/app_ui_state.dart`
- **Rol**: Define la frontera entre la UI y la Lógica. Es fundamental para mantener el bajo acoplamiento.
- **Componentes**:
  - `AppUiState`: Clase (usualmente inmutable) que encapsula todo el estado que la UI necesita para renderizarse. Se divide en fases (`FaseApp`) para representar los diferentes estados generales de la aplicación (ej. inicial, mostrando opciones, viaje activo).
  - `IAppLogic`: Interfaz que define todas las acciones que la UI puede invocar sobre la lógica de negocio. `AppLogicNotifier` implementa esta interfaz.
  - **Modelos de Datos para la UI**: Clases de datos como `Coordenada`, `InfoParadaEnMapa`, `OpcionDeRutaMostrable`, `TramoViajeMostrable`, etc., que estructuran la información que la lógica provee a la UI.

## Flujo de Datos General

1.  La **UI** observa el `AppUiState` expuesto por el `appLogicProvider`.
2.  Cuando el usuario interactúa con la **UI** (ej. mueve el mapa, selecciona una parada, pide una ruta), la UI invoca un método correspondiente en `IAppLogic` (accesible a través del `appLogicProvider.notifier`).
3.  El `AppLogicNotifier` recibe la acción, procesa la solicitud, y si es necesario, llama a uno o más **Adaptadores de Servicio** para obtener o enviar datos.
4.  Los **Adaptadores de Servicio** interactúan con las fuentes de datos externas y devuelven la información procesada al `AppLogicNotifier`.
5.  El `AppLogicNotifier` actualiza su estado interno, lo que resulta en una nueva instancia de `AppUiState`.
6.  Riverpod notifica a la **UI** que el `AppUiState` ha cambiado, y la UI se reconstruye para reflejar el nuevo estado.

Este flujo asegura que la lógica de negocio permanezca centralizada y desacoplada de la presentación, facilitando el mantenimiento, las pruebas y la evolución de la aplicación.
