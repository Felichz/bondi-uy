import 'dart:async';
// Eliminados imports no usados
// import 'dart:typed_data';
// import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:bondi_uy/backend/providers/app_logic_provider.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
// import 'package:bondi_uy/ui/widgets/bus_tooltip_widget.dart'; // No se usa actualmente
import 'package:bondi_uy/utils/geometry_utils.dart';
// import 'package:bondi_uy/map_manager/map_manager.dart'; // No se usa directamente aquí
import 'package:bondi_uy/ui/app_host.dart'; // Para acceder al mapManagerProvider
import 'package:bondi_uy/journey/journey_step_state.dart';
import 'package:bondi_uy/journey/route_dynamic_calculator.dart';

class ActiveTripOverlay extends ConsumerStatefulWidget {
  final MapboxMap? mapboxMap;

  const ActiveTripOverlay({super.key, required this.mapboxMap});

  @override
  ConsumerState<ActiveTripOverlay> createState() => _ActiveTripOverlayState();
}

class _ActiveTripOverlayState extends ConsumerState<ActiveTripOverlay> {
  int _currentLegIndex = 0;
  // Limpiar flags no utilizados para mantener el estado minimal

  // DIFF: Agregar listener para transiciones automáticas
  bool _automaticNavigationEnabled = true;
  // Estado previo no usado actualmente; dejar comentado para futuras mejoras
  // JourneyStepState? _lastKnownStep;

  // Sistema de animación de flechas
  // Sistema de animación no utilizado por ahora
  // Timer? _arrowAnimationTimer;
  // double _arrowAnimationPhase = 0.0;
  // List<String> _animatedArrowLayerIds = [];

  // Sistema de bus en tiempo real
  Timer? _busTrackingTimer;
  String? _currentBusLine;
  String? _currentBusDestination;
  Coordenada? _currentBusPosition;
  int? _currentBusEta;
  // Indicador no utilizado directamente (se usa isBusEtaRealTime pasado al panel)
  // bool? _currentBusIsRealTime;

  // Constantes para IDs de capas y fuentes de la ruta activa
  // IDs de capas/sources no usados en este overlay tras la refactorización
  // static const String ACTIVE_WALK_SOURCE_PREFIX = 'active-walk-source-';
  // static const String ACTIVE_WALK_LAYER_PREFIX = 'active-walk-layer-';
  // static const String ACTIVE_BUS_SOURCE_PREFIX = 'active-bus-source-';
  // static const String ACTIVE_BUS_LAYER_PREFIX = 'active-bus-layer-';
  // static const String ACTIVE_WAIT_SOURCE_PREFIX = 'active-wait-source-';
  // static const String ACTIVE_WAIT_LAYER_PREFIX = 'active-wait-layer-';
  // static const String USER_LOCATION_SOURCE_ID = 'user-location-source';
  // static const String USER_LOCATION_LAYER_ID = 'user-location-layer';

  // Constantes para iconos
  // static const String STOP_ICON_IMAGE_ID = 'stop-icon';
  // static const String BUS_ICON_IMAGE_ID = 'bus-icon';
  // static const String INCOMING_BUS_SOURCE_ID = 'incoming-bus-source';
  // static const String INCOMING_BUS_LAYER_ID = 'incoming-bus-layer';
  // static const String BUS_APPROACH_LINE_SOURCE_ID = 'bus-approach-line-source';
  // static const String BUS_APPROACH_LINE_LAYER_ID = 'bus-approach-line-layer';

  // Constantes para el bus en tiempo real
  // static const String _realtimeBusLayerId = "realtime-bus-layer";
  // static const String _realtimeBusSourceId = "realtime-bus-source";
  // static const String _busApproachLineLayerId = "bus-approach-line-layer";
  // static const String _busApproachLineBorderLayerId =
  //     "bus-approach-line-border-layer";
  // static const String _busApproachLineSourceId = "bus-approach-line-source";

  // Constantes para el tooltip de "Voy en camino!"
  // static const String _busTooltipLayerId = "bus-tooltip-layer";
  // static const String _busTooltipIconId = "incoming-bus-tooltip";

  // Variables para la animación del tooltip flotante
  // Timer? _tooltipFloatTimer;
  // double _tooltipFloatPhase = 0.0;
  // double _lastTooltipOffset =
  //     -5.0; // Offset base para posicionar arriba del bus (ajustado para estar más cerca)

  // Propiedades de estilo
  // Propiedades de estilo no usadas directamente en el overlay
  // static const Map<String, dynamic> _WALK_LINE_PROPERTIES = { ... };
  // static const Map<String, dynamic> _BUS_LINE_PROPERTIES = { ... };
  // static const Map<String, dynamic> _WAIT_CIRCLE_PROPERTIES = { ... };
  // static const Map<String, dynamic> _BORDER_PROPERTIES = { ... };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeActiveTrip();
    });
  }

  @override
  void dispose() {
    // Cancelar timers activos
    _busTrackingTimer?.cancel();
    super.dispose();
  }

  // Método de limpieza de elementos de previsualización (no usado actualmente tras la refactorización)
  // Future<void> _clearPreviousRoutePreview() async { ... }

  Future<void> _initializeActiveTrip() async {
    print("[ActiveTripOverlay] Initializing active trip");

    // Obtener MapManager del provider
    final mapManager = ref.read(mapManagerProvider);
    if (mapManager == null) {
      print("[ActiveTripOverlay] ERROR: MapManager no disponible");
      return;
    }

    // Mostrar elementos del viaje activo usando MapManager
    final activeTripState = ref.read(appLogicProvider).datosFaseViajeActivo;
    if (activeTripState != null && activeTripState.tramosDelViaje.isNotEmpty) {
      try {
        await mapManager.showActiveTrip(activeTripState);

        // Hacer zoom al primer paso del viaje (paso 0)
        print("[ActiveTripOverlay] Making initial zoom to leg 0");
        await mapManager.updateCurrentLeg(0, activeTripState.tramosDelViaje);

        // ELIMINADO: Ya no iniciamos tracking aquí, el sistema centralizado se encarga
      } catch (e) {
        print("[ActiveTripOverlay] Error initializing active trip: $e");
      }
    }

    print("[ActiveTripOverlay] Active trip initialization complete");
  }

  // Carga de iconos (no utilizada directamente aquí; gestionada por MapManager)
  // Future<void> _loadMapIcons() async { ... }

  // Future<MbxImage> _loadIconImageFromAsset(String assetName) async { ... }

  // DIFF: Nuevo método para transiciones automáticas
  void _onAutomaticStepTransition(int newStepIndex) {
    print('[ActiveTripOverlay] Automatic transition to step: $newStepIndex');

    setState(() {
      _currentLegIndex = newStepIndex;
    });

    // Usar lógica existente para actualizar el mapa
    _onLegSelected(newStepIndex);
  }

  void _onLegSelected(int legIndex) {
    setState(() {
      _currentLegIndex = legIndex;
    });

    // Obtener MapManager del provider y actualizar tramo actual
    final mapManager = ref.read(mapManagerProvider);
    final activeTripState = ref.read(appLogicProvider).datosFaseViajeActivo;

    if (mapManager != null && activeTripState != null) {
      print(
        "[ActiveTripOverlay] Updating current leg in MapManager: $legIndex",
      );
      mapManager.updateCurrentLeg(legIndex, activeTripState.tramosDelViaje);
    }

    // DIFF: Si es transición automática, actualizar tracking
    if (_automaticNavigationEnabled) {
      _updateTrackingForAutomaticMode(legIndex);
    }
  }

  // DIFF: Nuevo método para manejar tracking en modo automático
  void _updateTrackingForAutomaticMode(int legIndex) {
    final activeTripState = ref.read(appLogicProvider).datosFaseViajeActivo;
    if (activeTripState == null ||
        legIndex >= activeTripState.tramosDelViaje.length)
      return;

    final currentTramo = activeTripState.tramosDelViaje[legIndex];
    final appLogic = ref.read(appLogicProvider.notifier);

    // Manejar tracking de bus según el tipo de paso
    switch (currentTramo.tipo) {
      case TipoTramoViaje.ESPERAR_BUS:
        // Cuando esperamos el bus, necesitamos encontrar el próximo tramo de VIAJE_EN_BUS
        final nextBusTramo = _findNextBusTramo(
          activeTripState.tramosDelViaje,
          legIndex,
        );
        if (nextBusTramo != null && nextBusTramo.idTramo.isNotEmpty) {
          print(
            '[ActiveTripOverlay] Iniciando seguimiento para tramo de bus: ${nextBusTramo.idTramo}',
          );
          appLogic.iniciarSeguimientoBusTiempoReal(
            idViajeActivo: activeTripState.idViajeActivoConfirmado,
            idTramoBus: nextBusTramo.idTramo,
          );
        } else {
          print(
            '[ActiveTripOverlay] No se encontró tramo de bus para seguimiento',
          );
          appLogic.detenerSeguimientoBusTiempoReal();
        }
        break;
      case TipoTramoViaje.CAMINAR:
        // Mientras el usuario camina hacia la parada, mantener el tracking de API
        // para mostrar el bus que viene en camino con menor énfasis visual.
        final nextBusTramo = _findNextBusTramo(
          activeTripState.tramosDelViaje,
          legIndex,
        );
        if (nextBusTramo != null && nextBusTramo.idTramo.isNotEmpty) {
          print(
            '[ActiveTripOverlay] (CAMINAR) Manteniendo tracking API para próximo bus: ${nextBusTramo.idTramo}',
          );
          appLogic.iniciarSeguimientoBusTiempoReal(
            idViajeActivo: activeTripState.idViajeActivoConfirmado,
            idTramoBus: nextBusTramo.idTramo,
          );
        } else {
          // Si no hay un próximo tramo de bus identificado, no detener proactivamente
          // para permitir futuros datos; solo loguear.
          print(
            '[ActiveTripOverlay] (CAMINAR) No se detectó próximo tramo de bus para tracking',
          );
        }
        break;
      case TipoTramoViaje.VIAJE_EN_BUS:
        // El usuario está en el bus, cambiar a tracking del usuario
        _switchToUserLocationTracking();
        break;
    }
  }

  // Método para encontrar el próximo tramo de bus después de un tramo de espera
  TramoViajeMostrable? _findNextBusTramo(
    List<TramoViajeMostrable> tramos,
    int currentIndex,
  ) {
    // Buscar el próximo tramo de tipo VIAJE_EN_BUS después del índice actual
    for (int i = currentIndex + 1; i < tramos.length; i++) {
      if (tramos[i].tipo == TipoTramoViaje.VIAJE_EN_BUS) {
        return tramos[i];
      }
    }
    return null;
  }

  void _switchToUserLocationTracking() {
    print('[ActiveTripOverlay] Switching to user location tracking mode');
    // El MapBusRealtime debería cambiar a modo de tracking del usuario
    final mapManager = ref.read(mapManagerProvider);
    if (mapManager != null) {
      // Esto se manejará en la extensión de MapBusRealtime
      mapManager.busRealtime.switchToUserLocationMode();
    }
  }

  // Métodos antiguos de tracking de bus eliminados tras refactorización.

  @override
  Widget build(BuildContext context) {
    final appUiState = ref.watch(appLogicProvider);
    final appLogic = ref.read(appLogicProvider.notifier);
    final activeTripState = appUiState.datosFaseViajeActivo;

    // DIFF: Obtener estado de progreso automático
    final currentJourneyStep = appUiState.currentJourneyStep;
    final currentStepProgress = appUiState.currentStepProgress;
    final isAutomaticNavigationEnabled =
        appUiState.isAutomaticNavigationEnabled;

    // Reaccionar a cambios en el sondeo de bus en tiempo real
    ref.listen<AppUiState>(appLogicProvider, (previous, next) {
      final prevState = previous?.datosFaseViajeActivo;
      final nextState = next.datosFaseViajeActivo;

      // Solo actualizar si cambió la información del bus en tiempo real
      if (prevState?.posicionActualBusReal !=
              nextState?.posicionActualBusReal ||
          prevState?.minutosParaLlegadaBusReal !=
              nextState?.minutosParaLlegadaBusReal ||
          prevState?.seguimientoBusRealDisponibleEnTramoActual !=
              nextState?.seguimientoBusRealDisponibleEnTramoActual) {
        _handleRealtimeBusUpdate(nextState);
      }

      // DIFF: Listener para transiciones automáticas
      // Detectar cambios en el paso del journey automático
      final prevJourneyStep = previous?.currentJourneyStep;
      final nextJourneyStep = next.currentJourneyStep;

      // Detectar transiciones automáticas del step
      if (prevJourneyStep?.stepIndex != nextJourneyStep?.stepIndex &&
          _automaticNavigationEnabled &&
          nextJourneyStep != null) {
        print(
          '[ActiveTripOverlay] Auto step transition detected: ${prevJourneyStep?.stepIndex} → ${nextJourneyStep.stepIndex}',
        );
        _onAutomaticStepTransition(nextJourneyStep.stepIndex);
      }

      // Detectar cambio de modo de navegación automática
      final prevAutoEnabled = previous?.isAutomaticNavigationEnabled ?? false;
      final nextAutoEnabled = next.isAutomaticNavigationEnabled;
      if (prevAutoEnabled != nextAutoEnabled) {
        print(
          '[ActiveTripOverlay] Automatic navigation mode changed: $prevAutoEnabled → $nextAutoEnabled',
        );
        _automaticNavigationEnabled = nextAutoEnabled;
      }
    });

    if (activeTripState == null) {
      return Container(
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.orange),
                  const SizedBox(height: 16),
                  Text(
                    'Error en viaje activo',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed:
                        () => appLogic.usuarioCanceloBusquedaOSeleccionRuta(),
                    child: const Text('Volver al inicio'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Obtener información de línea del tramo actual
    String? effectiveBusLine = _currentBusLine;
    String? effectiveBusDestination = _currentBusDestination;

    if (effectiveBusLine == null && activeTripState.tramosDelViaje.isNotEmpty) {
      final currentSegment = activeTripState.tramosDelViaje[_currentLegIndex];
      if (currentSegment.tipo == TipoTramoViaje.VIAJE_EN_BUS ||
          currentSegment.tipo == TipoTramoViaje.ESPERAR_BUS) {
        effectiveBusLine = currentSegment.nombreLineaBus;
        effectiveBusDestination = currentSegment.destinoFinalDelBus;
        _currentBusLine = effectiveBusLine;
        _currentBusDestination = effectiveBusDestination;
      }
    }

    // Usar datos del sondeo en tiempo real desde el estado si están disponibles
    final realtimeBusPosition = activeTripState.posicionActualBusReal;
    final realtimeBusEta = activeTripState.minutosParaLlegadaBusReal;
    final isRealtimeAvailable =
        activeTripState.seguimientoBusRealDisponibleEnTramoActual;

    return _ActiveTripInstructionsPanel(
      activeTripState: activeTripState,
      appLogic: appLogic,
      currentLegIndex: _currentLegIndex,
      onLegSelected: _onLegSelected,
      // Usar datos del sondeo en tiempo real si están disponibles, sino usar datos locales
      currentBusPosition: realtimeBusPosition ?? _currentBusPosition,
      currentBusEta: realtimeBusEta ?? _currentBusEta,
      currentBusLine: effectiveBusLine,
      isBusEtaRealTime: isRealtimeAvailable,
      currentBusDestination: effectiveBusDestination,
      // DIFF: Pasar datos de progreso automático
      currentJourneyStep: currentJourneyStep,
      currentStepProgress: currentStepProgress,
      isAutomaticNavigationEnabled: isAutomaticNavigationEnabled,
    );
  }

  // Método para reaccionar a cambios en el estado del sondeo de bus
  void _handleRealtimeBusUpdate(EstadoFaseViajeActivo? activeTripState) {
    if (activeTripState == null) return;

    final mapManager = ref.read(mapManagerProvider);
    if (mapManager == null) return;

    // Si hay datos de bus en tiempo real disponibles, actualizar el mapa
    if (activeTripState.seguimientoBusRealDisponibleEnTramoActual &&
        activeTripState.posicionActualBusReal != null &&
        activeTripState.minutosParaLlegadaBusReal != null) {
      print(
        "[ActiveTripOverlay] Updating realtime bus position: ${activeTripState.posicionActualBusReal}",
      );

      // Actualizar la posición del bus en el MapManager
      mapManager.busRealtime.updateBusPosition(
        activeTripState.posicionActualBusReal!,
        activeTripState.minutosParaLlegadaBusReal!,
        true, // Es tiempo real
      );
    }
  }
}

// --- Panel de instrucciones moderno y limpio ---
class _ActiveTripInstructionsPanel extends StatelessWidget {
  final EstadoFaseViajeActivo activeTripState;
  final IAppLogic appLogic;
  final int currentLegIndex;
  final void Function(int) onLegSelected;
  final Coordenada? currentBusPosition;
  final int? currentBusEta;
  final String? currentBusLine;
  final bool isBusEtaRealTime;
  final String? currentBusDestination;
  // DIFF: Nuevos parámetros para progreso automático
  final JourneyStepState? currentJourneyStep;
  final RouteProgress? currentStepProgress;
  final bool isAutomaticNavigationEnabled;

  const _ActiveTripInstructionsPanel({
    required this.activeTripState,
    required this.appLogic,
    required this.currentLegIndex,
    required this.onLegSelected,
    required this.currentBusPosition,
    required this.currentBusEta,
    required this.currentBusLine,
    required this.isBusEtaRealTime,
    required this.currentBusDestination,
    // DIFF: Nuevos parámetros
    this.currentJourneyStep,
    this.currentStepProgress,
    required this.isAutomaticNavigationEnabled,
  });

  @override
  Widget build(BuildContext context) {
    if (activeTripState.tramosDelViaje.isEmpty) {
      return const SizedBox.shrink();
    }

    final TramoViajeMostrable tramoActual =
        activeTripState.tramosDelViaje[currentLegIndex];
    final theme = Theme.of(context);

    return Stack(
      children: [
        // Panel principal compacto en la parte superior
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          right: 12,
          child: _buildMainInstructionCard(context, tramoActual, theme),
        ),

        // Panel de navegación en la parte inferior
        Positioned(
          bottom: 12,
          left: 12,
          right: 12,
          child: _buildNavigationPanel(context, theme),
        ),

        // Botón toggle de animaciones - esquina inferior izquierda
        Positioned(
          bottom: 80, // Arriba del panel de navegación
          left: 16,
          child: _buildAnimationToggleButton(context),
        ),
      ],
    );
  }

  Widget _buildMainInstructionCard(
    BuildContext context,
    TramoViajeMostrable tramo,
    ThemeData theme,
  ) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: theme.colorScheme.surface,
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.08),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header compacto con paso e icono + botón salir
            Row(
              children: [
                // Círculo del paso
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _getInstructionColor(tramo),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _getInstructionColor(tramo).withOpacity(0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getInstructionIcon(tramo),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paso ${currentLegIndex + 1} de ${activeTripState.tramosDelViaje.length}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _getInstructionTitle(tramo),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                          fontSize: 20,
                        ),
                      ),
                      // DIFF: Mostrar indicador de navegación automática
                      if (isAutomaticNavigationEnabled) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.assistant_navigation,
                              size: 12,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Navegación Automática',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Botón salir sutil
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => appLogic.detenerSeguimientoActivo(),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(
                          0.7,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Instrucción principal - más compacta
            Text(
              _getDetailedInstruction(tramo),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                height: 1.25,
                color: theme.colorScheme.onSurface,
                fontSize: 15,
              ),
            ),

            // DIFF: Mostrar instrucciones automáticas si está habilitado
            if (isAutomaticNavigationEnabled && currentJourneyStep != null) ...[
              const SizedBox(height: 6),
              Text(
                _getAutomaticInstructions(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
            ],

            const SizedBox(height: 10),

            // DIFF: Mostrar progreso dinámico si está disponible
            _buildDynamicProgress(context, theme),

            // Chips informativos - más compactos
            _buildAdditionalInfo(context, tramo, theme),
          ],
        ),
      ),
    );
  }

  // DIFF: Nuevo método para mostrar progreso dinámico
  Widget _buildDynamicProgress(BuildContext context, ThemeData theme) {
    // Diseño actualizado: se elimina el panel de progreso porcentual por no aportar valor.
    // Mantener la firma por compatibilidad y devolver vacío.
    return const SizedBox.shrink();
  }

  Widget _buildAdditionalInfo(
    BuildContext context,
    TramoViajeMostrable tramo,
    ThemeData theme,
  ) {
    // Paso ESPERAR_BUS: mostrar datos dinámicos relevantes (línea, ETA en tiempo real y distancia bus→parada)
    if (tramo.tipo == TipoTramoViaje.ESPERAR_BUS) {
      final chips = <Widget>[];

      // Línea de bus (si está disponible en el tramo)
      if (tramo.nombreLineaBus != null) {
        chips.addAll([
          _buildCompactInfoChip(
            icon: Icons.directions_bus,
            label: 'L${tramo.nombreLineaBus}',
            color: Colors.orange.shade600,
            theme: theme,
          ),
          const SizedBox(width: 8),
        ]);
      }

      // ETA en tiempo real (priorizar estado actual; fallback al tramo)
      final int? etaMin = currentBusEta ?? tramo.minutosEstimadosLlegadaBus;
      final bool etaIsRealTime =
          isBusEtaRealTime || (tramo.esTiempoRealBus == true);
      if (etaMin != null) {
        chips.addAll([
          _buildCompactInfoChip(
            icon: etaIsRealTime ? Icons.gps_fixed : Icons.schedule,
            label: '$etaMin min',
            color:
                etaIsRealTime ? Colors.green.shade600 : Colors.orange.shade600,
            theme: theme,
          ),
          const SizedBox(width: 8),
        ]);
      }

      // Distancia bus → parada (dinámica). Si no hay posición de bus, no se muestra
      final double? busDistanceM = _computeBusDistanceToStop(tramo);
      if (busDistanceM != null) {
        chips.add(
          _buildCompactInfoChip(
            icon: Icons.straighten,
            label: _formatMeters(busDistanceM),
            color: Colors.green.shade600,
            theme: theme,
          ),
        );
      }

      return Row(children: chips);
    }

    // Resto de pasos: mantener esquema previo (tiempo del tramo y distancia del tramo si aplica)
    return Row(
      children: [
        _buildCompactInfoChip(
          icon: Icons.access_time,
          label: _formatDuration(tramo.duracionEstimadaSegundos),
          color: Colors.blue.shade600,
          theme: theme,
        ),
        const SizedBox(width: 8),
        if (tramo.distanciaMetros > 0) ...[
          _buildCompactInfoChip(
            icon: Icons.straighten,
            label: '${tramo.distanciaMetros} m',
            color: Colors.green.shade600,
            theme: theme,
          ),
          const SizedBox(width: 8),
        ],
        if (tramo.nombreLineaBus != null) ...[
          _buildCompactInfoChip(
            icon: Icons.directions_bus,
            label: 'L${tramo.nombreLineaBus}',
            color: Colors.orange.shade600,
            theme: theme,
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _buildCompactInfoChip({
    required IconData icon,
    required String label,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // Calcula la distancia actual entre la posición del bus y la parada origen de este tramo de espera.
  // Si no hay posición de bus o no se puede determinar la parada, devuelve null.
  double? _computeBusDistanceToStop(TramoViajeMostrable tramo) {
    if (currentBusPosition == null) return null;

    // Para ESPERAR_BUS, la parada suele venir en posicionPunto; fallback a coordenadasParadaOrigen.
    final stop = tramo.posicionPunto ?? tramo.coordenadasParadaOrigen;
    if (stop == null) return null;

    final d = calculateHaversineDistance(
      currentBusPosition!.latitud,
      currentBusPosition!.longitud,
      stop.latitud,
      stop.longitud,
    );
    return d;
  }

  // Formatea una distancia en metros a una representación amigable (m o km).
  String _formatMeters(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }

  Widget _buildNavigationPanel(BuildContext context, ThemeData theme) {
    // DIFF: Hide manual navigation panel when automatic navigation is enabled
    if (isAutomaticNavigationEnabled) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: Card(
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: theme.colorScheme.surface,
          ),
          child: Column(
            children: [
              // Barra de progreso más sutil
              Container(
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.7),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor:
                      (currentLegIndex + 1) /
                      activeTripState.tramosDelViaje.length,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Botones de navegación
              Row(
                children: [
                  // Botón anterior compacto
                  _buildCompactNavButton(
                    context: context,
                    icon: Icons.chevron_left,
                    enabled: currentLegIndex > 0,
                    onPressed:
                        currentLegIndex > 0
                            ? () => onLegSelected(currentLegIndex - 1)
                            : null,
                    theme: theme,
                    isPrimary: false,
                  ),

                  const SizedBox(width: 12),

                  // Indicador central
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${currentLegIndex + 1} de ${activeTripState.tramosDelViaje.length}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'pasos',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Botón siguiente compacto
                  _buildCompactNavButton(
                    context: context,
                    icon: Icons.chevron_right,
                    enabled:
                        currentLegIndex <
                        activeTripState.tramosDelViaje.length - 1,
                    onPressed:
                        currentLegIndex <
                                activeTripState.tramosDelViaje.length - 1
                            ? () => onLegSelected(currentLegIndex + 1)
                            : null,
                    theme: theme,
                    isPrimary: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactNavButton({
    required BuildContext context,
    required IconData icon,
    required bool enabled,
    required VoidCallback? onPressed,
    required ThemeData theme,
    required bool isPrimary,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color:
                enabled
                    ? (isPrimary
                        ? theme.colorScheme.primary.withOpacity(0.08)
                        : theme.colorScheme.surfaceVariant.withOpacity(0.6))
                    : theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
            border:
                enabled && isPrimary
                    ? Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.25),
                      width: 1,
                    )
                    : null,
          ),
          child: Icon(
            icon,
            color:
                enabled
                    ? (isPrimary
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant)
                    : theme.disabledColor,
            size: 22,
          ),
        ),
      ),
    );
  }

  // Métodos helper para obtener información específica del tramo
  String _getInstructionTitle(TramoViajeMostrable tramo) {
    switch (tramo.tipo) {
      case TipoTramoViaje.CAMINAR:
        return 'Caminar';
      case TipoTramoViaje.ESPERAR_BUS:
        return 'Esperar Bus';
      case TipoTramoViaje.VIAJE_EN_BUS:
        return 'Viaje en Bus';
    }
  }

  IconData _getInstructionIcon(TramoViajeMostrable tramo) {
    switch (tramo.tipo) {
      case TipoTramoViaje.CAMINAR:
        return Icons.directions_walk;
      case TipoTramoViaje.ESPERAR_BUS:
        return Icons.schedule;
      case TipoTramoViaje.VIAJE_EN_BUS:
        return Icons.directions_bus;
    }
  }

  Color _getInstructionColor(TramoViajeMostrable tramo) {
    switch (tramo.tipo) {
      case TipoTramoViaje.CAMINAR:
        return Colors.blue;
      case TipoTramoViaje.ESPERAR_BUS:
        return Colors.orange;
      case TipoTramoViaje.VIAJE_EN_BUS:
        return Colors.green;
    }
  }

  String _getDetailedInstruction(TramoViajeMostrable tramo) {
    switch (tramo.tipo) {
      case TipoTramoViaje.CAMINAR:
        return 'Camina hasta la parada de bus más cercana';
      case TipoTramoViaje.ESPERAR_BUS:
        if (tramo.nombreLineaBus != null) {
          return 'Espera el bus de la línea ${tramo.nombreLineaBus}';
        }
        return 'Espera en la parada hasta que llegue tu bus';
      case TipoTramoViaje.VIAJE_EN_BUS:
        if (tramo.destinoFinalDelBus != null) {
          return 'Sube al bus con destino a ${tramo.destinoFinalDelBus}';
        }
        return 'Viaja en el bus hasta tu parada de destino';
    }
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes;
    if (minutes < 1) return "< 1 min";
    return '$minutes min';
  }

  // DIFF: Nuevo método para instrucciones automáticas
  String _getAutomaticInstructions() {
    if (currentJourneyStep == null) return '';

    switch (currentJourneyStep!.type) {
      case JourneyStepType.WALKING_TO_STOP:
        return 'Te guiaremos automáticamente hasta la parada de bus';
      case JourneyStepType.WAITING_FOR_BUS:
        return 'Detectaremos automáticamente cuando subas al bus';
      case JourneyStepType.RIDING_BUS:
        return 'Te avisaremos automáticamente cuando llegar tu parada';
      case JourneyStepType.WALKING_TO_DESTINATION:
        return 'Te guiaremos automáticamente hasta tu destino final';
    }
  }

  // DIFF: Botón para toggle de animaciones
  Widget _buildAnimationToggleButton(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final appLogic = ref.read(appLogicProvider.notifier);
        final animationsEnabled = appLogic.animationsEnabled;

        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: animationsEnabled ? Colors.blue : Colors.grey[600],
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                appLogic.toggleAnimations();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      animationsEnabled
                          ? 'Animaciones desactivadas'
                          : 'Animaciones activadas',
                    ),
                    duration: const Duration(seconds: 2),
                    backgroundColor:
                        animationsEnabled ? Colors.red : Colors.green,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(28),
              child: Center(
                child: Icon(
                  animationsEnabled
                      ? Icons.animation
                      : Icons.animation_outlined,
                  size: 28,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
