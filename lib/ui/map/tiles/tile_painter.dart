// Rasterizes vector tiles with a sober cartographic style.
//
// Each tile is drawn once at [PintorTeselas.resolucion] px (more than the
// 256 logical px it occupies on screen, so it looks sharp on dense displays)
// and cached as an image.

import 'dart:ui' as ui;

import '../map_style.dart';
import 'mvt.dart';

/// Fill width (logical px at 256 px per tile) for each street class,
/// per zoom level from 10 to 18.
const _widths = <String, List<double>>{
  'motorway': [1.2, 1.6, 2.2, 3.0, 4.5, 6.5, 9, 13, 18],
  'trunk': [1.2, 1.6, 2.2, 3.0, 4.5, 6.5, 9, 13, 18],
  'primary': [0.9, 1.2, 1.8, 2.6, 4.0, 6, 8.5, 12, 16],
  'secondary': [0.6, 0.9, 1.3, 2.0, 3.2, 5, 7, 10, 14],
  'tertiary': [0.4, 0.6, 1.0, 1.6, 2.6, 4, 6, 9, 12],
  'minor': [0, 0, 0.5, 0.9, 1.6, 3, 4.5, 7, 10],
  'service': [0, 0, 0, 0.4, 0.8, 1.5, 2.5, 4, 6],
  'path': [0, 0, 0, 0, 0.6, 0.8, 1, 1.2, 1.4],
  'track': [0, 0, 0, 0, 0.6, 0.8, 1, 1.2, 1.4],
  'rail': [0.5, 0.6, 0.7, 0.8, 1, 1.2, 1.4, 1.6, 1.8],
  'transit': [0.5, 0.6, 0.7, 0.8, 1, 1.2, 1.4, 1.6, 1.8],
};

double widthStreet(String classValue, int zoom) {
  final t = _widths[classValue];
  if (t == null) return 0;
  return t[(zoom - 10).clamp(0, t.length - 1)];
}

const _orderStreets = [
  'path',
  'track',
  'service',
  'minor',
  'tertiary',
  'secondary',
  'primary',
  'trunk',
  'motorway',
];

class TilePainter {
  final MapStyle style;

  /// Image pixels per tile.
  final int resolution;

  const TilePainter(this.style, {this.resolution = 512});

  /// Draws [fuente] onto [canvas] (image coordinates 0..resolucion).
  /// [escala]/[shift] map MVT coordinates from the source tile to the
  /// destination tile space, in logical px (0..256).
  void paint(
    ui.Canvas canvas,
    TileMvt source, {
    required int zoom,
    required double scale,
    required ui.Offset shift,
  }) {
    final e = style;
    final k = resolution / 256.0;
    canvas.save();
    canvas.scale(k);

    ui.Offset p(TilePoint q) =>
        ui.Offset(q.x * scale + shift.dx, q.y * scale + shift.dy);

    ui.Path polygons(Iterable<MvtElement> elements) {
      final path = ui.Path()..fillType = ui.PathFillType.nonZero;
      for (final element in elements) {
        if (element.type != GeometryType.polygon) continue;
        for (final ring in element.geometry) {
          if (ring.length < 3) continue;
          path.addPolygon([for (final q in ring) p(q)], true);
        }
      }
      return path;
    }

    ui.Paint fill(ui.Color c) => ui.Paint()..color = c;
    bool inClass(MvtElement x, Set<String> cs) => cs.contains(x.classValue);

    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 256, 256), fill(e.land));

    final landuse = source['landuse']?.elements ?? const <MvtElement>[];
    canvas.drawPath(
      polygons(
        landuse.where(
          (x) => inClass(x, const {'residential', 'neighbourhood'}),
        ),
      ),
      fill(e.block),
    );
    canvas.drawPath(
      polygons(
        landuse.where(
          (x) => inClass(x, const {
            'commercial',
            'retail',
            'industrial',
            'railway',
            'garages',
          }),
        ),
      ),
      fill(e.commercial),
    );
    canvas.drawPath(
      polygons(
        landuse.where(
          (x) =>
              inClass(x, const {'school', 'university', 'college', 'hospital'}),
        ),
      ),
      fill(e.education),
    );
    canvas.drawPath(
      polygons(
        landuse.where(
          (x) => inClass(x, const {'cemetery', 'pitch', 'stadium'}),
        ),
      ),
      fill(e.grass),
    );

    final landcover = source['landcover']?.elements ?? const <MvtElement>[];
    canvas.drawPath(
      polygons(landcover.where((x) => inClass(x, const {'grass', 'farmland'}))),
      fill(e.grass),
    );
    canvas.drawPath(
      polygons(landcover.where((x) => x.classValue == 'wood')),
      fill(e.forest),
    );
    canvas.drawPath(
      polygons(landcover.where((x) => x.classValue == 'sand')),
      fill(e.arena),
    );
    canvas.drawPath(
      polygons(source['park']?.elements ?? const []),
      fill(e.grass),
    );

    canvas.drawPath(
      polygons(source['water']?.elements ?? const []),
      fill(e.water),
    );
    for (final w in source['waterway']?.elements ?? const <MvtElement>[]) {
      _lines(canvas, w, p, e.water, zoom >= 15 ? 1.6 : 0.8);
    }
    for (final a in source['aeroway']?.elements ?? const <MvtElement>[]) {
      if (a.type == GeometryType.polygon) {
        canvas.drawPath(polygons([a]), fill(e.commercial));
      } else {
        _lines(canvas, a, p, e.footway, 3);
      }
    }

    if (zoom >= 15) {
      final buildings = polygons(source['building']?.elements ?? const []);
      canvas.drawPath(buildings, fill(e.building));
      if (zoom >= 17) {
        canvas.drawPath(
          buildings,
          ui.Paint()
            ..color = e.streetBorder
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 0.5,
        );
      }
    }

    // Streets: outlines first, then fills, by hierarchy.
    final byClass = <String, List<MvtElement>>{};
    for (final x
        in source['transportation']?.elements ?? const <MvtElement>[]) {
      if (x.type != GeometryType.line) continue;
      final c = _classStreet(x);
      if (c != null) (byClass[c] ??= []).add(x);
    }
    for (final x in [...?byClass['rail'], ...?byClass['transit']]) {
      _lines(
        canvas,
        x,
        p,
        e.via,
        widthStreet('rail', zoom),
        dashed: zoom >= 15,
      );
    }
    final withBorder = zoom >= 13;
    if (withBorder) {
      for (final c in _orderStreets) {
        final w = widthStreet(c, zoom);
        if (w <= 0 || c == 'path' || c == 'track') continue;
        final border = switch (c) {
          'motorway' || 'trunk' => e.motorwayBorder,
          'primary' || 'secondary' => e.avenueBorder,
          _ => e.streetBorder,
        };
        for (final x in byClass[c] ?? const <MvtElement>[]) {
          _lines(canvas, x, p, border, w + (zoom >= 15 ? 2 : 1.2));
        }
      }
    }
    for (final c in _orderStreets) {
      final w = widthStreet(c, zoom);
      if (w <= 0) continue;
      final color = switch (c) {
        'motorway' || 'trunk' => e.motorway,
        'primary' || 'secondary' => withBorder ? e.avenue : e.avenueBorder,
        'path' || 'track' => e.footway,
        _ => withBorder ? e.street : e.streetBorder,
      };
      for (final x in byClass[c] ?? const <MvtElement>[]) {
        _lines(canvas, x, p, color, w, dashed: c == 'path' || c == 'track');
      }
    }
    canvas.restore();
  }

  String? _classStreet(MvtElement x) {
    final c = x.classValue;
    if (c == null || c.endsWith('_construction')) return null;
    if (x.properties['brunnel'] == 'tunnel') return null;
    if (c == 'rail' || c == 'transit') return c;
    return _orderStreets.contains(c) ? c : null;
  }

  void _lines(
    ui.Canvas canvas,
    MvtElement x,
    ui.Offset Function(TilePoint) p,
    ui.Color color,
    double width, {
    bool dashed = false,
  }) {
    if (width <= 0) return;
    final paint =
        ui.Paint()
          ..color = color
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = ui.StrokeCap.round
          ..strokeJoin = ui.StrokeJoin.round;
    for (final line in x.geometry) {
      if (line.length < 2) continue;
      final pts = [for (final q in line) p(q)];
      if (dashed) {
        scripts(canvas, pts, paint, stroke: 2.5, gap: 2.5);
      } else {
        canvas.drawPath(ui.Path()..addPolygon(pts, false), paint);
      }
    }
  }
}

/// Draws a dashed polyline.
void scripts(
  ui.Canvas c,
  List<ui.Offset> pts,
  ui.Paint p, {
  required double stroke,
  required double gap,
  double phase = 0,
}) {
  final cycle = stroke + gap;
  var pos = -phase % cycle;
  final path = ui.Path();
  for (var i = 1; i < pts.length; i++) {
    final a = pts[i - 1], b = pts[i];
    final d = b - a;
    final long = d.distance;
    if (long == 0) continue;
    final dir = d / long;
    var t = 0.0;
    while (t < long) {
      final inCycle = ((pos % cycle) + cycle) % cycle;
      if (inCycle < stroke) {
        final until = (t + (stroke - inCycle)).clamp(0.0, long);
        final ia = a + dir * t, ib = a + dir * until;
        path
          ..moveTo(ia.dx, ia.dy)
          ..lineTo(ib.dx, ib.dy);
        pos += until - t;
        t = until;
      } else {
        final jump = (cycle - inCycle).clamp(0.0, long - t);
        if (jump <= 0) break;
        pos += jump;
        t += jump;
      }
    }
  }
  c.drawPath(path, p);
}

/// Draws round dots along a polyline (walking route).
void pointsAlong(
  ui.Canvas c,
  List<ui.Offset> pts,
  ui.Paint p, {
  required double radio,
  required double separation,
}) {
  var rest = 0.0;
  for (var i = 1; i < pts.length; i++) {
    final a = pts[i - 1], b = pts[i];
    final d = b - a;
    final long = d.distance;
    if (long == 0) continue;
    final dir = d / long;
    var t = rest;
    while (t <= long) {
      c.drawCircle(a + dir * t, radio, p);
      t += separation;
    }
    rest = t - long;
  }
}
