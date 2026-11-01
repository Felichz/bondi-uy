// Llegadas en tiempo real de la API de transporte de la Intendencia de
// Montevideo (`transporteRest/siguientesParada/{parada}`), con OAuth2
// client-credentials.

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../contract/modelo.dart';
import '../puertos.dart';

const _urlToken =
    'https://mvdapi-auth.montevideo.gub.uy/auth/realms/pci/protocol/openid-connect/token';
const _urlLlegadas =
    'https://api.montevideo.gub.uy/transporteRest/siguientesParada';

// Credenciales de la API de la IM: se inyectan en build con
// `--dart-define-from-file=config/dev.json` (archivo fuera de git).
const _clientId = String.fromEnvironment('MVD_CLIENT_ID');
const _clientSecret = String.fromEnvironment('MVD_CLIENT_SECRET');

/// true si hay credenciales para consultar llegadas en vivo.
bool get llegadasMontevideoConfiguradas =>
    _clientId.isNotEmpty && _clientSecret.isNotEmpty;

class LlegadasMontevideo implements FuenteLlegadas {
  final http.Client _http;
  String? _token;
  DateTime? _vence;

  LlegadasMontevideo({http.Client? cliente}) : _http = cliente ?? http.Client();

  Future<String> _obtenerToken({bool forzar = false}) async {
    final ahora = DateTime.now();
    if (!forzar &&
        _token != null &&
        _vence != null &&
        ahora.isBefore(_vence!)) {
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
      throw ErrorServicio('montevideo-token', 'HTTP ${resp.statusCode}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    _token = json['access_token'] as String;
    final expira = (json['expires_in'] as num?)?.toInt() ?? 300;
    _vence = ahora.add(Duration(seconds: (expira - 60).clamp(30, 1 << 20)));
    return _token!;
  }

  @override
  Future<List<LlegadaEnParada>> llegadas(String idParada) async {
    try {
      var token = await _obtenerToken();
      var resp = await _get(idParada, token);
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        token = await _obtenerToken(forzar: true);
        resp = await _get(idParada, token);
      }
      if (resp.statusCode != 200) {
        throw ErrorServicio('montevideo', 'HTTP ${resp.statusCode}');
      }
      final lista = jsonDecode(utf8.decode(resp.bodyBytes));
      if (lista is! List) return const [];
      return [
        for (final e in lista)
          if (e is Map<String, dynamic>)
            if (interpretarLlegadaMontevideo(e) case final l?) l,
      ];
    } on ErrorServicio {
      rethrow;
    } catch (e) {
      throw ErrorServicio('montevideo', e);
    }
  }

  Future<http.Response> _get(String idParada, String token) => _http
      .get(
        Uri.parse('$_urlLlegadas/$idParada'),
        headers: {'Authorization': 'Bearer $token'},
      )
      .timeout(const Duration(seconds: 10));
}

/// Interpreta un elemento de `siguientesParada`. Público para tests/fixtures.
LlegadaEnParada? interpretarLlegadaMontevideo(Map<String, dynamic> e) {
  final linea = e['linea']?.toString().trim();
  if (linea == null || linea.isEmpty) return null;
  final minutosCrudo = e['minutos'];
  final minutos = switch (minutosCrudo) {
    int m => m,
    double m => m.round(),
    String m => int.tryParse(m),
    _ => null,
  };
  if (minutos == null) return null;
  Coordenada? pos;
  final c = e['coordinates'];
  if (c is List && c.length == 2 && c[0] is num && c[1] is num) {
    final lng = (c[0] as num).toDouble(), lat = (c[1] as num).toDouble();
    if (lat != 0 && lng != 0) pos = Coordenada(lat, lng);
  }
  return LlegadaEnParada(
    LlegadaBus(
      linea: linea,
      destino: (e['destino'] ?? e['descripcionDestino'])?.toString(),
      minutos: minutos < 0 ? 0 : minutos,
      enVivo: e['real'] == true,
      posicion: pos,
    ),
    vehiculo: e['idBus']?.toString(),
  );
}
