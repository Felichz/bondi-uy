# Clean Architecture Migration Plan
## Remove LegTripDisplayable in favor of TripStep

**Date:** 2025-10-03
**Status:** Complexity analysis
**Current Version:** Using temporary adapter `journey_to_core_adapter.dart`

---

## Executive Summary

**Problem:** We have TWO parallel data models:
- `LegTripDisplayable` (legacy) - Used throughout the app
- `TripStep` (core) - New architecture, only in tests

**Current Solution:** An adapter that converts between both (temporary but functional)

**Clean Solution:** Remove `LegTripDisplayable` completely, use only `TripStep`

**Estimated Complexity:**
- **Time:** 2-3 weeks (160-240 hours)
- **Risk:** HIGH
- **Affected files:** 24 files
- **Required tests:** Extensive

---

## Impact Analysis

### 1. Files That Use LegTripDisplayable

| File | Occurrences | Complexity | Est. Hours |
|---------|------------|-------------|------------|
| `lib/ui/overlays/active_trip_overlay.dart` | 10 | HIGH | 20h |
| `lib/map_manager/map_bus_realtime.dart` | 10 | HIGH | 16h |
| `lib/journey/journey_manager.dart` | 8 | MEDIUM | 12h |
| `lib/map_manager/map_route_renderer.dart` | 6 | HIGH | 16h |
| `lib/backend/contrato_ui/app_ui_state.dart` | 6 | CRITICAL | 24h |
| `lib/backend/services/itinerary_planning_service_adapter.dart` | 5 | CRITICAL | 20h |
| `lib/devtools/gps_playback_generator.dart` | 5 | MEDIUM | 8h |
| `lib/map_manager/map_camera_controller.dart` | 4 | MEDIUM | 8h |
| `lib/backend/providers/app_logic_provider.dart` | 3 | MEDIUM | 8h |
| Tests (4 files) | ~20 | MEDIUM | 16h |
| Others (docs, scripts) | ~10 | LOW | 8h |
| **TOTAL** | **87+** | - | **156h** |

### 2. Structures That Require Refactoring

#### 2.1 OpcionDeRutaMostrable
```dart
class OpcionDeRutaMostrable {
  final List<LegTripDisplayable> tramosParaPreview;  // ← CHANGE
  // ... 10 other fields
}
```

**Impact:**
- Used in the route carousel (critical UI)
- The OTP API parser builds it
- Referenced in 15+ places

**Required changes:**
```dart
class OpcionDeRutaMostrable {
  final List<TripStep> tramosParaPreview;  // ✅ NEW
  // ... rest unchanged
}
```

#### 2.2 EstadoFaseViajeActivo
```dart
class EstadoFaseViajeActivo {
  final List<LegTripDisplayable> tramosDelViaje;  // ← CHANGE
  final OpcionDeRutaMostrable opcionDeRutaSeleccionada;  // Also affected
  // ... other fields
}
```

**Impact:**
- CENTRAL state of the active trip
- Used by JourneyManager, MapManager, UI
- Referenced in 30+ places

---

## Refactoring Tasks

### PHASE 1: Data Model (40h)

#### 1.1 Extend TripStep with UI Fields (8h)
**File:** `lib/journey/core/trip_step.dart`

**Changes:**
```dart
class TripStep {
  // Existing fields (core architecture)
  final String id;
  final TripStepType type;
  final String description;
  final TripStepMetadata metadata;

  // NEW fields for UI compatibility
  final List<Coordinate>? geometry;  // geometryPolyline
  final Coordinate? pointPosition;   // positionPunto
  final int? estimatedDurationSeconds;
  final int? distanceMeters;
  final String? destinationName;     // For UI
  final String? busDestination;      // destinoFinalDelBus
  final String? shapeId;
  final int? estimatedBusArrivalMinutes;
  final bool? isRealTimeBus;
  final Coordinate? currentBusPosition;

  // ... rest
}
```

**Reason:** The current TripStep only has minimal metadata. The UI needs more information.

#### 1.2 Create TripStepMetadataExtended (4h)
**File:** `lib/journey/core/trip_step.dart`

```dart
class TripStepMetadataExtended extends TripStepMetadata {
  final String? stopOriginName;
  final String? stopDestinationName;
  final Coordinate? stopOriginCoords;
  final Coordinate? stopDestinationCoords;
  final String? busDestinationName;

  // ... constructors
}
```

#### 1.3 Refactor AppUiState (12h)
**File:** `lib/backend/contrato_ui/app_ui_state.dart`

**Changes:**
```dart
// BEFORE
class OpcionDeRutaMostrable {
  final List<LegTripDisplayable> tramosParaPreview;
}

class EstadoFaseViajeActivo {
  final List<LegTripDisplayable> tramosDelViaje;
}

// AFTER
class OpcionDeRutaMostrable {
  final List<TripStep> tramosParaPreview;  // ✅
}

class EstadoFaseViajeActivo {
  final List<TripStep> tramosDelViaje;  // ✅
}
```

**Cascade impact:**
- All `copyWith()` methods must update the type
- All constructors must update the type
- Serialization/deserialization if it exists

#### 1.4 Remove LegTripDisplayable (4h)
**File:** `lib/backend/contrato_ui/app_ui_state.dart`

- Remove the entire class (150 lines)
- Remove the `TypeLegTrip` enum → use `TripStepType`
- Update imports in 24 files

#### 1.5 Model Tests (12h)
- Test of the extended TripStep
- UI compatibility test
- Serialization test

---

### PHASE 2: OTP API Parser (24h)

#### 2.1 Refactor ItineraryPlanningServiceAdapter (16h)
**File:** `lib/backend/services/itinerary_planning_service_adapter.dart`

**Critical function:** `_adaptOneOTPItineraryToMostrable()`

**BEFORE (current):**
```dart
tramosDelItinerario.add(
  LegTripDisplayable(
    idLeg: _generateUniqueId("walk${itineraryOtpIndex}_$i"),
    type: TypeLegTrip.CAMINAR,
    geometryPolyline: geometry,
    description: "Caminar hacia ${leg.to?.name}",
    durationEstimatedSeconds: legDurationSec,
    distanceMeters: legDistanceMet,
  ),
);
```

**AFTER (new):**
```dart
tramosDelItinerario.add(
  TripStep(
    id: _generateUniqueId("walk${itineraryOtpIndex}_$i"),
    type: TripStepType.walkToStop,  // Inference logic
    description: "Caminar hacia ${leg.to?.name}",
    metadata: TripStepMetadataExtended(
      totalDistanceMeters: legDistanceMet.toDouble(),
      destinationStopId: leg.to?.stopId,
      stopDestinationName: leg.to?.name,
      stopDestinationCoords: coordDestinoTramo,
    ),
    geometry: geometry,
    estimatedDurationSeconds: legDurationSec,
    distanceMeters: legDistanceMet,
  ),
);
```

**Challenges:**
1. **Type inference:** Determine `walkToStop` vs `walkToDestination`
2. **Complete metadata:** Extract all the necessary fields from the OTP Leg
3. **Bus route geometry:** Handle shapeId and the full geometry
4. **ETA parsing:** Convert the bus's real-time data

#### 2.2 Parsing Tests (8h)
- Test with real OTP responses
- Edge case tests (no geometry, no ETA, etc.)
- Type inference test

---

### PHASE 3: UI Components (36h)

#### 3.1 ActiveTripOverlay (12h)
**File:** `lib/ui/overlays/active_trip_overlay.dart`

**Typical changes:**
```dart
// BEFORE
final LegTripDisplayable leg = tramosDelViaje[currentStepIndex];
final String? busLine = leg.nameLineBus;
final Coordinate? stopCoords = leg.coordenadasParadaOrigen;

// AFTER
final TripStep step = tramosDelViaje[currentStepIndex];
final String? busLine = step.metadata.busLine;
final Coordinate? stopCoords = step.metadata.stopOriginCoords;
```

**10 occurrences** of field access → update all of them

#### 3.2 Route Preview Carousel (8h)
**Location:** Where `OpcionDeRutaMostrable.tramosParaPreview` is displayed

**Changes:**
- Field access for each leg
- Icons based on `TripStepType` instead of `TypeLegTrip`
- Duration/distance formatting

#### 3.3 Other UI Components (16h)
- Progress indicators
- Navigation instructions
- Tooltips and labels
- Debugging panels

---

### PHASE 4: Map and Visualization (32h)

#### 4.1 MapRouteRenderer (12h)
**File:** `lib/map_manager/map_route_renderer.dart`

**Critical function:** `renderRoute(List<LegTripDisplayable> legs)`

**Changes:**
```dart
// BEFORE
void renderRoute(List<LegTripDisplayable> legs) {
  for (final leg in legs) {
    if (leg.type == TypeLegTrip.CAMINAR) {
      final geometry = leg.geometryPolyline;
      // ...
    }
  }
}

// AFTER
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
**File:** `lib/map_manager/map_bus_realtime.dart`

- Access to bus geometry
- Extraction of stopIds
- ETA handling

#### 4.3 MapCameraController (8h)
**File:** `lib/map_manager/map_camera_controller.dart`

- Bounds calculation from steps
- Zoom to specific segments

---

### PHASE 5: Journey Manager (16h)

#### 5.1 Remove the Adapter (4h)
**File:** `lib/journey/adapters/journey_to_core_adapter.dart`

- Delete the entire file
- Remove imports in JourneyManager

#### 5.2 Direct JourneyManager (8h)
**File:** `lib/journey/journey_manager.dart`

```dart
// BEFORE
final steps = <TripStep>[];
for (int i = 0; i < legs.length; i++) {
  steps.add(tramoToTripStep(legs[i], i, legs));  // Adapter
}

// AFTER
// legs are already List<TripStep>, use them directly
_stateMachine = TripStateMachine(
  tripId: 'journey_${DateTime.now().millisecondsSinceEpoch}',
  steps: legs,  // They are already TripSteps!
);
```

#### 5.3 Journey Tests (4h)
- Update all mocks
- Verify transitions

---

### PHASE 6: DevTools and Simulator (12h)

#### 6.1 TripSimulator (4h)
**File:** `lib/devtools/trip_simulator.dart`

- Change the reference to legs
- Update geometry access

#### 6.2 GPSPlaybackGenerator (4h)
**File:** `lib/devtools/gps_playback_generator.dart`

- Update step parsing
- Generate from TripSteps

#### 6.3 Tests and Scripts (4h)
- `scripts/test_gps_generator.dart`
- Integration tests

---

### PHASE 7: Full Testing (24h)

#### 7.1 Unit Tests (8h)
- All modified components
- Edge cases

#### 7.2 Integration Tests (12h)
- Full flow: search → selection → journey
- End-to-end simulator
- Real GPS

#### 7.3 Manual Testing (4h)
- QA on a real device
- Verify the UI does not break
- Performance

---

## Risks and Mitigations

### HIGH Risks

| Risk | Probability | Impact | Mitigation |
|--------|--------------|---------|------------|
| **Breaking changes in UI** | HIGH | CRITICAL | Feature flags, rollback plan |
| **Incorrect OTP parser** | MEDIUM | CRITICAL | Extensive tests with real data |
| **Information loss** | MEDIUM | HIGH | Field audit before/after |
| **Performance degradation** | LOW | MEDIUM | Benchmarks before/after |

### MEDIUM Risks

| Risk | Probability | Impact | Mitigation |
|--------|--------------|---------|------------|
| **Broken tests** | HIGH | MEDIUM | Update incrementally |
| **Outdated docs** | HIGH | LOW | Update in each phase |
| **Regression bugs** | MEDIUM | MEDIUM | Exhaustive QA |

---

## Implementation Strategy

### Option A: Big Bang (NOT RECOMMENDED)
- Refactor everything at once
- **Risk:** EXTREME
- **Advantage:** Fast if it goes well
- **Disadvantage:** If it fails, everything fails

### Option B: Incremental with Feature Flags ✅ RECOMMENDED
1. **Weeks 1-2:** Extend TripStep, keep both models
2. **Weeks 2-3:** Dual parser (generates both), feature flag in UI
3. **Weeks 3-4:** Migrate the UI component by component
4. **Weeks 4-5:** Testing, remove old code

**Advantages:**
- Easy rollback at each step
- Incremental testing
- Lower risk

### Option C: Keep the Adapter (CURRENT) ✅ PRAGMATIC
- Leave the adapter as it is
- Refactor only if there is time
- **Advantage:** It works, low risk
- **Disadvantage:** Technical debt remains

---

## Effort Estimate

| Phase | Hours | Days (6h/day) |
|------|-------|---------------|
| 1. Data Model | 40h | 7 days |
| 2. OTP Parser | 24h | 4 days |
| 3. UI Components | 36h | 6 days |
| 4. Map | 32h | 5 days |
| 5. Journey Manager | 16h | 3 days |
| 6. DevTools | 12h | 2 days |
| 7. Testing | 24h | 4 days |
| **Contingency (20%)** | 37h | 6 days |
| **TOTAL** | **221h** | **37 days** |

**In weeks:** ~7.5 weeks (almost 2 months) of full-time work

---

## Recommendation

### For NOW: Option C (Keep the Adapter) ✅

**Reasons:**
1. **It works:** The adapter is valid and robust
2. **Low risk:** It does not break anything existing
3. **Time:** 2 months is a lot for a refactor
4. **ROI:** Marginal benefit vs. effort

**The adapter is NOT a hack, it is a legitimate design pattern (Adapter Pattern)**

### For the FUTURE: Option B (Incremental)

**When to do it:**
- When there are 2+ months available
- When the app is more stable
- When there are more automated tests
- As part of a larger refactoring

**Signals to refactor:**
- Many fields keep being added to LegTripDisplayable
- Performance issues due to conversions
- Recurring bugs in the adapter
- The team grows and there are more resources

---

## Conclusion

**Clean Solution:** Remove LegTripDisplayable completely

**Complexity:**
- ⏱️ **221 hours** (~2 months)
- 🎯 **24 files** affected
- ⚠️ **HIGH risk**
- 📊 **ROI: Low** (in the short term)

**Recommendation:** Keep the current adapter, refactor in the future when there is more time and resources.

---

**Author:** Analysis generated during the TripOrchestrator integration
**Reviewed by:** Pending
**Next review:** Q1 2026
