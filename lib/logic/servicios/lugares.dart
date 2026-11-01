// Sugerencias de lugares (autocompletado), limitadas a Montevideo.
//
// - Por defecto: Photon (OSM, sin clave).
// - Si se configura `MAPBOX_TOKEN` (--dart-define), Mapbox Geocoding v5.

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../contract/modelo.dart';
import '../puertos.dart';

const _mapboxToken = String.fromEnvironment('MAPBOX_TOKEN');

/// Centro de Montevideo, sesgo por defecto de las búsquedas.
const centroMontevideo = Coordenada(-34.9011, -56.1645);

/// Caja de Montevideo y alrededores: oeste, sur, este, norte.
const _bbox = '-56.45,-34.95,-55.95,-34.70';

BuscadorLugares buscadorLugaresPorDefecto({http.Client? cliente}) =>
    _mapboxToken.isNotEmpty
        ? LugaresMapbox(token: _mapboxToken, cliente: cliente)
        : LugaresPhoton(cliente: cliente);

class LugaresPhoton implements BuscadorLugares {
  final http.Client _http;
  LugaresPhoton({http.Client? cliente}) : _http = cliente ?? http.Client();

  @override
  Future<List<Lugar>> sugerencias(String texto, {Coordenada? cerca}) async {
    final q = texto.trim();
    if (q.isEmpty) return const [];
    final sesgo = cerca ?? centroMontevideo;
    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': q,
      'lat': '${sesgo.lat}',
      'lon': '${sesgo.lng}',
      'limit': '6',
      'bbox': _bbox,
    });
    final json = await _getJson(_http, uri, 'photon');
    return interpretarPhoton(json);
  }
}

List<Lugar> interpretarPhoton(Map<String, dynamic> json) {
  final res = <Lugar>[];
  final vistos = <String>{};
  for (final f in (json['features'] as List?) ?? const []) {
    if (f is! Map<String, dynamic>) continue;
    final p = f['properties'] as Map<String, dynamic>? ?? const {};
    final coords = (f['geometry'] as Map?)?['coordinates'] as List?;
    if (coords == null || coords.length != 2) continue;
    final calle = p['street'] as String?;
    final numero = p['housenumber']?.toString();
    var nombre = (p['name'] as String?)?.trim() ?? '';
    if (nombre.isEmpty && calle != null) {
      nombre = numero != null ? '$calle $numero' : calle;
    }
    if (nombre.isEmpty) continue;
    final detalle = [
      if (p['name'] != null && calle != null)
        numero != null ? '$calle $numero' : calle,
      p['district'] ?? p['locality'],
      p['city'],
    ].whereType<String>().where((s) => s != nombre).toSet().take(2).join(', ');
    final clave = '$nombre|$detalle';
    if (!vistos.add(clave)) continue;
    res.add(
      Lugar(
        id: '${p['osm_type']}${p['osm_id']}',
        nombre: nombre,
        detalle: detalle.isEmpty ? null : detalle,
        coordenada: Coordenada(
          (coords[1] as num).toDouble(),
          (coords[0] as num).toDouble(),
        ),
      ),
    );
  }
  return res;
}

class LugaresMapbox implements BuscadorLugares {
  final http.Client _http;
  final String token;

  LugaresMapbox({required this.token, http.Client? cliente})
    : _http = cliente ?? http.Client();

  @override
  Future<List<Lugar>> sugerencias(String texto, {Coordenada? cerca}) async {
    final q = texto.trim();
    if (q.isEmpty) return const [];
    final sesgo = cerca ?? centroMontevideo;
    final uri = Uri.https(
      'api.mapbox.com',
      '/geocoding/v5/mapbox.places/${Uri.encodeComponent(q)}.json',
      {
        'access_token': token,
        'country': 'uy',
        'language': 'es',
        'autocomplete': 'true',
        'limit': '6',
        'proximity': '${sesgo.lng},${sesgo.lat}',
        'bbox': _bbox,
      },
    );
    return interpretarGeocodingMapbox(
      await _getJson(_http, uri, 'mapbox-geocoding'),
    );
  }
}

List<Lugar> interpretarGeocodingMapbox(Map<String, dynamic> json) {
  final res = <Lugar>[];
  for (final f in (json['features'] as List?) ?? const []) {
    if (f is! Map<String, dynamic>) continue;
    final centro = f['center'] as List?;
    if (centro == null || centro.length != 2) continue;
    final texto = (f['text'] as String?)?.trim() ?? '';
    final numero = f['address']?.toString();
    final nombre = numero != null ? '$texto $numero' : texto;
    if (nombre.isEmpty) continue;
    final ctx = <String>[
      for (final c in (f['context'] as List?) ?? const [])
        if (c is Map && _esContextoUtil(c['id']?.toString()))
          c['text'].toString(),
    ];
    res.add(
      Lugar(
        id: f['id']?.toString() ?? nombre,
        nombre: nombre,
        detalle: ctx.isEmpty ? null : ctx.take(2).join(', '),
        coordenada: Coordenada(
          (centro[1] as num).toDouble(),
          (centro[0] as num).toDouble(),
        ),
      ),
    );
  }
  return res;
}

bool _esContextoUtil(String? id) =>
    id != null &&
    (id.startsWith('neighborhood') ||
        id.startsWith('locality') ||
        id.startsWith('place'));

Future<Map<String, dynamic>> _getJson(
  http.Client cliente,
  Uri uri,
  String servicio,
) async {
  final http.Response resp;
  try {
    resp = await cliente
        .get(uri, headers: {'User-Agent': 'BondiUY/1.0 (app de transporte)'})
        .timeout(const Duration(seconds: 8));
  } catch (e) {
    throw ErrorServicio(servicio, e);
  }
  if (resp.statusCode != 200) {
    throw ErrorServicio(servicio, 'HTTP ${resp.statusCode}');
  }
  return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
}
