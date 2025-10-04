# 🧪 Testing de Integración con Datos Reales - README

## ⚡ NUEVO: GPS Sintético Automático

**Ya no necesitas grabar viaje real.** El GPS playback y checkpoints se generan **automáticamente** desde las geometrías.

Ver: **[SYNTHETIC_GPS_GUIDE.md](SYNTHETIC_GPS_GUIDE.md)** - Guía completa

---

## ✨ Quick Start (2 minutos)

### 1. Captura ruta desde carousel

```bash
# Ejecuta la app
flutter run

# 1. Busca un destino
# 2. Click en botón VERDE (copy icon)
# 3. Pega el JSON:
pbpaste > test/fixtures/trip_real_001.json
```

**¡Listo!** El JSON ya incluye:
- ✅ GPS playback sintético (100+ puntos)
- ✅ Checkpoints automáticos (10+ checkpoints)
- ✅ Geometrías completas

### 2. Ejecuta el test

```bash
flutter test test/integration/trip_real_integration_test.dart
```

**No necesitas:**
- ❌ Grabar viaje real
- ❌ Agregar checkpoints manualmente
- ❌ Esperar a que la feature funcione

---

## 🎯 ¿Qué hace este sistema?

Este sistema ejecuta **TODA** la lógica real de la app (GPS, geometría, detección de pasos) usando datos 100% reales capturados desde la app.

### Lo que se testea:

```
Coordenadas GPS Reales
    ↓
GeometryAdapter (CAPA 2)
    ↓
  - Cálculo de distancias
  - Geofencing
  - Detección de proximidad a parada
  - Detección de proximidad a ruta de bus
    ↓
StepDetectionContext (interfaz)
    ↓
TripStateMachine (CAPA 1)
    ↓
  - Detección de llegada a parada
  - Detección de subida al bus
  - Progreso del viaje
  - Transiciones de pasos
    ↓
Validación Programática (Checkpoints)
```

### ✅ Antes vs Después

| Antes | Después |
|-------|---------|
| Testear en emulador (30s+) | Tests automáticos (<3s) |
| Reportar bugs verbalmente | Checkpoints programáticos |
| LLM espera feedback | LLM itera autónomo |
| Mocks inventados | Datos 100% reales |
| TDD imposible | TDD completo |

---

## 📁 Archivos Creados

### Core del sistema

- **[test/helpers/trip_integration_runner.dart](test/helpers/trip_integration_runner.dart)** - Runner que ejecuta todo el stack
- **[test/helpers/trip_fixture_data.dart](test/helpers/trip_fixture_data.dart)** - Parser de fixtures (actualizado)
- **[test/integration/trip_real_integration_test.dart](test/integration/trip_real_integration_test.dart)** - Tests de integración

### Herramientas de captura

- **[lib/devtools/trip_data_capture_service.dart](lib/devtools/trip_data_capture_service.dart)** - Servicio para capturar GPS playback (actualizado)

### Documentación

- **[test/INTEGRATION_TESTING_GUIDE.md](test/INTEGRATION_TESTING_GUIDE.md)** - Guía completa paso a paso
- **[test/INTEGRATION_TESTING_README.md](test/INTEGRATION_TESTING_README.md)** - Este archivo (quick start)

### Fixtures

- **[test/fixtures/trip_example_simple.json](test/fixtures/trip_example_simple.json)** - Placeholder para datos reales

---

## 🔑 Conceptos Clave

### Fixture = Datos Reales Capturados

Un fixture contiene:
- ✅ Origen y destino
- ✅ Ruta con stops y segments
- ✅ **Geometrías completas** (puntos GPS de cada segment)
- ✅ **GPS Playback** (ubicaciones GPS simuladas segundo a segundo)
- ✅ **Checkpoints** (validaciones programáticas)

### Checkpoint = Validación Programática

Un checkpoint dice: "En el segundo X, el sistema debería estar en el estado Y"

Ejemplo:
```json
{
  "timestamp": 30,
  "name": "Usuario llegó a la parada",
  "assertions": {
    "currentStepIndex": 1,
    "currentStepType": "waitForBus",
    "isWithinGeofence": true
  }
}
```

Si el test falla, sabes **exactamente** qué esperabas vs qué obtuviste.

### GPS Playback = Simulación Determinística

En vez de GPS real (no determinístico), reproducimos la secuencia exacta de ubicaciones GPS.

Ventaja: **Reproducibilidad 100%** - mismo fixture = mismo resultado siempre.

---

## 🚀 Casos de Uso

### Caso 1: Desarrollar nueva feature con TDD

```bash
# 1. Crear fixture con escenario deseado
# 2. Definir checkpoints de comportamiento esperado
# 3. Ejecutar test (fallará - feature no existe)
# 4. Implementar feature
# 5. Ejecutar test hasta que pase
# 6. Refactorizar con confianza
```

### Caso 2: Debuggear bug reportado

```bash
# 1. Usuario reporta: "No detecta cuando subo al bus"
# 2. Capturar fixture del viaje donde falla
# 3. Agregar checkpoint: "En segundo X debe detectar boarding"
# 4. Test falla (reproduce el bug)
# 5. Fix el código
# 6. Test pasa (bug corregido)
# 7. Fixture queda como test de regresión
```

### Caso 3: Iterar con LLM autónomamente

```bash
# 1. Crear fixture con datos reales
# 2. Definir checkpoints claros
# 3. Decirle al LLM: "Haz que este test pase"
# 4. LLM modifica código, ejecuta test, analiza error, repite
# 5. LLM reporta cuando el test pasa
# 6. Humano valida el código final
```

---

## 📖 Documentación Completa

Lee **[test/INTEGRATION_TESTING_GUIDE.md](test/INTEGRATION_TESTING_GUIDE.md)** para:

- ✅ Explicación detallada de cada componente
- ✅ Cómo capturar GPS playback durante viajes activos
- ✅ Cómo definir buenos checkpoints
- ✅ Cómo debuggear tests fallidos
- ✅ Ejemplos completos de fixtures
- ✅ Tips avanzados y mejores prácticas

---

## 🧪 Comandos Útiles

```bash
# Ejecutar test de integración
flutter test test/integration/trip_real_integration_test.dart

# Ejecutar solo validación de fixture
flutter test test/integration/trip_real_integration_test.dart --name "Validar que fixture"

# Inspeccionar estructura del fixture
flutter test test/integration/trip_real_integration_test.dart --name "Inspeccionar"

# Ejecutar todos los tests (unit + integration)
./scripts/test_journey_core.sh
```

---

## ⚠️ Importante

### El fixture debe tener datos reales

El placeholder en `test/fixtures/trip_example_simple.json` tiene:
```json
{
  "tripId": "PLACEHOLDER",
  "name": "ESTE ES UN PLACEHOLDER - Pegar datos reales"
}
```

**Debes reemplazarlo** con datos capturados desde la app, o el test fallará.

### Las geometrías deben estar completas

Si capturas un fixture y las geometrías están vacías:
```json
"geometry": []  // ❌ MALO - no se puede calcular distancias
```

Verifica que el botón de captura esté obteniendo las geometrías correctamente del estado de la app.

---

## 🎓 Siguientes Pasos

1. **Captura tu primer fixture real:**
   - Ejecuta la app
   - Busca un destino
   - Click en botón verde
   - Pega en `test/fixtures/trip_real_001.json`

2. **Agrega 2-3 checkpoints básicos:**
   - Inicio del viaje
   - Llegada a parada
   - Final del viaje

3. **Ejecuta el test:**
   ```bash
   flutter test test/integration/trip_real_integration_test.dart
   ```

4. **Si falla, debuggea usando la guía:**
   - Lee [test/INTEGRATION_TESTING_GUIDE.md](test/INTEGRATION_TESTING_GUIDE.md)
   - Sección "Debugging de Tests Fallidos"

5. **Itera hasta que pase:**
   - Modifica código
   - Re-ejecuta test
   - Analiza errores
   - Repite

---

## 💡 Tips

- **Empieza simple:** Fixture con 1 bus, sin trasbordo
- **Checkpoints conservadores:** Usa rangos amplios inicialmente
- **Un fixture por bug:** Cada bug reproducible merece su fixture
- **Nombres descriptivos:** `trip_bug_boarding_121.json` > `trip_002.json`

---

## 🤝 Ayuda

Si algo no funciona:

1. Lee la guía completa: [test/INTEGRATION_TESTING_GUIDE.md](test/INTEGRATION_TESTING_GUIDE.md)
2. Ejecuta el test de inspección para ver la estructura del fixture
3. Verifica que las geometrías no estén vacías
4. Revisa los prints en la consola - son muy verbosos a propósito

---

¡Listo! Ahora tienes un sistema de testing que permite desarrollar con TDD usando datos 100% reales. 🚀
