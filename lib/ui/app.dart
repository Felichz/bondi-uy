// UI root: a persistent map with the current phase's panel on top.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contract/app_state.dart';
import '../contract/providers.dart';
import 'notices.dart';
import 'search/search_screen.dart';
import 'demo/demo.dart';
import 'ui_status.dart';
import 'explore/explore_panel.dart';
import 'map/framing.dart';
import 'map/scene.dart';
import 'map/bondi_map.dart';
import 'options/options_panel.dart';
import 'theme/theme_preference.dart';
import 'texts/language_preference.dart';
import 'texts/texts.dart';
import 'theme/app_theme.dart';
import 'trip/trip_panel.dart';
import 'web/web_frame.dart';

class BondiApp extends ConsumerWidget {
  const BondiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    pinLanguage(language);
    return MaterialApp(
      title: 'BondiUY',
      debugShowCheckedModeBanner: false,
      theme: themeBondi(Brightness.light),
      darkTheme: themeBondi(Brightness.dark),
      themeMode: ref.watch(preferenceThemeProvider),
      locale:
          language == Language.es
              ? const Locale('es', 'UY')
              : const Locale('en'),
      // Changing language rebuilds everything with the new texts (the
      // logic and its state live outside, in the providers: nothing is lost).
      home: HomeScreen(key: ValueKey(language)),
      // On the web, on wide screens, inside a phone frame.
      builder: (context, child) {
        final forced = ref.watch(frameForcedProvider);
        return WebFrame(force: forced != null, child: child!);
      },
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appActionsProvider).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(appStateProvider);
    final searching = ref.watch(searchOpenProvider);
    final uiMap = MapUiStatus(
      optionFocused: ref.watch(optionFocusedProvider),
      showBus: ref.watch(showBusProvider),
    );
    // Each trip starts by following you.
    ref.listen<bool>(appStateProvider.select((s) => s.phase is TripPhase), (
      before,
      inTrip,
    ) {
      if (inTrip && before == false) {
        ref.read(showBusProvider.notifier).state = false;
      }
    });
    final c = BondiColors.of(context);
    final height = MediaQuery.sizeOf(context).height;
    final safe = MediaQuery.paddingOf(context);

    // Map areas covered by each phase's panels.
    final margins = switch (status.phase) {
      ExplorePhase() => EdgeInsets.only(
        top: safe.top + 84,
        bottom:
            status.stopQueried != null
                ? height * 0.45
                : status.demo != null
                ? safe.bottom + 12 + ref.watch(heightCardDemoProvider)
                : 24,
      ),
      OptionsPhase() => EdgeInsets.only(
        top: safe.top + 84,
        bottom: safe.bottom + 16 + ref.watch(heightSheetOptionsProvider),
      ),
      final TripPhase v => EdgeInsets.only(
        top: safe.top + 8 + ref.watch(heightCardTripProvider),
        bottom: v.status == TripStatus.completed ? height * 0.42 : 100,
      ),
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (c.brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: BondiMap(
                key: const ValueKey('map'),
                scene: buildScene(status, uiMap),
                framing: framingOf(status, uiMap),
                style: c.map,
                margins: margins,
                controller: ref.watch(controllerMapProvider),
                source: ref.watch(sourceTilesProvider),
                decodeInIsolate: ref.watch(tilesInIsolateProvider),
                onTapStop:
                    status.phase is ExplorePhase
                        ? ref.read(appActionsProvider).queryStop
                        : null,
                onTapMap:
                    status.stopQueried != null
                        ? ref.read(appActionsProvider).closeStop
                        : null,
              ),
            ),
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder:
                    (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.03),
                          end: Offset.zero,
                        ).animate(a),
                        child: child,
                      ),
                    ),
                child: switch (status.phase) {
                  ExplorePhase() => const ExplorePanel(
                    key: ValueKey('phase-explore'),
                  ),
                  OptionsPhase() => const OptionsPanel(
                    key: ValueKey('phase-options'),
                  ),
                  TripPhase() => const TripPanel(key: ValueKey('phase-trip')),
                },
              ),
            ),
            if (searching != null)
              const Positioned.fill(
                child: SearchScreen(key: ValueKey('search')),
              ),
            const NoticeListener(),
          ],
        ),
      ),
    );
  }
}
