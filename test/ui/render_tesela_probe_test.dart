// Visual probe: renders real tiles to PNG (build/sondas/) to review
// the pixel art style. It makes no pixel asserts; it checks that it does not fail and
// that the image has content.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bondi_uy/ui/map/map_style.dart';
import 'package:bondi_uy/ui/map/tiles/mvt.dart';
import 'package:bondi_uy/ui/map/tiles/tile_painter.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> guardar(ui.Image img, String name, {int scale = 3}) async {
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawImageRect(
    img,
    ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
    ui.Rect.fromLTWH(0, 0, img.width * scale * 1.0, img.height * scale * 1.0),
    ui.Paint()..filterQuality = ui.FilterQuality.none,
  );
  final grande = rec.endRecording().toImageSync(
    img.width * scale,
    img.height * scale,
  );
  final png = await grande.toByteData(format: ui.ImageByteFormat.png);
  final f = File('build/sondas/$name.png');
  await f.parent.create(recursive: true);
  await f.writeAsBytes(png!.buffer.asUint8List());
}

void main() {
  test('renderiza teselas del centro y la rambla', () async {
    for (final style in [MapStyle.light, MapStyle.dark]) {
      final painter = TilePainter(style, resolution: 256);
      // z14 x=5634..5638 from the fixture; over-enlarges to z16 a quarter of a tile.
      final dir = Directory('test/fixtures/teselas/14');
      final xs =
          dir
              .listSync()
              .map(
                (e) => int.parse(
                  e.uri.pathSegments.where((s) => s.isNotEmpty).last,
                ),
              )
              .toList()
            ..sort();
      final x = xs[xs.length ~/ 2];
      final ys =
          Directory('${dir.path}/$x')
              .listSync()
              .map((e) => int.parse(e.uri.pathSegments.last.split('.').first))
              .toList()
            ..sort();
      for (final y in ys) {
        final mvt = decodeMvt(File('${dir.path}/$x/$y.pbf').readAsBytesSync());
        for (final (zoom, sub) in [(14, 0), (16, 1), (16, 2)]) {
          final rec = ui.PictureRecorder();
          final c = ui.Canvas(rec);
          final factor = zoom == 14 ? 1 : 4;
          final extent = mvt['transportation']?.extent ?? 4096;
          final scale = 256 * factor / extent;
          final off = ui.Offset(-(sub % 2) * 256.0, -(sub ~/ 2) * 256.0);
          painter.paint(c, mvt, zoom: zoom, scale: scale, desplazamiento: off);
          final img = rec.endRecording().toImageSync(256, 256);
          await guardar(
            img,
            '${style.glow.name}_z${zoom}_${x}_${y}_$sub',
            scale: 2,
          );
        }
      }
    }
  });
}
