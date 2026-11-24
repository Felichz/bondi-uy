// Nothing is drawn over something else on a phone. The map keeps its balloons
// out from under the floating controls (the camera button, the re-center
// button, the step notice): they used to overlap ("Arrives in 1 min" under
// "Show the bus"). And the trip card shows one figure at a time: the old one
// used to fade out under the new one ("190 m" over "200 m").

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/ui/map/bondi_map.dart';
import 'package:bondi_uy/ui/map/obstacles.dart';
import 'package:bondi_uy/ui/map/scene_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  // A phone's browser: short, once its bars are taken out.
  for (final size in const [Size(393, 725), Size(360, 640)]) {
    testWidgets(
      'no balloon under a floating control (${size.width.round()}x${size.height.round()})',
      (tester) async {
        final a = await Harness.mount(
          tester,
          prefix: 'map_obstacles_${size.width.round()}',
          demo: true,
          size: size,
        );
        await a.wait(const Duration(seconds: 2));
        await a.tap('demo-destination-plaza-independencia');
        await a.until(
          () =>
              a.phase is OptionsPhase &&
              (a.phase as OptionsPhase).status == OptionsStatus.ready,
        );
        await a.tap('start-trip');

        final obstacles = ProviderScope.containerOf(
          tester.element(find.byType(BondiMap)),
        ).read(mapObstaclesProvider);
        var seen = 0, withControls = 0, pills = 0;
        Future<void> watch(Duration time) async {
          for (
            var t = Duration.zero;
            t < time;
            t += const Duration(milliseconds: 100)
          ) {
            await tester.pump(const Duration(milliseconds: 100));
            // The trip card's big figure: one number at a time, never the
            // old one showing through the new. (Per card: while the step
            // changes there are two cards, each with its own.)
            for (final figure
                in find.byKey(const ValueKey('trip-figure')).evaluate()) {
              expect(
                find
                    .descendant(
                      of: find.byElementPredicate((e) => e == figure),
                      matching: find.byType(FittedBox),
                    )
                    .evaluate()
                    .length,
                lessThanOrEqualTo(1),
                reason: 'two figures drawn over each other',
              );
            }
            final controls = obstacles.rects.toList();
            if (controls.isNotEmpty) withControls++;
            // The pills at the edge (the bus that is coming, your stop): not
            // under a control, nor over a balloon.
            for (final pill in SceneDrawer.last!.borderBoxes) {
              pills++;
              for (final other in [
                ...controls,
                ...SceneDrawer.last!.balloonBoxes,
              ]) {
                expect(
                  pill.overlaps(other),
                  isFalse,
                  reason: 'an edge pill ($pill) is over $other',
                );
              }
            }
            for (final (i, box) in SceneDrawer.last!.balloonBoxes.indexed) {
              seen++;
              for (final c in controls) {
                expect(
                  box.overlaps(c),
                  isFalse,
                  reason:
                      'the balloon "${SceneDrawer.last!.balloonsPlaced[i]}" '
                      '($box) is under a control ($c), step '
                      '${(a.phase as TripPhase).currentStep + 1}',
                );
              }
            }
          }
        }

        // Walking, waiting with the bus coming, and the first of the ride.
        await watch(const Duration(seconds: 6));
        await a.untilStep(1);
        await watch(const Duration(seconds: 6));
        await a.capture('waiting');
        await a.untilStep(2);
        await watch(const Duration(seconds: 3));
        expect(seen, greaterThan(50), reason: 'there were balloons');
        expect(withControls, greaterThan(20), reason: 'and floating controls');
        expect(pills, greaterThan(10), reason: 'and pills at the edge');
        await a.close();
      },
    );
  }
}
