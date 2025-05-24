import 'dart:async';
import 'dart:convert';
import 'dart:math' show sin, pi;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:bondi_uy/backend/providers/app_logic_provider.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import 'package:bondi_uy/ui/widgets/bus_tooltip_widget.dart';
import 'package:bondi_uy/utils/geometry_utils.dart';
import 'package:bondi_uy/map_manager/map_manager.dart';
import 'package:bondi_uy/ui/app_host.dart'; // Para acceder al mapManagerProvider

class ActiveTripOverlay extends ConsumerStatefulWidget {
  final MapboxMap? mapboxMap;

  const ActiveTripOverlay({super.key, required this.mapboxMap});

  @override
  ConsumerState<ActiveTripOverlay> createState() => _ActiveTripOverlayState();
}

class _ActiveTripOverlayState extends ConsumerState<ActiveTripOverlay> {
  int _currentLegIndex = 0;
  bool _isAutoZoomEnabled = true;
  bool _followUserLocation = true;
  List<String> _activeRouteSourceIds = [];
  List<String> _activeRouteLayerIds = [];
  bool _iconsLoaded = false; // Para controlar la carga de iconos

  // Sistema de animación de flechas
  Timer? _arrowAnimationTimer;
  double _arrowAnimationPhase = 0.0;
  List<String> _animatedArrowLayerIds = [];

  // Sistema de bus en tiempo real
  Timer? _busTrackingTimer;
  String? _currentBusLine;
  String? _currentBusDestination;
  Coordenada? _currentBusPosition;
  int? _currentBusEta;
  bool? _currentBusIsRealTime;

  // Constantes para IDs de capas y fuentes de la ruta activa
  static const String ACTIVE_WALK_SOURCE_PREFIX = 'active-walk-source-';
  static const String ACTIVE_WALK_LAYER_PREFIX = 'active-walk-layer-';
  static const String ACTIVE_BUS_SOURCE_PREFIX = 'active-bus-source-';
  static const String ACTIVE_BUS_LAYER_PREFIX = 'active-bus-layer-';
  static const String ACTIVE_WAIT_SOURCE_PREFIX = 'active-wait-source-';
  static const String ACTIVE_WAIT_LAYER_PREFIX = 'active-wait-layer-';
  static const String USER_LOCATION_SOURCE_ID = 'user-location-source';
  static const String USER_LOCATION_LAYER_ID = 'user-location-layer';

  // Constantes para iconos
  static const String STOP_ICON_IMAGE_ID = 'stop-icon';
  static const String BUS_ICON_IMAGE_ID = 'bus-icon';
  static const String INCOMING_BUS_SOURCE_ID = 'incoming-bus-source';
  static const String INCOMING_BUS_LAYER_ID = 'incoming-bus-layer';
  static const String BUS_APPROACH_LINE_SOURCE_ID = 'bus-approach-line-source';
  static const String BUS_APPROACH_LINE_LAYER_ID = 'bus-approach-line-layer';

  // Constantes para el bus en tiempo real
  static const String _realtimeBusLayerId = "realtime-bus-layer";
  static const String _realtimeBusSourceId = "realtime-bus-source";
  static const String _busApproachLineLayerId = "bus-approach-line-layer";
  static const String _busApproachLineBorderLayerId =
      "bus-approach-line-border-layer";
  static const String _busApproachLineSourceId = "bus-approach-line-source";

  // Constantes para el tooltip de "Voy en camino!"
  static const String _busTooltipLayerId = "bus-tooltip-layer";
  static const String _busTooltipIconId = "incoming-bus-tooltip";

  // Variables para la animación del tooltip flotante
  Timer? _tooltipFloatTimer;
  double _tooltipFloatPhase = 0.0;
  double _lastTooltipOffset =
      -5.0; // Offset base para posicionar arriba del bus (ajustado para estar más cerca)

  // Propiedades de estilo
  static const Map<String, dynamic> _WALK_LINE_PROPERTIES = {
    'line-color': 0xFF448AFF,
    'line-width': 4.0,
    'line-opacity': 0.9,
    'line-join': 'round',
    'line-cap': 'round',
  };
  static const Map<String, dynamic> _BUS_LINE_PROPERTIES = {
    'line-color': 0xFFFF5722,
    'line-width': 5.0,
    'line-opacity': 0.9,
    'line-join': 'round',
    'line-cap': 'round',
  };
  static const Map<String, dynamic> _WAIT_CIRCLE_PROPERTIES = {
    'circle-color': 0xFFFFA500,
    'circle-radius': 8.0,
    'circle-stroke-width': 2.0,
    'circle-stroke-color': 0xFFFFFFFF,
    'circle-opacity': 0.9,
  };
  static const Map<String, dynamic> _BORDER_PROPERTIES = {
    'line-color': 0xFF000000,
    'line-width': 8.0,
    'line-opacity': 1.0,
    'line-join': 'round',
    'line-cap': 'round',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeActiveTrip();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _clearPreviousRoutePreview() async {
    if (widget.mapboxMap == null) return;

    print("[ActiveTripOverlay] Clearing previous route preview elements");

    // Limpiar capas de route preview que podrían estar presentes de RouteOptionsOverlay
    final previewLayerIds = [
      // Preview layers de route options
      'route-preview-walk-border',
      'route-preview-walk',
      'route-preview-bus-border',
      'route-preview-bus',
      'route-preview-wait',
      'route-preview-boarding',
      'route-preview-alighting',
      // Bus real-time layers de preview
      'preview-bus-realtime',
      'preview-bus-approach-line',
      'preview-bus-approach-line-border',
      'preview-bus-tooltip',
      // Animated arrow layers
      'preview-bus-stop-boarding-0',
      'preview-bus-stop-alighting-0',
      'preview-bus-stop-boarding-1',
      'preview-bus-stop-alighting-1',
      'preview-bus-stop-boarding-2',
      'preview-bus-stop-alighting-2',
      'preview-bus-stop-boarding-3',
      'preview-bus-stop-alighting-3',
      'preview-bus-stop-boarding-4',
      'preview-bus-stop-alighting-4',
    ];

    final previewSourceIds = [
      // Preview sources de route options
      'route-preview-walk-source',
      'route-preview-bus-source',
      'route-preview-wait-source',
      'route-preview-boarding-source',
      'route-preview-alighting-source',
      // Bus real-time sources de preview
      'preview-bus-realtime-source',
      'preview-bus-approach-line-source',
      'preview-bus-tooltip-source',
      // Animated arrow sources
      'preview-bus-stop-boarding-source-0',
      'preview-bus-stop-alighting-source-0',
      'preview-bus-stop-boarding-source-1',
      'preview-bus-stop-alighting-source-1',
      'preview-bus-stop-boarding-source-2',
      'preview-bus-stop-alighting-source-2',
      'preview-bus-stop-boarding-source-3',
      'preview-bus-stop-alighting-source-3',
      'preview-bus-stop-boarding-source-4',
      'preview-bus-stop-alighting-source-4',
    ];

    // Limpiar capas
    for (String layerId in previewLayerIds) {
      try {
        if (await widget.mapboxMap!.style.styleLayerExists(layerId)) {
          await widget.mapboxMap!.style.removeStyleLayer(layerId);
          print("[ActiveTripOverlay] Removed preview layer: $layerId");
        }
      } catch (e) {
        print("[ActiveTripOverlay] Error removing preview layer $layerId: $e");
      }
    }

    // Limpiar fuentes
    for (String sourceId in previewSourceIds) {
      try {
        if (await widget.mapboxMap!.style.styleSourceExists(sourceId)) {
          await widget.mapboxMap!.style.removeStyleSource(sourceId);
          print("[ActiveTripOverlay] Removed preview source: $sourceId");
        }
      } catch (e) {
        print(
          "[ActiveTripOverlay] Error removing preview source $sourceId: $e",
        );
      }
    }

    print("[ActiveTripOverlay] Finished clearing route preview elements");
  }

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

        // Iniciar tracking del próximo tramo de bus basado en el paso actual
        _updateBusTrackingForCurrentLeg();
      } catch (e) {
        print("[ActiveTripOverlay] Error initializing active trip: $e");
      }
    }

    print("[ActiveTripOverlay] Active trip initialization complete");
  }

  Future<void> _loadMapIcons() async {
    if (widget.mapboxMap == null || _iconsLoaded) return;

    try {
      // Cargar icono de parada
      final MbxImage stopImage = await _loadIconImageFromAsset('stop_icon.png');
      await widget.mapboxMap!.style.addStyleImage(
        STOP_ICON_IMAGE_ID,
        1.0,
        stopImage,
        false,
        [],
        [],
        null,
      );

      // Cargar icono de bus
      final MbxImage busImage = await _loadIconImageFromAsset(
        'incoming_bus.png',
      );
      await widget.mapboxMap!.style.addStyleImage(
        BUS_ICON_IMAGE_ID,
        1.0,
        busImage,
        false,
        [],
        [],
        null,
      );

      _iconsLoaded = true;
      print("[ActiveTripOverlay] Icons loaded successfully");
    } catch (e) {
      print("[ActiveTripOverlay] Error loading icons: $e");
    }
  }

  Future<MbxImage> _loadIconImageFromAsset(String assetName) async {
    final ByteData data = await rootBundle.load('assets/icons/$assetName');
    final Uint8List bytes = data.buffer.asUint8List();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image image = frameInfo.image;

    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (byteData == null) {
      throw Exception('Failed to encode image to PNG');
    }

    final Uint8List pngBytes = byteData.buffer.asUint8List();
    return MbxImage(width: image.width, height: image.height, data: pngBytes);
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

    // Actualizar el bus tracking basado en el nuevo tramo seleccionado
    _updateBusTrackingForCurrentLeg();
  }

  void _updateBusTrackingForCurrentLeg() {
    final activeTripState = ref.read(appLogicProvider).datosFaseViajeActivo;
    if (activeTripState == null || activeTripState.tramosDelViaje.isEmpty) {
      _stopBusTracking();
      return;
    }

    final tramosDelViaje = activeTripState.tramosDelViaje;
    final tramoActual = tramosDelViaje[_currentLegIndex];

    print(
      "[ActiveTripOverlay] Updating bus tracking for leg $_currentLegIndex: ${tramoActual.tipo}",
    );

    // Determinar cuál es el próximo tramo de bus que necesitamos trackear
    TramoViajeMostrable? proximoTramoBus = _findNextBusSegment(
      tramosDelViaje,
      _currentLegIndex,
    );

    if (proximoTramoBus != null) {
      print(
        "[ActiveTripOverlay] Next bus segment found: line=${proximoTramoBus.nombreLineaBus}, type=${proximoTramoBus.tipo}",
      );
      _startBusTracking(proximoTramoBus);

      // Si el tramo ya tiene información de bus, mostrarla inmediatamente
      if (proximoTramoBus.posicionActualBus != null) {
        _updateBusPosition(
          proximoTramoBus.posicionActualBus!,
          proximoTramoBus.minutosEstimadosLlegadaBus ?? 0,
          proximoTramoBus.esTiempoRealBus ?? false,
        );
      }
    } else {
      print(
        "[ActiveTripOverlay] No more bus segments to track, stopping bus tracking",
      );
      _stopBusTracking();
    }
  }

  TramoViajeMostrable? _findNextBusSegment(
    List<TramoViajeMostrable> tramos,
    int currentLegIndex,
  ) {
    final tramoActual = tramos[currentLegIndex];

    // Lógica para determinar el próximo tramo de bus a trackear
    switch (tramoActual.tipo) {
      case TipoTramoViaje.CAMINAR:
        // Si estoy caminando, buscar el siguiente tramo de bus
        for (int i = currentLegIndex + 1; i < tramos.length; i++) {
          final tramo = tramos[i];
          if (tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS ||
              tramo.tipo == TipoTramoViaje.ESPERAR_BUS) {
            print(
              "[ActiveTripOverlay] Walking phase: found next bus at index $i",
            );
            return tramo;
          }
        }
        break;

      case TipoTramoViaje.ESPERAR_BUS:
        // Si estoy esperando el bus, trackear el bus actual (el que estoy esperando)
        print("[ActiveTripOverlay] Waiting phase: tracking current bus");
        return tramoActual;

      case TipoTramoViaje.VIAJE_EN_BUS:
        // Si ya estoy EN el bus viajando, buscar el siguiente tramo de bus (transbordo)
        for (int i = currentLegIndex + 1; i < tramos.length; i++) {
          final tramo = tramos[i];
          if (tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS ||
              tramo.tipo == TipoTramoViaje.ESPERAR_BUS) {
            print(
              "[ActiveTripOverlay] On bus phase: found next transfer bus at index $i",
            );
            return tramo;
          }
        }
        // Si no hay más buses, esto significa que estoy en el último/único bus
        print(
          "[ActiveTripOverlay] On bus phase: this is the last bus, no more tracking needed",
        );
        return null;
    }

    print("[ActiveTripOverlay] No next bus segment found");
    return null;
  }

  void _startBusTracking(TramoViajeMostrable tramo) {
    if (tramo.tipo != TipoTramoViaje.VIAJE_EN_BUS &&
        tramo.tipo != TipoTramoViaje.ESPERAR_BUS)
      return;

    _currentBusLine = tramo.nombreLineaBus;
    _currentBusDestination = tramo.destinoFinalDelBus;

    // Obtener información inicial del bus si está disponible
    if (tramo.posicionActualBus != null) {
      _updateBusPosition(
        tramo.posicionActualBus!,
        tramo.minutosEstimadosLlegadaBus ?? 0,
        tramo.esTiempoRealBus ?? false,
      );
    }

    print(
      "[ActiveTripOverlay] Bus tracking started for line: $_currentBusLine (type: ${tramo.tipo})",
    );
  }

  void _stopBusTracking() {
    // Limpiar estado del bus tracking
    _currentBusPosition = null;
    _currentBusEta = null;
    _currentBusIsRealTime = null;
    _currentBusLine = null;
    _currentBusDestination = null;

    // TODO: Implementar limpieza del display del bus cuando esté disponible en MapManager
    // Por ahora solo limpiamos el estado local

    print("[ActiveTripOverlay] Bus tracking stopped");
  }

  Future<void> _updateBusPosition(
    Coordenada position,
    int etaMinutes,
    bool isRealTime,
  ) async {
    _currentBusPosition = position;
    _currentBusEta = etaMinutes;
    _currentBusIsRealTime = isRealTime;

    // TODO: Implementar display del bus cuando esté disponible en MapManager
    // Por ahora solo actualizamos el estado local

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appUiState = ref.watch(appLogicProvider);
    final appLogic = ref.read(appLogicProvider.notifier);
    final activeTripState = appUiState.datosFaseViajeActivo;

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

    return _ActiveTripInstructionsPanel(
      activeTripState: activeTripState,
      appLogic: appLogic,
      currentLegIndex: _currentLegIndex,
      onLegSelected: _onLegSelected,
      // Usar datos efectivos (del estado o locales)
      currentBusPosition: _currentBusPosition,
      currentBusEta: _currentBusEta,
      currentBusLine: effectiveBusLine,
      isBusEtaRealTime: _currentBusIsRealTime ?? false,
      currentBusDestination: effectiveBusDestination,
    );
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

            const SizedBox(height: 10),

            // Chips informativos - más compactos
            _buildAdditionalInfo(context, tramo, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalInfo(
    BuildContext context,
    TramoViajeMostrable tramo,
    ThemeData theme,
  ) {
    return Row(
      children: [
        // Tiempo
        _buildCompactInfoChip(
          icon: Icons.access_time,
          label: _formatDuration(tramo.duracionEstimadaSegundos),
          color: Colors.blue.shade600,
          theme: theme,
        ),

        const SizedBox(width: 8),

        // Distancia
        if (tramo.distanciaMetros > 0) ...[
          _buildCompactInfoChip(
            icon: Icons.straighten,
            label: '${tramo.distanciaMetros} m',
            color: Colors.green.shade600,
            theme: theme,
          ),
          const SizedBox(width: 8),
        ],

        // Línea de bus
        if (tramo.nombreLineaBus != null) ...[
          _buildCompactInfoChip(
            icon: Icons.directions_bus,
            label: 'L${tramo.nombreLineaBus}',
            color: Colors.orange.shade600,
            theme: theme,
          ),
          const SizedBox(width: 8),
        ],

        // ETA del bus
        if (tramo.minutosEstimadosLlegadaBus != null)
          _buildCompactInfoChip(
            icon:
                tramo.esTiempoRealBus == true
                    ? Icons.gps_fixed
                    : Icons.schedule,
            label: '${tramo.minutosEstimadosLlegadaBus}min',
            color:
                tramo.esTiempoRealBus == true
                    ? Colors.green.shade600
                    : Colors.orange.shade600,
            theme: theme,
          ),
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

  Widget _buildNavigationPanel(BuildContext context, ThemeData theme) {
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
      default:
        return 'Paso';
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
      default:
        return Icons.help_outline;
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
      default:
        return Colors.grey;
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
      default:
        return tramo.descripcion;
    }
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes;
    if (minutes < 1) return "< 1 min";
    return '$minutes min';
  }
}
