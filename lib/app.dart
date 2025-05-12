import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'; // Necesario para MapboxOptions
import 'package:bondi_uy/screens/map_screen.dart';

// TODO: Considerar mover _MAPBOX_ACCESS_TOKEN aquí o a un archivo de constantes.
// Por ahora, asumimos que podría estar en main.dart o se pasará.
// const String _MAPBOX_ACCESS_TOKEN = "tu_token_aqui"; // Ejemplo si se moviera

// Función de inicialización que puede ser llamada desde main() en main.dart
void initializeAppConfig(String mapboxAccessToken) {
  WidgetsFlutterBinding.ensureInitialized();
  MapboxOptions.setAccessToken(mapboxAccessToken);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Anteriormente, _MAPBOX_ACCESS_TOKEN se obtenía de main.dart o era global.
    // Ahora lo importamos desde mapbox_constants.dart
    return MaterialApp(
      title: 'BondiUY',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MapScreen(), // Revertir a esto
    );
  }
}
