// Mapa vectorial interactivo de BondiUY.
//
// Dibuja teselas vectoriales de OpenStreetMap con el estilo de la app (claro
// u oscuro), los recorridos del viaje y marcadores vectoriales. La cámara la
// decide la UI a partir de un [Encuadre]; el usuario puede moverla a mano.
//
// En viaje la cámara acompaña al usuario cuadro a cuadro, y los marcadores
// que se mueven (el usuario, el bus) se deslizan entre dos lecturas en vez de
// saltar.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../contract/modelo.dart';
import 'encuadre.dart';
import 'escena.dart';
import 'estilo_mapa.dart';
import 'movimiento.dart';
import 'pintor_escena.dart';
import 'proyeccion.dart';
import 'teselas/fuente_teselas.dart';
import 'teselas/gestor_teselas.dart';

const _zoomMin = 10.0;
const _zoomMax = 18.5;

/// Permite a la UI saber si el usuario movió el mapa y volver a encuadrar.
class ControladorMapa extends ChangeNotifier {
  bool _libre = false;
  VoidCallback? _recentrar;

  /// true si el usuario movió la cámara a mano (se pausa el seguimiento).
  bool get libre => _libre;

  void _marcarLibre(bool v) {
    if (_libre == v) return;
    _libre = v;
    notifyListeners();
  }

  void recentrar() => _recentrar?.call();
}

class MapaBondi extends StatefulWidget {
  final EscenaMapa escena;
  final Encuadre? encuadre;
  final EstiloMapa estilo;

  /// Zonas tapadas por paneles (px lógicos): el encuadre las evita.
  final EdgeInsets margenes;
  final ControladorMapa? controlador;
  final FuenteTeselas fuente;
  final bool decodificarEnIsolate;
  final void Function(String idParada)? onTocarParada;
  final VoidCallback? onTocarMapa;
  final Coordenada centroInicial;

  const MapaBondi({
    super.key,
    required this.escena,
    required this.fuente,
    this.estilo = EstiloMapa.claro,
    this.encuadre,
    this.margenes = EdgeInsets.zero,
    this.controlador,
    this.decodificarEnIsolate = true,
    this.onTocarParada,
    this.onTocarMapa,
    this.centroInicial = const Coordenada(-34.9011, -56.1645),
  });

  @override
  State<MapaBondi> createState() => _MapaBondiState();
}

class _MapaBondiState extends State<MapaBondi> with TickerProviderStateMixin {
  // Un gestor por estilo: cambiar de claro a oscuro y volver no re-dibuja.
  final Map<Brightness, GestorTeselas> _gestores = {};
  late PintorEscena _pintor;
  late Camara _camara = Camara.en(widget.centroInicial, 13);
  late final AnimationController _anim;
  late final AnimationController _latido;
  Camara? _desde, _hacia;
  Size _tam = Size.zero;
  String? _claveEncuadrada;

  Camara? _camaraInicioGesto;
  Offset? _focoInicio;
  Offset? _toqueDoble;

  /// Reloj de cuadros: desliza marcadores y acompaña al usuario. Solo corre
  /// mientras algo se mueve.
  late final Ticker _reloj;
  Duration _ultimoTic = Duration.zero;

  /// Marcadores que se mueven (el usuario, el bus): su posición se predice
  /// entre lecturas para que avancen de forma continua.
  final Map<String, MovimientoPredicho> _moviles = {};
  final Map<String, Coordenada> _ultimaLectura = {};
  Timer? _reanudar;

  /// Última marca mostrada de cada móvil y cuándo apareció: al cambiar de
  /// forma (tu punto -> vos en el bus) o al irse (el bus que llegó), la
  /// vieja se desvanece y la nueva aparece, en vez de saltar.
  final Map<String, MarcaMapa> _mostradas = {};
  final Map<String, double> _aparecio = {};
  final List<(MarcaMapa, double)> _salientes = [];
  static const _fundido = 0.45; // s

  /// La transición entre encuadres persigue al objetivo vivo (el usuario
  /// se sigue moviendo mientras la cámara viaja).
  bool _haciaVivo = false;

  /// La cámara ya alcanzó al objetivo y lo acompaña exacto. Se suelta si el
  /// objetivo pega un salto (cambió el encuadre, el alto de un panel).
  bool _enganchada = false;
  Camara? _objetivoAnterior;

  GestorTeselas _gestor(EstiloMapa e) =>
      _gestores[e.brillo] ??= GestorTeselas(
        widget.fuente,
        e,
        usarIsolate: widget.decodificarEnIsolate,
      )..addListener(_repintar);

  @override
  void initState() {
    super.initState();
    _pintor = PintorEscena(_gestor(widget.estilo), widget.estilo);
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..addListener(() {
      final d = _desde;
      final e = widget.encuadre;
      if (_haciaVivo && e != null) {
        // El destino se mueve con el usuario y puede saltar (cambia el alto
        // de un panel): se lo persigue suavizado, nunca copiado de golpe.
        final vivo = _objetivo(e);
        final h = _hacia;
        if (vivo != null && h != null) {
          _hacia = Camara.interpolar(h, vivo, 0.2);
        }
      }
      final h = _hacia;
      if (d == null || h == null) return;
      final t = Curves.easeInOutCubic.transform(_anim.value);
      setState(() => _camara = Camara.interpolar(d, h, t));
    });
    // Al terminar una transición, el seguimiento retoma desde ahí, ya
    // enganchado si perseguía al objetivo vivo (no hay nada que corregir).
    _anim.addStatusListener((st) {
      if (st == AnimationStatus.completed) {
        _enganchada = _haciaVivo;
        _objetivoAnterior = _enganchada ? _camara : null;
        _haciaVivo = false;
        _asegurarReloj();
      }
    });
    _latido = AnimationController(
      vsync: this,
      // Un ciclo: dos pulsos, una flotación de los globos.
      duration: const Duration(milliseconds: 3200),
    );
    _reloj = createTicker(_alTic);
    widget.controlador?._recentrar = _recentrar;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _actualizarLatido();
  }

  @override
  void didUpdateWidget(MapaBondi old) {
    super.didUpdateWidget(old);
    if (old.controlador != widget.controlador) {
      widget.controlador?._recentrar = _recentrar;
    }
    if (old.fuente != widget.fuente) {
      for (final g in _gestores.values) {
        g
          ..removeListener(_repintar)
          ..dispose();
      }
      _gestores.clear();
    }
    if (old.estilo != widget.estilo || old.fuente != widget.fuente) {
      _pintor = PintorEscena(_gestor(widget.estilo), widget.estilo);
    }
    _actualizarLatido();
    _sincronizarMoviles();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _aplicarEncuadre();
    });
  }

  void _repintar() {
    if (mounted) setState(() {});
  }

  bool get _sinAnimaciones =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Pulsos y guiones solo corren si hay algo vivo en la escena.
  void _actualizarLatido() {
    final necesita = !_sinAnimaciones && widget.escena.tieneLatido;
    if (necesita && !_latido.isAnimating) {
      _latido.repeat();
    } else if (!necesita && _latido.isAnimating) {
      _latido.stop();
    }
  }

  Offset get _mitad => Offset(
    (_tam.width / 2).floorToDouble(),
    (_tam.height / 2).floorToDouble(),
  );

  // --- marcadores que se mueven ----------------------------------------------

  static String? _claveMovil(MarcaMapa m) => switch (m) {
    MarcaUsuario() || MarcaUsuarioEnBus() => 'usuario',
    MarcaBus() => 'bus',
    _ => null,
  };

  void _sincronizarMoviles() {
    final vistas = <String>{};
    final ahora = _ahora;
    final fundir = !_sinAnimaciones && !_tam.isEmpty;
    for (final m in widget.escena.marcas) {
      final k = _claveMovil(m);
      if (k == null) continue;
      vistas.add(k);
      final antes = _mostradas[k];
      if (fundir && (antes == null || antes.runtimeType != m.runtimeType)) {
        if (antes != null) _salientes.add((antes, ahora));
        _aparecio[k] = ahora;
      }
      final p = mercator(m.coordenada);
      final camino = m.camino;
      final mov = _moviles[k];
      if (mov == null) {
        _moviles[k] = MovimientoPredicho(p, ahora);
        _ultimaLectura[k] = m.coordenada;
        continue;
      }
      if (_ultimaLectura[k] == m.coordenada) continue;
      _ultimaLectura[k] = m.coordenada;
      mov.lectura(
        p,
        ahora,
        camino: camino == null ? null : _caminoMercator(camino),
        fuenteCamino: camino,
        limite: m is MarcaBus && m.limite != null ? mercator(m.limite!) : null,
        // Saltos grandes (otro bus, el GPS que se reubica) no se predicen.
        reubicado: (p - mov.posicion).distance * metrosPorUnidad > 400,
      );
    }
    for (final k in _mostradas.keys.toList()) {
      if (vistas.contains(k)) continue;
      // Se fue (el bus que llegó a la parada): se desvanece donde estaba.
      if (fundir) _salientes.add((_mostradas[k]!, ahora));
      _mostradas.remove(k);
    }
    _moviles.removeWhere((k, _) => !vistas.contains(k));
    _ultimaLectura.removeWhere((k, _) => !vistas.contains(k));
    _aparecio.removeWhere((k, _) => !vistas.contains(k));
    _asegurarReloj();
  }

  final _caminos = Expando<List<Offset>>();
  List<Offset> _caminoMercator(List<Coordenada> c) =>
      _caminos[c] ??= [for (final p in c) mercator(p)];

  /// Tiempo del cuadro actual en segundos (respeta el tiempo falso de los
  /// tests).
  double get _ahora {
    final b = SchedulerBinding.instance;
    if (b.schedulerPhase != SchedulerPhase.idle) {
      _ultimoAhora = b.currentFrameTimeStamp.inMicroseconds / 1e6;
    }
    return _ultimoAhora;
  }

  double _ultimoAhora = 0;

  /// La escena con los marcadores móviles en su posición predicha y con su
  /// rumbo; los recorridos que nacen en ellos (lo que falta caminar o
  /// viajar, la aproximación del bus) arrancan donde se los ve.
  EscenaMapa get _escenaMostrada {
    if (_moviles.isEmpty && _salientes.isEmpty) return widget.escena;
    final ahora = _ahora;
    final lecturas = <String, (Coordenada, Coordenada)>{};
    final marcas = <MarcaMapa>[];
    final opacidad = Map<MarcaMapa, double>.identity();
    _salientes.removeWhere((s) => ahora - s.$2 >= _fundido);
    for (final (m, t0) in _salientes) {
      marcas.add(m);
      opacidad[m] = 1 - Curves.easeIn.transform((ahora - t0) / _fundido);
    }
    for (final m in widget.escena.marcas) {
      final k = _claveMovil(m);
      final mov = _moviles[k ?? ''];
      if (k == null || mov == null) {
        marcas.add(m);
        continue;
      }
      final c = desdeMercator(mov.posicion);
      lecturas[k] = (m.coordenada, c);
      final mostrada = m.movidaA(c, rumbo: mov.rumbo);
      _mostradas[k] = mostrada;
      marcas.add(mostrada);
      final t0 = _aparecio[k];
      if (t0 != null && ahora - t0 < _fundido) {
        opacidad[mostrada] = Curves.easeOut.transform(
          ((ahora - t0) / _fundido).clamp(0.0, 1.0),
        );
      }
    }
    final trazos = [
      for (final t in widget.escena.trazos)
        switch (t.estilo) {
          EstiloTrazo.caminar || EstiloTrazo.bus
              when lecturas['usuario'] != null =>
            _nacerEn(t, lecturas['usuario']!),
          EstiloTrazo.aproximacion when lecturas['bus'] != null => _nacerEn(
            t,
            lecturas['bus']!,
          ),
          _ => t,
        },
    ];
    return widget.escena.con(
      marcas: marcas,
      trazos: trazos,
      opacidad: opacidad,
    );
  }

  /// Si [t] nace en la lectura de un marcador móvil, lo hace nacer donde se
  /// muestra el marcador (recortando lo que ya quedó atrás).
  TrazoMapa _nacerEn(TrazoMapa t, (Coordenada, Coordenada) lectura) {
    final (fijo, mostrado) = lectura;
    final pts = t.puntos;
    if (pts.length < 2) return t;
    final inicio = mercator(pts.first);
    if ((inicio - mercator(fijo)).distance * metrosPorUnidad > 30) return t;
    final p = mercator(mostrado);
    // Segmento más cercano a lo mostrado, entre los primeros del recorrido.
    var mejor = 1;
    var mejorD = double.infinity;
    for (var i = 1; i < pts.length && i < 400; i++) {
      final a = mercator(pts[i - 1]), b = mercator(pts[i]);
      final ab = b - a;
      final l2 = ab.dx * ab.dx + ab.dy * ab.dy;
      final u =
          l2 == 0
              ? 0.0
              : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / l2).clamp(
                0.0,
                1.0,
              );
      final d = (p - (a + ab * u)).distance;
      if (d < mejorD) {
        mejorD = d;
        mejor = i;
      }
    }
    return TrazoMapa(t.estilo, [mostrado, ...pts.skip(mejor)]);
  }

  // --- reloj: deslizamientos y seguimiento -----------------------------------

  bool get _siguiendo {
    final e = widget.encuadre;
    return e != null &&
        e.seguimiento == Seguimiento.continuo &&
        _claveEncuadrada == e.clave &&
        !(widget.controlador?.libre ?? false) &&
        !_anim.isAnimating &&
        _camaraInicioGesto == null;
  }

  void _asegurarReloj() {
    if (!mounted) return;
    final ahora = _ahora;
    final hace =
        _moviles.values.any((m) => m.enMovimientoA(ahora)) ||
        _salientes.isNotEmpty ||
        _aparecio.values.any((t) => ahora - t < _fundido) ||
        _siguiendo;
    if (hace && !_reloj.isActive) {
      _ultimoTic = Duration.zero;
      _reloj.start();
    }
  }

  void _alTic(Duration transcurrido) {
    final dt = ((transcurrido - _ultimoTic).inMicroseconds / 1e6).clamp(
      0.0,
      0.1,
    );
    _ultimoTic = transcurrido;
    final ahora = _ahora;
    var sigue = false;
    for (final m in _moviles.values) {
      m.avanzar(ahora);
      if (m.enMovimientoA(ahora)) sigue = true;
    }
    if (_salientes.isNotEmpty ||
        _aparecio.values.any((t) => ahora - t < _fundido)) {
      sigue = true;
    }
    var camara = _camara;
    if (_siguiendo) {
      final objetivo = _objetivo(widget.encuadre!);
      if (objetivo != null) {
        // ¿El objetivo se movió de a poco (el usuario avanza) o pegó un
        // salto (cambió el grupo, el alto de un panel)? Si saltó, se suelta
        // y se lo alcanza con suavidad.
        final previo = _objetivoAnterior;
        _objetivoAnterior = objetivo;
        if (previo != null) {
          final salto =
              ((objetivo.centro - previo.centro) * camara.escalaMundo)
                  .distance +
              (objetivo.zoom - previo.zoom).abs() * 300;
          if (salto > 6) _enganchada = false;
        }
        final dz = objetivo.zoom - camara.zoom;
        final dc = (objetivo.centro - camara.centro) * camara.escalaMundo;
        final k = 1 - math.exp(-dt / 0.35);
        if (_enganchada) {
          // Pegada al usuario (sin retraso: el punto no "nada" en la
          // pantalla); el zoom se acomoda suave.
          camara = Camara(objetivo.centro, camara.zoom + dz * k);
          if (dz.abs() > 0.002) sigue = true;
        } else if (dz.abs() < 0.004 && dc.distance < 0.5) {
          camara = objetivo;
          _enganchada = true;
        } else {
          // Alcanzándolo: con inercia (constante de tiempo ~0,35 s).
          camara = Camara(
            Offset.lerp(camara.centro, objetivo.centro, k)!,
            camara.zoom + dz * k,
          );
          sigue = true;
        }
      }
    }
    if (!sigue) _reloj.stop();
    setState(() => _camara = camara);
  }

  /// Cámara ideal para el encuadre en este instante, con los marcadores
  /// móviles en su posición predicha.
  Camara? _objetivo(Encuadre e) {
    if (_tam.isEmpty) return null;
    final esenciales = [
      for (final p in e.puntos) mercator(p),
      for (final k in e.moviles)
        if (_moviles[k] case final m?) m.posicion,
    ];
    final extras = [
      for (final k in e.extras)
        if (_moviles[k] case final m?) m.posicion,
    ];
    if (esenciales.isEmpty) return null;
    final v = _zonaUtil;
    Camara encuadre(List<Offset> pts) => encuadrarMercator(
      pts,
      ancho: _tam.width,
      alto: _tam.height,
      arriba: v.top,
      abajo: _tam.height - v.bottom,
      izquierda: v.left,
      derecha: _tam.width - v.right,
      zoomMax: e.zoomMax,
      zoomMin: _zoomMin,
    );
    if (extras.isNotEmpty) {
      final todo = encuadre([...esenciales, ...extras]);
      if (todo.zoom >= math.max(e.zoomMin, e.zoomExtras) - 0.5) return todo;
    }
    var cam = encuadre(esenciales);
    final ancla = _moviles[e.ancla ?? '']?.posicion;
    if (ancla == null || cam.zoom >= e.zoomMin) return cam;
    // Ni lo esencial entra con un zoom legible: se acerca hasta el mínimo y
    // se corre hacia el grupo sin que el ancla (el usuario) salga de la vista.
    cam = Camara(cam.centro, e.zoomMin);
    final seguro = v.deflate(math.min(v.width, v.height) * 0.14);
    final a = cam.aLienzo(ancla, _mitad);
    final dentro = Offset(
      a.dx.clamp(seguro.left, math.max(seguro.left, seguro.right)),
      a.dy.clamp(seguro.top, math.max(seguro.top, seguro.bottom)),
    );
    return cam.con(centro: cam.centro + (a - dentro) / cam.escalaMundo);
  }

  /// Zona del lienzo donde se quiere ver lo importante: sin paneles y con
  /// lugar para lo que sobresale de los marcadores (badge del bus, pin).
  Rect get _zonaUtil {
    final m = widget.margenes;
    return Rect.fromLTRB(
      m.left + 56,
      m.top + 64,
      _tam.width - m.right - 56,
      _tam.height - m.bottom - 28,
    );
  }

  void _aplicarEncuadre({bool forzar = false}) {
    final e = widget.encuadre;
    if (e == null || _tam.isEmpty) return;
    final nuevaClave = e.clave != _claveEncuadrada;
    if (nuevaClave) {
      _reanudar?.cancel();
      widget.controlador?._marcarLibre(false);
    }
    final libre = widget.controlador?.libre ?? false;
    if (!forzar && !nuevaClave) {
      if (libre) return;
      switch (e.seguimiento) {
        case Seguimiento.ninguno:
          return;
        case Seguimiento.continuo:
          // El reloj la acompaña cuadro a cuadro (también con "quitar
          // animaciones": es la posición real moviéndose, no un adorno).
          _asegurarReloj();
          return;
        case Seguimiento.siSeSale:
          final destino = _objetivo(e);
          if (destino == null) return;
          // Mover solo si algo se sale o sobra mucho zoom.
          final hueco = (destino.zoom - _camara.zoom).abs();
          if (hueco < 0.6 && _todosVisibles(e.puntos)) return;
          _animarA(destino, rapida: true);
          return;
      }
    }
    final destino = _objetivo(e);
    if (destino == null) return;
    _claveEncuadrada = e.clave;
    _animarA(destino, vivo: e.seguimiento == Seguimiento.continuo);
  }

  bool _todosVisibles(List<Coordenada> pts) {
    final m = widget.margenes;
    final seguro = Rect.fromLTRB(
      m.left + 40,
      m.top + 56,
      _tam.width - m.right - 40,
      _tam.height - m.bottom - 20,
    );
    return pts.every(
      (p) => seguro.contains(_camara.aLienzo(mercator(p), _mitad)),
    );
  }

  void _animarA(Camara destino, {bool rapida = false, bool vivo = false}) {
    _enganchada = false;
    _objetivoAnterior = null;
    _haciaVivo = vivo;
    final distanciaZoom = (destino.zoom - _camara.zoom).abs();
    if (_anim.isAnimating) _anim.stop();
    _desde = _camara;
    _hacia = destino;
    if (_sinAnimaciones) {
      setState(() => _camara = destino);
      return;
    }
    _anim.duration = Duration(
      milliseconds:
          rapida ? 500 : (550 + 90 * distanciaZoom).clamp(550, 1100).round(),
    );
    _anim.forward(from: 0);
  }

  void _recentrar() {
    _reanudar?.cancel();
    widget.controlador?._marcarLibre(false);
    _claveEncuadrada = null;
    _aplicarEncuadre(forzar: true);
  }

  /// En viaje, si el usuario movió el mapa y lo soltó, la cámara vuelve sola
  /// al rato.
  void _programarReanudar() {
    _reanudar?.cancel();
    final espera = widget.encuadre?.reanudarTras;
    if (espera != null && (widget.controlador?.libre ?? false)) {
      _reanudar = Timer(espera, () {
        if (mounted && (widget.controlador?.libre ?? false)) _recentrar();
      });
    }
    _asegurarReloj();
  }

  // --- gestos ------------------------------------------------------------------

  void _alEmpezar(ScaleStartDetails d) {
    _reanudar?.cancel();
    _enganchada = false;
    _haciaVivo = false;
    _anim.stop();
    _hacia = null;
    _camaraInicioGesto = _camara;
    _focoInicio = d.localFocalPoint;
  }

  void _alActualizar(ScaleUpdateDetails d) {
    final inicio = _camaraInicioGesto;
    final focoIni = _focoInicio;
    if (inicio == null || focoIni == null) return;
    final foco = d.localFocalPoint;
    final zoom = (inicio.zoom + math.log(d.scale) / math.ln2).clamp(
      _zoomMin,
      _zoomMax,
    );
    final bajoFoco = inicio.desdeLienzo(focoIni, _mitad);
    final escala = tamTesela * math.pow(2, zoom);
    final centro = bajoFoco - (foco - _mitad) / escala.toDouble();
    if ((foco - focoIni).distance > 6 || (d.scale - 1).abs() > 0.03) {
      widget.controlador?._marcarLibre(true);
    }
    setState(() => _camara = Camara(centro, zoom));
  }

  void _alTerminar(ScaleEndDetails d) {
    _camaraInicioGesto = null;
    _programarReanudar();
    final v = d.velocity.pixelsPerSecond;
    if (v.distance < 250 || !(widget.controlador?.libre ?? true)) return;
    // Inercia breve, desacelerando.
    final escala = _camara.escalaMundo;
    _desde = _camara;
    _hacia = _camara.con(centro: _camara.centro - (v * 0.22) / escala);
    _anim.duration = const Duration(milliseconds: 420);
    _anim.forward(from: 0);
  }

  void _alTocar(TapUpDetails d) {
    final p = d.localPosition;
    String? mejor;
    var mejorD = 18.0;
    for (final (id, pos) in _pintor.paradasVisibles) {
      final dist = (pos - p).distance;
      if (dist < mejorD) {
        mejorD = dist;
        mejor = id;
      }
    }
    if (mejor != null) {
      widget.onTocarParada?.call(mejor);
    } else {
      widget.onTocarMapa?.call();
    }
  }

  void _alDobleToque() {
    final foco = _toqueDoble;
    if (foco == null) return;
    final bajo = _camara.desdeLienzo(foco, _mitad);
    final z = (_camara.zoom + 1).clamp(_zoomMin, _zoomMax);
    final escala = tamTesela * math.pow(2, z);
    widget.controlador?._marcarLibre(true);
    _animarA(
      Camara(bajo - (foco - _mitad) / escala.toDouble(), z),
      rapida: true,
    );
    _programarReanudar();
  }

  @override
  void dispose() {
    _reanudar?.cancel();
    _reloj.dispose();
    _anim.dispose();
    _latido.dispose();
    for (final g in _gestores.values) {
      g
        ..removeListener(_repintar)
        ..dispose();
    }
    if (widget.controlador?._recentrar == _recentrar) {
      widget.controlador?._recentrar = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _pintor.familia = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return LayoutBuilder(
      builder: (context, box) {
        final tam = box.biggest;
        if (tam != _tam) {
          final primera = _tam.isEmpty;
          _tam = tam;
          if (primera) {
            _sincronizarMoviles();
            final e = widget.encuadre;
            final c = e == null ? null : _objetivo(e);
            if (c != null) {
              _camara = c;
              _claveEncuadrada = e!.clave;
            }
          }
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: _alEmpezar,
          onScaleUpdate: _alActualizar,
          onScaleEnd: _alTerminar,
          onTapUp: _alTocar,
          onDoubleTapDown: (d) => _toqueDoble = d.localPosition,
          onDoubleTap: _alDobleToque,
          child: CustomPaint(
            size: tam,
            isComplex: true,
            painter: _PintorMapa(
              pintor: _pintor,
              camara: _camara,
              escena: _escenaMostrada,
              latido: _latido,
              margenes: widget.margenes,
              libre: widget.controlador?.libre ?? false,
            ),
          ),
        );
      },
    );
  }
}

class _PintorMapa extends CustomPainter {
  final PintorEscena pintor;
  final Camara camara;
  final EscenaMapa escena;
  final Animation<double> latido;
  final EdgeInsets margenes;
  final bool libre;

  _PintorMapa({
    required this.pintor,
    required this.camara,
    required this.escena,
    required this.latido,
    required this.margenes,
    required this.libre,
  }) : super(repaint: latido);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.clipRect(Offset.zero & size);
    pintor.pintar(
      canvas,
      size,
      camara,
      escena,
      fase: latido.value,
      margenes: margenes,
      libre: libre,
    );
  }

  @override
  bool shouldRepaint(_PintorMapa old) => true;
}
