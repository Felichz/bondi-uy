// BondiUY theme: elegant white (and graphite in dark), sheets with a subtle
// gradient over the map, system typography with tabular figures.

import 'package:flutter/material.dart';

import '../map/map_style.dart';

/// Semantic colors of the app, in light and dark.
@immutable
class BondiColors extends ThemeExtension<BondiColors> {
  final Brightness brightness;

  /// Sheet fill (panels, cards, sheets): opaque, with a barely perceptible
  /// gradient (lighter at the top). And the solid color for flat backgrounds
  /// (dialogs, full screens).
  final Color sheetAbove;
  final Color sheetBelow;
  final Color sheetSolid;

  /// Sheet edge: catches the light at the top, settles at the bottom.
  final Color borderLight;
  final Color borderShadow;

  /// Long diffuse shadow + contact shadow.
  final Color shadow;
  final Color shadowNear;

  /// Layer on top of the sheet (rows, inner tiles).
  final Color layer;
  final Color layerBorder;

  final Color text;
  final Color textSoft;
  final Color textFaint;
  final Color separator;
  final Color surface; // chips, rows, fields

  /// Primary action (button "Empezar viaje"): ink on white / white on graphite.
  final Color action;
  final Color overAction;

  final Color walk;
  final Color bus;
  final Color live;
  final Color scheduled;
  final Color alert;
  final Color danger;

  final MapStyle map;

  const BondiColors({
    required this.brightness,
    required this.sheetAbove,
    required this.sheetBelow,
    required this.sheetSolid,
    required this.borderLight,
    required this.borderShadow,
    required this.shadow,
    required this.shadowNear,
    required this.layer,
    required this.layerBorder,
    required this.text,
    required this.textSoft,
    required this.textFaint,
    required this.separator,
    required this.surface,
    required this.action,
    required this.overAction,
    required this.walk,
    required this.bus,
    required this.live,
    required this.scheduled,
    required this.alert,
    required this.danger,
    required this.map,
  });

  static const light = BondiColors(
    brightness: Brightness.light,
    sheetAbove: Color(0xFFFFFFFF),
    sheetBelow: Color(0xFFF4F6F9),
    sheetSolid: Color(0xFFFFFFFF),
    borderLight: Color(0xFFFFFFFF),
    borderShadow: Color(0x17101828),
    shadow: Color(0x2E1A2433),
    shadowNear: Color(0x14000000),
    layer: Color(0xFFF1F3F7),
    layerBorder: Color(0x0F101828),
    text: Color(0xFF111318),
    textSoft: Color(0xFF5C616C),
    textFaint: Color(0xFF8A8F99),
    separator: Color(0x14111318),
    surface: Color(0x0D111318),
    action: Color(0xFF111318),
    overAction: Color(0xFFFFFFFF),
    walk: Color(0xFF2563EB),
    bus: Color(0xFFE0412F),
    live: Color(0xFF0B8A5C),
    scheduled: Color(0xFFB86E00),
    alert: Color(0xFFB86E00),
    danger: Color(0xFFC62828),
    map: MapStyle.light,
  );

  static const dark = BondiColors(
    brightness: Brightness.dark,
    sheetAbove: Color(0xFF2B2F38),
    sheetBelow: Color(0xFF1E2128),
    sheetSolid: Color(0xFF1C1F26),
    borderLight: Color(0x33FFFFFF),
    borderShadow: Color(0x0AFFFFFF),
    shadow: Color(0x80000000),
    shadowNear: Color(0x40000000),
    layer: Color(0xFF343944),
    layerBorder: Color(0x12FFFFFF),
    text: Color(0xFFF2F4F7),
    textSoft: Color(0xFFA7AEBA),
    textFaint: Color(0xFF7A818D),
    separator: Color(0x14FFFFFF),
    surface: Color(0x12FFFFFF),
    action: Color(0xFFF2F4F7),
    overAction: Color(0xFF111318),
    walk: Color(0xFF6B9BFF),
    bus: Color(0xFFFF6A55),
    live: Color(0xFF36D08F),
    scheduled: Color(0xFFF2A93B),
    alert: Color(0xFFF2A93B),
    danger: Color(0xFFFF6B6B),
    map: MapStyle.dark,
  );

  static BondiColors of(BuildContext context) =>
      Theme.of(context).extension<BondiColors>() ?? light;

  @override
  BondiColors copyWith() => this;

  @override
  BondiColors lerp(BondiColors? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

const _figures = [FontFeature.tabularFigures()];

ThemeData themeBondi(Brightness brightness) {
  final c =
      brightness == Brightness.dark ? BondiColors.dark : BondiColors.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: c.walk,
    brightness: brightness,
    primary: c.action,
    onPrimary: c.overAction,
    surface: c.sheetSolid,
    onSurface: c.text,
    error: c.danger,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.map.land,
    splashFactory: InkSparkle.splashFactory,
  );
  final t = base.textTheme.apply(bodyColor: c.text, displayColor: c.text);
  final round = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  return base.copyWith(
    extensions: [c],
    textTheme: t.copyWith(
      displaySmall: t.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
        fontFeatures: _figures,
      ),
      headlineMedium: t.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        fontFeatures: _figures,
      ),
      headlineSmall: t.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: t.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: t.bodyLarge?.copyWith(fontSize: 17, height: 1.35),
      bodyMedium: t.bodyMedium?.copyWith(
        fontSize: 15,
        height: 1.35,
        color: c.textSoft,
      ),
      labelLarge: t.labelLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: c.action,
        foregroundColor: c.overAction,
        elevation: 0,
        textStyle: t.labelLarge?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: round,
        side: BorderSide(color: c.separator, width: 1.5),
        foregroundColor: c.text,
        textStyle: t.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: round,
        foregroundColor: c.walk,
        textStyle: t.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: c.text,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor:
          brightness == Brightness.dark
              ? const Color(0xFF2A2E36)
              : const Color(0xFF1B1E24),
      contentTextStyle: t.bodyLarge?.copyWith(
        color: Colors.white,
        fontSize: 16,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.sheetSolid,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    dividerTheme: DividerThemeData(color: c.separator, thickness: 1, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.walk),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      hintStyle: TextStyle(color: c.textFaint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c.walk, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
    ),
  );
}
