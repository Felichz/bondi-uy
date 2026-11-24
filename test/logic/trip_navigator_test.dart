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
  final inicio = DateTime(2026, 8, 3, 18);

  group('Plan OTP grabado', () {
    test('D1 directo: caminar -> esperar -> bus -> caminar', () {
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

    test('526 -> 109: siete pasos con trasbordo caminando', () {
      final o = tripFromFixture(9).option;
      expect(o.legs.length, 7);
      expect(o.lines, ['526', '109']);
      expect(o.transfers, 1);
      expect((o.legs[3] as WalkLeg).towardStop?.id, '4908');
    });
  });

  group('Navegación con el GPS grabado', () {
    for (final (index, stepsExpected) in [
      (0, [0, 1, 2, 3]),
      (9, [0, 1, 2, 3, 4, 5, 6]),
    ]) {
      test('opción $index avanza de a un paso y termina', () {
        final nav = TripNavigator(tripFromFixture(index).option);
        final r = repeat(nav, samplesFromFixture(index, inicio));
        expect(r.steps, stepsExpected, reason: 'traza estricta +1');
        expect(r.completed, isTrue);
      });
    }

    test('la caminata informa metros restantes decrecientes y recorrido', () {
      final nav = TripNavigator(tripFromFixture(0).option);
      final locationSamples = samplesFromFixture(0, inicio);
      final first =
          [
            for (final m in locationSamples.take(20)) nav.process(m),
          ].where((e) => e.step == 0).toList();
      expect(first, isNotEmpty);
      final meters = first.map((e) => e.progress.metersRestantes!).toList();
      expect(meters.first, greaterThan(250));
      expect(meters.last, lessThan(meters.first));
      final route = first.last.progress.routeRemaining!;
      expect(route.length, greaterThanOrEqualTo(2));
      expect(first.last.progress.fraction, greaterThan(0));
    });

    test('arriba del bus cuenta las paradas que faltan hasta 0', () {
      final nav = TripNavigator(tripFromFixture(0).option);
      final inBus = <int>[];
      for (final m in samplesFromFixture(0, inicio)) {
        final r = nav.process(m);
        if (r.step == 2 && r.progress.stopsRestantes != null) {
          inBus.add(r.progress.stopsRestantes!);
        }
      }
      expect(inBus, isNotEmpty);
      expect(inBus.first, greaterThan(5));
      expect(inBus.last, 0);
      for (var i = 1; i < inBus.length; i++) {
        expect(inBus[i], lessThanOrEqualTo(inBus[i - 1]), reason: 'nunca sube');
      }
    });

    test('esperar sin moverse no dispara la subida', () {
      final o = tripFromFixture(0).option;
      final nav = TripNavigator(o);
      final stop = (o.legs[1] as WaitLeg).stop.coordinate;
      nav.confirmStep(); // arrived at the stop
      for (var i = 0; i < 30; i++) {
        final r = nav.process(
          LocationSample(
            coordinate: stop,
            moment: inicio.add(Duration(seconds: 5 * i)),
            velocity: 0,
          ),
        );
        expect(r.step, 1);
      }
    });

    test('respaldo manual avanza y al final completa', () {
      final o = tripFromFixture(0).option;
      final nav = TripNavigator(o);
      for (var i = 0; i < o.legs.length - 1; i++) {
        expect(nav.confirmStep().step, i + 1);
      }
      expect(nav.confirmStep().completed, isTrue);
    });

    test('si el GPS se perdió la subida, salta al bus cuando ya viaja', () {
      final o = tripFromFixture(0).option;
      final nav = TripNavigator(o);
      final locationSamples = samplesFromFixture(0, inicio);
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
    });

    test('si se bajó entre dos lecturas, sigue en la caminata final', () {
      // Readings spaced apart (GPS cut out, app suspended, accelerated demo):
      // none falls near the drop-off stop. Before this fix the
      // browser stayed on "Viajá en el D1" with the user already walking.
      final o = tripFromFixture(0).option;
      final alighting = (o.legs[2] as BusLeg).alighting.coordinate;
      final nav = TripNavigator(o);
      final withoutAlighting = [
        for (final m in samplesFromFixture(0, inicio))
          if (distance(m.coordinate, alighting) > 150) m,
      ];
      final r = repeat(nav, withoutAlighting);
      expect(r.steps, containsAllInOrder([2, 3]));
      expect(r.completed, isTrue);
    });
  });
}
