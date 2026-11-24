// Local storage, depending on the platform.
//
// - Phone: files in the app's directory (preferences and the map tile
//   cache).
// - Web: `localStorage` for preferences; the browser caches the tiles over
//   HTTP, so the app's own cache does nothing.

export 'storage_io.dart' if (dart.library.js_interop) 'almacen_web.dart';
