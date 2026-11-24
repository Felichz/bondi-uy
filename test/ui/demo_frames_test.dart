// The demo frame by frame, as the map paints it: the states the logic publishes go
// through MovilesEscena (prediction between readings, fades, the routes that start at
// each marker) at 60 frames per second, and every frame is checked against what a
// visitor would notice:
// - a marker that is fully visible (not fading) jumps from one frame to the next;
// - the user goes back along their path, or the bus moves away from its stop;
// - a route does not start where its marker is seen.

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/logic/geo/geo.dart';
import 'package:bondi_uy/logic/simulation/demo.dart';
import 'package:bondi_uy/ui/map/scene.dart';
import 'package:bondi_uy/ui/map/vehicles.dart';
import 'package:flutter_test/flutter_test.dart';

import '../logic/route_demo.dart';

const _cuadro = 1 / 60;
const _nothing = Coordinate(0, 0);

/// Meters left, along [path], from [c] to its end. With [antes]
/// (what was left one frame earlier) it is measured near there: a path that loops
/// comes close to itself and must not be confused with the other loop.
double _missing(List<Coordinate> path, Coordinate c, double? antes) {
  final l = Polyline(path);
  final near = antes == null ? null : l.long - antes;
  return l.long -
      l
          .project(
            c,
            from: near == null ? null : near - 150,
            until: near == null ? null : near + 150,
          )
          .route;
}

List<String> _problems(List<Instant> states, DemoScales scales) {
  final res = <String>[];
  void mal(double t, String that) {
    if (res.length < 40) res.add('t=${t.toStringAsFixed(2)}s: $that');
  }

  final vehicles = VehiclesScene();
  // The fastest thing in the scene (the bus), in real meters per second, with
  // margin to catch up with a late prediction (up to three times its
  // speed for a moment; more already looks like a jerk).
  final fast =
      8.3 * (scales.bus > scales.walk ? scales.bus : scales.walk) * 3.2;
  var i = 0;
  late AppState status;
  late MapScene scene;
  Coordinate? userPrevious, busPrevious;
  double? missingUser, missingBus;
  Object? stepPrevious;
  // Since when the logic has placed the user in the same spot.
  Coordinate? readingUser;
  var stillFrom = 0.0;
  final inicio = states.first.real.inMicroseconds / 1e6;
  final fin = states.last.real.inMicroseconds / 1e6 + 2;
  for (var t = inicio; t <= fin; t += _cuadro) {
    var fresh = false;
    while (i < states.length && states[i].real.inMicroseconds / 1e6 <= t) {
      status = states[i].s;
      i++;
      fresh = true;
    }
    if (fresh) {
      scene = buildScene(status, const MapUiStatus());
      vehicles.synchronize(scene, t, fuse: true);
    }
    vehicles.advance(t);
    final view = vehicles.shown(scene, t);
    final phase = status.phase;
    final step = phase is TripPhase ? (phase.stepActual, phase.status) : phase;

    // The moving marker in effect as it is seen (those fading out come
    // first in the list), if it is fully visible; and its path (from the scene).
    MapMarker? inView(bool Function(MapMarker) es) {
      final m = view.marks.lastWhere(
        es,
        orElse: () => const MarkerOrigin(_nothing),
      );
      if (m is MarkerOrigin) return null;
      return view.opacity(m) >= 0.999 ? m : null;
    }

    List<Coordinate>? path(bool Function(MapMarker) es) {
      for (final m in scene.marks) {
        if (es(m)) return m.path;
      }
      return null;
    }

    bool isUser(MapMarker m) => m is MarkerUser || m is MarkerUserInBus;
    bool esBus(MapMarker m) => m is MarkerBus;

    // --- The user ---------------------------------------------------------
    final u = inView(isUser);
    // Standing still (waiting for the bus) for a while, they are seen where they are:
    // the prediction does not let them move past the stop.
    final reading = phase is TripPhase ? phase.user : null;
    if (reading != readingUser) {
      readingUser = reading;
      stillFrom = t;
    }
    if (u != null &&
        reading != null &&
        phase is TripPhase &&
        phase.legActual is WaitLeg &&
        t - stillFrom > 1.5) {
      final d = distance(u.coordinate, reading);
      if (d > 3) {
        mal(t, 'esperando quieto, se lo ve a ${d.round()} m de donde está');
      }
    }
    if (u != null) {
      final c = u.coordinate;
      final p = userPrevious;
      if (p != null) {
        final d = distance(p, c);
        if (d > fast * _cuadro + 1) {
          mal(t, 'el usuario salta ${d.round()} m en un cuadro');
        }
      }
      final cam = path(isUser);
      final antes = step == stepPrevious ? missingUser : null;
      final missing =
          cam == null || cam.length < 2 ? null : _missing(cam, c, antes);
      if (missing != null &&
          antes != null &&
          step == stepPrevious &&
          missing > antes + 1.5) {
        mal(t, 'el usuario retrocede ${(missing - antes).round()} m');
      }
      missingUser = missing;
      userPrevious = c;
    } else {
      userPrevious = null;
      missingUser = null;
    }

    // --- The incoming bus ---------------------------------------------------
    final b = inView(esBus);
    if (b != null) {
      final c = b.coordinate;
      final p = busPrevious;
      if (p != null) {
        final d = distance(p, c);
        if (d > fast * _cuadro + 1) {
          mal(t, 'el bus salta ${d.round()} m en un cuadro');
        }
      }
      final cam = path(esBus);
      final antes = missingBus;
      final missing =
          cam == null || cam.length < 2 ? null : _missing(cam, c, antes);
      if (missing != null && antes != null && missing > antes + 1.5) {
        mal(t, 'el bus se aleja ${(missing - antes).round()} m de la parada');
      }
      missingBus = missing;
      busPrevious = c;
    } else {
      busPrevious = null;
      missingBus = null;
    }
    stepPrevious = step;

    // --- Routes start at their marker -------------------------------
    if (phase is TripPhase && phase.status == TripStatus.inProgress) {
      final actual = phase.legActual;
      for (final stroke in view.strokes) {
        final marker = switch (stroke.style) {
          StrokeStyle.walk when actual is WalkLeg => u,
          StrokeStyle.bus when actual is BusLeg => u,
          StrokeStyle.approximation => b,
          _ => null,
        };
        if (marker == null || stroke.points.length < 2) continue;
        final d = distance(stroke.points.first, marker.coordinate);
        if (d > 3) {
          mal(
            t,
            'el recorrido (${stroke.style.name}) nace a ${d.round()} m '
            'de donde se ve su marcador',
          );
        }
      }
    }
  }
  return res;
}

void main() {
  for (final destination in destinationsDemo) {
    for (final (scales, inOptions) in [
      (const DemoScales(), Duration.zero),
      (const DemoScales(), const Duration(seconds: 40)),
      (const DemoScales(walk: 15, bus: 15), Duration.zero),
      (const DemoScales(walk: 5, bus: 5), const Duration(seconds: 3)),
    ]) {
      test(
        '${destination.id} a ${scales.walk.round()}x hasta subir y '
        '${scales.bus.round()}x en bus, ${inOptions.inSeconds} s en opciones',
        () {
          final states = traverseDemo(
            destination: destination,
            scales: scales,
            inOptions: inOptions,
          );
          final p = _problems(states, scales);
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
