import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bondi_uy/utils/map_types.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart'; // Para SugerenciaLugar y Coordenada

class GeocodingService {
  // Token de Mapbox - en el proyecto viejo estaba en mapbox_constants.dart
  static const String _mapboxAccessToken =
      "pk.eyJ1IjoiZmVsaWNoeiIsImEiOiJjbWFieDgxOW0yaGJ0Mmxwd3RmMGdndTc2In0.NC4vimNVJuH-tOgZQDs0kw";

  Future<List<SugerenciaLugar>> fetchSuggestions(String query) async {
    if (query.trim().isEmpty || query.length < 3) {
      return [];
    }

    try {
      final url =
          "https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json"
          "?access_token=$_mapboxAccessToken"
          "&country=UY"
          "&language=es"
          "&autocomplete=true"
          "&limit=5";

      print("[GeocodingService] Fetching suggestions for: '$query'");

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> features = data['features'] ?? [];

        final List<SugerenciaLugar> suggestions = [];

        for (final feature in features) {
          try {
            final geometry = feature['geometry'];
            final properties = feature['properties'];

            if (geometry != null &&
                geometry['type'] == 'Point' &&
                geometry['coordinates'] != null) {
              final List<dynamic> coordinates = geometry['coordinates'];
              if (coordinates.length >= 2) {
                final double lon = (coordinates[0] as num).toDouble();
                final double lat = (coordinates[1] as num).toDouble();

                // Obtener nombres en español primero, fallback a inglés
                final String placeName =
                    feature['place_name_es'] ?? feature['place_name'] ?? '';
                final String text = feature['text_es'] ?? feature['text'] ?? '';
                final String? address = feature['address']?.toString();

                // Construir nombre para mostrar
                String displayName;
                if (text.isNotEmpty && address != null && address.isNotEmpty) {
                  displayName = "$text $address";
                } else if (text.isNotEmpty) {
                  displayName = text;
                } else {
                  displayName = placeName;
                }

                suggestions.add(
                  SugerenciaLugar(
                    id: feature['id']?.toString() ?? '',
                    nombreCompleto: placeName,
                    nombreLugar: text.isNotEmpty ? text : null,
                    direccion: address,
                    coordenadas: Coordenada(latitud: lat, longitud: lon),
                  ),
                );
              }
            }
          } catch (e) {
            print("[GeocodingService] Error procesando feature: $e");
            continue;
          }
        }

        print(
          "[GeocodingService] Obtenidas ${suggestions.length} sugerencias para '$query'",
        );
        return suggestions;
      } else {
        print(
          "[GeocodingService] Error HTTP ${response.statusCode}: ${response.body}",
        );
        return [];
      }
    } catch (e) {
      print("[GeocodingService] Error obteniendo sugerencias: $e");
      return [];
    }
  }
}
