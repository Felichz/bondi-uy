import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:bondi_uy/backend/providers/app_logic_provider.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';

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
      _clearPreviousRoutePreview();
      _initializeActiveTrip();
      _hideCityLabels();
    });
  }

  @override
  void dispose() {
    _stopArrowAnimation();
    _clearActiveRoute().catchError((e) {
      print("[ActiveTripOverlay] Error clearing route on dispose: $e");
    });
    super.dispose();
  }

  Future<void> _clearPreviousRoutePreview() async {
    if (widget.mapboxMap == null) return;

    // Limpiar capas de route preview que podrían estar presentes
    final previewLayerIds = [
      'route-preview-walk-border',
      'route-preview-walk',
      'route-preview-bus-border',
      'route-preview-bus',
      'route-preview-wait',
      'route-preview-boarding',
      'route-preview-alighting',
    ];

    final previewSourceIds = [
      'route-preview-walk-source',
      'route-preview-bus-source',
      'route-preview-wait-source',
      'route-preview-boarding-source',
      'route-preview-alighting-source',
    ];

    for (String layerId in previewLayerIds) {
      try {
        if (await widget.mapboxMap!.style.styleLayerExists(layerId)) {
          await widget.mapboxMap!.style.removeStyleLayer(layerId);
        }
      } catch (e) {
        print("Error removing preview layer $layerId: $e");
      }
    }

    for (String sourceId in previewSourceIds) {
      try {
        if (await widget.mapboxMap!.style.styleSourceExists(sourceId)) {
          await widget.mapboxMap!.style.removeStyleSource(sourceId);
        }
      } catch (e) {
        print("Error removing preview source $sourceId: $e");
      }
    }
  }

  Future<void> _initializeActiveTrip() async {
    if (widget.mapboxMap == null) return;

    // Cargar iconos primero
    await _loadMapIcons();

    final activeTripState = ref.read(appLogicProvider).datosFaseViajeActivo;
    if (activeTripState != null && activeTripState.tramosDelViaje.isNotEmpty) {
      await _displayActiveRoute(activeTripState.tramosDelViaje);
      await _highlightCurrentLegOnMap(_currentLegIndex);

      // Zoom inicial al primer tramo específicamente
      await _zoomToCurrentLeg(_currentLegIndex);
    }
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
    _highlightCurrentLegOnMap(legIndex);
    _zoomToCurrentLeg(legIndex);
  }

  Future<void> _zoomToCurrentLeg(int legIndex) async {
    if (widget.mapboxMap == null) return;
    final activeTripState = ref.read(appLogicProvider).datosFaseViajeActivo;
    if (activeTripState == null ||
        legIndex >= activeTripState.tramosDelViaje.length)
      return;

    final tramo = activeTripState.tramosDelViaje[legIndex];

    try {
      if (tramo.geometriaPolilinea != null &&
          tramo.geometriaPolilinea!.isNotEmpty) {
        final coordinates = tramo.geometriaPolilinea!;
        final mapboxPoints =
            coordinates
                .map((c) => Point(coordinates: Position(c.longitud, c.latitud)))
                .toList();

        final cameraOptions = await widget.mapboxMap!.cameraForCoordinates(
          mapboxPoints,
          MbxEdgeInsets(
            top: 250.0,
            left: 40.0,
            bottom: MediaQuery.of(context).size.height * 0.25,
            right: 40.0,
          ),
          null,
          null,
        );

        await widget.mapboxMap!.flyTo(
          cameraOptions,
          MapAnimationOptions(duration: 800),
        );
      } else if (tramo.posicionPunto != null) {
        final punto = tramo.posicionPunto!;
        await widget.mapboxMap!.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(punto.longitud, punto.latitud)),
            zoom: 16.0,
          ),
          MapAnimationOptions(duration: 800),
        );
      }
    } catch (e) {
      print("[ActiveTripOverlay] Error zooming to current leg: $e");
    }
  }

  Future<void> _highlightCurrentLegOnMap(int legIndex) async {
    if (widget.mapboxMap == null) return;
    final activeTripState = ref.read(appLogicProvider).datosFaseViajeActivo;
    if (activeTripState == null) return;

    for (int i = 0; i < activeTripState.tramosDelViaje.length; i++) {
      final tramo = activeTripState.tramosDelViaje[i];
      bool isCurrent = i == legIndex;
      String layerId;
      double? lineWidth;
      double? circleRadius;

      switch (tramo.tipo) {
        case TipoTramoViaje.CAMINAR:
          layerId = '$ACTIVE_WALK_LAYER_PREFIX$i';
          lineWidth = isCurrent ? 6.0 : 4.0;
          break;
        case TipoTramoViaje.VIAJE_EN_BUS:
          layerId = '$ACTIVE_BUS_LAYER_PREFIX$i';
          lineWidth = isCurrent ? 7.0 : 5.0;
          break;
        case TipoTramoViaje.ESPERAR_BUS:
          layerId = '$ACTIVE_WAIT_LAYER_PREFIX$i';
          circleRadius = isCurrent ? 10.0 : 8.0;
          break;
        default:
          continue;
      }

      try {
        if (await widget.mapboxMap?.style.styleLayerExists(layerId) ?? false) {
          switch (tramo.tipo) {
            case TipoTramoViaje.CAMINAR:
            case TipoTramoViaje.VIAJE_EN_BUS:
              if (lineWidth != null) {
                await widget.mapboxMap?.style.setStyleLayerProperty(
                  layerId,
                  'line-width',
                  lineWidth,
                );
              }
              break;
            case TipoTramoViaje.ESPERAR_BUS:
              if (circleRadius != null) {
                await widget.mapboxMap?.style.setStyleLayerProperty(
                  layerId,
                  'circle-radius',
                  circleRadius,
                );
              }
              break;
          }
        }
      } catch (e) {
        print('Error setting layer properties for $layerId: $e');
      }
    }
  }

  Future<void> _displayActiveRoute(List<TramoViajeMostrable> tramos) async {
    if (widget.mapboxMap == null) return;
    await _clearActiveRoute();

    // PASO 1: Agregar todas las líneas y puntos primero
    for (int i = 0; i < tramos.length; i++) {
      final tramo = tramos[i];

      switch (tramo.tipo) {
        case TipoTramoViaje.CAMINAR:
          await _drawWalkSegment(tramo, i);
          break;
        case TipoTramoViaje.VIAJE_EN_BUS:
          await _drawBusSegment(tramo, i);
          break;
        case TipoTramoViaje.ESPERAR_BUS:
          await _drawWaitPoint(tramo, i);
          break;
      }
    }

    // PASO 2: Agregar todas las paradas de bus al final (para que aparezcan encima)
    for (int i = 0; i < tramos.length; i++) {
      final tramo = tramos[i];
      if (tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS) {
        await _addBusStopsForSegment(tramo, i);
      }
    }

    // PASO 3: Iniciar animación de flechas
    _startArrowAnimation();
  }

  Future<void> _drawWalkSegment(TramoViajeMostrable tramo, int index) async {
    if (tramo.geometriaPolilinea == null || tramo.geometriaPolilinea!.isEmpty)
      return;

    final sourceId = '$ACTIVE_WALK_SOURCE_PREFIX$index';
    final shadowLayerId = '$ACTIVE_WALK_LAYER_PREFIX$index-shadow';
    final mainLayerId = '$ACTIVE_WALK_LAYER_PREFIX$index';

    final geoJsonFeature = {
      "type": "Feature",
      "geometry": {
        "type": "LineString",
        "coordinates":
            tramo.geometriaPolilinea!
                .map((c) => [c.longitud, c.latitud])
                .toList(),
      },
    };

    await widget.mapboxMap!.style.addSource(
      GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)),
    );
    _activeRouteSourceIds.add(sourceId);

    // Borde
    await widget.mapboxMap!.style.addLayer(
      LineLayer(
        id: shadowLayerId,
        sourceId: sourceId,
        lineColor: _BORDER_PROPERTIES['line-color'] as int,
        lineWidth: (_BORDER_PROPERTIES['line-width'] as num).toDouble(),
        lineOpacity: (_BORDER_PROPERTIES['line-opacity'] as num).toDouble(),
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      ),
    );
    _activeRouteLayerIds.add(shadowLayerId);

    // Línea principal
    await widget.mapboxMap!.style.addLayer(
      LineLayer(
        id: mainLayerId,
        sourceId: sourceId,
        lineColor: _WALK_LINE_PROPERTIES['line-color'] as int,
        lineWidth: (_WALK_LINE_PROPERTIES['line-width'] as num).toDouble(),
        lineOpacity: (_WALK_LINE_PROPERTIES['line-opacity'] as num).toDouble(),
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      ),
    );
    _activeRouteLayerIds.add(mainLayerId);
  }

  Future<void> _drawBusSegment(TramoViajeMostrable tramo, int index) async {
    if (tramo.geometriaPolilinea == null || tramo.geometriaPolilinea!.isEmpty)
      return;

    final sourceId = '$ACTIVE_BUS_SOURCE_PREFIX$index';
    final shadowLayerId = '$ACTIVE_BUS_LAYER_PREFIX$index-shadow';
    final mainLayerId = '$ACTIVE_BUS_LAYER_PREFIX$index';

    final geoJsonFeature = {
      "type": "Feature",
      "geometry": {
        "type": "LineString",
        "coordinates":
            tramo.geometriaPolilinea!
                .map((c) => [c.longitud, c.latitud])
                .toList(),
      },
    };

    await widget.mapboxMap!.style.addSource(
      GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)),
    );
    _activeRouteSourceIds.add(sourceId);

    // Borde
    await widget.mapboxMap!.style.addLayer(
      LineLayer(
        id: shadowLayerId,
        sourceId: sourceId,
        lineColor: _BORDER_PROPERTIES['line-color'] as int,
        lineWidth: (_BORDER_PROPERTIES['line-width'] as num).toDouble(),
        lineOpacity: (_BORDER_PROPERTIES['line-opacity'] as num).toDouble(),
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      ),
    );
    _activeRouteLayerIds.add(shadowLayerId);

    // Línea principal
    await widget.mapboxMap!.style.addLayer(
      LineLayer(
        id: mainLayerId,
        sourceId: sourceId,
        lineColor: _BUS_LINE_PROPERTIES['line-color'] as int,
        lineWidth: (_BUS_LINE_PROPERTIES['line-width'] as num).toDouble(),
        lineOpacity: (_BUS_LINE_PROPERTIES['line-opacity'] as num).toDouble(),
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      ),
    );
    _activeRouteLayerIds.add(mainLayerId);
  }

  Future<void> _drawWaitPoint(TramoViajeMostrable tramo, int index) async {
    if (tramo.posicionPunto == null) return;

    final sourceId = '$ACTIVE_WAIT_SOURCE_PREFIX$index';
    final layerId = '$ACTIVE_WAIT_LAYER_PREFIX$index';

    final geoJsonFeature = {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [
          tramo.posicionPunto!.longitud,
          tramo.posicionPunto!.latitud,
        ],
      },
    };

    await widget.mapboxMap!.style.addSource(
      GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)),
    );
    _activeRouteSourceIds.add(sourceId);

    await widget.mapboxMap!.style.addLayer(
      CircleLayer(
        id: layerId,
        sourceId: sourceId,
        circleColor: _WAIT_CIRCLE_PROPERTIES['circle-color'] as int,
        circleRadius:
            (_WAIT_CIRCLE_PROPERTIES['circle-radius'] as num).toDouble(),
        circleStrokeWidth:
            (_WAIT_CIRCLE_PROPERTIES['circle-stroke-width'] as num).toDouble(),
        circleStrokeColor:
            _WAIT_CIRCLE_PROPERTIES['circle-stroke-color'] as int,
        circleOpacity:
            (_WAIT_CIRCLE_PROPERTIES['circle-opacity'] as num).toDouble(),
      ),
    );
    _activeRouteLayerIds.add(layerId);
  }

  Future<void> _addBusStopsForSegment(
    TramoViajeMostrable tramo,
    int index,
  ) async {
    if (!_iconsLoaded ||
        tramo.geometriaPolilinea == null ||
        tramo.geometriaPolilinea!.isEmpty) {
      return;
    }

    final coordenadas = tramo.geometriaPolilinea!;

    // Parada de origen (primer punto del tramo de bus)
    final origen = coordenadas.first;
    await _addBusStopMarker(
      'active-bus-origin-$index',
      'active-bus-origin-layer-$index',
      origen.latitud,
      origen.longitud,
      'Subir al bus', // Verde ↑
    );

    // Parada de destino (último punto del tramo de bus)
    final destino = coordenadas.last;
    await _addBusStopMarker(
      'active-bus-destination-$index',
      'active-bus-destination-layer-$index',
      destino.latitud,
      destino.longitud,
      'Bajar del bus', // Rojo ↓
    );
  }

  Future<void> _addBusStopMarker(
    String sourceId,
    String layerId,
    double lat,
    double lng,
    String label,
  ) async {
    if (widget.mapboxMap == null || !_iconsLoaded) return;

    // Crear fuente del marcador
    final geoJsonSource = GeoJsonSource(
      id: sourceId,
      data: jsonEncode({
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [lng, lat],
        },
        "properties": {"label": label, "isBoarding": label.contains('Subir')},
      }),
    );

    await widget.mapboxMap!.style.addSource(geoJsonSource);
    _activeRouteSourceIds.add(sourceId);

    // Usar el icono de parada igual que en RouteOptionsOverlay
    final symbolLayer = SymbolLayer(
      id: layerId,
      sourceId: sourceId,
      iconImage: STOP_ICON_IMAGE_ID, // Usar el icono stop_icon.png
      iconAllowOverlap: true,
      iconSize: 0.5, // Ligeramente más grande que las paradas normales (0.4)
      textField:
          label.contains('Subir') ? '↑' : '↓', // Flechas para subir/bajar
      textColor:
          label.contains('Subir')
              ? 0xFF4CAF50
              : 0xFFF44336, // Verde para subir, rojo para bajar
      textSize: 28, // Más grande para mejor visibilidad y animación
      textOffset:
          label.contains('Subir')
              ? [0.0, -1.25]
              : [0.0, 1.25], // Subir arriba (-), bajar abajo (+)
      textHaloColor: 0xFF000000,
      textHaloWidth: 1.2, // Halo más grueso para mejor contraste
      textAllowOverlap: true, // Permitir overlap para asegurar visibilidad
    );

    await widget.mapboxMap!.style.addLayer(symbolLayer);
    _activeRouteLayerIds.add(layerId);

    // Agregar a la lista de capas animadas
    _animatedArrowLayerIds.add(layerId);
  }

  Future<void> _zoomToRouteBounds(List<Coordenada> routeCoordinates) async {
    if (widget.mapboxMap == null || routeCoordinates.isEmpty) return;

    try {
      final mapboxPoints =
          routeCoordinates
              .map((c) => Point(coordinates: Position(c.longitud, c.latitud)))
              .toList();

      final cameraOptions = await widget.mapboxMap!.cameraForCoordinates(
        mapboxPoints,
        MbxEdgeInsets(
          top: 180.0,
          left: 40.0,
          bottom: MediaQuery.of(context).size.height * 0.25,
          right: 40.0,
        ),
        null,
        null,
      );

      await widget.mapboxMap!.flyTo(
        cameraOptions,
        MapAnimationOptions(duration: 1200),
      );
    } catch (e) {
      print("[ActiveTripOverlay] Error zooming to route bounds: $e");
    }
  }

  Future<void> _clearActiveRoute() async {
    if (widget.mapboxMap == null) return;

    // Detener animación
    _stopArrowAnimation();
    _animatedArrowLayerIds.clear();

    final layerIdsCopy = List<String>.from(_activeRouteLayerIds);
    final sourceIdsCopy = List<String>.from(_activeRouteSourceIds);

    for (String layerId in layerIdsCopy) {
      try {
        if (await widget.mapboxMap!.style.styleLayerExists(layerId)) {
          await widget.mapboxMap!.style.removeStyleLayer(layerId);
        }
      } catch (e) {
        print("Error removing layer $layerId: $e");
      }
    }
    for (String sourceId in sourceIdsCopy) {
      try {
        if (await widget.mapboxMap!.style.styleSourceExists(sourceId)) {
          await widget.mapboxMap!.style.removeStyleSource(sourceId);
        }
      } catch (e) {
        print("Error removing source $sourceId: $e");
      }
    }
    _activeRouteLayerIds.clear();
    _activeRouteSourceIds.clear();
  }

  Future<void> _hideCityLabels() async {
    if (widget.mapboxMap == null) return;

    try {
      // Intentar ocultar diferentes tipos de labels que pueden interferir
      final labelLayerIds = [
        'settlement-major-label',
        'settlement-minor-label',
        'state-label',
        'country-label',
        'place-city-large-s',
        'place-city-medium-s',
        'place-city-small-s',
        'admin-1-boundary-label',
        'admin-0-boundary-label',
      ];

      for (String layerId in labelLayerIds) {
        try {
          if (await widget.mapboxMap!.style.styleLayerExists(layerId)) {
            await widget.mapboxMap!.style.setStyleLayerProperty(
              layerId,
              'visibility',
              'none',
            );
            print("[ActiveTripOverlay] Hidden city label layer: $layerId");
          }
        } catch (e) {
          // Continuar con el siguiente layer si este falla
          print("[ActiveTripOverlay] Could not hide layer $layerId: $e");
        }
      }
    } catch (e) {
      print("[ActiveTripOverlay] Error hiding city labels: $e");
    }
  }

  void _startArrowAnimation() {
    _stopArrowAnimation(); // Asegurar que no hay timer previo

    _arrowAnimationTimer = Timer.periodic(
      const Duration(milliseconds: 100), // 100ms para animación suave
      (timer) => _updateArrowAnimation(),
    );
  }

  void _stopArrowAnimation() {
    _arrowAnimationTimer?.cancel();
    _arrowAnimationTimer = null;
  }

  Future<void> _updateArrowAnimation() async {
    if (widget.mapboxMap == null || _animatedArrowLayerIds.isEmpty) return;

    _arrowAnimationPhase += 0.15; // Velocidad más lenta para mejor fluidez
    if (_arrowAnimationPhase > 2 * 3.14159) {
      _arrowAnimationPhase -= 2 * 3.14159; // Reset cada ciclo completo
    }

    // Calcular offset flotante más sutil (seno para movimiento suave)
    final floatOffset =
        (sin(_arrowAnimationPhase) * 0.15); // Amplitud reducida de 0.3 a 0.15

    // Actualizar todas las capas de flechas animadas de forma sincronizada
    for (String layerId in _animatedArrowLayerIds) {
      try {
        if (await widget.mapboxMap!.style.styleLayerExists(layerId)) {
          final isUpArrow = layerId.contains('origin'); // Los origin son ↑
          final baseOffset = isUpArrow ? -1.25 : 1.25;

          // SINCRONIZAR: ambas flechas se mueven en la misma dirección relativa
          // Cuando floatOffset es positivo, ambas flechas se alejan de la parada
          // Cuando floatOffset es negativo, ambas flechas se acercan a la parada
          final animatedOffset =
              isUpArrow
                  ? (baseOffset - floatOffset)
                  : (baseOffset + floatOffset);

          await widget.mapboxMap!.style.setStyleLayerProperty(
            layerId,
            'text-offset',
            [0.0, animatedOffset],
          );
        }
      } catch (e) {
        print(
          "[ActiveTripOverlay] Error updating arrow animation for $layerId: $e",
        );
      }
    }
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

    return _ActiveTripInstructionsPanel(
      activeTripState: activeTripState,
      appLogic: appLogic,
      currentLegIndex: _currentLegIndex,
      onLegSelected: _onLegSelected,
    );
  }
}

// --- Panel de instrucciones moderno y limpio ---
class _ActiveTripInstructionsPanel extends StatelessWidget {
  final EstadoFaseViajeActivo activeTripState;
  final IAppLogic appLogic;
  final int currentLegIndex;
  final void Function(int) onLegSelected;

  const _ActiveTripInstructionsPanel({
    required this.activeTripState,
    required this.appLogic,
    required this.currentLegIndex,
    required this.onLegSelected,
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
