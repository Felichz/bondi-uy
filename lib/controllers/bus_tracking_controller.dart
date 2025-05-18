import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:bondi_uy/models/route_leg.dart';
import 'package:bondi_uy/services/mapbox_service.dart';
import 'package:bondi_uy/providers/map_notifier.dart';
import 'package:bondi_uy/providers/service_providers.dart';
import 'package:bondi_uy/models/point_dart.dart' as models;
import 'package:bondi_uy/utils/geometry_utils.dart' as geometry_utils;
import 'package:flutter/material.dart'; // Para Colors
import '../models/bus_arrival_info.dart';
import 'package:collection/collection.dart';
import '../services/eta_fetcher_service.dart'; // IMPORTAR ETAFetcherService

class BusTrackingController {
  final WidgetRef _ref;
  final MapboxService _mapboxService;
  MapboxMap? get _mapboxMap => _mapboxService.mapboxMap;

  Map<String, List<Position>> _shapeGeometries = {};
  bool _shapesLoaded = false;

  // Datos del bus/tramo actualmente rastreado
  RouteLeg? _currentTrackedBusLeg;
  BusArrivalInfo? _currentTrackedETAInfo;
  String? _currentTrackingStopId;
  String? _currentTrackingLineShortName;

  List<Position>? _currentFullShapeForBusLeg;
  int? _originStopIndexOnShape;
  int? _destinationStopIndexOnShape;
  String? _currentFullLineShapeId;

  Timer? _realtimeBusTimer;
  // Timer? _busSimulationTimer; // Simulación no se usa activamente por ahora

  static const String REALTIME_BUS_SOURCE_ID = "realtime-bus-source";
  static const String REALTIME_BUS_LAYER_ID = "realtime-bus-layer";
  static const String FULL_BUS_LINE_SHAPE_SOURCE_ID_PREFIX =
      "full-bus-line-shape-source-";
  static const String FULL_BUS_LINE_SHAPE_LAYER_ID_PREFIX =
      "full-bus-line-shape-layer-";
  // static const String DEBUG_REAL_BUS_POSITION_SOURCE_ID = // Debug no se usa activamente
  //     "debug-real-bus-pos-source";
  // static const String DEBUG_REAL_BUS_POSITION_LAYER_ID = // Debug no se usa activamente
  //     "debug-real-bus-pos-layer";

  BusTrackingController({
    required WidgetRef ref,
    required MapboxService mapboxService,
  }) : _ref = ref,
       _mapboxService = mapboxService {
    _loadAndParseShapesGeoJson();
  }

  Future<void> _loadAndParseShapesGeoJson() async {
    if (_shapesLoaded) {
      return;
    }
    try {
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
      if (_shapeGeometries.isEmpty) {
        print(
          "[BusTrackingController_Debug] ADVERTENCIA: No se cargaron geometrías de shapes.",
        );
      }
    } catch (e, s) {
      print(
        "[BusTrackingController_Debug] Error cargando o parseando shapes.geojson: $e\n$s",
      );
    }
  }

  Future<void> startTrackingBusLine(
    RouteLeg busLegToTrack,
    BusArrivalInfo? etaInfo,
  ) async {
    await stopTrackingBusLine();

    _currentTrackedBusLeg = busLegToTrack; // Guardar el tramo
    _currentTrackedETAInfo = etaInfo; // Guardar el ETA inicial

    // Guardar datos para la actualización en el timer
    _currentTrackingStopId =
        busLegToTrack.from.stopId ?? busLegToTrack.from.stopGtfsId;
    _currentTrackingLineShortName = etaInfo?.lineShortName;

    final String? otpShapeId = busLegToTrack.trip?.shapeId;
    String? shapeIdToSearch = otpShapeId;

    if (otpShapeId != null && otpShapeId.contains(':')) {
      shapeIdToSearch = otpShapeId.split(':').last;
    }

    _currentFullShapeForBusLeg = null;
    _originStopIndexOnShape = null;
    _destinationStopIndexOnShape = null;

    if (!_shapesLoaded) await _loadAndParseShapesGeoJson();
    if (!_shapesLoaded) {
      print(
        "[BusTrackingController_Debug] startTrackingBusLine: Shapes no cargados. No se puede dibujar línea completa.",
      );
      // No necesariamente retornamos, el bus podría mostrarse sin la línea completa.
    }

    if (shapeIdToSearch != null &&
        _shapeGeometries.containsKey(shapeIdToSearch)) {
      _currentFullShapeForBusLeg = _shapeGeometries[shapeIdToSearch];
      if (_currentFullShapeForBusLeg != null &&
          _currentFullShapeForBusLeg!.isNotEmpty) {
        final LegEndpoint busLegFrom = busLegToTrack.from;
        final LegEndpoint busLegTo = busLegToTrack.to;
        final models.Point_dart originStopPointDart = models.Point_dart(
          lat: busLegFrom.lat,
          lng: busLegFrom.lon,
        );
        _originStopIndexOnShape = geometry_utils.findClosestPointIndexOnShape(
          _currentFullShapeForBusLeg!,
          originStopPointDart,
        );
        final models.Point_dart destinationStopPointDart = models.Point_dart(
          lat: busLegTo.lat,
          lng: busLegTo.lon,
        );
        _destinationStopIndexOnShape = geometry_utils
            .findClosestPointIndexOnShape(
              _currentFullShapeForBusLeg!,
              destinationStopPointDart,
            );
        print(
          "[BusTrackingController_Debug] startTrackingBusLine: Indices en shape: origen=$_originStopIndexOnShape, destino=$_destinationStopIndexOnShape para shapeId $shapeIdToSearch",
        );

        _currentFullLineShapeId = shapeIdToSearch; // Guardar para limpieza
        await _mapboxService.drawFullBusLineShape(
          _currentFullShapeForBusLeg!,
          "$FULL_BUS_LINE_SHAPE_SOURCE_ID_PREFIX$shapeIdToSearch",
          "$FULL_BUS_LINE_SHAPE_LAYER_ID_PREFIX$shapeIdToSearch",
          Colors.grey.withOpacity(0.4),
          2.0,
        );
      } else {
        _currentFullShapeForBusLeg =
            null; // Asegurar que esté nulo si no es válido
      }
    } else {
      print(
        "[BusTrackingController_Debug] startTrackingBusLine: ShapeId '$shapeIdToSearch' no encontrado.",
      );
    }

    // Ahora, manejar el marcador del bus y el segmento verde basado en etaInfo
    if (etaInfo != null && etaInfo.isReal && etaInfo.position != null) {
      print(
        "[BusTrackingController_Debug] ETA en tiempo real con posición disponible. Mostrando bus.",
      );
      await _mapboxService.updateRealtimeBusMarkerAndSegment(
        etaInfo,
        _currentFullShapeForBusLeg,
        _originStopIndexOnShape,
      );

      _realtimeBusTimer?.cancel();
      _realtimeBusTimer = Timer.periodic(const Duration(seconds: 10), (
        timer,
      ) async {
        // Timer cada 10 segundos
        if (_currentTrackingStopId == null ||
            _currentTrackingLineShortName == null) {
          print(
            "[BusTrackingController_Timer] Faltan datos para actualizar ETA (stopId o lineShortName). Deteniendo timer.",
          );
          timer.cancel();
          stopTrackingBusLine(); // Detener seguimiento completo
          return;
        }

        // Notificar a MapNotifier que estamos intentando obtener una actualización
        // Esto podría usarse para un indicador de carga en la UI si se desea.
        // _ref.read(mapNotifierProvider.notifier).setRealtimeUpdateInProgress(true);

        print(
          "[BusTrackingController_Timer] Intentando obtener ETA actualizado para parada: $_currentTrackingStopId, línea: $_currentTrackingLineShortName",
        );
        try {
          final etaFetcherService = _ref.read(
            etaFetcherServiceProvider,
          ); // Obtener el servicio

          String stopIdForUpdate = _currentTrackingStopId!;
          if (_currentTrackingStopId!.contains(':')) {
            stopIdForUpdate = _currentTrackingStopId!.split(':').last;
            print(
              "[BusTrackingController_Timer] ID de parada ajustado para la API de actualización: $stopIdForUpdate (original: $_currentTrackingStopId)",
            );
          }

          final List<BusArrivalInfo> allArrivals = await etaFetcherService
              .getUpcomingBusesForStop(stopIdForUpdate); // USAR stopIdForUpdate

          final BusArrivalInfo? newEtaInfo = allArrivals.firstWhereOrNull(
            (arrival) =>
                arrival.lineShortName == _currentTrackingLineShortName &&
                arrival.isReal &&
                arrival.position != null,
          );

          if (newEtaInfo != null) {
            print(
              "[BusTrackingController_Timer] ETA actualizado encontrado: ${newEtaInfo.minutesToArrival} min, Pos: ${newEtaInfo.position?.toJson()}. Actualizando mapa.",
            );
            _currentTrackedETAInfo = newEtaInfo; // Actualizar el ETA guardado
            // Actualizar MapState con la nueva información de ETA si es necesario (para que la UI general también se actualice)
            _ref
                .read(mapNotifierProvider.notifier)
                .updateRepresentativeETA(newEtaInfo);

            await _mapboxService.updateRealtimeBusMarkerAndSegment(
              newEtaInfo,
              _currentFullShapeForBusLeg,
              _originStopIndexOnShape,
            );
          } else {
            print(
              "[BusTrackingController_Timer] No se encontró ETA actualizado en tiempo real para la línea $_currentTrackingLineShortName en la parada $_currentTrackingStopId, o no tiene posición. Deteniendo seguimiento.",
            );
            timer.cancel();
            stopTrackingBusLine();
            // Notificar a MapNotifier que el seguimiento falló o ya no está disponible
            _ref
                .read(mapNotifierProvider.notifier)
                .updateRealtimeTrackingStatus(false, true);
          }
        } catch (e, s) {
          print(
            "[BusTrackingController_Timer] Error obteniendo ETA actualizado: $e\n$s. Deteniendo seguimiento.",
          );
          timer.cancel();
          stopTrackingBusLine();
          _ref
              .read(mapNotifierProvider.notifier)
              .updateRealtimeTrackingStatus(false, true);
        } finally {
          // _ref.read(mapNotifierProvider.notifier).setRealtimeUpdateInProgress(false);
        }
        // Código anterior del timer:
        // final mapState = _ref.read(mapNotifierProvider);
        // if (mapState.trackedBusLineShortName == etaInfo.lineShortName && // etaInfo aquí es el original, no el actualizado
        //     mapState.realtimeTrackingAvailable) {
        //   print(
        //     "[BusTrackingController_Debug] Timer: (Placeholder) Re-evaluar posición del bus ${etaInfo.lineShortName}",
        //   );
        // } else {
        //   timer.cancel();
        // }
      });
    } else {
      print(
        "[BusTrackingController_Debug] Sin ETA en tiempo real con posición. Limpiando marcador de bus.",
      );
      await _mapboxService.clearRealtimeBusMarkerAndSegment();
    }
  }

  Future<void> stopTrackingBusLine() async {
    print("[BusTrackingController_Debug] stopTrackingBusLine called.");
    _realtimeBusTimer?.cancel();
    _realtimeBusTimer = null;

    // Limpiar datos del bus/tramo rastreado
    _currentTrackedBusLeg = null;
    _currentTrackedETAInfo = null;
    _currentTrackingStopId = null;
    _currentTrackingLineShortName = null;

    await _mapboxService.clearRealtimeBusMarkerAndSegment();

    if (_currentFullLineShapeId != null) {
      await _mapboxService.removeLayerAndSource(
        layerId: "$FULL_BUS_LINE_SHAPE_LAYER_ID_PREFIX$_currentFullLineShapeId",
        sourceId:
            "$FULL_BUS_LINE_SHAPE_SOURCE_ID_PREFIX$_currentFullLineShapeId",
      );
      _currentFullLineShapeId = null;
    }
    _currentFullShapeForBusLeg = null;
    _originStopIndexOnShape = null;
    _destinationStopIndexOnShape = null;
  }

  // _fetchAndDisplayRealtimeBusLocations ya no es necesario con el nuevo flujo.
  // La lógica de mostrar el bus ahora está en startTrackingBusLine usando el etaInfo.

  void dispose() {
    _realtimeBusTimer?.cancel();
    // _busSimulationTimer?.cancel();
  }
}
