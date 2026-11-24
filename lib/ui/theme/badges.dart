// Small reusable pieces: bus line badge, live dot.

import 'package:flutter/material.dart';

import 'app_theme.dart';
import '../texts/texts.dart';

/// Bus line badge: same shape as the map badge.
class BadgeLine extends StatelessWidget {
  final String line;
  final bool large;
  const BadgeLine(this.line, {super.key, this.large = false});

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    final size = large ? 20.0 : 15.0;
    return Semantics(
      label: tx.line(line),
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: large ? 10 : 7,
          vertical: large ? 7 : 4,
        ),
        decoration: BoxDecoration(
          color: c.bus,
          borderRadius: BorderRadius.circular(large ? 12 : 8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_bus_rounded,
              size: size + 2,
              color: Colors.white,
            ),
            SizedBox(width: large ? 5 : 3),
            Text(
              line,
              style: TextStyle(
                color: Colors.white,
                fontSize: size,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pulsing dot: indicates real-time data.
class LiveDot extends StatefulWidget {
  final Color? color;
  final double size;
  const LiveDot({super.key, this.color, this.size = 9});

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  // Created in initState: if animations are disabled, build does not touch it
  // and dispose must not create it late (see test "sin animaciones").
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? BondiColors.of(context).live;
    final point = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    if (MediaQuery.disableAnimationsOf(context)) return point;
    return SizedBox(
      width: widget.size * 2.2,
      height: widget.size * 2.2,
      child: AnimatedBuilder(
        animation: _c,
        builder:
            (_, child) => Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: widget.size * (1 + 1.2 * _c.value),
                  height: widget.size * (1 + 1.2 * _c.value),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.35 * (1 - _c.value)),
                    shape: BoxShape.circle,
                  ),
                ),
                child!,
              ],
            ),
        child: point,
      ),
    );
  }
}
