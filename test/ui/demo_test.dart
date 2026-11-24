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
  testWidgets('dos viajes seguidos desde la tarjeta de la demo', (
    tester,
  ) async {
    final a = await Harness.mount(tester, prefix: 'demo', demo: true);
    await a.wait(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('demo-tarjeta')), findsOneWidget);
    expect(find.text('Terminal Tres Cruces'), findsOneWidget);
    await a.capture('inicio');

    Future<void> trip(String destination) async {
      // The destinations row scrolls: the destination is looked for the way
      // a person would.
      await tester.dragUntilVisible(
        find.byKey(ValueKey('demo-destino-$destination')),
        find.byKey(const ValueKey('demo-destinos')),
        const Offset(-160, 0),
      );
      await a.wait(const Duration(milliseconds: 300));
      await a.tocar('demo-destino-$destination');
      await a.until(
        () =>
            a.phase is OptionsPhase &&
            (a.phase as OptionsPhase).status == OptionsStatus.ready,
        reason: 'opciones de $destination',
      );
      final options = (a.phase as OptionsPhase).options;
      expect(options.where((o) => o.recommended), hasLength(1));
      await a.wait(const Duration(seconds: 1));
      await a.capture('opciones_$destination');
      await a.tocar('empezar-viaje');
      expect(a.phase, isA<TripPhase>());
      await a.until(
        () => (a.phase as TripPhase).status == TripStatus.completed,
        max: const Duration(minutes: 8),
        reason: 'llegar a $destination',
      );
      await a.wait(const Duration(seconds: 1));
      expect(find.text('¡Llegaste!'), findsOneWidget);
      await a.capture('llegada_$destination');
      await a.tocar('viaje-listo');
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

  testWidgets('en inglés: los textos y los formatos cambian', (tester) async {
    final a = await Harness.mount(
      tester,
      prefix: 'demo_en',
      demo: true,
      language: Language.en,
    );
    await a.wait(const Duration(seconds: 2));
    expect(find.text('Try a trip'), findsOneWidget);
    expect(find.text('Where to?'), findsOneWidget);
    await a.capture('inicio');
    await a.tocar('demo-destino-tres-cruces');
    await a.until(
      () =>
          a.phase is OptionsPhase &&
          (a.phase as OptionsPhase).status == OptionsStatus.ready,
    );
    await a.wait(const Duration(seconds: 1));
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('Start trip'), findsOneWidget);
    await a.capture('opciones');
    await a.tocar('empezar-viaje');
    await a.wait(const Duration(seconds: 2));
    expect(find.textContaining('Step 1 of'), findsOneWidget);
    expect(find.text('Walk to the stop'), findsOneWidget);
    await a.capture('caminando');
    await a.untilStep(2);
    await a.wait(const Duration(seconds: 2));
    expect(find.textContaining('Ride the'), findsOneWidget);
    // The figure changes with a fade: for a moment both the old and the new
    // one are there.
    expect(find.textContaining('to go'), findsWidgets);
    await a.capture('en_bus');
    await a.close();
  });
  testWidgets('al subir, el aviso de que el bus llega se va', (tester) async {
    final a = await Harness.mount(
      tester,
      prefix: 'demo_aviso',
      demo: true,
      velocity: 30,
    );
    await a.wait(const Duration(seconds: 2));
    // With a transfer: at the second wait, nothing else covers the notice
    // when boarding.
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('demo-destino-punta-carretas')),
      find.byKey(const ValueKey('demo-destinos')),
      const Offset(-160, 0),
    );
    await a.wait(const Duration(milliseconds: 300));
    await a.tocar('demo-destino-punta-carretas');
    await a.until(
      () =>
          a.phase is OptionsPhase &&
          (a.phase as OptionsPhase).status == OptionsStatus.ready,
    );
    await a.tocar('empezar-viaje');
    final notice = find.byKey(const ValueKey('aviso-busArriving'));
    // Waiting for the second bus, it warns that it is arriving (at 30x, seconds
    // before boarding: the notice lasts longer than that).
    await a.until(
      () =>
          a.phase is TripPhase &&
          (a.phase as TripPhase).stepActual == 3 &&
          notice.evaluate().isNotEmpty,
      step: const Duration(milliseconds: 100),
      reason: 'aviso de que el segundo bus llega',
    );
    await a.untilStep(4);
    await a.wait(const Duration(seconds: 1));
    expect(notice, findsNothing, reason: 'ya subió: el aviso quedó viejo');
    await a.close();
  });

  // In English the figures are longer ("Arrives in 1 min" vs "Llega en
  // 1 min"): on a narrow screen the figure cannot break across two lines,
  // because with maxLines: 1 the second one (the number) gets lost.
  testWidgets('en inglés y en pantalla angosta: la cifra se ve entera', (
    tester,
  ) async {
    final a = await Harness.mount(
      tester,
      prefix: 'demo_en_angosta',
      demo: true,
      language: Language.en,
      size: const Size(360, 780),
    );
    await a.wait(const Duration(seconds: 2));
    await a.tocar('demo-destino-plaza-independencia');
    await a.until(
      () =>
          a.phase is OptionsPhase &&
          (a.phase as OptionsPhase).status == OptionsStatus.ready,
    );
    await a.wait(const Duration(seconds: 1));
    await a.tocar('empezar-viaje');
    await a.untilStep(1);
    await a.wait(const Duration(seconds: 1));

    void whole(Finder text) {
      expect(text, findsWidgets);
      for (final e in text.evaluate()) {
        final paragraph = e.renderObject! as RenderParagraph;
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: '"${paragraph.text.toPlainText()}" no entra en una línea',
        );
      }
    }

    whole(find.textContaining('Arrives in'));
    await a.capture('esperando');
    await a.untilStep(2);
    await a.wait(const Duration(seconds: 2));
    whole(find.textContaining('to go'));
    await a.capture('en_bus');
    await a.close();
  });
}
