import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Trip Real Data Test - Validar JSON capturado', () {
    test('Cargar y validar trip_example_simple.json', () async {
      // 1. CARGAR JSON REAL
      final file = File('test/fixtures/trip_example_simple.json');
      expect(file.existsSync(), true, reason: 'El archivo trip_example_simple.json debe existir');

      final jsonString = await file.readAsString();
      final tripData = json.decode(jsonString) as Map<String, dynamic>;

      print('\n📦 JSON cargado: ${tripData['name']}');
      print('   Trip ID: ${tripData['tripId']}');
      print('   Capturado: ${tripData['capturedAt']}');

      // 2. VALIDAR ESTRUCTURA BÁSICA
      expect(tripData['tripId'], isNotNull);
      expect(tripData['name'], isNotNull);
      expect(tripData['capturedAt'], isNotNull);
      expect(tripData['origin'], isNotNull);
      expect(tripData['destination'], isNotNull);
      expect(tripData['route'], isNotNull);

      // 3. VALIDAR ORIGEN Y DESTINO
      final origin = tripData['origin'] as Map<String, dynamic>;
      final destination = tripData['destination'] as Map<String, dynamic>;

      expect(origin['lat'], isNotNull);
      expect(origin['lng'], isNotNull);
      expect(origin['name'], isNotNull);

      expect(destination['lat'], isNotNull);
      expect(destination['lng'], isNotNull);
      expect(destination['name'], isNotNull);

      print('   Origen: ${origin['name']} (${origin['lat']}, ${origin['lng']})');
      print('   Destino: ${destination['name']} (${destination['lat']}, ${destination['lng']})');

      // 4. VALIDAR RUTA
      final route = tripData['route'] as Map<String, dynamic>;
      expect(route['routeId'], isNotNull);
      expect(route['totalDuration'], isNotNull);
      expect(route['segments'], isNotNull);

      print('   Duración total: ${route['totalDuration']}s (${(route['totalDuration'] / 60).toStringAsFixed(1)} min)');
      print('   Distancia caminata: ${route['totalWalkDistance']}m');

      // 5. VALIDAR SEGMENTOS
      final segments = route['segments'] as List;
      expect(segments.isNotEmpty, true);

      print('   Segmentos: ${segments.length}');

      var totalGeometryPoints = 0;

      for (var i = 0; i < segments.length; i++) {
        final segment = segments[i] as Map<String, dynamic>;

        // Cada segmento debe tener estos campos
        expect(segment['type'], isNotNull);
        expect(segment['description'], isNotNull);

        final type = segment['type'] as String;
        final description = segment['description'] as String;
        final duration = segment['duration'] as int?;
        final distance = segment['distance'] as int?;
        final geometry = segment['geometry'] as List?;

        final geometryCount = geometry?.length ?? 0;
        totalGeometryPoints += geometryCount;

        print('\n   📍 Segmento ${i + 1}/${segments.length}: $type');
        print('      Descripción: $description');
        if (duration != null) print('      Duración: ${duration}s');
        if (distance != null) print('      Distancia: ${distance}m');
        print('      Puntos geometría: $geometryCount');

        // Validar que los segmentos que NO son ESPERAR tienen geometría
        if (type != 'ESPERAR_BUS') {
          expect(geometry, isNotNull);
          expect(geometry!.isNotEmpty, true, reason: 'Segmento $type debe tener geometría');

          // Validar primer punto de geometría
          final firstPoint = geometry.first as Map<String, dynamic>;
          expect(firstPoint['lat'], isNotNull);
          expect(firstPoint['lng'], isNotNull);
        }
      }

      print('\n   📊 Total puntos de geometría: $totalGeometryPoints');

      // 6. VALIDAR GPS PLAYBACK
      final gpsPlayback = tripData['gpsPlayback'] as List?;
      if (gpsPlayback != null && gpsPlayback.isNotEmpty) {
        print('\n   📍 GPS Playback: ${gpsPlayback.length} puntos');

        final firstPoint = gpsPlayback.first as Map<String, dynamic>;
        final lastPoint = gpsPlayback.last as Map<String, dynamic>;

        expect(firstPoint['lat'], isNotNull);
        expect(firstPoint['lng'], isNotNull);
        expect(firstPoint['timestamp'], isNotNull);

        print('      Primer punto: t=${firstPoint['timestamp']}s');
        print('      Último punto: t=${lastPoint['timestamp']}s');
        print('      Duración: ${lastPoint['timestamp']}s');
      } else {
        print('\n   ⚠️  GPS Playback vacío (capturado desde carousel)');
      }

      // 7. VALIDAR CHECKPOINTS
      final checkpoints = tripData['checkpoints'] as List?;
      if (checkpoints != null && checkpoints.isNotEmpty) {
        print('\n   ✅ Checkpoints: ${checkpoints.length}');

        for (var i = 0; i < checkpoints.length; i++) {
          final checkpoint = checkpoints[i] as Map<String, dynamic>;
          expect(checkpoint['timestamp'], isNotNull);

          final type = checkpoint['type'] ?? checkpoint['event'] ?? 'unknown';
          print('      CP${i + 1}: t=${checkpoint['timestamp']}s, $type');
        }
      } else {
        print('\n   ⚠️  Checkpoints vacíos (capturado desde carousel)');
      }

      // 8. VALIDAR STOPS
      final stops = route['stops'] as List?;
      if (stops != null && stops.isNotEmpty) {
        print('\n   🚏 Paradas: ${stops.length}');

        for (var i = 0; i < stops.length; i++) {
          final stop = stops[i] as Map<String, dynamic>;
          expect(stop['stopId'], isNotNull);
          expect(stop['name'], isNotNull);
          expect(stop['lat'], isNotNull);
          expect(stop['lng'], isNotNull);

          print('      Parada ${i + 1}: ${stop['name']} (${stop['stopId']})');
        }
      }

      print('\n🎉 JSON validado correctamente - Estructura completa y consistente');
    });

    test('Verificar que el JSON tiene data de la API (geometrías extensas)', () async {
      final file = File('test/fixtures/trip_example_simple.json');
      final jsonString = await file.readAsString();
      final tripData = json.decode(jsonString) as Map<String, dynamic>;

      final route = tripData['route'] as Map<String, dynamic>;
      final segments = route['segments'] as List;

      // Buscar el segmento VIAJE_EN_BUS que debe tener geometría extensa de la API
      final busSegment = segments.firstWhere(
        (s) => (s as Map<String, dynamic>)['type'] == 'VIAJE_EN_BUS',
        orElse: () => null,
      );

      if (busSegment != null) {
        final segment = busSegment as Map<String, dynamic>;
        final geometry = segment['geometry'] as List?;

        expect(geometry, isNotNull);
        expect(geometry!.length, greaterThan(50),
          reason: 'Geometría del bus debe tener muchos puntos (viene de shapes.geojson de la API)');

        print('\n🚌 Segmento de bus validado:');
        print('   Puntos de geometría: ${geometry.length}');
        print('   Esto confirma que es data real de la API (shapes.geojson)');
        print('   ✅ JSON contiene geometrías completas de producción');
      } else {
        print('\n⚠️  No se encontró segmento VIAJE_EN_BUS');
      }
    });
  });
}
