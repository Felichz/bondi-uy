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
    print(
      "[BondiUY_Debug_ETA_Service] fetchUpcomingBusesForStopAndLine: Obteniendo todos los arribos para la parada $stopId y filtrando por línea $lineShortName",
    );

    // Llamar al nuevo método que obtiene todos los arribos para la parada
    final List<Map<String, dynamic>> allArrivals =
        await fetchNextArrivalsForStop(stopId);

    // Filtrar por la línea deseada
    final List<Map<String, dynamic>> filteredArrivals =
        allArrivals
            .where((bus) => bus['line']?.toString() == lineShortName)
            .toList();

    // Aplicar el límite de amountperline (aunque la API original lo hacía, aquí lo replicamos si es necesario)
    // El nuevo endpoint no tiene amountperline, así que si se quiere un límite, se aplica post-filtro.
    // Por ahora, devolvemos todos los de la línea. Si se necesita un límite, se puede añadir aquí.
    // Ejemplo: return filteredArrivals.take(3).toList();

    print(
      "[BondiUY_Debug_ETA_Service] fetchUpcomingBusesForStopAndLine: Encontrados ${filteredArrivals.length} arribos para línea $lineShortName en parada $stopId.",
    );
    return filteredArrivals;
  }

  // NUEVO MÉTODO usando el endpoint transporteRest/siguientesParada/
  Future<List<Map<String, dynamic>>> fetchNextArrivalsForStop(
    String stopId,
  ) async {
    final String apiUrl =
        "https://api.montevideo.gub.uy/transporteRest/siguientesParada/$stopId";

    print(
      "[BondiUY_Debug_NextArrivals_Service] Llamando a API con URL: $apiUrl",
    );

    try {
      // Este endpoint parece no requerir token según pruebas directas.
      // Si falla por autenticación, se deberá añadir la lógica de token aquí.
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        List<Map<String, dynamic>> upcomingBuses = [];

        print(
          "[BondiUY_Debug_API_RESPONSE_NextArrivals] Código de estado: ${response.statusCode} para parada $stopId",
        );
        // print("[BondiUY_Debug_API_RESPONSE_NextArrivals] Body: ${response.body}");

        for (var busInfo in responseData) {
          if (busInfo is Map<String, dynamic>) {
            List<dynamic>? coords = busInfo['coordinates'];
            Map<String, dynamic>? locationGeoJson;
            if (coords != null && coords.length == 2) {
              // Asegurarse de que las coordenadas sean double
              final lon =
                  coords[0] is num ? (coords[0] as num).toDouble() : null;
              final lat =
                  coords[1] is num ? (coords[1] as num).toDouble() : null;
              if (lon != null && lat != null) {
                locationGeoJson = {
                  'type': 'Point',
                  'coordinates': [lon, lat],
                };
              }
            }

            upcomingBuses.add({
              'line': busInfo['linea']?.toString(),
              'destination': busInfo['destino']?.toString(),
              'minutesToArrival': busInfo['minutos'],
              'location':
                  locationGeoJson, // Puede ser null si no hay coordenadas o no son válidas
              'isReal': busInfo['real'] ?? false,
              'idBus': busInfo['idBus'], // Añadir otros campos útiles
              'variantId':
                  busInfo['variante'], // 'variante' en el nuevo endpoint
              'stopNameActual': busInfo['parada_actual'],
            });
          }
        }
        // La API ya suele devolver ordenado por minutos.
        return upcomingBuses;
      } else {
        print(
          "[BondiUY_Debug_NextArrivals_Service] Error API (${response.statusCode}) para parada $stopId: ${response.body}",
        );
        // Si es un error de autenticación común, intentar obtener token y reintentar.
        // Por ahora, lanzamos la excepción directamente.
        // if (response.statusCode == 401 || response.statusCode == 403) {
        //   _apiToken = null; // Invalidar token
        // }
        throw Exception("Error API: ${response.statusCode}");
      }
    } catch (e) {
      print(
        "[BondiUY_Debug_NextArrivals_Service] Excepción para parada $stopId: $e",
      );
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
        print("[BondiUY_Debug_API_RESPONSE_REALTIME] Body: ${response.body}");
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
