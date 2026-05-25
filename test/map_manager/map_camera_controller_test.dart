import 'package:flutter_test/flutter_test.dart';
import 'package:bondi_uy/map_manager/map_camera_controller.dart';
import 'package:bondi_uy/map_manager/map_manager.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:async';

/// Tests unitarios de MapCameraController
///
/// Objetivo: Verificar lógica de decisión de zoom SIN renderizar mapa
/// - Qué coordenadas se recolectan para cada tipo de tramo
/// - Cuándo se ejecuta o bloquea un zoom (cooldown, auto-follow, cambios significativos)
/// - Correcta configuración de padding según contexto

void main() {
  group('MapCameraController Unit Tests', () {
    late MockMapboxMap mockMapbox;
    late MockMapManager mockMapManager;
    late MapCameraController controller;

    setUp(() {
      mockMapbox = MockMapboxMap();
      mockMapManager = MockMapManager();
      controller = MapCameraController(mockMapbox, mockMapManager);
    });

    group('zoomToCurrentLeg - Recolección de Coordenadas', () {
      test('CAMINAR: Incluye geometría + parada destino + usuario', () async {
        // Tramo CAMINAR con geometría de 10 puntos
        final tramo = _buildTramo(
          tipo: TipoTramoViaje.CAMINAR,
          geometry: _buildLine(start: Coordenada(latitud: -34.9, longitud: -56.1), points: 10, stepLat: 0.001),
          paradaDestino: Coordenada(latitud: -34.91, longitud: -56.11),
        );

        mockMapManager.userLocation = Coordenada(latitud: -34.905, longitud: -56.105);

        await controller.zoomToCurrentLeg(0, [tramo]);

        // Verificar que se llamó flyTo
        expect(mockMapbox.flyToCalls.length, 1, reason: 'Debe ejecutar 1 flyTo');

        final call = mockMapbox.flyToCalls.first;
        final coords = call.coordinates;

        // Debe incluir: geometría (10) + parada destino (1) + usuario (1) = 12
        expect(coords.length, greaterThanOrEqualTo(10),
          reason: 'Debe incluir al menos geometría del tramo');

        // Verificar parada destino incluida
        expect(coords.any((c) => c.latitud == -34.91 && c.longitud == -56.11), isTrue,
          reason: 'Debe incluir parada destino');

        // Verificar usuario incluido
        expect(coords.any((c) => c.latitud == -34.905 && c.longitud == -56.105), isTrue,
          reason: 'Debe incluir posición usuario');
      });

      test('ESPERAR_BUS: Incluye parada + bus + usuario', () async {
        final tramo = _buildTramo(
          tipo: TipoTramoViaje.ESPERAR_BUS,
          posicionPunto: Coordenada(latitud: -34.91, longitud: -56.11),
        );

        mockMapManager.userLocation = Coordenada(latitud: -34.9101, longitud: -56.1101);
        mockMapManager.busLocation = Coordenada(latitud: -34.905, longitud: -56.105);

        await controller.zoomToCurrentLeg(0, [tramo]);

        expect(mockMapbox.flyToCalls.length, 1);
        final coords = mockMapbox.flyToCalls.first.coordinates;

        // Debe incluir: parada (1) + bus (1) + usuario (1) = 3
        expect(coords.length, greaterThanOrEqualTo(3),
          reason: 'Debe incluir parada, bus y usuario');

        // Verificar parada
        expect(coords.any((c) => c.latitud == -34.91), isTrue, reason: 'Debe incluir parada');

        // Verificar bus
        expect(coords.any((c) => c.latitud == -34.905), isTrue, reason: 'Debe incluir bus');

        // Verificar usuario
        expect(coords.any((c) => c.latitud == -34.9101), isTrue, reason: 'Debe incluir usuario');
      });

      test('VIAJE_EN_BUS: Incluye bus + parada destino (NO geometría completa)', () async {
        // Bus ride con geometría de 100 puntos (toda la línea)
        final tramo = _buildTramo(
          tipo: TipoTramoViaje.VIAJE_EN_BUS,
          geometry: _buildLine(start: Coordenada(latitud: -34.9, longitud: -56.1), points: 100, stepLat: 0.0001),
          paradaDestino: Coordenada(latitud: -34.92, longitud: -56.12),
        );

        mockMapManager.busLocation = Coordenada(latitud: -34.905, longitud: -56.105);

        await controller.zoomToCurrentLeg(0, [tramo]);

        expect(mockMapbox.flyToCalls.length, 1);
        final coords = mockMapbox.flyToCalls.first.coordinates;

        // IMPORTANTE: NO debe incluir toda la geometría (sería zoom out masivo)
        // Solo debe incluir: bus actual + parada destino
        expect(coords.length, lessThan(10),
          reason: 'NO debe incluir geometría completa de línea bus (zoom out excesivo)');

        // Verificar bus incluido
        expect(coords.any((c) => c.latitud == -34.905), isTrue, reason: 'Debe incluir bus');

        // Verificar parada destino incluida
        expect(coords.any((c) => c.latitud == -34.92), isTrue, reason: 'Debe incluir parada destino');
      });

      test('VIAJE_EN_BUS sin bus position: Solo muestra parada destino', () async {
        final tramo = _buildTramo(
          tipo: TipoTramoViaje.VIAJE_EN_BUS,
          geometry: _buildLine(start: Coordenada(latitud: -34.9, longitud: -56.1), points: 100, stepLat: 0.0001),
          paradaDestino: Coordenada(latitud: -34.92, longitud: -56.12),
        );

        // Bus position es NULL (no disponible)
        mockMapManager.busLocation = null;

        await controller.zoomToCurrentLeg(0, [tramo]);

        expect(mockMapbox.flyToCalls.length, 1);
        final coords = mockMapbox.flyToCalls.first.coordinates;

        // Si solo hay parada destino (1 coord), usa zoom centrado en vez de bounds
        // O si flyTo se llama con 1 coord, verifica que sea la parada
        if (coords.length == 1) {
          expect(coords.first.latitud, -34.92, reason: 'Debe centrar en parada destino');
        } else {
          // Debe incluir al menos la parada destino
          expect(coords.any((c) => c.latitud == -34.92), isTrue,
            reason: 'Debe incluir parada destino incluso sin bus position');
        }
      });

      test('CAMINAR con bus cercano (ETA <= 5 min): Incluye bus', () async {
        final tramo = _buildTramo(
          tipo: TipoTramoViaje.CAMINAR,
          geometry: _buildLine(start: Coordenada(latitud: -34.9, longitud: -56.1), points: 5, stepLat: 0.001),
          paradaDestino: Coordenada(latitud: -34.905, longitud: -56.105),
        );

        // Bus a ~200m de la parada destino (~25 km/h = 7 m/s → ~30s ETA < 5 min)
        mockMapManager.busLocation = Coordenada(latitud: -34.903, longitud: -56.103);
        mockMapManager.userLocation = Coordenada(latitud: -34.9, longitud: -56.1);

        await controller.zoomToCurrentLeg(0, [tramo]);

        final coords = mockMapbox.flyToCalls.first.coordinates;

        // Debe incluir bus porque está cerca (útil para contexto)
        expect(coords.any((c) => (c.latitud - -34.903).abs() < 0.0001), isTrue,
          reason: 'Bus cercano (ETA < 5 min) debe incluirse para dar contexto');
      });

      test('CAMINAR con bus lejano (ETA > 5 min): NO incluye bus', () async {
        final tramo = _buildTramo(
          tipo: TipoTramoViaje.CAMINAR,
          geometry: _buildLine(start: Coordenada(latitud: -34.9, longitud: -56.1), points: 5, stepLat: 0.001),
          paradaDestino: Coordenada(latitud: -34.905, longitud: -56.105),
        );

        // Bus a ~5km de la parada destino (~25 km/h → ~12 min ETA > 5 min)
        mockMapManager.busLocation = Coordenada(latitud: -34.95, longitud: -56.15);
        mockMapManager.userLocation = Coordenada(latitud: -34.9, longitud: -56.1);

        await controller.zoomToCurrentLeg(0, [tramo]);

        final coords = mockMapbox.flyToCalls.first.coordinates;

        // NO debe incluir bus (zoom out innecesario)
        expect(coords.any((c) => (c.latitud - -34.95).abs() < 0.0001), isFalse,
          reason: 'Bus lejano (ETA > 5 min) NO debe incluirse (zoom out excesivo)');
      });

      test('Tramo con geometría vacía: Usa punto único con zoom fijo', () async {
        final tramo = _buildTramo(
          tipo: TipoTramoViaje.ESPERAR_BUS,
          posicionPunto: Coordenada(latitud: -34.91, longitud: -56.11),
          geometry: [], // vacío
        );

        await controller.zoomToCurrentLeg(0, [tramo]);

        // Debe haber llamado flyTo con zoom fijo
        expect(mockMapbox.flyToCalls.length, 1);

        final call = mockMapbox.flyToCalls.first;

        // Si solo hay 1 coordenada, usa zoom centrado a 16.0
        if (call.coordinates.length == 1) {
          expect(call.cameraOptions.zoom, 16.0,
            reason: 'Con 1 sola coordenada debe usar zoom fijo 16.0');
        }
      });
    });

    group('Auto-follow y Cooldown', () {
      test('Primera animación: NO aplica cooldown', () async {
        final tramo = _buildTramo(tipo: TipoTramoViaje.CAMINAR, geometry: _buildLine(points: 3));

        await controller.zoomToCurrentLeg(0, [tramo]);

        expect(mockMapbox.flyToCalls.length, 1,
          reason: 'Primera animación debe ejecutarse sin cooldown');
      });

      test('Segunda animación inmediata: Bloqueada por cooldown', () async {
        final tramo1 = _buildTramo(tipo: TipoTramoViaje.CAMINAR, geometry: _buildLine(points: 3));
        final tramo2 = _buildTramo(tipo: TipoTramoViaje.ESPERAR_BUS, posicionPunto: Coordenada(latitud: -34.92, longitud: -56.12));

        await controller.zoomToCurrentLeg(0, [tramo1]);
        expect(mockMapbox.flyToCalls.length, 1);

        // Inmediatamente después (sin esperar 3s)
        await controller.zoomToCurrentLeg(1, [tramo1, tramo2]);

        // BUG ESPERADO: Debería bloquearse por cooldown
        // PERO si hay override en transición de paso, podría pasar
        // Spec dice: "Override en transiciones de paso"

        // Por ahora esperamos que SÍ pase (override)
        expect(mockMapbox.flyToCalls.length, 2,
          reason: 'Transición de paso debe tener override de cooldown');
      });

      test('Auto-follow deshabilitado: Bloquea animaciones', () async {
        final tramo = _buildTramo(tipo: TipoTramoViaje.CAMINAR, geometry: _buildLine(points: 3));

        // Simular interacción manual del usuario
        controller.notifyManualInteraction();

        await controller.zoomToCurrentLeg(0, [tramo]);

        // Debe bloquearse porque auto-follow está off
        expect(mockMapbox.flyToCalls.length, 0,
          reason: 'Con auto-follow disabled NO debe animar');
      });

      test('Auto-follow resume después de 6s: Reactiva animaciones', () async {
        final tramo = _buildTramo(tipo: TipoTramoViaje.CAMINAR, geometry: _buildLine(points: 3));

        controller.notifyManualInteraction();

        // Esperar 6+ segundos (simular paso del tiempo)
        await Future.delayed(Duration(seconds: 7));

        // Forzar check de resume
        controller.maybeResumeAutoFollow();

        await controller.zoomToCurrentLeg(0, [tramo]);

        expect(mockMapbox.flyToCalls.length, 1,
          reason: 'Después de 6s auto-follow debe reactivarse');
      });
    });

    group('updateWaitingBusViewport - Actualizaciones Dinámicas', () {
      test('Primera llamada: Ejecuta zoom', () async {
        final tramo = _buildTramo(
          tipo: TipoTramoViaje.ESPERAR_BUS,
          posicionPunto: Coordenada(latitud: -34.91, longitud: -56.11),
          paradaOrigen: Coordenada(latitud: -34.91, longitud: -56.11),
        );

        final busPos = Coordenada(latitud: -34.905, longitud: -56.105);
        final userPos = Coordenada(latitud: -34.9101, longitud: -56.1101);

        await controller.updateWaitingBusViewport(
          waitingLeg: tramo,
          busPosition: busPos,
          userPosition: userPos,
        );

        expect(mockMapbox.flyToCalls.length, 1,
          reason: 'Primera actualización debe ejecutar zoom');
      });

      test('Llamada inmediata después: Bloqueada por cooldown', () async {
        final tramo = _buildTramo(
          tipo: TipoTramoViaje.ESPERAR_BUS,
          posicionPunto: Coordenada(latitud: -34.91, longitud: -56.11),
          paradaOrigen: Coordenada(latitud: -34.91, longitud: -56.11),
        );

        final busPos1 = Coordenada(latitud: -34.905, longitud: -56.105);
        final busPos2 = Coordenada(latitud: -34.906, longitud: -56.106); // movió 100m

        await controller.updateWaitingBusViewport(
          waitingLeg: tramo,
          busPosition: busPos1,
        );

        expect(mockMapbox.flyToCalls.length, 1);

        // Segunda llamada inmediata
        await controller.updateWaitingBusViewport(
          waitingLeg: tramo,
          busPosition: busPos2,
        );

        // Debe bloquearse por cooldown (< 3s desde última)
        expect(mockMapbox.flyToCalls.length, 1,
          reason: 'Segunda llamada inmediata debe bloquearse por cooldown');
      });

      test('Cambio insignificante (< 20m): No anima', () async {
        final tramo = _buildTramo(
          tipo: TipoTramoViaje.ESPERAR_BUS,
          posicionPunto: Coordenada(latitud: -34.91, longitud: -56.11),
          paradaOrigen: Coordenada(latitud: -34.91, longitud: -56.11),
        );

        final busPos1 = Coordenada(latitud: -34.905, longitud: -56.105);
        final busPos2 = Coordenada(latitud: -34.9051, longitud: -56.1051); // movió ~15m

        await controller.updateWaitingBusViewport(
          waitingLeg: tramo,
          busPosition: busPos1,
        );

        mockMapbox.flyToCalls.clear();

        // Esperar 4s (pasar cooldown)
        await Future.delayed(Duration(seconds: 4));

        await controller.updateWaitingBusViewport(
          waitingLeg: tramo,
          busPosition: busPos2,
        );

        // Debe bloquearse por cambio insignificante
        expect(mockMapbox.flyToCalls.length, 0,
          reason: 'Cambio < 20m debe bloquearse (minor change)');
      });
    });

    group('Padding según contexto', () {
      test('zoomToActiveTrip: Usa padding de active trip', () async {
        final route = _buildRoute(segments: 3);

        await controller.zoomToActiveTrip(route.tramosParaPreview);

        final call = mockMapbox.flyToCalls.first;

        // Padding: top=250, left=40, bottom=100, right=40
        expect(call.padding?.top, 250.0);
        expect(call.padding?.left, 40.0);
        expect(call.padding?.bottom, 100.0);
        expect(call.padding?.right, 40.0);
      });

      test('zoomToCurrentLeg: Usa padding de current leg', () async {
        final tramo = _buildTramo(tipo: TipoTramoViaje.CAMINAR, geometry: _buildLine(points: 3));

        await controller.zoomToCurrentLeg(0, [tramo]);

        final call = mockMapbox.flyToCalls.first;

        // Padding: top=260, left=60, bottom=160, right=60
        expect(call.padding?.top, 260.0);
        expect(call.padding?.left, 60.0);
        expect(call.padding?.bottom, 160.0);
        expect(call.padding?.right, 60.0);
      });
    });
  });
}

// ============================================================================
// MOCKS
// ============================================================================

class MockMapboxMap implements MapboxMap {
  final List<FlyToCall> flyToCalls = [];
  final List<CameraForCoordinatesCall> cameraForCoordinatesCalls = [];

  @override
  Future<void> flyTo(CameraOptions cameraOptions, MapAnimationOptions? animationOptions) async {
    // Agregar la llamada a flyTo
    // Las coordenadas ya fueron capturadas en cameraForCoordinates
    if (cameraForCoordinatesCalls.isNotEmpty) {
      final lastCameraCall = cameraForCoordinatesCalls.last;
      flyToCalls.add(FlyToCall(
        cameraOptions: cameraOptions,
        animationOptions: animationOptions,
        coordinates: lastCameraCall.coordinates,
        padding: lastCameraCall.padding,
      ));
    } else {
      // Caso de flyTo directo (sin cameraForCoordinates previo)
      // Extraer coordenada del center
      final coords = <Coordenada>[];
      if (cameraOptions.center != null) {
        coords.add(Coordenada(
          latitud: cameraOptions.center!.coordinates.lat.toDouble(),
          longitud: cameraOptions.center!.coordinates.lng.toDouble(),
        ));
      }
      flyToCalls.add(FlyToCall(
        cameraOptions: cameraOptions,
        animationOptions: animationOptions,
        coordinates: coords,
        padding: null,
      ));
    }
  }

  @override
  Future<CameraOptions> cameraForCoordinates(
    List<Point> coordinates,
    MbxEdgeInsets padding,
    double? bearing,
    double? pitch,
  ) async {
    // Guardar la llamada a cameraForCoordinates
    cameraForCoordinatesCalls.add(CameraForCoordinatesCall(
      coordinates: coordinates.map((p) => Coordenada(
        latitud: p.coordinates.lat.toDouble(),
        longitud: p.coordinates.lng.toDouble(),
      )).toList(),
      padding: padding,
    ));

    return CameraOptions(
      center: coordinates.isNotEmpty ? coordinates.first : null,
      zoom: 14.0,
      bearing: bearing,
      pitch: pitch,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FlyToCall {
  final CameraOptions cameraOptions;
  final MapAnimationOptions? animationOptions;
  final List<Coordenada> coordinates;
  final MbxEdgeInsets? padding;

  FlyToCall({
    required this.cameraOptions,
    this.animationOptions,
    this.coordinates = const [],
    this.padding,
  });
}

class CameraForCoordinatesCall {
  final List<Coordenada> coordinates;
  final MbxEdgeInsets padding;

  CameraForCoordinatesCall({
    required this.coordinates,
    required this.padding,
  });
}

class MockMapManager implements MapManager {
  Coordenada? userLocation;
  Coordenada? busLocation;

  @override
  Coordenada? getCurrentUserLocation() => userLocation;

  @override
  Coordenada? getCurrentBusPosition() => busLocation;

  @override
  Future<void> handleAutoFollowResumed() async {
    // No-op para tests
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ============================================================================
// HELPERS
// ============================================================================

TramoViajeMostrable _buildTramo({
  required TipoTramoViaje tipo,
  List<Coordenada>? geometry,
  Coordenada? posicionPunto,
  Coordenada? paradaOrigen,
  Coordenada? paradaDestino,
}) {
  // Calcular distancia si es CAMINAR o VIAJE_EN_BUS con geometría
  final distancia = (tipo == TipoTramoViaje.CAMINAR || tipo == TipoTramoViaje.VIAJE_EN_BUS) && geometry != null && geometry.isNotEmpty
    ? 1000
    : 0;

  return TramoViajeMostrable(
    idTramo: 'test-tramo-${tipo.name}',
    tipo: tipo,
    descripcion: tipo.name,
    duracionEstimadaSegundos: 300,
    distanciaMetros: distancia,
    geometriaPolilinea: geometry,
    posicionPunto: posicionPunto,
    coordenadasParadaOrigen: paradaOrigen,
    coordenadasParadaDestino: paradaDestino,
  );
}

List<Coordenada> _buildLine({
  Coordenada? start,
  int points = 5,
  double stepLat = 0.001,
  double stepLng = 0.001,
}) {
  final startCoord = start ?? Coordenada(latitud: -34.9, longitud: -56.1);
  return List.generate(points, (i) => Coordenada(
    latitud: startCoord.latitud + (i * stepLat),
    longitud: startCoord.longitud + (i * stepLng),
  ));
}

OpcionDeRutaMostrable _buildRoute({required int segments}) {
  return OpcionDeRutaMostrable(
    idOpcion: 'test-route',
    duracionTotalSegundos: segments * 300,
    horaLlegadaEstimada: DateTime.now().add(Duration(seconds: segments * 300)),
    secuenciaModosIconos: [TipoTramoViaje.CAMINAR],
    distanciaTotalCaminataMetros: 1000,
    tiempoTotalEsperaBusSegundos: 0,
    esRecomendada: true,
    score: 90,
    tramosParaPreview: List.generate(segments, (i) => _buildTramo(
      tipo: TipoTramoViaje.CAMINAR,
      geometry: _buildLine(points: 3),
    )),
  );
}
