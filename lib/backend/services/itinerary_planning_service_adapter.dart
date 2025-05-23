import 'dart:convert';
import 'dart:math'; // Para math.min y math.max

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../contrato_ui/app_ui_state.dart'; // Para Coordenada, OpcionDeRutaMostrable, TramoViajeMostrable, TipoTramoViaje, etc.
import './montevideo_api_service_adapter.dart'; // Para obtener ETAs
import 'package:intl/intl.dart'; // Para formatear fecha y hora

// TODO: Configurar estas constantes adecuadamente.
const String OTP_BASE_URL = "http://192.168.1.5:8080/otp/routers/default/plan";
const int OTP_NUM_ITINERARIES = 5; // Número de itinerarios a solicitar

// Constantes adaptadas del servicio antiguo
const int MAX_UNIQUE_STOPS_FOR_ETA_LOOKUP =
    3; // Límite de paradas únicas para consultar ETA activamente

// TODO: Mover a un archivo de configuración o constantes
const String OTP_GRAPHQL_ENDPOINT_URL =
    "http://192.168.1.5:8080/otp/routers/default/index/graphql";
// Asegúrate de que esta URL sea accesible desde donde se ejecuta tu app Flutter.
// Para emulador Android, si OTP corre en el host: "http://10.0.2.2:8080/otp/routers/default/index/graphql"
// Para web o dispositivo físico, la IP de la máquina host en la red local: "http://TU_IP_LOCAL:8080/otp/routers/default/index/graphql"

// --- Modelos Internos Simplificados (similares a los del código antiguo para parsear OTP) ---
// Estos pueden evolucionar o ser reemplazados por un parseo más directo a AppUiState.

class _OtpItinerary {
  final int? startTime; // Unix timestamp ms
  final int? endTime; // Unix timestamp ms
  final int? duration; // seconds
  final int? walkTime; // seconds
  final int? transitTime; // seconds
  final int? waitingTime; // seconds
  final double? walkDistance; // meters
  final bool? walkLimitExceeded;
  final int? elevationLost; // meters
  final int? elevationGained; // meters
  final int? transfers;
  final List<_OtpLeg>? legs;

  _OtpItinerary({
    this.startTime,
    this.endTime,
    this.duration,
    this.walkTime,
    this.transitTime,
    this.waitingTime,
    this.walkDistance,
    this.walkLimitExceeded,
    this.elevationLost,
    this.elevationGained,
    this.transfers,
    this.legs,
  });

  factory _OtpItinerary.fromJson(Map<String, dynamic> json) {
    return _OtpItinerary(
      startTime: json['startTime'] as int?,
      endTime: json['endTime'] as int?,
      duration: json['duration'] as int?,
      walkTime: json['walkTime'] as int?,
      transitTime: json['transitTime'] as int?,
      waitingTime: json['waitingTime'] as int?,
      walkDistance: (json['walkDistance'] as num?)?.toDouble(),
      walkLimitExceeded: json['walkLimitExceeded'] as bool?,
      elevationLost: json['elevationLost'] as int?,
      elevationGained: json['elevationGained'] as int?,
      transfers: json['transfers'] as int?,
      legs:
          (json['legs'] as List?)
              ?.map(
                (legJson) => _OtpLeg.fromJson(legJson as Map<String, dynamic>),
              )
              .toList(),
    );
  }
}

class _OtpLeg {
  final int? startTime; // Unix timestamp ms
  final int? endTime; // Unix timestamp ms
  final int? departureDelay; // seconds
  final int? arrivalDelay; // seconds
  final bool? realTime;
  final double? distance; // meters
  final String? mode; // e.g., WALK, BUS
  final String? route; // Route ID for transit (ahora es String?)
  final double? duration; // seconds (cambiado a double?)
  final String? agencyName;
  final String? agencyUrl;
  final int? agencyTimeZoneOffset; // ms
  final String? routeColor; // hex string
  final String? routeTextColor; // hex string
  final bool? interlineWithPreviousLeg;
  final String? tripShortName;
  final String? headsign;
  final String? agencyId;
  final String? tripId;
  final String? routeShortName;
  final String? routeLongName;
  final _OtpLegEndpoint? from;
  final _OtpLegEndpoint? to;
  final _OtpLegGeometry? legGeometry;
  final bool? rentedBike;
  final bool? transitLeg;
  final List<_OtpStep>? steps; // For walk legs
  final String? tripHeadsign; // Nuevo campo parseado de trip.tripHeadsign

  _OtpLeg({
    this.startTime,
    this.endTime,
    this.departureDelay,
    this.arrivalDelay,
    this.realTime,
    this.distance,
    this.mode,
    this.route,
    this.duration, // añadido
    this.agencyName,
    this.agencyUrl,
    this.agencyTimeZoneOffset,
    this.routeColor,
    this.routeTextColor,
    this.interlineWithPreviousLeg,
    this.tripShortName,
    this.headsign,
    this.agencyId,
    this.tripId,
    this.routeShortName,
    this.routeLongName,
    this.from,
    this.to,
    this.legGeometry,
    this.rentedBike,
    this.transitLeg,
    this.steps,
    this.tripHeadsign, // Añadido al constructor
  });

  factory _OtpLeg.fromJson(Map<String, dynamic> json) {
    return _OtpLeg(
      startTime: json['startTime'] as int?,
      endTime: json['endTime'] as int?,
      departureDelay: json['departureDelay'] as int?,
      arrivalDelay: json['arrivalDelay'] as int?,
      realTime: json['realTime'] as bool?,
      distance: (json['distance'] as num?)?.toDouble(),
      mode: json['mode'] as String?,
      route: json['route']?['gtfsId'] as String?,
      duration:
          (json['duration'] as num?)
              ?.toDouble(), // añadido y parseado como double
      agencyName: json['agencyName'] as String?,
      agencyUrl: json['agencyUrl'] as String?,
      agencyTimeZoneOffset: json['agencyTimeZoneOffset'] as int?,
      routeColor: json['routeColor'] as String?,
      routeTextColor: json['routeTextColor'] as String?,
      interlineWithPreviousLeg: json['interlineWithPreviousLeg'] as bool?,
      tripShortName: json['tripShortName'] as String?,
      headsign: json['headsign'] as String?,
      agencyId: json['agencyId'] as String?,
      tripId: json['tripId'] as String?,
      routeShortName: json['route']?['shortName'] as String?,
      routeLongName: json['route']?['longName'] as String?,
      from:
          json['from'] != null
              ? _OtpLegEndpoint.fromJson(json['from'] as Map<String, dynamic>)
              : null,
      to:
          json['to'] != null
              ? _OtpLegEndpoint.fromJson(json['to'] as Map<String, dynamic>)
              : null,
      legGeometry:
          json['legGeometry'] != null
              ? _OtpLegGeometry.fromJson(
                json['legGeometry'] as Map<String, dynamic>,
              )
              : null,
      rentedBike: json['rentedBike'] as bool?,
      transitLeg: json['transitLeg'] as bool?,
      steps:
          (json['steps'] as List?)
              ?.map(
                (stepJson) =>
                    _OtpStep.fromJson(stepJson as Map<String, dynamic>),
              )
              .toList(),
      tripHeadsign:
          json['trip']?['tripHeadsign'] as String?, // Parsear trip.tripHeadsign
    );
  }
}

class _OtpLegEndpoint {
  final String?
  name; // Nombre general del 'place' (puede ser dirección o nombre de parada)
  final double lat;
  final double lon;
  final String? stopId; // GTFS ID de la parada, ej: "agency:stopCode"
  final String?
  stopNameFromOtp; // Nombre específico de la parada (de json['stop']['name'])

  _OtpLegEndpoint({
    this.name,
    required this.lat,
    required this.lon,
    this.stopId,
    this.stopNameFromOtp,
  });

  factory _OtpLegEndpoint.fromJson(Map<String, dynamic> json) {
    String? parsedStopId;
    String? parsedStopName;
    // Verificar si 'stop' existe y es un mapa antes de acceder a sus campos
    if (json['stop'] != null && json['stop'] is Map<String, dynamic>) {
      final stopData = json['stop'] as Map<String, dynamic>;
      parsedStopId = stopData['gtfsId'] as String?;
      parsedStopName = stopData['name'] as String?;
    }

    return _OtpLegEndpoint(
      name: json['name'] as String?, // Nombre general del endpoint
      lat: (json['lat'] as num? ?? 0.0).toDouble(),
      lon: (json['lon'] as num? ?? 0.0).toDouble(),
      stopId: parsedStopId,
      stopNameFromOtp: parsedStopName,
    );
  }
}

class _OtpRoute {
  final String? shortName; // Ej: "121"
  final String? longName; // Ej: "Plaza Independencia - Portones"
  // final String? gtfsId;

  _OtpRoute({this.shortName, this.longName});

  factory _OtpRoute.fromJson(Map<String, dynamic> json) {
    return _OtpRoute(
      shortName: json['shortName'] as String?,
      longName: json['longName'] as String?,
      // gtfsId: json['gtfsId'] as String?,
    );
  }
}

class _OtpTrip {
  // final String? gtfsId;
  final String?
  shapeId; // Para obtener la geometría completa de la línea si es necesario

  _OtpTrip({this.shapeId});

  factory _OtpTrip.fromJson(Map<String, dynamic> json) {
    return _OtpTrip(
      // gtfsId: json['gtfsId'] as String?,
      shapeId: json['shapeId'] as String?,
    );
  }
}

class _OtpLegGeometry {
  final String? points; // Encoded polyline
  final int? length;

  _OtpLegGeometry({this.points, this.length});

  factory _OtpLegGeometry.fromJson(Map<String, dynamic> json) {
    return _OtpLegGeometry(
      points: json['points'] as String?,
      length: json['length'] as int?,
    );
  }

  List<Coordenada>? get pointsDecoded {
    if (points == null || points!.isEmpty) {
      return null;
    }
    try {
      final PolylinePoints polylinePoints = PolylinePoints();
      List<PointLatLng> decoded = polylinePoints.decodePolyline(points!);
      return decoded
          .map((p) => Coordenada(latitud: p.latitude, longitud: p.longitude))
          .toList();
    } catch (e) {
      print(
        "[ItineraryPlanningServiceAdapter_ERROR] Falló decodificación de polilínea: $e",
      );
      return null;
    }
  }
}

class _OtpStep {
  final double? distance;
  final String? relativeDirection; // e.g. RIGHT, LEFT
  final String? streetName;
  final String? absoluteDirection; // e.g. NORTH, SOUTHWEST
  final bool? stayOn;
  final bool? area;
  final bool? bogusName;
  final double? lon;
  final double? lat;
  final List<dynamic>? elevation; // Puede ser vacío o tener números
  final String? exit;
  final String? alerts; // OTP usa 'alerts' en plural en algunos endpoints

  _OtpStep({
    this.distance,
    this.relativeDirection,
    this.streetName,
    this.absoluteDirection,
    this.stayOn,
    this.area,
    this.bogusName,
    this.lon,
    this.lat,
    this.elevation,
    this.exit,
    this.alerts,
  });

  factory _OtpStep.fromJson(Map<String, dynamic> json) {
    return _OtpStep(
      distance: (json['distance'] as num?)?.toDouble(),
      relativeDirection: json['relativeDirection'] as String?,
      streetName: json['streetName'] as String?,
      absoluteDirection: json['absoluteDirection'] as String?,
      stayOn: json['stayOn'] as bool?,
      area: json['area'] as bool?,
      bogusName: json['bogusName'] as bool?,
      lon: (json['lon'] as num?)?.toDouble(),
      lat: (json['lat'] as num?)?.toDouble(),
      elevation: json['elevation'] as List<dynamic>?,
      exit: json['exit'] as String?,
      alerts: json['alerts'] as String?,
    );
  }
}

// --- Interfaz y Clase del Servicio Adaptador ---

abstract class ItineraryPlanningServiceAdapterBase {
  /// Planifica rutas entre un origen y un destino.
  /// Deberá interactuar con un servicio tipo OTP y posiblemente con el MontevideoApiServiceAdapter
  /// para enriquecer los resultados con ETAs y otra información relevante.
  Future<List<OpcionDeRutaMostrable>> planRoute({
    required Coordenada origenCoords,
    String? origenNombre,
    required Coordenada destinoCoords,
    String? destinoNombre,
    DateTime? fechaHoraSalida, // Opcional, si no se provee, se usa ahora
    bool?
    llegarA, // Opcional, si es true, fechaHoraSalida es la hora de llegada deseada
    int? numItinerarios, // Cuántas opciones devolver
  });
}

class ItineraryPlanningServiceAdapter
    implements ItineraryPlanningServiceAdapterBase {
  final MontevideoApiServiceAdapterBase _montevideoApiService;
  int _simpleIdCounter = 0; // Para _generateUniqueId simple
  final PolylinePoints _polylinePoints =
      PolylinePoints(); // Instancia para decodificar

  ItineraryPlanningServiceAdapter(this._montevideoApiService);

  // Helper para encontrar el ETA más relevante
  EtaMostrable? _findMatchingEta(
    List<EtaMostrable> etas,
    String? targetLine,
    String? targetHeadsign,
  ) {
    if (etas.isEmpty || targetLine == null) return null;

    EtaMostrable? lineMatch;
    for (final eta in etas) {
      if (eta.linea.trim().toLowerCase() == targetLine.trim().toLowerCase()) {
        if (targetHeadsign != null &&
            eta.destino != null &&
            eta.destino!.trim().toLowerCase() ==
                targetHeadsign.trim().toLowerCase()) {
          return eta; // Coincidencia exacta de línea y destino
        }
        if (lineMatch == null) {
          lineMatch = eta; // Primera coincidencia solo por línea
        }
      }
    }
    return lineMatch; // Devuelve coincidencia de línea si no hubo con destino, o null
  }

  Future<Map<String, dynamic>?> _fetchOtpGraphQLPlan({
    required Coordenada origenCoords,
    required Coordenada destinoCoords,
    required DateTime fechaHora,
    int numItinerarios = 3,
  }) async {
    final DateFormat dateFormatter = DateFormat('yyyy-MM-dd');
    final DateFormat timeFormatter = DateFormat('HH:mm:ss');

    final String dateFormatted = dateFormatter.format(fechaHora);
    final String timeFormatted = timeFormatter.format(fechaHora);

    // Query adaptada de old/lib/services/otp_service.dart
    // Se usa TRANSIT en lugar de BUS para mayor compatibilidad con OTPv2 estándar.
    // Se solicitan campos adicionales que podrían ser útiles (headsign, stopSequence).
    final String queryString = '''
      query PlanRuta(
        \$fromLat: Float!, \$fromLon: Float!,
        \$toLat: Float!, \$toLon: Float!,
        \$date: String!, \$time: String!,
        \$numItineraries: Int!
      ) {
        plan(
          from: { lat: \$fromLat, lon: \$fromLon },
          to: { lat: \$toLat, lon: \$toLon },
          date: \$date,
          time: \$time,
          transportModes: [
            { mode: WALK },
            { mode: TRANSIT } 
          ],
          numItineraries: \$numItineraries
        ) {
          itineraries {
            startTime
            endTime
            duration # Duración total del itinerario en segundos
            walkDistance
            # transitTime # ELIMINADO
            # waitingTime # ELIMINADO
            # transfers # ELIMINADO
            legs {
              mode
              startTime
              endTime
              duration # Duración del tramo en segundos
              distance
              headsign # OPCIONAL: Añadido para investigacion
              from { 
                name 
                lat 
                lon 
                stop { gtfsId name } 
                departureTime # Tiempo de salida del leg
              }
              to { 
                name 
                lat 
                lon 
                stop { gtfsId name }
                arrivalTime # Tiempo de llegada del leg
              }
              route { 
                gtfsId 
                shortName # ej. "121"
                longName  # ej. "Pza. Independencia - Pocitos"
                agency { name }
              }
              trip { 
                gtfsId 
                tripHeadsign # CAMBIADO: de headsign a tripHeadsign
              }
              legGeometry { 
                points 
                length 
              }
              intermediateStops { # Paradas intermedias en un tramo de bus
                gtfsId
                name
                lat
                lon
              }
            }
          }
        }
      }
    ''';

    final Map<String, dynamic> variables = {
      'fromLat': origenCoords.latitud,
      'fromLon': origenCoords.longitud,
      'toLat': destinoCoords.latitud,
      'toLon': destinoCoords.longitud,
      'date': dateFormatted,
      'time': timeFormatted,
      'numItineraries': numItinerarios,
    };

    print(
      "[ItineraryPlanningServiceAdapter_DEBUG] Enviando query GraphQL a OTP: $OTP_GRAPHQL_ENDPOINT_URL",
    );
    // print("[ItineraryPlanningServiceAdapter_DEBUG] Query: $queryString"); // Descomentar para debugging detallado
    // print("[ItineraryPlanningServiceAdapter_DEBUG] Variables: $variables"); // Descomentar para debugging detallado

    try {
      final response = await http
          .post(
            Uri.parse(OTP_GRAPHQL_ENDPOINT_URL),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'query': queryString, 'variables': variables}),
          )
          .timeout(const Duration(seconds: 20)); // Timeout para la respuesta

      if (response.statusCode == 200) {
        final responseBody = json.decode(
          utf8.decode(response.bodyBytes),
        ); // Usar utf8.decode para caracteres especiales
        if (responseBody['errors'] != null) {
          print(
            "[ItineraryPlanningServiceAdapter_ERROR] Errores en respuesta GraphQL de OTP: ${responseBody['errors']}",
          );
          return null;
        }
        // print("[ItineraryPlanningServiceAdapter_DEBUG] Respuesta GraphQL OTP data: ${responseBody['data']}"); // Debugging
        return responseBody['data'] as Map<String, dynamic>?;
      } else {
        print(
          "[ItineraryPlanningServiceAdapter_ERROR] Error de OTP (HTTP ${response.statusCode}): ${response.body}",
        );
        return null;
      }
    } catch (e, s) {
      print(
        "[ItineraryPlanningServiceAdapter_ERROR] Excepción llamando a OTP: $e\n$s",
      );
      return null;
    }
  }

  List<Coordenada> _decodePolyline(String encodedPolyline) {
    if (encodedPolyline.isEmpty) return [];
    try {
      List<PointLatLng> decodedPoints = _polylinePoints.decodePolyline(
        encodedPolyline,
      );
      return decodedPoints
          .map(
            (point) =>
                Coordenada(latitud: point.latitude, longitud: point.longitude),
          )
          .toList();
    } catch (e) {
      print(
        "[ItineraryPlanningServiceAdapter_ERROR] Error decodificando polilínea: $encodedPolyline, Error: $e",
      );
      return [];
    }
  }

  String _generateUniqueId(String prefix) {
    _simpleIdCounter++;
    return "${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_simpleIdCounter";
  }

  @override
  Future<List<OpcionDeRutaMostrable>> planRoute({
    required Coordenada origenCoords,
    String? origenNombre,
    required Coordenada destinoCoords,
    String? destinoNombre,
    DateTime? fechaHoraSalida,
    bool? llegarA,
    int? numItinerarios,
  }) async {
    print(
      "[ItineraryPlanningServiceAdapter] Planificando ruta de ${origenNombre ?? 'origen'} a ${destinoNombre ?? 'destino'}",
    );

    final DateTime fechaHoraParaOtp = fechaHoraSalida ?? DateTime.now();
    final int numItinerariosFinal = numItinerarios ?? OTP_NUM_ITINERARIES;

    final otpResponse = await _fetchOtpGraphQLPlan(
      origenCoords: origenCoords,
      destinoCoords: destinoCoords,
      fechaHora: fechaHoraParaOtp,
      numItinerarios: numItinerariosFinal,
    );

    if (otpResponse == null ||
        otpResponse['plan'] == null ||
        otpResponse['plan']['itineraries'] == null ||
        (otpResponse['plan']['itineraries'] as List).isEmpty) {
      print(
        "[ItineraryPlanningServiceAdapter_WARN] No se recibieron itinerarios de OTP o hubo un error.",
      );
      return [];
    }

    final List<_OtpItinerary> otpItineraries =
        (otpResponse['plan']['itineraries'] as List)
            .map(
              (itJson) =>
                  _OtpItinerary.fromJson(itJson as Map<String, dynamic>),
            )
            .toList();

    // --- INICIO: Lógica para obtener ETAs ---
    final Set<String> uniqueFirstBusStopIds = {};
    // Mapa para ayudar a encontrar el ETA correcto (línea y destino) para cada parada.
    // Solo guardamos los detalles del primer itinerario que usa una parada como su "primera parada de bus".
    final Map<String, ({String lineName, String? headsign})>
    firstBusLegDetailsByStopId = {};

    for (final otpItinerary in otpItineraries) {
      if (otpItinerary.legs == null) continue;
      for (final leg in otpItinerary.legs!) {
        final esTramoBus =
            leg.mode?.toUpperCase() == "BUS" ||
            leg.mode?.toUpperCase() == "TRANSIT";
        if (esTramoBus) {
          final stopId = leg.from?.stopId?.split(':').last;
          if (stopId != null) {
            uniqueFirstBusStopIds.add(stopId);
            if (!firstBusLegDetailsByStopId.containsKey(stopId)) {
              firstBusLegDetailsByStopId[stopId] = (
                lineName: leg.routeShortName ?? leg.routeLongName ?? '',
                headsign: leg.headsign,
              );
            }
          }
          break; // Solo nos interesa la primera parada de bus de este itinerario
        }
      }
    }

    List<String> stopsToQueryForEta = uniqueFirstBusStopIds.toList();
    if (stopsToQueryForEta.length > MAX_UNIQUE_STOPS_FOR_ETA_LOOKUP) {
      stopsToQueryForEta = stopsToQueryForEta.sublist(
        0,
        MAX_UNIQUE_STOPS_FOR_ETA_LOOKUP,
      );
    }

    final Map<String, List<EtaMostrable>> etasByStopIdCache = {};
    if (stopsToQueryForEta.isNotEmpty) {
      print(
        "[ItineraryPlanningServiceAdapter] Consultando ETAs para las paradas: $stopsToQueryForEta",
      );
    }
    for (final String stopIdStr in stopsToQueryForEta) {
      try {
        final stopDetails = await _montevideoApiService.getStopDetailsWithEta(
          stopIdStr,
          "Parada ID: $stopIdStr",
          Coordenada(latitud: 0, longitud: 0),
        );
        if (stopDetails != null && stopDetails.etas != null) {
          etasByStopIdCache[stopIdStr] = stopDetails.etas!;
        } else {
          etasByStopIdCache[stopIdStr] =
              []; // Cachear lista vacía si no hay datos o error
        }
      } catch (e) {
        print(
          "[ItineraryPlanningServiceAdapter_ERROR] Error obteniendo ETA para parada $stopIdStr: $e",
        );
        etasByStopIdCache[stopIdStr] = []; // Cachear error como lista vacía
      }
    }
    // --- FIN: Lógica para obtener ETAs ---

    final List<OpcionDeRutaMostrable> opcionesDeRuta = [];
    int itineraryOtpIndex = 0;

    for (final _OtpItinerary otpItinerary in otpItineraries) {
      itineraryOtpIndex++;
      if (otpItinerary.legs == null || otpItinerary.legs!.isEmpty) {
        print(
          "[ItineraryPlanningServiceAdapter_WARN] Itinerario OTP $itineraryOtpIndex sin tramos, saltando.",
        );
        continue;
      }

      _OtpLeg? firstBusLegOfCurrentItinerary;
      EtaMostrable? etaForFirstBusLegOfCurrentItinerary;

      // Identificar el primer tramo de bus de este itinerario específico
      for (final leg in otpItinerary.legs!) {
        final esTramoBus =
            leg.mode?.toUpperCase() == "BUS" ||
            leg.mode?.toUpperCase() == "TRANSIT";
        if (esTramoBus) {
          firstBusLegOfCurrentItinerary = leg;
          break;
        }
      }

      if (firstBusLegOfCurrentItinerary != null) {
        final String? stopId =
            firstBusLegOfCurrentItinerary.from?.stopId?.split(':').last;
        final String? lineName =
            firstBusLegOfCurrentItinerary.routeShortName ??
            firstBusLegOfCurrentItinerary.routeLongName;
        final String? headsign =
            firstBusLegOfCurrentItinerary.tripHeadsign ??
            firstBusLegOfCurrentItinerary.headsign;

        if (stopId != null && etasByStopIdCache.containsKey(stopId)) {
          final List<EtaMostrable> etasForStop = etasByStopIdCache[stopId]!;
          etaForFirstBusLegOfCurrentItinerary = _findMatchingEta(
            etasForStop,
            lineName,
            headsign,
          );
          if (etaForFirstBusLegOfCurrentItinerary != null) {
            print(
              "[ItineraryPlanningServiceAdapter] ETA encontrada para itinerario $itineraryOtpIndex, parada $stopId, linea $lineName: ${etaForFirstBusLegOfCurrentItinerary.minutosParaLlegada} min",
            );
          }
        }
      }

      final List<TramoViajeMostrable> tramosDelItinerario = [];
      List<TipoTramoViaje> secuenciaModos = [];
      int distanciaTotalCaminataMetros =
          (otpItinerary.walkDistance ?? 0.0)
              .round(); // Usar walkDistance total si está disponible
      int tiempoTotalEsperaSegundos =
          (otpItinerary.waitingTime ??
              0); // Usar waitingTime total si está disponible
      int tiempoTotalTransitoSegundos = (otpItinerary.transitTime ?? 0);

      // Si walkDistance no está a nivel de itinerario, lo calculamos sumando los tramos.
      // Hacemos lo mismo para el tiempo de espera si no viene calculado por OTP.
      bool calcularDistanciaCaminataManualmente =
          otpItinerary.walkDistance == null;
      bool calcularTiempoEsperaManualmente = otpItinerary.waitingTime == null;
      if (calcularDistanciaCaminataManualmente)
        distanciaTotalCaminataMetros = 0;
      if (calcularTiempoEsperaManualmente) tiempoTotalEsperaSegundos = 0;

      DateTime? tiempoFinTramoAnterior =
          otpItinerary.startTime != null
              ? DateTime.fromMillisecondsSinceEpoch(otpItinerary.startTime!)
              : null;

      for (int i = 0; i < otpItinerary.legs!.length; i++) {
        final _OtpLeg leg = otpItinerary.legs![i];

        if (leg.startTime == null ||
            leg.endTime == null ||
            leg.duration == null ||
            leg.mode == null ||
            leg.from == null ||
            leg.to == null) {
          print(
            "[ItineraryPlanningServiceAdapter_WARN] Tramo OTP $itineraryOtpIndex leg $i incompleto, saltando: ${json.encode(leg)}",
          );
          continue;
        }

        final DateTime legStartTime = DateTime.fromMillisecondsSinceEpoch(
          leg.startTime!,
        );
        final DateTime legEndTime = DateTime.fromMillisecondsSinceEpoch(
          leg.endTime!,
        );
        final int legDurationSec = leg.duration!.round();
        final int legDistanceMet = (leg.distance ?? 0.0).round();

        final Coordenada coordOrigenTramo = Coordenada(
          latitud: leg.from!.lat,
          longitud: leg.from!.lon,
        );
        final Coordenada coordDestinoTramo = Coordenada(
          latitud: leg.to!.lat,
          longitud: leg.to!.lon,
        );

        List<Coordenada> geometria = _decodePolyline(
          leg.legGeometry?.points ?? '',
        );
        if (geometria.isEmpty)
          geometria = [coordOrigenTramo, coordDestinoTramo];

        final esTramoBus =
            leg.mode!.toUpperCase() == "BUS" ||
            leg.mode!.toUpperCase() == "TRANSIT";
        if (esTramoBus &&
            tiempoFinTramoAnterior != null &&
            tiempoFinTramoAnterior.isBefore(legStartTime)) {
          final int esperaDuration =
              legStartTime.difference(tiempoFinTramoAnterior).inSeconds;
          if (esperaDuration > 5) {
            tramosDelItinerario.add(
              TramoViajeMostrable(
                idTramo: _generateUniqueId("wait${itineraryOtpIndex}_$i"),
                tipo: TipoTramoViaje.ESPERAR_BUS,
                posicionPunto: coordOrigenTramo,
                descripcion:
                    "Esperar en ${leg.from?.stopNameFromOtp ?? leg.from?.name ?? leg.from?.stopId ?? 'parada'}",
                duracionEstimadaSegundos: esperaDuration,
                distanciaMetros: 0,
                nombreLineaBus: leg.routeShortName ?? leg.routeLongName,
                idParadaOrigenTramoBus: leg.from?.stopId?.split(':').last,
                nombreParadaOrigen:
                    leg.from?.stopNameFromOtp ??
                    leg.from?.name ??
                    leg.from?.stopId,
              ),
            );
            secuenciaModos.add(TipoTramoViaje.ESPERAR_BUS);
            if (calcularTiempoEsperaManualmente)
              tiempoTotalEsperaSegundos += esperaDuration;
          }
        }
        tiempoFinTramoAnterior = legEndTime;

        if (leg.mode!.toUpperCase() == "WALK") {
          tramosDelItinerario.add(
            TramoViajeMostrable(
              idTramo: _generateUniqueId("walk${itineraryOtpIndex}_$i"),
              tipo: TipoTramoViaje.CAMINAR,
              geometriaPolilinea: geometria,
              descripcion:
                  "Caminar hacia ${leg.to?.stopNameFromOtp ?? leg.to?.name ?? 'destino'}",
              duracionEstimadaSegundos: legDurationSec,
              distanciaMetros: legDistanceMet,
            ),
          );
          secuenciaModos.add(TipoTramoViaje.CAMINAR);
          if (calcularDistanciaCaminataManualmente)
            distanciaTotalCaminataMetros += legDistanceMet;
        } else if (esTramoBus) {
          String? idParadaOrigenNorm = leg.from?.stopId?.split(':').last;
          String? idParadaDestinoNorm = leg.to?.stopId?.split(':').last;

          int? minutosLlegadaBusTramo;
          bool? esTiempoRealTramo;
          Coordenada? posicionBusTramo;

          // Si este es el primer tramo de bus del itinerario Y tenemos un ETA para él
          if (leg == firstBusLegOfCurrentItinerary &&
              etaForFirstBusLegOfCurrentItinerary != null) {
            minutosLlegadaBusTramo =
                etaForFirstBusLegOfCurrentItinerary.minutosParaLlegada;
            esTiempoRealTramo =
                etaForFirstBusLegOfCurrentItinerary.esTiempoReal;
            posicionBusTramo = etaForFirstBusLegOfCurrentItinerary.posicionBus;
          }

          tramosDelItinerario.add(
            TramoViajeMostrable(
              idTramo: _generateUniqueId("bus${itineraryOtpIndex}_$i"),
              tipo: TipoTramoViaje.VIAJE_EN_BUS,
              geometriaPolilinea: geometria,
              descripcion:
                  "Bus ${leg.routeShortName ?? leg.routeLongName ?? '-'} hacia ${leg.tripHeadsign ?? leg.headsign ?? leg.to?.stopNameFromOtp ?? leg.to?.name ?? 'destino'}",
              duracionEstimadaSegundos: legDurationSec,
              distanciaMetros: legDistanceMet,
              nombreLineaBus: leg.routeShortName ?? leg.routeLongName,
              destinoFinalDelBus: leg.tripHeadsign ?? leg.headsign,
              idParadaOrigenTramoBus: idParadaOrigenNorm,
              nombreParadaOrigen:
                  leg.from?.stopNameFromOtp ??
                  leg.from?.name ??
                  leg.from?.stopId,
              coordenadasParadaOrigen: coordOrigenTramo,
              idParadaDestinoTramoBus: idParadaDestinoNorm,
              nombreParadaDestino:
                  leg.to?.stopNameFromOtp ?? leg.to?.name ?? leg.to?.stopId,
              coordenadasParadaDestino: coordDestinoTramo,
              // --- Campos de ETA para el primer bus ---
              minutosEstimadosLlegadaBus: minutosLlegadaBusTramo,
              esTiempoRealBus: esTiempoRealTramo,
              posicionActualBus: posicionBusTramo,
            ),
          );
          secuenciaModos.add(TipoTramoViaje.VIAJE_EN_BUS);
        }
      }

      if (tramosDelItinerario.isEmpty) {
        print(
          "[ItineraryPlanningServiceAdapter_WARN] Itinerario OTP $itineraryOtpIndex no generó tramos mostrables, saltando.",
        );
        continue;
      }

      final DateTime horaLlegadaFinal =
          otpItinerary.endTime != null
              ? DateTime.fromMillisecondsSinceEpoch(otpItinerary.endTime!)
              : (otpItinerary.startTime != null && otpItinerary.duration != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                    otpItinerary.startTime!,
                  ).add(Duration(seconds: otpItinerary.duration!))
                  : DateTime.now()); // Fallback muy básico

      int duracionTotalCalculadaSeg = tramosDelItinerario.fold(
        0,
        (sum, tramo) => sum + tramo.duracionEstimadaSegundos,
      );

      // Calcular número de transbordos manualmente
      int numeroDeTransbordosCalculado = 0;
      int tramosDeBusEnItinerario =
          otpItinerary.legs!
              .where(
                (leg) =>
                    leg.mode?.toUpperCase() == "BUS" ||
                    leg.mode?.toUpperCase() == "TRANSIT",
              )
              .length;
      if (tramosDeBusEnItinerario > 1) {
        numeroDeTransbordosCalculado = tramosDeBusEnItinerario - 1;
      }

      opcionesDeRuta.add(
        OpcionDeRutaMostrable(
          idOpcion: _generateUniqueId("opt${itineraryOtpIndex}"),
          duracionTotalSegundos:
              otpItinerary.duration ?? duracionTotalCalculadaSeg,
          horaLlegadaEstimada: horaLlegadaFinal,
          secuenciaModosIconos:
              secuenciaModos.isNotEmpty
                  ? secuenciaModos
                  : [TipoTramoViaje.CAMINAR],
          distanciaTotalCaminataMetros: distanciaTotalCaminataMetros,
          tiempoTotalEsperaBusSegundos: tiempoTotalEsperaSegundos,
          costoEstimadoViaje: null,
          esRecomendada: opcionesDeRuta.isEmpty,
          score:
              100 -
              (numeroDeTransbordosCalculado) *
                  15 - // Usar transbordos calculados
              (itineraryOtpIndex * 5) -
              (duracionTotalCalculadaSeg ~/
                  600), // Penalizar transbordos, orden y duración
          tramosParaPreview: tramosDelItinerario,
          etaProximoBus: etaForFirstBusLegOfCurrentItinerary,
          // advertenciaPrincipal: null, // TODO: Lógica para advertencias (ej. caminata excesiva basada en distanciaTotalCaminataMetros)
        ),
      );
    }

    // Ordenar por score (mayor es mejor)
    opcionesDeRuta.sort((a, b) => b.score.compareTo(a.score));
    // Reasignar esRecomendada a la mejor después de ordenar
    if (opcionesDeRuta.isNotEmpty) {
      final mejorOpcion = opcionesDeRuta.first;
      opcionesDeRuta[0] = mejorOpcion.copyWith(esRecomendada: true);
      for (int i = 1; i < opcionesDeRuta.length; i++) {
        if (opcionesDeRuta[i].esRecomendada) {
          opcionesDeRuta[i] = opcionesDeRuta[i].copyWith(esRecomendada: false);
        }
      }
    }

    print(
      "[ItineraryPlanningServiceAdapter] ${opcionesDeRuta.length} opciones de ruta procesadas y ordenadas desde OTP.",
    );
    return opcionesDeRuta;
  }
}

// Provider
final itineraryPlanningServiceProvider =
    Provider<ItineraryPlanningServiceAdapterBase>((ref) {
      final montevideoApiService = ref.watch(montevideoApiServiceProvider);
      return ItineraryPlanningServiceAdapter(montevideoApiService);
    });
