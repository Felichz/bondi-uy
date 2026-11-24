// UI language: English by default, the one the user chose if they changed
// it, and on the web the one from `?lang=en|es` if it is in the address.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/storage.dart';
import 'texts.dart';

Language? _ofText(String? v) => switch (v?.toLowerCase()) {
  'es' => Language.es,
  'en' => Language.en,
  _ => null,
};

class LanguagePreference extends StateNotifier<Language> {
  final bool persist;

  LanguagePreference({Language? initial, this.persist = true})
    : super(
        initial ?? _ofText(Uri.base.queryParameters['lang']) ?? Language.en,
      ) {
    // The address takes precedence over what is saved: it is an explicit choice.
    if (persist && _ofText(Uri.base.queryParameters['lang']) == null) {
      _load();
    }
  }

  Future<void> _load() async {
    final saved = _ofText(await readPreference('idioma'));
    if (saved != null && mounted) state = saved;
  }

  void alternate() {
    state = state == Language.es ? Language.en : Language.es;
    if (persist) guardarPreference('idioma', state.name);
  }

  void pin(Language i) => state = i;
}

final languageProvider = StateNotifierProvider<LanguagePreference, Language>(
  (_) => LanguagePreference(),
);
