import 'package:flutter_test/flutter_test.dart';
import 'package:bondi_uy/journey/journey_manager.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';

/// Test de integración: JourneyManager + TripOrchestrator
///
/// Este test valida que la integración entre JourneyManager y TripOrchestrator
/// funciona correctamente, específicamente:
///
/// 1. TripOrchestrator detecta transiciones de pasos
/// 2. JourneyManager sincroniza índices correctamente (NO incrementa, sino que usa el índice del orchestrator)
/// 3. NO se saltan pasos en la secuencia
/// 4. Eventos correctos son emitidos
///
/// ESTE TEST HABRÍA DETECTADO EL BUG: donde JourneyManager llamaba a
/// _transitionToNextStep() en lugar de sincronizar al índice del orchestrator,
/// causando que saltara pasos.
void main() {
  group('JourneyManager + TripOrchestrator Integration', () {
    test('Debe sincronizar índices correctamente sin saltar pasos', () async {
      // NOTA: Este test valida el BUG CRÍTICO donde JourneyManager saltaba pasos
      // al llamar _transitionToNextStep() en vez de sincronizar al índice del orchestrator
      // 1. SETUP: Crear tramos simulados (4 pasos típicos)
      final tramos = [
        TramoViajeMostrable(
          idTramo: 'tramo_0',
          tipo: TipoTramoViaje.CAMINAR,
          descripcion: 'Caminar a parada 1',
          geometriaPolilinea: [
            Coordenada(latitud: -34.9025, longitud: -56.1283),
            Coordenada(latitud: -34.9044, longitud: -56.1294),
          ],
          duracionEstimadaSegundos: 240,
          distanciaMetros: 300,
          nombreParadaDestino: 'Parada 1',
          coordenadasParadaDestino: Coordenada(latitud: -34.9044, longitud: -56.1294),
          idParadaDestinoTramoBus: 'stop1',
        ),
        TramoViajeMostrable(
          idTramo: 'tramo_1',
          tipo: TipoTramoViaje.ESPERAR_BUS,
          descripcion: 'Esperar bus línea 60',
          posicionPunto: Coordenada(latitud: -34.9044, longitud: -56.1294),
          duracionEstimadaSegundos: 300,
          distanciaMetros: 0,
          nombreLineaBus: '60',
          esTiempoRealBus: true,
          nombreParadaOrigen: 'Parada 1',
          coordenadasParadaOrigen: Coordenada(latitud: -34.9044, longitud: -56.1294),
          idParadaOrigenTramoBus: 'stop1',
        ),
        TramoViajeMostrable(
          idTramo: 'tramo_2',
          tipo: TipoTramoViaje.VIAJE_EN_BUS,
          descripcion: 'Viaje en bus 60 a Parada 2',
          geometriaPolilinea: [
            Coordenada(latitud: -34.9044, longitud: -56.1294),
            Coordenada(latitud: -34.9063, longitud: -56.2010),
          ],
          duracionEstimadaSegundos: 600,
          distanciaMetros: 5000,
          nombreLineaBus: '60',
          esTiempoRealBus: true,
          nombreParadaOrigen: 'Parada 1',
          coordenadasParadaOrigen: Coordenada(latitud: -34.9044, longitud: -56.1294),
          idParadaOrigenTramoBus: 'stop1',
          nombreParadaDestino: 'Parada 2',
          coordenadasParadaDestino: Coordenada(latitud: -34.9063, longitud: -56.2010),
          idParadaDestinoTramoBus: 'stop2',
        ),
        TramoViajeMostrable(
          idTramo: 'tramo_3',
          tipo: TipoTramoViaje.CAMINAR,
          descripcion: 'Caminar a destino final',
          geometriaPolilinea: [
            Coordenada(latitud: -34.9063, longitud: -56.2010),
            Coordenada(latitud: -34.9070, longitud: -56.1995),
          ],
          duracionEstimadaSegundos: 120,
          distanciaMetros: 150,
        ),
      ];

      // 2. Capturar eventos emitidos por JourneyManager
      final events = <JourneyEvent>[];

      final journeyManager = JourneyManager(
        tramos: tramos,
        onEvent: (event) {
          events.add(event);
          print('[TEST] 📡 Event: ${event.type}');
          if (event.type == JourneyEventType.STEP_TRANSITIONED) {
            print('[TEST]    Previous: ${event.data?['previousIndex']}, New: ${event.data?['newIndex']}');
          }
        },
        isTestMode: true,
      );

      // 3. Inicializar JourneyManager (esto crea el orchestrator internamente)
      print('\n[TEST] 🚀 Inicializando JourneyManager...');

      await journeyManager.initialize();

      await Future.delayed(const Duration(milliseconds: 100));

      print('\n[TEST] ═══════════════════════════════════════════════════════');
      print('[TEST] 🚶‍♂️ FASE 1: CAMINAR A LA PARADA');
      print('[TEST] ═══════════════════════════════════════════════════════\n');

      // 4. FASE 1: Simular llegada a la parada
      // Inyectar ubicación cerca de la parada
      journeyManager.injectLocationUpdate(
        Coordenada(latitud: -34.9044, longitud: -56.1294), // En la parada
      );

      await Future.delayed(const Duration(milliseconds: 300));

      // El orchestrator debería detectar llegada y avanzar a paso 1 (WAITING_FOR_BUS)
      final transitionsAfterPhase1 = events.where((e) => e.type == JourneyEventType.STEP_TRANSITIONED).toList();

      // VALIDACIÓN CRÍTICA: Debe haber exactamente 1 transición (0 → 1)
      expect(
        transitionsAfterPhase1.length,
        1,
        reason: 'Debe haber 1 transición después de fase 1',
      );

      expect(transitionsAfterPhase1[0].data?['previousIndex'], 0);
      expect(transitionsAfterPhase1[0].data?['newIndex'], 1,
          reason: 'Debe avanzar a paso 1 (WAITING_FOR_BUS), no saltar al 2');

      print('\n[TEST] ═══════════════════════════════════════════════════════');
      print('[TEST] 🚏 FASE 2: ESPERAR EL BUS');
      print('[TEST] ═══════════════════════════════════════════════════════\n');

      // 5. FASE 2: (Opcional - verificación adicional si hay más transiciones)
      // En un sistema en vivo, aquí se simularía subida al bus
      // Para este test, lo importante es validar que la primera transición (0→1) fue correcta

      // Las fases 3 y 4 se saltean para simplificar el test
      // Lo importante es que la transición 0→1 fue correcta (sin saltos)

      print('\n[TEST] ═══════════════════════════════════════════════════════');
      print('[TEST] 📊 VALIDANDO SECUENCIA DE TRANSICIONES');
      print('[TEST] ═══════════════════════════════════════════════════════\n');

      // 8. VALIDACIÓN CRÍTICA: Verificar secuencia de transiciones
      final transitions = events
          .where((e) => e.type == JourneyEventType.STEP_TRANSITIONED)
          .toList();

      print('[TEST] Total de transiciones: ${transitions.length}');

      // VALIDACIÓN PRINCIPAL: Debe haber AL MENOS 1 transición (0→1)
      expect(transitions.length, greaterThanOrEqualTo(1),
          reason: 'Debe haber al menos 1 transición de paso');

      // Validar primera transición (la más crítica)
      expect(transitions[0].data?['previousIndex'], 0);
      expect(transitions[0].data?['newIndex'], 1,
          reason: '🚨 BUG: Primera transición debe ser 0→1, no 0→2 (saltando paso)');

      // VALIDACIÓN MÁS IMPORTANTE: NO debe saltar pasos
      // ESTE ES EL TEST QUE HABRÍA DETECTADO EL BUG
      print('[TEST] Validando ${transitions.length} transiciones...');

      for (int i = 0; i < transitions.length; i++) {
        final prevIndex = transitions[i].data?['previousIndex'] as int;
        final newIndex = transitions[i].data?['newIndex'] as int;

        print('[TEST] ✅ Transición $i: $prevIndex → $newIndex');

        expect(
          newIndex,
          prevIndex + 1,
          reason: '🚨 BUG DETECTADO: Transición $i saltó pasos! Debe ser $prevIndex → ${prevIndex + 1}, pero fue $prevIndex → $newIndex',
        );
      }

      print('[TEST] ✅ TODAS las transiciones son consecutivas - NO hay saltos de pasos');

      print('\n[TEST] ═══════════════════════════════════════════════════════');
      print('[TEST] ✅ TEST COMPLETADO EXITOSAMENTE');
      print('[TEST] ═══════════════════════════════════════════════════════\n');

      journeyManager.stop();
    });

    test('Debe manejar viaje simple (solo caminar) sin saltar', () async {
      // Viaje con solo 1 paso: caminar directo al destino
      final tramos = [
        TramoViajeMostrable(
          idTramo: 'tramo_0',
          tipo: TipoTramoViaje.CAMINAR,
          descripcion: 'Caminar directo al destino',
          geometriaPolilinea: [
            Coordenada(latitud: -34.9025, longitud: -56.1283),
            Coordenada(latitud: -34.9070, longitud: -56.1995),
          ],
          duracionEstimadaSegundos: 400,
          distanciaMetros: 500,
        ),
      ];

      final events = <JourneyEvent>[];

      final journeyManager = JourneyManager(
        tramos: tramos,
        onEvent: events.add,
        isTestMode: true,
      );

      await journeyManager.initialize();

      // Simular llegada al destino
      journeyManager.injectLocationUpdate(
        Coordenada(latitud: -34.9070, longitud: -56.1995),
      );

      await Future.delayed(const Duration(milliseconds: 300));

      // No debe haber transiciones (solo 1 paso)
      final transitions = events.where((e) => e.type == JourneyEventType.STEP_TRANSITIONED).toList();
      expect(transitions.length, 0, reason: 'Viaje de 1 paso no tiene transiciones');

      // Debe completar
      final completed = events.where((e) => e.type == JourneyEventType.JOURNEY_COMPLETED).toList();
      expect(completed.length, greaterThanOrEqualTo(1));

      journeyManager.stop();
    });

    test('Debe validar eventos emitidos en orden correcto', () async {
      final tramos = [
        TramoViajeMostrable(
          idTramo: 'tramo_0',
          tipo: TipoTramoViaje.CAMINAR,
          descripcion: 'Caminar a parada',
          geometriaPolilinea: [
            Coordenada(latitud: -34.9025, longitud: -56.1283),
            Coordenada(latitud: -34.9044, longitud: -56.1294),
          ],
          duracionEstimadaSegundos: 200,
          distanciaMetros: 250,
          coordenadasParadaDestino: Coordenada(latitud: -34.9044, longitud: -56.1294),
        ),
        TramoViajeMostrable(
          idTramo: 'tramo_1',
          tipo: TipoTramoViaje.ESPERAR_BUS,
          descripcion: 'Esperar bus',
          posicionPunto: Coordenada(latitud: -34.9044, longitud: -56.1294),
          duracionEstimadaSegundos: 180,
          nombreLineaBus: '60',
        ),
      ];

      final eventTypes = <JourneyEventType>[];

      final journeyManager = JourneyManager(
        tramos: tramos,
        onEvent: (event) => eventTypes.add(event.type),
        isTestMode: true,
      );

      await journeyManager.initialize();
      await Future.delayed(const Duration(milliseconds: 100));

      // Simular llegada a parada
      journeyManager.injectLocationUpdate(
        Coordenada(latitud: -34.9044, longitud: -56.1294),
      );

      await Future.delayed(const Duration(milliseconds: 300));

      // Validar que LOCATION_UPDATED viene antes de STEP_TRANSITIONED
      final locationIndex = eventTypes.indexOf(JourneyEventType.LOCATION_UPDATED);
      final transitionIndex = eventTypes.indexOf(JourneyEventType.STEP_TRANSITIONED);

      expect(locationIndex, greaterThanOrEqualTo(0), reason: 'Debe haber evento LOCATION_UPDATED');
      expect(transitionIndex, greaterThan(locationIndex),
          reason: 'STEP_TRANSITIONED debe venir después de LOCATION_UPDATED');

      journeyManager.stop();
    });
  });
}
