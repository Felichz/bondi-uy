import 'dart:async';
import 'package:flutter/material.dart';
// CAMBIADO: Importar todo el paquete en lugar de solo rootBundle
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
// Necesario para Point_dart

// Ajustar las rutas de importación según la nueva ubicación
// Alias para evitar colisión y usar models.Point_dart
import '../models/itinerary.dart';
import '../models/route_leg.dart';
import '../widgets/search_panel.dart';
import '../widgets/instructions_bar.dart';
import '../widgets/route_options_panel.dart';
import '../widgets/trip_instructions_sheet.dart';
import '../services/mapbox_service.dart';
// IMPORTAR BusRealtime

// Importar proveedores y estado
import '../providers/service_providers.dart'; // Asumo que bondiApiProvider está aquí o en api_provider.dart
import '../providers/map_notifier.dart';
import '../state/map_state.dart';
import '../controllers/map_zoom_controller.dart'; // AÑADIDO: Importar MapZoomController
import '../controllers/bus_tracking_controller.dart'; // AÑADIDO: Importar BusTrackingController
import '../controllers/route_display_controller.dart'; // AÑADIDO: Importar RouteDisplayController
import '../controllers/map_interaction_controller.dart'; // AÑADIDO: Importar MapInteractionController

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
  MapZoomController?
  _mapZoomController; // AÑADIDO: Instancia de MapZoomController
  BusTrackingController?
  _busTrackingController; // AÑADIDO: Instancia de BusTrackingController
  RouteDisplayController?
  _routeDisplayController; // AÑADIDO: Instancia de RouteDisplayController
  MapInteractionController?
  _mapInteractionController; // AÑADIDO: Instancia de MapInteractionController
  // CameraOptions iniciales, se pueden mover al MapNotifier o ser un ZoomTarget.initial.
  // final CameraOptions _initialCameraOptions = CameraOptions(
  //   center: Point(
  //     coordinates: Position(
  //       -56.164532, // Longitud de Montevideo
  //       -34.901112, // Latitud de Montevideo
  //     ),
  //   ),
  //   zoom: 12.0,
  // );

  // Controladores para los campos de texto de Origen y Destino
  late TextEditingController _origenController;
  late TextEditingController _destinoController;

  MapboxService? _mapboxService;

  late FocusNode _origenFocusNode;
  late FocusNode _destinoFocusNode;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    print("[_MapScreenState_Debug] initState called.");
    _origenController = TextEditingController();
    _destinoController = TextEditingController();
    _origenFocusNode = FocusNode();
    _destinoFocusNode = FocusNode();

    // Listener para mostrar RouteOptionsModal
    ref.listenManual<
      List<Itinerary>
    >(mapNotifierProvider.select((s) => s.availableItineraries), (
      previousItineraries,
      nextItineraries,
    ) {
      final mapState = ref.read(
        mapNotifierProvider,
      ); // Leer estado actual para isCalculatingRoute
      if (nextItineraries.isNotEmpty && !mapState.isCalculatingRoute) {
        // Comprobar si realmente es un cambio nuevo
        bool itinerariesTrulyChanged =
            previousItineraries == null ||
            !listEquals(previousItineraries, nextItineraries);

        if (itinerariesTrulyChanged) {
          _routeDisplayController?.clearPreviousRouteLayers().then((_) {
            _busTrackingController?.stopTrackingBusLine();
            if (mounted) {
              showRouteOptionsModal(
                context: context,
                availableItineraries: nextItineraries,
                fetchUpcomingBuses: _fetchUpcomingBuses,
                processAndDisplaySelectedItinerary: (Itinerary itinerary) {
                  print(
                    "[_MapScreenState_DEBUG] RouteOptionsPanel: Itinerary selected.",
                  );
                  // MapNotifier se encarga de resetear userInteraction y currentZoomTarget
                  ref
                      .read(mapNotifierProvider.notifier)
                      .processSelectedItinerary(itinerary);
                },
              );
            }
          });
        }
      }
    });

    // Listener para reaccionar a cambios en currentZoomTarget
    ref.listenManual<ZoomTarget>(
      mapNotifierProvider.select((state) => state.currentZoomTarget),
      (prevZoomTarget, nextZoomTarget) {
        print(
          "[_MapScreenState_DEBUG] Listener (currentZoomTarget) triggered. Prev: ${prevZoomTarget?.type}, Next: ${nextZoomTarget.type}",
        );

        if (_mapZoomController == null) {
          print(
            "[_MapScreenState_DEBUG] Zoom listener: _mapZoomController is null. Aborting zoom.",
          );
          return;
        }

        // Delegar el manejo del zoom al MapZoomController
        _mapZoomController!.handleZoomTarget(nextZoomTarget);
      },
      onError: (error, stackTrace) {
        if (kDebugMode) {
          print(
            '[_MapScreenState_Debug] Error en listener currentZoomTarget: $error\n$stackTrace',
          );
        }
      },
    );

    // Listener para iniciar navegación detallada (ya no maneja zoom directamente)
    ref.listenManual<MapState>(mapNotifierProvider, (previous, next) {
      bool shouldStartNav =
          (previous == null ||
              previous.isInOverviewMode && !next.isInOverviewMode) ||
          (!previous.isInOverviewMode &&
              !next.isInOverviewMode &&
              previous.selectedLegIndex != next.selectedLegIndex);

      if (shouldStartNav &&
          !next.isInOverviewMode &&
          next.selectedLegIndex == 0) {
        if (next.currentRouteLegs.isNotEmpty && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _routeDisplayController?.updateMapRouteHighlight();
            }
          });
        }
      } else if (previous?.selectedLegIndex != next.selectedLegIndex &&
          !next.isInOverviewMode) {
        // Cambio de tramo en modo detallado
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _routeDisplayController?.updateMapRouteHighlight();
          }
        });
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

    // Listener para iniciar/detener sondeo de bus
    ref.listenManual<
      RouteLeg?
    >(mapNotifierProvider.select((s) => s.legToTrackInRealtime), (
      prevLeg,
      nextLeg,
    ) {
      print(
        "[_MapScreenState_Debug] Listener (legToTrackInRealtime): prevLeg=${prevLeg?.route?.shortName}, nextLeg=${nextLeg?.route?.shortName}",
      );
      // Asegurarse que el controlador esté inicializado
      if (_busTrackingController == null) {
        print(
          "[_MapScreenState_Debug] Listener (legToTrackInRealtime): _busTrackingController es null. Abortando.",
        );
        return;
      }

      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          if (nextLeg != null) {
            _busTrackingController!.startTrackingBusLine(nextLeg);
          } else {
            _busTrackingController!.stopTrackingBusLine();
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _origenController.dispose();
    _destinoController.dispose();
    _debounceTimer?.cancel();
    _mapboxService?.stopTooltipFloatingAnimation();
    _origenFocusNode.dispose();
    _destinoFocusNode.dispose();
    _busTrackingController?.dispose();
    _mapZoomController?.dispose();
    _routeDisplayController?.dispose();
    _mapInteractionController?.dispose();
    mapboxMap?.dispose();
    super.dispose();
  }

  _onMapCreated(MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    _mapboxService = MapboxService(this.mapboxMap!);
    // AÑADIDO: Inicializar MapZoomController aquí una vez que mapboxMap y mapboxService están listos
    _mapZoomController = MapZoomController(
      mapboxMap: this.mapboxMap!,
      mapboxService: _mapboxService!,
      ref: ref,
    );
    // AÑADIDO: Inicializar BusTrackingController aquí
    _busTrackingController = BusTrackingController(
      ref: ref,
      mapboxService: _mapboxService!,
    );
    // AÑADIDO: Inicializar RouteDisplayController aquí
    _routeDisplayController = RouteDisplayController(
      mapboxService: _mapboxService!,
      ref: ref,
    );
    // AÑADIDO: Inicializar MapInteractionController aquí
    _mapInteractionController = MapInteractionController(
      mapboxService: _mapboxService!,
      ref: ref,
    );
    print(
      "[_MapScreenState_Debug] _onMapCreated: mapboxMap instance set, MapZoomController, BusTrackingController, RouteDisplayController, and MapInteractionController initialized.",
    );
  }

  void _onStyleLoadedListener(StyleLoadedEventData event) async {
    if (_mapboxService != null && _mapZoomController != null) {
      await _mapboxService!.handleStyleLoaded();
      // Forzamos una revisión del target de zoom inicial por si el notifier ya lo estableció.
      // MapZoomController se encargará de aplicar el zoom si es de tipo initial.
      final initialZoomTarget = ref.read(mapNotifierProvider).currentZoomTarget;
      print(
        "[_MapScreenState_DEBUG] _onStyleLoaded: Checking initial zoom target: ${initialZoomTarget.type}",
      );
      if (initialZoomTarget.type == ZoomTargetType.initial) {
        _mapZoomController!.handleZoomTarget(initialZoomTarget);
      } // No es necesario un else para mapboxMap.flyTo aquí, ya que MapZoomController lo maneja.
    } else {
      print(
        "[MapScreen_Debug] MapboxService or MapZoomController no inicializado en _onStyleLoadedListener.",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapNotifierProvider);
    final mapNotifier = ref.read(mapNotifierProvider.notifier);

    ref.listen<List<RouteLeg>>(
      mapNotifierProvider.select((s) => s.currentRouteLegs),
      (previousLegs, nextLegs) {
        bool routeChanged =
            previousLegs == null || !listEquals(previousLegs, nextLegs);
        final currentMapState = ref.read(mapNotifierProvider);

        if (routeChanged &&
            nextLegs.isNotEmpty &&
            currentMapState.isInOverviewMode) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _routeDisplayController
                  ?.processAndDisplaySelectedItineraryUI(nextLegs)
                  .then((success) {
                    if (!success && mounted) {
                      _showNoRouteFoundMessage(
                        "El itinerario seleccionado no tiene tramos.",
                      );
                    }
                  });
            }
          });
        }
      },
    );

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: <Widget>[
              Expanded(
                child: Stack(
                  children: [
                    MapWidget(
                      key: const ValueKey("mapWidget"),
                      onMapCreated: _onMapCreated,
                      onStyleLoadedListener: _onStyleLoadedListener,
                      cameraOptions: MapZoomController.initialCameraOptions,
                      styleUri: MapboxStyles.MAPBOX_STREETS,
                      onTapListener: (MapContentGestureContext mapTapContext) {
                        _mapInteractionController?.handleMapTapEvent(
                          mapTapContext,
                          context,
                        );
                      },
                      onMapIdleListener:
                          _mapInteractionController?.onMapIdleListener,
                      onCameraChangeListener:
                          _mapInteractionController?.onMapCameraChangeListener,
                    ),
                    if (mapState.isCalculatingRoute)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.3),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                    TripInstructions(
                      currentRouteLegs: mapState.currentRouteLegs,
                      selectedLegIndex: mapState.selectedLegIndex,
                      showCollapsedInstructionsBar:
                          mapState.showCollapsedInstructionsBar,
                      origenControllerText: _origenController.text,
                      destinoControllerText: _destinoController.text,
                      isInOverviewMode: mapState.isInOverviewMode,
                      onLegSelectedInBottomSheet: (int tappedLegIndex) {
                        _showTripInstructionsBottomSheet(
                          mapState.currentRouteLegs,
                        );
                      },
                      onNavigateToPreviousLeg: _navigateToPreviousLeg,
                      onNavigateToNextLeg: _navigateToNextLeg,
                      onExpandInstructionsTap: () {
                        _showTripInstructionsBottomSheet(
                          mapState.currentRouteLegs,
                        );
                      },
                      realtimeEtaMinutes: mapState.highlightedBusEtaMinutes,
                      trackedBusLineShortNameForEta:
                          mapState.trackedBusLineShortName,
                    ),
                  ],
                ),
              ),
            ],
          ),
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
              initialExpandedState: mapState.currentRouteLegs.isEmpty,
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

  void _showNoRouteFoundMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    ref.read(mapNotifierProvider.notifier);
    if (ref.read(mapNotifierProvider).isCalculatingRoute) {}
  }

  void _showTripInstructionsBottomSheet(List<RouteLeg> legs) {
    if (!mounted || legs.isEmpty) return;
    // La lógica de mapState y mapNotifier ahora está dentro de TripInstructionsSheet o se accede vía ref.
    // final mapState = ref.read(mapNotifierProvider);
    // final mapNotifier = ref.read(mapNotifierProvider.notifier);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (BuildContext bc) {
        // Asegurarse de que _routeDisplayController no sea null aquí.
        // Si MapScreen es complejo, podrías tener un estado de carga/inicialización
        // para asegurar que todos los controladores estén listos.
        if (_routeDisplayController == null) {
          // Manejar el caso donde el controlador no está listo, aunque no debería ocurrir
          // si _onMapCreated se completó correctamente.
          return const Center(
            child: Text("Error: Controlador no inicializado."),
          );
        }
        return TripInstructionsSheet(
          legs: legs,
          origenControllerText: _origenController.text,
          destinoControllerText: _destinoController.text,
          routeDisplayController: _routeDisplayController!,
        );
      },
    );
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
    _routeDisplayController?.updateMapRouteHighlight();
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
    _routeDisplayController?.updateMapRouteHighlight();
  }

  Future<List<Map<String, dynamic>>> _fetchUpcomingBuses(
    String stopId,
    String lineShortName,
  ) async {
    final montevideoApiService = ref.read(montevideoApiServiceProvider);
    try {
      return await montevideoApiService.fetchUpcomingBusesForStopAndLine(
        stopId,
        lineShortName,
      );
    } catch (e) {
      rethrow;
    }
  }
}
