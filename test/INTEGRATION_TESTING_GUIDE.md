# 🧪 Guía Completa de Testing de Integración con Datos Reales

## 🎯 Objetivo

Esta guía te muestra cómo ejecutar tests de integración **completos** que validan **toda la lógica de geometría y detección de pasos** usando datos 100% reales capturados desde la app.

**Problema resuelto:** Antes teníamos que probar manualmente en el emulador y reportar bugs verbalmente. Ahora el LLM puede iterar autónomamente hasta que pasen los tests.

---

## 📊 ¿Qué se Testea?

### Tests Unitarios (ya existentes)
- ✅ `TripStateMachine` - Lógica de estados del viaje
- ✅ `StepDetector` - Detección de transiciones de pasos
- ✅ `TripOrchestrator` - Coordinación de componentes

### Tests de Integración (NUEVO)
- ✅ **GeometryAdapter** - Cálculo de distancias, geofencing, detección de proximidad
- ✅ **Integración completa** - Desde coordenadas GPS hasta detección de pasos
- ✅ **Datos reales** - Geometrías, paradas, rutas capturadas de la app
- ✅ **Validación programática** - Checkpoints automáticos que validan estado

---

## 🔄 Flujo Completo del Sistema

```
┌─────────────────────────────────────────────────────────────┐
│  1. Captura desde App (Manual - una vez)                    │
│     - Usuario busca destino en app                          │
│     - Click en botón verde para copiar JSON                 │
│     - Opcionalmente: iniciar viaje y grabar GPS playback    │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  2. Preparación de Fixture (Manual - una vez)               │
│     - Pegar JSON en test/fixtures/trip_XXX.json             │
│     - Definir checkpoints manualmente                       │
│     - Validar que geometrías no estén vacías                │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  3. Ejecución de Test (Automático - infinitas veces)       │
│     - TripIntegrationRunner lee el fixture                  │
│     - Construye TripSteps desde segments                    │
│     - Construye GeometryAdapter con stops/routes            │
│     - Ejecuta GPS playback punto por punto                  │
│     - Valida checkpoints programáticamente                  │
│     - Reporta éxito/fallo con detalles                      │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  4. Iteración LLM (Automático)                              │
│     - LLM modifica lógica de geometría                      │
│     - Ejecuta flutter test                                  │
│     - Si falla: analiza error, modifica código, repite      │
│     - Si pasa: continúa con siguiente feature               │
└─────────────────────────────────────────────────────────────┘
```

---

## 📝 Paso 1: Capturar Datos Reales desde la App

### Opción A: Captura Básica (Solo ruta)

1. Ejecuta la app en modo debug:
   ```bash
   flutter run
   ```

2. Busca un destino para generar opciones de ruta

3. Click en el **botón verde** (ícono copy) en el FAB

4. El JSON se copia al portapapeles

5. Pega en un archivo:
   ```bash
   # Crear nuevo fixture
   pbpaste > test/fixtures/trip_real_001.json
   ```

### Opción B: Captura con GPS Playback (Recomendado para tests completos)

Esta opción captura el GPS real mientras haces el viaje en el simulador/emulador.

**Pasos:**

1. Modifica temporalmente el código para grabar GPS durante el viaje activo

2. Agrega esto en `JourneyManager.initialize()`:
   ```dart
   import 'package:bondi_uy/devtools/trip_data_capture_service.dart';

   // Al inicio del viaje
   TripDataCaptureService.startGpsRecording();
   ```

3. Agrega esto en `JourneyManager._handleLocationUpdate()`:
   ```dart
   // En cada actualización de ubicación
   TripDataCaptureService.recordGpsPoint(
     newLocation,
     comment: 'Step ${_state!.currentStepIndex}: ${_state!.currentStep.type}',
   );
   ```

4. Agrega esto en `JourneyManager` cuando el viaje termina:
   ```dart
   // Al completar el viaje
   TripDataCaptureService.stopGpsRecording();
   ```

5. Ejecuta el viaje en el emulador/simulador

6. Click en el botón verde para copiar (ahora incluirá GPS playback)

7. Pega en el fixture

**Importante:** Recuerda **quitar** estos cambios después de capturar el GPS (son solo para debugging).

---

## 📝 Paso 2: Preparar el Fixture

### Estructura del JSON

El JSON capturado tiene esta estructura:

```json
{
  "tripId": "trip_1234567890",
  "name": "Trip capturado - 2025-01-03 14:30:00",
  "capturedAt": "2025-01-03T14:30:00.000Z",

  "origin": {
    "lat": -34.9011,
    "lng": -56.1645,
    "name": "Origen"
  },

  "destination": {
    "lat": -34.8960,
    "lng": -56.1555,
    "name": "Destino"
  },

  "route": {
    "routeId": "route_xyz",
    "stops": [
      {
        "stopId": "6789",
        "name": "Bvar. Artigas y Flores",
        "lat": -34.8945,
        "lng": -56.1672,
        "busLines": ["121"]
      }
    ],

    "segments": [
      {
        "type": "CAMINAR",
        "description": "Caminar a parada X",
        "duration": 180,
        "distance": 250,
        "geometry": [
          {"lat": -34.9011, "lng": -56.1645},
          {"lat": -34.9010, "lng": -56.1644}
          // ... más puntos
        ]
      }
    ]
  },

  "gpsPlayback": [
    {"timestamp": 0, "lat": -34.9011, "lng": -56.1645, "comment": "Inicio"},
    {"timestamp": 5, "lat": -34.9010, "lng": -56.1644}
    // ... más puntos
  ],

  "checkpoints": [
    // DEBES AGREGAR ESTOS MANUALMENTE (ver abajo)
  ],

  "expectedBehavior": {
    "totalDuration": 900,
    "stepsExpected": 4,
    "shouldComplete": true,
    "description": "Trip capturado desde la app"
  }
}
```

### Definir Checkpoints

Los checkpoints son **validaciones programáticas** que se ejecutan en momentos específicos del viaje.

**Ejemplo:**

```json
"checkpoints": [
  {
    "timestamp": 10,
    "name": "Usuario debe estar caminando a la parada",
    "assertions": {
      "currentStepIndex": 0,
      "currentStepType": "walkToStop",
      "progressMin": 0.2,
      "progressMax": 0.6,
      "isWithinGeofence": false
    }
  },
  {
    "timestamp": 30,
    "name": "Usuario debe haber llegado a la parada",
    "assertions": {
      "currentStepIndex": 1,
      "currentStepType": "waitForBus",
      "isWithinGeofence": true,
      "distanceToTargetMax": 25
    }
  },
  {
    "timestamp": 60,
    "name": "Usuario debe estar en el bus",
    "assertions": {
      "currentStepIndex": 2,
      "currentStepType": "onBus",
      "progressMin": 0.0,
      "progressMax": 0.3
    }
  }
]
```

**Campos de assertions:**

- `currentStepIndex` (int): Índice del paso actual esperado (0, 1, 2, ...)
- `currentStepType` (string): Tipo esperado (`walkToStop`, `waitForBus`, `onBus`, `walkToDestination`)
- `progressMin` / `progressMax` (double): Rango de progreso esperado (0.0 - 1.0)
- `isWithinGeofence` (bool): Si el usuario debe estar dentro del geofence
- `distanceToTargetMax` (double): Distancia máxima al objetivo en metros

**Cómo definir buenos checkpoints:**

1. Mira el `gpsPlayback` - cada timestamp representa un segundo
2. Identifica momentos clave: "llegó a parada", "subió al bus", "se bajó del bus"
3. Para cada momento, define qué debería estar pasando en el código
4. Sé conservador con los rangos (e.g., `progressMin: 0.3, progressMax: 0.7` en vez de valor exacto)

---

## 🧪 Paso 3: Ejecutar Tests

### Ejecutar test de integración

```bash
# Test específico de integración
flutter test test/integration/trip_real_integration_test.dart

# Con verbose output
flutter test test/integration/trip_real_integration_test.dart --verbose

# Solo el test principal
flutter test test/integration/trip_real_integration_test.dart --name "Ejecutar trip completo"
```

### Ejecutar solo validación de fixture

```bash
# Verifica que el fixture tenga datos válidos
flutter test test/integration/trip_real_integration_test.dart --name "Validar que fixture tiene datos"
```

### Inspeccionar estructura del fixture

```bash
# Imprime toda la estructura del fixture para debugging
flutter test test/integration/trip_real_integration_test.dart --name "Inspeccionar estructura"
```

---

## 📊 Paso 4: Interpretar Resultados

### Test Exitoso

```
🧪 ========================================
🧪 TEST DE INTEGRACIÓN CON DATOS REALES
🧪 ========================================
📝 Trip: Trip capturado - 2025-01-03 14:30:00
🆔 ID: trip_1234567890
📅 Capturado: 2025-01-03 14:30:00.000Z
🧪 ========================================

[RUNNER] 🚀 Iniciando test de integración: Trip capturado - 2025-01-03 14:30:00
[RUNNER] ✅ Fixture válido:
[RUNNER]    • GPS playback: 120 puntos
[RUNNER]    • Checkpoints: 3
[RUNNER]    • Segments: 4
[RUNNER]    • Stops: 2
[RUNNER] 🔧 Construyendo componentes...
[RUNNER]    • TripSteps: 4
[RUNNER]    • Stop locations: 2
[RUNNER]    • Bus routes: 1
[RUNNER] ✅ Componentes construidos
[RUNNER] 📍 Iniciando GPS playback...
[RUNNER] 🎯 Validando checkpoint: Usuario debe estar caminando a la parada
[RUNNER] ✅ Checkpoint pasó
[RUNNER] 🔄 Paso cambiado: waitForBus (index: 1)
[RUNNER] 🎯 Validando checkpoint: Usuario debe haber llegado a la parada
[RUNNER] ✅ Checkpoint pasó
[RUNNER] 🔄 Paso cambiado: onBus (index: 2)
[RUNNER] 🎯 Validando checkpoint: Usuario debe estar en el bus
[RUNNER] ✅ Checkpoint pasó
[RUNNER] 🏁 Trip completado (callback)
[RUNNER] ✅ GPS playback completado
[RUNNER] 🏁 Validando estado final...
[RUNNER] ✅ Trip completado como se esperaba

============================================================
🧪 REPORTE DE TEST DE INTEGRACIÓN
============================================================
✅ Éxito: SÍ
⏱️  Tiempo: 2456ms

📋 Checkpoints (3):
  ✅ [10s] Usuario debe estar caminando a la parada
  ✅ [30s] Usuario debe haber llegado a la parada
  ✅ [60s] Usuario debe estar en el bus

📊 Estado final:
  • stepIndex: 3
  • stepType: walkToDestination
  • stepState: completed
  • progress: 1.0
  • overallProgress: 1.0
  • isCompleted: true
  • status: completed
============================================================

✅ TEST DE INTEGRACIÓN COMPLETADO EXITOSAMENTE
```

### Test Fallido

```
[RUNNER] 🎯 Validando checkpoint: Usuario debe haber llegado a la parada
[RUNNER] ❌ Checkpoint falló:
[RUNNER]    • stepIndex esperado: 1, actual: 0
[RUNNER]    • stepType esperado: waitForBus, actual: walkToStop

============================================================
🧪 REPORTE DE TEST DE INTEGRACIÓN
============================================================
✅ Éxito: NO
⏱️  Tiempo: 1823ms

📋 Checkpoints (3):
  ✅ [10s] Usuario debe estar caminando a la parada
  ❌ [30s] Usuario debe haber llegado a la parada
     ⚠️  stepIndex esperado: 1, actual: 0
     ⚠️  stepType esperado: waitForBus, actual: walkToStop
  ❌ [60s] Usuario debe estar en el bus
     ⚠️  stepIndex esperado: 2, actual: 0
============================================================

Expected: true
  Actual: <false>
```

**Interpretación:** El usuario no avanzó al paso 1 (waitForBus) cuando debería haberlo hecho. Posible bug en detección de geofence.

---

## 🔧 Debugging de Tests Fallidos

### 1. Inspeccionar el fixture

```bash
flutter test test/integration/trip_real_integration_test.dart --name "Inspeccionar estructura"
```

Esto imprime toda la estructura del fixture para verificar que los datos sean correctos.

### 2. Agregar prints en el runner

Edita `test/helpers/trip_integration_runner.dart` y agrega prints adicionales:

```dart
// En _executeGpsPlayback()
print('[RUNNER] 📍 [${point.timestamp}s] Ubicación: ${point.lat}, ${point.lng}');
print('[RUNNER] 📍    Step actual: ${stateMachine.currentStepIndex}, Progress: ${stateMachine.currentStep.progress}');
```

### 3. Reducir velocidad del playback

En `_executeGpsPlayback()`:

```dart
// Cambiar de 10x a 1x (tiempo real)
await Future.delayed(Duration(milliseconds: deltaTime * 1000)); // Era * 10
```

### 4. Validar geometrías

Si los tests fallan porque el progreso no avanza:

```dart
// Verificar que las geometrías no estén vacías
for (final segment in fixture.route.segments) {
  print('Segment ${segment.type}: ${segment.geometry.length} puntos');
}
```

Si las geometrías están vacías, el fixture fue capturado incorrectamente.

---

## 🚀 Workflow para LLM

### Escenario: Bug en detección de boarding

**1. Contexto inicial:**
```
El usuario reporta: "El viaje no detecta cuando me subo al bus"
```

**2. Crear fixture de reproducción:**
```bash
# Usuario captura viaje real donde falla
# Pega en: test/fixtures/trip_bug_boarding.json
```

**3. Definir checkpoints específicos:**
```json
{
  "timestamp": 45,
  "name": "Usuario debe haber subido al bus aquí",
  "assertions": {
    "currentStepIndex": 2,  // Debería estar en onBus
    "currentStepType": "onBus"
  }
}
```

**4. LLM ejecuta test:**
```bash
flutter test test/integration/trip_real_integration_test.dart
```

**5. Test falla:**
```
❌ [45s] Usuario debe haber subido al bus aquí
   ⚠️  stepIndex esperado: 2, actual: 1
   ⚠️  stepType esperado: onBus, actual: waitForBus
```

**6. LLM analiza código:**
```dart
// LLM lee: GeometryAdapter._isOnBusRoute()
// Identifica: threshold muy pequeño (50m)
// Modifica: aumenta a 100m
```

**7. LLM ejecuta test de nuevo:**
```bash
flutter test test/integration/trip_real_integration_test.dart
```

**8. Test pasa:**
```
✅ Éxito: SÍ
```

**9. LLM continúa con siguiente bug.**

---

## 📚 Mejores Prácticas

### Para Fixtures

1. **Nombres descriptivos:** `trip_tres_cruces_pocitos_121.json` mejor que `trip_001.json`

2. **Un fixture por escenario:**
   - `trip_simple_1bus.json` - Viaje básico
   - `trip_trasbordo_2buses.json` - Con trasbordo
   - `trip_bug_boarding_issue.json` - Reproducir bug específico

3. **Geometrías completas:** Verifica que `geometry` no esté vacío

4. **Checkpoints conservadores:** Usa rangos amplios inicialmente, refina después

### Para Checkpoints

1. **Al menos 3 checkpoints por viaje:**
   - Inicio (caminando)
   - Medio (en parada o bus)
   - Final (llegando a destino)

2. **Checkpoints en transiciones:**
   - Justo antes de llegar a parada
   - Justo después de subir al bus
   - Justo antes de bajarse

3. **Assertions progresivas:**
   ```json
   // Checkpoint 1: solo validar que está caminando
   {"currentStepType": "walkToStop"}

   // Checkpoint 2: validar progreso también
   {"currentStepType": "walkToStop", "progressMin": 0.4}

   // Checkpoint 3: validar todo
   {"currentStepType": "waitForBus", "isWithinGeofence": true, "distanceToTargetMax": 25}
   ```

### Para GPS Playback

1. **Frecuencia adecuada:** 1 punto cada 2-5 segundos es suficiente

2. **Comments útiles:** Agrega `comment` en puntos clave:
   ```json
   {"timestamp": 30, "lat": -34.8945, "lng": -56.1672, "comment": "Llegando a parada"}
   ```

3. **Playback completo:** Captura desde origen hasta destino final

---

## ⚡ Tips Avanzados

### Ejecutar múltiples fixtures en paralelo

```bash
# Crea varios fixtures
test/fixtures/trip_scenario_1.json
test/fixtures/trip_scenario_2.json
test/fixtures/trip_scenario_3.json

# Modifica el test para iterar sobre ellos
final fixtures = [
  'trip_scenario_1.json',
  'trip_scenario_2.json',
  'trip_scenario_3.json',
];

for (final fixturePath in fixtures) {
  test('Test: $fixturePath', () async {
    final fixture = await TripFixtureData.loadFromFile('test/fixtures/$fixturePath');
    final runner = TripIntegrationRunner(fixture);
    final result = await runner.run();
    expect(result.success, true);
  });
}
```

### Generar checkpoints automáticamente

Si tienes GPS playback pero no quieres definir checkpoints manualmente:

```dart
// En TripIntegrationRunner, antes de validar checkpoints:
if (fixture.checkpoints.isEmpty) {
  _generateAutomaticCheckpoints();
}
```

Esto puede generar checkpoints básicos cada N segundos.

### Comparar fixtures (antes/después de fix)

```bash
# Captura antes del fix
test/fixtures/trip_before_fix.json

# Aplica fix al código

# Captura después del fix
test/fixtures/trip_after_fix.json

# Compara resultados
flutter test test/integration/trip_real_integration_test.dart
```

---

## 🎓 Conclusión

Este sistema de testing de integración permite:

✅ **Validación completa** - Testea todo el stack de geometría + lógica
✅ **Datos reales** - Sin mocks inventados
✅ **Iteración rápida** - Tests en ~2 segundos
✅ **Autonomía LLM** - LLM puede debuggear sin intervención humana
✅ **Reproducibilidad** - Un fixture reproduce el mismo bug 100% de las veces

**Siguiente paso:** Captura tu primer viaje real y crea tu primer fixture.
