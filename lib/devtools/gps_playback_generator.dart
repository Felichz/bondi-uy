/// Generador sintético de GPS playback para testing
///
/// Este generador toma las geometrías de una ruta capturada y genera
/// una secuencia de puntos GPS simulados que representan cómo se movería
/// un usuario durante el viaje.
///
/// NO requiere grabar un viaje real - todo se calcula desde las geometrías.

import 'dart:math' as math;
import '../backend/contrato_ui/app_ui_state.dart';

class GpsPlaybackGenerator {
  /// Genera GPS playback completo desde una ruta
  ///
  /// Retorna una lista de puntos GPS con timestamps en segundos.
  static List<Map<String, dynamic>> generateFromRoute({
    required Coordenada origin,
    required Coordenada destination,
    required List<TramoViajeMostrable> tramos,
    double speedMultiplier = 1.0, // Para acelerar/ralentizar simulación
  }) {
    final playback = <Map<String, dynamic>>[];
    int currentTime = 0;

    print('[GPSGenerator] 🎬 Generando GPS playback para ${tramos.length} tramos');

    for (int i = 0; i < tramos.length; i++) {
      final tramo = tramos[i];
      print('[GPSGenerator] 📍 Tramo ${i + 1}/${tramos.length}: ${tramo.tipo.name}');

      switch (tramo.tipo) {
        case TipoTramoViaje.CAMINAR:
          final points = _generateWalkingPoints(
            tramo: tramo,
            startTime: currentTime,
            speedMultiplier: speedMultiplier,
          );
          playback.addAll(points);
          if (points.isNotEmpty) {
            currentTime = points.last['timestamp'] as int;
          }
          print('[GPSGenerator]    ✅ ${points.length} puntos generados (${points.length > 0 ? points.last['timestamp'] - points.first['timestamp'] : 0}s)');
          break;

        case TipoTramoViaje.ESPERAR_BUS:
          final points = _generateWaitingPoints(
            tramo: tramo,
            startTime: currentTime,
            speedMultiplier: speedMultiplier,
          );
          playback.addAll(points);
          if (points.isNotEmpty) {
            currentTime = points.last['timestamp'] as int;
          }
          print('[GPSGenerator]    ✅ ${points.length} puntos generados (esperando)');
          break;

        case TipoTramoViaje.VIAJE_EN_BUS:
          final points = _generateBusRidePoints(
            tramo: tramo,
            startTime: currentTime,
            speedMultiplier: speedMultiplier,
          );
          playback.addAll(points);
          if (points.isNotEmpty) {
            currentTime = points.last['timestamp'] as int;
          }
          print('[GPSGenerator]    ✅ ${points.length} puntos generados (${points.length > 0 ? points.last['timestamp'] - points.first['timestamp'] : 0}s)');
          break;
      }
    }

    print('[GPSGenerator] 🎉 GPS playback generado: ${playback.length} puntos totales, ${currentTime}s duración');

    return playback;
  }

  /// Genera puntos GPS para caminar
  static List<Map<String, dynamic>> _generateWalkingPoints({
    required TramoViajeMostrable tramo,
    required int startTime,
    required double speedMultiplier,
  }) {
    final points = <Map<String, dynamic>>[];

    // Si no hay geometría, generar línea recta desde punto inicial al final
    final geometry = tramo.geometriaPolilinea;
    if (geometry == null || geometry.isEmpty) {
      print('[GPSGenerator]    ⚠️  Sin geometría - generando línea recta');
      return points;
    }

    // Velocidad de caminata: ~1.4 m/s (5 km/h)
    const walkingSpeed = 1.4; // metros por segundo
    final adjustedSpeed = walkingSpeed * speedMultiplier;

    // Intervalo de muestreo: cada 2 segundos
    const samplingInterval = 2.0; // segundos

    // Interpolar puntos a lo largo de la geometría
    int currentTime = startTime;
    double distanceCovered = 0.0;

    // Agregar punto inicial
    points.add({
      'timestamp': currentTime,
      'lat': geometry.first.latitud,
      'lng': geometry.first.longitud,
      'comment': 'Inicio: ${tramo.descripcion}',
    });

    // Calcular distancia total
    double totalDistance = 0.0;
    for (int i = 0; i < geometry.length - 1; i++) {
      totalDistance += _distance(geometry[i], geometry[i + 1]);
    }

    // Generar puntos intermedios
    while (distanceCovered < totalDistance) {
      distanceCovered += adjustedSpeed * samplingInterval;

      if (distanceCovered >= totalDistance) {
        // Último punto
        currentTime += samplingInterval.round();
        points.add({
          'timestamp': currentTime,
          'lat': geometry.last.latitud,
          'lng': geometry.last.longitud,
          'comment': 'Llegada: ${tramo.descripcion}',
        });
        break;
      }

      // Encontrar punto en la geometría a esta distancia
      final point = _pointAtDistance(geometry, distanceCovered);
      currentTime += samplingInterval.round();

      points.add({
        'timestamp': currentTime,
        'lat': point.latitud,
        'lng': point.longitud,
      });
    }

    return points;
  }

  /// Genera puntos GPS para esperar el bus (usuario estático)
  static List<Map<String, dynamic>> _generateWaitingPoints({
    required TramoViajeMostrable tramo,
    required int startTime,
    required double speedMultiplier,
  }) {
    final points = <Map<String, dynamic>>[];

    // Posición de la parada
    final position = tramo.posicionPunto ?? tramo.coordenadasParadaOrigen;
    if (position == null) {
      print('[GPSGenerator]    ⚠️  Sin posición de parada');
      return points;
    }

    // Duración de espera (ajustada por speed multiplier)
    final waitDuration = (tramo.duracionEstimadaSegundos ?? 300) ~/ speedMultiplier;

    // Generar puntos cada 5 segundos (usuario no se mueve)
    int currentTime = startTime;

    // Punto inicial
    points.add({
      'timestamp': currentTime,
      'lat': position.latitud,
      'lng': position.longitud,
      'comment': 'Esperando bus: ${tramo.nombreLineaBus ?? ""}',
    });

    // Puntos intermedios (cada 5s)
    for (int t = 5; t < waitDuration; t += 5) {
      points.add({
        'timestamp': startTime + t,
        'lat': position.latitud,
        'lng': position.longitud,
      });
    }

    // Punto final
    if (waitDuration > 0) {
      points.add({
        'timestamp': startTime + waitDuration,
        'lat': position.latitud,
        'lng': position.longitud,
        'comment': 'Bus llegó - subiendo',
      });
    }

    return points;
  }

  /// Genera puntos GPS para viaje en bus
  static List<Map<String, dynamic>> _generateBusRidePoints({
    required TramoViajeMostrable tramo,
    required int startTime,
    required double speedMultiplier,
  }) {
    final points = <Map<String, dynamic>>[];

    final geometry = tramo.geometriaPolilinea;
    if (geometry == null || geometry.isEmpty) {
      print('[GPSGenerator]    ⚠️  Sin geometría de bus');
      return points;
    }

    // Velocidad del bus: ~8-10 m/s (30-36 km/h promedio en ciudad)
    const busSpeed = 8.0; // metros por segundo
    final adjustedSpeed = busSpeed * speedMultiplier;

    // Intervalo de muestreo: cada 3 segundos
    const samplingInterval = 3.0;

    int currentTime = startTime;
    double distanceCovered = 0.0;

    // Agregar punto inicial (subiendo al bus)
    points.add({
      'timestamp': currentTime,
      'lat': geometry.first.latitud,
      'lng': geometry.first.longitud,
      'comment': 'Subió al bus: ${tramo.nombreLineaBus ?? ""}',
    });

    // Calcular distancia total
    double totalDistance = 0.0;
    for (int i = 0; i < geometry.length - 1; i++) {
      totalDistance += _distance(geometry[i], geometry[i + 1]);
    }

    // Generar puntos intermedios
    while (distanceCovered < totalDistance) {
      distanceCovered += adjustedSpeed * samplingInterval;

      if (distanceCovered >= totalDistance) {
        // Último punto (bajando del bus)
        currentTime += samplingInterval.round();
        points.add({
          'timestamp': currentTime,
          'lat': geometry.last.latitud,
          'lng': geometry.last.longitud,
          'comment': 'Bajando del bus en parada destino',
        });
        break;
      }

      // Encontrar punto en la geometría
      final point = _pointAtDistance(geometry, distanceCovered);
      currentTime += samplingInterval.round();

      points.add({
        'timestamp': currentTime,
        'lat': point.latitud,
        'lng': point.longitud,
      });
    }

    return points;
  }

  /// Calcula distancia entre dos coordenadas (Haversine)
  static double _distance(Coordenada from, Coordenada to) {
    const R = 6371000.0; // Radio de la Tierra en metros
    final lat1 = from.latitud * math.pi / 180;
    final lat2 = to.latitud * math.pi / 180;
    final dLat = (to.latitud - from.latitud) * math.pi / 180;
    final dLon = (to.longitud - from.longitud) * math.pi / 180;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return R * c;
  }

  /// Encuentra el punto en la geometría a una distancia específica desde el inicio
  static Coordenada _pointAtDistance(List<Coordenada> geometry, double targetDistance) {
    double accumulatedDistance = 0.0;

    for (int i = 0; i < geometry.length - 1; i++) {
      final segmentDistance = _distance(geometry[i], geometry[i + 1]);

      if (accumulatedDistance + segmentDistance >= targetDistance) {
        // El punto está en este segmento
        final remainingDistance = targetDistance - accumulatedDistance;
        final ratio = remainingDistance / segmentDistance;

        // Interpolación lineal
        final lat = geometry[i].latitud + (geometry[i + 1].latitud - geometry[i].latitud) * ratio;
        final lng = geometry[i].longitud + (geometry[i + 1].longitud - geometry[i].longitud) * ratio;

        return Coordenada(latitud: lat, longitud: lng);
      }

      accumulatedDistance += segmentDistance;
    }

    // Si llegamos aquí, retornar el último punto
    return geometry.last;
  }

  /// Genera checkpoints automáticos basados en la geometría
  static List<Map<String, dynamic>> generateCheckpoints({
    required List<TramoViajeMostrable> tramos,
    required List<Map<String, dynamic>> gpsPlayback,
  }) {
    final checkpoints = <Map<String, dynamic>>[];

    if (gpsPlayback.isEmpty) {
      return checkpoints;
    }

    print('[GPSGenerator] 🎯 Generando checkpoints automáticos...');

    int currentStepIndex = 0;
    int lastTimestamp = 0;

    for (int i = 0; i < tramos.length; i++) {
      final tramo = tramos[i];

      // Encontrar puntos GPS que corresponden a este tramo
      final tramoPoints = gpsPlayback.where((p) {
        final timestamp = p['timestamp'] as int;
        return timestamp >= lastTimestamp;
      }).toList();

      if (tramoPoints.isEmpty) continue;

      final firstPoint = tramoPoints.first['timestamp'] as int;
      final lastPoint = tramoPoints.last['timestamp'] as int;
      final midPoint = ((firstPoint + lastPoint) / 2).round();

      // Checkpoint al inicio del tramo
      checkpoints.add({
        'timestamp': firstPoint + 2, // 2 segundos después de empezar
        'name': 'Inicio: ${tramo.descripcion}',
        'assertions': {
          'currentStepIndex': i,
          'currentStepType': _stepTypeForTramo(tramo.tipo, i, tramos.length),
        }
      });

      // Checkpoint a mitad del tramo (si es suficientemente largo)
      if (lastPoint - firstPoint > 10) {
        checkpoints.add({
          'timestamp': midPoint,
          'name': 'Mitad: ${tramo.descripcion}',
          'assertions': {
            'currentStepIndex': i,
            'progressMin': 0.3,
            'progressMax': 0.7,
          }
        });
      }

      // Checkpoint al final del tramo
      if (i < tramos.length - 1) {
        // No es el último tramo
        checkpoints.add({
          'timestamp': lastPoint - 2, // 2 segundos antes de terminar
          'name': 'Llegando a: ${tramos[i + 1].descripcion}',
          'assertions': {
            'currentStepIndex': i,
            'progressMin': 0.8,
          }
        });
      }

      lastTimestamp = lastPoint;
    }

    // Checkpoint final del viaje
    final finalTimestamp = gpsPlayback.last['timestamp'] as int;
    checkpoints.add({
      'timestamp': finalTimestamp - 5,
      'name': 'Viaje casi completado',
      'assertions': {
        'currentStepIndex': tramos.length - 1,
        'progressMin': 0.9,
      }
    });

    print('[GPSGenerator] ✅ ${checkpoints.length} checkpoints generados');

    return checkpoints;
  }

  /// Determina el tipo de paso para un tramo
  static String _stepTypeForTramo(TipoTramoViaje tipo, int index, int total) {
    switch (tipo) {
      case TipoTramoViaje.CAMINAR:
        return index == total - 1 ? 'walkToDestination' : 'walkToStop';
      case TipoTramoViaje.ESPERAR_BUS:
        return 'waitForBus';
      case TipoTramoViaje.VIAJE_EN_BUS:
        return 'onBus';
    }
  }
}
