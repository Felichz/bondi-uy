import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/logic/geo/geo.dart';
import 'package:bondi_uy/logic/ports.dart';
import 'package:bondi_uy/logic/trip/trip_navigator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

/// Replays the recorded samples and returns the trace of steps.
({List<int> steps, bool completed, List<NavigationStatus> states}) repeat(
  TripNavigator nav,
  List<LocationSample> locationSamples,
) {
  final steps = <int>[nav.step];
  final states = <NavigationStatus>[];
  for (final m in locationSamples) {
    final r = nav.process(m);
    states.add(r);
    if (r.step != steps.last) steps.add(r.step);
    if (r.completed) break;
  }
  return (steps: steps, completed: nav.completed, states: states);
}

void main() {
  final start = DateTime(2026, 8, 3, 18);

  group('Recorded OTP plan', () {
    test('D1 direct: walk -> wait -> bus -> walk', () {
      final o = tripFromFixture(0).option;
      expect(o.legs.map((t) => t.runtimeType.toString()), [
        'WalkLeg',
        'WaitLeg',
        'BusLeg',
        'WalkLeg',
      ]);
      final bus = o.legs[2] as BusLeg;
      expect(bus.line, 'D1');
      expect(bus.boarding.id, '5296');
      expect(bus.alighting.id, '5124');
      expect(bus.stopsIntermediate, isNotEmpty);
      expect((o.legs.first as WalkLeg).towardStop?.id, '5296');
      expect((o.legs.last as WalkLeg).isAtDestination, isTrue);
      expect(tripFromFixture(0).shapeByLeg[bus.id], '9102');
    });

    test('526 -> 109: seven steps with a walking transfer', () {
      final o = tripFromFixture(9).option;
      expect(o.legs.length, 7);
      expect(o.lines, ['526', '109']);
      expect(o.transfers, 1);
      expect((o.legs[3] as WalkLeg).towardStop?.id, '4908');
    });
  });

  group('Navigation with the recorded GPS', () {
    for (final (index, stepsExpected) in [
      (0, [0, 1, 2, 3]),
      (9, [0, 1, 2, 3, 4, 5, 6]),
    ]) {
      test('option $index advances one step at a time and finishes', () {
        final nav = TripNavigator(tripFromFixture(index).option);
        final r = repeat(nav, samplesFromFixture(index, start));
        expect(r.steps, stepsExpected, reason: 'strict +1 trace');
        expect(r.completed, isTrue);
      });
    }

    test('the walk reports decreasing remaining meters and the route', () {
      final nav = TripNavigator(tripFromFixture(0).option);
      final locationSamples = samplesFromFixture(0, start);
      final first =
          [
            for (final m in locationSamples.take(20)) nav.process(m),
          ].where((e) => e.step == 0).toList();
      expect(first, isNotEmpty);
      final meters = first.map((e) => e.progress.metersLeft!).toList();
      expect(meters.first, greaterThan(250));
      expect(meters.last, lessThan(meters.first));
      final route = first.last.progress.routeRemaining!;
      expect(route.length, greaterThanOrEqualTo(2));
      expect(first.last.progress.fraction, greaterThan(0));
    });

    test('on board the bus it counts the remaining stops down to 0', () {
      final nav = TripNavigator(tripFromFixture(0).option);
      final inBus = <int>[];
      for (final m in samplesFromFixture(0, start)) {
        final r = nav.process(m);
        if (r.step == 2 && r.progress.stopsLeft != null) {
          inBus.add(r.progress.stopsLeft!);
        }
      }
      expect(inBus, isNotEmpty);
      expect(inBus.first, greaterThan(5));
      expect(inBus.last, 0);
      for (var i = 1; i < inBus.length; i++) {
        expect(
          inBus[i],
          lessThanOrEqualTo(inBus[i - 1]),
          reason: 'never goes up',
        );
      }
    });

    test('waiting without moving does not trigger boarding', () {
      final o = tripFromFixture(0).option;
      final nav = TripNavigator(o);
      final stop = (o.legs[1] as WaitLeg).stop.coordinate;
      nav.confirmStep(); // arrived at the stop
      for (var i = 0; i < 30; i++) {
        final r = nav.process(
          LocationSample(
            coordinate: stop,
            moment: start.add(Duration(seconds: 5 * i)),
            velocity: 0,
          ),
        );
        expect(r.step, 1);
      }
    });

    test('manual fallback advances and completes at the end', () {
      final o = tripFromFixture(0).option;
      final nav = TripNavigator(o);
      for (var i = 0; i < o.legs.length - 1; i++) {
        expect(nav.confirmStep().step, i + 1);
      }
      expect(nav.confirmStep().completed, isTrue);
    });

    test(
      'if the GPS missed the boarding, it jumps to the bus once traveling',
      () {
        final o = tripFromFixture(0).option;
        final nav = TripNavigator(o);
        final locationSamples = samplesFromFixture(0, start);
        // The waiting samples are discarded: the user "appears" already traveling.
        final samples = (optionFromFixture(0)['replay']['userSamples'] as List);
        final withoutWait = [
          for (var i = 0; i < locationSamples.length; i++)
            if (samples[i]['phase'] != 'wait') locationSamples[i],
        ];
        final r = repeat(nav, withoutWait);
        expect(r.steps.first, 0);
        expect(r.steps, containsAllInOrder([0, 2, 3]));
        expect(r.completed, isTrue);
      },
    );

    test(
      'if they got off between two readings, it continues on the final walk',
      () {
        // Readings spaced apart (GPS cut out, app suspended, accelerated demo):
        // none falls near the drop-off stop. Before this fix the
        // browser stayed on "Viajá en el D1" with the user already walking.
        final o = tripFromFixture(0).option;
        final alighting = (o.legs[2] as BusLeg).alighting.coordinate;
        final nav = TripNavigator(o);
        final neverAlighting = [
          for (final m in samplesFromFixture(0, start))
            if (distance(m.coordinate, alighting) > 150) m,
        ];
        final r = repeat(nav, neverAlighting);
        expect(r.steps, containsAllInOrder([2, 3]));
        expect(r.completed, isTrue);
      },
    );
  });
}
