/// Servicio para capturar datos de trips y exportarlos como JSON para testing
///
/// Este servicio toma un trip seleccionado en el carousel y lo exporta
/// en formato JSON compatible con los tests de integración.
///
/// ESTRATEGIA:
/// - Captura la ruta desde el carousel (con geometrías completas)
/// - Genera GPS playback SINTÉTICAMENTE desde las geometrías
/// - Genera checkpoints AUTOMÁTICAMENTE
/// - NO requiere grabar viaje real
///
/// IMPORTANTE: Para capturar GPS playback durante un viaje activo, usa
/// startGpsRecording() al iniciar el viaje y stopGpsRecording() al finalizar.

import 'dart:convert';
import 'package:flutter/services.dart';
import '../backend/contrato_ui/app_ui_state.dart';
import 'gps_playback_generator.dart';

class TripDataCaptureService {
  // GPS Recording para playback
  static final List<Map<String, dynamic>> _gpsRecording = [];
  static DateTime? _recordingStartTime;
  static bool _isRecording = false;

  /// Inicia grabación de GPS para playback
  static void startGpsRecording() {
    _gpsRecording.clear();
    _recordingStartTime = DateTime.now();
    _isRecording = true;
    print('[TripCapture] 🔴 Iniciando grabación GPS para playback');
  }

  /// Detiene grabación de GPS
  static void stopGpsRecording() {
    _isRecording = false;
    print('[TripCapture] ⏹️  Grabación GPS detenida (${_gpsRecording.length} puntos)');
  }

  /// Registra un punto GPS durante la grabación
  static void recordGpsPoint(Coordenada location, {String? comment}) {
    if (!_isRecording || _recordingStartTime == null) return;

    final timestamp = DateTime.now().difference(_recordingStartTime!).inSeconds;

    _gpsRecording.add({
      'timestamp': timestamp,
      'lat': location.latitud,
      'lng': location.longitud,
      if (comment != null) 'comment': comment,
    });
  }

  /// Captura un trip y lo copia al portapapeles como JSON
  ///
  /// AUTOMÁTICO: Genera GPS playback y checkpoints desde las geometrías
  static Future<void> captureTripToClipboard({
    required String tripId,
    required Coordenada origin,
    required Coordenada destination,
    required OpcionDeRutaMostrable selectedRoute,
    Coordenada? initialBusPosition,
    bool generateSyntheticGps = true, // NUEVO: generar GPS sintético
    bool generateCheckpoints = true, // NUEVO: generar checkpoints automáticos
    List<Map<String, dynamic>>? manualGpsPlayback,
    List<Map<String, dynamic>>? manualCheckpoints,
  }) async {
    List<Map<String, dynamic>> gpsPlayback;
    List<Map<String, dynamic>> checkpoints;

    // Opción 1: GPS y checkpoints generados sintéticamente (RECOMENDADO)
    if (generateSyntheticGps && manualGpsPlayback == null) {
      print('[TripCapture] 🎬 Generando GPS playback sintético desde geometrías...');
      gpsPlayback = GpsPlaybackGenerator.generateFromRoute(
        origin: origin,
        destination: destination,
        tramos: selectedRoute.tramosParaPreview,
        speedMultiplier: 1.0,
      );
      print('[TripCapture] ✅ ${gpsPlayback.length} puntos GPS generados');
    } else {
      // Opción 2: GPS grabado manualmente o provisto
      gpsPlayback = manualGpsPlayback ?? _gpsRecording;
    }

    // Generar checkpoints automáticamente si se requiere
    if (generateCheckpoints && manualCheckpoints == null && gpsPlayback.isNotEmpty) {
      print('[TripCapture] 🎯 Generando checkpoints automáticos...');
      checkpoints = GpsPlaybackGenerator.generateCheckpoints(
        tramos: selectedRoute.tramosParaPreview,
        gpsPlayback: gpsPlayback,
      );
      print('[TripCapture] ✅ ${checkpoints.length} checkpoints generados');
    } else {
      checkpoints = manualCheckpoints ?? [];
    }

    final json = _buildTripJson(
      tripId: tripId,
      origin: origin,
      destination: destination,
      selectedRoute: selectedRoute,
      initialBusPosition: initialBusPosition,
      gpsPlayback: gpsPlayback,
      checkpoints: checkpoints,
    );

    final jsonString = const JsonEncoder.withIndent('  ').convert(json);

    await Clipboard.setData(ClipboardData(text: jsonString));

    print('[TripCapture] ✅ Trip copiado al portapapeles (${jsonString.length} caracteres)');
    print('[TripCapture] 📋 Trip ID: $tripId');
    print('[TripCapture] 📊 Segmentos: ${selectedRoute.tramosParaPreview.length}');
    print('[TripCapture] 📍 GPS playback: ${gpsPlayback.length} puntos (${gpsPlayback.isNotEmpty ? gpsPlayback.last['timestamp'] : 0}s)');
    print('[TripCapture] 🎯 Checkpoints: ${checkpoints.length}');
  }

  static Map<String, dynamic> _buildTripJson({
    required String tripId,
    required Coordenada origin,
    required Coordenada destination,
    required OpcionDeRutaMostrable selectedRoute,
    Coordenada? initialBusPosition,
    List<Map<String, dynamic>>? gpsPlayback,
    List<Map<String, dynamic>>? checkpoints,
  }) {
    // Extraer paradas únicas de los tramos
    final stops = <Map<String, dynamic>>[];
    final stopsMap = <String, Map<String, dynamic>>{};

    for (final tramo in selectedRoute.tramosParaPreview) {
      // Paradas de origen/destino de buses
      if (tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS) {
        if (tramo.coordenadasParadaOrigen != null && tramo.idParadaOrigenTramoBus != null) {
          final stopId = tramo.idParadaOrigenTramoBus!;
          if (!stopsMap.containsKey(stopId)) {
            stopsMap[stopId] = {
              'stopId': stopId,
              'name': tramo.nombreParadaOrigen ?? 'Parada $stopId',
              'lat': tramo.coordenadasParadaOrigen!.latitud,
              'lng': tramo.coordenadasParadaOrigen!.longitud,
              'busLines': <String>[],
            };
          }
          if (tramo.nombreLineaBus != null) {
            (stopsMap[stopId]!['busLines'] as List<String>).add(tramo.nombreLineaBus!);
          }
        }

        if (tramo.coordenadasParadaDestino != null && tramo.idParadaDestinoTramoBus != null) {
          final stopId = tramo.idParadaDestinoTramoBus!;
          if (!stopsMap.containsKey(stopId)) {
            stopsMap[stopId] = {
              'stopId': stopId,
              'name': tramo.nombreParadaDestino ?? 'Parada $stopId',
              'lat': tramo.coordenadasParadaDestino!.latitud,
              'lng': tramo.coordenadasParadaDestino!.longitud,
              'busLines': <String>[],
            };
          }
          if (tramo.nombreLineaBus != null) {
            final busLines = stopsMap[stopId]!['busLines'] as List<String>;
            if (!busLines.contains(tramo.nombreLineaBus!)) {
              busLines.add(tramo.nombreLineaBus!);
            }
          }
        }
      }

      // Paradas de espera
      if (tramo.tipo == TipoTramoViaje.ESPERAR_BUS && tramo.posicionPunto != null) {
        final stopId = 'stop_wait_${stops.length}';
        if (!stopsMap.containsKey(stopId)) {
          stopsMap[stopId] = {
            'stopId': stopId,
            'name': tramo.descripcion ?? 'Parada',
            'lat': tramo.posicionPunto!.latitud,
            'lng': tramo.posicionPunto!.longitud,
            'busLines': tramo.nombreLineaBus != null ? [tramo.nombreLineaBus!] : [],
          };
        }
      }
    }

    stops.addAll(stopsMap.values);

    // Convertir tramos
    final segments = <Map<String, dynamic>>[];
    for (final tramo in selectedRoute.tramosParaPreview) {
      final segment = <String, dynamic>{
        'type': tramo.tipo.name,
        'description': tramo.descripcion ?? '',
        'duration': tramo.duracionEstimadaSegundos ?? 0,
      };

      if (tramo.distanciaMetros != null) {
        segment['distance'] = tramo.distanciaMetros!.round();
      }

      // Geometría
      if (tramo.geometriaPolilinea != null && tramo.geometriaPolilinea!.isNotEmpty) {
        segment['geometry'] = tramo.geometriaPolilinea!.map((c) => {
          'lat': c.latitud,
          'lng': c.longitud,
        }).toList();
      } else {
        segment['geometry'] = [];
      }

      // Datos específicos por tipo
      switch (tramo.tipo) {
        case TipoTramoViaje.CAMINAR:
          segment['from'] = 'origin'; // Simplificado
          segment['to'] = 'next_stop';
          break;

        case TipoTramoViaje.ESPERAR_BUS:
          segment['at'] = tramo.idParadaOrigenTramoBus ?? 'stop_unknown';
          segment['busLine'] = tramo.nombreLineaBus;
          segment['hasEta'] = selectedRoute.etaProximoBus != null;
          if (selectedRoute.etaProximoBus != null) {
            segment['etaMinutes'] = selectedRoute.etaProximoBus!.minutosParaLlegada;
          }
          break;

        case TipoTramoViaje.VIAJE_EN_BUS:
          segment['from'] = tramo.idParadaOrigenTramoBus ?? 'stop_unknown';
          segment['to'] = tramo.idParadaDestinoTramoBus ?? 'stop_unknown';
          segment['busLine'] = tramo.nombreLineaBus;
          segment['shapeId'] = tramo.shapeId;
          break;
      }

      segments.add(segment);
    }

    // Construir JSON completo
    return {
      'tripId': tripId,
      'name': 'Trip capturado - ${DateTime.now().toString().substring(0, 19)}',
      'capturedAt': DateTime.now().toIso8601String(),
      'origin': {
        'lat': origin.latitud,
        'lng': origin.longitud,
        'name': 'Origen',
      },
      'destination': {
        'lat': destination.latitud,
        'lng': destination.longitud,
        'name': 'Destino',
      },
      'route': {
        'routeId': selectedRoute.idOpcion,
        'recommended': selectedRoute.esRecomendada,
        'totalDuration': selectedRoute.duracionTotalSegundos,
        'totalWalkDistance': selectedRoute.distanciaTotalCaminataMetros,
        'totalWaitTime': selectedRoute.tiempoTotalEsperaBusSegundos,
        'stops': stops,
        'segments': segments,
      },
      if (initialBusPosition != null)
        'initialBusPosition': {
          'lat': initialBusPosition.latitud,
          'lng': initialBusPosition.longitud,
          'capturedAt': DateTime.now().toIso8601String(),
        },
      if (gpsPlayback != null && gpsPlayback.isNotEmpty)
        'gpsPlayback': gpsPlayback,
      if (checkpoints != null && checkpoints.isNotEmpty)
        'checkpoints': checkpoints,
      'expectedBehavior': {
        'totalDuration': selectedRoute.duracionTotalSegundos,
        'stepsExpected': segments.length,
        'shouldComplete': true,
        'description': 'Trip capturado desde la app',
      },
    };
  }
}
