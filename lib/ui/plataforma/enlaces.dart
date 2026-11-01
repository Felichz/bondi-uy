// Abrir un enlace externo: en la web, en una pestaña nueva; en el teléfono
// no se usa (no hay enlaces fuera de la app).

export 'enlaces_io.dart' if (dart.library.js_interop) 'enlaces_web.dart';
