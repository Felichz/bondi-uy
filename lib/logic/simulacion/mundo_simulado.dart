// Mundo simulado: reloj acelerado + GPS del usuario + buses sintéticos.
//
// Sirve para dos cosas:
// - Modo `simulado` y modo demo de la app: el usuario y los buses se mueven
//   solos, a velocidad acelerada, por las calles y los shapes GTFS reales.
//   Permite recorrer todos los flujos sin salir a la calle.
// - Tests: el mismo mundo con tiempo falso (fake_async / WidgetTester).
//
// Todo es continuo en el tiempo, para que nada salte ni vuelva atrás:
// - Cada línea que pasa por una parada tiene un horario fijo (un bus cada
//   [ParametrosSimulacion.frecuencia]). Cada vehículo es una función del
//   tiempo: viene por el recorrido, se detiene en la parada y sigue. Una vez
//   fijado, el horario no se corre nunca.
// - El usuario viaja EN uno de esos vehículos (el primero que llega después
//   de él a la parada): su posición arriba del bus es la del vehículo.
// - El guion del usuario empieza cada tramo donde terminó el anterior: si la
//   geometría de un tramo no arranca justo ahí, camina hasta ella.

import 'dart:async';
import 'dart:math' as math;

import '../../contract/modelo.dart';
import '../geo/geo.dart';
import '../puertos.dart';
import '../viaje/seguidor_bus.dart';

class ParametrosSimulacion {
  /// Multiplicador del tiempo (8 = un viaje de 40 min dura 5 min).
  final double velocidad;
  final double caminarMps;
  final double busMps;

  /// Cada cuánto (tiempo real) se emite una muestra de GPS.
  final Duration intervaloGps;

  /// Segundos (simulados) que el usuario espera en la parada, como mínimo,
  /// antes de que llegue su bus.
  final int esperaMinima;

  /// Cada cuánto pasa un bus de una misma línea por una parada.
  final Duration frecuencia;

  /// Cuánto se queda el bus detenido en la parada de subida.
  final Duration detenido;

  /// Cuánto tarda el usuario en bajar del bus.
  final Duration bajada;

  const ParametrosSimulacion({
    this.velocidad = 8,
    this.caminarMps = 1.4,
    this.busMps = 8.3,
    this.intervaloGps = const Duration(seconds: 1),
    this.esperaMinima = 20,
    this.frecuencia = const Duration(minutes: 4),
    this.detenido = const Duration(seconds: 10),
    this.bajada = const Duration(seconds: 8),
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

  /// Servicios (línea + parada de subida) con horario: "parada|linea".
  final Map<String, _Servicio> _servicios = {};

  _Guion? _guion;

  // ------------------------------------------------------------------------
  // Viaje del usuario
  // ------------------------------------------------------------------------

  /// El usuario empieza a recorrer [opcion] (lo llama el controlador).
  Future<void> recorrer(OpcionViaje opcion, Map<String, String> shapes) async {
    final recorridos = <String, RecorridoLinea?>{};
    for (final t in opcion.tramos.whereType<TramoBus>()) {
      recorridos[t.id] = await _recorridoDe(t, shapes[t.id]);
    }
    final desde = muestra().coordenada;
    _guion = _Guion.construir(this, opcion, recorridos, ahora(), desde);
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

  /// Recorrido del bus de [t] sobre su shape GTFS (o, sin shape, sobre la
  /// geometría del tramo), con la parada de subida en la pasada correcta.
  Future<RecorridoLinea?> _recorridoDe(TramoBus t, String? shapeId) async {
    final shape = shapeId == null ? null : await catalogo.shape(shapeId);
    final subida = t.subida.coordenada, bajada = t.bajada.coordenada;
    return (shape == null
            ? null
            : RecorridoLinea.crear(shape, subida, bajada: bajada)) ??
        RecorridoLinea.crear(t.geometria, subida, bajada: bajada);
  }

  /// El servicio de [linea] en [parada]; si no existía, se crea con su
  /// próximo bus llegando en [primera].
  _Servicio _servicio(
    String parada,
    String linea,
    RecorridoLinea recorrido,
    DateTime primera,
  ) => _servicios['$parada|$linea'] ??= _Servicio(
    linea: linea,
    recorrido: recorrido,
    primera: primera,
    p: p,
  );

  List<LlegadaEnParada> llegadasEn(String parada, List<String> lineas) {
    final t = ahora();
    final res = <LlegadaEnParada>[];
    // Las líneas con servicio en la parada se informan siempre, aunque el
    // catálogo traiga muchas.
    final todas = {
      ...lineas,
      for (final s in _servicios.entries)
        if (s.key.startsWith('$parada|')) s.value.linea,
    };
    for (final linea in todas) {
      final s = _servicios['$parada|$linea'];
      if (s == null) {
        res.add(_porHorario(parada, linea, t));
        continue;
      }
      var hayEnCamino = false;
      for (final k in s.cercanos(t)) {
        final rec = s.recorridoEn(k, t);
        // Todavía no salió, ya terminó, o pasó hace rato: la fuente no lo da.
        if (rec < 0 || rec > s.shape.largo || rec > s.recParada + 400) {
          continue;
        }
        final segundos = s.llegada(k).difference(t).inMilliseconds / 1000;
        hayEnCamino = true;
        res.add(
          LlegadaEnParada(
            LlegadaBus(
              linea: linea,
              minutos: (math.max(0, segundos) / 60).ceil(),
              enVivo: true,
              posicion: s.shape.puntoEn(rec),
            ),
            vehiculo: 'sim-$linea-$k',
          ),
        );
      }
      if (!hayEnCamino) {
        // El próximo todavía no salió: solo su horario.
        final k = s.proximoDesde(t);
        res.add(
          LlegadaEnParada(
            LlegadaBus(
              linea: linea,
              minutos: (s.llegada(k).difference(t).inSeconds / 60).ceil(),
              enVivo: false,
            ),
            vehiculo: 'sim-$linea-$k',
          ),
        );
      }
    }
    return res;
  }

  /// Líneas sin recorrido conocido: un horario fijo por línea y parada (no
  /// se mueve nunca para atrás).
  LlegadaEnParada _porHorario(String parada, String linea, DateTime t) {
    const cada = 9 * 60;
    final fase = Object.hash(parada, linea).abs() % cada;
    final s = t.millisecondsSinceEpoch ~/ 1000;
    final k = ((s - fase) / cada).ceil();
    final llega = k * cada + fase;
    return LlegadaEnParada(
      LlegadaBus(
        linea: linea,
        minutos: ((llega - s) / 60).ceil(),
        enVivo: false,
      ),
      vehiculo: 'hor-$linea-$k',
    );
  }

  /// Prepara el servicio de una línea en una parada (para previsualizar el
  /// bus en las opciones antes de iniciar el viaje): su próximo bus llega en
  /// [llegaEn]. Si ya existía, no se toca: el horario no se corre.
  Future<void> prepararLinea(
    TramoBus bus,
    String? shapeId, {
    required Duration llegaEn,
  }) async {
    if (_servicios.containsKey('${bus.subida.id}|${bus.linea}')) return;
    final recorrido = await _recorridoDe(bus, shapeId);
    if (recorrido == null) return;
    _servicio(bus.subida.id, bus.linea, recorrido, ahora().add(llegaEn));
  }
}

extension on Stopwatch {
  Duration Function() get elapsedFn => () => elapsed;
}

/// Una línea que pasa por una parada, con horario fijo: el vehículo `k`
/// llega a la parada en `primera + k * frecuencia`.
class _Servicio {
  final String linea;
  final RecorridoLinea recorrido;
  final DateTime primera;
  final ParametrosSimulacion p;

  _Servicio({
    required this.linea,
    required this.recorrido,
    required this.primera,
    required this.p,
  });

  Polilinea get shape => recorrido.linea;
  double get recParada => recorrido.recorridoParada;

  DateTime llegada(int k) => primera.add(p.frecuencia * k);

  /// Metros sobre el shape del vehículo [k] en [t]: viene a velocidad
  /// constante, se detiene en la parada y sigue.
  double recorridoEn(int k, DateTime t) {
    final dt = t.difference(llegada(k)).inMicroseconds / 1e6;
    if (dt < 0) return recParada + dt * p.busMps;
    final det = p.detenido.inMicroseconds / 1e6;
    if (dt <= det) return recParada;
    return recParada + (dt - det) * p.busMps;
  }

  /// El primer vehículo que llega a la parada en [t] o después.
  int proximoDesde(DateTime t) =>
      (t.difference(primera).inMicroseconds / p.frecuencia.inMicroseconds)
          .ceil();

  /// Vehículos que pueden estar sobre el recorrido en [t].
  Iterable<int> cercanos(DateTime t) sync* {
    final f = p.frecuencia.inMicroseconds / 1e6;
    final antes = (recParada / p.busMps / f).ceil() + 1;
    final despues =
        ((shape.largo - recParada) / p.busMps / f).ceil() + 1;
    final k = proximoDesde(t);
    for (var i = k - despues; i <= k + antes; i++) {
      yield i;
    }
  }
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
  final _Posicion Function(DateTime t) en;
  const _Segmento(this.desde, this.hasta, this.en);
}

class _Guion {
  final List<_Segmento> segmentos;
  _Guion(this.segmentos);

  static _Guion construir(
    MundoSimulado m,
    OpcionViaje o,
    Map<String, RecorridoLinea?> recorridos,
    DateTime inicio,
    Coordenada desde,
  ) {
    final p = m.p;
    final segs = <_Segmento>[];
    var t = inicio;
    var aqui = desde;
    Duration seg(double s) => Duration(microseconds: (s * 1e6).round());

    void quieto(DateTime hasta) {
      if (!hasta.isAfter(t)) return;
      final c = aqui;
      segs.add(_Segmento(t, hasta, (_) => _Posicion(c, 0)));
      t = hasta;
    }

    // De [aqui] a [b] en línea recta durante [d].
    void haciaEn(Coordenada b, Duration d) {
      final a = aqui, t0 = t, t1 = t.add(d);
      final v = distancia(a, b) / math.max(0.001, d.inMicroseconds / 1e6);
      segs.add(
        _Segmento(t0, t1, (x) {
          final f = (x.difference(t0).inMicroseconds / d.inMicroseconds).clamp(
            0.0,
            1.0,
          );
          return _Posicion(
            Coordenada(a.lat + (b.lat - a.lat) * f, a.lng + (b.lng - a.lng) * f),
            v,
          );
        }),
      );
      t = t1;
      aqui = b;
    }

    // Camina por [pts] desde donde está: se suma al camino en su punto más
    // cercano (entre los primeros metros), sin volver a su comienzo.
    void caminarPor(List<Coordenada> pts) {
      var resto = pts;
      if (pts.length >= 2) {
        final poli = Polilinea(pts);
        final unirse = poli.proyectar(aqui, hasta: math.min(poli.largo, 150));
        resto = poli.tramo(unirse.recorrido, poli.largo);
      }
      final camino = [
        if (resto.isEmpty || distancia(aqui, resto.first) > 0.5) aqui,
        ...resto,
      ];
      if (camino.length < 2) return;
      final poli = Polilinea(camino);
      final dur = seg(poli.largo / p.caminarMps);
      final t0 = t;
      segs.add(
        _Segmento(t0, t0.add(dur), (x) {
          final f =
              dur.inMicroseconds == 0
                  ? 1.0
                  : (x.difference(t0).inMicroseconds / dur.inMicroseconds)
                      .clamp(0.0, 1.0);
          return _Posicion(poli.puntoEn(poli.largo * f), p.caminarMps);
        }),
      );
      t = t0.add(dur);
      aqui = camino.last;
    }

    // Baja del bus del tramo [i]: unos segundos quieto y sigue desde ahí
    // (la caminata siguiente lo toma donde está). Si el viaje termina en el
    // bus, camina hasta la parada.
    void bajar(int i, Coordenada parada) {
      quieto(t.add(p.bajada));
      if (i + 1 >= o.tramos.length) caminarPor([parada]);
    }

    // El vehículo que toma el usuario en la próxima subida.
    (_Servicio, int)? vehiculo;

    for (var i = 0; i < o.tramos.length; i++) {
      final tramo = o.tramos[i];
      switch (tramo) {
        case TramoCaminar(:final geometria):
          caminarPor(geometria);
        case TramoEsperar(:final parada):
          if (distancia(aqui, parada.coordenada) > 0.5) {
            caminarPor([parada.coordenada]);
          }
          final bus = o.tramos[i + 1] as TramoBus;
          final rec = recorridos[bus.id];
          if (rec == null) break;
          final minimo = t.add(Duration(seconds: p.esperaMinima));
          // El servicio de la primera subida ya existe desde la vista previa
          // (y no se corre); el de un trasbordo se crea ahora, con su bus
          // llegando poco después del usuario.
          final s = m._servicio(parada.id, bus.linea, rec, minimo);
          final k = s.proximoDesde(minimo);
          vehiculo = (s, k);
          quieto(s.llegada(k));
        case TramoBus(:final subida, :final bajada):
          final rec = recorridos[tramo.id];
          if (rec == null) {
            // Sin recorrido: va directo por la geometría del tramo.
            final poli = Polilinea(tramo.geometria);
            final dur = seg(poli.largo / p.busMps);
            final t0 = t;
            segs.add(
              _Segmento(t0, t0.add(dur), (x) {
                final f = (x.difference(t0).inMicroseconds /
                        math.max(1, dur.inMicroseconds))
                    .clamp(0.0, 1.0);
                return _Posicion(poli.puntoEn(poli.largo * f), p.busMps);
              }),
            );
            t = t0.add(dur);
            aqui = tramo.geometria.last;
            bajar(i, bajada.coordenada);
            break;
          }
          final (s, k) =
              vehiculo ??
              () {
                final s = m._servicio(subida.id, tramo.linea, rec, t);
                return (s, s.proximoDesde(t));
              }();
          vehiculo = null;
          // Sube mientras el bus está detenido en la parada.
          quieto(s.llegada(k));
          haciaEn(s.shape.puntoEn(s.recParada), p.detenido);
          // Viaja en ese vehículo hasta la bajada.
          final recBajada = math.max(
            s.recParada + 1,
            s.shape.proyectar(bajada.coordenada, desde: s.recParada).recorrido,
          );
          final llegaBajada = s
              .llegada(k)
              .add(p.detenido)
              .add(seg((recBajada - s.recParada) / p.busMps));
          final t0 = t;
          segs.add(
            _Segmento(
              t0,
              llegaBajada,
              (x) => _Posicion(
                s.shape.puntoEn(math.min(recBajada, s.recorridoEn(k, x))),
                p.busMps,
              ),
            ),
          );
          t = llegaBajada;
          aqui = s.shape.puntoEn(recBajada);
          bajar(i, bajada.coordenada);
      }
    }
    if (segs.isEmpty) {
      final c = aqui;
      segs.add(_Segmento(t, t, (_) => _Posicion(c, 0)));
    }
    return _Guion(segs);
  }

  _Posicion posicion(DateTime t) {
    for (final s in segmentos) {
      if (!t.isAfter(s.hasta)) {
        return s.en(t.isBefore(s.desde) ? s.desde : t);
      }
    }
    final ult = segmentos.last.en(segmentos.last.hasta);
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
        bus,
        v.shapePorTramo[bus.id],
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
