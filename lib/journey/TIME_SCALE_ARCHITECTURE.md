# Time Scale Architecture - Simulación Robusta

## Problema Original

Cuando el simulador corre a velocidad acelerada (ej. 10x), todos los cálculos dependientes de tiempo fallan:

1. **Velocidades irreales**: 100m en 1s real → 100 m/s (360 km/h) ❌
2. **Early exit false positives**: Distancia usuario-bus >50m por timing issues ❌
3. **Detecciones erróneas**: Counters de 3/3 detecciones consecutivas se alcanzan muy rápido ❌

## Solución: TimeScaleManager

Un servicio **singleton centralizado** que normaliza el tiempo para que la app funcione correctamente en simulación acelerada.

### Arquitectura

```
┌─────────────────────────────────────────────────────────┐
│                    TripSimulator                         │
│                                                          │
│  start() ─────────► TimeScaleManager.startSimulation(10x)│
│  stop()  ─────────► TimeScaleManager.stopSimulation()   │
└─────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────┐
│              TimeScaleManager (Singleton)                │
│                                                          │
│  • timeScale: double (1.0 = real, 10.0 = 10x faster)    │
│  • now: DateTime (tiempo virtual ajustado)               │
│  • timeBetween(): Duration ajustada                      │
│  • adjustThreshold(): ajusta distancias                  │
│  • adjustConsecutiveCount(): ajusta counters             │
└─────────────────────────────────────────────────────────┘
                              │
                 ┌────────────┴────────────┐
                 ▼                         ▼
┌──────────────────────────┐  ┌─────────────────────────┐
│   LocationTracker        │  │   JourneyManager        │
│                          │  │                         │
│ • _calculateSpeed()      │  │ • _evaluateBusEarlyExit()│
│   usa timeManager.now    │  │   usa adjustThreshold() │
│   usa timeBetween()      │  │   usa adjustConsecutive()│
└──────────────────────────┘  └─────────────────────────┘
```

### Integración

#### 1. TripSimulator
```dart
// Al iniciar simulación
TimeScaleManager().startSimulation(_speed); // ej. 10.0x

// Al detener
TimeScaleManager().stopSimulation();
```

#### 2. LocationTracker - Cálculo de Velocidad
```dart
void _calculateSpeed(Coordenada newLocation) {
  final timeManager = TimeScaleManager();
  final now = timeManager.now; // Tiempo virtual

  // ...

  // Tiempo transcurrido ajustado
  final timeDiff = timeManager.timeBetween(prev.timestamp, curr.timestamp)
    .inMilliseconds / 1000.0;

  // Velocidad normalizada: 100m en 1s real = 100m en 10s virtual = 10 m/s ✅
  _currentSpeed = totalDistance / totalTime;
}
```

#### 3. JourneyManager - Detecciones Robustas
```dart
void _evaluateBusEarlyExit(Coordenada userLocation) {
  final timeManager = TimeScaleManager();

  // Ajustar threshold: 50m → 500m a 10x (más tolerante)
  final adjustedThreshold = timeManager.adjustThreshold(_busProximityThreshold);

  // Ajustar contador: 3 detecciones → 1 detección a 10x (menos estricto)
  final adjustedRequiredCount = timeManager.adjustConsecutiveCount(_busExitRequiredConsecutive);

  if (distanceToBus > adjustedThreshold) {
    _busExitNegativeCount++;
    if (_busExitNegativeCount >= adjustedRequiredCount) {
      // Bajada prematura detectada
    }
  }
}
```

## Beneficios

### ✅ Velocidades Realistas
- **Antes**: 100m/s (360 km/h) en simulación 10x
- **Después**: 10 m/s (36 km/h) - velocidad normalizada correcta

### ✅ Thresholds Adaptativos
- **Antes**: Threshold fijo 50m → falsos positivos por timing
- **Después**: Threshold escalado 500m a 10x → compensa latencia

### ✅ Detecciones Robustas
- **Antes**: 3 detecciones consecutivas muy rápido → falsos positivos
- **Después**: 1 detección a 10x → ajustado proporcionalmente

### ✅ Centralizado y Simple
- Un solo punto de control (`TimeScaleManager`)
- Todos los componentes usan la misma escala de tiempo
- Fácil de debuggear: `[SIM 10x]` en logs

## Uso en Nuevos Componentes

Si creas nuevo código que depende de tiempo/velocidad:

```dart
import '../journey/time_scale_manager.dart';

void myTimeBasedLogic() {
  final timeManager = TimeScaleManager();

  // Usar tiempo virtual
  final now = timeManager.now;

  // Calcular duración ajustada
  final duration = timeManager.timeBetween(start, end);

  // Ajustar thresholds de distancia
  final threshold = timeManager.adjustThreshold(50.0);

  // Ajustar contadores consecutivos
  final count = timeManager.adjustConsecutiveCount(3);
}
```

## Testing

```dart
test('velocidad normalizada en simulación 10x', () {
  TimeScaleManager().startSimulation(10.0);

  // Simular 100m de movimiento en 1s real
  final speed = calculateSpeed(100.0, Duration(seconds: 1));

  // Debería ser 10 m/s (no 100 m/s)
  expect(speed, closeTo(10.0, 0.1));

  TimeScaleManager().stopSimulation();
});
```

## Archivos Modificados

1. **`lib/journey/time_scale_manager.dart`** - Nuevo servicio singleton
2. **`lib/journey/location_tracker.dart`** - Usa timeManager para velocidad
3. **`lib/journey/journey_manager.dart`** - Usa adjustThreshold/adjustConsecutiveCount
4. **`lib/devtools/trip_simulator.dart`** - Activa/desactiva time scale

## Principio de Diseño

> **"El simulador solo inyecta posiciones GPS. Todo lo demás debe funcionar igual que en producción, pero con tiempo normalizado."**

Esto mantiene la separación de concerns: el simulador no necesita conocer la lógica interna de detección, solo ajusta la escala de tiempo global.
