// The trip camera can follow the incoming bus instead of the user: some people
// care more about where the bus is coming from than where they are.

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/logic/simulation/demo.dart';
import 'package:bondi_uy/ui/map/framing.dart';
import 'package:bondi_uy/ui/map/scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../logic/route_demo.dart';
import 'harness.dart';

void main() {
  test('with "see the bus", the camera follows the bus while it comes', () {
    final states = traverseDemo(
      destination: destinationsDemo.first,
      inOptions: Duration.zero,
    );
    var withBus = 0, onBoard = 0;
    for (final e in states) {
      final f = e.s.phase;
      if (f is! TripPhase || f.status != TripStatus.inProgress) continue;
      final me = framingOf(e.s, const MapUiStatus())!;
      final bus = framingOf(e.s, const MapUiStatus(showBus: true))!;
      expect(
        me.anchor,
        Vehicles.user,
        reason: 'by default, it follows the user',
      );
      if (canSeeBus(f)) {
        withBus++;
        expect(bus.anchor, Vehicles.bus, reason: 'the bus is never left out');
        expect(bus.vehicles, contains(Vehicles.bus));
        expect(bus.vehicles, isNot(contains(Vehicles.user)));
        expect(bus.key, isNot(me.key), reason: 'changing mode reframes');
        expect(bus.tracking, Tracking.continuous);
      } else {
        // On the bus (the bus is the user) or no bus in view: there is no
        // other mode, even if one was chosen.
        if (f.currentLeg is BusLeg) onBoard++;
        expect(bus.anchor, me.anchor);
        expect(bus.key, me.key);
      }
    }
    expect(withBus, greaterThan(10), reason: 'there was an incoming bus');
    expect(onBoard, greaterThan(10), reason: 'and a ride on board the bus');
  });

  testWidgets(
    'the button appears with the bus coming, toggles and goes away on boarding',
    (tester) async {
      final a = await Harness.mount(
        tester,
        prefix: 'camera_bus',
        demo: true,
        velocity: 15,
      );
      await a.wait(const Duration(seconds: 2));
      final button = find.byKey(const ValueKey('button-camera'));
      await a.tap('demo-destination-plaza-independencia');
      await a.until(
        () =>
            a.phase is OptionsPhase &&
            (a.phase as OptionsPhase).status == OptionsStatus.ready,
      );
      await a.tap('start-trip');
      await a.until(
        () => a.phase is TripPhase && canSeeBus(a.phase as TripPhase),
        reason: 'an incoming bus',
      );
      await a.wait(const Duration(milliseconds: 400));
      expect(find.text('Ver el bus'), findsOneWidget);
      await a.capture('following_me');

      await tester.tap(button);
      await a.wait(const Duration(seconds: 1));
      expect(find.text('Verme a mí'), findsOneWidget);
      await a.capture('following_the_bus');

      // On the bus the button goes away: you are the bus.
      await a.untilStep(2);
      await a.wait(const Duration(seconds: 1));
      expect(
        tester
            .widget<AnimatedScale>(
              find.byKey(const ValueKey('button-camera-scale')),
            )
            .scale,
        0,
      );
      await a.close();
    },
  );
}
