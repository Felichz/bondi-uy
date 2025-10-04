import 'dart:math' as math;
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import 'package:bondi_uy/devtools/trip_simulation_spec.dart';
import 'package:bondi_uy/utils/geometry_utils.dart';

/// Construye especificaciones de simulación desde diferentes fuentes
///
/// Responsabilidades:
/// - Extraer geometrías del estado de la app
/// - Construir rutas simplificadas para simulación
/// - Configurar duraciones basadas en distancias reales
/// - Definir eventos de cámara esperados según especificaciones del flujo
class TripSimulationBuilder {
  /// Construye spec desde el estado actual de viaje activo
  static TripSimulationSpec fromActiveTripState(
    EstadoFaseViajeActivo state, {
    Coordenada? initialBusPosition,
    double speed = 1.0,
  }) {
    final phases = <SimulationPhase>[];

    // Encontrar primer tramo de bus
    final busIndex = state.tramosDelViaje.indexWhere(
      (t) => t.tipo == TipoTramoViaje.VIAJE_EN_BUS,
    );

    if (busIndex < 0) {
      throw Exception('No se encontró tramo de bus en el viaje');
    }

    // FASE 1: Walking to stop (si existe)
    final walkToStopGeom = _extractWalkToStopGeometry(state, busIndex);
    if (walkToStopGeom.isNotEmpty) {
      phases.add(SimulationPhase(
        type: PhaseType.walkToStop,
        duration: 15.0, // TODO: Calcular basado en distancia real
        userPath: walkToStopGeom,
        description: 'Usuario camina a la parada',
      ));
    }

    // FASES 2 y 3: Bus approach + Ride
    final busTramo = state.tramosDelViaje[busIndex];
    final busGeometry = busTramo.geometriaPolilinea ?? [];

    if (busGeometry.isNotEmpty) {
      final busPhases = _buildBusPhases(
        busGeometry: busGeometry,
        stopOrigin: busTramo.coordenadasParadaOrigen,
        stopDestination: busTramo.coordenadasParadaDestino,
        initialBusPosition: initialBusPosition ?? state.posicionActualBusReal,
      );
      phases.addAll(busPhases);
    }

    // FASE 4: Walking to destination (si existe)
    final walkToDestGeom = _extractWalkToDestGeometry(state, busIndex);
    if (walkToDestGeom.isNotEmpty) {
      phases.add(SimulationPhase(
        type: PhaseType.walkToDestination,
        duration: 10.0, // TODO: Calcular basado en distancia real
        userPath: walkToDestGeom,
        description: 'Usuario camina al destino final',
      ));
    }

    // Construir eventos de cámara esperados según flujo
    final cameraEvents = _buildExpectedCameraEvents(phases);

    return TripSimulationSpec(
      phases: phases,
      config: SimulationConfig(
        speed: speed,
        emitEvents: true,
        expectedCameraEvents: cameraEvents,
      ),
    );
  }

  /// Extrae geometría de caminata a parada
  static List<Coordenada> _extractWalkToStopGeometry(
    EstadoFaseViajeActivo state,
    int busIndex,
  ) {
    for (int i = 0; i < busIndex; i++) {
      final tramo = state.tramosDelViaje[i];
      if (tramo.tipo == TipoTramoViaje.CAMINAR &&
          (tramo.geometriaPolilinea?.isNotEmpty ?? false)) {
        return List<Coordenada>.from(tramo.geometriaPolilinea!);
      }
    }
    return [];
  }

  /// Extrae geometría de caminata a destino
  static List<Coordenada> _extractWalkToDestGeometry(
    EstadoFaseViajeActivo state,
    int busIndex,
  ) {
    for (int i = busIndex + 1; i < state.tramosDelViaje.length; i++) {
      final tramo = state.tramosDelViaje[i];
      if (tramo.tipo == TipoTramoViaje.CAMINAR &&
          (tramo.geometriaPolilinea?.isNotEmpty ?? false)) {
        return List<Coordenada>.from(tramo.geometriaPolilinea!);
      }
    }
    return [];
  }

  /// Construye las fases de bus (approach + ride)
  ///
  /// Esto reemplaza toda la lógica compleja de _buildTraces
  static List<SimulationPhase> _buildBusPhases({
    required List<Coordenada> busGeometry,
    required Coordenada? stopOrigin,
    required Coordenada? stopDestination,
    Coordenada? initialBusPosition,
  }) {
    if (busGeometry.length < 2) return [];

    final stop = stopOrigin ?? busGeometry.first;
    final dest = stopDestination ?? busGeometry.last;

    final stopIdx = findClosestPointIndexOnShape(busGeometry, stop);
    final destIdx = findClosestPointIndexOnShape(busGeometry, dest);

    // Bus approach: desde posición actual/inicio hasta parada
    List<Coordenada> approachPath;
    if (initialBusPosition != null) {
      final currentIdx = findClosestPointIndexOnShape(
        busGeometry,
        initialBusPosition,
      );
      approachPath = _extractSegment(busGeometry, currentIdx, stopIdx);
    } else {
      // Fallback: usar 60 puntos antes de la parada
      final startIdx = math.max(0, stopIdx - 60);
      approachPath = busGeometry.sublist(startIdx, stopIdx + 1);
    }

    // Ride: desde parada origen hasta parada destino
    final ridePath = _extractSegment(busGeometry, stopIdx, destIdx);

    return [
      // Fase de espera: bus se acerca mientras usuario espera en parada
      SimulationPhase(
        type: PhaseType.waitForBus,
        duration: 15.0,
        userPath: [stop], // Usuario quieto en la parada
        busPath: approachPath,
        busEtaMinutes: 5,
        description: 'Usuario espera en parada, bus se acerca',
      ),
      // Fase de viaje: usuario y bus viajan juntos
      SimulationPhase(
        type: PhaseType.rideOnBus,
        duration: 15.0,
        userPath: ridePath,
        busPath: ridePath, // Misma ruta
        description: 'Usuario viaja en el bus',
      ),
    ];
  }

  /// Extrae un segmento de geometría entre dos índices
  static List<Coordenada> _extractSegment(
    List<Coordenada> geometry,
    int startIdx,
    int endIdx,
  ) {
    if (startIdx <= endIdx) {
      return geometry.sublist(startIdx, endIdx + 1);
    } else {
      // Si el bus está "adelante" en la geometría, invertir
      return List<Coordenada>.from(
        geometry.sublist(endIdx, startIdx + 1).reversed,
      );
    }
  }

  /// Define los eventos de cámara esperados según el flujo de usuario
  ///
  /// Basado en: docs/flujos/flujo-principal/1-flujo-de-usuario.txt
  static List<ExpectedCameraEvent> _buildExpectedCameraEvents(
    List<SimulationPhase> phases,
  ) {
    final events = <ExpectedCameraEvent>[];
    double cumulativeTime = 0.0;

    for (int i = 0; i < phases.length; i++) {
      final phase = phases[i];

      switch (phase.type) {
        case PhaseType.walkToStop:
          // "dibujamos un tramo azul desde la ubicacion del usuario hasta la parada"
          events.add(ExpectedCameraEvent(
            atTime: cumulativeTime + 1.0, // Al inicio de la fase
            type: CameraEventType.zoomToUserAndStop,
            description:
                'Cámara debe enfocar usuario y parada (tramo azul de caminata)',
            expectedData: {
              'shouldInclude': ['user', 'stop'],
              'shouldDrawBlueLine': true,
            },
          ));
          break;

        case PhaseType.waitForBus:
          // "el mapa va a enfocar la parada y tambien el bus en tiempo real"
          // "el enfoque siempre se debe mantener entre la parada y el bus"
          events.add(ExpectedCameraEvent(
            atTime: cumulativeTime + 1.0,
            type: CameraEventType.zoomToBusAndStop,
            description:
                'Cámara debe enfocar parada Y bus acercándose (línea verde)',
            expectedData: {
              'shouldInclude': ['bus', 'stop'],
              'shouldDrawGreenLine': true,
              'shouldAdjustZoomOnBusUpdate': true,
            },
          ));
          break;

        case PhaseType.rideOnBus:
          // "el mapa ajustará el enfoque basandose unicamente en la parada de destino
          // y la ubicación del usuario osea el bus dibujado en la ubicación del usuario"
          events.add(ExpectedCameraEvent(
            atTime: cumulativeTime + 1.0,
            type: CameraEventType.zoomToUserOnBus,
            description:
                'Cámara debe enfocar bus (= usuario) y parada de destino',
            expectedData: {
              'shouldInclude': ['user', 'destinationStop'],
              'userShouldEqualBus': true,
            },
          ));
          break;

        case PhaseType.walkToDestination:
          // "el mapa vuelve a dibujar la ubicación del usuario de manera default"
          events.add(ExpectedCameraEvent(
            atTime: cumulativeTime + 1.0,
            type: CameraEventType.zoomToDestination,
            description:
                'Cámara debe enfocar usuario y destino final (modo caminata)',
            expectedData: {
              'shouldInclude': ['user', 'destination'],
              'shouldDrawBlueLine': true,
            },
          ));
          break;
      }

      cumulativeTime += phase.duration;
    }

    return events;
  }
}
