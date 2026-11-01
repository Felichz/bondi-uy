// Sonda visual: renderiza teselas reales a PNG (build/sondas/) para revisar
// el estilo pixel art. No hace asserts de píxeles; verifica que no falle y
// que la imagen tenga contenido.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bondi_uy/ui/mapa/estilo_mapa.dart';
import 'package:bondi_uy/ui/mapa/teselas/mvt.dart';
import 'package:bondi_uy/ui/mapa/teselas/pintor_teselas.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> guardar(ui.Image img, String nombre, {int escala = 3}) async {
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawImageRect(
    img,
    ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
    ui.Rect.fromLTWH(0, 0, img.width * escala * 1.0, img.height * escala * 1.0),
    ui.Paint()..filterQuality = ui.FilterQuality.none,
  );
  final grande = rec.endRecording().toImageSync(
    img.width * escala,
    img.height * escala,
  );
  final png = await grande.toByteData(format: ui.ImageByteFormat.png);
  final f = File('build/sondas/$nombre.png');
  await f.parent.create(recursive: true);
  await f.writeAsBytes(png!.buffer.asUint8List());
}

void main() {
  test('renderiza teselas del centro y la rambla', () async {
    for (final estilo in [EstiloMapa.claro, EstiloMapa.oscuro]) {
      final pintor = PintorTeselas(estilo, resolucion: 256);
      // z14 x=5634..5638 del fixture; sobre-amplía a z16 un cuarto de tesela.
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
        final mvt = decodificarMvt(
          File('${dir.path}/$x/$y.pbf').readAsBytesSync(),
        );
        for (final (zoom, sub) in [(14, 0), (16, 1), (16, 2)]) {
          final rec = ui.PictureRecorder();
          final c = ui.Canvas(rec);
          final factor = zoom == 14 ? 1 : 4;
          final extent = mvt['transportation']?.extent ?? 4096;
          final escala = 256 * factor / extent;
          final off = ui.Offset(-(sub % 2) * 256.0, -(sub ~/ 2) * 256.0);
          pintor.pintar(
            c,
            mvt,
            zoom: zoom,
            escala: escala,
            desplazamiento: off,
          );
          final img = rec.endRecording().toImageSync(256, 256);
          await guardar(
            img,
            '${estilo.brillo.name}_z${zoom}_${x}_${y}_$sub',
            escala: 2,
          );
        }
      }
    }
  });
}
