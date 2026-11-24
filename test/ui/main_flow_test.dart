// Full main flow, as the user experiences it:
// search destination -> options (recommended) -> start trip -> walk ->
// wait for the bus (live) -> ride -> walk -> ¡Llegaste! -> home.
//
// Runs headless with the real pixel map, the real logic, the recorded OTP plan
// (Saldanha da Gama 3941 -> Plaza Independencia) and the simulated world.
// Leaves screenshots in build/capturas/.

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/ui/map/scene_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  for (final (prefix, withoutAnimations, dark) in [
    ('recommended', false, false),
    ('dark', false, true),
    ('no_animations', true, false),
  ]) {
    testWidgets('recommended trip end to end ($prefix)', (tester) async {
      final a = await Harness.mount(
        tester,
        prefix: prefix,
        withoutAnimations: withoutAnimations,
        dark: dark,
      );

      // Home: search and map.
      expect(find.text('¿A dónde vas?'), findsOneWidget);
      await a.wait(const Duration(seconds: 2));
      await a.capture('start');

      // Search for a destination.
      await tester.tap(find.byKey(const ValueKey('search-destination')));
      await a.wait(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('field-destination')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('field-destination')),
        'plaza',
      );
      await a.wait(const Duration(milliseconds: 600));
      expect(
        find.byKey(const ValueKey('suggestion-plaza-independencia')),
        findsOneWidget,
      );
      await a.capture('suggestions');
      await tester.tap(
        find.byKey(const ValueKey('suggestion-plaza-independencia')),
      );
      await a.wait(const Duration(milliseconds: 300));

      // Options: exactly one recommended, focused.
      await a.until(
        () => find.byKey(const ValueKey('start-trip')).evaluate().isNotEmpty,
        reason: 'options appear',
      );
      expect(find.byKey(const ValueKey('recommended-badge')), findsOneWidget);
      final phase = a.controller.state.phase as OptionsPhase;
      expect(phase.options.where((o) => o.recommended).length, 1);
      expect(phase.options.first.recommended, isTrue);
      await a.wait(const Duration(seconds: 2));
      // The preview already shows the live bus for the focused option.
      await a.until(
        () => (a.controller.state.phase as OptionsPhase).liveBuses.isNotEmpty,
        reason: 'live bus in the preview',
      );
      await a.wait(const Duration(seconds: 1));
      await a.capture('options');

      // Swipe to another option and back.
      await tester.drag(
        find.byKey(const ValueKey('options-carousel')),
        const Offset(-300, 0),
      );
      await a.wait(const Duration(milliseconds: 800));
      await a.capture('other_option');
      await tester.drag(
        find.byKey(const ValueKey('options-carousel')),
        const Offset(300, 0),
      );
      await a.wait(const Duration(milliseconds: 800));

      // Start trip.
      await tester.tap(find.byKey(const ValueKey('start-trip')));
      await a.wait(const Duration(milliseconds: 600));
      final trip = a.controller.state.phase as TripPhase;
      expect(find.text('Paso 1 de ${trip.totalSteps}'), findsOneWidget);
      expect(find.text('Caminá hasta la parada'), findsOneWidget);
      await a.wait(const Duration(seconds: 3));
      // The user's dot shows the direction they are walking, also with the
      // system animations disabled (the heading used to be lost).
      expect(SceneDrawer.last!.headingUser, isNotNull);
      await a.capture('walking');

      // The trip advances on its own, step by step, without jumps.
      final steps = <int>[0];
      final captured = <String>{};
      await a
          .until(
            () {
              final f = a.controller.state.phase;
              if (f is TripPhase) {
                if (f.currentStep != steps.last) steps.add(f.currentStep);
                return f.status == TripStatus.completed;
              }
              return false;
            },
            max: const Duration(minutes: 8),
            step: const Duration(milliseconds: 500),
            reason: 'the trip completes',
          )
          .then((_) {});
      expect(
        steps,
        List.generate(trip.totalSteps, (i) => i),
        reason: 'strict +1 advance',
      );
      captured.add('end');
      await a.wait(const Duration(seconds: 1));
      expect(find.text('¡Llegaste!'), findsOneWidget);
      expect(find.text('Plaza Independencia'), findsOneWidget);
      await a.capture('arrival');

      await tester.tap(find.byKey(const ValueKey('trip-done')));
      await a.wait(const Duration(milliseconds: 600));
      expect(a.controller.state.phase, isA<ExplorePhase>());
      expect(find.text('¿A dónde vas?'), findsOneWidget);
      await a.capture('end');
      await a.close();
    });
  }
}
