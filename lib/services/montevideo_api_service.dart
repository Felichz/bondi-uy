import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import 'eta_fetcher_service.dart'; // Importar la interfaz
import '../models/bus_arrival_info.dart'; // Importar el modelo
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'; // Asegurar import para Position

class MontevideoApiService implements ETAFetcherService {
  // Implementar la interfaz
  String? _accessToken;
  DateTime? _tokenExpiration;

  Future<String?> getApiToken() async {
    if (_accessToken != null &&
        _tokenExpiration != null &&
        DateTime.now().isBefore(_tokenExpiration!)) {
      return _accessToken;
    }

    try {
      final response = await http.post(
        Uri.parse(ACCESS_TOKEN_URL),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': CLIENT_ID,
          'client_secret': CLIENT_SECRET,
          'grant_type': 'client_credentials',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        // Guardar la expiración restando unos minutos por seguridad
        _tokenExpiration = DateTime.now().add(
          Duration(seconds: (data['expires_in'] as int) - 120),
        );
        return _accessToken;
      } else {
        print(
          "[MontevideoApiService_ERROR] Failed to get API token: ${response.statusCode} ${response.body}",
        );
        return null;
      }
    } catch (e) {
      print("[MontevideoApiService_ERROR] Exception getting API token: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchBusLinesForStop(String stopId) async {
    final token = await getApiToken();
    if (token == null) return [];

    final url = Uri.parse('$BASE_URL/busservice/lines/$stopId');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        _accessToken = null; // Invalidar token
        final newToken = await getApiToken();
        if (newToken != null) {
          final retryResponse = await http.get(
            url,
            headers: {'Authorization': 'Bearer $newToken'},
          );
          if (retryResponse.statusCode == 200) {
            return List<Map<String, dynamic>>.from(
              json.decode(retryResponse.body),
            );
          } else {
            print(
              "[MontevideoApiService_ERROR] Failed to fetch bus lines for stop $stopId after retry: ${retryResponse.statusCode} ${retryResponse.body}",
            );
          }
        }
      } else {
        print(
          "[MontevideoApiService_ERROR] Failed to fetch bus lines for stop $stopId: ${response.statusCode} ${response.body}",
        );
      }
      return [];
    } catch (e) {
      print(
        "[MontevideoApiService_ERROR] Exception fetching bus lines for stop $stopId: $e",
      );
      return [];
    }
  }

  // Implementación del método de la interfaz ETAFetcherService
  @override
  Future<List<BusArrivalInfo>> getUpcomingBusesForStop(String stopId) async {
    // Llama al nuevo método que obtiene todos los arribos para la parada
    final List<Map<String, dynamic>> rawArrivalData =
        await _fetchArrivalsForStop(stopId);

    if (rawArrivalData.isEmpty) {
      // Esto puede ocurrir si la API devuelve un array vacío (200 OK pero sin arribos)
      // o si _fetchArrivalsForStop devuelve [] por un error.
      print(
        "[MontevideoApiService_INFO] No arrival data received for stop $stopId from _fetchArrivalsForStop.",
      );
      return [];
    }

    return rawArrivalData.map((arrivalMap) {
      final minutes = arrivalMap['minutos'];
      final isReal = arrivalMap['real'] as bool? ?? false;
      // El campo 'linea' viene en cada objeto del array JSON
      final line = arrivalMap['linea'] as String? ?? 'N/A';

      Position? busPosition;
      final coordinatesData = arrivalMap['coordinates'];
      if (coordinatesData is List) {
        final coords = coordinatesData; // Ya es una lista
        if (coords.length == 2 && coords[0] is num && coords[1] is num) {
          // Asegurarse de que las coordenadas no sean (0,0) o nulas si eso indica ausencia
          if ((coords[0] as num) != 0.0 || (coords[1] as num) != 0.0) {
            // JSON es [longitud, latitud]. Mapbox Position(longitude, latitude).
            busPosition = Position(
              (coords[0] as num).toDouble(), // Longitud (X)
              (coords[1] as num).toDouble(), // Latitud (Y)
            );
          }
        }
      } else if (coordinatesData is Map<String, dynamic>) {
        // Manejo del formato anterior por si acaso (si existiera y fuera diferente)
        final locationData = coordinatesData;
        if (locationData['type'] == 'Point' &&
            locationData['coordinates'] is List) {
          final coordsAnterior = locationData['coordinates'] as List<dynamic>;
          if (coordsAnterior.length == 2 &&
              coordsAnterior[0] is num &&
              coordsAnterior[1] is num) {
            if ((coordsAnterior[0] as num) != 0.0 ||
                (coordsAnterior[1] as num) != 0.0) {
              // Asumiendo el mismo orden [lon, lat] para este formato si se diera el caso
              busPosition = Position(
                (coordsAnterior[0] as num).toDouble(), // Longitud (X)
                (coordsAnterior[1] as num).toDouble(), // Latitud (Y)
              );
            }
          }
        }
      }

      return BusArrivalInfo(
        minutesToArrival:
            minutes is int
                ? minutes
                : (minutes is double ? minutes.round() : 0),
        isReal: isReal,
        lineShortName: line,
        position: busPosition,
      );
    }).toList();
  }

  // Nuevo método privado para llamar al endpoint /siguientesParada/{stopId}
  Future<List<Map<String, dynamic>>> _fetchArrivalsForStop(
    String stopId,
  ) async {
    final token = await getApiToken();
    if (token == null) return [];

    // Usar el endpoint correcto directamente, ya que es una excepción a BASE_URL
    final url = Uri.parse(
      'https://api.montevideo.gub.uy/transporteRest/siguientesParada/$stopId',
    );
    print(
      "[MontevideoApiService_DEBUG] Fetching all arrivals for stop $stopId from $url",
    );

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        // El cuerpo de la respuesta es directamente un array JSON
        final decodedBody = json.decode(response.body);
        if (decodedBody is List) {
          return List<Map<String, dynamic>>.from(decodedBody);
        } else {
          print(
            "[MontevideoApiService_ERROR] Unexpected response format for stop $stopId. Expected List, got ${decodedBody.runtimeType}. Body: ${response.body}",
          );
          return [];
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        _accessToken = null; // Invalidar token
        print(
          "[MontevideoApiService_WARN] Token expired or invalid for stop $stopId. Retrying...",
        );
        final newToken = await getApiToken();
        if (newToken != null) {
          final retryResponse = await http.get(
            url,
            headers: {'Authorization': 'Bearer $newToken'},
          );
          if (retryResponse.statusCode == 200) {
            final decodedRetryBody = json.decode(retryResponse.body);
            if (decodedRetryBody is List) {
              return List<Map<String, dynamic>>.from(decodedRetryBody);
            } else {
              print(
                "[MontevideoApiService_ERROR] Unexpected response format for stop $stopId after retry. Expected List, got ${decodedRetryBody.runtimeType}. Body: ${retryResponse.body}",
              );
              return [];
            }
          } else {
            print(
              "[MontevideoApiService_ERROR] Failed to fetch arrivals for stop $stopId after retry: ${retryResponse.statusCode} ${retryResponse.body}",
            );
          }
        }
      } else {
        // Manejar otros errores, como 404 (si la parada no existe) o 429 (rate limit)
        print(
          "[MontevideoApiService_ERROR] Failed to fetch arrivals for stop $stopId: ${response.statusCode} ${response.body}",
        );
      }
      return [];
    } catch (e) {
      print(
        "[MontevideoApiService_ERROR] Exception fetching arrivals for stop $stopId: $e",
      );
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchRealtimeBusLocations(
    String lineShortName,
  ) async {
    final token = await getApiToken();
    if (token == null) return null;

    final url = Uri.parse(
      '$BASE_URL/busservice/realtimelocations/$lineShortName',
    );
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        _accessToken = null; // Invalidar token
        final newToken = await getApiToken();
        if (newToken != null) {
          final retryResponse = await http.get(
            url,
            headers: {'Authorization': 'Bearer $newToken'},
          );
          if (retryResponse.statusCode == 200) {
            return Map<String, dynamic>.from(json.decode(retryResponse.body));
          } else {
            print(
              "[MontevideoApiService_ERROR] Failed to fetch realtime bus locations for line $lineShortName after retry: ${retryResponse.statusCode} ${retryResponse.body}",
            );
          }
        }
      } else {
        print(
          "[MontevideoApiService_ERROR] Failed to fetch realtime bus locations for line $lineShortName: ${response.statusCode} ${response.body}",
        );
      }
      return null;
    } catch (e) {
      print(
        "[MontevideoApiService_ERROR] Exception fetching realtime bus locations for line $lineShortName: $e",
      );
      return null;
    }
  }
}
