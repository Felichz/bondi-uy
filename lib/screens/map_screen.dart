import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:math' as math;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Ajustar las rutas de importación según la nueva ubicación
import '../models/point_dart.dart';
import '../models/itinerary.dart';
import '../models/route_leg.dart';
import '../utils/haversine.dart';
import '../widgets/compose_with_origin.dart';
import '../widgets/search_panel.dart';
import '../widgets/instructions_bar.dart';
import '../widgets/route_options_panel.dart';
import '../services/mapbox_service.dart';
import '../utils/geometry_utils.dart';
import '../utils/geometry_utils.dart' as geometry_utils;

// Importar proveedores y estado
import '../providers/service_providers.dart';
import '../providers/map_notifier.dart';
import '../state/map_state.dart';

// Cambiar a ConsumerStatefulWidget
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  // Cambiar a ConsumerState
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

// Cambiar a ConsumerState<MapScreen>
class _MapScreenState extends ConsumerState<MapScreen> {
  MapboxMap? mapboxMap;
  final CameraOptions _initialCameraOptions = CameraOptions(
    center: Point(
      coordinates: Position(
        -56.164532, // Longitud de Montevideo
        -34.901112, // Latitud de Montevideo
      ),
    ),
    zoom: 12.0,
  );

  // Controladores para los campos de texto de Origen y Destino
  late TextEditingController _origenController;
  late TextEditingController _destinoController;

  // Coordenadas para Origen y Destino AHORA EN MapState
  // Point? _origenCoordinates;
  // Point? _destinoCoordinates;

  // Referencias a los servicios (AHORA SE ACCEDEN VIA PROVIDERS O SON LOCALES)
  // late final ValueNotifier<GraphQLClient> _otpGqlClient; // Ya no se usa directamente aquí
  // late final MontevideoApiService _montevideoApiService; // Vía provider
  // late final OtpService _otpService; // Vía provider
  // late final GeocodingService _geocodingService; // Vía provider
  MapboxService? _mapboxService; // Sigue siendo local, necesita mapboxMap

  // IDs específicos para la gestión interna de capas/fuentes en esta pantalla si es necesario,
  // pero preferiblemente usar las constantes de MapboxService si existen allí.
  static const String REALTIME_BUS_SOURCE_ID = "realtime-bus-source";
  static const String REALTIME_BUS_LAYER_ID = "realtime-bus-layer";
  static const String REALTIME_BUS_DOTS_LAYER_ID = "realtime-bus-dots-layer";
  // static const String HIGHLIGHTED_REALTIME_BUS_ICON_ID = "highlighted-realtime-bus-icon"; // No usado directamente

  // Prefijos para capas/fuentes de ruta OTP (mantener si se usan dinámicamente aquí)
  static const String OTP_ROUTE_SOURCE_PREFIX = "otp-route-source-";
  static const String OTP_ROUTE_LAYER_PREFIX = "otp-route-layer-";

  // Prefijos para capas/fuentes de shape de línea base (mantener si se usan dinámicamente aquí)
  static const String FULL_BUS_LINE_SHAPE_SOURCE_ID_PREFIX =
      "full-bus-line-shape-source-";
  static const String FULL_BUS_LINE_SHAPE_LAYER_ID_PREFIX =
      "full-bus-line-shape-layer-";
  String?
  _currentFullLineShapeId; // Sigue siendo local (manejo de limpieza de capa específica)

  // Estado de la UI (AHORA EN MapState o manejado por el notifier)
  late FocusNode _origenFocusNode;
  late FocusNode _destinoFocusNode;
  Timer?
  _debounceTimer; // Para la búsqueda de geocoding (Sigue local, interactúa con GeocodingService)
  // bool _isCalculatingRoute = false; // EN MapState
  // bool _showCollapsedInstructionsBar = false; // EN MapState
  // List<dynamic> _currentRouteLegs = []; // EN MapState
  // int? _selectedLegIndex; // EN MapState
  // bool _isInOverviewMode = false; // EN MapState
  // bool _isSearchPanelExpanded = true; // NO USADO, eliminar o manejar en SearchPanel
  // List<Map<String, dynamic>> _availableItineraries = []; // EN MapState

  // Estado del rastreo de bus en tiempo real (Parte en MapState, parte local)
  Timer? _realtimeBusTimer; // Sigue siendo local (controla el fetch periódico)
  // String? _trackedBusLineShortName; // EN MapState
  Map<String, List<Position>> _shapeGeometries =
      {}; // Sigue local (cargado una vez)
  bool _shapesLoaded = false; // Sigue local (cargado una vez)
  List<Position>?
  _currentFullShapeForBusLeg; // Sigue local (necesario para lógica de dibujo/cálculo)
  int? _originStopIndexOnShape; // Sigue local
  int? _destinationStopIndexOnShape; // Sigue local
  // Position? _highlightedBusPosition; // EN MapState

  // Estado del movimiento del mapa (Parte en MapState, parte local)
  // bool _userManuallyMovedMap = false; // EN MapState
  bool _isProgrammaticCameraMove =
      false; // Sigue local (controla lógica de _onMapIdle y _onMapCameraChange)
  bool _isWaitingForInitialLegZoomToComplete =
      false; // Sigue local (controla lógica de _onMapIdle)

  @override
  void initState() {
    super.initState();
    _origenController = TextEditingController();
    _destinoController = TextEditingController();
    _origenFocusNode = FocusNode();
    _destinoFocusNode = FocusNode();

    // Mover listeners de efectos secundarios aquí
    // Listener para mostrar RouteOptionsModal
    ref.listenManual<MapState>(mapNotifierProvider, (previous, next) {
      // Usamos next.availableItineraries directamente ya que listenManual puede llamarse al inicio
      if (next.availableItineraries.isNotEmpty && !next.isCalculatingRoute) {
        // Comprobar si realmente es un cambio nuevo para evitar mostrar el modal múltiples veces
        // si el listener se dispara por otras razones (aunque listenManual ayuda con esto)
        bool itinerariesChanged =
            previous == null ||
            previous.availableItineraries != next.availableItineraries;
        if (itinerariesChanged) {
          _clearPreviousRouteLayers().then((_) {
            _stopTrackingBusLine();
            if (mounted) {
              showRouteOptionsModal(
                context: context,
                availableItineraries: next.availableItineraries,
                fetchUpcomingBuses: _fetchUpcomingBuses,
                processAndDisplaySelectedItinerary: (Itinerary itinerary) {
                  ref
                      .read(mapNotifierProvider.notifier)
                      .processSelectedItinerary(itinerary);
                  // El dibujo (processAndDisplaySelectedItineraryUI) se activará por el listener en build (o podría moverse aquí también)
                },
              );
            }
          });
        }
      }
    });

    // Listener para iniciar navegación detallada
    ref.listenManual<MapState>(mapNotifierProvider, (previous, next) {
      // Comprobar el cambio de estado específico
      bool shouldStartNav =
          (previous == null || previous.isInOverviewMode) &&
          !next.isInOverviewMode &&
          next.selectedLegIndex == 0;
      if (shouldStartNav) {
        if (next.currentRouteLegs.isNotEmpty && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // Doble check por si se desmonta durante el post-frame
              _isWaitingForInitialLegZoomToComplete = true; // Sigue local
              _zoomToLeg(0);
              _updateMapRouteHighlight();
              _updateBusTrackingBasedOnLeg(0);
            }
          });
        }
      }
    });

    // Listener para mostrar errores
    ref.listenManual<String?>(
      mapNotifierProvider.select((state) => state.errorMessage),
      (prevError, nextError) {
        if (nextError != null && nextError.isNotEmpty) {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                // Re-check mounted
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(nextError),
                    backgroundColor: Colors.redAccent,
                    action: SnackBarAction(
                      label: "OK",
                      textColor: Colors.white,
                      onPressed: () {
                        ref
                            .read(mapNotifierProvider.notifier)
                            .clearErrorMessage();
                      },
                    ),
                  ),
                );
              }
            });
          }
        }
      },
    );

    _loadAndParseShapesGeoJson(); // Llamar al método existente
  }

  @override
  void dispose() {
    _origenController.dispose();
    _destinoController.dispose();
    _debounceTimer?.cancel();
    _mapboxService?.stopTooltipFloatingAnimation();
    _origenFocusNode.dispose();
    _destinoFocusNode.dispose();
    _stopTrackingBusLine(); // Asegurarse de que esto usa el estado del notifier si es necesario
    mapboxMap?.dispose();
    super.dispose();
  }

  _onMapCreated(MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    // MapboxService sigue siendo local
    _mapboxService = MapboxService(this.mapboxMap!);
    // La carga de datos/imágenes se hará en _onStyleLoadedListener a través del servicio
  }

  void _onStyleLoadedListener(StyleLoadedEventData event) async {
    if (_mapboxService != null) {
      await _mapboxService!.handleStyleLoaded();
    } else {
      print(
        "[MapScreen_Debug] MapboxService no inicializado en _onStyleLoadedListener.",
      );
    }
  }

  void _handleMapTapEvent(MapContentGestureContext context) async {
    if (mapboxMap == null || _mapboxService == null) return;
    // _showBusLinesForStop será llamado como callback desde handleMapTap
    await _mapboxService!.handleMapTap(context, _showBusLinesForStop);
  }

  void _showBusLinesForStop(String stopId, String stopName) {
    print("Solicitando líneas para la parada: $stopName (ID: $stopId)");
    _fetchAndDisplayBusLines(stopId, stopName);
  }

  Future<void> _fetchAndDisplayBusLines(String stopId, String stopName) async {
    print(
      "[MapScreen_Debug] Obteniendo líneas para stopId: $stopId desde la API (usando servicio)...",
    );

    // Usar el provider para MontevideoApiService
    final montevideoApiService = ref.read(montevideoApiServiceProvider);
    List<Map<String, String>> busLinesData = [];
    String errorMessage = 'No hay información de líneas para esta parada.';

    try {
      busLinesData = await montevideoApiService.fetchBusLinesForStop(stopId);
      if (busLinesData.isEmpty) {
        errorMessage =
            'No se encontraron líneas para esta parada (respuesta del servicio vacía).';
      }
    } catch (e, s) {
      errorMessage = "Excepción al obtener líneas desde el servicio: $e";
      print("[MapScreen_Debug] $errorMessage");
      print("[MapScreen_Debug] StackTrace: $s");
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Container(
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                ListTile(
                  title: Text(
                    'Parada: $stopName (ID: $stopId)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const Divider(),
                if (busLinesData.isNotEmpty)
                  ...busLinesData.map(
                    (lineInfo) => ListTile(
                      leading: CircleAvatar(
                        child: Text(lineInfo['line'] ?? '?'),
                      ),
                      title: Text('Línea: ${lineInfo['line']}'),
                      subtitle: Text('ID Variante: ${lineInfo['lineId']}'),
                      onTap: () {
                        Navigator.pop(context);
                        print(
                          "Línea ${lineInfo['line']} (ID: ${lineInfo['lineId']}) seleccionada para parada $stopId",
                        );
                        // TODO: Implementar visualización de la ruta de esta línea
                        // Esto podría implicar llamar a un método en MapNotifier
                      },
                    ),
                  )
                else
                  ListTile(title: Text(errorMessage)),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadAndParseShapesGeoJson() async {
    if (_shapesLoaded) {
      print("[MapScreen_Debug] shapes.geojson ya cargado.");
      return;
    }
    try {
      print("[MapScreen_Debug] Cargando y parseando shapes.geojson...");
      final String geoJsonString = await rootBundle.loadString(
        'assets/data/shapes.geojson',
      );
      final Map<String, dynamic> geoJsonData = json.decode(geoJsonString);
      final List<dynamic> features = geoJsonData['features'] ?? [];

      for (var feature in features) {
        final properties = feature['properties'];
        final geometry = feature['geometry'];

        if (properties != null && geometry != null) {
          final String? shapeId = MapboxService.getStringValue(
            properties['shape_id'],
          );
          if (shapeId != null &&
              shapeId.isNotEmpty &&
              geometry['type'] == 'LineString') {
            final List<dynamic> coordinates = geometry['coordinates'] ?? [];
            List<Position> positions =
                coordinates
                    .map(
                      (coord) => Position(
                        (coord[0] as num).toDouble(),
                        (coord[1] as num).toDouble(),
                      ),
                    )
                    .toList();
            if (positions.length >= 2) {
              _shapeGeometries[shapeId] = positions;
            }
          }
        }
      }
      _shapesLoaded = true;
      print(
        "[MapScreen_Debug] Parseo de shapes.geojson completado. ${_shapeGeometries.length} shapes cargados.",
      );
      if (_shapeGeometries.isEmpty) {
        print(
          "[MapScreen_Debug] ADVERTENCIA: No se cargaron geometrías de shapes. Verifica 'assets/data/shapes.geojson' y su estructura.",
        );
      }
    } catch (e, s) {
      print("[MapScreen_Debug] Error cargando o parseando shapes.geojson: $e");
      print(s);
    }
  }

  // _handleSearchRouteWithGraphQl AHORA ESTÁ EN MapNotifier como searchRoute()
  // EL BOTÓN EN SearchPanel llamará a ref.read(mapNotifierProvider.notifier).searchRoute();

  void _showNoRouteFoundMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    // El estado isCalculatingRoute se maneja en el notifier
    final mapNotifier = ref.read(mapNotifierProvider.notifier);
    if (ref.read(mapNotifierProvider).isCalculatingRoute) {
      mapNotifier.state = mapNotifier.state.copyWith(isCalculatingRoute: false);
    }
  }

  Future<void> _clearPreviousRouteLayers() async {
    if (mapboxMap == null || _mapboxService == null) return;
    print("[MapScreen_Debug] Limpiando capas y fuentes de ruta anteriores...");

    await _mapboxService!.clearAllRouteLayersAndSources();

    // Actualizar estado a través del notifier
    // El notifier ya hace esto en clearRouteState o cuando se obtienen nuevos itinerarios
    // ref.read(mapNotifierProvider.notifier).clearRouteVisuals(); // Podría ser un método específico

    // Asegurar que la capa general de paradas sea visible después de limpiar una ruta
    try {
      if (await mapboxMap!.style.styleLayerExists(
        MapboxService.STOPS_LAYER_ID,
      )) {
        await mapboxMap!.style.setStyleLayerProperty(
          MapboxService.STOPS_LAYER_ID,
          "visibility",
          "visible",
        );
      }
    } catch (e) {
      print(
        "[MapScreen_Debug] Error restaurando visibilidad de capa ${MapboxService.STOPS_LAYER_ID}: $e",
      );
    }
  }

  Future<void> _updateMapRouteHighlight() async {
    if (mapboxMap == null || _mapboxService == null) return;
    final selectedLegIndex = ref.read(mapNotifierProvider).selectedLegIndex;
    await _mapboxService!.updateMapRouteHighlight(selectedLegIndex);
  }

  void _showTripInstructionsBottomSheet(List<RouteLeg> legs) {
    if (!mounted || legs.isEmpty) return;
    final mapState = ref.read(mapNotifierProvider);
    final mapNotifier = ref.read(mapNotifierProvider.notifier);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (BuildContext bc) {
        return StatefulBuilder(
          // StatefulBuilder para el estado local del BottomSheet
          builder: (BuildContext context, StateSetter setModalState) {
            // Releer el estado dentro del builder para asegurar que esté actualizado si el notifier cambia.
            // Aunque para selectedLegIndex, dependemos de setModalState para el repintado inmediato del BottomSheet.
            int? currentSelectedLegIndex =
                ref.watch(mapNotifierProvider).selectedLegIndex;

            List<Widget> buildInstructionListTiles(
              List<RouteLeg> currentLegs, // Aceptar List<RouteLeg>
              int? currentSelectedLeg,
              Function(int legIndex) onLegSelected,
            ) {
              List<Widget> instructionTiles = [];
              String origenDisplayName =
                  currentLegs.first.from.name ?? 'Punto de inicio';
              if (origenDisplayName.toLowerCase() == 'origin' &&
                  _origenController.text.isNotEmpty) {
                origenDisplayName = _origenController.text;
              }
              instructionTiles.add(
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text("Origen: $origenDisplayName"),
                  dense: true,
                ),
              );

              for (int i = 0; i < currentLegs.length; i++) {
                final RouteLeg leg = currentLegs[i];
                final String mode = leg.mode.toUpperCase();
                final String fromName =
                    leg.from.name ?? 'Ubicación desconocida';
                final String toName = leg.to.name ?? 'Ubicación desconocida';
                final int distance = leg.distance.round();
                final int durationMinutes = (leg.duration / 60).round();
                String durationText = " (~${durationMinutes} min)";
                if (durationMinutes == 0 && leg.duration > 0)
                  durationText = " (< 1 min)";
                else if (durationMinutes == 0)
                  durationText = "";

                IconData iconData = Icons.help_outline;
                Color iconColor = Colors.grey;
                String title = "";
                String subtitle = "";
                bool isThreeLine = false;

                if (mode == 'WALK') {
                  iconData = Icons.directions_walk;
                  iconColor = Colors.blueAccent;
                  String walkDestinationDisplay = toName;
                  if (toName.toLowerCase() == 'destination' &&
                      i == currentLegs.length - 1 &&
                      _destinoController.text.isNotEmpty) {
                    walkDestinationDisplay = _destinoController.text;
                  }
                  title =
                      "Caminar ${distance}m hacia $walkDestinationDisplay$durationText";
                } else if (mode == 'BUS' || mode == 'TRANSIT') {
                  iconData = Icons.directions_bus;
                  iconColor = Colors.deepOrangeAccent;
                  final lineName =
                      leg.route?.shortName ??
                      leg.route?.longName ??
                      'Bus desconocido';
                  title = "Tomar bus línea $lineName$durationText";
                  subtitle = "Desde: $fromName \\nHasta: $toName";
                  isThreeLine = true;
                } else {
                  title = "$mode ${distance}m$durationText";
                  subtitle = "Desde: $fromName, Hasta: $toName";
                  isThreeLine = true;
                }
                final int currentLegIndexForTap = i;
                instructionTiles.add(
                  ListTile(
                    leading: Icon(iconData, color: iconColor),
                    title: Text(title),
                    subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                    isThreeLine: isThreeLine,
                    dense: true,
                    selected:
                        currentSelectedLeg == i, // Usar el estado del notifier
                    selectedTileColor: iconColor.withOpacity(0.15),
                    onTap: () => onLegSelected(currentLegIndexForTap),
                  ),
                );
              }
              String destinoDisplayName =
                  currentLegs.last.to.name ?? 'Punto final';
              if (destinoDisplayName.toLowerCase() == 'destination' &&
                  _destinoController.text.isNotEmpty) {
                destinoDisplayName = _destinoController.text;
              }
              instructionTiles.add(
                ListTile(
                  leading: const Icon(Icons.flag, color: Colors.green),
                  title: Text("Destino: $destinoDisplayName"),
                  dense: true,
                ),
              );
              return instructionTiles;
            }

            final instructionWidgets = buildInstructionListTiles(
              mapState.currentRouteLegs, // Pasar List<RouteLeg>
              currentSelectedLegIndex,
              (int tappedLegIndex) {
                mapNotifier.setSelectedLegIndex(tappedLegIndex);
                // _userManuallyMovedMap y _isWaitingForInitialLegZoomToComplete se manejan en el notifier o localmente
                _isWaitingForInitialLegZoomToComplete = true;
                _updateMapRouteHighlight(); // Depende del estado del notifier
                _zoomToLeg(tappedLegIndex); // Depende del estado del notifier
                setModalState(() {}); // Actualizar el BottomSheet
              },
            );

            return SafeArea(
              child: FractionallySizedBox(
                heightFactor: 0.6,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                      child: Text(
                        'Instrucciones de Viaje',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: instructionWidgets.length,
                          itemBuilder:
                              (context, index) => instructionWidgets[index],
                          separatorBuilder:
                              (context, index) => const SizedBox(height: 4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _applyOverviewRouteStyle() async {
    if (mapboxMap == null || _mapboxService == null) return;
    await _mapboxService!.applyOverviewRouteStyle();
  }

  // _startDetailedNavigation AHORA ESTÁ EN MapNotifier
  // EL BOTÓN "Iniciar Viaje" llamará a ref.read(mapNotifierProvider.notifier).startDetailedNavigation();
  // Y luego, basado en el estado, se llamará a _zoomToLeg(0) y _updateMapRouteHighlight()
  // Y se iniciará el rastreo del bus si es necesario.

  Future<void> _zoomToLeg(int legIndex) async {
    if (mapboxMap == null || _mapboxService == null) return;
    final mapState = ref.read(mapNotifierProvider);
    if (legIndex < 0 || legIndex >= mapState.currentRouteLegs.length) return;

    _isProgrammaticCameraMove = true; // Sigue siendo local
    bool success = false;

    Position? busPositionToInclude;
    final RouteLeg currentLeg = mapState.currentRouteLegs[legIndex];
    final String mode = currentLeg.mode.toUpperCase();

    // userManuallyMovedMap y highlightedBusPosition vienen del estado
    if ((mode == 'BUS' || mode == 'TRANSIT') &&
        !mapState.userManuallyMovedMap &&
        mapState.highlightedBusPosition != null) {
      busPositionToInclude = mapState.highlightedBusPosition;
    }

    success = await _mapboxService!.zoomToLeg(
      mapState.currentRouteLegs,
      legIndex,
      busPositionToInclude,
      mapState.showCollapsedInstructionsBar, // Viene del estado
    );

    if (!success) {
      _isProgrammaticCameraMove = false;
      print(
        "[MapScreen_Debug_GraphQL] Falló el servicio zoomToLeg para el tramo $legIndex. _isProgrammaticCameraMove reseteado.",
      );
    }
  }

  void _navigateToPreviousLeg() {
    final mapState = ref.read(mapNotifierProvider);
    final mapNotifier = ref.read(mapNotifierProvider.notifier);
    if (mapState.selectedLegIndex == null ||
        mapState.selectedLegIndex! <= 0 ||
        !mounted)
      return;

    final newLegIndex = mapState.selectedLegIndex! - 1;
    mapNotifier.setSelectedLegIndex(newLegIndex);
    _isWaitingForInitialLegZoomToComplete = true; // Sigue local

    _updateMapRouteHighlight(); // Depende del estado
    _zoomToLeg(newLegIndex); // Depende del estado

    // Actualizar rastreo de bus
    _updateBusTrackingBasedOnLeg(newLegIndex);
  }

  void _navigateToNextLeg() {
    final mapState = ref.read(mapNotifierProvider);
    final mapNotifier = ref.read(mapNotifierProvider.notifier);
    if (mapState.selectedLegIndex == null ||
        mapState.selectedLegIndex! >= mapState.currentRouteLegs.length - 1 ||
        !mounted)
      return;

    final newLegIndex = mapState.selectedLegIndex! + 1;
    mapNotifier.setSelectedLegIndex(newLegIndex);
    _isWaitingForInitialLegZoomToComplete = true; // Sigue local

    _updateMapRouteHighlight(); // Depende del estado
    _zoomToLeg(newLegIndex); // Depende del estado

    // Actualizar rastreo de bus
    _updateBusTrackingBasedOnLeg(newLegIndex);
  }

  // Helper para iniciar/detener rastreo de bus basado en el tramo actual
  void _updateBusTrackingBasedOnLeg(int legIndex) {
    final mapState = ref.read(mapNotifierProvider);
    if (legIndex >= 0 && legIndex < mapState.currentRouteLegs.length) {
      final RouteLeg currentLeg =
          mapState.currentRouteLegs[legIndex] as RouteLeg;
      final String mode = currentLeg.mode.toUpperCase();
      if (mode == 'BUS' || mode == 'TRANSIT') {
        _startTrackingBusLine(currentLeg); // Pasa el tramo actual
      } else {
        _stopTrackingBusLine();
      }
    } else {
      _stopTrackingBusLine();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Leer el estado y el notifier
    final mapState = ref.watch(mapNotifierProvider);
    final mapNotifier = ref.read(mapNotifierProvider.notifier);
    final geocodingService = ref.watch(
      geocodingServiceProvider,
    ); // Para SearchPanel

    // Listener para dibujar/actualizar la ruta en el mapa según el estado
    // Se queda aquí porque necesita reaccionar a los cambios y reconstruir la UI del mapa
    ref.listen<MapState>(mapNotifierProvider, (previous, next) {
      // Reaccionar a cuando un itinerario es procesado y listo para mostrarse en modo overview
      // O cuando cambia el índice del tramo seleccionado para actualizar el highlight
      bool routeChanged = previous?.currentRouteLegs != next.currentRouteLegs;
      bool overviewStatusChanged =
          previous?.isInOverviewMode != next.isInOverviewMode;
      bool legIndexChanged =
          previous?.selectedLegIndex != next.selectedLegIndex;

      if (routeChanged &&
          next.currentRouteLegs.isNotEmpty &&
          next.isInOverviewMode) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted)
            _processAndDisplaySelectedItineraryUI(next.currentRouteLegs);
        });
      } else if (legIndexChanged && !next.isInOverviewMode) {
        // Actualizar resaltado cuando cambia el índice en modo navegación
        // _updateMapRouteHighlight se llama en _navigateToPreviousLeg/_navigateToNextLeg y al inicio de la navegación
        // No es estrictamente necesario aquí si esas llamadas son suficientes.
        // Considerar si _updateMapRouteHighlight debe llamarse aquí también.
      }

      // Podríamos añadir aquí la lógica para actualizar el resaltado de la ruta si no
      // se cubre completamente con las llamadas actuales.
      // if (legIndexChanged && !next.isInOverviewMode) {
      //    WidgetsBinding.instance.addPostFrameCallback((_) {
      //       if (mounted) _updateMapRouteHighlight();
      //     });
      // }

      // Nota: La lógica original para iniciar la navegación detallada y mostrar el modal
      // ha sido movida a initState con listenManual.
    });

    return Scaffold(
      body: Stack(
        children: [
          // El MapWidget ocupa todo el espacio posible detrás
          Column(
            children: <Widget>[
              Expanded(
                child: Stack(
                  children: [
                    MapWidget(
                      key: const ValueKey("mapWidget"),
                      onMapCreated: _onMapCreated,
                      onStyleLoadedListener: _onStyleLoadedListener,
                      cameraOptions: _initialCameraOptions,
                      styleUri: MapboxStyles.MAPBOX_STREETS,
                      onTapListener: _handleMapTapEvent,
                      onCameraChangeListener: _onMapCameraChange,
                      onMapIdleListener: _onMapIdle,
                    ),
                    if (mapState.isCalculatingRoute) // Leer del estado
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.3),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                    // TripInstructions se superpone al mapa, dentro del área del Expanded
                    TripInstructions(
                      currentRouteLegs:
                          mapState.currentRouteLegs, // Leer del estado
                      selectedLegIndex:
                          mapState.selectedLegIndex, // Leer del estado
                      showCollapsedInstructionsBar:
                          mapState
                              .showCollapsedInstructionsBar, // Leer del estado
                      origenControllerText: _origenController.text,
                      destinoControllerText: _destinoController.text,
                      isInOverviewMode:
                          mapState.isInOverviewMode, // Leer del estado
                      onLegSelectedInBottomSheet: (int tappedLegIndex) {
                        _showTripInstructionsBottomSheet(
                          mapState.currentRouteLegs,
                        );
                      },
                      onNavigateToPreviousLeg: _navigateToPreviousLeg,
                      onNavigateToNextLeg: _navigateToNextLeg,
                      onExpandInstructionsTap: () {
                        if (mapState.currentRouteLegs.isNotEmpty) {
                          _showTripInstructionsBottomSheet(
                            mapState.currentRouteLegs,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          // SearchPanel se superpone encima de todo, posicionado desde el Stack principal
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: SearchPanel(
              origenController: _origenController,
              destinoController: _destinoController,
              origenFocusNode: _origenFocusNode,
              destinoFocusNode: _destinoFocusNode,
              origenCoordinates: mapState.origenCoordinates,
              destinoCoordinates: mapState.destinoCoordinates,
              geocodingService: ref.read(geocodingServiceProvider),
              isCalculatingRoute: mapState.isCalculatingRoute,
              onSearchRoute:
                  () => ref.read(mapNotifierProvider.notifier).searchRoute(),
              onOrigenSelected:
                  (point) => ref
                      .read(mapNotifierProvider.notifier)
                      .setOrigenCoordinates(point),
              onDestinoSelected:
                  (point) => ref
                      .read(mapNotifierProvider.notifier)
                      .setDestinoCoordinates(point),
              onOrigenClear:
                  () => ref
                      .read(mapNotifierProvider.notifier)
                      .setOrigenCoordinates(null),
              onDestinoClear:
                  () => ref
                      .read(mapNotifierProvider.notifier)
                      .setDestinoCoordinates(null),
              initialExpandedState:
                  mapState.currentRouteLegs.isEmpty, // Expandido si no hay ruta
            ),
          ),
          if (mapState.isInOverviewMode && mapState.currentRouteLegs.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                onPressed: () {
                  mapNotifier.startDetailedNavigation();
                  // La reacción a este cambio de estado (zoom, highlight, tracking) se maneja en el listener o post-frame.
                },
                child: const Text("Iniciar Viaje"),
              ),
            ),
          if (mapState.isInOverviewMode && mapState.currentRouteLegs.isNotEmpty)
            Positioned(
              bottom: 85,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 10.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(10.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  "Este será tu recorrido completo.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 15.0),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Este método ahora se encarga de la parte UI de procesar un itinerario,
  // una vez que el MapNotifier ha actualizado el estado con currentRouteLegs.
  Future<void> _processAndDisplaySelectedItineraryUI(
    List<RouteLeg> legs,
  ) async {
    if (mapboxMap == null || _mapboxService == null || legs.isEmpty) {
      if (legs.isEmpty)
        _showNoRouteFoundMessage("El itinerario seleccionado no tiene tramos.");
      return;
    }

    // El estado (currentRouteLegs, isInOverviewMode, etc.) ya fue actualizado por el notifier.
    // Aquí solo realizamos las acciones en el mapa.
    // await _clearPreviousRouteLayers(); // Esto ya se hizo antes de mostrar RouteOptionsModal

    for (int i = 0; i < legs.length; i++) {
      final RouteLeg leg = legs[i];
      final String mode = leg.mode.toUpperCase();
      final String polylineString = leg.legGeometry.points;

      if (polylineString.isNotEmpty) {
        List<PointLatLng> decodedPoints = PolylinePoints().decodePolyline(
          polylineString,
        );
        List<Position> positions =
            decodedPoints
                .map((p) => Position(p.longitude, p.latitude))
                .toList();
        Color legColor;
        double lineWidth = 4.0;
        double shadowWidth = 6.0;
        if (mode == 'WALK')
          legColor = Colors.blueAccent;
        else if (mode == 'BUS' || mode == 'TRANSIT') {
          legColor = Colors.deepOrangeAccent;
          lineWidth = 5.0;
          shadowWidth = 7.0;
        } else
          legColor = Colors.grey;
        await _mapboxService!.drawRouteSegment(
          positions,
          "$OTP_ROUTE_SOURCE_PREFIX$i",
          "$OTP_ROUTE_LAYER_PREFIX$i",
          legColor,
          i,
          lineWidth: lineWidth,
          shadowWidth: shadowWidth,
        );
      }
    }

    await _mapboxService!.displayRelevantStops(legs);
    await _mapboxService!.zoomToRouteBounds(legs);
    _applyOverviewRouteStyle(); // Aplica estilo de overview

    // Ocultar capa de paradas generales
    try {
      if (await mapboxMap!.style.styleLayerExists(
        MapboxService.STOPS_LAYER_ID,
      )) {
        await mapboxMap!.style.setStyleLayerProperty(
          MapboxService.STOPS_LAYER_ID,
          "visibility",
          "none",
        );
      }
    } catch (e) {
      print(
        "[MapScreen_Debug] Error ocultando capa ${MapboxService.STOPS_LAYER_ID}: $e",
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUpcomingBuses(
    String stopId,
    String lineShortName,
  ) async {
    print(
      "[MapScreen_Debug_ETA] Solicitando ETAs para parada $stopId, línea $lineShortName",
    );
    final montevideoApiService = ref.read(montevideoApiServiceProvider);
    try {
      return await montevideoApiService.fetchUpcomingBusesForStopAndLine(
        stopId,
        lineShortName,
      );
    } catch (e) {
      print("[MapScreen_Debug_ETA] Error fetching upcoming buses: $e");
      rethrow;
    }
  }

  Future<void> _fetchAndDisplayRealtimeBusLocations() async {
    if (mapboxMap == null || _mapboxService == null) return;

    final mapState = ref.read(mapNotifierProvider);
    final mapNotifier = ref.read(mapNotifierProvider.notifier);

    if (mapState.trackedBusLineShortName == null ||
        mapState.trackedBusLineShortName!.isEmpty) {
      return;
    }
    print(
      "[MapScreen_Debug_RealtimeBus] Solicitando ubicaciones para línea: ${mapState.trackedBusLineShortName}",
    );

    final montevideoApiService = ref.read(montevideoApiServiceProvider);
    try {
      final Map<String, dynamic> geoJsonData = await montevideoApiService
          .fetchRealtimeBusLocations(mapState.trackedBusLineShortName!);
      final List<dynamic> features = geoJsonData['features'] ?? [];
      Position?
      newHighlightedBusPosition; // Variable local para determinar el nuevo bus resaltado

      if (features.isNotEmpty) {
        print(
          "[MapScreen_Debug_RealtimeBus] ${features.length} buses encontrados.",
        );
        int closestUpcomingBusIndex = -1;
        double minDistanceToOriginStop = double.infinity;

        if (_currentFullShapeForBusLeg != null &&
            _currentFullShapeForBusLeg!.isNotEmpty &&
            _originStopIndexOnShape != null) {
          for (int i = 0; i < features.length; i++) {
            var feature = features[i];
            if (feature is Map<String, dynamic> &&
                feature['geometry']?['coordinates'] is List) {
              final coords = feature['geometry']['coordinates'] as List;
              if (coords.length == 2) {
                final busPoint = Point_dart(
                  lat: (coords[1] as num).toDouble(),
                  lng: (coords[0] as num).toDouble(),
                );
                final busIndexOnShape = findClosestPointIndexOnShape(
                  _currentFullShapeForBusLeg!,
                  busPoint,
                );
                bool isPastUserOrigin = false;
                bool isRelevantToUserPath = false;

                if (busIndexOnShape != -1) {
                  if (_originStopIndexOnShape != null)
                    isPastUserOrigin =
                        busIndexOnShape > _originStopIndexOnShape!;
                  if (_destinationStopIndexOnShape != null)
                    isRelevantToUserPath =
                        busIndexOnShape <= _destinationStopIndexOnShape!;
                }
                feature['properties'] = feature['properties'] ?? {};
                feature['properties']['isPastOrigin'] = isPastUserOrigin;
                feature['properties']['isRelevant'] = isRelevantToUserPath;
                feature['properties']['isClosestUpcoming'] = false;

                if (isRelevantToUserPath &&
                    !isPastUserOrigin &&
                    busIndexOnShape <= _originStopIndexOnShape!) {
                  final Point_dart userOriginStopLocation = Point_dart(
                    lat:
                        (_currentFullShapeForBusLeg![_originStopIndexOnShape!]
                                    .lat
                                as num)
                            .toDouble(),
                    lng:
                        (_currentFullShapeForBusLeg![_originStopIndexOnShape!]
                                    .lng
                                as num)
                            .toDouble(),
                  );
                  final double distanceToUserOriginStop =
                      calculateHaversineDistance(
                        busPoint.lat,
                        busPoint.lng,
                        userOriginStopLocation.lat,
                        userOriginStopLocation.lng,
                      );
                  if (distanceToUserOriginStop < minDistanceToOriginStop) {
                    minDistanceToOriginStop = distanceToUserOriginStop;
                    closestUpcomingBusIndex = i;
                  }
                }
              }
            }
          }
          if (closestUpcomingBusIndex != -1) {
            (features[closestUpcomingBusIndex]['properties']
                    as Map<String, dynamic>)['isClosestUpcoming'] =
                true;
            final closestBusFeature = features[closestUpcomingBusIndex];
            if (closestBusFeature['geometry']?['coordinates'] is List &&
                (closestBusFeature['geometry']['coordinates'] as List).length ==
                    2) {
              final coords =
                  closestBusFeature['geometry']['coordinates'] as List;
              newHighlightedBusPosition = Position(
                (coords[0] as num).toDouble(),
                (coords[1] as num).toDouble(),
              );
            }
          }
        } else {
          for (var feature in features) {
            if (feature is Map<String, dynamic>) {
              feature['properties'] = feature['properties'] ?? {};
              feature['properties']['isRelevant'] = false;
              feature['properties']['isClosestUpcoming'] = false;
            }
          }
        }
        // Actualizar el estado en el notifier SI CAMBIÓ
        if (mapState.highlightedBusPosition?.lng !=
                newHighlightedBusPosition?.lng ||
            mapState.highlightedBusPosition?.lat !=
                newHighlightedBusPosition?.lat) {
          mapNotifier.state = mapNotifier.state.copyWith(
            highlightedBusPosition: () => newHighlightedBusPosition,
          );
        }

        final String modifiedGeoJsonString = json.encode(geoJsonData);
        final sourceExists = await mapboxMap!.style.styleSourceExists(
          REALTIME_BUS_SOURCE_ID,
        );
        if (!sourceExists) {
          await mapboxMap!.style.addSource(
            GeoJsonSource(
              id: REALTIME_BUS_SOURCE_ID,
              data: modifiedGeoJsonString,
            ),
          );
        } else {
          final source =
              await mapboxMap!.style.getSource(REALTIME_BUS_SOURCE_ID)
                  as GeoJsonSource?;
          await source?.updateGeoJSON(modifiedGeoJsonString);
        }
        await _updateRealtimeBusLayers(features);

        if (newHighlightedBusPosition != null &&
            !mapState.userManuallyMovedMap &&
            mapState.selectedLegIndex != null &&
            mapState.selectedLegIndex! < mapState.currentRouteLegs.length) {
          final RouteLeg currentLeg =
              mapState.currentRouteLegs[mapState.selectedLegIndex!];
          final String mode = currentLeg.mode.toUpperCase();
          if (mode == 'BUS' || mode == 'TRANSIT') {
            if (!_isWaitingForInitialLegZoomToComplete &&
                !_isProgrammaticCameraMove) {
              await _zoomToLeg(mapState.selectedLegIndex!);
            }
          }
        }
      } else {
        if (mapState.highlightedBusPosition != null) {
          // Si había un bus y ya no hay
          mapNotifier.state = mapNotifier.state.copyWith(
            highlightedBusPosition: () => null,
          );
        }
        try {
          if (await mapboxMap!.style.styleLayerExists(REALTIME_BUS_LAYER_ID))
            await mapboxMap!.style.removeStyleLayer(REALTIME_BUS_LAYER_ID);
          if (await mapboxMap!.style.styleLayerExists(
            REALTIME_BUS_DOTS_LAYER_ID,
          ))
            await mapboxMap!.style.removeStyleLayer(REALTIME_BUS_DOTS_LAYER_ID);
          if (await mapboxMap!.style.styleLayerExists(
            MapboxService.INCOMING_BUS_TOOLTIP_LAYER_ID,
          ))
            await mapboxMap!.style.removeStyleLayer(
              MapboxService.INCOMING_BUS_TOOLTIP_LAYER_ID,
            );
        } catch (_) {}
        _mapboxService?.stopTooltipFloatingAnimation();
      }
    } catch (e, s) {
      print(
        "[MapScreen_Debug_RealtimeBus] Excepción obteniendo buses desde el servicio: $e",
      );
      print(s);
    }

    if (_mapboxService != null) {
      // Usar el highlightedBusPosition del estado
      await _mapboxService!.drawIncomingBusSegment(
        mapState.highlightedBusPosition,
        _currentFullShapeForBusLeg,
        _originStopIndexOnShape,
      );
    }
  }

  Future<void> _updateRealtimeBusLayers(List<dynamic> features) async {
    if (mapboxMap == null || _mapboxService == null) return;

    final String iconToUse = "bus-icon";
    final double normalIconSize = 0.4;
    final double smallerRelevantIconSize = normalIconSize * 0.8;
    final double closestUpcomingIconSize = normalIconSize * 1.5;

    final mainLayerExists = await mapboxMap!.style.styleLayerExists(
      REALTIME_BUS_LAYER_ID,
    );
    final List<Object> mainFilter = [
      '==',
      ['get', 'isRelevant'],
      true,
    ];
    final List<Object> iconImageExpression = [
      'case',
      ['get', 'isClosestUpcoming'],
      MapboxService.INCOMING_BUS_ICON_ID,
      iconToUse,
    ];
    final List<Object> iconSizeExpression = [
      'case',
      ['get', 'isClosestUpcoming'],
      closestUpcomingIconSize,
      smallerRelevantIconSize,
    ];

    if (!mainLayerExists) {
      await mapboxMap!.style.addLayer(
        SymbolLayer(
          id: REALTIME_BUS_LAYER_ID,
          sourceId: REALTIME_BUS_SOURCE_ID,
          filter: mainFilter,
          iconImageExpression: iconImageExpression,
          iconSizeExpression: iconSizeExpression,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          minZoom: 10.0,
        ),
      );
    } else {
      await mapboxMap!.style.setStyleLayerProperty(
        REALTIME_BUS_LAYER_ID,
        "filter",
        mainFilter,
      );
      await mapboxMap!.style.setStyleLayerProperty(
        REALTIME_BUS_LAYER_ID,
        "iconImageExpression",
        iconImageExpression,
      );
      await mapboxMap!.style.setStyleLayerProperty(
        REALTIME_BUS_LAYER_ID,
        "iconSizeExpression",
        iconSizeExpression,
      );
    }

    final dotsLayerExists = await mapboxMap!.style.styleLayerExists(
      REALTIME_BUS_DOTS_LAYER_ID,
    );
    final List<Object> dotsFilter = [
      '==',
      ['get', 'isRelevant'],
      false,
    ];

    if (!dotsLayerExists) {
      await mapboxMap!.style.addLayer(
        CircleLayer(
          id: REALTIME_BUS_DOTS_LAYER_ID,
          sourceId: REALTIME_BUS_SOURCE_ID,
          filter: dotsFilter,
          circleColor: Colors.red.value,
          circleRadius: 3.0,
          circleOpacity: 0.7,
        ),
      );
    } else {
      await mapboxMap!.style.setStyleLayerProperty(
        REALTIME_BUS_DOTS_LAYER_ID,
        "filter",
        dotsFilter,
      );
    }

    final tooltipLayerId = MapboxService.INCOMING_BUS_TOOLTIP_LAYER_ID;
    final tooltipLayerExists = await mapboxMap!.style.styleLayerExists(
      tooltipLayerId,
    );
    final List<Object> tooltipFilter = [
      'all',
      [
        [
          '==',
          ['get', 'isRelevant'],
          true,
        ],
        [
          '==',
          ['get', 'isClosestUpcoming'],
          true,
        ],
      ],
    ];
    final bool shouldShowTooltip = features.any(
      (f) => f is Map && f['properties']?['isClosestUpcoming'] == true,
    );

    if (shouldShowTooltip) {
      if (!tooltipLayerExists) {
        await mapboxMap!.style.addLayer(
          SymbolLayer(
            id: tooltipLayerId,
            sourceId: REALTIME_BUS_SOURCE_ID,
            filter: tooltipFilter,
            iconImage: MapboxService.INCOMING_BUS_TOOLTIP_ICON_ID,
            iconSize: closestUpcomingIconSize,
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
            minZoom: 10.0,
            iconOffset: [0.0, 0.0],
          ),
        );
      } else {
        await mapboxMap!.style.setStyleLayerProperty(
          tooltipLayerId,
          "filter",
          tooltipFilter,
        );
      }
      _mapboxService?.startTooltipFloatingAnimation();
    } else {
      if (tooltipLayerExists) {
        await mapboxMap!.style.removeStyleLayer(tooltipLayerId);
      }
      _mapboxService?.stopTooltipFloatingAnimation();
    }
  }

  Future<void> _startTrackingBusLine(RouteLeg busLeg) async {
    await _stopTrackingBusLine(); // Detener rastreo anterior y limpiar estado del notifier

    final mapNotifier = ref.read(mapNotifierProvider.notifier);
    final String? lineShortName = busLeg.route?.shortName;
    final String? otpShapeId = busLeg.trip?.shapeId;
    String? shapeIdToSearch = otpShapeId;

    if (otpShapeId != null && otpShapeId.contains(':')) {
      shapeIdToSearch = otpShapeId.split(':').last;
    }

    if (lineShortName == null || lineShortName.isEmpty) {
      print(
        "[MapScreen_Debug_RealtimeBus] No se puede rastrear: falta nombre corto de línea.",
      );
      mapNotifier.state = mapNotifier.state.copyWith(
        trackedBusLineShortName: () => null,
      ); // Asegurar que está limpio
      return;
    }

    // Actualizar el nombre del bus rastreado en el notifier
    mapNotifier.state = mapNotifier.state.copyWith(
      trackedBusLineShortName: () => lineShortName,
    );
    print(
      "[MapScreen_Debug_RealtimeBus] Iniciando rastreo línea: $lineShortName (Shape Buscado: $shapeIdToSearch)",
    );

    _currentFullShapeForBusLeg = null;
    _originStopIndexOnShape = null;
    _destinationStopIndexOnShape = null;

    if (shapeIdToSearch != null &&
        _shapeGeometries.containsKey(shapeIdToSearch)) {
      _currentFullShapeForBusLeg = _shapeGeometries[shapeIdToSearch];
      final LegEndpoint busLegFrom = busLeg.from;
      final LegEndpoint busLegTo = busLeg.to;
      if (_currentFullShapeForBusLeg != null &&
          _currentFullShapeForBusLeg!.isNotEmpty) {
        final userBoardingStopCoords = Point_dart(
          lat: busLegFrom.lat,
          lng: busLegFrom.lon,
        );
        _originStopIndexOnShape = findClosestPointIndexOnShape(
          _currentFullShapeForBusLeg!,
          userBoardingStopCoords,
        );
        if (busLegTo != null) {
          final userAlightingStopCoords = Point_dart(
            lat: busLegTo.lat,
            lng: busLegTo.lon,
          );
          _destinationStopIndexOnShape = findClosestPointIndexOnShape(
            _currentFullShapeForBusLeg!,
            userAlightingStopCoords,
          );
        }
      }
    }

    if (_currentFullShapeForBusLeg != null &&
        _currentFullShapeForBusLeg!.isNotEmpty &&
        shapeIdToSearch != null) {
      _currentFullLineShapeId = shapeIdToSearch;
      final fullLineSourceId =
          "$FULL_BUS_LINE_SHAPE_SOURCE_ID_PREFIX$shapeIdToSearch";
      final fullLineLayerId =
          "$FULL_BUS_LINE_SHAPE_LAYER_ID_PREFIX$shapeIdToSearch";
      List<Position> positionsToDraw = _currentFullShapeForBusLeg!;
      try {
        await _mapboxService?.drawFullBusLineShape(
          positionsToDraw,
          fullLineSourceId,
          fullLineLayerId,
          Colors.grey.withOpacity(0.7),
          3.0,
        );
      } catch (e) {
        print("[MapScreen_Debug_RealtimeBus] Error dibujando línea base: $e");
      }
    }

    _fetchAndDisplayRealtimeBusLocations();
    _realtimeBusTimer?.cancel(); // Cancelar timer anterior por si acaso
    _realtimeBusTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      // Verificar si aún debemos rastrear (el estado podría haber cambiado)
      if (ref.read(mapNotifierProvider).trackedBusLineShortName ==
          lineShortName) {
        _fetchAndDisplayRealtimeBusLocations();
      } else {
        timer.cancel(); // Detener si ya no es la línea correcta
      }
    });
  }

  Future<void> _stopTrackingBusLine() async {
    _realtimeBusTimer?.cancel();
    _realtimeBusTimer = null;

    final mapNotifier = ref.read(mapNotifierProvider.notifier);
    // Limpiar estado relacionado al rastreo en el notifier
    mapNotifier.state = mapNotifier.state.copyWith(
      trackedBusLineShortName: () => null,
      highlightedBusPosition: () => null,
    );

    _mapboxService?.stopTooltipFloatingAnimation();
    print("[MapScreen_Debug_RealtimeBus] Rastreo de buses detenido.");

    _currentFullShapeForBusLeg = null;
    _originStopIndexOnShape = null;
    _destinationStopIndexOnShape = null;
    // _highlightedBusPosition ahora está en el notifier y se limpió arriba.

    if (mapboxMap != null && _mapboxService != null) {
      try {
        if (await mapboxMap!.style.styleLayerExists(REALTIME_BUS_LAYER_ID))
          await mapboxMap!.style.removeStyleLayer(REALTIME_BUS_LAYER_ID);
        if (await mapboxMap!.style.styleLayerExists(REALTIME_BUS_DOTS_LAYER_ID))
          await mapboxMap!.style.removeStyleLayer(REALTIME_BUS_DOTS_LAYER_ID);
        if (await mapboxMap!.style.styleLayerExists(
          MapboxService.INCOMING_BUS_TOOLTIP_LAYER_ID,
        ))
          await mapboxMap!.style.removeStyleLayer(
            MapboxService.INCOMING_BUS_TOOLTIP_LAYER_ID,
          );
      } catch (e) {
        print("[MapScreen_Debug_RealtimeBus] Error limpiando capas de bus: $e");
      }

      if (_currentFullLineShapeId != null) {
        final fullLineSourceId =
            "$FULL_BUS_LINE_SHAPE_SOURCE_ID_PREFIX$_currentFullLineShapeId";
        final fullLineLayerId =
            "$FULL_BUS_LINE_SHAPE_LAYER_ID_PREFIX$_currentFullLineShapeId";
        try {
          if (await mapboxMap!.style.styleLayerExists(fullLineLayerId))
            await mapboxMap!.style.removeStyleLayer(fullLineLayerId);
          if (await mapboxMap!.style.styleSourceExists(fullLineSourceId))
            await mapboxMap!.style.removeStyleSource(fullLineSourceId);
        } catch (e) {
          print("[MapScreen_Debug_RealtimeBus] Error limpiando línea base: $e");
        }
        _currentFullLineShapeId = null;
      }
    }
  }

  void _onMapCameraChange(CameraChangedEventData event) {
    if (_isProgrammaticCameraMove) return;
    final mapNotifier = ref.read(mapNotifierProvider.notifier);
    // Solo actualiza si el estado realmente cambia para evitar rebuilds innecesarios.
    if (!ref.read(mapNotifierProvider).userManuallyMovedMap) {
      mapNotifier.setUserManuallyMovedMap(true);
    }
    // print("[MapScreen_Debug_MapMove] Usuario movió el mapa. userManuallyMovedMap = true.");
  }

  void _onMapIdle(MapIdleEventData data) {
    bool wasProgrammaticMove = _isProgrammaticCameraMove;
    if (_isProgrammaticCameraMove) _isProgrammaticCameraMove = false;

    bool wasWaitingForInitialLegZoom = _isWaitingForInitialLegZoomToComplete;
    if (_isWaitingForInitialLegZoomToComplete)
      _isWaitingForInitialLegZoomToComplete = false;

    if (wasProgrammaticMove && wasWaitingForInitialLegZoom) {
      final mapState = ref.read(mapNotifierProvider);
      if (mapState.highlightedBusPosition != null &&
          !mapState.userManuallyMovedMap &&
          mapState.selectedLegIndex != null) {
        final RouteLeg currentLeg =
            mapState.currentRouteLegs[mapState.selectedLegIndex!];
        final String mode = currentLeg.mode.toUpperCase();
        if (mode == 'BUS' || mode == 'TRANSIT') {
          _zoomToLeg(mapState.selectedLegIndex!);
        }
      }
    }
  }
}

// Las funciones de utilidad calculateHaversineDistance y findClosestPointIndexOnShape
// ya fueron movidas a ../utils/ y se importan desde allí. No necesitan estar aquí.
