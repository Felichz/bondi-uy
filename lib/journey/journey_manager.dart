// lib/journey/journey_manager.dart

/// JourneyManager
///
/// Encapsula TODA la lógica compleja de navegación automática de un viaje activo.
/// Esta clase es la responsable de:
/// - Gestionar el estado interno del journey (pasos, progreso, transiciones)
/// - Coordinar LocationTracker para seguimiento de ubicación
/// - Detectar eventos automáticos (llegadas, subida al bus, etc.)
/// - Calcular progreso dinámico usando RouteDynamicCalculator
/// - Notificar cambios importantes al orquestador (AppLogicNotifier)
///
/// AppLogicNotifier usa JourneyManager internamente y traduce sus eventos
/// a actualizaciones de AppUiState para la UI.

import 'dart:async';
import '../backend/contrato_ui/app_ui_state.dart';
import 'location_tracker.dart';
import 'journey_step_state.dart';
import 'route_dynamic_calculator.dart';
import '../utils/geometry_utils.dart';
import 'package:bondi_uy/utils/feature_logger.dart';
import 'detectors/geofencing_detector.dart';
import 'detectors/bus_boarding_detector.dart';
import 'detectors/bus_exit_detector.dart';

/// Eventos que JourneyManager puede emitir
enum JourneyEventType {
  LOCATION_UPDATED,
  STEP_TRANSITIONED,
  ARRIVAL_DETECTED,
  BUS_BOARDING_DETECTED,
  BUS_EARLY_EXIT_DETECTED, // Usuario se bajó del bus antes de tiempo
  JOURNEY_COMPLETED,
  PROGRESS_UPDATED,
  BUS_POSITION_UPDATED, // Actualización de posición de bus en tiempo real
  WALKING_ROUTE_UPDATED, // Ruta walking recalculada
}

class JourneyEvent {
  final JourneyEventType type;
  final Map<String, dynamic>? data;

  JourneyEvent(this.type, {this.data});
}

/// Estado interno del JourneyManager
class JourneyState {
  final int currentStepIndex;
  final JourneyStepState currentStep;
  final Coordenada? lastKnownLocation;
  final RouteProgress? currentProgress;
  final bool isActive;

  JourneyState({
    required this.currentStepIndex,
    required this.currentStep,
    this.lastKnownLocation,
    this.currentProgress,
    this.isActive = true,
  });

  JourneyState copyWith({
    int? currentStepIndex,
    JourneyStepState? currentStep,
    Coordenada? lastKnownLocation,
    RouteProgress? currentProgress,
    bool? isActive,
  }) {
    return JourneyState(
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      currentStep: currentStep ?? this.currentStep,
      lastKnownLocation: lastKnownLocation ?? this.lastKnownLocation,
      currentProgress: currentProgress ?? this.currentProgress,
      isActive: isActive ?? this.isActive,
    );
  }
}

class JourneyManager {
  final List<TramoViajeMostrable> tramos;
  final void Function(JourneyEvent) onEvent;
  final bool isTestMode;

  // Componentes internos
  LocationTracker? _locationTracker;
  JourneyState? _state;

  // Detectores especializados (disponibles para uso futuro)
  final _geofencingDetector = GeofencingDetector();
  final _busBoardingDetector = BusBoardingDetector();
  final _busExitDetector = BusExitDetector();

  // Histéresis para detección de subida al bus
  int _busBoardingPositiveCount = 0;
  DateTime? _lastBusBoardingEval;
  static const int _busBoardingRequiredConsecutive = 5;
  static const Duration _busBoardingEvalMinSpacing = Duration(milliseconds: 900);
  static const double _departureThresholdMeters = 90.0;

  // Ubicación previa para análisis direccional
  Coordenada? _previousUserLocation;
  DateTime? _lastLocationUpdate;

  // Bus tracking en tiempo real
  Timer? _busTrackingTimer;
  Coordenada? _currentBusPosition;
  int? _currentBusEta;

  // Recálculo dinámico de ruta walking
  Timer? _routeRecalculationTimer;

  // Detección de bajada prematura del bus
  static const double _busProximityThreshold = 50.0;
  int _busExitNegativeCount = 0;
  static const int _busExitRequiredConsecutive = 3;

  JourneyManager({
    required this.tramos,
    required this.onEvent,
    this.isTestMode = false,
  });

  /// Inicializar el journey manager y comenzar tracking
  Future<void> initialize() async {
    print("[JOURNEY_MANAGER] 🎯 === INICIALIZANDO ====");
    print("[JOURNEY_MANAGER] 🎯 Total de tramos: ${tramos.length}");

    if (tramos.isEmpty) {
      print("[JOURNEY_MANAGER] ❌ No hay tramos para inicializar");
      throw Exception("No se puede inicializar journey sin tramos");
    }

    try {
      // Crear LocationTracker
      print("[JOURNEY_MANAGER] 📍 Creando LocationTracker...");
      _locationTracker = LocationTracker(
        onLocationUpdate: _handleLocationUpdate,
        onArrivalDetected: _handleArrivalDetected,
        isTestMode: isTestMode,
      );
      print("[JOURNEY_MANAGER] ✅ LocationTracker creado");

      // Inicializar estado con primer paso
      final primerTramo = tramos[0];
      final stepType = _determineStepType(primerTramo, 0);
      final destination = _getStepDestination(primerTramo);

      print("[JOURNEY_MANAGER] 🚶‍♂️ Configurando primer paso:");
      print("[JOURNEY_MANAGER] 🚶‍♂️   Tipo: $stepType");
      print("[JOURNEY_MANAGER] 🚶‍♂️   Destino: $destination");

      // Obtener ubicación inicial
      final initialLocation = _locationTracker?.lastKnownLocation;

      _state = JourneyState(
        currentStepIndex: 0,
        currentStep: JourneyStepState(
          stepIndex: 0,
          type: stepType,
          destination: destination,
          startLocation: initialLocation,
          busLine: primerTramo.nombreLineaBus,
          instructions: _getStepInstructions(primerTramo),
          startTime: DateTime.now(),
          currentRoute: primerTramo.geometriaPolilinea,
        ),
        lastKnownLocation: initialLocation,
        isActive: true,
      );
      print("[JOURNEY_MANAGER] ✅ Estado inicial configurado");

      // Configurar geofences para primer paso
      print("[JOURNEY_MANAGER] 🎯 Configurando geofences...");
      _setupGeofencesForCurrentStep();
      print("[JOURNEY_MANAGER] ✅ Geofences configurados");

      // Iniciar tracking de ubicación
      print("[JOURNEY_MANAGER] 📡 Iniciando tracking de ubicación...");
      await _locationTracker!.startTracking();
      print("[JOURNEY_MANAGER] ✅ Tracking iniciado");

      print("[JOURNEY_MANAGER] ✅ === INICIALIZACIÓN COMPLETADA ====");
    } catch (e, stackTrace) {
      print("[JOURNEY_MANAGER] ❌ Error en inicialización: $e");
      print("[JOURNEY_MANAGER] ❌ Stack trace: $stackTrace");
      rethrow;
    }
  }

  /// Detener el journey manager
  Future<void> stop() async {
    print("[JOURNEY_MANAGER] 🛑 Deteniendo...");

    // Detener location tracking
    await _locationTracker?.stopTracking();
    _locationTracker?.dispose();
    _locationTracker = null;

    // Detener timers
    _stopBusTracking();
    _stopRouteRecalculation();

    // Marcar estado como inactivo
    if (_state != null) {
      _state = _state!.copyWith(isActive: false);
    }

    print("[JOURNEY_MANAGER] ✅ Detenido");
  }

  /// Alias para compatibilidad
  Future<void> dispose() async {
    await stop();
  }

  /// Obtener el estado actual
  JourneyState? get currentState => _state;

  /// Callback de actualización de ubicación desde LocationTracker
  void _handleLocationUpdate(Coordenada newLocation) {
    if (_state == null || !_state!.isActive) return;

    print("[JOURNEY_MANAGER] 📍 Ubicación actualizada: ${newLocation.latitud}, ${newLocation.longitud}");

    try {
      FeatureLogger().log(
        'journey',
        'location_update',
        data: {
          'lat': newLocation.latitud,
          'lon': newLocation.longitud,
          'step': _state!.currentStepIndex,
          'type': _state!.currentStep.type.toString(),
        },
      );
    } catch (_) {}

    // Actualizar timestamp
    final now = DateTime.now();
    _lastLocationUpdate = now;

    // Actualizar estado con nueva ubicación
    _state = _state!.copyWith(lastKnownLocation: newLocation);

    // Calcular progreso actualizado
    _updateProgress(newLocation);

    // Detectar subida al bus si estamos esperando
    if (_state!.currentStep.type == JourneyStepType.WAITING_FOR_BUS) {
      _evaluateBusBoarding(newLocation, now);
    }

    // Detectar bajada prematura del bus si estamos en el bus
    if (_state!.currentStep.type == JourneyStepType.RIDING_BUS) {
      _evaluateBusEarlyExit(newLocation);
    }

    // Notificar evento de ubicación
    onEvent(JourneyEvent(
      JourneyEventType.LOCATION_UPDATED,
      data: {
        'location': newLocation,
        'stepIndex': _state!.currentStepIndex,
        'stepType': _state!.currentStep.type,
      },
    ));

    // Guardar para análisis direccional
    _previousUserLocation = newLocation;
  }

  /// Callback de llegada detectada desde LocationTracker
  void _handleArrivalDetected(String geofenceId) {
    if (_state == null || !_state!.isActive) return;

    print("[JOURNEY_MANAGER] 🎯 Llegada detectada: $geofenceId");

    try {
      FeatureLogger().log(
        'journey',
        'arrival',
        data: {
          'geofence': geofenceId,
          'step': _state!.currentStepIndex,
        },
      );
    } catch (_) {}

    // Notificar evento de llegada
    onEvent(JourneyEvent(
      JourneyEventType.ARRIVAL_DETECTED,
      data: {'geofenceId': geofenceId},
    ));

    // Transición al siguiente paso
    _transitionToNextStep();
  }

  /// Evaluar si el usuario ha subido al bus
  void _evaluateBusBoarding(Coordenada userLocation, DateTime now) {
    if (_state == null || !_state!.isActive) return;

    final currentStepIndex = _state!.currentStepIndex;

    // Buscar el próximo tramo de bus
    TramoViajeMostrable? nextBusTramo;
    for (int i = currentStepIndex + 1; i < tramos.length; i++) {
      if (tramos[i].tipo == TipoTramoViaje.VIAJE_EN_BUS) {
        nextBusTramo = tramos[i];
        break;
      }
    }

    if (nextBusTramo == null || nextBusTramo.geometriaPolilinea == null) {
      return;
    }

    // Obtener velocidad actual del LocationTracker
    final userSpeed = _locationTracker?.currentSpeed ?? 0.0;

    // Usar RouteDynamicCalculator para detectar boarding
    final busBoarding = RouteDynamicCalculator.detectBusBoarding(
      userLocation: userLocation,
      busRoutePoints: nextBusTramo.geometriaPolilinea!,
      userSpeed: userSpeed,
      previousLocation: _previousUserLocation,
    );

    // Aplicar histéresis para evitar falsos positivos
    if (_lastBusBoardingEval != null &&
        now.difference(_lastBusBoardingEval!) < _busBoardingEvalMinSpacing) {
      return;
    }
    _lastBusBoardingEval = now;

    if (busBoarding) {
      _busBoardingPositiveCount++;
      print(
        "[JOURNEY_MANAGER] 🚌 Boarding detection positivo (${_busBoardingPositiveCount}/$_busBoardingRequiredConsecutive)",
      );

      if (_busBoardingPositiveCount >= _busBoardingRequiredConsecutive) {
        print("[JOURNEY_MANAGER] �� === SUBIDA AL BUS DETECTADA ===");

        try {
          FeatureLogger().log('journey', 'bus_boarding_detected');
        } catch (_) {}

        // Notificar evento de subida al bus
        onEvent(JourneyEvent(JourneyEventType.BUS_BOARDING_DETECTED));

        // Resetear contador
        _busBoardingPositiveCount = 0;

        // Transición al paso de viaje en bus
        _transitionToNextStep();
      }
    } else {
      _busBoardingPositiveCount = 0;
    }
  }

  /// Evaluar si el usuario se bajó del bus prematuramente
  void _evaluateBusEarlyExit(Coordenada userLocation) {
    if (_state == null || !_state!.isActive) return;
    if (_currentBusPosition == null) return; // Sin posición de bus, no evaluar

    // Calcular distancia entre usuario y bus
    final distanceToBus = calculateHaversineDistance(
      userLocation.latitud,
      userLocation.longitud,
      _currentBusPosition!.latitud,
      _currentBusPosition!.longitud,
    );

    print(
      "[JOURNEY_MANAGER] 🚌 Distancia usuario-bus: ${distanceToBus.toStringAsFixed(1)}m",
    );

    // Si el usuario está lejos del bus, incrementar contador
    if (distanceToBus > _busProximityThreshold) {
      _busExitNegativeCount++;
      print(
        "[JOURNEY_MANAGER] ⚠️ Usuario lejos del bus (${_busExitNegativeCount}/$_busExitRequiredConsecutive)",
      );

      if (_busExitNegativeCount >= _busExitRequiredConsecutive) {
        print("[JOURNEY_MANAGER] 🚪 === BAJADA PREMATURA DETECTADA ===");

        try {
          FeatureLogger().log('journey', 'bus_early_exit_detected');
        } catch (_) {}

        // Notificar evento de bajada prematura
        onEvent(JourneyEvent(
          JourneyEventType.BUS_EARLY_EXIT_DETECTED,
          data: {
            'location': userLocation,
            'busPosition': _currentBusPosition,
            'distance': distanceToBus,
          },
        ));

        // Resetear contador
        _busExitNegativeCount = 0;

        // TODO: Decidir qué hacer - ¿volver a WAITING_FOR_BUS? ¿recalcular ruta?
        // Por ahora solo notificamos, la app decide
      }
    } else {
      // Usuario cerca del bus, resetear contador
      _busExitNegativeCount = 0;
    }
  }

  /// Actualizar el progreso del paso actual
  Future<void> _updateProgress(Coordenada userLocation) async {
    if (_state == null || !_state!.isActive) return;

    final progress = await _calculateStepProgress(userLocation);
    _state = _state!.copyWith(currentProgress: progress);

    // Notificar evento de progreso
    onEvent(JourneyEvent(
      JourneyEventType.PROGRESS_UPDATED,
      data: {'progress': progress},
    ));
  }

  /// Calcular el progreso del paso actual
  Future<RouteProgress> _calculateStepProgress(Coordenada userLocation) async {
    if (_state == null ||
        _state!.currentStep.destination == null ||
        _state!.currentStepIndex >= tramos.length) {
      return _emptyProgress();
    }

    final tramo = tramos[_state!.currentStepIndex];
    final poly = tramo.geometriaPolilinea;

    // Si hay polilínea, usar progreso basado en proyección
    if (poly != null && poly.length >= 2) {
      // Calcular distancia total de la polilínea
      double total = 0.0;
      for (int i = 0; i < poly.length - 1; i++) {
        total += calculateHaversineDistance(
          poly[i].latitud,
          poly[i].longitud,
          poly[i + 1].latitud,
          poly[i + 1].longitud,
        );
      }

      // Metros recorridos usando proyección a segmento
      final completed = RouteDynamicCalculator.progressAlongPolyline(
        point: userLocation,
        polyline: poly,
      );

      final remaining = (total - completed).clamp(0.0, total);
      final pct = total > 0 ? ((completed / total) * 100.0).clamp(0.0, 100.0) : 0.0;

      // Calcular tiempo restante basado en velocidad
      const double walkingSpeedMps = 1.4; // 5 km/h
      const double busSpeedMps = 8.33; // 30 km/h
      final speed =
          _state!.currentStep.type == JourneyStepType.RIDING_BUS
              ? busSpeedMps
              : walkingSpeedMps;
      final remainingSecs = speed > 0 ? (remaining / speed).round() : 0;

      return RouteProgress(
        percentageComplete: pct,
        remainingDistance: remaining,
        remainingTimeSeconds: remainingSecs,
        currentOptimalRoute: poly,
        totalDistance: total,
        completedDistance: completed,
      );
    }

    // Fallback a cálculo por línea recta
    if (_state!.currentStep.type == JourneyStepType.RIDING_BUS) {
      return RouteDynamicCalculator.calculateBusProgress(
        startLocation: _state!.currentStep.startLocation ?? userLocation,
        currentLocation: userLocation,
        destination: _state!.currentStep.destination!,
      );
    }

    return RouteDynamicCalculator.calculateProgress(
      startLocation: _state!.currentStep.startLocation ?? userLocation,
      currentLocation: userLocation,
      destination: _state!.currentStep.destination!,
    );
  }

  RouteProgress _emptyProgress() {
    return RouteProgress(
      percentageComplete: 0,
      remainingDistance: 0,
      remainingTimeSeconds: 0,
      currentOptimalRoute: [],
      totalDistance: 0,
      completedDistance: 0,
    );
  }

  /// Transición al siguiente paso
  void _transitionToNextStep() {
    if (_state == null || !_state!.isActive) return;

    print("[JOURNEY_MANAGER] 🔄 === TRANSICIÓN AL SIGUIENTE PASO ====");

    final currentStepIndex = _state!.currentStepIndex;
    final nextStepIndex = currentStepIndex + 1;

    print("[JOURNEY_MANAGER] 🔄 Paso actual: $currentStepIndex");
    print("[JOURNEY_MANAGER] 🔄 Siguiente paso: $nextStepIndex");
    print("[JOURNEY_MANAGER] 🔄 Total de tramos: ${tramos.length}");

    // Verificar si hemos completado el viaje
    if (nextStepIndex >= tramos.length) {
      print("[JOURNEY_MANAGER] 🏁 === VIAJE COMPLETADO ===");

      try {
        FeatureLogger().log('journey', 'journey_complete');
      } catch (_) {}

      _state = _state!.copyWith(isActive: false);

      onEvent(JourneyEvent(JourneyEventType.JOURNEY_COMPLETED));
      return;
    }

    // Configurar siguiente paso
    final nextTramo = tramos[nextStepIndex];
    final nextStepType = _determineStepType(nextTramo, nextStepIndex);
    final nextDestination = _getStepDestination(nextTramo);

    print("[JOURNEY_MANAGER] ➡️ Nuevo paso:");
    print("[JOURNEY_MANAGER] ➡️   Tipo: $nextStepType");
    print("[JOURNEY_MANAGER] ➡️   Destino: $nextDestination");
    print("[JOURNEY_MANAGER] ➡️   Línea: ${nextTramo.nombreLineaBus}");

    final newStep = JourneyStepState(
      stepIndex: nextStepIndex,
      type: nextStepType,
      destination: nextDestination,
      startLocation: _state!.lastKnownLocation,
      busLine: nextTramo.nombreLineaBus,
      instructions: _getStepInstructions(nextTramo),
      startTime: DateTime.now(),
      currentRoute: nextTramo.geometriaPolilinea,
    );

    _state = JourneyState(
      currentStepIndex: nextStepIndex,
      currentStep: newStep,
      lastKnownLocation: _state!.lastKnownLocation,
      isActive: true,
    );

    // Reconfigurar geofences
    print("[JOURNEY_MANAGER] 🎯 Reconfigurando geofences...");
    _setupGeofencesForCurrentStep();

    // Gestionar timers según tipo de paso
    _manageStepTimers(nextStepType);

    // Notificar transición
    try {
      FeatureLogger().log(
        'journey',
        'step_transition',
        data: {
          'from': currentStepIndex,
          'to': nextStepIndex,
          'type': nextStepType.toString(),
        },
      );
    } catch (_) {}

    onEvent(JourneyEvent(
      JourneyEventType.STEP_TRANSITIONED,
      data: {
        'previousIndex': currentStepIndex,
        'newIndex': nextStepIndex,
        'newStep': newStep,
      },
    ));

    print("[JOURNEY_MANAGER] ✅ === TRANSICIÓN COMPLETADA ===");
  }

  /// Gestionar timers según el tipo de paso
  void _manageStepTimers(JourneyStepType stepType) {
    print("[JOURNEY_MANAGER] ⏱️ Gestionando timers para paso: $stepType");

    switch (stepType) {
      case JourneyStepType.WALKING_TO_STOP:
      case JourneyStepType.WALKING_TO_DESTINATION:
        // Iniciar recálculo de ruta walking
        _stopBusTracking(); // Detener bus tracking si estaba activo
        _startRouteRecalculation();
        break;

      case JourneyStepType.WAITING_FOR_BUS:
        // Iniciar bus tracking
        _stopRouteRecalculation(); // Detener recálculo de ruta
        _startBusTracking();
        break;

      case JourneyStepType.RIDING_BUS:
        // Mantener bus tracking (para detectar bajada prematura)
        _stopRouteRecalculation();
        // NO detenemos _busTrackingTimer - seguimos trackeando el bus
        print("[JOURNEY_MANAGER] 🚌 Manteniendo bus tracking para detección de bajada prematura");
        break;
    }
  }

  /// Configurar geofences para el paso actual
  void _setupGeofencesForCurrentStep() {
    if (_locationTracker == null || _state == null) return;

    print("[JOURNEY_MANAGER] 🎯 Configurando geofences para paso ${_state!.currentStepIndex}");

    // Para WAITING_FOR_BUS, NO configurar geofences automáticos
    // La transición ocurre por detección de boarding
    if (_state!.currentStep.type == JourneyStepType.WAITING_FOR_BUS) {
      print("[JOURNEY_MANAGER] 🚏 WAITING_FOR_BUS - sin geofences automáticos");
      _locationTracker!.setupGeofencesForStep([], []);
      return;
    }

    // Para otros pasos, configurar geofence en el destino
    if (_state!.currentStep.destination != null) {
      final destination = _state!.currentStep.destination!;
      final geofenceId = 'step_${_state!.currentStepIndex}_destination';

      print("[JOURNEY_MANAGER] 🎯 Geofence: $geofenceId");
      print("[JOURNEY_MANAGER] 🎯 Destino: ${destination.latitud}, ${destination.longitud}");

      _locationTracker!.setupGeofencesForStep(
        [destination],
        [geofenceId],
      );
    }
  }

  /// Determinar el tipo de paso
  JourneyStepType _determineStepType(TramoViajeMostrable tramo, int index) {
    switch (tramo.tipo) {
      case TipoTramoViaje.CAMINAR:
        // Determinar si es caminar a parada o a destino final
        final isLastStep = index == tramos.length - 1;
        return isLastStep
            ? JourneyStepType.WALKING_TO_DESTINATION
            : JourneyStepType.WALKING_TO_STOP;
      case TipoTramoViaje.ESPERAR_BUS:
        return JourneyStepType.WAITING_FOR_BUS;
      case TipoTramoViaje.VIAJE_EN_BUS:
        return JourneyStepType.RIDING_BUS;
    }
  }

  /// Obtener el destino del paso
  Coordenada? _getStepDestination(TramoViajeMostrable tramo) {
    switch (tramo.tipo) {
      case TipoTramoViaje.CAMINAR:
        // Último punto de la geometría
        if (tramo.geometriaPolilinea != null &&
            tramo.geometriaPolilinea!.isNotEmpty) {
          return tramo.geometriaPolilinea!.last;
        }
        return null;
      case TipoTramoViaje.ESPERAR_BUS:
        // Posición de la parada
        return tramo.posicionPunto ?? tramo.coordenadasParadaOrigen;
      case TipoTramoViaje.VIAJE_EN_BUS:
        // Parada destino
        return tramo.coordenadasParadaDestino;
    }
  }

  /// Obtener instrucciones del paso
  String _getStepInstructions(TramoViajeMostrable tramo) {
    switch (tramo.tipo) {
      case TipoTramoViaje.CAMINAR:
        return tramo.descripcion ?? 'Camina hacia el destino';
      case TipoTramoViaje.ESPERAR_BUS:
        return 'Espera el bus ${tramo.nombreLineaBus ?? ''}';
      case TipoTramoViaje.VIAJE_EN_BUS:
        return 'Viaja en el bus ${tramo.nombreLineaBus ?? ''}';
    }
  }

  /// Método para inyectar ubicación simulada (para testing/dev)
  void injectLocationUpdate(Coordenada location) {
    if (_locationTracker != null) {
      _locationTracker!.injectLocationUpdate(location);
    }
  }

  /// Activar modo de feed externo (para simulación)
  void enterExternalFeedMode() {
    if (_locationTracker != null) {
      _locationTracker!.enterExternalFeedMode();
    }
  }

  // ============================================================================
  // BUS TRACKING EN TIEMPO REAL
  // ============================================================================

  /// Iniciar tracking de bus en tiempo real
  void _startBusTracking() {
    if (_state == null) return;

    final currentStepIndex = _state!.currentStepIndex;

    // Buscar el siguiente tramo de bus
    TramoViajeMostrable? busTramo;
    for (int i = currentStepIndex; i < tramos.length; i++) {
      if (tramos[i].tipo == TipoTramoViaje.VIAJE_EN_BUS) {
        busTramo = tramos[i];
        break;
      }
    }

    if (busTramo == null) {
      print("[JOURNEY_MANAGER] 🚌 No hay tramo de bus para trackear");
      return;
    }

    // Verificar si hay información de bus disponible
    // TODO: Integrar con API real de bus
    print("[JOURNEY_MANAGER] 🚌 Iniciando bus tracking para línea: ${busTramo.nombreLineaBus}");

    // Iniciar timer de polling cada 10 segundos
    _busTrackingTimer = Timer.periodic(
      Duration(seconds: 10),
      (_) => _fetchBusPosition(busTramo!),
    );

    // Fetch inicial inmediato
    _fetchBusPosition(busTramo);
  }

  /// Obtener posición actual del bus desde API
  Future<void> _fetchBusPosition(TramoViajeMostrable busTramo) async {
    if (_state == null || !_state!.isActive) return;

    // TODO: Implementar llamada real a API de bus
    // Por ahora, este método será llamado desde app_logic_provider
    // cuando reciba updates de la API

    print("[JOURNEY_MANAGER] 🚌 Fetching bus position...");

    // La posición será actualizada via updateBusPosition()
  }

  /// Actualizar posición del bus (llamado desde app_logic_provider)
  void updateBusPosition(Coordenada position, int eta) {
    _currentBusPosition = position;
    _currentBusEta = eta;

    print(
      "[JOURNEY_MANAGER] 🚌 Bus actualizado: ${position.latitud}, ${position.longitud} (ETA: ${eta}min)",
    );

    // Emitir evento
    onEvent(JourneyEvent(
      JourneyEventType.BUS_POSITION_UPDATED,
      data: {
        'position': position,
        'eta': eta,
        'stepType': _state?.currentStep.type,
      },
    ));
  }

  /// Detener tracking de bus
  void _stopBusTracking() {
    if (_busTrackingTimer != null) {
      print("[JOURNEY_MANAGER] 🚌 Deteniendo bus tracking");
      _busTrackingTimer?.cancel();
      _busTrackingTimer = null;
      _currentBusPosition = null;
      _currentBusEta = null;
    }
  }

  /// Verificar si un tramo de bus tiene ETA disponible
  bool _hasBusETA(TramoViajeMostrable busTramo) {
    // TODO: Verificar contra datos reales de API
    // Por ahora asumimos que si hay nombreLineaBus, hay posibilidad de ETA
    return busTramo.nombreLineaBus != null && busTramo.nombreLineaBus!.isNotEmpty;
  }

  // ============================================================================
  // RECÁLCULO DINÁMICO DE RUTA WALKING
  // ============================================================================

  /// Iniciar recálculo periódico de ruta walking
  void _startRouteRecalculation() {
    print("[JOURNEY_MANAGER] 🚶‍♂️ Iniciando recálculo dinámico de ruta (cada 5s)");

    _routeRecalculationTimer = Timer.periodic(
      Duration(seconds: 5),
      (_) => _recalculateWalkingRoute(),
    );

    // Cálculo inicial inmediato
    _recalculateWalkingRoute();
  }

  /// Recalcular ruta óptima walking
  Future<void> _recalculateWalkingRoute() async {
    if (_state == null || !_state!.isActive) return;
    if (_state!.lastKnownLocation == null) return;
    if (_state!.currentStep.destination == null) return;

    final from = _state!.lastKnownLocation!;
    final to = _state!.currentStep.destination!;

    print(
      "[JOURNEY_MANAGER] 🔄 Recalculando ruta: ${from.latitud},${from.longitud} → ${to.latitud},${to.longitud}",
    );

    // TODO: Integrar con API real de routing (Google/Mapbox)
    // Por ahora, usar línea recta como fallback
    final optimalRoute = [from, to];

    // Actualizar currentRoute en estado
    final updatedStep = _state!.currentStep.copyWith(
      currentRoute: optimalRoute,
    );
    _state = _state!.copyWith(currentStep: updatedStep);

    // Emitir evento
    onEvent(JourneyEvent(
      JourneyEventType.WALKING_ROUTE_UPDATED,
      data: {
        'route': optimalRoute,
        'from': from,
        'to': to,
      },
    ));

    print("[JOURNEY_MANAGER] ✅ Ruta actualizada (${optimalRoute.length} puntos)");
  }

  /// Detener recálculo de ruta
  void _stopRouteRecalculation() {
    if (_routeRecalculationTimer != null) {
      print("[JOURNEY_MANAGER] 🚶‍♂️ Deteniendo recálculo de ruta");
      _routeRecalculationTimer?.cancel();
      _routeRecalculationTimer = null;
    }
  }
}
