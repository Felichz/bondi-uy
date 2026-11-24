# Architectural Alignment Review Guide - BondiUY

## 1. Purpose

This guide aims to ensure that all new feature development and code refactoring for the BondiUY application consistently adhere to the layer separation architecture (UI vs. Business Logic) and to the established design principles. Compliance is crucial to keep a clean, maintainable, testable codebase aligned with the product vision.

## 2. Fundamental Principles

### Strict Layer Separation

- **UI Layer (ui/)**:

  - Exclusively responsible for presentation and direct interaction with the user
  - Agnostic to the underlying business logic

- **Business Logic Layer (backend/)**:
  - Contains all business logic, service orchestration, data processing and application state management
  - Agnostic to the visual implementation of the UI

### Single and Minimal UI-Logic Contract

```dart
// backend/contrato_ui/app_ui_state.dart
AppUiState: // Only source of data towards the UI
IAppLogic: // Only entry point from the UI
```

## 3. Detailed Review Checklist

### A. Reviewing the Logic Layer (backend/)

- [ ] Are changes to AppUiState made ONLY through its copyWith method?
- [ ] Is the data in AppUiState raw (numeric/enums)?

**Incorrect example**:

```dart
// ❌ Avoid pre-formatted strings
duracionTotalTexto: "5 min"
```

**Correct example**:

```dart
// ✅ Use raw data
duracionTotalSegundos: 300
```

### B. Reviewing the UI Layer (ui/)

- [ ] Do widgets read global state ONLY through AppUiState (obtained via ref.watch(appLogicProvider))?
- [ ] Do user interactions that require business logic or new data invoke ONLY the public methods exposed by AppLogicNotifier (obtained via ref.read(appLogicProvider.notifier).actionName())?
- [ ] Does the UI avoid directly modifying AppUiState?

### C. Reviewing the Contract (backend/contrato_ui/app_ui_state.dart)

- [ ] Are the state definitions and their fields clear, concise, and do they represent the semantics of the data without ambiguity?
- [ ] Does the contract expose the minimum information necessary for the UI to fulfill its function, avoiding internal implementation details of the logic?
- [ ] Is data redundancy avoided?
- [ ] Is the data truly "raw" and free of presentation elements?

## 4. Review Priorities

1. Strict compliance with the contract and layer separation
2. Logic agnosticism with respect to presentation
3. UI autonomy in presentation
4. Clarity and Maintainability: the code must be easy to understand within its layer, and the contract must be explicit.

## 5. Mini Application Scenarios

**Scenario**: Change the bus stop icon  
**Solution**:

```dart
// Modify only in the UI layer
Marker(
  icon: CustomBusStopIcon(), // New asset
)
```

**Scenario**: Add a new user preference "Avoid tolls" in route planning  
**Analysis**: It is a new business rule  
**Affected layers**:

- **Contract**: IAppLogic might need a new parameter in iniciarBusquedaDeRutas. AppUiState might need a field in PreferenciasUsuario if the UI must show the state of this preference.
- **Logic**: AppLogicNotifier will pass this preference to ItineraryPlanningService. The planning service must be modified to consider this option when interacting with the routing engine (OTP).
- **UI**: Add a new control (checkbox, switch) so the user can enable/disable the preference. This control, when changed, will call a new action in IAppLogic to update the preference (e.g. actualizarPreferenciaEvitarPeajes(bool activado)), which in turn would update AppUiState.

**Scenario**: The map must automatically center on the user's location when the app starts, if permission is granted  
**Analysis**: It involves getting geolocation data (logic) and then controlling the map (UI)  
**Flow**:

- **UI**: On start (or when the map widget is ready), calls appLogicProvider.notifier.obtenerUbicacionActualUsuarioParaInicio().
- **Logic**: Tries to get the location.
- **UI**: Watches AppUiState.zoomACoordenadaInicial. If it is not null, uses the Mapbox SDK to animate the camera to that coordinate. It also renders the updated stops.
