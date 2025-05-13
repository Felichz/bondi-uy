import 'dart:convert';
import 'package:http/http.dart' as http;

class MontevideoApiService {
  static const String _baseUrl =
      "https://api.montevideo.gub.uy/api/transportepublico";
  static const String _accessTokenUrl =
      "https://mvdapi-auth.montevideo.gub.uy/auth/realms/pci/protocol/openid-connect/token";
  static const String _clientId = "93d925e7";
  static const String _clientSecret = "2ac468b09443250d178653e7707ea9ad";

  String? _apiToken;

  Future<String?> getApiToken() async {
    if (_apiToken != null) return _apiToken;
    final response = await http.post(
      Uri.parse(_accessTokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'grant_type': 'client_credentials',
      },
    );
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      _apiToken = data['access_token'];
      return _apiToken;
    }
    return null;
  }

  Future<List<Map<String, String>>> fetchBusLinesForStop(String stopId) async {
    final token = await getApiToken();
    if (token == null) return [];
    final response = await http.get(
      Uri.parse("$_baseUrl/buses/busstops/$stopId/lines"),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map(
            (lineInfo) => {
              'line': (lineInfo['line'] ?? 'N/A').toString(),
              'lineId': (lineInfo['lineId'] ?? 'N/A').toString(),
            },
          )
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchUpcomingBusesForStopAndLine(
    String stopId,
    String lineShortName,
  ) async {
    final token = await getApiToken();
    if (token == null) {
      print("[BondiUY_Debug_ETA_Service] No se pudo obtener token para ETAs.");
      throw Exception("Error de autenticación en servicio");
    }

    final String apiUrl =
        "$_baseUrl/buses/busstops/$stopId/upcomingbuses?lines=$lineShortName&amountperline=3";

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        List<Map<String, dynamic>> upcomingBuses = [];
        for (var busInfo in responseData) {
          if (busInfo is Map<String, dynamic>) {
            dynamic etaValue;
            if (busInfo.containsKey('minutesToArrival')) {
              etaValue = busInfo['minutesToArrival'];
            } else if (busInfo.containsKey('arrivalMinutes')) {
              etaValue = busInfo['arrivalMinutes'];
            } else if (busInfo.containsKey('eta')) {
              etaValue = busInfo['eta'];
            }

            int? etaMinutes;
            if (etaValue is int) {
              etaMinutes = etaValue;
            } else if (etaValue is String) {
              etaMinutes = int.tryParse(etaValue);
            } else if (etaValue is double) {
              etaMinutes = etaValue.round();
            }

            if (etaMinutes != null &&
                ((busInfo['line']?.toString() == lineShortName) ||
                    (busInfo['lineId']?.toString() == lineShortName))) {
              upcomingBuses.add({
                'line': busInfo['line']?.toString(),
                'destination': busInfo['destination']?.toString(),
                'minutesToArrival': etaMinutes,
              });
            }
          }
        }
        upcomingBuses.sort(
          (a, b) => (a['minutesToArrival'] as int).compareTo(
            b['minutesToArrival'] as int,
          ),
        );
        return upcomingBuses;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        _apiToken =
            null; // Invalidar token para reintentar en la próxima llamada a getApiToken()
        print(
          "[BondiUY_Debug_ETA_Service] Error de autenticación (${response.statusCode}). Token invalidado.",
        );
        throw Exception(
          "Error API (auth): ${response.statusCode}",
        ); // Lanzar excepción para que el llamador maneje el reintento si es necesario
      } else {
        print(
          "[BondiUY_Debug_ETA_Service] Error API obteniendo ETAs (${response.statusCode}): ${response.body}",
        );
        throw Exception("Error API: ${response.statusCode}");
      }
    } catch (e) {
      print("[BondiUY_Debug_ETA_Service] Excepción obteniendo ETAs: $e");
      throw Exception("Excepción en servicio: $e");
    }
  }

  Future<Map<String, dynamic>> fetchRealtimeBusLocations(
    String lineShortName,
  ) async {
    String? token = await getApiToken();
    if (token == null) {
      print(
        "[BondiUY_Debug_Realtime_Service] No se pudo obtener token inicial para buses en tiempo real.",
      );
      throw Exception(
        "Error de autenticación en servicio para buses en tiempo real",
      );
    }

    final String apiUrl = "$_baseUrl/buses?lines=$lineShortName&format=geojson";

    print(
      "[BondiUY_Debug] Iniciando request a Montevideo API para realtime de buses (línea: $lineShortName)",
    );

    try {
      http.Response response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        print(
          "[BondiUY_Debug_Realtime_Service] Error de autenticación (${response.statusCode}). Forzando renovación de token y reintentando...",
        );
        _apiToken = null; // Invalidar token cacheado
        token = await getApiToken(); // Obtener nuevo token

        if (token != null) {
          print(
            "[BondiUY_Debug_Realtime_Service] Reintentando con nuevo token...",
          );
          print(
            "[BondiUY_Debug] Iniciando REINTENTO request a Montevideo API para realtime de buses (línea: $lineShortName)",
          );
          response = await http.get(
            Uri.parse(apiUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          );
        } else {
          print(
            "[BondiUY_Debug_Realtime_Service] No se pudo obtener nuevo token para reintento.",
          );
          throw Exception(
            "No se pudo obtener nuevo token para reintento en servicio",
          );
        }
      }

      if (response.statusCode == 200) {
        print(
          "[BondiUY_Debug] Respuesta recibida de Montevideo API para realtime de buses (línea: $lineShortName)",
        );
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        print(
          "[BondiUY_Debug_Realtime_Service] Error API obteniendo buses (${response.statusCode}): ${response.body}",
        );
        throw Exception(
          "Error API al obtener buses en tiempo real: ${response.statusCode}",
        );
      }
    } catch (e) {
      print("[BondiUY_Debug_Realtime_Service] Excepción obteniendo buses: $e");
      throw Exception(
        "Excepción en servicio al obtener buses en tiempo real: $e",
      );
    }
  }
}
