// lib/models/bus_arrival_info.dart
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'; // Para Position

class BusArrivalInfo {
  final int minutesToArrival;
  final bool isReal;
  final String lineShortName;
  final Position? position;
  // Podría tener más campos si la API los devuelve y son útiles, ej: tripId, destination

  BusArrivalInfo({
    required this.minutesToArrival,
    required this.isReal,
    required this.lineShortName,
    this.position,
  });
}
