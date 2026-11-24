// Demo mode, as a visitor to the portfolio uses it: no servers, picks a
// destination with a tap, speeds up time, takes the whole trip, goes back
// home and takes another one.

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/logic/simulation/demo.dart';
import 'package:bondi_uy/ui/texts/texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  testWidgets('two trips in a row from the demo card', (tester) async {
    final a = await Harness.mount(tester, prefix: 'demo', demo: true);
    await a.wait(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('demo-card')), findsOneWidget);
    expect(find.text('Terminal Tres Cruces'), findsOneWidget);
    await a.capture('start');

    Future<void> trip(String destination) async {
      // The destinations row scrolls: the destination is looked for the way
      // a person would.
      await tester.dragUntilVisible(
        find.byKey(ValueKey('demo-destination-$destination')),
        find.byKey(const ValueKey('demo-destinations')),
        const Offset(-160, 0),
      );
      await a.wait(const Duration(milliseconds: 300));
      await a.tap('demo-destination-$destination');
      await a.until(
        () =>
            a.phase is OptionsPhase &&
            (a.phase as OptionsPhase).status == OptionsStatus.ready,
        reason: 'options for $destination',
      );
      final options = (a.phase as OptionsPhase).options;
      expect(options.where((o) => o.recommended), hasLength(1));
      await a.wait(const Duration(seconds: 1));
      await a.capture('options_$destination');
      await a.tap('start-trip');
      expect(a.phase, isA<TripPhase>());
      await a.until(
        () => (a.phase as TripPhase).status == TripStatus.completed,
        max: const Duration(minutes: 8),
        reason: 'arrive at $destination',
      );
      await a.wait(const Duration(seconds: 1));
      expect(find.text('¡Llegaste!'), findsOneWidget);
      await a.capture('arrival_$destination');
      await a.tap('trip-done');
      expect(a.phase, isA<ExplorePhase>());
    }

    await trip('tres-cruces');
    // Back home, where the next trip starts from.
    await a.wait(const Duration(seconds: 2));
    final location = a.controller.state.location.coordinate!;
    expect((location.lat - houseDemo.lat).abs(), lessThan(0.001));
    expect((location.lng - houseDemo.lng).abs(), lessThan(0.001));
    await trip('mercado-puerto');
    await a.close();
  });

  testWidgets('in English: texts and formats change', (tester) async {
    final a = await Harness.mount(
      tester,
      prefix: 'demo_en',
      demo: true,
      language: Language.en,
    );
    await a.wait(const Duration(seconds: 2));
    expect(find.text('Try a trip'), findsOneWidget);
    expect(find.text('Where to?'), findsOneWidget);
    await a.capture('start');
    await a.tap('demo-destination-tres-cruces');
    await a.until(
      () =>
          a.phase is OptionsPhase &&
          (a.phase as OptionsPhase).status == OptionsStatus.ready,
    );
    await a.wait(const Duration(seconds: 1));
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('Start trip'), findsOneWidget);
    await a.capture('options');
    await a.tap('start-trip');
    await a.wait(const Duration(seconds: 2));
    expect(find.textContaining('Step 1 of'), findsOneWidget);
    expect(find.text('Walk to the stop'), findsOneWidget);
    await a.capture('walking');
    await a.untilStep(2);
    await a.wait(const Duration(seconds: 2));
    expect(find.textContaining('Ride the'), findsOneWidget);
    // The figure changes with a fade: for a moment both the old and the new
    // one are there.
    expect(find.textContaining('to go'), findsWidgets);
    await a.capture('on_bus');
    await a.close();
  });
  testWidgets('on boarding, the bus-arriving notice goes away', (tester) async {
    final a = await Harness.mount(
      tester,
      prefix: 'demo_notice',
      demo: true,
      velocity: 30,
    );
    await a.wait(const Duration(seconds: 2));
    // With a transfer: at the second wait, nothing else covers the notice
    // when boarding.
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('demo-destination-punta-carretas')),
      find.byKey(const ValueKey('demo-destinations')),
      const Offset(-160, 0),
    );
    await a.wait(const Duration(milliseconds: 300));
    await a.tap('demo-destination-punta-carretas');
    await a.until(
      () =>
          a.phase is OptionsPhase &&
          (a.phase as OptionsPhase).status == OptionsStatus.ready,
    );
    await a.tap('start-trip');
    final notice = find.byKey(const ValueKey('notice-busArriving'));
    // Waiting for the second bus, it warns that it is arriving (at 30x, seconds
    // before boarding: the notice lasts longer than that).
    await a.until(
      () =>
          a.phase is TripPhase &&
          (a.phase as TripPhase).currentStep == 3 &&
          notice.evaluate().isNotEmpty,
      step: const Duration(milliseconds: 100),
      reason: 'notice that the second bus is arriving',
    );
    await a.untilStep(4);
    await a.wait(const Duration(seconds: 1));
    expect(
      notice,
      findsNothing,
      reason: 'already boarded: the notice is stale',
    );
    await a.close();
  });

  // In English the figures are longer ("Arrives in 1 min" vs "Llega en
  // 1 min"): on a narrow screen the figure cannot break across two lines,
  // because with maxLines: 1 the second one (the number) gets lost.
  testWidgets('in English on a narrow screen: the figure shows whole', (
    tester,
  ) async {
    final a = await Harness.mount(
      tester,
      prefix: 'demo_en_narrow',
      demo: true,
      language: Language.en,
      size: const Size(360, 780),
    );
    await a.wait(const Duration(seconds: 2));
    await a.tap('demo-destination-plaza-independencia');
    await a.until(
      () =>
          a.phase is OptionsPhase &&
          (a.phase as OptionsPhase).status == OptionsStatus.ready,
    );
    await a.wait(const Duration(seconds: 1));
    await a.tap('start-trip');
    await a.untilStep(1);
    await a.wait(const Duration(seconds: 1));

    void whole(Finder text) {
      expect(text, findsWidgets);
      for (final e in text.evaluate()) {
        final paragraph = e.renderObject! as RenderParagraph;
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: '"${paragraph.text.toPlainText()}" does not fit on one line',
        );
      }
    }

    whole(find.textContaining('Arrives in'));
    await a.capture('waiting');
    await a.untilStep(2);
    await a.wait(const Duration(seconds: 2));
    whole(find.textContaining('to go'));
    await a.capture('on_bus');
    await a.close();
  });
}
