/// Adaptador que convierte estructuras del JourneyManager viejo
/// a las estructuras de la arquitectura core/ nueva
///
/// Esto permite que JourneyManager use TripOrchestrator + GeometryAdapter
/// sin romper la API existente.

import '../../backend/contrato_ui/app_ui_state.dart';
import '../core/trip_step.dart';
import '../journey_step_state.dart';

/// Convierte un TramoViajeMostrable a TripStep de la arquitectura core
TripStep tramoToTripStep(TramoViajeMostrable tramo, int index, List<TramoViajeMostrable> allTramos) {
  final stepType = _inferStepType(tramo, index, allTramos);
  final metadata = _buildMetadata(tramo, index, allTramos);

  return TripStep(
    id: 'step_$index',
    type: stepType,
    description: tramo.descripcion,
    metadata: metadata,
  );
}

/// Infiere el TripStepType desde un TramoViajeMostrable
TripStepType _inferStepType(TramoViajeMostrable tramo, int index, List<TramoViajeMostrable> allTramos) {
  switch (tramo.tipo) {
    case TipoTramoViaje.CAMINAR:
      // Determinar si es walk to stop o walk to destination
      // Si el siguiente tramo es ESPERAR_BUS o hay un bus después, es walk to stop
      if (index + 1 < allTramos.length) {
        final nextTramo = allTramos[index + 1];
        if (nextTramo.tipo == TipoTramoViaje.ESPERAR_BUS ||
            nextTramo.tipo == TipoTramoViaje.VIAJE_EN_BUS) {
          return TripStepType.walkToStop;
        }
      }
      return TripStepType.walkToDestination;

    case TipoTramoViaje.ESPERAR_BUS:
      return TripStepType.waitForBus;

    case TipoTramoViaje.VIAJE_EN_BUS:
      return TripStepType.onBus;
  }
}

/// Construye metadata desde un TramoViajeMostrable
TripStepMetadata _buildMetadata(TramoViajeMostrable tramo, int index, List<TramoViajeMostrable> allTramos) {
  String? originStopId;
  String? destinationStopId;
  String? busLine;
  double? totalDistanceMeters;
  bool hasEta = false;

  switch (tramo.tipo) {
    case TipoTramoViaje.CAMINAR:
      totalDistanceMeters = tramo.distanciaMetros?.toDouble();

      // Si es walk to stop, buscar el stopId del siguiente tramo
      if (index + 1 < allTramos.length) {
        final nextTramo = allTramos[index + 1];
        if (nextTramo.tipo == TipoTramoViaje.ESPERAR_BUS) {
          // El stop de origen del wait es nuestro destino
          destinationStopId = nextTramo.idParadaOrigenTramoBus;
        } else if (nextTramo.tipo == TipoTramoViaje.VIAJE_EN_BUS) {
          // Usar parada origen del bus
          destinationStopId = nextTramo.idParadaOrigenTramoBus;
        }
      }
      break;

    case TipoTramoViaje.ESPERAR_BUS:
      originStopId = tramo.idParadaOrigenTramoBus;
      busLine = tramo.nombreLineaBus;
      hasEta = tramo.esTiempoRealBus ?? false;
      break;

    case TipoTramoViaje.VIAJE_EN_BUS:
      originStopId = tramo.idParadaOrigenTramoBus;
      destinationStopId = tramo.idParadaDestinoTramoBus;
      busLine = tramo.nombreLineaBus;
      totalDistanceMeters = tramo.distanciaMetros.toDouble();
      break;
  }

  return TripStepMetadata(
    originStopId: originStopId,
    destinationStopId: destinationStopId,
    busLine: busLine,
    totalDistanceMeters: totalDistanceMeters,
    hasEta: hasEta,
  );
}

/// Obtiene descripción por defecto para un step type
String _getDefaultDescription(TripStepType type) {
  switch (type) {
    case TripStepType.walkToStop:
      return 'Camina hacia la parada';
    case TripStepType.waitForBus:
      return 'Espera el bus';
    case TripStepType.onBus:
      return 'En el bus';
    case TripStepType.walkToDestination:
      return 'Camina al destino';
  }
}

/// Convierte JourneyStepType a TripStepType
TripStepType journeyStepTypeToTripStepType(JourneyStepType journeyType) {
  switch (journeyType) {
    case JourneyStepType.WALKING_TO_STOP:
      return TripStepType.walkToStop;
    case JourneyStepType.WAITING_FOR_BUS:
      return TripStepType.waitForBus;
    case JourneyStepType.RIDING_BUS:
      return TripStepType.onBus;
    case JourneyStepType.WALKING_TO_DESTINATION:
      return TripStepType.walkToDestination;
  }
}

/// Convierte TripStepType a JourneyStepType
JourneyStepType tripStepTypeToJourneyStepType(TripStepType tripType) {
  switch (tripType) {
    case TripStepType.walkToStop:
      return JourneyStepType.WALKING_TO_STOP;
    case TripStepType.waitForBus:
      return JourneyStepType.WAITING_FOR_BUS;
    case TripStepType.onBus:
      return JourneyStepType.RIDING_BUS;
    case TripStepType.walkToDestination:
      return JourneyStepType.WALKING_TO_DESTINATION;
  }
}

/// Construye stopLocations map desde tramos
Map<String, Coordenada> buildStopLocationsFromTramos(List<TramoViajeMostrable> tramos) {
  final stopLocations = <String, Coordenada>{};

  for (final tramo in tramos) {
    // Agregar parada origen si existe
    if (tramo.idParadaOrigenTramoBus != null && tramo.coordenadasParadaOrigen != null) {
      stopLocations[tramo.idParadaOrigenTramoBus!] = tramo.coordenadasParadaOrigen!;
    }

    // Agregar parada destino si existe
    if (tramo.idParadaDestinoTramoBus != null && tramo.coordenadasParadaDestino != null) {
      stopLocations[tramo.idParadaDestinoTramoBus!] = tramo.coordenadasParadaDestino!;
    }
  }

  return stopLocations;
}

/// Construye busRoutes map desde tramos
Map<String, List<Coordenada>> buildBusRoutesFromTramos(List<TramoViajeMostrable> tramos) {
  final busRoutes = <String, List<Coordenada>>{};

  for (final tramo in tramos) {
    if (tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS &&
        tramo.nombreLineaBus != null &&
        tramo.geometriaPolilinea != null &&
        tramo.geometriaPolilinea!.isNotEmpty) {
      busRoutes[tramo.nombreLineaBus!] = tramo.geometriaPolilinea!;
    }
  }

  return busRoutes;
}

/// Obtiene coordenada de destino final desde tramos
Coordenada getDestinationFromTramos(List<TramoViajeMostrable> tramos) {
  if (tramos.isEmpty) {
    return Coordenada(latitud: 0, longitud: 0);
  }

  // Buscar el último tramo CAMINAR que debería tener el destino final
  for (int i = tramos.length - 1; i >= 0; i--) {
    final tramo = tramos[i];
    if (tramo.tipo == TipoTramoViaje.CAMINAR &&
        tramo.geometriaPolilinea != null &&
        tramo.geometriaPolilinea!.isNotEmpty) {
      return tramo.geometriaPolilinea!.last;
    }
  }

  // Fallback: último punto de cualquier geometría
  for (int i = tramos.length - 1; i >= 0; i--) {
    final tramo = tramos[i];
    if (tramo.geometriaPolilinea != null && tramo.geometriaPolilinea!.isNotEmpty) {
      return tramo.geometriaPolilinea!.last;
    }
  }

  return Coordenada(latitud: 0, longitud: 0);
}
