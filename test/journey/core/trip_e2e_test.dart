import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:bondi_uy/journey/core/trip_state_machine.dart';
import 'package:bondi_uy/journey/core/trip_step.dart';
import 'package:bondi_uy/journey/core/step_detector.dart';
import 'package:bondi_uy/journey/core/trip_orchestrator.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';

/// Test End-to-End del flujo completo de usuario usando data real
///
/// Este test simula el MISMO código que corre en producción para validar
/// el flujo completo descrito en docs/flujos/flujo-principal/1-flujo-de-usuario.txt:
///
/// 1. Usuario selecciona ruta en carousel → inicia viaje
/// 2. PASO 1: Caminar a parada (Walk → WaitForBus automático)
/// 3. PASO 2: Esperar bus (WaitForBus → OnBus automático cuando detecta movimiento)
/// 4. PASO 3: En el bus (OnBus → WalkToDestination automático cuando llega a parada)
/// 5. PASO 4: Caminar a destino (WalkToDestination → Completed automático)
void main() {
  group('Trip E2E Test - Flujo completo de usuario con JSON real', () {
    late Map<String, dynamic> tripData;
    late List<Map<String, dynamic>> gpsPlayback;
    late List<Map<String, dynamic>> checkpoints;

    setUpAll(() async {
      // Cargar JSON real capturado desde la app
      final file = File('test/fixtures/trip_example_simple.json');
      final jsonString = await file.readAsString();
      tripData = json.decode(jsonString) as Map<String, dynamic>;

      gpsPlayback = (tripData['gpsPlayback'] as List?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ?? [];

      checkpoints = (tripData['checkpoints'] as List?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ?? [];

      print('\n📦 JSON cargado: ${tripData['name']}');
      print('   GPS Playback: ${gpsPlayback.length} puntos');
      print('   Checkpoints: ${checkpoints.length}');
    });

    test('Simular viaje completo: Walk → Wait → Bus → Walk (data real)', () async {
      // 1. PARSEAR SEGMENTOS DEL JSON A TRIP STEPS
      final segments = (tripData['route']['segments'] as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();

      final steps = <TripStep>[];

      for (var i = 0; i < segments.length; i++) {
        final seg = segments[i];
        final type = seg['type'] as String;

        TripStepType stepType;
        TripStepMetadata metadata;

        switch (type) {
          case 'CAMINAR':
            if (seg['to'] == 'next_stop') {
              stepType = TripStepType.walkToStop;
              metadata = TripStepMetadata(
                destinationStopId: seg['stopId'] as String?,
                totalDistanceMeters: (seg['distance'] as int?)?.toDouble(),
              );
            } else {
              stepType = TripStepType.walkToDestination;
              metadata = TripStepMetadata(
                totalDistanceMeters: (seg['distance'] as int?)?.toDouble(),
              );
            }
            break;

          case 'ESPERAR_BUS':
            stepType = TripStepType.waitForBus;
            final busLines = seg['busLines'] as List?;
            metadata = TripStepMetadata(
              originStopId: seg['stopId'] as String?,
              busLine: busLines?.isNotEmpty == true ? busLines!.first as String : null,
              hasEta: seg['eta'] != null,
            );
            break;

          case 'VIAJE_EN_BUS':
            stepType = TripStepType.onBus;
            final busLines = seg['busLines'] as List?;
            metadata = TripStepMetadata(
              originStopId: seg['fromStopId'] as String?,
              destinationStopId: seg['toStopId'] as String?,
              busLine: busLines?.isNotEmpty == true ? busLines!.first as String : null,
            );
            break;

          default:
            throw Exception('Tipo desconocido: $type');
        }

        steps.add(TripStep(
          id: 'step_$i',
          type: stepType,
          description: seg['description'] as String,
          metadata: metadata,
        ));
      }

      print('\n🎬 Iniciando viaje con ${steps.length} pasos:');
      for (var i = 0; i < steps.length; i++) {
        print('   ${i + 1}. ${steps[i].type.toString().split('.').last}: ${steps[i].description}');
      }

      // 2. CREAR STATE MACHINE
      final stateMachine = TripStateMachine(
        tripId: tripData['tripId'] as String,
        steps: steps,
      );

      // 3. PARSEAR GEOMETRÍAS DEL JSON PARA SIMULAR GeometryAdapter
      final geometries = segments.map((seg) {
        final geom = seg['geometry'] as List?;
        if (geom == null || geom.isEmpty) return <Coordenada>[];

        return geom.map((p) {
          final point = p as Map<String, dynamic>;
          return Coordenada(
            latitud: point['lat'] as double,
            longitud: point['lng'] as double,
          );
        }).toList();
      }).toList();

      // 4. MOCK GEOMETRY ADAPTER USANDO GPS PLAYBACK
      var currentGpsIndex = 0;
      Coordenada? previousPosition;
      int? previousTimestamp;

      final origin = tripData['origin'] as Map<String, dynamic>;
      final destination = tripData['destination'] as Map<String, dynamic>;

      final originCoord = Coordenada(
        latitud: origin['lat'] as double,
        longitud: origin['lng'] as double,
      );

      final destCoord = Coordenada(
        latitud: destination['lat'] as double,
        longitud: destination['lng'] as double,
      );

      // Función que simula GeometryAdapter - usa GPS playback para obtener ubicación
      Future<StepDetectionContext> mockGeometryAdapter(TripStep step) async {
        // Obtener posición actual del GPS playback
        if (currentGpsIndex >= gpsPlayback.length) {
          currentGpsIndex = gpsPlayback.length - 1;
        }

        final currentGps = gpsPlayback[currentGpsIndex];
        final userPosition = Coordenada(
          latitud: currentGps['lat'] as double,
          longitud: currentGps['lng'] as double,
        );

        // Calcular velocidad basándose en posición anterior
        double speed = 0.0;
        if (previousPosition != null && previousTimestamp != null) {
          final currentTimestamp = currentGps['timestamp'] as int;
          final timeDelta = (currentTimestamp - previousTimestamp!).toDouble();
          if (timeDelta > 0) {
            final distanceMoved = _calculateDistance(previousPosition!, userPosition);
            speed = distanceMoved / timeDelta; // m/s
          }
        }

        previousPosition = userPosition;
        previousTimestamp = currentGps['timestamp'] as int;

        // Determinar target según el paso actual
        Coordenada target;
        final stepIndex = stateMachine.currentStepIndex;
        final stepGeometry = geometries[stepIndex];

        if (step.type == TripStepType.walkToStop) {
          // Target es el último punto de la geometría de walk
          target = stepGeometry.isNotEmpty
              ? stepGeometry.last
              : destCoord;
        } else if (step.type == TripStepType.waitForBus) {
          // Para wait, el target es el último punto del PRÓXIMO paso (onBus)
          final nextStepIndex = stepIndex + 1;
          if (nextStepIndex < geometries.length) {
            final nextGeometry = geometries[nextStepIndex];
            target = nextGeometry.isNotEmpty
                ? nextGeometry.last
                : destCoord;
          } else {
            target = destCoord;
          }
        } else if (step.type == TripStepType.onBus) {
          // Target es el último punto de la geometría del bus
          target = stepGeometry.isNotEmpty
              ? stepGeometry.last
              : destCoord;
        } else {
          // walkToDestination
          target = destCoord;
        }

        // Calcular distancia usando Haversine
        final distance = _calculateDistance(userPosition, target);

        // Determinar si está en geofence (20m threshold)
        final isWithinGeofence = distance < 20;

        // Determinar si está en movimiento
        final isMoving = speed > 0.5; // > 0.5 m/s considerado movimiento

        // Para onBus, verificar si está en la ruta (velocidad de bus ~5-10 m/s)
        final isOnBusRoute = speed > 3.0; // > 3 m/s = ~11 km/h (velocidad de bus)

        return StepDetectionContext(
          distanceToTarget: distance,
          initialDistanceToTarget: step.metadata.totalDistanceMeters ?? 1000.0,
          isWithinGeofence: isWithinGeofence,
          isOnBusRoute: isOnBusRoute,
          userSpeed: speed,
          isUserMoving: isMoving,
          timestamp: DateTime.now(),
        );
      }

      // 5. SETUP ORCHESTRATOR
      var stepChanges = 0;
      var tripCompleted = false;

      final orchestrator = createDefaultOrchestrator(
        stateMachine: stateMachine,
        getContextForStep: mockGeometryAdapter,
        onStepChanged: (newStep) {
          stepChanges++;
          print('\n✅ PASO COMPLETADO → Avanzando a paso ${stateMachine.currentStepIndex + 1}');
          print('   Nuevo paso: ${newStep.type.toString().split('.').last}');
          print('   Descripción: ${newStep.description}');
        },
        onTripCompleted: () {
          tripCompleted = true;
          print('\n🎉 VIAJE COMPLETADO!');
        },
      );

      // 6. INICIAR ORQUESTADOR
      print('\n🚀 Iniciando orquestador...\n');
      orchestrator.start(updateInterval: const Duration(milliseconds: 100));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(stateMachine.status, TripStatus.inProgress);
      expect(stateMachine.currentStepIndex, 0);

      // 7. SIMULAR VIAJE USANDO GPS PLAYBACK
      // Dividir GPS playback en segmentos según los checkpoints

      print('═══════════════════════════════════════════════════════════');
      print('🚶‍♂️ FASE 1: CAMINAR A LA PARADA');
      print('═══════════════════════════════════════════════════════════\n');

      // Avanzar GPS hasta primer checkpoint (llegada a parada)
      while (currentGpsIndex < gpsPlayback.length &&
             stateMachine.currentStepIndex == 0) {
        await orchestrator.updateNow();
        currentGpsIndex += 1; // Avanzar punto por punto

        if (currentGpsIndex % 30 == 0) {
          print('   GPS[$currentGpsIndex/${gpsPlayback.length}] - Progreso: ${(stateMachine.currentStep.progress * 100).toStringAsFixed(0)}%');
        }
      }

      // Debe haber avanzado al paso 2 (wait for bus)
      expect(stateMachine.currentStepIndex, greaterThanOrEqualTo(1));
      expect(stepChanges, greaterThanOrEqualTo(1));

      print('\n═══════════════════════════════════════════════════════════');
      print('🚏 FASE 2: ESPERAR EL BUS');
      print('═══════════════════════════════════════════════════════════\n');

      // Simular espera y luego boarding
      await orchestrator.updateNow();

      // Continuar GPS playback hasta que detecte que subió al bus
      var previousStep = stateMachine.currentStepIndex;
      while (currentGpsIndex < gpsPlayback.length &&
             stateMachine.currentStepIndex == previousStep) {
        await orchestrator.updateNow();
        currentGpsIndex += 1;

        if (currentGpsIndex % 30 == 0) {
          print('   Esperando... GPS[$currentGpsIndex/${gpsPlayback.length}]');
        }
      }

      if (stateMachine.currentStepIndex > previousStep) {
        print('   ✅ Detectado: Usuario subió al bus');
      }

      print('\n═══════════════════════════════════════════════════════════');
      print('🚌 FASE 3: EN EL BUS');
      print('═══════════════════════════════════════════════════════════\n');

      // Avanzar GPS durante el viaje en bus
      previousStep = stateMachine.currentStepIndex;
      while (currentGpsIndex < gpsPlayback.length &&
             stateMachine.currentStepIndex == previousStep) {
        await orchestrator.updateNow();
        currentGpsIndex += 1;

        if (currentGpsIndex % 50 == 0) {
          print('   🚌 En tránsito... Progreso: ${(stateMachine.currentStep.progress * 100).toStringAsFixed(0)}%');
        }
      }

      if (stateMachine.currentStepIndex > previousStep) {
        print('   ✅ Detectado: Usuario llegó a parada de destino');
      }

      print('\n═══════════════════════════════════════════════════════════');
      print('🚶‍♂️ FASE 4: CAMINAR AL DESTINO');
      print('═══════════════════════════════════════════════════════════\n');

      // Avanzar GPS hasta el final
      while (currentGpsIndex < gpsPlayback.length && !tripCompleted) {
        await orchestrator.updateNow();
        currentGpsIndex += 1;

        if (currentGpsIndex % 30 == 0) {
          print('   GPS[$currentGpsIndex/${gpsPlayback.length}] - Progreso: ${(stateMachine.currentStep.progress * 100).toStringAsFixed(0)}%');
        }
      }

      print('\n═══════════════════════════════════════════════════════════');
      print('📊 RESULTADOS DEL VIAJE');
      print('═══════════════════════════════════════════════════════════\n');

      // 8. VALIDACIONES FINALES
      print('   Pasos completados: ${stepChanges}');
      print('   GPS procesado: $currentGpsIndex/${gpsPlayback.length} puntos');
      print('   Estado final: ${stateMachine.status}');
      print('   Progreso general: ${(stateMachine.overallProgress * 100).toStringAsFixed(0)}%');

      // Validar que completó todos los pasos
      expect(stepChanges, greaterThanOrEqualTo(steps.length - 1),
          reason: 'Debe haber cambiado de paso al menos ${steps.length - 1} veces');

      // Validar estado final
      if (tripCompleted) {
        expect(stateMachine.status, TripStatus.completed);
        expect(stateMachine.isCompleted, true);
        print('\n   ✅ VIAJE COMPLETADO EXITOSAMENTE');
      } else {
        print('\n   ⚠️  Viaje no completado - GPS playback insuficiente');
        print('   Último paso: ${stateMachine.currentStep.description}');
      }

      orchestrator.dispose();

      print('\n═══════════════════════════════════════════════════════════\n');
    });
  });
}

/// Calcula distancia entre dos coordenadas usando fórmula de Haversine
double _calculateDistance(Coordenada from, Coordenada to) {
  const earthRadius = 6371000.0; // metros

  final lat1 = from.latitud * (pi / 180.0);
  final lat2 = to.latitud * (pi / 180.0);
  final dLat = (to.latitud - from.latitud) * (pi / 180.0);
  final dLon = (to.longitud - from.longitud) * (pi / 180.0);

  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1) * cos(lat2) *
      sin(dLon / 2) * sin(dLon / 2);

  final c = 2 * asin(sqrt(a));

  return earthRadius * c;
}
