import 'package:flutter_test/flutter_test.dart';
import 'package:bondi_uy/journey/location_tracker.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';

void main() {
  group('LocationTracker', () {
    late LocationTracker locationTracker;
    late List<Coordenada> locationUpdates;
    late List<String> arrivalDetections;

    setUp(() {
      locationUpdates = [];
      arrivalDetections = [];
      
      locationTracker = LocationTracker(
        onLocationUpdate: (location) => locationUpdates.add(location),
        onArrivalDetected: (geofenceId) => arrivalDetections.add(geofenceId),
      );
    });

    tearDown(() {
      locationTracker.dispose();
    });

    group('Initialization', () {
      test('should initialize with correct callbacks', () {
        expect(locationTracker.isTracking, isFalse);
        expect(locationTracker.lastKnownLocation, isNull);
        expect(locationTracker.activeGeofences, isEmpty);
      });
    });

    group('Geofence Management', () {
      test('should setup geofences correctly', () {
        final destinations = [
          Coordenada(latitud: -34.906, longitud: -56.186),
          Coordenada(latitud: -34.907, longitud: -56.187),
        ];
        final ids = ['stop_1', 'stop_2'];

        locationTracker.setupGeofencesForStep(destinations, ids);

        expect(locationTracker.activeGeofences.length, equals(2));
        expect(locationTracker.activeGeofences[0].id, equals('stop_1'));
        expect(locationTracker.activeGeofences[0].center, equals(destinations[0]));
        expect(locationTracker.activeGeofences[0].radius, equals(50.0));
      });

      test('should clear previous geofences when setting new ones', () {
        // Set initial geofences
        locationTracker.setupGeofencesForStep(
          [Coordenada(latitud: -34.906, longitud: -56.186)],
          ['stop_1'],
        );
        expect(locationTracker.activeGeofences.length, equals(1));

        // Set new geofences
        locationTracker.setupGeofencesForStep(
          [
            Coordenada(latitud: -34.907, longitud: -56.187),
            Coordenada(latitud: -34.908, longitud: -56.188),
          ],
          ['stop_2', 'stop_3'],
        );

        expect(locationTracker.activeGeofences.length, equals(2));
        expect(locationTracker.activeGeofences[0].id, equals('stop_2'));
        expect(locationTracker.activeGeofences[1].id, equals('stop_3'));
      });
    });

    group('GeofenceZone', () {
      test('should create geofence with correct properties', () {
        final center = Coordenada(latitud: -34.906, longitud: -56.186);
        final geofence = GeofenceZone(
          id: 'test_zone',
          center: center,
          radius: 100.0,
        );

        expect(geofence.id, equals('test_zone'));
        expect(geofence.center, equals(center));
        expect(geofence.radius, equals(100.0));
      });

      test('should have meaningful toString', () {
        final center = Coordenada(latitud: -34.906, longitud: -56.186);
        final geofence = GeofenceZone(
          id: 'test_zone',
          center: center,
          radius: 100.0,
        );

        final toString = geofence.toString();
        expect(toString, contains('test_zone'));
        expect(toString, contains('100.0'));
      });
    });

    group('Constants and Configuration', () {
      test('should have correct default constants', () {
        expect(LocationTracker.UPDATE_INTERVAL_MS, equals(5000));
        expect(LocationTracker.ARRIVAL_THRESHOLD_METERS, equals(50.0));
      });
    });

    group('Tracking State', () {
      test('should track state correctly when not tracking', () {
        expect(locationTracker.isTracking, isFalse);
      });

      test('should dispose correctly', () {
        locationTracker.setupGeofencesForStep(
          [Coordenada(latitud: -34.906, longitud: -56.186)],
          ['test'],
        );
        
        locationTracker.dispose();
        
        expect(locationTracker.isTracking, isFalse);
        expect(locationTracker.activeGeofences, isEmpty);
      });
    });

    group('Integration Tests', () {
      test('should handle multiple geofence setups without errors', () {
        for (int i = 0; i < 10; i++) {
          locationTracker.setupGeofencesForStep(
            [Coordenada(latitud: -34.906 + i * 0.001, longitud: -56.186)],
            ['stop_$i'],
          );
        }

        expect(locationTracker.activeGeofences.length, equals(1));
        expect(locationTracker.activeGeofences[0].id, equals('stop_9'));
      });
    });
  });

  group('LocationTracker Edge Cases', () {
    test('should handle empty geofence lists', () {
      final locationTracker = LocationTracker(
        onLocationUpdate: (_) {},
        onArrivalDetected: (_) {},
      );

      locationTracker.setupGeofencesForStep([], []);
      expect(locationTracker.activeGeofences, isEmpty);

      locationTracker.dispose();
    });

    test('should handle mismatched destination and id lists', () {
      final locationTracker = LocationTracker(
        onLocationUpdate: (_) {},
        onArrivalDetected: (_) {},
      );

      final destinations = [
        Coordenada(latitud: -34.906, longitud: -56.186),
        Coordenada(latitud: -34.907, longitud: -56.187),
      ];
      final ids = ['stop_1']; // Fewer IDs than destinations

      locationTracker.setupGeofencesForStep(destinations, ids);
      
      // Should only create geofences for the minimum of both lists
      expect(locationTracker.activeGeofences.length, equals(1));

      locationTracker.dispose();
    });
  });
}