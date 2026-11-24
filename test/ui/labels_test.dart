import 'dart:ui' as ui;

import 'package:bondi_uy/contract/model.dart';
import 'package:bondi_uy/ui/map/scene.dart';
import 'package:bondi_uy/ui/map/map_style.dart';
import 'package:bondi_uy/ui/map/scene_painter.dart';
import 'package:bondi_uy/ui/map/projection.dart';
import 'package:bondi_uy/ui/map/tiles/tile_manager.dart';
import 'package:flutter/painting.dart' show EdgeInsets;
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('streets are labeled in close-up views', () async {
    await loadSources();
    final g = TileManager(
      MemoryTiles.load(),
      MapStyle.light,
      useIsolate: false,
    );
    final painter = SceneDrawer(g, MapStyle.light)..family = 'Roboto';
    const size = ui.Size(412, 892);
    // 18 de Julio y Ejido.
    for (final z in [15.0, 16.0, 17.0]) {
      final cam = Camera.at(const Coordinate(-34.9055, -56.1905), z);
      for (var i = 0; i < 10; i++) {
        painter.paint(
          ui.Canvas(ui.PictureRecorder()),
          size,
          cam,
          MapScene.empty,
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      painter.paint(ui.Canvas(ui.PictureRecorder()), size, cam, MapScene.empty);
      expect(painter.labelsPlaced, isNotEmpty, reason: 'zoom $z');
    }
    // Area of the recorded trip (Malvín), with the margins of the trip phase.
    for (final z in [16.0, 16.5, 17.0]) {
      final cam = Camera.at(const Coordinate(-34.8990, -56.1170), z);
      for (var i = 0; i < 10; i++) {
        painter.paint(
          ui.Canvas(ui.PictureRecorder()),
          size,
          cam,
          MapScene.empty,
          margins: const EdgeInsets.only(top: 210, bottom: 100),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      expect(painter.labelsPlaced, isNotEmpty, reason: 'Malvín zoom $z');
    }
  });
}
