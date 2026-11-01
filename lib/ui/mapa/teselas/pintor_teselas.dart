// Rasteriza teselas vectoriales con estilo cartográfico sobrio.
//
// Cada tesela se dibuja una vez a [PintorTeselas.resolucion] px (más que los
// 256 px lógicos que ocupa en pantalla, para que se vea nítida en pantallas
// densas) y se cachea como imagen.

import 'dart:ui' as ui;

import '../estilo_mapa.dart';
import 'mvt.dart';

/// Ancho de relleno (px lógicos a 256 px por tesela) de cada clase de calle,
/// por zoom de 10 a 18.
const _anchos = <String, List<double>>{
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

double anchoCalle(String clase, int zoom) {
  final t = _anchos[clase];
  if (t == null) return 0;
  return t[(zoom - 10).clamp(0, t.length - 1)];
}

const _ordenCalles = [
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

class PintorTeselas {
  final EstiloMapa estilo;

  /// Píxeles de la imagen por tesela.
  final int resolucion;

  const PintorTeselas(this.estilo, {this.resolucion = 512});

  /// Dibuja [fuente] en [canvas] (coordenadas de imagen 0..resolucion).
  /// [escala]/[desplazamiento] llevan coordenadas MVT de la tesela fuente al
  /// espacio de la tesela destino, en px lógicos (0..256).
  void pintar(
    ui.Canvas canvas,
    TeselaMvt fuente, {
    required int zoom,
    required double escala,
    required ui.Offset desplazamiento,
  }) {
    final e = estilo;
    final k = resolucion / 256.0;
    canvas.save();
    canvas.scale(k);

    ui.Offset p(PuntoTesela q) => ui.Offset(
      q.x * escala + desplazamiento.dx,
      q.y * escala + desplazamiento.dy,
    );

    ui.Path poligonos(Iterable<ElementoMvt> es) {
      final path = ui.Path()..fillType = ui.PathFillType.nonZero;
      for (final el in es) {
        if (el.tipo != TipoGeometria.poligono) continue;
        for (final anillo in el.geometria) {
          if (anillo.length < 3) continue;
          path.addPolygon([for (final q in anillo) p(q)], true);
        }
      }
      return path;
    }

    ui.Paint relleno(ui.Color c) => ui.Paint()..color = c;
    bool de(ElementoMvt x, Set<String> cs) => cs.contains(x.clase);

    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 256, 256), relleno(e.tierra));

    final landuse = fuente['landuse']?.elementos ?? const <ElementoMvt>[];
    canvas.drawPath(
      poligonos(
        landuse.where((x) => de(x, const {'residential', 'neighbourhood'})),
      ),
      relleno(e.manzana),
    );
    canvas.drawPath(
      poligonos(
        landuse.where(
          (x) => de(x, const {
            'commercial',
            'retail',
            'industrial',
            'railway',
            'garages',
          }),
        ),
      ),
      relleno(e.comercial),
    );
    canvas.drawPath(
      poligonos(
        landuse.where(
          (x) => de(x, const {'school', 'university', 'college', 'hospital'}),
        ),
      ),
      relleno(e.educacion),
    );
    canvas.drawPath(
      poligonos(
        landuse.where((x) => de(x, const {'cemetery', 'pitch', 'stadium'})),
      ),
      relleno(e.pasto),
    );

    final landcover = fuente['landcover']?.elementos ?? const <ElementoMvt>[];
    canvas.drawPath(
      poligonos(landcover.where((x) => de(x, const {'grass', 'farmland'}))),
      relleno(e.pasto),
    );
    canvas.drawPath(
      poligonos(landcover.where((x) => x.clase == 'wood')),
      relleno(e.bosque),
    );
    canvas.drawPath(
      poligonos(landcover.where((x) => x.clase == 'sand')),
      relleno(e.arena),
    );
    canvas.drawPath(
      poligonos(fuente['park']?.elementos ?? const []),
      relleno(e.pasto),
    );

    canvas.drawPath(
      poligonos(fuente['water']?.elementos ?? const []),
      relleno(e.agua),
    );
    for (final w in fuente['waterway']?.elementos ?? const <ElementoMvt>[]) {
      _lineas(canvas, w, p, e.agua, zoom >= 15 ? 1.6 : 0.8);
    }
    for (final a in fuente['aeroway']?.elementos ?? const <ElementoMvt>[]) {
      if (a.tipo == TipoGeometria.poligono) {
        canvas.drawPath(poligonos([a]), relleno(e.comercial));
      } else {
        _lineas(canvas, a, p, e.sendero, 3);
      }
    }

    if (zoom >= 15) {
      final edificios = poligonos(fuente['building']?.elementos ?? const []);
      canvas.drawPath(edificios, relleno(e.edificio));
      if (zoom >= 17) {
        canvas.drawPath(
          edificios,
          ui.Paint()
            ..color = e.calleBorde
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 0.5,
        );
      }
    }

    // Calles: bordes y después rellenos, por jerarquía.
    final porClase = <String, List<ElementoMvt>>{};
    for (final x
        in fuente['transportation']?.elementos ?? const <ElementoMvt>[]) {
      if (x.tipo != TipoGeometria.linea) continue;
      final c = _claseCalle(x);
      if (c != null) (porClase[c] ??= []).add(x);
    }
    for (final x in [...?porClase['rail'], ...?porClase['transit']]) {
      _lineas(
        canvas,
        x,
        p,
        e.via,
        anchoCalle('rail', zoom),
        discontinua: zoom >= 15,
      );
    }
    final conBorde = zoom >= 13;
    if (conBorde) {
      for (final c in _ordenCalles) {
        final w = anchoCalle(c, zoom);
        if (w <= 0 || c == 'path' || c == 'track') continue;
        final borde = switch (c) {
          'motorway' || 'trunk' => e.autopistaBorde,
          'primary' || 'secondary' => e.avenidaBorde,
          _ => e.calleBorde,
        };
        for (final x in porClase[c] ?? const <ElementoMvt>[]) {
          _lineas(canvas, x, p, borde, w + (zoom >= 15 ? 2 : 1.2));
        }
      }
    }
    for (final c in _ordenCalles) {
      final w = anchoCalle(c, zoom);
      if (w <= 0) continue;
      final color = switch (c) {
        'motorway' || 'trunk' => e.autopista,
        'primary' || 'secondary' => conBorde ? e.avenida : e.avenidaBorde,
        'path' || 'track' => e.sendero,
        _ => conBorde ? e.calle : e.calleBorde,
      };
      for (final x in porClase[c] ?? const <ElementoMvt>[]) {
        _lineas(
          canvas,
          x,
          p,
          color,
          w,
          discontinua: c == 'path' || c == 'track',
        );
      }
    }
    canvas.restore();
  }

  String? _claseCalle(ElementoMvt x) {
    final c = x.clase;
    if (c == null || c.endsWith('_construction')) return null;
    if (x.propiedades['brunnel'] == 'tunnel') return null;
    if (c == 'rail' || c == 'transit') return c;
    return _ordenCalles.contains(c) ? c : null;
  }

  void _lineas(
    ui.Canvas canvas,
    ElementoMvt x,
    ui.Offset Function(PuntoTesela) p,
    ui.Color color,
    double ancho, {
    bool discontinua = false,
  }) {
    if (ancho <= 0) return;
    final paint =
        ui.Paint()
          ..color = color
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = ancho
          ..strokeCap = ui.StrokeCap.round
          ..strokeJoin = ui.StrokeJoin.round;
    for (final linea in x.geometria) {
      if (linea.length < 2) continue;
      final pts = [for (final q in linea) p(q)];
      if (discontinua) {
        guiones(canvas, pts, paint, trazo: 2.5, hueco: 2.5);
      } else {
        canvas.drawPath(ui.Path()..addPolygon(pts, false), paint);
      }
    }
  }
}

/// Dibuja una polilínea discontinua.
void guiones(
  ui.Canvas c,
  List<ui.Offset> pts,
  ui.Paint p, {
  required double trazo,
  required double hueco,
  double fase = 0,
}) {
  final ciclo = trazo + hueco;
  var pos = -fase % ciclo;
  final path = ui.Path();
  for (var i = 1; i < pts.length; i++) {
    final a = pts[i - 1], b = pts[i];
    final d = b - a;
    final largo = d.distance;
    if (largo == 0) continue;
    final dir = d / largo;
    var t = 0.0;
    while (t < largo) {
      final enCiclo = ((pos % ciclo) + ciclo) % ciclo;
      if (enCiclo < trazo) {
        final hasta = (t + (trazo - enCiclo)).clamp(0.0, largo);
        final ia = a + dir * t, ib = a + dir * hasta;
        path
          ..moveTo(ia.dx, ia.dy)
          ..lineTo(ib.dx, ib.dy);
        pos += hasta - t;
        t = hasta;
      } else {
        final salto = (ciclo - enCiclo).clamp(0.0, largo - t);
        if (salto <= 0) break;
        pos += salto;
        t += salto;
      }
    }
  }
  c.drawPath(path, p);
}

/// Dibuja puntos redondos a lo largo de una polilínea (caminata).
void puntosALoLargo(
  ui.Canvas c,
  List<ui.Offset> pts,
  ui.Paint p, {
  required double radio,
  required double separacion,
}) {
  var resto = 0.0;
  for (var i = 1; i < pts.length; i++) {
    final a = pts[i - 1], b = pts[i];
    final d = b - a;
    final largo = d.distance;
    if (largo == 0) continue;
    final dir = d / largo;
    var t = resto;
    while (t <= largo) {
      c.drawCircle(a + dir * t, radio, p);
      t += separacion;
    }
    resto = t - largo;
  }
}
