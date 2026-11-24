// Local storage in the browser.

import 'dart:typed_data';

import 'package:web/web.dart' as web;

const _prefix = 'bondiuy.';

/// Small saved text (preferences), or null.
Future<String?> readPreference(String clave) async {
  try {
    return web.window.localStorage.getItem('$_prefix$clave');
  } catch (_) {
    return null; // storage blocked (private mode, iframe)
  }
}

Future<void> guardarPreference(String clave, String value) async {
  try {
    web.window.localStorage.setItem('$_prefix$clave', value);
  } catch (_) {}
}

/// The browser already caches the map tiles over HTTP.
Future<Uint8List?> readCache(String name) async => null;

Future<void> guardarCache(String name, Uint8List data) async {}

/// The browser decompresses on its own (Content-Encoding).
Uint8List decompressSiGzip(Uint8List data) => data;
