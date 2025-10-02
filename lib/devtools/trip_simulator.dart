import 'dart:async';
import 'dart:math' as math;
import 'package:bondi_uy/utils/feature_logger.dart';

import '../backend/contrato_ui/app_ui_state.dart';
import '../backend/providers/app_logic_provider.dart';
import '../utils/geometry_utils.dart';

class TripSimulator {
  final AppLogicNotifier notifier;
  final Coordenada? _initialBusPosition;

  Timer? _timer;
  double _speed;

  // Timeline (segundos, base sin speed). Se ajustan por _speed al vuelo
  static const double _userWalkToStopSecs = 15.0;
  static const double _busApproachExtraSecs = 15.0; // después del usuario
  static const double _rideBusSecs = 15.0;
  static const double _userWalkToDestSecs = 10.0;

  DateTime? _startTime;
  bool _ridePhaseLogged = false;
  bool _waitPhaseLogged = false;

  // Traces
  List<Coordenada> _userWalkToStop = [];
  List<Coordenada> _busApproach = [];
  List<Coordenada> _busRide = [];
  List<Coordenada> _userWalkToDest = [];
  int _lastApproachIdx = 0; // asegurar monotonicidad

  TripSimulator(
    this.notifier, {
    double speed = 1.0,
    Coordenada? initialBusPosition,
  }) : _speed = speed.clamp(0.25, 3.0),
       _initialBusPosition = initialBusPosition;

  bool get isRunning => _timer != null;

  void setSpeed(double speed) {
    _speed = speed.clamp(0.25, 3.0);
  }

  Future<void> start() async {
    if (isRunning) return;
    final active = notifier.devGetActiveTripState();
    if (active == null) {
      return;
    }

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

    _startTime = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _startTime = null;
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
    // Preferir geometría completa si hay shapeId
    List<Coordenada> busGeom = [];
    final fullByShape = getFullShapeGeometry(busTramo.shapeId);
    if (fullByShape != null && fullByShape.length >= 2) {
      busGeom = fullByShape;
    } else {
      busGeom = busTramo.geometriaPolilinea ?? [];
    }
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
  }

  void _tick() {
    if (_startTime == null) return;
    final now = DateTime.now();
    final elapsed =
        now.difference(_startTime!).inMilliseconds / 1000.0; // segundos reales
    final speed = _speed;

    // Timelines relativos al tiempo 0
    final walkToStopT =
        _userWalkToStop.isEmpty ? 0.0 : (_userWalkToStopSecs / speed);
    final busApproachT = (_userWalkToStopSecs + _busApproachExtraSecs) / speed;
    final rideBusT = _busRide.isEmpty ? 0.0 : (_rideBusSecs / speed);
    final walkToDestT =
        _userWalkToDest.isEmpty ? 0.0 : (_userWalkToDestSecs / speed);

    // 1) Usuario caminando a parada [0, walkToStopT]
    if (_userWalkToStop.isNotEmpty) {
      final p = (elapsed / walkToStopT).clamp(0.0, 1.0);
      final idx = ((p * (_userWalkToStop.length - 1))).round();
      final userPos = _userWalkToStop[idx];
      notifier.devPushMockUserLocation(userPos);
      if (!_waitPhaseLogged && p >= 1.0) {
        _waitPhaseLogged = true;
        try {
          FeatureLogger().log('sim', 'wait_phase_start');
        } catch (_) {}
      }
    }

    // 2) Bus aproximándose a la parada [0, busApproachT]
    if (_busApproach.isNotEmpty) {
      final pBus = (elapsed / busApproachT).clamp(0.0, 1.0);
      // Monotonía: usar floor y clamp para evitar retrocesos por redondeo
      var idxBus = (pBus * (_busApproach.length - 1)).floor();
      if (idxBus < 0) idxBus = 0;
      if (idxBus > _lastApproachIdx)
        idxBus = idxBus;
      else
        idxBus = _lastApproachIdx;
      if (idxBus >= _busApproach.length) idxBus = _busApproach.length - 1;
      _lastApproachIdx = idxBus;
      final busPos = _busApproach[idxBus];
      int etaMinutes = 0;
      if (elapsed < busApproachT) {
        final remaining = busApproachT - elapsed;
        etaMinutes = math.max(1, (remaining / 60.0).ceil());
      }
      // Reducir frecuencia de pushes: solo en cambios de índice o cada ~400ms
      _pushBusRealtime(busPos, etaMinutes);
    }

    // 3) Usuario y bus en bus (ride) después de busApproach
    final afterBusApproach = elapsed - busApproachT;
    if (afterBusApproach >= 0 && _busRide.isNotEmpty) {
      final pRide = (afterBusApproach / rideBusT).clamp(0.0, 1.0);
      final idxRide = ((pRide * (_busRide.length - 1))).round();
      final ridePos = _busRide[idxRide];
      // usuario “pegado” al bus
      notifier.devPushMockUserLocation(ridePos);
      if (!_ridePhaseLogged) {
        _ridePhaseLogged = true;
        try {
          FeatureLogger().log('sim', 'ride_phase_start');
        } catch (_) {}
      }
      // ETA durante ride no es relevante; mantener 0 o 1 para que el overlay no lo esconda
      _pushBusRealtime(ridePos, 1);
    }

    // 4) Usuario caminando a destino después de bus (ride)
    final afterRide = elapsed - (busApproachT + rideBusT);
    if (afterRide >= 0 && _userWalkToDest.isNotEmpty) {
      final pWalkDest = (afterRide / walkToDestT).clamp(0.0, 1.0);
      final idxWalkDest = ((pWalkDest * (_userWalkToDest.length - 1))).round();
      final userPos2 = _userWalkToDest[idxWalkDest];
      notifier.devPushMockUserLocation(userPos2);
    }

    // Finalizar cuando completamos todas las fases
    final totalSimTime = busApproachT + rideBusT + walkToDestT;
    if (elapsed >= totalSimTime + 0.2) {
      stop();
    }
  }

  void _pushBusRealtime(Coordenada pos, int etaMinutes) {
    notifier.devPushRealtimeBusPosition(pos, etaMinutes);
  }
}
