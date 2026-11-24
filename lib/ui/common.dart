// UI pieces shared across phases.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contract/app_state.dart';
import '../contract/providers.dart';
import 'ui_status.dart';
import 'map/framing.dart';
import 'theme/app_theme.dart';
import 'theme/sheet.dart';
import 'texts/texts.dart';

/// Floating button to re-center the map when the user has moved it.
class RecenterButton extends ConsumerWidget {
  const RecenterButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctl = ref.watch(controllerMapProvider);
    final c = BondiColors.of(context);
    return ListenableBuilder(
      listenable: ctl,
      builder:
          (context, _) => AnimatedScale(
            scale: ctl.free ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: SheetButton(
              key: const ValueKey('button-recenter'),
              icon: Icons.my_location_rounded,
              label: tx.recenterMap,
              color: c.walk,
              onTap: ctl.recenter,
            ),
          ),
    );
  }
}

/// On a trip, with a bus coming: switches the camera between following you and
/// following the bus. Its label says what tapping it does ("See the bus" / "See me").
class TripCameraButton extends ConsumerWidget {
  const TripCameraButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final can = ref.watch(
      appStateProvider.select(
        (s) => switch (s.phase) {
          final TripPhase f => canSeeBus(f),
          _ => false,
        },
      ),
    );
    final showBus = ref.watch(showBusProvider);
    final c = BondiColors.of(context);
    final icon =
        showBus
            ? Icons.person_pin_circle_rounded
            : Icons.directions_bus_rounded;
    final text = showBus ? tx.seeMe : tx.seeTheBus;
    return AnimatedScale(
      key: const ValueKey('button-camera-scale'),
      scale: can ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: IgnorePointer(
        ignoring: !can,
        child: Semantics(
          button: true,
          label: text,
          excludeSemantics: true,
          child: Pressable(
            child: Sheet(
              padding: EdgeInsets.zero,
              radio: BorderRadius.circular(26),
              elevated: false,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  key: const ValueKey('button-camera'),
                  customBorder: const StadiumBorder(),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    // The framing key changes: the map goes to the chosen one
                    // even if it was moved by hand.
                    ref.read(showBusProvider.notifier).state = !showBus;
                  },
                  child: SizedBox(
                    height: 52,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 22, color: showBus ? c.walk : c.bus),
                          const SizedBox(width: 8),
                          Text(
                            text,
                            style: TextStyle(
                              color: c.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
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
      ),
    );
  }
}

/// Visible name of a search point.
String pointName(SearchPoint? p, {String? empty}) => switch (p) {
  MyLocation() => tx.myLocation,
  ChosenPlace(:final place) => place.name,
  null => empty ?? tx.chooseAPlace,
};

/// Handle of the bottom sheets.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      decoration: BoxDecoration(
        color: BondiColors.of(context).textFaint.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

/// Reports its child's size every time it changes (after the frame).
class Measured extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onChange;
  const Measured({super.key, required this.onChange, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasured(onChange);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderMeasured).onChange = onChange;
}

class _RenderMeasured extends RenderProxyBox {
  ValueChanged<Size> onChange;
  Size? _before;
  _RenderMeasured(this.onChange);

  @override
  void performLayout() {
    super.performLayout();
    if (size == _before) return;
    _before = size;
    final t = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(t));
  }
}

const _lowercase = {
  'a',
  'al',
  'de',
  'del',
  'el',
  'en',
  'la',
  'las',
  'los',
  'por',
  'y',
};

/// Turns "PLAZA INDEPENDENCIA" into "Plaza Independencia". Short acronyms
/// ("UAM", "CUTCSA") stay in uppercase; connectors go in lowercase.
String capitalize(String s) {
  final words = s.split(' ');
  return [
    for (var i = 0; i < words.length; i++)
      () {
        final p = words[i];
        if (p.isEmpty) return p;
        final drop = p.toLowerCase();
        if (i > 0 && _lowercase.contains(drop)) return drop;
        final acronym =
            p == p.toUpperCase() &&
            p.length <= 3 &&
            !_lowercase.contains(drop) &&
            RegExp(r'^[A-ZÁÉÍÓÚÑ]+$').hasMatch(p) &&
            !_abbreviations.contains(drop);
        if (acronym && words.length > 1) return p;
        return drop[0].toUpperCase() + drop.substring(1);
      }(),
  ].join(' ');
}

/// Street abbreviations that are not acronyms ("AV", "BV").
const _abbreviations = {'av', 'bv', 'dr', 'gral', 'pte', 'cno', 'ing', 'sta'};
