# 🏗️ Nuevo Diseño de Flujo de Información

## 🎯 **Análisis: Flujo Actual vs Flujo Ideal**

### **Diferencias Principales:**

| Aspecto                    | Flujo Actual         | Flujo Ideal                         |
| -------------------------- | -------------------- | ----------------------------------- |
| **Navegación entre pasos** | Manual (botones)     | Automática (basada en ubicación)    |
| **Tracking de usuario**    | No implementado      | Cada 5 segundos con rutas dinámicas |
| **Detección de llegadas**  | No existe            | Automática a paradas/destino        |
| **Seguimiento de bus**     | Solo coordenadas API | Híbrido: API → Usuario cuando sube  |
| **Actualización de rutas** | Estática             | Dinámica según ubicación actual     |
| **Gestión de zoom**        | Manual por paso      | Inteligente y contextual            |

## 🏗️ **Arquitectura de Alto Nivel**

```
┌─────────────────────────────────────────────────────────────┐
│                    USER JOURNEY ORCHESTRATOR                │
├─────────────────────────────────────────────────────────────┤
│  • Detecta transiciones automáticas entre pasos             │
│  • Coordina todos los subsistemas                          │
│  • Mantiene estado del progreso del viaje                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────┬──────────────────┬──────────────────┬──────────────────┐
│   LOCATION       │   BUS TRACKING   │   ROUTE DYNAMIC  │   SMART CAMERA   │
│   TRACKER        │   MANAGER        │   CALCULATOR     │   CONTROLLER     │
├──────────────────┼──────────────────┼──────────────────┼──────────────────┤
│ • GPS cada 5s    │ • Sondeo API     │ • Rutas live     │ • Zoom contextual│
│ • Detección      │ • Switch usuario │ • Distancias     │ • Focus dinámico │
│   llegadas       │ • Estado híbrido │ • Progreso       │ • Elementos      │
│ • Geofencing     │ • ETA management │ • Optimización   │   relevantes     │
└──────────────────┴──────────────────┴──────────────────┴──────────────────┘
```

## 📦 **Componentes del Sistema**

### **1. Componente Central: UserJourneyOrchestrator**

```typescript
class UserJourneyOrchestrator {
  // Estado del viaje
  currentStep: JourneyStep
  userLocation: Coordenada
  journeyProgress: JourneyProgress

  // Subsistemas
  locationTracker: LocationTracker
  busTrackingManager: BusTrackingManager
  routeCalculator: RouteDynamicCalculator
  smartCamera: SmartCameraController

  // Flujo principal
  async initializeJourney(selectedRoute: OpcionDeRuta) {
    1. Configurar primer paso (WALKING_TO_STOP)
    2. Iniciar location tracking
    3. Calcular ruta inicial usuario → parada
    4. Si hay ETA, iniciar bus tracking
    5. Configurar geofences para detección automática
  }

  // Timer principal cada 5 segundos
  async onLocationUpdate(newLocation: Coordenada) {
    1. Detectar si llegó a destino del paso actual
    2. Si llegó → transición automática al siguiente paso
    3. Si no → actualizar rutas y progreso dinámicamente
    4. Coordinar zoom inteligente
  }

  // Transiciones automáticas
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

### **2. LocationTracker - Seguimiento Inteligente**

```typescript
class LocationTracker {
  // Configuración
  private updateInterval = 5000ms
  private arrivalThreshold = 50m // Distancia para considerar "llegada"

  async startTracking() {
    Timer.periodic(5000ms, () => {
      1. Obtener ubicación GPS actual
      2. Validar precisión y calidad
      3. Detectar llegadas a destinos configurados
      4. Notificar cambios al orchestrator
    })
  }

  // Detección automática de llegadas
  detectArrival(userLocation: Coordenada, destination: Coordenada): boolean {
    const distance = calculateDistance(userLocation, destination)
    return distance <= arrivalThreshold
  }

  // Geofencing para optimización
  setupGeofences(destinations: List<Coordenada>) {
    // Configurar zonas de detección automática
    // Optimizar batería usando geofences nativos
  }
}
```

### **3. BusTrackingManager - Sistema Híbrido**

```typescript
class BusTrackingManager {
  // Estados del tracking
  trackingMode: 'API_REALTIME' | 'USER_LOCATION' | 'INACTIVE'
  currentBusLine: string
  etaInfo: EtaInfo

  // Inicio del tracking (API)
  async startApiTracking(stopId: string, busLine: string) {
    trackingMode = 'API_REALTIME'
    Timer.periodic(10000ms, () => {
      1. Sondear ETA desde API
      2. Actualizar posición del bus en mapa
      3. Calcular línea verde bus → parada
    })
  }

  // Transición a tracking del usuario
  async switchToUserTracking() {
    trackingMode = 'USER_LOCATION'
    1. Detener sondeo de API
    2. Usar ubicación del usuario como posición del bus
    3. Renderizar bus icon en ubicación del usuario
    4. Mantener enfoque: usuario → parada destino
  }

  // Detección automática de subida al bus
  detectBoardingBus(userLocation: Coordenada, busRoute: List<Coordenada>): boolean {
    1. Verificar si usuario está en el corredor de la ruta del bus
    2. Verificar velocidad de movimiento (>walking speed)
    3. Verificar dirección de movimiento (coincide con bus route)
    return allConditionsMet
  }
}
```

### **4. RouteDynamicCalculator - Rutas Vivas**

```typescript
class RouteDynamicCalculator {
  // Cálculo dinámico de rutas
  async calculateOptimalRoute(
    from: Coordenada,
    to: Coordenada,
    mode: 'WALKING' | 'BUS'
  ): Promise<RouteInfo> {
    1. Calcular ruta más eficiente
    2. Obtener geometría de la ruta
    3. Calcular distancia y tiempo estimado
    4. Retornar información completa
  }

  // Progreso dinámico
  calculateProgress(
    startLocation: Coordenada,
    currentLocation: Coordenada,
    destination: Coordenada
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

### **5. SmartCameraController - Zoom Inteligente**

```typescript
class SmartCameraController {
  // Zoom contextual por tipo de paso
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

  // Actualización inteligente del zoom
  async smartZoomUpdate(relevantPoints: List<Coordenada>, priority: ZoomPriority) {
    1. Filtrar puntos por relevancia
    2. Calcular bounds óptimos
    3. Aplicar padding contextual
    4. Animar suavemente hacia nueva vista
  }
}
```

## 🔄 **Flujo de Información Completo - Nuevo Diseño**

### **Paso 1: Inicialización del Viaje**

```
Usuario confirma opción → UserJourneyOrchestrator.initializeJourney()
├── 1. Configurar primer paso (WALKING_TO_STOP)
├── 2. LocationTracker.startTracking()
├── 3. RouteDynamicCalculator.calculateOptimalRoute(usuario → parada)
├── 4. Si hay ETA → BusTrackingManager.startApiTracking()
├── 5. SmartCameraController.updateCameraForStep()
└── 6. UI muestra: paso actual, distancia, progreso, ETA del bus
```

### **Paso 2: Loop Principal (cada 5 segundos)**

```
LocationTracker detecta nueva ubicación
├── UserJourneyOrchestrator.onLocationUpdate()
│   ├── ¿Usuario llegó al destino del paso?
│   │   ├── SÍ → transitionToNextStep()
│   │   └── NO → updateCurrentStepProgress()
│   │       ├── RouteDynamicCalculator.calculateProgress()
│   │       ├── RouteDynamicCalculator.calculateOptimalRoute()
│   │       ├── SmartCameraController.smartZoomUpdate()
│   │       └── UI actualiza: distancia, progreso, tiempo restante
│   └── BusTrackingManager.updateBusTracking()
└── MapRenderer actualiza: ruta azul, posición usuario, bus, zoom
```

### **Paso 3: Transiciones Automáticas**

```
WALKING_TO_STOP → WAITING_FOR_BUS
├── Detectar llegada a parada (geofencing)
├── Cambiar modo de tracking a bus
├── Si hay ETA → mostrar bus en tiempo real
├── Ajustar zoom: usuario + bus + parada
└── UI: "Espera la línea X, llega en Y minutos"

WAITING_FOR_BUS → RIDING_BUS
├── Detectar subida al bus (velocidad + dirección + corredor)
├── BusTrackingManager.switchToUserTracking()
├── Renderizar bus icon en ubicación del usuario
├── Ajustar zoom: usuario + parada destino
└── UI: "En viaje hacia destino, baja en parada Z"

RIDING_BUS → NEXT_STEP
├── Detectar llegada a parada destino
├── Determinar siguiente paso del itinerario
├── Reconfigurar tracking según tipo de paso
└── Continuar flujo recursivamente
```

## 🎨 **Estados de la UI por Paso**

### **Estado de Caminata**

```
┌─────────────────────────────────────┐
│ 🚶‍♂️ Camina hacia la parada          │
├─────────────────────────────────────┤
│ 📍 150m restantes                   │
│ ⏱️ 2 minutos                         │
│ ⭕ 60% completado                    │
│                                     │
│ [Tramo azul dinámico en mapa]       │
└─────────────────────────────────────┘
```

### **Estado de Espera con ETA**

```
┌─────────────────────────────────────┐
│ 🚌 Espera Línea 123                 │
├─────────────────────────────────────┤
│ 🟢 Bus llega en 3 minutos           │
│ 📍 A 200m de la parada              │
│                                     │
│ [Bus + línea verde + parada]        │
└─────────────────────────────────────┘
```

### **Estado de Viaje en Bus**

```
┌─────────────────────────────────────┐
│ 🚌 En viaje - Línea 123             │
├─────────────────────────────────────┤
│ 📍 Próxima parada: Av. Principal    │
│ ⏱️ 5 minutos restantes               │
│                                     │
│ [Bus icon en usuario → parada]      │
└─────────────────────────────────────┘
```

## 📊 **Ventajas del Nuevo Diseño**

1. **✅ Automatización Completa**: Sin intervención manual del usuario
2. **✅ Experiencia Fluida**: Transiciones naturales y contextuales
3. **✅ Información Relevante**: Datos dinámicos y actualizados
4. **✅ Eficiencia de Batería**: Geofencing + timers optimizados
5. **✅ Robustez**: Manejo de errores y fallbacks
6. **✅ Escalabilidad**: Modular y extensible
7. **✅ Precisión**: Tracking híbrido API + GPS del usuario

## 🔧 **Detalles de Implementación**

### **Tipos de Pasos del Viaje**

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
  startLocation: Coordenada;
  targetLocation: Coordenada;
  busLine?: string;
  stopId?: string;
  instructions: string;
  estimatedDuration: number;
}
```

### **Estados del Progreso**

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

### **Información de Rutas Dinámicas**

```typescript
interface RouteInfo {
  geometry: List<Coordenada>;
  distance: number;
  duration: number;
  instructions: List<string>;
  waypoints: List<Coordenada>;
  isOptimal: boolean;
  lastCalculated: DateTime;
}
```

### **Configuración de Tracking**

```typescript
interface TrackingConfig {
  locationUpdateInterval: number; // 5000ms
  arrivalThreshold: number; // 50m
  busDetectionThreshold: number; // 100m
  speedThreshold: number; // 5 km/h para detectar bus
  geofenceRadius: number; // 100m
}
```
