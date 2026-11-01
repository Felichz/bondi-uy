// Almacenamiento local según la plataforma.
//
// - Teléfono: archivos en el directorio de la app (preferencias y caché de
//   teselas del mapa).
// - Web: `localStorage` para preferencias; las teselas las cachea el
//   navegador con HTTP, así que la caché propia no hace nada.

export 'almacen_io.dart' if (dart.library.js_interop) 'almacen_web.dart';
