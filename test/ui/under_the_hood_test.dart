// The web "under the hood" presentation: the app plugged into a plate where the calls
// between its pieces are seen. What is drawn are real calls: this
// test takes a trip and checks that they go through every seam.

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/contract/traces.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bondi_uy/ui/web/web_frame.dart';
import 'package:bondi_uy/ui/web/under_the_hood.dart';

import 'harness.dart';

void main() {
  test('the plate boxes never overlap in any possible window', () {
    for (var height = heightMinUnderTheHood; height <= 1440; height += 40) {
      final phoneSize = phoneSizeUnderTheHood(height);
      final min = widthMinUnderTheHood(phoneSize.width);
      for (var width = min; width <= 2560; width += 64) {
        final size = Size(width, height);
        final phone = phoneUnderTheHood(size, phoneSize);
        final boxes = {...plateBoxes(size, phone), 'phone': phone};
        final window = Offset.zero & size;
        final names = boxes.keys.toList();
        for (var i = 0; i < names.length; i++) {
          final r = boxes[names[i]]!;
          expect(
            window.deflate(8).contains(r.topLeft) &&
                window.deflate(8).contains(r.bottomRight),
            isTrue,
            reason: '${names[i]} goes out of the window at $size',
          );
          for (var j = i + 1; j < names.length; j++) {
            final o = boxes[names[j]]!;
            expect(
              r.inflate(8).overlaps(o),
              isFalse,
              reason: '${names[i]} and ${names[j]} overlap at $size',
            );
          }
        }
      }
    }
  });

  // A large desktop, and a 1920 one with the browser at 125 %.
  for (final size in const [Size(1920, 1080), Size(1536, 745)]) {
    testWidgets(
      'a trip, seen under the hood (${size.width.round()}x${size.height.round()})',
      (tester) async {
        final a = await Harness.mount(
          tester,
          prefix: 'under_the_hood_${size.width.round()}',
          demo: true,
          frame: true,
          size: size,
        );
        await a.wait(const Duration(seconds: 2));
        expect(find.text('Por dentro'), findsWidgets);
        await a.capture('start');

        await a.tap('demo-destination-plaza-independencia');
        await a.until(
          () =>
              a.phase is OptionsPhase &&
              (a.phase as OptionsPhase).status == OptionsStatus.ready,
        );
        await a.wait(const Duration(milliseconds: 1200));
        await a.capture('options');
        await a.tap('start-trip');
        await a.wait(const Duration(milliseconds: 1500));
        await a.capture('walking');
        await a.untilStep(1);
        await a.wait(const Duration(milliseconds: 800));
        await a.capture('waiting');

        // With the mouse over a piece, its card says where the code is.
        final phone = phoneUnderTheHood(
          size,
          phoneSizeUnderTheHood(size.height),
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        for (final (piece, file) in const [
          ('tracker', 'lib/logic/trip/bus_tracker.dart'),
          ('contract', 'lib/contract/'),
          ('places', 'lib/logic/services/places.dart'),
        ]) {
          await mouse.moveTo(plateBoxes(size, phone)[piece]!.center);
          await a.wait(const Duration(milliseconds: 300));
          expect(find.text(file), findsOneWidget, reason: piece);
          await a.capture('card_$piece');
        }
        await mouse.moveTo(Offset(size.width - 4, 4));
        await a.wait(const Duration(milliseconds: 100));
        expect(find.byKey(const ValueKey('piece-card')), findsNothing);
        await mouse.removePointer();
        await a.untilStep(2);
        await a.wait(const Duration(milliseconds: 1500));
        await a.capture('on_bus');

        // Every seam of the app, with real calls.
        for (final pair in [
          (Piece.interfaceValue, Piece.controller), // UI actions
          (Piece.controller, Piece.planner),
          (Piece.controller, Piece.recommender),
          (Piece.controller, Piece.arrivals),
          (Piece.controller, Piece.tracker),
          (Piece.location, Piece.controller),
          (Piece.controller, Piece.navigator),
        ]) {
          expect(
            a.traces!.calls,
            contains(pair),
            reason: 'calls ${pair.$1} -> ${pair.$2}',
          );
        }
        await a.close();
      },
    );
  }
}
