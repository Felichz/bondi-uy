// The demo as a visitor uses it, trip by trip, watching how everything moves:
// the approaching bus, the user and the routes that are drawn.
//
// Each state the logic publishes is checked against what a visitor would
// notice as an error:
// - the approaching bus moves away from the stop, or its wait grows;
// - the user jumps or goes back within a step;
// - the user leaves the stop without the bus (or the bus is left behind);
// - a route does not start at the user, goes backwards or cuts a corner;
// - what is left of the step is not drawn.
//
// The five destinations are run through at the demo's scale and at others,
// leaving right away or after looking at the options for a while (the preview
// bus was already on its way).

import 'dart:math' as math;

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/logic/geo/geo.dart';
import 'package:bondi_uy/logic/simulation/demo.dart';
import 'package:bondi_uy/ui/map/scene.dart';
import 'package:flutter_test/flutter_test.dart';

import 'route_demo.dart';

List<String> _problems(List<Instant> all) {
  // Of several states published at the same instant, the visitor only sees
  // the last one (the others never get painted).
  final states = [
    for (var n = 0; n < all.length; n++)
      if (n == all.length - 1 || all[n + 1].real != all[n].real) all[n],
  ];
  final res = <String>[];
  late final String idOption;
  var contexts = 0;
  void bad(Instant i, String that) {
    final f = i.s.phase;
    final step = f is TripPhase ? 'step ${f.currentStep}' : f.runtimeType;
    res.add(
      't=${(i.real.inMilliseconds / 1000).toStringAsFixed(2)}s $step: $that',
    );
    // The first problems, with the states that precede them.
    if (contexts++ < 4) {
      final n = states.indexOf(i);
      for (final e in states.sublist(math.max(0, n - 4), n + 1)) {
        res.add(summaryInstant(e, idOption));
      }
    }
  }

  idOption =
      states.map((e) => e.s.phase).whereType<TripPhase>().first.option.id;

  // The preview, just calculated, shows a bus that can be caught.
  for (final e in states) {
    final f = e.s.phase;
    if (f is! OptionsPhase) continue;
    final o = f.options.where((o) => o.recommended).firstOrNull;
    if (o?.nextBus == null) continue;
    if (o!.notice == NoticeOption.firstBusMayNotReach) {
      bad(
        e,
        'the preview shows a bus that cannot be caught '
        '(${o.nextBus!.minutes} min)',
      );
    }
    break;
  }

  Instant? previous;
  // The last distinct GPS sample (a state can repeat the previous sample: it
  // was published by a bus poll, not by the GPS).
  (Coordinate, DateTime)? samplePrevious;
  BusInPath? busPrevious;
  int? waitPrevious;
  for (final i in states) {
    final s = i.s;
    final f = s.phase;
    final p = previous;
    previous = i;

    // --- The approaching bus ---------------------------------------------------
    final wait = waitVisible(s);
    final bus = busVisible(s, idOption);
    // A bus only gives up its place to the next one after it reaches the stop
    // (if the user did not take it, the next one comes, further away).
    final arrived =
        busPrevious != null &&
        (busPrevious.minutes == 0 ||
            (busPrevious.metersUntilStop ?? 999) <= 30);
    // Waiting at the stop, the bus that arrives takes the user along: it must
    // not arrive and leave without them (leaving them waiting for the next one).
    if (f is TripPhase &&
        f.currentLeg is WaitLeg &&
        (f.progress.metersLeft ?? 99) <= 15 &&
        bus != null &&
        arrived &&
        wait == waitPrevious &&
        (bus.minutes > busPrevious.minutes ||
            (bus.metersUntilStop ?? 0) >
                (busPrevious.metersUntilStop ?? 0) + 30)) {
      bad(
        i,
        'the bus arrived and left without the user (the next one, in ${bus.minutes} min)',
      );
    }
    if (bus != null &&
        busPrevious != null &&
        wait == waitPrevious &&
        !arrived) {
      final m0 = busPrevious.metersUntilStop, m1 = bus.metersUntilStop;
      if (m0 != null && m1 != null && m1 > m0 + 5) {
        bad(i, 'the bus moves away from the stop: $m0 m -> $m1 m');
      }
      if (bus.minutes > busPrevious.minutes) {
        bad(i, 'the wait grows: ${busPrevious.minutes} -> ${bus.minutes} min');
      }
    }
    if (bus != null) {
      busPrevious = bus;
      waitPrevious = wait;
    } else if (wait != waitPrevious) {
      busPrevious = null;
    }

    if (f is! TripPhase || f.status != TripStatus.inProgress) continue;
    final me = f.user;
    if (me == null) continue;

    // --- The user ---------------------------------------------------------
    final mp = samplePrevious;
    if (mp == null || mp.$1 != me) {
      if (mp != null) {
        final dt = i.sim.difference(mp.$2).inMilliseconds / 1000;
        final d = distance(mp.$1, me);
        if (d > 9 * dt + 5) {
          bad(i, 'the user jumps ${d.round()} m in ${dt.toStringAsFixed(1)} s');
        }
      }
      samplePrevious = (me, i.sim);
    }
    final fp = p?.s.phase;
    if (p != null && fp is TripPhase && fp.user != null) {
      final r0 = fp.progress.metersLeft, r1 = f.progress.metersLeft;
      final sameStep = fp.currentStep == f.currentStep;
      if (sameStep &&
          f.currentLeg is! WaitLeg &&
          r0 != null &&
          r1 != null &&
          r1 > r0 + 3) {
        bad(i, 'the user goes back in their step: $r0 m were left, now $r1 m');
      }
    }

    final scene = buildScene(s, const MapUiStatus());
    final t = f.currentLeg;

    // --- Getting on the bus -------------------------------------------------------
    // A bus drawn as arriving (0 min) is at the stop: it does not move away
    // just because of that label (if it carries the user, the user is drawn on
    // it). "At the stop" means less than 80 m: some stops are 60 m from their shape.
    if (t is WaitLeg) {
      for (final m in scene.marks.whereType<MarkerBus>()) {
        if (m.minutes != 0) continue;
        final toStop = distance(m.coordinate, t.stop.coordinate);
        if (toStop > 80) {
          bad(
            i,
            'a bus drawn as arriving is ${toStop.round()} m from '
            'the stop',
          );
        }
      }
    }
    if (t is WaitLeg) {
      final far = f.progress.metersLeft ?? 0;
      final onFoot = scene.marks.any((m) => m is MarkerUser);
      if (far > 25 && onFoot) {
        bad(i, 'leaves the stop ($far m) on foot, without their bus');
      }
    }
    if (t is BusLeg && scene.marks.any((m) => m is MarkerBus)) {
      bad(i, 'on board the bus, another incoming bus is drawn');
    }

    // --- The routes that are drawn -------------------------------------
    final geo = switch (t) {
      WalkLeg(:final geometry) => geometry,
      BusLeg(:final geometry) => geometry,
      WaitLeg() => null,
    };
    if (geo == null || geo.length < 2) continue;
    final line = Polyline(geo);
    final ru = line.project(me).route;
    final active = t is BusLeg ? StrokeStyle.bus : StrokeStyle.walk;
    // What is left (in color) covers everything ahead of the user: if it is
    // not there, what is done (gray) would be visible ahead.
    if (!scene.strokes.any((x) => x.style == active) &&
        (f.progress.metersLeft ?? 0) > 30) {
      bad(i, 'the rest of the step is not drawn');
    }
    for (final stroke in scene.strokes) {
      if (stroke.style != active || stroke.points.length < 2) continue;
      final a = stroke.points.first;
      if (distance(a, me) > 5) {
        bad(i, 'the route starts ${distance(a, me).round()} m from the user');
      }
      final b = stroke.points[1];
      final rb = line.project(b).route;
      if (rb < ru - 5) {
        bad(i, 'the route starts backwards (${(ru - rb).round()} m)');
      }
      final string = distance(a, b);
      if (string > math.max(0, rb - ru) + 15) {
        bad(
          i,
          'the route cuts corners: ${string.round()} m in a straight line '
          'for ${(rb - ru).round()} m of street',
        );
      }
    }
  }
  return res;
}

void main() {
  test(
    'after closing the arrival, the user is already home (not at the destination)',
    () {
      traverseDemo(
        destination: destinationsDemo.first,
        inOptions: Duration.zero,
        onArrive: (c, async) {
          c.closeArrival();
          // Without waiting for the next GPS reading: the explore phase already
          // starts with the user where they are (the camera frames them there).
          async.flushMicrotasks();
          expect(c.state.phase, isA<ExplorePhase>());
          final u = c.state.location.coordinate!;
          expect(distance(u, houseDemo), lessThan(5));
        },
      );
    },
  );

  for (final destination in destinationsDemo) {
    for (final (scales, inOptions) in [
      // As in the published demo.
      (const DemoScales(), Duration.zero),
      (const DemoScales(), const Duration(seconds: 6)),
      // The preview bus passes before the visitor starts.
      (const DemoScales(), const Duration(seconds: 40)),
      // Slower: each reading covers less of the world's time.
      (const DemoScales(walk: 15, bus: 15), Duration.zero),
      (const DemoScales(walk: 5, bus: 5), const Duration(seconds: 3)),
      (const DemoScales(walk: 1, bus: 1), const Duration(seconds: 30)),
    ]) {
      test(
        '${destination.id} at ${scales.walk.round()}x until boarding and '
        '${scales.bus.round()}x on the bus, ${inOptions.inSeconds} s in options',
        () {
          final states = traverseDemo(
            destination: destination,
            scales: scales,
            inOptions: inOptions,
          );
          final p = _problems(states);
          expect(
            p,
            isEmpty,
            reason: '${p.length} problems:\n${p.take(12).join('\n')}',
          );
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    }
  }
}
