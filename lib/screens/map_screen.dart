import 'dart:async';
import 'package:flutter/material.dart';
// CAMBIADO: Importar todo el paquete en lugar de solo rootBundle
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Timestamp;
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
import '../services/geocoding_service.dart';
// IMPORTAR BusRealtime

// Importar proveedores y estado
import '../providers/service_providers.dart'; // Asumo que bondiApiProvider está aquí o en api_provider.dart
import '../providers/map_notifier.dart';
import '../state/map_state.dart';
import '../controllers/map_zoom_controller.dart'; // AÑADIDO: Importar MapZoomController
import '../controllers/bus_tracking_controller.dart'; // AÑADIDO: Importar BusTrackingController
import '../controllers/route_display_controller.dart'; // AÑADIDO: Importar RouteDisplayController
import '../controllers/map_interaction_controller.dart'; // AÑADIDO: Importar MapInteractionController
import '../models/processed_itinerary.dart'; // AÑADIDO
import '../models/point_dart.dart'
    as local_point; // Para el autocompletado si se usa
import '../models/bus_arrival_info.dart'; // AÑADIR ESTE IMPORT
import '../models/consolidated_itinerary.dart'; // AÑADIR IMPORT si no está
import '../models/leg_mode_constants.dart'; // Añadido para LegModeConstants

// Cambiar a ConsumerStatefulWidget
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  // Cambiar a ConsumerState
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

// Cambiar a ConsumerState<MapScreen>
class _MapScreenState extends ConsumerState<MapScreen>
    with SingleTickerProviderStateMixin {
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

  // Para gestionar el estado de la bottom sheet de búsqueda
  // Se podría mover a un provider si se vuelve más complejo
  ValueNotifier<bool> isSearchPanelExpanded = ValueNotifier(false);

  // Para evitar mostrar el SnackBar de no disponibilidad repetidamente
  bool _realtimeSnackbarShown = false;

  @override
  void initState() {
    super.initState();
    print("[_MapScreenState_Debug] initState called.");
    _origenController = TextEditingController();
    _destinoController = TextEditingController();
    _origenFocusNode = FocusNode();
    _destinoFocusNode = FocusNode();

    final mapNotifier = ref.read(mapNotifierProvider.notifier);

    ref.listenManual<
      PlanningStatus
    >(mapNotifierProvider.select((s) => s.planningStatus), (
      previousStatus,
      nextStatus,
    ) {
      final mapState = ref.read(mapNotifierProvider);
      if (nextStatus == PlanningStatus.success &&
          mapState.consolidatedItineraries.isNotEmpty) {
        _routeDisplayController?.clearPreviousRouteLayers().then((_) {
          _busTrackingController?.stopTrackingBusLine();
          if (mounted) {
            showRouteOptionsModal(
              context: context,
              processAndDisplaySelectedItinerary: (
                ConsolidatedItinerary consolidatedItinerary,
              ) {
                print(
                  "[_MapScreenState_DEBUG] RouteOptionsPanel: ConsolidatedItinerary selected.",
                );
                if (_mapboxService != null && _busTrackingController != null) {
                  mapNotifier.processSelectedItinerary(
                    consolidatedItinerary,
                    _mapboxService!,
                    _busTrackingController!,
                  );
                } else {
                  print(
                    "[_MapScreenState_ERROR] mapboxService o busTrackingController nulos al procesar itinerario.",
                  );
                }
                Navigator.of(context).pop();
                FocusScope.of(context).unfocus();
                _origenFocusNode.unfocus();
                _destinoFocusNode.unfocus();
                _realtimeSnackbarShown =
                    false; // Resetear al seleccionar nueva ruta
              },
            );
          }
        });
      } else if (nextStatus == PlanningStatus.success &&
          mapState.consolidatedItineraries.isEmpty) {
        print(
          "[_MapScreenState_DEBUG] PlanningStatus.success but no consolidated itineraries.",
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se encontraron rutas.")),
        );
        _realtimeSnackbarShown = false; // Resetear
      } else if (nextStatus == PlanningStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al planificar la ruta.")),
        );
        _realtimeSnackbarShown = false; // Resetear
      }
    });

    ref.listenManual<ZoomTargetType>(
      mapNotifierProvider.select((state) => state.currentZoomTarget),
      (prevZoomTargetType, nextZoomTargetType) {
        print(
          "[_MapScreenState_DEBUG] Listener (currentZoomTarget) triggered. Prev: $prevZoomTargetType, Next: $nextZoomTargetType",
        );
        if (_mapZoomController == null) {
          print(
            "[_MapScreenState_DEBUG] Zoom listener: _mapZoomController is null. Aborting zoom.",
          );
          return;
        }
        _mapZoomController!.handleZoomTarget(nextZoomTargetType);
      },
      onError: (error, stackTrace) {
        if (kDebugMode) {
          print(
            '[_MapScreenState_Debug] Error en listener currentZoomTarget: $error\n$stackTrace',
          );
        }
      },
    );

    ref.listenManual<MapState>(mapNotifierProvider, (previous, next) {
      bool isInOverviewModePrevious =
          previous?.currentDisplayMode == MapDisplayMode.routeOverview;
      bool isInOverviewModeNext =
          next.currentDisplayMode == MapDisplayMode.routeOverview;

      bool shouldStartNav =
          (previous == null ||
              (isInOverviewModePrevious && !isInOverviewModeNext)) ||
          (!isInOverviewModePrevious &&
              !isInOverviewModeNext &&
              previous?.currentLegIndex != next.currentLegIndex);

      if (shouldStartNav &&
          !isInOverviewModeNext &&
          next.currentLegIndex == 0) {
        final representativeItinerary = next.representativeItinerary;
        if (representativeItinerary != null &&
            (representativeItinerary.legs).isNotEmpty &&
            mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                _routeDisplayController != null &&
                _mapboxService != null) {
              _routeDisplayController!.updateMapRouteHighlight();
            }
          });
        }
      } else if (previous?.currentLegIndex != next.currentLegIndex &&
          !isInOverviewModeNext) {
        final representativeItinerary = next.representativeItinerary;
        if (representativeItinerary != null &&
            mounted &&
            _routeDisplayController != null &&
            _mapboxService != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _routeDisplayController!.updateMapRouteHighlight();
            }
          });
        }
      }

      if (next.realtimeTrackingAttempted && !next.realtimeTrackingAvailable) {
        if (!_realtimeSnackbarShown) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Seguimiento en tiempo real no disponible para este tramo.',
              ),
            ),
          );
          _realtimeSnackbarShown = true;
          if (next.currentDisplayMode == MapDisplayMode.legTracking) {
            mapNotifier.toggleInstructionsPanel(true);
          }
        }
      } else if (next.realtimeTrackingAvailable) {
        _realtimeSnackbarShown = false;
      }
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
    isSearchPanelExpanded.dispose();
    super.dispose();
  }

  _onMapCreated(MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    _mapboxService = MapboxService(this.mapboxMap!);
    _mapZoomController = MapZoomController(
      mapboxMap: this.mapboxMap!,
      mapboxService: _mapboxService!,
      ref: ref,
    );
    _busTrackingController = BusTrackingController(
      ref: ref,
      mapboxService: _mapboxService!,
    );
    _routeDisplayController = RouteDisplayController(
      mapboxService: _mapboxService!,
      ref: ref,
    );
    _mapInteractionController = MapInteractionController(
      ref: ref,
      mapboxService: _mapboxService!,
    );

    ref
        .read(mapNotifierProvider.notifier)
        .forceMapIdleAndZoomTo(ZoomTargetType.initial);

    if (mounted) {
      setState(() {});
    }
  }

  void _clearSearchFields() {
    _origenController.clear();
    _destinoController.clear();
    _origenFocusNode.unfocus();
    _destinoFocusNode.unfocus();
    final mapNotifier = ref.read(mapNotifierProvider.notifier);
    if (_mapboxService != null && _busTrackingController != null) {
      mapNotifier.clearOrigin(_mapboxService!, _busTrackingController!);
      mapNotifier.clearDestination(_mapboxService!, _busTrackingController!);
      mapNotifier.clearRouteState(_mapboxService!, _busTrackingController!);
    } else {
      print(
        "[_MapScreenState_ERROR] mapboxService o busTrackingController nulos al limpiar campos.",
      );
    }
  }

  void _onSearchPanelToggle(bool isExpanded) {
    isSearchPanelExpanded.value = isExpanded;
    final mapNotifier = ref.read(mapNotifierProvider.notifier);
    if (!isExpanded) {
      final mapState = ref.read(mapNotifierProvider);
      if (mapState.selectedConsolidatedItinerary == null &&
          mapState.origin == null &&
          mapState.destination == null) {
        mapNotifier.forceMapIdleAndZoomTo(ZoomTargetType.initial);
      }
    } else {
      final mapState = ref.read(mapNotifierProvider);
      if (mapState.origin == null &&
          mapState.destination == null &&
          mapState.selectedConsolidatedItinerary == null) {
        mapNotifier.forceMapIdleAndZoomTo(ZoomTargetType.initial);
      }
    }
  }

  void _onExpandInstructionsTap() {
    final mapNotifier = ref.read(mapNotifierProvider.notifier);
    final mapState = ref.read(mapNotifierProvider);

    if (mapState.selectedConsolidatedItinerary != null &&
        mapState.representativeItinerary != null) {
      if (mapState.showInstructionsPanel) {
        mapNotifier.toggleInstructionsPanel(false);
        mapNotifier.forceMapIdleAndZoomTo(ZoomTargetType.overview);
      } else {
        mapNotifier.toggleInstructionsPanel(true);
        if (mapState.currentLegIndex != null &&
            _mapboxService != null &&
            _busTrackingController != null) {
          final currentLeg =
              mapState.representativeItinerary!.legs[mapState.currentLegIndex!];
          if (currentLeg.mode == LegModeConstants.bus) {
            mapNotifier.switchToLegTracking(
              mapState.currentLegIndex!,
              _mapboxService!,
              _busTrackingController!,
            );
          } else {
            mapNotifier.forceMapIdleAndZoomTo(ZoomTargetType.leg);
          }
        } else {
          mapNotifier.forceMapIdleAndZoomTo(ZoomTargetType.overview);
        }
      }
    } else {
      mapNotifier.toggleInstructionsPanel(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapNotifierProvider);
    final mapNotifier = ref.read(mapNotifierProvider.notifier);

    return Scaffold(
      body: Stack(
        children: <Widget>[
          MapWidget(
            key: const ValueKey("mapWidget"),
            onMapCreated: _onMapCreated,
            cameraOptions:
                mapState.currentCameraOptions ??
                MapZoomController.initialCameraOptions,
            onTapListener: (MapContentGestureContext mcc) {
              if (mounted && _mapInteractionController != null) {
                _mapInteractionController!.handleMapTapEvent(mcc, context);
              }
            },
            onLongTapListener: (MapContentGestureContext context) {
              _mapInteractionController?.handleMapLongPressEvent(context);
            },
            onCameraChangeListener: (CameraChangedEventData data) {
              _mapInteractionController?.onMapCameraChangeListener(data);
            },
            onMapIdleListener: (MapIdleEventData data) {
              _mapInteractionController?.onMapIdleListener(data);
            },
            onStyleLoadedListener: (_) {
              print(
                "[_MapScreenState_DEBUG] Map style loaded (onStyleLoadedListener).",
              );
              _mapboxService?.handleStyleLoaded();
            },
            onMapLoadErrorListener: (MapLoadingErrorEventData data) {
              print("[_MapScreenState_ERROR] Map load error: ${data.message}");
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SearchPanel(
                  origenController: _origenController,
                  destinoController: _destinoController,
                  origenFocusNode: _origenFocusNode,
                  destinoFocusNode: _destinoFocusNode,
                  origenCoordinates:
                      mapState.origin != null
                          ? local_point.Point_dart(
                            lat: mapState.origin!.lat.toDouble(),
                            lng: mapState.origin!.lng.toDouble(),
                          )
                          : null,
                  destinoCoordinates:
                      mapState.destination != null
                          ? local_point.Point_dart(
                            lat: mapState.destination!.lat.toDouble(),
                            lng: mapState.destination!.lng.toDouble(),
                          )
                          : null,
                  geocodingService: ref.read(geocodingServiceProvider),
                  isCalculatingRoute:
                      mapState.planningStatus == PlanningStatus.loading,
                  onOrigenSelected: (
                    local_point.Point_dart? point,
                    String? address,
                  ) {
                    _origenController.text = address ?? '';
                    if (point != null) {
                      final mapboxPosition = Position(point.lng, point.lat);
                      if (_mapboxService != null &&
                          _busTrackingController != null) {
                        mapNotifier.setOrigin(
                          mapboxPosition,
                          address,
                          _mapboxService!,
                          _busTrackingController!,
                        );
                      } else {
                        print(
                          "[_MapScreenState_ERROR] Servicios nulos al seleccionar origen.",
                        );
                      }
                    } else {
                      if (_mapboxService != null &&
                          _busTrackingController != null) {
                        mapNotifier.setOrigin(
                          null,
                          address,
                          _mapboxService!,
                          _busTrackingController!,
                        );
                      } else {
                        print(
                          "[_MapScreenState_ERROR] Servicios nulos al seleccionar origen (sin coordenadas).",
                        );
                      }
                    }
                    setState(() {});
                  },
                  onDestinoSelected: (
                    local_point.Point_dart? point,
                    String? address,
                  ) {
                    _destinoController.text = address ?? '';
                    if (point != null) {
                      final mapboxPosition = Position(point.lng, point.lat);
                      if (_mapboxService != null &&
                          _busTrackingController != null) {
                        mapNotifier.setDestination(
                          mapboxPosition,
                          address,
                          _mapboxService!,
                          _busTrackingController!,
                        );
                      } else {
                        print(
                          "[_MapScreenState_ERROR] Servicios nulos al seleccionar destino.",
                        );
                      }
                    } else {
                      if (_mapboxService != null &&
                          _busTrackingController != null) {
                        mapNotifier.setDestination(
                          null,
                          address,
                          _mapboxService!,
                          _busTrackingController!,
                        );
                      } else {
                        print(
                          "[_MapScreenState_ERROR] Servicios nulos al seleccionar destino (sin coordenadas).",
                        );
                      }
                    }
                    setState(() {});
                  },
                  onOrigenClear: _clearSearchFields,
                  onDestinoClear: _clearSearchFields,
                  onSwap: () {
                    if (_mapboxService != null &&
                        _busTrackingController != null) {
                      mapNotifier.swapOriginAndDestination(
                        _mapboxService!,
                        _busTrackingController!,
                      );
                    } else {
                      print(
                        "[_MapScreenState_ERROR] Servicios nulos al intercambiar O/D.",
                      );
                    }
                  },
                  onSearchRoute: () {
                    if (_mapboxService != null &&
                        _busTrackingController != null) {
                      mapNotifier.planRoute(
                        _mapboxService!,
                        _busTrackingController!,
                      );
                    } else {
                      print(
                        "[_MapScreenState_ERROR] Servicios nulos al intentar planificar ruta.",
                      );
                    }
                  },
                  initialExpandedState:
                      mapState.consolidatedItineraries.isEmpty &&
                      mapState.origin == null &&
                      mapState.destination == null,
                  onToggleExpansion: _onSearchPanelToggle,
                ),
                if (mapState.selectedConsolidatedItinerary != null &&
                    mapState.representativeItinerary != null &&
                    !mapState.showInstructionsPanel)
                  TripInstructions(
                    key: const ValueKey("tripInstructionsBar"),
                    currentRouteLegs:
                        mapState.representativeItinerary?.legs ?? [],
                    selectedLegIndex: mapState.currentLegIndex,
                    showCollapsedInstructionsBar:
                        !mapState.showInstructionsPanel &&
                        mapState.selectedConsolidatedItinerary != null &&
                        mapState.currentLegIndex != null &&
                        !(mapState.currentDisplayMode ==
                            MapDisplayMode.routeOverview),
                    origenControllerText: _origenController.text,
                    destinoControllerText: _destinoController.text,
                    isInOverviewMode:
                        (mapState.currentDisplayMode ==
                            MapDisplayMode.routeOverview),
                    onLegSelectedInBottomSheet: (index) {
                      if (_mapboxService != null &&
                          _busTrackingController != null) {
                        mapNotifier.setSelectedLegIndex(
                          index,
                          _mapboxService!,
                          _busTrackingController!,
                          isFromTap: true,
                        );
                      }
                    },
                    onNavigateToPreviousLeg: () {
                      if (mapState.currentLegIndex != null &&
                          mapState.currentLegIndex! > 0 &&
                          _mapboxService != null &&
                          _busTrackingController != null) {
                        mapNotifier.setSelectedLegIndex(
                          mapState.currentLegIndex! - 1,
                          _mapboxService!,
                          _busTrackingController!,
                        );
                      }
                    },
                    onNavigateToNextLeg: () {
                      if (mapState.currentLegIndex != null &&
                          mapState.representativeItinerary != null &&
                          mapState.currentLegIndex! <
                              mapState.representativeItinerary!.legs.length -
                                  1 &&
                          _mapboxService != null &&
                          _busTrackingController != null) {
                        mapNotifier.setSelectedLegIndex(
                          mapState.currentLegIndex! + 1,
                          _mapboxService!,
                          _busTrackingController!,
                        );
                      }
                    },
                    onExpandInstructionsTap: _onExpandInstructionsTap,
                    realtimeEtaMinutes:
                        mapState
                            .selectedConsolidatedItinerary
                            ?.representativeProcessedItinerary
                            ?.representativeFirstBusETAInfo
                            ?.minutesToArrival,
                    trackedBusLineShortNameForEta:
                        mapState
                            .selectedConsolidatedItinerary
                            ?.representativeProcessedItinerary
                            ?.representativeFirstBusETAInfo
                            ?.lineShortName,
                    isHighlightedBusReal:
                        mapState
                            .selectedConsolidatedItinerary
                            ?.representativeProcessedItinerary
                            ?.representativeFirstBusETAInfo
                            ?.isReal,
                  ),
              ],
            ),
          ),
          if (mapState.showInstructionsPanel &&
              mapState.selectedConsolidatedItinerary != null &&
              mapState.representativeItinerary != null &&
              _routeDisplayController != null)
            TripInstructionsSheet(
              key: const ValueKey("tripInstructionsSheet"),
              legs: mapState.representativeItinerary!.legs,
              origenControllerText:
                  mapState.originAddress ?? _origenController.text,
              destinoControllerText:
                  mapState.destinationAddress ?? _destinoController.text,
              routeDisplayController: _routeDisplayController!,
              onLegSelected: (int legIndex) {
                if (_mapboxService != null && _busTrackingController != null) {
                  mapNotifier.setSelectedLegIndex(
                    legIndex,
                    _mapboxService!,
                    _busTrackingController!,
                    isFromTap: true,
                  );
                } else {
                  print(
                    "[_MapScreenState_ERROR] Servicios nulos al seleccionar tramo desde TripInstructionsSheet.",
                  );
                }
              },
            ),
          if (mapState.planningStatus == PlanningStatus.loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
