// Tema de BondiUY: blanco elegante (y grafito en oscuro), láminas con degradé
// sutil sobre el mapa, tipografía del sistema con cifras tabulares.

import 'package:flutter/material.dart';

import '../mapa/estilo_mapa.dart';

/// Colores semánticos de la app, en claro y oscuro.
@immutable
class ColoresBondi extends ThemeExtension<ColoresBondi> {
  final Brightness brillo;

  /// Relleno de las láminas (paneles, tarjetas, hojas): opaco, con un
  /// degradé apenas perceptible (más luminoso arriba). Y el color sólido
  /// para fondos planos (diálogos, pantallas completas).
  final Color laminaArriba;
  final Color laminaAbajo;
  final Color laminaSolida;

  /// Filo de la lámina: brilla arriba, se asienta abajo.
  final Color bordeLuz;
  final Color bordeSombra;

  /// Sombra larga y difusa + sombra de contacto.
  final Color sombra;
  final Color sombraCerca;

  /// Capa sobre la lámina (filas, fichas internas).
  final Color capa;
  final Color capaBorde;

  final Color texto;
  final Color textoSuave;
  final Color textoTenue;
  final Color separador;
  final Color superficie; // chips, filas, campos

  /// Acción principal (botón "Empezar viaje"): tinta sobre blanco / blanco sobre grafito.
  final Color accion;
  final Color sobreAccion;

  final Color caminar;
  final Color bus;
  final Color enVivo;
  final Color programado;
  final Color alerta;
  final Color peligro;

  final EstiloMapa mapa;

  const ColoresBondi({
    required this.brillo,
    required this.laminaArriba,
    required this.laminaAbajo,
    required this.laminaSolida,
    required this.bordeLuz,
    required this.bordeSombra,
    required this.sombra,
    required this.sombraCerca,
    required this.capa,
    required this.capaBorde,
    required this.texto,
    required this.textoSuave,
    required this.textoTenue,
    required this.separador,
    required this.superficie,
    required this.accion,
    required this.sobreAccion,
    required this.caminar,
    required this.bus,
    required this.enVivo,
    required this.programado,
    required this.alerta,
    required this.peligro,
    required this.mapa,
  });

  static const claro = ColoresBondi(
    brillo: Brightness.light,
    laminaArriba: Color(0xFFFFFFFF),
    laminaAbajo: Color(0xFFF4F6F9),
    laminaSolida: Color(0xFFFFFFFF),
    bordeLuz: Color(0xFFFFFFFF),
    bordeSombra: Color(0x17101828),
    sombra: Color(0x2E1A2433),
    sombraCerca: Color(0x14000000),
    capa: Color(0xFFF1F3F7),
    capaBorde: Color(0x0F101828),
    texto: Color(0xFF111318),
    textoSuave: Color(0xFF5C616C),
    textoTenue: Color(0xFF8A8F99),
    separador: Color(0x14111318),
    superficie: Color(0x0D111318),
    accion: Color(0xFF111318),
    sobreAccion: Color(0xFFFFFFFF),
    caminar: Color(0xFF2563EB),
    bus: Color(0xFFE0412F),
    enVivo: Color(0xFF0B8A5C),
    programado: Color(0xFFB86E00),
    alerta: Color(0xFFB86E00),
    peligro: Color(0xFFC62828),
    mapa: EstiloMapa.claro,
  );

  static const oscuro = ColoresBondi(
    brillo: Brightness.dark,
    laminaArriba: Color(0xFF2B2F38),
    laminaAbajo: Color(0xFF1E2128),
    laminaSolida: Color(0xFF1C1F26),
    bordeLuz: Color(0x33FFFFFF),
    bordeSombra: Color(0x0AFFFFFF),
    sombra: Color(0x80000000),
    sombraCerca: Color(0x40000000),
    capa: Color(0xFF343944),
    capaBorde: Color(0x12FFFFFF),
    texto: Color(0xFFF2F4F7),
    textoSuave: Color(0xFFA7AEBA),
    textoTenue: Color(0xFF7A818D),
    separador: Color(0x14FFFFFF),
    superficie: Color(0x12FFFFFF),
    accion: Color(0xFFF2F4F7),
    sobreAccion: Color(0xFF111318),
    caminar: Color(0xFF6B9BFF),
    bus: Color(0xFFFF6A55),
    enVivo: Color(0xFF36D08F),
    programado: Color(0xFFF2A93B),
    alerta: Color(0xFFF2A93B),
    peligro: Color(0xFFFF6B6B),
    mapa: EstiloMapa.oscuro,
  );

  static ColoresBondi of(BuildContext context) =>
      Theme.of(context).extension<ColoresBondi>() ?? claro;

  @override
  ColoresBondi copyWith() => this;

  @override
  ColoresBondi lerp(ColoresBondi? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

const _cifras = [FontFeature.tabularFigures()];

ThemeData temaBondi(Brightness brillo) {
  final c =
      brillo == Brightness.dark ? ColoresBondi.oscuro : ColoresBondi.claro;
  final esquema = ColorScheme.fromSeed(
    seedColor: c.caminar,
    brightness: brillo,
    primary: c.accion,
    onPrimary: c.sobreAccion,
    surface: c.laminaSolida,
    onSurface: c.texto,
    error: c.peligro,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brillo,
    colorScheme: esquema,
    scaffoldBackgroundColor: c.mapa.tierra,
    splashFactory: InkSparkle.splashFactory,
  );
  final t = base.textTheme.apply(bodyColor: c.texto, displayColor: c.texto);
  final redondo = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );
  return base.copyWith(
    extensions: [c],
    textTheme: t.copyWith(
      displaySmall: t.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
        fontFeatures: _cifras,
      ),
      headlineMedium: t.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        fontFeatures: _cifras,
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
        color: c.textoSuave,
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
        backgroundColor: c.accion,
        foregroundColor: c.sobreAccion,
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
        shape: redondo,
        side: BorderSide(color: c.separador, width: 1.5),
        foregroundColor: c.texto,
        textStyle: t.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: redondo,
        foregroundColor: c.caminar,
        textStyle: t.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: c.texto,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor:
          brillo == Brightness.dark
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
      backgroundColor: c.laminaSolida,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    dividerTheme: DividerThemeData(color: c.separador, thickness: 1, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.caminar),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.superficie,
      hintStyle: TextStyle(color: c.textoTenue),
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
        borderSide: BorderSide(color: c.caminar, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
    ),
  );
}
