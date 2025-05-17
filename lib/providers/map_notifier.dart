import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// No necesitamos GraphQLClient directamente aquí si ItineraryPlanningService lo maneja
// import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../state/map_state.dart';
import '../models/point_dart.dart';
import '../models/itinerary.dart';
import '../models/route_leg.dart';
import 'service_providers.dart'; // Importa los proveedores de servicio
// Importar el nuevo servicio y su excepción
import '../services/itinerary_planning_service.dart';

// Proveedor para el MapNotifier
final mapNotifierProvider = StateNotifierProvider<MapNotifier, MapState>((ref) {
  return MapNotifier(ref);
});

class MapNotifier extends StateNotifier<MapState> {
  final Ref _ref;
  Timer? _debounceTimer;
  Timer?
  _cooldownTimer; // NUEVO para gestionar el cooldown después del movimiento manual

  MapNotifier(this._ref)
    : super(const MapState()); // MapState() inicializa con los nuevos defaults

  // --- Métodos para actualizar estado ---

  void setOrigenCoordinates(Point_dart? point) {
    ZoomTarget nextZoomTarget = state.currentZoomTarget;
    if (point != null) {
      final newPosition = Position(point.lng, point.lat);
      if (state.destinoCoordinates == null) {
        nextZoomTarget = ZoomTarget(
          type: ZoomTargetType.origenSelection,
          singlePoint: newPosition,
        );
      } else {
        // Si ya hay un destino, podríamos querer un zoom a ambos puntos
        final pointsToFit = [
          newPosition,
          Position(
            state.destinoCoordinates!.lng,
            state.destinoCoordinates!.lat,
          ),
        ];
        nextZoomTarget = ZoomTarget(
          type: ZoomTargetType.points,
          points: pointsToFit,
        );
      }
    } else {
      // Origen borrado, si no hay destino, volver a initial. Si hay destino, zoom al destino.
      if (state.destinoCoordinates == null) {
        nextZoomTarget = ZoomTarget.initial;
      } else {
        nextZoomTarget = ZoomTarget(
          type: ZoomTargetType.destinoSelection,
          singlePoint: Position(
            state.destinoCoordinates!.lng,
            state.destinoCoordinates!.lat,
          ),
        );
      }
    }
    state = state.copyWith(
      origenCoordinates: () => point,
      currentZoomTarget: nextZoomTarget,
      userMapInteraction: UserMapInteractionState.idle,
    );
  }

  void setDestinoCoordinates(Point_dart? point) {
    ZoomTarget nextZoomTarget = state.currentZoomTarget;
    if (point != null) {
      final newPosition = Position(point.lng, point.lat);
      if (state.origenCoordinates == null) {
        nextZoomTarget = ZoomTarget(
          type: ZoomTargetType.destinoSelection,
          singlePoint: newPosition,
        );
      } else {
        // Si ya hay un origen, podríamos querer un zoom a ambos puntos
        final pointsToFit = [
          Position(state.origenCoordinates!.lng, state.origenCoordinates!.lat),
          newPosition,
        ];
        nextZoomTarget = ZoomTarget(
          type: ZoomTargetType.points,
          points: pointsToFit,
        );
      }
    } else {
      // Destino borrado, si no hay origen, volver a initial. Si hay origen, zoom al origen.
      if (state.origenCoordinates == null) {
        nextZoomTarget = ZoomTarget.initial;
      } else {
        nextZoomTarget = ZoomTarget(
          type: ZoomTargetType.origenSelection,
          singlePoint: Position(
            state.origenCoordinates!.lng,
            state.origenCoordinates!.lat,
          ),
        );
      }
    }
    state = state.copyWith(
      destinoCoordinates: () => point,
      currentZoomTarget: nextZoomTarget,
      userMapInteraction: UserMapInteractionState.idle,
    );
  }

  void clearRouteState() {
    print("[MapNotifier_DEBUG] clearRouteState called.");
    _cooldownTimer?.cancel();
    state = state.copyWith(
      isCalculatingRoute: false,
      showCollapsedInstructionsBar: false,
      currentRouteLegs: [],
      selectedLegIndex: () => null,
      isInOverviewMode: false,
      availableItineraries: [],
      trackedBusLineShortName: () => null,
      highlightedBusPosition: () => null,
      highlightedBusEtaMinutes: () => null,
      legToTrackInRealtime: () => null,
      currentZoomTarget: ZoomTarget.initial,
      userMapInteraction: UserMapInteractionState.idle,
      lastManualMoveTimestamp: () => null,
      simulatedBusPosition: () => null,
      busSpeedMetersPerSecond: () => null,
      lastSpeedCalculationTime: () => null,
      simulationSegmentOriginPoint: () => null,
      realDebugBusPosition: () => null,
      maxSimulationTravelDistance: () => null,
      errorMessage: () => null, // Asegurarse de limpiar el mensaje de error
    );
    print(
      "[MapNotifier_DEBUG] clearRouteState: legToTrackInRealtime set to null.",
    );
  }

  // NUEVOS MÉTODOS PARA INTERACCIÓN DEL MAPA
  void mapInteractionStarted() {
    _cooldownTimer?.cancel();
    if (state.userMapInteraction !=
        UserMapInteractionState.manualMoveInProgress) {
      print(
        "[MapNotifier_DEBUG] mapInteractionStarted: Setting state to manualMoveInProgress",
      );
      state = state.copyWith(
        userMapInteraction: UserMapInteractionState.manualMoveInProgress,
      );
    }
  }

  void mapInteractionEnded() {
    if (state.userMapInteraction ==
            UserMapInteractionState.manualMoveInProgress ||
        state.userMapInteraction == UserMapInteractionState.idle) {
      print(
        "[MapNotifier_DEBUG] mapInteractionEnded: Setting state to manualMoveCooldown and starting timer",
      );
      final now = DateTime.now();
      state = state.copyWith(
        userMapInteraction: UserMapInteractionState.manualMoveCooldown,
        lastManualMoveTimestamp: () => now,
        currentZoomTarget: ZoomTarget.none,
      );
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer(const Duration(seconds: 15), () {
        if (mounted &&
            state.userMapInteraction ==
                UserMapInteractionState.manualMoveCooldown) {
          final timeSinceLastMove = DateTime.now().difference(
            state.lastManualMoveTimestamp ?? now,
          );
          if (timeSinceLastMove.inSeconds >= 14) {
            print("[MapNotifier_DEBUG] Cooldown ended. Setting state to idle.");
            state = state.copyWith(
              userMapInteraction: UserMapInteractionState.idle,
            );
            _triggerAutoZoomLogic();
          }
        }
      });
    }
  }

  void setSelectedLegIndex(int? index) {
    print("[MapNotifier_DEBUG] setSelectedLegIndex called with index: $index");
    RouteLeg? legToTrack;
    String? busLineNameToTrack;
    ZoomTarget nextZoomTarget = state.currentZoomTarget;

    if (index != null && index >= 0 && index < state.currentRouteLegs.length) {
      final selectedLeg = state.currentRouteLegs[index];
      if (selectedLeg.mode.toUpperCase() == 'BUS') {
        legToTrack = selectedLeg;
        busLineNameToTrack = selectedLeg.route?.shortName;
        nextZoomTarget = ZoomTarget(
          type: ZoomTargetType.busAndLegOrigin,
          legIndex: index,
        );
      } else if (selectedLeg.mode.toUpperCase() == 'WALK') {
        nextZoomTarget = ZoomTarget(type: ZoomTargetType.leg, legIndex: index);
        int nextLegIndex = index + 1;
        if (nextLegIndex < state.currentRouteLegs.length) {
          final nextLeg = state.currentRouteLegs[nextLegIndex];
          if (nextLeg.mode.toUpperCase() == 'BUS') {
            legToTrack = nextLeg;
            busLineNameToTrack = nextLeg.route?.shortName;
          }
        }
      } else {
        nextZoomTarget = ZoomTarget(type: ZoomTargetType.leg, legIndex: index);
      }
    } else {
      nextZoomTarget = ZoomTarget.none;
    }

    state = state.copyWith(
      selectedLegIndex: () => index,
      userMapInteraction: UserMapInteractionState.idle,
      currentZoomTarget: nextZoomTarget,
      legToTrackInRealtime: () => legToTrack,
      trackedBusLineShortName: () => busLineNameToTrack,
      busSpeedMetersPerSecond: () => null,
      simulatedBusPosition: () => null,
      realDebugBusPosition: () => null,
    );
    print(
      "[MapNotifier_DEBUG] setSelectedLegIndex: Updated state. legToTrack: ${legToTrack?.mode} (Line: $busLineNameToTrack), userInteraction: idle, zoomTarget: ${nextZoomTarget.type}",
    );
  }

  void setAvailableItineraries(List<Itinerary> itineraries) {
    state = state.copyWith(
      availableItineraries: itineraries,
      errorMessage: () => null, // Limpiar error si se establecen itinerarios
    );
  }

  void processSelectedItinerary(Itinerary selectedItinerary) {
    print("[MapNotifier_DEBUG] processSelectedItinerary called.");
    RouteLeg? firstBusLeg;
    String? busLineNameToTrack;
    if (selectedItinerary.legs.isNotEmpty) {
      for (final leg in selectedItinerary.legs) {
        if (leg.mode.toUpperCase() == 'BUS') {
          firstBusLeg = leg;
          break;
        }
      }
      if (firstBusLeg != null) {
        busLineNameToTrack = firstBusLeg.route?.shortName;
      }
    }

    state = state.copyWith(
      currentRouteLegs: selectedItinerary.legs,
      selectedLegIndex: () => null, // Reset selected leg
      isInOverviewMode: true,
      currentZoomTarget: const ZoomTarget(type: ZoomTargetType.overview),
      userMapInteraction: UserMapInteractionState.idle,
      legToTrackInRealtime:
          () => firstBusLeg, // Puede ser null si no hay tramos de bus
      trackedBusLineShortName: () => busLineNameToTrack, // Puede ser null
      showCollapsedInstructionsBar: true,
      errorMessage: () => null, // Limpiar errores al procesar un itinerario
      highlightedBusPosition: () => null, // Limpiar posición de bus anterior
      simulatedBusPosition: () => null, // Limpiar posición simulada
      highlightedBusEtaMinutes: () => null, // Limpiar ETA anterior
    );
    print(
      "[MapNotifier_DEBUG] processSelectedItinerary: Set to overview. legToTrack: ${firstBusLeg?.mode}, line: $busLineNameToTrack",
    );
  }

  void startDetailedNavigation() {
    print("[MapNotifier_DEBUG] startDetailedNavigation called.");
    if (state.currentRouteLegs.isNotEmpty) {
      state = state.copyWith(
        isInOverviewMode: false,
        userMapInteraction: UserMapInteractionState.idle,
      );
      print(
        "[MapNotifier_DEBUG] startDetailedNavigation: Mode set to detailed navigation. Current selectedLegIndex: ${state.selectedLegIndex}",
      );
      if (state.selectedLegIndex == null) {
        setSelectedLegIndex(0);
      }
    } else {
      print(
        "[MapNotifier_DEBUG] startDetailedNavigation: No current route legs to navigate.",
      );
    }
  }

  // Método principal para buscar rutas, ahora usando ItineraryPlanningService
  Future<void> searchRoute() async {
    if (state.origenCoordinates == null || state.destinoCoordinates == null) {
      state = state.copyWith(
        errorMessage: () => "Por favor, selecciona un origen y un destino.",
      );
      return;
    }

    // Limpiar estado de ruta anterior y errores antes de una nueva búsqueda
    clearRouteStateAndError();

    state = state.copyWith(isCalculatingRoute: true);

    final itineraryPlanner = _ref.read(itineraryPlanningServiceProvider);
    final now = DateTime.now();

    try {
      print(
        "[MapNotifier_DEBUG] searchRoute: Calling ItineraryPlanningService. Origen: ${state.origenCoordinates}, Destino: ${state.destinoCoordinates}",
      );
      final List<Itinerary> itineraries = await itineraryPlanner.getItineraries(
        fromPoint: state.origenCoordinates!,
        toPoint: state.destinoCoordinates!,
        dateTime: now,
      );

      if (!mounted) return; // Verificar si el notifier sigue montado

      if (itineraries.isEmpty) {
        print(
          "[MapNotifier_DEBUG] searchRoute: No itineraries found by service.",
        );
        state = state.copyWith(
          availableItineraries: [],
          isCalculatingRoute: false,
          errorMessage: () => "No se encontraron rutas para tu búsqueda.",
        );
      } else {
        print(
          "[MapNotifier_DEBUG] searchRoute: Itineraries found: ${itineraries.length}",
        );
        state = state.copyWith(
          availableItineraries: itineraries,
          isCalculatingRoute: false,
          errorMessage: () => null,
        );
      }
    } on ItineraryPlanningException catch (e) {
      print(
        "[MapNotifier_DEBUG] searchRoute: ItineraryPlanningException caught: ${e.message}",
      );
      if (!mounted) return;
      state = state.copyWith(
        isCalculatingRoute: false,
        errorMessage:
            () => e.message, // Usar el mensaje de la excepción personalizada
        availableItineraries: [], // Limpiar itinerarios en caso de error
      );
    } catch (e) {
      print(
        "[MapNotifier_DEBUG] searchRoute: Generic error caught: ${e.toString()}",
      );
      if (!mounted) return;
      state = state.copyWith(
        isCalculatingRoute: false,
        errorMessage: () => "Ocurrió un error desconocido al buscar la ruta.",
        availableItineraries: [], // Limpiar itinerarios en caso de error
      );
    }
  }

  void clearErrorMessage() {
    state = state.copyWith(errorMessage: () => null);
  }

  // Helper para limpiar estado de ruta y error
  void clearRouteStateAndError() {
    print("[MapNotifier_DEBUG] clearRouteStateAndError called.");
    _cooldownTimer?.cancel();
    state = state.copyWith(
      isCalculatingRoute: false,
      showCollapsedInstructionsBar: false,
      currentRouteLegs: [],
      selectedLegIndex: () => null,
      isInOverviewMode: false,
      availableItineraries: [],
      trackedBusLineShortName: () => null,
      highlightedBusPosition: () => null,
      highlightedBusEtaMinutes: () => null,
      legToTrackInRealtime: () => null,
      currentZoomTarget:
          (state.origenCoordinates != null && state.destinoCoordinates != null)
              ? ZoomTarget(
                type: ZoomTargetType.points,
                points: [
                  Position(
                    state.origenCoordinates!.lng,
                    state.origenCoordinates!.lat,
                  ),
                  Position(
                    state.destinoCoordinates!.lng,
                    state.destinoCoordinates!.lat,
                  ),
                ],
              )
              : ZoomTarget
                  .initial, // Si no hay origen/destino, vuelve a initial, sino zoom a los puntos de búsqueda.
      userMapInteraction: UserMapInteractionState.idle,
      lastManualMoveTimestamp: () => null,
      simulatedBusPosition: () => null,
      busSpeedMetersPerSecond: () => null,
      lastSpeedCalculationTime: () => null,
      simulationSegmentOriginPoint: () => null,
      realDebugBusPosition: () => null,
      maxSimulationTravelDistance: () => null,
      errorMessage: () => null,
    );
  }

  // Método para establecer el nombre corto de la línea de bus que se está rastreando
  void setTrackedBusLineShortName(String? lineShortName) {
    state = state.copyWith(trackedBusLineShortName: () => lineShortName);
  }

  // Método para actualizar el estado de la simulación y la posición/ETA del bus
  void updateBusSimulationState({
    Position? newHighlightedBusPosition,
    int? newEtaMinutes,
    Position? newSimulatedBusPosition,
    double? newBusSpeedMetersPerSecond,
    DateTime? newLastSpeedCalculationTime,
    Position? newSimulationSegmentOriginPoint,
    Position? newRealDebugBusPosition,
    double? newMaxSimulationTravelDistance,
    bool? newIsHighlightedBusReal,
  }) {
    state = state.copyWith(
      highlightedBusPosition: () => newHighlightedBusPosition,
      highlightedBusEtaMinutes: () => newEtaMinutes,
      simulatedBusPosition: () => newSimulatedBusPosition,
      busSpeedMetersPerSecond: () => newBusSpeedMetersPerSecond,
      lastSpeedCalculationTime: () => newLastSpeedCalculationTime,
      simulationSegmentOriginPoint: () => newSimulationSegmentOriginPoint,
      realDebugBusPosition: () => newRealDebugBusPosition,
      maxSimulationTravelDistance: () => newMaxSimulationTravelDistance,
      isHighlightedBusReal: () => newIsHighlightedBusReal,
    );
  }

  // Lógica para el re-centrado automático del mapa
  void _triggerAutoZoomLogic() {
    if (state.userMapInteraction == UserMapInteractionState.idle) {
      if (state.currentRouteLegs.isNotEmpty) {
        if (state.isInOverviewMode) {
          state = state.copyWith(
            currentZoomTarget: const ZoomTarget(type: ZoomTargetType.overview),
          );
        } else if (state.selectedLegIndex != null) {
          final selectedLeg = state.currentRouteLegs[state.selectedLegIndex!];
          if (selectedLeg.mode.toUpperCase() == 'BUS') {
            state = state.copyWith(
              currentZoomTarget: ZoomTarget(
                type: ZoomTargetType.busAndLegOrigin,
                legIndex: state.selectedLegIndex!,
              ),
            );
          } else {
            state = state.copyWith(
              currentZoomTarget: ZoomTarget(
                type: ZoomTargetType.leg,
                legIndex: state.selectedLegIndex!,
              ),
            );
          }
        }
      } else if (state.origenCoordinates != null ||
          state.destinoCoordinates != null) {
        // Lógica si no hay ruta pero sí origen/destino
        if (state.origenCoordinates != null &&
            state.destinoCoordinates != null) {
          state = state.copyWith(
            currentZoomTarget: ZoomTarget(
              type: ZoomTargetType.points,
              points: [
                Position(
                  state.origenCoordinates!.lng,
                  state.origenCoordinates!.lat,
                ),
                Position(
                  state.destinoCoordinates!.lng,
                  state.destinoCoordinates!.lat,
                ),
              ],
            ),
          );
        } else if (state.origenCoordinates != null) {
          state = state.copyWith(
            currentZoomTarget: ZoomTarget(
              type: ZoomTargetType.origenSelection,
              singlePoint: Position(
                state.origenCoordinates!.lng,
                state.origenCoordinates!.lat,
              ),
            ),
          );
        } else if (state.destinoCoordinates != null) {
          state = state.copyWith(
            currentZoomTarget: ZoomTarget(
              type: ZoomTargetType.destinoSelection,
              singlePoint: Position(
                state.destinoCoordinates!.lng,
                state.destinoCoordinates!.lat,
              ),
            ),
          );
        }
      } else {
        state = state.copyWith(currentZoomTarget: ZoomTarget.initial);
      }
    }
  }

  // --- Gestión de Timers (Ejemplo) ---
  @override
  void dispose() {
    _debounceTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }
}

// Enum para definir el tipo de objetivo de zoom
// Se movió a map_state.dart

// Clase para encapsular la información del objetivo de zoom
// Se movió a map_state.dart
