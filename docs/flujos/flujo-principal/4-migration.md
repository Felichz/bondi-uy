# Plan de Migración: Flujo Manual → Flujo Automático

## 🔍 **Análisis Diferencial: Flujo Actual vs Nuevo**

### **Arquitectura Actual**

```
RouteOptionsOverlay (Manual) → ActiveTripOverlay (Botones) → MapManager → Componentes especializados
```

### **Arquitectura Nueva**

```
RouteOptionsOverlay → UserJourneyOrchestrator (Auto) → ActiveTripOverlay (Auto) → MapManager → Componentes especializados
```

## 📋 **Plan de Implementación Incremental**

### **Fase 1: Agregar Sistema de Tracking de Ubicación (Sin cambiar UI)**

**Nuevos componentes a crear:**

#### **1.1 LocationTracker - Seguimiento GPS**

```dart
// lib/journey/location_tracker.dart
class LocationTracker {
  Timer? _trackingTimer;
  final Function(Coordenada) onLocationUpdate;
  final Function(String) onArrivalDetected;

  Coordenada? _lastKnownLocation;
  List<GeofenceZone> _activeGeofences = [];

  static const int UPDATE_INTERVAL_MS = 5000;
  static const double ARRIVAL_THRESHOLD_METERS = 50.0;

  LocationTracker({
    required this.onLocationUpdate,
    required this.onArrivalDetected,
  });

  // DIFF: Nuevo método
  Future<void> startTracking() async {
    _trackingTimer = Timer.periodic(
      Duration(milliseconds: UPDATE_INTERVAL_MS),
      (_) async => await _performLocationUpdate()
    );
  }

  // DIFF: Nuevo método
  Future<void> _performLocationUpdate() async {
    final newLocation = await _getCurrentGPSLocation();
    if (newLocation != null) {
      _lastKnownLocation = newLocation;
      onLocationUpdate(newLocation);
      _checkArrivals(newLocation);
    }
  }

  // DIFF: Nuevo método
  void _checkArrivals(Coordenada userLocation) {
    for (final geofence in _activeGeofences) {
      final distance = _calculateDistance(userLocation, geofence.center);
      if (distance <= ARRIVAL_THRESHOLD_METERS) {
        onArrivalDetected(geofence.id);
      }
    }
  }

  // DIFF: Nuevo método
  void setupGeofencesForStep(List<Coordenada> destinations, List<String> ids) {
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
  final Coordenada center;
  final double radius;

  GeofenceZone({required this.id, required this.center, required this.radius});
}
```

#### **1.2 JourneyStepState - Estado del paso actual**

```dart
// lib/journey/journey_step_state.dart
class JourneyStepState {
  final int stepIndex;
  final JourneyStepType type;
  final Coordenada? destination;
  final String? busLine;
  final double? remainingDistance;
  final int? remainingTimeSeconds;
  final double? progressPercentage;

  // DIFF: Nueva clase para estado del paso
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

### **Fase 2: Modificar AppLogicNotifier (Cambios mínimos)**

**Cambios en `lib/backend/providers/app_logic_provider.dart`:**

```dart
class AppLogicNotifier extends StateNotifier<AppUiState> with IAppLogic {
  // DIFF: Agregar nuevo componente
  LocationTracker? _locationTracker;
  JourneyStepState? _currentJourneyStep;

  // DIFF: Nuevo método para inicializar tracking automático
  @override
  void confirmarOpcionDeRutaEIniciarViaje(String idOpcionSeleccionada) {
    // ... código existente ...

    // CAMBIO MÍNIMO: Agregar al final
    if (opcionConfirmada != null) {
      _initializeAutomaticTracking(opcionConfirmada);
    }
  }

  // DIFF: Nuevo método
  Future<void> _initializeAutomaticTracking(OpcionDeRutaMostrable option) async {
    _locationTracker = LocationTracker(
      onLocationUpdate: _onUserLocationUpdate,
      onArrivalDetected: _onArrivalDetected,
    );

    // Configurar primer paso
    _currentJourneyStep = JourneyStepState(
      stepIndex: 0,
      type: _determineStepType(option.tramosParaPreview[0]),
      destination: _getStepDestination(option.tramosParaPreview[0]),
    );

    // Configurar geofences para primer paso
    _setupGeofencesForCurrentStep();

    // Iniciar tracking
    await _locationTracker!.startTracking();
  }

  // DIFF: Nuevo método - callback de ubicación
  void _onUserLocationUpdate(Coordenada newLocation) {
    if (_currentJourneyStep == null) return;

    // Calcular progreso dinámico
    final progress = _calculateStepProgress(newLocation);

    // Actualizar estado
    _currentJourneyStep = _currentJourneyStep!.copyWith(
      remainingDistance: progress.remainingDistance,
      remainingTimeSeconds: progress.remainingTimeSeconds,
      progressPercentage: progress.progressPercentage,
    );

    // Notificar cambios a la UI
    _updateUIWithLocationProgress();
  }

  // DIFF: Nuevo método - callback de llegada
  void _onArrivalDetected(String geofenceId) {
    print("[AppLogicNotifier] Auto-arrival detected: $geofenceId");
    _transitionToNextStep();
  }

  // DIFF: Nuevo método - transición automática
  void _transitionToNextStep() {
    if (_currentJourneyStep == null) return;

    final nextStepIndex = _currentJourneyStep!.stepIndex + 1;
    final activeTripState = state.datosFaseViajeActivo;

    if (activeTripState == null ||
        nextStepIndex >= activeTripState.tramosDelViaje.length) {
      // Viaje completado
      _completeJourney();
      return;
    }

    // Actualizar al siguiente paso
    final nextTramo = activeTripState.tramosDelViaje[nextStepIndex];
    _currentJourneyStep = JourneyStepState(
      stepIndex: nextStepIndex,
      type: _determineStepType(nextTramo),
      destination: _getStepDestination(nextTramo),
      busLine: nextTramo.nombreLineaBus,
    );

    // Reconfigurar geofences
    _setupGeofencesForCurrentStep();

    // Notificar cambio a UI (esto hará que ActiveTripOverlay se actualice)
    _notifyStepTransition();
  }
}
```

### **Fase 3: Modificar ActiveTripOverlay (Cambios mínimos)**

**Cambios en `lib/ui/overlays/active_trip_overlay.dart`:**

```dart
class _ActiveTripOverlayState extends ConsumerState<ActiveTripOverlay> {
  int _currentLegIndex = 0;
  // DIFF: Agregar listener para transiciones automáticas
  bool _automaticNavigationEnabled = true;

  @override
  Widget build(BuildContext context) {
    // ... código existente ...

    // DIFF: Agregar listener para transiciones automáticas
    ref.listen<AppUiState>(appLogicProvider, (previous, next) {
      // ... listeners existentes ...

      // NUEVO: Listener para transiciones automáticas
      final prevStep = previous?.currentJourneyStep;
      final nextStep = next.currentJourneyStep;

      if (prevStep?.stepIndex != nextStep?.stepIndex &&
          _automaticNavigationEnabled) {
        _onAutomaticStepTransition(nextStep?.stepIndex ?? 0);
      }
    });

    return _buildUI();
  }

  // DIFF: Nuevo método para transiciones automáticas
  void _onAutomaticStepTransition(int newStepIndex) {
    setState(() {
      _currentLegIndex = newStepIndex;
    });

    // Usar lógica existente
    _onLegSelected(newStepIndex);
  }

  // DIFF: Modificar método existente para soportar modo automático
  void _onLegSelected(int legIndex) {
    // ... código existente sin cambios ...

    // NUEVO: Si es transición automática, actualizar tracking
    if (_automaticNavigationEnabled) {
      _updateTrackingForAutomaticMode(legIndex);
    }
  }

  // DIFF: Nuevo método
  void _updateTrackingForAutomaticMode(int legIndex) {
    final activeTripState = ref.read(appLogicProvider).datosFaseViajeActivo;
    if (activeTripState == null) return;

    final currentTramo = activeTripState.tramosDelViaje[legIndex];

    // Manejar tracking de bus según el tipo de paso
    switch (currentTramo.tipo) {
      case TipoTramoViaje.WAITING_FOR_BUS:
        // Iniciar tracking de bus en tiempo real
        _startBusTrackingForStep(currentTramo);
        break;
      case TipoTramoViaje.RIDING_BUS:
        // Cambiar a tracking del usuario
        _switchToUserLocationTracking();
        break;
      default:
        // Detener tracking de bus
        _stopBusTracking();
    }
  }
}
```

### **Fase 4: Extender MapBusRealtime (Cambios mínimos)**

**Cambios en `lib/map_manager/map_bus_realtime.dart`:**

```dart
class MapBusRealtime {
  // DIFF: Agregar estado para tracking híbrido
  BusTrackingMode _trackingMode = BusTrackingMode.INACTIVE;

  // DIFF: Nuevo método para cambiar modo de tracking
  Future<void> switchToUserLocationMode() async {
    print("[MapBusRealtime] Switching to user location tracking mode");

    _trackingMode = BusTrackingMode.USER_LOCATION;

    // Detener sondeo de API
    _busTrackingTimer?.cancel();

    // El bus ahora será renderizado usando la ubicación del usuario
    // Esto se manejará desde el LocationTracker
  }

  // DIFF: Nuevo método para renderizar bus en ubicación del usuario
  Future<void> updateBusToUserLocation(Coordenada userLocation) async {
    if (_trackingMode != BusTrackingMode.USER_LOCATION) return;

    // Renderizar icono de bus en la ubicación del usuario
    await _displayBusOnMap(userLocation);

    // Actualizar línea hacia parada de destino
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

### **Fase 5: Agregar RouteDynamicCalculator (Componente nuevo)**

```dart
// lib/journey/route_dynamic_calculator.dart
class RouteDynamicCalculator {
  // DIFF: Nuevo componente para cálculos dinámicos
  static Future<RouteProgress> calculateProgress({
    required Coordenada startLocation,
    required Coordenada currentLocation,
    required Coordenada destination,
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

  static Future<List<Coordenada>> _calculateOptimalRoute(
    Coordenada from,
    Coordenada to
  ) async {
    // Usar servicio existente de routing o implementar lógica simple
    // Por ahora, línea recta como MVP
    return [from, to];
  }

  static double _calculateDistance(Coordenada a, Coordenada b) {
    // Usar fórmula haversine existente
    return GeometryUtils.calculateDistance(a, b);
  }

  static int _estimateWalkingTime(double distanceMeters) {
    const double walkingSpeedMps = 1.4; // 1.4 m/s = velocidad promedio caminando
    return (distanceMeters / walkingSpeedMps).round();
  }
}

class RouteProgress {
  final double percentageComplete;
  final double remainingDistance;
  final int remainingTimeSeconds;
  final List<Coordenada> currentOptimalRoute;

  RouteProgress({
    required this.percentageComplete,
    required this.remainingDistance,
    required this.remainingTimeSeconds,
    required this.currentOptimalRoute,
  });
}
```

## 🎯 **Resumen de Cambios Mínimos**

### **Archivos a Crear (Nuevos):**

1. `lib/journey/location_tracker.dart` - Tracking GPS cada 5s
2. `lib/journey/journey_step_state.dart` - Estado del paso actual
3. `lib/journey/route_dynamic_calculator.dart` - Cálculos dinámicos

### **Archivos a Modificar (Mínimos diffs):**

1. `lib/backend/providers/app_logic_provider.dart` - Agregar lógica automática
2. `lib/ui/overlays/active_trip_overlay.dart` - Agregar listener automático
3. `lib/map_manager/map_bus_realtime.dart` - Agregar modo híbrido

### **Estado Actual a Extender:**

```dart
// En AppUiState - DIFF mínimo
class AppUiState {
  // ... campos existentes ...

  // NUEVOS campos
  final JourneyStepState? currentJourneyStep;
  final bool isAutomaticNavigationEnabled;
  final Coordenada? currentUserLocation;
  final RouteProgress? currentStepProgress;
}
```

## 🚀 **Estrategia de Implementación**

### **Semana 1: Fundación**

- Crear LocationTracker (sin conectar a UI)
- Crear JourneyStepState
- Tests unitarios básicos

### **Semana 2: Integración Básica**

- Conectar LocationTracker a AppLogicNotifier
- Implementar detección de llegadas básica
- Mantener navegación manual como fallback

### **Semana 3: Transiciones Automáticas**

- Implementar `_transitionToNextStep()`
- Conectar ActiveTripOverlay con listener automático
- Sistema híbrido de tracking de bus

### **Semana 4: Refinamiento**

- RouteDynamicCalculator para rutas dinámicas
- Optimizaciones de performance
- Manejo de casos edge

## 📊 **Diferencias Principales Implementadas**

| Aspecto                    | Flujo Actual     | Flujo Nuevo                | Cambio Requerido                |
| -------------------------- | ---------------- | -------------------------- | ------------------------------- |
| **Navegación entre pasos** | Manual (botones) | Automática (geofencing)    | LocationTracker + callbacks     |
| **Tracking de usuario**    | No implementado  | GPS cada 5s                | LocationTracker.startTracking() |
| **Detección de llegadas**  | No existe        | Automática (50m threshold) | GeofenceZone.checkArrivals()    |
| **Seguimiento de bus**     | Solo API         | Híbrido API→Usuario        | BusTrackingMode.USER_LOCATION   |
| **Cálculo de progreso**    | Estático         | Dinámico                   | RouteDynamicCalculator          |
| **Actualización de rutas** | Fija             | Recalculada en tiempo real | calculateProgress()             |

## 🔧 **Compatibilidad y Fallbacks**

### **Modo Híbrido:**

- Mantener navegación manual como backup
- Toggle entre automático/manual en UI
- Fallback a comportamiento actual si GPS falla

### **Detección de Errores:**

- GPS no disponible → usar navegación manual
- Timeout en tracking → notificar usuario
- Fallos en geofencing → usar distancia simple

### **Performance:**

- Timer de 5s optimizado para batería
- Usar geofences nativos cuando sea posible
- Caché de cálculos de rutas

Este plan permite implementar el nuevo flujo de forma incremental manteniendo la funcionalidad existente como fallback durante toda la migración.
