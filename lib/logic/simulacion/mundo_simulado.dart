// Mundo simulado: reloj acelerado + GPS del usuario + buses sintéticos.
//
// Sirve para dos cosas:
// - Modo `simulado` de la app: se planifica con OTP real, pero el usuario y
//   los buses se mueven solos, a velocidad acelerada, por las calles y los
//   shapes GTFS reales. Permite recorrer todos los flujos sin salir a la calle.
// - Tests: el mismo mundo con tiempo falso (fake_async / WidgetTester).
//
// El guion es coherente: el bus que el usuario espera llega a la parada
// cuando corresponde y el usuario "sube" y viaja con él.

import 'dart:async';
import 'dart:math' as math;

import '../../contract/modelo.dart';
import '../geo/geo.dart';
import '../puertos.dart';

class ParametrosSimulacion {
  /// Multiplicador del tiempo (8 = un viaje de 40 min dura 5 min).
  final double velocidad;
  final double caminarMps;
  final double busMps;

  /// Cada cuánto (tiempo real) se emite una muestra de GPS.
  final Duration intervaloGps;

  /// Segundos (simulados) que el bus tarda en llegar a la parada después de
  /// que el usuario llega, como mínimo.
  final int esperaMinima;

  const ParametrosSimulacion({
    this.velocidad = 8,
    this.caminarMps = 1.4,
    this.busMps = 8.3,
    this.intervaloGps = const Duration(seconds: 1),
    this.esperaMinima = 45,
  });
}

class MundoSimulado {
  final ParametrosSimulacion p;
  final CatalogoRed catalogo;
  Coordenada posicionInicial;

  final DateTime _inicioSim;

  /// Tiempo real transcurrido desde el inicio (inyectable en tests).
  final Duration Function() _transcurrido;

  MundoSimulado({
    required this.catalogo,
    required this.posicionInicial,
    this.p = const ParametrosSimulacion(),
    DateTime? ahoraSimulado,
    Duration Function()? transcurrido,
  }) : _inicioSim = ahoraSimulado ?? DateTime.now(),
       _transcurrido = transcurrido ?? (Stopwatch()..start()).elapsedFn;

  late double _velocidad = p.velocidad;
  Duration _anclaReal = Duration.zero;
  DateTime? _anclaSim;

  /// Multiplicador del tiempo; se puede cambiar en marcha (modo demo).
  double get velocidad => _velocidad;

  /// Cambia la velocidad sin que el reloj salte: desde ahora corre a [v].
  set velocidad(double v) {
    final t = ahora();
    _anclaReal = _transcurrido();
    _anclaSim = t;
    _velocidad = v;
  }

  /// Reloj simulado (inyectar como `Reloj` en el controlador).
  DateTime ahora() => (_anclaSim ?? _inicioSim).add(
    Duration(
      microseconds:
          ((_transcurrido() - _anclaReal).inMicroseconds * _velocidad).round(),
    ),
  );

  // Llegadas programadas de buses sintéticos: "parada|linea" -> momento.
  final Map<String, DateTime> _llegadaBus = {};
  final Map<String, Polilinea> _shapes = {};
  final Map<String, double> _recorridoParada = {};

  _Guion? _guion;

  // ------------------------------------------------------------------------
  // Viaje del usuario
  // ------------------------------------------------------------------------

  /// El usuario empieza a recorrer [opcion] (lo llama el controlador).
  Future<void> recorrer(OpcionViaje opcion, Map<String, String> shapes) async {
    final lineasBus = <String, Polilinea>{};
    for (final t in opcion.tramos.whereType<TramoBus>()) {
      final shapeId = shapes[t.id];
      final shape = shapeId == null ? null : await catalogo.shape(shapeId);
      final poli = Polilinea(shape ?? t.geometria);
      lineasBus[t.id] = poli;
      _registrarShape(t.subida.id, t.linea, poli, t.subida.coordenada);
    }
    _guion = _Guion.construir(this, opcion, lineasBus, ahora());
  }

  void detener() {
    final g = _guion;
    if (g != null) posicionInicial = g.posicion(ahora()).coordenada;
    _guion = null;
  }

  MuestraUbicacion muestra() {
    final t = ahora();
    final g = _guion;
    if (g == null) {
      return MuestraUbicacion(
        coordenada: posicionInicial,
        momento: t,
        velocidad: 0,
        precision: 5,
      );
    }
    final pos = g.posicion(t);
    return MuestraUbicacion(
      coordenada: pos.coordenada,
      momento: t,
      velocidad: pos.velocidad,
      precision: 5,
    );
  }

  // ------------------------------------------------------------------------
  // Buses sintéticos
  // ------------------------------------------------------------------------

  void _registrarShape(
    String parada,
    String linea,
    Polilinea shape,
    Coordenada c,
  ) {
    final k = '$parada|$linea';
    _shapes[k] = shape;
    _recorridoParada[k] = shape.proyectar(c).recorrido;
  }

  /// Momento en que llega el próximo bus de [linea] a [parada].
  DateTime llegadaProgramada(String parada, String linea, {Duration? minimo}) {
    final k = '$parada|$linea';
    final t = ahora();
    var llegada = _llegadaBus[k];
    if (llegada == null ||
        llegada.isBefore(t.subtract(const Duration(seconds: 20)))) {
      llegada = t.add(minimo ?? const Duration(minutes: 4));
      _llegadaBus[k] = llegada;
    }
    return llegada;
  }

  void _fijarLlegada(String parada, String linea, DateTime momento) {
    _llegadaBus['$parada|$linea'] = momento;
  }

  List<LlegadaEnParada> llegadasEn(String parada, List<String> lineas) {
    final t = ahora();
    final res = <LlegadaEnParada>[];
    for (final linea in lineas) {
      final k = '$parada|$linea';
      final llegada = llegadaProgramada(parada, linea);
      final segundos = llegada.difference(t).inSeconds;
      if (segundos < -15) continue;
      Coordenada? pos;
      final shape = _shapes[k];
      if (shape != null) {
        final rec = _recorridoParada[k]! - math.max(0, segundos) * p.busMps;
        pos = shape.puntoEn(math.max(0, rec));
      }
      res.add(
        LlegadaEnParada(
          LlegadaBus(
            linea: linea,
            minutos: (math.max(0, segundos) / 60).ceil(),
            enVivo: pos != null,
            posicion: pos,
          ),
          vehiculo: 'sim-$linea-${llegada.millisecondsSinceEpoch}',
        ),
      );
    }
    return res;
  }

  /// Prepara la geometría de una línea en una parada (para previsualizar
  /// el bus en las opciones antes de iniciar el viaje).
  Future<void> prepararLinea(
    String parada,
    Coordenada coordParada,
    String linea,
    String? shapeId,
    List<Coordenada> geometriaTramo, {
    required Duration llegaEn,
  }) async {
    final k = '$parada|$linea';
    if (!_shapes.containsKey(k)) {
      final shape = shapeId == null ? null : await catalogo.shape(shapeId);
      _registrarShape(
        parada,
        linea,
        Polilinea(shape ?? geometriaTramo),
        coordParada,
      );
    }
    llegadaProgramada(parada, linea, minimo: llegaEn);
  }
}

extension on Stopwatch {
  Duration Function() get elapsedFn => () => elapsed;
}

// --------------------------------------------------------------------------
// Guion del usuario
// --------------------------------------------------------------------------

class _Posicion {
  final Coordenada coordenada;
  final double velocidad;
  const _Posicion(this.coordenada, this.velocidad);
}

class _Segmento {
  final DateTime desde;
  final DateTime hasta;
  final _Posicion Function(double fraccion) en;
  const _Segmento(this.desde, this.hasta, this.en);
}

class _Guion {
  final List<_Segmento> segmentos;
  _Guion(this.segmentos);

  static _Guion construir(
    MundoSimulado m,
    OpcionViaje o,
    Map<String, Polilinea> lineasBus,
    DateTime inicio,
  ) {
    final segs = <_Segmento>[];
    var t = inicio;
    Duration seg(double s) => Duration(milliseconds: (s * 1000).round());

    for (var i = 0; i < o.tramos.length; i++) {
      final tramo = o.tramos[i];
      switch (tramo) {
        case TramoCaminar():
          final poli = Polilinea(tramo.geometria);
          final dur = seg(poli.largo / m.p.caminarMps);
          final desde = t;
          segs.add(
            _Segmento(desde, desde.add(dur), (f) {
              return _Posicion(poli.puntoEn(poli.largo * f), m.p.caminarMps);
            }),
          );
          t = t.add(dur);
        case TramoEsperar():
          final bus = o.tramos[i + 1] as TramoBus;
          // El bus llega al menos `esperaMinima` después de que el usuario
          // llega a la parada, y nunca antes de lo que ya se le mostró.
          final minimo = t.add(Duration(seconds: m.p.esperaMinima));
          final previa = m._llegadaBus['${tramo.parada.id}|${tramo.linea}'];
          final llegada =
              (previa != null && previa.isAfter(minimo)) ? previa : minimo;
          m._fijarLlegada(tramo.parada.id, tramo.linea, llegada);
          final c = tramo.parada.coordenada;
          segs.add(_Segmento(t, llegada, (_) => _Posicion(c, 0)));
          // 10 s de ascenso con el bus detenido.
          final sube = llegada.add(const Duration(seconds: 10));
          segs.add(_Segmento(llegada, sube, (_) => _Posicion(c, 0)));
          t = sube;
          assert(lineasBus.containsKey(bus.id));
        case TramoBus():
          final poli = lineasBus[tramo.id]!;
          final desdeRec = poli.proyectar(tramo.subida.coordenada).recorrido;
          final hastaRec =
              poli
                  .proyectar(tramo.bajada.coordenada, desde: desdeRec)
                  .recorrido;
          final metros = math.max(1.0, hastaRec - desdeRec);
          final dur = seg(metros / m.p.busMps);
          segs.add(
            _Segmento(t, t.add(dur), (f) {
              return _Posicion(poli.puntoEn(desdeRec + metros * f), m.p.busMps);
            }),
          );
          t = t.add(dur);
          // Bajar del bus.
          final c = tramo.bajada.coordenada;
          final baja = t.add(const Duration(seconds: 8));
          segs.add(_Segmento(t, baja, (_) => _Posicion(c, 0)));
          t = baja;
      }
    }
    return _Guion(segs);
  }

  _Posicion posicion(DateTime t) {
    for (final s in segmentos) {
      if (!t.isAfter(s.hasta)) {
        final total = s.hasta.difference(s.desde).inMilliseconds;
        final f =
            total <= 0
                ? 1.0
                : (t.difference(s.desde).inMilliseconds / total).clamp(
                  0.0,
                  1.0,
                );
        return s.en(f);
      }
    }
    final ult = segmentos.last.en(1);
    return _Posicion(ult.coordenada, 0);
  }
}

// --------------------------------------------------------------------------
// Puertos simulados
// --------------------------------------------------------------------------

class UbicacionSimulada implements FuenteUbicacion {
  final MundoSimulado mundo;
  UbicacionSimulada(this.mundo);

  @override
  Future<PermisoUbicacion> asegurarPermiso() async =>
      PermisoUbicacion.concedido;

  @override
  Future<MuestraUbicacion?> actual() async => mundo.muestra();

  @override
  Stream<MuestraUbicacion> seguir() {
    late StreamController<MuestraUbicacion> c;
    Timer? timer;
    c = StreamController<MuestraUbicacion>(
      onListen: () {
        timer = Timer.periodic(
          mundo.p.intervaloGps,
          (_) => c.add(mundo.muestra()),
        );
      },
      onCancel: () => timer?.cancel(),
    );
    return c.stream;
  }
}

/// Envuelve un planificador real y prepara los buses sintéticos de cada
/// opción, para que la vista previa ya muestre un bus viniendo.
class PlanificadorSimulado implements PlanificadorViajes {
  final PlanificadorViajes real;
  final MundoSimulado mundo;
  final Map<String, Map<String, String>> _shapes = {};

  PlanificadorSimulado(this.real, this.mundo);

  Map<String, String> shapesDe(String idOpcion) =>
      _shapes[idOpcion] ?? const {};

  @override
  Future<List<ViajePlanificado>> planificar({
    required Coordenada origen,
    required Coordenada destino,
    required DateTime salida,
  }) async {
    final viajes = await real.planificar(
      origen: origen,
      destino: destino,
      salida: salida,
    );
    for (final v in viajes) {
      _shapes[v.opcion.id] = v.shapePorTramo;
      final bus = v.opcion.primerBus;
      if (bus == null) continue;
      final caminata =
          v.opcion.tramos.first is TramoCaminar
              ? (v.opcion.tramos.first as TramoCaminar).duracionSegundos
              : 0;
      await mundo.prepararLinea(
        bus.subida.id,
        bus.subida.coordenada,
        bus.linea,
        v.shapePorTramo[bus.id],
        bus.geometria,
        llegaEn: Duration(seconds: caminata + 90),
      );
    }
    return viajes;
  }
}

class LlegadasSimuladas implements FuenteLlegadas {
  final MundoSimulado mundo;

  /// Líneas que pasan por cada parada (del catálogo).
  final Future<Map<String, List<String>>> _lineas;

  LlegadasSimuladas(this.mundo)
    : _lineas = mundo.catalogo.paradas().then(
        (ps) => {for (final p in ps) p.parada.id: p.lineas},
      );

  @override
  Future<List<LlegadaEnParada>> llegadas(String idParada) async {
    final lineas = (await _lineas)[idParada] ?? const <String>[];
    return mundo.llegadasEn(idParada, lineas.take(6).toList());
  }
}
