import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:bondi_uy/backend/providers/app_logic_provider.dart';
import 'package:bondi_uy/ui/map_style_constants.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:bondi_uy/utils/geometry_utils.dart';

class RouteOptionsOverlay extends ConsumerStatefulWidget {
  final MapboxMap? mapboxMap;

  const RouteOptionsOverlay({super.key, required this.mapboxMap});

  @override
  ConsumerState<RouteOptionsOverlay> createState() =>
      _RouteOptionsOverlayState();
}

class _RouteOptionsOverlayState extends ConsumerState<RouteOptionsOverlay> {
  late PageController _pageController;
  int _currentOptionIndex = 0;
  List<String> _activeRouteSourceIds = [];
  List<String> _activeRouteLayerIds = [];
  bool _hasInitializedRecommendedOption = false;
  bool _iconsLoaded = false; // Estado de carga de iconos

  // Sistema de animación de flechas
  Timer? _arrowAnimationTimer;
  double _arrowAnimationPhase = 0.0;
  List<String> _animatedArrowLayerIds = [];

  // Constantes para IDs de capas y fuentes de previsualización de ruta
  static const String PREVIEW_WALK_SOURCE_PREFIX = 'preview-walk-source-';
  static const String PREVIEW_WALK_LAYER_PREFIX = 'preview-walk-layer-';
  static const String PREVIEW_BUS_SOURCE_PREFIX = 'preview-bus-source-';
  static const String PREVIEW_BUS_LAYER_PREFIX = 'preview-bus-layer-';
  static const String PREVIEW_WAIT_SOURCE_PREFIX = 'preview-wait-source-';
  static const String PREVIEW_WAIT_LAYER_PREFIX = 'preview-wait-layer-';

  // Constantes para iconos (igual que InitialPhaseView)
  static const String STOP_ICON_IMAGE_ID = 'stop-icon'; // stop_icon.png
  static const String BUS_ICON_IMAGE_ID = 'bus-icon'; // incoming_bus.png

  // Constantes para buses en tiempo real en preview
  static const String PREVIEW_BUS_REALTIME_SOURCE_PREFIX =
      'preview-bus-realtime-source-';
  static const String PREVIEW_BUS_REALTIME_LAYER_PREFIX =
      'preview-bus-realtime-layer-';

  // Constantes para línea verde de aproximación en preview
  static const String PREVIEW_BUS_APPROACH_SOURCE_PREFIX =
      'preview-bus-approach-source-';
  static const String PREVIEW_BUS_APPROACH_LAYER_PREFIX =
      'preview-bus-approach-layer-';

  @override
  void initState() {
    super.initState();

    // Inicializar el índice de la opción recomendada antes de crear el PageController
    final appUiState = ref.read(appLogicProvider);
    final routeOptionsState = appUiState.datosFaseOpcionesRuta;

    print(
      "[RouteOptionsOverlay] initState - routeOptionsState: ${routeOptionsState?.opcionesDeRuta.length ?? 'null'}",
    );

    if (routeOptionsState != null &&
        routeOptionsState.opcionesDeRuta.isNotEmpty) {
      final recommendedIndex = routeOptionsState.opcionesDeRuta.indexWhere(
        (opt) => opt.esRecomendada,
      );
      _currentOptionIndex = recommendedIndex >= 0 ? recommendedIndex : 0;
      print(
        "[RouteOptionsOverlay] initState - índice recomendado encontrado: $_currentOptionIndex",
      );
    } else {
      print(
        "[RouteOptionsOverlay] initState - opciones no disponibles, usando índice 0",
      );
      _currentOptionIndex = 0;
    }

    // Crear PageController con la página inicial correcta
    _pageController = PageController(initialPage: _currentOptionIndex);
    print(
      "[RouteOptionsOverlay] initState - PageController creado con página inicial: $_currentOptionIndex",
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCarousel();
    });
  }

  void _initializeCarousel() {
    final appUiState = ref.read(appLogicProvider);
    final routeOptionsState = appUiState.datosFaseOpcionesRuta;

    print(
      "[RouteOptionsOverlay] _initializeCarousel - opciones disponibles: ${routeOptionsState?.opcionesDeRuta.length ?? 'null'}",
    );

    if (routeOptionsState != null &&
        routeOptionsState.opcionesDeRuta.isNotEmpty) {
      print(
        "[RouteOptionsOverlay] Inicializando carousel con opción $_currentOptionIndex",
      );
      // Solo mostrar el preview inicial - la corrección del índice se maneja en didUpdateWidget
      _showInitialPreview();
    }
  }

  void _showInitialPreview() {
    // Primer intento inmediato
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        print("[RouteOptionsOverlay] Primer intento de preview inicial");
        _showRoutePreview(_currentOptionIndex);
      }
    });

    // Segundo intento con más delay para asegurar que el mapa esté listo
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        print("[RouteOptionsOverlay] Segundo intento de preview inicial");
        _showRoutePreview(_currentOptionIndex);
      }
    });

    // Tercer intento como backup
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        print("[RouteOptionsOverlay] Tercer intento de preview inicial");
        _showRoutePreview(_currentOptionIndex);
      }
    });
  }

  @override
  void didUpdateWidget(RouteOptionsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Si el mapa cambió, reinicializar
    if (oldWidget.mapboxMap != widget.mapboxMap) {
      print("[RouteOptionsOverlay] Mapa cambió, reinicializando...");
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showRoutePreview(_currentOptionIndex);
        }
      });
    }

    // Solo detectar cuando las opciones se cargan por primera vez (no cada cambio)
    if (!_hasInitializedRecommendedOption) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final appUiState = ref.read(appLogicProvider);
        final routeOptionsState = appUiState.datosFaseOpcionesRuta;

        if (routeOptionsState != null &&
            routeOptionsState.opcionesDeRuta.isNotEmpty) {
          // Buscar la opción recomendada
          final recommendedIndex = routeOptionsState.opcionesDeRuta.indexWhere(
            (opt) => opt.esRecomendada,
          );
          final correctIndex = recommendedIndex >= 0 ? recommendedIndex : 0;

          print(
            "[RouteOptionsOverlay] Primera carga de opciones. Índice recomendado: $correctIndex",
          );
          print("[RouteOptionsOverlay] Índice actual: $_currentOptionIndex");

          // Marcar como inicializado para evitar futuras correcciones
          _hasInitializedRecommendedOption = true;

          // Si el índice cambió, actualizar
          if (_currentOptionIndex != correctIndex) {
            print(
              "[RouteOptionsOverlay] Corrigiendo índice de $_currentOptionIndex a $correctIndex",
            );

            setState(() {
              _currentOptionIndex = correctIndex;
            });

            // Actualizar el PageController
            if (_pageController.hasClients) {
              _pageController.animateToPage(
                _currentOptionIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          }

          // SIEMPRE mostrar el preview inicial cuando se cargan las opciones por primera vez
          print(
            "[RouteOptionsOverlay] Mostrando preview inicial para índice: $_currentOptionIndex",
          );
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) {
              _showRoutePreview(_currentOptionIndex);
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    // Detener animación de flechas
    _stopArrowAnimation();

    // Limpiar capas del preview al desmontar el overlay
    _clearRoutePreview().catchError((e) {
      print("[RouteOptionsOverlay] Error clearing preview on dispose: $e");
    });

    _pageController.dispose();
    super.dispose();
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

    // Crear una copia de la lista para evitar concurrent modification
    final layerIdsCopy = List<String>.from(_animatedArrowLayerIds);

    // Actualizar todas las capas de flechas animadas de forma sincronizada
    for (String layerId in layerIdsCopy) {
      try {
        if (await widget.mapboxMap!.style.styleLayerExists(layerId)) {
          final isUpArrow = layerId.contains('boarding'); // Los boarding son ↑
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
          "[RouteOptionsOverlay] Error updating arrow animation for $layerId: $e",
        );
      }
    }
  }

  Future<MbxImage> _loadIconImageFromAsset(String assetName) async {
    final ByteData byteData = await rootBundle.load('assets/icons/$assetName');
    final Uint8List bytes = byteData.buffer.asUint8List();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    return MbxImage(
      width: frameInfo.image.width,
      height: frameInfo.image.height,
      data: bytes,
    );
  }

  Future<void> _loadMapIcons() async {
    if (widget.mapboxMap == null || _iconsLoaded) return;
    print("[RouteOptionsOverlay] Attempting to load map icons...");
    try {
      // Use stop_icon.png for bus stops
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
      print(
        "[RouteOptionsOverlay] Loaded $STOP_ICON_IMAGE_ID from stop_icon.png",
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
      print(
        "[RouteOptionsOverlay] Loaded $BUS_ICON_IMAGE_ID from incoming_bus.png",
      );

      _iconsLoaded = true;
      print("[RouteOptionsOverlay] All icons loaded successfully.");
    } catch (e, s) {
      print("[RouteOptionsOverlay] Error loading map icons: $e");
      print(s);
    }
  }

  void _showRoutePreview(int optionIndex) {
    final appUiState = ref.read(appLogicProvider);
    final routeOptionsState = appUiState.datosFaseOpcionesRuta;

    print(
      "[RouteOptionsOverlay] _showRoutePreview llamado para índice $optionIndex",
    );

    if (widget.mapboxMap == null) {
      print("[RouteOptionsOverlay] ERROR: mapboxMap es null");
      return;
    }

    if (routeOptionsState == null) {
      print("[RouteOptionsOverlay] ERROR: routeOptionsState es null");
      return;
    }

    if (optionIndex < 0 ||
        optionIndex >= routeOptionsState.opcionesDeRuta.length) {
      print(
        "[RouteOptionsOverlay] ERROR: índice $optionIndex fuera de rango (0-${routeOptionsState.opcionesDeRuta.length - 1})",
      );
      return;
    }

    final option = routeOptionsState.opcionesDeRuta[optionIndex];
    print(
      "[RouteOptionsOverlay] Mostrando preview para opción: ${option.idOpcion}",
    );

    // Notificar a la lógica cual opción está siendo previsualizada
    ref
        .read(appLogicProvider.notifier)
        .seleccionarOpcionDeRutaParaPrevisualizar(option.idOpcion);

    // Mostrar preview en el mapa
    _displayRoutePreview(option);
  }

  Future<void> _displayRoutePreview(OpcionDeRutaMostrable ruta) async {
    if (widget.mapboxMap == null) return;

    print(
      "[RouteOptionsOverlay] Iniciando _displayRoutePreview para ruta: ${ruta.idOpcion}",
    );
    print(
      "[RouteOptionsOverlay] Número de tramos: ${ruta.tramosParaPreview.length}",
    );

    // Cargar iconos si no están cargados
    if (!_iconsLoaded) {
      await _loadMapIcons();
    }

    await _clearRoutePreview();

    try {
      List<Coordenada> todasLasCoordenadasDeLaRuta = [];

      // FASE 1: Dibujar todas las líneas de ruta (walk, bus, wait) primero
      for (int i = 0; i < ruta.tramosParaPreview.length; i++) {
        final tramo = ruta.tramosParaPreview[i];

        switch (tramo.tipo) {
          case TipoTramoViaje.CAMINAR:
            await _drawWalkSegment(tramo, i, todasLasCoordenadasDeLaRuta);
            break;

          case TipoTramoViaje.VIAJE_EN_BUS:
            await _drawBusSegment(tramo, i, todasLasCoordenadasDeLaRuta);
            // NO agregar paradas aquí - se harán en fase 2
            break;

          case TipoTramoViaje.ESPERAR_BUS:
            await _drawWaitPoint(tramo, i);
            break;
        }
      }

      // FASE 2: Agregar todas las paradas de bus encima de las líneas
      if (_iconsLoaded) {
        for (int i = 0; i < ruta.tramosParaPreview.length; i++) {
          final tramo = ruta.tramosParaPreview[i];

          if (tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS) {
            await _addBusStopsForSegment(tramo, i);
          }
        }
      }

      // FASE 3: Mostrar buses en tiempo real si hay información disponible
      await _displayRealtimeBusesForPreview(ruta);

      // FASE 4: Iniciar animación de flechas
      _startArrowAnimation();

      // Zoom a la ruta completa
      if (todasLasCoordenadasDeLaRuta.isNotEmpty) {
        await _zoomToRoute(todasLasCoordenadasDeLaRuta);
      }

      print("[RouteOptionsOverlay] Preview de ruta completado exitosamente");
    } catch (e) {
      print("[RouteOptionsOverlay] Error en _displayRoutePreview: $e");
    }
  }

  Future<void> _addBusStopsForSegment(
    TramoViajeMostrable tramo,
    int segmentIndex,
  ) async {
    if (widget.mapboxMap == null ||
        tramo.geometriaPolilinea == null ||
        tramo.geometriaPolilinea!.isEmpty)
      return;

    final polyline = tramo.geometriaPolilinea!;

    // Parada de subida (primer punto del tramo de bus)
    if (polyline.isNotEmpty) {
      final boardingStop = polyline.first;
      await _addBusStopMarker(
        'bus-boarding-stop-$segmentIndex',
        'bus-boarding-layer-$segmentIndex',
        boardingStop.latitud,
        boardingStop.longitud,
        'Subir al bus',
      );
    }

    // Parada de bajada (último punto del tramo de bus)
    if (polyline.length > 1) {
      final alightingStop = polyline.last;
      await _addBusStopMarker(
        'bus-alighting-stop-$segmentIndex',
        'bus-alighting-layer-$segmentIndex',
        alightingStop.latitud,
        alightingStop.longitud,
        'Bajar del bus',
      );
    }
  }

  Future<void> _drawWalkSegment(
    TramoViajeMostrable tramo,
    int index,
    List<Coordenada> todasLasCoordenadasDeLaRuta,
  ) async {
    if (tramo.geometriaPolilinea == null || tramo.geometriaPolilinea!.isEmpty) {
      return;
    }

    final sourceId = '$PREVIEW_WALK_SOURCE_PREFIX$index';
    final shadowLayerId = '$PREVIEW_WALK_LAYER_PREFIX$index-shadow';
    final mainLayerId = '$PREVIEW_WALK_LAYER_PREFIX$index';

    todasLasCoordenadasDeLaRuta.addAll(tramo.geometriaPolilinea!);

    final geoJsonFeature = {
      "type": "Feature",
      "geometry": {
        "type": "LineString",
        "coordinates": _coordenadasToGeoJsonPositionList(
          tramo.geometriaPolilinea!,
        ),
      },
    };

    // Agregar fuente
    await widget.mapboxMap!.style.addSource(
      GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)),
    );
    _activeRouteSourceIds.add(sourceId);

    // Agregar capa de borde
    await widget.mapboxMap!.style.addLayer(
      LineLayer(
        id: shadowLayerId,
        sourceId: sourceId,
        lineColor: MapStyleConstants.BORDER_PROPERTIES['line-color'] as int,
        lineWidth:
            (MapStyleConstants.BORDER_PROPERTIES['line-width'] as num)
                .toDouble(),
        lineOpacity:
            (MapStyleConstants.BORDER_PROPERTIES['line-opacity'] as num)
                .toDouble(),
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      ),
    );
    _activeRouteLayerIds.add(shadowLayerId);

    // Agregar capa principal - WALK es línea SÓLIDA (no dashed)
    await widget.mapboxMap!.style.addLayer(
      LineLayer(
        id: mainLayerId,
        sourceId: sourceId,
        lineColor: MapStyleConstants.WALK_LINE_PROPERTIES['line-color'] as int,
        lineWidth:
            (MapStyleConstants.WALK_LINE_PROPERTIES['line-width'] as num)
                .toDouble(),
        lineOpacity:
            (MapStyleConstants.WALK_LINE_PROPERTIES['line-opacity'] as num)
                .toDouble(),
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
        // NO lineDasharray - líneas sólidas como en código viejo
      ),
    );
    _activeRouteLayerIds.add(mainLayerId);
  }

  Future<void> _drawBusSegment(
    TramoViajeMostrable tramo,
    int index,
    List<Coordenada> todasLasCoordenadasDeLaRuta,
  ) async {
    if (tramo.geometriaPolilinea == null || tramo.geometriaPolilinea!.isEmpty) {
      return;
    }

    final sourceId = '$PREVIEW_BUS_SOURCE_PREFIX$index';
    final shadowLayerId = '$PREVIEW_BUS_LAYER_PREFIX$index-shadow';
    final mainLayerId = '$PREVIEW_BUS_LAYER_PREFIX$index';

    todasLasCoordenadasDeLaRuta.addAll(tramo.geometriaPolilinea!);

    final geoJsonFeature = {
      "type": "Feature",
      "geometry": {
        "type": "LineString",
        "coordinates": _coordenadasToGeoJsonPositionList(
          tramo.geometriaPolilinea!,
        ),
      },
    };

    // Agregar fuente
    await widget.mapboxMap!.style.addSource(
      GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)),
    );
    _activeRouteSourceIds.add(sourceId);

    // Agregar capa de borde
    await widget.mapboxMap!.style.addLayer(
      LineLayer(
        id: shadowLayerId,
        sourceId: sourceId,
        lineColor: MapStyleConstants.BORDER_PROPERTIES['line-color'] as int,
        lineWidth:
            (MapStyleConstants.BORDER_PROPERTIES['line-width'] as num)
                .toDouble(),
        lineOpacity:
            (MapStyleConstants.BORDER_PROPERTIES['line-opacity'] as num)
                .toDouble(),
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      ),
    );
    _activeRouteLayerIds.add(shadowLayerId);

    // Agregar capa principal
    await widget.mapboxMap!.style.addLayer(
      LineLayer(
        id: mainLayerId,
        sourceId: sourceId,
        lineColor: MapStyleConstants.BUS_LINE_PROPERTIES['line-color'] as int,
        lineWidth:
            (MapStyleConstants.BUS_LINE_PROPERTIES['line-width'] as num)
                .toDouble(),
        lineOpacity:
            (MapStyleConstants.BUS_LINE_PROPERTIES['line-opacity'] as num)
                .toDouble(),
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      ),
    );
    _activeRouteLayerIds.add(mainLayerId);
  }

  Future<void> _drawWaitPoint(TramoViajeMostrable tramo, int index) async {
    if (tramo.posicionPunto == null) return;

    final sourceId = '$PREVIEW_WAIT_SOURCE_PREFIX$index';
    final layerId = '$PREVIEW_WAIT_LAYER_PREFIX$index';

    final geoJsonFeature = {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [
          tramo.posicionPunto!.longitud,
          tramo.posicionPunto!.latitud,
        ],
      },
      "properties": {"label": "Esperar bus"},
    };

    // Agregar fuente
    await widget.mapboxMap!.style.addSource(
      GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)),
    );
    _activeRouteSourceIds.add(sourceId);

    // Agregar capa del círculo
    await widget.mapboxMap!.style.addLayer(
      CircleLayer(
        id: layerId,
        sourceId: sourceId,
        circleColor:
            MapStyleConstants.WAIT_CIRCLE_PROPERTIES['circle-color'] as int,
        circleRadius:
            (MapStyleConstants.WAIT_CIRCLE_PROPERTIES['circle-radius'] as num)
                .toDouble(),
        circleStrokeColor:
            MapStyleConstants.WAIT_CIRCLE_PROPERTIES['circle-stroke-color']
                as int,
        circleStrokeWidth:
            (MapStyleConstants.WAIT_CIRCLE_PROPERTIES['circle-stroke-width']
                    as num)
                .toDouble(),
        circleOpacity:
            (MapStyleConstants.WAIT_CIRCLE_PROPERTIES['circle-opacity'] as num)
                .toDouble(),
      ),
    );
    _activeRouteLayerIds.add(layerId);
  }

  Future<void> _zoomToRoute(List<Coordenada> coordenadas) async {
    if (widget.mapboxMap == null || coordenadas.isEmpty) return;

    try {
      // Convertir coordenadas a puntos de Mapbox
      final mapboxPoints =
          coordenadas
              .map((c) => Point(coordinates: Position(c.longitud, c.latitud)))
              .toList();

      // Calcular padding responsivo - AUMENTADO para considerar la card de opciones
      final screenHeight = MediaQuery.of(context).size.height;
      final isSmallScreen = screenHeight < 700;

      final topPadding = isSmallScreen ? 80.0 : 100.0;
      // AUMENTADO significativamente: la card ocupa ~1/3 de la pantalla
      final bottomPadding = 400.0; // Espacio generoso para el carousel
      final sidePadding = 50.0;

      // Calcular opciones de cámara para mostrar toda la ruta
      final cameraOptions = await widget.mapboxMap!.cameraForCoordinates(
        mapboxPoints,
        MbxEdgeInsets(
          top: topPadding,
          left: sidePadding,
          bottom: bottomPadding,
          right: sidePadding,
        ),
        null,
        null,
      );

      // Hacer el zoom con animación
      await widget.mapboxMap!.flyTo(
        cameraOptions,
        MapAnimationOptions(duration: 1200),
      );
    } catch (e) {
      print("[RouteOptionsOverlay] Error zooming to route: $e");
    }
  }

  List<List<double>> _coordenadasToGeoJsonPositionList(
    List<Coordenada> coordenadas,
  ) {
    return coordenadas.map((c) => [c.longitud, c.latitud]).toList();
  }

  List<double> _coordenadaToGeoJsonPosition(Coordenada coordenada) {
    return [coordenada.longitud, coordenada.latitud];
  }

  Future<void> _fitToRouteCoordinates(List<Coordenada> coordinates) async {
    if (widget.mapboxMap == null || coordinates.isEmpty) return;

    try {
      // Detectar pantallas pequeñas
      final screenHeight = MediaQuery.of(context).size.height;
      final isSmallScreen = screenHeight < 700;

      // Calcular bounds de todas las coordenadas
      double minLat = coordinates.first.latitud;
      double maxLat = coordinates.first.latitud;
      double minLng = coordinates.first.longitud;
      double maxLng = coordinates.first.longitud;

      for (var coord in coordinates) {
        if (coord.latitud < minLat) minLat = coord.latitud;
        if (coord.latitud > maxLat) maxLat = coord.latitud;
        if (coord.longitud < minLng) minLng = coord.longitud;
        if (coord.longitud > maxLng) maxLng = coord.longitud;
      }

      final southwest = Point(coordinates: Position(minLng, minLat));
      final northeast = Point(coordinates: Position(maxLng, maxLat));

      // Padding ajustado para que el carousel no tape la ruta - ACTUALIZADO
      final padding = MbxEdgeInsets(
        top: isSmallScreen ? 80.0 : 100.0, // Más espacio arriba
        left: 50.0,
        bottom:
            isSmallScreen
                ? 350.0 // Espacio generoso para la card
                : 400.0, // Espacio generoso para la card
        right: 50.0,
      );

      final cameraOptions = await widget.mapboxMap!.cameraForCoordinateBounds(
        CoordinateBounds(
          southwest: southwest,
          northeast: northeast,
          infiniteBounds: false,
        ),
        padding,
        null, // bearing
        null, // pitch
        null, // maxZoom
        null, // offset
      );

      await widget.mapboxMap!.flyTo(
        cameraOptions,
        MapAnimationOptions(duration: 1000),
      );
    } catch (e) {
      print("[RouteOptionsOverlay] Error fitting to route coordinates: $e");
    }
  }

  Future<void> _addMarker(
    String sourceId,
    String layerId,
    double lat,
    double lng,
    Color color,
    String label,
  ) async {
    if (widget.mapboxMap == null) return;

    // Crear fuente del marcador
    final geoJsonSource = GeoJsonSource(
      id: sourceId,
      data: jsonEncode({
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [lng, lat],
        },
        "properties": {"label": label},
      }),
    );

    await widget.mapboxMap!.style.addSource(geoJsonSource);
    _activeRouteSourceIds.add(sourceId);

    // Crear capa del marcador
    final circleLayer = CircleLayer(
      id: layerId,
      sourceId: sourceId,
      circleRadius: 8.0,
      circleColor: color.value,
      circleStrokeColor: Colors.white.value,
      circleStrokeWidth: 2.0,
    );

    await widget.mapboxMap!.style.addLayer(circleLayer);
    _activeRouteLayerIds.add(layerId);
  }

  Future<void> _clearRoutePreview() async {
    if (widget.mapboxMap == null) return;

    // Detener animación de flechas
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

  Future<void> _displayRealtimeBusesForPreview(
    OpcionDeRutaMostrable ruta,
  ) async {
    if (widget.mapboxMap == null || !_iconsLoaded) return;

    print("[RouteOptionsOverlay] Displaying realtime buses for preview");
    print(
      "[RouteOptionsOverlay] Route has ${ruta.tramosParaPreview.length} segments",
    );
    print(
      "[RouteOptionsOverlay] Route ETA info: ${ruta.etaProximoBus != null ? 'Present' : 'Null'}",
    );

    // Buscar SOLO el primer tramo de bus (más relevante para el usuario en preview)
    TramoViajeMostrable? primerTramoBus;
    int indicePrimerTramoBus = -1;

    for (int i = 0; i < ruta.tramosParaPreview.length; i++) {
      final tramo = ruta.tramosParaPreview[i];

      if (tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS ||
          tramo.tipo == TipoTramoViaje.ESPERAR_BUS) {
        primerTramoBus = tramo;
        indicePrimerTramoBus = i;
        print(
          "[RouteOptionsOverlay] First bus segment found at index $i: line=${tramo.nombreLineaBus}",
        );
        break; // Solo el primer tramo de bus
      }
    }

    int busesAdded = 0;

    if (primerTramoBus != null) {
      print(
        "[RouteOptionsOverlay] First bus segment data: position=${primerTramoBus.posicionActualBus != null ? 'Present' : 'Null'}, eta=${primerTramoBus.minutosEstimadosLlegadaBus}, realTime=${primerTramoBus.esTiempoRealBus}",
      );

      // Verificar si tiene información de bus en tiempo real
      if (primerTramoBus.posicionActualBus != null &&
          primerTramoBus.minutosEstimadosLlegadaBus != null &&
          primerTramoBus.nombreLineaBus != null) {
        await _addRealtimeBusToPreview(primerTramoBus, indicePrimerTramoBus);
        busesAdded++;
        print(
          "[RouteOptionsOverlay] Added realtime bus for first bus line ${primerTramoBus.nombreLineaBus}",
        );
      } else {
        print(
          "[RouteOptionsOverlay] First bus segment missing required data: posicion=${primerTramoBus.posicionActualBus != null}, eta=${primerTramoBus.minutosEstimadosLlegadaBus != null}, line=${primerTramoBus.nombreLineaBus != null}",
        );

        // Si el tramo no tiene datos, usar el ETA general de la ruta como fallback
        if (ruta.etaProximoBus != null &&
            ruta.etaProximoBus!.posicionBus != null) {
          print(
            "[RouteOptionsOverlay] Using general route ETA as fallback: line=${ruta.etaProximoBus!.linea}, eta=${ruta.etaProximoBus!.minutosParaLlegada}min",
          );
          await _addRealtimeBusFromEta(
            ruta.etaProximoBus!,
            indicePrimerTramoBus,
          );
          busesAdded++;
          print(
            "[RouteOptionsOverlay] Added realtime bus from general ETA for line ${ruta.etaProximoBus!.linea}",
          );
        }
      }
    } else {
      print("[RouteOptionsOverlay] No bus segments found in route");

      // Como último recurso, usar el ETA general si existe
      if (ruta.etaProximoBus != null &&
          ruta.etaProximoBus!.posicionBus != null) {
        print(
          "[RouteOptionsOverlay] Using general route ETA as only option: line=${ruta.etaProximoBus!.linea}",
        );
        await _addRealtimeBusFromEta(
          ruta.etaProximoBus!,
          0, // Usar índice 0 como fallback
        );
        busesAdded++;
        print(
          "[RouteOptionsOverlay] Added realtime bus from general ETA for line ${ruta.etaProximoBus!.linea}",
        );
      }
    }

    print("[RouteOptionsOverlay] Total buses added to preview: $busesAdded");
  }

  Future<void> _addRealtimeBusToPreview(
    TramoViajeMostrable tramo,
    int segmentIndex,
  ) async {
    if (widget.mapboxMap == null ||
        !_iconsLoaded ||
        tramo.posicionActualBus == null ||
        tramo.geometriaPolilinea == null ||
        tramo.geometriaPolilinea!.isEmpty)
      return;

    final sourceId = '$PREVIEW_BUS_REALTIME_SOURCE_PREFIX$segmentIndex';
    final layerId = '$PREVIEW_BUS_REALTIME_LAYER_PREFIX$segmentIndex';

    // Coordenada del bus
    final busPosition = tramo.posicionActualBus!;

    // Parada de origen (donde el usuario debe subir)
    final paradaOrigen = tramo.geometriaPolilinea!.first;

    final geoJsonFeature = {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [busPosition.longitud, busPosition.latitud],
      },
      "properties": {
        "linea": tramo.nombreLineaBus,
        "eta": tramo.minutosEstimadosLlegadaBus,
        "isRealTime": tramo.esTiempoRealBus ?? false,
        "destino": tramo.destinoFinalDelBus,
      },
    };

    try {
      // 1. Agregar línea verde de aproximación PRIMERO (para que quede debajo del bus)
      await _addBusApproachLineToPreview(
        busPosition,
        paradaOrigen,
        segmentIndex,
        tramo,
      );

      // 2. Agregar fuente del bus
      await widget.mapboxMap!.style.addSource(
        GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)),
      );
      _activeRouteSourceIds.add(sourceId);

      // 3. Agregar capa del bus con tamaño más pequeño para preview
      await widget.mapboxMap!.style.addLayer(
        SymbolLayer(
          id: layerId,
          sourceId: sourceId,
          iconImage: BUS_ICON_IMAGE_ID,
          iconAllowOverlap: true,
          iconSize: 0.5, // Más pequeño para preview (era 0.7)
          iconAnchor: IconAnchor.CENTER,
        ),
      );
      _activeRouteLayerIds.add(layerId);

      print(
        "[RouteOptionsOverlay] Added realtime bus for line ${tramo.nombreLineaBus} with ETA ${tramo.minutosEstimadosLlegadaBus}min and approach line",
      );
    } catch (e) {
      print("[RouteOptionsOverlay] Error adding realtime bus: $e");
    }
  }

  Future<void> _addBusApproachLineToPreview(
    Coordenada busPosition,
    Coordenada stopPosition,
    int segmentIndex,
    TramoViajeMostrable tramo,
  ) async {
    if (widget.mapboxMap == null) {
      print("[RouteOptionsOverlay] Missing mapboxMap for bus approach line");
      return;
    }

    final sourceId = '$PREVIEW_BUS_APPROACH_SOURCE_PREFIX$segmentIndex';
    final shadowLayerId =
        '$PREVIEW_BUS_APPROACH_LAYER_PREFIX$segmentIndex-shadow';
    final mainLayerId = '$PREVIEW_BUS_APPROACH_LAYER_PREFIX$segmentIndex';

    print("[RouteOptionsOverlay] Creating bus approach line:");
    print(
      "  - Bus position: (${busPosition.latitud}, ${busPosition.longitud})",
    );
    print(
      "  - Stop position: (${stopPosition.latitud}, ${stopPosition.longitud})",
    );
    print("  - ShapeId: ${tramo.shapeId}");

    // Cargar geometrías de shapes si no están cargadas
    await loadShapeGeometries();

    // Obtener la geometría completa de la línea usando el shapeId
    List<Coordenada>? fullLineGeometry;
    if (tramo.shapeId != null) {
      fullLineGeometry = getFullShapeGeometry(tramo.shapeId);
      print("  - Full line geometry: ${fullLineGeometry?.length ?? 0} points");
    }

    // Si no tenemos geometría completa, usar la del tramo como fallback
    if (fullLineGeometry == null || fullLineGeometry.isEmpty) {
      print(
        "  - No full line geometry found, using segment geometry as fallback",
      );
      fullLineGeometry = tramo.geometriaPolilinea;
      if (fullLineGeometry == null || fullLineGeometry.isEmpty) {
        print("  - No geometry available, using straight line");
        fullLineGeometry = null;
      }
    }

    List<List<double>> coordinates;

    if (fullLineGeometry != null && fullLineGeometry.isNotEmpty) {
      print("  - Using geometry with ${fullLineGeometry.length} points");

      // Encontrar índices en la geometría completa
      final busIndex = findClosestPointIndexOnShape(
        fullLineGeometry,
        busPosition,
      );
      final stopIndex = findClosestPointIndexOnShape(
        fullLineGeometry,
        stopPosition,
      );

      print(
        "[RouteOptionsOverlay] Bus approach indices: busIndex=$busIndex, stopIndex=$stopIndex",
      );

      if (busIndex != -1) {
        final closestToBus = fullLineGeometry[busIndex];
        final distanceToBus = calculateHaversineDistance(
          busPosition.latitud,
          busPosition.longitud,
          closestToBus.latitud,
          closestToBus.longitud,
        );
        print(
          "  - Closest point to bus: (${closestToBus.latitud}, ${closestToBus.longitud}), distance: ${distanceToBus.toStringAsFixed(1)}m",
        );
      }

      if (stopIndex != -1) {
        final closestToStop = fullLineGeometry[stopIndex];
        final distanceToStop = calculateHaversineDistance(
          stopPosition.latitud,
          stopPosition.longitud,
          closestToStop.latitud,
          closestToStop.longitud,
        );
        print(
          "  - Closest point to stop: (${closestToStop.latitud}, ${closestToStop.longitud}), distance: ${distanceToStop.toStringAsFixed(1)}m",
        );
      }

      // Si no encontramos ambos puntos, usar línea recta como fallback
      if (busIndex == -1 || stopIndex == -1) {
        print(
          "[RouteOptionsOverlay] Using straight line fallback for bus approach (indices not found)",
        );
        coordinates = [
          [busPosition.longitud, busPosition.latitud],
          [stopPosition.longitud, stopPosition.latitud],
        ];
      } else {
        // Calcular segmento de la geometría entre bus y parada
        final segment = getGeometrySegment(
          fullLineGeometry,
          busIndex,
          stopIndex,
        );
        print(
          "[RouteOptionsOverlay] Raw segment from indices $busIndex to $stopIndex: ${segment.length} points",
        );

        if (segment.length < 2) {
          print(
            "[RouteOptionsOverlay] Segment too short (${segment.length}), using straight line",
          );
          coordinates = [
            [busPosition.longitud, busPosition.latitud],
            [stopPosition.longitud, stopPosition.latitud],
          ];
        } else {
          coordinates = segment.map((c) => [c.longitud, c.latitud]).toList();
          print(
            "[RouteOptionsOverlay] ✅ Using geometry segment with ${coordinates.length} points",
          );
          print(
            "  - Segment start: [${coordinates.first[1]}, ${coordinates.first[0]}]",
          );
          print(
            "  - Segment end: [${coordinates.last[1]}, ${coordinates.last[0]}]",
          );
        }
      }
    } else {
      // Sin geometría, usar línea recta
      print("[RouteOptionsOverlay] No geometry available, using straight line");
      coordinates = [
        [busPosition.longitud, busPosition.latitud],
        [stopPosition.longitud, stopPosition.latitud],
      ];
    }

    // Crear línea siguiendo la geometría de la ruta
    final geoJsonFeatureCollection = {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "geometry": {"type": "LineString", "coordinates": coordinates},
          "properties": {"type": "bus-approach"},
        },
      ],
    };

    try {
      // Agregar fuente de la línea verde
      await widget.mapboxMap!.style.addSource(
        GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeatureCollection)),
      );
      _activeRouteSourceIds.add(sourceId);

      // 1. Agregar capa de borde (más gruesa, negra, debajo)
      await widget.mapboxMap!.style.addLayer(
        LineLayer(
          id: shadowLayerId,
          sourceId: sourceId,
          lineColor: 0xFF000000, // Negro para el borde
          lineWidth:
              8.0, // CAMBIO: de 6.0 a 8.0 para consistencia con otros bordes
          lineOpacity: 0.9,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
        ),
      );
      _activeRouteLayerIds.add(shadowLayerId);

      // 2. Agregar capa de línea verde principal (encima del borde)
      await widget.mapboxMap!.style.addLayer(
        LineLayer(
          id: mainLayerId,
          sourceId: sourceId,
          lineColor: 0xFF4CAF50, // Verde como en el código anterior
          lineWidth: 5.0, // CAMBIO: de 4.0 a 5.0 para consistencia con BUS
          lineOpacity: 0.9,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
        ),
      );
      _activeRouteLayerIds.add(mainLayerId);

      print(
        "[RouteOptionsOverlay] Added green approach line with border following bus route geometry",
      );
    } catch (e) {
      print("[RouteOptionsOverlay] Error adding approach line: $e");
    }
  }

  Future<void> _addRealtimeBusFromEta(EtaMostrable eta, int index) async {
    if (widget.mapboxMap == null || !_iconsLoaded || eta.posicionBus == null)
      return;

    final sourceId = '${PREVIEW_BUS_REALTIME_SOURCE_PREFIX}eta_$index';
    final layerId = '${PREVIEW_BUS_REALTIME_LAYER_PREFIX}eta_$index';

    final geoJsonFeature = {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [eta.posicionBus!.longitud, eta.posicionBus!.latitud],
      },
      "properties": {
        "linea": eta.linea,
        "eta": eta.minutosParaLlegada,
        "isRealTime": eta.esTiempoReal,
        "destino": eta.destino,
      },
    };

    try {
      // Agregar fuente del bus
      await widget.mapboxMap!.style.addSource(
        GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)),
      );
      _activeRouteSourceIds.add(sourceId);

      // Agregar capa del bus
      await widget.mapboxMap!.style.addLayer(
        SymbolLayer(
          id: layerId,
          sourceId: sourceId,
          iconImage: BUS_ICON_IMAGE_ID,
          iconAllowOverlap: true,
          iconSize: 0.7,
          iconAnchor: IconAnchor.CENTER,
        ),
      );
      _activeRouteLayerIds.add(layerId);

      print(
        "[RouteOptionsOverlay] Added realtime bus from ETA for line ${eta.linea} with ${eta.minutosParaLlegada}min",
      );
    } catch (e) {
      print("[RouteOptionsOverlay] Error adding realtime bus from ETA: $e");
    }
  }

  Future<void> _addOriginDestinationMarker(
    String sourceId,
    String layerId,
    double lat,
    double lng,
    bool isOrigin,
  ) async {
    if (widget.mapboxMap == null) return;

    // Crear fuente del marcador
    final geoJsonSource = GeoJsonSource(
      id: sourceId,
      data: jsonEncode({
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [lng, lat],
        },
        "properties": {"label": isOrigin ? "Origen" : "Destino"},
      }),
    );

    await widget.mapboxMap!.style.addSource(geoJsonSource);
    _activeRouteSourceIds.add(sourceId);

    // Crear capa del marcador con colores distintivos
    final properties =
        isOrigin
            ? MapStyleConstants.ORIGIN_MARKER_PROPERTIES
            : MapStyleConstants.DESTINATION_MARKER_PROPERTIES;

    final circleLayer = CircleLayer(
      id: layerId,
      sourceId: sourceId,
      circleRadius: (properties['circle-radius'] as num).toDouble(),
      circleColor: properties['circle-color'] as int,
      circleStrokeColor: properties['circle-stroke-color'] as int,
      circleStrokeWidth: (properties['circle-stroke-width'] as num).toDouble(),
      circleOpacity: (properties['circle-opacity'] as num).toDouble(),
    );

    await widget.mapboxMap!.style.addLayer(circleLayer);
    _activeRouteLayerIds.add(layerId);
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

    // Usar el icono de parada igual que en InitialPhaseView
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

  @override
  Widget build(BuildContext context) {
    final appUiState = ref.watch(appLogicProvider);
    final appLogic = ref.read(appLogicProvider.notifier);
    final routeOptionsState = appUiState.datosFaseOpcionesRuta;

    // LISTENER para cambios en idOpcionRutaPrevisualizada del backend
    ref.listen(
      appLogicProvider.select((state) => state.idOpcionRutaPrevisualizada),
      (previous, next) {
        print(
          "[RouteOptionsOverlay] idOpcionRutaPrevisualizada cambió de $previous a $next",
        );

        if (next != null) {
          final currentAppUiState = ref.read(appLogicProvider);
          final currentRouteOptionsState =
              currentAppUiState.datosFaseOpcionesRuta;

          if (currentRouteOptionsState != null) {
            // Encontrar el índice de la opción previsualizada en el backend
            final backendSelectedIndex = currentRouteOptionsState.opcionesDeRuta
                .indexWhere((opt) => opt.idOpcion == next);

            // Si encontramos la opción y es diferente a la actual en UI
            if (backendSelectedIndex >= 0 &&
                backendSelectedIndex != _currentOptionIndex) {
              print(
                "[RouteOptionsOverlay] Sincronizando UI con backend: $_currentOptionIndex -> $backendSelectedIndex",
              );

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _currentOptionIndex = backendSelectedIndex;
                  });

                  // Actualizar PageController para sincronizar UI
                  if (_pageController.hasClients) {
                    _pageController.animateToPage(
                      _currentOptionIndex,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                    );
                  }

                  // Actualizar preview del mapa
                  final option =
                      currentRouteOptionsState
                          .opcionesDeRuta[backendSelectedIndex];
                  _displayRoutePreview(option);
                }
              });
            }
          }
        }
      },
    );

    if (routeOptionsState == null || routeOptionsState.opcionesDeRuta.isEmpty) {
      return _buildEmptyState(appLogic);
    }

    final options = routeOptionsState.opcionesDeRuta;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Stack(
      children: [
        // El mapa toma todo el espacio disponible (está en AppHost)
        Container(),

        // Panel draggable colapsable
        DraggableScrollableSheet(
          initialChildSize:
              isSmallScreen
                  ? 0.6
                  : 0.5, // Completamente expandido desde el inicio
          minChildSize: 0.1, // Colapsado - solo handle visible
          maxChildSize: isSmallScreen ? 0.6 : 0.5, // Máximo expandido
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24.0),
                  topRight: Radius.circular(24.0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle para drag
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Contenido scrollable
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          _buildHeader(appLogic, isSmallScreen),

                          // Carousel con altura específica según contenido
                          SizedBox(
                            height: isSmallScreen ? 210 : 250,
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: options.length,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentOptionIndex = index;
                                });
                                _showRoutePreview(index);
                              },
                              itemBuilder: (context, index) {
                                final option = options[index];
                                return _buildModernRouteCard(
                                  option,
                                  index == _currentOptionIndex,
                                  isSmallScreen,
                                );
                              },
                            ),
                          ),

                          // Footer
                          _buildFooter(options, appLogic, isSmallScreen),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeader(AppLogicNotifier appLogic, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        isSmallScreen ? 16 : 20,
        24,
        isSmallScreen ? 12 : 16,
      ),
      child: Row(
        children: [
          // Icono y título
          Container(
            width: isSmallScreen ? 36 : 40,
            height: isSmallScreen ? 36 : 40,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.alt_route,
              color: Colors.blue,
              size: isSmallScreen ? 18 : 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Opciones de Viaje',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                    fontSize: isSmallScreen ? 18 : null,
                  ),
                ),
                Text(
                  'Elige la mejor ruta para ti',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontSize: isSmallScreen ? 11 : null,
                  ),
                ),
              ],
            ),
          ),
          // Botón cancelar minimalista
          GestureDetector(
            onTap: () => appLogic.usuarioCanceloBusquedaOSeleccionRuta(),
            child: Container(
              width: isSmallScreen ? 32 : 36,
              height: isSmallScreen ? 32 : 36,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 18),
              ),
              child: Icon(
                Icons.close,
                color: Colors.grey[600],
                size: isSmallScreen ? 16 : 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernRouteCard(
    OpcionDeRutaMostrable option,
    bool isSelected,
    bool isSmallScreen,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: isSmallScreen ? 6.0 : 10.0,
      ),
      padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.grey[200]!,
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow:
            isSelected
                ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header con duración y recomendación
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDuration(option.duracionTotalSegundos),
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.blue[700] : Colors.grey[800],
                        height: 1.0,
                        fontSize: isSmallScreen ? 24 : 28,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Llegada: ${TimeOfDay.fromDateTime(option.horaLlegadaEstimada).format(context)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                        fontSize: isSmallScreen ? 12 : 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (option.esRecomendada) ...[
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 10 : 12,
                    vertical: isSmallScreen ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'RECOMENDADA',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: isSmallScreen ? 9 : 10,
                    ),
                  ),
                ),
              ],
            ],
          ),

          SizedBox(height: isSmallScreen ? 16 : 20),

          // Iconos de modos de transporte
          _buildModernModeIcons(
            context,
            option.secuenciaModosIconos,
            isSelected,
            isSmallScreen,
          ),

          SizedBox(height: isSmallScreen ? 16 : 20),

          // Información detallada
          Wrap(
            spacing: 12,
            children: [
              // ETA del próximo bus
              if (option.etaProximoBus != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 10 : 12,
                    vertical: isSmallScreen ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        option.etaProximoBus!.esTiempoReal
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color:
                              option.etaProximoBus!.esTiempoReal
                                  ? Colors.green
                                  : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${option.etaProximoBus!.minutosParaLlegada} min',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color:
                              option.etaProximoBus!.esTiempoReal
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                          fontSize: isSmallScreen ? 12 : 13,
                        ),
                      ),
                    ],
                  ),
                ),

              // Distancia de caminata
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 10 : 12,
                  vertical: isSmallScreen ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.directions_walk,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${option.distanciaTotalCaminataMetros}m',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                        fontSize: isSmallScreen ? 12 : 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Padding bottom para que no esté pegado al borde
          SizedBox(height: isSmallScreen ? 12 : 16),
        ],
      ),
    );
  }

  Widget _buildModernModeIcons(
    BuildContext context,
    List<TipoTramoViaje> modos,
    bool isSelected,
    bool isSmallScreen,
  ) {
    List<Widget> icons = [];
    Color iconColor = isSelected ? Colors.blue[600]! : Colors.grey[600]!;
    final iconSize = isSmallScreen ? 40.0 : 48.0;
    final iconInnerSize = isSmallScreen ? 20.0 : 24.0;

    for (int i = 0; i < modos.length; i++) {
      if (modos[i] == TipoTramoViaje.ESPERAR_BUS) continue;

      IconData iconData;
      switch (modos[i]) {
        case TipoTramoViaje.CAMINAR:
          iconData = Icons.directions_walk;
          break;
        case TipoTramoViaje.VIAJE_EN_BUS:
          iconData = Icons.directions_bus;
          break;
        default:
          iconData = Icons.help_outline;
      }

      icons.add(
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 14),
            border: Border.all(color: iconColor.withOpacity(0.2), width: 1),
          ),
          child: Icon(iconData, color: iconColor, size: iconInnerSize),
        ),
      );

      if (i < modos.length - 1 && modos[i + 1] != TipoTramoViaje.ESPERAR_BUS) {
        icons.add(SizedBox(width: isSmallScreen ? 8 : 12));
        icons.add(
          Container(
            width: isSmallScreen ? 16 : 24,
            height: 2,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
        icons.add(SizedBox(width: isSmallScreen ? 8 : 12));
      }
    }

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: icons);
  }

  Widget _buildModernWarningChip(
    TipoAdvertenciaItinerario advertencia,
    bool isSmallScreen,
  ) {
    String message;
    Color color = Colors.orange[600]!;

    switch (advertencia) {
      case TipoAdvertenciaItinerario.TIEMPO_CAMINATA_EXCESIVO:
        message = 'Caminata larga';
        break;
      case TipoAdvertenciaItinerario.TRANSBORDO_AJUSTADO:
        message = 'Transbordo ajustado';
        break;
      case TipoAdvertenciaItinerario.ETA_NO_DISPONIBLE_PARA_PRIMER_BUS:
        message = 'ETA no disponible';
        color = Colors.grey[600]!;
        break;
      case TipoAdvertenciaItinerario.ETA_NO_ES_TIEMPO_REAL_PARA_PRIMER_BUS:
        message = 'ETA programada';
        color = Colors.blue[600]!;
        break;
      default:
        message = 'Advertencia';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 6 : 8,
        vertical: isSmallScreen ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, color: color, size: isSmallScreen ? 10 : 12),
          SizedBox(width: isSmallScreen ? 3 : 4),
          Text(
            message,
            style: TextStyle(
              fontSize: isSmallScreen ? 9 : 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(
    List<OpcionDeRutaMostrable> options,
    AppLogicNotifier appLogic,
    bool isSmallScreen,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        isSmallScreen ? 8 : 12,
        24,
        isSmallScreen ? 16 : 20,
      ),
      child: Row(
        children: [
          // Indicadores de página modernos
          Row(
            children: List.generate(options.length, (index) {
              bool isActive = index == _currentOptionIndex;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? (isSmallScreen ? 14 : 16) : 5,
                height: isSmallScreen ? 5 : 6,
                decoration: BoxDecoration(
                  color: isActive ? Colors.blue : Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),

          const Spacer(),

          // Botón de confirmación moderno
          ElevatedButton(
            onPressed: () {
              appLogic.confirmarOpcionDeRutaEIniciarViaje(
                options[_currentOptionIndex].idOpcion,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 20 : 24,
                vertical: isSmallScreen ? 10 : 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: isSmallScreen ? 16 : 18),
                SizedBox(width: isSmallScreen ? 4 : 6),
                Text(
                  'Confirmar',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: isSmallScreen ? 13 : 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLogicNotifier appLogic) {
    return Container(
      child: Column(
        children: [
          const Spacer(),
          Container(
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.route_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No se encontraron rutas',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Intenta con otras ubicaciones',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed:
                      () => appLogic.usuarioCanceloBusquedaOSeleccionRuta(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Nueva Búsqueda'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours h ${minutes} min';
    }
    return '$minutes min';
  }
}
