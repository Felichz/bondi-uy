// Carga, decodifica y rasteriza teselas; mantiene cachés LRU.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'fuente_teselas.dart';
import 'mvt.dart';
import '../estilo_mapa.dart';
import 'pintor_teselas.dart';

/// Nombre de calle/barrio ubicable en el mapa, en mercator normalizado.
class RotuloMapa {
  final String texto;
  final String clase;
  final List<ui.Offset> puntos;
  const RotuloMapa(this.texto, this.clase, this.puntos);
}

class _Fuente {
  final TeselaMvt mvt;
  final List<RotuloMapa> rotulos;
  _Fuente(this.mvt, this.rotulos);
}

class GestorTeselas extends ChangeNotifier {
  final FuenteTeselas fuente;
  final PintorTeselas _pintor;
  int get resolucion => _pintor.resolucion;

  /// Decodificar en un isolate (desactivar en tests con tiempo falso).
  final bool usarIsolate;

  final _fuentes = <String, _Fuente?>{};
  final _pedidasFuente = <String, Future<_Fuente?>>{};
  final _imagenes = <String, ui.Image>{};
  final _pedidasImagen = <String>{};
  bool _descartado = false;

  GestorTeselas(this.fuente, EstiloMapa estilo, {this.usarIsolate = true})
    : _pintor = PintorTeselas(estilo);

  static String _k(int z, int x, int y) => '$z/$x/$y';

  /// Imagen (resolucion x resolucion) de la tesela a zoom de visualización [z], o null si
  /// todavía no está (se pide y se notifica al estar lista).
  ui.Image? imagen(int z, int x, int y) {
    final n = 1 << z;
    if (y < 0 || y >= n) return null;
    x = ((x % n) + n) % n;
    final k = _k(z, x, y);
    final img = _imagenes.remove(k);
    if (img != null) {
      _imagenes[k] = img; // LRU: al final
      return img;
    }
    if (_pedidasImagen.add(k)) unawaited(_rasterizar(z, x, y));
    return null;
  }

  /// Rótulos de las teselas fuente ya cargadas que cubren la tesela [z,x,y].
  List<RotuloMapa> rotulos(int z, int x, int y) {
    final (zs, xs, ys) = _fuenteDe(z, x, y);
    return _fuentes[_k(zs, xs, ys)]?.rotulos ?? const [];
  }

  (int, int, int) _fuenteDe(int z, int x, int y) {
    if (z <= zoomMaximoDatos) return (z, x, y);
    final d = z - zoomMaximoDatos;
    return (zoomMaximoDatos, x >> d, y >> d);
  }

  Future<void> _rasterizar(int z, int x, int y) async {
    final (zs, xs, ys) = _fuenteDe(z, x, y);
    final f = await _cargarFuente(zs, xs, ys);
    if (_descartado) return;
    final k = _k(z, x, y);
    if (f == null) {
      _pedidasImagen.remove(k);
      return;
    }
    final d = z - zs;
    final factor = 1 << d;
    final extent =
        f.mvt.capas.values.isEmpty ? 4096 : f.mvt.capas.values.first.extent;
    final escala = 256.0 * factor / extent;
    final res = _pintor.resolucion;
    final subX = x - (xs << d), subY = y - (ys << d);
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    _pintor.pintar(
      canvas,
      f.mvt,
      zoom: z,
      escala: escala,
      desplazamiento: ui.Offset(-subX * 256.0, -subY * 256.0),
    );
    final img = rec.endRecording().toImageSync(res, res);
    _imagenes[k] = img;
    _pedidasImagen.remove(k);
    while (_imagenes.length > 96) {
      final viejo = _imagenes.keys.first;
      _imagenes.remove(viejo)?.dispose();
    }
    notifyListeners();
  }

  Future<_Fuente?> _cargarFuente(int z, int x, int y) {
    final k = _k(z, x, y);
    if (_fuentes.containsKey(k)) return Future.value(_fuentes[k]);
    return _pedidasFuente[k] ??= () async {
      Uint8List? bytes;
      try {
        bytes = await fuente.bytes(z, x, y);
      } catch (_) {
        bytes = null;
      }
      _Fuente? f;
      if (bytes != null) {
        final mvt =
            usarIsolate
                ? await compute(decodificarMvt, bytes)
                : decodificarMvt(bytes);
        f = _Fuente(mvt, _extraerRotulos(mvt, z, x, y));
      }
      _pedidasFuente.remove(k);
      if (f != null) {
        _fuentes[k] = f;
        while (_fuentes.length > 40) {
          _fuentes.remove(_fuentes.keys.first);
        }
      }
      return f;
    }();
  }

  List<RotuloMapa> _extraerRotulos(TeselaMvt mvt, int z, int x, int y) {
    final res = <RotuloMapa>[];
    final n = math.pow(2, z).toDouble();
    ui.Offset mundo(PuntoTesela p, int extent) =>
        ui.Offset((x + p.x / extent) / n, (y + p.y / extent) / n);

    final nombres = mvt['transportation_name'];
    if (nombres != null) {
      for (final e in nombres.elementos) {
        final nombre = e.nombre;
        if (nombre == null || e.tipo != TipoGeometria.linea) continue;
        for (final linea in e.geometria) {
          if (linea.length < 2) continue;
          res.add(
            RotuloMapa(nombre, e.clase ?? 'minor', [
              for (final p in linea) mundo(p, nombres.extent),
            ]),
          );
        }
      }
    }
    final lugares = mvt['place'];
    if (lugares != null) {
      for (final e in lugares.elementos) {
        final nombre = e.nombre;
        final clase = e.clase;
        if (nombre == null || e.tipo != TipoGeometria.punto) continue;
        if (clase != 'suburb' && clase != 'neighbourhood' && clase != 'quarter')
          continue;
        res.add(
          RotuloMapa(nombre, 'barrio', [
            for (final g in e.geometria)
              for (final p in g) mundo(p, lugares.extent),
          ]),
        );
      }
    }
    return res;
  }

  @override
  void dispose() {
    _descartado = true;
    for (final i in _imagenes.values) {
      i.dispose();
    }
    _imagenes.clear();
    super.dispose();
  }
}
