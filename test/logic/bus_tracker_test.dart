import 'package:bondi_uy/contract/model.dart';
import 'package:bondi_uy/logic/geo/geo.dart';
import 'package:bondi_uy/logic/ports.dart';
import 'package:bondi_uy/logic/trip/bus_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

StopArrival arrivalOfPoll(Map<String, dynamic> s) => StopArrival(
  BusArrival(
    line: s['line'] as String,
    minutes: s['etaMinutes'] as int,
    live: s['realtime'] as bool,
    position: Coordinate(
      (s['lat'] as num).toDouble(),
      (s['lng'] as num).toDouble(),
    ),
  ),
  vehicle: s['vehicleId'] as String?,
);

void main() {
  final trip = tripFromFixture(0);
  final bus = trip.option.legs[2] as BusLeg;
  final shape = shapeFromAsset(trip.shapeByLeg[bus.id]!)!;
  final route =
      RouteLine.create(
        shape,
        bus.boarding.coordinate,
        alighting: bus.alighting.coordinate,
      )!;

  test('every real D1 poll produces an approximation along the street', () {
    final tracker = BusTracker(line: 'D1', route: route);
    for (final s in pollsFromFixture(0).where((s) => s['found'] == true)) {
      final b = tracker.choose([arrivalOfPoll(s)])!;
      expect(b.live, isTrue);
      expect(b.minutes, s['etaMinutes']);
      final ap = b.approximation!;
      expect(ap.first, b.position);
      expect(distance(ap.last, bus.boarding.coordinate), lessThan(40));
      // Never a chord: no jump between consecutive points > 500 m.
      for (var i = 1; i < ap.length; i++) {
        expect(distance(ap[i - 1], ap[i]), lessThan(500));
      }
      // It follows the street: much longer than the straight line.
      expect(long(ap), greaterThan(distance(ap.first, ap.last) * 0.99));
      expect(b.metersUntilStop, greaterThan(0));
    }
  });

  test('follows the same vehicle between polls', () {
    final tracker = BusTracker(line: 'D1', route: route);
    final s = pollsFromFixture(0).first;
    final chosen = tracker.choose([arrivalOfPoll(s)]);
    expect(chosen, isNotNull);
    // Another D1 shows up closer in minutes, but the same vehicle is followed.
    final other = StopArrival(
      BusArrival(
        line: 'D1',
        minutes: 1,
        live: true,
        position: shape[shape.length ~/ 3],
      ),
      vehicle: 'other',
    );
    final b = tracker.choose([other, arrivalOfPoll(s)])!;
    expect(b.minutes, s['etaMinutes']);
  });

  test('a bus that already passed the stop is not shown as coming', () {
    final tracker = BusTracker(line: 'D1', route: route);
    final after = Polyline(shape).pointAt(route.routeStop + 800);
    final b = tracker.choose([
      StopArrival(
        BusArrival(line: 'D1', minutes: 3, live: true, position: after),
      ),
    ]);
    expect(b, isNull);
  });

  test('another line at the same stop is ignored', () {
    final tracker = BusTracker(line: 'D1', route: route);
    expect(
      tracker.choose([
        const StopArrival(BusArrival(line: '104', minutes: 2, live: true)),
      ]),
      isNull,
    );
  });

  test('no shape: bus with a position but no made-up approximation', () {
    final tracker = BusTracker(line: 'D1');
    final s = pollsFromFixture(0).first;
    final b = tracker.choose([arrivalOfPoll(s)])!;
    expect(b.position, isNotNull);
    expect(b.approximation, isNull);
  });

  test(
    'the bus that reached the stop is reported as arrived, not the next one',
    () {
      final tracker = BusTracker(line: 'D1', route: route);
      StopArrival arrivalAt(double metersBefore, String vehicle, int minutes) =>
          StopArrival(
            BusArrival(
              line: 'D1',
              minutes: minutes,
              live: true,
              position: Polyline(shape).pointAt(route.routeStop - metersBefore),
            ),
            vehicle: vehicle,
          );
      // Ours is arriving; the next one is 2 km away.
      final arriving =
          tracker.choose([arrivalAt(80, 'a', 0), arrivalAt(2000, 'b', 4)])!;
      expect(arriving.metersUntilStop, lessThan(150));
      // It passed the stop: the source now only reports the next one.
      for (var i = 0; i < BusTracker.pollsArrived; i++) {
        final b = tracker.choose([arrivalAt(1900, 'b', 4)])!;
        expect(b.minutes, 0, reason: 'still "arrived" at poll $i');
        expect(b.metersUntilStop, 0);
      }
      // If the user did not board, only now is the next one announced.
      final next = tracker.choose([arrivalAt(1800, 'b', 4)])!;
      expect(next.minutes, 4);
    },
  );
}
