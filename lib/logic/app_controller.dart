// Implementación de AppActions: el "chef" de datos de la app.
//
// Recibe intenciones de la UI, consulta los puertos (OTP, API de Montevideo,
// geocoding, GPS, catálogo GTFS) y publica un AppState nuevo. No conoce
// widgets, mapas, colores ni textos.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contract/app_actions.dart';
import '../contract/app_state.dart';
import 'geo/geo.dart';
import 'puertos.dart';
import 'viaje/navegador.dart';
import 'viaje/recomendador.dart';
import 'viaje/seguidor_bus.dart';

class ConfigLogica {
  final Duration sondeoBus;
  final Duration sondeoParada;
  final Duration debounceSugerencias;
  final ReglasNavegacion reglas;

  /// Paradas de las que se piden ETAs al mostrar opciones.
  final int maxParadasEta;

  const ConfigLogica({
    this.sondeoBus = const Duration(seconds: 10),
    this.sondeoParada = const Duration(seconds: 20),
    this.debounceSugerencias = const Duration(milliseconds: 350),
    this.reglas = const ReglasNavegacion(),
    this.maxParadasEta = 4,
  });
}

class AppController extends StateNotifier<AppState> implements AppActions {
  final PlanificadorViajes _planificador;
  final FuenteLlegadas _llegadas;
  final BuscadorLugares _lugares;
  final CatalogoRed _catalogo;
  final FuenteUbicacion _ubicacion;
  final Reloj _ahora;
  final ConfigLogica config;

  /// Ganchos para el modo demo (simulación de GPS sobre el viaje elegido).
  final void Function(OpcionViaje opcion)? alIniciarViaje;
  final void Function()? alTerminarViaje;

  /// Al llegar al destino (si no se indica, se usa [alTerminarViaje]).
  final void Function()? alLlegar;

  AppController({
    required PlanificadorViajes planificador,
    required FuenteLlegadas llegadas,
    required BuscadorLugares lugares,
    required CatalogoRed catalogo,
    required FuenteUbicacion ubicacion,
    Reloj? reloj,
    this.config = const ConfigLogica(),
    this.alIniciarViaje,
    this.alTerminarViaje,
    this.alLlegar,
    ControlDemo? demo,
    AppState? estadoInicial,
  }) : _demo = demo,
       _planificador = planificador,
       _llegadas = llegadas,
       _lugares = lugares,
       _catalogo = catalogo,
       _ubicacion = ubicacion,
       _ahora = reloj ?? DateTime.now,
       super(
         (estadoInicial ?? AppState.inicial()).copyWith(
           demo:
               demo == null
                   ? null
                   : Demo(
                     velocidad: demo.velocidad,
                     velocidades: demo.velocidades,
                     destinos: demo.destinos,
                   ),
         ),
       );

  final ControlDemo? _demo;

  @override
  void cambiarVelocidadDemo(double velocidad) {
    final d = _demo, actual = state.demo;
    if (d == null || actual == null) return;
    d.velocidad = velocidad;
    state = state.copyWith(demo: actual.conVelocidad(velocidad));
  }

  // --- estado interno (no visible para la UI) ---
  bool _arrancado = false;
  StreamSubscription<MuestraUbicacion>? _gps;
  Timer? _debounce;
  int _secConsulta = 0;
  int _secBusqueda = 0;
  int _secAviso = 0;

  final Map<String, ViajePlanificado> _planificados = {};
  final Map<String, SeguidorBus> _seguidoresOpcion = {};
  Timer? _timerOpciones;
  String? _opcionEnfocada;

  Navegador? _nav;
  Timer? _timerViaje;
  SeguidorBus? _seguidorViaje;
  int? _esperaSeguida;
  int _secViaje = 0;
  final Set<String> _avisosDados = {};

  Timer? _timerParada;
  int _secParada = 0;

  // =====================================================================
  // Arranque y ubicación
  // =====================================================================

  @override
  void arrancar() {
    if (_arrancado) return;
    _arrancado = true;
    unawaited(_cargarParadas());
    unawaited(_iniciarUbicacion());
  }

  Future<void> _cargarParadas() async {
    try {
      final paradas = await _catalogo.paradas();
      if (mounted) state = state.copyWith(paradas: paradas);
    } catch (_) {
      // Sin red de paradas la app sigue funcionando (solo no se muestran).
    }
  }

  @override
  void reintentarUbicacion() => unawaited(_iniciarUbicacion());

  Future<void> _iniciarUbicacion() async {
    _publicarUbicacion(EstadoUbicacion.buscando, state.ubicacion.coordenada);
    final PermisoUbicacion permiso;
    try {
      permiso = await _ubicacion.asegurarPermiso();
    } catch (_) {
      _publicarUbicacion(EstadoUbicacion.error, null);
      return;
    }
    if (!mounted) return;
    switch (permiso) {
      case PermisoUbicacion.concedido:
        break;
      case PermisoUbicacion.servicioApagado:
        _publicarUbicacion(EstadoUbicacion.desactivada, null);
        return;
      case PermisoUbicacion.denegado:
      case PermisoUbicacion.denegadoParaSiempre:
        _publicarUbicacion(EstadoUbicacion.sinPermiso, null);
        return;
    }
    await _gps?.cancel();
    _gps = _ubicacion.seguir().listen(_alRecibirMuestra, onError: (_) {});
    final primera = await _ubicacion.actual();
    if (!mounted) return;
    if (primera != null) {
      _alRecibirMuestra(primera);
    } else if (state.ubicacion.coordenada == null) {
      _publicarUbicacion(EstadoUbicacion.error, null);
    }
  }

  void _publicarUbicacion(EstadoUbicacion estado, Coordenada? c) {
    if (!mounted) return;
    state = state.copyWith(
      ubicacion: UbicacionUsuario(estado: estado, coordenada: c),
    );
  }

  void _alRecibirMuestra(MuestraUbicacion m) {
    if (!mounted) return;
    final previa = state.ubicacion.coordenada;
    final fase = state.fase;
    final moverse =
        previa == null ||
        distancia(previa, m.coordenada) > 2 ||
        state.ubicacion.estado != EstadoUbicacion.disponible;

    if (fase is FaseViaje &&
        fase.estado == EstadoViaje.enCurso &&
        _nav != null) {
      final r = _nav!.procesar(m);
      var nueva = fase.copyWith(
        pasoActual: r.paso,
        progreso: r.progreso,
        usuario: m.coordenada,
        origenAvance: r.avanzo ? OrigenAvance.automatico : null,
      );
      if (r.completado) {
        nueva = nueva.copyWith(estado: EstadoViaje.completado, fin: _ahora());
      }
      state = state.copyWith(
        ubicacion: UbicacionUsuario(
          estado: EstadoUbicacion.disponible,
          coordenada: m.coordenada,
        ),
        fase: nueva,
      );
      if (r.avanzo || r.completado) _alCambiarPaso();
      _avisosDeProgreso();
      return;
    }
    if (moverse) {
      _publicarUbicacion(EstadoUbicacion.disponible, m.coordenada);
    }
  }

  // =====================================================================
  // Búsqueda
  // =====================================================================

  @override
  void escribirConsulta(CampoBusqueda campo, String texto) {
    final t = texto.trim();
    final seq = ++_secConsulta;
    _debounce?.cancel();
    if (t.length < 2) {
      state = state.copyWith(
        busqueda: state.busqueda.conConsulta(
          campo: campo,
          texto: texto,
          sugerencias: const [],
          estado: EstadoSugerencias.inactivo,
        ),
      );
      return;
    }
    state = state.copyWith(
      busqueda: state.busqueda.conConsulta(
        campo: campo,
        texto: texto,
        estado: EstadoSugerencias.cargando,
      ),
    );
    _debounce = Timer(config.debounceSugerencias, () async {
      try {
        final res = await _lugares.sugerencias(
          t,
          cerca: state.ubicacion.coordenada,
        );
        if (!mounted || seq != _secConsulta) return;
        state = state.copyWith(
          busqueda: state.busqueda.conConsulta(
            campo: campo,
            texto: texto,
            sugerencias: res,
            estado: EstadoSugerencias.listo,
          ),
        );
      } catch (_) {
        if (!mounted || seq != _secConsulta) return;
        state = state.copyWith(
          busqueda: state.busqueda.conConsulta(
            campo: campo,
            texto: texto,
            sugerencias: const [],
            estado: EstadoSugerencias.error,
          ),
        );
      }
    });
  }

  @override
  void cancelarConsulta() {
    _debounce?.cancel();
    _secConsulta++;
    state = state.copyWith(busqueda: state.busqueda.sinConsulta());
  }

  @override
  void elegirLugar(CampoBusqueda campo, Lugar lugar) {
    _debounce?.cancel();
    _secConsulta++;
    state = state.copyWith(
      busqueda: state.busqueda.conPunto(campo, LugarElegido(lugar)),
    );
  }

  @override
  void usarMiUbicacion(CampoBusqueda campo) {
    _secConsulta++;
    final actual = state.busqueda;
    // "Mi ubicación" no puede ser origen y destino a la vez.
    if (campo == CampoBusqueda.destino && actual.origen is MiUbicacion) {
      state = state.copyWith(busqueda: actual.sinConsulta());
      return;
    }
    var b = actual.conPunto(campo, const MiUbicacion());
    if (campo == CampoBusqueda.origen && b.destino is MiUbicacion) {
      b = b.conPunto(CampoBusqueda.destino, null);
    }
    state = state.copyWith(busqueda: b);
    if (state.ubicacion.coordenada == null) reintentarUbicacion();
  }

  @override
  void limpiarCampo(CampoBusqueda campo) {
    _secConsulta++;
    state = state.copyWith(busqueda: state.busqueda.conPunto(campo, null));
  }

  @override
  void intercambiarOrigenYDestino() {
    final b = state.busqueda;
    if (b.destino == null) return;
    state = state.copyWith(
      busqueda: Busqueda(origen: b.destino!, destino: b.origen),
    );
  }

  Coordenada? _resolver(PuntoBusqueda? p) => switch (p) {
    MiUbicacion() => state.ubicacion.coordenada,
    LugarElegido(:final lugar) => lugar.coordenada,
    null => null,
  };

  @override
  void buscarViajes() => unawaited(_buscarViajes());

  Future<void> _buscarViajes() async {
    final b = state.busqueda;
    if (b.destino == null) {
      _avisar(TipoAviso.faltaDestino);
      return;
    }
    final origen = _resolver(b.origen);
    final destino = _resolver(b.destino);
    if (origen == null || destino == null) {
      _avisar(TipoAviso.sinUbicacion);
      if (state.ubicacion.coordenada == null) reintentarUbicacion();
      return;
    }
    final seq = ++_secBusqueda;
    _detenerOpciones();
    _planificados.clear();
    state = state.copyWith(
      busqueda: b.sinConsulta(),
      limpiarParadaConsultada: true,
      fase: FaseOpciones(
        estado: EstadoOpciones.cargando,
        origen: origen,
        destino: destino,
      ),
    );
    _cerrarParadaInterno();

    final List<ViajePlanificado> viajes;
    try {
      final crudos = await _planificador.planificar(
        origen: origen,
        destino: destino,
        salida: _ahora(),
      );
      viajes = ordenarYRecomendar(crudos, _ahora());
    } catch (_) {
      if (!mounted || seq != _secBusqueda) return;
      state = state.copyWith(
        fase: FaseOpciones(
          estado: EstadoOpciones.error,
          origen: origen,
          destino: destino,
        ),
      );
      // La fase de opciones en estado `error` ya lo comunica: sin aviso extra.
      return;
    }
    if (!mounted || seq != _secBusqueda || state.fase is! FaseOpciones) return;
    for (final v in viajes) {
      _planificados[v.opcion.id] = v;
    }
    state = state.copyWith(
      fase: FaseOpciones(
        estado:
            viajes.isEmpty
                ? EstadoOpciones.sinResultados
                : EstadoOpciones.listo,
        origen: origen,
        destino: destino,
        opciones: [
          for (final v in viajes)
            v.opcion.conProximoBus(null, aviso: avisoDeOpcion(v.opcion)),
        ],
      ),
    );
    if (viajes.isNotEmpty) unawaited(_etasDeOpciones(seq));
  }

  /// Pide ETAs de la parada de subida del primer bus de cada opción.
  Future<void> _etasDeOpciones(int seq) async {
    final fase = state.fase;
    if (fase is! FaseOpciones) return;
    final paradas = <String>{};
    for (final o in fase.opciones) {
      final b = o.primerBus;
      if (b != null && paradas.length < config.maxParadasEta)
        paradas.add(b.subida.id);
    }
    final resultados = <String, List<LlegadaEnParada>>{};
    await Future.wait([
      for (final id in paradas)
        _llegadas
            .llegadas(id)
            .then((l) => resultados[id] = l)
            .catchError((_) => const <LlegadaEnParada>[]),
    ]);
    if (!mounted || seq != _secBusqueda) return;
    final actual = state.fase;
    if (actual is! FaseOpciones) return;
    final opciones = <OpcionViaje>[];
    for (final o in actual.opciones) {
      final b = o.primerBus;
      final lista = b == null ? null : resultados[b.subida.id];
      if (b == null || lista == null) {
        opciones.add(o);
        continue;
      }
      final seg = _seguidorOpcion(o.id);
      final bus = (await seg)?.elegir(lista);
      final llegada =
          bus == null
              ? null
              : LlegadaBus(
                linea: bus.linea,
                minutos: bus.minutos,
                enVivo: bus.enVivo,
                posicion: bus.posicion,
              );
      opciones.add(
        o.conProximoBus(
          llegada,
          aviso:
              avisoDeOpcion(o, proximo: llegada) ??
              (llegada == null || !llegada.enVivo
                  ? AvisoOpcion.sinDatosEnVivoPrimerBus
                  : null),
        ),
      );
      if (bus != null && bus.posicion != null) {
        _ponerBusOpcion(o.id, bus);
      }
    }
    final f = state.fase;
    if (!mounted || seq != _secBusqueda || f is! FaseOpciones) return;
    state = state.copyWith(fase: f.copyWith(opciones: opciones));
  }

  void _ponerBusOpcion(String id, BusEnCamino bus) {
    final f = state.fase;
    if (f is! FaseOpciones) return;
    state = state.copyWith(
      fase: f.copyWith(busesEnVivo: {...f.busesEnVivo, id: bus}),
    );
  }

  final Map<String, Future<SeguidorBus?>> _seguidoresOpcionFut = {};

  Future<SeguidorBus?> _seguidorOpcion(String idOpcion) {
    return _seguidoresOpcionFut[idOpcion] ??= () async {
      final v = _planificados[idOpcion];
      final bus = v?.opcion.primerBus;
      if (v == null || bus == null) return null;
      final seg = SeguidorBus(
        linea: bus.linea,
        recorrido: await _recorrido(v, bus),
      );
      _seguidoresOpcion[idOpcion] = seg;
      return seg;
    }();
  }

  Future<RecorridoLinea?> _recorrido(ViajePlanificado v, TramoBus bus) async {
    final shapeId = v.shapePorTramo[bus.id];
    List<Coordenada>? shape;
    if (shapeId != null) {
      try {
        shape = await _catalogo.shape(shapeId);
      } catch (_) {}
    }
    if (shape == null) return null;
    return RecorridoLinea.crear(
      shape,
      bus.subida.coordenada,
      bajada: bus.bajada.coordenada,
    );
  }

  @override
  void enfocarOpcion(String idOpcion) {
    if (state.fase is! FaseOpciones) return;
    if (_opcionEnfocada == idOpcion && _timerOpciones != null) return;
    _opcionEnfocada = idOpcion;
    _timerOpciones?.cancel();
    final seq = _secBusqueda;
    unawaited(_sondearOpcion(idOpcion, seq));
    _timerOpciones = Timer.periodic(
      config.sondeoBus,
      (_) => _sondearOpcion(idOpcion, seq),
    );
  }

  Future<void> _sondearOpcion(String idOpcion, int seq) async {
    final v = _planificados[idOpcion];
    final bus = v?.opcion.primerBus;
    if (v == null || bus == null) return;
    final List<LlegadaEnParada> lista;
    try {
      lista = await _llegadas.llegadas(bus.subida.id);
    } catch (_) {
      return;
    }
    final seg = await _seguidorOpcion(idOpcion);
    if (!mounted || seq != _secBusqueda || _opcionEnfocada != idOpcion) return;
    final elegido = seg?.elegir(lista);
    final f = state.fase;
    if (f is! FaseOpciones) return;
    final buses = Map.of(f.busesEnVivo);
    if (elegido == null || elegido.posicion == null) {
      buses.remove(idOpcion);
    } else {
      buses[idOpcion] = elegido;
    }
    final opciones = [
      for (final o in f.opciones)
        if (o.id == idOpcion && elegido != null)
          o.conProximoBus(
            LlegadaBus(
              linea: elegido.linea,
              minutos: elegido.minutos,
              enVivo: elegido.enVivo,
              posicion: elegido.posicion,
            ),
          )
        else
          o,
    ];
    state = state.copyWith(
      fase: f.copyWith(opciones: opciones, busesEnVivo: buses),
    );
  }

  void _detenerOpciones() {
    _timerOpciones?.cancel();
    _timerOpciones = null;
    _opcionEnfocada = null;
    _seguidoresOpcion.clear();
    _seguidoresOpcionFut.clear();
  }

  @override
  void cerrarOpciones() {
    _secBusqueda++;
    _detenerOpciones();
    state = state.copyWith(fase: const FaseExplorar());
  }

  // =====================================================================
  // Viaje activo
  // =====================================================================

  @override
  void iniciarViaje(String idOpcion) {
    final f = state.fase;
    if (f is! FaseOpciones) return;
    OpcionViaje? opcion;
    for (final o in f.opciones) {
      if (o.id == idOpcion) opcion = o;
    }
    if (opcion == null) return;
    _detenerOpciones();
    _secViaje++;
    _avisosDados.clear();
    _nav = Navegador(opcion, reglas: config.reglas);
    final usuario = state.ubicacion.coordenada;
    var fase = FaseViaje(
      opcion: opcion,
      pasoActual: 0,
      origenAvance: OrigenAvance.inicio,
      progreso: ProgresoPaso.vacio,
      estado: EstadoViaje.enCurso,
      inicio: _ahora(),
      usuario: usuario,
      // El bus del primer tramo ya lo veníamos siguiendo en la vista previa.
      busEsperado: f.busesEnVivo[idOpcion],
    );
    if (usuario != null) {
      final r = _nav!.procesar(
        MuestraUbicacion(coordenada: usuario, momento: _ahora()),
      );
      fase = fase.copyWith(pasoActual: r.paso, progreso: r.progreso);
    }
    state = state.copyWith(fase: fase);
    _alCambiarPaso();
    alIniciarViaje?.call(opcion);
  }

  @override
  void confirmarPasoActual() {
    final f = state.fase;
    if (f is! FaseViaje || f.estado != EstadoViaje.enCurso || _nav == null)
      return;
    final r = _nav!.confirmarPaso();
    var nueva = f.copyWith(
      pasoActual: r.paso,
      progreso: r.progreso,
      origenAvance: OrigenAvance.manual,
    );
    if (r.completado) {
      nueva = nueva.copyWith(estado: EstadoViaje.completado, fin: _ahora());
    }
    state = state.copyWith(fase: nueva);
    _alCambiarPaso();
  }

  @override
  void terminarViaje() {
    if (state.fase is! FaseViaje) return;
    _detenerViaje();
    state = state.copyWith(fase: const FaseExplorar());
  }

  @override
  void cerrarLlegada() {
    final f = state.fase;
    if (f is! FaseViaje) return;
    _detenerViaje();
    state = state.copyWith(
      fase: const FaseExplorar(),
      busqueda: const Busqueda(),
    );
  }

  void _detenerViaje() {
    _secViaje++;
    _timerViaje?.cancel();
    _timerViaje = null;
    _seguidorViaje = null;
    _esperaSeguida = null;
    _nav = null;
    alTerminarViaje?.call();
  }

  /// Reconfigura el seguimiento del bus según el paso actual.
  void _alCambiarPaso() {
    final f = state.fase;
    if (f is! FaseViaje) return;
    if (f.estado == EstadoViaje.completado) {
      _timerViaje?.cancel();
      _timerViaje = null;
      _seguidorViaje = null;
      _esperaSeguida = null;
      if (f.busEsperado != null) {
        state = state.copyWith(fase: f.copyWith(limpiarBusEsperado: true));
      }
      (alLlegar ?? alTerminarViaje)?.call();
      return;
    }
    final espera = _esperaASeguir(f);
    if (espera == _esperaSeguida) return;
    _esperaSeguida = espera;
    _timerViaje?.cancel();
    _timerViaje = null;
    _seguidorViaje = null;
    final seq = ++_secViaje;
    // Arriba del bus (o sin más buses) no hay bus que esperar: el bus es el
    // usuario. Se limpia de inmediato para no mostrar datos de otra etapa.
    final mantener =
        espera != null &&
        f.busEsperado != null &&
        f.busEsperado!.linea == (f.opcion.tramos[espera] as TramoEsperar).linea;
    state = state.copyWith(
      fase: f.copyWith(limpiarBusEsperado: !mantener, sinDatosEnVivo: false),
    );
    if (espera == null) return;
    unawaited(() async {
      final bus = f.opcion.tramos[espera + 1] as TramoBus;
      final v = _planificados[f.opcion.id] ?? ViajePlanificado(f.opcion);
      final recorrido = await _recorrido(v, bus);
      if (!mounted || seq != _secViaje) return;
      _seguidorViaje = SeguidorBus(linea: bus.linea, recorrido: recorrido);
      await _sondearViaje(seq);
      if (!mounted || seq != _secViaje) return;
      _timerViaje = Timer.periodic(config.sondeoBus, (_) => _sondearViaje(seq));
    }());
  }

  /// Índice del próximo tramo de espera a seguir, o null si se está en el bus.
  int? _esperaASeguir(FaseViaje f) {
    for (var i = f.pasoActual; i < f.opcion.tramos.length; i++) {
      final t = f.opcion.tramos[i];
      if (t is TramoBus) return null;
      if (t is TramoEsperar) return i;
    }
    return null;
  }

  Future<void> _sondearViaje(int seq) async {
    final f0 = state.fase;
    final seg = _seguidorViaje;
    final espera = _esperaSeguida;
    if (f0 is! FaseViaje || seg == null || espera == null) return;
    final parada = (f0.opcion.tramos[espera] as TramoEsperar).parada;
    List<LlegadaEnParada>? lista;
    try {
      lista = await _llegadas.llegadas(parada.id);
    } catch (_) {
      lista = null;
    }
    if (!mounted || seq != _secViaje) return;
    final f = state.fase;
    if (f is! FaseViaje || f.estado != EstadoViaje.enCurso) return;
    if (lista == null) return; // error de red: se conserva lo último
    final bus = seg.elegir(lista);
    state = state.copyWith(
      fase: f.copyWith(
        busEsperado: bus,
        limpiarBusEsperado: bus == null,
        sinDatosEnVivo: bus == null || !bus.enVivo,
      ),
    );
    _avisosDeProgreso();
  }

  /// Hitos que merecen un aviso (una sola vez por paso).
  void _avisosDeProgreso() {
    final f = state.fase;
    if (f is! FaseViaje || f.estado != EstadoViaje.enCurso) return;
    final t = f.tramoActual;
    if (t is TramoBus &&
        f.progreso.paradasRestantes == 0 &&
        _avisosDados.add('bajate-${t.id}')) {
      _avisar(TipoAviso.bajateEnLaProxima);
    }
    final bus = f.busEsperado;
    if (t is TramoEsperar &&
        bus != null &&
        bus.enVivo &&
        bus.minutos <= 1 &&
        _avisosDados.add('llega-${t.id}')) {
      _avisar(TipoAviso.busLlegando);
    }
  }

  // =====================================================================
  // Paradas
  // =====================================================================

  @override
  void consultarParada(String idParada) {
    if (state.fase is! FaseExplorar) return;
    ParadaDeRed? red;
    for (final p in state.paradas) {
      if (p.parada.id == idParada) red = p;
    }
    if (red == null) return;
    final seq = ++_secParada;
    _timerParada?.cancel();
    state = state.copyWith(
      paradaConsultada: ConsultaParada(
        parada: red.parada,
        lineas: red.lineas,
        estado: EstadoConsulta.cargando,
      ),
    );
    final r = red;
    Future<void> sondear() async {
      try {
        final l = await _llegadas.llegadas(idParada);
        if (!mounted || seq != _secParada) return;
        final llegadas = [for (final x in l) x.datos]
          ..sort((a, b) => a.minutos.compareTo(b.minutos));
        state = state.copyWith(
          paradaConsultada: ConsultaParada(
            parada: r.parada,
            lineas: r.lineas,
            estado: EstadoConsulta.listo,
            llegadas: llegadas,
          ),
        );
      } catch (_) {
        if (!mounted || seq != _secParada) return;
        final previa = state.paradaConsultada;
        if (previa != null && previa.estado == EstadoConsulta.listo) return;
        state = state.copyWith(
          paradaConsultada: ConsultaParada(
            parada: r.parada,
            lineas: r.lineas,
            estado: EstadoConsulta.error,
          ),
        );
      }
    }

    unawaited(sondear());
    _timerParada = Timer.periodic(config.sondeoParada, (_) => sondear());
  }

  @override
  void cerrarParada() {
    _cerrarParadaInterno();
    state = state.copyWith(limpiarParadaConsultada: true);
  }

  void _cerrarParadaInterno() {
    _secParada++;
    _timerParada?.cancel();
    _timerParada = null;
  }

  // =====================================================================
  // Avisos
  // =====================================================================

  void _avisar(TipoAviso tipo) {
    if (!mounted) return;
    state = state.copyWith(aviso: Aviso(++_secAviso, tipo));
  }

  @override
  void descartarAviso(int idAviso) {
    if (state.aviso?.id == idAviso) {
      state = state.copyWith(limpiarAviso: true);
    }
  }

  @override
  void dispose() {
    _gps?.cancel();
    _debounce?.cancel();
    _timerOpciones?.cancel();
    _timerViaje?.cancel();
    _timerParada?.cancel();
    super.dispose();
  }
}
