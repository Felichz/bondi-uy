// Explore phase: search box on top, tapped stop at the bottom.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contract/app_state.dart';
import '../../contract/providers.dart';
import '../common.dart';
import '../demo/demo.dart';
import '../ui_status.dart';
import '../map/obstacles.dart';
import '../formats.dart';
import '../theme/badges.dart';
import '../theme/theme_preference.dart';
import '../theme/app_theme.dart';
import '../theme/sheet.dart';
import '../texts/language_preference.dart';
import '../texts/texts.dart';

class ExplorePanel extends ConsumerWidget {
  const ExplorePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(appStateProvider);
    final stop = status.stopQueried;
    final demo = status.demo;
    final heightSheet = MediaQuery.sizeOf(context).height * 0.45;
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            left: 12,
            right: 12,
            top: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CardSearch(search: status.search),
                if (!status.location.available &&
                    status.location.status != LocationStatus.searching) ...[
                  const SizedBox(height: 10),
                  _NoticeLocation(status.location.status),
                ],
              ],
            ),
          ),
          if (demo != null && stop == null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Measured(
                onChange:
                    (t) =>
                        ref.read(heightCardDemoProvider.notifier).state =
                            t.height,
                child: DemoCard(demo),
              ),
            ),
          Positioned(
            right: 16,
            bottom:
                stop != null
                    ? heightSheet + 12
                    : demo != null
                    ? ref.watch(heightCardDemoProvider) + 24
                    : 24,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RecenterButton(),
                SizedBox(height: 12),
                MapObstacle(child: _ButtonLanguage()),
                SizedBox(height: 12),
                MapObstacle(child: _ButtonTheme()),
              ],
            ),
          ),
          if (stop != null)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              height: heightSheet - 8,
              child: _SheetStop(stop, key: ValueKey('stop-${stop.stop.id}')),
            ),
        ],
      ),
    );
  }
}

/// "EN" / "ES": shows the language it switches to.
class _ButtonLanguage extends ConsumerWidget {
  const _ButtonLanguage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = BondiColors.of(context);
    final language = ref.watch(languageProvider);
    return Semantics(
      button: true,
      label: tx.languageLabel,
      excludeSemantics: true,
      child: Pressable(
        child: Sheet(
          padding: EdgeInsets.zero,
          radio: BorderRadius.circular(28),
          elevated: false,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: const ValueKey('button-language'),
              customBorder: const CircleBorder(),
              onTap: () => ref.read(languageProvider.notifier).alternate(),
              child: SizedBox(
                width: 52,
                height: 52,
                child: Center(
                  child: Text(
                    language == Language.es ? 'EN' : 'ES',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: c.text,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonTheme extends ConsumerWidget {
  const _ButtonTheme();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(preferenceThemeProvider);
    final (icon, name) = switch (mode) {
      ThemeMode.system => (Icons.brightness_auto_rounded, tx.themeAutomatic),
      ThemeMode.light => (Icons.light_mode_rounded, tx.themeLight),
      ThemeMode.dark => (Icons.dark_mode_rounded, tx.themeDark),
    };
    return SheetButton(
      key: const ValueKey('button-theme'),
      icon: icon,
      label: tx.themeLabel(name),
      onTap: () {
        ref.read(preferenceThemeProvider.notifier).next();
        final fresh = switch (ref.read(preferenceThemeProvider)) {
          ThemeMode.system => tx.themeNoticeAutomatic,
          ThemeMode.light => tx.themeNoticeLight,
          ThemeMode.dark => tx.themeNoticeDark,
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(fresh),
              duration: const Duration(seconds: 2),
            ),
          );
      },
    );
  }
}

class _CardSearch extends ConsumerWidget {
  final Search search;
  const _CardSearch({required this.search});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = BondiColors.of(context);
    final t = Theme.of(context).textTheme;
    final destination = search.destination;
    void open(SearchField field) =>
        ref.read(searchOpenProvider.notifier).state = field;
    if (destination == null) {
      return Sheet(
        padding: EdgeInsets.zero,
        radio: BorderRadius.circular(30),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const ValueKey('search-destination'),
            onTap: () => open(SearchField.destination),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 26, color: c.text),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      tx.whereAreYouGoing,
                      style: t.titleLarge?.copyWith(
                        color: c.textSoft,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Sheet(
      key: const ValueKey('search-full'),
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
      radio: BorderRadius.circular(26),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => open(SearchField.destination),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.from(pointName(search.origin)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pointName(destination),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            key: const ValueKey('see-trips'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            onPressed: () => ref.read(appActionsProvider).searchTrips(),
            child: Text(tx.seeTrips),
          ),
        ],
      ),
    );
  }
}

class _NoticeLocation extends ConsumerWidget {
  final LocationStatus status;
  const _NoticeLocation(this.status);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = BondiColors.of(context);
    final text = switch (status) {
      LocationStatus.disabled => tx.locationOff,
      LocationStatus.withoutPermission => tx.locationWithoutPermission,
      _ => tx.locationNotFound,
    };
    return Sheet(
      key: const ValueKey('notice-location'),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      radio: BorderRadius.circular(20),
      elevated: false,
      child: Row(
        children: [
          Icon(Icons.location_off_rounded, color: c.alert),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 15, color: c.text)),
          ),
          TextButton(
            onPressed: () => ref.read(appActionsProvider).retryLocation(),
            child: Text(tx.activate),
          ),
        ],
      ),
    );
  }
}

class _SheetStop extends ConsumerWidget {
  final StopQuery query;
  const _SheetStop(this.query, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = BondiColors.of(context);
    final t = Theme.of(context).textTheme;
    return Sheet(
      padding: EdgeInsets.zero,
      radio: BorderRadius.circular(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.layer,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.layerBorder),
                  ),
                  child: Icon(Icons.hail_rounded, color: c.text),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stopName(query.stop.name),
                        key: const ValueKey('stop-name'),
                        style: t.titleLarge,
                      ),
                      Text(tx.stopNumber(query.stop.id), style: t.bodyMedium),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('stop-close'),
                  tooltip: tx.close,
                  onPressed: () => ref.read(appActionsProvider).closeStop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(child: _arrivals(context)),
        ],
      ),
    );
  }

  Widget _arrivals(BuildContext context) {
    final c = BondiColors.of(context);
    switch (query.status) {
      case QueryStatus.loading:
        return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
      case QueryStatus.error:
        return _Empty(
          icon: Icons.cloud_off_rounded,
          text: tx.stopErrorArrivals,
        );
      case QueryStatus.ready:
        if (query.arrivals.isEmpty) {
          return _Empty(
            icon: Icons.schedule_rounded,
            text:
                query.lines.isEmpty
                    ? tx.stopWithoutInfo
                    : tx.stopWithoutNext(query.lines.join(', ')),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          itemCount: query.arrivals.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, i) {
            final l = query.arrivals[i];
            return Row(
              key: ValueKey('arrival-$i'),
              children: [
                SizedBox(
                  width: 78,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: BadgeLine(l.line),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    capitalize(l.destination ?? ''),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, color: c.text),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      minutes(l.minutes),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (l.live) LiveDot(size: 6, color: c.live),
                        Text(
                          l.live ? tx.live : tx.schedule,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: l.live ? c.live : c.alert,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        );
    }
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 34, color: c.textFaint),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: c.textSoft),
          ),
        ],
      ),
    );
  }
}
