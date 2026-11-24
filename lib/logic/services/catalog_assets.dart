// Stop network and GTFS shapes packaged as GeoJSON assets.
//
// assets/data/stops.geojson  -> {stop_id, stop_name, lines[]}
// assets/data/shapes.geojson -> {shape_id} LineString
// (generated from the GTFS with tool/generate_*.)

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../contract/model.dart';
import '../ports.dart';

class CatalogAssets implements NetworkCatalog {
  final AssetBundle _bundle;
  Future<List<NetworkStop>>? _stops;
  Future<Map<String, List<Coordinate>>>? _shapes;

  CatalogAssets({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  @override
  Future<List<NetworkStop>> stops() => _stops ??= _loadStops();

  @override
  Future<List<Coordinate>?> shape(String shapeId) async =>
      (await (_shapes ??= _loadShapes()))[shapeId.split(':').last];

  Future<List<NetworkStop>> _loadStops() async {
    final json =
        jsonDecode(await _bundle.loadString('assets/data/stops.geojson'))
            as Map<String, dynamic>;
    return [
      for (final f in (json['features'] as List?) ?? const [])
        if (_stop(f as Map<String, dynamic>) case final p?) p,
    ];
  }

  NetworkStop? _stop(Map<String, dynamic> f) {
    final p = f['properties'] as Map<String, dynamic>?;
    final c = (f['geometry'] as Map<String, dynamic>?)?['coordinates'] as List?;
    if (p == null || c == null || c.length != 2) return null;
    return NetworkStop(
      stop: Stop(
        id: p['stop_id'].toString(),
        name: p['stop_name']?.toString() ?? '',
        coordinate: Coordinate(
          (c[1] as num).toDouble(),
          (c[0] as num).toDouble(),
        ),
      ),
      lines: [for (final l in (p['lines'] as List?) ?? const []) l.toString()],
    );
  }

  Future<Map<String, List<Coordinate>>> _loadShapes() async {
    final json =
        jsonDecode(await _bundle.loadString('assets/data/shapes.geojson'))
            as Map<String, dynamic>;
    final res = <String, List<Coordinate>>{};
    for (final f in (json['features'] as List?) ?? const []) {
      final id = (f['properties'] as Map?)?['shape_id']?.toString();
      final g = f['geometry'] as Map?;
      if (id == null || g?['type'] != 'LineString') continue;
      res[id] = [
        for (final c in g!['coordinates'] as List)
          Coordinate((c[1] as num).toDouble(), (c[0] as num).toDouble()),
      ];
    }
    return res;
  }
}
