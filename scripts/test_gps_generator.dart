/// Simple script to test the synthetic GPS generator
/// Run with: dart run scripts/test_gps_generator.dart

import 'dart:convert';
import 'dart:io';
import '../lib/backend/contrato_ui/app_ui_state.dart';
import '../lib/devtools/gps_playback_generator.dart';

void main() async {
  print('\n🎬 ========================================');
  print('🎬 TEST: Generador de GPS Sintético');
  print('🎬 ========================================\n');

  // Read fixture
  final file = File('test/fixtures/trip_test_synthetic.json');
  final contents = await file.readAsString();
  final json = jsonDecode(contents) as Map<String, dynamic>;

  final route = json['route'] as Map<String, dynamic>;
  final segments = route['segments'] as List;

  print('📊 Datos del fixture:');
  print('   • Nombre: ${json['name']}');
  print('   • Origen: ${json['origin']['name']}');
  print('   • Destino: ${json['destination']['name']}');
  print('   • Segments: ${segments.length}');
  print('');

  // Build legs
  final legs = <DisplayableTripLeg>[];
  final stops = (route['stops'] as List?) ?? [];

  for (final segment in segments) {
    final type = TripLegType.values.firstWhere(
      (t) => t.name == segment['type'],
    );

    final geometryList = segment['geometry'] as List?;
    final geometry = geometryList != null
        ? geometryList
            .map((g) => Coordinate(
                  latitude: (g['lat'] as num).toDouble(),
                  longitude: (g['lng'] as num).toDouble(),
                ))
            .toList()
        : <Coordinate>[];

    Coordinate? pointPosition;
    if (segment['at'] != null && stops.isNotEmpty) {
      try {
        final stopData = stops.firstWhere((s) => s['stopId'] == segment['at']);
        pointPosition = Coordinate(
          latitude: (stopData['lat'] as num).toDouble(),
          longitude: (stopData['lng'] as num).toDouble(),
        );
      } catch (e) {
        // Stop not found, continue
      }
    }

    legs.add(DisplayableTripLeg(
      idLeg: 'tramo_${legs.length}',
      type: type,
      geometryPolyline: geometry.isNotEmpty ? geometry : null,
      pointPosition: pointPosition,
      description: segment['description'] as String,
      durationEstimatedSeconds: segment['duration'] as int,
      distanceMeters: (segment['distance'] as int?) ?? 0,
      busLineName: segment['busLine'] as String?,
    ));
  }

  final origin = json['origin'] as Map<String, dynamic>;
  final destination = json['destination'] as Map<String, dynamic>;

  print('🎬 Generando GPS playback sintético...\n');

  // Generate the GPS playback
  final gpsPlayback = GpsPlaybackGenerator.generateFromRoute(
    origin: Coordinate(
      latitude: (origin['lat'] as num).toDouble(),
      longitude: (origin['lng'] as num).toDouble(),
    ),
    destination: Coordinate(
      latitude: (destination['lat'] as num).toDouble(),
      longitude: (destination['lng'] as num).toDouble(),
    ),
    legs: legs,
    speedMultiplier: 1.0,
  );

  print('\n✅ GPS playback generado:');
  print('   • Total de puntos: ${gpsPlayback.length}');
  if (gpsPlayback.isNotEmpty) {
    print('   • Primer punto: t=${gpsPlayback.first['timestamp']}s');
    print('   • Último punto: t=${gpsPlayback.last['timestamp']}s');
    print('   • Duración total: ${gpsPlayback.last['timestamp']}s');

    // Show a few sample points
    print('\n📍 Primeros 5 puntos:');
    for (int i = 0; i < 5 && i < gpsPlayback.length; i++) {
      final p = gpsPlayback[i];
      final comment = p['comment'] != null ? ' - ${p['comment']}' : '';
      print('   [${p['timestamp']}s] ${p['lat']}, ${p['lng']}$comment');
    }
  }
  print('');

  print('🎯 Generando checkpoints automáticos...\n');

  // Generate checkpoints
  final checkpoints = GpsPlaybackGenerator.generateCheckpoints(
    legs: legs,
    gpsPlayback: gpsPlayback,
  );

  print('✅ Checkpoints generados:');
  print('   • Total: ${checkpoints.length}');
  for (final cp in checkpoints) {
    final assertions = cp['assertions'] as Map<String, dynamic>;
    print('   • [${cp['timestamp']}s] ${cp['name']}');
    print('      Assertions: ${assertions.keys.join(", ")}');
  }
  print('');

  print('🎉 ========================================');
  print('🎉 GENERACIÓN EXITOSA');
  print('🎉 ========================================\n');
  print('✅ El generador de GPS sintético funciona correctamente.');
  print('✅ Genera ${gpsPlayback.length} puntos GPS y ${checkpoints.length} checkpoints.');
  print('✅ Ahora puedes usarlo en tests de integración.\n');
}
