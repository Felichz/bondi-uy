// Selección del bus que viene a una parada y su recorrido de aproximación.
//
// Reglas de veracidad (heredadas del contrato visual E2E):
// - La aproximación sigue el shape GTFS en el sentido de marcha. Nunca una
//   recta entre bus y parada, nunca un shape invertido.
// - Un bus que ya pasó la parada no "viene": se descarta.
// - Entre sondeos se sigue al mismo vehículo mientras siga viniendo.
// - Cuando el bus que se seguía llega a la parada, deja de "venir" (la
//   fuente lo da por pasado o deja de informarlo). Si el usuario lo está
//   esperando, ese no es el momento de anunciar el próximo: está subiendo.
//   Se lo informa como llegado (0 min, 0 m) durante un rato; recién después,
//   si no subió, se pasa al siguiente.

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

  /// El recorrido del bus de [tramo]: sobre su [shape] GTFS o, sin shape (o
  /// si la parada no está sobre él), sobre la geometría del tramo. Lo usan
  /// el seguimiento del bus y el mundo simulado, para que los dos ubiquen la
  /// parada en el mismo lugar.
  static RecorridoLinea? deTramo(TramoBus tramo, List<Coordenada>? shape) {
    final subida = tramo.subida.coordenada, bajada = tramo.bajada.coordenada;
    return (shape == null ? null : crear(shape, subida, bajada: bajada)) ??
        crear(tramo.geometria, subida, bajada: bajada);
  }

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

  /// Metros de recorrido antes del bus que se incluyen en su camino.
  static const metrosAtras = 2000.0;

  /// Aproximación bus -> parada, o null si el bus no está sobre el recorrido
  /// antes de la parada. [camino] incluye además por dónde venía.
  ({
    List<Coordenada> puntos,
    List<Coordenada> camino,
    double metros,
    double rumbo,
  })?
  aproximacion(
    Coordenada bus, {
    double maxLateral = 150,
  }) {
    final p = linea.proyectar(bus, hasta: recorridoParada);
    if (p.distanciaLateral > maxLateral) return null;
    // (Detenido en la parada, el redondeo puede ubicarlo un pelo después.)
    if (p.recorrido > recorridoParada + 1) return null;
    final rec = math.min(p.recorrido, recorridoParada);
    final puntos = [bus, ...linea.tramo(rec, recorridoParada)];
    return (
      puntos: puntos,
      camino: linea.tramo(math.max(0, rec - metrosAtras), recorridoParada),
      metros: recorridoParada - rec,
      rumbo: linea.rumboEn(rec),
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
  final DateTime Function()? _reloj;

  /// El vehículo que se sigue y su último estado.
  String? _vehiculo;
  BusEnCamino? _ultimo;

  /// El bus seguido cuando estaba por llegar (null si venía lejos).
  BusEnCamino? _llegando;

  /// ¿Lo esperaba alguien la última vez que se lo vio venir?
  bool _esperadoAlLlegar = false;

  /// Ya se informó una vez que llegó; desde cuándo (o cuántos sondeos) se
  /// lo retiene.
  bool _llegadaInformada = false;
  DateTime? _llegoEn;
  int _sondeosRetenido = 0;

  /// Sondeos que se informa "llegó" antes de pasar al siguiente bus, sin
  /// reloj (con reloj se usa [retencion]).
  static const sondeosLlegado = 6;

  /// Cuánto se informa "llegó" antes de pasar al siguiente bus: lo que tarda
  /// en confirmarse que el usuario subió, sin importar cada cuánto se sondee.
  static const retencion = Duration(minutes: 2);

  /// A esta distancia (o 0 min) el bus se considera llegando.
  static const metrosLlegando = 150;

  /// A esta distancia del usuario que se quedó en la parada, el bus que se
  /// fue ya no lo lleva.
  static const metrosPerdido = 80.0;

  SeguidorBus({required this.linea, this.recorrido, DateTime Function()? reloj})
    : _reloj = reloj;

  /// Elige el bus relevante entre las llegadas a la parada. Con [retener]
  /// (el usuario espera en la parada), el bus que llegó se sigue informando
  /// como llegado un rato; sin él, se pasa enseguida al próximo. Si el bus
  /// ya se fue de la parada, [usuarioEnLaParada] (el usuario se quedó) y ya
  /// está lejos de [usuario], lo perdió: deja de informarse.
  BusEnCamino? elegir(
    List<LlegadaEnParada> llegadas, {
    bool retener = true,
    bool usuarioEnLaParada = false,
    Coordenada? usuario,
  }) {
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
        if (l.vehiculo == _vehiculo) return _seguido(b, retener);
      }
      // Ya no viene: si estaba llegando, llegó. También si la fuente todavía
      // lo informa del otro lado de la parada, aunque ningún sondeo lo haya
      // visto cerca (entre dos sondeos se detuvo y siguió).
      Coordenada? real;
      for (final l in candidatos) {
        if (l.vehiculo == _vehiculo) real = l.datos.posicion;
      }
      final paso = real != null && (recorrido?.yaPaso(real) ?? false);
      final llegado = _llegando ?? (paso ? _ultimo : null);
      // Se fue de la parada, el usuario sigue ahí y el bus ya está lejos de
      // él: lo perdió (ya no se lo informa llegado, viene el próximo). Lejos
      // es más de lo que el bus avanza entre una lectura del GPS y la otra:
      // recién subido, la última lectura todavía lo puede dar en la parada.
      final sinElUsuario =
          paso &&
          usuario != null &&
          usuarioEnLaParada &&
          distancia(real, usuario) > metrosPerdido;
      // Un bus que llegó se informa en la parada al menos una vez, aunque
      // nadie lo espere: no deja su lugar al próximo sin haber llegado. Se lo
      // retiene un rato más solo si cuando se lo vio llegar alguien lo
      // esperaba (si llegó mientras el usuario caminaba, ya se fue: viene el
      // próximo).
      final primera = llegado != null && !_llegadaInformada && !sinElUsuario;
      final sigue =
          llegado != null &&
          retener &&
          _esperadoAlLlegar &&
          !sinElUsuario &&
          _sigueRetenido();
      if (llegado != null && (primera || sigue)) {
        _llegando = llegado;
        _llegadaInformada = true;
        return BusEnCamino(
          linea: llegado.linea,
          // Si lo esperaban, donde va (el usuario va arriba); si no, en la
          // parada, donde se lo vio llegar.
          posicion:
              retener && _esperadoAlLlegar
                  ? real ?? recorrido?.parada ?? llegado.posicion
                  : recorrido?.parada ?? llegado.posicion,
          minutos: 0,
          enVivo: llegado.enVivo,
          camino: llegado.camino,
          metrosHastaParada: 0,
          rumbo: llegado.rumbo,
        );
      }
    }
    _llegando = null;
    _ultimo = null;
    _llegadaInformada = false;
    _sondeosRetenido = 0;
    _llegoEn = null;
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
    return _seguido(b, retener);
  }

  bool _sigueRetenido() {
    final reloj = _reloj;
    if (reloj == null) return _sondeosRetenido++ < sondeosLlegado;
    final ahora = reloj();
    _llegoEn ??= ahora;
    return ahora.difference(_llegoEn!) < retencion;
  }

  BusEnCamino _seguido(BusEnCamino b, bool retener) {
    _ultimo = b;
    _esperadoAlLlegar = retener;
    final m = b.metrosHastaParada;
    _llegando =
        b.enVivo && (b.minutos == 0 || (m != null && m <= metrosLlegando))
            ? b
            : null;
    _sondeosRetenido = 0;
    _llegoEn = null;
    _llegadaInformada = false;
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
      camino: ap.camino.length >= 2 ? ap.camino : null,
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
