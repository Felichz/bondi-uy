import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Simple feature-based logger writing each tag to its own file under logs/.
/// Usage:
///   await FeatureLogger().init(); // in main
///   FeatureLogger().log('camera', 'anim start', data: {'legs': 3});
class FeatureLogger {
  static final FeatureLogger _instance = FeatureLogger._internal();
  factory FeatureLogger() => _instance;
  FeatureLogger._internal();

  Directory? _baseDir;
  final Map<String, IOSink> _sinks = {};
  bool _initialized = false;

  // Tags allowed to also echo to console to reduce noise.
  // Empty set => none; null => all.
  Set<String>? consoleEchoTags = {'camera', 'logger'}; // configurable
  String? _logDirPath; // exposed for debug

  Future<void> init({bool clean = true}) async {
    if (_initialized) return;
    final dir = await getApplicationSupportDirectory();
    _baseDir = Directory('${dir.path}/logs');
    _logDirPath = _baseDir!.path;
    if (clean && await _baseDir!.exists()) {
      await _baseDir!.delete(recursive: true).catchError((_) => _baseDir!);
    }
    await _baseDir!.create(recursive: true);
    _initialized = true;
    log('logger', 'init ok', data: {'clean': clean, 'dir': _logDirPath});
    // Extra explicit path print (always) so dev sees it even if tag filtering changes
    // ignore: avoid_print
    print('LOG_DIR=$_logDirPath');
  }

  void log(String tag, String msg, {Map<String, Object?>? data}) {
    if (!_initialized) return; // avoid exceptions before init
    final ts = _ts();
    final line = _formatLine(ts, tag, msg, data);
    _write(tag, line);
    if (consoleEchoTags == null || consoleEchoTags!.contains(tag)) {
      // Compact console echo
      // ignore: avoid_print
      print(line);
    }
  }

  void camera(String msg, {Map<String, Object?>? data}) =>
      log('camera', msg, data: data);

  String? get logDirectoryPath => _logDirPath;

  Future<void> dispose() async {
    for (final s in _sinks.values) {
      await s.flush();
      await s.close();
    }
    _sinks.clear();
    _initialized = false;
  }

  String _formatLine(
    String ts,
    String tag,
    String msg,
    Map<String, Object?>? data,
  ) {
    final b = StringBuffer();
    b.write(ts);
    b.write('|');
    b.write(tag);
    b.write('|');
    b.write(msg);
    if (data != null && data.isNotEmpty) {
      b.write('|');
      data.forEach((k, v) {
        b.write(k);
        b.write('=');
        b.write(_short(v));
        b.write(' ');
      });
    }
    return b.toString().trim();
  }

  void _write(String tag, String line) {
    final sink = _sinks[tag];
    if (sink != null) {
      sink.writeln(line);
      return;
    }
    final file = File('${_baseDir!.path}/$tag.txt');
    final newSink = file.openWrite(mode: FileMode.writeOnlyAppend);
    _sinks[tag] = newSink;
    newSink.writeln(line);
  }

  String _ts() {
    final now = DateTime.now();
    return '${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)}.${now.millisecond.toString().padLeft(3, '0')}';
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _short(Object? v) {
    if (v == null) return 'null';
    final s = v.toString();
    if (s.length > 60) return s.substring(0, 57) + '…';
    return s.replaceAll('\n', ' ');
  }
}
