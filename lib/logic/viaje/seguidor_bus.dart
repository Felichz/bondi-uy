// Selección del bus que viene a una parada y su recorrido de aproximación.
//
// Reglas de veracidad (heredadas del contrato visual E2E):
// - La aproximación sigue el shape GTFS en el sentido de marcha. Nunca una
//   recta entre bus y parada, nunca un shape invertido.
// - Un bus que ya pasó la parada no "viene": se descarta.
// - Entre sondeos se sigue al mismo vehículo mientras siga viniendo.
// - Cuando el bus que se seguía llega a la parada, deja de "venir" (la
//   fuente lo da por pasado o deja de informarlo). Ese no es el momento de
//   anunciar el próximo: el usuario está subiendo. Se lo informa como
//   llegado (0 min, 0 m, en la parada) durante unos sondeos; recién después,
//   si el usuario no subió, se pasa al siguiente.

import 'dart:math' as math;

import '../../contract/modelo.dart';
import '../geo/geo.dart';
import '../puertos.dart';

/// Geometría del recorrido de una línea alrededor de una parada de subida.
class RecorridoLinea {
  final Polilinea linea;

  /// Metros recorridos sobre [linea] hasta la parada de subida.
  final double recorridoParada;

  /// La parada de subida sobre el shape.
  Coordenada get parada => linea.puntoEn(recorridoParada);

  RecorridoLinea._(this.linea, this.recorridoParada);

  /// Ubica la parada sobre el shape. Si se conoce la bajada, se usa para
  /// desambiguar shapes que pasan dos veces por la misma zona (ida/vuelta).
  static RecorridoLinea? crear(
    List<Coordenada> shape,
    Coordenada subida, {
    Coordenada? bajada,
    double maxLateral = 80,
  }) {
    if (shape.length < 2) return null;
    final linea = Polilinea(shape);
    Proyeccion? elegida;
    if (bajada != null) {
      // Probar cada pasada cercana de la subida y quedarse con la que tiene
      // la bajada más adelante y más cerca del shape.
      var mejorCosto = double.infinity;
      for (final s in _pasadasCercanas(linea, subida, maxLateral)) {
        final b = linea.proyectar(bajada, desde: s.recorrido);
        if (b.recorrido <= s.recorrido) continue;
        final costo = s.distanciaLateral + b.distanciaLateral;
        if (costo < mejorCosto) {
          mejorCosto = costo;
          elegida = s;
        }
      }
    }
    elegida ??= linea.proyectar(subida);
    if (elegida.distanciaLateral > maxLateral) return null;
    return RecorridoLinea._(linea, elegida.recorrido);
  }

  static List<Proyeccion> _pasadasCercanas(
    Polilinea linea,
    Coordenada c,
    double maxLateral,
  ) {
    final res = <Proyeccion>[];
    var desde = 0.0;
    while (desde < linea.largo) {
      final hasta = math.min(linea.largo, desde + 400);
      final p = linea.proyectar(c, desde: desde, hasta: hasta);
      if (p.distanciaLateral <= maxLateral &&
          (res.isEmpty || p.recorrido - res.last.recorrido > 200)) {
        res.add(p);
      }
      desde = hasta;
    }
    return res;
  }

  /// Aproximación bus -> parada, o null si el bus no está sobre el recorrido
  /// antes de la parada.
  ({List<Coordenada> puntos, double metros, double rumbo})? aproximacion(
    Coordenada bus, {
    double maxLateral = 150,
  }) {
    final p = linea.proyectar(bus, hasta: recorridoParada);
    if (p.distanciaLateral > maxLateral) return null;
    if (p.recorrido > recorridoParada) return null;
    final puntos = [bus, ...linea.tramo(p.recorrido, recorridoParada)];
    return (
      puntos: puntos,
      metros: recorridoParada - p.recorrido,
      rumbo: linea.rumboEn(p.recorrido),
    );
  }

  /// true si el bus está sobre el recorrido pero ya pasó la parada.
  bool yaPaso(Coordenada bus, {double maxLateral = 150}) {
    final despues = linea.proyectar(bus, desde: recorridoParada);
    final antes = linea.proyectar(bus, hasta: recorridoParada);
    return despues.distanciaLateral <= maxLateral &&
        despues.distanciaLateral + 20 < antes.distanciaLateral &&
        despues.recorrido > recorridoParada + 30;
  }
}

class SeguidorBus {
  final String linea;
  final RecorridoLinea? recorrido;
  String? _vehiculo;

  /// El bus seguido cuando estaba por llegar (null si venía lejos).
  BusEnCamino? _llegando;
  int _sondeosRetenido = 0;

  /// Sondeos (~10 s cada uno) que se informa "llegó" antes de pasar al
  /// siguiente bus.
  static const sondeosLlegado = 6;

  /// A esta distancia (o 0 min) el bus se considera llegando.
  static const metrosLlegando = 150;

  SeguidorBus({required this.linea, this.recorrido});

  /// Elige el bus relevante entre las llegadas a la parada.
  BusEnCamino? elegir(List<LlegadaEnParada> llegadas) {
    final candidatos = [
      for (final l in llegadas)
        if (_mismaLinea(l.datos.linea, linea)) l,
    ];
    final utiles = <(LlegadaEnParada, BusEnCamino)>[];
    for (final l in candidatos) {
      final bus = _construir(l);
      if (bus != null) utiles.add((l, bus));
    }

    // 1) El mismo vehículo que veníamos siguiendo.
    if (_vehiculo != null) {
      for (final (l, b) in utiles) {
        if (l.vehiculo == _vehiculo) return _seguido(b);
      }
      // Ya no viene: si estaba llegando, llegó. Si la fuente todavía lo
      // informa (ya pasó la parada), se muestra donde está de verdad; si no,
      // en la parada.
      final llegado = _llegando;
      if (llegado != null && _sondeosRetenido < sondeosLlegado) {
        _sondeosRetenido++;
        Coordenada? real;
        for (final l in candidatos) {
          if (l.vehiculo == _vehiculo) real = l.datos.posicion;
        }
        return BusEnCamino(
          linea: llegado.linea,
          posicion: real ?? recorrido?.parada ?? llegado.posicion,
          minutos: 0,
          enVivo: llegado.enVivo,
          metrosHastaParada: 0,
          rumbo: llegado.rumbo,
        );
      }
    }
    _llegando = null;
    _sondeosRetenido = 0;
    if (utiles.isEmpty) {
      _vehiculo = null;
      return null;
    }
    // 2) El próximo en llegar, priorizando los que tienen posición en vivo.
    utiles.sort((a, b) {
      final va = a.$2.enVivo && a.$2.posicion != null ? 0 : 1;
      final vb = b.$2.enVivo && b.$2.posicion != null ? 0 : 1;
      if (va != vb) return va - vb;
      return a.$2.minutos.compareTo(b.$2.minutos);
    });
    final (l, b) = utiles.first;
    _vehiculo = l.vehiculo;
    return _seguido(b);
  }

  BusEnCamino _seguido(BusEnCamino b) {
    final m = b.metrosHastaParada;
    _llegando =
        b.enVivo && (b.minutos == 0 || (m != null && m <= metrosLlegando))
            ? b
            : null;
    _sondeosRetenido = 0;
    return b;
  }

  BusEnCamino? _construir(LlegadaEnParada l) {
    final d = l.datos;
    final pos = d.posicion;
    if (pos == null || recorrido == null) {
      return BusEnCamino(
        linea: d.linea,
        posicion: pos,
        minutos: d.minutos,
        enVivo: d.enVivo,
      );
    }
    final ap = recorrido!.aproximacion(pos);
    if (ap == null) {
      if (recorrido!.yaPaso(pos)) return null; // ya pasó: no viene
      return BusEnCamino(
        linea: d.linea,
        posicion: pos,
        minutos: d.minutos,
        enVivo: d.enVivo,
      );
    }
    return BusEnCamino(
      linea: d.linea,
      posicion: pos,
      minutos: d.minutos,
      enVivo: d.enVivo,
      aproximacion: ap.puntos.length >= 2 ? ap.puntos : null,
      metrosHastaParada: ap.metros.round(),
      rumbo: ap.rumbo,
    );
  }
}

bool _mismaLinea(String a, String b) =>
    a.trim().toUpperCase() == b.trim().toUpperCase();

/// Convierte una llegada cruda en la llegada del contrato que se muestra en
/// la tarjeta de opción (sin geometría).
LlegadaBus? proximaLlegadaDeLinea(
  List<LlegadaEnParada> llegadas,
  String linea,
  RecorridoLinea? recorrido,
) {
  final seg = SeguidorBus(linea: linea, recorrido: recorrido);
  final b = seg.elegir(llegadas);
  if (b == null) return null;
  return LlegadaBus(
    linea: b.linea,
    minutos: b.minutos,
    enVivo: b.enVivo,
    posicion: b.posicion,
  );
}
