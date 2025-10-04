# 🧪 Testing con Datos Reales - Guía Completa

## 🎯 Objetivo

Testear la geometría y lógica de viajes con **datos 100% reales** capturados de la app, para que el LLM pueda iterar autónomamente con feedback de tests.

---

## 🚀 Flujo Completo (5 minutos)

### Paso 1: Capturar Trip Real (30 segundos)

1. Abre la app en modo debug
2. Busca un destino (Ej: "18 de Julio")
3. Verás el carousel de opciones de rutas
4. Presiona el **botón verde flotante** (📋) con ícono de "content_copy"
5. Verás mensaje: **"✅ Trip copiado al portapapeles!"**

### Paso 2: Guardar como Fixture (1 minuto)

```bash
# En terminal
cd test/fixtures

# Crear archivo con nombre descriptivo
cat > trip_mi_casa_trabajo.json
# Pega (Cmd+V) el JSON del portapapeles
# Presiona Ctrl+D para guardar
```

**Convención de nombres:**
- `trip_casa_trabajo_1bus.json` - Viaje simple con 1 bus
- `trip_centro_pocitos_trasbordo.json` - Con trasbordo
- `trip_universidad_cv_3buses.json` - Con múltiples trasbordos

### Paso 3: Crear Test (3 minutos)

Crea `test/journey/integration/trip_mi_casa_trabajo_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:bondi_uy/devtools/trip_simulator.dart';
import '../helpers/trip_fixture_data.dart';

void main() {
  test('Viaje casa-trabajo debe completarse correctamente', () async {
    // 1. Cargar fixture
    final tripData = await TripFixtureData.loadFromFile(
      'test/fixtures/trip_mi_casa_trabajo.json',
    );

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🧪 ${tripData.name}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('Origen: ${tripData.origin.name}');
    print('Destino: ${tripData.destination.name}');
    print('Segmentos: ${tripData.route.segments.length}');

    // 2. TODO: Setup del sistema completo con datos reales
    //    (Aquí usarás el TripSimulator que ya tienes)

    // 3. TODO: Ejecutar simulación

    // 4. TODO: Verificar que completó correctamente

    // Por ahora, solo verifica que el JSON sea válido
    expect(tripData.tripId, isNotEmpty);
    expect(tripData.route.segments, isNotEmpty);
    expect(tripData.expectedBehavior.shouldComplete, true);

    print('✅ Test básico pasó - JSON válido');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  });
}
```

### Paso 4: Ejecutar Test

```bash
flutter test test/journey/integration/trip_mi_casa_trabajo_test.dart
```

**Resultado esperado:**
```
00:00 +1: All tests passed!
```

---

## 📋 Qué Contiene el JSON Capturado

El JSON tiene toda la info necesaria para reproducir el viaje:

```json
{
  "tripId": "trip_1704290400000",
  "name": "Trip capturado - 2025-01-03 12:00:00",
  "capturedAt": "2025-01-03T12:00:00.000Z",

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
    "routeId": "route_123",
    "recommended": true,
    "totalDuration": 1200,
    "totalWalkDistance": 600,
    "totalWaitTime": 300,

    "stops": [
      {
        "stopId": "stop_1",
        "name": "Bulevar Artigas",
        "lat": -34.9000,
        "lng": -56.1640,
        "busLines": ["64"]
      }
    ],

    "segments": [
      {
        "type": "CAMINAR",
        "description": "Caminar a parada",
        "duration": 300,
        "distance": 400,
        "from": "origin",
        "to": "next_stop",
        "geometry": [
          {"lat": -34.9011, "lng": -56.1645},
          {"lat": -34.9000, "lng": -56.1640}
        ]
      },
      {
        "type": "ESPERAR_BUS",
        "description": "Esperar bus línea 64",
        "duration": 300,
        "at": "stop_1",
        "busLine": "64",
        "hasEta": true,
        "etaMinutes": 5
      },
      {
        "type": "VIAJE_EN_BUS",
        "description": "Bus 64",
        "duration": 600,
        "from": "stop_1",
        "to": "stop_2",
        "busLine": "64",
        "shapeId": "shape_64_A",
        "geometry": [/* puntos de la ruta del bus */]
      },
      {
        "type": "CAMINAR",
        "description": "Caminar a destino",
        "duration": 180,
        "distance": 200,
        "from": "stop_2",
        "to": "destination",
        "geometry": [/* puntos */]
      }
    ]
  },

  "initialBusPosition": {
    "lat": -34.9020,
    "lng": -56.1660,
    "capturedAt": "2025-01-03T12:00:00.000Z"
  },

  "expectedBehavior": {
    "totalDuration": 1380,
    "stepsExpected": 4,
    "shouldComplete": true,
    "description": "Trip capturado desde la app"
  }
}
```

**Ventajas:**
- ✅ **Coordenadas reales** de Montevideo
- ✅ **Geometrías reales** de las rutas
- ✅ **Paradas reales** con IDs reales
- ✅ **Durations reales** del planificador
- ✅ **100% reproducible**

---

## 🧪 Cómo Crear el Test de Integración Completo

El test debe:
1. Cargar el JSON
2. Crear el sistema completo (providers, journey manager, etc.)
3. Simular GPS usando `TripSimulator`
4. Verificar que el viaje se complete correctamente

**Estructura del test:**

```dart
test('Viaje real debe completarse', () async {
  // 1. CARGAR FIXTURE
  final tripData = await TripFixtureData.loadFromFile('...');

  // 2. CREAR MOCKS con datos reales
  final container = ProviderContainer(
    overrides: [
      // Mock API con datos del fixture
      montevideoApiServiceProvider.overrideWithValue(
        MockApiWithFixtureData(tripData),
      ),
      // Mock Planning con la ruta del fixture
      itineraryPlanningServiceProvider.overrideWithValue(
        MockPlanningWithFixtureData(tripData),
      ),
    ],
  );

  final notifier = container.read(appLogicProvider.notifier);

  // 3. INICIAR VIAJE
  await notifier.seleccionarDestinoYBuscarRutas(tripData.destination.toCoord());
  await notifier.iniciarViajeConOpcion(tripData.route.routeId);

  // 4. SIMULAR GPS con TripSimulator
  final simulator = TripSimulator(
    notifier,
    speed: 10.0, // Rápido para test
    initialBusPosition: tripData.initialBusPosition?.toCoord(),
  );

  await simulator.start();

  // 5. ESPERAR COMPLETACIÓN (con timeout)
  final completed = await _waitForCompletion(
    notifier,
    timeout: Duration(seconds: 30),
  );

  // 6. VERIFICAR
  expect(completed, true, reason: 'El viaje debe completarse');

  final finalState = notifier.state;
  expect(finalState.faseActual, FaseUI.NAVEGACION_NORMAL);

  simulator.stop();
});
```

---

## 🎓 Casos de Uso

### Caso 1: Trip Simple (1 Bus)
```bash
# Capturar
1. Busca un trip simple (1 bus, sin trasbordo)
2. Click botón verde
3. Guarda en: test/fixtures/trip_simple_1bus.json
```

**Para qué:**
- Validar que el flujo básico funciona
- Detectar: llegada a parada, subida al bus, llegada al destino

### Caso 2: Trip con Trasbordo (2 Buses)
```bash
# Capturar
1. Busca un trip con trasbordo
2. Click botón verde
3. Guarda en: test/fixtures/trip_trasbordo_2buses.json
```

**Para qué:**
- Validar trasbordos
- Detectar: bajada del primer bus, caminata a segunda parada, subida al segundo bus

### Caso 3: Trip Complejo (3+ Buses)
```bash
# Capturar
1. Busca un trip largo con múltiples trasbordos
2. Click botón verde
3. Guarda en: test/fixtures/trip_complejo_3buses.json
```

**Para qué:**
- Validar casos extremos
- Estrés test del sistema

### Caso 4: Bug Reproducible
```bash
# Cuando encuentres un bug:
1. Reproduce el bug en la app
2. Captura ese trip específico
3. Guarda en: test/fixtures/trip_bug_descripcion.json
4. Crea test que falle reproduciendo el bug
5. Fix el bug
6. Test debe pasar
7. Commit test + fix juntos
```

---

## ✅ Checklist para Capturar Buenos Fixtures

- [ ] **Nombre descriptivo** - `trip_casa_trabajo_1bus.json`
- [ ] **Documenta qué testea** - Agrega en `expectedBehavior.description`
- [ ] **Captura variedad** - Simple, trasbordo, complejo
- [ ] **Captura bugs** - Si encuentras uno, captúralo
- [ ] **Geometrías completas** - Que tengan `geometry` con puntos
- [ ] **ETA real** - Captura cuando haya ETA disponible

---

## 🔄 Workflow con LLM

### 1. Captura varios trips reales
```bash
test/fixtures/
├── trip_casa_trabajo_1bus.json
├── trip_centro_pocitos_trasbordo.json
├── trip_universidad_cv_3buses.json
└── trip_bug_no_detecta_parada.json
```

### 2. Crea tests para cada uno

### 3. LLM itera autónomamente

```
LLM:
1. Lee el fixture
2. Crea/modifica código de geometría
3. Ejecuta: flutter test
4. Ve resultado: PASA o FALLA
5. Si falla → ajusta código → goto 3
6. Si pasa → siguiente fixture
```

**SIN INTERVENCIÓN HUMANA** ✨

---

## 📁 Estructura Final

```
test/
├── fixtures/
│   ├── README.md
│   ├── trip_simple_1bus.json
│   ├── trip_trasbordo_2buses.json
│   └── trip_complejo_3buses.json
├── helpers/
│   └── trip_fixture_data.dart
└── journey/
    └── integration/
        ├── trip_simple_test.dart
        ├── trip_trasbordo_test.dart
        └── trip_complejo_test.dart
```

---

## 🚀 Próximos Pasos

1. ✅ **Captura 3 trips reales** (simple, trasbordo, complejo)
2. ✅ **Guárdalos como fixtures**
3. ⏳ **Crea tests básicos** (solo validar JSON por ahora)
4. ⏳ **Integra con TripSimulator** (usar el que ya tienes)
5. ⏳ **Agrega verificaciones** (que el viaje complete)
6. ⏳ **Itera con LLM** hasta que todos pasen

---

## 💡 Tips

- **Captura en diferentes momentos del día** - ETAs diferentes
- **Captura diferentes zonas** - Centro, Pocitos, Ciudad Vieja, etc.
- **Captura con/sin ETA** - Para testear ambos casos
- **Si algo falla, captúralo** - Los bugs son los mejores test cases

---

## ❓ FAQ

**P: ¿Qué pasa si cambio la estructura de datos?**
R: Actualiza `TripDataCaptureService` y `TripFixtureData.fromJson()`

**P: ¿Los fixtures quedan obsoletos?**
R: Sí, si cambia la API de planificación. Re-captura cuando sea necesario.

**P: ¿Cuántos fixtures necesito?**
R: Empieza con 3-5 casos representativos. Agrega más según encuentres bugs.

**P: ¿El LLM puede crear los tests solo?**
R: Sí, dale los fixtures y le pides que cree tests de integración completos.

---

**¡Ahora tienes todo para testear con datos reales! 🎉**
