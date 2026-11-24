// Surface material: opaque sheets with a subtle gradient.
//
// No transparency: the text reads with the contrast of a sheet of paper over
// any part of the map. The depth comes from a barely noticeable gradient
// (brighter at the top), an edge that catches the light at the top and settles
// at the bottom, and a long, clean shadow that leaves no gray band.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';

/// Flat sheets, with no gradient or edge (high contrast, pixel tests).
final sheetSolidProvider = Provider<bool>((_) => false);

class Sheet extends ConsumerWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius radio;

  /// Stronger shadow for main floating panels.
  final bool elevated;

  /// No shadow (full screens).
  final bool withShadow;

  const Sheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radio = const BorderRadius.all(Radius.circular(24)),
    this.elevated = true,
    this.withShadow = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = BondiColors.of(context);
    final flat =
        ref.watch(sheetSolidProvider) || MediaQuery.highContrastOf(context);
    final content = ClipRRect(
      borderRadius: radio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: flat ? c.sheetSolid : null,
          gradient:
              flat
                  ? null
                  : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c.sheetAbove, c.sheetBelow],
                  ),
        ),
        child: CustomPaint(
          foregroundPainter:
              flat
                  ? null
                  : _Edge(
                    radio: radio,
                    light: c.borderLight,
                    shadow: c.borderShadow,
                  ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    if (!withShadow) return content;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radio,
        boxShadow: [
          // Long and diffuse, drawn inward: it floats without smudging.
          BoxShadow(
            color: c.shadow,
            blurRadius: elevated ? 48 : 24,
            offset: Offset(0, elevated ? 20 : 8),
            spreadRadius: elevated ? -18 : -10,
          ),
          // Contact shadow: defines the edge against the map.
          BoxShadow(
            color: c.shadowNear,
            blurRadius: elevated ? 8 : 4,
            offset: const Offset(0, 2),
            spreadRadius: -2,
          ),
        ],
      ),
      child: content,
    );
  }
}

class _Edge extends CustomPainter {
  final BorderRadius radio;
  final Color light;
  final Color shadow;
  const _Edge({required this.radio, required this.light, required this.shadow});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      radio.toRRect(rect).deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [light, shadow],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_Edge o) =>
      o.radio != radio || o.light != light || o.shadow != shadow;
}

/// Layer on top of the sheet (rows, inner cards).
class Layer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius radio;
  final Color? color;
  const Layer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radio = const BorderRadius.all(Radius.circular(16)),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.layer,
        borderRadius: radio,
        border: Border.all(color: c.layerBorder, width: 1),
      ),
      child: child,
    );
  }
}

/// Sinks slightly when touched (physical response, before anything happens).
class Pressable extends StatefulWidget {
  final Widget child;
  const Pressable({super.key, required this.child});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _setDown(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _setDown(true),
    onPointerUp: (_) => _setDown(false),
    onPointerCancel: (_) => _setDown(false),
    child: AnimatedScale(
      scale: _down ? 0.94 : 1,
      duration: Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 140,
      ),
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}

/// Round button (recenter, theme, close, itinerary).
class SheetButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const SheetButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    return Pressable(
      child: Sheet(
        padding: EdgeInsets.zero,
        radio: BorderRadius.circular(28),
        elevated: false,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 52,
              height: 52,
              child: Icon(icon, color: color ?? c.text, semanticLabel: label),
            ),
          ),
        ),
      ),
    );
  }
}
