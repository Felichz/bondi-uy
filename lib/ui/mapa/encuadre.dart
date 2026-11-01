// Qué debe mostrar la cámara en cada momento del flujo (concern de UI).
//
// Cada momento enfoca un GRUPO de elementos (la especificación de la versión
// anterior, old/v2/test/devtools/CAMERA_BEHAVIOR_SPEC.md):
//
// - Opciones: el viaje entero (y el bus en vivo si aparece).
// - Caminar a la parada: vos + lo que falta caminar + la parada; ya cerca de
//   la parada (60 m), también el bus si llega en 5 min o menos y el conjunto
//   se sigue leyendo. Mientras tanto el bus se señala en el borde.
// - Esperar: la parada + el bus + vos (el zoom se cierra a medida que el bus
//   se acerca).
// - En el bus: vos + las próximas paradas; cerca del final, la bajada. (No
//   el recorrido entero: sería alejarse 20 km.)
// - Caminar al destino: vos + lo que falta caminar + el destino.
//
// En viaje el encuadre se recalcula cuadro a cuadro con las posiciones
// predichas del usuario y del bus, así acompaña sin saltos. Si el grupo no
// entra con el zoom mínimo, manda el usuario ([Encuadre.ancla]): la cámara se
// corre hacia el grupo sin dejarlo fuera de la vista.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../contract/app_state.dart';
import 'escena.dart';

/// Cómo acompaña la cámara a un encuadre mientras el estado cambia.
enum Seguimiento {
  /// Encuadra una vez al cambiar la [Encuadre.clave].
  ninguno,

  /// Re-encuadra solo si algún punto se sale de la vista (opciones).
  siSeSale,

  /// Re-encuadra de forma continua y suave (viaje).
  continuo,
}

/// Marcadores móviles que un encuadre puede incluir (su posición la sabe el
/// mapa, que la predice entre lecturas).
abstract final class Moviles {
  static const usuario = 'usuario';
  static const bus = 'bus';
}

@immutable
class Encuadre {
  /// Cambia cuando el contexto cambia (fase, opción, paso): la cámara vuelve
  /// a encuadrar aunque el usuario la haya movido.
  final String clave;

  /// Puntos fijos del grupo (paradas, recorridos, destino).
  final List<Coordenada> puntos;

  /// Marcadores móviles del grupo ([Moviles]).
  final Set<String> moviles;

  /// Móviles deseables: entran si el grupo sigue siendo legible (zoom
  /// [zoomExtras] o más); si no, se enfoca lo esencial.
  final Set<String> extras;
  final double zoomExtras;

  /// El móvil que nunca puede quedar fuera de la vista.
  final String? ancla;
  final Seguimiento seguimiento;
  final double zoomMax;

  /// Zoom mínimo con [ancla]: si el grupo no entra, se prioriza ver bien al
  /// ancla (un indicador de borde señala lo que quedó afuera).
  final double zoomMin;

  /// Si el usuario movió el mapa, la cámara vuelve sola tras este tiempo sin
  /// tocarlo (solo en viaje: nadie debería perder el hilo de su viaje).
  final Duration? reanudarTras;

  const Encuadre({
    required this.clave,
    required this.puntos,
    this.moviles = const {},
    this.extras = const {},
    this.zoomExtras = 14.5,
    this.ancla,
    this.seguimiento = Seguimiento.ninguno,
    this.zoomMax = 17,
    this.zoomMin = 10,
    this.reanudarTras,
  });
}

const _reanudarViaje = Duration(seconds: 12);

/// Un bus a esta distancia en minutos (o menos) entra en el encuadre de la
/// caminata a la parada...
const minutosBusCercano = 5;

/// ...recién cuando al usuario le faltan estos metros para la parada. Antes,
/// lo importante es el camino; el bus se señala en el borde de la pantalla.
const metrosParaVerElBus = 60;

Encuadre? encuadreDe(AppState s, EstadoUiMapa ui) {
  final usuario = s.ubicacion.coordenada;
  switch (s.fase) {
    case FaseExplorar():
      final p = s.paradaConsultada;
      if (p != null) {
        return Encuadre(
          clave: 'parada-${p.parada.id}',
          puntos: [p.parada.coordenada],
        );
      }
      if (usuario != null) {
        return Encuadre(clave: 'explorar', puntos: [usuario], zoomMax: 16);
      }
      return null;

    case final FaseOpciones f:
      if (f.opciones.isEmpty) {
        final pts = [
          if (f.origen != null) f.origen!,
          if (f.destino != null) f.destino!,
        ];
        return pts.isEmpty
            ? null
            : Encuadre(clave: 'opciones-${f.estado.name}', puntos: pts);
      }
      final o = f.opciones.firstWhere(
        (o) => o.id == ui.opcionEnfocada,
        orElse:
            () => f.opciones.firstWhere(
              (o) => o.recomendada,
              orElse: () => f.opciones.first,
            ),
      );
      return Encuadre(
        clave: 'opcion-${o.id}',
        // Si aparece el bus en vivo fuera de la vista, se re-encuadra.
        seguimiento: Seguimiento.siSeSale,
        puntos: [
          ..._puntosOpcion(o),
          if (f.busesEnVivo[o.id]?.posicion case final b?) b,
        ],
      );

    case final FaseViaje f:
      final pos = f.usuario ?? usuario;
      if (f.estado == EstadoViaje.completado) {
        return Encuadre(
          clave: 'llegada',
          puntos: [_fin(f.opcion), if (pos != null) pos],
          zoomMax: 17,
        );
      }
      final t = f.tramoActual;
      final clave = 'paso-${f.pasoActual}';
      final conUsuario = pos != null;
      Encuadre viaje(
        List<Coordenada> puntos, {
        Set<String> moviles = const {},
        Set<String> extras = const {},
        required double zoomMin,
        required double zoomMax,
      }) => Encuadre(
        clave: clave,
        puntos: [...puntos, if (!conUsuario && puntos.isEmpty) _fin(f.opcion)],
        moviles: {if (conUsuario) Moviles.usuario, ...moviles},
        extras: extras,
        ancla: conUsuario ? Moviles.usuario : null,
        seguimiento: Seguimiento.continuo,
        zoomMin: zoomMin,
        zoomMax: zoomMax,
        reanudarTras: _reanudarViaje,
      );
      switch (t) {
        case TramoCaminar():
          final bus = f.busEsperado;
          final resto = f.progreso.metrosRestantes;
          final busCerca =
              !t.esAlDestino &&
              resto != null &&
              resto <= metrosParaVerElBus &&
              bus?.posicion != null &&
              bus!.minutos <= minutosBusCercano;
          return viaje(
            [..._muestrear(f.progreso.recorridoRestante ?? t.geometria), t.fin],
            extras: {if (busCerca) Moviles.bus},
            zoomMin: 15,
            zoomMax: 17.5,
          );
        case TramoEsperar():
          // Además, el comienzo del recorrido del bus: cuando el bus llega y
          // deja de "venir", el encuadre no se derrumba sobre la parada, y ya
          // se parece al del paso siguiente (la subida no pega dos saltos).
          final siguiente =
              f.pasoActual + 1 < f.totalPasos
                  ? f.opcion.tramos[f.pasoActual + 1]
                  : null;
          return viaje(
            [
              t.parada.coordenada,
              if (siguiente is TramoBus)
                ..._primerosMetros(siguiente.geometria, 350),
            ],
            moviles: {if (f.busEsperado?.posicion != null) Moviles.bus},
            zoomMin: 14,
            zoomMax: 17,
          );
        case TramoBus():
          final faltan = f.progreso.paradasRestantes;
          final proxima = f.progreso.proximaParada ?? t.bajada;
          final i = t.paradasIntermedias.indexWhere((p) => p.id == proxima.id);
          final siguiente =
              i >= 0 && i + 1 < t.paradasIntermedias.length
                  ? t.paradasIntermedias[i + 1]
                  : null;
          return viaje(
            [
              proxima.coordenada,
              if (siguiente != null) siguiente.coordenada,
              if (faltan != null && faltan <= 3) t.bajada.coordenada,
            ],
            zoomMin: 14.5,
            zoomMax: 17,
          );
      }
  }
}

List<Coordenada> _puntosOpcion(OpcionViaje o) => [
  for (final t in o.tramos)
    ...switch (t) {
      TramoCaminar(:final geometria) => _muestrear(geometria),
      TramoBus(:final geometria) => _muestrear(geometria),
      TramoEsperar(:final parada) => [parada.coordenada],
    },
];

/// Los primeros [metros] de [g] (aproximación plana, alcanza a esta escala).
List<Coordenada> _primerosMetros(List<Coordenada> g, double metros) {
  final r = <Coordenada>[g.first];
  var total = 0.0;
  for (var i = 1; i < g.length && total < metros; i++) {
    final dy = (g[i].lat - g[i - 1].lat) * 111320;
    final dx = (g[i].lng - g[i - 1].lng) * 111320 * 0.82;
    total += math.sqrt(dx * dx + dy * dy);
    r.add(g[i]);
  }
  return r;
}

List<Coordenada> _muestrear(List<Coordenada> g) {
  if (g.length <= 20) return g;
  final paso = g.length ~/ 20;
  return [for (var i = 0; i < g.length; i += paso) g[i], g.last];
}

Coordenada _fin(OpcionViaje o) => switch (o.tramos.last) {
  TramoCaminar(:final fin) => fin,
  TramoBus(:final bajada) => bajada.coordenada,
  TramoEsperar(:final parada) => parada.coordenada,
};
