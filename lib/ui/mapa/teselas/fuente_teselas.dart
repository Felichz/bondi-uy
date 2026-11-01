// De dónde salen las teselas vectoriales.
//
// Datos: OpenStreetMap vía OpenFreeMap (esquema OpenMapTiles, sin clave).
// Atribución obligatoria: "© OpenStreetMap".

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../plataforma/almacen.dart';

/// Zoom máximo con datos propios; más cerca se sobre-amplía.
const int zoomMaximoDatos = 14;

abstract interface class FuenteTeselas {
  /// Bytes MVT (sin gzip) o null si no existe / falla.
  Future<Uint8List?> bytes(int z, int x, int y);
}

class TeselasOpenFreeMap implements FuenteTeselas {
  static const _tileJson = 'https://tiles.openfreemap.org/planet';
  final http.Client _http;
  Future<String?>? _plantilla;

  TeselasOpenFreeMap({http.Client? cliente}) : _http = cliente ?? http.Client();

  Future<String?> _obtenerPlantilla() async {
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
    final nombre = 'teselas/$z-$x-$y.pbf';
    final guardada = await leerCache(nombre);
    if (guardada != null) return guardada;
    final plantilla = await (_plantilla ??= _obtenerPlantilla());
    if (plantilla == null) {
      _plantilla = null; // reintentar la próxima vez
      return null;
    }
    final url = plantilla
        .replaceAll('{z}', '$z')
        .replaceAll('{x}', '$x')
        .replaceAll('{y}', '$y');
    try {
      final r = await _http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      final datos = descomprimirSiGzip(r.bodyBytes);
      await guardarCache(nombre, datos);
      return datos;
    } catch (_) {
      return null;
    }
  }
}
