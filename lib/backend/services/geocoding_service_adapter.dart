import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart'; // Importar Coordenada y SugerenciaLugar

// Token de Mapbox (el mismo que se usa para inicializar el mapa y para Geocoding)
const String MAPBOX_ACCESS_TOKEN =
    "pk.eyJ1IjoiZmVsaWNoeiIsImEiOiJjbWFieDgxOW0yaGJ0Mmxwd3RmMGdndTc2In0.NC4vimNVJuH-tOgZQDs0kw";

// TODO: Considerar mover el token a una configuración centralizada o pasarlo como dependencia.
// const String _mapboxAccessToken = String.fromEnvironment( // Comentado o eliminado
//   'MAPBOX_ACCESS_TOKEN',
//   defaultValue:
//       '',
// );

// Se elimina CoordenadaGeo y SugerenciaLugar de este archivo, ya que se usarán las del contrato.
// class CoordenadaGeo { ... } // Eliminada
// class SugerenciaLugar { ... } // Eliminada

class GeocodingServiceAdapter {
  final http.Client _httpClient;
  final String _apiKey;

  GeocodingServiceAdapter({http.Client? httpClient, String? apiKey})
    : _httpClient = httpClient ?? http.Client(),
      _apiKey = apiKey ?? MAPBOX_ACCESS_TOKEN;

  Future<List<SugerenciaLugar>> fetchSuggestions(
    String query, {
    Coordenada? proximity, // Usar Coordenada del contrato
  }) async {
    if (_apiKey.isEmpty) {
      print('Error: Mapbox Access Token no está configurado.');
      return [];
    }
    if (query.isEmpty) {
      return [];
    }

    String proximityParam = '';
    if (proximity != null) {
      // Asegurarse de que Coordenada del contrato tenga longitud y latitud
      proximityParam = '&proximity=${proximity.longitud},${proximity.latitud}';
    }

    final url =
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json?access_token=$_apiKey&country=UY&language=es&autocomplete=true&limit=5$proximityParam';

    try {
      final response = await _httpClient.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List?;
        if (features != null) {
          return features
              .map(
                (feature) => SugerenciaLugar.fromJson(
                  feature as Map<String, dynamic>,
                ), // Usar el factory del contrato
              )
              .toList();
        }
        return [];
      } else {
        print('Error Geocoding API: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Excepción en fetchSuggestions: $e');
      return [];
    }
  }

  Future<List<SugerenciaLugar>> reverseGeocode(Coordenada location) async {
    if (_apiKey.isEmpty) {
      print('Error: Mapbox Access Token no está configurado.');
      return [];
    }

    final url =
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${location.longitud},${location.latitud}.json?access_token=$_apiKey&country=UY&language=es&types=address,poi';

    try {
      final response = await _httpClient.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List?;
        if (features != null) {
          return features
              .map(
                (feature) =>
                    SugerenciaLugar.fromJson(feature as Map<String, dynamic>),
              )
              .toList();
        }
        return [];
      } else {
        print(
          'Error Reverse Geocoding API: ${response.statusCode} - ${response.body}',
        );
        return [];
      }
    } catch (e) {
      print('Excepción en reverseGeocode: $e');
      return [];
    }
  }
}
