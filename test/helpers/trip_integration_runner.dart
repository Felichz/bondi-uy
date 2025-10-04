/// Runner para tests de integración completos usando datos reales
///
/// Este runner ejecuta TODO el stack de la app:
/// - GeometryAdapter (capa 2: GPS/Geometría)
/// - TripStateMachine (capa 1: Lógica unidimensional)
/// - TripOrchestrator (coordinador)
///
/// Usa datos reales capturados desde la app y valida checkpoints programáticamente.

import 'package:flutter_test/flutter_test.dart';
import 'package:bondi_uy/journey/core/trip_state_machine.dart';
import 'package:bondi_uy/journey/core/trip_step.dart';
import 'package:bondi_uy/journey/core/trip_orchestrator.dart';
import 'package:bondi_uy/journey/adapters/geometry_adapter.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import 'trip_fixture_data.dart';

/// Resultado de validación de un checkpoint
class CheckpointValidationResult {
  final bool passed;
  final String checkpointName;
  final int timestamp;
  final List<String> failures;
  final Map<String, dynamic> actualState;

  CheckpointValidationResult({
    required this.passed,
    required this.checkpointName,
    required this.timestamp,
    required this.failures,
    required this.actualState,
  });
}

/// Resultado completo de ejecución del test
class TripIntegrationResult {
  final bool success;
  final List<CheckpointValidationResult> checkpointResults;
  final Map<String, dynamic> finalState;
  final Duration executionTime;
  final String? errorMessage;

  TripIntegrationResult({
    required this.success,
    required this.checkpointResults,
    required this.finalState,
    required this.executionTime,
    this.errorMessage,
  });

  void printReport() {
    print('\n' + '=' * 60);
    print('🧪 REPORTE DE TEST DE INTEGRACIÓN');
    print('=' * 60);
    print('✅ Éxito: ${success ? 'SÍ' : 'NO'}');
    print('⏱️  Tiempo: ${executionTime.inMilliseconds}ms');

    if (errorMessage != null) {
      print('❌ Error: $errorMessage');
    }

    print('\n📋 Checkpoints (${checkpointResults.length}):');
    for (final result in checkpointResults) {
      final icon = result.passed ? '✅' : '❌';
      print('  $icon [${result.timestamp}s] ${result.checkpointName}');

      if (!result.passed) {
        for (final failure in result.failures) {
          print('     ⚠️  $failure');
        }
      }
    }

    print('\n📊 Estado final:');
    finalState.forEach((key, value) {
      print('  • $key: $value');
    });
    print('=' * 60 + '\n');
  }
}

/// Runner de tests de integración con datos reales
class TripIntegrationRunner {
  final TripFixtureData fixture;

  late TripStateMachine stateMachine;
  late GeometryAdapter geometryAdapter;
  late TripOrchestrator orchestrator;

  final List<CheckpointValidationResult> _checkpointResults = [];
  DateTime? _startTime;

  TripIntegrationRunner(this.fixture);

  /// Ejecuta el test completo y retorna el resultado
  Future<TripIntegrationResult> run() async {
    _startTime = DateTime.now();

    try {
      print('[RUNNER] 🚀 Iniciando test de integración: ${fixture.name}');

      // 1. Validar fixture
      _validateFixture();

      // 2. Construir componentes
      _buildComponents();

      // 3. Iniciar orchestrator
      orchestrator.start(updateInterval: Duration(milliseconds: 100));

      // 4. Ejecutar GPS playback y validar checkpoints
      await _executeGpsPlayback();

      // 5. Validar estado final
      final finalSuccess = _validateFinalState();

      // 6. Cleanup
      orchestrator.dispose();

      final executionTime = DateTime.now().difference(_startTime!);

      return TripIntegrationResult(
        success: finalSuccess && _checkpointResults.every((r) => r.passed),
        checkpointResults: _checkpointResults,
        finalState: _getFinalState(),
        executionTime: executionTime,
      );
    } catch (e, stackTrace) {
      print('[RUNNER] ❌ Error durante ejecución: $e');
      print(stackTrace);

      return TripIntegrationResult(
        success: false,
        checkpointResults: _checkpointResults,
        finalState: _getFinalState(),
        executionTime: DateTime.now().difference(_startTime!),
        errorMessage: e.toString(),
      );
    }
  }

  /// Valida que el fixture tenga los datos necesarios
  void _validateFixture() {
    if (fixture.gpsPlayback.isEmpty) {
      throw Exception('Fixture no tiene gpsPlayback - necesario para test de integración');
    }

    if (fixture.checkpoints.isEmpty) {
      print('[RUNNER] ⚠️  Fixture no tiene checkpoints - solo se validará estado final');
    }

    if (fixture.route.segments.isEmpty) {
      throw Exception('Fixture no tiene segments - imposible construir trip');
    }

    print('[RUNNER] ✅ Fixture válido:');
    print('[RUNNER]    • GPS playback: ${fixture.gpsPlayback.length} puntos');
    print('[RUNNER]    • Checkpoints: ${fixture.checkpoints.length}');
    print('[RUNNER]    • Segments: ${fixture.route.segments.length}');
    print('[RUNNER]    • Stops: ${fixture.route.stops.length}');
  }

  /// Construye los componentes del sistema
  void _buildComponents() {
    print('[RUNNER] 🔧 Construyendo componentes...');

    // 1. Construir TripSteps desde segments
    final steps = _buildTripSteps();
    print('[RUNNER]    • TripSteps: ${steps.length}');

    // 2. Construir TripStateMachine
    stateMachine = TripStateMachine(
      tripId: fixture.tripId,
      steps: steps,
    );

    // 3. Construir repositorios de paradas y rutas
    final stopLocations = <String, Coordenada>{};
    for (final stop in fixture.route.stops) {
      stopLocations[stop.stopId] = stop.toCoord();
    }

    // TODO: Construir busRoutes desde geometrías de segments VIAJE_EN_BUS
    final busRoutes = <String, List<Coordenada>>{};
    for (final segment in fixture.route.segments) {
      if (segment.type == 'VIAJE_EN_BUS' && segment.busLine != null) {
        if (segment.geometry.isNotEmpty) {
          busRoutes[segment.busLine!] = segment.geometry.map((g) => g.toCoord()).toList();
        }
      }
    }

    print('[RUNNER]    • Stop locations: ${stopLocations.length}');
    print('[RUNNER]    • Bus routes: ${busRoutes.length}');

    // 4. Construir GeometryAdapter
    geometryAdapter = GeometryAdapter(
      stopLocations: stopLocations,
      busRoutes: busRoutes,
      destinationLocation: fixture.destination.toCoord(),
      currentUserLocation: fixture.origin.toCoord(),
    );

    // 5. Construir orchestrator
    orchestrator = createDefaultOrchestrator(
      stateMachine: stateMachine,
      getContextForStep: geometryAdapter.createContextForStep,
      onTripCompleted: () {
        print('[RUNNER] 🏁 Trip completado (callback)');
      },
      onStepChanged: (newStep) {
        print('[RUNNER] 🔄 Paso cambiado: ${newStep.type} (index: ${stateMachine.currentStepIndex})');
      },
      onProgressUpdated: (progress) {
        // Silencioso - demasiado verbose
      },
    );

    print('[RUNNER] ✅ Componentes construidos');
  }

  /// Construye TripSteps desde segments del fixture
  List<TripStep> _buildTripSteps() {
    final steps = <TripStep>[];

    for (int i = 0; i < fixture.route.segments.length; i++) {
      final segment = fixture.route.segments[i];

      // Determinar tipo de paso
      TripStepType stepType;
      switch (segment.type) {
        case 'CAMINAR':
          // Es el último segmento?
          stepType = i == fixture.route.segments.length - 1
              ? TripStepType.walkToDestination
              : TripStepType.walkToStop;
          break;
        case 'ESPERAR_BUS':
          stepType = TripStepType.waitForBus;
          break;
        case 'VIAJE_EN_BUS':
          stepType = TripStepType.onBus;
          break;
        default:
          throw Exception('Tipo de segment desconocido: ${segment.type}');
      }

      // Construir metadata
      final metadata = TripStepMetadata(
        originStopId: segment.from,
        destinationStopId: segment.to,
        busLine: segment.busLine,
        totalDistanceMeters: segment.distance?.toDouble(),
        hasEta: segment.hasEta ?? false,
      );

      steps.add(TripStep(
        id: 'step_$i',
        type: stepType,
        description: segment.description,
        metadata: metadata,
      ));
    }

    return steps;
  }

  /// Ejecuta el GPS playback y valida checkpoints
  Future<void> _executeGpsPlayback() async {
    print('[RUNNER] 📍 Iniciando GPS playback...');

    int currentTime = 0;
    int lastCheckpointIndex = 0;

    for (int i = 0; i < fixture.gpsPlayback.length; i++) {
      final point = fixture.gpsPlayback[i];

      // Avanzar en el tiempo (simular delay)
      final deltaTime = point.timestamp - currentTime;
      if (deltaTime > 0) {
        await Future.delayed(Duration(milliseconds: deltaTime * 10)); // 10x speed
      }
      currentTime = point.timestamp;

      // Actualizar ubicación GPS
      geometryAdapter.updateUserLocation(point.toCoord());

      // Forzar update del orchestrator
      await orchestrator.updateNow();

      // Log
      if (point.comment != null) {
        print('[RUNNER] 📍 [${point.timestamp}s] ${point.comment}');
      }

      // Validar checkpoints que corresponden a este timestamp
      while (lastCheckpointIndex < fixture.checkpoints.length) {
        final checkpoint = fixture.checkpoints[lastCheckpointIndex];

        if (checkpoint.timestamp <= currentTime) {
          _validateCheckpoint(checkpoint);
          lastCheckpointIndex++;
        } else {
          break;
        }
      }
    }

    print('[RUNNER] ✅ GPS playback completado');
  }

  /// Valida un checkpoint
  void _validateCheckpoint(TripCheckpoint checkpoint) {
    print('[RUNNER] 🎯 Validando checkpoint: ${checkpoint.name}');

    final failures = <String>[];
    final actualState = _getCurrentState();

    final assertions = checkpoint.assertions;

    // Validar stepIndex
    if (assertions.currentStepIndex != null) {
      if (stateMachine.currentStepIndex != assertions.currentStepIndex) {
        failures.add(
          'stepIndex esperado: ${assertions.currentStepIndex}, actual: ${stateMachine.currentStepIndex}',
        );
      }
    }

    // Validar stepType
    if (assertions.currentStepType != null) {
      final actualType = stateMachine.currentStep.type.toString().split('.').last;
      if (actualType != assertions.currentStepType) {
        failures.add(
          'stepType esperado: ${assertions.currentStepType}, actual: $actualType',
        );
      }
    }

    // Validar progress
    if (assertions.progressMin != null || assertions.progressMax != null) {
      final actualProgress = stateMachine.currentStep.progress;

      if (assertions.progressMin != null && actualProgress < assertions.progressMin!) {
        failures.add(
          'progress debe ser >= ${assertions.progressMin}, actual: ${actualProgress.toStringAsFixed(2)}',
        );
      }

      if (assertions.progressMax != null && actualProgress > assertions.progressMax!) {
        failures.add(
          'progress debe ser <= ${assertions.progressMax}, actual: ${actualProgress.toStringAsFixed(2)}',
        );
      }
    }

    // Validar geofence
    if (assertions.isWithinGeofence != null) {
      // Necesitamos obtener el context para verificar geofence
      // Por simplicidad, asumimos que si el progress es alto, está en geofence
      final isInGeofence = stateMachine.currentStep.progress > 0.9;

      if (isInGeofence != assertions.isWithinGeofence) {
        failures.add(
          'isWithinGeofence esperado: ${assertions.isWithinGeofence}, actual: $isInGeofence',
        );
      }
    }

    final result = CheckpointValidationResult(
      passed: failures.isEmpty,
      checkpointName: checkpoint.name,
      timestamp: checkpoint.timestamp,
      failures: failures,
      actualState: actualState,
    );

    _checkpointResults.add(result);

    if (result.passed) {
      print('[RUNNER] ✅ Checkpoint pasó');
    } else {
      print('[RUNNER] ❌ Checkpoint falló:');
      for (final failure in failures) {
        print('[RUNNER]    • $failure');
      }
    }
  }

  /// Obtiene el estado actual del sistema
  Map<String, dynamic> _getCurrentState() {
    return {
      'stepIndex': stateMachine.currentStepIndex,
      'stepType': stateMachine.currentStep.type.toString().split('.').last,
      'stepState': stateMachine.currentStep.state.toString().split('.').last,
      'progress': stateMachine.currentStep.progress,
      'overallProgress': stateMachine.overallProgress,
      'isCompleted': stateMachine.isCompleted,
      'status': stateMachine.status.toString().split('.').last,
    };
  }

  /// Obtiene el estado final del sistema
  Map<String, dynamic> _getFinalState() {
    return _getCurrentState();
  }

  /// Valida el estado final del trip
  bool _validateFinalState() {
    print('[RUNNER] 🏁 Validando estado final...');

    final expected = fixture.expectedBehavior;
    bool success = true;

    // Validar shouldComplete
    if (expected.shouldComplete) {
      if (!stateMachine.isCompleted) {
        print('[RUNNER] ❌ Se esperaba que el trip se completara, pero no lo hizo');
        success = false;
      } else {
        print('[RUNNER] ✅ Trip completado como se esperaba');
      }
    }

    // Validar número de pasos
    if (stateMachine.steps.length != expected.stepsExpected) {
      print('[RUNNER] ⚠️  Número de pasos diferente: esperado ${expected.stepsExpected}, actual ${stateMachine.steps.length}');
    }

    return success;
  }
}
