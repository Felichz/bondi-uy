// La presentación "por dentro": el teléfono enchufado a una placa donde se
// ven las piezas de la app y las llamadas entre ellas, a medida que ocurren.
//
// Cada pulso es una traza real (lib/contract/trazas.dart): una acción que la
// UI le pide a la lógica, el estado que la lógica publica, una lectura del
// GPS, un pedido a la API de buses, una decisión del navegador o del
// seguidor. Nada está guionado: lo que se ve es lo que la app hace.
//
// La placa se pinta en dos capas: lo fijo (fondo, pistas, chips) se graba una
// vez por tamaño; lo vivo (pulsos, pistas encendidas, luces, lecturas) se
// pinta cada cuadro, sin reconstruir widgets.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contract/app_state.dart';
import '../../contract/proveedores.dart';
import '../../contract/trazas.dart';
import '../plataforma/enlaces.dart';
import '../textos/textos.dart';

// --- Paleta de la placa (siempre oscura) --------------------------------------

const _fondoCentro = Color(0xFF12161D);
const _fondoBorde = Color(0xFF06080B);
const _pista = Color(0xFF232A35);
const _pistaLuz = Color(0xFF2E3744);
const _chip = Color(0xFF151A21);
const _chipArriba = Color(0xFF1D232C);
const _chipFilo = Color(0xFF323B48);
const _pin = Color(0xFF8F7A52);
const _texto = Color(0xFFF2F4F7);
const _textoSuave = Color(0xFFA7AEBA);
const _textoTenue = Color(0xFF6B7380);

const _accion = Color(0xFFE9EDF3);
const _estado = Color(0xFF36D08F);
const _ubicacion = Color(0xFF6B9BFF);
const _bus = Color(0xFFFF6A55);
const _plan = Color(0xFFF2A93B);
const _red = Color(0xFF8FA6C4);

/// Color de una llamada según su dominio.
Color _colorDe(Traza t) {
  if (t.desde == Pieza.interfaz) return _accion;
  if (t.hacia == Pieza.interfaz) return _estado;
  final otra = t.desde == Pieza.controlador ? t.hacia : t.desde;
  return switch (otra) {
    Pieza.ubicacion || Pieza.navegador => _ubicacion,
    Pieza.llegadas || Pieza.seguidor => _bus,
    Pieza.planificador || Pieza.recomendador => _plan,
    Pieza.catalogo || Pieza.lugares => _red,
    _ => _accion,
  };
}

/// El color del dominio de cada pieza.
Color _colorPieza(Pieza p) => switch (p) {
  Pieza.interfaz => _accion,
  Pieza.controlador => _estado,
  Pieza.navegador || Pieza.ubicacion => _ubicacion,
  Pieza.seguidor || Pieza.llegadas => _bus,
  Pieza.recomendador || Pieza.planificador => _plan,
  Pieza.catalogo || Pieza.lugares => _red,
};

IconData _iconoPieza(Pieza p) => switch (p) {
  Pieza.interfaz => Icons.swap_horiz,
  Pieza.controlador => Icons.hub_outlined,
  Pieza.navegador => Icons.navigation_outlined,
  Pieza.seguidor => Icons.directions_bus_outlined,
  Pieza.recomendador => Icons.sort,
  Pieza.ubicacion => Icons.my_location,
  Pieza.llegadas => Icons.schedule,
  Pieza.planificador => Icons.alt_route,
  Pieza.catalogo => Icons.map_outlined,
  Pieza.lugares => Icons.place_outlined,
};

/// Dónde está cada pieza en el repositorio.
String _archivoPieza(Pieza p) => switch (p) {
  Pieza.interfaz => 'lib/contract/',
  Pieza.controlador => 'lib/logic/app_controller.dart',
  Pieza.navegador => 'lib/logic/viaje/navegador.dart',
  Pieza.seguidor => 'lib/logic/viaje/seguidor_bus.dart',
  Pieza.recomendador => 'lib/logic/viaje/recomendador.dart',
  Pieza.ubicacion => 'lib/logic/servicios/ubicacion_gps.dart',
  Pieza.llegadas => 'lib/logic/servicios/montevideo.dart',
  Pieza.planificador => 'lib/logic/servicios/otp.dart',
  Pieza.catalogo => 'lib/logic/servicios/catalogo_assets.dart',
  Pieza.lugares => 'lib/logic/servicios/lugares.dart',
};

const _repo = 'https://github.com/Felichz/bondi-uy';

String _enlacePieza(Pieza p) {
  final f = _archivoPieza(p);
  return f.endsWith('/') ? '$_repo/tree/main/$f' : '$_repo/blob/main/$f';
}

/// La pata por donde una pista en [pt] entra a la caja [c] (null si [pt] no
/// está en su borde).
Rect? _pataEn(Rect c, Offset pt) {
  const e = 0.5;
  final enAlto = pt.dy > c.top && pt.dy < c.bottom;
  final enAncho = pt.dx > c.left && pt.dx < c.right;
  if (enAlto && (pt.dx - c.left).abs() < e) {
    return Rect.fromLTWH(c.left - 6, pt.dy - 2, 6, 4);
  }
  if (enAlto && (pt.dx - c.right).abs() < e) {
    return Rect.fromLTWH(c.right, pt.dy - 2, 6, 4);
  }
  if (enAncho && (pt.dy - c.top).abs() < e) {
    return Rect.fromLTWH(pt.dx - 2, c.top - 6, 4, 6);
  }
  if (enAncho && (pt.dy - c.bottom).abs() < e) {
    return Rect.fromLTWH(pt.dx - 2, c.bottom, 4, 6);
  }
  return null;
}

TextStyle _estilo(
  double tam,
  Color color, {
  FontWeight peso = FontWeight.w500,
}) => TextStyle(
  fontFamily: 'Roboto',
  fontSize: tam,
  color: color,
  fontWeight: peso,
  height: 1.25,
  fontFeatures: const [ui.FontFeature.tabularFigures()],
);

// --- Plano: dónde va cada cosa ---------------------------------------------

/// Una pieza dibujada en la placa: su chip, su nombre y su papel.
class _Chip {
  final Pieza pieza;
  final Rect rect;
  final String nombre;
  final String papel;

  /// Conector de borde (un puerto hacia el mundo) o chip del núcleo.
  final bool puerto;
  const _Chip(
    this.pieza,
    this.rect,
    this.nombre,
    this.papel, {
    this.puerto = false,
  });
}

class _Plano {
  final Size tam;
  final Rect telefono;
  final Rect conector;
  final Map<Pieza, _Chip> chips;
  final Rect contrato;

  /// Pistas entre piezas vecinas (sin la interfaz: esa va por el contrato,
  /// en dos carriles).
  final Map<(Pieza, Pieza), List<Offset>> pistas;
  final List<Offset> acciones;
  final List<Offset> estado;

  /// Los cuerpos de los chips (el contrato incluido): lo vivo se pinta debajo,
  /// así una pista entra a un chip por sus patas y no le pasa por encima.
  late final List<RRect> cuerpos = [
    RRect.fromRectAndRadius(contrato, const Radius.circular(12)),
    for (final ch in chips.values)
      RRect.fromRectAndRadius(ch.rect, const Radius.circular(12)),
  ];

  /// La caja de cada pieza (la interfaz es la App API).
  late final Map<Pieza, Rect> cajas = {
    Pieza.interfaz: contrato,
    for (final ch in chips.values) ch.pieza: ch.rect,
  };

  /// Las patas por donde entran las pistas a las cajas, por punto de pista.
  late final Map<Offset, Rect> patas = () {
    final r = <Offset, Rect>{};
    for (final ruta in [...pistas.values, acciones, estado]) {
      for (final pt in ruta) {
        for (final c in cajas.values) {
          final pata = _pataEn(c, pt);
          if (pata != null) r[pt] = pata;
        }
      }
    }
    return r;
  }();

  Pieza? piezaEn(Offset o) {
    for (final e in cajas.entries) {
      if (e.value.inflate(4).contains(o)) return e.key;
    }
    return null;
  }

  String nombreDe(Pieza p) =>
      p == Pieza.interfaz ? 'App API' : chips[p]!.nombre;

  _Plano._(
    this.tam,
    this.telefono,
    this.conector,
    this.chips,
    this.contrato,
    this.pistas,
    this.acciones,
    this.estado,
  );

  // Medidas de la placa: los chips nunca se achican (sus textos tampoco);
  // lo que sobra de ancho se reparte entre los huecos.
  static const _anchoContrato = 150.0;
  static const _anchoControl = 214.0;
  static const _anchoNucleo = 196.0;
  static const _altoNucleo = 120.0;
  static const _anchoPuerto = 220.0;
  static const _huecoConector = 40.0;
  static const _huecoContrato = 48.0;

  /// Lugar para que las pistas a los puertos doblen a la derecha del núcleo.
  static const _huecoPuertos = 92.0;
  static const _margen = 24.0;

  /// Ancho que necesita la placa a la derecha del teléfono.
  static const anchoMinimo =
      _huecoConector +
      _anchoContrato +
      _huecoContrato +
      _anchoControl +
      _huecoPuertos +
      _anchoPuerto +
      _margen;

  factory _Plano(Size tam, Rect telefono) {
    final cy = telefono.center.dy;
    final x0 = telefono.right;
    final alto = tam.height;
    final sobra = math.max(0.0, tam.width - x0 - anchoMinimo);
    final conector = Rect.fromLTWH(telefono.right - 6, cy - 64, 22, 128);

    Rect centrado(double x, double y, double w, double h) =>
        Rect.fromCenter(center: Offset(x, y), width: w, height: h);

    final contrato = Rect.fromLTWH(
      x0 + _huecoConector + sobra * 0.25,
      cy - 75,
      _anchoContrato,
      150,
    );
    final control = Rect.fromLTWH(
      contrato.right + _huecoContrato + sobra * 0.30,
      cy - 84,
      _anchoControl,
      168,
    );
    // Arriba, el navegador y el recomendador lado a lado, sin pasar del borde
    // derecho del controlador (las pistas a los puertos doblan después);
    // abajo, el seguidor.
    const margenV = 28.0;
    final dy = math.min(alto * 0.31, 300.0);
    final yArriba = (cy - dy).clamp(
      margenV + _altoNucleo / 2,
      control.top - 36 - _altoNucleo / 2,
    );
    final yAbajo = (cy + dy).clamp(
      control.bottom + 36 + _altoNucleo / 2,
      alto - margenV - _altoNucleo / 2,
    );
    final recomendador = Rect.fromLTWH(
      control.right - _anchoNucleo,
      yArriba - _altoNucleo / 2,
      _anchoNucleo,
      _altoNucleo,
    );
    final nucleo = <Pieza, Rect>{
      Pieza.recomendador: recomendador,
      Pieza.navegador: recomendador.shift(const Offset(-_anchoNucleo - 24, 0)),
      Pieza.seguidor: centrado(
        control.center.dx,
        yAbajo,
        _anchoNucleo,
        _altoNucleo,
      ),
    };
    const puertos = [
      Pieza.ubicacion,
      Pieza.llegadas,
      Pieza.planificador,
      Pieza.catalogo,
      Pieza.lugares,
    ];
    final paso = math.min(
      (alto - 2 * margenV - 84) / (puertos.length - 1),
      150.0,
    );
    final xPuerto =
        control.right + _huecoPuertos + sobra * 0.45 + _anchoPuerto / 2;
    final chips = <Pieza, _Chip>{
      Pieza.controlador: _Chip(
        Pieza.controlador,
        control,
        'AppController',
        tx.coreControlador,
      ),
      Pieza.navegador: _Chip(
        Pieza.navegador,
        nucleo[Pieza.navegador]!,
        'Navegador',
        tx.coreNavegador,
      ),
      Pieza.recomendador: _Chip(
        Pieza.recomendador,
        nucleo[Pieza.recomendador]!,
        'Recomendador',
        tx.coreRecomendador,
      ),
      Pieza.seguidor: _Chip(
        Pieza.seguidor,
        nucleo[Pieza.seguidor]!,
        'SeguidorBus',
        tx.coreSeguidor,
      ),
      for (var i = 0; i < puertos.length; i++)
        puertos[i]: _Chip(
          puertos[i],
          centrado(
            xPuerto,
            cy + (i - (puertos.length - 1) / 2) * paso,
            _anchoPuerto,
            84,
          ),
          switch (puertos[i]) {
            Pieza.ubicacion => 'GPS',
            Pieza.llegadas => 'API Intendencia',
            Pieza.planificador => 'OpenTripPlanner',
            Pieza.catalogo => 'GTFS',
            _ => 'Lugares',
          },
          switch (puertos[i]) {
            Pieza.ubicacion => 'seguir() · actual()',
            Pieza.llegadas => 'llegadas(parada)',
            Pieza.planificador => 'planificar(a, b)',
            Pieza.catalogo => 'paradas() · shape(id)',
            _ => 'sugerencias(texto)',
          },
          puerto: true,
        ),
    };

    // Pistas del controlador a cada pieza: salen por el lado que la mira.
    // Las de los puertos doblan a la derecha de todo el núcleo.
    final pistas = <(Pieza, Pieza), List<Offset>>{};
    final finNucleo = [
      control,
      ...nucleo.values,
    ].map((r) => r.right).reduce(math.max);
    final porDerecha = [for (final p in puertos) chips[p]!];
    for (var i = 0; i < porDerecha.length; i++) {
      final c = porDerecha[i];
      final salida = Offset(
        control.right,
        control.top + 28 + i * (control.height - 56) / (porDerecha.length - 1),
      );
      pistas[(Pieza.controlador, c.pieza)] = _ruta(
        salida,
        Offset(c.rect.left, c.rect.center.dy),
        quiebre: finNucleo + 28 + i * 14,
      );
    }
    for (final p in [Pieza.navegador, Pieza.recomendador]) {
      final c = chips[p]!.rect;
      final x = c.center.dx.clamp(control.left + 30, control.right - 30);
      pistas[(Pieza.controlador, p)] = _rutaVertical(
        Offset(x, control.top),
        Offset(c.center.dx, c.bottom),
      );
    }
    final seg = chips[Pieza.seguidor]!.rect;
    pistas[(Pieza.controlador, Pieza.seguidor)] = _rutaVertical(
      Offset(seg.center.dx, control.bottom),
      Offset(seg.center.dx, seg.top),
    );

    // La interfaz llega al controlador por el contrato, en dos carriles:
    // las acciones bajan, el estado sube.
    List<Offset> carril(double dy) => [
      Offset(conector.right, cy + dy),
      Offset(contrato.left, cy + dy),
      Offset(contrato.right, cy + dy),
      Offset(control.left, cy + dy),
    ];
    return _Plano._(
      tam,
      telefono,
      conector,
      chips,
      contrato,
      pistas,
      carril(-22),
      carril(22),
    );
  }

  /// El recorrido de una traza: por qué pistas pasa, de dónde a dónde.
  List<Offset>? recorrido(Traza t) {
    if (t.desde == Pieza.interfaz) return acciones;
    if (t.hacia == Pieza.interfaz) return estado.reversed.toList();
    final ida = pistas[(t.desde, t.hacia)];
    if (ida != null) return ida;
    return pistas[(t.hacia, t.desde)]?.reversed.toList();
  }
}

/// Recorrido de pista en ángulos rectos con las esquinas a 45°: sale
/// horizontal, dobla en [quiebre] y llega horizontal.
List<Offset> _ruta(Offset a, Offset b, {required double quiebre}) {
  const r = 14.0;
  if ((a.dy - b.dy).abs() < 1) return [a, b];
  final s = (b.dy - a.dy).sign;
  final c = math.min(r, (b.dy - a.dy).abs() / 2);
  return [
    a,
    Offset(quiebre - c, a.dy),
    Offset(quiebre, a.dy + s * c),
    Offset(quiebre, b.dy - s * c),
    Offset(quiebre + c, b.dy),
    b,
  ];
}

/// Sale vertical y llega vertical, con un tramo horizontal en el medio.
List<Offset> _rutaVertical(Offset a, Offset b) {
  const r = 14.0;
  if ((a.dx - b.dx).abs() < 1) return [a, b];
  final medio = (a.dy + b.dy) / 2;
  final s = (b.dx - a.dx).sign;
  final v = (b.dy - a.dy).sign;
  final c = math.min(r, (b.dx - a.dx).abs() / 2);
  return [
    a,
    Offset(a.dx, medio - v * c),
    Offset(a.dx + s * c, medio),
    Offset(b.dx - s * c, medio),
    Offset(b.dx, medio + v * c),
    b,
  ];
}

// --- Lo vivo ------------------------------------------------------------------

class _Pulso {
  final List<Offset> puntos;
  final List<double> acum;
  final Color color;
  final double inicio;
  final double duracion;

  /// Las patas que cruza, con su distancia sobre el recorrido.
  final List<(double, Rect)> patas;

  /// Cuántas patas ya cruzó la cabeza.
  int cruzadas = 0;

  _Pulso(this.puntos, this.color, this.inicio, Map<Offset, Rect> patasDelPlano)
    : acum = _acumular(puntos),
      duracion = (_acumular(puntos).last / 900).clamp(0.35, 1.1),
      patas = [
        for (final (i, a) in _acumular(puntos).indexed)
          if (patasDelPlano[puntos[i]] case final r?) (a, r),
      ];

  /// Dónde está la cabeza en [ahora] (distancia sobre el recorrido).
  double cabeza(double ahora) =>
      Curves.easeInOutCubic.transform(
        ((ahora - inicio) / duracion).clamp(0.0, 1.0),
      ) *
      largo;

  static List<double> _acumular(List<Offset> p) {
    final a = List<double>.filled(p.length, 0);
    for (var i = 1; i < p.length; i++) {
      a[i] = a[i - 1] + (p[i] - p[i - 1]).distance;
    }
    return a;
  }

  double get largo => acum.last;

  Offset en(double s) {
    if (s <= 0) return puntos.first;
    if (s >= largo) return puntos.last;
    var i = 1;
    while (acum[i] < s) {
      i++;
    }
    final l = acum[i] - acum[i - 1];
    return Offset.lerp(
      puntos[i - 1],
      puntos[i],
      l == 0 ? 0 : (s - acum[i - 1]) / l,
    )!;
  }

  /// La parte del recorrido entre [desde] y [hasta] (metros sobre él).
  List<Offset> tramo(double desde, double hasta) {
    final r = <Offset>[en(desde)];
    for (var i = 0; i < puntos.length; i++) {
      if (acum[i] > desde && acum[i] < hasta) r.add(puntos[i]);
    }
    r.add(en(hasta));
    return r;
  }
}

/// Lo último que pasó por una pieza.
class _Lectura {
  String llamada = '';
  String? resultado;
  Color color = _textoSuave;
  double momento = -10;
  int cuenta = 0;
}

/// Una línea de la consola.
class _Linea {
  final DateTime momento;
  final Traza traza;
  final Color color;
  int veces = 1;
  _Linea(this.momento, this.traza, this.color);
}

class _Vivo extends ChangeNotifier {
  final List<_Pulso> pulsos = [];
  final Map<Pieza, _Lectura> lecturas = {
    for (final p in Pieza.values) p: _Lectura(),
  };

  /// Lo último que cruzó la App API en cada sentido.
  final accion = _Lectura();
  final estado = _Lectura();

  /// Cuándo entró o salió algo por cada pata (se enciende un instante).
  final Map<Rect, (double, Color)> patas = {};

  /// Cuándo pasó algo por cada pista (para que quede encendida un instante).
  final Map<List<Offset>, (double, Color)> encendidas = Map.identity();
  final ValueNotifier<List<_Linea>> consola = ValueNotifier(const []);
  double ahora = 0;

  void tic(double t) {
    ahora = t;
    pulsos.removeWhere((p) => t - p.inicio > p.duracion + 0.4);
    // La pata se enciende cuando la cabeza del pulso pasa por ella.
    for (final pu in pulsos) {
      final s = pu.cabeza(t);
      while (pu.cruzadas < pu.patas.length &&
          pu.patas[pu.cruzadas].$1 <= s + 0.5) {
        patas[pu.patas[pu.cruzadas].$2] = (t, pu.color);
        pu.cruzadas++;
      }
    }
    patas.removeWhere((_, v) => t - v.$1 > 1);
    notifyListeners();
  }

  void llamada(Traza t, _Plano? plano) {
    final color = _colorDe(t);
    final recorrido = plano?.recorrido(t);
    if (recorrido != null && pulsos.length < 70) {
      // Muchas lecturas seguidas por la misma pista: un pulso cada tanto
      // alcanza para verla viva (no un tren continuo).
      final ultimo = encendidas[recorrido];
      if (ultimo == null || ahora - ultimo.$1 > 0.09) {
        pulsos.add(_Pulso(recorrido, color, ahora, plano!.patas));
      }
      encendidas[recorrido] = (ahora, color);
    }
    // Lo que recibió (o devolvió) cada extremo. Lo que cruza el contrato
    // (acciones y estado) queda en la lectura de la interfaz.
    for (final p in [t.desde, t.hacia]) {
      lecturas[p]!
        ..llamada = t.llamada
        ..resultado = t.resultado
        ..color = color
        ..momento = ahora
        ..cuenta += 1;
    }
    if (t.desde == Pieza.interfaz || t.hacia == Pieza.interfaz) {
      (t.desde == Pieza.interfaz ? accion : estado)
        ..llamada = t.llamada
        ..resultado = t.resultado
        ..color = color
        ..momento = ahora
        ..cuenta += 1;
    }
    final lineas = consola.value;
    final ult = lineas.isEmpty ? null : lineas.first;
    if (ult != null &&
        ult.traza.desde == t.desde &&
        ult.traza.hacia == t.hacia &&
        _sinArgumentos(ult.traza.llamada) == _sinArgumentos(t.llamada)) {
      ult.veces++;
      consola.value = [
        _Linea(t.momento, t, color)..veces = ult.veces,
        ...lineas.skip(1),
      ];
    } else {
      consola.value = [_Linea(t.momento, t, color), ...lineas.take(13)];
    }
  }

  static String _sinArgumentos(String s) {
    final i = s.indexOf('(');
    return i < 0 ? s : s.substring(0, i);
  }

  @override
  void dispose() {
    consola.dispose();
    super.dispose();
  }
}

// --- Widget ----------------------------------------------------------------------

const _margenIzquierdo = 56.0;
const _columnaMinima = 340.0;
const _huecoMinimo = 32.0;

/// Dónde va el teléfono de [tel] en una ventana [tam]: después del relato,
/// centrado en alto. La columna del relato y el hueco hasta el teléfono crecen
/// con la ventana, pero ceden primero para que la placa entre entera.
Rect telefonoPorDentro(Size tam, Size tel) => _ubicar(tam, tel).telefono;

({Rect telefono, double columna}) _ubicar(Size tam, Size tel) {
  var columna = (tam.width * 0.22).clamp(_columnaMinima, 420.0);
  var hueco = (tam.width * 0.03).clamp(_huecoMinimo, 64.0);
  final exceso =
      _margenIzquierdo +
      columna +
      hueco +
      tel.width +
      _Plano.anchoMinimo -
      tam.width;
  if (exceso > 0) {
    final deHueco = math.min(exceso, hueco - _huecoMinimo);
    hueco -= deHueco;
    columna = math.max(_columnaMinima, columna - (exceso - deHueco));
  }
  return (
    telefono: Rect.fromLTWH(
      _margenIzquierdo + columna + hueco,
      (tam.height - tel.height) / 2,
      tel.width,
      tel.height,
    ),
    columna: columna,
  );
}

/// Las cajas de la placa (los chips y el contrato) para una ventana [tam] con
/// el teléfono en [telefono]. Para comprobar que no se pisan.
@visibleForTesting
Map<String, Rect> cajasDeLaPlaca(Size tam, Rect telefono) {
  final p = _Plano(tam, telefono);
  return {
    for (final e in p.chips.entries) e.key.name: e.value.rect,
    'contrato': p.contrato,
  };
}

/// Ancho de ventana que necesita la vista "por dentro" con un teléfono de
/// [anchoTelefono]: el relato, el teléfono y la placa enteros.
double anchoMinimoPorDentro(double anchoTelefono) =>
    _margenIzquierdo +
    _columnaMinima +
    _huecoMinimo +
    anchoTelefono +
    _Plano.anchoMinimo;

class PorDentro extends ConsumerStatefulWidget {
  /// El teléfono con la app, ya escalado.
  final Widget telefono;
  final Size tamTelefono;

  /// Encabezado (marca y selector de vista).
  final Widget encabezado;

  const PorDentro({
    super.key,
    required this.telefono,
    required this.tamTelefono,
    required this.encabezado,
  });

  @override
  ConsumerState<PorDentro> createState() => _PorDentroState();
}

class _PorDentroState extends ConsumerState<PorDentro>
    with SingleTickerProviderStateMixin {
  final _vivo = _Vivo();
  late final Ticker _reloj;
  StreamSubscription<Traza>? _trazas;
  _Plano? _plano;
  ui.Image? _fijo;
  (Size, double)? _claveFijo;
  double _ultimoEstado = -10;

  /// La pieza bajo el mouse (su tarjeta se muestra al lado).
  Pieza? _sobre;
  String? _resumenEstado;

  @override
  void initState() {
    super.initState();
    _reloj = createTicker((d) => _vivo.tic(d.inMicroseconds / 1e6))..start();
    _trazas = ref
        .read(trazasProvider)
        ?.stream
        .listen((t) => _vivo.llamada(t, _plano));
  }

  @override
  void dispose() {
    _trazas?.cancel();
    _reloj.dispose();
    _vivo.dispose();
    _fijo?.dispose();
    super.dispose();
  }

  /// El estado que la lógica publica, como una llamada hacia la interfaz
  /// (lo que cambió de verdad, a lo sumo unas veces por segundo).
  void _alPublicar(AppState s) {
    final r = _resumen(s);
    final ahora = _vivo.ahora;
    if (r == _resumenEstado && ahora - _ultimoEstado < 0.4) return;
    if (ahora - _ultimoEstado < 0.12) return;
    _resumenEstado = r;
    _ultimoEstado = ahora;
    _vivo.llamada(
      Traza(
        Pieza.controlador,
        Pieza.interfaz,
        'AppState',
        resultado: r,
        momento: DateTime.now(),
      ),
      _plano,
    );
  }

  static String _resumen(AppState s) => switch (s.fase) {
    FaseExplorar() => 'explorar',
    final FaseOpciones f =>
      f.estado == EstadoOpciones.listo
          ? 'opciones (${f.opciones.length})'
          : 'opciones, ${f.estado.name}',
    final FaseViaje f =>
      f.estado == EstadoViaje.completado
          ? 'viaje, llegó'
          : 'viaje, paso ${f.pasoActual + 1} de ${f.totalPasos}'
              '${f.progreso.metrosRestantes == null ? '' : ', ${f.progreso.metrosRestantes} m'}',
  };

  /// Lo fijo, rasterizado una vez: cada cuadro solo copia la imagen (una
  /// Picture volvería a ejecutar sus sombras y su grilla cada vez).
  ui.Image _grabarFijo(_Plano p, double densidad) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(densidad);
    _pintarFijo(c, p);
    final dibujo = rec.endRecording();
    final imagen = dibujo.toImageSync(
      (p.tam.width * densidad).ceil(),
      (p.tam.height * densidad).ceil(),
    );
    dibujo.dispose();
    return imagen;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppState>(appStateProvider, (_, s) => _alPublicar(s));
    return LayoutBuilder(
      builder: (context, box) {
        final tam = box.biggest;
        final (:telefono, :columna) = _ubicar(tam, widget.tamTelefono);
        if (_plano?.tam != tam || _plano?.telefono != telefono) {
          _plano = _Plano(tam, telefono);
        }
        final plano = _plano!;
        final densidad = MediaQuery.devicePixelRatioOf(context);
        if (_claveFijo != (tam, densidad)) {
          _fijo?.dispose();
          _fijo = _grabarFijo(plano, densidad);
          _claveFijo = (tam, densidad);
        }
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(
                child: MouseRegion(
                  cursor:
                      _sobre == null
                          ? MouseCursor.defer
                          : SystemMouseCursors.click,
                  onHover: (e) {
                    final p = plano.piezaEn(e.localPosition);
                    if (p != _sobre) setState(() => _sobre = p);
                  },
                  onExit: (_) {
                    if (_sobre != null) setState(() => _sobre = null);
                  },
                  child: GestureDetector(
                    onTapUp: (e) {
                      final p = plano.piezaEn(e.localPosition);
                      if (p != null) abrirEnlace(_enlacePieza(p));
                    },
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _PintorPlaca(plano, _fijo!, _vivo),
                      ),
                    ),
                  ),
                ),
              ),
              // El relato fluye de arriba abajo; la consola ocupa lo que
              // queda (y no aparece si no entra): nada se pisa.
              Positioned(
                left: _margenIzquierdo,
                top: 36,
                bottom: 36,
                width: columna,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    widget.encabezado,
                    const SizedBox(height: 28),
                    const _Relato(),
                    const SizedBox(height: 20),
                    Expanded(
                      child: LayoutBuilder(
                        builder:
                            (context, b) =>
                                b.maxHeight < 120
                                    ? const SizedBox.shrink()
                                    // Alta como sus renglones, no más.
                                    : Align(
                                      alignment: Alignment.topLeft,
                                      child: SizedBox(
                                        height: math.min(b.maxHeight, 340),
                                        child: _Consola(_vivo.consola),
                                      ),
                                    ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned.fromRect(rect: telefono, child: widget.telefono),
              if (_sobre case final p?)
                _Tarjeta.junto(p, plano.nombreDe(p), plano.cajas[p]!, plano),
            ],
          ),
        );
      },
    );
  }
}

// --- Texto -------------------------------------------------------------------------

/// La tarjeta de una pieza: qué hace y dónde está su código.
class _Tarjeta extends StatelessWidget {
  final Pieza pieza;
  final String nombre;
  const _Tarjeta(this.pieza, this.nombre);

  static const ancho = 300.0;
  static const altoEstimado = 190.0;

  /// La tarjeta debajo de la caja (o arriba, si abajo no entra), sin tapar
  /// el teléfono.
  static Widget junto(Pieza p, String nombre, Rect caja, _Plano plano) {
    final abajo = caja.bottom + 12 + altoEstimado < plano.tam.height;
    final double izq = caja.left.clamp(
      plano.telefono.right + 16,
      math.max(plano.telefono.right + 16, plano.tam.width - ancho - 16),
    );
    return Positioned(
      left: izq,
      top: abajo ? caja.bottom + 12 : null,
      bottom: abajo ? null : plano.tam.height - caja.top + 12,
      width: ancho,
      child: IgnorePointer(child: _Tarjeta(p, nombre)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorPieza(pieza);
    return DecoratedBox(
      key: const ValueKey('tarjeta-pieza'),
      decoration: BoxDecoration(
        color: const Color(0xF50F1318),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2E3744)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(_iconoPieza(pieza), size: 17, color: color),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    nombre,
                    style: _estilo(15, _texto, peso: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _archivoPieza(pieza),
              style: _estilo(12, color.withValues(alpha: 0.85)),
            ),
            const SizedBox(height: 10),
            Text(
              tx.coreDetalle(pieza),
              style: _estilo(13, _textoSuave).copyWith(height: 1.45),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.open_in_new, size: 13, color: _textoTenue),
                const SizedBox(width: 6),
                Text(
                  tx.coreVerCodigo,
                  style: _estilo(12, _textoTenue, peso: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Relato extends StatelessWidget {
  const _Relato();

  @override
  Widget build(BuildContext context) {
    Widget clave(Color c, String s) => Padding(
      padding: const EdgeInsets.only(right: 16, bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: c.withValues(alpha: 0.7), blurRadius: 8),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(s, style: _estilo(13, _textoSuave)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tx.coreTitulo,
          style: _estilo(
            40,
            _texto,
            peso: FontWeight.w800,
          ).copyWith(letterSpacing: -1.2, height: 1.05),
        ),
        const SizedBox(height: 16),
        Text(
          tx.coreBajada,
          style: _estilo(16, _textoSuave).copyWith(height: 1.55),
        ),
        const SizedBox(height: 18),
        Wrap(
          children: [
            clave(_accion, tx.coreClaveAcciones),
            clave(_estado, tx.coreClaveEstado),
            clave(_ubicacion, tx.coreClaveUbicacion),
            clave(_bus, tx.coreClaveBuses),
            clave(_plan, tx.coreClavePlan),
          ],
        ),
        const SizedBox(height: 6),
        Text(tx.coreNotaDemo, style: _estilo(12.5, _textoTenue)),
      ],
    );
  }
}

class _Consola extends StatelessWidget {
  final ValueNotifier<List<_Linea>> lineas;
  const _Consola(this.lineas);

  static String _hora(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}.'
      '${(t.millisecond ~/ 100)}';

  static String _nombre(Pieza p) => switch (p) {
    Pieza.interfaz => 'UI',
    Pieza.controlador => 'AppController',
    Pieza.navegador => 'Navegador',
    Pieza.seguidor => 'SeguidorBus',
    Pieza.recomendador => 'Recomendador',
    Pieza.planificador => 'OTP',
    Pieza.llegadas => 'API IM',
    Pieza.ubicacion => 'GPS',
    Pieza.catalogo => 'GTFS',
    Pieza.lugares => 'Lugares',
  };

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE6161B22), Color(0xE60D1015)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF262E39)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 40,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _Latido(),
                const SizedBox(width: 10),
                Text(
                  tx.coreConsola,
                  style: _estilo(
                    11.5,
                    _textoSuave,
                    peso: FontWeight.w700,
                  ).copyWith(letterSpacing: 1.4),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ClipRect(
                child: ValueListenableBuilder<List<_Linea>>(
                  valueListenable: lineas,
                  builder:
                      (context, ls, _) => ListView(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        children: [
                          for (var i = 0; i < ls.length; i++)
                            Opacity(
                              opacity: (1 - i * 0.07).clamp(0.25, 1.0),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${_hora(ls[i].momento)}  ',
                                        style: _estilo(12, _textoTenue),
                                      ),
                                      TextSpan(
                                        text:
                                            '${_nombre(ls[i].traza.desde)} › ${_nombre(ls[i].traza.hacia)}  ',
                                        style: _estilo(12, _textoSuave),
                                      ),
                                      TextSpan(
                                        text: ls[i].traza.llamada,
                                        style: _estilo(
                                          12,
                                          ls[i].color,
                                          peso: FontWeight.w600,
                                        ),
                                      ),
                                      if (ls[i].traza.resultado != null)
                                        TextSpan(
                                          text: '  ${ls[i].traza.resultado}',
                                          style: _estilo(12, _textoTenue),
                                        ),
                                      if (ls[i].veces > 1)
                                        TextSpan(
                                          text: '  ×${ls[i].veces}',
                                          style: _estilo(
                                            12,
                                            _textoSuave,
                                            peso: FontWeight.w700,
                                          ),
                                        ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        ],
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un punto verde que late: "en vivo".
class _Latido extends StatefulWidget {
  const _Latido();

  @override
  State<_Latido> createState() => _LatidoState();
}

class _LatidoState extends State<_Latido> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder:
        (context, _) => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _estado,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _estado.withValues(alpha: 0.8 * (1 - _a.value)),
                blurRadius: 2 + 10 * _a.value,
                spreadRadius: 6 * _a.value,
              ),
            ],
          ),
        ),
  );
}

// --- Pintura -----------------------------------------------------------------------

/// Lo fijo: fondo, grilla, pistas decorativas, las pistas de la red y los
/// cuerpos de los chips.
void _pintarFijo(Canvas c, _Plano p) {
  final r = Offset.zero & p.tam;
  c.drawRect(
    r,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset(p.tam.width * 0.6, p.tam.height * 0.5),
        p.tam.longestSide * 0.75,
        const [_fondoCentro, _fondoBorde],
      ),
  );
  // Grilla de puntos.
  final punto = Paint()..color = const Color(0x0FFFFFFF);
  for (var x = 12.0; x < p.tam.width; x += 24) {
    for (var y = 12.0; y < p.tam.height; y += 24) {
      c.drawRect(Rect.fromLTWH(x, y, 1.2, 1.2), punto);
    }
  }
  // Pistas de fondo: la placa sigue más allá de lo que se usa.
  final azar = math.Random(7);
  final tenue =
      Paint()
        ..color = const Color(0x0DFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
  final via = Paint()..color = const Color(0x14FFFFFF);
  final ocupado = [
    p.telefono.inflate(30),
    p.contrato.inflate(20),
    for (final ch in p.chips.values) ch.rect.inflate(24),
  ];
  for (var i = 0; i < 70; i++) {
    final a = Offset(
      azar.nextDouble() * p.tam.width,
      azar.nextDouble() * p.tam.height,
    );
    final largo = 80 + azar.nextDouble() * 260;
    final horizontal = azar.nextBool();
    final b =
        horizontal
            ? Offset(
              a.dx + (azar.nextBool() ? largo : -largo),
              a.dy + (azar.nextDouble() - 0.5) * 120,
            )
            : Offset(
              a.dx + (azar.nextDouble() - 0.5) * 120,
              a.dy + (azar.nextBool() ? largo : -largo),
            );
    final pts =
        horizontal
            ? _ruta(a, b, quiebre: (a.dx + b.dx) / 2)
            : _rutaVertical(a, b);
    if (ocupado.any((o) => pts.any(o.contains))) continue;
    c.drawPath(Path()..addPolygon(pts, false), tenue);
    c.drawCircle(a, 2.6, via);
    c.drawCircle(b, 2.6, via);
  }

  // La red: pistas de cobre apagadas.
  void pista(List<Offset> pts) {
    final path = Path()..addPolygon(pts, false);
    c.drawPath(
      path,
      Paint()
        ..color = _pista
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    c.drawPath(
      path,
      Paint()
        ..color = _pistaLuz
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round,
    );
    for (final v in [pts.first, pts.last]) {
      if (p.patas.containsKey(v)) continue;
      c.drawCircle(v, 4.5, Paint()..color = _pista);
      c.drawCircle(v, 2, Paint()..color = _fondoBorde);
    }
  }

  for (final pts in p.pistas.values) {
    pista(pts);
  }
  pista(p.acciones);
  pista(p.estado);

  // El conector donde se enchufa el teléfono.
  final con = p.conector;
  c.drawRRect(
    RRect.fromRectAndRadius(con, const Radius.circular(5)),
    Paint()
      ..shader = ui.Gradient.linear(con.topLeft, con.topRight, const [
        Color(0xFF2A313C),
        Color(0xFF181C23),
      ]),
  );
  for (var i = 0; i < 9; i++) {
    c.drawRect(
      Rect.fromLTWH(con.right - 9, con.top + 12 + i * 12.5, 6, 4),
      Paint()..color = _pin.withValues(alpha: 0.85),
    );
  }

  // Cuerpos de los chips, el contrato incluido.
  bool libre(Offset o) =>
      !p.patas.values.any((q) => (q.center - o).distance < 8);
  void cuerpo(Rect rect, {required bool puerto, Color? acento}) {
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    c.drawRRect(
      rr.shift(const Offset(0, 14)),
      Paint()
        ..color = const Color(0x80000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    // Patas.
    final pata = Paint()..color = _pin.withValues(alpha: puerto ? 0.5 : 0.75);
    final n = (rect.height / 16).floor();
    for (var i = 0; i < n; i++) {
      final y = rect.top + 12 + i * (rect.height - 24) / math.max(1, n - 1);
      if (libre(Offset(rect.left - 3, y))) {
        c.drawRect(Rect.fromLTWH(rect.left - 5, y - 1.5, 5, 3), pata);
      }
      if (!puerto && libre(Offset(rect.right + 3, y))) {
        c.drawRect(Rect.fromLTWH(rect.right, y - 1.5, 5, 3), pata);
      }
    }
    c.drawRRect(
      rr,
      Paint()
        ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, const [
          _chipArriba,
          _chip,
        ]),
    );
    c.drawRRect(
      rr.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          const [Color(0xFF3D4757), _chipFilo, Color(0xFF14181E)],
          const [0, 0.25, 1],
        ),
    );
    // Los puertos (el mundo de afuera) llevan una franja de su dominio.
    if (acento != null) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left + 8, rect.top + 14, 3, rect.height - 28),
          const Radius.circular(1.5),
        ),
        Paint()..color = acento.withValues(alpha: 0.55),
      );
    }
  }

  cuerpo(p.contrato, puerto: false);
  for (final ch in p.chips.values) {
    cuerpo(
      ch.rect,
      puerto: ch.puerto,
      acento: ch.puerto ? _colorPieza(ch.pieza) : null,
    );
  }
  // Las patas por donde entran las pistas.
  for (final q in p.patas.values) {
    c.drawRect(q, Paint()..color = _pin.withValues(alpha: 0.9));
  }
}

class _PintorPlaca extends CustomPainter {
  final _Plano p;
  final ui.Image fijo;
  final _Vivo vivo;
  _PintorPlaca(this.p, this.fijo, this.vivo) : super(repaint: vivo);

  static final Map<String, TextPainter> _textos = {};

  /// Texto cacheado por contenido y estilo.
  TextPainter _t(String s, TextStyle e, {double? ancho, int lineas = 1}) {
    final k =
        '$s|${e.fontSize}|${e.color?.toARGB32()}|${e.fontWeight}|$ancho|$lineas';
    if (_textos.length > 400) _textos.clear();
    return _textos[k] ??= (TextPainter(
      text: TextSpan(text: s, style: e),
      textDirection: TextDirection.ltr,
      maxLines: lineas,
      ellipsis: '…',
    )..layout(maxWidth: ancho ?? double.infinity));
  }

  @override
  void paint(Canvas c, Size size) {
    c.drawImageRect(
      fijo,
      Rect.fromLTWH(0, 0, fijo.width.toDouble(), fijo.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final ahora = vivo.ahora;

    c.save();
    // Pistas que llevaron algo hace poco: quedan encendidas y se apagan.
    for (final e in vivo.encendidas.entries) {
      final k = (1 - (ahora - e.value.$1) / 1.2).clamp(0.0, 1.0);
      if (k <= 0) continue;
      final path = Path()..addPolygon(e.key, false);
      // Halo: un trazo ancho y tenue (sin desenfoque: barato en cualquier
      // máquina).
      c.drawPath(
        path,
        Paint()
          ..color = e.value.$2.withValues(alpha: 0.09 * k)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
      c.drawPath(
        path,
        Paint()
          ..color = e.value.$2.withValues(alpha: 0.55 * k)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Pulsos: una cabeza brillante con su estela, por la pista.
    for (final pu in vivo.pulsos) {
      final f = ((ahora - pu.inicio) / pu.duracion).clamp(0.0, 1.0);
      final s = pu.cabeza(ahora);
      final cola = math.max(0.0, s - 90);
      final desvanecer =
          f >= 1
              ? (1 - (ahora - pu.inicio - pu.duracion) / 0.4).clamp(0.0, 1.0)
              : 1.0;
      if (s - cola > 1) {
        final tramo = pu.tramo(cola, s);
        final path = Path()..addPolygon(tramo, false);
        c.drawPath(
          path,
          Paint()
            ..shader = ui.Gradient.linear(tramo.first, tramo.last, [
              pu.color.withValues(alpha: 0),
              pu.color.withValues(alpha: 0.9 * desvanecer),
            ])
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
      final cabeza = pu.en(s);
      _brillo(c, cabeza, 13, pu.color, 0.55 * desvanecer);
      c.drawCircle(
        cabeza,
        2.8,
        Paint()
          ..color = Color.lerp(
            pu.color,
            Colors.white,
            0.6,
          )!.withValues(alpha: desvanecer),
      );
    }

    c.restore();

    // Los cuerpos de los chips, otra vez encima de lo vivo: las pistas y los
    // pulsos quedan debajo. Se copian de la capa fija (un recorte con un
    // camino combinado no se respetaba en la web).
    final escala = fijo.width / size.width;
    for (final rr in p.cuerpos) {
      c.save();
      c.clipRRect(rr);
      final r = rr.outerRect;
      c.drawImageRect(
        fijo,
        Rect.fromLTRB(
          r.left * escala,
          r.top * escala,
          r.right * escala,
          r.bottom * escala,
        ),
        r,
        Paint()..filterQuality = FilterQuality.medium,
      );
      c.restore();
    }

    // Las patas encendidas: por ahí entró (o salió) algo recién.
    for (final e in vivo.patas.entries) {
      final k = (1 - (ahora - e.value.$1) / 0.9).clamp(0.0, 1.0);
      if (k <= 0) continue;
      _brillo(c, e.key.center, 11, e.value.$2, 0.6 * k);
      c.drawRect(
        e.key,
        Paint()
          ..color =
              Color.lerp(_pin, Color.lerp(e.value.$2, Colors.white, 0.3), k)!,
      );
    }

    _api(c, p.contrato, ahora);
    for (final ch in p.chips.values) {
      _rotulos(c, ch, vivo.lecturas[ch.pieza]!, ahora);
    }
  }

  /// La luz de actividad y la cuenta de llamadas, arriba a la derecha.
  void _luz(Canvas c, Rect r, _Lectura l, int cuenta, double ahora) {
    final activo = (1 - (ahora - l.momento) / 0.9).clamp(0.0, 1.0);
    final luz = r.topRight + const Offset(-16, 16);
    if (activo > 0) _brillo(c, luz, 14, l.color, 0.6 * activo);
    c.drawCircle(
      luz,
      3.2,
      Paint()..color = Color.lerp(const Color(0xFF2A313B), l.color, activo)!,
    );
    if (cuenta == 0) return;
    final t = _t('$cuenta', _estilo(10.5, _textoTenue, peso: FontWeight.w600));
    t.paint(c, Offset(r.right - 26 - t.width, r.top + 10));
  }

  /// El ícono de la pieza: más vivo mientras algo pasa por ella.
  void _icono(Canvas c, Pieza p, Offset o, double activo) {
    final i = _iconoPieza(p);
    _t(
      String.fromCharCode(i.codePoint),
      TextStyle(
        fontFamily: i.fontFamily,
        package: i.fontPackage,
        fontSize: 15,
        height: 1,
        color: _colorPieza(p).withValues(alpha: 0.6 + 0.4 * activo),
      ),
    ).paint(c, o);
  }

  /// La App API por dentro: arriba el carril de las acciones (entran desde
  /// la UI), abajo el del estado (sale hacia la UI), a la altura de sus
  /// pistas.
  void _api(Canvas c, Rect r, double ahora) {
    final a = vivo.accion, e = vivo.estado;
    final ultima = a.momento >= e.momento ? a : e;
    _luz(c, r, ultima, a.cuenta + e.cuenta, ahora);
    final activo = (1 - (ahora - ultima.momento) / 0.9).clamp(0.0, 1.0);
    _icono(c, Pieza.interfaz, Offset(r.left + 14, r.top + 18.5), activo);
    final x = r.left + 36;
    _t(
      'App API',
      _estilo(16, _texto, peso: FontWeight.w700),
      ancho: r.right - x - 30,
    ).paint(c, Offset(x, r.top + 16));
    final cy = r.center.dy;
    c.drawLine(
      Offset(r.left + 12, cy + 7),
      Offset(r.right - 12, cy + 7),
      Paint()
        ..color = const Color(0x14FFFFFF)
        ..strokeWidth = 1,
    );
    void carril(_Lectura l, String nombre, double y, Color color, bool entra) {
      final k = (1 - (ahora - l.momento) / 0.9).clamp(0.0, 1.0);
      // Una flecha en el sentido del carril.
      final m = Offset(r.left + 20, y);
      final s = entra ? 1.0 : -1.0;
      c.drawPath(
        Path()
          ..moveTo(m.dx - 3.5 * s, m.dy - 4.5)
          ..lineTo(m.dx + 3.5 * s, m.dy)
          ..lineTo(m.dx - 3.5 * s, m.dy + 4.5)
          ..close(),
        Paint()..color = Color.lerp(_textoTenue, color, 0.35 + 0.65 * k)!,
      );
      // El nombre a la altura de la pista; debajo, lo último que pasó (del
      // estado, su resumen: que es un AppState ya lo dice el carril).
      final ancho = r.right - x - 10;
      _t(
        nombre,
        _estilo(11.5, _textoTenue),
        ancho: ancho,
      ).paint(c, Offset(x, y - 7.5));
      if (l.cuenta == 0) return;
      _t(
        entra ? l.llamada : (l.resultado ?? l.llamada),
        _estilo(11.5, l.color, peso: FontWeight.w600),
        ancho: ancho,
      ).paint(c, Offset(x, y + 8));
    }

    carril(a, 'AppActions', cy - 22, _accion, true);
    carril(e, 'AppState', cy + 22, _estado, false);
  }

  void _rotulos(Canvas c, _Chip ch, _Lectura l, double ahora) {
    final r = ch.rect;
    final puerto = ch.puerto;
    _luz(c, r, l, l.cuenta, ahora);
    final activo = (1 - (ahora - l.momento) / 0.9).clamp(0.0, 1.0);
    final x = r.left + (puerto ? 38 : 36);
    final ancho = r.right - x - 30;
    var y = r.top + (puerto ? 14 : 16);
    final tNombre = _t(
      ch.nombre,
      _estilo(puerto ? 15 : 16, _texto, peso: FontWeight.w700),
      ancho: ancho,
    );
    _icono(
      c,
      ch.pieza,
      Offset(r.left + (puerto ? 17 : 14), y + (tNombre.height - 15) / 2),
      activo,
    );
    tNombre.paint(c, Offset(x, y));
    y += tNombre.height + 3;
    // El papel, en dos renglones si hace falta (no se corta).
    final tPapel = _t(
      ch.papel,
      _estilo(11.5, _textoTenue),
      ancho: r.right - x - 14,
      lineas: puerto ? 1 : 2,
    );
    tPapel.paint(c, Offset(x, y));
    y += tPapel.height + 8;
    if (l.cuenta == 0 || y + 14 > r.bottom) return;
    final tLlamada = _t(
      l.llamada,
      _estilo(11.5, l.color, peso: FontWeight.w600),
      ancho: r.right - x - 14,
    );
    tLlamada.paint(c, Offset(x, y));
    y += tLlamada.height + 2;
    final res = l.resultado;
    if (res != null && y + 12 < r.bottom) {
      _t(
        '= $res',
        _estilo(11, _textoSuave),
        ancho: r.right - x - 14,
      ).paint(c, Offset(x, y));
    }
  }

  /// Un resplandor redondo: degradé radial, sin desenfoque.
  static void _brillo(Canvas c, Offset o, double r, Color color, double a) {
    if (a <= 0) return;
    c.drawCircle(
      o,
      r,
      Paint()
        ..shader = ui.Gradient.radial(o, r, [
          color.withValues(alpha: a),
          color.withValues(alpha: 0),
        ]),
    );
  }

  @override
  bool shouldRepaint(_PintorPlaca old) =>
      old.p != p || old.fijo != fijo || old.vivo != vivo;
}
