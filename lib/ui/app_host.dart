import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/services.dart';
import 'package:bondi_uy/backend/providers/app_logic_provider.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import 'package:bondi_uy/map_manager/map_manager.dart';
import 'package:bondi_uy/utils/feature_logger.dart';
import 'dart:math' as math;

import 'package:bondi_uy/ui/overlays/initial_phase_overlay.dart';
import 'package:bondi_uy/ui/overlays/route_options_overlay.dart';
import 'package:bondi_uy/ui/overlays/active_trip_overlay.dart';
import 'package:bondi_uy/devtools/trip_data_capture_service.dart';

// Provider global para el MapManager
final mapManagerProvider = StateProvider<MapManager?>((ref) => null);
// Dev: estado de grabación (para feedback visual)
// Eliminado: grabación manual
// Dev: velocidad de reproducción
final devReplaySpeedProvider = StateProvider<double>((ref) => 1.0);

class AppHost extends ConsumerStatefulWidget {
  const AppHost({super.key});

  @override
  ConsumerState<AppHost> createState() => _AppHostState();
}

class _AppHostState extends ConsumerState<AppHost> {
  MapboxMap? mapboxMap;
  MapManager? mapManager;
  FaseApp? _lastPhase;

  // NUEVO: métricas de eventos de mapa
  int _cameraChangeCount = 0;
  int _mapIdleCount = 0;
  int _tapCount = 0;
  DateTime _lastCameraAggLog = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastIdleAggLog = DateTime.fromMillisecondsSinceEpoch(0);
  // Heurística de gesto real del usuario (tap reciente)
  DateTime? _lastUserTap;
  DateTime _lastGestureLog = DateTime.fromMillisecondsSinceEpoch(0);
  Point? _lastCameraCenter;
  double? _lastCameraZoom;

  static const _aggEvery = 50; // log agregado cada 50 eventos
  static const _aggInterval = Duration(seconds: 5); // o cada 5s mínimo
  static const _postAnimationGrace = Duration(milliseconds: 900);
  static const _debugSampleInterval = Duration(seconds: 5);
  DateTime _lastGestureDebugSample = DateTime.fromMillisecondsSinceEpoch(0);
  int _moveEvalCount = 0;
  int _moveTrueCount = 0;
  bool _lastMoveOkState = false;

  void _logMapEvent(String type, {Map<String, Object?>? data}) {
    FeatureLogger().log('map_evt', type, data: data);
  }

  void _handleCameraChange(event) {
    _cameraChangeCount++;
    double? zoom;
    double? bearing;
    double? pitch;
    Point? center;
    try {
      final cs = (event as dynamic).cameraState;
      zoom = cs?.zoom; bearing = cs?.bearing; pitch = cs?.pitch; center = cs?.center;
    } catch (_) {}
    final now = DateTime.now();

    // GRACE: ignorar eventos inmediatamente después de animación para no marcar como drag (solo log early/late)
    final lastAnimEnd = mapManager?.cameraController.lastAnimationEnd;
    if (lastAnimEnd != null) {
      final sinceMs = now.difference(lastAnimEnd).inMilliseconds;
      if (sinceMs < _postAnimationGrace.inMilliseconds) {
        final ratio = sinceMs / _postAnimationGrace.inMilliseconds;
        if (ratio < 0.1 || (ratio > 0.9 && ratio < 1.0)) {
          FeatureLogger().camera('gesture:ignore_post_anim', data: {'ms': sinceMs});
        }
        return;
      }
    }

    final dueByCount = _cameraChangeCount % _aggEvery == 1;
    final dueByTime = now.difference(_lastCameraAggLog) >= _aggInterval;
    if (dueByCount || dueByTime) {
      _lastCameraAggLog = now;
      _logMapEvent('camera_change', data: {
        'count': _cameraChangeCount,
        if (zoom != null) 'z': zoom.toStringAsFixed(2),
        if (bearing != null) 'br': bearing.toStringAsFixed(1),
        if (pitch != null) 'p': pitch.toStringAsFixed(1),
        'sinceTapMs': _lastUserTap == null ? -1 : now.difference(_lastUserTap!).inMilliseconds,
      });
    }

    // Ignorar eventos generados por animaciones de cámara
    if (mapManager?.cameraController.isAnimating == true) {
      return;
    }

    final movementOk = _movementExceeded(center, zoom);
    _moveEvalCount++;
    if (movementOk) _moveTrueCount++;
    if (movementOk && !_lastMoveOkState) {
      FeatureLogger().camera('gesture:move_transition_true', data: {
        'tapAgoMs': _lastUserTap == null ? -1 : now.difference(_lastUserTap!).inMilliseconds
      });
    }
    _lastMoveOkState = movementOk;
    if (now.difference(_lastGestureDebugSample) >= _debugSampleInterval) {
      FeatureLogger().camera('gesture:move_sample', data: {
        'evals': _moveEvalCount,
        'true': _moveTrueCount,
        'pctTrue': _moveEvalCount == 0 ? 0 : ((_moveTrueCount / _moveEvalCount) * 100).toStringAsFixed(1)
      });
      _lastGestureDebugSample = now;
      _moveEvalCount = 0;
      _moveTrueCount = 0;
    }

    // Tap reciente → gesto legítimo inmediato
    if (_lastUserTap != null && now.difference(_lastUserTap!) < const Duration(milliseconds: 1500)) {
      if (movementOk) _pauseAutoFollowReason('tap_move');
      return;
    }

    // Heurística drag: sin tap reciente, suficientes eventos y movimiento real
    if (movementOk && _recentDragWindow.addAndCheck(now)) {
      _pauseAutoFollowReason('drag_detected');
    }
  }

  void _pauseAutoFollowReason(String reason) {
    final now = DateTime.now();
    // Throttle logs de pausa (mínimo 800ms entre logs de este tipo)
    if (now.difference(_lastGestureLog) < const Duration(milliseconds: 800)) return;
    _lastGestureLog = now;
    mapManager?.notifyUserCameraInteraction();
    mapManager?.cameraController.resetLastBounds();
    FeatureLogger().camera('gesture:$reason');
  }

  bool _movementExceeded(Point? center, double? zoom) {
    if (center == null || zoom == null) return false;
    if (_lastCameraCenter == null) { _lastCameraCenter = center; _lastCameraZoom = zoom; return false; }
    // Thresholds (más estrictos)
    const minMetersShift = 25.0; // antes 10
    const minZoomDelta = 0.15;   // antes 0.08
    final fase = ref.read(appLogicProvider).faseActual;
    double centerShiftMeters = 0.0;
    try {
      // Cálculo rápido planar aproximado (no haversine) suficiente para threshold pequeño
      final dx = (center.coordinates.lng - _lastCameraCenter!.coordinates.lng) * 111320 *
          math.cos((_lastCameraCenter!.coordinates.lat + center.coordinates.lat) / 2 * math.pi / 180);
      final dy = (center.coordinates.lat - _lastCameraCenter!.coordinates.lat) * 110540;
      centerShiftMeters = math.sqrt(dx * dx + dy * dy);
    } catch (_) {}

    final zoomDelta = (zoom - (_lastCameraZoom ?? zoom)).abs();
    bool exceeded = centerShiftMeters > minMetersShift || zoomDelta > minZoomDelta;
    if (_lastUserTap == null && fase == FaseApp.MOSTRANDO_OPCIONES_RUTA) {
      // En preview exigir ambos (evita que sólo el auto ajuste de zoom dispare detección)
      exceeded = centerShiftMeters > minMetersShift && zoomDelta > minZoomDelta;
    }
    if (exceeded) { _lastCameraCenter = center; _lastCameraZoom = zoom; }
    return exceeded;
  }

  void _handleMapIdle(event) {
    _mapIdleCount++;
    final now = DateTime.now();
    final dueByCount = _mapIdleCount % _aggEvery == 1;
    final dueByTime = now.difference(_lastIdleAggLog) >= _aggInterval;
    if (dueByCount || dueByTime) {
      _lastIdleAggLog = now;
      _logMapEvent('map_idle', data: {
        'count': _mapIdleCount,
        'sinceTapMs': _lastUserTap == null ? -1 : now.difference(_lastUserTap!).inMilliseconds,
      });
    }
  }

  void _handleTap(dynamic gestureContext) {
    _tapCount++;
    _lastUserTap = DateTime.now();
    _logMapEvent('tap', data: {'count': _tapCount});
    mapManager?.notifyUserCameraInteraction();
  }

  @override
  Widget build(BuildContext context) {
    final appUiState = ref.watch(appLogicProvider);

    // Detectar cambios de fase para debug y limpiar el mapa según corresponda
    if (_lastPhase != null && _lastPhase != appUiState.faseActual) {
      print(
        "[AppHost] Phase changing from $_lastPhase to ${appUiState.faseActual}",
      );
      _handlePhaseChange(_lastPhase!, appUiState.faseActual);
    }
    _lastPhase = appUiState.faseActual;

    return MaterialApp(
      title: 'BondiUY',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(
            0xFF1976D2,
          ), // Color azul característico de transporte
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
      ),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Stack(
          children: [
            // MAPA ÚNICO PERSISTENTE - Base de toda la aplicación
            MapWidget(
              key: const ValueKey("persistent_map"),
              onMapCreated: (MapboxMap controller) {
                mapboxMap = controller;
                // Crear MapManager cuando el mapa esté listo
                _initializeMapManager();
                // Notificar a la capa de lógica que el mapa está listo
                ref.read(appLogicProvider.notifier).pantallaDeInicioCargada();
              },
              cameraOptions: CameraOptions(
                center: Point(coordinates: Position(-56.1645, -34.9011)),
                zoom: 12.0,
              ),
              onMapLoadErrorListener: (MapLoadingErrorEventData data) {
                ref
                    .read(appLogicProvider.notifier)
                    .setErrorGlobal("Error cargando el mapa: ${data.message}");
              },
              onStyleLoadedListener: (_) {
                print("[AppHost] Map style loaded - ready for overlays");
                // Reinicializar MapManager cuando el estilo se carga
                if (mapManager != null) {
                  _reinitializeMapManager();
                }
              },
              // NUEVO: Notificar cualquier cambio de cámara continuo (arrastre / pinch)
              onCameraChangeListener: (event) {
                _handleCameraChange(event);
              },
              // NUEVO: Cuando la cámara se detiene (idle) podemos registrar también
              onMapIdleListener: (event) {
                _handleMapIdle(event);
              },
              // NUEVO: Tap básico para pausar auto-follow
              onTapListener: (gestureContext) {
                _handleTap(gestureContext);
              },
            ),

            // OVERLAYS ESPECÍFICOS POR FASE
            _buildPhaseOverlay(appUiState.faseActual, mapboxMap),

            // Overlay para spinner global
            if (appUiState.mostrandoSpinnerGlobal)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: Card(
                    elevation: 8,
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Cargando...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Overlay para mensajes de error
            if (appUiState.mensajeErrorGlobal != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                child: _buildErrorSnackbar(
                  context,
                  ref,
                  appUiState.mensajeErrorGlobal!,
                ),
              ),

            // Overlay para mensajes informativos
            if (appUiState.mensajeInfoGlobal != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                child: _buildInfoSnackbar(
                  context,
                  ref,
                  appUiState.mensajeInfoGlobal!,
                ),
              ),
          ],
        ),
        floatingActionButton: kDebugMode ? _DevFab() : null,
      ),
    );
  }

  Widget _buildPhaseOverlay(FaseApp fase, MapboxMap? mapboxMap) {
    // Transiciones suaves entre overlays sin cambiar el mapa de fondo
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.1), // Deslizar desde abajo ligeramente
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
      child: _buildOverlayForPhase(fase, mapboxMap),
    );
  }

  Widget _buildOverlayForPhase(FaseApp fase, MapboxMap? mapboxMap) {
    switch (fase) {
      case FaseApp.INICIAL_SIN_BUSQUEDA:
        return InitialPhaseOverlay(
          key: const ValueKey('initial_overlay'),
          mapboxMap: mapboxMap,
        );
      case FaseApp.MOSTRANDO_OPCIONES_RUTA:
        return RouteOptionsOverlay(
          key: const ValueKey('route_options_overlay'),
          mapboxMap: mapboxMap,
        );
      case FaseApp.VIAJE_ACTIVO_EN_CURSO:
        return ActiveTripOverlay(
          key: const ValueKey('active_trip_overlay'),
          mapboxMap: mapboxMap,
        );
      default:
        return InitialPhaseOverlay(
          key: const ValueKey('fallback_overlay'),
          mapboxMap: mapboxMap,
        );
    }
  }

  Widget _buildErrorSnackbar(
    BuildContext context,
    WidgetRef ref,
    String message,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      onPressed: () {
                        ref
                            .read(appLogicProvider.notifier)
                            .limpiarMensajeDeErrorGlobal();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoSnackbar(
    BuildContext context,
    WidgetRef ref,
    String message,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      onPressed: () {
                        // TODO: Implementar método para limpiar mensaje info
                        // ref.read(appLogicProvider).limpiarMensajeInfoGlobal();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handlePhaseChange(FaseApp from, FaseApp to) {
    if (mapManager == null) return;

    print("[AppHost] Handling phase change from $from to $to");

    // OPTIMIZACIÓN: Si la transición es de preview a active trip,
    // dejar que MapManager maneje la optimización internamente
    final isOptimizedTransition =
        from == FaseApp.MOSTRANDO_OPCIONES_RUTA &&
        to == FaseApp.VIAJE_ACTIVO_EN_CURSO;

    if (isOptimizedTransition) {
      print(
        "[AppHost] ✅ OPTIMIZED TRANSITION: Letting MapManager handle route_preview → active_trip transition",
      );
      // No hacer cleanup aquí, MapManager.showActiveTrip() maneja la optimización
      return;
    }

    // Limpiar estado anterior según la fase (solo si no es transición optimizada)
    switch (from) {
      case FaseApp.MOSTRANDO_OPCIONES_RUTA:
        // Saliendo de preview de rutas (pero no hacia active trip)
        mapManager!.cleanup.clearRoute();
        break;
      case FaseApp.VIAJE_ACTIVO_EN_CURSO:
        // Saliendo de viaje activo
        mapManager!.cleanup.clearRoute();
        break;
      default:
        // Para otras fases, limpiar todo
        mapManager!.clearAll();
        break;
    }

    // Preparar para nueva fase
    switch (to) {
      case FaseApp.INICIAL_SIN_BUSQUEDA:
        mapManager!.showInitialPhase();
        break;
      case FaseApp.MOSTRANDO_OPCIONES_RUTA:
        // El preview específico se maneja en RouteOptionsOverlay
        break;
      case FaseApp.VIAJE_ACTIVO_EN_CURSO:
        // El viaje específico se maneja en ActiveTripOverlay
        break;
    }
  }

  void _initializeMapManager() {
    if (mapboxMap == null) return;

    print("[AppHost] Initializing MapManager");

    mapManager = MapManager(mapboxMap, ref: ref);

    // Hacer el MapManager accesible globalmente vía provider
    ref.read(mapManagerProvider.notifier).state = mapManager;

    // Inicializar de forma asíncrona
    mapManager!.initialize().catchError((e) {
      print("[AppHost] Error initializing MapManager: $e");
      ref
          .read(appLogicProvider.notifier)
          .setErrorGlobal("Error inicializando el mapa: $e");
    });
  }

  void _reinitializeMapManager() {
    if (mapManager == null) return;

    print("[AppHost] Reinitializing MapManager after style reload");

    // Reinicializar iconos y configuración
    mapManager!.initialize().catchError((e) {
      print("[AppHost] Error reinitializing MapManager: $e");
    });
  }

  @override
  void initState() {
    super.initState();
    _recentDragWindow = _DragWindow(maxEvents: 8, within: const Duration(milliseconds: 1200));
  }

  late _DragWindow _recentDragWindow;
}

class _DevFab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.read(appLogicProvider.notifier);
    // Eliminado: estado de grabación
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Controles de velocidad
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              heroTag: 'dev_speed_down',
              backgroundColor: Colors.grey.shade700,
              tooltip: 'Reducir velocidad',
              child: const Icon(Icons.remove),
              onPressed: () {
                final current = ref.read(devReplaySpeedProvider);
                final next = (current - 0.5).clamp(0.25, 3.0);
                ref.read(devReplaySpeedProvider.notifier).state = next;
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Velocidad: ${next.toStringAsFixed(2)}x'),
                      duration: const Duration(milliseconds: 800),
                    ),
                  );
                }
              },
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Consumer(
                builder: (_, ref, __) {
                  final speed = ref.watch(devReplaySpeedProvider);
                  return Text(
                    '${speed.toStringAsFixed(2)}x',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              heroTag: 'dev_speed_up',
              backgroundColor: Colors.grey.shade700,
              tooltip: 'Aumentar velocidad',
              child: const Icon(Icons.add),
              onPressed: () {
                final current = ref.read(devReplaySpeedProvider);
                final next = (current + 0.5).clamp(0.25, 3.0);
                ref.read(devReplaySpeedProvider.notifier).state = next;
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Velocidad: ${next.toStringAsFixed(2)}x'),
                      duration: const Duration(milliseconds: 800),
                    ),
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'dev_simulate_trip',
          backgroundColor: Colors.blue,
          tooltip: 'Simular viaje (ruta actual)',
          child: const Icon(Icons.play_arrow),
          onPressed: () async {
            final speed = ref.read(devReplaySpeedProvider);
            await app.devStartTripSimulation(speed: speed);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Simulación iniciada'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'dev_copy_trip',
          backgroundColor: Colors.green,
          tooltip: 'Copiar trip como JSON (para tests)',
          child: const Icon(Icons.content_copy),
          onPressed: () async {
            final state = ref.read(appLogicProvider);

            // Solo funciona si hay opciones de ruta mostradas
            if (state.datosFaseOpcionesRuta == null ||
                state.datosFaseOpcionesRuta!.opcionesDeRuta.isEmpty) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ No hay rutas seleccionadas. Busca un trip primero.'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
              return;
            }

            // Tomar la primera opción (o la recomendada)
            final opciones = state.datosFaseOpcionesRuta!.opcionesDeRuta;
            final selectedRoute = opciones.firstWhere(
              (o) => o.esRecomendada,
              orElse: () => opciones.first,
            );

            // Capturar datos
            try {
              await TripDataCaptureService.captureTripToClipboard(
                tripId: 'trip_${DateTime.now().millisecondsSinceEpoch}',
                origin: state.ubicacionActualUsuario ?? Coordenada(latitud: 0, longitud: 0),
                destination: state.puntoDestinoParaBusqueda ?? Coordenada(latitud: 0, longitud: 0),
                selectedRoute: selectedRoute,
                initialBusPosition: state.datosFaseViajeActivo?.posicionActualBusReal,
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '✅ Trip copiado al portapapeles!\n'
                      '${selectedRoute.tramosParaPreview.length} segmentos',
                    ),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Error: $e'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            }
          },
        ),
        // Eliminado: botón de grabación manual
      ],
    );
  }
}

class _DragWindow {
  final int maxEvents;
  final Duration within;
  final List<DateTime> _events = [];
  _DragWindow({required this.maxEvents, required this.within});
  bool addAndCheck(DateTime now) {
    _events.add(now);
    // Purge antiguos
    _events.removeWhere((t) => now.difference(t) > within);
    return _events.length >= maxEvents;
  }
}
