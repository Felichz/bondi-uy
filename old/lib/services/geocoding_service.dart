import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bondi_uy/constants/mapbox_constants.dart';

class GeocodingService {
  Future<List<Map<String, dynamic>>> fetchSuggestions(String query) async {
    final url =
        "https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json?access_token=$MAPBOX_ACCESS_TOKEN&country=UY&language=es&autocomplete=true&limit=5";
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['features'] ?? []);
    }
    return [];
  }
}
