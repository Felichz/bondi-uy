// Idioma de la interfaz: inglés por defecto, el que el usuario eligió si lo
// cambió, y en la web el de `?lang=en|es` si viene en la dirección.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../plataforma/almacen.dart';
import 'textos.dart';

Idioma? _deTexto(String? v) => switch (v?.toLowerCase()) {
  'es' => Idioma.es,
  'en' => Idioma.en,
  _ => null,
};

class PreferenciaIdioma extends StateNotifier<Idioma> {
  final bool persistir;

  PreferenciaIdioma({Idioma? inicial, this.persistir = true})
    : super(
        inicial ?? _deTexto(Uri.base.queryParameters['lang']) ?? Idioma.en,
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
