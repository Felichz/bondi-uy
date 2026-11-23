// Los marcadores que se mueven (el usuario, el bus) entre una lectura y la
// siguiente, y cómo se ve la escena en cada cuadro.
//
// La lógica publica lecturas sueltas; el mapa las convierte en movimiento
// continuo (ver movimiento.dart), funde los marcadores que cambian de forma o
// se van, y hace nacer los recorridos donde se ve cada marcador. No depende
// de widgets: el mapa le pasa la escena y la hora de cada cuadro, y los tests
// pueden recorrer un viaje entero cuadro a cuadro.

import 'dart:ui' show Offset;

import 'package:flutter/animation.dart' show Curves;

import '../../contract/modelo.dart';
import 'escena.dart';
import 'movimiento.dart';
import 'proyeccion.dart';

class MovilesEscena {
  /// Duración (s) de los fundidos.
  static const fundido = 0.45;

  /// Marcadores que se mueven: su posición se predice entre lecturas para
  /// que avancen de forma continua.
  final Map<String, MovimientoPredicho> _moviles = {};
  final Map<String, Coordenada> _ultimaLectura = {};

  /// Última marca mostrada de cada móvil y cuándo apareció: al cambiar de
  /// forma (tu punto -> vos en el bus) o al irse (el bus que llegó), la
  /// vieja se desvanece y la nueva aparece, en vez de saltar.
  final Map<String, MarcaMapa> _mostradas = {};
  final Map<String, double> _aparecio = {};
  final List<(MarcaMapa, double)> _salientes = [];

  static String? _clave(MarcaMapa m) => switch (m) {
    MarcaUsuario() || MarcaUsuarioEnBus() => 'usuario',
    MarcaBus() => 'bus',
    _ => null,
  };

  /// Posición predicha (mercator) del móvil [clave] ('usuario' o 'bus').
  Offset? posicion(String clave) => _moviles[clave]?.posicion;

  /// Lee las marcas móviles de [escena] (lecturas nuevas) en [ahora] (s).
  /// Con [fundir], lo que cambia de forma o se va se desvanece.
  void sincronizar(EscenaMapa escena, double ahora, {required bool fundir}) {
    final vistas = <String>{};
    for (final m in escena.marcas) {
      final k = _clave(m);
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
      final caminoM = camino == null ? null : _caminoMercator(camino);
      final otro = _esOtro(k, mov.posicion, p, caminoM);
      if (otro && fundir) {
        // No se lo desliza ni se lo hace saltar: el que se veía se desvanece
        // donde estaba y el nuevo aparece donde está.
        final visto = _mostradas[k];
        if (visto != null) _salientes.add((visto, ahora));
        _aparecio[k] = ahora;
      }
      mov.lectura(
        p,
        ahora,
        camino: caminoM,
        fuenteCamino: camino,
        limite: m is MarcaBus && m.limite != null ? mercator(m.limite!) : null,
        reubicado: otro,
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
  }

  /// true si la lectura [nueva] no es el mismo marcador avanzando desde
  /// [visto] sino otro: un salto grande que no sigue su camino (el GPS que se
  /// reubica, volver a casa), o un bus que aparece detrás por su recorrido
  /// (llegó uno y el que viene es el siguiente: los buses no retroceden).
  static bool _esOtro(
    String clave,
    Offset visto,
    Offset nueva,
    List<Offset>? camino,
  ) {
    final salto = (nueva - visto).distance * metrosPorUnidad;
    if (camino != null && camino.length >= 2) {
      final (sVisto, dVisto) = _sobre(camino, visto);
      final (sNueva, dNueva) = _sobre(camino, nueva);
      if (dVisto < 30 && dNueva < 30) {
        // Por el mismo camino: adelante es el mismo que avanza.
        return clave == 'bus' && sNueva < sVisto - 30;
      }
    }
    return salto > 400;
  }

  /// (metros recorridos, metros de distancia) de [p] sobre [camino].
  static (double, double) _sobre(List<Offset> camino, Offset p) {
    var acum = 0.0, mejorS = 0.0, mejorD = double.infinity;
    for (var i = 1; i < camino.length; i++) {
      final a = camino[i - 1], ab = camino[i] - a;
      final l2 = ab.dx * ab.dx + ab.dy * ab.dy;
      final u =
          l2 == 0
              ? 0.0
              : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / l2).clamp(
                0.0,
                1.0,
              );
      final d = (p - (a + ab * u)).distance;
      final largo = ab.distance;
      if (d < mejorD) {
        mejorD = d;
        mejorS = acum + largo * u;
      }
      acum += largo;
    }
    return (mejorS * metrosPorUnidad, mejorD * metrosPorUnidad);
  }

  final _caminos = Expando<List<Offset>>();
  List<Offset> _caminoMercator(List<Coordenada> c) =>
      _caminos[c] ??= [for (final p in c) mercator(p)];

  /// true mientras algo se mueve o se funde en [ahora].
  bool animando(double ahora) =>
      _moviles.values.any((m) => m.enMovimientoA(ahora)) ||
      _salientes.isNotEmpty ||
      _aparecio.values.any((t) => ahora - t < fundido);

  /// Ubica los marcadores en [ahora]; true si hay que seguir dibujando.
  bool avanzar(double ahora) {
    for (final m in _moviles.values) {
      m.avanzar(ahora);
    }
    return animando(ahora);
  }

  /// [escena] con los marcadores móviles en su posición predicha y con su
  /// rumbo; los recorridos que nacen en ellos (lo que falta caminar o
  /// viajar, la aproximación del bus) arrancan donde se los ve.
  EscenaMapa mostrada(EscenaMapa escena, double ahora) {
    if (_moviles.isEmpty && _salientes.isEmpty) return escena;
    final lecturas = <String, (Coordenada, Coordenada)>{};
    final marcas = <MarcaMapa>[];
    final opacidad = Map<MarcaMapa, double>.identity();
    _salientes.removeWhere((s) => ahora - s.$2 >= fundido);
    for (final (m, t0) in _salientes) {
      marcas.add(m);
      opacidad[m] = 1 - Curves.easeIn.transform((ahora - t0) / fundido);
    }
    for (final m in escena.marcas) {
      final k = _clave(m);
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
      if (t0 != null && ahora - t0 < fundido) {
        opacidad[mostrada] = Curves.easeOut.transform(
          ((ahora - t0) / fundido).clamp(0.0, 1.0),
        );
      }
    }
    final trazos = [
      for (final t in escena.trazos)
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
    return escena.con(marcas: marcas, trazos: trazos, opacidad: opacidad);
  }
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
            : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / l2).clamp(0.0, 1.0);
    final d = (p - (a + ab * u)).distance;
    if (d < mejorD) {
      mejorD = d;
      mejor = i;
    }
  }
  return TrazoMapa(t.estilo, [mostrado, ...pts.skip(mejor)]);
}
