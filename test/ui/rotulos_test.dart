import 'dart:ui' as ui;

import 'package:bondi_uy/contract/modelo.dart';
import 'package:bondi_uy/ui/mapa/escena.dart';
import 'package:bondi_uy/ui/mapa/estilo_mapa.dart';
import 'package:bondi_uy/ui/mapa/pintor_escena.dart';
import 'package:bondi_uy/ui/mapa/proyeccion.dart';
import 'package:bondi_uy/ui/mapa/teselas/gestor_teselas.dart';
import 'package:flutter/painting.dart' show EdgeInsets;
import 'package:flutter_test/flutter_test.dart';

import 'arnes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('las calles se rotulan en vistas cercanas', () async {
    await cargarFuentes();
    final g = GestorTeselas(
      TeselasEnMemoria.cargar(),
      EstiloMapa.claro,
      usarIsolate: false,
    );
    final pintor = PintorEscena(g, EstiloMapa.claro)..familia = 'Roboto';
    const tam = ui.Size(412, 892);
    // 18 de Julio y Ejido.
    for (final z in [15.0, 16.0, 17.0]) {
      final cam = Camara.en(const Coordenada(-34.9055, -56.1905), z);
      for (var i = 0; i < 10; i++) {
        pintor.pintar(
          ui.Canvas(ui.PictureRecorder()),
          tam,
          cam,
          EscenaMapa.vacia,
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      pintor.pintar(
        ui.Canvas(ui.PictureRecorder()),
        tam,
        cam,
        EscenaMapa.vacia,
      );
      expect(pintor.rotulosPuestos, isNotEmpty, reason: 'zoom $z');
    }
    // Zona del viaje grabado (Malvín), con los márgenes de la fase viaje.
    for (final z in [16.0, 16.5, 17.0]) {
      final cam = Camara.en(const Coordenada(-34.8990, -56.1170), z);
      for (var i = 0; i < 10; i++) {
        pintor.pintar(
          ui.Canvas(ui.PictureRecorder()),
          tam,
          cam,
          EscenaMapa.vacia,
          margenes: const EdgeInsets.only(top: 210, bottom: 100),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      expect(pintor.rotulosPuestos, isNotEmpty, reason: 'Malvín zoom $z');
    }
  });
}
