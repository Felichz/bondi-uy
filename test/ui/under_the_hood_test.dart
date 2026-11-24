// The web "under the hood" presentation: the app plugged into a plate where the calls
// between its pieces are seen. What is drawn are real calls: this
// test takes a trip and checks that they go through every seam.

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/contract/traces.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  // A big desktop and a 1920 one with the browser at 125 %, in both themes.
  for (final (size, dark) in const [
    (Size(1920, 1080), false),
    (Size(1536, 745), false),
    (Size(1536, 745), true),
  ]) {
    testWidgets(
      'a trip, seen under the hood (${size.width.round()}x${size.height.round()}${dark ? ', dark' : ''})',
      (tester) async {
        final a = await Harness.mount(
          tester,
          prefix: 'under_the_hood_${size.width.round()}${dark ? '_dark' : ''}',
          dark: dark,
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
        // The console reads like a terminal: the newest call is the bottom
        // entry (the list holds them newest first), and no line is cut.
        final entries = find.descendant(
          of: find.byKey(const ValueKey('console-lines')),
          matching: find.byKey(const ValueKey('console-entry')),
        );
        expect(entries.evaluate().length, greaterThan(3));
        expect(
          tester.getTopLeft(entries.at(0)).dy,
          greaterThan(tester.getTopLeft(entries.at(1)).dy),
          reason: 'the newest call is below the previous one',
        );
        for (final p in tester.renderObjectList<RenderParagraph>(
          find.descendant(
            of: find.byKey(const ValueKey('console-lines')),
            matching: find.byType(RichText),
          ),
        )) {
          expect(
            p.didExceedMaxLines,
            isFalse,
            reason: 'a console line was cut: ${p.text.toPlainText()}',
          );
          expect(p.maxLines, isNull);
        }

        // The console sits in the portfolio's window: the green light
        // maximizes it over the story column, and restores it.
        final zoom = find.byKey(const ValueKey('console-zoom'));
        expect(zoom, findsOneWidget);
        final lede = find.textContaining('App API.').hitTestable();
        expect(lede, findsOneWidget);
        await tester.tap(zoom);
        await a.wait(const Duration(milliseconds: 600));
        expect(lede, findsNothing, reason: 'maximized, the story folds away');
        await a.capture('console_maximized');
        await tester.tap(zoom);
        await a.wait(const Duration(milliseconds: 600));
        expect(lede, findsOneWidget);

        // No tabs: this is the only landing. The theme button switches
        // between light and dark.
        expect(find.text('Presentación'), findsNothing);
        expect(find.text('Overview'), findsNothing);
        final toggle = find.byKey(const ValueKey('theme-toggle'));
        expect(toggle, findsOneWidget);
        final before =
            dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded;
        final after = dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded;
        expect(find.byIcon(before), findsOneWidget);
        await tester.tap(toggle);
        await a.wait(const Duration(milliseconds: 600));
        expect(find.byIcon(after), findsOneWidget);
        await a.capture('theme_toggled');
        await a.close();
      },
    );
  }
}
