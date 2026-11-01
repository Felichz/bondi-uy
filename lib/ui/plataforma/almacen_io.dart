// Almacenamiento local en el teléfono: archivos en el directorio de la app.

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<Directory?>? _base;

Future<Directory?> _directorio() =>
    _base ??= () async {
      try {
        return await getApplicationSupportDirectory();
      } catch (_) {
        return null;
      }
    }();

Future<File?> _archivo(String nombre) async {
  final d = await _directorio();
  return d == null ? null : File('${d.path}/$nombre');
}

/// Texto chico guardado (preferencias), o null.
Future<String?> leerPreferencia(String clave) async {
  try {
    final f = await _archivo('pref-$clave.txt');
    if (f == null || !await f.exists()) return null;
    return (await f.readAsString()).trim();
  } catch (_) {
    return null;
  }
}

Future<void> guardarPreferencia(String clave, String valor) async {
  try {
    await (await _archivo('pref-$clave.txt'))?.writeAsString(valor);
  } catch (_) {}
}

/// Bytes cacheados ([nombre] único dentro de la caché), o null.
Future<Uint8List?> leerCache(String nombre) async {
  try {
    final f = await _archivo('cache/$nombre');
    if (f == null || !await f.exists()) return null;
    return await f.readAsBytes();
  } catch (_) {
    return null;
  }
}

Future<void> guardarCache(String nombre, Uint8List datos) async {
  try {
    final f = await _archivo('cache/$nombre');
    if (f == null) return;
    await f.parent.create(recursive: true);
    await f.writeAsBytes(datos, flush: false);
  } catch (_) {}
}

/// Algunos servidores mandan el cuerpo comprimido sin avisarlo por HTTP.
Uint8List descomprimirSiGzip(Uint8List datos) =>
    datos.length > 2 && datos[0] == 0x1f && datos[1] == 0x8b
        ? Uint8List.fromList(gzip.decode(datos))
        : datos;
