// Red de paradas y shapes GTFS empaquetados como assets GeoJSON.
//
// assets/data/stops.geojson  -> {stop_id, stop_name, lines[]}
// assets/data/shapes.geojson -> {shape_id} LineString
// (generados desde el GTFS con tool/generate_*.)

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../contract/modelo.dart';
import '../puertos.dart';

class CatalogoAssets implements CatalogoRed {
  final AssetBundle _bundle;
  Future<List<ParadaDeRed>>? _paradas;
  Future<Map<String, List<Coordenada>>>? _shapes;

  CatalogoAssets({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  @override
  Future<List<ParadaDeRed>> paradas() => _paradas ??= _cargarParadas();

  @override
  Future<List<Coordenada>?> shape(String shapeId) async =>
      (await (_shapes ??= _cargarShapes()))[shapeId.split(':').last];

  Future<List<ParadaDeRed>> _cargarParadas() async {
    final json =
        jsonDecode(await _bundle.loadString('assets/data/stops.geojson'))
            as Map<String, dynamic>;
    return [
      for (final f in (json['features'] as List?) ?? const [])
        if (_parada(f as Map<String, dynamic>) case final p?) p,
    ];
  }

  ParadaDeRed? _parada(Map<String, dynamic> f) {
    final p = f['properties'] as Map<String, dynamic>?;
    final c = (f['geometry'] as Map<String, dynamic>?)?['coordinates'] as List?;
    if (p == null || c == null || c.length != 2) return null;
    return ParadaDeRed(
      parada: Parada(
        id: p['stop_id'].toString(),
        nombre: p['stop_name']?.toString() ?? '',
        coordenada: Coordenada(
          (c[1] as num).toDouble(),
          (c[0] as num).toDouble(),
        ),
      ),
      lineas: [for (final l in (p['lines'] as List?) ?? const []) l.toString()],
    );
  }

  Future<Map<String, List<Coordenada>>> _cargarShapes() async {
    final json =
        jsonDecode(await _bundle.loadString('assets/data/shapes.geojson'))
            as Map<String, dynamic>;
    final res = <String, List<Coordenada>>{};
    for (final f in (json['features'] as List?) ?? const []) {
      final id = (f['properties'] as Map?)?['shape_id']?.toString();
      final g = f['geometry'] as Map?;
      if (id == null || g?['type'] != 'LineString') continue;
      res[id] = [
        for (final c in g!['coordinates'] as List)
          Coordenada((c[1] as num).toDouble(), (c[0] as num).toDouble()),
      ];
    }
    return res;
  }
}
