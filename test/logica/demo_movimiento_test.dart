// La demo como la usa un visitante, viaje por viaje, mirando cómo se mueve
// todo: el bus que viene, el usuario y los recorridos que se dibujan.
//
// Cada estado que publica la lógica se revisa contra lo que un visitante
// notaría como un error:
// - el bus que viene se aleja de la parada o su espera crece;
// - el usuario salta o retrocede dentro de un paso;
// - el usuario se va de la parada sin el bus (o el bus se queda atrás);
// - un recorrido no nace en el usuario, va para atrás o corta una esquina;
// - lo hecho (gris) se dibuja por delante del usuario.
//
// Se recorren los cinco destinos a varias velocidades, saliendo enseguida o
// después de mirar las opciones un rato (el bus de la vista previa ya venía).

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/logic/geo/geo.dart';
import 'package:bondi_uy/logic/servicios/catalogo_assets.dart';
import 'package:bondi_uy/logic/simulacion/demo.dart';
import 'package:bondi_uy/logic/simulacion/mundo_simulado.dart';
import 'package:bondi_uy/ui/mapa/escena.dart';
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
class _Instante {
  final Duration real;
  final DateTime sim;
  final AppState s;
  _Instante(this.real, this.sim, this.s);
}

List<_Instante> _ultimos = [];

/// Un viaje de la demo de punta a punta.
List<_Instante> _recorrer({
  required Lugar destino,
  required double velocidad,
  required Duration enOpciones,
}) {
  late List<_Instante> estados;
  fakeAsync((async) {
    _ultimos = estados = [];
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
      (s) => estados.add(_Instante(async.elapsed, mundo.ahora(), s)),
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
          '${estados.skip(estados.length - 6).map((e) => _resumen(e, id)).join('\n')}',
    );
    c.dispose();
  });
  return estados;
}

/// La espera (índice de tramo) cuyo bus se está mostrando, o null.
int? _esperaVisible(AppState s) {
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

BusEnCamino? _busVisible(AppState s, String idOpcion) => switch (s.fase) {
  FaseOpciones(:final busesEnVivo) => busesEnVivo[idOpcion],
  FaseViaje(:final busEsperado) => busEsperado,
  _ => null,
};

/// Una línea legible de un estado (para entender un problema).
String _resumen(_Instante i, String idOpcion) {
  final f = i.s.fase;
  final t = (i.real.inMilliseconds / 1000).toStringAsFixed(2);
  final bus = _busVisible(i.s, idOpcion);
  final b =
      bus == null
          ? 'sin bus'
          : 'bus ${bus.minutos} min ${bus.metrosHastaParada} m';
  if (f is! FaseViaje) return '    t=${t}s ${f.runtimeType} $b';
  return '    t=${t}s paso ${f.pasoActual} (${f.tramoActual.runtimeType}) '
      'faltan ${f.progreso.metrosRestantes} m, $b, '
      'usuario ${f.usuario?.lat.toStringAsFixed(6)},${f.usuario?.lng.toStringAsFixed(6)}';
}

List<String> _problemas(List<_Instante> todos) {
  // De varios estados publicados en el mismo instante, el visitante solo ve
  // el último (los demás no llegan a pintarse).
  final estados = [
    for (var n = 0; n < todos.length; n++)
      if (n == todos.length - 1 || todos[n + 1].real != todos[n].real) todos[n],
  ];
  final res = <String>[];
  late final String idOpcion;
  var contextos = 0;
  void mal(_Instante i, String que) {
    final f = i.s.fase;
    final paso = f is FaseViaje ? 'paso ${f.pasoActual}' : f.runtimeType;
    res.add('t=${(i.real.inMilliseconds / 1000).toStringAsFixed(2)}s $paso: $que');
    // Los primeros problemas, con los estados que los preceden.
    if (contextos++ < 4) {
      final n = estados.indexOf(i);
      for (final e in estados.sublist(math.max(0, n - 4), n + 1)) {
        res.add(_resumen(e, idOpcion));
      }
    }
  }

  idOpcion =
      estados
          .map((e) => e.s.fase)
          .whereType<FaseViaje>()
          .first
          .opcion
          .id;

  _Instante? previo;
  // La última muestra de GPS distinta (un estado puede repetir la muestra
  // anterior: lo publicó un sondeo del bus, no el GPS).
  (Coordenada, DateTime)? muestraPrevia;
  BusEnCamino? busPrevio;
  int? esperaPrevia;
  for (final i in estados) {
    final s = i.s;
    final f = s.fase;
    final p = previo;
    previo = i;

    // --- El bus que viene ---------------------------------------------------
    final espera = _esperaVisible(s);
    final bus = _busVisible(s, idOpcion);
    // Un bus solo deja su lugar al siguiente después de llegar a la parada
    // (si el usuario no lo tomó, viene el próximo, más lejos).
    final llego =
        busPrevio != null &&
        (busPrevio.minutos == 0 || (busPrevio.metrosHastaParada ?? 999) <= 30);
    if (bus != null && busPrevio != null && espera == esperaPrevia && !llego) {
      final m0 = busPrevio.metrosHastaParada, m1 = bus.metrosHastaParada;
      if (m0 != null && m1 != null && m1 > m0 + 5) {
        mal(i, 'el bus se aleja de la parada: $m0 m -> $m1 m');
      }
      if (bus.minutos > busPrevio.minutos) {
        mal(i, 'la espera crece: ${busPrevio.minutos} -> ${bus.minutos} min');
      }
    }
    if (bus != null) {
      busPrevio = bus;
      esperaPrevia = espera;
    } else if (espera != esperaPrevia) {
      busPrevio = null;
    }

    if (f is! FaseViaje || f.estado != EstadoViaje.enCurso) continue;
    final yo = f.usuario;
    if (yo == null) continue;

    // --- El usuario ---------------------------------------------------------
    final mp = muestraPrevia;
    if (mp == null || mp.$1 != yo) {
      if (mp != null) {
        final dt = i.sim.difference(mp.$2).inMilliseconds / 1000;
        final d = distancia(mp.$1, yo);
        if (d > 9 * dt + 5) {
          mal(i, 'el usuario salta ${d.round()} m en ${dt.toStringAsFixed(1)} s');
        }
      }
      muestraPrevia = (yo, i.sim);
    }
    final fp = p?.s.fase;
    if (p != null && fp is FaseViaje && fp.usuario != null) {
      final r0 = fp.progreso.metrosRestantes, r1 = f.progreso.metrosRestantes;
      final mismoPaso = fp.pasoActual == f.pasoActual;
      if (mismoPaso &&
          f.tramoActual is! TramoEsperar &&
          r0 != null &&
          r1 != null &&
          r1 > r0 + 3) {
        mal(i, 'el usuario retrocede en su paso: le faltaban $r0 m, ahora $r1 m');
      }
    }

    final escena = construirEscena(s, const EstadoUiMapa());
    final t = f.tramoActual;

    // --- Subir al bus -------------------------------------------------------
    if (t is TramoEsperar) {
      final lejos = f.progreso.metrosRestantes ?? 0;
      final aPie = escena.marcas.any((m) => m is MarcaUsuario);
      if (lejos > 25 && aPie) {
        mal(i, 'se va de la parada ($lejos m) a pie, sin su bus');
      }
    }
    if (t is TramoBus && escena.marcas.any((m) => m is MarcaBus)) {
      mal(i, 'arriba del bus se dibuja otro bus que viene');
    }

    // --- Los recorridos que se dibujan -------------------------------------
    final geo = switch (t) {
      TramoCaminar(:final geometria) => geometria,
      TramoBus(:final geometria) => geometria,
      TramoEsperar() => null,
    };
    if (geo == null || geo.length < 2) continue;
    final linea = Polilinea(geo);
    final ru = linea.proyectar(yo).recorrido;
    final activo = t is TramoBus ? EstiloTrazo.bus : EstiloTrazo.caminar;
    // Lo que falta (en color) tapa todo lo que está por delante del usuario:
    // si no está, lo hecho (gris) quedaría a la vista por delante.
    if (!escena.trazos.any((x) => x.estilo == activo) &&
        (f.progreso.metrosRestantes ?? 0) > 30) {
      mal(i, 'no se dibuja lo que falta del paso');
    }
    for (final trazo in escena.trazos) {
      if (trazo.estilo != activo || trazo.puntos.length < 2) continue;
      final a = trazo.puntos.first;
      if (distancia(a, yo) > 5) {
        mal(i, 'el recorrido nace a ${distancia(a, yo).round()} m del usuario');
      }
      final b = trazo.puntos[1];
      final rb = linea.proyectar(b).recorrido;
      if (rb < ru - 5) {
        mal(i, 'el recorrido arranca para atrás (${(ru - rb).round()} m)');
      }
      final cuerda = distancia(a, b);
      if (cuerda > math.max(0, rb - ru) + 15) {
        mal(
          i,
          'el recorrido corta camino: ${cuerda.round()} m en línea recta '
          'para ${(rb - ru).round()} m de calle',
        );
      }
    }
  }
  return res;
}

void main() {
  for (final destino in destinosDemo) {
    for (final (velocidad, enOpciones) in [
      (15.0, Duration.zero),
      (15.0, const Duration(seconds: 6)),
      // El bus de la vista previa pasa antes de que el visitante arranque.
      (15.0, const Duration(seconds: 40)),
      (30.0, const Duration(seconds: 20)),
      (5.0, const Duration(seconds: 3)),
      // En tiempo real cada sondeo cubre poco tiempo del mundo.
      (1.0, const Duration(seconds: 30)),
    ]) {
      test(
        '${destino.id} a ${velocidad.round()}x, '
        '${enOpciones.inSeconds} s en opciones',
        () {
          final estados = _recorrer(
            destino: destino,
            velocidad: velocidad,
            enOpciones: enOpciones,
          );
          final p = _problemas(estados);
          expect(
            p,
            isEmpty,
            reason: '${p.length} problemas:\n${p.take(12).join('\n')}',
          );
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    }
  }
}

/// Para depurar un caso desde otro archivo de test.
List<_Instante> recorrerParaDepurar(String id, double velocidad, Duration enOpciones) {
  try {
    return _recorrer(
      destino: destinosDemo.firstWhere((l) => l.id == id),
      velocidad: velocidad,
      enOpciones: enOpciones,
    );
  } on TestFailure {
    return _ultimos;
  }
}
