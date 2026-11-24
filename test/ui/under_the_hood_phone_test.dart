// The inside view on a phone: the app full screen over a strip that opens
// into a sheet with the compact board, live, while the app keeps running.

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/ui/map/bondi_map.dart';
import 'package:bondi_uy/ui/web/under_the_hood.dart';
import 'package:bondi_uy/ui/web/web_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  test('the compact board fits any phone width without overlaps', () {
    for (var width = 340.0; width <= 700; width += 8) {
      final (:size, :boxes) = boxesOfCompactBoard(width);
      final board = (Offset.zero & size).deflate(4);
      final names = boxes.keys.toList();
      for (var i = 0; i < names.length; i++) {
        final r = boxes[names[i]]!;
        expect(
          board.contains(r.topLeft) && board.contains(r.bottomRight),
          isTrue,
          reason: '${names[i]} leaves the board at $width',
        );
        for (var j = i + 1; j < names.length; j++) {
          expect(
            r.inflate(5).overlaps(boxes[names[j]]!),
            isFalse,
            reason: '${names[i]} and ${names[j]} overlap at $width',
          );
        }
      }
    }
  });

  for (final (size, dark) in const [
    // A 393-wide phone with the browser's bars taken out, and a small one.
    (Size(393, 773), true),
    (Size(360, 800), false),
  ]) {
    testWidgets(
      'a trip with the board in a sheet (${size.width.round()}x${size.height.round()}${dark ? ', dark' : ''})',
      (tester) async {
        final a = await Harness.mount(
          tester,
          prefix:
              'under_the_hood_phone_${size.width.round()}${dark ? '_dark' : ''}',
          demo: true,
          frame: true,
          size: size,
          dark: dark,
        );
        await a.wait(const Duration(seconds: 2));
        final strip = find.byKey(const ValueKey('inside-strip'));
        expect(strip, findsOneWidget, reason: 'the strip under the app');
        await a.capture('closed');

        // In a phone's browser the app is drawn a little smaller: it is laid
        // out for a larger screen than the one it is shown in.
        final scale = phoneWebScale(
          Size(size.width, size.height - UnderTheHoodPocket.stripHeight),
        );
        expect(scale, lessThan(1));
        expect(
          tester.getSize(find.byType(BondiMap)).width,
          closeTo(size.width / scale, 0.5),
        );

        // The app works as always above the strip.
        await a.tap('demo-destination-plaza-independencia');
        await a.until(
          () =>
              a.phase is OptionsPhase &&
              (a.phase as OptionsPhase).status == OptionsStatus.ready,
        );
        await a.tap('start-trip');
        await a.wait(const Duration(milliseconds: 1500));
        await a.capture('walking');
        await a.untilStep(1);
        await a.wait(const Duration(milliseconds: 800));
        await a.capture('waiting');

        // Open: the sheet rises with the board, and the app stays above it.
        await tester.tap(strip);
        await a.wait(const Duration(milliseconds: 900));
        expect(
          tester.getTopLeft(strip).dy,
          lessThan(size.height - UnderTheHoodPocket.sheetHeight(0) + 1),
        );
        await a.capture('open_waiting');

        // A tap on a piece shows its card.
        final (size: board, :boxes) = boxesOfCompactBoard(size.width);
        final top = tester.getBottomLeft(strip).dy;
        await tester.tapAt(Offset(0, top) + boxes['tracker']!.center);
        await a.wait(const Duration(milliseconds: 300));
        expect(
          find.text('lib/logic/trip/bus_tracker.dart'),
          findsOneWidget,
          reason: 'the card of the piece tapped',
        );
        await a.capture('card');
        expect(board.height, UnderTheHoodPocket.sheetHeight(0) - 48);

        // Close: back to the strip.
        await tester.tap(strip);
        await a.wait(const Duration(milliseconds: 900));
        expect(tester.getBottomLeft(strip).dy, closeTo(size.height, 1));
        await a.close();
      },
    );
  }
}
