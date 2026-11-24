// Theme preference (automatic / light / dark). It is purely presentational,
// so it lives in the UI and is stored locally.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/storage.dart';

class ThemePreference extends StateNotifier<ThemeMode> {
  final bool persist;

  ThemePreference({this.persist = true}) : super(ThemeMode.system) {
    if (persist) _load();
  }

  Future<void> _load() async {
    final v = await readPreference('tema');
    final mode = ThemeMode.values.where((m) => m.name == v).firstOrNull;
    if (mode != null && mounted) state = mode;
  }

  /// automatic -> light -> dark -> automatic
  void next() {
    state = switch (state) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    if (persist) savePreference('tema', state.name);
  }

  /// A mode chosen by the user (remembered).
  void choose(ThemeMode m) {
    state = m;
    if (persist) savePreference('tema', m.name);
  }

  void pin(ThemeMode m) => state = m;
}

final preferenceThemeProvider =
    StateNotifierProvider<ThemePreference, ThemeMode>((_) => ThemePreference());
