// Pieces of the demo mode: the card to pick a trip with one tap and the
// speed control of the simulated world.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contract/app_state.dart';
import '../../contract/providers.dart';
import '../theme/sheet.dart';
import '../theme/app_theme.dart';
import '../texts/texts.dart';

/// Height of the demo card on the home screen (logical px).
final heightCardDemoProvider = StateProvider<double>((_) => 0);

/// "Probá un viaje": the recorded destinations, one tap away.
class DemoCard extends ConsumerWidget {
  final Demo demo;
  const DemoCard(this.demo, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = BondiColors.of(context);
    final t = Theme.of(context).textTheme;
    return Sheet(
      key: const ValueKey('demo-card'),
      radio: BorderRadius.circular(28),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: c.walk.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'DEMO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: c.walk,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(tx.triesOneTrip, style: t.titleMedium)),
            ],
          ),
          const SizedBox(height: 6),
          Text(tx.demoExplanation, style: t.bodyMedium?.copyWith(fontSize: 14)),
          const SizedBox(height: 12),
          // A row that scrolls: the card does not cover the map.
          SizedBox(
            height: 42,
            child: ListView.separated(
              key: const ValueKey('demo-destinations'),
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: demo.destinations.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final d = demo.destinations[i];
                return _Destination(
                  d,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    final a = ref.read(appActionsProvider);
                    a.choosePlace(SearchField.destination, d);
                    a.searchTrips();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  final Place place;
  final VoidCallback onTap;
  const _Destination(this.place, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    return Pressable(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey('demo-destination-${place.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(10, 9, 14, 9),
            decoration: BoxDecoration(
              color: c.layer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.layerBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.place_rounded, size: 17, color: c.bus),
                const SizedBox(width: 6),
                Text(
                  place.name,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
