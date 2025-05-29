# Guía de Revisión de Alineamiento Arquitectónico - BondiUY

## 1. Propósito

Esta guía tiene como objetivo asegurar que todo el desarrollo de nuevas funcionalidades y la refactorización del código para la aplicación BondiUY se adhieran consistentemente a la arquitectura de separación de capas (UI vs. Lógica de Negocio) y a los principios de diseño establecidos. Su cumplimiento es crucial para mantener un codebase limpio, mantenible, testeable y alineado con la visión del producto.

## 2. Principios Fundamentales

### Separación Estricta de Capas

- **Capa de UI (ui/)**:

  - Exclusivamente responsable de la presentación y la interacción directa con el usuario
  - Agnóstica a la lógica de negocio subyacente

- **Capa de Lógica de Negocio (backend/)**:
  - Contiene toda la lógica de negocio, orquestación de servicios, procesamiento de datos y gestión del estado de la aplicación
  - Agnóstica a la implementación visual de la UI

### Contrato UI-Lógica Único y Mínimo

```dart
// backend/contrato_ui/app_ui_state.dart
AppUiState: // Única fuente de datos hacia la UI
IAppLogic: // Único punto de entrada desde la UI
```

## 3. Checklist de Revisión Detallado

### A. Revisando la Capa de Lógica (backend/)

- [ ] ¿Las modificaciones al AppUiState se realizan ÚNICAMENTE a través de su método copyWith?
- [ ] ¿Los datos en AppUiState son crudos (numéricos/enums)?

**Ejemplo incorrecto**:

```dart
// ❌ Evitar strings pre-formateados
duracionTotalTexto: "5 min"
```

**Ejemplo correcto**:

```dart
// ✅ Usar datos crudos
duracionTotalSegundos: 300
```

### B. Revisando la Capa de UI (ui/)

- [ ] ¿Los widgets leen datos del estado global ÚNICAMENTE a través del AppUiState (obtenido vía ref.watch(appLogicProvider))?
- [ ] ¿Las interacciones del usuario que requieren lógica de negocio o nuevos datos invocan ÚNICAMENTE los métodos públicos expuestos por AppLogicNotifier (obtenido vía ref.read(appLogicProvider.notifier).nombreAccion())?
- [ ] ¿La UI no intenta modificar directamente el AppUiState?

### C. Revisando el Contrato (backend/contrato_ui/app_ui_state.dart)

- [ ] ¿Las definiciones de estado y sus campos son claras, concisas y representan la semántica de los datos sin ambigüedad?
- [ ] ¿El contrato expone la mínima información necesaria para que la UI cumpla su función, evitando detalles de implementación interna de la lógica?
- [ ] ¿Se evita la redundancia de datos?
- [ ] ¿Los datos son verdaderamente "crudos" y no contienen elementos de presentación?

## 4. Prioridades Durante la Revisión

1. Cumplimiento estricto del contrato y separación de capas
2. Agnosticismo de la lógica respecto a la presentación
3. Autonomía de la UI en la presentación
4. Claridad y Mantenibilidad: El código debe ser fácil de entender dentro de su capa y el contrato debe ser explícito.

## 5. Mini-Escenarios de Aplicación

**Escenario**: Cambiar el ícono de paradas de bus  
**Solución**:

```dart
// Modificar solo en capa UI
Marker(
  icon: CustomBusStopIcon(), // Nuevo asset
)
```

**Escenario**: Añadir una nueva preferencia de usuario "Evitar peajes" en la planificación de rutas  
**Análisis**: Es una nueva regla de negocio  
**Capas Afectadas**:

- **Contrato**: IAppLogic podría necesitar un nuevo parámetro en iniciarBusquedaDeRutas. AppUiState podría necesitar un campo en PreferenciasUsuario si la UI debe mostrar el estado de esta preferencia.
- **Lógica**: El AppLogicNotifier pasará esta preferencia al ItineraryPlanningService. El servicio de planificación deberá ser modificado para considerar esta opción al interactuar con el motor de rutas (OTP).
- **UI**: Añadir un nuevo control (checkbox, switch) para que el usuario active/desactive la preferencia. Este control, al cambiar, llamará a una nueva acción en IAppLogic para actualizar la preferencia (ej. actualizarPreferenciaEvitarPeajes(bool activado)), lo que a su vez actualizaría el AppUiState.

**Escenario**: El mapa debe centrarse automáticamente en la ubicación del usuario al iniciar la app si el permiso está concedido  
**Análisis**: Implica obtener datos de geolocalización (lógica) y luego controlar el mapa (UI)  
**Flujo**:

- **UI**: Al iniciar, (o cuando el widget del mapa esté listo), llama a appLogicProvider.notifier.obtenerUbicacionActualUsuarioParaInicio().
- **Lógica**: Intenta obtener la ubicación.
- **UI**: Observa AppUiState.zoomACoordenadaInicial. Si no es nulo, usa el SDK de Mapbox para animar la cámara a esa coordenada. También renderiza las paradas actualizadas.
