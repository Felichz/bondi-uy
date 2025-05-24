import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:bondi_uy/backend/providers/app_logic_provider.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import 'package:bondi_uy/map_manager/map_manager.dart';

import 'package:bondi_uy/ui/overlays/initial_phase_overlay.dart';
import 'package:bondi_uy/ui/overlays/route_options_overlay.dart';
import 'package:bondi_uy/ui/overlays/active_trip_overlay.dart';

// Provider global para el MapManager
final mapManagerProvider = StateProvider<MapManager?>((ref) => null);

class AppHost extends ConsumerStatefulWidget {
  const AppHost({super.key});

  @override
  ConsumerState<AppHost> createState() => _AppHostState();
}

class _AppHostState extends ConsumerState<AppHost> {
  MapboxMap? mapboxMap;
  MapManager? mapManager;
  FaseApp? _lastPhase;

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
        mapManager!.cleanup.clearRoutePreview();
        break;
      case FaseApp.VIAJE_ACTIVO_EN_CURSO:
        // Saliendo de viaje activo
        mapManager!.cleanup.clearActiveTrip();
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

    mapManager = MapManager(mapboxMap);

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
}
