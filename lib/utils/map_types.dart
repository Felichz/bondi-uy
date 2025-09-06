// lib/utils/map_types.dart
import '../backend/contrato_ui/app_ui_state.dart'; // Import for Coordenada

enum ZoomTargetType {
  initial,
  origenSelection,
  destinationSelection,
  points,
  overview,
  leg,
  none, // Equivalent to NINGUNO
  paradaEspecifica,
  puntosOrigenDestino,
  rutaCompleta,
  bounds,
  ubicacionUsuario,
}

class ZoomTarget {
  final ZoomTargetType tipo;
  final List<Map<String, double>>?
  puntos; // Assuming points are List of {'latitude': lat, 'longitude': lon} or similar
  final int? indiceTramo; // Corresponds to legIndex for ZoomTargetType.leg
  final Coordenada? puntoUnico;

  ZoomTarget({
    required this.tipo,
    this.puntos,
    this.indiceTramo,
    this.puntoUnico,
  });
}
