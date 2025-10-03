/// Handlers especializados para eventos de JourneyManager
///
/// Separa la lógica de manejo de eventos para mantener app_logic_provider.dart limpio.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../journey/journey_manager.dart';
import '../../../journey/journey_step_state.dart';
import '../../contrato_ui/app_ui_state.dart';
import '../../../ui/app_host.dart';
import 'logging_helpers.dart';

class JourneyEventHandlers {
  final Ref ref;
  final AppUiState Function() getState;
  final void Function(AppUiState) setState;

  JourneyEventHandlers({
    required this.ref,
    required this.getState,
    required this.setState,
  });

  /// Handler para actualización de ubicación
  void handleLocationUpdated(JourneyEvent event) {
    final location = event.data?['location'] as Coordenada?;
    if (location == null) return;

    final currentState = getState();
    setState(currentState.copyWith(ubicacionActualUsuario: location));
  }

  /// Handler para transición de paso
  void handleStepTransitioned(JourneyEvent event) {
    final stepIndex = event.data?['stepIndex'] as int?;
    final step = event.data?['step'] as JourneyStepState?;

    if (stepIndex == null || step == null) return;

    LoggingHelpers.logStepTransition(
      fromIndex: stepIndex - 1,
      toIndex: stepIndex,
      stepType: step.type.toString(),
    );

    // Actualizar UI según el nuevo paso
    _updateUIForNewStep(stepIndex, step);
  }

  /// Handler para llegada detectada
  void handleArrivalDetected(JourneyEvent event) {
    final stepType = event.data?['stepType'] as JourneyStepType?;

    if (stepType != null) {
      LoggingHelpers.logArrivalDetected(stepType.toString());
    }

    // La transición de paso ya manejará la actualización de UI
  }

  /// Handler para subida al bus detectada
  void handleBusBoardingDetected(JourneyEvent event) {
    final busInfo = event.data?['busInfo'] as String? ?? 'desconocido';

    LoggingHelpers.logBoardingDetected(busInfo);

    // La transición de paso ya manejará la actualización de UI
  }

  /// Handler para salida prematura del bus
  void handleBusEarlyExit(JourneyEvent event) {
    LoggingHelpers.logError(
      'BUS_EARLY_EXIT',
      'Usuario se bajó del bus antes de tiempo',
    );

    // Podríamos mostrar un mensaje al usuario o recalcular ruta
    final currentState = getState();
    setState(currentState.copyWith(
      mensajeErrorGlobal: 'Detectamos que te bajaste del bus. ¿Necesitas recalcular la ruta?',
    ));
  }

  /// Handler para viaje completado
  void handleJourneyCompleted(JourneyEvent event) {
    print("[AppLogic] 🎉 === VIAJE COMPLETADO ===");

    final currentState = getState();
    setState(currentState.copyWith(
      faseActual: FaseApp.INICIAL_SIN_BUSQUEDA,
      clearDatosFaseViajeActivo: true,
    ));
  }

  /// Handler para actualización de progreso
  void handleProgressUpdated(JourneyEvent event) {
    // El progreso ya se actualiza en el estado interno del JourneyManager
    // Aquí podríamos agregar lógica adicional si es necesaria
  }

  /// Handler para actualización de posición de bus
  void handleBusPositionUpdated(JourneyEvent event) {
    final busPosition = event.data?['position'] as Coordenada?;
    final eta = event.data?['eta'] as int?;
    final stepType = event.data?['stepType'] as JourneyStepType?;

    if (busPosition == null || eta == null) return;

    // Actualizar UI con nueva posición de bus
    final currentState = getState();
    final activeTripData = currentState.datosFaseViajeActivo;

    if (activeTripData != null) {
      // Actualizar estado con información de bus
      // Nota: etaBusRelevante no existe en AppUiState actual,
      // la información se maneja directamente por MapManager

      // Actualizar mapa
      _updateMapForBusPosition(busPosition, eta, stepType);
    }
  }

  /// Handler para ruta de caminata actualizada
  void handleWalkingRouteUpdated(JourneyEvent event) {
    final route = event.data?['route'] as List<Coordenada>?;

    if (route == null || route.isEmpty) return;

    // Actualizar ruta en el mapa
    final mapManager = ref.read(mapManagerProvider);
    mapManager?.updateWalkingRoute(route);
  }

  // ========== MÉTODOS PRIVADOS DE APOYO ==========

  void _updateUIForNewStep(int stepIndex, JourneyStepState step) {
    final currentState = getState();
    final activeTripData = currentState.datosFaseViajeActivo;

    if (activeTripData == null) return;

    // Aquí podrías actualizar información específica del UI según el paso
    // Por ahora solo registramos el cambio
  }

  void _updateMapForBusPosition(
    Coordenada busPosition,
    int eta,
    JourneyStepType? stepType,
  ) {
    final mapManager = ref.read(mapManagerProvider);
    if (mapManager == null) return;

    // Actualizar marcador de bus
    mapManager.updateBusPosition(busPosition, eta, true);

    // Ajustar zoom si es necesario
    final currentState = getState();
    final userLocation = currentState.ubicacionActualUsuario;

    if (stepType != null) {
      mapManager.adjustZoomForBusUpdate(
        busPosition: busPosition,
        stepType: stepType.toString(),
        userPosition: userLocation,
      );
    }
  }
}
