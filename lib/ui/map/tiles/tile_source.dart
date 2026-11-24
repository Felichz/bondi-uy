// Where the vector tiles come from.
//
// Data: OpenStreetMap via OpenFreeMap (OpenMapTiles schema, no key).
// Required attribution: "© OpenStreetMap".

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../platform/storage.dart';

/// Maximum zoom with our own data; closer in, it is over-scaled.
const int zoomMaxData = 14;

abstract interface class TileSource {
  /// MVT bytes (not gzipped), or null if it does not exist or fails.
  Future<Uint8List?> bytes(int z, int x, int y);
}

class OpenFreeMapTiles implements TileSource {
  static const _tileJson = 'https://tiles.openfreemap.org/planet';
  final http.Client _http;
  Future<String?>? _template;

  OpenFreeMapTiles({http.Client? client}) : _http = client ?? http.Client();

  Future<String?> _getTemplate() async {
    try {
      final r = await _http
          .get(Uri.parse(_tileJson))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final tiles =
          (jsonDecode(r.body) as Map<String, dynamic>)['tiles'] as List;
      return tiles.first as String;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Uint8List?> bytes(int z, int x, int y) async {
    final name = 'teselas/$z-$x-$y.pbf';
    final saved = await readCache(name);
    if (saved != null) return saved;
    final template = await (_template ??= _getTemplate());
    if (template == null) {
      _template = null; // retry next time
      return null;
    }
    final url = template
        .replaceAll('{z}', '$z')
        .replaceAll('{x}', '$x')
        .replaceAll('{y}', '$y');
    try {
      final r = await _http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      final data = decompressIfGzip(r.bodyBytes);
      await saveCache(name, data);
      return data;
    } catch (_) {
      return null;
    }
  }
}
