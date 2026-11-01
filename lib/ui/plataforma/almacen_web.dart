// Almacenamiento local en el navegador.

import 'dart:typed_data';

import 'package:web/web.dart' as web;

const _prefijo = 'bondiuy.';

/// Texto chico guardado (preferencias), o null.
Future<String?> leerPreferencia(String clave) async {
  try {
    return web.window.localStorage.getItem('$_prefijo$clave');
  } catch (_) {
    return null; // almacenamiento bloqueado (modo privado, iframe)
  }
}

Future<void> guardarPreferencia(String clave, String valor) async {
  try {
    web.window.localStorage.setItem('$_prefijo$clave', valor);
  } catch (_) {}
}

/// El navegador ya cachea las teselas por HTTP.
Future<Uint8List?> leerCache(String nombre) async => null;

Future<void> guardarCache(String nombre, Uint8List datos) async {}

/// El navegador descomprime solo (Content-Encoding).
Uint8List descomprimirSiGzip(Uint8List datos) => datos;
