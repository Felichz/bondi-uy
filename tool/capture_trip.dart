// Captura una consulta OTP y la materializa como fixture determinista.
// El fixture contiene todas las opciones devueltas por OTP, el stream de GPS
// sintético del usuario y, opcionalmente, muestras reales de llegadas de la
// API de Montevideo para los buses seleccionados.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

const _defaultOtpUrl =
    'http://localhost:8080/otp/routers/default/index/graphql';
const _mvdTokenUrl =
    'https://mvdapi-auth.montevideo.gub.uy/auth/realms/pci/protocol/openid-connect/token';
const _mvdArrivalsBaseUrl = 'https://api.montevideo.gub.uy/transporteRest';

Future<void> main(List<String> args) async {
  try {
    final config = _CaptureConfig.parse(args);
    if (config.showHelp) {
      _printUsage();
      return;
    }

    final otpClient = _OtpClient(config.otpUrl);
    final rawPlan = await otpClient
        .plan(
          from: config.from,
          to: config.to,
          date: config.date,
          time: config.time,
          itineraries: config.itineraries,
        )
        .whenComplete(otpClient.close);

    final rawItineraries =
        ((rawPlan['plan'] as Map<String, dynamic>?)?['itineraries'] as List?)
            ?.whereType<Map>()
            .cast<Map<String, dynamic>>()
            .toList() ??
        const <Map<String, dynamic>>[];
    if (rawItineraries.isEmpty) {
      throw StateError(
        'OTP no devolvió itinerarios. Verificá que la fecha esté vigente en el GTFS, '
        'que el grafo tenga calles OSM para conectar origen/destino y que el router '
        'contenga servicio de tránsito para ese horario.',
      );
    }

    final options = <Map<String, dynamic>>[];
    for (var index = 0; index < rawItineraries.length; index++) {
      final option = _normalizeOption(rawItineraries[index], index);
      option['replay'] = {
        'userSamples': _generateUserSamples(
          option,
          walkingSpeedMps: config.walkingSpeedMps,
          busSpeedMps: config.busSpeedMps,
          sampleIntervalSeconds: config.userSampleIntervalSeconds,
        ),
        'busPolls': <Map<String, dynamic>>[],
      };
      options.add(option);
    }

    if (config.pollWindowSeconds > 0) {
      final mvdClient = _MontevideoArrivalsClient.fromEnvironment();
      await _captureBusPolls(
        options: options,
        optionIndexes: config.pollOptionIndexes,
        client: mvdClient,
        windowSeconds: config.pollWindowSeconds,
        intervalSeconds: config.pollIntervalSeconds,
      );
      await mvdClient.close();
    }

    final fixture = <String, dynamic>{
      'schemaVersion': 2,
      'request': {
        'origin': config.from.toJson(config.fromName),
        'destination': config.to.toJson(config.toName),
        'date': config.date,
        'time': config.time,
        'itinerariesRequested': config.itineraries,
      },
      'provenance': {
        'capturedAt': DateTime.now().toUtc().toIso8601String(),
        'otpGraphqlUrl': config.otpUrl,
        'montevideoPolling': {
          'enabled': config.pollWindowSeconds > 0,
          'windowSeconds': config.pollWindowSeconds,
          'intervalSeconds': config.pollIntervalSeconds,
        },
        'userReplay': {
          'walkingSpeedMps': config.walkingSpeedMps,
          'busSpeedMps': config.busSpeedMps,
          'sampleIntervalSeconds': config.userSampleIntervalSeconds,
        },
      },
      'rawOtpPlan': rawPlan,
      'options': options,
    };

    final output = File(config.outputPath);
    await output.parent.create(recursive: true);
    await output.writeAsString(
      const JsonEncoder.withIndent('  ').convert(fixture),
    );

    stdout.writeln('Fixture creado: ${output.path}');
    stdout.writeln('Opciones OTP: ${options.length}');
    for (final option in options) {
      final legs = option['legs'] as List<dynamic>;
      final transitLegs =
          legs
              .whereType<Map<String, dynamic>>()
              .where((leg) => leg['isTransit'] == true)
              .length;
      final samples =
          ((option['replay'] as Map<String, dynamic>)['userSamples']
                  as List<dynamic>)
              .length;
      stdout.writeln(
        '  [${option['otpIndex']}] ${option['durationSeconds']}s, '
        '$transitLegs bus(es), $samples muestras GPS de usuario',
      );
    }
  } on _UsageException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln();
    _printUsage();
    exitCode = 64;
  } catch (error, stackTrace) {
    stderr.writeln('Error capturando viaje: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}

class _CaptureConfig {
  final bool showHelp;
  final String otpUrl;
  final _Coordinate from;
  final _Coordinate to;
  final String fromName;
  final String toName;
  final String date;
  final String time;
  final int itineraries;
  final String outputPath;
  final List<int> pollOptionIndexes;
  final int pollWindowSeconds;
  final int pollIntervalSeconds;
  final int userSampleIntervalSeconds;
  final double walkingSpeedMps;
  final double busSpeedMps;

  _CaptureConfig({
    required this.showHelp,
    required this.otpUrl,
    required this.from,
    required this.to,
    required this.fromName,
    required this.toName,
    required this.date,
    required this.time,
    required this.itineraries,
    required this.outputPath,
    required this.pollOptionIndexes,
    required this.pollWindowSeconds,
    required this.pollIntervalSeconds,
    required this.userSampleIntervalSeconds,
    required this.walkingSpeedMps,
    required this.busSpeedMps,
  });

  factory _CaptureConfig.parse(List<String> args) {
    final values = <String, String>{};
    for (var index = 0; index < args.length; index++) {
      final argument = args[index];
      if (!argument.startsWith('--')) {
        throw _UsageException('Argumento inesperado: $argument');
      }
      final equalsIndex = argument.indexOf('=');
      if (equalsIndex > 0) {
        values[argument.substring(2, equalsIndex)] = argument.substring(
          equalsIndex + 1,
        );
        continue;
      }
      final key = argument.substring(2);
      if (key == 'help') {
        values[key] = 'true';
        continue;
      }
      if (index + 1 >= args.length || args[index + 1].startsWith('--')) {
        throw _UsageException('Falta valor para --$key');
      }
      values[key] = args[++index];
    }

    if (values['help'] == 'true') {
      return _CaptureConfig(
        showHelp: true,
        otpUrl: '',
        from: const _Coordinate(0, 0),
        to: const _Coordinate(0, 0),
        fromName: '',
        toName: '',
        date: '',
        time: '',
        itineraries: 0,
        outputPath: '',
        pollOptionIndexes: const [],
        pollWindowSeconds: 0,
        pollIntervalSeconds: 0,
        userSampleIntervalSeconds: 0,
        walkingSpeedMps: 0,
        busSpeedMps: 0,
      );
    }

    String required(String key) {
      final value = values[key];
      if (value == null || value.isEmpty) {
        throw _UsageException('Falta --$key');
      }
      return value;
    }

    int positiveInt(String key, int defaultValue) {
      final value = values[key];
      if (value == null) return defaultValue;
      final parsed = int.tryParse(value);
      if (parsed == null || parsed <= 0) {
        throw _UsageException('--$key debe ser un entero mayor a cero');
      }
      return parsed;
    }

    int nonNegativeInt(String key, int defaultValue) {
      final value = values[key];
      if (value == null) return defaultValue;
      final parsed = int.tryParse(value);
      if (parsed == null || parsed < 0) {
        throw _UsageException('--$key debe ser un entero mayor o igual a cero');
      }
      return parsed;
    }

    double positiveDouble(String key, double defaultValue) {
      final value = values[key];
      if (value == null) return defaultValue;
      final parsed = double.tryParse(value);
      if (parsed == null || parsed <= 0) {
        throw _UsageException('--$key debe ser un número mayor a cero');
      }
      return parsed;
    }

    final pollWindowSeconds = nonNegativeInt('poll-window-seconds', 0);
    final pollOptionsValue = values['poll-options'] ?? '';
    final pollOptions =
        pollOptionsValue.isEmpty
            ? <int>[]
            : pollOptionsValue.split(',').map((value) {
              final parsed = int.tryParse(value.trim());
              if (parsed == null || parsed < 0) {
                throw _UsageException(
                  '--poll-options debe ser una lista de índices: ej. 0,2',
                );
              }
              return parsed;
            }).toList();
    if (pollWindowSeconds > 0 && pollOptions.isEmpty) {
      throw _UsageException(
        'Usar --poll-options 0,2 cuando se indique --poll-window-seconds.',
      );
    }

    return _CaptureConfig(
      showHelp: false,
      otpUrl:
          values['otp-url'] ??
          Platform.environment['OTP_GRAPHQL_URL'] ??
          _defaultOtpUrl,
      from: _Coordinate.parse(required('from')),
      to: _Coordinate.parse(required('to')),
      fromName: values['from-name'] ?? 'Origen',
      toName: values['to-name'] ?? 'Destino',
      date: required('date'),
      time: required('time'),
      itineraries: positiveInt('itineraries', 5),
      outputPath: required('out'),
      pollOptionIndexes: pollOptions,
      pollWindowSeconds: pollWindowSeconds,
      pollIntervalSeconds: positiveInt('poll-interval-seconds', 10),
      userSampleIntervalSeconds: positiveInt('user-sample-seconds', 5),
      walkingSpeedMps: positiveDouble('walking-speed-mps', 1.4),
      busSpeedMps: positiveDouble('bus-speed-mps', 8.3),
    );
  }
}

class _UsageException implements Exception {
  final String message;
  _UsageException(this.message);
}

class _Coordinate {
  final double lat;
  final double lng;

  const _Coordinate(this.lat, this.lng);

  factory _Coordinate.parse(String value) {
    final parts = value.split(',');
    if (parts.length != 2) {
      throw _UsageException('--from y --to deben tener formato lat,lng');
    }
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) {
      throw _UsageException('Coordenadas inválidas: $value');
    }
    return _Coordinate(lat, lng);
  }

  Map<String, dynamic> toJson(String name) => {
    'name': name,
    'lat': lat,
    'lng': lng,
  };

  Map<String, dynamic> toPointJson() => {'lat': lat, 'lng': lng};
}

class _OtpClient {
  final String endpoint;
  final http.Client _client;

  _OtpClient(this.endpoint) : _client = http.Client();

  void close() => _client.close();

  Future<Map<String, dynamic>> plan({
    required _Coordinate from,
    required _Coordinate to,
    required String date,
    required String time,
    required int itineraries,
  }) async {
    const query = r'''
      query PlanRuta(
        $fromLat: Float!, $fromLon: Float!,
        $toLat: Float!, $toLon: Float!,
        $date: String!, $time: String!, $numItineraries: Int!
      ) {
        plan(
          from: { lat: $fromLat, lon: $fromLon },
          to: { lat: $toLat, lon: $toLon },
          date: $date,
          time: $time,
          transportModes: [{ mode: WALK }, { mode: TRANSIT }],
          numItineraries: $numItineraries
        ) {
          itineraries {
            startTime
            endTime
            duration
            walkDistance
            legs {
              mode
              startTime
              endTime
              duration
              distance
              headsign
              from { name lat lon stop { gtfsId name } }
              to { name lat lon stop { gtfsId name } }
              route { gtfsId shortName longName agency { name } }
              trip { gtfsId tripHeadsign shapeId }
              legGeometry { points length }
              intermediateStops { gtfsId name lat lon }
            }
          }
        }
      }
    ''';
    final response = await _client
        .post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'query': query,
            'variables': {
              'fromLat': from.lat,
              'fromLon': from.lng,
              'toLat': to.lat,
              'toLon': to.lng,
              'date': date,
              'time': time,
              'numItineraries': itineraries,
            },
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw StateError(
        'OTP respondió HTTP ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Respuesta OTP inválida: se esperaba un objeto JSON');
    }
    final errors = decoded['errors'];
    if (errors is List && errors.isNotEmpty) {
      throw StateError('OTP GraphQL devolvió errores: ${jsonEncode(errors)}');
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw StateError('OTP GraphQL no devolvió data');
    }
    return data;
  }
}

Map<String, dynamic> _normalizeOption(
  Map<String, dynamic> itinerary,
  int otpIndex,
) {
  final itineraryStart = _asInt(itinerary['startTime']) ?? 0;
  final rawLegs =
      (itinerary['legs'] as List?)
          ?.whereType<Map>()
          .cast<Map<String, dynamic>>()
          .toList() ??
      const <Map<String, dynamic>>[];
  final legs = <Map<String, dynamic>>[];

  for (var legIndex = 0; legIndex < rawLegs.length; legIndex++) {
    final leg = rawLegs[legIndex];
    final mode = (leg['mode'] as String? ?? '').toUpperCase();
    final startTime = _asInt(leg['startTime']) ?? itineraryStart;
    final endTime = _asInt(leg['endTime']) ?? startTime;
    final rawRoute = leg['route'] as Map<String, dynamic>?;
    final rawTrip = leg['trip'] as Map<String, dynamic>?;
    final rawGeometry = leg['legGeometry'] as Map<String, dynamic>?;
    final geometry = _decodePolyline(rawGeometry?['points'] as String? ?? '');
    final from = _normalizePlace(leg['from'] as Map<String, dynamic>?);
    final to = _normalizePlace(leg['to'] as Map<String, dynamic>?);
    final intermediateStops =
        ((leg['intermediateStops'] as List?) ?? const <dynamic>[])
            .whereType<Map>()
            .map((stop) => _normalizeStop(stop.cast<String, dynamic>()))
            .toList();

    legs.add({
      'legIndex': legIndex,
      'mode': mode,
      'isTransit': mode == 'TRANSIT' || mode == 'BUS',
      'startOffsetSeconds': ((startTime - itineraryStart) / 1000).round(),
      'endOffsetSeconds': ((endTime - itineraryStart) / 1000).round(),
      'scheduledDurationSeconds': _asInt(leg['duration']) ?? 0,
      'distanceMeters': _asDouble(leg['distance']) ?? 0.0,
      'headsign': leg['headsign'],
      'from': from,
      'to': to,
      'route':
          rawRoute == null
              ? null
              : {
                'gtfsId': rawRoute['gtfsId'],
                'shortName': rawRoute['shortName'],
                'longName': rawRoute['longName'],
                'agencyName': (rawRoute['agency'] as Map?)?['name'],
              },
      'trip':
          rawTrip == null
              ? null
              : {
                'gtfsId': rawTrip['gtfsId'],
                'headsign': rawTrip['tripHeadsign'],
                'shapeId': rawTrip['shapeId'],
              },
      'geometry': geometry.map((point) => point.toPointJson()).toList(),
      'intermediateStops': intermediateStops,
    });
  }

  final canonical = jsonEncode({
    'duration': itinerary['duration'],
    'legs': legs.map(
      (leg) => {
        'mode': leg['mode'],
        'from': (leg['from'] as Map<String, dynamic>)['stopId'],
        'to': (leg['to'] as Map<String, dynamic>)['stopId'],
        'route': (leg['route'] as Map<String, dynamic>?)?['gtfsId'],
        'trip': (leg['trip'] as Map<String, dynamic>?)?['gtfsId'],
      },
    ).toList(),
  });
  return {
    'id': 'otp-$otpIndex-${_fnv1a64(canonical)}',
    'otpIndex': otpIndex,
    'durationSeconds': _asInt(itinerary['duration']) ?? 0,
    'walkDistanceMeters': _asDouble(itinerary['walkDistance']) ?? 0.0,
    'legs': legs,
  };
}

Map<String, dynamic> _normalizePlace(Map<String, dynamic>? place) {
  final value = place ?? const <String, dynamic>{};
  final stop = value['stop'] as Map<String, dynamic>?;
  return {
    'name': stop?['name'] ?? value['name'] ?? 'Sin nombre',
    'gtfsId': stop?['gtfsId'],
    'stopId': _normalizeStopId(stop?['gtfsId'] as String?),
    'lat': _asDouble(value['lat']),
    'lng': _asDouble(value['lon']),
  };
}

Map<String, dynamic> _normalizeStop(Map<String, dynamic> stop) => {
  'gtfsId': stop['gtfsId'],
  'stopId': _normalizeStopId(stop['gtfsId'] as String?),
  'name': stop['name'] ?? 'Sin nombre',
  'lat': _asDouble(stop['lat']),
  'lng': _asDouble(stop['lon']),
};

String? _normalizeStopId(String? gtfsId) => gtfsId?.split(':').last;

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String _fnv1a64(String value) {
  var hash = 0xcbf29ce484222325;
  for (final byte in utf8.encode(value)) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0xffffffffffffffff;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

List<_Coordinate> _decodePolyline(String encoded) {
  if (encoded.isEmpty) return const <_Coordinate>[];
  final points = <_Coordinate>[];
  var index = 0;
  var latitude = 0;
  var longitude = 0;
  while (index < encoded.length) {
    var result = 0;
    var shift = 0;
    int value;
    do {
      value = encoded.codeUnitAt(index++) - 63;
      result |= (value & 0x1f) << shift;
      shift += 5;
    } while (value >= 0x20 && index < encoded.length);
    latitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

    result = 0;
    shift = 0;
    do {
      value = encoded.codeUnitAt(index++) - 63;
      result |= (value & 0x1f) << shift;
      shift += 5;
    } while (value >= 0x20 && index < encoded.length);
    longitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;
    points.add(_Coordinate(latitude / 1e5, longitude / 1e5));
  }
  return points;
}

List<Map<String, dynamic>> _generateUserSamples(
  Map<String, dynamic> option, {
  required double walkingSpeedMps,
  required double busSpeedMps,
  required int sampleIntervalSeconds,
}) {
  final samples = <Map<String, dynamic>>[];
  final legs = (option['legs'] as List<dynamic>).cast<Map<String, dynamic>>();
  var currentTime = 0;
  Map<String, dynamic>? previousLeg;

  for (final leg in legs) {
    final isTransit = leg['isTransit'] == true;
    if (isTransit) {
      final plannedGap =
          previousLeg == null
              ? _asInt(leg['startOffsetSeconds']) ?? 0
              : math.max(
                0,
                (_asInt(leg['startOffsetSeconds']) ?? 0) -
                    (_asInt(previousLeg['endOffsetSeconds']) ?? 0),
              );
      currentTime = _appendWaitingSamples(
        samples: samples,
        startTime: currentTime,
        durationSeconds: plannedGap,
        point: _coordinateFromJson(leg['from'] as Map<String, dynamic>),
        optionId: option['id'] as String,
        legIndex: leg['legIndex'] as int,
        intervalSeconds: sampleIntervalSeconds,
      );
    }

    final geometry =
        (leg['geometry'] as List<dynamic>)
            .whereType<Map>()
            .map((point) => _coordinateFromJson(point.cast<String, dynamic>()))
            .toList();
    final from = _coordinateFromJson(leg['from'] as Map<String, dynamic>);
    final to = _coordinateFromJson(leg['to'] as Map<String, dynamic>);
    final path = geometry.length >= 2 ? geometry : [from, to];
    final speed = isTransit ? busSpeedMps : walkingSpeedMps;
    currentTime = _appendMovingSamples(
      samples: samples,
      startTime: currentTime,
      path: path,
      speedMps: speed,
      optionId: option['id'] as String,
      legIndex: leg['legIndex'] as int,
      phase: isTransit ? 'onBus' : 'walk',
      intervalSeconds: sampleIntervalSeconds,
    );
    previousLeg = leg;
  }
  return samples;
}

int _appendWaitingSamples({
  required List<Map<String, dynamic>> samples,
  required int startTime,
  required int durationSeconds,
  required _Coordinate point,
  required String optionId,
  required int legIndex,
  required int intervalSeconds,
}) {
  _addSample(
    samples,
    t: startTime,
    point: point,
    speedMps: 0,
    optionId: optionId,
    legIndex: legIndex,
    phase: 'wait',
  );
  for (
    var elapsed = intervalSeconds;
    elapsed < durationSeconds;
    elapsed += intervalSeconds
  ) {
    _addSample(
      samples,
      t: startTime + elapsed,
      point: point,
      speedMps: 0,
      optionId: optionId,
      legIndex: legIndex,
      phase: 'wait',
    );
  }
  if (durationSeconds > 0) {
    _addSample(
      samples,
      t: startTime + durationSeconds,
      point: point,
      speedMps: 0,
      optionId: optionId,
      legIndex: legIndex,
      phase: 'wait',
    );
  }
  return startTime + durationSeconds;
}

int _appendMovingSamples({
  required List<Map<String, dynamic>> samples,
  required int startTime,
  required List<_Coordinate> path,
  required double speedMps,
  required String optionId,
  required int legIndex,
  required String phase,
  required int intervalSeconds,
}) {
  final totalDistance = _pathDistance(path);
  final durationSeconds = math.max(1, (totalDistance / speedMps).ceil());
  _addSample(
    samples,
    t: startTime,
    point: path.first,
    speedMps: speedMps,
    optionId: optionId,
    legIndex: legIndex,
    phase: phase,
  );
  for (
    var elapsed = intervalSeconds;
    elapsed < durationSeconds;
    elapsed += intervalSeconds
  ) {
    _addSample(
      samples,
      t: startTime + elapsed,
      point: _pointAtDistance(path, totalDistance * elapsed / durationSeconds),
      speedMps: speedMps,
      optionId: optionId,
      legIndex: legIndex,
      phase: phase,
    );
  }
  _addSample(
    samples,
    t: startTime + durationSeconds,
    point: path.last,
    speedMps: speedMps,
    optionId: optionId,
    legIndex: legIndex,
    phase: phase,
  );
  return startTime + durationSeconds;
}

void _addSample(
  List<Map<String, dynamic>> samples, {
  required int t,
  required _Coordinate point,
  required double speedMps,
  required String optionId,
  required int legIndex,
  required String phase,
}) {
  if (samples.isNotEmpty &&
      samples.last['t'] == t &&
      samples.last['lat'] == point.lat &&
      samples.last['lng'] == point.lng &&
      samples.last['phase'] == phase) {
    return;
  }
  samples.add({
    't': t,
    'lat': point.lat,
    'lng': point.lng,
    'speedMps': speedMps,
    'optionId': optionId,
    'legIndex': legIndex,
    'phase': phase,
  });
}

_Coordinate _coordinateFromJson(Map<String, dynamic> json) {
  final lat = _asDouble(json['lat']);
  final lng = _asDouble(json['lng']);
  if (lat == null || lng == null) {
    throw StateError(
      'Leg sin coordenadas para generar GPS: ${jsonEncode(json)}',
    );
  }
  return _Coordinate(lat, lng);
}

double _pathDistance(List<_Coordinate> points) {
  var distance = 0.0;
  for (var index = 0; index < points.length - 1; index++) {
    distance += _distance(points[index], points[index + 1]);
  }
  return distance;
}

_Coordinate _pointAtDistance(List<_Coordinate> points, double targetDistance) {
  var accumulated = 0.0;
  for (var index = 0; index < points.length - 1; index++) {
    final segment = _distance(points[index], points[index + 1]);
    if (accumulated + segment >= targetDistance && segment > 0) {
      final ratio = (targetDistance - accumulated) / segment;
      return _Coordinate(
        points[index].lat + (points[index + 1].lat - points[index].lat) * ratio,
        points[index].lng + (points[index + 1].lng - points[index].lng) * ratio,
      );
    }
    accumulated += segment;
  }
  return points.last;
}

double _distance(_Coordinate from, _Coordinate to) {
  const earthRadiusMeters = 6371000.0;
  final lat1 = from.lat * math.pi / 180;
  final lat2 = to.lat * math.pi / 180;
  final deltaLat = (to.lat - from.lat) * math.pi / 180;
  final deltaLng = (to.lng - from.lng) * math.pi / 180;
  final a =
      math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
      math.cos(lat1) *
          math.cos(lat2) *
          math.sin(deltaLng / 2) *
          math.sin(deltaLng / 2);
  return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

class _MontevideoArrivalsClient {
  final String clientId;
  final String clientSecret;
  final http.Client _client;
  String? _token;
  DateTime? _tokenExpiresAt;

  _MontevideoArrivalsClient({
    required this.clientId,
    required this.clientSecret,
  }) : _client = http.Client();

  factory _MontevideoArrivalsClient.fromEnvironment() {
    final clientId = Platform.environment['MVD_API_CLIENT_ID'];
    final clientSecret = Platform.environment['MVD_API_CLIENT_SECRET'];
    if (clientId == null ||
        clientId.isEmpty ||
        clientSecret == null ||
        clientSecret.isEmpty) {
      throw _UsageException(
        'Para hacer polling usar MVD_API_CLIENT_ID y MVD_API_CLIENT_SECRET en el entorno. '
        'No se leen credenciales desde el código ni se escriben en fixtures.',
      );
    }
    return _MontevideoArrivalsClient(
      clientId: clientId,
      clientSecret: clientSecret,
    );
  }

  Future<List<Map<String, dynamic>>> arrivals(String stopId) async {
    final token = await _getToken();
    final response = await _client
        .get(
          Uri.parse('$_mvdArrivalsBaseUrl/siguientesParada/$stopId'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError(
        'Montevideo API respondió HTTP ${response.statusCode} para parada $stopId',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw StateError('Llegadas de parada $stopId no son una lista JSON');
    }
    return decoded
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }

  Future<String> _getToken() async {
    if (_token != null &&
        _tokenExpiresAt != null &&
        DateTime.now().isBefore(_tokenExpiresAt!)) {
      return _token!;
    }
    final response = await _client
        .post(
          Uri.parse(_mvdTokenUrl),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'client_id': clientId,
            'client_secret': clientSecret,
            'grant_type': 'client_credentials',
          },
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError(
        'No se pudo obtener token de Montevideo API: HTTP ${response.statusCode}',
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final token = decoded['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('La respuesta OAuth no contiene access_token');
    }
    final expiresIn = _asInt(decoded['expires_in']) ?? 300;
    _token = token;
    _tokenExpiresAt = DateTime.now().add(
      Duration(seconds: math.max(30, expiresIn - 30)),
    );
    return token;
  }

  Future<void> close() async => _client.close();
}

Future<void> _captureBusPolls({
  required List<Map<String, dynamic>> options,
  required List<int> optionIndexes,
  required _MontevideoArrivalsClient client,
  required int windowSeconds,
  required int intervalSeconds,
}) async {
  final targets = <_PollTarget>[];
  for (final optionIndex in optionIndexes.toSet()) {
    if (optionIndex >= options.length) {
      throw _UsageException(
        'Opción $optionIndex no existe. OTP devolvió ${options.length} opciones.',
      );
    }
    final option = options[optionIndex];
    final legs = (option['legs'] as List<dynamic>).cast<Map<String, dynamic>>();
    for (final leg in legs) {
      if (leg['isTransit'] != true) continue;
      final from = leg['from'] as Map<String, dynamic>;
      final route = leg['route'] as Map<String, dynamic>?;
      final stopId = from['stopId'] as String?;
      final line = route?['shortName'] as String?;
      if (stopId == null || line == null || line.isEmpty) {
        throw StateError('Leg transit sin stopId o línea: ${jsonEncode(leg)}');
      }
      targets.add(
        _PollTarget(option: option, leg: leg, stopId: stopId, line: line),
      );
    }
  }
  if (targets.isEmpty) {
    throw _UsageException(
      'Las opciones seleccionadas no tienen legs de tránsito para sondear.',
    );
  }

  stdout.writeln(
    'Sondeando ${targets.length} leg(s) de bus cada ${intervalSeconds}s por ${windowSeconds}s...',
  );
  for (var elapsed = 0; elapsed <= windowSeconds; elapsed += intervalSeconds) {
    final observedAt = DateTime.now().toUtc().toIso8601String();
    await Future.wait(
      targets.map((target) async {
        final arrivals = await client.arrivals(target.stopId);
        target.record(
          elapsedSeconds: elapsed,
          observedAt: observedAt,
          arrivals: arrivals,
        );
      }),
    );
    if (elapsed + intervalSeconds <= windowSeconds) {
      await Future<void>.delayed(Duration(seconds: intervalSeconds));
    }
  }

  for (final target in targets) {
    final replay = target.option['replay'] as Map<String, dynamic>;
    (replay['busPolls'] as List<Map<String, dynamic>>).addAll(target.samples);
  }
}

class _PollTarget {
  final Map<String, dynamic> option;
  final Map<String, dynamic> leg;
  final String stopId;
  final String line;
  final List<Map<String, dynamic>> samples = [];
  String? _lockedVehicleId;

  _PollTarget({
    required this.option,
    required this.leg,
    required this.stopId,
    required this.line,
  });

  void record({
    required int elapsedSeconds,
    required String observedAt,
    required List<Map<String, dynamic>> arrivals,
  }) {
    final candidates =
        arrivals
            .where(
              (arrival) => (arrival['linea'] as String?)?.trim() == line.trim(),
            )
            .toList();
    Map<String, dynamic>? selected;
    if (_lockedVehicleId != null) {
      selected = candidates.cast<Map<String, dynamic>?>().firstWhere(
        (arrival) => arrival?['idBus']?.toString() == _lockedVehicleId,
        orElse: () => null,
      );
    } else if (candidates.isNotEmpty) {
      candidates.sort((left, right) {
        final leftEta = _asInt(left['minutos']) ?? 1 << 30;
        final rightEta = _asInt(right['minutos']) ?? 1 << 30;
        return leftEta.compareTo(rightEta);
      });
      selected = candidates.first;
      final id = selected['idBus']?.toString();
      if (id != null && id.isNotEmpty) _lockedVehicleId = id;
    }

    final coordinates = selected?['coordinates'];
    final hasCoordinates =
        coordinates is List &&
        coordinates.length == 2 &&
        coordinates[0] is num &&
        coordinates[1] is num;
    samples.add({
      't': elapsedSeconds,
      'observedAt': observedAt,
      'optionId': option['id'],
      'legIndex': leg['legIndex'],
      'boardingStopId': stopId,
      'line': line,
      'found': selected != null,
      'vehicleId': selected?['idBus']?.toString(),
      'operatorId': selected?['idEmpresa']?.toString(),
      'variant': selected?['variante']?.toString(),
      'destination': selected?['descripcionDestino'] ?? selected?['destino'],
      'etaMinutes': _asInt(selected?['minutos']),
      'realtime': selected?['real'] == true,
      if (hasCoordinates) 'lng': (coordinates[0] as num).toDouble(),
      if (hasCoordinates) 'lat': (coordinates[1] as num).toDouble(),
    });
  }
}

void _printUsage() {
  stdout.writeln('''
Uso:
  dart run tool/capture_trip.dart `
    --otp-url <url-graphql> `
    --from <lat,lng> --from-name <texto> `
    --to <lat,lng> --to-name <texto> `
    --date YYYY-MM-DD --time HH:MM:SS `
    --out <archivo.json>

Opcionales:
  --itineraries 5                 Opciones a pedir a OTP (default: 5)
  --walking-speed-mps 1.4         Velocidad adulta normal de caminata
  --bus-speed-mps 8.3             Velocidad para GPS del usuario a bordo
  --user-sample-seconds 5         Cadencia de ubicaciones GPS del usuario
  --poll-options 0,2              Opciones a sondear en Montevideo API
  --poll-window-seconds 300       Ventana real de captura de buses (0 desactiva)
  --poll-interval-seconds 10      Misma cadencia que producción

Para polling de buses configurar MVD_API_CLIENT_ID y MVD_API_CLIENT_SECRET.
OTP_GRAPHQL_URL puede reemplazar --otp-url.
''');
}
