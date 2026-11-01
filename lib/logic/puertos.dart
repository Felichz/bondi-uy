// Puertos: lo que la capa de lógica necesita del mundo exterior.
//
// Cada puerto tiene una implementación real (OTP, API de Montevideo, Mapbox
// geocoding, GPS) y una de repetición/sintética para tests y modo demo.

import 'dart:async';

import '../contract/modelo.dart';

/// Opción planificada + datos internos que la UI no necesita.
class ViajePlanificado {
  final OpcionViaje opcion;

  /// shape GTFS (sin prefijo de feed) de cada tramo de bus, por id de tramo.
  final Map<String, String> shapePorTramo;

  const ViajePlanificado(this.opcion, {this.shapePorTramo = const {}});
}

abstract interface class PlanificadorViajes {
  /// Devuelve itinerarios crudos (sin ranking ni ETAs). Lanza
  /// [ErrorServicio] si el servicio no responde.
  Future<List<ViajePlanificado>> planificar({
    required Coordenada origen,
    required Coordenada destino,
    required DateTime salida,
  });
}

/// Llegada informada por la fuente, con el id de vehículo para poder seguir
/// siempre al mismo bus entre sondeos.
class LlegadaEnParada {
  final LlegadaBus datos;
  final String? vehiculo;
  const LlegadaEnParada(this.datos, {this.vehiculo});
}

abstract interface class FuenteLlegadas {
  /// Próximas llegadas a una parada. Lanza [ErrorServicio] si falla.
  Future<List<LlegadaEnParada>> llegadas(String idParada);
}

abstract interface class BuscadorLugares {
  Future<List<Lugar>> sugerencias(String texto, {Coordenada? cerca});
}

/// Datos estáticos de la red (GTFS empaquetado).
abstract interface class CatalogoRed {
  Future<List<ParadaDeRed>> paradas();

  /// Geometría completa de un shape GTFS, o null si no existe.
  Future<List<Coordenada>?> shape(String shapeId);
}

class MuestraUbicacion {
  final Coordenada coordenada;
  final DateTime momento;

  /// Velocidad en m/s si la fuente la informa.
  final double? velocidad;

  /// Precisión horizontal en metros si la fuente la informa.
  final double? precision;

  const MuestraUbicacion({
    required this.coordenada,
    required this.momento,
    this.velocidad,
    this.precision,
  });
}

enum PermisoUbicacion {
  concedido,
  denegado,
  denegadoParaSiempre,
  servicioApagado,
}

abstract interface class FuenteUbicacion {
  /// Pide permiso si hace falta.
  Future<PermisoUbicacion> asegurarPermiso();

  /// Una lectura puntual (o null si no hay fix a tiempo).
  Future<MuestraUbicacion?> actual();

  /// Flujo continuo de lecturas. Se cancela al cancelar la suscripción.
  Stream<MuestraUbicacion> seguir();
}

class ErrorServicio implements Exception {
  final String servicio;
  final Object? causa;
  const ErrorServicio(this.servicio, [this.causa]);

  @override
  String toString() => 'ErrorServicio($servicio): $causa';
}

/// Reloj inyectable (tests y modo demo aceleran el tiempo).
typedef Reloj = DateTime Function();

/// Control del mundo simulado del modo demo.
abstract interface class ControlDemo {
  double get velocidad;
  set velocidad(double v);
  List<double> get velocidades;

  /// Destinos con viaje grabado.
  List<Lugar> get destinos;
}
