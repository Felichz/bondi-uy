// Options phase: the recommended one in front; the others one swipe away.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contract/app_state.dart';
import '../../contract/providers.dart';
import '../common.dart';
import '../ui_status.dart';
import '../formats.dart';
import '../theme/badges.dart';
import '../theme/app_theme.dart';
import '../theme/sheet.dart';
import '../texts/texts.dart';

class OptionsPanel extends ConsumerWidget {
  const OptionsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(appStateProvider);
    final phase = status.phase;
    if (phase is! OptionsPhase) return const SizedBox.shrink();
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            left: 12,
            right: 12,
            top: 8,
            child: _Header(status.search),
          ),
          Positioned(
            right: 16,
            bottom: ref.watch(heightSheetOptionsProvider) + 20,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [RecenterButton()],
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Measured(
              onChange:
                  (t) =>
                      ref.read(heightSheetOptionsProvider.notifier).state =
                          t.height,
              child: _Sheet(phase),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  final Search search;
  const _Header(this.search);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = BondiColors.of(context);
    final t = Theme.of(context).textTheme;
    return Sheet(
      key: const ValueKey('options-header'),
      padding: const EdgeInsets.fromLTRB(4, 6, 14, 6),
      radio: BorderRadius.circular(26),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('options-close'),
            tooltip: tx.back,
            onPressed: () {
              ref.read(optionFocusedProvider.notifier).state = null;
              ref.read(appActionsProvider).closeOptions();
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: InkWell(
              key: const ValueKey('options-edit'),
              borderRadius: BorderRadius.circular(12),
              onTap:
                  () =>
                      ref.read(searchOpenProvider.notifier).state =
                          SearchField.destination,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.from(pointName(search.origin)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyMedium?.copyWith(fontSize: 14),
                    ),
                    Text(
                      pointName(search.destination),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium?.copyWith(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Icon(Icons.edit_rounded, size: 20, color: c.textFaint),
        ],
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  final OptionsPhase phase;
  const _Sheet(this.phase);

  @override
  Widget build(BuildContext context) {
    return Sheet(
      key: const ValueKey('options-sheet'),
      padding: EdgeInsets.zero,
      radio: BorderRadius.circular(30),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: switch (phase.status) {
          OptionsStatus.loading => const _Loading(),
          OptionsStatus.error => _WithoutOptions(
            icon: Icons.cloud_off_rounded,
            title: tx.errorPlanTitle,
            text: tx.errorPlanText,
            retry: true,
          ),
          OptionsStatus.withoutResults => _WithoutOptions(
            icon: Icons.directions_bus_outlined,
            title: tx.withoutTripsTitle,
            text: tx.withoutTripsText,
            retry: false,
          ),
          OptionsStatus.ready => _Carousel(phase),
        },
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      key: const ValueKey('options-loading'),
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const SizedBox(
              width: 120,
              child: LinearProgressIndicator(minHeight: 4),
            ),
          ),
          const SizedBox(height: 20),
          Text(tx.searchingTrip, style: t.titleLarge),
        ],
      ),
    );
  }
}

class _WithoutOptions extends ConsumerWidget {
  final IconData icon;
  final String title;
  final String text;
  final bool retry;
  const _WithoutOptions({
    required this.icon,
    required this.title,
    required this.text,
    required this.retry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = BondiColors.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      key: const ValueKey('options-empty'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 38, color: c.textFaint),
          const SizedBox(height: 12),
          Text(title, style: t.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(text, style: t.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              if (retry) {
                ref.read(appActionsProvider).searchTrips();
              } else {
                ref.read(searchOpenProvider.notifier).state =
                    SearchField.destination;
              }
            },
            child: Text(retry ? tx.retry : tx.changeDestination),
          ),
        ],
      ),
    );
  }
}

class _Carousel extends ConsumerStatefulWidget {
  final OptionsPhase phase;
  const _Carousel(this.phase);

  @override
  ConsumerState<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends ConsumerState<_Carousel> {
  late final PageController _pages;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    final ops = widget.phase.options;
    final previous = ref.read(optionFocusedProvider);
    var i = ops.indexWhere((o) => o.id == previous);
    if (i < 0) i = ops.indexWhere((o) => o.recommended);
    _index = i < 0 ? 0 : i;
    _pages = PageController(initialPage: _index);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus(_index));
  }

  void _focus(int i) {
    final ops = widget.phase.options;
    if (i >= ops.length) return;
    if (i != _index) HapticFeedback.selectionClick();
    setState(() => _index = i);
    ref.read(optionFocusedProvider.notifier).state = ops[i].id;
    ref.read(appActionsProvider).focusOption(ops[i].id);
  }

  void _goTo(int i) => _pages.animateToPage(
    i,
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ops = widget.phase.options;
    final current = ops[_index.clamp(0, ops.length - 1)];
    // The card height grows with the system text size (accessibility).
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SheetHandle(),
        SizedBox(
          height: 172 * scale.clamp(1.0, 1.6),
          child: PageView.builder(
            key: const ValueKey('options-carousel'),
            controller: _pages,
            itemCount: ops.length,
            onPageChanged: _focus,
            itemBuilder: (context, i) => _CardOption(ops[i]),
          ),
        ),
        _Pager(
          total: ops.length,
          current: _index,
          onPrevious: _index > 0 ? () => _goTo(_index - 1) : null,
          onNext: _index < ops.length - 1 ? () => _goTo(_index + 1) : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: BondiColors.of(context).shadow,
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                  spreadRadius: -6,
                ),
              ],
            ),
            child: FilledButton.icon(
              key: const ValueKey('start-trip'),
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(appActionsProvider).startTrip(current.id);
              },
              icon: const Icon(Icons.navigation_rounded),
              label: Text(tx.startTrip),
            ),
          ),
        ),
      ],
    );
  }
}

/// "‹ 1 de 6 ›" (1 of 6): where you are in the carousel, with arrows for
/// those who don't discover the swipe.
class _Pager extends StatelessWidget {
  final int total;
  final int current;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  const _Pager({
    required this.total,
    required this.current,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    if (total <= 1) return const SizedBox(height: 8);
    Widget arrow(IconData i, VoidCallback? f, String label) => IconButton(
      onPressed: f,
      tooltip: label,
      visualDensity: VisualDensity.compact,
      icon: Icon(i, size: 22),
      color: c.text,
      disabledColor: c.textFaint.withValues(alpha: 0.35),
    );
    return Semantics(
      label: tx.optionNofM(current + 1, total),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          arrow(Icons.chevron_left_rounded, onPrevious, tx.previousOption),
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == current ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color:
                    i == current ? c.text : c.textFaint.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          arrow(Icons.chevron_right_rounded, onNext, tx.nextOption),
        ],
      ),
    );
  }
}

class _CardOption extends StatelessWidget {
  final TripOption option;
  const _CardOption(this.option);

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    final t = Theme.of(context).textTheme;
    final boarding = option.firstBus?.boarding;
    return Padding(
      key: ValueKey('option-${option.id}'),
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                duration(option.durationSeconds),
                key: ValueKey('option-${option.id}-duration'),
                style: t.headlineMedium,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${time(option.exit)} – ${time(option.arrival)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (option.recommended) const _StampRecommended(),
            ],
          ),
          const SizedBox(height: 12),
          _BarLegs(option),
          const SizedBox(height: 14),
          _NextBus(option),
          const SizedBox(height: 3),
          Text(
            [
              if (boarding != null) tx.boardIn(stopName(boarding.name)),
              tx.walk(distance(option.walkMeters)),
              if (option.transfers > 0) tx.transfers(option.transfers),
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.bodyMedium?.copyWith(fontSize: 14, color: c.textSoft),
          ),
        ],
      ),
    );
  }
}

class _StampRecommended extends StatelessWidget {
  const _StampRecommended();

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    return Container(
      key: const ValueKey('recommended-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.live.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 13, color: c.live),
          const SizedBox(width: 4),
          Text(
            tx.recommended,
            style: TextStyle(
              color: c.live,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// The trip as a bar: each leg takes up as long as it lasts. Walks in
/// gray with their icon, buses in red with the line. The wait is the gap
/// between the walk and the bus.
class _BarLegs extends StatelessWidget {
  final TripOption option;
  const _BarLegs(this.option);

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    final legs = [
      for (final t in option.legs)
        if (t is! WaitLeg) t,
    ];
    return Semantics(
      label: tx.barLegs(option.lines),
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, box) {
          const gap = 4.0, minWalk = 30.0, minBus = 62.0;
          final free = box.maxWidth - gap * (legs.length - 1);
          double weight(Leg t) => switch (t) {
            WalkLeg(:final durationSeconds) => durationSeconds * 1.0,
            BusLeg(:final durationSeconds) => durationSeconds * 1.0,
            WaitLeg() => 0,
          };
          double min(Leg t) => t is BusLeg ? minBus : minWalk;
          // Proportional to the duration, without any leg becoming unreadable.
          final total = legs.fold(0.0, (a, t) => a + weight(t));
          final widths = [
            for (final t in legs)
              math.max(min(t), free * weight(t) / math.max(1, total)),
          ];
          final surplus = widths.fold(0.0, (a, w) => a + w) - free;
          if (surplus > 0) {
            final flexible = [
              for (var i = 0; i < legs.length; i++)
                if (widths[i] > min(legs[i])) i,
            ];
            final margin = flexible.fold(
              0.0,
              (a, i) => a + widths[i] - min(legs[i]),
            );
            for (final i in flexible) {
              final w = widths[i] - min(legs[i]);
              widths[i] -= margin <= 0 ? 0 : surplus * w / margin;
            }
          }
          return Row(
            children: [
              for (var i = 0; i < legs.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                SizedBox(
                  width: math.max(min(legs[i]), widths[i]),
                  height: 28,
                  child: switch (legs[i]) {
                    final BusLeg b => _SegmentBus(b.line),
                    final WalkLeg w => _SegmentWalk(
                      minutes: (w.durationSeconds / 60).round(),
                      color: c,
                    ),
                    WaitLeg() => const SizedBox.shrink(),
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SegmentBus extends StatelessWidget {
  final String line;
  const _SegmentBus(this.line);

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: c.bus,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.directions_bus_rounded,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              line,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentWalk extends StatelessWidget {
  final int minutes;
  final BondiColors color;
  const _SegmentWalk({required this.minutes, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = color;
    return LayoutBuilder(
      builder:
          (context, box) => Container(
            decoration: BoxDecoration(
              color: c.layer,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: c.layerBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.directions_walk_rounded,
                  size: 16,
                  color: c.textSoft,
                ),
                if (box.maxWidth >= 54)
                  Text(
                    '$minutes',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.textSoft,
                    ),
                  ),
              ],
            ),
          ),
    );
  }
}

class _NextBus extends StatelessWidget {
  final TripOption option;
  const _NextBus(this.option);

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    final first = option.firstBus;
    if (first == null) {
      return _Line(
        icon: Icons.directions_walk_rounded,
        text: tx.allOnFoot,
        color: c.textSoft,
      );
    }
    final arrival = option.nextBus;
    if (option.notice == NoticeOption.firstBusMayNotReach && arrival != null) {
      return _Line(
        icon: Icons.warning_amber_rounded,
        text: tx.passesMaybeNotArrive(first.line, minutes(arrival.minutes)),
        color: c.alert,
      );
    }
    if (arrival != null && arrival.live) {
      return Row(
        key: ValueKey('option-${option.id}-live'),
        children: [
          LiveDot(color: c.live, size: 8),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              tx.passesIn(first.line, minutes(arrival.minutes)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.live,
              ),
            ),
          ),
        ],
      );
    }
    if (arrival != null) {
      return _Line(
        icon: Icons.schedule_rounded,
        text: tx.wouldPassIn(first.line, minutes(arrival.minutes)),
        color: c.alert,
      );
    }
    return _Line(
      icon: Icons.schedule_rounded,
      text: tx.exitsWithoutData(time(option.exit)),
      color: c.textSoft,
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Line({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    ],
  );
}
