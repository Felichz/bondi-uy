// La demo cuadro a cuadro, como la pinta el mapa: los estados que publica la
// lógica pasan por MovilesEscena (la predicción entre lecturas, los fundidos,
// los recorridos que nacen en cada marcador) a 60 cuadros por segundo, y cada
// cuadro se revisa contra lo que un visitante notaría:
// - un marcador que se ve entero (no fundiéndose) salta de un cuadro al otro;
// - el usuario retrocede por su camino, o el bus se aleja de su parada;
// - un recorrido no nace donde se ve su marcador.

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/logic/geo/geo.dart';
import 'package:bondi_uy/logic/simulacion/demo.dart';
import 'package:bondi_uy/ui/mapa/escena.dart';
import 'package:bondi_uy/ui/mapa/moviles.dart';
import 'package:flutter_test/flutter_test.dart';

import '../logica/recorrido_demo.dart';

const _cuadro = 1 / 60;
const _nada = Coordenada(0, 0);

/// Metros que faltan, por [camino], desde [c] hasta su final. Con [antes]
/// (lo que faltaba un cuadro atrás) se mide cerca de ahí: un camino que da
/// la vuelta pasa cerca de sí mismo y no se lo confunde con la otra vuelta.
double _faltan(List<Coordenada> camino, Coordenada c, double? antes) {
  final l = Polilinea(camino);
  final cerca = antes == null ? null : l.largo - antes;
  return l.largo -
      l
          .proyectar(
            c,
            desde: cerca == null ? null : cerca - 150,
            hasta: cerca == null ? null : cerca + 150,
          )
          .recorrido;
}

List<String> _problemas(List<Instante> estados, double velocidad) {
  final res = <String>[];
  void mal(double t, String que) {
    if (res.length < 40) res.add('t=${t.toStringAsFixed(2)}s: $que');
  }

  final moviles = MovilesEscena();
  // El más rápido de la escena (el bus), en metros por segundo real, con
  // margen para alcanzar una predicción atrasada (hasta tres veces su
  // velocidad un momento; más ya se ve como un tirón).
  final rapido = 8.3 * velocidad * 3.2;
  var i = 0;
  late AppState estado;
  late EscenaMapa escena;
  Coordenada? usuarioPrevio, busPrevio;
  double? faltabaUsuario, faltabaBus;
  Object? pasoPrevio;
  // Desde cuándo la lógica da al usuario en el mismo lugar.
  Coordenada? lecturaUsuario;
  var quietoDesde = 0.0;
  final inicio = estados.first.real.inMicroseconds / 1e6;
  final fin = estados.last.real.inMicroseconds / 1e6 + 2;
  for (var t = inicio; t <= fin; t += _cuadro) {
    var nueva = false;
    while (i < estados.length && estados[i].real.inMicroseconds / 1e6 <= t) {
      estado = estados[i].s;
      i++;
      nueva = true;
    }
    if (nueva) {
      escena = construirEscena(estado, const EstadoUiMapa());
      moviles.sincronizar(escena, t, fundir: true);
    }
    moviles.avanzar(t);
    final vista = moviles.mostrada(escena, t);
    final fase = estado.fase;
    final paso = fase is FaseViaje ? (fase.pasoActual, fase.estado) : fase;

    // La marca móvil vigente tal como se ve (las que se desvanecen van
    // antes en la lista), si se ve entera; y su camino (de la escena).
    MarcaMapa? enVista(bool Function(MarcaMapa) es) {
      final m = vista.marcas.lastWhere(es, orElse: () => const MarcaOrigen(_nada));
      if (m is MarcaOrigen) return null;
      return vista.opacidad(m) >= 0.999 ? m : null;
    }

    List<Coordenada>? camino(bool Function(MarcaMapa) es) {
      for (final m in escena.marcas) {
        if (es(m)) return m.camino;
      }
      return null;
    }

    bool esUsuario(MarcaMapa m) => m is MarcaUsuario || m is MarcaUsuarioEnBus;
    bool esBus(MarcaMapa m) => m is MarcaBus;

    // --- El usuario ---------------------------------------------------------
    final u = enVista(esUsuario);
    // Quieto (esperando el bus) un rato, se lo ve donde está: la predicción
    // no lo deja pasado de la parada.
    final lectura = fase is FaseViaje ? fase.usuario : null;
    if (lectura != lecturaUsuario) {
      lecturaUsuario = lectura;
      quietoDesde = t;
    }
    if (u != null &&
        lectura != null &&
        fase is FaseViaje &&
        fase.tramoActual is TramoEsperar &&
        t - quietoDesde > 1.5) {
      final d = distancia(u.coordenada, lectura);
      if (d > 3) {
        mal(t, 'esperando quieto, se lo ve a ${d.round()} m de donde está');
      }
    }
    if (u != null) {
      final c = u.coordenada;
      final p = usuarioPrevio;
      if (p != null) {
        final d = distancia(p, c);
        if (d > rapido * _cuadro + 1) {
          mal(t, 'el usuario salta ${d.round()} m en un cuadro');
        }
      }
      final cam = camino(esUsuario);
      final antes = paso == pasoPrevio ? faltabaUsuario : null;
      final falta =
          cam == null || cam.length < 2 ? null : _faltan(cam, c, antes);
      if (falta != null &&
          antes != null &&
          paso == pasoPrevio &&
          falta > antes + 1.5) {
        mal(t, 'el usuario retrocede ${(falta - antes).round()} m');
      }
      faltabaUsuario = falta;
      usuarioPrevio = c;
    } else {
      usuarioPrevio = null;
      faltabaUsuario = null;
    }

    // --- El bus que viene ---------------------------------------------------
    final b = enVista(esBus);
    if (b != null) {
      final c = b.coordenada;
      final p = busPrevio;
      if (p != null) {
        final d = distancia(p, c);
        if (d > rapido * _cuadro + 1) {
          mal(t, 'el bus salta ${d.round()} m en un cuadro');
        }
      }
      final cam = camino(esBus);
      final antes = faltabaBus;
      final falta =
          cam == null || cam.length < 2 ? null : _faltan(cam, c, antes);
      if (falta != null && antes != null && falta > antes + 1.5) {
        mal(t, 'el bus se aleja ${(falta - antes).round()} m de la parada');
      }
      faltabaBus = falta;
      busPrevio = c;
    } else {
      busPrevio = null;
      faltabaBus = null;
    }
    pasoPrevio = paso;

    // --- Los recorridos nacen en su marcador -------------------------------
    if (fase is FaseViaje && fase.estado == EstadoViaje.enCurso) {
      final actual = fase.tramoActual;
      for (final trazo in vista.trazos) {
        final marca = switch (trazo.estilo) {
          EstiloTrazo.caminar when actual is TramoCaminar => u,
          EstiloTrazo.bus when actual is TramoBus => u,
          EstiloTrazo.aproximacion => b,
          _ => null,
        };
        if (marca == null || trazo.puntos.length < 2) continue;
        final d = distancia(trazo.puntos.first, marca.coordenada);
        if (d > 3) {
          mal(
            t,
            'el recorrido (${trazo.estilo.name}) nace a ${d.round()} m '
            'de donde se ve su marcador',
          );
        }
      }
    }
  }
  return res;
}

void main() {
  for (final destino in destinosDemo) {
    for (final (velocidad, enOpciones) in [
      (15.0, Duration.zero),
      (15.0, const Duration(seconds: 40)),
      (30.0, const Duration(seconds: 20)),
      (5.0, const Duration(seconds: 3)),
    ]) {
      test(
        '${destino.id} a ${velocidad.round()}x, '
        '${enOpciones.inSeconds} s en opciones',
        () {
          final estados = recorrerDemo(
            destino: destino,
            velocidad: velocidad,
            enOpciones: enOpciones,
          );
          final p = _problemas(estados, velocidad);
          expect(
            p,
            isEmpty,
            reason: '${p.length} problemas:\n${p.take(15).join('\n')}',
          );
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    }
  }
}
