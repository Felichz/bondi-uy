/// EJEMPLO: Cómo integrar la nueva arquitectura con el código existente
///
/// Este archivo muestra cómo usar TripOrchestrator con datos reales de la app.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/trip_state_machine.dart';
import '../core/trip_step.dart';
import '../core/trip_orchestrator.dart';
import '../adapters/geometry_adapter.dart';
import '../../backend/contrato_ui/app_ui_state.dart';

/// PASO 1: Convertir una ruta de búsqueda a TripSteps
///
/// Esta función toma los resultados de búsqueda existentes y los convierte
/// a la estructura de pasos que usa el TripStateMachine.
List<TripStep> convertRouteTripToSteps({
  required Coordenada userLocation,
  required Coordenada destination,
  required List<dynamic> routeSegments, // Tu estructura actual de rutas
}) {
  final steps = <TripStep>[];
  var stepId = 0;

  for (final segment in routeSegments) {
    // Ejemplo: si el segmento es una caminata
    if (segment is WalkSegment) {
      steps.add(TripStep(
        id: 'step_${stepId++}',
        type: segment.isToFinalDestination
            ? TripStepType.walkToDestination
            : TripStepType.walkToStop,
        description: segment.isToFinalDestination
            ? 'Caminar al destino'
            : 'Caminar a parada ${segment.stopName}',
        metadata: TripStepMetadata(
          destinationStopId: segment.stopId,
          totalDistanceMeters: segment.distanceMeters,
        ),
      ));
    }
    // Ejemplo: si el segmento es esperar el bus
    else if (segment is WaitSegment) {
      steps.add(TripStep(
        id: 'step_${stepId++}',
        type: TripStepType.waitForBus,
        description: 'Esperar bus ${segment.busLine}',
        metadata: TripStepMetadata(
          originStopId: segment.stopId,
          busLine: segment.busLine,
          hasEta: segment.hasEta,
        ),
      ));
    }
    // Ejemplo: si el segmento es viajar en bus
    else if (segment is BusSegment) {
      steps.add(TripStep(
        id: 'step_${stepId++}',
        type: TripStepType.onBus,
        description: 'En bus ${segment.busLine} hasta ${segment.destinationStopName}',
        metadata: TripStepMetadata(
          originStopId: segment.originStopId,
          destinationStopId: segment.destinationStopId,
          busLine: segment.busLine,
        ),
      ));
    }
  }

  return steps;
}

/// PASO 2: Crear GeometryAdapter con datos de la app
///
/// Esta función construye el adaptador usando los repositorios existentes
/// de paradas y rutas de bus.
GeometryAdapter createAdapterFromAppData({
  required Map<String, StopData> stopsRepository, // Tu repositorio actual
  required Map<String, BusRoute> busRoutesRepository, // Tu repositorio actual
  required Coordenada destination,
  Coordenada? currentUserLocation,
}) {
  // Convertir paradas a formato Coordenada
  final stopLocations = <String, Coordenada>{};
  for (final entry in stopsRepository.entries) {
    stopLocations[entry.key] = Coordenada(
      latitud: entry.value.latitude,
      longitud: entry.value.longitude,
    );
  }

  // Convertir rutas de bus a formato List<Coordenada>
  final busRoutes = <String, List<Coordenada>>{};
  for (final entry in busRoutesRepository.entries) {
    busRoutes[entry.key] = entry.value.coordinates
        .map((coord) => Coordenada(
              latitud: coord.latitude,
              longitud: coord.longitude,
            ))
        .toList();
  }

  return GeometryAdapter(
    stopLocations: stopLocations,
    busRoutes: busRoutes,
    destinationLocation: destination,
    currentUserLocation: currentUserLocation,
  );
}

/// PASO 3: Provider para el TripOrchestrator
///
/// Este provider se puede usar con Riverpod para gestionar el viaje activo.
final activeTripOrchestratorProvider =
    StateNotifierProvider<ActiveTripNotifier, TripOrchestratorState?>((ref) {
  return ActiveTripNotifier();
});

class TripOrchestratorState {
  final TripOrchestrator orchestrator;
  final TripStateMachine stateMachine;
  final GeometryAdapter adapter;

  TripOrchestratorState({
    required this.orchestrator,
    required this.stateMachine,
    required this.adapter,
  });
}

class ActiveTripNotifier extends StateNotifier<TripOrchestratorState?> {
  ActiveTripNotifier() : super(null);

  /// Inicia un nuevo viaje
  void startTrip({
    required List<TripStep> steps,
    required GeometryAdapter adapter,
    required void Function() onCompleted,
    required void Function(TripStep) onStepChanged,
    required void Function(double) onProgressUpdated,
  }) {
    // Limpiar viaje anterior si existe
    if (state != null) {
      state!.orchestrator.dispose();
    }

    // Crear máquina de estados
    final stateMachine = TripStateMachine(
      tripId: 'trip_${DateTime.now().millisecondsSinceEpoch}',
      steps: steps,
    );

    // Crear orquestador
    final orchestrator = createDefaultOrchestrator(
      stateMachine: stateMachine,
      getContextForStep: adapter.createContextForStep,
      onTripCompleted: () {
        onCompleted();
        state = null; // Limpiar estado al completar
      },
      onStepChanged: onStepChanged,
      onProgressUpdated: onProgressUpdated,
    );

    // Actualizar estado
    state = TripOrchestratorState(
      orchestrator: orchestrator,
      stateMachine: stateMachine,
      adapter: adapter,
    );

    // Iniciar orquestador
    orchestrator.start(updateInterval: const Duration(seconds: 5));
  }

  /// Actualiza la ubicación del usuario
  void updateUserLocation(Coordenada location) {
    state?.adapter.updateUserLocation(location);
  }

  /// Cancela el viaje activo
  void cancelTrip() {
    if (state != null) {
      state!.orchestrator.cancel();
      state = null;
    }
  }

  @override
  void dispose() {
    state?.orchestrator.dispose();
    super.dispose();
  }
}

/// PASO 4: Uso desde la UI o AppLogicProvider
///
/// Ejemplo de cómo iniciar un viaje desde tu código existente:
void exampleUsageFromUI({
  required WidgetRef ref,
  required Coordenada userLocation,
  required Coordenada destination,
  required List<dynamic> routeSegments,
  required Map<String, StopData> stops,
  required Map<String, BusRoute> busRoutes,
}) {
  // 1. Convertir ruta a pasos
  final steps = convertRouteTripToSteps(
    userLocation: userLocation,
    destination: destination,
    routeSegments: routeSegments,
  );

  // 2. Crear adaptador
  final adapter = createAdapterFromAppData(
    stopsRepository: stops,
    busRoutesRepository: busRoutes,
    destination: destination,
    currentUserLocation: userLocation,
  );

  // 3. Iniciar viaje
  ref.read(activeTripOrchestratorProvider.notifier).startTrip(
        steps: steps,
        adapter: adapter,
        onCompleted: () {
          print('🎉 Viaje completado!');
          // Aquí actualizar UI, mostrar mensaje, etc.
        },
        onStepChanged: (newStep) {
          print('➡️ Nuevo paso: ${newStep.description}');
          // Aquí actualizar UI, cambiar vista del mapa, etc.
        },
        onProgressUpdated: (progress) {
          print('📊 Progreso: ${(progress * 100).toStringAsFixed(0)}%');
          // Aquí actualizar barra de progreso, etc.
        },
      );
}

/// PASO 5: Integración con LocationTracker
///
/// Conectar el tracker de GPS existente con el orquestador:
void onGPSLocationUpdate({
  required Coordenada newLocation,
  required WidgetRef ref,
}) {
  // Actualizar ubicación en el orquestrador
  ref.read(activeTripOrchestratorProvider.notifier).updateUserLocation(newLocation);

  // El orquestrador automáticamente:
  // 1. Calculará distancias
  // 2. Verificará geofences
  // 3. Actualizará progreso
  // 4. Detectará si debe avanzar al siguiente paso
  // 5. Emitirá eventos a los callbacks
}

// ============================================================================
// TIPOS DE EJEMPLO (reemplazar con tus tipos reales)
// ============================================================================

class WalkSegment {
  final String stopId;
  final String stopName;
  final double distanceMeters;
  final bool isToFinalDestination;

  WalkSegment({
    required this.stopId,
    required this.stopName,
    required this.distanceMeters,
    this.isToFinalDestination = false,
  });
}

class WaitSegment {
  final String stopId;
  final String busLine;
  final bool hasEta;

  WaitSegment({
    required this.stopId,
    required this.busLine,
    this.hasEta = false,
  });
}

class BusSegment {
  final String busLine;
  final String originStopId;
  final String destinationStopId;
  final String destinationStopName;

  BusSegment({
    required this.busLine,
    required this.originStopId,
    required this.destinationStopId,
    required this.destinationStopName,
  });
}

class StopData {
  final double latitude;
  final double longitude;

  StopData({required this.latitude, required this.longitude});
}

class BusRoute {
  final List<RouteCoordinate> coordinates;

  BusRoute({required this.coordinates});
}

class RouteCoordinate {
  final double latitude;
  final double longitude;

  RouteCoordinate({required this.latitude, required this.longitude});
}
