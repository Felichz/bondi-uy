import 'package:flutter/material.dart';
import 'package:bondi_uy/utils/map_types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:bondi_uy/providers/app_providers.dart'; // Assuming providers are defined here
import 'package:bondi_uy/ui/widgets/app_search_panel.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart'; // Import AppUiState and related models, including Coordenada, EstadoSolicitud, FaseApp
import 'dart:convert'; // Import for JSON encoding
import 'package:flutter/services.dart'; // Required for rootBundle to load assets (placeholder)
import 'dart:typed_data'; // Required for ByteData (placeholder)
import 'dart:ui' as ui; // Import dart:ui para decodeImageFromList
// TODO: Importar widgets específicos de esta fase (Mapbox, SearchPanel adaptado, etc.)
// TODO: Importar el provider del AppUiState de la capa de lógica
// TODO: Importar la interfaz IAppLogic para llamar a las acciones
// Ejemplo: import 'package:bondi_uy/backend/providers/app_logic_provider.dart';

// Constants for Mapbox layers and sources (should ideally come from a config/domain layer)
const String STOPS_SOURCE_ID = 'stops-source';
const String STOPS_LAYER_ID = 'stops-layer';
const String STOP_ICON_IMAGE_ID = 'stop-icon'; // ID for the stop icon image

// Constants for Origin/Destination Markers
const String ORIGIN_MARKER_SOURCE_ID = 'origin-marker-source';
const String ORIGIN_MARKER_LAYER_ID = 'origin-marker-layer';
const String DESTINATION_MARKER_SOURCE_ID = 'destination-marker-source';
const String DESTINATION_MARKER_LAYER_ID = 'destination-marker-layer';
const String ORIGIN_ICON_IMAGE_ID =
    'origin-marker-icon'; // New ID for origin icon
const String DESTINATION_ICON_IMAGE_ID =
    'destination-marker-icon'; // New ID for destination icon

// TODO: Consider if the map controller should be managed by a provider or locally.
// For now, managing locally and passing to IAppLogic methods.

class InitialPhaseView extends ConsumerStatefulWidget {
  const InitialPhaseView({super.key});

  @override
  ConsumerState<InitialPhaseView> createState() => _InitialPhaseViewState();
}

class _InitialPhaseViewState extends ConsumerState<InitialPhaseView> {
  MapboxMap? mapboxMap;
  // Eliminados: PointAnnotationManager y PointAnnotation para origen y destino
  // PointAnnotationManager? _originAnnotationManager;
  // PointAnnotationManager? _destinationAnnotationManager;
  // PointAnnotation? _originAnnotation;
  // PointAnnotation? _destinationAnnotation;

  // Para asegurar que los íconos se cargan solo una vez
  bool _iconsLoaded = false;

  @override
  void initState() {
    super.initState();

    // Listener para reaccionar a los cambios en zoomTargetActual
    // Usamos listenManual para tener más control o si necesitamos cancelar la suscripción explícitamente.
    // Alternativamente, ref.listen dentro de build si el widget se reconstruye con frecuencia,
    // o un Consumer que envuelva solo la parte del mapa si es más aislado.
    // Para un listener a nivel de State, initState o didChangeDependencies es común.
    ref.listenManual(appUiStateProvider.select((s) => s.zoomTargetActual),
        (ZoomTarget? previousTarget, ZoomTarget? currentTarget) {
      final currentUiState = ref.read(appUiStateProvider);
      if (currentUiState.permitirZoomAutomaticoMapa &&
          currentTarget != null && currentTarget.tipo != ZoomTargetType.none) {
        print(
            "[_InitialPhaseViewState] Listener: Detected zoom target: ${currentTarget.tipo}");
        _performAutomaticZoom(currentTarget);
      }
    }, fireImmediately: true); // fireImmediately para manejar un target inicial si existe
  }

  @override
  void dispose() {
    // Ya no se necesitan limpiar managers de anotaciones para origen/destino
    super.dispose();
  }

  // Función mejorada para cargar íconos y obtener sus dimensiones
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
      print("[_InitialPhaseViewState] Loaded $STOP_ICON_IMAGE_ID");

      final MbxImage originImage = await _loadIconImageFromAsset(
        'origin_marker_icon.png',
      );
      await mapboxMap!.style.addStyleImage(
        ORIGIN_ICON_IMAGE_ID,
        1.0,
        originImage,
        false,
        [],
        [],
        null,
      );
      print("[_InitialPhaseViewState] Loaded $ORIGIN_ICON_IMAGE_ID");

      final MbxImage destinationImage = await _loadIconImageFromAsset(
        'destination_marker_icon.png',
      );
      await mapboxMap!.style.addStyleImage(
        DESTINATION_ICON_IMAGE_ID,
        1.0,
        destinationImage,
        false,
        [],
        [],
        null,
      );
      print("[_InitialPhaseViewState] Loaded $DESTINATION_ICON_IMAGE_ID");

      _iconsLoaded = true;
      print("[_InitialPhaseViewState] All icons loaded successfully.");
    } catch (e, s) {
      print("[_InitialPhaseViewState] Error loading map icons: $e");
      print(s);
      final appLogic = ref.read(appLogicProvider);
      appLogic.setErrorGlobal("Error al cargar íconos del mapa.");
    }
  }

  // Callback para cuando el estilo del mapa está cargado
  void _onStyleLoadedCallback() {
    // MapboxMap pasa StyleLoadedEventData, pero el código antiguo no lo usaba
    print(
      "[_InitialPhaseViewState] Map style loaded via onStyleLoadedListener.",
    );
    // await _loadMapIcons(); // Esto se llama ahora desde onMapCreated después de que el estilo carga
    // if (_iconsLoaded) {
    //   _updateMapElements(); // Esto también se podría mover o asegurar que se llame después de _loadMapIcons
    // }
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;

    // El estilo se carga implícitamente. Los íconos y fuentes deben cargarse DESPUÉS de que el estilo esté listo.
    // El listener onStyleLoaded es el mejor lugar, o un Future.delayed corto si onStyleLoaded no da el timing correcto para la inicialización de todo.
    // Por ahora, intentaremos cargarlos aquí, asumiendo que el estilo base ya está presente o se cargará inmediatamente.
    // Una mejor práctica es usar onStyleLoadedListener para esto.
    _loadMapIcons().then((_) {
      if (_iconsLoaded) {
        _updateMapElements(); // Mover la actualización inicial aquí
        // Informar a la lógica que el mapa está listo para cargar datos iniciales
        final appLogic = ref.read(appLogicProvider);
        mapboxMap.getCameraState().then((cameraState) {
          final center = Coordenada(
            latitud: cameraState.center.coordinates.lat.toDouble(),
            longitud: cameraState.center.coordinates.lng.toDouble(),
          );
          final zoom = cameraState.zoom.toDouble();
          // TODO: Necesitamos las esquinas del viewport para la carga inicial
          // Esto es un placeholder, la lógica real para obtener bounds debe ser implementada.
          // final bounds = await mapboxMap.coordinateBoundsForCamera(cameraState.toCameraOptions());
          // appLogic.cargarParadasInicialesDelViewport(center, zoom, bounds.southwest, bounds.northeast);
          appLogic
              .pantallaDeInicioCargada(); // O una acción más específica si es necesario
          print(
            "[_InitialPhaseViewState] Map created and initial icons loaded. Requesting initial stops.",
          );
        });
      }
    });

    // Eliminada la inicialización de PointAnnotationManager para origen y destino
    // mapboxMap.annotations.createPointAnnotationManager().then((manager) {
    //   _originAnnotationManager = manager;
    //   final appUiState = ref.read(appUiStateProvider);
    //   if (appUiState.puntoOrigenParaBusqueda != null) {
    //     _updateOriginMarker(
    //       appUiState.puntoOrigenParaBusqueda,
    //       appUiState.nombreLugarOrigenSeleccionado,
    //     );
    //   }
    // });
    // mapboxMap.annotations.createPointAnnotationManager().then((manager) {
    //   _destinationAnnotationManager = manager;
    //   final appUiState = ref.read(appUiStateProvider);
    //   if (appUiState.puntoDestinoParaBusqueda != null) {
    //     _updateDestinationMarker(
    //       appUiState.puntoDestinoParaBusqueda,
    //       appUiState.nombreLugarDestinoSeleccionado,
    //     );
    //   }
    // });

    // Ya no se usa subscribe, se usará onStyleLoadedListener en el widget MapboxMap
    // mapboxMap.subscribe(_onStyleLoadedCallback, [
    // MapEvents.styleLoaded,
    // ]);
  }

  void _updateMapElements() {
    if (!_iconsLoaded || mapboxMap == null) return;

    final appUiState = ref.read(appUiStateProvider);
    _displayStops(appUiState.datosFaseInicial?.paradasVisiblesEnMapa ?? []);

    // Llamadas a las nuevas funciones de actualización de capas de origen/destino
    _updateOriginMarkerLayer(
      appUiState.puntoOrigenParaBusqueda,
      appUiState.nombreLugarOrigenSeleccionado,
    );
    _updateDestinationMarkerLayer(
      appUiState.puntoDestinoParaBusqueda,
      appUiState.nombreLugarDestinoSeleccionado,
    );
  }

  void _onMapLoadError(MapLoadingErrorEventData data) {
    final errorMessage = "Error cargando el mapa: ${data.message}";
    print("[_InitialPhaseViewState] $errorMessage");
    ref.read(appLogicProvider).setErrorGlobal(errorMessage);
  }

  void _onMapTapListener(MapContentGestureContext context) {
    final appLogic = ref.read(appLogicProvider);
    if (mapboxMap == null) return;

    // El código antiguo usaba context.touchPosition que era ScreenCoordinate
    // MapContentGestureContext en algunas versiones tiene touchPosition o screenPosition
    final ScreenCoordinate touchPosition =
        context.touchPosition; // Intentar con touchPosition

    mapboxMap!
        .queryRenderedFeatures(
          RenderedQueryGeometry.fromScreenCoordinate(
            touchPosition,
          ), // Usar la ScreenCoordinate correcta
          RenderedQueryOptions(layerIds: [STOPS_LAYER_ID], filter: null),
        )
        .then((queriedFeaturesNullable) {
          final List<QueriedRenderedFeature> features =
              queriedFeaturesNullable
                  .whereType<QueriedRenderedFeature>()
                  .toList();

          if (features.isNotEmpty) {
            // El código antiguo iteraba, pero usualmente solo nos interesa el primer feature tocado para paradas.
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
          // Si no se encontró una parada o hubo un error en las propiedades.
          print(
            "[_InitialPhaseViewState] Tapped on map, no stop identified or error in query. Deselecting.",
          );
          appLogic.usuarioDeseleccionoInformacionDeParada();
        })
        .catchError((error) {
          print(
            "[_InitialPhaseViewState] Error in queryRenderedFeatures: $error",
          );
          appLogic.usuarioDeseleccionoInformacionDeParada();
        });
  }

  // Nueva función para mostrar paradas usando GeoJSON y SymbolLayer
  Future<void> _displayStops(List<InfoParadaEnMapa> stops) async {
    if (mapboxMap == null || !_iconsLoaded) return;

    // Crear el FeatureCollection GeoJSON
    final features =
        stops.map((stop) {
          return {
            'type': 'Feature',
            'id': stop.idParada, // Usar idParada como ID de la feature
            'geometry': {
              'type': 'Point',
              'coordinates': [stop.posicion.longitud, stop.posicion.latitud],
            },
            'properties': {
              'idParada': stop.idParada,
              'nombre': stop.nombre,
              // Añadir más propiedades si son necesarias para el popup o interacciones
            },
          };
        }).toList();

    final geoJsonSource = {'type': 'FeatureCollection', 'features': features};

    try {
      // Intentar obtener la fuente existente, si no, añadirla
      final existingSource = await mapboxMap!.style.getSource(STOPS_SOURCE_ID);
      if (existingSource == null) {
        await mapboxMap!.style.addSource(
          GeoJsonSource(id: STOPS_SOURCE_ID, data: json.encode(geoJsonSource)),
        );
      } else {
        // Si la fuente existe, actualizar sus datos
        (existingSource as GeoJsonSource).updateGeoJSON(
          json.encode(geoJsonSource),
        );
      }

      // Intentar obtener la capa existente, si no, añadirla
      final existingLayer = await mapboxMap!.style.getLayer(STOPS_LAYER_ID);
      if (existingLayer == null) {
        await mapboxMap!.style.addLayer(
          SymbolLayer(
            id: STOPS_LAYER_ID,
            sourceId: STOPS_SOURCE_ID,
            iconImage: STOP_ICON_IMAGE_ID,
            iconAllowOverlap: true,
            iconSize: 0.5,
            textOffset: [0.0, 1.5],
            textSize: 10.0,
            textColor: Colors.black.value,
            textAllowOverlap: false,
            textHaloColor: Colors.white.value,
            textHaloWidth: 1.0,
          ),
        );
      }
      // Si la capa ya existe, no es necesario hacer nada más a menos que sus propiedades de estilo necesiten cambiar dinámicamente
      // (lo cual no es el caso aquí, ya que el estilo es fijo).
      print(
        "[_InitialPhaseViewState] Stops displayed/updated. Count: ${stops.length}",
      );
    } catch (e, s) {
      print("[_InitialPhaseViewState] Error displaying stops: $e");
      print(s);
      ref
          .read(appLogicProvider)
          .setErrorGlobal("Error al mostrar paradas en el mapa.");
    }
  }

  // Nueva función genérica para actualizar capas de un solo punto (origen/destino)
  Future<void> _updateSinglePointLayer({
    required String sourceId,
    required String layerId,
    required String iconImageId,
    Coordenada? coordenada,
    String? textField,
    Color? textColor,
    required String logContext,
  }) async {
    if (mapboxMap == null || !_iconsLoaded) return;

    try {
      final existingLayer = await mapboxMap!.style.getLayer(layerId);
      final existingSource = await mapboxMap!.style.getSource(sourceId);

      if (coordenada == null) {
        if (existingLayer != null) {
          await mapboxMap!.style.removeStyleLayer(layerId);
          print(
            "[_InitialPhaseViewState] $logContext layer '$layerId' removed.",
          );
        }
        if (existingSource != null) {
          await mapboxMap!.style.removeStyleSource(sourceId);
          print(
            "[_InitialPhaseViewState] $logContext source '$sourceId' removed.",
          );
        }
        return;
      }

      final geoJsonFeature = {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [coordenada.longitud, coordenada.latitud],
        },
        'properties': {
          if (textField != null) 'name': textField,
          // Podríamos añadir más propiedades si fueran necesarias para el estilo o popups
        },
      };
      final geoJsonSourceData = {
        'type': 'FeatureCollection',
        'features': [geoJsonFeature],
      };
      final geoJsonDataString = json.encode(geoJsonSourceData);

      if (existingSource == null) {
        await mapboxMap!.style.addSource(
          GeoJsonSource(id: sourceId, data: geoJsonDataString),
        );
        print("[_InitialPhaseViewState] $logContext source '$sourceId' added.");
      } else {
        (existingSource as GeoJsonSource).updateGeoJSON(geoJsonDataString);
        print(
          "[_InitialPhaseViewState] $logContext source '$sourceId' updated.",
        );
      }

      if (existingLayer == null) {
        await mapboxMap!.style.addLayer(
          SymbolLayer(
            id: layerId,
            sourceId: sourceId,
            iconImage: iconImageId,
            iconAllowOverlap: true,
            iconSize: 1.0,
            textField: textField, // Usar directamente el textField provisto
            textColor: (textColor ?? Colors.black).value,
            textOffset: [0.0, -2.5], // Posicionar texto arriba del ícono
            textSize: 12.0,
            textHaloColor: Colors.white.value,
            textHaloWidth: 1.0,
            iconIgnorePlacement: true, // Para asegurar que se muestre
            textIgnorePlacement: true, // Para asegurar que se muestre el texto
          ),
        );
        print("[_InitialPhaseViewState] $logContext layer '$layerId' added.");
      } else {
        // Si la capa existe, actualizar sus propiedades si es necesario (ej. textField si cambia dinámicamente)
        // Por ahora, el cambio de textField se maneja actualizando la fuente y la capa lo recoge.
        // Si quisiéramos cambiar el iconImage dinámicamente, lo haríamos aquí con setLayerProperty.
        print(
          "[_InitialPhaseViewState] $logContext layer '$layerId' already exists. Properties might be updated via source.",
        );
      }
    } catch (e, s) {
      print(
        "[_InitialPhaseViewState] Error updating $logContext layer '$layerId': $e",
      );
      print(s);
      ref
          .read(appLogicProvider)
          .setErrorGlobal("Error al actualizar marcador de $logContext.");
    }
  }

  // Antigua _updateOriginMarker ahora llama a _updateSinglePointLayer
  Future<void> _updateOriginMarkerLayer(
    Coordenada? origen,
    String? nombreLugar,
  ) async {
    await _updateSinglePointLayer(
      sourceId: ORIGIN_MARKER_SOURCE_ID,
      layerId: ORIGIN_MARKER_LAYER_ID,
      iconImageId: ORIGIN_ICON_IMAGE_ID,
      coordenada: origen,
      textField: nombreLugar ?? (origen != null ? "Origen" : null),
      textColor: Colors.blue,
      logContext: "Origin",
    );
  }

  // Antigua _updateDestinationMarker ahora llama a _updateSinglePointLayer
  Future<void> _updateDestinationMarkerLayer(
    Coordenada? destino,
    String? nombreLugar,
  ) async {
    await _updateSinglePointLayer(
      sourceId: DESTINATION_MARKER_SOURCE_ID,
      layerId: DESTINATION_MARKER_LAYER_ID,
      iconImageId: DESTINATION_ICON_IMAGE_ID,
      coordenada: destino,
      textField: nombreLugar ?? (destino != null ? "Destino" : null),
      textColor: Colors.green,
      logContext: "Destination",
    );
  }

  // Implementar _onMapIdleListener
  void _onMapIdleListener(MapIdleEventData data) {
    if (mapboxMap == null) return;
    final appLogic = ref.read(appLogicProvider);

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
          // TODO: Determinar si la interacción fue manual.
          // Por ahora, se notifica siempre. Se necesita lógica de userMapInteraction.
          appLogic.usuarioMovioMapaManualente(center, zoom);
          appLogic.setPermitirZoomAutomaticoMapa(false);
        })
        .catchError((e) {
          print(
            "[_InitialPhaseViewState] Error getting camera state on idle: $e",
          );
        });
  }

  // Implementar _zoomToFitPoints (Placeholder, necesita MapboxService o lógica de cámara)
  Future<void> _performAutomaticZoom(ZoomTarget target) async {
    if (!mounted || mapboxMap == null) return;

    print("[_InitialPhaseViewState] Performing automatic zoom for target: ${target.tipo}");

    List<Coordenada>? pointsToZoom = [];

    switch (target.tipo) {
      case ZoomTargetType.paradaEspecifica:
        if (target.puntoUnico != null) {
          pointsToZoom.add(target.puntoUnico!);
        }
        break;
      case ZoomTargetType.puntosOrigenDestino:
        if (target.puntos != null && target.puntos!.isNotEmpty) {
          pointsToZoom.addAll(target.puntos!.map((point) => Coordenada(latitud: point['latitud']!, longitud: point['longitud']!)));
        }
        break;
      case ZoomTargetType.none:
      case ZoomTargetType.rutaCompleta: // No manejado en InitialPhaseView
      case ZoomTargetType.bounds: // No manejado en InitialPhaseView
      case ZoomTargetType.ubicacionUsuario: // No manejado aún
        print(
            "[_InitialPhaseViewState] Zoom target type ${target.tipo} not handled or no points.");
        // Si no hay puntos para este tipo de target, o el tipo no es para esta vista,
        // igualmente seteamos permitirZoomAutomaticoMapa a false para no quedar en un estado de espera.
        ref.read(appLogicProvider).setPermitirZoomAutomaticoMapa(false);
        return;
      default:
        print("[_InitialPhaseViewState] Unknown zoom target type: ${target.tipo}");
        ref.read(appLogicProvider).setPermitirZoomAutomaticoMapa(false);
        return;
    }

    if (pointsToZoom.isNotEmpty) {
      // Llamamos a la función existente que ya verifica 'permitirZoomAutomaticoMapa'
      // pero nuestra lógica de control está en este wrapper.
      // _zoomToFitPoints ya tiene la lógica de animación.
      await _zoomToFitPoints(pointsToZoom);
    } else {
      print("[_InitialPhaseViewState] No valid points to zoom to for target: ${target.tipo}");
    }

    // Después de intentar el zoom (o si no había puntos válidos para el target),
    // desactivar el permiso para futuros zooms automáticos hasta que la lógica lo vuelva a permitir.
    // Esto es crucial para que el usuario pueda interactuar manualmente después.
    // Añadimos un pequeño delay para asegurar que la animación del mapa pueda iniciar/completar visualmente
    // antes de que potencialmente _onMapIdleListener se dispare y lo setee a false también.
    await Future.delayed(const Duration(milliseconds: 100)); // Ajustar si es necesario
    if (mounted) {
      ref.read(appLogicProvider).setPermitirZoomAutomaticoMapa(false);
      print("[_InitialPhaseViewState] permitirZoomAutomaticoMapa set to false after zoom attempt.");
    }
  }

  Future<void> _zoomToFitPoints(List<Coordenada> points) async {
    if (mapboxMap == null ||
        points.isEmpty ||
        !ref.read(appUiStateProvider).permitirZoomAutomaticoMapa)
      return;

    print(
      "[_InitialPhaseViewState] Zooming to fit points (permitido: ${ref.read(appUiStateProvider).permitirZoomAutomaticoMapa}): $points",
    );

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
        padding: padding, // Se puede aplicar padding también a un solo punto
        zoom: 15.0,
      );
      await mapboxMap!.flyTo(cameraOptions, animationOptions);
    } else {
      // Para múltiples posiciones, Mapbox espera una lista de Point para cameraForCoordinates
      final List<Point> mapboxPoints =
          points
              .map((p) => Point(coordinates: Position(p.longitud, p.latitud)))
              .toList();

      try {
        final CameraOptions cameraOptions = await mapboxMap!
            .cameraForCoordinates(
              mapboxPoints, // Usar la lista de Point
              padding,
              null, // bearing
              null, // pitch
            );
        await mapboxMap!.flyTo(cameraOptions, animationOptions);
      } catch (e, s) {
        print(
          "[_InitialPhaseViewState] Error in cameraForCoordinates or flying to points: $e",
        );
        print(s);
        // Fallback si falla el cálculo de cameraForCoordinates: volar al primer punto.
        // Esto es menos ideal que el fallback anterior que volaba al centro de los puntos si el cálculo de bounds fallaba.
        // Pero sin bounds, volar al primer punto es un fallback simple.
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

  @override
  Widget build(BuildContext context) {
    // Escuchar cambios en AppUiState para actualizar el mapa
    ref.listen<AppUiState>(appUiStateProvider, (previous, next) {
      if (mapboxMap == null || !_iconsLoaded) return;

      if (previous?.datosFaseInicial?.paradasVisiblesEnMapa !=
          next.datosFaseInicial?.paradasVisiblesEnMapa) {
        _displayStops(next.datosFaseInicial?.paradasVisiblesEnMapa ?? []);
      }

      List<Coordenada> pointsToZoom = [];

      bool originChanged = false;
      if (previous?.puntoOrigenParaBusqueda != next.puntoOrigenParaBusqueda ||
          previous?.nombreLugarOrigenSeleccionado !=
              next.nombreLugarOrigenSeleccionado) {
        _updateOriginMarkerLayer(
          next.puntoOrigenParaBusqueda,
          next.nombreLugarOrigenSeleccionado,
        );
        originChanged = true;
      }
      if (next.puntoOrigenParaBusqueda != null) {
        pointsToZoom.add(next.puntoOrigenParaBusqueda!);
      }

      bool destinationChanged = false;
      if (previous?.puntoDestinoParaBusqueda != next.puntoDestinoParaBusqueda ||
          previous?.nombreLugarDestinoSeleccionado !=
              next.nombreLugarDestinoSeleccionado) {
        _updateDestinationMarkerLayer(
          next.puntoDestinoParaBusqueda,
          next.nombreLugarDestinoSeleccionado,
        );
        destinationChanged = true;
      }
      if (next.puntoDestinoParaBusqueda != null) {
        pointsToZoom.add(next.puntoDestinoParaBusqueda!);
      }

      if ((originChanged || destinationChanged) && pointsToZoom.isNotEmpty) {
        _zoomToFitPoints(pointsToZoom);
      }

      if (previous?.infoParadaConsultada != next.infoParadaConsultada) {
        if (next.infoParadaConsultada != null) {
          _showStopInfoModal(context, next.infoParadaConsultada!);
        } else {
          // Si el modal está abierto y la info se vuelve null, cerrarlo.
          // Navigator.canPop(context) podría ser útil aquí si el modal es una ruta.
          // Por ahora, asumimos que el usuario lo cierra o la lógica lo maneja.
        }
      }
    });

    final appUiState = ref.watch(appUiStateProvider);

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
        const Positioned(top: 0, left: 0, right: 0, child: AppSearchPanel()),
      ],
    );
  }

  void _showStopInfoModal(
    BuildContext context,
    InfoDetalladaParada infoParada,
  ) {
    final appLogic = ref.read(appLogicProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que el modal sea más alto
      builder: (BuildContext bc) {
        return DraggableScrollableSheet(
          expand: false, // No expandir completamente por defecto
          initialChildSize: 0.4, // Altura inicial (40% de la pantalla)
          minChildSize: 0.25, // Altura mínima
          maxChildSize: 0.75, // Altura máxima
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).cardColor, // Usar color de fondo del tema
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20.0),
                  topRight: Radius.circular(20.0),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Handle para arrastrar
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
                          Navigator.pop(context); // Cierra el modal
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
                              controller:
                                  scrollController, // Importante para DraggableScrollableSheet
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
                                    // trailing: eta.posicionBus != null ? Icon(Icons.location_on_outlined) : null, // Opcional: mostrar icono si hay pos bus
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      // Esta llamada es opcional, si el cierre del modal por otros medios (ej. swipe down)
      // no es capturado por el onPressed del botón de cierre.
      // Si el usuario cierra el modal haciendo swipe hacia abajo y el estado de infoParadaConsultada
      // no se limpia en la lógica, este whenComplete podría ser un lugar para llamar a
      // appLogic.usuarioDeseleccionoInformacionDeParada(), PERO hay que tener cuidado de no llamarlo
      // dos veces si ya se llamó en el IconButton.
      // Por ahora, lo comentamos para evitar doble llamada.
      // if (ref.read(appUiStateProvider).infoParadaConsultada != null) {
      //   // appLogic.usuarioDeseleccionoInformacionDeParada();
      // }
    });
  }
}
