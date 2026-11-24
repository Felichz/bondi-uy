// Open an external link: on the web, in a new tab; on the phone it is not
// used (there are no links outside the app).

export 'links_io.dart' if (dart.library.js_interop) 'links_web.dart';
