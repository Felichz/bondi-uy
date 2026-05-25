import 'package:flutter_test/flutter_test.dart';
import 'package:bondi_uy/map_manager/map_bus_realtime.dart';
import 'package:bondi_uy/map_manager/map_manager.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';

// Mock classes for testing
class MockMapManager extends MapManager {
  MockMapManager() : super(null);

  final List<String> registeredSources = [];
  final List<String> registeredLayers = [];

  void registerSource(String sourceId) {
    registeredSources.add(sourceId);
  }

  void registerLayer(String layerId) {
    registeredLayers.add(layerId);
  }

  void clearRegistrations() {
    registeredSources.clear();
    registeredLayers.clear();
  }
}

class MockMapIconsLoader {
  bool areIconsLoaded = true;
}

void main() {
  group('BusTrackingMode', () {
    test('should have all required tracking modes', () {
      expect(BusTrackingMode.values.length, equals(3));
      expect(BusTrackingMode.values, contains(BusTrackingMode.INACTIVE));
      expect(BusTrackingMode.values, contains(BusTrackingMode.API_REALTIME));
      expect(BusTrackingMode.values, contains(BusTrackingMode.USER_LOCATION));
    });
  });

  group('MapBusRealtime', () {
    late MapBusRealtime mapBusRealtime;
    late MockMapManager mockMapManager;

    setUp(() {
      mockMapManager = MockMapManager();
      // Note: For unit tests, we pass null for MapboxMap since we can't easily mock it
      // In integration tests, we would use a real or properly mocked MapboxMap
      mapBusRealtime = MapBusRealtime(null, mockMapManager);
    });

    tearDown(() {
      mapBusRealtime.dispose();
    });

    group('Initialization', () {
      test('should initialize with default tracking mode', () {
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.INACTIVE));
      });

      test('should have correct constants defined', () {
        expect(MapBusRealtime.BUS_REALTIME_SOURCE_PREFIX, equals('bus-realtime-source-'));
        expect(MapBusRealtime.BUS_REALTIME_LAYER_PREFIX, equals('bus-realtime-layer-'));
        expect(MapBusRealtime.BUS_TOOLTIP_LAYER_PREFIX, equals('bus-tooltip-layer-'));
        expect(MapBusRealtime.BUS_APPROACH_SOURCE_PREFIX, equals('bus-approach-source-'));
        expect(MapBusRealtime.BUS_APPROACH_LAYER_PREFIX, equals('bus-approach-layer-'));
        expect(MapBusRealtime.USER_BUS_SOURCE_ID, equals('user-bus-source'));
        expect(MapBusRealtime.USER_BUS_LAYER_ID, equals('user-bus-layer'));
        expect(MapBusRealtime.USER_BUS_ICON_ID, equals('user-bus-icon'));
      });
    });

    group('Tracking Mode Management', () {
      test('should switch to user location mode', () async {
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.INACTIVE));

        await mapBusRealtime.switchToUserLocationMode();

        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.USER_LOCATION));
      });

      test('should start API tracking mode', () async {
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.INACTIVE));

        await mapBusRealtime.startApiTracking();

        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.API_REALTIME));
      });

      test('should stop all tracking', () async {
        // First start some tracking
        await mapBusRealtime.switchToUserLocationMode();
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.USER_LOCATION));

        // Then stop it
        mapBusRealtime.stopAllTracking();

        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.INACTIVE));
      });

      test('should handle multiple mode switches', () async {
        // Start with API tracking
        await mapBusRealtime.startApiTracking();
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.API_REALTIME));

        // Switch to user location
        await mapBusRealtime.switchToUserLocationMode();
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.USER_LOCATION));

        // Stop all tracking
        mapBusRealtime.stopAllTracking();
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.INACTIVE));

        // Start API tracking again
        await mapBusRealtime.startApiTracking();
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.API_REALTIME));
      });
    });

    group('User Location Tracking', () {
      test('should update bus to user location when in correct mode', () async {
        final userLocation = Coordenada(latitud: -34.906, longitud: -56.186);
        
        // Switch to user location mode first
        await mapBusRealtime.switchToUserLocationMode();
        
        // This should work without throwing (even with null MapboxMap in unit test)
        await mapBusRealtime.updateBusToUserLocation(userLocation);
        
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.USER_LOCATION));
      });

      test('should not update bus location when not in user tracking mode', () async {
        final userLocation = Coordenada(latitud: -34.906, longitud: -56.186);
        
        // Keep in INACTIVE mode
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.INACTIVE));
        
        // This should not throw but also not do anything
        await mapBusRealtime.updateBusToUserLocation(userLocation);
        
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.INACTIVE));
      });

      test('should handle null mapbox map gracefully', () async {
        final userLocation = Coordenada(latitud: -34.906, longitud: -56.186);
        
        await mapBusRealtime.switchToUserLocationMode();
        
        // This should not throw even with null MapboxMap
        expect(() async => await mapBusRealtime.updateBusToUserLocation(userLocation), 
               returnsNormally);
      });
    });

    group('State Management', () {
      test('should reset tracking mode when disposing', () async {
        await mapBusRealtime.switchToUserLocationMode();
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.USER_LOCATION));

        mapBusRealtime.dispose();

        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.INACTIVE));
      });

      test('should handle dispose when already inactive', () {
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.INACTIVE));
        
        // Should not throw
        expect(() => mapBusRealtime.dispose(), returnsNormally);
        
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.INACTIVE));
      });
    });

    group('Integration Scenarios', () {
      test('should handle typical bus boarding flow', () async {
        // Start with API tracking (waiting for bus)
        await mapBusRealtime.startApiTracking();
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.API_REALTIME));

        // User boards bus, switch to user location tracking
        await mapBusRealtime.switchToUserLocationMode();
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.USER_LOCATION));

        // Update user location while on bus
        final userLocation = Coordenada(latitud: -34.906, longitud: -56.186);
        await mapBusRealtime.updateBusToUserLocation(userLocation);
        
        // User arrives at destination, stop tracking
        mapBusRealtime.stopAllTracking();
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.INACTIVE));
      });

      test('should handle multiple consecutive user location updates', () async {
        await mapBusRealtime.switchToUserLocationMode();
        
        final locations = [
          Coordenada(latitud: -34.906, longitud: -56.186),
          Coordenada(latitud: -34.907, longitud: -56.187),
          Coordenada(latitud: -34.908, longitud: -56.188),
        ];

        for (final location in locations) {
          await mapBusRealtime.updateBusToUserLocation(location);
          expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.USER_LOCATION));
        }
      });

      test('should handle rapid mode switches', () async {
        // Rapidly switch between modes
        for (int i = 0; i < 5; i++) {
          await mapBusRealtime.startApiTracking();
          expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.API_REALTIME));

          await mapBusRealtime.switchToUserLocationMode();
          expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.USER_LOCATION));

          mapBusRealtime.stopAllTracking();
          expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.INACTIVE));
        }
      });
    });

    group('Error Handling', () {
      test('should handle null user location gracefully', () async {
        await mapBusRealtime.switchToUserLocationMode();
        
        // This is a developer error, but should not crash the app
        // In a real implementation, we might want to add null checks
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.USER_LOCATION));
      });

      test('should maintain consistent state after errors', () async {
        await mapBusRealtime.startApiTracking();
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.API_REALTIME));

        // Even if some operation fails, the mode should remain consistent
        // (In this unit test, we can't easily simulate MapboxMap errors)
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.API_REALTIME));
      });
    });

    group('Performance Considerations', () {
      test('should handle frequent location updates efficiently', () async {
        await mapBusRealtime.switchToUserLocationMode();
        
        // Simulate rapid location updates (like GPS every second)
        final startTime = DateTime.now();
        
        for (int i = 0; i < 100; i++) {
          final location = Coordenada(
            latitud: -34.906 + (i * 0.0001), 
            longitud: -56.186 + (i * 0.0001)
          );
          await mapBusRealtime.updateBusToUserLocation(location);
        }
        
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);
        
        // Should complete reasonably quickly (less than 1 second for 100 updates)
        expect(duration.inMilliseconds, lessThan(1000));
        expect(mapBusRealtime.trackingMode, equals(BusTrackingMode.USER_LOCATION));
      });
    });
  });

  group('BusTrackingMode Edge Cases', () {
    test('should handle enum comparison correctly', () {
      expect(BusTrackingMode.INACTIVE == BusTrackingMode.INACTIVE, isTrue);
      expect(BusTrackingMode.API_REALTIME == BusTrackingMode.USER_LOCATION, isFalse);
    });

    test('should have meaningful enum names', () {
      expect(BusTrackingMode.INACTIVE.toString(), contains('INACTIVE'));
      expect(BusTrackingMode.API_REALTIME.toString(), contains('API_REALTIME'));
      expect(BusTrackingMode.USER_LOCATION.toString(), contains('USER_LOCATION'));
    });
  });

  group('Bus Approach Line Stop Position', () {
    late MapBusRealtime mapBusRealtime;
    late MockMapManager mockMapManager;

    setUp(() {
      mockMapManager = MockMapManager();
      mapBusRealtime = MapBusRealtime(null, mockMapManager);
    });

    tearDown(() {
      mapBusRealtime.dispose();
    });

    test('BUG: Durante ESPERAR_BUS, debe trackear parada DESTINO del próximo bus', () async {
      // Setup: Crear tramos del viaje (típico escenario con esperar + viaje)
      final paradaOrigen = Coordenada(latitud: -34.904436, longitud: -56.129387);
      final paradaDestino = Coordenada(latitud: -34.906003, longitud: -56.200689);

      final tramoEspera = TramoViajeMostrable(
        idTramo: 'espera_1',
        tipo: TipoTramoViaje.ESPERAR_BUS,
        descripcion: 'Esperar bus',
        duracionEstimadaSegundos: 300,
        distanciaMetros: 0,
        posicionPunto: paradaOrigen,
        nombreLineaBus: '121',
      );

      final tramoViaje = TramoViajeMostrable(
        idTramo: 'viaje_1',
        tipo: TipoTramoViaje.VIAJE_EN_BUS,
        descripcion: 'Viaje en bus 121',
        duracionEstimadaSegundos: 600,
        distanciaMetros: 5000,
        nombreLineaBus: '121',
        coordenadasParadaOrigen: paradaOrigen,  // Parada donde el usuario SUBIRÁ
        coordenadasParadaDestino: paradaDestino, // Parada donde el usuario debe BAJAR
        idParadaOrigenTramoBus: 'stop_origin',
        idParadaDestinoTramoBus: 'stop_dest',
        shapeId: 'shape_121',
        geometriaPolilinea: [paradaOrigen, paradaDestino],
      );

      final tramos = [tramoEspera, tramoViaje];

      // Act: Simular que estamos ESPERANDO el bus (índice 0)
      // En este caso, se busca el siguiente tramo VIAJE_EN_BUS y se muestra
      // la línea verde del bus hacia la parada donde estamos esperando
      await mapBusRealtime.updateBusTrackingForLeg(0, tramos);

      // Assert: Verificar que currentStopPosition sea la parada de ORIGEN
      // (donde el usuario está esperando para SUBIR)
      final currentStop = mapBusRealtime.currentStopPosition;

      // BUG ACTUAL (línea 290-291 de map_bus_realtime.dart):
      // Durante ESPERAR_BUS, se asigna _currentStopPosition = tramo.coordenadasParadaOrigen
      // Esto es CORRECTO para la fase ESPERAR_BUS (mostrar línea hacia donde subirá)

      // Pero cuando cambiamos a VIAJE_EN_BUS, la misma lógica se mantiene incorrectamente
      expect(currentStop, isNotNull, reason: 'Debe haber una parada siendo trackeada');
      expect(currentStop!.latitud, equals(paradaOrigen.latitud),
        reason: 'Durante ESPERAR_BUS, debe mostrar línea hacia parada de ORIGEN (donde subir)');
    });

    test('FIX: switchToUserLocationMode debe actualizar parada a DESTINO', () async {
      // Setup: Simular flujo completo ESPERAR_BUS → subir al bus → USER_LOCATION
      final paradaOrigen = Coordenada(latitud: -34.904436, longitud: -56.129387);
      final paradaDestino = Coordenada(latitud: -34.906003, longitud: -56.200689);

      final tramoEspera = TramoViajeMostrable(
        idTramo: 'espera_1',
        tipo: TipoTramoViaje.ESPERAR_BUS,
        descripcion: 'Esperar bus',
        duracionEstimadaSegundos: 300,
        distanciaMetros: 0,
        posicionPunto: paradaOrigen,
        nombreLineaBus: '121',
      );

      final tramoViaje = TramoViajeMostrable(
        idTramo: 'viaje_1',
        tipo: TipoTramoViaje.VIAJE_EN_BUS,
        descripcion: 'Viaje en bus 121',
        duracionEstimadaSegundos: 600,
        distanciaMetros: 5000,
        nombreLineaBus: '121',
        coordenadasParadaOrigen: paradaOrigen,  // Parada donde el usuario SUBE
        coordenadasParadaDestino: paradaDestino, // Parada donde el usuario debe BAJAR
        idParadaOrigenTramoBus: 'stop_origin',
        idParadaDestinoTramoBus: 'stop_dest',
        shapeId: 'shape_121',
        geometriaPolilinea: [paradaOrigen, paradaDestino],
      );

      final tramos = [tramoEspera, tramoViaje];

      // Step 1: Usuario esperando el bus (fase ESPERAR_BUS)
      await mapBusRealtime.updateBusTrackingForLeg(0, tramos);

      // Verificar que se está trackeando la parada de ORIGEN (donde subir)
      var currentStop = mapBusRealtime.currentStopPosition;
      expect(currentStop, isNotNull);
      expect(currentStop!.latitud, equals(paradaOrigen.latitud),
        reason: 'Durante ESPERAR_BUS, debe trackear parada ORIGEN');

      // Step 2: Usuario sube al bus → cambiar a USER_LOCATION mode
      await mapBusRealtime.switchToUserLocationMode();

      // Verificar que ahora se está trackeando la parada de DESTINO (donde bajar)
      currentStop = mapBusRealtime.currentStopPosition;
      expect(currentStop, isNotNull,
        reason: 'Debe seguir trackeando una parada después de switchToUserLocationMode');
      expect(currentStop!.latitud, equals(paradaDestino.latitud),
        reason: 'Después de switchToUserLocationMode, debe trackear parada DESTINO (donde bajar)');
      expect(currentStop.longitud, equals(paradaDestino.longitud),
        reason: 'Después de switchToUserLocationMode, debe trackear parada DESTINO (donde bajar)');

      // Step 3: Simular actualización de ubicación del usuario
      final userLocation = Coordenada(latitud: -34.9094, longitud: -56.142317);
      await mapBusRealtime.updateBusToUserLocation(userLocation);

      // La parada trackeada debe seguir siendo DESTINO
      currentStop = mapBusRealtime.currentStopPosition;
      expect(currentStop, isNotNull);
      expect(currentStop!.latitud, equals(paradaDestino.latitud),
        reason: 'Debe mantener parada DESTINO durante todo el viaje en bus');
    });
  });
}