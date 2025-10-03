# 🚌 Journey Core - Arquitectura de Viaje Simplificada

## 📋 Índice

- [Visión General](#visión-general)
- [Problema Resuelto](#problema-resuelto)
- [Arquitectura en Capas](#arquitectura-en-capas)
- [Componentes Principales](#componentes-principales)
- [Flujo de Datos](#flujo-de-datos)
- [Ejemplo de Uso](#ejemplo-de-uso)
- [Testing](#testing)
- [Ventajas](#ventajas)

## 🎯 Visión General

Esta arquitectura separa la **lógica de progresión del viaje** de la **complejidad geométrica** (GPS, coordenadas, mapas), permitiendo:

1. ✅ **Unit testing** de la lógica de viaje sin GPS ni emulador
2. ✅ **Feedback instantáneo** para desarrollo con LLM
3. ✅ **Código testeable y mantenible**
4. ✅ **Separación de responsabilidades clara**

## 🔥 Problema Resuelto

### Antes (Problemático):
```
❌ Lógica de viaje mezclada con GPS/Mapas
❌ Testing requiere emulador Android
❌ Debugging con print logs manual
❌ Ciclo de desarrollo lento
❌ Difícil de testear con LLM
```

### Después (Simplificado):
```
✅ Lógica de viaje aislada y testeable
✅ Tests unitarios instantáneos
✅ Debugging con assertions
✅ Ciclo de desarrollo rápido
✅ LLM puede validar automáticamente
```

## 🏗️ Arquitectura en Capas

```
┌────────────────────────────────────────────────────┐
│  CAPA 1: LÓGICA DE VIAJE (Unidimensional)        │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                    │
│  ┌──────────────────┐    ┌───────────────────┐   │
│  │ TripStateMachine │    │  StepDetector     │   │
│  │                  │    │                   │   │
│  │ - steps[]        │◄───│ - shouldAdvance() │   │
│  │ - currentIndex   │    │ - calcProgress()  │   │
│  │ - progress       │    └───────────────────┘   │
│  └──────────────────┘                            │
│           ▲                                       │
│           │                                       │
│  ┌────────┴─────────┐                            │
│  │ TripOrchestrator │                            │
│  │                  │                            │
│  │ - update loop    │                            │
│  │ - coordinator    │                            │
│  └──────────────────┘                            │
└────────────────────────────────────────────────────┘
                       ▲
                       │ StepDetectionContext
                       │ (sin coordenadas directas)
                       │
┌────────────────────────────────────────────────────┐
│  CAPA 2: ADAPTADOR GEOMÉTRICO (Coordenadas)      │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                    │
│  ┌──────────────────────────────────────────┐    │
│  │        GeometryAdapter                   │    │
│  │                                          │    │
│  │ - stopLocations Map                     │    │
│  │ - busRoutes Map                         │    │
│  │                                          │    │
│  │ createContextForStep(step):             │    │
│  │   1. Calcula distancia GPS              │    │
│  │   2. Verifica geofence                  │    │
│  │   3. Detecta si está en ruta de bus     │    │
│  │   4. Retorna StepDetectionContext       │    │
│  └──────────────────────────────────────────┘    │
│                                                    │
└────────────────────────────────────────────────────┘
```

## 🧩 Componentes Principales

### 1. **TripStep** (trip_step.dart)

Representa un paso individual del viaje. NO conoce coordenadas.

```dart
TripStep(
  id: 'walk1',
  type: TripStepType.walkToStop,
  description: 'Caminar a parada 1',
  metadata: TripStepMetadata(
    destinationStopId: 'stop1',  // Solo IDs, no coordenadas
    totalDistanceMeters: 500,
  ),
  progress: 0.0,  // 0.0 - 1.0
  state: TripStepState.inProgress,
)
```

**Tipos de pasos:**
- `walkToStop` - Caminar a una parada
- `waitForBus` - Esperar el bus en una parada
- `onBus` - Dentro del bus (de parada A a parada B)
- `walkToDestination` - Caminar al destino final

### 2. **TripStateMachine** (trip_state_machine.dart)

Gestiona la progresión lineal del viaje. NO conoce coordenadas.

```dart
final machine = TripStateMachine(
  tripId: 'trip123',
  steps: [...],
);

machine.start();                          // Inicia el viaje
machine.updateCurrentStepProgress(0.5);   // Actualiza progreso del paso actual
machine.advanceToNextStep();              // Avanza al siguiente paso
```

**API Principal:**
- `start()` - Inicia el viaje
- `updateCurrentStepProgress(double)` - Actualiza progreso (0.0 - 1.0)
- `advanceToNextStep()` - Avanza al siguiente paso
- `overallProgress` - Progreso total del viaje
- `currentStep` - Paso actual

### 3. **StepDetector** (step_detector.dart)

Decide cuándo avanzar al siguiente paso. NO conoce coordenadas directas.

```dart
interface StepDetector {
  bool shouldAdvanceToNextStep(TripStep, StepDetectionContext)
  double calculateProgress(TripStep, StepDetectionContext)
}
```

**Implementaciones:**
- `WalkStepDetector` - Detecta llegada a parada/destino
- `WaitForBusDetector` - Detecta cuando el usuario se sube al bus
- `OnBusDetector` - Detecta llegada a parada de bajada

**Características:**
- ✅ Histéresis: Confirmaciones consecutivas para evitar falsos positivos
- ✅ Agnostico a coordenadas: Solo recibe `StepDetectionContext`

### 4. **StepDetectionContext** (step_detector.dart)

Estructura simplificada que contiene información procesada. NO coordenadas directas.

```dart
StepDetectionContext(
  distanceToTarget: 250.0,              // Metros al objetivo
  initialDistanceToTarget: 500.0,       // Distancia inicial
  isWithinGeofence: false,              // ¿Está en el geofence?
  isOnBusRoute: true,                   // ¿Está en la ruta del bus?
  userSpeed: 5.0,                       // m/s
  isUserMoving: true,                   // ¿Se está moviendo?
  timestamp: DateTime.now(),
)
```

### 5. **TripOrchestrator** (trip_orchestrator.dart)

Coordina la máquina de estados y los detectores. NO conoce coordenadas.

```dart
final orchestrator = TripOrchestrator(
  stateMachine: machine,
  detectors: {...},
  getContextForStep: geometryAdapter.createContextForStep,
  onTripCompleted: () => print('¡Viaje completado!'),
);

orchestrator.start(updateInterval: Duration(seconds: 5));
```

**Ciclo de actualización:**
1. Obtiene contexto del GeometryAdapter
2. Calcula progreso con el detector apropiado
3. Actualiza el state machine
4. Verifica si debe avanzar
5. Emite eventos (callbacks)

### 6. **GeometryAdapter** (geometry_adapter.dart)

Traduce coordenadas GPS a `StepDetectionContext`. Esta es la ÚNICA capa que conoce coordenadas.

```dart
final adapter = GeometryAdapter(
  stopLocations: {'stop1': Coordenada(-34.9, -56.1), ...},
  busRoutes: {'64': [coords...]},
  destinationLocation: Coordenada(-34.8, -56.2),
  currentUserLocation: userLocation,
);

// Traduce coordenadas complejas a contexto simple
final context = await adapter.createContextForStep(step);
```

**Responsabilidades:**
- ✅ Calcular distancias GPS
- ✅ Verificar geofences
- ✅ Detectar si está en ruta de bus
- ✅ Estimar velocidad del usuario
- ✅ Cachear distancias iniciales

## 🔄 Flujo de Datos

```
1. GPS actualiza ubicación del usuario
         │
         ▼
2. GeometryAdapter traduce a StepDetectionContext
   (coordenadas complejas → datos simples)
         │
         ▼
3. TripOrchestrator obtiene el contexto
         │
         ▼
4. StepDetector calcula progreso y decide si avanzar
   (usando solo el contexto, NO coordenadas)
         │
         ▼
5. TripStateMachine actualiza estado
         │
         ▼
6. UI se actualiza (mediante callbacks)
```

## 💡 Ejemplo de Uso

### Crear un viaje completo

```dart
// 1. Definir los pasos del viaje
final steps = [
  TripStep(
    id: 'walk1',
    type: TripStepType.walkToStop,
    description: 'Caminar a parada 1',
    metadata: TripStepMetadata(
      destinationStopId: 'stop_123',
      totalDistanceMeters: 500,
    ),
  ),
  TripStep(
    id: 'wait1',
    type: TripStepType.waitForBus,
    description: 'Esperar bus línea 64',
    metadata: TripStepMetadata(
      originStopId: 'stop_123',
      busLine: '64',
      hasEta: true,
    ),
  ),
  TripStep(
    id: 'bus1',
    type: TripStepType.onBus,
    description: 'En bus hasta parada 2',
    metadata: TripStepMetadata(
      originStopId: 'stop_123',
      destinationStopId: 'stop_456',
      busLine: '64',
    ),
  ),
  TripStep(
    id: 'walk2',
    type: TripStepType.walkToDestination,
    description: 'Caminar a destino',
    metadata: TripStepMetadata(
      totalDistanceMeters: 200,
    ),
  ),
];

// 2. Crear máquina de estados
final stateMachine = TripStateMachine(
  tripId: 'trip_001',
  steps: steps,
);

// 3. Crear adaptador de geometría
final geometryAdapter = GeometryAdapter(
  stopLocations: {
    'stop_123': Coordenada(-34.9011, -56.1645),
    'stop_456': Coordenada(-34.8975, -56.1580),
  },
  busRoutes: {
    '64': busRoute64Coordinates,
  },
  destinationLocation: Coordenada(-34.8960, -56.1555),
);

// 4. Crear orquestador
final orchestrator = createDefaultOrchestrator(
  stateMachine: stateMachine,
  getContextForStep: geometryAdapter.createContextForStep,
  onTripCompleted: () {
    print('¡Viaje completado!');
  },
  onStepChanged: (newStep) {
    print('Nuevo paso: ${newStep.description}');
  },
  onProgressUpdated: (progress) {
    print('Progreso: ${(progress * 100).toStringAsFixed(0)}%');
  },
);

// 5. Iniciar viaje
orchestrator.start(updateInterval: Duration(seconds: 5));

// 6. Actualizar ubicación del usuario (cada vez que GPS cambia)
void onGPSUpdate(Coordenada newLocation) {
  geometryAdapter.updateUserLocation(newLocation);
}
```

## 🧪 Testing

### Tests Unitarios (Instantáneos)

```dart
test('Simular viaje completo sin GPS', () async {
  // SETUP
  final steps = [...];
  final stateMachine = TripStateMachine(tripId: 'test', steps: steps);

  // MOCK del GeometryAdapter
  var mockDistance = 500.0;
  var mockGeofence = false;

  Future<StepDetectionContext> mockAdapter(TripStep step) async {
    return StepDetectionContext(
      distanceToTarget: mockDistance,
      initialDistanceToTarget: 500.0,
      isWithinGeofence: mockGeofence,
      timestamp: DateTime.now(),
    );
  }

  final orchestrator = createDefaultOrchestrator(
    stateMachine: stateMachine,
    getContextForStep: mockAdapter,
  );

  // TEST
  orchestrator.start();

  // Simular usuario caminando
  mockDistance = 250.0;
  await orchestrator.updateNow();
  expect(stateMachine.currentStep.progress, closeTo(0.5, 0.1));

  // Simular llegada
  mockDistance = 10.0;
  mockGeofence = true;
  await orchestrator.updateNow();  // Confirmación 1
  await orchestrator.updateNow();  // Confirmación 2 - avanza

  expect(stateMachine.currentStepIndex, 1);
});
```

### Ejecutar Tests

```bash
# Todos los tests del core
flutter test test/journey/core/

# Test específico
flutter test test/journey/core/trip_state_machine_test.dart

# Con coverage
flutter test --coverage
```

## ✨ Ventajas

### 1. **Testeable**
- Unit tests instantáneos sin emulador
- Mock del GeometryAdapter trivial
- TDD (Test-Driven Development) posible

### 2. **Mantenible**
- Separación clara de responsabilidades
- Cada componente tiene un propósito único
- Fácil de entender y modificar

### 3. **Debuggeable**
- Logs claros en cada capa
- Estado inspeccionable en cualquier momento
- Tests reproducibles

### 4. **Compatible con LLM**
- Tests proporcionan feedback instantáneo
- LLM puede validar cambios automáticamente
- Ciclo de desarrollo rápido

### 5. **Extensible**
- Agregar nuevos tipos de pasos: trivial
- Agregar nuevos detectores: trivial
- Modificar lógica de geometría: aislado

## 🚀 Próximos Pasos

1. ✅ Integrar con `JourneyManager` existente
2. ✅ Migrar lógica de viaje actual a esta arquitectura
3. ✅ Agregar velocidad del usuario real (historial de ubicaciones)
4. ✅ Implementar ETA para `waitForBus`
5. ✅ Agregar eventos más granulares (onGeofenceEnter, etc.)

## 📚 Documentación Relacionada

- [User Flow Documentation](../../../docs/flujos/flujo-principal/1-flujo-de-usuario.txt)
- [User Flow Diagram](../../../docs/flujos/flujo-principal/1b-flujo-de-usuario.mmd)
