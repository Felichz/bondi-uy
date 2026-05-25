import 'dart:async';
import 'dart:math' as math;
import 'package:bondi_uy/utils/feature_logger.dart';

import '../backend/contrato_ui/app_ui_state.dart';
import '../backend/providers/app_logic_provider.dart';
import '../utils/geometry_utils.dart';
import '../journey/time_scale_manager.dart';

class TripSimulator {
  final AppLogicNotifier notifier;
  final Coordenada? _initialBusPosition;

  Timer? _timer;
  double _speed;

  // Velocidades realistas (m/s)
  static const double _walkingSpeedMps = 1.4; // 5 km/h - velocidad caminata
  static const double _busSpeedMps = 11.0; // 40 km/h - velocidad bus urbano

  // Duraciones calculadas dinámicamente basadas en distancias reales
  double _userWalkToStopSecs = 15.0;
  double _busApproachSecs = 15.0;
  double _rideBusSecs = 15.0;
  double _userWalkToDestSecs = 10.0;

  DateTime? _startTime;
  bool _ridePhaseLogged = false;
  bool _waitPhaseLogged = false;

  // Traces
  List<Coordenada> _userWalkToStop = [];
  List<Coordenada> _busApproach = [];
  List<Coordenada> _busRide = [];
  List<Coordenada> _userWalkToDest = [];

  TripSimulator(
    this.notifier, {
    double speed = 1.0,
    Coordenada? initialBusPosition,
  }) : _speed = speed.clamp(0.25, 100.0),  // Allow up to 100x for testing
       _initialBusPosition = initialBusPosition;

  bool get isRunning => _timer != null;

  void setSpeed(double speed) {
    _speed = speed.clamp(0.25, 100.0);  // Allow up to 100x for testing
  }

  Future<void> start() async {
    if (isRunning) return;
    final active = notifier.devGetActiveTripState();
    if (active == null) {
      return;
    }

    // 🛑 DETENER sondeo de bus real para evitar competencia con simulador
    notifier.devStopBusRealtimePolling();

    // 🔧 ACTIVAR time scale manager con velocidad de simulación
    TimeScaleManager().startSimulation(_speed);

    // 🔧 DESHABILITAR early exit detection durante simulación
    notifier.devDisableEarlyExitDetection();

    // Asegurar geometrías completas en memoria si disponemos de shapeId
    try {
      await loadShapeGeometries();
    } catch (_) {}

    // Construir traces a partir de los tramos
    _buildTraces(active);
    if (_userWalkToStop.isEmpty &&
        _busRide.isEmpty &&
        _userWalkToDest.isEmpty) {
      return;
    }

    try {
      FeatureLogger().log(
        'sim',
        'start',
        data: {
          'walk_pts': _userWalkToStop.length,
          'bus_app_pts': _busApproach.length,
          'ride_pts': _busRide.length,
          'walk_dest_pts': _userWalkToDest.length,
        },
      );
    } catch (_) {}

    // CRÍTICO: Desactivar GPS real para evitar conflictos
    notifier.devActivateExternalLocationFeed();

    _startTime = DateTime.now();
    // Update cada 1 segundo (1Hz) como GPS real
    _timer = Timer.periodic(const Duration(milliseconds: 1000), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _startTime = null;

    // 🔧 DETENER time scale manager
    TimeScaleManager().stopSimulation();

    // Reactivar el sondeo de bus real al detener el simulador
    notifier.devResumeRealBusPolling();

    // 🔧 REHABILITAR early exit detection después de simulación
    notifier.devEnableEarlyExitDetection();
  }

  void _buildTraces(EstadoFaseViajeActivo active) {
    _userWalkToStop = [];
    _busApproach = [];
    _busRide = [];
    _userWalkToDest = [];

    int busIndex = active.tramosDelViaje.indexWhere(
      (t) => t.tipo == TipoTramoViaje.VIAJE_EN_BUS,
    );
    if (busIndex < 0) return;

    // Walking to stop (si existe)
    for (int i = 0; i < busIndex; i++) {
      final tramo = active.tramosDelViaje[i];
      if (tramo.tipo == TipoTramoViaje.CAMINAR &&
          (tramo.geometriaPolilinea?.isNotEmpty ?? false)) {
        _userWalkToStop = List<Coordenada>.from(tramo.geometriaPolilinea!);
        break;
      }
    }

    // Bus tramo
    final busTramo = active.tramosDelViaje[busIndex];
    // Usar posición inicial provista (capturada antes de limpiar estado) o la del estado
    final lastRealBusPos = _initialBusPosition ?? active.posicionActualBusReal;
    // USAR LA GEOMETRÍA DEL TRAMO (ya está recortada al viaje específico)
    // NO usar fullShape porque contiene toda la línea (20+ km)
    List<Coordenada> busGeom = busTramo.geometriaPolilinea ?? [];
    print('[TRIP_SIM] 🚌 Geometría del tramo bus: ${busGeom.length} puntos');
    if (busGeom.length >= 2) {
      // Fallbacks robustos cuando faltan coordenadas de parada
      final stop = busTramo.coordenadasParadaOrigen ?? busGeom.first;
      final dest = busTramo.coordenadasParadaDestino ?? busGeom.last;

      final stopIdx = findClosestPointIndexOnShape(busGeom, stop);
      // Aproximación: construir SIEMPRE una secuencia que vaya HACIA la parada
      const int fallbackWindowPoints = 60; // ventana suficientemente larga
      bool builtFromLast = false;
      if (lastRealBusPos != null) {
        final lastIdx = findClosestPointIndexOnShape(busGeom, lastRealBusPos);
        // Segmento geométrico desde el punto cercano a 'last' hacia la parada
        List<Coordenada> segmentTowardStop;
        if (lastIdx <= stopIdx) {
          segmentTowardStop = busGeom.sublist(lastIdx, stopIdx + 1);
        } else {
          segmentTowardStop = List<Coordenada>.from(
            busGeom.sublist(stopIdx, lastIdx + 1).reversed,
          );
        }
        // Anteponer SIEMPRE la última posición real para evitar saltos iniciales
        if (segmentTowardStop.isEmpty) {
          _busApproach = [lastRealBusPos, busGeom[stopIdx]];
        } else {
          final firstSeg = segmentTowardStop.first;
          final distFirst = calculateHaversineDistance(
            lastRealBusPos.latitud,
            lastRealBusPos.longitud,
            firstSeg.latitud,
            firstSeg.longitud,
          );
          if (distFirst > 3) {
            _busApproach = [lastRealBusPos, ...segmentTowardStop];
          } else {
            _busApproach = segmentTowardStop;
          }
        }
        // Evitar degenerado si resultó de 1 punto
        if (_busApproach.length < 2) {
          _busApproach = [lastRealBusPos, busGeom[stopIdx]];
        }
        builtFromLast = true;
      }
      if (!builtFromLast) {
        if (stopIdx > 0) {
          final startIdx = math.max(0, stopIdx - fallbackWindowPoints);
          _busApproach = busGeom.sublist(startIdx, stopIdx + 1);
        } else {
          final forwardEnd = math.min(
            busGeom.length - 1,
            stopIdx + fallbackWindowPoints,
          );
          _busApproach = List<Coordenada>.from(
            busGeom.sublist(stopIdx, forwardEnd + 1).reversed,
          );
        }
      }
      // Evitar aproximación degenerada (1 punto en la parada)
      if (_busApproach.length < 2) {
        if (stopIdx > 0) {
          final startIdx = math.max(0, stopIdx - fallbackWindowPoints);
          _busApproach = busGeom.sublist(startIdx, stopIdx + 1);
        } else {
          final forwardEnd = math.min(
            busGeom.length - 1,
            stopIdx + fallbackWindowPoints,
          );
          _busApproach = List<Coordenada>.from(
            busGeom.sublist(stopIdx, forwardEnd + 1).reversed,
          );
        }
      }

      // Ride: desde la parada a destino (si hay), sino hasta final
      int endIdx = busGeom.length - 1;
      if (dest != null) {
        final destIdx = findClosestPointIndexOnShape(busGeom, dest);
        endIdx = destIdx;
      }
      if (endIdx <= stopIdx) {
        // Si por geometría endIdx no es después, usar tail del shape
        endIdx = busGeom.length - 1;
      }
      if (endIdx > stopIdx) {
        _busRide = busGeom.sublist(stopIdx, endIdx + 1);
      }
      print('[TRIP_SIM] 📊 _busApproach: ${_busApproach.length} puntos');
      print('[TRIP_SIM] 📊 _busRide: ${_busRide.length} puntos');
    }

    // Walking to destination (si existe luego del bus)
    for (int i = busIndex + 1; i < active.tramosDelViaje.length; i++) {
      final tramo = active.tramosDelViaje[i];
      if (tramo.tipo == TipoTramoViaje.CAMINAR &&
          (tramo.geometriaPolilinea?.isNotEmpty ?? false)) {
        _userWalkToDest = List<Coordenada>.from(tramo.geometriaPolilinea!);
        break;
      }
    }

    // 🎯 Calcular duraciones realistas basadas en distancia y velocidad física
    if (_userWalkToStop.isNotEmpty) {
      final distance = _calculateRouteDistance(_userWalkToStop);
      _userWalkToStopSecs = distance / _walkingSpeedMps;
      print('[TRIP_SIM] 🚶 Walk to stop: ${distance.toStringAsFixed(0)}m @ ${_walkingSpeedMps}m/s = ${_userWalkToStopSecs.toStringAsFixed(1)}s');
    }

    if (_busApproach.isNotEmpty) {
      final distance = _calculateRouteDistance(_busApproach);
      _busApproachSecs = distance / _busSpeedMps;
      print('[TRIP_SIM] 🚌 Bus approach: ${distance.toStringAsFixed(0)}m @ ${_busSpeedMps}m/s = ${_busApproachSecs.toStringAsFixed(1)}s');
    }

    if (_busRide.isNotEmpty) {
      final distance = _calculateRouteDistance(_busRide);
      _rideBusSecs = distance / _busSpeedMps;
      print('[TRIP_SIM] 🚌 Bus ride: ${distance.toStringAsFixed(0)}m @ ${_busSpeedMps}m/s = ${_rideBusSecs.toStringAsFixed(1)}s');
    }

    if (_userWalkToDest.isNotEmpty) {
      final distance = _calculateRouteDistance(_userWalkToDest);
      _userWalkToDestSecs = distance / _walkingSpeedMps;
      print('[TRIP_SIM] 🚶 Walk to dest: ${distance.toStringAsFixed(0)}m @ ${_walkingSpeedMps}m/s = ${_userWalkToDestSecs.toStringAsFixed(1)}s');
    }
  }

  void _tick() {
    if (_startTime == null) return;
    final now = DateTime.now();
    final elapsed =
        now.difference(_startTime!).inMilliseconds / 1000.0; // segundos reales
    final speed = _speed;

    // Duraciones de cada fase (secuenciales, sin superposición)
    // Duraciones ya calculadas con velocidades físicas realistas
    final walkToStopDuration =
        _userWalkToStop.isEmpty ? 0.0 : (_userWalkToStopSecs / speed);
    final busApproachDuration = _busApproach.isEmpty
        ? 0.0
        : (_busApproachSecs / speed);
    final rideBusDuration = _busRide.isEmpty ? 0.0 : (_rideBusSecs / speed);
    final walkToDestDuration =
        _userWalkToDest.isEmpty ? 0.0 : (_userWalkToDestSecs / speed);

    // Puntos de transición entre fases (acumulativos)
    final walkToStopEnd = walkToStopDuration;
    final busApproachEnd = walkToStopEnd + busApproachDuration;
    final rideBusEnd = busApproachEnd + rideBusDuration;
    final walkToDestEnd = rideBusEnd + walkToDestDuration;

    // FASE 1: Usuario caminando a parada [0, walkToStopEnd]
    if (elapsed < walkToStopEnd && _userWalkToStop.isNotEmpty) {
      print('[TRIP_SIM] 🚶 FASE 1: Usuario caminando a parada (${elapsed.toStringAsFixed(1)}s / ${walkToStopEnd.toStringAsFixed(1)}s)');

      // 🔧 Bus approach empieza en paralelo - ACTUALIZAR BUS PRIMERO
      if (_busApproach.isNotEmpty) {
        // Durante walk, el bus ya está en movimiento hacia la parada
        // Progreso del bus considera toda la duración de approach (walk + extra)
        final totalBusApproachTime = walkToStopDuration + busApproachDuration;
        final pBus = (elapsed / totalBusApproachTime).clamp(0.0, 1.0);
        final busPos = _interpolatePosition(_busApproach, pBus);
        final remaining = totalBusApproachTime - elapsed;
        final etaMinutes = math.max(1, (remaining / 60.0).ceil());
        _pushBusRealtime(busPos, etaMinutes);
      }

      // Luego actualizar usuario
      final p = (elapsed / walkToStopDuration).clamp(0.0, 1.0);
      final userPos = _interpolatePosition(_userWalkToStop, p);
      notifier.devPushMockUserLocation(userPos);

      if (!_waitPhaseLogged && p >= 0.99) {
        _waitPhaseLogged = true;
        try {
          FeatureLogger().log('sim', 'wait_phase_start');
        } catch (_) {}
      }
      return;
    }

    // FASE 2: Usuario esperando en parada, bus terminando aproximación
    // [walkToStopEnd, busApproachEnd]
    if (elapsed < busApproachEnd && _busApproach.isNotEmpty) {
      print('[TRIP_SIM] ⏳ FASE 2: Usuario esperando en parada (${elapsed.toStringAsFixed(1)}s / ${busApproachEnd.toStringAsFixed(1)}s)');

      // 🔧 Bus completando aproximación - ACTUALIZAR BUS PRIMERO
      final totalBusApproachTime = walkToStopDuration + busApproachDuration;
      final pBus = (elapsed / totalBusApproachTime).clamp(0.0, 1.0);
      final busPos = _interpolatePosition(_busApproach, pBus);
      final remaining = totalBusApproachTime - elapsed;
      final etaMinutes = math.max(0, (remaining / 60.0).ceil());
      _pushBusRealtime(busPos, etaMinutes);

      // Luego usuario quieto en la parada
      if (_userWalkToStop.isNotEmpty) {
        notifier.devPushMockUserLocation(_userWalkToStop.last);
      }
      return;
    }

    // FASE 3: Usuario y bus en ride [busApproachEnd, rideBusEnd]
    if (elapsed < rideBusEnd && _busRide.isNotEmpty) {
      print('[TRIP_SIM] 🚌 FASE 3: Ride en bus (${elapsed.toStringAsFixed(1)}s / ${rideBusEnd.toStringAsFixed(1)}s)');
      final rideElapsed = elapsed - busApproachEnd;
      final pRide = (rideElapsed / rideBusDuration).clamp(0.0, 1.0);
      final ridePos = _interpolatePosition(_busRide, pRide);

      // 🔧 CRÍTICO: Actualizar BUS PRIMERO, luego usuario
      // Esto asegura que cuando el usuario se actualice y JourneyManager
      // calcule distancia usuario-bus, el bus ya esté en la posición correcta
      _pushBusRealtime(ridePos, 1);
      notifier.devPushMockUserLocation(ridePos);

      if (!_ridePhaseLogged) {
        _ridePhaseLogged = true;
        try {
          FeatureLogger().log('sim', 'ride_phase_start');
        } catch (_) {}
      }
      return;
    }

    // FASE 4: Usuario caminando a destino [rideBusEnd, walkToDestEnd]
    if (elapsed < walkToDestEnd && _userWalkToDest.isNotEmpty) {
      print('[TRIP_SIM] 🚶 FASE 4: Usuario caminando a destino (${elapsed.toStringAsFixed(1)}s / ${walkToDestEnd.toStringAsFixed(1)}s)');
      final walkDestElapsed = elapsed - rideBusEnd;
      final pWalkDest = (walkDestElapsed / walkToDestDuration).clamp(0.0, 1.0);
      final userPos = _interpolatePosition(_userWalkToDest, pWalkDest);
      notifier.devPushMockUserLocation(userPos);

      // Bus se queda en última posición del ride (o desaparece)
      if (_busRide.isNotEmpty) {
        _pushBusRealtime(_busRide.last, 0);
      }
      return;
    }

    // Simulación completada
    if (elapsed >= walkToDestEnd) {
      stop();
    }
  }

  void _pushBusRealtime(Coordenada pos, int etaMinutes) {
    notifier.devPushRealtimeBusPosition(pos, etaMinutes);
  }

  /// Calcula la distancia total de una ruta en metros
  double _calculateRouteDistance(List<Coordenada> route) {
    if (route.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 0; i < route.length - 1; i++) {
      totalDistance += calculateHaversineDistance(
        route[i].latitud,
        route[i].longitud,
        route[i + 1].latitud,
        route[i + 1].longitud,
      );
    }
    return totalDistance;
  }

  /// Interpola suavemente una posición en la ruta basándose en el progreso
  ///
  /// En vez de saltar entre puntos discretos, calcula una posición intermedia
  /// interpolando linealmente entre dos puntos adyacentes.
  ///
  /// [route] - Lista de coordenadas de la ruta
  /// [progress] - Progreso de 0.0 a 1.0
  ///
  /// Returns: Coordenada interpolada
  Coordenada _interpolatePosition(List<Coordenada> route, double progress) {
    if (route.isEmpty) {
      return Coordenada(latitud: 0, longitud: 0);
    }
    if (route.length == 1 || progress <= 0.0) {
      return route.first;
    }
    if (progress >= 1.0) {
      return route.last;
    }

    // Calcular índice exacto con decimales
    final exactIndex = progress * (route.length - 1);
    final index = exactIndex.floor();
    final nextIndex = (index + 1).clamp(0, route.length - 1);

    // Progreso entre los dos puntos (0.0 a 1.0)
    final t = exactIndex - index;

    // Interpolación lineal entre punto actual y siguiente
    final p1 = route[index];
    final p2 = route[nextIndex];

    final lat = p1.latitud + (p2.latitud - p1.latitud) * t;
    final lng = p1.longitud + (p2.longitud - p1.longitud) * t;

    return Coordenada(latitud: lat, longitud: lng);
  }
}
