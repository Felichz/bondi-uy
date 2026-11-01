// Preferencia de tema (automático / claro / oscuro). Es puramente
// presentacional, así que vive en la UI y se guarda localmente.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../plataforma/almacen.dart';

class PreferenciaTema extends StateNotifier<ThemeMode> {
  final bool persistir;

  PreferenciaTema({this.persistir = true}) : super(ThemeMode.system) {
    if (persistir) _cargar();
  }

  Future<void> _cargar() async {
    final v = await leerPreferencia('tema');
    final modo = ThemeMode.values.where((m) => m.name == v).firstOrNull;
    if (modo != null && mounted) state = modo;
  }

  /// automático -> claro -> oscuro -> automático
  void siguiente() {
    state = switch (state) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    if (persistir) guardarPreferencia('tema', state.name);
  }

  void fijar(ThemeMode m) => state = m;
}

final preferenciaTemaProvider =
    StateNotifierProvider<PreferenciaTema, ThemeMode>((_) => PreferenciaTema());
