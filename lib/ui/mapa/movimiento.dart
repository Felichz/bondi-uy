// Movimiento continuo a partir de lecturas sueltas.
//
// El GPS (y la API de buses) entregan posiciones puntuales cada pocos
// segundos. Mostrarlas tal cual hace que el marcador y el mapa salten; solo
// interpolar entre la anterior y la nueva hace que avance y frene. Como las
// apps de viajes, acá se estima la velocidad y el marcador sigue avanzando
// entre lecturas, POR EL CAMINO cuando se conoce (la calle que caminás, el
// recorrido del bus), así dobla en las esquinas. Cada lectura nueva corrige
// el plan sin saltos: el marcador apura o afloja para alcanzar la posición
// que predice la lectura, sin pasar de unas tres veces su velocidad (una
// corrección grande se reparte en más tiempo, no se hace de un tirón).
//
// Todo en coordenadas mercator normalizadas (0..1) y segundos.

import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Metros por unidad de mercator normalizado a la latitud de Montevideo.
final double metrosPorUnidad = 40075016.7 * math.cos(-34.9 * math.pi / 180);

class MovimientoPredicho {
  Offset _pos;
  double? _rumbo;

  // Última lectura.
  Offset _fijo;
  double _tFijo;

  /// Tiempo típico entre lecturas (promedio móvil), s.
  double _intervalo = 1;
  int _lecturas = 0;

  /// Rapidez estimada (unidades/s) y, sin camino, velocidad 2D.
  double _rapidez = 0;
  Offset _velocidad = Offset.zero;

  _Camino? _camino;
  Object? _fuenteCamino;

  // Plan vigente: de (s0 | p0) a (s1 | p1) entre t0 y t1.
  double _t0 = 0, _t1 = 0;
  double _s0 = 0;
  Offset _p0 = Offset.zero;
  bool _porCamino = false;

  /// Diferencia entre lo que se mostraba y el camino al empezar el plan: se
  /// absorbe en medio segundo (así cambiar de camino no produce saltos).
  Offset _desvio = Offset.zero;

  /// Punto que la predicción no puede pasar (la parada a la que viene el
  /// bus). Solo una lectura real más allá lo lleva del otro lado.
  Offset? _limite;

  /// Constante de tiempo (s) con que se absorbe la diferencia entre lo que
  /// se mostraba y la lectura nueva.
  double _tau = 0.5;

  /// Constante de tiempo para absorber [error] (mercator): medio segundo, o
  /// más si así la corrección superaría el doble de la rapidez (+3 m/s). Con
  /// una sola muestra de velocidad (recién apareció) la estimación es floja:
  /// la corrección no pasa de la rapidez.
  double _tauPara(double error) {
    // Quieto, va a la lectura enseguida: no hay movimiento que acompañar.
    if (_quieto) return 0.4;
    final margen = _rapidez * (_lecturas <= 1 ? 1 : 2) + 3 / metrosPorUnidad;
    return (error / margen).clamp(0.5, 4.0);
  }

  MovimientoPredicho(Offset inicio, double t)
    : _pos = inicio,
      _fijo = inicio,
      _tFijo = t;

  /// Posición a mostrar (mercator).
  Offset get posicion => _pos;

  /// Hacia dónde se mueve (grados, 0 = norte), si se sabe.
  double? get rumbo => _rumbo;

  /// La última lectura recibida.
  Offset get fijo => _fijo;

  /// true mientras el plan no terminó (hay que seguir dibujando cuadros).
  bool enMovimientoA(double t) => t < _t1;

  /// Una lectura nueva en [p] al tiempo [t]. [camino] (polilínea mercator,
  /// en sentido de marcha) restringe el movimiento a esa geometría. Con
  /// [reubicado] (salto grande: otro bus, el GPS que se reubica) se muestra
  /// directo, sin predecir.
  void lectura(
    Offset p,
    double t, {
    List<Offset>? camino,
    Object? fuenteCamino,
    Offset? limite,
    bool reubicado = false,
    bool predecir = true,
  }) {
    avanzar(t);
    _limite = limite;
    // Cambió el camino (otro tramo: bajaste, subiste al bus): la velocidad
    // de antes no dice nada de la de ahora.
    var caminoNuevo = false;
    if (camino == null || camino.length < 2) {
      caminoNuevo = _camino != null;
      _camino = null;
      _fuenteCamino = null;
    } else if (!identical(fuenteCamino ?? camino, _fuenteCamino)) {
      caminoNuevo = _camino != null || _fuenteCamino != null;
      _camino = _Camino(camino);
      _fuenteCamino = fuenteCamino ?? camino;
    }
    final dt = t - _tFijo;
    if (reubicado) {
      _pos = p;
      _rapidez = 0;
      _velocidad = Offset.zero;
      _rumbo = null;
      _fijar(p, t);
      _t0 = _t1 = t;
      _p0 = p;
      _errorP = Offset.zero;
      _porCamino = false;
      return;
    }
    if (dt > 0.05) {
      _intervalo = (_lecturas == 0 ? dt : 0.6 * _intervalo + 0.4 * dt).clamp(
        0.2,
        8.0,
      );
      _lecturas++;
      final paso = p - _fijo;
      final metros = paso.distance * metrosPorUnidad;
      // Menos de 1,5 m entre lecturas: quieto (ruido del GPS).
      final muestra = metros < 1.5 ? 0.0 : paso.distance / dt;
      final v = metros < 1.5 ? Offset.zero : paso / dt;
      final primera = _rapidez == 0 || caminoNuevo;
      _rapidez = primera ? muestra : 0.5 * _rapidez + 0.5 * muestra;
      _velocidad = primera ? v : _velocidad * 0.5 + v * 0.5;
      if (metros >= 1.5) _rumbo = _grados(paso);
    }
    if (!predecir) {
      // Quieto: sin velocidad que lo lleve más allá de la lectura.
      _rapidez = 0;
      _velocidad = Offset.zero;
    }
    _quieto = !predecir;
    _fijar(p, t);
    _planear(p, t);
  }

  bool _quieto = false;

  void _fijar(Offset p, double t) {
    _fijo = p;
    _tFijo = t;
  }

  void _planear(Offset p, double t) {
    // El marcador sigue la trayectoria que predice la lectura (desde donde
    // está la lectura, a la velocidad estimada) y el error de donde se lo
    // veía se absorbe de a poco: e^(-t/0,5 s). Continuo, sin frenar ni
    // saltar. La predicción dura dos intervalos: la próxima lectura llega
    // antes y corrige; si no llega (sin señal), se detiene recién entonces.
    final horizonte = math.max(2.0, _intervalo * 2);
    _t0 = t;
    _horizonte = horizonte;
    _t1 = t + horizonte;
    _sLim = null;
    _pLim = null;
    final c = _camino;
    if (c != null) {
      final (sFijo, dFijo) = c.proyectar(p);
      // Con la lectura sobre el camino, el marcador va por el camino aunque
      // se lo viera fuera de él: se lo ubica cerca de la lectura (no en otra
      // vuelta del recorrido) y la diferencia se absorbe de a poco. En línea
      // recta se saldría por la tangente en la primera curva.
      if (dFijo * metrosPorUnidad < 30) {
        final ventana = 400 / metrosPorUnidad;
        final (sPos, _) = c.proyectar(
          _pos,
          desde: sFijo - ventana,
          hasta: sFijo + ventana,
        );
        final lim = _limite;
        if (lim != null) {
          // No pasarse de la parada, salvo que la lectura ya esté más allá.
          final (sLim, dLim) = c.proyectar(lim);
          if (dLim * metrosPorUnidad < 40 && sFijo <= sLim) _sLim = sLim;
        }
        _porCamino = true;
        _s0 = sFijo;
        _errorS = sPos - sFijo;
        _tau = _tauPara(_errorS.abs());
        _t1 = math.max(_t1, t + 3 * _tau);
        // Muy adelantado (otra ruta, un error de GPS): se permite volver.
        _monotono = _errorS * metrosPorUnidad < 40;
        _sMostrado = sPos;
        _desvio = _pos - c.punto(sPos);
        _tauDesvio = _tauPara(_desvio.distance);
        _t1 = math.max(_t1, t + 3 * _tauDesvio);
        return;
      }
    }
    // Sin camino: en línea recta a la velocidad estimada (quieto, si lo
    // está), sin pasarse del límite si viene hacia él.
    _porCamino = false;
    _p0 = p;
    _errorP = _pos - p;
    _tau = _tauPara(_errorP.distance);
    _t1 = math.max(_t1, t + 3 * _tau);
    final lim = _limite;
    final v = _velocidad.distance;
    if (lim != null && v > 0) {
      final dir = _velocidad / v;
      final hastaLim = (lim - p).dx * dir.dx + (lim - p).dy * dir.dy;
      if (hastaLim >= 0) _pLim = p + dir * hastaLim;
    }
    _desvio = Offset.zero;
  }

  // Plan vigente (ver [_planear]).
  double _horizonte = 2;
  double _tauDesvio = 0.5;
  double _errorS = 0;
  double _sMostrado = 0;
  bool _monotono = true;
  double? _sLim;
  Offset _errorP = Offset.zero;
  Offset? _pLim;

  /// Ubica el marcador en el instante [t].
  void avanzar(double t) {
    if (_t1 <= _t0) return;
    final dt = (math.min(t, _t1) - _t0).clamp(0.0, double.infinity);
    // Se predice el avance hasta el horizonte; la corrección sigue hasta
    // absorberse.
    final dtAvance = math.min(dt, _horizonte);
    final queda = math.exp(-dt / _tau);
    final absorber = math.exp(-dt / _tauDesvio);
    final c = _camino;
    if (_porCamino && c != null) {
      var s = _s0 + _rapidez * dtAvance + _errorS * queda;
      final lim = _sLim;
      if (lim != null) s = math.min(s, lim);
      if (_monotono) s = math.max(s, _sMostrado);
      s = s.clamp(0.0, c.largo);
      if (s - _sMostrado > 1e-9) _rumbo = _grados(c.tangente(s));
      _sMostrado = s;
      _pos = c.punto(s) + _desvio * absorber;
    } else {
      final antes = _pos;
      var p = _p0 + _velocidad * dtAvance + _errorP * queda;
      final lim = _pLim;
      final v = _velocidad.distance;
      if (lim != null && v > 0) {
        final dir = _velocidad / v;
        final pasado = (p - lim).dx * dir.dx + (p - lim).dy * dir.dy;
        if (pasado > 0) p -= dir * pasado;
      }
      _pos = p;
      final d = _pos - antes;
      if (d.distance * metrosPorUnidad > 0.05 && _velocidad != Offset.zero) {
        _rumbo = _grados(_velocidad);
      }
    }
  }

  static double _grados(Offset d) =>
      (math.atan2(d.dx, -d.dy) * 180 / math.pi) % 360;
}

/// Polilínea con largo acumulado, para moverse por distancia recorrida.
class _Camino {
  final List<Offset> pts;
  final List<double> acum;

  _Camino(this.pts) : acum = List.filled(pts.length, 0) {
    for (var i = 1; i < pts.length; i++) {
      acum[i] = acum[i - 1] + (pts[i] - pts[i - 1]).distance;
    }
  }

  double get largo => acum.last;

  /// (distancia recorrida hasta el punto más cercano, distancia lateral),
  /// entre [desde] y [hasta] (distancias recorridas) si se indican.
  (double, double) proyectar(Offset p, {double? desde, double? hasta}) {
    var mejorS = 0.0, mejorD = double.infinity;
    for (var i = 1; i < pts.length; i++) {
      if (desde != null && acum[i] < desde) continue;
      if (hasta != null && acum[i - 1] > hasta) break;
      final a = pts[i - 1], b = pts[i];
      final ab = b - a;
      final l2 = ab.dx * ab.dx + ab.dy * ab.dy;
      final u =
          l2 == 0
              ? 0.0
              : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / l2).clamp(
                0.0,
                1.0,
              );
      final q = a + ab * u;
      final d = (p - q).distance;
      if (d < mejorD) {
        mejorD = d;
        mejorS = acum[i - 1] + math.sqrt(l2) * u;
      }
    }
    return (mejorS, mejorD);
  }

  int _tramo(double s) {
    var i = 1;
    while (i < pts.length - 1 && acum[i] < s) {
      i++;
    }
    return i;
  }

  Offset punto(double s) {
    if (s <= 0) return pts.first;
    if (s >= largo) return pts.last;
    final i = _tramo(s);
    final l = acum[i] - acum[i - 1];
    final u = l == 0 ? 0.0 : (s - acum[i - 1]) / l;
    return Offset.lerp(pts[i - 1], pts[i], u)!;
  }

  Offset tangente(double s) {
    final i = _tramo(s.clamp(0, largo));
    return pts[i] - pts[i - 1];
  }
}
