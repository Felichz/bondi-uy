/// Test de integración completo usando datos reales capturados desde la app
///
/// Este test ejecuta TODO el stack real:
/// - GeometryAdapter (GPS, geometría, distancias)
/// - TripStateMachine (lógica de pasos)
/// - TripOrchestrator (coordinación)
///
/// Usa TripIntegrationRunner para ejecutar GPS playback y validar checkpoints.

import 'package:flutter_test/flutter_test.dart';
import '../helpers/trip_fixture_data.dart';
import '../helpers/trip_integration_runner.dart';

void main() {
  group('Trip Integration Test - Datos Reales', () {
    test('Ejecutar trip completo desde fixture real', () async {
      // Cargar fixture con datos reales capturados desde la app
      final fixture = await TripFixtureData.loadFromFile(
        'test/fixtures/trip_example_simple.json',
      );

      print('\n🧪 ========================================');
      print('🧪 TEST DE INTEGRACIÓN CON DATOS REALES');
      print('🧪 ========================================');
      print('📝 Trip: ${fixture.name}');
      print('🆔 ID: ${fixture.tripId}');
      print('📅 Capturado: ${fixture.capturedAt}');
      print('🧪 ========================================\n');

      // Crear runner
      final runner = TripIntegrationRunner(fixture);

      // Ejecutar test completo
      final result = await runner.run();

      // Imprimir reporte
      result.printReport();

      // Assertions de Flutter Test
      expect(result.success, true,
          reason: 'El test de integración debe ser exitoso');

      // Validar que todos los checkpoints pasaron
      for (final checkpointResult in result.checkpointResults) {
        expect(checkpointResult.passed, true,
            reason:
                'Checkpoint "${checkpointResult.checkpointName}" falló: ${checkpointResult.failures.join(", ")}');
      }

      // Validar estado final
      expect(result.finalState['isCompleted'], fixture.expectedBehavior.shouldComplete,
          reason: 'El estado final de completado debe coincidir con lo esperado');

      print('\n✅ TEST DE INTEGRACIÓN COMPLETADO EXITOSAMENTE\n');
    });

    test('Validar que fixture tiene datos necesarios', () async {
      final fixture = await TripFixtureData.loadFromFile(
        'test/fixtures/trip_example_simple.json',
      );

      // Validar que no es placeholder
      expect(fixture.tripId, isNot('PLACEHOLDER'),
          reason: 'Debes reemplazar el fixture con datos reales capturados');

      // Validar estructura básica
      expect(fixture.route.segments, isNotEmpty,
          reason: 'El fixture debe tener segments');

      expect(fixture.route.stops, isNotEmpty,
          reason: 'El fixture debe tener stops');

      // Validar GPS playback
      expect(fixture.gpsPlayback, isNotEmpty,
          reason:
              'El fixture debe tener gpsPlayback para test de integración');

      // Validar que las geometrías no estén vacías
      int segmentsWithGeometry = 0;
      for (final segment in fixture.route.segments) {
        if (segment.geometry.isNotEmpty) {
          segmentsWithGeometry++;
        }
      }

      expect(segmentsWithGeometry, greaterThan(0),
          reason:
              'Al menos un segment debe tener geometría para validar cálculos de distancia');

      print('✅ Fixture válido con datos reales');
    });

    test('Validar construcción de componentes desde fixture', () async {
      final fixture = await TripFixtureData.loadFromFile(
        'test/fixtures/trip_example_simple.json',
      );

      final runner = TripIntegrationRunner(fixture);

      // Esto lanzará excepción si el fixture es inválido
      expect(() => runner.run(), returnsNormally);

      print('✅ Componentes se construyen correctamente desde fixture');
    });
  });

  group('Trip Integration Test - Escenarios Específicos', () {
    test('SKIP: Viaje con trasbordo (2 buses)', () async {
      // Este test se saltea hasta que haya un fixture con trasbordo
      // Para implementarlo:
      // 1. Capturar un viaje real con trasbordo desde la app
      // 2. Crear test/fixtures/trip_trasbordo_2buses.json
      // 3. Agregar checkpoints específicos para detección de trasbordo
      // 4. Remover el skip

      print('⏭️  Test pendiente: necesita fixture con trasbordo');
    }, skip: true);

    test('SKIP: Viaje con caminata larga', () async {
      // Test para validar progreso de caminata larga
      // Útil para detectar bugs en cálculo de distancias

      print('⏭️  Test pendiente: necesita fixture con caminata larga');
    }, skip: true);

    test('SKIP: Viaje con bus de geometría compleja', () async {
      // Test para validar detección de boarding con geometrías curvas/complejas

      print('⏭️  Test pendiente: necesita fixture con geometría compleja');
    }, skip: true);
  });

  group('Debugging y Helpers', () {
    test('Inspeccionar estructura de fixture', () async {
      final fixture = await TripFixtureData.loadFromFile(
        'test/fixtures/trip_example_simple.json',
      );

      print('\n📊 ESTRUCTURA DEL FIXTURE');
      print('=' * 60);
      print('Trip ID: ${fixture.tripId}');
      print('Nombre: ${fixture.name}');
      print('\nOrigen: ${fixture.origin.name}');
      print('  Coordenadas: (${fixture.origin.lat}, ${fixture.origin.lng})');
      print('\nDestino: ${fixture.destination.name}');
      print(
          '  Coordenadas: (${fixture.destination.lat}, ${fixture.destination.lng})');

      print('\nRuta:');
      print('  • Stops: ${fixture.route.stops.length}');
      for (final stop in fixture.route.stops) {
        print('    - ${stop.name} (${stop.stopId})');
        print('      Líneas: ${stop.busLines.join(", ")}');
      }

      print('  • Segments: ${fixture.route.segments.length}');
      for (int i = 0; i < fixture.route.segments.length; i++) {
        final seg = fixture.route.segments[i];
        print('    ${i + 1}. ${seg.type}: ${seg.description}');
        print('       Duración: ${seg.duration}s, Distancia: ${seg.distance}m');
        print('       Geometría: ${seg.geometry.length} puntos');
      }

      print('\nGPS Playback: ${fixture.gpsPlayback.length} puntos');
      if (fixture.gpsPlayback.isNotEmpty) {
        print('  • Primer punto: t=${fixture.gpsPlayback.first.timestamp}s');
        print('  • Último punto: t=${fixture.gpsPlayback.last.timestamp}s');
        print('  • Duración total: ${fixture.gpsPlayback.last.timestamp}s');
      }

      print('\nCheckpoints: ${fixture.checkpoints.length}');
      for (final cp in fixture.checkpoints) {
        print('  • [${cp.timestamp}s] ${cp.name}');
      }

      print('\nComportamiento esperado:');
      print('  • Debe completarse: ${fixture.expectedBehavior.shouldComplete}');
      print('  • Pasos esperados: ${fixture.expectedBehavior.stepsExpected}');
      print('  • Duración total: ${fixture.expectedBehavior.totalDuration}s');

      print('=' * 60 + '\n');
    });
  });
}
