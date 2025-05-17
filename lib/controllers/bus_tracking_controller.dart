import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:bondi_uy/models/route_leg.dart';
import 'package:bondi_uy/services/mapbox_service.dart';
import 'package:bondi_uy/providers/map_notifier.dart';
import 'package:bondi_uy/providers/service_providers.dart';
import 'package:bondi_uy/state/map_state.dart';
import 'package:bondi_uy/models/point_dart.dart' as models;
import 'package:bondi_uy/utils/geometry_utils.dart' as geometry_utils;
import 'package:flutter/material.dart'; // Para Colors

class BusTrackingController {
  final WidgetRef _ref;
  final MapboxService _mapboxService;
  MapboxMap? get _mapboxMap => _mapboxService.mapboxMap; // Acceso al mapboxMap

  Map<String, List<Position>> _shapeGeometries = {};
  bool _shapesLoaded = false;

  List<Position>? _currentFullShapeForBusLeg;
  int? _originStopIndexOnShape;
  int? _destinationStopIndexOnShape;
  String? _currentFullLineShapeId;

  Timer? _realtimeBusTimer;
  Timer? _busSimulationTimer;

  static const String REALTIME_BUS_SOURCE_ID = "realtime-bus-source";
  static const String REALTIME_BUS_LAYER_ID = "realtime-bus-layer";
  static const String FULL_BUS_LINE_SHAPE_SOURCE_ID_PREFIX =
      "full-bus-line-shape-source-";
  static const String FULL_BUS_LINE_SHAPE_LAYER_ID_PREFIX =
      "full-bus-line-shape-layer-";
  static const String DEBUG_REAL_BUS_POSITION_SOURCE_ID =
      "debug-real-bus-pos-source";
  static const String DEBUG_REAL_BUS_POSITION_LAYER_ID =
      "debug-real-bus-pos-layer";

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
          // Usar MapboxService.getStringValue si es apropiado, o adaptar.
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
        "[BusTrackingController_Debug] Error cargando o parseando shapes.geojson: $e",
      );
      print(s);
    }
  }

  Future<void> startTrackingBusLine(RouteLeg busLegToTrack) async {
    await stopTrackingBusLine(); // Llama al stop de este controlador

    final mapNotifier = _ref.read(mapNotifierProvider.notifier);
    final String? lineShortName = busLegToTrack.route?.shortName;
    final String? otpShapeId = busLegToTrack.trip?.shapeId;
    String? shapeIdToSearch = otpShapeId;

    if (otpShapeId != null && otpShapeId.contains(':')) {
      shapeIdToSearch = otpShapeId.split(':').last;
    }

    if (lineShortName == null || lineShortName.isEmpty) {
      print(
        "[BusTrackingController_Debug] startTrackingBusLine: lineShortName nulo o vacío. Retornando.",
      );
      return;
    }

    mapNotifier.setTrackedBusLineShortName(lineShortName);

    _currentFullShapeForBusLeg = null;
    _originStopIndexOnShape = null;
    _destinationStopIndexOnShape = null;

    // _shapesLoaded ya se maneja internamente o a través de la inicialización
    if (!_shapesLoaded)
      await _loadAndParseShapesGeoJson(); // Asegurar que estén cargados
    if (!_shapesLoaded) {
      print(
        "[BusTrackingController_Debug] startTrackingBusLine: Shapes no cargados después del intento. Retornando.",
      );
      return;
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
      }
    } else {
      print(
        "[BusTrackingController_Debug] startTrackingBusLine: ShapeId '$shapeIdToSearch' no encontrado en _shapeGeometries.",
      );
    }

    if (_currentFullShapeForBusLeg != null &&
        _currentFullShapeForBusLeg!.isNotEmpty &&
        shapeIdToSearch != null) {
      _currentFullLineShapeId = shapeIdToSearch;
      await _mapboxService.drawFullBusLineShape(
        _currentFullShapeForBusLeg!,
        "$FULL_BUS_LINE_SHAPE_SOURCE_ID_PREFIX$shapeIdToSearch",
        "$FULL_BUS_LINE_SHAPE_LAYER_ID_PREFIX$shapeIdToSearch",
        Colors.grey.withOpacity(0.4),
        2.0,
      );
      print(
        "[BusTrackingController_Debug] startTrackingBusLine: Línea completa dibujada con ID: $shapeIdToSearch",
      );
    }

    _fetchAndDisplayRealtimeBusLocations(); // Llama al fetch de este controlador
    _realtimeBusTimer?.cancel();
    _realtimeBusTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      // Leer el estado directamente desde el notifier
      final currentLegBeingTrackedInState =
          _ref.read(mapNotifierProvider).legToTrackInRealtime;
      if (currentLegBeingTrackedInState?.trip?.gtfsId ==
              busLegToTrack.trip?.gtfsId &&
          currentLegBeingTrackedInState?.route?.shortName ==
              busLegToTrack.route?.shortName) {
        print(
          "[BusTrackingController_Debug] Timer _realtimeBusTimer: Re-fetching ubicaciones.",
        );
        _fetchAndDisplayRealtimeBusLocations();
      } else {
        print(
          "[BusTrackingController_Debug] Timer _realtimeBusTimer: El tramo ha cambiado o es nulo. Cancelando timer.",
        );
        timer.cancel();
      }
    });
  }

  Future<void> stopTrackingBusLine() async {
    print("[BusTrackingController_Debug] stopTrackingBusLine called.");
    _realtimeBusTimer?.cancel();
    _busSimulationTimer?.cancel(); // También cancela el timer de simulación
    _realtimeBusTimer = null;
    _busSimulationTimer = null;

    final mapNotifier = _ref.read(mapNotifierProvider.notifier);
    mapNotifier.updateBusSimulationState(
      newRealDebugBusPosition: null,
      newEtaMinutes: null,
      newBusSpeedMetersPerSecond: null,
      newLastSpeedCalculationTime: null,
      newSimulationSegmentOriginPoint: null,
      newMaxSimulationTravelDistance: null,
      newSimulatedBusPosition: null,
    );
    mapNotifier.setTrackedBusLineShortName(null);

    _mapboxService.stopTooltipFloatingAnimation();

    _currentFullShapeForBusLeg = null;
    _originStopIndexOnShape = null;
    _destinationStopIndexOnShape = null;

    if (_mapboxMap != null) {
      // Usar _mapboxMap getter
      await _updateRealtimeBusLayers([]); // Llama al método de este controlador
      await _removeDebugRealBusPositionLayer(); // Llama al método de este controlador
      await _mapboxService.clearIncomingBusSegment();

      if (_currentFullLineShapeId != null) {
        final fullLineSourceId =
            "$FULL_BUS_LINE_SHAPE_SOURCE_ID_PREFIX$_currentFullLineShapeId";
        final fullLineLayerId =
            "$FULL_BUS_LINE_SHAPE_LAYER_ID_PREFIX$_currentFullLineShapeId";
        try {
          if (await _mapboxMap!.style.styleLayerExists(fullLineLayerId)) {
            await _mapboxMap!.style.removeStyleLayer(fullLineLayerId);
          }
          if (await _mapboxMap!.style.styleSourceExists(fullLineSourceId)) {
            await _mapboxMap!.style.removeStyleSource(fullLineSourceId);
          }
          print(
            "[BusTrackingController_Debug] stopTrackingBusLine: Línea completa ($fullLineLayerId) eliminada.",
          );
        } catch (e) {
          print(
            "[BusTrackingController_Debug] Error removing full bus line shape: $e",
          );
        }
        _currentFullLineShapeId = null;
      }
    }
  }

  Future<void> _fetchAndDisplayRealtimeBusLocations() async {
    final mapState = _ref.read(mapNotifierProvider);
    final RouteLeg? legToTrack = mapState.legToTrackInRealtime;
    final mapNotifier = _ref.read(mapNotifierProvider.notifier);

    final String? lineIdForApi = legToTrack?.route?.shortName;
    String? stopIdForApi;
    if (legToTrack != null) {
      if (legToTrack.from.stopId != null &&
          legToTrack.from.stopId!.isNotEmpty &&
          legToTrack.from.stopId != 'null') {
        stopIdForApi = legToTrack.from.stopId;
      } else if (legToTrack.from.stopGtfsId != null &&
          legToTrack.from.stopGtfsId!.isNotEmpty) {
        stopIdForApi = legToTrack.from.stopGtfsId;
        if (stopIdForApi!.contains(':')) {
          stopIdForApi = stopIdForApi.split(':').last;
        }
      }
    }

    if (lineIdForApi == null ||
        lineIdForApi.isEmpty ||
        stopIdForApi == null ||
        stopIdForApi.isEmpty ||
        legToTrack == null) {
      print(
        "[BusTrackingController_Debug] _fetchAndDisplayRealtimeBusLocations: Datos insuficientes para obtener buses (linea: $lineIdForApi, parada: $stopIdForApi). Cancelando.",
      );
      // Considerar limpiar la posición del bus si no hay datos para evitar mostrar información desactualizada.
      mapNotifier.updateBusSimulationState(
        newRealDebugBusPosition: null,
        newEtaMinutes: null,
      );
      await _updateDebugRealBusPositionLayer(null);
      await _updateRealtimeBusLayers([]);
      _mapboxService.clearIncomingBusSegment();
      return;
    }

    Position? apiBusPosition;
    int? apiEtaMinutes;
    List<Map<String, dynamic>> geoJsonFeaturesForMainBusLayer = [];

    try {
      final montevideoApiService = _ref.read(montevideoApiServiceProvider);
      final List<Map<String, dynamic>> allUpcomingBusesForStop =
          await montevideoApiService.fetchNextArrivalsForStop(stopIdForApi);

      Map<String, dynamic>? targetBusData;

      if (allUpcomingBusesForStop.isNotEmpty) {
        targetBusData = allUpcomingBusesForStop.firstWhere(
          (bus) {
            final bool lineMatch = bus['line']?.toString() == lineIdForApi;
            final bool isReal = bus['isReal'] == true;
            final busLocation = bus['location'];
            bool hasValidCoords = false;
            if (busLocation is Map<String, dynamic> &&
                busLocation['coordinates'] is List) {
              final coords = busLocation['coordinates'] as List<dynamic>;
              if (coords.length == 2 &&
                  coords[0] is double &&
                  coords[1] is double) {
                hasValidCoords = true;
              }
            }
            return lineMatch && isReal && hasValidCoords;
          },
          orElse: () {
            var firstRealForLine = allUpcomingBusesForStop.where(
              (bus) =>
                  bus['line']?.toString() == lineIdForApi &&
                  bus['isReal'] == true,
            );
            return firstRealForLine.isNotEmpty
                ? firstRealForLine.first
                : <String, dynamic>{};
          },
        );

        if (targetBusData.isEmpty ||
            (targetBusData['isReal'] != true ||
                targetBusData['location'] == null)) {
          var anyBusForLine = allUpcomingBusesForStop.where(
            (bus) => bus['line']?.toString() == lineIdForApi,
          );
          if (anyBusForLine.isNotEmpty) {
            if (targetBusData.isEmpty ||
                targetBusData['isReal'] != true ||
                targetBusData['location'] == null) {
              targetBusData = anyBusForLine.first;
            }
          }
        }

        if (targetBusData.isNotEmpty) {
          final dynamic locationField = targetBusData['location'];
          final dynamic etaField = targetBusData['minutesToArrival'];

          if (etaField is int) {
            apiEtaMinutes = etaField;
          } else if (etaField is String) {
            apiEtaMinutes = int.tryParse(etaField);
          }

          if (locationField is Map<String, dynamic> &&
              locationField['type'] == 'Point' &&
              locationField.containsKey('coordinates')) {
            final List<dynamic>? coordsList =
                locationField['coordinates'] as List<dynamic>?;
            if (coordsList != null &&
                coordsList.length == 2 &&
                coordsList[0] is double &&
                coordsList[1] is double) {
              if (coordsList[0] != 0.0 || coordsList[1] != 0.0) {
                apiBusPosition = Position(coordsList[0]!, coordsList[1]!);
              }
            }
          }
        }
      }
    } catch (e, s) {
      print(
        "[BusTrackingController_DEBUG_FETCH] Error fetching realtime bus data: $e",
      );
      print(s);
    }

    // Leer estado ANTES de llamar a updateBusSimulationState para tener el estado actual para la lógica de simulación.
    final MapState currentStateSnapshot = _ref.read(mapNotifierProvider);

    mapNotifier.updateBusSimulationState(
      newRealDebugBusPosition:
          apiBusPosition, // Siempre actualiza el debug real
      newEtaMinutes: apiEtaMinutes,
      // Aquí se pueden añadir los demás parámetros para la simulación si es necesario
      // como newBusSpeedMetersPerSecond, newLastSpeedCalculationTime, etc.,
      // calculados a partir de apiBusPosition y el estado previo.
    );
    await _updateDebugRealBusPositionLayer(
      apiBusPosition,
    ); // Mueve la capa de debug real

    // Usar el estado más reciente después de la actualización para decidir qué mostrar
    final MapState updatedMapState = _ref.read(mapNotifierProvider);
    final Position? busToDisplay = updatedMapState.highlightedBusPosition;
    final int? etaToDisplay = updatedMapState.highlightedBusEtaMinutes;

    geoJsonFeaturesForMainBusLayer.clear();
    if (busToDisplay != null) {
      final String? busLineShortName =
          updatedMapState.legToTrackInRealtime?.route?.shortName ?? 'Bus';
      geoJsonFeaturesForMainBusLayer.add({
        'type': 'Feature',
        'id': 'highlighted_bus',
        'geometry': {
          'type': 'Point',
          'coordinates': [busToDisplay.lng, busToDisplay.lat],
        },
        'properties': {
          'busLineName': busLineShortName,
          'etaMinutes': etaToDisplay ?? 0,
          'isRelevant': true,
          'isClosestUpcoming': true,
        },
      });
    }

    await _updateRealtimeBusLayers(geoJsonFeaturesForMainBusLayer);

    // Lógica para dibujar el segmento de bus entrante
    // Esta lógica ahora usa _currentFullShapeForBusLeg y _originStopIndexOnShape que son miembros de esta clase
    print(
      "[BusTrackingController_Debug_DrawIncomingCheck] En _fetchAndDisplayRealtimeBusLocations. busToDisplay: $busToDisplay, _currentFullShapeForBusLeg: ${_currentFullShapeForBusLeg?.isNotEmpty}, _originStopIndexOnShape: $_originStopIndexOnShape",
    );

    if (busToDisplay != null &&
        _currentFullShapeForBusLeg != null &&
        _currentFullShapeForBusLeg!.isNotEmpty &&
        _originStopIndexOnShape != null) {
      await _mapboxService.drawIncomingBusSegment(
        busToDisplay,
        _currentFullShapeForBusLeg,
        _originStopIndexOnShape,
      );
    } else {
      print(
        "[BusTrackingController_Debug_DrawIncomingCheck] En _fetchAndDisplayRealtimeBusLocations. Condiciones no cumplidas o datos nulos/vacíos. Llamando a clearIncomingBusSegment.",
      );
      _mapboxService.clearIncomingBusSegment();
    }

    // Iniciar o actualizar simulación si es necesario (basado en el estado actualizado)
    // Esta es una simplificación. La lógica original en MapNotifier para decidir si simular
    // o usar la posición real basada en ETA < 3 min, etc., ya está en updateBusSimulationState.
    // Aquí solo necesitamos asegurarnos de que el timer de simulación se inicie si hay velocidad.
    if (updatedMapState.busSpeedMetersPerSecond != null &&
        updatedMapState.busSpeedMetersPerSecond! > 0) {
      _startBusSimulationTimer();
    } else {
      _busSimulationTimer?.cancel();
    }
  }

  void _startBusSimulationTimer() {
    print(
      "[BusTrackingController_DEBUG_SIM_TIMER] === Entered _startBusSimulationTimer ===",
    );
    _busSimulationTimer?.cancel();
    _busSimulationTimer = Timer.periodic(const Duration(milliseconds: 1000), (
      timer,
    ) async {
      // Hacer async para poder usar await dentro si es necesario (aunque _updateRealtimeBusLayers no devuelve Future aquí)
      final mapState = _ref.read(mapNotifierProvider); // Leer el estado actual
      final mapNotifier = _ref.read(mapNotifierProvider.notifier);

      if (mapState.busSpeedMetersPerSecond == null ||
          mapState.busSpeedMetersPerSecond! <= 0 ||
          mapState.lastSpeedCalculationTime == null ||
          mapState.simulationSegmentOriginPoint == null ||
          _currentFullShapeForBusLeg == null || // Variable de instancia
          _currentFullShapeForBusLeg!.isEmpty ||
          _originStopIndexOnShape == null) {
        // Variable de instancia
        print(
          "[BusTrackingController_DEBUG_SIM_TIMER] Condiciones para simulación no cumplidas. Retornando.",
        );
        // No cancelar el timer aquí directamente, MapNotifier podría detenerlo basado en ETA.
        return;
      }

      final DateTime now = DateTime.now();
      final double elapsedSecondsSinceLastSpeedCalc =
          now.difference(mapState.lastSpeedCalculationTime!).inMilliseconds /
          1000.0;

      double totalDistanceToSimulateFromSegmentOrigin =
          mapState.busSpeedMetersPerSecond! * elapsedSecondsSinceLastSpeedCalc;

      if (mapState.maxSimulationTravelDistance != null &&
          totalDistanceToSimulateFromSegmentOrigin >
              mapState.maxSimulationTravelDistance!) {
        totalDistanceToSimulateFromSegmentOrigin =
            mapState.maxSimulationTravelDistance!;
      }

      final models.Point_dart segmentOriginPointDart = models.Point_dart(
        lat: mapState.simulationSegmentOriginPoint!.lat.toDouble(),
        lng: mapState.simulationSegmentOriginPoint!.lng.toDouble(),
      );

      int simulationOriginIndexOnShape = geometry_utils
          .findClosestPointIndexOnShape(
            _currentFullShapeForBusLeg!, // Variable de instancia
            segmentOriginPointDart,
          );

      if (simulationOriginIndexOnShape == -1) {
        print(
          "[BusTrackingController_DEBUG_SIM_TIMER] Punto origen de simulación no encontrado en shape. Deteniendo simulación en notifier.",
        );
        mapNotifier.updateBusSimulationState(
          newBusSpeedMetersPerSecond: null,
        ); // Esto debería detener la simulación
        // timer.cancel(); // El notifier se encarga de esto al poner speed a null
        return;
      }

      Position newSimulatedPosition = geometry_utils
          .getPointAtDistanceAlongPolyline(
            _currentFullShapeForBusLeg!, // Variable de instancia
            simulationOriginIndexOnShape,
            totalDistanceToSimulateFromSegmentOrigin,
          );

      final models.Point_dart newSimulatedPointDart = models.Point_dart(
        lat: newSimulatedPosition.lat.toDouble(),
        lng: newSimulatedPosition.lng.toDouble(),
      );

      int newSimulatedIdx = geometry_utils.findClosestPointIndexOnShape(
        _currentFullShapeForBusLeg!, // Variable de instancia
        newSimulatedPointDart,
      );

      // Verificar si el bus simulado ha llegado o pasado la parada de origen del tramo del usuario.
      if (_originStopIndexOnShape != null &&
          newSimulatedIdx >= _originStopIndexOnShape!) {
        newSimulatedPosition =
            _currentFullShapeForBusLeg![_originStopIndexOnShape!]; // Ajustar a la parada
        print(
          "[BusTrackingController_DEBUG_SIM_TIMER] Bus simulado llegó a la parada de origen. Deteniendo simulación y actualizando notifier.",
        );
        mapNotifier.updateBusSimulationState(
          newSimulatedBusPosition: newSimulatedPosition,
          newBusSpeedMetersPerSecond: null, // Detiene la simulación
          newEtaMinutes: 0, // ETA es 0 en la parada
        );
        // timer.cancel(); // El notifier lo gestiona
        // _mapboxService.clearIncomingBusSegment(); // MapNotifier se encarga de la UI a través de su estado

        // Actualizar la capa del bus una última vez para mostrarlo en la parada con ETA 0
        final List<Map<String, dynamic>> featuresForLayer = [];
        final String? busLineShortName =
            mapState.legToTrackInRealtime?.route?.shortName;
        if (busLineShortName != null) {
          featuresForLayer.add({
            'type': 'Feature',
            'id': 'highlighted-realtime-bus',
            'geometry': {
              'type': 'Point',
              'coordinates': [
                newSimulatedPosition.lng,
                newSimulatedPosition.lat,
              ],
            },
            'properties': {
              'line': busLineShortName,
              'etaMinutes': 0,
              'isRelevant': true,
              'isClosestUpcoming': true,
            },
          });
        }
        await _updateRealtimeBusLayers(
          featuresForLayer,
        ); // Llama al método de este controlador
        await _mapboxService.drawIncomingBusSegment(
          newSimulatedPosition,
          _currentFullShapeForBusLeg,
          _originStopIndexOnShape,
        ); // Dibuja el tramo hasta la parada

        return;
      }

      // Actualizar el estado en MapNotifier con la nueva posición simulada.
      // MapNotifier decidirá si esta posición simulada se convierte en la highlightedBusPosition.
      mapNotifier.updateBusSimulationState(
        newSimulatedBusPosition: newSimulatedPosition,
        // ETA no se recalcula aquí, se usa el último de la API o el que MapNotifier decida.
        // newEtaMinutes: mapState.highlightedBusEtaMinutes, // No es necesario, MapNotifier lo gestiona
      );

      // La actualización de capas y el segmento de bus entrante ahora es condicional
      // y se basa en el estado de MapNotifier (highlightedBusPosition).
      final MapState currentMapStateAfterNotifierUpdate = _ref.read(
        mapNotifierProvider,
      );
      final Position? busToDisplay =
          currentMapStateAfterNotifierUpdate.highlightedBusPosition;
      final int? etaToDisplay =
          currentMapStateAfterNotifierUpdate.highlightedBusEtaMinutes;

      if (busToDisplay != null) {
        final List<Map<String, dynamic>> featuresForLayer = [];
        final String? busLineShortName =
            currentMapStateAfterNotifierUpdate
                .legToTrackInRealtime
                ?.route
                ?.shortName;

        if (busLineShortName != null) {
          featuresForLayer.add({
            'type': 'Feature',
            'id': 'highlighted-realtime-bus',
            'geometry': {
              'type': 'Point',
              'coordinates': [
                busToDisplay
                    .lng, // Usa la posición que el notifier decidió mostrar
                busToDisplay.lat,
              ],
            },
            'properties': {
              'line': busLineShortName,
              'etaMinutes':
                  etaToDisplay, // Usa el ETA que el notifier decidió mostrar
              'isRelevant': true,
              'isClosestUpcoming': true,
            },
          });
        }
        await _updateRealtimeBusLayers(
          featuresForLayer,
        ); // Llama al método de este controlador

        if (_currentFullShapeForBusLeg != null &&
            _originStopIndexOnShape != null) {
          print(
            "[BusTrackingController_DEBUG_SIM_TIMER] Dibujando segmento entrante con busToDisplay: $busToDisplay",
          );
          await _mapboxService.drawIncomingBusSegment(
            busToDisplay,
            _currentFullShapeForBusLeg!,
            _originStopIndexOnShape!,
          );
        } else {
          print(
            "[BusTrackingController_DEBUG_SIM_TIMER] No se dibujó segmento entrante: _currentFullShapeForBusLeg o _originStopIndexOnShape es null.",
          );
        }
      } else {
        print(
          "[BusTrackingController_DEBUG_SIM_TIMER] busToDisplay es null después de la actualización del notifier. No se actualizan capas de bus.",
        );
        await _updateRealtimeBusLayers(
          [],
        ); // Limpia la capa si no hay bus para mostrar
        _mapboxService.clearIncomingBusSegment(); // Limpia el segmento
      }
    });
  }

  Future<void> _updateRealtimeBusLayers(List<dynamic> features) async {
    if (_mapboxMap == null) {
      // Usar _mapboxMap getter
      print(
        "[BusTrackingController_Debug] _updateRealtimeBusLayers: _mapboxMap es null. Retornando.",
      );
      return;
    }

    Map<String, dynamic> geoJsonData = {
      "type": "FeatureCollection",
      "features": features,
    };
    final String geoJsonString = json.encode(geoJsonData);

    try {
      final sourceExists = await _mapboxMap!.style.styleSourceExists(
        REALTIME_BUS_SOURCE_ID,
      );
      if (!sourceExists) {
        await _mapboxMap!.style.addSource(
          GeoJsonSource(id: REALTIME_BUS_SOURCE_ID, data: geoJsonString),
        );
      } else {
        final source =
            await _mapboxMap!.style.getSource(REALTIME_BUS_SOURCE_ID)
                as GeoJsonSource?;
        await source?.updateGeoJSON(geoJsonString);
      }
    } catch (e, s) {
      print(
        "[BusTrackingController_DEBUG_LAYERS] Error creating/updating source $REALTIME_BUS_SOURCE_ID: $e",
      );
      print(s);
      return;
    }

    try {
      if (await _mapboxMap!.style.styleLayerExists(REALTIME_BUS_LAYER_ID)) {
        await _mapboxMap!.style.removeStyleLayer(REALTIME_BUS_LAYER_ID);
      }
      // MapboxService.INCOMING_BUS_TOOLTIP_LAYER_ID es una constante estática en MapboxService
      if (await _mapboxMap!.style.styleLayerExists(
        MapboxService.INCOMING_BUS_TOOLTIP_LAYER_ID,
      )) {
        await _mapboxMap!.style.removeStyleLayer(
          MapboxService.INCOMING_BUS_TOOLTIP_LAYER_ID,
        );
      }
    } catch (e) {
      print(
        "[BusTrackingController_DEBUG_LAYERS] Error removiendo capas antiguas de bus en tiempo real: $e",
      );
    }

    if (features.isEmpty) {
      _mapboxService.stopTooltipFloatingAnimation();
      return;
    }

    final List<Object> mainFilter = [
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

    // MapboxService.INCOMING_BUS_ICON_ID es una constante estática en MapboxService
    final String busIconImageId = MapboxService.INCOMING_BUS_ICON_ID;
    const double busIconSize = 0.7;

    try {
      await _mapboxMap!.style.addLayer(
        SymbolLayer(
          id: REALTIME_BUS_LAYER_ID,
          sourceId: REALTIME_BUS_SOURCE_ID,
          filter: mainFilter,
          iconImage: busIconImageId,
          iconSize: busIconSize,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          minZoom: 10.0,
        ),
      );
    } catch (e, s) {
      print(
        "[BusTrackingController_DEBUG_LAYERS] FAILED adding layer $REALTIME_BUS_LAYER_ID: $e",
      );
      print(s);
    }

    bool shouldShowTooltipForFeature = false;
    if (features.isNotEmpty) {
      final properties = features[0]['properties'];
      if (properties is Map<String, dynamic> &&
          properties.containsKey('etaMinutes')) {
        final eta = properties['etaMinutes'];
        if (eta is num && eta >= 0) {
          shouldShowTooltipForFeature = true;
        }
      }
    }

    if (shouldShowTooltipForFeature) {
      try {
        // MapboxService.INCOMING_BUS_TOOLTIP_ICON_ID y MapboxService.INCOMING_BUS_TOOLTIP_LAYER_ID son constantes estáticas
        await _mapboxMap!.style.addLayer(
          SymbolLayer(
            id: MapboxService.INCOMING_BUS_TOOLTIP_LAYER_ID,
            sourceId: REALTIME_BUS_SOURCE_ID,
            filter: mainFilter,
            iconImage: MapboxService.INCOMING_BUS_TOOLTIP_ICON_ID,
            iconSize: 0.7,
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
            minZoom: 10.0,
            iconOffset: [0.0, 0.0], // La animación lo ajustará
            textField: '{etaMinutes} min',
            textColor: Colors.black.value,
            textHaloColor: Colors.white.value,
            textHaloWidth: 1.0,
            textSize: 12.0,
            textAnchor: TextAnchor.TOP,
            textOffset: [0.0, 1.5],
          ),
        );
        _mapboxService.startTooltipFloatingAnimation();
      } catch (e, s) {
        print(
          "[BusTrackingController_DEBUG_LAYERS] FAILED adding tooltip layer ${MapboxService.INCOMING_BUS_TOOLTIP_LAYER_ID}: $e",
        );
        print(s);
      }
    } else {
      _mapboxService.stopTooltipFloatingAnimation();
    }
  }

  Future<void> _updateDebugRealBusPositionLayer(
    Position? realBusPosition,
  ) async {
    if (_mapboxMap == null) return;

    Map<String, dynamic> geoJsonData = {
      "type": "FeatureCollection",
      "features": [],
    };

    if (realBusPosition != null) {
      geoJsonData["features"].add({
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [
            realBusPosition.lng.toDouble(),
            realBusPosition.lat.toDouble(),
          ],
        },
        "properties": {},
      });
    }
    final String geoJsonString = json.encode(geoJsonData);

    try {
      final sourceExists = await _mapboxMap!.style.styleSourceExists(
        DEBUG_REAL_BUS_POSITION_SOURCE_ID,
      );
      if (!sourceExists) {
        await _mapboxMap!.style.addSource(
          GeoJsonSource(
            id: DEBUG_REAL_BUS_POSITION_SOURCE_ID,
            data: geoJsonString,
          ),
        );
      } else {
        final source =
            await _mapboxMap!.style.getSource(DEBUG_REAL_BUS_POSITION_SOURCE_ID)
                as GeoJsonSource?;
        await source?.updateGeoJSON(geoJsonString);
      }

      final layerExists = await _mapboxMap!.style.styleLayerExists(
        DEBUG_REAL_BUS_POSITION_LAYER_ID,
      );
      if (!layerExists && realBusPosition != null) {
        await _mapboxMap!.style.addLayer(
          CircleLayer(
            id: DEBUG_REAL_BUS_POSITION_LAYER_ID,
            sourceId: DEBUG_REAL_BUS_POSITION_SOURCE_ID,
            circleColor: Colors.red.value,
            circleRadius: 5.0,
            circleOpacity: 0.8,
            circleStrokeColor: Colors.white.value,
            circleStrokeWidth: 1.5,
          ),
        );
      } else if (layerExists && realBusPosition == null) {
        await _mapboxMap!.style.removeStyleLayer(
          DEBUG_REAL_BUS_POSITION_LAYER_ID,
        );
      }
    } catch (e) {
      print(
        "[BusTrackingController_Debug] Error updating debug real bus position layer: $e",
      );
    }
  }

  Future<void> _removeDebugRealBusPositionLayer() async {
    if (_mapboxMap == null) return;
    try {
      if (await _mapboxMap!.style.styleLayerExists(
        DEBUG_REAL_BUS_POSITION_LAYER_ID,
      )) {
        await _mapboxMap!.style.removeStyleLayer(
          DEBUG_REAL_BUS_POSITION_LAYER_ID,
        );
      }
      if (await _mapboxMap!.style.styleSourceExists(
        DEBUG_REAL_BUS_POSITION_SOURCE_ID,
      )) {
        await _mapboxMap!.style.removeStyleSource(
          DEBUG_REAL_BUS_POSITION_SOURCE_ID,
        );
      }
    } catch (e) {
      print(
        "[BusTrackingController_Debug] Error removing debug real bus position layer: $e",
      );
    }
  }

  void dispose() {
    _realtimeBusTimer?.cancel();
    _busSimulationTimer?.cancel();
    // Asegurarse de limpiar cualquier capa/fuente que este controlador gestione directamente
    // si no se hace a través de stopTrackingBusLine o similar.
  }
}
