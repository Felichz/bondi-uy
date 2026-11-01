import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Converts GTFS `shapes.txt` into the compact GeoJSON asset consumed by the
/// app's realtime bus renderer.
///
/// Usage:
///   dart run tool/generate_shapes_geojson.dart \
///     --input path/to/shapes.txt \
///     --output assets/data/shapes.geojson
Future<void> main(List<String> args) async {
  final inputPath = _argument(args, '--input');
  final outputPath =
      _argument(args, '--output', required: false) ??
      'assets/data/shapes.geojson';

  if (inputPath == null) {
    stderr.writeln('Missing required --input path to GTFS shapes.txt.');
    exitCode = 64;
    return;
  }

  final input = File(inputPath);
  if (!input.existsSync()) {
    stderr.writeln('GTFS shapes file does not exist: $inputPath');
    exitCode = 66;
    return;
  }

  final lines = input
      .openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter());
  final iterator = StreamIterator(lines);
  if (!await iterator.moveNext()) {
    stderr.writeln('GTFS shapes file is empty: $inputPath');
    exitCode = 65;
    return;
  }

  final headers = _parseCsvLine(iterator.current);
  final shapeIdIndex = headers.indexOf('shape_id');
  final latitudeIndex = headers.indexOf('shape_pt_lat');
  final longitudeIndex = headers.indexOf('shape_pt_lon');
  final sequenceIndex = headers.indexOf('shape_pt_sequence');
  if ([
    shapeIdIndex,
    latitudeIndex,
    longitudeIndex,
    sequenceIndex,
  ].contains(-1)) {
    stderr.writeln('shapes.txt is missing one or more required GTFS columns.');
    exitCode = 65;
    return;
  }

  final pointsByShape = <String, List<_ShapePoint>>{};
  var rowNumber = 1;
  while (await iterator.moveNext()) {
    rowNumber++;
    final row = _parseCsvLine(iterator.current);
    if (row.length != headers.length) {
      throw FormatException(
        'Malformed CSV row $rowNumber: expected ${headers.length} columns, '
        'found ${row.length}.',
      );
    }
    final shapeId = row[shapeIdIndex];
    if (shapeId.isEmpty) continue;
    pointsByShape
        .putIfAbsent(shapeId, () => [])
        .add(
          _ShapePoint(
            sequence: int.parse(row[sequenceIndex]),
            latitude: double.parse(row[latitudeIndex]),
            longitude: double.parse(row[longitudeIndex]),
          ),
        );
  }

  final shapeIds = pointsByShape.keys.toList()..sort();
  final features = <Map<String, Object?>>[];
  for (final shapeId in shapeIds) {
    final points =
        pointsByShape[shapeId]!
          ..sort((a, b) => a.sequence.compareTo(b.sequence));
    if (points.length < 2) continue;
    features.add({
      'type': 'Feature',
      'properties': {'shape_id': shapeId},
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          for (final point in points) [point.longitude, point.latitude],
        ],
      },
    });
  }

  final output = File(outputPath);
  output.parent.createSync(recursive: true);
  await output.writeAsString(
    jsonEncode({'type': 'FeatureCollection', 'features': features}),
    flush: true,
  );
  stdout.writeln(
    'Generated ${features.length} GTFS shapes in ${output.path} '
    '(${output.lengthSync()} bytes).',
  );
}

String? _argument(List<String> args, String name, {bool required = true}) {
  final index = args.indexOf(name);
  if (index == -1) return null;
  if (index + 1 >= args.length || args[index + 1].startsWith('--')) {
    if (required) {
      throw FormatException('$name requires a value.');
    }
    return null;
  }
  return args[index + 1];
}

List<String> _parseCsvLine(String line) {
  final values = <String>[];
  final current = StringBuffer();
  var quoted = false;
  for (var index = 0; index < line.length; index++) {
    final character = line[index];
    if (character == '"') {
      if (quoted && index + 1 < line.length && line[index + 1] == '"') {
        current.write('"');
        index++;
      } else {
        quoted = !quoted;
      }
    } else if (character == ',' && !quoted) {
      values.add(current.toString());
      current.clear();
    } else {
      current.write(character);
    }
  }
  if (quoted) throw const FormatException('Unclosed quote in CSV row.');
  values.add(current.toString());
  return values;
}

class _ShapePoint {
  final int sequence;
  final double latitude;
  final double longitude;

  const _ShapePoint({
    required this.sequence,
    required this.latitude,
    required this.longitude,
  });
}
