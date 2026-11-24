// Local storage in the browser.

import 'dart:typed_data';

import 'package:web/web.dart' as web;

const _prefix = 'bondiuy.';

/// Small saved text (preferences), or null.
Future<String?> readPreference(String key) async {
  try {
    return web.window.localStorage.getItem('$_prefix$key');
  } catch (_) {
    return null; // storage blocked (private mode, iframe)
  }
}

Future<void> savePreference(String key, String value) async {
  try {
    web.window.localStorage.setItem('$_prefix$key', value);
  } catch (_) {}
}

/// The browser already caches the map tiles over HTTP.
Future<Uint8List?> readCache(String name) async => null;

Future<void> saveCache(String name, Uint8List data) async {}

/// The browser decompresses on its own (Content-Encoding).
Uint8List decompressIfGzip(Uint8List data) => data;
