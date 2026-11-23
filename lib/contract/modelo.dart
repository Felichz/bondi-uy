// Tipos de dominio que cruzan el contrato UI <-> lógica.
//
// Reglas del contrato:
// - Solo datos crudos: números, enums, coordenadas, nombres propios (calles,
//   paradas, líneas). Nunca texto presentacional ni formatos ("5 min").
// - Inmutables. La lógica crea instancias nuevas; la UI solo las lee.
// - Nada de Mapbox, colores, widgets ni estilos.

import 'package:flutter/foundation.dart' show immutable, listEquals;

@immutable
class Coordenada {
  final double lat;
  final double lng;

  const Coordenada(this.lat, this.lng)
    : assert(lat >= -90 && lat <= 90, 'latitud fuera de rango'),
      assert(lng >= -180 && lng <= 180, 'longitud fuera de rango');

  @override
  bool operator ==(Object other) =>
      other is Coordenada && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() =>
      'Coordenada(${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})';
}

/// Un lugar elegible como origen o destino (sugerencia de búsqueda).
@immutable
class Lugar {
  final String id;

  /// Nombre principal ("Plaza Independencia", "Av. Brasil 2550").
  final String nombre;

  /// Contexto opcional ("Ciudad Vieja, Montevideo").
  final String? detalle;
  final Coordenada coordenada;

  const Lugar({
    required this.id,
    required this.nombre,
    this.detalle,
    required this.coordenada,
  });

  @override
  bool operator ==(Object other) =>
      other is Lugar &&
      other.id == id &&
      other.nombre == nombre &&
      other.detalle == detalle &&
      other.coordenada == coordenada;

  @override
  int get hashCode => Object.hash(id, nombre, detalle, coordenada);
}

@immutable
class Parada {
  final String id;
  final String nombre;
  final Coordenada coordenada;

  const Parada({
    required this.id,
    required this.nombre,
    required this.coordenada,
  });

  @override
  bool operator ==(Object other) =>
      other is Parada && other.id == id && other.coordenada == coordenada;

  @override
  int get hashCode => Object.hash(id, coordenada);
}

/// Una parada del mapa de exploración, con las líneas que pasan por ella.
@immutable
class ParadaDeRed {
  final Parada parada;
  final List<String> lineas;

  const ParadaDeRed({required this.parada, required this.lineas});
}

/// Próxima llegada de un bus a una parada.
@immutable
class LlegadaBus {
  final String linea;

  /// Destino del bus tal como lo informa la fuente ("PLAZA INDEPENDENCIA").
  final String? destino;
  final int minutos;

  /// true = posición/ETA en tiempo real; false = horario programado.
  final bool enVivo;
  final Coordenada? posicion;

  const LlegadaBus({
    required this.linea,
    this.destino,
    required this.minutos,
    required this.enVivo,
    this.posicion,
  }) : assert(minutos >= 0);
}

/// Un bus concreto que viene hacia una parada, con la geometría de calle que
/// recorre hasta llegar. [aproximacion] es null cuando no existe una
/// geometría verídica: la UI nunca debe inventar una recta.
@immutable
class BusEnCamino {
  final String linea;

  /// null cuando solo se conoce el horario (sin GPS del bus).
  final Coordenada? posicion;
  final int minutos;
  final bool enVivo;

  /// Recorrido bus -> parada sobre el shape GTFS, en sentido de marcha.
  final List<Coordenada>? aproximacion;

  /// Por dónde viene: el recorrido de la línea desde un tramo antes del bus
  /// (por donde pasó hace un rato) hasta la parada. Entre una lectura y la
  /// siguiente, el bus se mueve por acá.
  final List<Coordenada>? camino;

  /// Metros que le faltan al bus para llegar, por la calle.
  final int? metrosHastaParada;

  /// Rumbo del bus (grados, 0 = norte) según el shape, si se conoce.
  final double? rumbo;

  const BusEnCamino({
    required this.linea,
    this.posicion,
    required this.minutos,
    required this.enVivo,
    this.aproximacion,
    this.camino,
    this.metrosHastaParada,
    this.rumbo,
  }) : assert(aproximacion == null || posicion != null);
}

// ---------------------------------------------------------------------------
// Viajes
// ---------------------------------------------------------------------------

/// Un tramo del viaje. Solo existen tres tipos (visión de la app):
/// caminar, esperar el bus y viajar en el bus.
@immutable
sealed class Tramo {
  final String id;
  const Tramo(this.id);
}

@immutable
class TramoCaminar extends Tramo {
  final List<Coordenada> geometria;
  final int distanciaMetros;
  final int duracionSegundos;

  /// Parada a la que se camina; null si se camina al destino final.
  final Parada? haciaParada;

  // Las aserciones validan datos en tiempo de ejecución: no puede ser const.
  // ignore: prefer_const_constructors_in_immutables
  TramoCaminar({
    required String id,
    required this.geometria,
    required this.distanciaMetros,
    required this.duracionSegundos,
    this.haciaParada,
  }) : assert(geometria.length >= 2, 'caminata sin geometría'),
       super(id);

  bool get esAlDestino => haciaParada == null;
  Coordenada get fin => geometria.last;
}

@immutable
class TramoEsperar extends Tramo {
  final Parada parada;
  final String linea;
  final String? destinoLinea;

  /// Espera según el plan (horarios), no en vivo.
  final int esperaProgramadaSegundos;

  const TramoEsperar({
    required String id,
    required this.parada,
    required this.linea,
    this.destinoLinea,
    required this.esperaProgramadaSegundos,
  }) : super(id);
}

@immutable
class TramoBus extends Tramo {
  final String linea;
  final String? destinoLinea;
  final Parada subida;
  final Parada bajada;

  /// Paradas entre subida y bajada (excluidas ambas), en orden de marcha.
  final List<Parada> paradasIntermedias;
  final List<Coordenada> geometria;
  final int distanciaMetros;
  final int duracionSegundos;

  // ignore: prefer_const_constructors_in_immutables
  TramoBus({
    required String id,
    required this.linea,
    this.destinoLinea,
    required this.subida,
    required this.bajada,
    required this.paradasIntermedias,
    required this.geometria,
    required this.distanciaMetros,
    required this.duracionSegundos,
  }) : assert(geometria.length >= 2, 'tramo de bus sin geometría'),
       super(id);
}

/// Advertencias posibles de una opción. La UI decide el texto.
enum AvisoOpcion {
  caminataLarga,
  transbordoAjustado,
  sinDatosEnVivoPrimerBus,
  primerBusPuedeNoAlcanzar,
}

@immutable
class OpcionViaje {
  final String id;
  final int duracionSegundos;
  final DateTime salida;
  final DateTime llegada;
  final int caminataMetros;
  final int transbordos;
  final bool recomendada;
  final List<Tramo> tramos;

  /// Próximo bus de la primera línea en la parada de subida, si se conoce.
  final LlegadaBus? proximoBus;
  final AvisoOpcion? aviso;

  // ignore: prefer_const_constructors_in_immutables
  OpcionViaje({
    required this.id,
    required this.duracionSegundos,
    required this.salida,
    required this.llegada,
    required this.caminataMetros,
    required this.transbordos,
    required this.recomendada,
    required this.tramos,
    this.proximoBus,
    this.aviso,
  }) : assert(tramos.isNotEmpty, 'opción sin tramos'),
       assert(_secuenciaValida(tramos), 'secuencia de tramos inválida');

  List<String> get lineas => [
    for (final t in tramos)
      if (t is TramoBus) t.linea,
  ];

  TramoBus? get primerBus {
    for (final t in tramos) {
      if (t is TramoBus) return t;
    }
    return null;
  }

  OpcionViaje conProximoBus(LlegadaBus? bus, {AvisoOpcion? aviso}) =>
      OpcionViaje(
        id: id,
        duracionSegundos: duracionSegundos,
        salida: salida,
        llegada: llegada,
        caminataMetros: caminataMetros,
        transbordos: transbordos,
        recomendada: recomendada,
        tramos: tramos,
        proximoBus: bus,
        aviso: aviso ?? this.aviso,
      );

  OpcionViaje conRecomendada(bool valor) => OpcionViaje(
    id: id,
    duracionSegundos: duracionSegundos,
    salida: salida,
    llegada: llegada,
    caminataMetros: caminataMetros,
    transbordos: transbordos,
    recomendada: valor,
    tramos: tramos,
    proximoBus: proximoBus,
    aviso: aviso,
  );

  /// Invariante: todo bus va precedido por su espera en la misma parada.
  static bool _secuenciaValida(List<Tramo> tramos) {
    for (var i = 0; i < tramos.length; i++) {
      final t = tramos[i];
      if (t is TramoBus) {
        if (i == 0) return false;
        final previo = tramos[i - 1];
        if (previo is! TramoEsperar) return false;
        if (previo.parada.id != t.subida.id || previo.linea != t.linea) {
          return false;
        }
      }
      if (t is TramoEsperar) {
        if (i + 1 >= tramos.length || tramos[i + 1] is! TramoBus) return false;
      }
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is OpcionViaje &&
      other.id == id &&
      other.recomendada == recomendada &&
      other.proximoBus == proximoBus &&
      other.aviso == aviso &&
      listEquals(other.tramos, tramos);

  @override
  int get hashCode => Object.hash(id, recomendada, proximoBus, aviso);
}
