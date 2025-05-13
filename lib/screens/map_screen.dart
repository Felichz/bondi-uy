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

  // Referencias a los servicios (AHORA SE ACCEDEN VIA PROVIDERS O SONLOCALES)
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
  // Position? _highlightedBusPosition; // EN MapState

  // Estado del movimiento del mapa (Parte en MapState, parte local)
  // bool _userManuallyMovedMap = false; // EN MapState
  bool _isProgrammaticCameraMove =
      false; // Sigue local (controla lógica de _onMapIdle y _onMapCameraChange)
  // bool _isWaitingForInitialLegZoomToComplete = false; // <<< ELIMINAR, ya no necesario

  // AÑADIDO: Para rastrear si el usuario ha iniciado un gesto de movimiento
  bool _userHasInitiatedMove = false;

  // AÑADIDO: Variables para el shape actual y los índices de paradas relevantes (MOVIDAS AQUÍ DESDE EL FINAL DE LA CLASE)
  List<Position>? _currentFullShapeForBusLeg;
  int? _originStopIndexOnShape;
  int? _destinationStopIndexOnShape;

  @override
  void initState() {
    super.initState();
    print("[_MapScreenState_Debug] initState called.");
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
              // >>> AÑADIDO: Resetear userManuallyMovedMap al iniciar navegación detallada <<<
              print(
                "[_MapScreenState_Debug] Listener (startDetailedNavigation): Resetting userManuallyMovedMap to false.",
              );
              ref
                  .read(mapNotifierProvider.notifier)
                  .setUserManuallyMovedMap(false);
              _zoomToLeg(0);
              _updateMapRouteHighlight();
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

    // >>> NUEVO: Listener para iniciar/detener sondeo de bus
    ref.listenManual<
      RouteLeg?
    >(mapNotifierProvider.select((s) => s.legToTrackInRealtime), (
      prevLeg,
      nextLeg,
    ) {
      print(
        "[_MapScreenState_Debug] Listener (legToTrackInRealtime): prevLeg=${prevLeg?.route?.shortName}, nextLeg=${nextLeg?.route?.shortName}",
      );
      // Pequeño delay para asegurar que otras actualizaciones de estado se procesen
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          // Re-check mounted after delay
          if (nextLeg != null) {
            print(
              "[_MapScreenState_Debug] Listener (legToTrackInRealtime): Calling _startTrackingBusLine for ${nextLeg.route?.shortName}",
            );
            _startTrackingBusLine(nextLeg);
          } else {
            print(
              "[_MapScreenState_Debug] Listener (legToTrackInRealtime): Calling _stopTrackingBusLine.",
            );
            _stopTrackingBusLine();
          }
        }
      });
    });

    // >>> NUEVO: Listener para manejar zoom al bus resaltado
    ref.listenManual<Position?>(
      mapNotifierProvider.select((s) => s.highlightedBusPosition),
      (prevBusPos, newBusPos) {
        // CORRECCIÓN LOGGING:
        final String prevLatStr = prevBusPos?.lat.toString() ?? "null";
        final String prevLngStr = prevBusPos?.lng.toString() ?? "null";
        final String newLatStr = newBusPos?.lat.toString() ?? "null";
        final String newLngStr = newBusPos?.lng.toString() ?? "null";
        print(
          "[_MapScreenState_Debug] Listener (highlightedBusPosition) TRIGGERED: prevBusPos=($prevLatStr, $prevLngStr), newBusPos=($newLatStr, $newLngStr)",
        );
        final mapState = ref.read(mapNotifierProvider);
        final bool positionChangedSignificantly =
            (prevBusPos?.lng != newBusPos?.lng ||
                prevBusPos?.lat != newBusPos?.lat ||
                (prevBusPos == null && newBusPos != null) ||
                (prevBusPos != null && newBusPos == null));

        print(
          "[_MapScreenState_Debug] Listener (highlightedBusPosition): positionChangedSignificantly=$positionChangedSignificantly. Current userManuallyMovedMap=${mapState.userManuallyMovedMap}, isInOverviewMode=${mapState.isInOverviewMode}",
        );

        if (newBusPos != null && positionChangedSignificantly) {
          print(
            "[_MapScreenState_Debug] Listener (highlightedBusPosition): newBusPos is NOT NULL and changed significantly. Processing zoom logic...",
          );
          if (mapState.isInOverviewMode) {
            print(
              "[_MapScreenState_Debug] Listener (highlightedBusPosition): Overview mode. Attempting zoom to bus, origin, and destination.",
            );
            final legToTrack = mapState.legToTrackInRealtime;
            if (legToTrack != null && _mapboxService != null) {
              final List<Position> positionsToFit = [
                Position(legToTrack.from.lon, legToTrack.from.lat),
                Position(legToTrack.to.lon, legToTrack.to.lat),
                newBusPos,
              ];
              _isProgrammaticCameraMove = true;
              print(
                "[_MapScreenState_Debug] Listener (highlightedBusPosition): Overview - SET _isProgrammaticCameraMove = true",
              );
              _mapboxService!
                  .zoomToFitPositions(
                    positionsToFit,
                    const EdgeInsets.all(60.0),
                    animationDuration: const Duration(milliseconds: 1500),
                  )
                  .then((initiated) {
                    if (!initiated) {
                      print(
                        "[_MapScreenState_Debug] Listener (highlightedBusPosition): Overview - zoomToFitPositions reported NO initiation. SET _isProgrammaticCameraMove = false",
                      );
                      _isProgrammaticCameraMove = false;
                    } else {
                      print(
                        "[_MapScreenState_Debug] Listener (highlightedBusPosition): Overview - zoomToFitPositions reported INITIATION. _isProgrammaticCameraMove remains true for _onMapIdle.",
                      );
                    }
                  })
                  .catchError((e) {
                    print(
                      "[_MapScreenState_Debug] Listener (highlightedBusPosition): Overview - zoomToFitPositions CATCH. SET _isProgrammaticCameraMove = false. Error: $e",
                    );
                    _isProgrammaticCameraMove = false;
                  });
            }
          } else if (!mapState.userManuallyMovedMap) {
            print(
              "[_MapScreenState_Debug] Listener (highlightedBusPosition): DetailedNav (userManuallyMovedMap is FALSE). Attempting zoom to bus and origin.",
            );
            final legToTrack = mapState.legToTrackInRealtime;
            if (legToTrack != null &&
                mapState.selectedLegIndex != null &&
                mapState.currentRouteLegs.isNotEmpty &&
                _mapboxService != null) {
              final List<Position> positionsToFit = [
                Position(legToTrack.from.lon, legToTrack.from.lat),
                newBusPos,
              ];
              _isProgrammaticCameraMove = true;
              print(
                "[_MapScreenState_Debug] Listener (highlightedBusPosition): DetailedNav - SET _isProgrammaticCameraMove = true",
              );
              _mapboxService!
                  .zoomToFitPositions(
                    positionsToFit,
                    const EdgeInsets.all(80.0),
                    animationDuration: const Duration(milliseconds: 1200),
                  )
                  .then((initiated) {
                    if (!initiated) {
                      print(
                        "[_MapScreenState_Debug] Listener (highlightedBusPosition): DetailedNav - zoomToFitPositions reported NO initiation. SET _isProgrammaticCameraMove = false",
                      );
                      _isProgrammaticCameraMove = false;
                    } else {
                      print(
                        "[_MapScreenState_Debug] Listener (highlightedBusPosition): DetailedNav - zoomToFitPositions reported INITIATION. _isProgrammaticCameraMove remains true for _onMapIdle.",
                      );
                    }
                  })
                  .catchError((e) {
                    print(
                      "[_MapScreenState_Debug] Listener (highlightedBusPosition): DetailedNav - zoomToFitPositions CATCH. SET _isProgrammaticCameraMove = false. Error: $e",
                    );
                    _isProgrammaticCameraMove = false;
                  });
            }
          } else {
            print(
              "[_MapScreenState_Debug] Listener (highlightedBusPosition): isInOverviewMode = false AND userManuallyMovedMap = true. No Zoom due to manual map move.",
            );
          }
        } else if (newBusPos == null && prevBusPos != null) {
          print(
            "[_MapScreenState_Debug] Listener (highlightedBusPosition): Highlighted bus disappeared (newBusPos is null).",
          );
        } else {
          print(
            "[_MapScreenState_Debug] Listener (highlightedBusPosition): newBusPos is NULL or NOT significantly changed. No Zoom. newBusPos: $newBusPos, changed: $positionChangedSignificantly",
          );
        }

        // La lógica original de _zoomToLeg para el inicio de navegación/cambio de tramo se mantiene.
        // Esta nueva lógica es *adicional* y reactiva al bus.
        // Ya no se usa la condición original para el zoom desde este listener.
        // print(
        //   "[_MapScreenState_Debug] Listener (highlightedBusPosition): Conditions for zoom NOT met. Overview=${mapState.isInOverviewMode}, MovedMap=${mapState.userManuallyMovedMap}, SelectedIndex=${mapState.selectedLegIndex}, LegToTrack=${mapState.legToTrackInRealtime != null}",
        // );
      },
      onError: (error, stackTrace) {
        // Asegurar que este bloque esté bien formado
        print(
          '[_MapScreenState_Debug] Error en listener highlightedBusPosition: $error',
        );
        print(stackTrace);
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

    // AÑADIDO: Listeners para gestos de movimiento
    // <<< ELIMINADAS LAS ASIGNACIONES INCORRECTAS DE GESTURES LISTENERS >>>
    // Los listeners ahora se pasan directamente al MapWidget en el método build.
    print(
      "[_MapScreenState_Debug] _onMapCreated: mapboxMap instance set. Gesture listeners are handled by MapWidget constructor.",
    );
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
                // >>> AÑADIDO: Resetear userManuallyMovedMap al seleccionar tramo del bottom sheet <<<
                print(
                  "[_MapScreenState_Debug] BottomSheet (onLegSelected): Resetting userManuallyMovedMap to false for leg $tappedLegIndex.",
                );
                mapNotifier.setUserManuallyMovedMap(false);
                mapNotifier.setSelectedLegIndex(tappedLegIndex);
                _updateMapRouteHighlight();
                _zoomToLeg(tappedLegIndex);
                setModalState(() {});
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
    if (mounted == false) return;
    print(
      "[_MapScreenState_Debug] _zoomToLeg llamado para el tramo: $legIndex",
    );

    if (mapboxMap == null || _mapboxService == null) {
      print(
        "[_MapScreenState_Debug] _zoomToLeg: MapboxMap o MapboxService es null. Abortando.",
      );
      return;
    }

    final mapState = ref.read(mapNotifierProvider);
    if (legIndex < 0 || legIndex >= mapState.currentRouteLegs.length) {
      print(
        "[_MapScreenState_Debug] _zoomToLeg: Índice de tramo inválido. Abortando.",
      );
      return;
    }

    final currentLeg = mapState.currentRouteLegs[legIndex];
    Position? busPositionToInclude;
    if (currentLeg.mode.toUpperCase() == "BUS" ||
        currentLeg.mode.toUpperCase() == "TRANSIT") {
      busPositionToInclude = mapState.highlightedBusPosition;
    }

    _isProgrammaticCameraMove = true;
    print(
      "[_MapScreenState_Debug] _zoomToLeg: SET _isProgrammaticCameraMove = true",
    );
    bool initiated = false;
    try {
      initiated = await _mapboxService!.zoomToLeg(
        mapState.currentRouteLegs,
        legIndex,
        busPositionToInclude,
        mapState.showCollapsedInstructionsBar,
      );
    } catch (e) {
      print(
        "[_MapScreenState_Debug] _zoomToLeg: Exception calling _mapboxService.zoomToLeg: $e. SET _isProgrammaticCameraMove = false",
      );
      _isProgrammaticCameraMove = false;
      return;
    }

    if (!initiated) {
      print(
        "[_MapScreenState_Debug] _zoomToLeg: _mapboxService.zoomToLeg reported NO initiation. SET _isProgrammaticCameraMove = false",
      );
      _isProgrammaticCameraMove = false;
    } else {
      print(
        "[_MapScreenState_Debug] _zoomToLeg: _mapboxService.zoomToLeg reported INITIATION. _isProgrammaticCameraMove remains true for _onMapIdle.",
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

    // >>> AÑADIDO: Resetear userManuallyMovedMap <<<
    print(
      "[_MapScreenState_Debug] _navigateToPreviousLeg: Resetting userManuallyMovedMap to false.",
    );
    mapNotifier.setUserManuallyMovedMap(false);

    final newLegIndex = mapState.selectedLegIndex! - 1;
    mapNotifier.setSelectedLegIndex(newLegIndex);
    _updateMapRouteHighlight(); // Depende del estado
    _zoomToLeg(newLegIndex); // Depende del estado

    // El rastreo se actualizará automáticamente por el listener de legToTrackInRealtime
    // _updateBusTrackingBasedOnLeg(newLegIndex); // <<< ELIMINAR
  }

  void _navigateToNextLeg() {
    final mapState = ref.read(mapNotifierProvider);
    final mapNotifier = ref.read(mapNotifierProvider.notifier);
    if (mapState.selectedLegIndex == null ||
        mapState.selectedLegIndex! >= mapState.currentRouteLegs.length - 1 ||
        !mounted)
      return;

    // >>> AÑADIDO: Resetear userManuallyMovedMap <<<
    print(
      "[_MapScreenState_Debug] _navigateToNextLeg: Resetting userManuallyMovedMap to false.",
    );
    mapNotifier.setUserManuallyMovedMap(false);

    final newLegIndex = mapState.selectedLegIndex! + 1;
    mapNotifier.setSelectedLegIndex(newLegIndex);
    _updateMapRouteHighlight(); // Depende del estado
    _zoomToLeg(newLegIndex); // Depende del estado

    // El rastreo se actualizará automáticamente por el listener de legToTrackInRealtime
    // _updateBusTrackingBasedOnLeg(newLegIndex); // <<< ELIMINAR
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
    print(
      "[_MapScreenState_Debug] _fetchAndDisplayRealtimeBusLocations called.",
    );
    if (mapboxMap == null || _mapboxService == null) {
      print(
        "[_MapScreenState_Debug] _fetchAndDisplayRealtimeBusLocations: mapboxMap or _mapboxService is null. Aborting.",
      );
      return;
    }

    final mapState = ref.read(mapNotifierProvider);
    final mapNotifier = ref.read(mapNotifierProvider.notifier);
    final RouteLeg? legBeingTracked = mapState.legToTrackInRealtime;
    print(
      "[_MapScreenState_Debug] _fetchAndDisplayRealtimeBusLocations: legBeingTracked=${legBeingTracked?.route?.shortName}",
    );

    final String? lineShortNameToFetch = legBeingTracked?.route?.shortName;

    if (lineShortNameToFetch == null || lineShortNameToFetch.isEmpty) {
      print(
        "[_MapScreenState_Debug] _fetchAndDisplayRealtimeBusLocations: No lineShortNameToFetch. Aborting.",
      );
      return;
    }
    print(
      "[_MapScreenState_Debug] _fetchAndDisplayRealtimeBusLocations: Requesting locations for line: $lineShortNameToFetch",
    );

    if (_currentFullShapeForBusLeg == null || _originStopIndexOnShape == null) {
      print(
        "[_MapScreenState_Debug] _fetchAndDisplayRealtimeBusLocations: _currentFullShapeForBusLeg or _originStopIndexOnShape is null. Cannot process bus locations effectively.",
      );
      // No abortamos aquí, la API se llamará, pero la relevancia no se calculará
    }

    final montevideoApiService = ref.read(montevideoApiServiceProvider);
    try {
      print(
        "[_MapScreenState_Debug] _fetchAndDisplayRealtimeBusLocations: Calling montevideoApiService.fetchRealtimeBusLocations for $lineShortNameToFetch.",
      );
      final Map<String, dynamic> geoJsonData = await montevideoApiService
          .fetchRealtimeBusLocations(lineShortNameToFetch);
      print(
        "[_MapScreenState_Debug] _fetchAndDisplayRealtimeBusLocations: API call returned. Features count: ${geoJsonData['features']?.length ?? 0}",
      );
      final List<dynamic> features = geoJsonData['features'] ?? [];
      Position? newHighlightedBusPosition;

      if (features.isNotEmpty) {
        int closestUpcomingBusIndex = -1;
        double minDistanceToOriginStop = double.infinity;

        if (_currentFullShapeForBusLeg != null &&
            _currentFullShapeForBusLeg!.isNotEmpty &&
            _originStopIndexOnShape != null) {
          // --- INICIO LÓGICA REIMPLEMENTADA DE main-old.dart ---
          final Point_dart userOriginStopLocation = Point_dart(
            lat:
                (_currentFullShapeForBusLeg![_originStopIndexOnShape!].lat
                        as num)
                    .toDouble(),
            lng:
                (_currentFullShapeForBusLeg![_originStopIndexOnShape!].lng
                        as num)
                    .toDouble(),
          );

          for (int i = 0; i < features.length; i++) {
            var feature = features[i];
            if (feature is Map<String, dynamic> &&
                feature['geometry'] != null &&
                feature['geometry']['coordinates'] != null) {
              final coords = feature['geometry']['coordinates'];
              if (coords is List && coords.length == 2) {
                final busPoint = Point_dart(
                  lat: (coords[1] as num).toDouble(),
                  lng: (coords[0] as num).toDouble(),
                );

                // >>> AÑADIR ESTA COMPROBACIÓN <<<
                if (busPoint.lat == 0.0 && busPoint.lng == 0.0) {
                  print(
                    "[_MapScreenState_Debug] Bus $i at (${busPoint.lng}, ${busPoint.lat}) has (0,0) coordinates. Marking as NOT relevant and skipping.",
                  );
                  if (feature is Map<String, dynamic>) {
                    feature['properties'] = feature['properties'] ?? {};
                    feature['properties']['isPastOrigin'] = false;
                    feature['properties']['isRelevant'] = false;
                    feature['properties']['isClosestUpcoming'] = false;
                    feature['properties']['busIndexOnShape'] = -1;
                  }
                  continue; // Saltar al siguiente feature
                }
                // >>> FIN DE LA COMPROBACIÓN <<<

                final busIndexOnShape = _findClosestPointIndexOnShape(
                  _currentFullShapeForBusLeg!,
                  busPoint,
                );

                bool isPastUserOrigin = false;
                bool isRelevantToUserPath = false;

                if (busIndexOnShape != -1) {
                  // isPastUserOrigin: el índice del bus es mayor que el índice de la parada donde sube el usuario
                  isPastUserOrigin = busIndexOnShape > _originStopIndexOnShape!;

                  // >>> MODIFICACIÓN: Simplificar isRelevantToUserPath <<<
                  // Consideramos relevante un bus si está antes o en la parada de destino (o si no hay destino)
                  // y si no ha pasado la parada de origen del usuario.
                  isRelevantToUserPath =
                      (!isPastUserOrigin) && // No debe haber pasado el origen
                      (_destinationStopIndexOnShape ==
                              null || // No hay destino O
                          busIndexOnShape <=
                              _destinationStopIndexOnShape!); // Está antes o en el destino
                  // >>> FIN MODIFICACIÓN <<<
                }
                feature['properties'] = feature['properties'] ?? {};
                feature['properties']['isPastOrigin'] = isPastUserOrigin;
                feature['properties']['isRelevant'] = isRelevantToUserPath;
                feature['properties']['isClosestUpcoming'] =
                    false; // Inicializar

                // Comprobar si este bus es candidato para ser el más cercano
                // Debe ser relevante (estar en el tramo del usuario) y no haber pasado la parada de origen.
                // print(\"[_MapScreenState_Debug] Bus $i: busIdx=$busIndexOnShape, origIdx=$_originStopIndexOnShape, destIdx=$_destinationStopIndexOnShape => relevant=$isRelevantToUserPath, pastOrigin=$isPastUserOrigin\");

                // >>> MODIFICACIÓN: Buscar el bus relevante más cercano al origen (índice más alto <= origen) <<<
                // Solo consideramos buses que son relevantes y no han pasado el origen.
                if (isRelevantToUserPath) {
                  // isRelevantToUserPath ya incluye !isPastUserOrigin
                  // En lugar de buscar la menor distancia, buscamos el bus con el índice en el shape
                  // más cercano a _originStopIndexOnShape pero menor o igual a él.
                  // Un índice más alto en el shape antes del origen significa que está más cerca del origen.
                  if (closestUpcomingBusIndex == -1 ||
                      busIndexOnShape >
                          (features[closestUpcomingBusIndex]['properties']['busIndexOnShape'] ??
                              -1)) {
                    // Guardamos el índice del feature y su índice en el shape para comparación futura
                    features[i]['properties']['busIndexOnShape'] =
                        busIndexOnShape; // Añadir busIndexOnShape a properties
                    closestUpcomingBusIndex = i;
                    print(
                      "[_MapScreenState_Debug] Bus $i is NEW closest upcoming. Index on shape: $busIndexOnShape",
                    );
                  } else {
                    // Guardamos el índice del feature y su índice en el shape aunque no sea el más cercano por ahora
                    features[i]['properties']['busIndexOnShape'] =
                        busIndexOnShape; // Añadir busIndexOnShape a properties
                    print(
                      "[_MapScreenState_Debug] Bus $i is Relevant but not closest upcoming. Index on shape: $busIndexOnShape",
                    );
                  }
                } else {
                  // Guardamos el índice del feature y su índice en el shape aunque no sea relevante
                  features[i]['properties']['busIndexOnShape'] =
                      busIndexOnShape; // Añadir busIndexOnShape a properties
                  print(
                    "[_MapScreenState_Debug] Bus $i is NOT relevant. Index on shape: $busIndexOnShape",
                  );
                }
                // >>> FIN MODIFICACIÓN <<<
              } else {
                // Coordenadas inválidas, marcar como no relevante
                feature['properties'] = feature['properties'] ?? {};
                feature['properties']['isPastOrigin'] = false;
                feature['properties']['isRelevant'] = false;
                feature['properties']['isClosestUpcoming'] = false;
              }
            } else {
              // Feature inválida, marcar como no relevante
              if (feature is Map<String, dynamic>) {
                feature['properties'] = feature['properties'] ?? {};
                feature['properties']['isPastOrigin'] = false;
                feature['properties']['isRelevant'] = false;
                feature['properties']['isClosestUpcoming'] = false;
              }
            }
          }
          // --- FIN LÓGICA REIMPLEMENTADA ---

          // Marcar el bus más cercano si se encontró
          if (closestUpcomingBusIndex != -1) {
            // --- INICIO LÓGICA REIMPLEMENTADA ---
            (features[closestUpcomingBusIndex]['properties']
                    as Map<String, dynamic>)['isClosestUpcoming'] =
                true;
            // Extraer la posición del bus resaltado
            final closestBusFeature = features[closestUpcomingBusIndex];
            if (closestBusFeature['geometry'] != null &&
                closestBusFeature['geometry']['coordinates'] != null) {
              final coords =
                  closestBusFeature['geometry']['coordinates'] as List;
              if (coords.length == 2) {
                newHighlightedBusPosition = Position(
                  (coords[0] as num).toDouble(),
                  (coords[1] as num).toDouble(),
                );
              }
            }
            // --- FIN LÓGICA REIMPLEMENTADA ---
            print(
              "[_MapScreenState_Debug] _fetchAndDisplayRealtimeBusLocations: Closest bus found (Index: $closestUpcomingBusIndex), newHighlightedBusPosition: (${newHighlightedBusPosition?.lng}, ${newHighlightedBusPosition?.lat})",
            );
          } else {
            print(
              "[_MapScreenState_Debug] _fetchAndDisplayRealtimeBusLocations: No relevant upcoming bus found on shape.",
            );
          }
        } else {
          print(
            "[_MapScreenState_Debug] _fetchAndDisplayRealtimeBusLocations: Missing shape or origin stop index for relevance calculation.",
          );
          // Podríamos tomar el primer bus como opción si no hay shape
          // if (features.isNotEmpty) { newHighlightedBusPosition = ... primer bus ...; }
        }

        final currentHighlightedBus = mapState.highlightedBusPosition;
        if ((currentHighlightedBus?.lng != newHighlightedBusPosition?.lng ||
                currentHighlightedBus?.lat != newHighlightedBusPosition?.lat) ||
            (currentHighlightedBus == null &&
                newHighlightedBusPosition != null) ||
            (currentHighlightedBus != null &&
                newHighlightedBusPosition == null)) {
          print(
            "[_MapScreenState_Debug] _fetchAndDisplayRealtimeBusLocations: highlightedBusPosition changed. Updating notifier. Old: (${currentHighlightedBus?.lng}, ${currentHighlightedBus?.lat}), New: (${newHighlightedBusPosition?.lng}, ${newHighlightedBusPosition?.lat})",
          );
          mapNotifier.state = mapNotifier.state.copyWith(
            highlightedBusPosition: () => newHighlightedBusPosition,
          );
        } else {
          print(
            "[_MapScreenState_Debug] _fetchAndDisplayRealtimeBusLocations: highlightedBusPosition did NOT change significantly. Old: (${currentHighlightedBus?.lng}, ${currentHighlightedBus?.lat}), New: (${newHighlightedBusPosition?.lng}, ${newHighlightedBusPosition?.lat})",
          );
        }

        if (_mapboxService != null) {
          print(
            "[_MapScreenState_Debug] _fetchAndDisplayRealtimeBusLocations: Calling _mapboxService.drawIncomingBusSegment.",
          );
          await _mapboxService!.drawIncomingBusSegment(
            newHighlightedBusPosition,
            _currentFullShapeForBusLeg,
            _originStopIndexOnShape,
          );
        }

        final String modifiedGeoJsonString = json.encode(geoJsonData);
        final sourceExists = await mapboxMap!.style.styleSourceExists(
          REALTIME_BUS_SOURCE_ID,
        );
        if (!sourceExists) {
          print(
            "[_MapScreenState_Debug] _fetchAndDisplayRealtimeBusLocations: Adding source $REALTIME_BUS_SOURCE_ID.",
          );
          await mapboxMap!.style.addSource(
            GeoJsonSource(
              id: REALTIME_BUS_SOURCE_ID,
              data: modifiedGeoJsonString,
            ),
          );
        } else {
          print(
            "[_MapScreenState_Debug] _fetchAndDisplayRealtimeBusLocations: Updating source $REALTIME_BUS_SOURCE_ID.",
          );
          final source =
              await mapboxMap!.style.getSource(REALTIME_BUS_SOURCE_ID)
                  as GeoJsonSource?;
          await source?.updateGeoJSON(modifiedGeoJsonString);
        }
        print(
          "[_MapScreenState_Debug] _fetchAndDisplayRealtimeBusLocations: Calling _updateRealtimeBusLayers.",
        );
        await _updateRealtimeBusLayers(features);
      } else {
        // No se encontraron buses
        print(
          "[_MapScreenState_Debug] _fetchAndDisplayRealtimeBusLocations: No features (buses) returned from API for $lineShortNameToFetch.",
        );
        if (mapState.highlightedBusPosition != null) {
          print(
            "[_MapScreenState_Debug] _fetchAndDisplayRealtimeBusLocations: Clearing highlightedBusPosition in notifier as no buses found.",
          );
          mapNotifier.state = mapNotifier.state.copyWith(
            highlightedBusPosition: () => null,
          );
        }
        try {
          print(
            "[_MapScreenState_Debug] _fetchAndDisplayRealtimeBusLocations: Attempting to remove bus layers (no buses).",
          );
          // ... (lógica existente para remover capas)
        } catch (_) {}
        _mapboxService?.stopTooltipFloatingAnimation();
        if (_mapboxService != null) {
          print(
            "[_MapScreenState_Debug] _fetchAndDisplayRealtimeBusLocations: Calling _mapboxService.drawIncomingBusSegment with null (no buses).",
          );
          await _mapboxService!.drawIncomingBusSegment(null, null, null);
        }
      }
    } catch (e, s) {
      print(
        "[_MapScreenState_Debug] _fetchAndDisplayRealtimeBusLocations: Exception: $e",
      );
      print(s);
      if (_mapboxService != null) {
        print(
          "[_MapScreenState_Debug] _fetchAndDisplayRealtimeBusLocations: Exception caught, calling _mapboxService.drawIncomingBusSegment with null.",
        );
        await _mapboxService!.drawIncomingBusSegment(null, null, null);
      }
    }
  }

  Future<void> _updateRealtimeBusLayers(List<dynamic> features) async {
    print(
      "[_MapScreenState_Debug] _updateRealtimeBusLayers called with ${features.length} features.",
    );
    if (mapboxMap == null || _mapboxService == null) {
      print(
        "[_MapScreenState_Debug] _updateRealtimeBusLayers: mapboxMap or _mapboxService is null. Aborting.",
      );
      return;
    }

    // >>> MODIFICACIÓN: Eliminar capas existentes antes de recrearlas <<<
    try {
      if (await mapboxMap!.style.styleLayerExists(REALTIME_BUS_LAYER_ID)) {
        print(
          "[_MapScreenState_Debug] _updateRealtimeBusLayers: Removing existing layer $REALTIME_BUS_LAYER_ID.",
        );
        await mapboxMap!.style.removeStyleLayer(REALTIME_BUS_LAYER_ID);
      }
      if (await mapboxMap!.style.styleLayerExists(REALTIME_BUS_DOTS_LAYER_ID)) {
        print(
          "[_MapScreenState_Debug] _updateRealtimeBusLayers: Removing existing layer $REALTIME_BUS_DOTS_LAYER_ID.",
        );
        await mapboxMap!.style.removeStyleLayer(REALTIME_BUS_DOTS_LAYER_ID);
      }
      // La capa de tooltip ya se maneja con eliminación/adición, así que no necesita cambios aquí.
    } catch (e) {
      print(
        "[_MapScreenState_Debug] _updateRealtimeBusLayers: Error removing existing layers: $e. Proceeding...",
      );
    }

    // Si no hay features, no añadir las capas de nuevo
    if (features.isEmpty) {
      print(
        "[_MapScreenState_Debug] _updateRealtimeBusLayers: No features, layers removed (or not added).",
      );
      // Asegurar que la animación del tooltip se detenga
      _mapboxService?.stopTooltipFloatingAnimation();
      return;
    }

    final String iconToUse = "bus-icon";
    final double normalIconSize = 0.4;
    final double smallerRelevantIconSize = normalIconSize * 0.8;
    final double closestUpcomingIconSize = normalIconSize * 1.5;

    // >>> RESTAURAR LÓGICA DE FILTROS Y EXISTENCIA <<<
    // AHORA SIEMPRE AÑADIMOS LA CAPA SI HAY FEATURES, YA QUE LA ELIMINAMOS ANTES
    // final bool mainLayerExists = await mapboxMap!.style.styleLayerExists(
    //   REALTIME_BUS_LAYER_ID,
    // );
    final List<Object> mainFilter = [
      'all', // <-- Cambiado a 'all' para compatibilidad, aunque solo hay una condición
      [
        '==',
        ['get', 'isRelevant'],
        true,
      ],
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

    // if (!mainLayerExists) { // AHORA SIEMPRE AÑADIMOS
    print(
      "[_MapScreenState_Debug] _updateRealtimeBusLayers: Adding layer $REALTIME_BUS_LAYER_ID.",
    );
    try {
      // Envuelve en try-catch
      await mapboxMap!.style.addLayer(
        SymbolLayer(
          id: REALTIME_BUS_LAYER_ID,
          sourceId: REALTIME_BUS_SOURCE_ID, // <<< Restaurar sourceId
          filter: mainFilter,
          iconImageExpression: iconImageExpression, // <<< OK aquí
          iconSizeExpression: iconSizeExpression, // <<< OK aquí
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          minZoom: 10.0,
        ),
      );
    } catch (e, s) {
      print(
        "[_MapScreenState_Debug] _updateRealtimeBusLayers: FAILED adding layer $REALTIME_BUS_LAYER_ID: $e",
      );
      print(s);
    }
    // } else {
    //   print(
    //     "[_MapScreenState_Debug] _updateRealtimeBusLayers: Updating properties for layer $REALTIME_BUS_LAYER_ID.",
    //   );
    //   await mapboxMap!.style.setStyleLayerProperty(
    //     REALTIME_BUS_LAYER_ID,
    //     "filter",
    //     mainFilter,
    //   );
    //   // <<< ELIMINADO: NO SE PUEDE ACTUALIZAR LA EXPRESIÓN >>>
    //   // await mapboxMap!.style.setStyleLayerProperty(
    //   //   REALTIME_BUS_LAYER_ID,
    //   //   "iconImageExpression",
    //   //   iconImageExpression,
    //   // );
    //   // await mapboxMap!.style.setStyleLayerProperty(
    //   //   REALTIME_BUS_LAYER_ID,
    //   //   "iconSizeExpression",
    //   //   iconSizeExpression,
    //   // );
    // }

    // >>> RESTAURAR LÓGICA PARA DOTS LAYER <<<
    // AHORA SIEMPRE AÑADIMOS LA CAPA SI HAY FEATURES, YA QUE LA ELIMINAMOS ANTES
    // final bool dotsLayerExists = await mapboxMap!.style.styleLayerExists(
    //   REALTIME_BUS_DOTS_LAYER_ID,
    // );
    final List<Object> dotsFilter = [
      'all', // <-- Cambiado a 'all' para compatibilidad
      [
        '==',
        ['get', 'isRelevant'],
        false,
      ],
    ];

    // if (!dotsLayerExists) { // AHORA SIEMPRE AÑADIMOS
    print(
      "[_MapScreenState_Debug] _updateRealtimeBusLayers: Adding layer $REALTIME_BUS_DOTS_LAYER_ID.",
    );
    try {
      // Envuelve en try-catch
      await mapboxMap!.style.addLayer(
        CircleLayer(
          id: REALTIME_BUS_DOTS_LAYER_ID,
          sourceId: REALTIME_BUS_SOURCE_ID, // <<< Restaurar sourceId
          filter: dotsFilter,
          circleColor: Colors.red.value,
          circleRadius: 3.0,
          circleOpacity: 0.7,
        ),
      );
    } catch (e, s) {
      print(
        "[_MapScreenState_Debug] _updateRealtimeBusLayers: FAILED adding layer $REALTIME_BUS_DOTS_LAYER_ID: $e",
      );
      print(s);
    }
    // } else {
    //   print(
    //     "[_MapScreenState_Debug] _updateRealtimeBusLayers: Updating filter for layer $REALTIME_BUS_DOTS_LAYER_ID.",
    //   );
    //   await mapboxMap!.style.setStyleLayerProperty(
    //     REALTIME_BUS_DOTS_LAYER_ID,
    //     "filter",
    //     dotsFilter,
    //   );
    // }

    // >>> RESTAURAR LÓGICA PARA TOOLTIP LAYER <<<
    // Esta lógica ya elimina y añade la capa, así que debería estar bien.
    final String tooltipLayerId = MapboxService.INCOMING_BUS_TOOLTIP_LAYER_ID;
    final bool tooltipLayerExists = await mapboxMap!.style.styleLayerExists(
      tooltipLayerId,
    );
    final List<Object> tooltipFilter = [
      'all',
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
    ];
    final bool shouldShowTooltip = features.any(
      (f) => f is Map && f['properties']?['isClosestUpcoming'] == true,
    );

    if (shouldShowTooltip) {
      if (!tooltipLayerExists) {
        print(
          "[_MapScreenState_Debug] _updateRealtimeBusLayers: Adding layer $tooltipLayerId.",
        );
        await mapboxMap!.style.addLayer(
          SymbolLayer(
            id: tooltipLayerId,
            sourceId: REALTIME_BUS_SOURCE_ID, // <<< Restaurar sourceId
            filter: tooltipFilter,
            iconImage: MapboxService.INCOMING_BUS_TOOLTIP_ICON_ID,
            iconSize: closestUpcomingIconSize,
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
            minZoom: 10.0,
            iconOffset: [0.0, 0.0], // Offset inicial, la animación lo cambiará
          ),
        );
      } else {
        // Asegurar que el filtro esté actualizado aunque la capa exista
        print(
          "[_MapScreenState_Debug] _updateRealtimeBusLayers: Updating filter for layer $tooltipLayerId.",
        );
        await mapboxMap!.style.setStyleLayerProperty(
          tooltipLayerId,
          "filter",
          tooltipFilter,
        );
      }
      print(
        "[_MapScreenState_Debug] _updateRealtimeBusLayers: Starting tooltip animation.",
      );
      _mapboxService?.startTooltipFloatingAnimation();
    } else {
      if (tooltipLayerExists) {
        print(
          "[_MapScreenState_Debug] _updateRealtimeBusLayers: Removing layer $tooltipLayerId.",
        );
        await mapboxMap!.style.removeStyleLayer(tooltipLayerId);
      }
      print(
        "[_MapScreenState_Debug] _updateRealtimeBusLayers: Stopping tooltip animation.",
      );
      _mapboxService?.stopTooltipFloatingAnimation();
    }
  }

  Future<void> _startTrackingBusLine(RouteLeg busLegToTrack) async {
    print(
      "[_MapScreenState_Debug] _startTrackingBusLine called for leg: ${busLegToTrack.route?.shortName} (Mode: ${busLegToTrack.mode})",
    );
    await _stopTrackingBusLine();

    final mapState = ref.read(mapNotifierProvider);
    final String? lineShortName = busLegToTrack.route?.shortName;
    final String? otpShapeId = busLegToTrack.trip?.shapeId;
    String? shapeIdToSearch = otpShapeId;
    print(
      "[_MapScreenState_Debug] _startTrackingBusLine: lineShortName=$lineShortName, otpShapeId=$otpShapeId",
    );

    if (otpShapeId != null && otpShapeId.contains(':')) {
      shapeIdToSearch = otpShapeId.split(':').last;
      print(
        "[_MapScreenState_Debug] _startTrackingBusLine: shapeIdToSearch normalized to $shapeIdToSearch",
      );
    }

    if (lineShortName == null || lineShortName.isEmpty) {
      print(
        "[_MapScreenState_Debug] _startTrackingBusLine: No lineShortName, cannot track. Aborting.",
      );
      return;
    }

    print(
      "[_MapScreenState_Debug] _startTrackingBusLine: Attempting to track line: $lineShortName, Shape ID: $shapeIdToSearch",
    );

    _currentFullShapeForBusLeg = null;
    _originStopIndexOnShape = null;
    _destinationStopIndexOnShape = null;

    if (!_shapesLoaded) {
      print(
        "[_MapScreenState_Debug] _startTrackingBusLine: shapes.geojson not loaded. Loading now...",
      );
      await _loadAndParseShapesGeoJson();
      if (!_shapesLoaded) {
        print(
          "[_MapScreenState_Debug] _startTrackingBusLine: Failed to load shapes.geojson. Aborting tracking for this leg.",
        );
        return;
      }
      print(
        "[_MapScreenState_Debug] _startTrackingBusLine: shapes.geojson loaded.",
      );
    }

    if (shapeIdToSearch != null &&
        _shapeGeometries.containsKey(shapeIdToSearch)) {
      _currentFullShapeForBusLeg = _shapeGeometries[shapeIdToSearch];
      print(
        "[_MapScreenState_Debug] _startTrackingBusLine: Found shape for $shapeIdToSearch. Length: ${_currentFullShapeForBusLeg?.length}",
      );
      final LegEndpoint busLegFrom = busLegToTrack.from;
      final LegEndpoint busLegTo = busLegToTrack.to;
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

        final userAlightingStopCoords = Point_dart(
          lat: busLegTo.lat,
          lng: busLegTo.lon,
        );
        _destinationStopIndexOnShape = findClosestPointIndexOnShape(
          _currentFullShapeForBusLeg!,
          userAlightingStopCoords,
        );
        print(
          "[_MapScreenState_Debug] _startTrackingBusLine: Origin stop index on shape: $_originStopIndexOnShape, Dest stop index: $_destinationStopIndexOnShape",
        );
      } else {
        print(
          "[_MapScreenState_Debug] _startTrackingBusLine: Shape for $shapeIdToSearch is empty or null.",
        );
      }
    } else {
      print(
        "[_MapScreenState_Debug] _startTrackingBusLine: Shape ID $shapeIdToSearch not found in _shapeGeometries. Keys: ${_shapeGeometries.keys.take(5).join(', ')}...",
      );
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
        print(
          "[_MapScreenState_Debug] _startTrackingBusLine: Calling _mapboxService.drawFullBusLineShape for $shapeIdToSearch.",
        );
        await _mapboxService?.drawFullBusLineShape(
          positionsToDraw,
          fullLineSourceId,
          fullLineLayerId,
          Colors.grey.withOpacity(0.7),
          3.0,
        );
      } catch (e) {
        print(
          "[_MapScreenState_Debug] _startTrackingBusLine: Error drawing full bus line shape: $e",
        );
      }
    }

    print(
      "[_MapScreenState_Debug] _startTrackingBusLine: Initiating first _fetchAndDisplayRealtimeBusLocations and starting timer.",
    );
    _fetchAndDisplayRealtimeBusLocations();
    _realtimeBusTimer?.cancel();
    _realtimeBusTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      final currentLegToTrack =
          ref.read(mapNotifierProvider).legToTrackInRealtime;
      print(
        "[_MapScreenState_Debug] Timer tick: currentLegToTrack=${currentLegToTrack?.route?.shortName}, busLegToTrack(original)=${busLegToTrack.route?.shortName}",
      );
      if (currentLegToTrack == busLegToTrack) {
        print(
          "[_MapScreenState_Debug] Timer tick: Calling _fetchAndDisplayRealtimeBusLocations.",
        );
        _fetchAndDisplayRealtimeBusLocations();
      } else {
        print(
          "[_MapScreenState_Debug] Timer tick: Leg to track changed or null. Cancelling timer.",
        );
        timer.cancel();
      }
    });
  }

  Future<void> _stopTrackingBusLine() async {
    print("[_MapScreenState_Debug] _stopTrackingBusLine called.");
    _realtimeBusTimer?.cancel();
    _realtimeBusTimer = null;
    print("[_MapScreenState_Debug] _stopTrackingBusLine: Timer cancelled.");

    final mapNotifier = ref.read(mapNotifierProvider.notifier);
    if (ref.read(mapNotifierProvider).highlightedBusPosition != null) {
      print(
        "[_MapScreenState_Debug] _stopTrackingBusLine: Clearing highlightedBusPosition in notifier.",
      );
      mapNotifier.state = mapNotifier.state.copyWith(
        highlightedBusPosition: () => null,
      );
    }

    print(
      "[_MapScreenState_Debug] _stopTrackingBusLine: Calling _mapboxService.stopTooltipFloatingAnimation.",
    );
    _mapboxService?.stopTooltipFloatingAnimation();

    _currentFullShapeForBusLeg = null;
    _originStopIndexOnShape = null;
    _destinationStopIndexOnShape = null;
    print(
      "[_MapScreenState_Debug] _stopTrackingBusLine: Cleared local shape/index variables.",
    );

    if (mapboxMap != null && _mapboxService != null) {
      try {
        print(
          "[_MapScreenState_Debug] _stopTrackingBusLine: Attempting to remove realtime bus layers.",
        );
        // ... (lógica existente de limpieza de capas REALTIME_BUS_*)
      } catch (e) {
        print(
          "[_MapScreenState_Debug] _stopTrackingBusLine: Error cleaning realtime bus layers: $e",
        );
      }

      if (_currentFullLineShapeId != null) {
        print(
          "[_MapScreenState_Debug] _stopTrackingBusLine: Attempting to remove full bus line shape layer: $_currentFullLineShapeId.",
        );
        // ... (lógica existente de limpieza de capa FULL_BUS_LINE_SHAPE_*)
        _currentFullLineShapeId = null;
      }

      try {
        print(
          "[_MapScreen_Debug] _stopTrackingBusLine: Calling _mapboxService.drawIncomingBusSegment with null to clear it.",
        );
        await _mapboxService!.drawIncomingBusSegment(null, null, null);
      } catch (e) {
        print(
          "[_MapScreenState_Debug] _stopTrackingBusLine: Error cleaning incoming bus segment: $e",
        );
      }
    } else {
      print(
        "[_MapScreenState_Debug] _stopTrackingBusLine: mapboxMap or _mapboxService is null. Cannot clean layers.",
      );
    }
  }

  // --- Callbacks de Eventos del Mapa ---

  void _onMapCameraChange(CameraChangedEventData event) {
    // print("[_MapScreenState_Debug] _onMapCameraChange triggered.");
    if (_isProgrammaticCameraMove) {
      // print(
      //     "[_MapScreenState_Debug] _onMapCameraChange: Ignored due to _isProgrammaticCameraMove.");
      return;
    }

    // Si no es un movimiento programático y el usuario aún no ha sido marcado como que inició un movimiento
    if (!_userHasInitiatedMove) {
      print(
        "[_MapScreenState_Debug] _onMapCameraChange: User initiated move. Setting _userHasInitiatedMove = true and userManuallyMovedMap = true.",
      );
      _userHasInitiatedMove = true;
      ref.read(mapNotifierProvider.notifier).setUserManuallyMovedMap(true);
    } else {
      // print(
      //     "[_MapScreenState_Debug] _onMapCameraChange: User move already in progress (_userHasInitiatedMove=true).");
    }
  }

  void _onMapIdle(MapIdleEventData data) {
    print("[_MapScreenState_Debug] _onMapIdle triggered.");
    final currentMapState = ref.read(mapNotifierProvider);

    if (_isProgrammaticCameraMove) {
      print(
        "[_MapScreenState_Debug] _onMapIdle: _isProgrammaticCameraMove was true. Scheduling to set it to false and potentially userManuallyMovedMap to false.",
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          print(
            "[_MapScreenState_Debug] _onMapIdle (after delay): Setting _isProgrammaticCameraMove to false.",
          );
          _isProgrammaticCameraMove = false;
          // Si el último movimiento fue programático y no hay un bus destacado O el usuario no había movido el mapa antes,
          // reseteamos userManuallyMovedMap.
          // Esta lógica asegura que si el usuario movió, y LUEGO un bus destacó e hizo zoom,
          // el estado de que el usuario movió no se pierda inmediatamente.
          if (ref.read(mapNotifierProvider).highlightedBusPosition == null ||
              !ref.read(mapNotifierProvider).userManuallyMovedMap) {
            // Solo se resetea userManuallyMovedMap si no hay bus destacado o si no lo había movido antes el usuario
            print(
              "[_MapScreenState_Debug] _onMapIdle (after delay): No highlighted bus or user hadn't moved map prior. Setting userManuallyMovedMap to false.",
            );
            ref
                .read(mapNotifierProvider.notifier)
                .setUserManuallyMovedMap(false);
          }
        }
      });
    } else if (_userHasInitiatedMove) {
      // Si el mapa se detuvo y fue debido a un movimiento iniciado por el usuario (no programático)
      print(
        "[_MapScreenState_Debug] _onMapIdle: User-initiated move finished. Setting _userHasInitiatedMove = false.",
      );
      _userHasInitiatedMove = false;
      // No tocamos userManuallyMovedMap aquí, ya se seteó en _onMapCameraChange
      // y solo se resetea bajo condiciones específicas de movimiento programático.
    } else {
      print(
        "[_MapScreenState_Debug] _onMapIdle: _isProgrammaticCameraMove was false and _userHasInitiatedMove was false. No specific action.",
      );
    }
  }

  // >>> INICIO MÉTODOS REINSERTADOS DE main-old.dart <<<
  int _findClosestPointIndexOnShape(
    List<Position> shapePoints,
    Point_dart targetPoint,
  ) {
    print(
      "[_MapScreenState_Debug] _findClosestPointIndexOnShape called. Target: (${targetPoint.lat}, ${targetPoint.lng}). Shape points: ${shapePoints.length}",
    );
    if (shapePoints.isEmpty) return -1;

    int closestIndex = -1;
    double minDistance = double.infinity;

    for (int i = 0; i < shapePoints.length; i++) {
      final shapePosition = shapePoints[i];
      // Asegurarse de que lat/lng sean double.
      final double shapeLat =
          (shapePosition.lat is num)
              ? (shapePosition.lat as num).toDouble()
              : 0.0;
      final double shapeLng =
          (shapePosition.lng is num)
              ? (shapePosition.lng as num).toDouble()
              : 0.0;

      final distance = _calculateHaversineDistance(
        targetPoint.lat,
        targetPoint.lng,
        shapeLat,
        shapeLng,
      );
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }
    print(
      "[_MapScreenState_Debug] _findClosestPointIndexOnShape result: Index=$closestIndex, MinDistance=$minDistance",
    );
    return closestIndex;
  }

  // Función auxiliar para distancia Haversine
  double _calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double R = 6371000; // Radio de la Tierra en metros

    double lat1Rad = math.pi * lat1 / 180;
    double lon1Rad = math.pi * lon1 / 180;
    double lat2Rad = math.pi * lat2 / 180;
    double lon2Rad = math.pi * lon2 / 180;

    double dLat = lat2Rad - lat1Rad;
    double dLon = lon2Rad - lon1Rad;

    double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return R * c; // Distancia en metros
  }

  // >>> FIN MÉTODOS REINSERTADOS <<<

  // >>> INICIO: Nuevos métodos para callbacks de gestos <<<
  void _onMapMoveStart(MapContentGestureContext context) {
    print(
      "[_MapScreenState_Debug] Gestures: _onMapMoveStart. Setting _userHasInitiatedMove = true.",
    );
    if (mounted) {
      setState(() {
        _userHasInitiatedMove = true;
      });
    }
  }

  void _onMapMoveEnd(MapContentGestureContext context) {
    print(
      "[_MapScreenState_Debug] Gestures: _onMapMoveEnd. Setting _userHasInitiatedMove = false.",
    );
    if (mounted) {
      setState(() {
        _userHasInitiatedMove = false;
      });
    }
  }

  // >>> FIN: Nuevos métodos para callbacks de gestos <<<
}

// Las funciones de utilidad calculateHaversineDistance y findClosestPointIndexOnShape
// ya fueron movidas a ../utils/ y se importan desde allí. No necesitan estar aquí.
