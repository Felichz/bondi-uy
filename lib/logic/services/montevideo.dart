// Real-time arrivals from the transport API of the Intendencia de
// Montevideo (`transporteRest/siguientesParada/{parada}`), with OAuth2
// client-credentials.

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../contract/model.dart';
import '../ports.dart';

const _urlToken =
    'https://mvdapi-auth.montevideo.gub.uy/auth/realms/pci/protocol/openid-connect/token';
const _urlArrivals =
    'https://api.montevideo.gub.uy/transporteRest/siguientesParada';

// Credentials for the IM API: injected at build time with
// `--dart-define-from-file=config/dev.json` (file kept outside git).
const _clientId = String.fromEnvironment('MVD_CLIENT_ID');
const _clientSecret = String.fromEnvironment('MVD_CLIENT_SECRET');

/// true if there are credentials to query live arrivals.
bool get arrivalsMontevideoConfigured =>
    _clientId.isNotEmpty && _clientSecret.isNotEmpty;

class MontevideoArrivals implements ArrivalSource {
  final http.Client _http;
  String? _token;
  DateTime? _expires;

  MontevideoArrivals({http.Client? client}) : _http = client ?? http.Client();

  Future<String> _getToken({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _token != null &&
        _expires != null &&
        now.isBefore(_expires!)) {
      return _token!;
    }
    final resp = await _http
        .post(
          Uri.parse(_urlToken),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'grant_type': 'client_credentials',
            'client_id': _clientId,
            'client_secret': _clientSecret,
          },
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw ServiceError('montevideo-token', 'HTTP ${resp.statusCode}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    _token = json['access_token'] as String;
    final expires = (json['expires_in'] as num?)?.toInt() ?? 300;
    _expires = now.add(Duration(seconds: (expires - 60).clamp(30, 1 << 20)));
    return _token!;
  }

  @override
  Future<List<StopArrival>> arrivals(String idStop) async {
    try {
      var token = await _getToken();
      var resp = await _get(idStop, token);
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        token = await _getToken(force: true);
        resp = await _get(idStop, token);
      }
      if (resp.statusCode != 200) {
        throw ServiceError('montevideo', 'HTTP ${resp.statusCode}');
      }
      final list = jsonDecode(utf8.decode(resp.bodyBytes));
      if (list is! List) return const [];
      return [
        for (final e in list)
          if (e is Map<String, dynamic>)
            if (interpretArrivalMontevideo(e) case final l?) l,
      ];
    } on ServiceError {
      rethrow;
    } catch (e) {
      throw ServiceError('montevideo', e);
    }
  }

  Future<http.Response> _get(String idStop, String token) => _http
      .get(
        Uri.parse('$_urlArrivals/$idStop'),
        headers: {'Authorization': 'Bearer $token'},
      )
      .timeout(const Duration(seconds: 10));
}

/// Parses one element of `siguientesParada`. Public for tests/fixtures.
StopArrival? interpretArrivalMontevideo(Map<String, dynamic> e) {
  final line = e['linea']?.toString().trim();
  if (line == null || line.isEmpty) return null;
  final minutesRaw = e['minutos'];
  final minutes = switch (minutesRaw) {
    int m => m,
    double m => m.round(),
    String m => int.tryParse(m),
    _ => null,
  };
  if (minutes == null) return null;
  Coordinate? pos;
  final c = e['coordinates'];
  if (c is List && c.length == 2 && c[0] is num && c[1] is num) {
    final lng = (c[0] as num).toDouble(), lat = (c[1] as num).toDouble();
    if (lat != 0 && lng != 0) pos = Coordinate(lat, lng);
  }
  return StopArrival(
    BusArrival(
      line: line,
      destination: (e['destino'] ?? e['descripcionDestino'])?.toString(),
      minutes: minutes < 0 ? 0 : minutes,
      live: e['real'] == true,
      position: pos,
    ),
    vehicle: e['idBus']?.toString(),
  );
}
