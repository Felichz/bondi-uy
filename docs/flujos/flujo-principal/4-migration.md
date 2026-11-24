# Migration Plan: Manual Flow → Automatic Flow

## 🔍 **Differential Analysis: Current vs New Flow**

### **Current Architecture**

```
RouteOptionsOverlay (Manual) → ActiveTripOverlay (Buttons) → MapManager → Specialized components
```

### **New Architecture**

```
RouteOptionsOverlay → UserJourneyOrchestrator (Auto) → ActiveTripOverlay (Auto) → MapManager → Specialized components
```

## 📋 **Incremental Implementation Plan**

### **Phase 1: Add Location Tracking System (Without Changing the UI)**

**New components to create:**

#### **1.1 LocationTracker - GPS Tracking**

```dart
// lib/journey/location_tracker.dart
class LocationTracker {
  Timer? _trackingTimer;
  final Function(Coordinate) onLocationUpdate;
  final Function(String) onArrivalDetected;

  Coordinate? _lastKnownLocation;
  List<GeofenceZone> _activeGeofences = [];

  static const int UPDATE_INTERVAL_MS = 5000;
  static const double ARRIVAL_THRESHOLD_METERS = 50.0;

  LocationTracker({
    required this.onLocationUpdate,
    required this.onArrivalDetected,
  });

  // DIFF: New method
  Future<void> startTracking() async {
    _trackingTimer = Timer.periodic(
      Duration(milliseconds: UPDATE_INTERVAL_MS),
      (_) async => await _performLocationUpdate()
    );
  }

  // DIFF: New method
  Future<void> _performLocationUpdate() async {
    final newLocation = await _getCurrentGPSLocation();
    if (newLocation != null) {
      _lastKnownLocation = newLocation;
      onLocationUpdate(newLocation);
      _checkArrivals(newLocation);
    }
  }

  // DIFF: New method
  void _checkArrivals(Coordinate userLocation) {
    for (final geofence in _activeGeofences) {
      final distance = _calculateDistance(userLocation, geofence.center);
      if (distance <= ARRIVAL_THRESHOLD_METERS) {
        onArrivalDetected(geofence.id);
      }
    }
  }

  // DIFF: New method
  void setupGeofencesForStep(List<Coordinate> destinations, List<String> ids) {
    _activeGeofences.clear();
    for (int i = 0; i < destinations.length; i++) {
      _activeGeofences.add(GeofenceZone(
        id: ids[i],
        center: destinations[i],
        radius: ARRIVAL_THRESHOLD_METERS,
      ));
    }
  }
}

class GeofenceZone {
  final String id;
  final Coordinate center;
  final double radius;

  GeofenceZone({required this.id, required this.center, required this.radius});
}
```

#### **1.2 JourneyStepState - Current Step State**

```dart
// lib/journey/journey_step_state.dart
class JourneyStepState {
  final int stepIndex;
  final JourneyStepType type;
  final Coordinate? destination;
  final String? busLine;
  final double? remainingDistance;
  final int? remainingTimeSeconds;
  final double? progressPercentage;

  // DIFF: New class for the step state
  JourneyStepState({
    required this.stepIndex,
    required this.type,
    this.destination,
    this.busLine,
    this.remainingDistance,
    this.remainingTimeSeconds,
    this.progressPercentage,
  });
}

enum JourneyStepType {
  WALKING_TO_STOP,
  WAITING_FOR_BUS,
  RIDING_BUS,
  WALKING_TO_DESTINATION
}
```

### **Phase 2: Modify AppLogicNotifier (Minimal Changes)**

**Changes in `lib/backend/providers/app_logic_provider.dart`:**

```dart
class AppLogicNotifier extends StateNotifier<AppUiState> with IAppLogic {
  // DIFF: Add new component
  LocationTracker? _locationTracker;
  JourneyStepState? _currentJourneyStep;

  // DIFF: New method to initialize automatic tracking
  @override
  void confirmarOpcionDeRutaEIniciarViaje(String idOpcionSeleccionada) {
    // ... existing code ...

    // MINIMAL CHANGE: Add at the end
    if (opcionConfirmada != null) {
      _initializeAutomaticTracking(opcionConfirmada);
    }
  }

  // DIFF: New method
  Future<void> _initializeAutomaticTracking(OpcionDeRutaMostrable option) async {
    _locationTracker = LocationTracker(
      onLocationUpdate: _onUserLocationUpdate,
      onArrivalDetected: _onArrivalDetected,
    );

    // Set up first step
    _currentJourneyStep = JourneyStepState(
      stepIndex: 0,
      type: _determineStepType(option.tramosParaPreview[0]),
      destination: _getStepDestination(option.tramosParaPreview[0]),
    );

    // Set up geofences for first step
    _setupGeofencesForCurrentStep();

    // Start tracking
    await _locationTracker!.startTracking();
  }

  // DIFF: New method - location callback
  void _onUserLocationUpdate(Coordinate newLocation) {
    if (_currentJourneyStep == null) return;

    // Calculate dynamic progress
    final progress = _calculateStepProgress(newLocation);

    // Update state
    _currentJourneyStep = _currentJourneyStep!.copyWith(
      remainingDistance: progress.remainingDistance,
      remainingTimeSeconds: progress.remainingTimeSeconds,
      progressPercentage: progress.progressPercentage,
    );

    // Notify UI of changes
    _updateUIWithLocationProgress();
  }

  // DIFF: New method - arrival callback
  void _onArrivalDetected(String geofenceId) {
    print("[AppLogicNotifier] Auto-arrival detected: $geofenceId");
    _transitionToNextStep();
  }

  // DIFF: New method - automatic transition
  void _transitionToNextStep() {
    if (_currentJourneyStep == null) return;

    final nextStepIndex = _currentJourneyStep!.stepIndex + 1;
    final activeTripState = state.datosFaseViajeActivo;

    if (activeTripState == null ||
        nextStepIndex >= activeTripState.tramosDelViaje.length) {
      // Trip completed
      _completeJourney();
      return;
    }

    // Update to the next step
    final nextTramo = activeTripState.tramosDelViaje[nextStepIndex];
    _currentJourneyStep = JourneyStepState(
      stepIndex: nextStepIndex,
      type: _determineStepType(nextTramo),
      destination: _getStepDestination(nextTramo),
      busLine: nextTramo.nameLineBus,
    );

    // Reconfigure geofences
    _setupGeofencesForCurrentStep();

    // Notify UI of the change (this will make ActiveTripOverlay update)
    _notifyStepTransition();
  }
}
```

### **Phase 3: Modify ActiveTripOverlay (Minimal Changes)**

**Changes in `lib/ui/overlays/active_trip_overlay.dart`:**

```dart
class _ActiveTripOverlayState extends ConsumerState<ActiveTripOverlay> {
  int _currentLegIndex = 0;
  // DIFF: Add listener for automatic transitions
  bool _automaticNavigationEnabled = true;

  @override
  Widget build(BuildContext context) {
    // ... existing code ...

    // DIFF: Add listener for automatic transitions
    ref.listen<AppUiState>(appLogicProvider, (previous, next) {
      // ... existing listeners ...

      // NEW: Listener for automatic transitions
      final prevStep = previous?.currentJourneyStep;
      final nextStep = next.currentJourneyStep;

      if (prevStep?.stepIndex != nextStep?.stepIndex &&
          _automaticNavigationEnabled) {
        _onAutomaticStepTransition(nextStep?.stepIndex ?? 0);
      }
    });

    return _buildUI();
  }

  // DIFF: New method for automatic transitions
  void _onAutomaticStepTransition(int newStepIndex) {
    setState(() {
      _currentLegIndex = newStepIndex;
    });

    // Use existing logic
    _onLegSelected(newStepIndex);
  }

  // DIFF: Modify existing method to support automatic mode
  void _onLegSelected(int legIndex) {
    // ... existing code unchanged ...

    // NEW: If it is an automatic transition, update tracking
    if (_automaticNavigationEnabled) {
      _updateTrackingForAutomaticMode(legIndex);
    }
  }

  // DIFF: New method
  void _updateTrackingForAutomaticMode(int legIndex) {
    final activeTripState = ref.read(appLogicProvider).datosFaseViajeActivo;
    if (activeTripState == null) return;

    final currentTramo = activeTripState.tramosDelViaje[legIndex];

    // Handle bus tracking according to the step type
    switch (currentTramo.type) {
      case TypeLegTrip.WAITING_FOR_BUS:
        // Start real-time bus tracking
        _startBusTrackingForStep(currentTramo);
        break;
      case TypeLegTrip.RIDING_BUS:
        // Switch to user location tracking
        _switchToUserLocationTracking();
        break;
      default:
        // Stop bus tracking
        _stopBusTracking();
    }
  }
}
```

### **Phase 4: Extend MapBusRealtime (Minimal Changes)**

**Changes in `lib/map_manager/map_bus_realtime.dart`:**

```dart
class MapBusRealtime {
  // DIFF: Add state for hybrid tracking
  BusTrackingMode _trackingMode = BusTrackingMode.INACTIVE;

  // DIFF: New method to change the tracking mode
  Future<void> switchToUserLocationMode() async {
    print("[MapBusRealtime] Switching to user location tracking mode");

    _trackingMode = BusTrackingMode.USER_LOCATION;

    // Stop API polling
    _busTrackingTimer?.cancel();

    // The bus will now be rendered using the user's location
    // This will be handled from the LocationTracker
  }

  // DIFF: New method to render the bus at the user's location
  Future<void> updateBusToUserLocation(Coordinate userLocation) async {
    if (_trackingMode != BusTrackingMode.USER_LOCATION) return;

    // Render bus icon at the user's location
    await _displayBusOnMap(userLocation);

    // Update line toward the destination stop
    if (_currentStopPosition != null) {
      await _updateBusApproachLineForActiveTrip(userLocation, _currentStopPosition!);
    }
  }
}

enum BusTrackingMode {
  INACTIVE,
  API_REALTIME,
  USER_LOCATION
}
```

### **Phase 5: Add RouteDynamicCalculator (New Component)**

```dart
// lib/journey/route_dynamic_calculator.dart
class RouteDynamicCalculator {
  // DIFF: New component for dynamic calculations
  static Future<RouteProgress> calculateProgress({
    required Coordinate startLocation,
    required Coordinate currentLocation,
    required Coordinate destination,
  }) async {

    final totalDistance = _calculateDistance(startLocation, destination);
    final remainingDistance = _calculateDistance(currentLocation, destination);
    final completedDistance = totalDistance - remainingDistance;

    return RouteProgress(
      percentageComplete: (completedDistance / totalDistance) * 100,
      remainingDistance: remainingDistance,
      remainingTimeSeconds: _estimateWalkingTime(remainingDistance),
      currentOptimalRoute: await _calculateOptimalRoute(currentLocation, destination),
    );
  }

  static Future<List<Coordinate>> _calculateOptimalRoute(
    Coordinate from,
    Coordinate to
  ) async {
    // Use existing routing service or implement simple logic
    // For now, a straight line as MVP
    return [from, to];
  }

  static double _calculateDistance(Coordinate a, Coordinate b) {
    // Use existing haversine formula
    return GeometryUtils.calculateDistance(a, b);
  }

  static int _estimateWalkingTime(double distanceMeters) {
    const double walkingSpeedMps = 1.4; // 1.4 m/s = average walking speed
    return (distanceMeters / walkingSpeedMps).round();
  }
}

class RouteProgress {
  final double percentageComplete;
  final double remainingDistance;
  final int remainingTimeSeconds;
  final List<Coordinate> currentOptimalRoute;

  RouteProgress({
    required this.percentageComplete,
    required this.remainingDistance,
    required this.remainingTimeSeconds,
    required this.currentOptimalRoute,
  });
}
```

## 🎯 **Summary of Minimal Changes**

### **Files to Create (New):**

1. `lib/journey/location_tracker.dart` - GPS tracking every 5s
2. `lib/journey/journey_step_state.dart` - Current step state
3. `lib/journey/route_dynamic_calculator.dart` - Dynamic calculations

### **Files to Modify (Minimal Diffs):**

1. `lib/backend/providers/app_logic_provider.dart` - Add automatic logic
2. `lib/ui/overlays/active_trip_overlay.dart` - Add automatic listener
3. `lib/map_manager/map_bus_realtime.dart` - Add hybrid mode

### **Current State to Extend:**

```dart
// In AppUiState - minimal DIFF
class AppUiState {
  // ... existing fields ...

  // NEW fields
  final JourneyStepState? currentJourneyStep;
  final bool isAutomaticNavigationEnabled;
  final Coordinate? currentUserLocation;
  final RouteProgress? currentStepProgress;
}
```

## 🚀 **Implementation Strategy**

### **Week 1: Foundation**

- Create LocationTracker (not connected to the UI)
- Create JourneyStepState
- Basic unit tests

### **Week 2: Basic Integration**

- Connect LocationTracker to AppLogicNotifier
- Implement basic arrival detection
- Keep manual navigation as a fallback

### **Week 3: Automatic Transitions**

- Implement `_transitionToNextStep()`
- Connect ActiveTripOverlay with the automatic listener
- Hybrid bus tracking system

### **Week 4: Refinement**

- RouteDynamicCalculator for dynamic routes
- Performance optimizations
- Handling of edge cases

## 📊 **Main Differences Implemented**

| Aspect                     | Current Flow     | New Flow                   | Required Change                 |
| -------------------------- | ---------------- | -------------------------- | ------------------------------- |
| **Navigation between steps** | Manual (buttons) | Automatic (geofencing)   | LocationTracker + callbacks     |
| **User tracking**          | Not implemented  | GPS every 5s               | LocationTracker.startTracking() |
| **Arrival detection**      | Does not exist   | Automatic (50m threshold)  | GeofenceZone.checkArrivals()    |
| **Bus tracking**           | API only         | Hybrid API→User            | BusTrackingMode.USER_LOCATION   |
| **Progress calculation**   | Static           | Dynamic                    | RouteDynamicCalculator          |
| **Route updates**          | Fixed            | Recalculated in real time  | calculateProgress()             |

## 🔧 **Compatibility and Fallbacks**

### **Hybrid Mode:**

- Keep manual navigation as a backup
- Toggle between automatic/manual in the UI
- Fall back to current behavior if GPS fails

### **Error Detection:**

- GPS unavailable → use manual navigation
- Tracking timeout → notify the user
- Geofencing failures → use simple distance

### **Performance:**

- 5s timer optimized for battery
- Use native geofences when possible
- Cache route calculations

This plan allows implementing the new flow incrementally while keeping the existing functionality as a fallback throughout the whole migration.
