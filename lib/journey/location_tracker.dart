import '../backend/contrato_ui/app_ui_state.dart';
import '../utils/geometry_utils.dart';
import 'package:bondi_uy/utils/feature_logger.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'time_scale_manager.dart';

// NUEVO: Clase para almacenar lecturas de ubicación con timestamp
class LocationReading {
  final Coordenada location;
  final DateTime timestamp;

  LocationReading(this.location, this.timestamp);
}

class LocationTracker {
  Timer? _trackingTimer;
  StreamSubscription<Position>?
  _positionSubscription; // NUEVO: stream de posiciones
  final Function(Coordenada) onLocationUpdate;
  final Function(String) onArrivalDetected;
  final bool isTestMode;

  Coordenada? _lastKnownLocation;
  List<GeofenceZone> _activeGeofences = [];

  // NUEVO: Para cálculo de velocidad
  List<LocationReading> _locationHistory = [];
  double _currentSpeed = 0.0; // m/s

  static const int UPDATE_INTERVAL_MS = 5000;
  static const int STREAM_MIN_INTERVAL_MS =
      1000; // Min intervalo entre notificaciones al app
  static const double ARRIVAL_THRESHOLD_METERS = 50.0;
  static const int MAX_LOCATION_HISTORY = 10; // Mantener últimas 10 lecturas

  DateTime? _lastStreamDispatch; // Controlar throttling de stream
  bool _streamActive = false;
  // NUEVO: modo de alimentación externa (simulación)
  bool _externalFeedMode = false;

  LocationTracker({
    required this.onLocationUpdate,
    required this.onArrivalDetected,
    this.isTestMode = false,
  });

  // NUEVO: Getter para velocidad actual
  double get currentSpeed => _currentSpeed;

  // NUEVO: Método para calcular velocidad basada en historial de ubicaciones
  void _calculateSpeed(Coordenada newLocation) {
    final timeManager = TimeScaleManager();
    final now = timeManager.now; // Usar tiempo ajustado por simulación
    final newReading = LocationReading(newLocation, now);

    // Agregar nueva lectura
    _locationHistory.add(newReading);

    // Mantener solo las últimas lecturas
    if (_locationHistory.length > MAX_LOCATION_HISTORY) {
      _locationHistory.removeAt(0);
    }

    // Necesitamos al menos 2 lecturas para calcular velocidad
    if (_locationHistory.length < 2) {
      _currentSpeed = 0.0;
      return;
    }

    // Calcular velocidad promedio usando las últimas 3 lecturas (si están disponibles)
    final recentReadings =
        _locationHistory.length >= 3
            ? _locationHistory.sublist(_locationHistory.length - 3)
            : _locationHistory;

    double totalDistance = 0.0;
    double totalTime = 0.0;

    for (int i = 1; i < recentReadings.length; i++) {
      final prev = recentReadings[i - 1];
      final curr = recentReadings[i];

      final distance = calculateHaversineDistance(
        prev.location.latitud,
        prev.location.longitud,
        curr.location.latitud,
        curr.location.longitud,
      );

      // ⚠️ NO usar TimeScaleManager para velocidad - queremos velocidad física real
      // El TimeScaleManager solo debe ajustar thresholds/timers, no métricas físicas
      final timeDiff =
          curr.timestamp.difference(prev.timestamp).inMilliseconds / 1000.0; // segundos REALES

      if (timeDiff > 0) {
        totalDistance += distance;
        totalTime += timeDiff;
      }
    }

    // Calcular velocidad promedio en m/s
    // SIEMPRE usamos tiempo REAL para que la velocidad sea física y realista
    // Ejemplo: 110m en 1s real = 110 m/s (no 11 m/s)
    if (totalTime > 0) {
      _currentSpeed = totalDistance / totalTime;
    } else {
      _currentSpeed = 0.0;
    }

    final simInfo = timeManager.isSimulating ? " [SIM ${timeManager.timeScale}x]" : "";
    print(
      "[LOCATION_TRACKER] 🏃‍♂️ Velocidad calculada: ${_currentSpeed.toStringAsFixed(2)} m/s (${(_currentSpeed * 3.6).toStringAsFixed(1)} km/h)$simInfo",
    );
  }

  Future<void> startTracking() async {
    print("[LOCATION_TRACKER] 📍 === INICIANDO LOCATION TRACKER ====");
    print(
      "[LOCATION_TRACKER] 📍 Intervalo de actualización: ${UPDATE_INTERVAL_MS}ms",
    );
    print(
      "[LOCATION_TRACKER] 📍 Umbral de llegada: ${ARRIVAL_THRESHOLD_METERS}m",
    );

    if (!isTestMode && !_externalFeedMode) {
      // Verificar permisos de ubicación solo en modo real
      print("[LOCATION_TRACKER] 🔐 Verificando permisos de ubicación...");
      LocationPermission permission = await Geolocator.checkPermission();
      print("[LOCATION_TRACKER] 🔐 Permiso actual: $permission");

      if (permission == LocationPermission.denied) {
        print("[LOCATION_TRACKER] 🔐 Solicitando permisos...");
        permission = await Geolocator.requestPermission();
        print("[LOCATION_TRACKER] 🔐 Respuesta: $permission");
        if (permission == LocationPermission.denied) {
          print("[LOCATION_TRACKER] ❌ Permisos denegados");
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print("[LOCATION_TRACKER] ❌ Permisos denegados permanentemente");
        throw Exception('Location permissions are permanently denied');
      }
      print("[LOCATION_TRACKER] ✅ Permisos concedidos");
    } else {
      print(
        "[LOCATION_TRACKER] 🧪 Modo test activado - saltando verificación de permisos",
      );
    }

    print("[LOCATION_TRACKER] ⏰ Configurando timer de actualización...");
    _trackingTimer = Timer.periodic(
      Duration(milliseconds: UPDATE_INTERVAL_MS),
      (_) async => await _performLocationUpdate(),
    );
    print(
      "[LOCATION_TRACKER] ✅ Timer configurado - actualizando cada ${UPDATE_INTERVAL_MS}ms",
    );

    // Intentar iniciar stream de posición para mayor responsividad
    if (!isTestMode && !_externalFeedMode) {
      await _startPositionStream();
    } else {
      print("[LOCATION_TRACKER] 🧪 Saltando position stream en modo test");
    }
    print("[LOCATION_TRACKER] ✅ === LOCATION TRACKER INICIADO ====");
  }

  Future<void> stopTracking() async {
    _trackingTimer?.cancel();
    _trackingTimer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _streamActive = false;
    _activeGeofences.clear();
  }

  Future<void> _startPositionStream() async {
    print("[LOCATION_TRACKER] 📡 Intentando iniciar PositionStream...");
    try {
      final locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 3, // ~3m
      );
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _onStreamPosition,
        onError: (e) {
          print("[LOCATION_TRACKER] ⚠️ Error en stream: $e");
        },
      );
      _streamActive = true;
      print("[LOCATION_TRACKER] ✅ PositionStream iniciado");
    } catch (e) {
      print("[LOCATION_TRACKER] ❌ No se pudo iniciar stream: $e");
    }
  }

  void _onStreamPosition(Position pos) {
    final now = DateTime.now();
    if (_lastStreamDispatch != null &&
        now.difference(_lastStreamDispatch!).inMilliseconds <
            STREAM_MIN_INTERVAL_MS) {
      // Throttle
      return;
    }
    _lastStreamDispatch = now;

    final newLoc = Coordenada(latitud: pos.latitude, longitud: pos.longitude);
    _lastKnownLocation = newLoc;
    _calculateSpeed(newLoc);
    onLocationUpdate(newLoc);
    _checkArrivals(newLoc); // Permite detección más rápida de llegada
    // Feature logs
    try {
      FeatureLogger().log(
        'geofence',
        'stream_position',
        data: {
          'lat': newLoc.latitud,
          'lon': newLoc.longitud,
          'spd': _currentSpeed.toStringAsFixed(2),
        },
      );
    } catch (_) {}
  }

  Future<void> _performLocationUpdate() async {
    print("[LOCATION_TRACKER] 📡 === ACTUALIZACIÓN DE UBICACIÓN ====");
    print(
      "[LOCATION_TRACKER] ⏰ INICIO de ciclo de 5 segundos - ${DateTime.now()}",
    );
    try {
      if (_externalFeedMode) {
        print(
          "[LOCATION_TRACKER] 🧪 ExternalFeedMode activo - no se consulta GPS",
        );
        return; // Inyección externa manejará onLocationUpdate + geofences
      }
      print("[LOCATION_TRACKER] 📡 Solicitando ubicación GPS...");
      final newLocation = await _getCurrentGPSLocation();
      if (newLocation != null) {
        print(
          "[LOCATION_TRACKER] 📍 GPS obtenido: ${newLocation.latitud}, ${newLocation.longitud}",
        );

        if (_lastKnownLocation != null) {
          final distanceMoved = calculateHaversineDistance(
            _lastKnownLocation!.latitud,
            _lastKnownLocation!.longitud,
            newLocation.latitud,
            newLocation.longitud,
          );
          print(
            "[LOCATION_TRACKER] 📍 Distancia desde última ubicación: ${distanceMoved.toStringAsFixed(1)}m",
          );
        }

        _lastKnownLocation = newLocation;

        // NUEVO: Calcular velocidad antes de notificar
        _calculateSpeed(newLocation);

        print("[LOCATION_TRACKER] 📢 Notificando nueva ubicación...");
        onLocationUpdate(newLocation);
        print("[LOCATION_TRACKER] 🎯 Verificando llegadas...");
        _checkArrivals(newLocation);
        try {
          FeatureLogger().log(
            'geofence',
            'timer_position',
            data: {
              'lat': newLocation.latitud,
              'lon': newLocation.longitud,
              'spd': _currentSpeed.toStringAsFixed(2),
            },
          );
        } catch (_) {}
        print(
          "[LOCATION_TRACKER] ⏰ FIN de ciclo de 5 segundos - ${DateTime.now()}",
        );
        print("[LOCATION_TRACKER] ✅ === ACTUALIZACIÓN COMPLETADA ====");
      } else {
        print("[LOCATION_TRACKER] ⚠️ No se pudo obtener ubicación GPS");
      }
    } catch (e) {
      print("[LOCATION_TRACKER] ❌ === ERROR EN ACTUALIZACIÓN ====");
      print("[LOCATION_TRACKER] ❌ Error: $e");
      print("[LOCATION_TRACKER] ❌ Tipo: ${e.runtimeType}");
    }
  }

  // NUEVO: activar modo de feed externo para simulación
  void enterExternalFeedMode() {
    print("[LOCATION_TRACKER] 🧪 Activando ExternalFeedMode (simulación)");
    _externalFeedMode = true;
    // Cancelar stream si estaba activo para evitar que sobrescriba la inyección externa
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _streamActive = false;
  }

  // NUEVO: inyectar ubicación simulada manteniendo pipeline real
  void injectLocationUpdate(Coordenada location) {
    print(
      "[LOCATION_TRACKER] 🧪 InjectLocationUpdate: ${location.latitud}, ${location.longitud}",
    );
    _lastKnownLocation = location;
    _calculateSpeed(location);
    onLocationUpdate(location);
    _checkArrivals(location);
  }

  Future<Coordenada?> _getCurrentGPSLocation() async {
    print("[LOCATION_TRACKER] 📡 Obteniendo posición GPS...");

    if (isTestMode) {
      // En modo test, devolver ubicación simulada
      print("[LOCATION_TRACKER] 🧪 Modo test - usando ubicación simulada");
      _lastKnownLocation =
          _lastKnownLocation ?? Coordenada(latitud: -34.906, longitud: -56.186);
      return _lastKnownLocation;
    }

    try {
      // Primero intentar con getLastKnownPosition que es más rápido en emuladores
      try {
        print(
          "[LOCATION_TRACKER] 📡 Intentando obtener última ubicación conocida...",
        );
        final lastPosition = await Geolocator.getLastKnownPosition();

        if (lastPosition != null) {
          // Verificar si la ubicación es reciente (menos de 30 segundos)
          final now = DateTime.now();
          final locationAge = now.difference(lastPosition.timestamp!);
          print(
            "[LOCATION_TRACKER] 📡 Última ubicación timestamp: ${lastPosition.timestamp}",
          );
          print(
            "[LOCATION_TRACKER] 📡 Edad de la ubicación: ${locationAge.inSeconds}s",
          );

          if (locationAge.inSeconds < 30) {
            print("[LOCATION_TRACKER] ✅ Última ubicación reciente (<30s):");
            print("[LOCATION_TRACKER] ✅   Latitud: ${lastPosition.latitude}");
            print("[LOCATION_TRACKER] ✅   Longitud: ${lastPosition.longitude}");
            print(
              "[LOCATION_TRACKER] ✅   Precisión: ${lastPosition.accuracy}m",
            );
            print("[LOCATION_TRACKER] ✅   Velocidad: ${lastPosition.speed}m/s");
            print(
              "[LOCATION_TRACKER] ✅   Timestamp: ${lastPosition.timestamp}",
            );

            return Coordenada(
              latitud: lastPosition.latitude,
              longitud: lastPosition.longitude,
            );
          } else {
            print(
              "[LOCATION_TRACKER] ⚠️ Última ubicación muy antigua (${locationAge.inSeconds}s), obteniendo ubicación fresca...",
            );
          }
        }
      } catch (e) {
        print(
          "[LOCATION_TRACKER] ⚠️ No se pudo obtener última ubicación conocida: $e",
        );
      }

      // Si no hay última ubicación, intentar posición actual con configuración para emulador
      print("[LOCATION_TRACKER] 📡 Obteniendo posición actual...");
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy:
            LocationAccuracy
                .medium, // Cambiado de high a medium para emuladores
        timeLimit: Duration(seconds: 10), // Aumentado timeout para emuladores
        forceAndroidLocationManager: true, // Forzar LocationManager en Android
      );

      print("[LOCATION_TRACKER] ✅ GPS exitoso:");
      print("[LOCATION_TRACKER] ✅   Latitud: ${position.latitude}");
      print("[LOCATION_TRACKER] ✅   Longitud: ${position.longitude}");
      print("[LOCATION_TRACKER] ✅   Precisión: ${position.accuracy}m");
      print("[LOCATION_TRACKER] ✅   Velocidad: ${position.speed}m/s");
      print("[LOCATION_TRACKER] ✅   Timestamp: ${position.timestamp}");

      return Coordenada(
        latitud: position.latitude,
        longitud: position.longitude,
      );
    } catch (e) {
      print("[LOCATION_TRACKER] ❌ Error obteniendo GPS: $e");
      print("[LOCATION_TRACKER] ❌ Tipo de error: ${e.runtimeType}");
      return null;
    }
  }

  void _checkArrivals(Coordenada userLocation) {
    print("[LOCATION_TRACKER] 🎯 === VERIFICANDO LLEGADAS ====");
    print(
      "[LOCATION_TRACKER] 🎯 Geofences activos: ${_activeGeofences.length}",
    );
    print(
      "[LOCATION_TRACKER] 🎯 Umbral de llegada: ${ARRIVAL_THRESHOLD_METERS}m",
    );

    for (int i = 0; i < _activeGeofences.length; i++) {
      final geofence = _activeGeofences[i];
      final distance = calculateHaversineDistance(
        userLocation.latitud,
        userLocation.longitud,
        geofence.center.latitud,
        geofence.center.longitud,
      );
      print(
        "[LOCATION_TRACKER] 🎯 Geofence $i (${geofence.id}): ${distance.toStringAsFixed(1)}m",
      );

      if (distance <= ARRIVAL_THRESHOLD_METERS) {
        print("[LOCATION_TRACKER] �� === LLEGADA DETECTADA ====");
        print("[LOCATION_TRACKER] 🏁 Geofence: ${geofence.id}");
        print(
          "[LOCATION_TRACKER] 🏁 Distancia: ${distance.toStringAsFixed(1)}m",
        );
        print("[LOCATION_TRACKER] 🏁 Notificando llegada...");
        try {
          FeatureLogger().log(
            'geofence',
            'arrival',
            data: {'id': geofence.id, 'dist_m': distance.toStringAsFixed(1)},
          );
        } catch (_) {}
        onArrivalDetected(geofence.id);
        print("[LOCATION_TRACKER] ✅ Llegada notificada");
      }
    }

    if (_activeGeofences.isEmpty) {
      print("[LOCATION_TRACKER] ⚠️ No hay geofences configurados");
    }
  }

  void setupGeofencesForStep(List<Coordenada> destinations, List<String> ids) {
    print("[LOCATION_TRACKER] 🎯 === CONFIGURANDO GEOFENCES ====");
    print("[LOCATION_TRACKER] 🎯 Destinos: ${destinations.length}");
    print("[LOCATION_TRACKER] 🎯 IDs: ${ids.length}");

    _activeGeofences.clear();
    print("[LOCATION_TRACKER] 🎯 Geofences anteriores limpiados");

    final minLength =
        destinations.length < ids.length ? destinations.length : ids.length;
    for (int i = 0; i < minLength; i++) {
      final geofence = GeofenceZone(
        id: ids[i],
        center: destinations[i],
        radius: ARRIVAL_THRESHOLD_METERS,
      );
      _activeGeofences.add(geofence);
      print("[LOCATION_TRACKER] 🎯 Geofence $i configurado:");
      print("[LOCATION_TRACKER] 🎯   ID: ${ids[i]}");
      print(
        "[LOCATION_TRACKER] 🎯   Centro: ${destinations[i].latitud}, ${destinations[i].longitud}",
      );
      print("[LOCATION_TRACKER] 🎯   Radio: ${ARRIVAL_THRESHOLD_METERS}m");
    }

    print(
      "[LOCATION_TRACKER] ✅ ${_activeGeofences.length} geofences configurados",
    );
  }

  Coordenada? get lastKnownLocation => _lastKnownLocation;
  bool get isTracking => _trackingTimer != null;
  List<GeofenceZone> get activeGeofences => List.unmodifiable(_activeGeofences);

  void dispose() {
    print("[LOCATION_TRACKER] 🛑 === DISPOSING LOCATION TRACKER ====");
    print("[LOCATION_TRACKER] 🛑 Timer activo: ${_trackingTimer != null}");
    print(
      "[LOCATION_TRACKER] 🛑 Geofences activos: ${_activeGeofences.length}",
    );
    stopTracking();
    print("[LOCATION_TRACKER] ✅ === LOCATION TRACKER DISPOSED ====");
  }

  // Método para tests: simular actualización de ubicación
  void simulateLocationUpdate(Coordenada location) {
    if (isTestMode) {
      print(
        "[LOCATION_TRACKER] 🧪 Simulando actualización de ubicación: ${location.latitud}, ${location.longitud}",
      );
      _lastKnownLocation = location;
      onLocationUpdate(location);
      _checkArrivals(location);
    }
  }
}

class GeofenceZone {
  final String id;
  final Coordenada center;
  final double radius;

  GeofenceZone({required this.id, required this.center, required this.radius});

  @override
  String toString() {
    return 'GeofenceZone(id: $id, center: $center, radius: $radius)';
  }
}
