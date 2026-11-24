// Loads, decodes and rasterizes tiles; keeps LRU caches.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'tile_source.dart';
import 'mvt.dart';
import '../map_style.dart';
import 'tile_painter.dart';

/// Street/neighbourhood name that can be placed on the map, in normalized mercator.
class MapLabel {
  final String text;
  final String classValue;
  final List<ui.Offset> points;
  const MapLabel(this.text, this.classValue, this.points);
}

class _Source {
  final TileMvt mvt;
  final List<MapLabel> labels;
  _Source(this.mvt, this.labels);
}

class TileManager extends ChangeNotifier {
  final TileSource source;
  final TilePainter _painter;
  int get resolution => _painter.resolution;

  /// Decode in an isolate (disable in tests with fake time).
  final bool useIsolate;

  final _sources = <String, _Source?>{};
  final _requestedSources = <String, Future<_Source?>>{};
  final _images = <String, ui.Image>{};
  final _requestedImages = <String>{};
  bool _discarded = false;

  TileManager(this.source, MapStyle style, {this.useIsolate = true})
    : _painter = TilePainter(style);

  static String _k(int z, int x, int y) => '$z/$x/$y';

  /// Image (resolution x resolution) of the tile at display zoom [z], or null if
  /// it is not ready yet (it is requested and notified once it is ready).
  ui.Image? image(int z, int x, int y) {
    final n = 1 << z;
    if (y < 0 || y >= n) return null;
    x = ((x % n) + n) % n;
    final k = _k(z, x, y);
    final img = _images.remove(k);
    if (img != null) {
      _images[k] = img; // LRU: moved to the end
      return img;
    }
    if (_requestedImages.add(k)) unawaited(_rasterize(z, x, y));
    return null;
  }

  /// Labels of the source tiles already loaded that cover tile [z,x,y].
  List<MapLabel> labels(int z, int x, int y) {
    final (zs, xs, ys) = _sourceOf(z, x, y);
    return _sources[_k(zs, xs, ys)]?.labels ?? const [];
  }

  (int, int, int) _sourceOf(int z, int x, int y) {
    if (z <= zoomMaxData) return (z, x, y);
    final d = z - zoomMaxData;
    return (zoomMaxData, x >> d, y >> d);
  }

  Future<void> _rasterize(int z, int x, int y) async {
    final (zs, xs, ys) = _sourceOf(z, x, y);
    final f = await _loadSource(zs, xs, ys);
    if (_discarded) return;
    final k = _k(z, x, y);
    if (f == null) {
      _requestedImages.remove(k);
      return;
    }
    final d = z - zs;
    final factor = 1 << d;
    final extent =
        f.mvt.layers.values.isEmpty ? 4096 : f.mvt.layers.values.first.extent;
    final scale = 256.0 * factor / extent;
    final res = _painter.resolution;
    final subX = x - (xs << d), subY = y - (ys << d);
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    _painter.paint(
      canvas,
      f.mvt,
      zoom: z,
      scale: scale,
      shift: ui.Offset(-subX * 256.0, -subY * 256.0),
    );
    final img = rec.endRecording().toImageSync(res, res);
    _images[k] = img;
    _requestedImages.remove(k);
    while (_images.length > 96) {
      final old = _images.keys.first;
      _images.remove(old)?.dispose();
    }
    notifyListeners();
  }

  Future<_Source?> _loadSource(int z, int x, int y) {
    final k = _k(z, x, y);
    if (_sources.containsKey(k)) return Future.value(_sources[k]);
    return _requestedSources[k] ??= () async {
      Uint8List? bytes;
      try {
        bytes = await source.bytes(z, x, y);
      } catch (_) {
        bytes = null;
      }
      _Source? f;
      if (bytes != null) {
        final mvt =
            useIsolate ? await compute(decodeMvt, bytes) : decodeMvt(bytes);
        f = _Source(mvt, _extractLabels(mvt, z, x, y));
      }
      _requestedSources.remove(k);
      if (f != null) {
        _sources[k] = f;
        while (_sources.length > 40) {
          _sources.remove(_sources.keys.first);
        }
      }
      return f;
    }();
  }

  List<MapLabel> _extractLabels(TileMvt mvt, int z, int x, int y) {
    final res = <MapLabel>[];
    final n = math.pow(2, z).toDouble();
    ui.Offset world(TilePoint p, int extent) =>
        ui.Offset((x + p.x / extent) / n, (y + p.y / extent) / n);

    final names = mvt['transportation_name'];
    if (names != null) {
      for (final e in names.elements) {
        final name = e.name;
        if (name == null || e.type != GeometryType.line) continue;
        for (final line in e.geometry) {
          if (line.length < 2) continue;
          res.add(
            MapLabel(name, e.classValue ?? 'minor', [
              for (final p in line) world(p, names.extent),
            ]),
          );
        }
      }
    }
    final places = mvt['place'];
    if (places != null) {
      for (final e in places.elements) {
        final name = e.name;
        final classValue = e.classValue;
        if (name == null || e.type != GeometryType.point) continue;
        if (classValue != 'suburb' &&
            classValue != 'neighbourhood' &&
            classValue != 'quarter')
          continue;
        res.add(
          MapLabel(name, 'neighborhood', [
            for (final g in e.geometry)
              for (final p in g) world(p, places.extent),
          ]),
        );
      }
    }
    return res;
  }

  @override
  void dispose() {
    _discarded = true;
    for (final i in _images.values) {
      i.dispose();
    }
    _images.clear();
    super.dispose();
  }
}
