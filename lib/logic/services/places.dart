// Place suggestions (autocomplete), limited to Montevideo.
//
// - Default: Photon (OSM, no key).
// - If `MAPBOX_TOKEN` is configured (--dart-define), Mapbox Geocoding v5.

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../contract/model.dart';
import '../ports.dart';

const _mapboxToken = String.fromEnvironment('MAPBOX_TOKEN');

/// Center of Montevideo, the default bias for searches.
const centerMontevideo = Coordinate(-34.9011, -56.1645);

/// Bounding box of Montevideo and its surroundings: west, south, east, north.
const _bbox = '-56.45,-34.95,-55.95,-34.70';

PlaceSearcher searcherPlacesByDefault({http.Client? cliente}) =>
    _mapboxToken.isNotEmpty
        ? MapboxPlaces(token: _mapboxToken, cliente: cliente)
        : PhotonPlaces(cliente: cliente);

class PhotonPlaces implements PlaceSearcher {
  final http.Client _http;
  PhotonPlaces({http.Client? cliente}) : _http = cliente ?? http.Client();

  @override
  Future<List<Place>> suggestions(String text, {Coordinate? near}) async {
    final q = text.trim();
    if (q.isEmpty) return const [];
    final bias = near ?? centerMontevideo;
    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': q,
      'lat': '${bias.lat}',
      'lon': '${bias.lng}',
      'limit': '6',
      'bbox': _bbox,
    });
    final json = await _getJson(_http, uri, 'photon');
    return interpretarPhoton(json);
  }
}

List<Place> interpretarPhoton(Map<String, dynamic> json) {
  final res = <Place>[];
  final seen = <String>{};
  for (final f in (json['features'] as List?) ?? const []) {
    if (f is! Map<String, dynamic>) continue;
    final p = f['properties'] as Map<String, dynamic>? ?? const {};
    final coords = (f['geometry'] as Map?)?['coordinates'] as List?;
    if (coords == null || coords.length != 2) continue;
    final street = p['street'] as String?;
    final numero = p['housenumber']?.toString();
    var name = (p['name'] as String?)?.trim() ?? '';
    if (name.isEmpty && street != null) {
      name = numero != null ? '$street $numero' : street;
    }
    if (name.isEmpty) continue;
    final detail = [
      if (p['name'] != null && street != null)
        numero != null ? '$street $numero' : street,
      p['district'] ?? p['locality'],
      p['city'],
    ].whereType<String>().where((s) => s != name).toSet().take(2).join(', ');
    final clave = '$name|$detail';
    if (!seen.add(clave)) continue;
    res.add(
      Place(
        id: '${p['osm_type']}${p['osm_id']}',
        name: name,
        detail: detail.isEmpty ? null : detail,
        coordinate: Coordinate(
          (coords[1] as num).toDouble(),
          (coords[0] as num).toDouble(),
        ),
      ),
    );
  }
  return res;
}

class MapboxPlaces implements PlaceSearcher {
  final http.Client _http;
  final String token;

  MapboxPlaces({required this.token, http.Client? cliente})
    : _http = cliente ?? http.Client();

  @override
  Future<List<Place>> suggestions(String text, {Coordinate? near}) async {
    final q = text.trim();
    if (q.isEmpty) return const [];
    final bias = near ?? centerMontevideo;
    final uri = Uri.https(
      'api.mapbox.com',
      '/geocoding/v5/mapbox.places/${Uri.encodeComponent(q)}.json',
      {
        'access_token': token,
        'country': 'uy',
        'language': 'es',
        'autocomplete': 'true',
        'limit': '6',
        'proximity': '${bias.lng},${bias.lat}',
        'bbox': _bbox,
      },
    );
    return interpretarGeocodingMapbox(
      await _getJson(_http, uri, 'mapbox-geocoding'),
    );
  }
}

List<Place> interpretarGeocodingMapbox(Map<String, dynamic> json) {
  final res = <Place>[];
  for (final f in (json['features'] as List?) ?? const []) {
    if (f is! Map<String, dynamic>) continue;
    final center = f['center'] as List?;
    if (center == null || center.length != 2) continue;
    final text = (f['text'] as String?)?.trim() ?? '';
    final numero = f['address']?.toString();
    final name = numero != null ? '$text $numero' : text;
    if (name.isEmpty) continue;
    final ctx = <String>[
      for (final c in (f['context'] as List?) ?? const [])
        if (c is Map && _esContextUtil(c['id']?.toString()))
          c['text'].toString(),
    ];
    res.add(
      Place(
        id: f['id']?.toString() ?? name,
        name: name,
        detail: ctx.isEmpty ? null : ctx.take(2).join(', '),
        coordinate: Coordinate(
          (center[1] as num).toDouble(),
          (center[0] as num).toDouble(),
        ),
      ),
    );
  }
  return res;
}

bool _esContextUtil(String? id) =>
    id != null &&
    (id.startsWith('neighborhood') ||
        id.startsWith('locality') ||
        id.startsWith('place'));

Future<Map<String, dynamic>> _getJson(
  http.Client cliente,
  Uri uri,
  String service,
) async {
  final http.Response resp;
  try {
    resp = await cliente
        .get(uri, headers: {'User-Agent': 'BondiUY/1.0 (app de transporte)'})
        .timeout(const Duration(seconds: 8));
  } catch (e) {
    throw ServiceError(service, e);
  }
  if (resp.statusCode != 200) {
    throw ServiceError(service, 'HTTP ${resp.statusCode}');
  }
  return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
}
