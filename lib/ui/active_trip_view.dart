import 'dart:convert'; // Para jsonEncode
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:bondi_uy/providers/app_providers.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';

// TODO: Importar widgets específicos si son necesarios (ej. para mostrar cada tramo de instrucción)

class ActiveTripView extends ConsumerStatefulWidget {
  const ActiveTripView({super.key});

  @override
  ConsumerState<ActiveTripView> createState() => _ActiveTripViewState();
}

class _ActiveTripViewState extends ConsumerState<ActiveTripView> {
  int _currentLegIndex = 0; // Manages the currently selected/highlighted instruction index
  bool _isAutoZoomEnabled = true; // For initial zoom to route bounds
  bool _followUserLocation = true; // To toggle user location tracking
  MapboxMap? mapboxMap;
  List<String> _activeRouteSourceIds = [];
  List<String> _activeRouteLayerIds = [];

  // Constantes para IDs de la ubicación del usuario
  static const String USER_LOCATION_SOURCE_ID = 'user-location-source';
  static const String USER_LOCATION_LAYER_ID = 'user-location-layer';

  // Constantes para IDs de capas y fuentes de la ruta activa
  static const String ACTIVE_WALK_SOURCE_PREFIX = 'active-walk-source-';
  static const String ACTIVE_WALK_LAYER_PREFIX = 'active-walk-layer-';
  static const String ACTIVE_BUS_SOURCE_PREFIX = 'active-bus-source-';
  static const String ACTIVE_BUS_LAYER_PREFIX = 'active-bus-layer-';
  static const String ACTIVE_WAIT_SOURCE_PREFIX = 'active-wait-source-';
  static const String ACTIVE_WAIT_LAYER_PREFIX = 'active-wait-layer-';
  // TODO: Podríamos necesitar íconos para inicio/fin de tramos o paradas específicas del viaje activo.
  // Properties for route lines
  static const Map<String, dynamic> _WALK_LINE_PROPERTIES = {
    'line-color': '#8888FF', // Light blue-ish grey for walking
    'line-width': 3.0,
    'line-dasharray': [2, 2],
  };
  static const Map<String, dynamic> _BUS_LINE_PROPERTIES = {
    'line-color': '#FF0000', // Primary color (e.g., red) for bus
    'line-width': 5.0,
  };
  static const Map<String, dynamic> _WAIT_CIRCLE_PROPERTIES = {
    'circle-color': '#FFA500', // Orange for waiting
    'circle-radius': 8.0,
    'circle-stroke-width': 2.0,
    'circle-stroke-color': '#FFFFFF',
  };

  static const Map<String, dynamic> _HIGHLIGHTED_WALK_LINE_PROPERTIES = {
    'line-color': '#5050D0', // Darker blue for highlighted walk
    'line-width': 5.0,
    'line-dasharray': [1, 0], // Solid or very short dash
  };
  static const Map<String, dynamic> _HIGHLIGHTED_BUS_LINE_PROPERTIES = {
    'line-color': '#CC0000', // Darker/brighter red for highlighted bus
    'line-width': 7.0,
  };
  static const Map<String, dynamic> _HIGHLIGHTED_WAIT_CIRCLE_PROPERTIES = {
    'circle-color': '#FF8C00', // Darker orange for highlighted waiting
    'circle-radius': 10.0,
    'circle-stroke-width': 2.5,
    'circle-stroke-color': '#FFFFFF',
  };

Future<void> _highlightCurrentLegOnMap(int legIndex) async {
    if (mapboxMap == null) return;
    final activeTripState = ref.read(appUiStateProvider).datosFaseViajeActivo;
    if (activeTripState == null) return;

    for (int i = 0; i < activeTripState.tramosDelViaje.length; i++) {
      final tramo = activeTripState.tramosDelViaje[i];
      bool isCurrent = i == legIndex;
      String layerId;
      Map<String, dynamic> properties;

      switch (tramo.tipo) {
        case TipoTramoViaje.CAMINAR:
          layerId = '$ACTIVE_WALK_LAYER_PREFIX$i';
          properties = isCurrent ? _HIGHLIGHTED_WALK_LINE_PROPERTIES : _WALK_LINE_PROPERTIES;
          break;
        case TipoTramoViaje.VIAJE_EN_BUS:
          layerId = '$ACTIVE_BUS_LAYER_PREFIX$i';
          properties = isCurrent ? _HIGHLIGHTED_BUS_LINE_PROPERTIES : _BUS_LINE_PROPERTIES;
          break;
        case TipoTramoViaje.ESPERAR_BUS:
          layerId = '$ACTIVE_WAIT_LAYER_PREFIX$i';
          properties = isCurrent ? _HIGHLIGHTED_WAIT_CIRCLE_PROPERTIES : _WAIT_CIRCLE_PROPERTIES;
          break;
        default:
          continue; // Skip unknown types
      }
      try {
        if (await mapboxMap?.style.styleLayerExists(layerId) ?? false) {
          // Iterate over properties and update them one by one
          for (var entry in properties.entries) {
            await mapboxMap?.style.setStyleLayerProperty(layerId, entry.key, entry.value);
          }
        }
      } catch (e) {
        print('Error setting layer properties for $layerId: $e');
      }
    }
  }


  @override
  void initState() {
    super.initState();
    // La lógica de dibujar la ruta y el zoom inicial se maneja en _onStyleLoaded.
    // El listener para zoomTargetActual ha sido eliminado como parte del refactor de Ticket 5.
  }

  void _onMapCreated(MapboxMap controller) {
    mapboxMap = controller;
    // El listener onStyleLoaded se encargará de dibujar la ruta cuando el estilo esté listo.
  }

  Future<void> _onStyleLoaded() async {
    if (!mounted) return;
    print("[_ActiveTripViewState] Map style loaded.");
    await _displayActiveRouteAndHighlightInitialLeg();

    // Add user location marker if available on style load
    final initialUserLocation = ref.read(appUiStateProvider).datosFaseViajeActivo?.ubicacionActualUsuario;
    if (initialUserLocation != null) {
      await _updateUserLocationOnMap(initialUserLocation);
    }
  }

  // --- Métodos para la ubicación del usuario ---
  Future<void> _updateUserLocationOnMap(Coordenada? userLocation) async {
    if (mapboxMap == null || !mounted) return;

    if (userLocation == null) {
      // Remove user location layer if it exists and location is null
      if (await mapboxMap!.style.styleLayerExists(USER_LOCATION_LAYER_ID)) {
        await mapboxMap!.style.removeStyleLayer(USER_LOCATION_LAYER_ID);
      }
      if (await mapboxMap!.style.styleSourceExists(USER_LOCATION_SOURCE_ID)) {
        await mapboxMap!.style.removeStyleSource(USER_LOCATION_SOURCE_ID);
      }
      return;
    }

    final point = Point(coordinates: Position(userLocation.longitud, userLocation.latitud));
    final geoJsonSource = {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': point.toJson(),
          'properties': {} // Add any properties if needed
        }
      ]
    };

    try {
      // Remove existing layer and source first, then add new ones.
      if (await mapboxMap!.style.styleLayerExists(USER_LOCATION_LAYER_ID)) {
        await mapboxMap!.style.removeStyleLayer(USER_LOCATION_LAYER_ID);
      }
      if (await mapboxMap!.style.styleSourceExists(USER_LOCATION_SOURCE_ID)) {
        await mapboxMap!.style.removeStyleSource(USER_LOCATION_SOURCE_ID);
      }

      // Add the new source with updated data
      await mapboxMap!.style.addSource(GeoJsonSource(id: USER_LOCATION_SOURCE_ID, data: jsonEncode(geoJsonSource)));

      // Add the new layer
      await mapboxMap!.style.addLayer(
        CircleLayer(
          id: USER_LOCATION_LAYER_ID,
          sourceId: USER_LOCATION_SOURCE_ID,
          circleColor: Colors.blue.value,
          circleRadius: 8.0,
          circleStrokeWidth: 2.0,
          circleStrokeColor: Colors.white.value,
        ),
      );
    } catch (e) {
      print("[_ActiveTripViewState] Error updating user location on map: $e");
    }

    if (_followUserLocation) {
      _centerMapOnUserLocation(userLocation);
    }
  }

  void _centerMapOnUserLocation(Coordenada userLocation) {
    if (mapboxMap == null || !mounted) return;
    mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(userLocation.longitud, userLocation.latitud)),
        zoom: 16.0, 
        pitch: 0.0,
        bearing: 0.0,
      ),
      MapAnimationOptions(duration: 900, startDelay: 0),
    );
  }

  Future<void> _displayActiveRouteAndHighlightInitialLeg() async {
    if (mapboxMap == null || !mounted) return;
    final activeTripState = ref.read(appUiStateProvider).datosFaseViajeActivo;
    if (activeTripState != null && activeTripState.tramosDelViaje.isNotEmpty) {
      List<Coordenada> todasLasCoordenadasDeLaRuta = activeTripState.tramosDelViaje
          .expand((tramo) => tramo.coordenadasDelTramo)
          .toList();

      await _displayActiveRoute(
        activeTripState.tramosDelViaje,
        _currentLegIndex, 
      );
      await _highlightCurrentLegOnMap(_currentLegIndex); // Highlight initial leg

      if (_isAutoZoomEnabled && todasLasCoordenadasDeLaRuta.isNotEmpty) {
        // Realizar el zoom inicial a los límites de la ruta mostrada.
        await _zoomToRouteBounds(todasLasCoordenadasDeLaRuta);
        // Después del primer zoom automático exitoso, lo desactivamos para que no interfiera
        // con la interacción manual, a menos que otra lógica lo reactive.
        if (mounted) {
          setState(() {
            _isAutoZoomEnabled = false;
            print("[_ActiveTripViewState] Initial auto zoom completed, _isAutoZoomEnabled set to false.");
          });
        }
      }
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

  Future<void> _displayActiveRoute(
    List<TramoViajeMostrable> tramos,
    int tramoActualIndex,
  ) async {
    if (mapboxMap == null) return;
    await _clearActiveRoute();

    List<Coordenada> todasLasCoordenadasDeLaRuta = [];

    for (int i = 0; i < tramos.length; i++) {
      final tramo = tramos[i];
      String sourceId = '';
      String layerId = '';
      Map<String, dynamic> geoJsonFeature;
      // Highlighting is now handled by _highlightCurrentLegOnMap, so direct style changes here are less critical
      // but we keep the original properties for initial drawing.
      // bool esTramoActual = i == tramoActualIndex; // This variable is not directly used for styling here anymore.

      switch (tramo.tipo) {
        case TipoTramoViaje.CAMINAR:
          sourceId = '$ACTIVE_WALK_SOURCE_PREFIX$i';
          layerId = '$ACTIVE_WALK_LAYER_PREFIX$i';
          if (tramo.geometriaPolilinea != null &&
              tramo.geometriaPolilinea!.isNotEmpty) {
            todasLasCoordenadasDeLaRuta.addAll(tramo.geometriaPolilinea!);
            geoJsonFeature = {
              "type": "Feature",
              "geometry": {
                "type": "LineString",
                "coordinates": _coordenadasToGeoJsonPositionList(
                  tramo.geometriaPolilinea!,
                ),
              },
            };
            await mapboxMap!.style.addSource(
              GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)),
            );
            await mapboxMap!.style.addLayer(
              LineLayer(
                id: layerId,
                sourceId: sourceId,
                lineColor: _parseColor(_WALK_LINE_PROPERTIES['line-color'] as String?),
                lineWidth: (_WALK_LINE_PROPERTIES['line-width'] as num?)?.toDouble(),
                lineDasharray: (_WALK_LINE_PROPERTIES['line-dasharray'] as List<dynamic>?)
                    ?.map((e) => (e as num).toDouble())
                    .toList(),
              ),
            );
            _activeRouteSourceIds.add(sourceId);
            _activeRouteLayerIds.add(layerId);
          }
          break;
        case TipoTramoViaje.VIAJE_EN_BUS:
          sourceId = '$ACTIVE_BUS_SOURCE_PREFIX$i';
          layerId = '$ACTIVE_BUS_LAYER_PREFIX$i';
          if (tramo.geometriaPolilinea != null &&
              tramo.geometriaPolilinea!.isNotEmpty) {
            todasLasCoordenadasDeLaRuta.addAll(tramo.geometriaPolilinea!);
            geoJsonFeature = {
              "type": "Feature",
              "geometry": {
                "type": "LineString",
                "coordinates": _coordenadasToGeoJsonPositionList(
                  tramo.geometriaPolilinea!,
                ),
              },
            };
            await mapboxMap!.style.addSource(
              GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)),
            );
            await mapboxMap!.style.addLayer(
              LineLayer(
                id: layerId,
                sourceId: sourceId,
                lineColor: _parseColor(_BUS_LINE_PROPERTIES['line-color'] as String?),
                lineWidth: (_BUS_LINE_PROPERTIES['line-width'] as num?)?.toDouble(),
              ),
            );
            _activeRouteSourceIds.add(sourceId);
            _activeRouteLayerIds.add(layerId);
          }
          break;
        case TipoTramoViaje.ESPERAR_BUS:
          sourceId = '$ACTIVE_WAIT_SOURCE_PREFIX$i';
          layerId = '$ACTIVE_WAIT_LAYER_PREFIX$i';
          if (tramo.posicionPunto != null) {
            todasLasCoordenadasDeLaRuta.add(tramo.posicionPunto!);
            geoJsonFeature = {
              "type": "Feature",
              "geometry": {
                "type": "Point",
                "coordinates": _coordenadaToGeoJsonPosition(
                  tramo.posicionPunto!,
                ),
              },
            };
            await mapboxMap!.style.addSource(
              GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)),
            );
            await mapboxMap!.style.addLayer(
              CircleLayer(
                id: layerId,
                sourceId: sourceId,
                circleColor: _parseColor(_WAIT_CIRCLE_PROPERTIES['circle-color'] as String?),
                circleRadius: (_WAIT_CIRCLE_PROPERTIES['circle-radius'] as num?)?.toDouble(),
                circleStrokeWidth: (_WAIT_CIRCLE_PROPERTIES['circle-stroke-width'] as num?)?.toDouble(),
                circleStrokeColor: _parseColor(_WAIT_CIRCLE_PROPERTIES['circle-stroke-color'] as String?),
              ),
            );
            _activeRouteSourceIds.add(sourceId);
            _activeRouteLayerIds.add(layerId);
          }
          break;
      }
    }

    if (todasLasCoordenadasDeLaRuta.isNotEmpty && mapboxMap != null) {
      final mapboxPoints =
          todasLasCoordenadasDeLaRuta
              .map((c) => Point(coordinates: Position(c.longitud, c.latitud)))
              .toList();
      try {
        final cameraOptions = await mapboxMap!.cameraForCoordinates(
          mapboxPoints,
          MbxEdgeInsets(
            top: 80.0,
            left: 40.0,
            bottom: (MediaQuery.of(context).size.height * 0.35), // Ajustar padding para panel de instrucciones
            right: 40.0,
          ), // Ajustar padding para panel de instrucciones
          null,
          null,
        );
        mapboxMap!.flyTo(cameraOptions, MapAnimationOptions(duration: 1200));
      } catch (e) {
        print("[_ActiveTripViewState] Error zooming to active route: $e");
      }
    }
    // TODO: Llamar a _highlightCurrentLeg(tramoActualIndex) después de dibujar todo.
  }

  Future<void> _clearActiveRoute() async {
    if (mapboxMap == null) return;
    for (String layerId in _activeRouteLayerIds) {
      try {
        if (await mapboxMap!.style.styleLayerExists(layerId)) {
          await mapboxMap!.style.removeStyleLayer(layerId);
        }
      } catch (e) {
        print("Error removing layer $layerId: $e");
      }
    }
    for (String sourceId in _activeRouteSourceIds) {
      try {
        if (await mapboxMap!.style.styleSourceExists(sourceId)) {
          await mapboxMap!.style.removeStyleSource(sourceId);
        }
      } catch (e) {
        print("Error removing source $sourceId: $e");
      }
    }
    _activeRouteLayerIds.clear();
    _activeRouteSourceIds.clear();
  }

  // TODO: Función para actualizar la posición del bus en tiempo real en el mapa.
  // Future<void> _updateRealTimeBusPosition(Coordenada posicionBus) async { ... }

  // TODO: Función para resaltar el tramo actual en el mapa.
  // Future<void> _highlightCurrentLeg(int tramoIndex) async { ... }

  int? _parseColor(String? hexColor) {
    if (hexColor == null) return null;
    final buffer = StringBuffer();
    if (hexColor.length == 6 || hexColor.length == 7) buffer.write('ff'); // Add alpha if missing
    buffer.write(hexColor.replaceFirst('#', ''));
    return int.tryParse(buffer.toString(), radix: 16);
  }

  void _handleMapIdle(MapIdleEventData data) {
    // Cuando el usuario interactúa manualmente con el mapa, desactivamos el auto-zoom inicial y el seguimiento de usuario.
    if (mounted && (_isAutoZoomEnabled || _followUserLocation)) {
      setState(() {
        _isAutoZoomEnabled = false;
        _followUserLocation = false;
        print("[_ActiveTripViewState] Map idle detected, _isAutoZoomEnabled and _followUserLocation set to false.");
      });
    }
  }

  // Método refactorizado para hacer zoom a un conjunto de coordenadas (límites).
  // El antiguo _performAutomaticZoom(ZoomTarget target) se reemplaza por este método más específico.
  Future<void> _zoomToRouteBounds(List<Coordenada> routeCoordinates) async {
    if (!mounted || mapboxMap == null || routeCoordinates.isEmpty) {
      print("[_ActiveTripViewState] Zoom to route bounds skipped: map not ready, or no coordinates.");
      return;
    }
    print("[_ActiveTripViewState] Performing zoom to route bounds.");

    if (routeCoordinates.length == 1) {
      // Si solo hay una coordenada, centrar el mapa en ella con un zoom razonable.
      final singlePoint = routeCoordinates.first;
      final cameraOptions = CameraOptions(
        center: Point(coordinates: Position(singlePoint.longitud, singlePoint.latitud)),
        zoom: 16.0, // Zoom predeterminado para un solo punto
        padding: MbxEdgeInsets(
            top: 80.0, 
            left: 40.0, 
            bottom: (MediaQuery.of(context).size.height * 0.33), // Considerar panel de instrucciones
            right: 40.0),
      );
      if (mounted) {
        try {
          await mapboxMap!.flyTo(
            cameraOptions,
            MapAnimationOptions(duration: 1200, startDelay: 0),
          );
          print("[_ActiveTripViewState] Flew to single point successfully.");
        } catch (e) {
          print("[_ActiveTripViewState] Error during flyTo single point: $e");
        }
      }
      return;
    }

    // Calcular los límites (bounds) a partir de la lista de coordenadas
    double minLat = routeCoordinates.first.latitud;
    double maxLat = routeCoordinates.first.latitud;
    double minLng = routeCoordinates.first.longitud;
    double maxLng = routeCoordinates.first.longitud;

    for (var coord in routeCoordinates.skip(1)) {
      if (coord.latitud < minLat) minLat = coord.latitud;
      if (coord.latitud > maxLat) maxLat = coord.latitud;
      if (coord.longitud < minLng) minLng = coord.longitud;
      if (coord.longitud > maxLng) maxLng = coord.longitud;
    }

    Point southwest = Point(coordinates: Position(minLng, minLat));
    Point northeast = Point(coordinates: Position(maxLng, maxLat));

    CameraOptions cameraOptions;
    try {
      // El panel de instrucciones en ActiveTripView tiene initialChildSize: 0.3, puede llegar a 0.65
      final MbxEdgeInsets padding = MbxEdgeInsets(
        top: 80.0, // Espacio para posible AppBar o notificaciones
        left: 40.0,
        bottom: (MediaQuery.of(context).size.height * 0.35), // 33% del panel + pequeño margen
        right: 40.0,
      );
      cameraOptions = await mapboxMap!.cameraForCoordinateBounds(
        CoordinateBounds(southwest: southwest, northeast: northeast, infiniteBounds: false),
        padding, 
        null, 
        null,
        null, // maxZoom
        null  // offset
      );
      print("[_ActiveTripViewState] Calculated camera for bounds: ${cameraOptions.encode()}");
    } catch (e) {
      print("[_ActiveTripViewState] Error calculating camera for bounds: $e");
      return;
    }

    if (mounted) {
      try {
        await mapboxMap!.flyTo(
          cameraOptions,
          MapAnimationOptions(duration: 1200, startDelay: 0),
        );
        print("[_ActiveTripViewState] flyTo to route bounds executed successfully.");
      } catch (e) {
        print("[_ActiveTripViewState] Error during flyTo to route bounds: $e");
      }
    }
    // No se deshabilita _isAutoZoomEnabled aquí. Se deshabilita en _onStyleLoaded después del primer zoom,
    // o en _handleMapIdle si el usuario interactúa.
  }

  @override
  Widget build(BuildContext context) {
    final appUiState = ref.watch(appUiStateProvider);
    final activeTripData = appUiState.datosFaseViajeActivo;

    // Actualizar la ubicación del usuario en el mapa cuando cambie en el estado
    // Usamos addPostFrameCallback para asegurar que se ejecute después de que el build complete
    // y el mapboxMap esté potencialmente listo o actualizado.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && activeTripData != null) {
        _updateUserLocationOnMap(activeTripData.ubicacionActualUsuario);
      }
    });

    final appLogic = ref.read(appLogicProvider);
    final activeTripState = appUiState.datosFaseViajeActivo;

    if (activeTripState == null) {
      // Esto no debería pasar si faseActual es VIAJE_ACTIVO_EN_CURSO.
      // Podría indicar un problema de estado. Volver a la fase inicial.
      Future.microtask(
        () => appLogic.usuarioCanceloBusquedaOSeleccionRuta(),
      ); // O una acción más específica para error en viaje activo.
      return const Scaffold(
        body: Center(
          child: Text("Error: Estado de viaje activo no disponible."),
        ),
      );
    }

    final OpcionDeRutaMostrable viajeConfirmado =
        activeTripState.opcionDeRutaSeleccionada;
    final List<TramoViajeMostrable> tramosDelViaje =
        activeTripState.tramosDelViaje;

    return Scaffold(
      // ...
      body: Stack(
        children: [
          MapWidget(
            onMapIdleListener: _handleMapIdle,
            key: const ValueKey("active_trip_map"),
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(-56.164532, -34.901112), // Montevideo default
              ),
              zoom: 12.0,
            ),
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: (_) async => await _onStyleLoaded(), // Corrected to call the new _onStyleLoaded
          ),
          // ...
          // Panel de Instrucciones Mejorado
          _ActiveTripInstructionsPanel(
            activeTripState: activeTripState,
            appLogic: appLogic,
            currentLegIndex: _currentLegIndex,
            onLegSelected: (newIndex) {
              setState(() {
                _currentLegIndex = newIndex;
                _highlightCurrentLegOnMap(newIndex);
                // Si el seguimiento de usuario está activo, podríamos querer desactivarlo al seleccionar manualmente un tramo
                // o ajustar el zoom al tramo seleccionado.
                // if (_followUserLocation) _followUserLocation = false;
                // TODO: Considerar ajustar el zoom del mapa al tramo seleccionado if _followUserLocation is false or _isAutoZoomEnabled is false
              });
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _followUserLocation = !_followUserLocation;
            if (_followUserLocation) {
              _isAutoZoomEnabled = false; // Si activamos seguir usuario, el zoom inicial ya no aplica
              final currentUserLocation = ref.read(appUiStateProvider).datosFaseViajeActivo?.ubicacionActualUsuario;
              if (currentUserLocation != null) {
                _centerMapOnUserLocation(currentUserLocation);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Siguiendo ubicación del usuario.'), duration: Duration(seconds: 2)),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Seguimiento de ubicación desactivado.'), duration: Duration(seconds: 2)),
              );
            }
          });
        },
        tooltip: _followUserLocation ? 'Dejar de seguir ubicación' : 'Seguir ubicación',
        backgroundColor: _followUserLocation ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
        foregroundColor: _followUserLocation ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
        child: Icon(_followUserLocation ? Icons.my_location : Icons.location_searching),
      ),
    );
  }

  // ...
}

// ...

class _ActiveTripInstructionsPanel extends StatelessWidget {
  final EstadoFaseViajeActivo activeTripState;
  final IAppLogic appLogic;
  final int currentLegIndex;
  final void Function(int) onLegSelected;
  final VoidCallback? onPreviousLeg;
  final VoidCallback? onNextLeg;

  const _ActiveTripInstructionsPanel({
    required this.activeTripState,
    required this.appLogic,
    required this.currentLegIndex,
    required this.onLegSelected,
    this.onPreviousLeg,
    this.onNextLeg,
  });

  @override
  Widget build(BuildContext context) {
    if (activeTripState.tramosDelViaje.isEmpty) {
      return const SizedBox.shrink(); // No mostrar nada si no hay tramos
    }

    // Determinar información del tramo actual para mostrar en la parte superior del panel (cuando esté colapsado)
    final TramoViajeMostrable tramoActual = (currentLegIndex >= 0 && currentLegIndex < activeTripState.tramosDelViaje.length) 
                                            ? activeTripState.tramosDelViaje[currentLegIndex] 
                                            : activeTripState.tramosDelViaje.first; // Fallback al primer tramo si el índice es inválido

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: DraggableScrollableSheet(
        // ...
        builder: (BuildContext context, ScrollController scrollController) {
          return Card(
            // ...
            child: Column(
              mainAxisSize: MainAxisSize.min, // Important for DraggableScrollableSheet content
              children: [
                // Handle para arrastrar
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 8.0, 8.0), // Added bottom padding
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios),
                        onPressed: onPreviousLeg,
                        tooltip: 'Anterior',
                      ),
                      Expanded(
                        child: Text(
                          tramoActual.descripcion, // Mostrar descripción del tramo actual
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        onPressed: onNextLeg,
                        tooltip: 'Siguiente',
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.close, size: 20),
                        label: const Text("Finalizar"),
                        onPressed: () => appLogic.detenerSeguimientoActivo(),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                          padding: const EdgeInsets.symmetric(horizontal: 8.0) // Adjust padding
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // ...
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: activeTripState.tramosDelViaje.length,
                    itemBuilder: (context, index) {
                      final tramo = activeTripState.tramosDelViaje[index];
                      bool esTramoActual = index == currentLegIndex;
                      return _TramoInstruccionListItem(
                        tramo: tramo,
                        esTramoActual: esTramoActual,
                        onTap: () => onLegSelected(index),
                      );
                    },
                    separatorBuilder: (context, index) => const Divider(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- Widget para cada ítem de instrucción en la lista ---
class _TramoInstruccionListItem extends StatelessWidget {
  final TramoViajeMostrable tramo;
  final bool esTramoActual;
  final VoidCallback? onTap; // TODO: Conectar onTap si es necesario

  const _TramoInstruccionListItem({
    required this.tramo,
    required this.esTramoActual,
    this.onTap,
  });

  IconData _getIconForTramo(TipoTramoViaje tipo) {
    switch (tipo) {
      case TipoTramoViaje.CAMINAR:
        return Icons.directions_walk;
      case TipoTramoViaje.ESPERAR_BUS:
        return Icons.time_to_leave;
      case TipoTramoViaje.VIAJE_EN_BUS:
        return Icons.directions_bus;
      default:
        return Icons.device_unknown; // Icono por defecto
    }
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes;
    if (minutes < 1) return "< 1 min";
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    Color tileColor = esTramoActual ? colorScheme.primary.withOpacity(0.1) : Colors.transparent;
    Color iconColor = esTramoActual ? colorScheme.primary : colorScheme.secondary;
    FontWeight titleFontWeight = esTramoActual ? FontWeight.bold : FontWeight.w500;


    return InkWell(
      onTap: onTap,
      splashColor: colorScheme.primary.withOpacity(0.2),
      child: Container(
        color: tileColor, // Resaltar tramo actual
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_getIconForTramo(tramo.tipo), size: 32, color: iconColor),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tramo.descripcion,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: titleFontWeight,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    "Duración: ${_formatDuration(tramo.duracionEstimadaSegundos)}${tramo.distanciaMetros > 0 ? '  •  Distancia: ${tramo.distanciaMetros} m' : ''}",
                    style: textTheme.bodyMedium?.copyWith(
                      color: textTheme.bodySmall?.color,
                      height: 1.2,
                    ),
                  ),
                  if (tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS &&
                      tramo.nombreLineaBus != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        "Línea: ${tramo.nombreLineaBus}${tramo.destinoFinalDelBus != null ? ' (Destino: ${tramo.destinoFinalDelBus})' : ''}",
                        style: textTheme.bodySmall?.copyWith(height: 1.2),
                      ),
                    ),
                  if (tramo.tipo == TipoTramoViaje.ESPERAR_BUS &&
                      tramo.nombreLineaBus != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        "Esperar Línea: ${tramo.nombreLineaBus}${tramo.destinoFinalDelBus != null ? ' (Destino: ${tramo.destinoFinalDelBus})' : ''}",
                        style: textTheme.bodySmall?.copyWith(height: 1.2),
                      ),
                    ),
                  // TODO: Mostrar ETA del bus si está disponible para este tramo
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
