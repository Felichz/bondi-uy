// Local storage on the phone: files in the app's directory.

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<Directory?>? _base;

Future<Directory?> _directory() =>
    _base ??= () async {
      try {
        return await getApplicationSupportDirectory();
      } catch (_) {
        return null;
      }
    }();

Future<File?> _file(String name) async {
  final d = await _directory();
  return d == null ? null : File('${d.path}/$name');
}

/// Small saved text (preferences), or null.
Future<String?> readPreference(String key) async {
  try {
    final f = await _file('pref-$key.txt');
    if (f == null || !await f.exists()) return null;
    return (await f.readAsString()).trim();
  } catch (_) {
    return null;
  }
}

Future<void> savePreference(String key, String value) async {
  try {
    await (await _file('pref-$key.txt'))?.writeAsString(value);
  } catch (_) {}
}

/// Cached bytes ([nombre] unique within the cache), or null.
Future<Uint8List?> readCache(String name) async {
  try {
    final f = await _file('cache/$name');
    if (f == null || !await f.exists()) return null;
    return await f.readAsBytes();
  } catch (_) {
    return null;
  }
}

Future<void> saveCache(String name, Uint8List data) async {
  try {
    final f = await _file('cache/$name');
    if (f == null) return;
    await f.parent.create(recursive: true);
    await f.writeAsBytes(data, flush: false);
  } catch (_) {}
}

/// Some servers send the body compressed without saying so over HTTP.
Uint8List decompressIfGzip(Uint8List data) =>
    data.length > 2 && data[0] == 0x1f && data[1] == 0x8b
        ? Uint8List.fromList(gzip.decode(data))
        : data;
