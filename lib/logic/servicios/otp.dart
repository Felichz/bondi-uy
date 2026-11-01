// Planificación de viajes con OpenTripPlanner 2 (GraphQL).
//
// `interpretarPlanOtp` es puro: convierte la respuesta cruda de OTP en
// [ViajePlanificado]. Se usa igual con el servidor real y con respuestas
// grabadas en fixtures.

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../contract/modelo.dart';
import '../geo/geo.dart';
import '../puertos.dart';

/// URL del endpoint GraphQL de OTP.
///
/// - `--dart-define=OTP_URL=http://...` fuerza una URL completa.
/// - `--dart-define=OTP_TUNNEL_ID=abc123` usa un túnel ngrok.
/// - Por defecto: el host de la máquina visto desde el emulador Android.
String otpUrlPorDefecto() {
  const url = String.fromEnvironment('OTP_URL');
  if (url.isNotEmpty) return url;
  const tunel = String.fromEnvironment('OTP_TUNNEL_ID');
  if (tunel.isNotEmpty) {
    return 'https://$tunel.ngrok-free.app/otp/routers/default/index/graphql';
  }
  return 'http://10.0.2.2:8080/otp/routers/default/index/graphql';
}

const String consultaPlanOtp = r'''
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

class PlanificadorOtp implements PlanificadorViajes {
  final String url;
  final http.Client _http;
  final int itinerarios;

  PlanificadorOtp({String? url, http.Client? cliente, this.itinerarios = 8})
    : url = url ?? otpUrlPorDefecto(),
      _http = cliente ?? http.Client();

  @override
  Future<List<ViajePlanificado>> planificar({
    required Coordenada origen,
    required Coordenada destino,
    required DateTime salida,
  }) async {
    String dos(int n) => n.toString().padLeft(2, '0');
    // OTP interpreta fecha/hora en la zona del feed (America/Montevideo,
    // UTC-3 sin horario de verano). Nunca la zona del dispositivo.
    salida = horaMontevideo(salida);
    final body = jsonEncode({
      'query': consultaPlanOtp,
      'variables': {
        'fromLat': origen.lat,
        'fromLon': origen.lng,
        'toLat': destino.lat,
        'toLon': destino.lng,
        'date': '${salida.year}-${dos(salida.month)}-${dos(salida.day)}',
        'time':
            '${dos(salida.hour)}:${dos(salida.minute)}:${dos(salida.second)}',
        'n': itinerarios,
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
      throw ErrorServicio('otp', e);
    }
    if (resp.statusCode != 200) {
      throw ErrorServicio('otp', 'HTTP ${resp.statusCode}: ${resp.body}');
    }
    final json =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    if (json['errors'] != null && json['data'] == null) {
      throw ErrorServicio('otp', json['errors']);
    }
    return interpretarPlanOtp(json['data'] as Map<String, dynamic>);
  }
}

/// El mismo instante expresado como "hora de pared" de Montevideo (UTC-3).
DateTime horaMontevideo(DateTime t) {
  final u = t.toUtc().subtract(const Duration(hours: 3));
  return DateTime(u.year, u.month, u.day, u.hour, u.minute, u.second);
}

/// Convierte `{plan: {itineraries: [...]}}` en viajes planificados.
/// Descarta itinerarios que no se pueden representar (sin geometría, etc).
List<ViajePlanificado> interpretarPlanOtp(Map<String, dynamic> data) {
  final plan = data['plan'] as Map<String, dynamic>?;
  final its = (plan?['itineraries'] as List?) ?? const [];
  final res = <ViajePlanificado>[];
  for (var i = 0; i < its.length; i++) {
    final v = _interpretarItinerario(its[i] as Map<String, dynamic>, i);
    if (v != null) res.add(v);
  }
  return res;
}

ViajePlanificado? _interpretarItinerario(Map<String, dynamic> it, int indice) {
  final legs = (it['legs'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
  if (legs.isEmpty) return null;

  final tramos = <Tramo>[];
  final shapes = <String, String>{};
  final firma = StringBuffer();
  var caminata = 0.0;
  int? finPrevio;
  final inicioIt = it['startTime'] as int?;

  for (var li = 0; li < legs.length; li++) {
    final leg = legs[li];
    final modo = leg['mode'] as String? ?? '';
    final desde = _punto(leg['from']);
    final hasta = _punto(leg['to']);
    if (desde == null || hasta == null) return null;
    final geometria = _geometria(leg, desde, hasta);
    final distanciaLeg =
        (leg['distance'] as num?)?.toDouble() ?? largo(geometria);
    final duracion = (leg['duration'] as num?)?.round() ?? 0;

    if (modo == 'WALK') {
      caminata += distanciaLeg;
      // Un "caminar" de pocos metros (trasbordo en la misma parada) no es un
      // paso para el usuario.
      if (distanciaLeg < 15 && tramos.isNotEmpty) {
        finPrevio = leg['endTime'] as int? ?? finPrevio;
        continue;
      }
      final siguiente = li + 1 < legs.length ? legs[li + 1] : null;
      final haciaParada =
          (siguiente != null && _esTransporte(siguiente['mode']))
              ? _parada(siguiente['from'])
              : null;
      tramos.add(
        TramoCaminar(
          id: 'c$li',
          geometria: geometria,
          distanciaMetros: distanciaLeg.round(),
          duracionSegundos: duracion,
          haciaParada: haciaParada,
        ),
      );
    } else if (_esTransporte(modo)) {
      final route = leg['route'] as Map<String, dynamic>?;
      final linea =
          (route?['shortName'] as String?) ?? (route?['longName'] as String?);
      final subida = _parada(leg['from']);
      final bajada = _parada(leg['to']);
      if (linea == null || subida == null || bajada == null) return null;
      final trip = leg['trip'] as Map<String, dynamic>?;
      final destinoLinea =
          (trip?['tripHeadsign'] as String?) ?? (leg['headsign'] as String?);
      final inicioLeg = leg['startTime'] as int?;
      final esperaMs =
          (inicioLeg != null)
              ? inicioLeg - (finPrevio ?? inicioIt ?? inicioLeg)
              : 0;

      tramos.add(
        TramoEsperar(
          id: 'e$li',
          parada: subida,
          linea: linea,
          destinoLinea: destinoLinea,
          esperaProgramadaSegundos: (esperaMs / 1000).round().clamp(0, 1 << 30),
        ),
      );
      final intermedias = <Parada>[
        for (final s in (leg['intermediateStops'] as List?) ?? const [])
          if (_paradaDeStop(s as Map<String, dynamic>) case final p?) p,
      ];
      final idBus = 'b$li';
      tramos.add(
        TramoBus(
          id: idBus,
          linea: linea,
          destinoLinea: destinoLinea,
          subida: subida,
          bajada: bajada,
          paradasIntermedias: intermedias,
          geometria: geometria,
          distanciaMetros: distanciaLeg.round(),
          duracionSegundos: duracion,
        ),
      );
      final shapeId = trip?['shapeId'] as String?;
      if (shapeId != null && shapeId.isNotEmpty) {
        shapes[idBus] = shapeId.split(':').last;
      }
      firma.write('$linea@${subida.id}>${bajada.id};');
    } else {
      // Modos que la app no representa (tren, bici...): se descarta la opción.
      return null;
    }
    finPrevio = leg['endTime'] as int? ?? finPrevio;
  }

  if (tramos.isEmpty) return null;
  final salidaMs = it['startTime'] as int?;
  final llegadaMs = it['endTime'] as int?;
  if (salidaMs == null || llegadaMs == null) return null;
  final buses = tramos.whereType<TramoBus>().length;

  final opcion = OpcionViaje(
    id:
        'otp-$indice-${firma.isEmpty ? 'caminata' : firma.toString().hashCode.toUnsigned(32).toRadixString(16)}',
    duracionSegundos:
        (it['duration'] as num?)?.round() ??
        ((llegadaMs - salidaMs) / 1000).round(),
    salida: DateTime.fromMillisecondsSinceEpoch(salidaMs),
    llegada: DateTime.fromMillisecondsSinceEpoch(llegadaMs),
    caminataMetros:
        ((it['walkDistance'] as num?)?.toDouble() ?? caminata).round(),
    transbordos: buses > 0 ? buses - 1 : 0,
    recomendada: false,
    tramos: tramos,
  );
  return ViajePlanificado(opcion, shapePorTramo: shapes);
}

bool _esTransporte(Object? modo) =>
    modo == 'BUS' || modo == 'TRANSIT' || modo == 'TROLLEYBUS';

Coordenada? _punto(Object? lugar) {
  if (lugar is! Map<String, dynamic>) return null;
  final lat = (lugar['lat'] as num?)?.toDouble();
  final lon = (lugar['lon'] as num?)?.toDouble();
  if (lat == null || lon == null) return null;
  return Coordenada(lat, lon);
}

Parada? _parada(Object? lugar) {
  if (lugar is! Map<String, dynamic>) return null;
  final c = _punto(lugar);
  final stop = lugar['stop'] as Map<String, dynamic>?;
  final gtfsId = stop?['gtfsId'] as String?;
  if (c == null || gtfsId == null) return null;
  return Parada(
    id: gtfsId.split(':').last,
    nombre: _nombreParada(
      (stop?['name'] as String?) ?? (lugar['name'] as String?) ?? '',
    ),
    coordenada: c,
  );
}

Parada? _paradaDeStop(Map<String, dynamic> s) {
  final gtfsId = s['gtfsId'] as String?;
  final lat = (s['lat'] as num?)?.toDouble();
  final lon = (s['lon'] as num?)?.toDouble();
  if (gtfsId == null || lat == null || lon == null) return null;
  return Parada(
    id: gtfsId.split(':').last,
    nombre: _nombreParada(s['name'] as String? ?? ''),
    coordenada: Coordenada(lat, lon),
  );
}

List<Coordenada> _geometria(
  Map<String, dynamic> leg,
  Coordenada desde,
  Coordenada hasta,
) {
  final pts =
      (leg['legGeometry'] as Map<String, dynamic>?)?['points'] as String?;
  if (pts != null && pts.isNotEmpty) {
    final dec = decodificarPolilinea(pts);
    if (dec.length >= 2) return dec;
  }
  return [desde, hasta];
}

/// Los nombres del GTFS de Montevideo vienen en "Title Case" con conectores en
/// mayúscula ("Av 18 De Julio Y Andes"). Se normalizan los conectores.
String _nombreParada(String crudo) {
  const menores = {'De', 'Del', 'La', 'Las', 'Los', 'Y', 'E', 'El'};
  final partes = crudo.trim().split(RegExp(r'\s+'));
  return [
    for (var i = 0; i < partes.length; i++)
      i > 0 && menores.contains(partes[i])
          ? partes[i].toLowerCase()
          : partes[i],
  ].join(' ');
}
