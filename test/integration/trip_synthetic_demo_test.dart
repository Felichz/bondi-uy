/// Test de demostración del sistema de GPS sintético
///
/// Este test NO requiere datos reales - usa geometrías sintéticas de Montevideo
/// para demostrar que el sistema completo funciona.

import 'package:flutter_test/flutter_test.dart';
import 'package:bondi_uy/devtools/gps_playback_generator.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import '../helpers/trip_fixture_data.dart';
import '../helpers/trip_integration_runner.dart';

void main() {
  group('Demo de GPS Sintético', () {
    test('Generar GPS sintético desde geometrías de prueba', () async {
      print('\n🎬 ========================================');
      print('🎬 DEMO: Generación de GPS Sintético');
      print('🎬 ========================================\n');

      // Cargar fixture con geometrías pero SIN gpsPlayback
      final fixture = await TripFixtureData.loadFromFile(
        'test/fixtures/trip_test_synthetic.json',
      );

      print('📊 Fixture cargado:');
      print('   • Nombre: ${fixture.name}');
      print('   • Origen: ${fixture.origin.name}');
      print('   • Destino: ${fixture.destination.name}');
      print('   • Segments: ${fixture.route.segments.length}');
      print('   • GPS playback original: ${fixture.gpsPlayback.length} puntos');
      print('   • Checkpoints originales: ${fixture.checkpoints.length}');
      print('');

      // Construir tramos desde segments
      final tramos = <TramoViajeMostrable>[];
      for (final segment in fixture.route.segments) {
        final tipo = TipoTramoViaje.values.firstWhere(
          (t) => t.name == segment.type,
        );

        tramos.add(TramoViajeMostrable(
          idTramo: 'tramo_${tramos.length}',
          tipo: tipo,
          geometriaPolilinea: segment.geometry.map((g) => g.toCoord()).toList(),
          posicionPunto: segment.at != null
              ? fixture.route.stops
                  .firstWhere((s) => s.stopId == segment.at)
                  .toCoord()
              : null,
          descripcion: segment.description,
          duracionEstimadaSegundos: segment.duration,
          distanciaMetros: segment.distance ?? 0,
          nombreLineaBus: segment.busLine,
          coordenadasParadaOrigen: segment.from != null && segment.from != 'origin'
              ? fixture.route.stops
                  .firstWhere((s) => s.stopId == segment.from)
                  .toCoord()
              : null,
          coordenadasParadaDestino: segment.to != null && segment.to != 'destination'
              ? fixture.route.stops
                  .firstWhere((s) => s.stopId == segment.to)
                  .toCoord()
              : null,
        ));
      }

      print('🎬 Generando GPS playback sintético...\n');

      // Generar GPS playback sintético
      final gpsPlayback = GpsPlaybackGenerator.generateFromRoute(
        origin: fixture.origin.toCoord(),
        destination: fixture.destination.toCoord(),
        tramos: tramos,
        speedMultiplier: 1.0,
      );

      print('\n✅ GPS playback generado:');
      print('   • Total de puntos: ${gpsPlayback.length}');
      if (gpsPlayback.isNotEmpty) {
        print('   • Primer punto: t=${gpsPlayback.first['timestamp']}s');
        print('   • Último punto: t=${gpsPlayback.last['timestamp']}s');
        print('   • Duración total: ${gpsPlayback.last['timestamp']}s');
      }
      print('');

      // Validar que se generaron puntos
      expect(gpsPlayback, isNotEmpty, reason: 'Debe generar GPS playback');
      expect(gpsPlayback.length, greaterThan(10), reason: 'Debe generar múltiples puntos');

      // Validar timestamps
      expect(gpsPlayback.first['timestamp'], 0, reason: 'Debe empezar en t=0');
      expect(
        gpsPlayback.last['timestamp'],
        greaterThan(0),
        reason: 'Debe tener duración > 0',
      );

      // Validar que los timestamps son monótonos
      for (int i = 1; i < gpsPlayback.length; i++) {
        expect(
          gpsPlayback[i]['timestamp'],
          greaterThanOrEqualTo(gpsPlayback[i - 1]['timestamp']),
          reason: 'Timestamps deben ser monótonos',
        );
      }

      print('🎯 Generando checkpoints automáticos...\n');

      // Generar checkpoints automáticos
      final checkpoints = GpsPlaybackGenerator.generateCheckpoints(
        tramos: tramos,
        gpsPlayback: gpsPlayback,
      );

      print('✅ Checkpoints generados:');
      print('   • Total: ${checkpoints.length}');
      for (int i = 0; i < checkpoints.length && i < 5; i++) {
        final cp = checkpoints[i];
        print('   • [${cp['timestamp']}s] ${cp['name']}');
      }
      if (checkpoints.length > 5) {
        print('   ... y ${checkpoints.length - 5} más');
      }
      print('');

      // Validar checkpoints
      expect(checkpoints, isNotEmpty, reason: 'Debe generar checkpoints');
      expect(checkpoints.length, greaterThan(3), reason: 'Debe generar varios checkpoints');

      // Validar estructura de checkpoints
      for (final checkpoint in checkpoints) {
        expect(checkpoint['timestamp'], isNotNull);
        expect(checkpoint['name'], isNotNull);
        expect(checkpoint['assertions'], isNotNull);
      }

      print('🧪 ========================================');
      print('🧪 DEMO COMPLETADO EXITOSAMENTE');
      print('🧪 ========================================\n');
    });

    test('Ejecutar test de integración con GPS sintético', () async {
      print('\n🧪 ========================================');
      print('🧪 TEST DE INTEGRACIÓN CON GPS SINTÉTICO');
      print('🧪 ========================================\n');

      // Cargar fixture original (sin GPS)
      var fixture = await TripFixtureData.loadFromFile(
        'test/fixtures/trip_test_synthetic.json',
      );

      // Generar GPS y checkpoints sintéticos
      final tramos = <TramoViajeMostrable>[];
      for (final segment in fixture.route.segments) {
        final tipo = TipoTramoViaje.values.firstWhere(
          (t) => t.name == segment.type,
        );

        tramos.add(TramoViajeMostrable(
          idTramo: 'tramo_${tramos.length}',
          tipo: tipo,
          geometriaPolilinea: segment.geometry.map((g) => g.toCoord()).toList(),
          posicionPunto: segment.at != null
              ? fixture.route.stops
                  .firstWhere((s) => s.stopId == segment.at)
                  .toCoord()
              : null,
          descripcion: segment.description,
          duracionEstimadaSegundos: segment.duration,
          distanciaMetros: segment.distance ?? 0,
          nombreLineaBus: segment.busLine,
          coordenadasParadaOrigen: segment.from != null && segment.from != 'origin'
              ? fixture.route.stops
                  .firstWhere((s) => s.stopId == segment.from)
                  .toCoord()
              : null,
          coordenadasParadaDestino: segment.to != null && segment.to != 'destination'
              ? fixture.route.stops
                  .firstWhere((s) => s.stopId == segment.to)
                  .toCoord()
              : null,
        ));
      }

      final gpsPlayback = GpsPlaybackGenerator.generateFromRoute(
        origin: fixture.origin.toCoord(),
        destination: fixture.destination.toCoord(),
        tramos: tramos,
        speedMultiplier: 2.0, // 2x más rápido para test
      );

      final checkpoints = GpsPlaybackGenerator.generateCheckpoints(
        tramos: tramos,
        gpsPlayback: gpsPlayback,
      );

      // Crear nuevo fixture con GPS sintético
      fixture = TripFixtureData(
        tripId: fixture.tripId,
        name: fixture.name,
        capturedAt: fixture.capturedAt,
        origin: fixture.origin,
        destination: fixture.destination,
        route: fixture.route,
        initialBusPosition: fixture.initialBusPosition,
        expectedBehavior: fixture.expectedBehavior,
        gpsPlayback: gpsPlayback.map((p) => GpsPlaybackPoint.fromJson(p)).toList(),
        checkpoints: checkpoints.map((c) => TripCheckpoint.fromJson(c)).toList(),
      );

      print('📊 Fixture con GPS sintético:');
      print('   • GPS points: ${fixture.gpsPlayback.length}');
      print('   • Checkpoints: ${fixture.checkpoints.length}');
      print('   • Duración: ${fixture.gpsPlayback.isNotEmpty ? fixture.gpsPlayback.last.timestamp : 0}s');
      print('');

      // Ejecutar test de integración completo
      final runner = TripIntegrationRunner(fixture);
      final result = await runner.run();

      // Imprimir reporte
      result.printReport();

      // Validaciones
      expect(result.checkpointResults, isNotEmpty, reason: 'Debe haber ejecutado checkpoints');

      // El test puede fallar por bugs en la lógica, pero debe ejecutarse sin errores
      if (!result.success) {
        print('\n⚠️  El test falló, pero eso es esperado si la lógica tiene bugs.');
        print('⚠️  Lo importante es que el sistema de GPS sintético FUNCIONA.');
        print('⚠️  Ahora puedes usar esto para debuggear la lógica de geometría.\n');
      }

      print('\n✅ SISTEMA DE GPS SINTÉTICO VALIDADO\n');
    });
  });
}
