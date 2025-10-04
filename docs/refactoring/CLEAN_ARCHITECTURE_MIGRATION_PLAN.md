# Plan de Migración a Arquitectura Clean
## Eliminar TramoViajeMostrable en favor de TripStep

**Fecha:** 2025-10-03
**Estado:** Análisis de Complejidad
**Versión Actual:** Usando adaptador temporal `journey_to_core_adapter.dart`

---

## Resumen Ejecutivo

**Problema:** Tenemos DOS modelos de datos paralelos:
- `TramoViajeMostrable` (legacy) - Usado en toda la app
- `TripStep` (core) - Arquitectura nueva, solo en tests

**Solución Actual:** Adaptador que convierte entre ambos (temporal pero funcional)

**Solución Clean:** Eliminar `TramoViajeMostrable` completamente, usar solo `TripStep`

**Complejidad Estimada:**
- **Tiempo:** 2-3 semanas (160-240 horas)
- **Riesgo:** ALTO
- **Archivos afectados:** 24 archivos
- **Tests requeridos:** Extensivos

---

## Análisis de Impacto

### 1. Archivos que Usan TramoViajeMostrable

| Archivo | Ocurrencias | Complejidad | Horas Est. |
|---------|------------|-------------|------------|
| `lib/ui/overlays/active_trip_overlay.dart` | 10 | ALTA | 20h |
| `lib/map_manager/map_bus_realtime.dart` | 10 | ALTA | 16h |
| `lib/journey/journey_manager.dart` | 8 | MEDIA | 12h |
| `lib/map_manager/map_route_renderer.dart` | 6 | ALTA | 16h |
| `lib/backend/contrato_ui/app_ui_state.dart` | 6 | CRÍTICA | 24h |
| `lib/backend/services/itinerary_planning_service_adapter.dart` | 5 | CRÍTICA | 20h |
| `lib/devtools/gps_playback_generator.dart` | 5 | MEDIA | 8h |
| `lib/map_manager/map_camera_controller.dart` | 4 | MEDIA | 8h |
| `lib/backend/providers/app_logic_provider.dart` | 3 | MEDIA | 8h |
| Tests (4 archivos) | ~20 | MEDIA | 16h |
| Otros (docs, scripts) | ~10 | BAJA | 8h |
| **TOTAL** | **87+** | - | **156h** |

### 2. Estructuras que Requieren Refactorización

#### 2.1 OpcionDeRutaMostrable
```dart
class OpcionDeRutaMostrable {
  final List<TramoViajeMostrable> tramosParaPreview;  // ← CAMBIAR
  // ... otros 10 campos
}
```

**Impacto:**
- Usado en carousel de rutas (UI crítica)
- Parser del API OTP lo construye
- 15+ lugares lo referencian

**Cambios necesarios:**
```dart
class OpcionDeRutaMostrable {
  final List<TripStep> tramosParaPreview;  // ✅ NUEVO
  // ... resto igual
}
```

#### 2.2 EstadoFaseViajeActivo
```dart
class EstadoFaseViajeActivo {
  final List<TramoViajeMostrable> tramosDelViaje;  // ← CAMBIAR
  final OpcionDeRutaMostrable opcionDeRutaSeleccionada;  // También afectado
  // ... otros campos
}
```

**Impacto:**
- Estado CENTRAL del viaje activo
- Usado por JourneyManager, MapManager, UI
- 30+ lugares lo referencian

---

## Tareas de Refactorización

### FASE 1: Modelo de Datos (40h)

#### 1.1 Extender TripStep con Campos UI (8h)
**Archivo:** `lib/journey/core/trip_step.dart`

**Cambios:**
```dart
class TripStep {
  // Campos existentes (arquitectura core)
  final String id;
  final TripStepType type;
  final String description;
  final TripStepMetadata metadata;

  // NUEVOS campos para compatibilidad UI
  final List<Coordenada>? geometry;  // geometriaPolilinea
  final Coordenada? pointPosition;   // posicionPunto
  final int? estimatedDurationSeconds;
  final int? distanceMeters;
  final String? destinationName;     // Para UI
  final String? busDestination;      // destinoFinalDelBus
  final String? shapeId;
  final int? estimatedBusArrivalMinutes;
  final bool? isRealTimeBus;
  final Coordenada? currentBusPosition;

  // ... resto
}
```

**Razón:** TripStep actual solo tiene metadata mínimo. UI necesita más información.

#### 1.2 Crear TripStepMetadataExtended (4h)
**Archivo:** `lib/journey/core/trip_step.dart`

```dart
class TripStepMetadataExtended extends TripStepMetadata {
  final String? stopOriginName;
  final String? stopDestinationName;
  final Coordenada? stopOriginCoords;
  final Coordenada? stopDestinationCoords;
  final String? busDestinationName;

  // ... constructores
}
```

#### 1.3 Refactorizar AppUiState (12h)
**Archivo:** `lib/backend/contrato_ui/app_ui_state.dart`

**Cambios:**
```dart
// ANTES
class OpcionDeRutaMostrable {
  final List<TramoViajeMostrable> tramosParaPreview;
}

class EstadoFaseViajeActivo {
  final List<TramoViajeMostrable> tramosDelViaje;
}

// DESPUÉS
class OpcionDeRutaMostrable {
  final List<TripStep> tramosParaPreview;  // ✅
}

class EstadoFaseViajeActivo {
  final List<TripStep> tramosDelViaje;  // ✅
}
```

**Impacto en cascada:**
- Todos los `copyWith()` deben actualizar tipo
- Todos los constructores deben actualizar tipo
- Serialización/deserialización si existe

#### 1.4 Eliminar TramoViajeMostrable (4h)
**Archivo:** `lib/backend/contrato_ui/app_ui_state.dart`

- Eliminar clase completa (150 líneas)
- Eliminar enum `TipoTramoViaje` → usar `TripStepType`
- Actualizar imports en 24 archivos

#### 1.5 Tests de Modelos (12h)
- Test de TripStep extendido
- Test de compatibilidad con UI
- Test de serialización

---

### FASE 2: Parser del API OTP (24h)

#### 2.1 Refactorizar ItineraryPlanningServiceAdapter (16h)
**Archivo:** `lib/backend/services/itinerary_planning_service_adapter.dart`

**Función crítica:** `_adaptOneOTPItineraryToMostrable()`

**ANTES (actual):**
```dart
tramosDelItinerario.add(
  TramoViajeMostrable(
    idTramo: _generateUniqueId("walk${itineraryOtpIndex}_$i"),
    tipo: TipoTramoViaje.CAMINAR,
    geometriaPolilinea: geometria,
    descripcion: "Caminar hacia ${leg.to?.name}",
    duracionEstimadaSegundos: legDurationSec,
    distanciaMetros: legDistanceMet,
  ),
);
```

**DESPUÉS (nuevo):**
```dart
tramosDelItinerario.add(
  TripStep(
    id: _generateUniqueId("walk${itineraryOtpIndex}_$i"),
    type: TripStepType.walkToStop,  // Lógica de inferencia
    description: "Caminar hacia ${leg.to?.name}",
    metadata: TripStepMetadataExtended(
      totalDistanceMeters: legDistanceMet.toDouble(),
      destinationStopId: leg.to?.stopId,
      stopDestinationName: leg.to?.name,
      stopDestinationCoords: coordDestinoTramo,
    ),
    geometry: geometria,
    estimatedDurationSeconds: legDurationSec,
    distanceMeters: legDistanceMet,
  ),
);
```

**Desafíos:**
1. **Inferencia de tipo:** Determinar `walkToStop` vs `walkToDestination`
2. **Metadata completo:** Extraer todos los campos necesarios de OTP Leg
3. **Bus route geometry:** Manejar shapeId y geometría completa
4. **ETA parsing:** Convertir tiempo real del bus

#### 2.2 Tests de Parsing (8h)
- Test con respuestas reales de OTP
- Test de edge cases (sin geometría, sin ETA, etc.)
- Test de inferencia de tipos

---

### FASE 3: UI Components (36h)

#### 3.1 ActiveTripOverlay (12h)
**Archivo:** `lib/ui/overlays/active_trip_overlay.dart`

**Cambios típicos:**
```dart
// ANTES
final TramoViajeMostrable tramo = tramosDelViaje[currentStepIndex];
final String? busLine = tramo.nombreLineaBus;
final Coordenada? stopCoords = tramo.coordenadasParadaOrigen;

// DESPUÉS
final TripStep step = tramosDelViaje[currentStepIndex];
final String? busLine = step.metadata.busLine;
final Coordenada? stopCoords = step.metadata.stopOriginCoords;
```

**10 ocurrencias** de acceso a campos → actualizar todas

#### 3.2 Route Preview Carousel (8h)
**Ubicación:** Donde se muestra `OpcionDeRutaMostrable.tramosParaPreview`

**Cambios:**
- Acceso a campos de cada tramo
- Iconos basados en `TripStepType` en vez de `TipoTramoViaje`
- Formateo de duración/distancia

#### 3.3 Otros Componentes UI (16h)
- Indicadores de progreso
- Instrucciones de navegación
- Tooltips y labels
- Debugging panels

---

### FASE 4: Mapa y Visualización (32h)

#### 4.1 MapRouteRenderer (12h)
**Archivo:** `lib/map_manager/map_route_renderer.dart`

**Función crítica:** `renderRoute(List<TramoViajeMostrable> tramos)`

**Cambios:**
```dart
// ANTES
void renderRoute(List<TramoViajeMostrable> tramos) {
  for (final tramo in tramos) {
    if (tramo.tipo == TipoTramoViaje.CAMINAR) {
      final geometry = tramo.geometriaPolilinea;
      // ...
    }
  }
}

// DESPUÉS
void renderRoute(List<TripStep> steps) {
  for (final step in steps) {
    if (step.type == TripStepType.walkToStop ||
        step.type == TripStepType.walkToDestination) {
      final geometry = step.geometry;
      // ...
    }
  }
}
```

#### 4.2 MapBusRealtime (12h)
**Archivo:** `lib/map_manager/map_bus_realtime.dart`

- Acceso a geometría de bus
- Extracción de stopIds
- Manejo de ETA

#### 4.3 MapCameraController (8h)
**Archivo:** `lib/map_manager/map_camera_controller.dart`

- Cálculo de bounds desde steps
- Zoom a segmentos específicos

---

### FASE 5: Journey Manager (16h)

#### 5.1 Eliminar Adaptador (4h)
**Archivo:** `lib/journey/adapters/journey_to_core_adapter.dart`

- Eliminar archivo completo
- Remover imports en JourneyManager

#### 5.2 JourneyManager Directo (8h)
**Archivo:** `lib/journey/journey_manager.dart`

```dart
// ANTES
final steps = <TripStep>[];
for (int i = 0; i < tramos.length; i++) {
  steps.add(tramoToTripStep(tramos[i], i, tramos));  // Adaptador
}

// DESPUÉS
// tramos ya son List<TripStep>, usar directamente
_stateMachine = TripStateMachine(
  tripId: 'journey_${DateTime.now().millisecondsSinceEpoch}',
  steps: tramos,  // Ya son TripSteps!
);
```

#### 5.3 Tests de Journey (4h)
- Actualizar todos los mocks
- Verificar transiciones

---

### FASE 6: DevTools y Simulador (12h)

#### 6.1 TripSimulator (4h)
**Archivo:** `lib/devtools/trip_simulator.dart`

- Cambiar referencia a tramos
- Actualizar acceso a geometrías

#### 6.2 GPSPlaybackGenerator (4h)
**Archivo:** `lib/devtools/gps_playback_generator.dart`

- Actualizar parsing de steps
- Generar desde TripSteps

#### 6.3 Tests y Scripts (4h)
- `scripts/test_gps_generator.dart`
- Tests de integración

---

### FASE 7: Testing Integral (24h)

#### 7.1 Tests Unitarios (8h)
- Todos los componentes modificados
- Edge cases

#### 7.2 Tests de Integración (12h)
- Flujo completo: búsqueda → selección → journey
- Simulador end-to-end
- GPS real

#### 7.3 Testing Manual (4h)
- QA en dispositivo real
- Verificar UI no rompe
- Performance

---

## Riesgos y Mitigaciones

### Riesgos ALTOS

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| **Breaking changes en UI** | ALTA | CRÍTICO | Feature flags, rollback plan |
| **Parser OTP incorrecto** | MEDIA | CRÍTICO | Tests extensivos con data real |
| **Pérdida de información** | MEDIA | ALTO | Audit de campos antes/después |
| **Performance degradación** | BAJA | MEDIO | Benchmarks antes/después |

### Riesgos MEDIOS

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| **Tests rotos** | ALTA | MEDIO | Actualizar incremental |
| **Docs desactualizados** | ALTA | BAJO | Actualizar en cada fase |
| **Regression bugs** | MEDIA | MEDIO | QA exhaustivo |

---

## Estrategia de Implementación

### Opción A: Big Bang (NO RECOMENDADA)
- Refactorizar todo de una vez
- **Riesgo:** EXTREMO
- **Ventaja:** Rápido si sale bien
- **Desventaja:** Si falla, todo falla

### Opción B: Incremental con Feature Flags ✅ RECOMENDADA
1. **Semana 1-2:** Extender TripStep, mantener ambos modelos
2. **Semana 2-3:** Parser dual (genera ambos), feature flag en UI
3. **Semana 3-4:** Migrar UI componente por componente
4. **Semana 4-5:** Testing, eliminar código viejo

**Ventajas:**
- Rollback fácil en cada paso
- Testing incremental
- Menor riesgo

### Opción C: Mantener Adaptador (ACTUAL) ✅ PRAGMÁTICA
- Dejar adaptador como está
- Refactorizar solo si hay tiempo
- **Ventaja:** Funciona, bajo riesgo
- **Desventaja:** Deuda técnica permanece

---

## Estimación de Esfuerzo

| Fase | Horas | Días (6h/día) |
|------|-------|---------------|
| 1. Modelo de Datos | 40h | 7 días |
| 2. Parser OTP | 24h | 4 días |
| 3. UI Components | 36h | 6 días |
| 4. Mapa | 32h | 5 días |
| 5. Journey Manager | 16h | 3 días |
| 6. DevTools | 12h | 2 días |
| 7. Testing | 24h | 4 días |
| **Contingencia (20%)** | 37h | 6 días |
| **TOTAL** | **221h** | **37 días** |

**En semanas:** ~7.5 semanas (casi 2 meses) de trabajo full-time

---

## Recomendación

### Para AHORA: Opción C (Mantener Adaptador) ✅

**Razones:**
1. **Funciona:** El adaptador es válido y robusto
2. **Bajo riesgo:** No rompe nada existente
3. **Tiempo:** 2 meses es mucho para un refactor
4. **ROI:** Beneficio marginal vs esfuerzo

**El adaptador NO es un hack, es un patrón de diseño legítimo (Adapter Pattern)**

### Para el FUTURO: Opción B (Incremental)

**Cuándo hacerlo:**
- Cuando haya 2+ meses disponibles
- Cuando la app sea más estable
- Cuando haya más tests automatizados
- Como parte de una refactorización mayor

**Señales para refactorizar:**
- Se agregan muchos campos a TramoViajeMostrable
- Performance issues por conversiones
- Bugs recurrentes en el adaptador
- Equipo crece y hay más recursos

---

## Conclusión

**Solución Clean:** Eliminar TramoViajeMostrable completamente

**Complejidad:**
- ⏱️ **221 horas** (~2 meses)
- 🎯 **24 archivos** afectados
- ⚠️ **Riesgo ALTO**
- 📊 **ROI: Bajo** (para el corto plazo)

**Recomendación:** Mantener adaptador actual, refactorizar en el futuro cuando haya más tiempo y recursos.

---

**Autor:** Análisis generado durante integración de TripOrchestrator
**Revisado por:** Pendiente
**Próxima revisión:** Q1 2026
