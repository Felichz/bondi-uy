// Trip planning with OpenTripPlanner 2 (GraphQL).
//
// `interpretarPlanOtp` is pure: it converts the raw OTP response into
// [PlannedTrip]. It is used the same way with the real server and with
// responses recorded in fixtures.

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../contract/model.dart';
import '../geo/geo.dart';
import '../ports.dart';

/// URL of OTP's GraphQL endpoint.
///
/// - `--dart-define=OTP_URL=http://...` forces a full URL.
/// - `--dart-define=OTP_TUNNEL_ID=abc123` uses an ngrok tunnel.
/// - Default: the machine's host as seen from the Android emulator.
String otpUrlByDefault() {
  const url = String.fromEnvironment('OTP_URL');
  if (url.isNotEmpty) return url;
  const tunnel = String.fromEnvironment('OTP_TUNNEL_ID');
  if (tunnel.isNotEmpty) {
    return 'https://$tunnel.ngrok-free.app/otp/routers/default/index/graphql';
  }
  return 'http://10.0.2.2:8080/otp/routers/default/index/graphql';
}

const String queryPlanOtp = r'''
query Plan($fromLat: Float!, $fromLon: Float!, $toLat: Float!, $toLon: Float!,
           $date: String!, $time: String!, $n: Int!) {
  plan(from: {lat: $fromLat, lon: $fromLon}, to: {lat: $toLat, lon: $toLon},
       date: $date, time: $time, numItineraries: $n,
       transportModes: [{mode: WALK}, {mode: TRANSIT}]) {
    itineraries {
      startTime endTime duration walkDistance
      legs {
        mode startTime endTime duration distance headsign
        from { name lat lon stop { gtfsId name } }
        to { name lat lon stop { gtfsId name } }
        route { gtfsId shortName longName }
        trip { gtfsId tripHeadsign shapeId }
        legGeometry { points }
        intermediateStops { gtfsId name lat lon }
      }
    }
  }
}
''';

class PlannerOtp implements TripPlanner {
  final String url;
  final http.Client _http;
  final int itineraries;

  PlannerOtp({String? url, http.Client? cliente, this.itineraries = 8})
    : url = url ?? otpUrlByDefault(),
      _http = cliente ?? http.Client();

  @override
  Future<List<PlannedTrip>> plan({
    required Coordinate origin,
    required Coordinate destination,
    required DateTime exit,
  }) async {
    String dos(int n) => n.toString().padLeft(2, '0');
    // OTP reads date/time in the feed's time zone (America/Montevideo,
    // UTC-3, no daylight saving time). Never the device's time zone.
    exit = timeMontevideo(exit);
    final body = jsonEncode({
      'query': queryPlanOtp,
      'variables': {
        'fromLat': origin.lat,
        'fromLon': origin.lng,
        'toLat': destination.lat,
        'toLon': destination.lng,
        'date': '${exit.year}-${dos(exit.month)}-${dos(exit.day)}',
        'time': '${dos(exit.hour)}:${dos(exit.minute)}:${dos(exit.second)}',
        'n': itineraries,
      },
    });
    final http.Response resp;
    try {
      resp = await _http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 25));
    } catch (e) {
      throw ServiceError('otp', e);
    }
    if (resp.statusCode != 200) {
      throw ServiceError('otp', 'HTTP ${resp.statusCode}: ${resp.body}');
    }
    final json =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    if (json['errors'] != null && json['data'] == null) {
      throw ServiceError('otp', json['errors']);
    }
    return interpretPlanOtp(json['data'] as Map<String, dynamic>);
  }
}

/// The same instant expressed as Montevideo "wall clock" time (UTC-3).
DateTime timeMontevideo(DateTime t) {
  final u = t.toUtc().subtract(const Duration(hours: 3));
  return DateTime(u.year, u.month, u.day, u.hour, u.minute, u.second);
}

/// Converts `{plan: {itineraries: [...]}}` into planned trips.
/// Discards itineraries that cannot be represented (no geometry, etc).
List<PlannedTrip> interpretPlanOtp(Map<String, dynamic> data) {
  final plan = data['plan'] as Map<String, dynamic>?;
  final its = (plan?['itineraries'] as List?) ?? const [];
  final res = <PlannedTrip>[];
  for (var i = 0; i < its.length; i++) {
    final v = _interpretItinerary(its[i] as Map<String, dynamic>, i);
    if (v != null) res.add(v);
  }
  return res;
}

PlannedTrip? _interpretItinerary(Map<String, dynamic> it, int index) {
  final jsonLegs =
      (it['legs'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
  if (jsonLegs.isEmpty) return null;

  final legs = <Leg>[];
  final shapes = <String, String>{};
  final signature = StringBuffer();
  var walk = 0.0;
  int? finPrevious;
  final inicioIt = it['startTime'] as int?;

  for (var li = 0; li < jsonLegs.length; li++) {
    final leg = jsonLegs[li];
    final modo = leg['mode'] as String? ?? '';
    final from = _punto(leg['from']);
    final until = _punto(leg['to']);
    if (from == null || until == null) return null;
    final geometry = _geometry(leg, from, until);
    final distanceLeg = (leg['distance'] as num?)?.toDouble() ?? long(geometry);
    final duration = (leg['duration'] as num?)?.round() ?? 0;

    if (modo == 'WALK') {
      walk += distanceLeg;
      // A "walk" of a few meters (transfer at the same stop) is not a
      // step for the user.
      if (distanceLeg < 15 && legs.isNotEmpty) {
        finPrevious = leg['endTime'] as int? ?? finPrevious;
        continue;
      }
      final siguiente = li + 1 < jsonLegs.length ? jsonLegs[li + 1] : null;
      final towardStop =
          (siguiente != null && _esTransport(siguiente['mode']))
              ? _stop(siguiente['from'])
              : null;
      legs.add(
        WalkLeg(
          id: 'c$li',
          geometry: geometry,
          distanceMeters: distanceLeg.round(),
          durationSeconds: duration,
          towardStop: towardStop,
        ),
      );
    } else if (_esTransport(modo)) {
      final route = leg['route'] as Map<String, dynamic>?;
      final line =
          (route?['shortName'] as String?) ?? (route?['longName'] as String?);
      final boarding = _stop(leg['from']);
      final alighting = _stop(leg['to']);
      if (line == null || boarding == null || alighting == null) return null;
      final trip = leg['trip'] as Map<String, dynamic>?;
      final destinationLine =
          (trip?['tripHeadsign'] as String?) ?? (leg['headsign'] as String?);
      final inicioLeg = leg['startTime'] as int?;
      final waitMs =
          (inicioLeg != null)
              ? inicioLeg - (finPrevious ?? inicioIt ?? inicioLeg)
              : 0;

      legs.add(
        WaitLeg(
          id: 'e$li',
          stop: boarding,
          line: line,
          destinationLine: destinationLine,
          waitScheduledSeconds: (waitMs / 1000).round().clamp(0, 1 << 30),
        ),
      );
      final intermediate = <Stop>[
        for (final s in (leg['intermediateStops'] as List?) ?? const [])
          if (_stopOfStop(s as Map<String, dynamic>) case final p?) p,
      ];
      final idBus = 'b$li';
      legs.add(
        BusLeg(
          id: idBus,
          line: line,
          destinationLine: destinationLine,
          boarding: boarding,
          alighting: alighting,
          stopsIntermediate: intermediate,
          geometry: geometry,
          distanceMeters: distanceLeg.round(),
          durationSeconds: duration,
        ),
      );
      final shapeId = trip?['shapeId'] as String?;
      if (shapeId != null && shapeId.isNotEmpty) {
        shapes[idBus] = shapeId.split(':').last;
      }
      signature.write('$line@${boarding.id}>${alighting.id};');
    } else {
      // Modes the app does not represent (train, bike...): the option is discarded.
      return null;
    }
    finPrevious = leg['endTime'] as int? ?? finPrevious;
  }

  if (legs.isEmpty) return null;
  final exitMs = it['startTime'] as int?;
  final arrivalMs = it['endTime'] as int?;
  if (exitMs == null || arrivalMs == null) return null;
  final buses = legs.whereType<BusLeg>().length;

  final option = TripOption(
    id:
        'otp-$index-${signature.isEmpty ? 'caminata' : signature.toString().hashCode.toUnsigned(32).toRadixString(16)}',
    durationSeconds:
        (it['duration'] as num?)?.round() ??
        ((arrivalMs - exitMs) / 1000).round(),
    exit: DateTime.fromMillisecondsSinceEpoch(exitMs),
    arrival: DateTime.fromMillisecondsSinceEpoch(arrivalMs),
    walkMeters: ((it['walkDistance'] as num?)?.toDouble() ?? walk).round(),
    transfers: buses > 0 ? buses - 1 : 0,
    recommended: false,
    legs: legs,
  );
  return PlannedTrip(option, shapeByLeg: shapes);
}

bool _esTransport(Object? modo) =>
    modo == 'BUS' || modo == 'TRANSIT' || modo == 'TROLLEYBUS';

Coordinate? _punto(Object? place) {
  if (place is! Map<String, dynamic>) return null;
  final lat = (place['lat'] as num?)?.toDouble();
  final lon = (place['lon'] as num?)?.toDouble();
  if (lat == null || lon == null) return null;
  return Coordinate(lat, lon);
}

Stop? _stop(Object? place) {
  if (place is! Map<String, dynamic>) return null;
  final c = _punto(place);
  final stop = place['stop'] as Map<String, dynamic>?;
  final gtfsId = stop?['gtfsId'] as String?;
  if (c == null || gtfsId == null) return null;
  return Stop(
    id: gtfsId.split(':').last,
    name: _nameStop(
      (stop?['name'] as String?) ?? (place['name'] as String?) ?? '',
    ),
    coordinate: c,
  );
}

Stop? _stopOfStop(Map<String, dynamic> s) {
  final gtfsId = s['gtfsId'] as String?;
  final lat = (s['lat'] as num?)?.toDouble();
  final lon = (s['lon'] as num?)?.toDouble();
  if (gtfsId == null || lat == null || lon == null) return null;
  return Stop(
    id: gtfsId.split(':').last,
    name: _nameStop(s['name'] as String? ?? ''),
    coordinate: Coordinate(lat, lon),
  );
}

List<Coordinate> _geometry(
  Map<String, dynamic> leg,
  Coordinate from,
  Coordinate until,
) {
  final pts =
      (leg['legGeometry'] as Map<String, dynamic>?)?['points'] as String?;
  if (pts != null && pts.isNotEmpty) {
    final dec = decodePolyline(pts);
    if (dec.length >= 2) return dec;
  }
  return [from, until];
}

/// Montevideo's GTFS names come in "Title Case" with connectors in upper
/// case ("Av 18 De Julio Y Andes"). The connectors are normalized.
String _nameStop(String raw) {
  const lesser = {'De', 'Del', 'La', 'Las', 'Los', 'Y', 'E', 'El'};
  final parts = raw.trim().split(RegExp(r'\s+'));
  return [
    for (var i = 0; i < parts.length; i++)
      i > 0 && lesser.contains(parts[i]) ? parts[i].toLowerCase() : parts[i],
  ].join(' ');
}
