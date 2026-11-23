// La demo como la usa un visitante, viaje por viaje, mirando cómo se mueve
// todo: el bus que viene, el usuario y los recorridos que se dibujan.
//
// Cada estado que publica la lógica se revisa contra lo que un visitante
// notaría como un error:
// - el bus que viene se aleja de la parada o su espera crece;
// - el usuario salta o retrocede dentro de un paso;
// - el usuario se va de la parada sin el bus (o el bus se queda atrás);
// - un recorrido no nace en el usuario, va para atrás o corta una esquina;
// - no se dibuja lo que falta del paso.
//
// Se recorren los cinco destinos a la escala de la demo y a otras, saliendo enseguida o
// después de mirar las opciones un rato (el bus de la vista previa ya venía).

import 'dart:math' as math;

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/logic/geo/geo.dart';
import 'package:bondi_uy/logic/simulacion/demo.dart';
import 'package:bondi_uy/ui/mapa/escena.dart';
import 'package:flutter_test/flutter_test.dart';

import 'recorrido_demo.dart';

List<String> _problemas(List<Instante> todos) {
  // De varios estados publicados en el mismo instante, el visitante solo ve
  // el último (los demás no llegan a pintarse).
  final estados = [
    for (var n = 0; n < todos.length; n++)
      if (n == todos.length - 1 || todos[n + 1].real != todos[n].real) todos[n],
  ];
  final res = <String>[];
  late final String idOpcion;
  var contextos = 0;
  void mal(Instante i, String que) {
    final f = i.s.fase;
    final paso = f is FaseViaje ? 'paso ${f.pasoActual}' : f.runtimeType;
    res.add('t=${(i.real.inMilliseconds / 1000).toStringAsFixed(2)}s $paso: $que');
    // Los primeros problemas, con los estados que los preceden.
    if (contextos++ < 4) {
      final n = estados.indexOf(i);
      for (final e in estados.sublist(math.max(0, n - 4), n + 1)) {
        res.add(resumenInstante(e, idOpcion));
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

  // La vista previa, recién calculada, muestra un bus que se alcanza.
  for (final e in estados) {
    final f = e.s.fase;
    if (f is! FaseOpciones) continue;
    final o = f.opciones.where((o) => o.recomendada).firstOrNull;
    if (o?.proximoBus == null) continue;
    if (o!.aviso == AvisoOpcion.primerBusPuedeNoAlcanzar) {
      mal(e, 'la vista previa muestra un bus que no se alcanza '
          '(${o.proximoBus!.minutos} min)');
    }
    break;
  }

  Instante? previo;
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
    final espera = esperaVisible(s);
    final bus = busVisible(s, idOpcion);
    // Un bus solo deja su lugar al siguiente después de llegar a la parada
    // (si el usuario no lo tomó, viene el próximo, más lejos).
    final llego =
        busPrevio != null &&
        (busPrevio.minutos == 0 || (busPrevio.metrosHastaParada ?? 999) <= 30);
    // Esperando en la parada, el bus que llega se lo lleva: no llega y se va
    // sin él (dejándolo esperando al siguiente).
    if (f is FaseViaje &&
        f.tramoActual is TramoEsperar &&
        (f.progreso.metrosRestantes ?? 99) <= 15 &&
        bus != null &&
        llego &&
        espera == esperaPrevia &&
        (bus.minutos > busPrevio.minutos ||
            (bus.metrosHastaParada ?? 0) >
                (busPrevio.metrosHastaParada ?? 0) + 30)) {
      mal(i, 'el bus llegó y se fue sin el usuario (el próximo, en ${bus.minutos} min)');
    }
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
    // Un bus dibujado como llegando (0 min) está en la parada: no se aleja
    // solo con ese cartel (si lleva al usuario, se dibuja el usuario en él).
    // En la parada es a menos de 80 m: hay paradas a 60 m de su shape.
    if (t is TramoEsperar) {
      for (final m in escena.marcas.whereType<MarcaBus>()) {
        if (m.minutos != 0) continue;
        final aParada = distancia(m.coordenada, t.parada.coordenada);
        if (aParada > 80) {
          mal(
            i,
            'un bus dibujado como llegando está a ${aParada.round()} m de '
            'la parada',
          );
        }
      }
    }
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
  test('al cerrar la llegada, el usuario ya está en casa (no en el destino)', () {
    recorrerDemo(
      destino: destinosDemo.first,
      enOpciones: Duration.zero,
      alLlegar: (c, async) {
        c.cerrarLlegada();
        // Sin esperar la próxima lectura del GPS: la fase de explorar ya
        // nace con el usuario donde está (la cámara lo encuadra ahí).
        async.flushMicrotasks();
        expect(c.state.fase, isA<FaseExplorar>());
        final u = c.state.ubicacion.coordenada!;
        expect(distancia(u, casaDemo), lessThan(5));
      },
    );
  });

  for (final destino in destinosDemo) {
    for (final (escalas, enOpciones) in [
      // Como en la demo publicada.
      (const EscalasDemo(), Duration.zero),
      (const EscalasDemo(), const Duration(seconds: 6)),
      // El bus de la vista previa pasa antes de que el visitante arranque.
      (const EscalasDemo(), const Duration(seconds: 40)),
      // Más despacio: cada lectura cubre menos tiempo del mundo.
      (const EscalasDemo(caminar: 15, bus: 15), Duration.zero),
      (const EscalasDemo(caminar: 5, bus: 5), const Duration(seconds: 3)),
      (const EscalasDemo(caminar: 1, bus: 1), const Duration(seconds: 30)),
    ]) {
      test(
        '${destino.id} a ${escalas.caminar.round()}x hasta subir y '
        '${escalas.bus.round()}x en bus, ${enOpciones.inSeconds} s en opciones',
        () {
          final estados = recorrerDemo(
            destino: destino,
            escalas: escalas,
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
