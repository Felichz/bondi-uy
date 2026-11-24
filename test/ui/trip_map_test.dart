// The map and the panel during the trip, as the user experiences them:
// - the camera follows the user (it does not stay still while walking or traveling),
// - the relevant stops get their balloon (where to board, the next one, where
//   to get off, the destination),
// - if the user moves the map, the camera comes back on its own after a while,
// - each advance is confirmed and the full itinerary is one tap away.

import 'dart:math' as math;

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/ui/common.dart';
import 'package:bondi_uy/ui/ui_status.dart';
import 'package:bondi_uy/ui/formats.dart';
import 'package:bondi_uy/ui/map/scene_painter.dart';
import 'package:bondi_uy/ui/map/projection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

SceneDrawer get _map => SceneDrawer.last!;

void main() {
  testWidgets('the camera follows the user and stops carry their balloon', (
    tester,
  ) async {
    final a = await Harness.mount(tester, prefix: 'trip_map');
    await a.searchSquare();
    // Preview: the boarding stop and the arrival time, labeled.
    expect(_map.balloonsPlaced, contains('Subís al D1'));
    expect(_map.balloonsPlaced.any((g) => g.startsWith('Llegás ')), isTrue);

    await a.tap('start-trip');
    final option = (a.phase as TripPhase).option;
    final line = option.lines.first;

    // Walking: the camera follows the user as they move, with the
    // stop always in view (the bus, only if it fits without zooming out too much).
    for (var i = 0; i < 6; i++) {
      await a.wait(const Duration(seconds: 1));
      final f = a.phase as TripPhase;
      if (f.currentStep != 0) break;
      final t = f.currentLeg as WalkLeg;
      expect(_inView(a, _map.userOnScreen!), isTrue, reason: 'you');
      expect(_inView(a, _onScreen(t.end)), isTrue, reason: 'the stop');
      // The incoming bus, if it is out of view, is marked at the edge.
      final bus = _map.busOnScreen;
      if (bus != null && !_inView(a, bus)) {
        expect(_map.busInBorder, startsWith(line), reason: 'bus indicator');
      }
    }
    expect(_map.balloonsPlaced, contains('Subís al $line'));
    await a.capture('walking');

    // Waiting: the stop, the incoming bus and you.
    await a.untilStep(1);
    await a.wait(const Duration(seconds: 2));
    final wait = a.phase as TripPhase;
    if (wait.currentStep == 1 && wait.busExpected?.position != null) {
      final t = wait.currentLeg as WaitLeg;
      expect(_inView(a, _onScreen(t.stop.coordinate)), isTrue);
      expect(_inView(a, _map.userOnScreen!), isTrue);
      expect(_inView(a, _map.busOnScreen!), isTrue, reason: 'the bus');
      await a.capture('waiting');
    }

    // On the bus: the next stop with its balloon, and the alighting stop in view
    // when it is close.
    await a.untilStep(2);
    await a.wait(const Duration(seconds: 3));
    expect(find.text('Subiste al $line. ¡Buen viaje!'), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-stop-strip')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-next')), findsOneWidget);
    final next = (a.phase as TripPhase).progress.nextStop!;
    expect(
      _map.balloonsPlaced.any(
        (g) => stopName(next.name).startsWith(g.replaceAll('…', '')),
      ),
      isTrue,
      reason: 'next stop balloon: ${_map.balloonsPlaced}',
    );
    await a.capture('on_bus');
    await a.until(
      () => (a.phase as TripPhase).progress.stopsLeft == 0,
      reason: 'last stop',
    );
    await a.wait(const Duration(seconds: 2));
    expect(_map.balloonsPlaced, contains('¡Bajate en esta!'));
    await a.capture('get_off');

    // Walking to the destination: the destination labeled.
    await a.untilStep(3);
    await a.wait(const Duration(seconds: 2));
    expect(_map.balloonsPlaced, contains('Plaza Independencia'));
    await a.close();
  });

  testWidgets('boarding the bus is one smooth movement', (tester) async {
    final a = await Harness.mount(tester, prefix: 'boarding', velocity: 6);
    await a.searchSquare();
    await a.tap('start-trip');
    await a.untilStep(1);
    final stop = ((a.phase as TripPhase).currentLeg as WaitLeg).stop.coordinate;
    await a.until(
      () =>
          (a.phase as TripPhase).currentStep > 1 ||
          ((a.phase as TripPhase).busExpected?.minutes ?? 99) <= 1,
      reason: 'the bus is about to arrive',
    );
    // Frame by frame (60 fps) from when the bus arrives until already on board.
    const frame = Duration(milliseconds: 16);
    Offset? before;
    double? stepBefore;
    var max = 0.0, tug = 0.0;
    var after = 0;
    var onBoardBeforeConfirm = false;
    while (after < 120) {
      await a.wait(frame, step: frame);
      final f = a.phase as TripPhase;
      if (f.currentStep == 1) {
        // Your bus is at the stop: neither "no data" nor the next bus.
        expect(find.byKey(const ValueKey('trip-no-data')), findsNothing);
        expect(f.busExpected?.minutes ?? 0, lessThanOrEqualTo(1));
        if (_map.userInBus) onBoardBeforeConfirm = true;
      }
      if (f.currentStep >= 2) after++;
      final p = _onScreen(stop);
      if (before != null) {
        final d = (p - before).distance;
        max = math.max(max, d);
        if (stepBefore != null) tug = math.max(tug, (d - stepBefore).abs());
        stepBefore = d;
      }
      before = p;
    }
    expect(
      onBoardBeforeConfirm,
      isTrue,
      reason:
          'once leaving with the bus it is shown on board, without waiting 60 m',
    );
    expect(max, lessThan(12), reason: 'the map does not jump');
    expect(tug, lessThan(6), reason: 'no tugs between frames');
    await a.close();
  });

  testWidgets(
    'if you move the map during a trip, the camera comes back on its own',
    (tester) async {
      final a = await Harness.mount(tester, prefix: 'resume');
      await a.searchSquare();
      await a.tap('start-trip');
      await a.wait(const Duration(seconds: 2));
      final ctl = a.container.read(controllerMapProvider);
      expect(ctl.free, isFalse);

      await tester.drag(
        find.byKey(const ValueKey('map')),
        const Offset(0, -250),
      );
      await a.wait(const Duration(milliseconds: 600));
      expect(ctl.free, isTrue);
      expect(find.byKey(const ValueKey('button-recenter')), findsOneWidget);
      await a.capture('map_moved');

      await a.wait(const Duration(seconds: 13));
      expect(ctl.free, isFalse, reason: 'went back to following the user');
      await a.close();
    },
  );

  testWidgets('the itinerary shows all steps and which one is current', (
    tester,
  ) async {
    final a = await Harness.mount(tester, prefix: 'itinerary');
    await a.searchSquare();
    await a.tap('start-trip');
    await a.untilStep(1);
    await a.wait(const Duration(seconds: 1));
    await a.tap('trip-itinerary');
    expect(find.byKey(const ValueKey('itinerary')), findsOneWidget);
    final line = (a.phase as TripPhase).option.lines.first;
    expect(find.text('Esperá el $line'), findsWidgets);
    expect(find.text('Viajá en el $line'), findsOneWidget);
    expect(find.text('AHORA'), findsOneWidget);
    await a.capture('open');
    await a.tap('itinerary-close');
    expect(find.byKey(const ValueKey('itinerary')), findsNothing);
    await a.close();
  });

  test('capitalize respects acronyms and connectors', () {
    expect(capitalize('PLAZA INDEPENDENCIA'), 'Plaza Independencia');
    expect(capitalize('HACIA UAM'), 'Hacia UAM');
    expect(capitalize('PARQUE DE LOS ALIADOS'), 'Parque de los Aliados');
    expect(capitalize('AV ITALIA'), 'Av Italia');
    expect(capitalize('POCITOS'), 'Pocitos');
  });
}

/// Where [c] lands on screen according to the camera of the last frame.
Offset _onScreen(Coordinate c) =>
    _map.camera!.toCanvas(mercator(c), const Offset(206, 446));

/// Inside the visible map: below the step card and above the
/// bottom bar.
bool _inView(Harness a, Offset p) {
  final top = 24 + 8 + a.container.read(heightCardTripProvider);
  return p.dx > 0 && p.dx < 412 && p.dy > top && p.dy < 892 - 100;
}
