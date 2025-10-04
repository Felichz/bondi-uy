# Trip Simulation System - Arquitectura Simplificada

## Principio Fundamental

**El simulador SOLO inyecta inputs GPS** (ubicación del usuario y del bus).

El resto del código de producción (MapManager, CameraController, JourneyManager, etc.) debe reaccionar **naturalmente** a esos inputs, igual que si vinieran de APIs reales.

## Problema que Resuelve

El objetivo del simulador es **poder revisar si funciona bien la app sin necesidad de**:
- Ir físicamente caminando a la parada de bus
- Mover manualmente la ubicación del usuario desde el emulador
- Esperar que llegue el bus real
- Intentar mantener la posición del usuario sincronizada con el bus manualmente (imposible)

## Lo que el Simulador HACE

```dart
// ✅ Solo inyecta ubicaciones GPS mock
notifier.devPushMockUserLocation(userPos);
notifier.devPushRealtimeBusPosition(busPos, eta);
```

## Lo que el Simulador NO HACE

```dart
// ❌ NO toca la cámara directamente
mapManager.zoomTo(...);  // Esto es responsabilidad del código de producción

// ❌ NO maneja lógica de journey
journeyManager.transitionToStep(...);  // Esto debe dispararse solo

// ❌ NO actualiza UI directamente
setState(...);  // La UI debe reaccionar a los inputs GPS
```

## Arquitectura

El sistema está dividido en **3 componentes independientes** con responsabilidades claras:

```
┌──────────────────────────────────┐
│   TripSimulationSpec             │  ← Define QUÉ simular
│   (trip_simulation_spec.dart)    │
│                                   │
│  - Fases del viaje                │
│  - Rutas/geometrías               │
│  - Duraciones                     │
│  - Eventos de cámara esperados    │
└──────────────────────────────────┘
           ▲
           │ construye
           │
┌──────────────────────────────────┐
│   TripSimulationBuilder           │  ← Construye specs desde
│   (trip_simulation_builder.dart)  │     diferentes fuentes
│                                    │
│  - Desde EstadoFaseViajeActivo    │
│  - Desde JSON fixtures            │
│  - Extrae geometrías              │
│  - Define eventos de cámara       │
└──────────────────────────────────┘
           │
           │ pasa spec a
           ▼
┌──────────────────────────────────┐
│   TripSimulationExecutor          │  ← Ejecuta la simulación
│   (trip_simulation_executor.dart) │
│                                    │
│  - Interpola posiciones            │
│  - Emite eventos                   │
│  - Control de velocidad            │
│  - Ciclo de ejecución              │
└──────────────────────────────────┘
```

### Separación de Responsabilidades

**ANTES (TripSimulator viejo)**:
- 380 líneas en un solo archivo
- Mezcla construcción + ejecución + lógica de negocio
- Difícil de testear (necesita AppLogicNotifier)
- Imposible cargar desde JSON
- No define eventos esperados

**AHORA**:
- **TripSimulationSpec**: Define datos (testeable con JSON)
- **TripSimulationBuilder**: Construye specs (lógica de construcción aislada)
- **TripSimulationExecutor**: Ejecuta (simple, solo interpola y emite)

## Uso

### 1. Cargar desde JSON Fixture (Testing)

```dart
// Cargar fixture de test
final file = File('test/fixtures/trip_simulation_example.json');
final json = jsonDecode(await file.readAsString());
final spec = TripSimulationSpec.fromJson(json);

// Ejecutar
final executor = TripSimulationExecutor(
  spec: spec,
  onUserLocationUpdate: (pos) => print('User: $pos'),
  onBusLocationUpdate: (pos, eta) => print('Bus: $pos, ETA: $eta'),
  onEvent: (event) => print(event),
);

executor.start();
```

### 2. Construir desde Estado de App (Producción)

```dart
// Construir spec desde estado actual
final spec = TripSimulationBuilder.fromActiveTripState(
  state.datosFaseViajeActivo!,
  initialBusPosition: state.posicionActualBusReal,
  speed: 2.0, // 2x velocidad
);

// Ejecutar
final executor = TripSimulationExecutor(
  spec: spec,
  onUserLocationUpdate: notifier.devPushMockUserLocation,
  onBusLocationUpdate: notifier.devPushRealtimeBusPosition,
);

executor.start();
```

## Eventos de Cámara Esperados (Para Validación)

**IMPORTANTE**: El simulador **NO dispara** estos eventos. Solo inyecta GPS.

Estos eventos documentan lo que **esperamos que el código de producción (MapManager/CameraController) dispare automáticamente** cuando recibe los inputs GPS.

Son útiles para **validar en tests** que la cámara está reaccionando correctamente a las ubicaciones simuladas.

Basados en especificaciones del flujo de usuario (`docs/flujos/flujo-principal/1-flujo-de-usuario.txt`):

### Fase 1: WalkToStop
```json
{
  "atTime": 1.0,
  "type": "zoomToUserAndStop",
  "description": "Cámara debe enfocar usuario y parada (tramo azul de caminata)",
  "expectedData": {
    "shouldInclude": ["user", "stop"],
    "shouldDrawBlueLine": true
  }
}
```

### Fase 2: WaitForBus
```json
{
  "atTime": 16.0,
  "type": "zoomToBusAndStop",
  "description": "Cámara debe enfocar bus y parada (línea verde)",
  "expectedData": {
    "shouldInclude": ["bus", "stop"],
    "shouldDrawGreenLine": true,
    "shouldAdjustZoomOnBusUpdate": true
  }
}
```

### Fase 3: RideOnBus
```json
{
  "atTime": 31.0,
  "type": "zoomToUserOnBus",
  "description": "Cámara debe enfocar usuario (en bus) y parada de destino",
  "expectedData": {
    "shouldInclude": ["user", "destinationStop"],
    "userShouldEqualBus": true
  }
}
```

### Fase 4: WalkToDestination
```json
{
  "atTime": 51.0,
  "type": "zoomToDestination",
  "description": "Cámara debe enfocar usuario y destino final",
  "expectedData": {
    "shouldInclude": ["user", "destination"],
    "shouldDrawBlueLine": true
  }
}
```

## Testing

### Test Básico: Cargar y Ejecutar

```dart
test('should execute simulation from JSON', () async {
  final json = jsonDecode(await File('fixture.json').readAsString());
  final spec = TripSimulationSpec.fromJson(json);

  final events = <SimulationEvent>[];
  final executor = TripSimulationExecutor(
    spec: spec,
    onUserLocationUpdate: (_) {},
    onEvent: (e) => events.add(e),
  );

  executor.start();
  await Future.delayed(Duration(seconds: 1));

  expect(events, isNotEmpty);
});
```

### Test de Eventos de Cámara (Validación de Código de Producción)

Este test valida que **el código de producción** (MapManager) está reaccionando correctamente a los inputs GPS del simulador:

```dart
test('should validate camera responds to GPS inputs', () async {
  final spec = TripSimulationSpec.fromJson(json);

  // 1. Capturar eventos de cámara REALES que el código de producción emite
  final actualCameraEvents = <CameraEvent>[];
  mapManager.onCameraChange = (event) => actualCameraEvents.add(event);

  // 2. Ejecutar simulador (solo inyecta GPS)
  final executor = TripSimulationExecutor(
    spec: spec,
    onUserLocationUpdate: notifier.devPushMockUserLocation,
    onBusLocationUpdate: notifier.devPushRealtimeBusPosition,
  );
  executor.start();
  await Future.delayed(...);

  // 3. Validar que MapManager SÍ disparó los eventos esperados
  final expectedWalkEvent = spec.config.expectedCameraEvents
    .firstWhere((e) => e.type == CameraEventType.zoomToUserAndStop);

  final actualWalkEvent = actualCameraEvents.firstWhere(
    (e) => e.timestamp.isNear(expectedWalkEvent.atTime),
  );

  // Verificar que la cámara del código de producción reaccionó correctamente
  expect(actualWalkEvent.includes, contains('user'));
  expect(actualWalkEvent.includes, contains('stop'));
  expect(actualWalkEvent.drewBlueLine, isTrue);
});
```

**Flujo del test**:
1. Simulador inyecta GPS → `devPushMockUserLocation(userPos)`
2. Código de producción reacciona → `MapManager` detecta cambio de ubicación
3. MapManager ajusta cámara → `onCameraChange` se dispara
4. Test valida → Comparar evento real vs evento esperado

### Test Acelerado (100x Velocidad)

```dart
test('should run fast for automated testing', () async {
  json['config']['speed'] = 100.0; // 60s simulación → 0.6s real
  final spec = TripSimulationSpec.fromJson(json);

  final executor = TripSimulationExecutor(/*...*/);
  executor.start();

  await Future.delayed(Duration(milliseconds: 700));
  expect(executor.isRunning, isFalse); // Terminó
});
```

## Estructura de JSON Fixture

Ver ejemplo completo: `test/fixtures/trip_simulation_example.json`

```json
{
  "phases": [
    {
      "type": "walkToStop",
      "duration": 15.0,
      "userPath": [
        { "lat": -34.9011, "lng": -56.1645 },
        { "lat": -34.9014, "lng": -56.1660 }
      ]
    },
    {
      "type": "waitForBus",
      "duration": 15.0,
      "busEtaMinutes": 5,
      "userPath": [{ "lat": -34.9014, "lng": -56.1660 }],
      "busPath": [...]
    }
  ],
  "config": {
    "speed": 1.0,
    "emitEvents": true,
    "expectedCameraEvents": [...]
  }
}
```

## Ventajas de esta Arquitectura

1. **Testeable**: Fixtures JSON permiten tests rápidos y reproducibles
2. **Separación de responsabilidades**: Cada clase tiene un propósito claro
3. **Observable**: Eventos permiten verificar comportamiento esperado
4. **Documentado**: Eventos de cámara están especificados según flujo de usuario
5. **Simple**: Executor es solo interpolación + emisión de eventos (< 200 líneas)
6. **Flexible**: Puede construirse desde estado real O JSON
7. **Rápido para testing**: Speed = 100x hace tests de 60s → 0.6s

## Próximos Pasos

1. **Integrar con TripSimulator actual**: Usar este sistema internamente
2. **Implementar validación de eventos de cámara**: Capturar eventos reales y compararlos con expectedCameraEvents
3. **Generar fixtures desde viajes reales**: Grabar viajes reales como JSON para regression testing
4. **Dashboard de testing**: UI para ejecutar múltiples fixtures y ver resultados

## Migración del Código Existente

El código viejo (`trip_simulator.dart`) puede convivir con este sistema. Eventualmente:

1. `TripSimulator.start()` llama internamente a `TripSimulationBuilder.fromActiveTripState()`
2. Ejecuta con `TripSimulationExecutor`
3. Mantiene misma interfaz pública, pero internamente usa nueva arquitectura

Esto permite **migración gradual sin romper código existente**.
