// Trip phase: one clear instruction per step, which advances on its own.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contract/app_state.dart';
import '../../contract/providers.dart';
import '../common.dart';
import '../ui_status.dart';
import '../map/obstacles.dart';
import '../formats.dart';
import '../theme/badges.dart';
import '../theme/app_theme.dart';
import '../theme/sheet.dart';
import 'itinerary.dart';
import '../texts/texts.dart';

class TripPanel extends ConsumerStatefulWidget {
  const TripPanel({super.key});

  @override
  ConsumerState<TripPanel> createState() => _TripPanelState();
}

class _TripPanelState extends ConsumerState<TripPanel> {
  /// Brief confirmation of a step advance ("Subiste al D1").
  ({int id, String text, IconData icon})? _advance;
  Timer? _hideAdvance;
  int _ids = 0;

  @override
  void dispose() {
    _hideAdvance?.cancel();
    super.dispose();
  }

  void _onPhaseChange(Phase? before, Phase now) {
    if (before is! TripPhase || now is! TripPhase) return;
    final advanced =
        now.currentStep > before.currentStep ||
        (now.status == TripStatus.completed &&
            before.status != TripStatus.completed);
    // A notice from the previous step ("¡Bajate en la próxima!", "Tu bus está
    // llegando") no longer applies: it goes away and does not cover what comes next.
    if (advanced) ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    if (now.status == TripStatus.completed &&
        before.status != TripStatus.completed) {
      HapticFeedback.heavyImpact();
      return;
    }
    if (now.currentStep <= before.currentStep) return;
    final (text, icon) = switch (before.currentLeg) {
      WalkLeg() => (tx.arrivedToStop, Icons.hail_rounded),
      WaitLeg(:final line) => (
        tx.boardedOn(line),
        Icons.directions_bus_rounded,
      ),
      BusLeg(:final line) => (
        tx.gotOffLine(line),
        Icons.directions_walk_rounded,
      ),
    };
    HapticFeedback.mediumImpact();
    _hideAdvance?.cancel();
    setState(() => _advance = (id: ++_ids, text: text, icon: icon));
    _hideAdvance = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _advance = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<Phase>(appStateProvider.select((s) => s.phase), _onPhaseChange);
    final status = ref.watch(appStateProvider);
    final phase = status.phase;
    if (phase is! TripPhase) return const SizedBox.shrink();
    final destination = pointName(
      status.search.destination,
      empty: tx.yourDestination,
    );
    final completed = phase.status == TripStatus.completed;
    final advance = _advance;
    return SafeArea(
      child: Stack(
        children: [
          if (!completed)
            Positioned(
              left: 12,
              right: 12,
              top: 8,
              child: Measured(
                onChange:
                    (t) =>
                        ref.read(heightCardTripProvider.notifier).state =
                            t.height,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  layoutBuilder:
                      (current, previous) => Stack(
                        alignment: Alignment.topCenter,
                        children: [...previous, if (current != null) current],
                      ),
                  transitionBuilder:
                      (c, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0.04, 0),
                            end: Offset.zero,
                          ).animate(a),
                          child: c,
                        ),
                      ),
                  child: _CardStep(
                    phase,
                    destination,
                    key: ValueKey('step-${phase.currentStep}'),
                  ),
                ),
              ),
            ),
          if (!completed)
            // Above the step advance confirmation ("Subiste al D1").
            const Positioned(
              right: 16,
              bottom: 136,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TripCameraButton(),
                  SizedBox(height: 12),
                  RecenterButton(),
                ],
              ),
            ),
          if (!completed)
            Positioned(
              left: 12,
              right: 12,
              bottom: 78,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutBack,
                  transitionBuilder:
                      (c, a) => FadeTransition(
                        opacity: a,
                        child: ScaleTransition(scale: a, child: c),
                      ),
                  child:
                      advance == null
                          ? const SizedBox.shrink()
                          : MapObstacle(
                            key: ValueKey('advance-${advance.id}'),
                            child: _AdvancePill(advance.text, advance.icon),
                          ),
                ),
              ),
            ),
          if (!completed)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _BottomBar(phase, destination),
            ),
          if (completed)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _Arrival(phase, destination),
            ),
        ],
      ),
    );
  }
}

/// "✓ Subiste al D1": confirms that the trip advanced on its own.
class _AdvancePill extends StatelessWidget {
  final String text;
  final IconData icon;
  const _AdvancePill(this.text, this.icon);

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(7, 7, 16, 7),
        decoration: BoxDecoration(
          color: c.action,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: c.shadow,
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: c.live, shape: BoxShape.circle),
              child: const Icon(
                Icons.check_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 18, color: c.overAction.withValues(alpha: 0.7)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                key: const ValueKey('trip-advance'),
                style: TextStyle(
                  color: c.overAction,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Instruction card
// ---------------------------------------------------------------------------

class _CardStep extends StatelessWidget {
  final TripPhase f;
  final String destination;
  const _CardStep(this.f, this.destination, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = f.currentLeg;
    final urgent = t is BusLeg && f.progress.stopsLeft == 0;
    return _Highlight(
      active: urgent,
      child: Sheet(
        key: const ValueKey('trip-card'),
        radio: BorderRadius.circular(28),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(f),
            const SizedBox(height: 10),
            _StripSteps(f),
            const SizedBox(height: 16),
            switch (t) {
              WalkLeg() => _StepWalk(f, t, destination),
              WaitLeg() => _StepWait(f, t),
              BusLeg() => _StepBus(f, t),
            },
          ],
        ),
      ),
    );
  }
}

/// Border that pulses around the card: "bajate en la próxima".
class _Highlight extends StatefulWidget {
  final bool active;
  final Widget child;
  const _Highlight({required this.active, required this.child});

  @override
  State<_Highlight> createState() => _HighlightState();
}

class _HighlightState extends State<_Highlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _synchronize();
  }

  @override
  void didUpdateWidget(_Highlight old) {
    super.didUpdateWidget(old);
    _synchronize();
  }

  void _synchronize() {
    final beat = widget.active && !MediaQuery.disableAnimationsOf(context);
    if (beat && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!beat && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    final c = BondiColors.of(context);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder:
          (context, child) => DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: c.bus.withValues(
                  alpha: _c.isAnimating ? 0.45 + 0.55 * _c.value : 1,
                ),
                width: 3,
              ),
            ),
            child: child,
          ),
    );
  }
}

class _Header extends StatelessWidget {
  final TripPhase f;
  const _Header(this.f);

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    final style = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: c.textSoft,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Row(
      children: [
        Text(
          tx.stepNofM(f.currentStep + 1, f.totalSteps),
          key: const ValueKey('trip-step'),
          style: style,
        ),
        const Spacer(),
        Icon(Icons.flag_rounded, size: 15, color: c.textSoft),
        const SizedBox(width: 4),
        Text(
          tx.arrive(time(f.option.arrival)),
          key: const ValueKey('trip-arrive'),
          style: style,
        ),
      ],
    );
  }
}

class _StripSteps extends StatelessWidget {
  final TripPhase f;
  const _StripSteps(this.f);

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    Color color(Leg t) => switch (t) {
      WalkLeg() => c.walk,
      WaitLeg() => c.live,
      BusLeg() => c.bus,
    };
    final fraction = f.progress.fraction;
    return Row(
      children: [
        for (var i = 0; i < f.totalSteps; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            flex: f.option.legs[i] is BusLeg ? 3 : 2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color:
                          i < f.currentStep
                              ? c.text.withValues(alpha: 0.55)
                              : i == f.currentStep
                              ? color(f.option.legs[i]).withValues(alpha: 0.25)
                              : c.separator,
                    ),
                    // The current step fills with its progress.
                    if (i == f.currentStep)
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor:
                            fraction == null ? 1 : math.max(0.12, fraction),
                        child: ColoredBox(color: color(f.option.legs[i])),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Title extends StatelessWidget {
  final Widget icon;
  final String title;
  final String? detail;
  const _Title({required this.icon, required this.title, this.detail});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        icon,
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                key: const ValueKey('trip-instruction'),
                style: t.headlineSmall,
              ),
              if (detail != null) ...[
                const SizedBox(height: 2),
                Text(
                  detail!,
                  key: const ValueKey('trip-detail'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  final String large;
  final String? small;
  final Color? color;
  const _Figure(this.large, {this.small, this.color});

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    // Always on one line: if it does not fit (English on a narrow phone) it
    // shrinks. Split across two lines, maxLines: 1 would cut off the number.
    final number = FittedBox(
      key: ValueKey(large),
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        large,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
          height: 1.15,
          color: color ?? c.text,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    return Row(
      key: const ValueKey('trip-figure'),
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // Only the big figure animates, and only when it changes ("Faltan 9
        // paradas" -> "Faltan 8 paradas"): the new one rises with a fade. The
        // old one leaves at once: fading out under the new one, two numbers
        // were read on top of each other (and a distance changes often).
        Flexible(
          child: AnimatedSwitcher(
            duration: Duration(
              milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 260,
            ),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder:
                (current, previous) => Stack(
                  alignment: Alignment.centerLeft,
                  children: [if (current != null) current],
                ),
            transitionBuilder:
                (child, a) => ClipRect(
                  child: FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(a),
                      child: child,
                    ),
                  ),
                ),
            child: number,
          ),
        ),
        if (small != null) ...[
          const SizedBox(width: 12),
          Text(
            small!,
            maxLines: 1,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: c.textSoft,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}

class _IconRound extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double? progress;
  const _IconRound(this.icon, this.color, {this.progress});

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    final p = progress;
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
          ),
          if (p != null)
            SizedBox(
              width: 54,
              height: 54,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: p),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder:
                    (_, v, __) => CircularProgressIndicator(
                      key: const ValueKey('trip-progress'),
                      value: v,
                      strokeWidth: 3.5,
                      strokeCap: StrokeCap.round,
                      backgroundColor: c.separator,
                      color: color,
                    ),
              ),
            ),
          Icon(icon, color: color, size: 26),
        ],
      ),
    );
  }
}

class _StepWalk extends StatelessWidget {
  final TripPhase f;
  final WalkLeg t;
  final String destinationName;
  const _StepWalk(this.f, this.t, this.destinationName);

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    final destination =
        t.towardStop != null
            ? tx.stop(stopName(t.towardStop!.name))
            : destinationName;
    final rest = f.progress.metersLeft ?? t.distanceMeters;
    final next =
        f.currentStep + 1 < f.totalSteps
            ? f.option.legs[f.currentStep + 1]
            : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Title(
          icon: _IconRound(
            Icons.directions_walk_rounded,
            c.walk,
            progress: f.progress.fraction ?? 0,
          ),
          title: t.isAtDestination ? tx.walksOnDestination : tx.walksToTheStop,
          detail: destination,
        ),
        const SizedBox(height: 12),
        _Figure(
          distance(rest),
          small: tx.walking(duration(secondsWalking(rest))),
        ),
        if (!t.isAtDestination && f.busExpected != null) ...[
          const SizedBox(height: 12),
          _BusThatComes(f.busExpected!, secondsWalking(rest)),
        ] else if (next is WaitLeg) ...[
          const SizedBox(height: 10),
          _After(tx.afterWait(next.line)),
        ],
      ],
    );
  }
}

/// What comes next, in small print.
class _After extends StatelessWidget {
  final String text;
  const _After(this.text);

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    return Row(
      children: [
        Icon(
          Icons.subdirectory_arrow_right_rounded,
          size: 18,
          color: c.textFaint,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, color: c.textSoft),
          ),
        ),
      ],
    );
  }
}

/// While you walk to the stop: when your bus passes and whether you make it.
class _BusThatComes extends StatelessWidget {
  final BusInPath bus;
  final int secondsUntilStop;
  const _BusThatComes(this.bus, this.secondsUntilStop);

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    final just = bus.minutes * 60 < secondsUntilStop;
    final color = !bus.live || just ? c.alert : c.live;
    return Layer(
      key: const ValueKey('trip-incoming-bus'),
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
      child: Row(
        children: [
          BadgeLine(bus.line),
          const SizedBox(width: 10),
          if (bus.live) LiveDot(color: color),
          if (bus.live) const SizedBox(width: 4),
          Expanded(
            child: Text(
              just
                  ? tx.passesQuickly(minutes(bus.minutes))
                  : tx.passesInShort(minutes(bus.minutes), live: bus.live),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepWait extends StatefulWidget {
  final TripPhase f;
  final WaitLeg t;
  const _StepWait(this.f, this.t);

  @override
  State<_StepWait> createState() => _StepWaitState();
}

class _StepWaitState extends State<_StepWait> {
  /// The greatest distance at which we saw the bus in this step: the 0% of the track.
  int? _startMeters;

  /// The live bus was about to arrive. Once it reaches the stop it stops
  /// "coming" (the source no longer reports it): it is not "no data", it arrived.
  bool _wasArriving = false;

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    final f = widget.f, t = widget.t;
    final bus = f.busExpected;
    final meters = bus != null && bus.live ? bus.metersUntilStop : null;
    if (meters != null && meters > (_startMeters ?? 0)) {
      _startMeters = meters;
    }
    if (bus != null && bus.live) {
      _wasArriving = bus.minutes <= 1 || (meters != null && meters <= 300);
    }
    final arrived = bus == null && _wasArriving;
    final start = _startMeters;
    final Widget figure;
    if (arrived) {
      figure = Row(
        key: const ValueKey('trip-bus-arrived'),
        children: [
          LiveDot(size: 11, color: c.live),
          const SizedBox(width: 6),
          Expanded(child: _Figure(tx.arrivedYourBus, color: c.live)),
        ],
      );
    } else if (bus != null && bus.live) {
      figure = Row(
        children: [
          LiveDot(size: 11, color: c.live),
          const SizedBox(width: 6),
          Expanded(
            child: _Figure(
              bus.minutes <= 0
                  ? tx.arriving
                  : tx.arrivesIn(minutes(bus.minutes)),
              small: meters != null ? tx.toDistance(distance(meters)) : null,
              color: c.live,
            ),
          ),
        ],
      );
    } else if (bus != null) {
      figure = _Figure(
        tx.inApprox(minutes(bus.minutes)),
        small: tx.perSchedule,
        color: c.alert,
      );
    } else {
      figure = Text(
        tx.withoutDataBus,
        key: const ValueKey('trip-no-data'),
        style: TextStyle(fontSize: 16, color: c.textSoft),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Title(
          icon: BadgeLine(t.line, large: true),
          title: tx.wait(t.line),
          detail: [
            if (t.destinationLine != null)
              tx.toward(capitalize(t.destinationLine!)),
            tx.stop(stopName(t.stop.name)),
          ].join(' · '),
        ),
        const SizedBox(height: 12),
        figure,
        if ((meters != null || arrived) && start != null) ...[
          const SizedBox(height: 14),
          _TrackBus(meters: meters ?? 0, metersStart: start),
        ],
        if (arrived) ...[
          const SizedBox(height: 12),
          Text(
            tx.waveAndBoard,
            style: TextStyle(fontSize: 15, color: c.textSoft),
          ),
        ] else if (bus != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              _Label(
                bus.live ? tx.liveUpper : tx.scheduleUpper,
                color: bus.live ? c.live : c.alert,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bus.live ? tx.makeSign : tx.canVary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: c.textSoft),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final Color color;
  const _Label(this.text, {required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: color,
      ),
    ),
  );
}

/// The bus approaching your stop: a track with the bus moving along it.
class _TrackBus extends StatelessWidget {
  final int meters;
  final int metersStart;
  const _TrackBus({required this.meters, required this.metersStart});

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    final advance =
        metersStart <= 0 ? 1.0 : (1 - meters / metersStart).clamp(0.0, 1.0);
    const icon = 30.0, stop = 26.0;
    return Semantics(
      label: tx.busToDistance(distance(meters)),
      excludeSemantics: true,
      child: SizedBox(
        key: const ValueKey('trip-bus-track'),
        height: icon,
        child: LayoutBuilder(
          builder: (context, box) {
            final route = box.maxWidth - icon - stop;
            return TweenAnimationBuilder<double>(
              tween: Tween(end: advance),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOut,
              builder:
                  (context, v, _) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Track: what has been covered in green, what is left in gray.
                      Positioned(
                        left: icon / 2,
                        right: stop / 2,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: c.separator,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Positioned(
                        left: icon / 2,
                        width: route * v + 1,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: c.live,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Your stop, at the end.
                      Positioned(
                        right: 0,
                        child: Container(
                          width: stop,
                          height: stop,
                          decoration: BoxDecoration(
                            color: c.sheetSolid,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.bus, width: 3),
                          ),
                          child: Icon(
                            Icons.north_rounded,
                            size: 14,
                            color: c.bus,
                          ),
                        ),
                      ),
                      Positioned(
                        left: route * v,
                        child: Container(
                          width: icon,
                          height: icon,
                          decoration: BoxDecoration(
                            color: c.bus,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.live, width: 2.5),
                          ),
                          child: const Icon(
                            Icons.directions_bus_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
            );
          },
        ),
      ),
    );
  }
}

class _StepBus extends StatelessWidget {
  final TripPhase f;
  final BusLeg t;
  const _StepBus(this.f, this.t);

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    final missing = f.progress.stopsLeft;
    final last = missing == 0;
    final next = f.progress.nextStop;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Title(
          icon: BadgeLine(t.line, large: true),
          title: last ? tx.getOffAtNext : tx.travelsIn(t.line),
          detail: tx.getOffAt(stopName(t.alighting.name)),
        ),
        const SizedBox(height: 12),
        if (last)
          Container(
            key: const ValueKey('trip-get-off'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: c.bus,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tx.ringsTheBell,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          _Figure(
            missing == null
                ? distance(t.distanceMeters)
                : tx.missing(stops(missing + 1)),
            small:
                f.progress.metersLeft != null
                    ? distance(f.progress.metersLeft!)
                    : null,
          ),
          if (missing != null) ...[
            const SizedBox(height: 10),
            _StripStops(
              total: t.stopsIntermediate.length + 1,
              missing: missing,
            ),
          ],
          if (next != null && next.id != t.alighting.id) ...[
            const SizedBox(height: 8),
            Row(
              key: const ValueKey('trip-next'),
              children: [
                _Label(tx.nextUpper, color: c.bus),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stopName(next.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: c.text,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

/// The stops of the bus leg as a line of dots: the ones already passed,
/// where you are headed, and yours at the end.
class _StripStops extends StatelessWidget {
  final int total;
  final int missing;
  const _StripStops({required this.total, required this.missing});

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    return Semantics(
      label: tx.missingToGetOff(stops(missing + 1)),
      excludeSemantics: true,
      child: SizedBox(
        key: const ValueKey('trip-stop-strip'),
        height: 24,
        width: double.infinity,
        child: CustomPaint(
          painter: _PainterStripStops(
            total: total,
            doneCount: (total - missing - 1).clamp(0, total),
            bus: c.bus,
            done: c.textFaint,
            background: c.sheetSolid,
            ink: c.text,
          ),
        ),
      ),
    );
  }
}

class _PainterStripStops extends CustomPainter {
  final int total, doneCount;
  final Color bus, done, background, ink;
  _PainterStripStops({
    required this.total,
    required this.doneCount,
    required this.bus,
    required this.done,
    required this.background,
    required this.ink,
  });

  @override
  void paint(Canvas c, Size s) {
    final y = s.height / 2;
    const margin = 10.0;
    final width = s.width - 2 * margin;
    // 0 = the boarding, [total] = your stop.
    double x(num i) => margin + width * i / math.max(1, total);
    final you = x(doneCount + 0.5);
    Paint stroke(Color color) =>
        Paint()
          ..color = color
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
    c.drawLine(
      Offset(margin, y),
      Offset(you, y),
      stroke(done.withValues(alpha: 0.45)),
    );
    c.drawLine(Offset(you, y), Offset(x(total), y), stroke(bus));
    // Intermediate stops, thinned out if there are many.
    final jump = total > 28 ? 2 : 1;
    for (var i = 1; i < total; i += jump) {
      final p = Offset(x(i), y);
      final past = i <= doneCount;
      final next = i == doneCount + 1;
      final r = next ? 5.5 : 3.2;
      c.drawCircle(p, r, Paint()..color = background);
      c.drawCircle(
        p,
        r,
        Paint()
          ..color = past ? done : bus
          ..style = PaintingStyle.stroke
          ..strokeWidth = next ? 2.6 : 1.8,
      );
    }
    // Your stop.
    final end = Offset(x(total), y);
    c.drawCircle(end, 9, Paint()..color = ink);
    c.drawCircle(end, 3.8, Paint()..color = background);
    // You, on the bus.
    c.drawCircle(Offset(you, y), 7.5, Paint()..color = background);
    c.drawCircle(Offset(you, y), 5, Paint()..color = bus);
  }

  @override
  bool shouldRepaint(_PainterStripStops o) =>
      o.total != total ||
      o.doneCount != doneCount ||
      o.bus != bus ||
      o.background != background;
}

// ---------------------------------------------------------------------------
// Bottom bar: finish, itinerary and manual fallback
// ---------------------------------------------------------------------------

class _BottomBar extends ConsumerWidget {
  final TripPhase f;
  final String destination;
  const _BottomBar(this.f, this.destination);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = BondiColors.of(context);
    final t = f.currentLeg;
    final isLast = f.currentStep == f.totalSteps - 1;
    final text = switch (t) {
      WalkLeg() when isLast => tx.alreadyArrived,
      WalkLeg() => tx.alreadyAtTheStop,
      WaitLeg() => tx.alreadyBoarded,
      BusLeg() => tx.alreadyGotOff,
    };
    return Row(
      children: [
        SheetButton(
          key: const ValueKey('trip-finish'),
          icon: Icons.close_rounded,
          label: tx.finishTrip,
          onTap: () => _confirmFinish(context, ref),
        ),
        const SizedBox(width: 10),
        SheetButton(
          key: const ValueKey('trip-itinerary'),
          icon: Icons.format_list_bulleted_rounded,
          label: tx.seeWholeTrip,
          onTap: () => showItinerary(context, f, destination),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Pressable(
            child: Sheet(
              padding: EdgeInsets.zero,
              radio: BorderRadius.circular(26),
              elevated: false,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  key: const ValueKey('trip-confirm-step'),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(appActionsProvider).confirmCurrentStep();
                  },
                  child: SizedBox(
                    height: 52,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            size: 20,
                            color: c.textSoft,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: c.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmFinish(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(tx.finishQuestion),
            content: Text(tx.finishText),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tx.follow),
              ),
              TextButton(
                key: const ValueKey('trip-finish-confirm'),
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                  foregroundColor: BondiColors.of(ctx).danger,
                ),
                child: Text(tx.finish),
              ),
            ],
          ),
    );
    if (ok == true) ref.read(appActionsProvider).finishTrip();
  }
}

// ---------------------------------------------------------------------------
// Arrival
// ---------------------------------------------------------------------------

class _Arrival extends ConsumerStatefulWidget {
  final TripPhase f;
  final String destination;
  const _Arrival(this.f, this.destination);

  @override
  ConsumerState<_Arrival> createState() => _ArrivalState();
}

class _ArrivalState extends ConsumerState<_Arrival> {
  Timer? _close;

  @override
  void initState() {
    super.initState();
    _close = Timer(const Duration(seconds: 12), () {
      if (mounted) ref.read(appActionsProvider).closeArrival();
    });
  }

  @override
  void dispose() {
    _close?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    final t = Theme.of(context).textTheme;
    final f = widget.f;
    final seconds = f.end?.difference(f.start).inSeconds;
    final check = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: c.live.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.check_rounded, color: c.live, size: 42),
    );
    return Sheet(
      key: const ValueKey('trip-arrival'),
      radio: BorderRadius.circular(28),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child:
                MediaQuery.disableAnimationsOf(context)
                    ? check
                    : TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 750),
                      curve: Curves.elasticOut,
                      builder:
                          (_, v, child) =>
                              Transform.scale(scale: v, child: child),
                      child: check,
                    ),
          ),
          const SizedBox(height: 16),
          Text(
            tx.arrived,
            textAlign: TextAlign.center,
            style: t.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            widget.destination,
            key: const ValueKey('trip-arrival-destination'),
            textAlign: TextAlign.center,
            style: t.titleMedium,
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (seconds != null)
                _Fact(Icons.schedule_rounded, duration(seconds)),
              if (f.option.walkMeters > 0)
                _Fact(
                  Icons.directions_walk_rounded,
                  distance(f.option.walkMeters),
                ),
              for (final l in f.option.lines) BadgeLine(l),
            ],
          ),
          const SizedBox(height: 22),
          FilledButton(
            key: const ValueKey('trip-done'),
            onPressed: () => ref.read(appActionsProvider).closeArrival(),
            child: Text(tx.ready),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Fact(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    return Layer(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      radio: BorderRadius.circular(10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c.textSoft),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
