# 🎬 Guía de GPS Sintético - Testing sin Viaje Real

## 🎯 El Problema Resuelto

**Antes:** Necesitabas grabar un viaje real para obtener GPS playback → imposible si la feature no funciona aún.

**Ahora:** Generas GPS playback SINTÉTICAMENTE desde las geometrías de la ruta → puedes testear antes de que la feature funcione.

---

## ✨ Cómo Funciona

```
Carousel (Vista Previa de Ruta)
    ↓
Geometrías Completas
    ↓
GpsPlaybackGenerator
    ↓
  - Caminar: Interpola puntos a ~1.4 m/s (5 km/h)
  - Esperar: Usuario estático en parada
  - Bus: Interpola puntos a ~8 m/s (30 km/h)
    ↓
GPS Playback Sintético (100+ puntos)
    ↓
Checkpoints Automáticos
    ↓
Fixture Completo ✅
```

---

## 🚀 Uso Rápido (2 minutos)

### Paso 1: Busca una ruta en la app

```bash
flutter run

# En la app:
# 1. Busca un destino (ej: "Pocitos")
# 2. Espera a que carguen las opciones de ruta
# 3. Click en el BOTÓN VERDE (copy icon)
```

### Paso 2: Pega el JSON

```bash
# Automáticamente incluye GPS sintético + checkpoints
pbpaste > test/fixtures/trip_real_001.json
```

### Paso 3: Ejecuta el test

```bash
flutter test test/integration/trip_real_integration_test.dart
```

**¡Eso es todo!** El GPS playback y checkpoints se generan automáticamente.

---

## 📊 Ejemplo de GPS Generado

### Input: Geometría de "Caminar"

```json
{
  "type": "CAMINAR",
  "duration": 180,
  "distance": 250,
  "geometry": [
    {"lat": -34.9011, "lng": -56.1645},
    {"lat": -34.9010, "lng": -56.1644},
    {"lat": -34.9008, "lng": -56.1642},
    {"lat": -34.9005, "lng": -56.1640}
  ]
}
```

### Output: GPS Playback Sintético

```json
"gpsPlayback": [
  {
    "timestamp": 0,
    "lat": -34.9011,
    "lng": -56.1645,
    "comment": "Inicio: Caminar a parada"
  },
  {
    "timestamp": 2,
    "lat": -34.90105,
    "lng": -56.16448
  },
  {
    "timestamp": 4,
    "lat": -34.90095,
    "lng": -56.16443
  },
  // ... más puntos cada 2 segundos
  {
    "timestamp": 178,
    "lat": -34.9005,
    "lng": -56.1640,
    "comment": "Llegada: Caminar a parada"
  }
]
```

### Output: Checkpoints Automáticos

```json
"checkpoints": [
  {
    "timestamp": 2,
    "name": "Inicio: Caminar a parada",
    "assertions": {
      "currentStepIndex": 0,
      "currentStepType": "walkToStop"
    }
  },
  {
    "timestamp": 89,
    "name": "Mitad: Caminar a parada",
    "assertions": {
      "currentStepIndex": 0,
      "progressMin": 0.3,
      "progressMax": 0.7
    }
  },
  {
    "timestamp": 176,
    "name": "Llegando a: Esperar bus línea 64",
    "assertions": {
      "currentStepIndex": 0,
      "progressMin": 0.8
    }
  }
]
```

---

## 🔧 Configuración Avanzada

### Cambiar velocidad de simulación

En `app_host.dart`, cuando llamas a `captureTripToClipboard`:

```dart
await TripDataCaptureService.captureTripToClipboard(
  tripId: 'trip_${DateTime.now().millisecondsSinceEpoch}',
  origin: origin,
  destination: destination,
  selectedRoute: selectedRoute,
  // Opciones para GPS sintético:
  generateSyntheticGps: true,  // true = generar, false = usar grabación manual
  generateCheckpoints: true,   // true = generar automáticamente
);
```

### Desactivar generación automática

```dart
await TripDataCaptureService.captureTripToClipboard(
  tripId: 'trip_123',
  origin: origin,
  destination: destination,
  selectedRoute: selectedRoute,
  generateSyntheticGps: false,     // No generar GPS sintético
  generateCheckpoints: false,      // No generar checkpoints
  manualGpsPlayback: customGps,    // Proveer GPS manual
  manualCheckpoints: customChecks, // Proveer checkpoints manual
);
```

---

## 🧪 Ventajas del GPS Sintético

### ✅ Pro

1. **No necesitas viaje real** - Testeas antes de que la feature funcione
2. **Determinístico** - Mismo input = mismo output siempre
3. **Rápido** - 2 minutos para capturar fixture completo
4. **Checkpoints automáticos** - No defines manualmente
5. **Consistente con geometrías** - Usa las mismas geometrías que la app

### ⚠️ Consideraciones

1. **Simplificado** - Velocidades constantes, no considera semáforos/tráfico
2. **Sin ruido GPS** - GPS real tiene imprecisiones, el sintético es perfecto
3. **Sin comportamiento humano** - Usuario no se detiene, no se desvía

**Para 90% de los casos, GPS sintético es suficiente.**

---

## 📐 Algoritmo de Generación

### Para CAMINAR

```
Velocidad: 1.4 m/s (~5 km/h)
Muestreo: Cada 2 segundos

Para cada geometría:
  1. Calcular distancia total de la polilínea
  2. t = 0
  3. Mientras no llegaste al final:
     a. Avanzar 2.8m (1.4 m/s × 2s)
     b. Encontrar punto en geometría a esa distancia
     c. Agregar punto GPS con timestamp t
     d. t += 2
```

### Para ESPERAR_BUS

```
Usuario estático en la parada

Para duración de espera:
  1. Obtener posición de parada
  2. Generar puntos cada 5 segundos
  3. Todos con la misma coordenada (usuario no se mueve)
```

### Para VIAJE_EN_BUS

```
Velocidad: 8 m/s (~30 km/h)
Muestreo: Cada 3 segundos

Similar a CAMINAR pero:
  - Mayor velocidad
  - Mayor intervalo de muestreo
```

---

## 🎯 Cuándo Usar GPS Sintético vs Real

### Usa GPS Sintético cuando:

- ✅ Desarrollas feature nueva (aún no funciona)
- ✅ Quieres tests rápidos y determinísticos
- ✅ Geometrías son confiables
- ✅ No te importan imperfecciones de GPS real

### Usa GPS Real cuando:

- ✅ Debuggeas bug específico en producción
- ✅ Quieres reproducir comportamiento exacto de usuario
- ✅ GPS tiene ruido/saltos que causaron el bug
- ✅ Feature ya funciona y puedes grabar viaje

---

## 🔍 Validar Calidad del GPS Sintético

### Test de inspección

```bash
flutter test test/integration/trip_real_integration_test.dart --name "Inspeccionar"
```

Esto imprime:
```
GPS Playback: 87 puntos
  • Primer punto: t=0s
  • Último punto: t=172s
  • Duración total: 172s

Checkpoints: 12
  • [2s] Inicio: Caminar a parada
  • [86s] Mitad: Caminar a parada
  ...
```

### Validar timestamps

Los timestamps deben:
- ✅ Empezar en 0
- ✅ Incrementar monótonamente
- ✅ Tener intervalos razonables (2-5 segundos)
- ✅ Duración total ≈ suma de duraciones de tramos

### Validar coordenadas

Las coordenadas deben:
- ✅ Estar dentro de la geometría de cada tramo
- ✅ Progresar en la dirección correcta
- ✅ No tener saltos grandes (>100m entre puntos consecutivos)

---

## 💡 Tips

### Ajustar checkpoints generados

Si los checkpoints automáticos son muy agresivos:

```dart
// Editar manualmente el JSON después de capturar
// Cambiar progressMin/progressMax para ser más permisivos

// Antes (automático):
"progressMin": 0.3,
"progressMax": 0.7

// Después (manual):
"progressMin": 0.2,
"progressMax": 0.8  // Rango más amplio
```

### Agregar checkpoints adicionales

```json
{
  "timestamp": 45,
  "name": "Checkpoint custom - detección de boarding",
  "assertions": {
    "currentStepIndex": 2,
    "currentStepType": "onBus",
    "isWithinGeofence": false  // Ya salió de la parada
  }
}
```

### Debuggear generación

En `gps_playback_generator.dart`, los prints muestran:

```
[GPSGenerator] 🎬 Generando GPS playback para 4 tramos
[GPSGenerator] 📍 Tramo 1/4: CAMINAR
[GPSGenerator]    ✅ 89 puntos generados (178s)
[GPSGenerator] 📍 Tramo 2/4: ESPERAR_BUS
[GPSGenerator]    ✅ 60 puntos generados (esperando)
[GPSGenerator] 📍 Tramo 3/4: VIAJE_EN_BUS
[GPSGenerator]    ✅ 120 puntos generados (360s)
[GPSGenerator] 📍 Tramo 4/4: CAMINAR
[GPSGenerator]    ✅ 40 puntos generados (80s)
[GPSGenerator] 🎉 GPS playback generado: 309 puntos totales, 618s duración
```

Si ves `⚠️  Sin geometría`, la ruta capturada no tiene geometrías completas.

---

## 🚀 Workflow Completo

### Desarrollo con TDD usando GPS Sintético

```bash
# 1. Capturar ruta desde carousel (sin viaje real)
flutter run → buscar destino → click botón verde
pbpaste > test/fixtures/trip_tres_cruces_pocitos.json

# 2. Verificar que se generó correctamente
flutter test test/integration/trip_real_integration_test.dart --name "Inspeccionar"

# 3. Ejecutar test (fallará - feature no implementada)
flutter test test/integration/trip_real_integration_test.dart

# 4. Implementar feature hasta que pase
# (iterar modificando código + re-ejecutando test)

# 5. Test pasa → Feature funciona ✅
```

---

## 📚 Archivos Relevantes

- **[lib/devtools/gps_playback_generator.dart](../lib/devtools/gps_playback_generator.dart)** - Generador sintético
- **[lib/devtools/trip_data_capture_service.dart](../lib/devtools/trip_data_capture_service.dart)** - Servicio de captura (integrado)
- **[test/helpers/trip_integration_runner.dart](helpers/trip_integration_runner.dart)** - Runner de tests
- **[test/INTEGRATION_TESTING_GUIDE.md](INTEGRATION_TESTING_GUIDE.md)** - Guía general

---

## ✅ Conclusión

El GPS sintético te permite:

- ✅ Testear **antes** de que la feature funcione
- ✅ Generar fixtures completos en **2 minutos**
- ✅ Checkpoints **automáticos** (no manual)
- ✅ Tests **determinísticos** (mismos resultados siempre)
- ✅ Desarrollo **TDD** desde el primer día

**No necesitas esperar a que la feature funcione para empezar a testearla.** 🚀
