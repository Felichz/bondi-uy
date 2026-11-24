# 🏗️ New Information Flow Design

## 🎯 **Analysis: Current Flow vs Ideal Flow**

### **Main Differences:**

| Aspect                     | Current Flow         | Ideal Flow                          |
| -------------------------- | -------------------- | ----------------------------------- |
| **Navigation between steps** | Manual (buttons)   | Automatic (location-based)          |
| **User tracking**          | Not implemented      | Every 5 seconds with dynamic routes |
| **Arrival detection**      | Does not exist       | Automatic at stops/destination      |
| **Bus tracking**           | API coordinates only | Hybrid: API → User when boarding    |
| **Route updates**          | Static               | Dynamic based on current location   |
| **Zoom management**        | Manual per step      | Smart and contextual                |

## 🏗️ **High-Level Architecture**

```
┌─────────────────────────────────────────────────────────────┐
│                    USER JOURNEY ORCHESTRATOR                │
├─────────────────────────────────────────────────────────────┤
│  • Detects automatic transitions between steps              │
│  • Coordinates all subsystems                              │
│  • Keeps the trip progress state                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────┬──────────────────┬──────────────────┬──────────────────┐
│   LOCATION       │   BUS TRACKING   │   ROUTE DYNAMIC  │   SMART CAMERA   │
│   TRACKER        │   MANAGER        │   CALCULATOR     │   CONTROLLER     │
├──────────────────┼──────────────────┼──────────────────┼──────────────────┤
│ • GPS every 5s   │ • API polling    │ • Live routes    │ • Contextual zoom│
│ • Arrival        │ • User switch    │ • Distances      │ • Dynamic focus  │
│   detection      │ • Hybrid state   │ • Progress       │ • Relevant       │
│ • Geofencing     │ • ETA management │ • Optimization   │   elements       │
└──────────────────┴──────────────────┴──────────────────┴──────────────────┘
```

## 📦 **System Components**

### **1. Central Component: UserJourneyOrchestrator**

```typescript
class UserJourneyOrchestrator {
  // Trip state
  currentStep: JourneyStep
  userLocation: Coordinate
  journeyProgress: JourneyProgress

  // Subsystems
  locationTracker: LocationTracker
  busTrackingManager: BusTrackingManager
  routeCalculator: RouteDynamicCalculator
  smartCamera: SmartCameraController

  // Main flow
  async initializeJourney(selectedRoute: OpcionDeRuta) {
    1. Set up first step (WALKING_TO_STOP)
    2. Start location tracking
    3. Calculate initial route user → stop
    4. If there is an ETA, start bus tracking
    5. Set up geofences for automatic detection
  }

  // Main timer every 5 seconds
  async onLocationUpdate(newLocation: Coordinate) {
    1. Detect whether the user reached the destination of the current step
    2. If reached → automatic transition to the next step
    3. If not → update routes and progress dynamically
    4. Coordinate smart zoom
  }

  // Automatic transitions
  async transitionToNextStep() {
    switch (currentStep.type) {
      case WALKING_TO_STOP → WAITING_FOR_BUS
      case WAITING_FOR_BUS → RIDING_BUS
      case RIDING_BUS → WALKING_TO_STOP | WAITING_FOR_BUS | WALKING_TO_DESTINATION
      case WALKING_TO_DESTINATION → JOURNEY_COMPLETED
    }
  }
}
```

### **2. LocationTracker - Smart Tracking**

```typescript
class LocationTracker {
  // Configuration
  private updateInterval = 5000ms
  private arrivalThreshold = 50m // Distance to consider "arrival"

  async startTracking() {
    Timer.periodic(5000ms, () => {
      1. Get current GPS location
      2. Validate accuracy and quality
      3. Detect arrivals at configured destinations
      4. Notify changes to the orchestrator
    })
  }

  // Automatic arrival detection
  detectArrival(userLocation: Coordinate, destination: Coordinate): boolean {
    const distance = calculateDistance(userLocation, destination)
    return distance <= arrivalThreshold
  }

  // Geofencing for optimization
  setupGeofences(destinations: List<Coordinate>) {
    // Set up automatic detection zones
    // Optimize battery using native geofences
  }
}
```

### **3. BusTrackingManager - Hybrid System**

```typescript
class BusTrackingManager {
  // Tracking states
  trackingMode: 'API_REALTIME' | 'USER_LOCATION' | 'INACTIVE'
  currentBusLine: string
  etaInfo: EtaInfo

  // Start tracking (API)
  async startApiTracking(stopId: string, busLine: string) {
    trackingMode = 'API_REALTIME'
    Timer.periodic(10000ms, () => {
      1. Poll ETA from the API
      2. Update bus position on the map
      3. Calculate green line bus → stop
    })
  }

  // Transition to user tracking
  async switchToUserTracking() {
    trackingMode = 'USER_LOCATION'
    1. Stop API polling
    2. Use the user's location as the bus position
    3. Render bus icon at the user's location
    4. Keep focus: user → destination stop
  }

  // Automatic detection of boarding the bus
  detectBoardingBus(userLocation: Coordinate, busRoute: List<Coordinate>): boolean {
    1. Check whether the user is in the corridor of the bus route
    2. Check movement speed (> walking speed)
    3. Check direction of movement (matches bus route)
    return allConditionsMet
  }
}
```

### **4. RouteDynamicCalculator - Live Routes**

```typescript
class RouteDynamicCalculator {
  // Dynamic route calculation
  async calculateOptimalRoute(
    from: Coordinate,
    to: Coordinate,
    mode: 'WALKING' | 'BUS'
  ): Promise<RouteInfo> {
    1. Calculate the most efficient route
    2. Get the route geometry
    3. Calculate distance and estimated time
    4. Return complete information
  }

  // Dynamic progress
  calculateProgress(
    startLocation: Coordinate,
    currentLocation: Coordinate,
    destination: Coordinate
  ): ProgressInfo {
    const totalDistance = distance(startLocation, destination)
    const remainingDistance = distance(currentLocation, destination)
    const completedDistance = totalDistance - remainingDistance

    return {
      percentageComplete: (completedDistance / totalDistance) * 100,
      remainingDistance,
      remainingTime: estimateTime(remainingDistance, walkingSpeed),
      currentRoute: calculateOptimalRoute(currentLocation, destination)
    }
  }
}
```

### **5. SmartCameraController - Smart Zoom**

```typescript
class SmartCameraController {
  // Contextual zoom by step type
  async updateCameraForStep(step: JourneyStep, context: CameraContext) {
    switch (step.type) {
      case WALKING_TO_STOP:
        await focusOn([userLocation, targetStop], walkingPadding)

      case WAITING_FOR_BUS:
        if (busPosition) {
          await focusOn([userLocation, busPosition, targetStop], waitingPadding)
        } else {
          await focusOn([userLocation, targetStop], waitingPadding)
        }

      case RIDING_BUS:
        await focusOn([userLocation, targetStop], ridingPadding)

      case WALKING_TO_DESTINATION:
        await focusOn([userLocation, destination], walkingPadding)
    }
  }

  // Smart zoom update
  async smartZoomUpdate(relevantPoints: List<Coordinate>, priority: ZoomPriority) {
    1. Filter points by relevance
    2. Calculate optimal bounds
    3. Apply contextual padding
    4. Animate smoothly to the new view
  }
}
```

## 🔄 **Complete Information Flow - New Design**

### **Step 1: Trip Initialization**

```
User confirms option → UserJourneyOrchestrator.initializeJourney()
├── 1. Set up first step (WALKING_TO_STOP)
├── 2. LocationTracker.startTracking()
├── 3. RouteDynamicCalculator.calculateOptimalRoute(user → stop)
├── 4. If ETA → BusTrackingManager.startApiTracking()
├── 5. SmartCameraController.updateCameraForStep()
└── 6. UI shows: current step, distance, progress, bus ETA
```

### **Step 2: Main Loop (every 5 seconds)**

```
LocationTracker detects new location
├── UserJourneyOrchestrator.onLocationUpdate()
│   ├── Did the user reach the step destination?
│   │   ├── YES → transitionToNextStep()
│   │   └── NO → updateCurrentStepProgress()
│   │       ├── RouteDynamicCalculator.calculateProgress()
│   │       ├── RouteDynamicCalculator.calculateOptimalRoute()
│   │       ├── SmartCameraController.smartZoomUpdate()
│   │       └── UI updates: distance, progress, remaining time
│   └── BusTrackingManager.updateBusTracking()
└── MapRenderer updates: blue route, user position, bus, zoom
```

### **Step 3: Automatic Transitions**

```
WALKING_TO_STOP → WAITING_FOR_BUS
├── Detect arrival at stop (geofencing)
├── Switch tracking mode to bus
├── If ETA → show real-time bus
├── Adjust zoom: user + bus + stop
└── UI: "Wait for line X, arrives in Y minutes"

WAITING_FOR_BUS → RIDING_BUS
├── Detect boarding the bus (speed + direction + corridor)
├── BusTrackingManager.switchToUserTracking()
├── Render bus icon at the user's location
├── Adjust zoom: user + destination stop
└── UI: "On the way to destination, get off at stop Z"

RIDING_BUS → NEXT_STEP
├── Detect arrival at destination stop
├── Determine next step of the itinerary
├── Reconfigure tracking according to the step type
└── Continue flow recursively
```

## 🎨 **UI States per Step**

### **Walking State**

```
┌─────────────────────────────────────┐
│ 🚶‍♂️ Walking to the stop              │
├─────────────────────────────────────┤
│ 📍 150m remaining                   │
│ ⏱️ 2 minutes                         │
│ ⭕ 60% completed                     │
│                                     │
│ [Dynamic blue segment on map]       │
└─────────────────────────────────────┘
```

### **Waiting State with ETA**

```
┌─────────────────────────────────────┐
│ 🚌 Waiting for Line 123             │
├─────────────────────────────────────┤
│ 🟢 Bus arrives in 3 minutes         │
│ 📍 200m from the stop               │
│                                     │
│ [Bus + green line + stop]           │
└─────────────────────────────────────┘
```

### **On the Bus State**

```
┌─────────────────────────────────────┐
│ 🚌 On the way - Line 123            │
├─────────────────────────────────────┤
│ 📍 Next stop: Av. Principal         │
│ ⏱️ 5 minutes remaining               │
│                                     │
│ [Bus icon at user → stop]           │
└─────────────────────────────────────┘
```

## 📊 **Advantages of the New Design**

1. **✅ Full Automation**: No manual user intervention
2. **✅ Smooth Experience**: Natural and contextual transitions
3. **✅ Relevant Information**: Dynamic and up-to-date data
4. **✅ Battery Efficiency**: Geofencing + optimized timers
5. **✅ Robustness**: Error handling and fallbacks
6. **✅ Scalability**: Modular and extensible
7. **✅ Precision**: Hybrid tracking API + user GPS

## 🔧 **Implementation Details**

### **Trip Step Types**

```typescript
enum JourneyStepType {
  WALKING_TO_STOP = "walking_to_stop",
  WAITING_FOR_BUS = "waiting_for_bus",
  RIDING_BUS = "riding_bus",
  WALKING_TO_DESTINATION = "walking_to_destination",
  JOURNEY_COMPLETED = "journey_completed",
}

interface JourneyStep {
  type: JourneyStepType;
  startLocation: Coordinate;
  targetLocation: Coordinate;
  busLine?: string;
  stopId?: string;
  instructions: string;
  estimatedDuration: number;
}
```

### **Progress States**

```typescript
interface JourneyProgress {
  currentStepIndex: number;
  totalSteps: number;
  overallProgress: number; // 0-100%
  currentStepProgress: number; // 0-100%
  remainingDistance: number;
  remainingTime: number;
  startTime: DateTime;
  estimatedArrival: DateTime;
}
```

### **Dynamic Route Information**

```typescript
interface RouteInfo {
  geometry: List<Coordinate>;
  distance: number;
  duration: number;
  instructions: List<string>;
  waypoints: List<Coordinate>;
  isOptimal: boolean;
  lastCalculated: DateTime;
}
```

### **Tracking Configuration**

```typescript
interface TrackingConfig {
  locationUpdateInterval: number; // 5000ms
  arrivalThreshold: number; // 50m
  busDetectionThreshold: number; // 100m
  speedThreshold: number; // 5 km/h to detect bus
  geofenceRadius: number; // 100m
}
```
