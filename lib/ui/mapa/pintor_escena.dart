// Compone un cuadro del mapa en píxeles lógicos: teselas, recorridos,
// rótulos de calles, paradas, marcadores vectoriales y globos flotantes.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../contract/modelo.dart';
import '../formatos.dart';
import 'escena.dart';
import 'estilo_mapa.dart';
import 'proyeccion.dart';
import 'teselas/gestor_teselas.dart';
import 'teselas/pintor_teselas.dart';
import '../textos/textos.dart';

class PintorEscena {
  final GestorTeselas teselas;
  final EstiloMapa estilo;
  PintorEscena(this.teselas, this.estilo);

  /// Familia tipográfica de la app (un CustomPainter no hereda el tema).
  String? familia;

  List<ParadaDeRed>? _redCache;
  List<Offset> _redMercator = const [];
  final _textos = <String, TextPainter>{};

  /// Rótulos colocados en el último cuadro (diagnóstico y tests).
  final List<String> rotulosPuestos = [];
  int rotulosCandidatos = 0;

  /// Globos dibujados en el último cuadro (diagnóstico y tests).
  final List<String> globosPuestos = [];

  /// Dónde quedó el usuario en el último cuadro (diagnóstico y tests).
  Offset? usuarioEnPantalla;

  /// Dónde quedó el bus que viene en el último cuadro (diagnóstico y tests).
  Offset? busEnPantalla;

  /// El usuario se dibujó arriba del bus (diagnóstico y tests).
  bool usuarioEnBus = false;

  /// Rumbo con el que se dibujó al usuario caminando (diagnóstico y tests).
  double? rumboUsuario;

  /// Texto del indicador de borde, si se dibujó (diagnóstico y tests).
  String? objetivoEnBorde;

  /// Texto del indicador de borde del bus que viene (diagnóstico y tests).
  String? busEnBorde;

  /// El último pintor que dibujó un cuadro (diagnóstico y tests).
  @visibleForTesting
  static PintorEscena? ultimo;

  /// Cámara del último cuadro (diagnóstico y tests).
  Camara? camara;

  /// Paradas de la red visibles en el último cuadro (para tocar).
  final List<(String, Offset)> paradasVisibles = [];

  /// [fase] avanza continuamente de 0 a 1 (un ciclo de ~3 s): pulsos, guiones
  /// que avanzan y globos que flotan.
  void pintar(
    Canvas c,
    Size tam,
    Camara cam,
    EscenaMapa escena, {
    double fase = 0,
    EdgeInsets margenes = EdgeInsets.zero,
    bool libre = false,
  }) {
    final mitad = Offset(
      (tam.width / 2).floorToDouble(),
      (tam.height / 2).floorToDouble(),
    );
    Offset aPantalla(Coordenada co) => cam.aLienzo(mercator(co), mitad);
    ultimo = this;
    camara = cam;

    _teselas(c, tam, cam, mitad);

    // Marcas visibles, en orden de dibujo.
    final orden = <(MarcaMapa, Offset)>[
      for (final m in escena.marcas) (m, aPantalla(m.coordenada)),
    ]..removeWhere(
      (e) =>
          e.$2.dx < -80 ||
          e.$2.dy < -80 ||
          e.$2.dx > tam.width + 80 ||
          e.$2.dy > tam.height + 80,
    );
    orden.sort((a, b) => _prioridad(a.$1) - _prioridad(b.$1));

    // Paradas intermedias: a zoom lejano se ralean para no empastar la línea.
    final recorrido = <(MarcaParadaRecorrido, Offset)>[];
    for (final (m, p) in orden) {
      if (m is! MarcaParadaRecorrido) continue;
      if (m.estado != EstadoParadaRecorrido.proxima &&
          (cam.zoom < 13.5 || recorrido.any((e) => (e.$2 - p).distance < 11))) {
        continue;
      }
      recorrido.add((m, p));
    }

    final zona = Rect.fromLTRB(
      8,
      margenes.top + 6,
      tam.width - 8,
      tam.height - margenes.bottom - 6,
    );
    final cajasMarcas = <Rect>[
      for (final (m, p) in orden)
        if (m is! MarcaParadaRecorrido && m is! MarcaTramo) _cajaMarca(m, p),
    ];
    final globos = _ubicarGlobos(
      [
        for (final e in orden)
          if (escena.opacidad(e.$1) >= 1) e,
      ],
      zona,
      cajasMarcas,
      fase,
    );

    final reservados = <Rect>[
      Rect.fromLTWH(0, 0, tam.width, margenes.top),
      Rect.fromLTWH(
        0,
        tam.height - margenes.bottom,
        tam.width,
        margenes.bottom,
      ),
      ...cajasMarcas,
      for (final g in globos) g.caja,
    ];
    _rotulos(c, tam, cam, mitad, reservados);

    _paradasRed(c, tam, cam, mitad, escena);

    for (final t in escena.trazos) {
      _trazo(c, [for (final p in t.puntos) aPantalla(p)], t.estilo, fase);
    }

    for (final (m, p) in recorrido) {
      _paradaRecorrido(c, m, p, fase);
    }
    usuarioEnPantalla = null;
    rumboUsuario = null;
    busEnPantalla = null;
    usuarioEnBus = false;
    for (final (m, p) in orden) {
      if (m is MarcaParadaRecorrido) continue;
      if (m is MarcaUsuario || m is MarcaUsuarioEnBus) usuarioEnPantalla = p;
      if (m is MarcaUsuario && m.caminando) rumboUsuario = m.rumbo;
      if (m is MarcaBus) busEnPantalla = p;
      if (m is MarcaUsuarioEnBus) usuarioEnBus = true;
      final a = escena.opacidad(m);
      if (a < 1) {
        if (a <= 0.01) continue;
        c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, a));
        _marca(c, m, p, fase);
        c.restore();
      } else {
        _marca(c, m, p, fase);
      }
    }

    globosPuestos.clear();
    for (final g in globos) {
      _globo(c, g, fase);
      globosPuestos.add(g.globo?.titulo ?? g.tramo!.texto);
    }

    // Lo que importa y quedó fuera de la vista se señala en el borde: el bus
    // que viene (hacia dónde está y cuánto le falta) y tu objetivo.
    objetivoEnBorde = null;
    busEnBorde = null;
    final enBorde = <Rect>[];
    for (final (m, p) in [
      for (final m in escena.marcas) (m, aPantalla(m.coordenada)),
    ]) {
      if (m is! MarcaBus || escena.opacidad(m) < 1) continue;
      final texto =
          '${m.linea} · ${m.minutos <= 0 ? tx.llegandoMinus : minutos(m.minutos)}';
      if (_enBorde(
        c,
        p,
        zona,
        enBorde,
        texto: texto,
        colorTexto: m.enVivo ? estilo.enVivo : estilo.programado,
        fondoIcono: estilo.bus,
        icono: Icons.directions_bus_rounded,
      )) {
        busEnBorde = texto;
      }
    }
    final obj = escena.objetivo;
    if (obj != null &&
        (obj.siempre || libre) &&
        _enBorde(
          c,
          aPantalla(obj.coordenada),
          zona,
          enBorde,
          texto: obj.texto,
          colorTexto: estilo.tinta,
          fondoIcono: estilo.caminar,
          icono: Icons.navigation_rounded,
          rotarIcono: true,
        )) {
      objetivoEnBorde = obj.texto;
    }

    _atribucion(c, tam, margenes.bottom);
  }

  int _prioridad(MarcaMapa m) => switch (m) {
    MarcaParadaRecorrido() => -1,
    MarcaTramo() => 0,
    MarcaOrigen() => 0,
    MarcaParada() => 1,
    MarcaParadaConsultada() => 2,
    MarcaDestino() => 3,
    MarcaBus() => 4,
    MarcaUsuario() => 5,
    MarcaUsuarioEnBus() => 6,
  };

  /// Lo que ocupa cada marcador en pantalla (para que los rótulos lo eviten).
  Rect _cajaMarca(MarcaMapa m, Offset p) => switch (m) {
    MarcaDestino() => Rect.fromLTRB(p.dx - 16, p.dy - 42, p.dx + 16, p.dy + 4),
    MarcaUsuarioEnBus() => Rect.fromLTRB(
      p.dx - 44,
      p.dy - 42,
      p.dx + 44,
      p.dy + 8,
    ),
    _ => Rect.fromCenter(center: p, width: 34, height: 34),
  };

  // --- paradas de la red -----------------------------------------------------

  void _paradasRed(
    Canvas c,
    Size tam,
    Camara cam,
    Offset mitad,
    EscenaMapa escena,
  ) {
    paradasVisibles.clear();
    final tenues = escena.paradasRedTenues;
    if (escena.paradasRed.isEmpty || cam.zoom < (tenues ? 16 : 15)) return;
    if (!identical(_redCache, escena.paradasRed)) {
      _redCache = escena.paradasRed;
      _redMercator = [
        for (final p in escena.paradasRed) mercator(p.parada.coordenada),
      ];
    }
    final r = tenues ? 3.0 : (cam.zoom >= 16.5 ? 5.0 : 3.5);
    final fondo =
        Paint()
          ..color = estilo.marcadorFondo.withValues(alpha: tenues ? 0.8 : 1);
    final aro =
        Paint()
          ..color = estilo.paradaRed.withValues(alpha: tenues ? 0.4 : 1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r > 4 ? 2 : 1.5;
    for (var i = 0; i < _redMercator.length; i++) {
      final a = cam.aLienzo(_redMercator[i], mitad);
      if (a.dx < -10 ||
          a.dy < -10 ||
          a.dx > tam.width + 10 ||
          a.dy > tam.height + 10) {
        continue;
      }
      if (!tenues) paradasVisibles.add((escena.paradasRed[i].parada.id, a));
      c.drawCircle(a, r, fondo);
      c.drawCircle(a, r, aro);
      // De cerca, la parada lleva su ícono: se reconoce sin leyenda.
      if (!tenues && cam.zoom >= 17.2) {
        c.drawCircle(a, 9, fondo);
        c.drawCircle(
          a,
          9,
          Paint()
            ..color = estilo.paradaRed
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        _icono(c, Icons.directions_bus_rounded, a, 11, estilo.paradaRed);
      }
    }
  }

  // --- teselas ---------------------------------------------------------------

  void _teselas(Canvas c, Size tam, Camara cam, Offset mitad) {
    c.drawRect(Offset.zero & tam, Paint()..color = estilo.tierra);
    final zi = cam.zoom.floor().clamp(2, 19);
    final lado = tamTesela * math.pow(2, cam.zoom - zi).toDouble();
    final n = 1 << zi;
    final origen = cam.desdeLienzo(Offset.zero, mitad) * n.toDouble();
    final fin =
        cam.desdeLienzo(Offset(tam.width, tam.height), mitad) * n.toDouble();
    final res = teselas.resolucion.toDouble();
    final pintura = Paint()..filterQuality = FilterQuality.medium;
    double borde(int t, double o) => (t - o) * lado;
    for (var ty = origen.dy.floor(); ty <= fin.dy.floor(); ty++) {
      for (var tx = origen.dx.floor(); tx <= fin.dx.floor(); tx++) {
        // Medio píxel de solapamiento: sin costuras con el suavizado.
        final dst = Rect.fromLTRB(
          borde(tx, origen.dx) - 0.5,
          borde(ty, origen.dy) - 0.5,
          borde(tx + 1, origen.dx) + 0.5,
          borde(ty + 1, origen.dy) + 0.5,
        );
        final img = teselas.imagen(zi, tx, ty);
        if (img != null) {
          c.drawImageRect(img, Rect.fromLTWH(0, 0, res, res), dst, pintura);
          continue;
        }
        final padre = teselas.imagen(zi - 1, tx >> 1, ty >> 1);
        if (padre != null) {
          final src = Rect.fromLTWH(
            (tx & 1) * res / 2,
            (ty & 1) * res / 2,
            res / 2,
            res / 2,
          );
          c.drawImageRect(padre, src, dst, pintura);
        }
      }
    }
  }

  // --- rótulos ---------------------------------------------------------------

  static const _zoomMinimo = {
    'motorway': 12.0,
    'trunk': 12.0,
    'primary': 13.0,
    'secondary': 14.0,
    'tertiary': 15.0,
    'minor': 15.5,
    'service': 17.0,
    'barrio': 11.0,
  };

  TextPainter _texto(
    String texto, {
    required bool barrio,
    required double tamano,
  }) {
    final clave = '${barrio ? 'b' : 'c'}$tamano|$texto';
    return _textos[clave] ??= () {
      if (_textos.length > 400) _textos.clear();
      return TextPainter(
        text: TextSpan(
          text: barrio ? texto.toUpperCase() : texto,
          style: TextStyle(
            fontFamily: familia,
            fontSize: tamano,
            fontWeight: barrio ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: barrio ? 1.4 : 0.1,
            color: barrio ? estilo.barrio : estilo.rotulo,
            shadows: [
              for (final d in const [
                Offset(1, 0),
                Offset(-1, 0),
                Offset(0, 1),
                Offset(0, -1),
              ])
                Shadow(color: estilo.rotuloHalo, offset: d, blurRadius: 1.5),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
    }();
  }

  void _rotulos(
    Canvas c,
    Size tam,
    Camara cam,
    Offset mitad,
    List<Rect> reservados,
  ) {
    final zi = cam.zoom.floor();
    final n = 1 << zi;
    final origen = cam.desdeLienzo(Offset.zero, mitad) * n.toDouble();
    final fin =
        cam.desdeLienzo(Offset(tam.width, tam.height), mitad) * n.toDouble();
    final ocupados = <Rect>[...reservados];
    final puestos = <String, Offset>{};
    final vistos = <RotuloMapa>{};
    final candidatos = <RotuloMapa>[];
    for (var ty = origen.dy.floor(); ty <= fin.dy.floor(); ty++) {
      for (var tx = origen.dx.floor(); tx <= fin.dx.floor(); tx++) {
        for (final r in teselas.rotulos(zi, tx, ty)) {
          if (vistos.add(r)) candidatos.add(r);
        }
      }
    }
    candidatos.sort(
      (a, b) =>
          (_zoomMinimo[a.clase] ?? 18).compareTo(_zoomMinimo[b.clase] ?? 18),
    );
    rotulosPuestos.clear();
    rotulosCandidatos = candidatos.length;
    // Zona donde un rótulo se puede leer (sin paneles encima).
    final visible = Rect.fromLTRB(
      40,
      (reservados.isNotEmpty ? reservados[0].bottom : 0) + 24,
      tam.width - 40,
      tam.height - (reservados.length > 1 ? reservados[1].height : 0) - 24,
    );
    var cuenta = 0;
    for (final r in candidatos) {
      if (cuenta > 30) break;
      final esBarrio = r.clase == 'barrio';
      if (esBarrio && cam.zoom > 14.5) continue;
      if (!esBarrio && cam.zoom < (_zoomMinimo[r.clase] ?? 18)) continue;
      final tp = _texto(
        r.texto,
        barrio: esBarrio,
        tamano:
            esBarrio
                ? 11
                : (r.clase == 'primary' || r.clase == 'trunk' ? 12.5 : 11.5),
      );
      final w = tp.width, h = tp.height;
      final pts = [for (final p in r.puntos) cam.aLienzo(p, mitad)];
      Offset? centro;
      var angulo = 0.0;
      if (esBarrio) {
        centro = pts.first;
      } else {
        // Tramo casi recto más largo, aunque esté hecho de varios segmentos
        // cortos (las calles vienen partidas en cada vértice).
        var mejor = 0.0;
        var inicio = 0;
        for (var i = 1; i < pts.length; i++) {
          final dir = pts[i] - pts[inicio];
          final seg = pts[i] - pts[i - 1];
          if (seg.distance > 0 && dir.distance > 0) {
            final desvio =
                (math.atan2(seg.dy, seg.dx) - math.atan2(dir.dy, dir.dx)).abs();
            final d = math.min(desvio, 2 * math.pi - desvio);
            if (d > 0.26 && i - 1 > inicio) {
              inicio = i - 1; // se quiebra: arranca un tramo nuevo
            }
          }
          final tramo = pts[i] - pts[inicio];
          final largo = tramo.distance;
          if (largo < w + 20 || largo <= mejor) continue;
          // Solo tramos cuyo centro cae en la zona visible y libre.
          final medio = (pts[i] + pts[inicio]) / 2;
          if (!visible.contains(medio)) continue;
          mejor = largo;
          centro = medio;
          angulo = math.atan2(tramo.dy, tramo.dx);
        }
        // Siempre legible: nunca cabeza abajo.
        if (angulo > math.pi / 2) angulo -= math.pi;
        if (angulo < -math.pi / 2) angulo += math.pi;
      }
      if (centro == null) continue;
      final cos = math.cos(angulo).abs(), sin = math.sin(angulo).abs();
      final caja = Rect.fromCenter(
        center: centro,
        width: w * cos + h * sin,
        height: w * sin + h * cos,
      );
      if (caja.left < 4 ||
          caja.top < 4 ||
          caja.right > tam.width - 4 ||
          caja.bottom > tam.height - 4) {
        continue;
      }
      final holgada = caja.inflate(6);
      if (ocupados.any((o) => o.overlaps(holgada))) continue;
      final previo = puestos[r.texto];
      if (previo != null && (previo - centro).distance < 260) continue;
      ocupados.add(holgada);
      puestos[r.texto] = centro;
      rotulosPuestos.add(r.texto);
      cuenta++;
      c.save();
      c.translate(centro.dx, centro.dy);
      c.rotate(angulo);
      tp.paint(c, Offset(-w / 2, -h / 2));
      c.restore();
    }
  }

  // --- trazos ------------------------------------------------------------------

  void _trazo(Canvas c, List<Offset> pts, EstiloTrazo e, double fase) {
    if (pts.length < 2) return;
    Paint linea(Color color, double w) =>
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round;
    final path = Path()..addPolygon(pts, false);
    switch (e) {
      case EstiloTrazo.bus:
        c.drawPath(path, linea(estilo.borde, 10));
        c.drawPath(path, linea(estilo.bus, 6.5));
      case EstiloTrazo.busTenue:
        c.drawPath(path, linea(estilo.busTenue, 4.5));
      case EstiloTrazo.busHecho:
        c.drawPath(path, linea(estilo.paradaRed.withValues(alpha: 0.28), 5));
      case EstiloTrazo.caminar:
        puntosALoLargo(
          c,
          pts,
          Paint()..color = estilo.borde,
          radio: 4.8,
          separacion: 10,
        );
        puntosALoLargo(
          c,
          pts,
          Paint()..color = estilo.caminar,
          radio: 3.4,
          separacion: 10,
        );
      case EstiloTrazo.caminarTenue:
        puntosALoLargo(
          c,
          pts,
          Paint()..color = estilo.caminarTenue,
          radio: 2.4,
          separacion: 8,
        );
      case EstiloTrazo.aproximacion:
        c.drawPath(path, linea(estilo.borde, 8));
        guiones(
          c,
          pts,
          linea(estilo.enVivo, 4.5),
          trazo: 9,
          hueco: 7,
          fase: -fase * 128,
        );
    }
  }

  // --- marcadores ------------------------------------------------------------------

  static final _sombra =
      Paint()
        ..color = const Color(0x38000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

  /// Un ciclo de flotación por vuelta de [fase] (sin saltos al reiniciar).
  static double _flotar(double fase) => math.sin(fase * 2 * math.pi);

  void _paradaRecorrido(
    Canvas c,
    MarcaParadaRecorrido m,
    Offset p,
    double fase,
  ) {
    switch (m.estado) {
      case EstadoParadaRecorrido.pasada:
        c.drawCircle(p, 3.6, Paint()..color = estilo.marcadorFondo);
        c.drawCircle(
          p,
          3.6,
          Paint()
            ..color = estilo.paradaRed.withValues(alpha: 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      case EstadoParadaRecorrido.futura:
        c.drawCircle(p, 4.6, Paint()..color = estilo.marcadorFondo);
        c.drawCircle(
          p,
          4.6,
          Paint()
            ..color = estilo.bus
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2,
        );
      case EstadoParadaRecorrido.proxima:
        _pulso(c, p, fase, estilo.bus);
        c.drawCircle(p.translate(0, 1), 8, _sombra);
        c.drawCircle(p, 7.5, Paint()..color = estilo.marcadorFondo);
        c.drawCircle(
          p,
          7.5,
          Paint()
            ..color = estilo.bus
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        c.drawCircle(p, 2.6, Paint()..color = estilo.bus);
    }
  }

  void _marca(Canvas c, MarcaMapa m, Offset p, double fase) {
    switch (m) {
      case MarcaParadaRecorrido() || MarcaTramo():
        break; // se dibujan aparte
      case MarcaOrigen():
        c.drawCircle(p, 7, Paint()..color = estilo.marcadorFondo);
        c.drawCircle(
          p,
          7,
          Paint()
            ..color = estilo.tinta
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      case MarcaDestino():
        _pin(c, p);
      case MarcaParada(:final rol, :final activa, :final urgente):
        final color = rol == RolParada.subida ? estilo.bus : estilo.tinta;
        final acento = urgente ? estilo.bus : color;
        if (activa) _pulso(c, p, fase, acento);
        c.drawCircle(p.translate(0, 1.5), 11, _sombra);
        c.drawCircle(
          p,
          11,
          Paint()..color = urgente ? estilo.bus : estilo.marcadorFondo,
        );
        c.drawCircle(
          p,
          11,
          Paint()
            ..color = urgente ? estilo.borde : acento
            ..style = PaintingStyle.stroke
            ..strokeWidth = urgente ? 2.5 : 3,
        );
        // La flecha flota hacia afuera: sube en la subida, baja en la bajada.
        final sube = rol == RolParada.subida;
        final dy = activa ? _flotar(fase) * 1.6 * (sube ? -1 : 1) : 0.0;
        _icono(
          c,
          sube ? Icons.north_rounded : Icons.south_rounded,
          p.translate(0, dy),
          13,
          urgente ? Colors.white : acento,
        );
      case MarcaParadaConsultada():
        _pulso(c, p, fase, estilo.caminar);
        c.drawCircle(p.translate(0, 1.5), 12, _sombra);
        c.drawCircle(p, 12, Paint()..color = estilo.marcadorFondo);
        c.drawCircle(
          p,
          12,
          Paint()
            ..color = estilo.tinta
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        _icono(c, Icons.directions_bus_rounded, p, 13, estilo.tinta);
      case MarcaBus(:final rumbo, :final enVivo):
        _vehiculo(c, p, rumbo, enVivo ? estilo.enVivo : estilo.programado);
      case MarcaUsuarioEnBus(:final linea):
        _insigniaBus(c, p, linea);
      case MarcaUsuario(:final rumbo, :final caminando):
        if (caminando && rumbo != null) _cono(c, p, rumbo);
        _pulso(c, p, fase, estilo.caminar);
        c.drawCircle(p.translate(0, 1), 11, _sombra);
        c.drawCircle(p, 10.5, Paint()..color = Colors.white);
        c.drawCircle(p, 7.5, Paint()..color = estilo.caminar);
    }
  }

  void _pulso(Canvas c, Offset p, double fase, Color color) {
    final t = (fase * 2) % 1.0;
    c.drawCircle(
      p,
      12 + 20 * t,
      Paint()..color = color.withValues(alpha: 0.28 * (1 - t)),
    );
  }

  /// Hacia dónde camina el usuario: un haz suave, como una linterna.
  void _cono(Canvas c, Offset p, double rumbo) {
    final ang = (rumbo - 90) * math.pi / 180;
    const abre = 0.55, largo = 40.0;
    final rect = Rect.fromCircle(center: p, radius: largo);
    final haz =
        Path()
          ..moveTo(p.dx, p.dy)
          ..arcTo(rect, ang - abre, 2 * abre, false)
          ..close();
    c.drawPath(
      haz,
      Paint()
        ..shader = RadialGradient(
          colors: [
            estilo.caminar.withValues(alpha: 0.42),
            estilo.caminar.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  /// El bus que viene: un disco con el ícono y, si se conoce, su rumbo. El
  /// aro dice si es en vivo (verde) o por horario (ámbar).
  void _vehiculo(Canvas c, Offset p, double? rumbo, Color aro) {
    if (rumbo != null) {
      final ang = (rumbo - 90) * math.pi / 180;
      final dir = Offset(math.cos(ang), math.sin(ang));
      final normal = Offset(-dir.dy, dir.dx);
      final punta = p + dir * 19;
      final base = p + dir * 12;
      c.drawPath(
        Path()
          ..moveTo(punta.dx, punta.dy)
          ..lineTo((base + normal * 6).dx, (base + normal * 6).dy)
          ..lineTo((base - normal * 6).dx, (base - normal * 6).dy)
          ..close(),
        Paint()..color = estilo.bus,
      );
    }
    c.drawCircle(p.translate(0, 1.5), 13, _sombra);
    c.drawCircle(p, 13, Paint()..color = aro);
    c.drawCircle(p, 10.5, Paint()..color = estilo.bus);
    _icono(c, Icons.directions_bus_rounded, p, 13, Colors.white);
  }

  void _pin(Canvas c, Offset p) {
    final cabeza = p.translate(0, -26);
    final path =
        Path()
          ..moveTo(p.dx, p.dy)
          ..quadraticBezierTo(
            p.dx - 5,
            p.dy - 10,
            cabeza.dx - 12,
            cabeza.dy + 5,
          )
          ..arcToPoint(
            Offset(cabeza.dx + 12, cabeza.dy + 5),
            radius: const Radius.circular(13),
            largeArc: true,
          )
          ..quadraticBezierTo(p.dx + 5, p.dy - 10, p.dx, p.dy)
          ..close();
    c.drawPath(path.shift(const Offset(0, 2)), _sombra);
    c.drawPath(path, Paint()..color = estilo.tinta);
    _icono(
      c,
      Icons.flag_rounded,
      cabeza.translate(0, 1),
      15,
      estilo.brillo == Brightness.dark ? const Color(0xFF111318) : Colors.white,
    );
  }

  void _icono(Canvas c, IconData i, Offset centro, double tam, Color color) {
    final clave = 'i${i.codePoint}|$tam|${color.toARGB32()}';
    final tp =
        _textos[clave] ??= (TextPainter(
          text: TextSpan(
            text: String.fromCharCode(i.codePoint),
            style: TextStyle(
              fontFamily: i.fontFamily,
              package: i.fontPackage,
              fontSize: tam,
              color: color,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout());
    tp.paint(c, centro - Offset(tp.width / 2, tp.height / 2));
  }

  /// El usuario arriba del bus: [ícono + línea] con aro azul y punta.
  void _insigniaBus(Canvas c, Offset p, String linea) {
    final tl = _texto2(linea, 15, FontWeight.w800, Colors.white);
    const alto = 30.0, icono = 18.0, pad = 8.0;
    final ancho = pad + icono + 4 + tl.width + pad;
    final arriba = p.dy - alto - 9;
    final caja = RRect.fromRectAndRadius(
      Rect.fromLTWH(p.dx - ancho / 2, arriba, ancho, alto),
      const Radius.circular(10),
    );
    final punta =
        Path()
          ..moveTo(p.dx - 6, arriba + alto - 1)
          ..lineTo(p.dx, p.dy - 2)
          ..lineTo(p.dx + 6, arriba + alto - 1)
          ..close();
    c.drawRRect(caja.shift(const Offset(0, 2)), _sombra);
    c.drawRRect(caja.inflate(3), Paint()..color = estilo.caminar);
    c.drawPath(punta, Paint()..color = estilo.bus);
    c.drawRRect(caja, Paint()..color = estilo.bus);
    _icono(
      c,
      Icons.directions_bus_rounded,
      Offset(caja.left + pad + icono / 2, arriba + alto / 2),
      icono,
      Colors.white,
    );
    tl.paint(
      c,
      Offset(caja.left + pad + icono + 4, arriba + (alto - tl.height) / 2),
    );
    c.drawCircle(p, 6, Paint()..color = Colors.white);
    c.drawCircle(p, 4, Paint()..color = estilo.caminar);
  }

  TextPainter _texto2(
    String t,
    double tam,
    FontWeight w,
    Color color, {
    double espaciado = 0,
  }) {
    final clave = 'm$tam${w.value}${color.toARGB32()}|$espaciado|$t';
    return _textos[clave] ??= () {
      if (_textos.length > 600) _textos.clear();
      return TextPainter(
        text: TextSpan(
          text: t,
          style: TextStyle(
            fontFamily: familia,
            fontSize: tam,
            fontWeight: w,
            color: color,
            letterSpacing: espaciado,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
    }();
  }

  // --- globos ------------------------------------------------------------------

  /// Cuánto sobresale cada marcador por arriba y por abajo de su punto: la
  /// punta del globo apoya justo ahí.
  (double arriba, double abajo) _salienteDe(MarcaMapa m) => switch (m) {
    MarcaDestino() => (40, 4),
    MarcaBus() => (18, 16),
    MarcaParadaRecorrido() => (10, 10),
    MarcaUsuario() => (14, 14),
    _ => (15, 14),
  };

  static const _cola = 7.0;

  _Contenido _medirGlobo(Globo g) {
    final urgente = g.tono == TonoGlobo.urgente;
    final titulo = _texto2(
      g.titulo,
      14.5,
      FontWeight.w700,
      urgente ? Colors.white : estilo.tinta,
    );
    TextPainter? detalle;
    final d = g.detalle;
    if (d != null) {
      final mayus = d == d.toUpperCase();
      detalle = _texto2(
        d,
        mayus ? 10.5 : 12,
        mayus ? FontWeight.w700 : FontWeight.w500,
        urgente
            ? Colors.white.withValues(alpha: 0.9)
            : g.enVivo
            ? estilo.enVivo
            : g.programado
            ? estilo.programado
            : estilo.rotulo,
        espaciado: mayus ? 0.8 : 0,
      );
    }
    final linea =
        g.linea == null
            ? null
            : _texto2(g.linea!, 13, FontWeight.w800, Colors.white);
    final double anchoPastilla =
        linea == null ? 0 : 6 + 14 + 3 + linea.width + 7;
    final punto = g.enVivo ? 10.0 : 0.0;
    final anchoTexto = math.max(titulo.width, (detalle?.width ?? 0.0) + punto);
    final altoTexto = titulo.height + (detalle == null ? 0 : detalle.height);
    final double ancho =
        20 + (linea == null ? 0 : anchoPastilla + 8) + anchoTexto;
    final double alto = 14 + math.max(linea == null ? 0 : 22, altoTexto);
    return _Contenido(
      Size(ancho, alto),
      titulo: titulo,
      detalle: detalle,
      linea: linea,
      anchoPastilla: anchoPastilla,
    );
  }

  _Contenido _medirTramo(MarcaTramo t) {
    final texto = _texto2(
      t.texto,
      t.caminar ? 12.5 : 13,
      FontWeight.w700,
      t.caminar ? estilo.rotulo : Colors.white,
    );
    return _Contenido(Size(8 + 15 + 3 + texto.width + 9, 24), titulo: texto);
  }

  List<_GloboPuesto> _ubicarGlobos(
    List<(MarcaMapa, Offset)> marcas,
    Rect zona,
    List<Rect> cajasMarcas,
    double fase,
  ) {
    final candidatos = [
      for (final (m, p) in marcas)
        if (m.globo != null || m is MarcaTramo) (m, p),
    ]..sort((a, b) {
      int prio(MarcaMapa m) => m.globo?.prioridad ?? 30;
      return prio(b.$1) - prio(a.$1);
    });
    final puestos = <_GloboPuesto>[];
    bool libre(Rect r, {required bool estricto}) {
      if (r.left < zona.left ||
          r.right > zona.right ||
          r.top < zona.top ||
          r.bottom > zona.bottom) {
        return false;
      }
      final holgada = r.inflate(3);
      if (puestos.any((g) => g.caja.overlaps(holgada))) return false;
      if (estricto && cajasMarcas.any((m) => m.overlaps(r.deflate(2)))) {
        return false;
      }
      return true;
    }

    double centrarX(double ancho, double x) =>
        (x - ancho / 2).clamp(zona.left, zona.right - ancho).toDouble();

    for (final (m, p) in candidatos) {
      if (m is MarcaTramo) {
        final medida = _medirTramo(m);
        final caja = Rect.fromCenter(
          center: p,
          width: medida.tam.width,
          height: medida.tam.height,
        );
        if (libre(caja, estricto: true)) {
          puestos.add(_GloboPuesto(caja, p, contenido: medida, tramo: m));
        }
        continue;
      }
      final g = m.globo!;
      final medida = _medirGlobo(g);
      final (arriba, abajo) = _salienteDe(m);
      final w = medida.tam.width, h = medida.tam.height;
      const lateral = 14.0;
      double centrarY(double y) =>
          (y - h / 2).clamp(zona.top, zona.bottom - h).toDouble();
      // Arriba es lo natural; si choca, abajo, y si no, a los costados.
      final opciones = <(_Lado, Rect, Offset)>[
        (
          _Lado.arriba,
          Rect.fromLTWH(centrarX(w, p.dx), p.dy - arriba - _cola - h, w, h),
          p.translate(0, -arriba),
        ),
        (
          _Lado.abajo,
          Rect.fromLTWH(centrarX(w, p.dx), p.dy + abajo + _cola, w, h),
          p.translate(0, abajo),
        ),
        // Más arriba, con la cola larga: cuando al lado hay otro marcador.
        (
          _Lado.arriba,
          Rect.fromLTWH(
            centrarX(w, p.dx),
            p.dy - arriba - _cola - 40 - h,
            w,
            h,
          ),
          p.translate(0, -arriba),
        ),
        (
          _Lado.derecha,
          Rect.fromLTWH(p.dx + lateral + _cola, centrarY(p.dy), w, h),
          p.translate(lateral, 0),
        ),
        (
          _Lado.izquierda,
          Rect.fromLTWH(p.dx - lateral - _cola - w, centrarY(p.dy), w, h),
          p.translate(-lateral, 0),
        ),
      ];
      final estricto = g.prioridad < 90;
      var elegida = opciones.where((o) => libre(o.$2, estricto: estricto));
      if (elegida.isEmpty && g.prioridad >= 90) {
        // Lo esencial se muestra igual, del lado que entre en la vista.
        elegida = [opciones[0].$2.top >= zona.top ? opciones[0] : opciones[1]];
      }
      if (elegida.isEmpty) continue;
      final (lado, caja, punta) = elegida.first;
      puestos.add(
        _GloboPuesto(
          caja,
          punta,
          contenido: medida,
          globo: g,
          lado: lado,
          flota: m is MarcaBus || g.tono == TonoGlobo.urgente,
        ),
      );
    }
    return puestos;
  }

  void _globo(Canvas c, _GloboPuesto g, double fase) {
    final medida = g.contenido;
    final tramo = g.tramo;
    if (tramo != null) {
      final caja = RRect.fromRectAndRadius(g.caja, const Radius.circular(12));
      c.drawRRect(caja.shift(const Offset(0, 1.5)), _sombra);
      c.drawRRect(
        caja,
        Paint()..color = tramo.caminar ? estilo.marcadorFondo : estilo.bus,
      );
      final color = tramo.caminar ? estilo.rotulo : Colors.white;
      _icono(
        c,
        tramo.caminar
            ? Icons.directions_walk_rounded
            : Icons.directions_bus_rounded,
        Offset(g.caja.left + 8 + 7.5, g.caja.center.dy),
        15,
        color,
      );
      medida.titulo.paint(
        c,
        Offset(
          g.caja.left + 8 + 15 + 3,
          g.caja.center.dy - medida.titulo.height / 2,
        ),
      );
      return;
    }
    final globo = g.globo!;
    final dy = g.flota ? _flotar(fase) * 2.5 : 0.0;
    final r = g.caja.translate(0, dy);
    final punta = g.punta.translate(0, dy);
    final urgente = globo.tono == TonoGlobo.urgente;
    final fondo = urgente ? estilo.bus : estilo.marcadorFondo;
    final caja = RRect.fromRectAndRadius(r, const Radius.circular(13));
    // La cola sale del borde que mira al marcador.
    final Path cola;
    switch (g.lado) {
      case _Lado.arriba || _Lado.abajo:
        final debajo = g.lado == _Lado.abajo;
        final base = debajo ? r.top + 1 : r.bottom - 1;
        final x = punta.dx.clamp(r.left + 16, r.right - 16).toDouble();
        cola =
            Path()
              ..moveTo(x - 7, base)
              ..lineTo(punta.dx, punta.dy + (debajo ? 2 : -2))
              ..lineTo(x + 7, base)
              ..close();
      case _Lado.derecha || _Lado.izquierda:
        final derecha = g.lado == _Lado.derecha;
        final base = derecha ? r.left + 1 : r.right - 1;
        final y = punta.dy.clamp(r.top + 12, r.bottom - 12).toDouble();
        cola =
            Path()
              ..moveTo(base, y - 7)
              ..lineTo(punta.dx + (derecha ? 2 : -2), punta.dy)
              ..lineTo(base, y + 7)
              ..close();
    }
    c.drawRRect(caja.shift(const Offset(0, 3)), _sombra);
    c.drawPath(cola.shift(const Offset(0, 2)), _sombra);
    c.drawPath(cola, Paint()..color = fondo);
    // Misma familia que las láminas: un degradé apenas más claro
    // arriba y un filo que brilla arriba y se apaga abajo.
    final oscuro = estilo.brillo == Brightness.dark;
    c.drawRRect(
      caja,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(fondo, Colors.white, urgente ? 0.10 : 0.06)!,
            Color.lerp(fondo, Colors.black, oscuro ? 0.10 : 0.03)!,
          ],
        ).createShader(r),
    );
    c.drawRRect(
      caja.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors:
              urgente
                  ? [Colors.white.withValues(alpha: 0.45), Colors.transparent]
                  : oscuro
                  ? [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.04),
                  ]
                  : [Colors.white, Colors.black.withValues(alpha: 0.07)],
        ).createShader(r),
    );

    var x0 = r.left + 10;
    final linea = medida.linea;
    if (linea != null) {
      final pastilla = RRect.fromRectAndRadius(
        Rect.fromLTWH(x0, r.center.dy - 11, medida.anchoPastilla, 22),
        const Radius.circular(7),
      );
      c.drawRRect(pastilla, Paint()..color = estilo.bus);
      _icono(
        c,
        Icons.directions_bus_rounded,
        Offset(x0 + 6 + 7, r.center.dy),
        14,
        Colors.white,
      );
      linea.paint(c, Offset(x0 + 6 + 14 + 3, r.center.dy - linea.height / 2));
      x0 += medida.anchoPastilla + 8;
    }
    final detalle = medida.detalle;
    final altoTexto =
        medida.titulo.height + (detalle == null ? 0 : detalle.height);
    var y = r.center.dy - altoTexto / 2;
    medida.titulo.paint(c, Offset(x0, y));
    y += medida.titulo.height;
    if (detalle != null) {
      var xd = x0;
      if (globo.enVivo) {
        final centro = Offset(x0 + 3.5, y + detalle.height / 2);
        final t = (fase * 2) % 1.0;
        c.drawCircle(
          centro,
          3.5 + 4 * t,
          Paint()..color = estilo.enVivo.withValues(alpha: 0.35 * (1 - t)),
        );
        c.drawCircle(centro, 3.5, Paint()..color = estilo.enVivo);
        xd += 10;
      }
      detalle.paint(c, Offset(xd, y));
    }
  }

  // --- objetivo fuera de la vista ---------------------------------------------

  /// Si [p] quedó fuera de la vista, una píldora en el borde apunta hacia
  /// allá (con una punta del lado del objeto y, si [rotarIcono], el ícono
  /// girado en esa dirección). Evita pisar las ya puestas en [puestas].
  bool _enBorde(
    Canvas c,
    Offset p,
    Rect zona,
    List<Rect> puestas, {
    required String texto,
    required Color colorTexto,
    required Color fondoIcono,
    required IconData icono,
    bool rotarIcono = false,
  }) {
    if (zona.deflate(16).contains(p)) return false;
    final tp = _texto2(texto, 13, FontWeight.w700, colorTexto);
    const alto = 32.0;
    final ancho = 6 + 22 + 8 + tp.width + 12;
    final interior = Rect.fromLTRB(
      zona.left + ancho / 2 + 4,
      zona.top + alto / 2 + 4,
      zona.right - ancho / 2 - 4,
      zona.bottom - alto / 2 - 4,
    );
    if (interior.width <= 0 || interior.height <= 0) return false;
    final centro = zona.center;
    final dir = p - centro;
    if (dir.distance < 1) return false;
    var t = double.infinity;
    if (dir.dx > 0) t = math.min(t, (interior.right - centro.dx) / dir.dx);
    if (dir.dx < 0) t = math.min(t, (interior.left - centro.dx) / dir.dx);
    if (dir.dy > 0) t = math.min(t, (interior.bottom - centro.dy) / dir.dy);
    if (dir.dy < 0) t = math.min(t, (interior.top - centro.dy) / dir.dy);
    var q = centro + dir * t;
    // Si pisa otra, se corre a lo largo del borde.
    final vertical =
        (q.dx - interior.left).abs() < 1 || (q.dx - interior.right).abs() < 1;
    for (var i = 1; i <= 4; i++) {
      final caja = Rect.fromCenter(center: q, width: ancho, height: alto);
      if (!puestas.any((r) => r.overlaps(caja.inflate(4)))) break;
      final paso = (alto + 8) * (i.isOdd ? i : -i);
      q = vertical ? q.translate(0, paso) : q.translate(paso, 0);
      q = Offset(
        q.dx.clamp(interior.left, interior.right),
        q.dy.clamp(interior.top, interior.bottom),
      );
    }
    final rect = Rect.fromCenter(center: q, width: ancho, height: alto);
    puestas.add(rect);
    final caja = RRect.fromRectAndRadius(rect, const Radius.circular(alto / 2));
    // Punta hacia el objeto, desde el borde de la píldora.
    final ang = math.atan2(dir.dy, dir.dx);
    final u = Offset(math.cos(ang), math.sin(ang));
    final borde = _salidaDeCaja(rect, u);
    final n = Offset(-u.dy, u.dx);
    final punta =
        Path()
          ..moveTo((borde - u * 3 + n * 6).dx, (borde - u * 3 + n * 6).dy)
          ..lineTo((borde + u * 7).dx, (borde + u * 7).dy)
          ..lineTo((borde - u * 3 - n * 6).dx, (borde - u * 3 - n * 6).dy)
          ..close();
    c.drawRRect(caja.shift(const Offset(0, 2)), _sombra);
    c.drawPath(punta, Paint()..color = estilo.marcadorFondo);
    c.drawRRect(caja, Paint()..color = estilo.marcadorFondo);
    c.drawRRect(
      caja.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors:
              estilo.brillo == Brightness.dark
                  ? [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.04),
                  ]
                  : [Colors.white, Colors.black.withValues(alpha: 0.07)],
        ).createShader(rect),
    );
    final circulo = Offset(caja.left + 6 + 11, q.dy);
    c.drawCircle(circulo, 11, Paint()..color = fondoIcono);
    if (rotarIcono) {
      c.save();
      c.translate(circulo.dx, circulo.dy);
      c.rotate(ang + math.pi / 2);
      _icono(c, icono, Offset.zero, 14, Colors.white);
      c.restore();
    } else {
      _icono(c, icono, circulo, 13, Colors.white);
    }
    tp.paint(c, Offset(caja.left + 6 + 22 + 8, q.dy - tp.height / 2));
    return true;
  }

  /// Punto del borde de [r] en la dirección [u] desde su centro.
  static Offset _salidaDeCaja(Rect r, Offset u) {
    final c = r.center;
    var t = double.infinity;
    if (u.dx.abs() > 1e-6) t = math.min(t, (r.width / 2) / u.dx.abs());
    if (u.dy.abs() > 1e-6) t = math.min(t, (r.height / 2) / u.dy.abs());
    return c + u * t;
  }

  void _atribucion(Canvas c, Size tam, double margenInferior) {
    final tp = _texto2('© OpenStreetMap', 10, FontWeight.w500, estilo.barrio);
    final y = (tam.height - margenInferior - tp.height - 6).clamp(
      6.0,
      tam.height,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(6, y - 2, tp.width + 10, tp.height + 4),
        const Radius.circular(6),
      ),
      Paint()..color = estilo.rotuloHalo.withValues(alpha: 0.75),
    );
    tp.paint(c, Offset(11, y));
  }
}

class _Contenido {
  final Size tam;
  final TextPainter titulo;
  final TextPainter? detalle;
  final TextPainter? linea;
  final double anchoPastilla;
  const _Contenido(
    this.tam, {
    required this.titulo,
    this.detalle,
    this.linea,
    this.anchoPastilla = 0,
  });
}

class _GloboPuesto {
  final Rect caja;

  /// Dónde apoya la punta (borde del marcador).
  final Offset punta;
  final _Contenido contenido;
  final Globo? globo;
  final MarcaTramo? tramo;
  final _Lado lado;
  final bool flota;
  const _GloboPuesto(
    this.caja,
    this.punta, {
    required this.contenido,
    this.globo,
    this.tramo,
    this.lado = _Lado.arriba,
    this.flota = false,
  });
}

/// De qué lado del marcador queda el globo.
enum _Lado { arriba, abajo, derecha, izquierda }
