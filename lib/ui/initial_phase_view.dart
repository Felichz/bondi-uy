import 'package:flutter/material.dart';
import 'package:bondi_uy/utils/map_types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:bondi_uy/ui/widgets/app_search_panel.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:bondi_uy/backend/providers/app_logic_provider.dart';

// Constants for Mapbox layers and sources (based on old project)
const String STOPS_SOURCE_ID = 'stops-source';
const String STOPS_LAYER_ID = 'stops-layer';
const String BUS_ICON_IMAGE_ID =
    'bus-icon'; // Use incoming_bus.png for realtime buses
const String STOP_ICON_IMAGE_ID =
    'stop-icon'; // Use stop_icon.png for bus stops

class InitialPhaseView extends ConsumerStatefulWidget {
  const InitialPhaseView({super.key});

  @override
  ConsumerState<InitialPhaseView> createState() => _InitialPhaseViewState();
}

class _InitialPhaseViewState extends ConsumerState<InitialPhaseView> {
  MapboxMap? mapboxMap;
  bool _iconsLoaded = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
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
    if (mapboxMap == null || _iconsLoaded) return;
    print("[_InitialPhaseViewState] Attempting to load map icons...");
    try {
      // Use incoming_bus.png for all bus-related icons (realtime buses)
      final MbxImage busImage = await _loadIconImageFromAsset(
        'incoming_bus.png',
      );
      await mapboxMap!.style.addStyleImage(
        BUS_ICON_IMAGE_ID,
        1.0,
        busImage,
        false,
        [],
        [],
        null,
      );
      print(
        "[_InitialPhaseViewState] Loaded $BUS_ICON_IMAGE_ID from incoming_bus.png",
      );

      // Use stop_icon.png for bus stops
      final MbxImage stopImage = await _loadIconImageFromAsset('stop_icon.png');
      await mapboxMap!.style.addStyleImage(
        STOP_ICON_IMAGE_ID,
        1.0,
        stopImage,
        false,
        [],
        [],
        null,
      );
      print(
        "[_InitialPhaseViewState] Loaded $STOP_ICON_IMAGE_ID from stop_icon.png",
      );

      _iconsLoaded = true;
      print("[_InitialPhaseViewState] All icons loaded successfully.");
    } catch (e, s) {
      print("[_InitialPhaseViewState] Error loading map icons: $e");
      print(s);
      final appLogic = ref.read(appLogicProvider.notifier);
      // appLogic.setErrorGlobal("Error al cargar íconos del mapa."); // TODO: Implement if needed
    }
  }

  void _onStyleLoadedCallback() {
    print(
      "[_InitialPhaseViewState] Map style loaded via onStyleLoadedListener.",
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;

    _loadMapIcons().then((_) {
      if (_iconsLoaded) {
        _updateMapElements();
        final appLogic = ref.read(appLogicProvider.notifier);
        mapboxMap.getCameraState().then((cameraState) {
          final center = Coordenada(
            latitud: cameraState.center.coordinates.lat.toDouble(),
            longitud: cameraState.center.coordinates.lng.toDouble(),
          );
          final zoom = cameraState.zoom.toDouble();
          appLogic.pantallaDeInicioCargada();
          print("[_InitialPhaseViewState] Map created and icons loaded.");
        });
      }
    });
  }

  void _updateMapElements() {
    if (!_iconsLoaded || mapboxMap == null) return;

    final appUiState = ref.read(appLogicProvider);
    _displayStops(appUiState.datosFaseInicial?.paradasVisiblesEnMapa ?? []);
  }

  void _onMapLoadError(MapLoadingErrorEventData data) {
    final errorMessage = "Error cargando el mapa: ${data.message}";
    print("[_InitialPhaseViewState] $errorMessage");
    // ref.read(appLogicProvider.notifier).setErrorGlobal(errorMessage); // TODO: Implement if needed
  }

  void _onMapTapListener(MapContentGestureContext context) {
    final appLogic = ref.read(appLogicProvider.notifier);
    if (mapboxMap == null) return;

    final ScreenCoordinate touchPosition = context.touchPosition;

    mapboxMap!
        .queryRenderedFeatures(
          RenderedQueryGeometry.fromScreenCoordinate(touchPosition),
          RenderedQueryOptions(layerIds: [STOPS_LAYER_ID], filter: null),
        )
        .then((queriedFeaturesNullable) {
          final List<QueriedRenderedFeature> features =
              queriedFeaturesNullable
                  .whereType<QueriedRenderedFeature>()
                  .toList();

          if (features.isNotEmpty) {
            final queriedFeature = features.first;
            final featureProperties =
                queriedFeature.queriedFeature.feature['properties'];

            if (featureProperties != null && featureProperties is Map) {
              final stopId = featureProperties['idParada'] as String?;
              if (stopId != null) {
                print("[_InitialPhaseViewState] Tapped on stop ID: $stopId");
                appLogic.usuarioHizoTapEnParadaDelMapa(stopId);
                return;
              }
            }
          }
          print("[_InitialPhaseViewState] Tapped on map, no stop identified.");
          appLogic.usuarioDeseleccionoInformacionDeParada();
        })
        .catchError((error) {
          print(
            "[_InitialPhaseViewState] Error in queryRenderedFeatures: $error",
          );
          appLogic.usuarioDeseleccionoInformacionDeParada();
        });
  }

  Future<void> _displayStops(List<InfoParadaEnMapa> stops) async {
    if (mapboxMap == null || !_iconsLoaded) return;

    // Si no hay paradas para mostrar, limpiar la capa si existe
    if (stops.isEmpty) {
      try {
        final existingLayer = await mapboxMap!.style.getLayer(STOPS_LAYER_ID);
        if (existingLayer != null) {
          await mapboxMap!.style.removeStyleLayer(STOPS_LAYER_ID);
        }
        final existingSource = await mapboxMap!.style.getSource(
          STOPS_SOURCE_ID,
        );
        if (existingSource != null) {
          await mapboxMap!.style.removeStyleSource(STOPS_SOURCE_ID);
        }
      } catch (e) {
        // Ignorar errores al limpiar capas que no existen
        print("[_InitialPhaseViewState] No existing layers to clean: $e");
      }
      return;
    }

    final features =
        stops.map((stop) {
          return {
            'type': 'Feature',
            'id': stop.idParada,
            'geometry': {
              'type': 'Point',
              'coordinates': [stop.posicion.longitud, stop.posicion.latitud],
            },
            'properties': {'idParada': stop.idParada, 'nombre': stop.nombre},
          };
        }).toList();

    final geoJsonSource = {'type': 'FeatureCollection', 'features': features};

    try {
      // Verificar si la fuente existe de manera segura
      bool sourceExists = false;
      try {
        final existingSource = await mapboxMap!.style.getSource(
          STOPS_SOURCE_ID,
        );
        sourceExists = existingSource != null;
      } catch (e) {
        // La fuente no existe, está bien
        sourceExists = false;
      }

      if (!sourceExists) {
        // Crear nueva fuente
        await mapboxMap!.style.addSource(
          GeoJsonSource(id: STOPS_SOURCE_ID, data: json.encode(geoJsonSource)),
        );
        print("[_InitialPhaseViewState] Created new stops source");
      } else {
        // Actualizar fuente existente
        final existingSource = await mapboxMap!.style.getSource(
          STOPS_SOURCE_ID,
        );
        (existingSource as GeoJsonSource).updateGeoJSON(
          json.encode(geoJsonSource),
        );
        print("[_InitialPhaseViewState] Updated existing stops source");
      }

      // Verificar si la capa existe de manera segura
      bool layerExists = false;
      try {
        final existingLayer = await mapboxMap!.style.getLayer(STOPS_LAYER_ID);
        layerExists = existingLayer != null;
      } catch (e) {
        // La capa no existe, está bien
        layerExists = false;
      }

      if (!layerExists) {
        await mapboxMap!.style.addLayer(
          SymbolLayer(
            id: STOPS_LAYER_ID,
            sourceId: STOPS_SOURCE_ID,
            iconImage: STOP_ICON_IMAGE_ID, // Use the proper stop icon
            iconAllowOverlap: true,
            iconSize: 0.4, // Same size as old project (0.4)
            minZoom: 13.5, // Only show stops at zoom level 13.5 and above
            textOffset: [0.0, 1.5],
            textSize: 10.0,
            textColor: Colors.black.value,
            textAllowOverlap: false,
            textHaloColor: Colors.white.value,
            textHaloWidth: 1.0,
          ),
        );
        print("[_InitialPhaseViewState] Created new stops layer");
      }

      print(
        "[_InitialPhaseViewState] Stops displayed/updated successfully. Count: ${stops.length}",
      );
    } catch (e, s) {
      print("[_InitialPhaseViewState] Error displaying stops: $e");
      print(s);
      ref
          .read(appLogicProvider.notifier)
          .setErrorGlobal("Error al mostrar paradas en el mapa.");
    }
  }

  void _onMapIdleListener(MapIdleEventData data) {
    if (mapboxMap == null) return;
    final appLogic = ref.read(appLogicProvider.notifier);

    mapboxMap!
        .getCameraState()
        .then((cameraState) {
          final center = Coordenada(
            latitud: cameraState.center.coordinates.lat.toDouble(),
            longitud: cameraState.center.coordinates.lng.toDouble(),
          );
          final zoom = cameraState.zoom.toDouble();
          print(
            "[_InitialPhaseViewState] Map idle. Center: $center, Zoom: $zoom",
          );
          appLogic.usuarioMovioMapaManualente(center, zoom);
        })
        .catchError((e) {
          print(
            "[_InitialPhaseViewState] Error getting camera state on idle: $e",
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppUiState>(appLogicProvider, (previous, next) {
      if (mapboxMap == null || !_iconsLoaded) return;

      if (previous?.datosFaseInicial?.paradasVisiblesEnMapa !=
          next.datosFaseInicial?.paradasVisiblesEnMapa) {
        _displayStops(next.datosFaseInicial?.paradasVisiblesEnMapa ?? []);
      }

      // Handle zoom when origin/destination change (coordinates only, no visual markers)
      List<Coordenada> pointsToZoom = [];
      bool shouldZoom = false;

      // GRANDMA FIRST: Sin punto de origen manual, solo destino
      // El origen siempre es la ubicación actual del usuario
      if (next.ubicacionActualUsuario != null) {
        pointsToZoom.add(next.ubicacionActualUsuario!);
      }

      if (previous?.puntoDestinoParaBusqueda != next.puntoDestinoParaBusqueda ||
          previous?.nombreLugarDestinoSeleccionado !=
              next.nombreLugarDestinoSeleccionado) {
        shouldZoom = true;
      }
      if (next.puntoDestinoParaBusqueda != null) {
        pointsToZoom.add(next.puntoDestinoParaBusqueda!);
      }

      if (shouldZoom && pointsToZoom.isNotEmpty) {
        _zoomToFitPoints(pointsToZoom);
      }

      if (previous?.infoParadaConsultada != next.infoParadaConsultada) {
        if (next.infoParadaConsultada != null) {
          _showStopInfoModal(context, next.infoParadaConsultada!);
        }
      }
    });

    return Stack(
      children: [
        MapWidget(
          key: const ValueKey("initialPhaseMap"),
          onMapCreated: _onMapCreated,
          cameraOptions: CameraOptions(
            center: Point(coordinates: Position(-56.1645, -34.9011)),
            zoom: 12.0,
          ),
          onMapLoadErrorListener: _onMapLoadError,
          onStyleLoadedListener: (_) {
            print(
              "[_InitialPhaseViewState] Style loaded (onStyleLoadedListener).",
            );
            _onStyleLoadedCallback();
            _loadMapIcons().then((_) {
              if (_iconsLoaded) {
                _updateMapElements();
              }
            });
          },
          onMapIdleListener: _onMapIdleListener,
          onTapListener: _onMapTapListener,
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 10,
          right: 10,
          child: const AppSearchPanel(),
        ),
      ],
    );
  }

  void _showStopInfoModal(
    BuildContext context,
    InfoDetalladaParada infoParada,
  ) {
    final appLogic = ref.read(appLogicProvider.notifier);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext bc) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.4,
            minChildSize: 0.25,
            maxChildSize: 0.75,
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    topRight: Radius.circular(20.0),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            infoParada.nombreParada,
                            style: Theme.of(context).textTheme.titleLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            Navigator.pop(context);
                            appLogic.usuarioDeseleccionoInformacionDeParada();
                          },
                        ),
                      ],
                    ),
                    Text(
                      "Parada ID: ${infoParada.idParada}",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    if (infoParada.lineasQuePasan.isNotEmpty) ...[
                      Text(
                        "Líneas que pasan:",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Wrap(
                        spacing: 8.0,
                        children:
                            infoParada.lineasQuePasan
                                .map((linea) => Chip(label: Text(linea)))
                                .toList(),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      "Próximas llegadas (ETAs):",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Expanded(
                      child:
                          infoParada.etas.isEmpty
                              ? const Center(
                                child: Text(
                                  "No hay ETAs disponibles en este momento.",
                                ),
                              )
                              : ListView.builder(
                                controller: scrollController,
                                itemCount: infoParada.etas.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final eta = infoParada.etas[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4.0,
                                    ),
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.directions_bus,
                                        color:
                                            eta.esTiempoReal
                                                ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                                : Colors.grey,
                                      ),
                                      title: Text(
                                        "Línea ${eta.linea}" +
                                            (eta.destino != null
                                                ? " (dir. ${eta.destino})"
                                                : ""),
                                      ),
                                      subtitle: Text(
                                        "${eta.minutosParaLlegada} min" +
                                            (eta.esTiempoReal
                                                ? " (tiempo real)"
                                                : " (programado)"),
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _zoomToFitPoints(List<Coordenada> points) async {
    if (mapboxMap == null || points.isEmpty) return;

    print("[_InitialPhaseViewState] Zooming to fit points: $points");

    final MbxEdgeInsets padding = MbxEdgeInsets(
      top: 50.0,
      left: 50.0,
      bottom: 50.0,
      right: 50.0,
    );
    final MapAnimationOptions animationOptions = MapAnimationOptions(
      duration: 1500,
      startDelay: 0,
    );

    if (points.length == 1) {
      final CameraOptions cameraOptions = CameraOptions(
        center: Point(
          coordinates: Position(points.first.longitud, points.first.latitud),
        ),
        padding: padding,
        zoom: 15.0,
      );
      await mapboxMap!.flyTo(cameraOptions, animationOptions);
    } else {
      final List<Point> mapboxPoints =
          points
              .map((p) => Point(coordinates: Position(p.longitud, p.latitud)))
              .toList();

      try {
        final CameraOptions cameraOptions = await mapboxMap!
            .cameraForCoordinates(mapboxPoints, padding, null, null);
        await mapboxMap!.flyTo(cameraOptions, animationOptions);
      } catch (e, s) {
        print("[_InitialPhaseViewState] Error in cameraForCoordinates: $e");
        print(s);
        final CameraOptions fallbackCameraOptions = CameraOptions(
          center: Point(
            coordinates: Position(points.first.longitud, points.first.latitud),
          ),
          padding: padding,
          zoom: 14.0,
        );
        await mapboxMap!.flyTo(fallbackCameraOptions, animationOptions);
      }
    }
  }
}
