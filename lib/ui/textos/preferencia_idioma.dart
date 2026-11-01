// Idioma de la interfaz: el del teléfono o navegador por defecto, el que el
// usuario eligió si lo cambió, y en la web el de `?lang=en|es` si viene en la
// dirección (así el portfolio abre la demo en inglés).

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../plataforma/almacen.dart';
import 'textos.dart';

Idioma? _deTexto(String? v) => switch (v?.toLowerCase()) {
  'es' => Idioma.es,
  'en' => Idioma.en,
  _ => null,
};

Idioma idiomaDelDispositivo() =>
    WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'es'
        ? Idioma.es
        : Idioma.en;

class PreferenciaIdioma extends StateNotifier<Idioma> {
  final bool persistir;

  PreferenciaIdioma({Idioma? inicial, this.persistir = true})
    : super(
        inicial ??
            _deTexto(Uri.base.queryParameters['lang']) ??
            idiomaDelDispositivo(),
      ) {
    // La dirección manda sobre lo guardado: es una elección explícita.
    if (persistir && _deTexto(Uri.base.queryParameters['lang']) == null) {
      _cargar();
    }
  }

  Future<void> _cargar() async {
    final guardado = _deTexto(await leerPreferencia('idioma'));
    if (guardado != null && mounted) state = guardado;
  }

  void alternar() {
    state = state == Idioma.es ? Idioma.en : Idioma.es;
    if (persistir) guardarPreferencia('idioma', state.name);
  }

  void fijar(Idioma i) => state = i;
}

final idiomaProvider = StateNotifierProvider<PreferenciaIdioma, Idioma>(
  (_) => PreferenciaIdioma(),
);
