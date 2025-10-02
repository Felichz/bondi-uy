import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:math';
import 'package:bondi_uy/utils/geometry_utils.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import 'map_manager.dart';
import 'package:bondi_uy/utils/feature_logger.dart';
import 'dart:math' show min, max; // para cálculo de bounds

/// Módulo especializado en controlar la cámara y zoom del mapa
class MapCameraController {
  final MapboxMap? mapboxMap;
  final MapManager mapManager;

  // NUEVO: Auto-follow y control de animaciones
  bool _autoFollowEnabled = true;
  DateTime _lastUserCameraInteraction = DateTime.now();
  DateTime _lastAnimationTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _initialCameraDone = false; // NUEVO: asegurar primer fly se ejecute
  bool _cooldownOverrideOnce = false; // Permite que el siguiente zoom ignore cooldown
  bool _ignoreMinorChangeOnce = false; // Permite ignorar chequeo de bounds una vez
  MbxEdgeInsets? _lastPadding; // Recordar último padding para refresco
  bool _refreshScheduled = false; // Evita múltiples microtasks
  bool _isAnimating = false; // Flag para distinguir cambios de cámara por animación
  DateTime _lastAnimationEnd = DateTime.fromMillisecondsSinceEpoch(0); // Marca fin última animación
  static const Duration _autoResumeAfter = Duration(seconds: 10);
  // Nuevo: ventana más corta para reanudar (heurística para que el usuario no espere tanto)
  static const Duration _autoResumeAfterFast = Duration(seconds: 6);
  int _resumeGeneration = 0; // Token para invalidar timers viejos
  static const Duration _minAnimationSpacing = Duration(seconds: 3);
  static const int _maxBusEtaMinutesForWalkContext = 5; // Solo mostrar bus en tramo CAMINAR si llega <=5 min
  // Umbrales de cambio para evitar animaciones innecesarias
  static const double _minCenterShiftMeters = 20.0;
  static const double _minBoundsExpansionMeters = 30.0;
  // Track último bounds usado
  List<Coordenada>? _lastBoundsCoords;
  // Nuevo: recordar última petición (aunque no haya animado) para refresco tras pausa
  List<Coordenada>? _lastRequestedCoords;
  MbxEdgeInsets? _lastRequestedPadding;

  MapCameraController(this.mapboxMap, this.mapManager);

  /// Hacer zoom a preview de ruta completa
  Future<void> zoomToRoutePreview(OpcionDeRutaMostrable route) async {
    if (mapboxMap == null) return;

  FeatureLogger().camera('zoom_preview:start', data: {'routeId': route.idOpcion});

    // Recolectar todas las coordenadas de la ruta
    List<Coordenada> allCoordinates = [];

    for (final tramo in route.tramosParaPreview) {
      if (tramo.geometriaPolilinea != null &&
          tramo.geometriaPolilinea!.isNotEmpty) {
        allCoordinates.addAll(tramo.geometriaPolilinea!);
      } else if (tramo.posicionPunto != null) {
        allCoordinates.add(tramo.posicionPunto!);
      }
    }

    // Agregar coordenadas del bus en tiempo real si existe
    _addBusCoordinatesToZoom(route, allCoordinates);

    if (allCoordinates.isNotEmpty) {
      await _zoomToCoordinates(allCoordinates, _getPreviewPadding());
    }
  }

  // Reset externo de bounds para forzar próximo _shouldAnimate a no filtrar por minor change
  void resetLastBounds() {
    _lastBoundsCoords = null;
    FeatureLogger().camera('bounds:reset_external');
  }

  /// Hacer zoom a viaje activo
  Future<void> zoomToActiveTrip(List<TramoViajeMostrable> tramos) async {
    if (mapboxMap == null || tramos.isEmpty) return;

  FeatureLogger().camera('zoom_active_trip:start', data: {'tramos': tramos.length});

    // Recolectar todas las coordenadas del viaje
    List<Coordenada> allCoordinates = [];

    for (final tramo in tramos) {
      if (tramo.geometriaPolilinea != null &&
          tramo.geometriaPolilinea!.isNotEmpty) {
        allCoordinates.addAll(tramo.geometriaPolilinea!);
      } else if (tramo.posicionPunto != null) {
        allCoordinates.add(tramo.posicionPunto!);
      }
    }

    // Añadir ubicación actual del usuario si disponible para contextualizar
    final userPos = mapManager.getCurrentUserLocation();
    if (userPos != null) {
      allCoordinates.add(userPos);
      FeatureLogger().camera('zoom_active_trip:add_user', data: {'lat': userPos.latitud, 'lon': userPos.longitud});
    }

    if (allCoordinates.isNotEmpty) {
  // Señal: el siguiente zoom (p.ej. al leg actual) puede sobre-escribir sin esperar cooldown
  _cooldownOverrideOnce = true;
      await _zoomToCoordinates(allCoordinates, _getActiveTripPadding());
    }
  }

  /// Hacer zoom a tramo actual del viaje activo
  Future<void> zoomToCurrentLeg(
    int legIndex,
    List<TramoViajeMostrable> tramos,
  ) async {
    if (mapboxMap == null || legIndex >= tramos.length) return;

  FeatureLogger().camera('zoom_leg:start', data: {'leg': legIndex, 'total': tramos.length});

    final tramo = tramos[legIndex];
    List<Coordenada> coordinatesForZoom = [];

    try {
      // Agregar coordenadas del tramo actual
      if (tramo.geometriaPolilinea != null &&
          tramo.geometriaPolilinea!.isNotEmpty) {
        coordinatesForZoom.addAll(tramo.geometriaPolilinea!);
      } else if (tramo.posicionPunto != null) {
        coordinatesForZoom.add(tramo.posicionPunto!);
      }

      // Si es ESPERAR_BUS: incluir bus y también la ubicación del usuario si está disponible
      if (tramo.tipo == TipoTramoViaje.ESPERAR_BUS) {
        _addBusCoordinatesForWaitingLeg(tramos, legIndex, coordinatesForZoom);

        final userPos = mapManager.getCurrentUserLocation();
        if (userPos != null) {
          coordinatesForZoom.add(userPos);
          FeatureLogger().camera('zoom_leg:add_user', data: {'lat': userPos.latitud, 'lon': userPos.longitud});
        }
      }

      // Si es VIAJE_EN_BUS: incluir la ubicación del bus/usuario y la parada destino
      if (tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS) {
        final busPos = mapManager.getCurrentBusPosition();
        if (busPos != null) {
          coordinatesForZoom.add(busPos);
          FeatureLogger().camera('zoom_leg:add_bus', data: {'lat': busPos.latitud, 'lon': busPos.longitud});
        }
        if (tramo.coordenadasParadaDestino != null) {
          coordinatesForZoom.add(tramo.coordenadasParadaDestino!);
          FeatureLogger().camera('zoom_leg:add_stop_dest', data: {'lat': tramo.coordenadasParadaDestino!.latitud, 'lon': tramo.coordenadasParadaDestino!.longitud});
        }
      }

      // Si es CAMINAR: incluir próxima parada y, si existe, una posición de bus para que el usuario tenga contexto
      if (tramo.tipo == TipoTramoViaje.CAMINAR) {
        if (tramo.coordenadasParadaDestino != null) {
          coordinatesForZoom.add(tramo.coordenadasParadaDestino!);
          FeatureLogger().camera('zoom_leg:add_stop_target', data: {'lat': tramo.coordenadasParadaDestino!.latitud, 'lon': tramo.coordenadasParadaDestino!.longitud});
        }
        final busPos = mapManager.getCurrentBusPosition();
        final destino = tramo.coordenadasParadaDestino;
        if (busPos != null && destino != null) {
          final etaMin = _estimateBusEtaMinutes(busPos, destino);
          if (etaMin != null && etaMin <= _maxBusEtaMinutesForWalkContext) {
            coordinatesForZoom.add(busPos);
            FeatureLogger().camera('zoom_leg:add_bus_for_walk', data: {
              'lat': busPos.latitud,
              'lon': busPos.longitud,
              'eta_min': etaMin.toStringAsFixed(1)
            });
          } else {
            FeatureLogger().camera('zoom_leg:skip_bus_far', data: {
              'eta_min': etaMin?.toStringAsFixed(1) ?? 'na'
            });
          }
        }
        final userPos = mapManager.getCurrentUserLocation();
        if (userPos != null) {
          coordinatesForZoom.add(userPos);
          FeatureLogger().camera('zoom_leg:add_user_for_walk', data: {'lat': userPos.latitud, 'lon': userPos.longitud});
        }
      }

      // Hacer zoom según las coordenadas disponibles
      if (coordinatesForZoom.length > 1) {
        // Permitir un override adicional si venimos de un zoom global hace muy poco
        final elapsedSinceLast = DateTime.now().difference(_lastAnimationTime);
        if (elapsedSinceLast < _minAnimationSpacing) {
          _cooldownOverrideOnce = true;
          FeatureLogger().camera('fly:override_leg_cooldown', data: {'elapsed_ms': elapsedSinceLast.inMilliseconds});
        }
        // Múltiples coordenadas: usar zoom a región
        await _zoomToCoordinates(coordinatesForZoom, _getCurrentLegPadding());
      } else if (coordinatesForZoom.length == 1) {
        // Una sola coordenada: zoom centrado
        final punto = coordinatesForZoom.first;
        await mapboxMap!.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(punto.longitud, punto.latitud)),
            zoom: 16.0,
          ),
          MapAnimationOptions(duration: 1200),
        );
      }
    } catch (e) {
  FeatureLogger().camera('zoom_leg:error', data: {'e': e.toString()});
    }
  }

  /// Agregar coordenadas del bus en tiempo real para el zoom
  void _addBusCoordinatesToZoom(
    OpcionDeRutaMostrable route,
    List<Coordenada> allCoordinates,
  ) {
  FeatureLogger().camera('zoom_preview:add_bus_scan');

    int busesAddedToZoom = 0;

    // Buscar el primer tramo de bus con posición en tiempo real
    for (int i = 0; i < route.tramosParaPreview.length; i++) {
      final tramo = route.tramosParaPreview[i];

      if ((tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS ||
              tramo.tipo == TipoTramoViaje.ESPERAR_BUS) &&
          tramo.posicionActualBus != null) {
        allCoordinates.add(tramo.posicionActualBus!);
        busesAddedToZoom++;

  FeatureLogger().camera('zoom_preview:bus_added', data: {'linea': tramo.nombreLineaBus ?? 'unk', 'lat': tramo.posicionActualBus!.latitud, 'lon': tramo.posicionActualBus!.longitud});

        // Solo agregar el primer bus encontrado (más relevante para preview)
        break;
      }
    }

    // Si no encontramos bus en los tramos, intentar con el ETA general
    if (busesAddedToZoom == 0 &&
        route.etaProximoBus != null &&
        route.etaProximoBus!.posicionBus != null) {
      FeatureLogger().camera('zoom_preview:eta_candidate_found', data: {
        'linea': route.etaProximoBus!.linea,
        'lat': route.etaProximoBus!.posicionBus!.latitud,
        'lon': route.etaProximoBus!.posicionBus!.longitud
      });
      allCoordinates.add(route.etaProximoBus!.posicionBus!);
      busesAddedToZoom++;

  FeatureLogger().camera('zoom_preview:bus_eta_added', data: {'linea': route.etaProximoBus!.linea, 'lat': route.etaProximoBus!.posicionBus!.latitud, 'lon': route.etaProximoBus!.posicionBus!.longitud});
    }
    if (busesAddedToZoom == 0) {
      FeatureLogger().camera('zoom_preview:bus_none', data: {
        'has_eta': route.etaProximoBus != null,
        'has_eta_pos': route.etaProximoBus?.posicionBus != null
      });
    }

  FeatureLogger().camera('zoom_preview:bus_count', data: {'count': busesAddedToZoom});
  }

  /// Hacer zoom a lista de coordenadas con padding específico
  Future<void> _zoomToCoordinates(
    List<Coordenada> coordinates,
    MbxEdgeInsets padding,
  ) async {
    if (mapboxMap == null || coordinates.isEmpty) return;
  // Guardar siempre la petición para futuros refresh
  _lastRequestedCoords = List.of(coordinates);
  _lastRequestedPadding = padding;
    final can = _shouldAnimate(forCoordinates: coordinates, firstAttempt: true);
    if (!can) {
      // Fallback: si no pasó pero aún no hicimos ninguna animación, forzar una sola vez
      if (!_initialCameraDone) {
        FeatureLogger().camera('fly:force_initial_retry');
      } else {
        return; // ya tuvimos animaciones previas, no forzar
      }
    }

    try {
      // Convertir coordenadas a puntos de Mapbox
      final mapboxPoints =
          coordinates
              .map((c) => Point(coordinates: Position(c.longitud, c.latitud)))
              .toList();

      // Calcular opciones de cámara para mostrar todas las coordenadas
      FeatureLogger().camera('fly:prepare', data: {'pts': mapboxPoints.length});
      final cameraOptions = await mapboxMap!.cameraForCoordinates(
        mapboxPoints,
        padding,
        null,
        null,
      );
      FeatureLogger().camera('fly:camera_options_ready', data: {
        'zoom': cameraOptions.zoom,
        'bearing': cameraOptions.bearing,
        'pitch': cameraOptions.pitch
      });

      // Hacer el zoom con animación
  _isAnimating = true;
  await mapboxMap!.flyTo(cameraOptions, MapAnimationOptions(duration: 1200));
      _lastAnimationTime = DateTime.now(); // actualizar cooldown sólo tras animación exitosa
      FeatureLogger().camera('fly:done', data: {
        'zoom': cameraOptions.zoom,
        'bearing': cameraOptions.bearing,
        'since_last_ms': DateTime.now().difference(_lastAnimationTime).inMilliseconds
      });
      _initialCameraDone = true;
  _lastPadding = padding; // guardar padding usado
  _isAnimating = false;
  _lastAnimationEnd = DateTime.now();
    } catch (e) {
  FeatureLogger().camera('fly:error', data: {'e': e.toString()});
  _isAnimating = false;
  _lastAnimationEnd = DateTime.now();
    }
  }

  /// Obtener padding para preview de ruta
  MbxEdgeInsets _getPreviewPadding() {
    // Padding aumentado para considerar la card de opciones en la parte inferior
    return MbxEdgeInsets(
      top: 100.0,
      left: 50.0,
      bottom: 400.0, // Espacio generoso para el carousel
      right: 50.0,
    );
  }

  /// Obtener padding para viaje activo
  MbxEdgeInsets _getActiveTripPadding() {
    return MbxEdgeInsets(
      top: 250.0, // Espacio para la card de instrucciones
      left: 40.0,
      bottom: 100.0, // Espacio para panel de navegación
      right: 40.0,
    );
  }

  /// Obtener padding para tramo actual
  MbxEdgeInsets _getCurrentLegPadding() {
    // Aumentar padding para evitar cortar el bus en el borde, especialmente en esperar bus
    return MbxEdgeInsets(top: 260.0, left: 60.0, bottom: 160.0, right: 60.0);
  }

  /// Agregar coordenadas del bus en tiempo real para tramo de espera
  void _addBusCoordinatesForWaitingLeg(
    List<TramoViajeMostrable> tramos,
    int currentLegIndex,
    List<Coordenada> coordinatesForZoom,
  ) {
  FeatureLogger().camera('waiting_leg:scan_bus', data: {'leg': currentLegIndex});

    // Primero, intentar obtener coordenadas del sistema centralizado de tracking
    final busPosition = mapManager.getCurrentBusPosition();
    if (busPosition != null) {
      coordinatesForZoom.add(busPosition);
  FeatureLogger().camera('waiting_leg:central_bus', data: {'lat': busPosition.latitud, 'lon': busPosition.longitud});
      return;
    }

    // Si no hay tracking activo, buscar en los tramos información estática
    // 1. Verificar si el tramo actual tiene información de bus
    final tramoActual = tramos[currentLegIndex];
    if (tramoActual.posicionActualBus != null) {
      coordinatesForZoom.add(tramoActual.posicionActualBus!);
  FeatureLogger().camera('waiting_leg:leg_bus', data: {'lat': tramoActual.posicionActualBus!.latitud, 'lon': tramoActual.posicionActualBus!.longitud});
      return;
    }

    // 2. Buscar el siguiente tramo VIAJE_EN_BUS que tenga información de bus
    for (int i = currentLegIndex + 1; i < tramos.length; i++) {
      final tramo = tramos[i];

      if (tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS &&
          tramo.posicionActualBus != null) {
        coordinatesForZoom.add(tramo.posicionActualBus!);
  FeatureLogger().camera('waiting_leg:next_leg_bus', data: {'leg': i, 'lat': tramo.posicionActualBus!.latitud, 'lon': tramo.posicionActualBus!.longitud});
        return;
      }
    }

  FeatureLogger().camera('waiting_leg:no_bus');
  }

  /// Ajuste dinámico (en vivo) entre parada y bus durante WAITING_FOR_BUS con ETA.
  Future<void> updateWaitingBusViewport({
    required TramoViajeMostrable waitingLeg,
    required Coordenada busPosition,
    Coordenada? userPosition,
  }) async {
    if (mapboxMap == null) return;
    // Intentar reanudar antes de decidir
    maybeResumeAutoFollow();
    if (!_autoFollowEnabled) {
      FeatureLogger().camera('waiting_viewport:skip_auto_follow_disabled');
      return;
    }
    try {
      final List<Coordenada> coords = [];
      // Parada origen (o punto) del tramo de espera
      if (waitingLeg.coordenadasParadaOrigen != null) {
        coords.add(waitingLeg.coordenadasParadaOrigen!);
      } else if (waitingLeg.posicionPunto != null) {
        coords.add(waitingLeg.posicionPunto!);
      }
      // Bus realtime
      coords.add(busPosition);
      // Usuario ayuda a mantener contexto si se mueve alejándose
      if (userPosition != null) {
        coords.add(userPosition);
      }
  if (coords.length < 2) { FeatureLogger().camera('waiting_viewport:skip_insufficient'); return; }
      await _zoomToCoordinates(
        coords,
        _getCurrentLegPadding(), // Reusar padding de tramo actual
      );
    } catch (e) {
  FeatureLogger().camera('waiting_viewport:error', data: {'e': e.toString()});
    }
  }

  // NUEVO: Informar interacción manual (gesto) para pausar auto-follow
  void notifyManualInteraction() {
    if (!_autoFollowEnabled) {
      return; // ya pausado, evitar spam
    }
    _autoFollowEnabled = false;
    _lastUserCameraInteraction = DateTime.now();
    FeatureLogger().camera('auto_follow:paused');
  _scheduleResumeTimer();
  }

  // NUEVO: Verificar si debemos reanudar auto-follow
  void maybeResumeAutoFollow() {
    final diff = DateTime.now().difference(_lastUserCameraInteraction);
    if (!_autoFollowEnabled && diff >= _autoResumeAfterFast) {
      _autoFollowEnabled = true;
  FeatureLogger().camera('auto_follow:resumed');
  // Preparar override para refrescar inmediatamente viewport anterior
  _cooldownOverrideOnce = true;
  _ignoreMinorChangeOnce = true;
  _scheduleRefreshAfterResume();
      // Notificar al MapManager para un recenter semántico (ej: esperar bus)
      try {
        mapManager.handleAutoFollowResumed();
      } catch (e) {
        FeatureLogger().camera('auto_follow:resume_recenter_error', data: {'e': e.toString()});
      }
    }
  }

  void _scheduleResumeTimer() {
    final wait = _autoResumeAfterFast; // por ahora siempre fast
    final myGen = ++_resumeGeneration;
    FeatureLogger().camera('auto_follow:resume_timer_set', data: {'ms': wait.inMilliseconds});
    Future.delayed(wait, () {
      if (myGen != _resumeGeneration) return; // invalidado por nueva interacción
      FeatureLogger().camera('auto_follow:resume_timer_fire');
      maybeResumeAutoFollow();
    });
  }

  bool _shouldAnimate({List<Coordenada>? forCoordinates, bool firstAttempt = false}) {
    maybeResumeAutoFollow();
    if (!_autoFollowEnabled) {
      FeatureLogger().camera('fly:skip_auto_follow_off');
      return false;
    }
    final now = DateTime.now();
    final elapsed = now.difference(_lastAnimationTime);
    // Antes de la primera animación NO aplicar cooldown
    if (_cooldownOverrideOnce) {
      FeatureLogger().camera('fly:override_cooldown_once');
    }
    if (_initialCameraDone && !_cooldownOverrideOnce && elapsed < _minAnimationSpacing) {
      FeatureLogger().camera('fly:skip_cooldown', data: {'since_last_ms': elapsed.inMilliseconds});
      return false; // Cooldown (no aplica antes de la primera animación)
    }
    // Antes de la primera animación tampoco aplicar filtro de bounds menores
    if (_initialCameraDone && forCoordinates != null && _lastBoundsCoords != null && !_ignoreMinorChangeOnce) {
      if (!_boundsChangedSignificantly(_lastBoundsCoords!, forCoordinates)) {
        FeatureLogger().camera('fly:skip_minor_bounds');
        return false; // Cambios insignificantes
      }
    }
    if (forCoordinates != null) {
      _lastBoundsCoords = forCoordinates;
    }
    FeatureLogger().camera('fly:proceed', data: {'first': !_initialCameraDone, 'elapsed_ms': elapsed.inMilliseconds});
    if (_cooldownOverrideOnce) {
      // Consumir override; no actualizamos _lastAnimationTime aquí, se hará tras fly
      _cooldownOverrideOnce = false;
    }
    if (_ignoreMinorChangeOnce) {
      _ignoreMinorChangeOnce = false;
    }
    return true;
  }

  void _scheduleRefreshAfterResume() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    Future.microtask(() {
      _refreshScheduled = false;
      _attemptRefreshAfterResume();
    });
  }

  bool get isAnimating => _isAnimating;
  bool get isAutoFollowEnabled => _autoFollowEnabled;
  DateTime get lastAnimationEnd => _lastAnimationEnd;

  // Permitir a MapManager forzar que la próxima animación ignore cooldown y minor-change
  void prepareImmediateAnimation() {
    _cooldownOverrideOnce = true;
    _ignoreMinorChangeOnce = true;
  }

  void _attemptRefreshAfterResume() {
    if (!_autoFollowEnabled) return; // ya se volvió a pausar
    var coords = _lastBoundsCoords;
    var padding = _lastPadding;
    // Fallback a la última petición si nunca se animó (usuario movió cámara antes)
    if ((coords == null || coords.isEmpty) && _lastRequestedCoords != null) {
      coords = _lastRequestedCoords;
      padding = padding ?? _lastRequestedPadding;
      FeatureLogger().camera('auto_follow:refresh_using_requested');
    }
    if (coords == null || coords.isEmpty) {
      FeatureLogger().camera('auto_follow:refresh_skipped_no_last');
      return;
    }
    if (padding == null) {
      FeatureLogger().camera('auto_follow:refresh_skipped_no_padding');
      return;
    }
    FeatureLogger().camera('auto_follow:refresh_after_resume');
    // Forzar animación ignorando cooldown y minor change una vez más
    _cooldownOverrideOnce = true;
    _ignoreMinorChangeOnce = true;
    _zoomToCoordinates(List.of(coords), padding);
  }

  // Estimar ETA en minutos del bus a la parada destino con velocidad media
  double? _estimateBusEtaMinutes(Coordenada bus, Coordenada destino) {
    try {
      final distM = calculateHaversineDistance(
        bus.latitud,
        bus.longitud,
        destino.latitud,
        destino.longitud,
      );
      // Velocidad media asumida (m/s). Si más adelante hay velocidad real, reemplazar.
      const double assumedSpeedMs = 7.0; // ~25 km/h
      if (assumedSpeedMs <= 0) return null;
      final etaSec = distM / assumedSpeedMs;
      return etaSec / 60.0;
    } catch (_) {
      return null;
    }
  }

  bool _boundsChangedSignificantly(
    List<Coordenada> prev,
    List<Coordenada> next,
  ) {
    if (prev.isEmpty || next.isEmpty) return true;
    // Calcular bounding boxes
    double minLat(List<Coordenada> c) => c.map((e) => e.latitud).reduce(min);
    double maxLat(List<Coordenada> c) => c.map((e) => e.latitud).reduce(max);
    double minLon(List<Coordenada> c) => c.map((e) => e.longitud).reduce(min);
    double maxLon(List<Coordenada> c) => c.map((e) => e.longitud).reduce(max);
    final prevBox = [minLat(prev), minLon(prev), maxLat(prev), maxLon(prev)];
    final nextBox = [minLat(next), minLon(next), maxLat(next), maxLon(next)];
    // Centros
    final prevCenter = Coordenada(
      latitud: (prevBox[0] + prevBox[2]) / 2,
      longitud: (prevBox[1] + prevBox[3]) / 2,
    );
    final nextCenter = Coordenada(
      latitud: (nextBox[0] + nextBox[2]) / 2,
      longitud: (nextBox[1] + nextBox[3]) / 2,
    );
    final centerShift = calculateHaversineDistance(
      prevCenter.latitud,
      prevCenter.longitud,
      nextCenter.latitud,
      nextCenter.longitud,
    );
    final prevDiag = calculateHaversineDistance(
      prevBox[0],
      prevBox[1],
      prevBox[2],
      prevBox[3],
    );
    final nextDiag = calculateHaversineDistance(
      nextBox[0],
      nextBox[1],
      nextBox[2],
      nextBox[3],
    );
    final expansion = (nextDiag - prevDiag).abs();
    final changed =
        centerShift > _minCenterShiftMeters || expansion > _minBoundsExpansionMeters;
    if (!changed) {
  FeatureLogger().camera('fly:skip_minor_change', data: {'shift_m': centerShift.toStringAsFixed(1), 'exp_m': expansion.toStringAsFixed(1)});
    }
    return changed;
  }

  // API pública para forzar flujo (ej: cuando usuario toca botón centrado)
  Future<void> forceAutoFollow(Future<void> Function() action) async {
    _autoFollowEnabled = true;
    _lastAnimationTime = DateTime.fromMillisecondsSinceEpoch(0);
    await action();
  }
}
