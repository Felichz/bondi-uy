// Un viaje de la demo de punta a punta, con cada estado que publica la
// lógica y el reloj (real y simulado) de ese momento. Lo usan los tests que
// revisan cómo se mueve todo (demo_movimiento_test y demo_cuadros_test).

import 'dart:convert';
import 'dart:io';

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/logic/app_controller.dart';
import 'package:bondi_uy/logic/servicios/catalogo_assets.dart';
import 'package:bondi_uy/logic/simulacion/demo.dart';
import 'package:bondi_uy/logic/simulacion/mundo_simulado.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _BundleDisco extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      utf8.decode(File(key).readAsBytesSync());
}

/// Un estado publicado, con el reloj real y el simulado de ese momento.
class Instante {
  final Duration real;
  final DateTime sim;
  final AppState s;
  Instante(this.real, this.sim, this.s);
}

/// Un viaje de la demo de punta a punta, como lo hace un visitante: elige
/// [destino], mira las opciones [enOpciones] y empieza la recomendada.
List<Instante> recorrerDemo({
  required Lugar destino,
  required double velocidad,
  required Duration enOpciones,
  void Function(AppController c, FakeAsync async)? alLlegar,
}) {
  late List<Instante> estados;
  fakeAsync((async) {
    estados = [];
    // Dentro del tiempo falso: un futuro creado afuera no se resuelve acá.
    final catalogo = CatalogoAssets(bundle: _BundleDisco());
    final mundo = MundoSimulado(
      catalogo: catalogo,
      posicionInicial: casaDemo,
      p: ParametrosSimulacion(velocidad: velocidad),
      ahoraSimulado: DateTime(2026, 9, 28, 18),
      transcurrido: () => async.elapsed,
    );
    final c = crearControladorDemo(
      mundo: mundo,
      catalogo: catalogo,
      bundle: _BundleDisco(),
    );
    c.addListener(
      (s) => estados.add(Instante(async.elapsed, mundo.ahora(), s)),
      fireImmediately: false,
    );
    c.arrancar();
    async.elapse(const Duration(seconds: 2));
    c.elegirLugar(CampoBusqueda.destino, destino);
    c.buscarViajes();
    async.elapse(const Duration(seconds: 2));
    final f = c.state.fase as FaseOpciones;
    expect(f.estado, EstadoOpciones.listo, reason: 'opciones a ${destino.id}');
    final id = f.opciones.firstWhere((o) => o.recomendada).id;
    c.enfocarOpcion(id);
    async.elapse(enOpciones);
    c.iniciarViaje(id);
    final limite = async.elapsed + const Duration(hours: 2);
    while (async.elapsed < limite) {
      async.elapse(const Duration(milliseconds: 50));
      final fase = c.state.fase;
      if (fase is FaseViaje && fase.estado == EstadoViaje.completado) break;
    }
    final fin = c.state.fase;
    expect(
      fin is FaseViaje && fin.estado == EstadoViaje.completado,
      isTrue,
      reason:
          'llega a ${destino.id}; últimos estados:\n'
          '${estados.skip(estados.length - 6).map((e) => resumenInstante(e, id)).join('\n')}',
    );
    alLlegar?.call(c, async);
    c.dispose();
  });
  return estados;
}

/// La espera (índice de tramo) cuyo bus se está mostrando, o null.
int? esperaVisible(AppState s) {
  final f = s.fase;
  if (f is FaseOpciones) return 1; // la vista previa sigue al primer bus
  if (f is! FaseViaje || f.estado != EstadoViaje.enCurso) return null;
  for (var i = f.pasoActual; i < f.totalPasos; i++) {
    final t = f.opcion.tramos[i];
    if (t is TramoBus) return null;
    if (t is TramoEsperar) return i;
  }
  return null;
}

BusEnCamino? busVisible(AppState s, String idOpcion) => switch (s.fase) {
  FaseOpciones(:final busesEnVivo) => busesEnVivo[idOpcion],
  FaseViaje(:final busEsperado) => busEsperado,
  _ => null,
};

/// Una línea legible de un estado (para entender un problema).
String resumenInstante(Instante i, String idOpcion) {
  final f = i.s.fase;
  final t = (i.real.inMilliseconds / 1000).toStringAsFixed(2);
  final bus = busVisible(i.s, idOpcion);
  final b =
      bus == null
          ? 'sin bus'
          : 'bus ${bus.minutos} min ${bus.metrosHastaParada} m';
  if (f is! FaseViaje) return '    t=${t}s ${f.runtimeType} $b';
  return '    t=${t}s paso ${f.pasoActual} (${f.tramoActual.runtimeType}) '
      'faltan ${f.progreso.metrosRestantes} m, $b, '
      'usuario ${f.usuario?.lat.toStringAsFixed(6)},${f.usuario?.lng.toStringAsFixed(6)}';
}
