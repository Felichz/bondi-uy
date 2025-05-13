import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../state/map_state.dart';
import '../services/otp_service.dart';
import '../models/point_dart.dart';
import '../models/itinerary.dart';
import '../models/route_leg.dart';
import 'service_providers.dart'; // Importa los proveedores de servicio

// Proveedor para el MapNotifier
final mapNotifierProvider = StateNotifierProvider<MapNotifier, MapState>((ref) {
  return MapNotifier(ref);
});

class MapNotifier extends StateNotifier<MapState> {
  final Ref _ref;
  // MapboxService NO se almacena aquí, se pasa a los métodos o se usa desde el widget
  // Timer para debounce de geocoding (si se maneja aquí)
  Timer? _debounceTimer;
  // Timer para bus en tiempo real (se manejará en el widget que tiene el MapboxService)
  // Timer? _realtimeBusTimer;

  MapNotifier(this._ref) : super(const MapState());

  // --- Métodos para actualizar estado ---

  void setOrigenCoordinates(Point_dart? point) {
    state = state.copyWith(origenCoordinates: () => point);
  }

  void setDestinoCoordinates(Point_dart? point) {
    state = state.copyWith(destinoCoordinates: () => point);
  }

  void clearRouteState() {
    print("[MapNotifier_Debug] clearRouteState called.");
    state = state.copyWith(
      isCalculatingRoute: false,
      showCollapsedInstructionsBar: false,
      currentRouteLegs: [],
      selectedLegIndex: () => null,
      isInOverviewMode: false,
      availableItineraries: [],
      trackedBusLineShortName: () => null,
      highlightedBusPosition: () => null,
      userManuallyMovedMap: false,
      legToTrackInRealtime: () => null,
    );
    print(
      "[MapNotifier_Debug] clearRouteState: legToTrackInRealtime set to null.",
    );
  }

  void setUserManuallyMovedMap(bool value) {
    if (state.userManuallyMovedMap != value) {
      // Solo actualizar si cambia
      state = state.copyWith(userManuallyMovedMap: value);
    }
  }

  void setSelectedLegIndex(int? index) {
    print("[MapNotifier_Debug] setSelectedLegIndex called with index: $index");
    RouteLeg? legToTrack;
    String? busLineNameToTrack;

    if (index != null && index >= 0 && index < state.currentRouteLegs.length) {
      final selectedLeg = state.currentRouteLegs[index];
      print(
        "[MapNotifier_Debug] setSelectedLegIndex: Selected leg mode: ${selectedLeg.mode}",
      );
      if (selectedLeg.mode.toUpperCase() == 'BUS') {
        legToTrack = selectedLeg;
        busLineNameToTrack = selectedLeg.route?.shortName;
        print(
          "[MapNotifier_Debug] setSelectedLegIndex: Tracking current BUS leg (Line: $busLineNameToTrack).",
        );
      } else if (selectedLeg.mode.toUpperCase() == 'WALK') {
        int nextLegIndex = index + 1;
        if (nextLegIndex < state.currentRouteLegs.length) {
          final nextLeg = state.currentRouteLegs[nextLegIndex];
          print(
            "[MapNotifier_Debug] setSelectedLegIndex: Current leg is WALK, next leg mode: ${nextLeg.mode}",
          );
          if (nextLeg.mode.toUpperCase() == 'BUS') {
            legToTrack = nextLeg;
            busLineNameToTrack = nextLeg.route?.shortName;
            print(
              "[MapNotifier_Debug] setSelectedLegIndex: Tracking next BUS leg (Line: $busLineNameToTrack).",
            );
          }
        } else {
          print(
            "[MapNotifier_Debug] setSelectedLegIndex: Current leg is WALK, but no next leg.",
          );
        }
      }
    } else {
      print(
        "[MapNotifier_Debug] setSelectedLegIndex: Index is null or out of bounds, clearing tracking.",
      );
    }

    state = state.copyWith(
      selectedLegIndex: () => index,
      userManuallyMovedMap: false,
      legToTrackInRealtime: () => legToTrack,
      trackedBusLineShortName: () => busLineNameToTrack,
    );
    print(
      "[MapNotifier_Debug] setSelectedLegIndex: Updated state. legToTrack: ${legToTrack?.mode} (Line: $busLineNameToTrack), userManuallyMovedMap: false.",
    );
  }

  void setAvailableItineraries(List<Itinerary> itineraries) {
    state = state.copyWith(availableItineraries: itineraries);
  }

  void processSelectedItinerary(Itinerary selectedItinerary) {
    print("[MapNotifier_Debug] processSelectedItinerary called.");
    RouteLeg? firstBusLeg;
    String? busLineNameToTrack;
    if (selectedItinerary.legs.isNotEmpty) {
      // Buscar manualmente el primer tramo de BUS para evitar problemas con firstWhere/orElse y nullability
      for (final leg in selectedItinerary.legs) {
        if (leg.mode.toUpperCase() == 'BUS') {
          firstBusLeg = leg;
          break; // Encontramos el primero, salimos del bucle
        }
      }

      if (firstBusLeg != null) {
        busLineNameToTrack = firstBusLeg.route?.shortName;
        print(
          "[MapNotifier_Debug] processSelectedItinerary: Found first BUS leg (Line: $busLineNameToTrack).",
        );
      } else {
        print(
          "[MapNotifier_Debug] processSelectedItinerary: No BUS leg found in the itinerary.",
        );
      }
    } else {
      print(
        "[MapNotifier_Debug] processSelectedItinerary: Itinerary has no legs.",
      );
    }

    if (selectedItinerary.legs.isNotEmpty) {
      state = state.copyWith(
        currentRouteLegs: selectedItinerary.legs,
        selectedLegIndex: () => null,
        isInOverviewMode: true,
        showCollapsedInstructionsBar: false,
        userManuallyMovedMap: false,
        highlightedBusPosition: () => null,
        isCalculatingRoute: false,
        legToTrackInRealtime: () => firstBusLeg,
        trackedBusLineShortName: () => busLineNameToTrack,
      );
      print(
        "[MapNotifier_Debug] processSelectedItinerary: Updated state for overview. legToTrack: ${firstBusLeg?.mode} (Line: $busLineNameToTrack)",
      );
    } else {
      state = state.copyWith(
        isCalculatingRoute: false,
        legToTrackInRealtime: () => null,
      );
      print(
        "[MapNotifier_Debug] processSelectedItinerary: Updated state (no legs), legToTrack cleared.",
      );
    }
  }

  void startDetailedNavigation() {
    print("[MapNotifier_Debug] startDetailedNavigation called.");
    if (state.currentRouteLegs.isNotEmpty) {
      final RouteLeg firstLeg = state.currentRouteLegs.first;
      RouteLeg? legToTrack;
      String? busLineNameToTrack;
      print(
        "[MapNotifier_Debug] startDetailedNavigation: First leg mode: ${firstLeg.mode}",
      );

      if (firstLeg.mode.toUpperCase() == 'BUS') {
        legToTrack = firstLeg;
        busLineNameToTrack = firstLeg.route?.shortName;
        print(
          "[MapNotifier_Debug] startDetailedNavigation: Tracking first BUS leg (Line: $busLineNameToTrack).",
        );
      } else if (firstLeg.mode.toUpperCase() == 'WALK') {
        if (state.currentRouteLegs.length > 1) {
          final secondLeg = state.currentRouteLegs[1];
          print(
            "[MapNotifier_Debug] startDetailedNavigation: First leg WALK, second leg mode: ${secondLeg.mode}",
          );
          if (secondLeg.mode.toUpperCase() == 'BUS') {
            legToTrack = secondLeg;
            busLineNameToTrack = secondLeg.route?.shortName;
            print(
              "[MapNotifier_Debug] startDetailedNavigation: Tracking second BUS leg (Line: $busLineNameToTrack).",
            );
          }
        } else {
          print(
            "[MapNotifier_Debug] startDetailedNavigation: First leg WALK, but no second leg.",
          );
        }
      } else {
        print(
          "[MapNotifier_Debug] startDetailedNavigation: First leg is not BUS or WALK (${firstLeg.mode}).",
        );
      }

      state = state.copyWith(
        isInOverviewMode: false,
        selectedLegIndex: () => 0,
        showCollapsedInstructionsBar: true,
        userManuallyMovedMap: false,
        legToTrackInRealtime: () => legToTrack,
        trackedBusLineShortName: () => busLineNameToTrack,
      );
      print(
        "[MapNotifier_Debug] startDetailedNavigation: Updated state for detailed nav. legToTrack: ${legToTrack?.mode} (Line: $busLineNameToTrack)",
      );
    } else {
      print(
        "[MapNotifier_Debug] startDetailedNavigation: No current route legs.",
      );
    }
  }

  // Método principal para buscar ruta
  Future<void> searchRoute() async {
    print("[MapNotifier_Debug] searchRoute called.");
    if (state.origenCoordinates == null || state.destinoCoordinates == null) {
      print("[MapNotifier_Debug] searchRoute: Missing origin or destination.");
      state = state.copyWith(
        errorMessage: () => "Por favor, selecciona un origen y destino.",
      );
      return;
    }

    print(
      "[MapNotifier_Debug] searchRoute: Setting isCalculatingRoute = true.",
    );
    state = state.copyWith(
      isCalculatingRoute: true,
      errorMessage: () => null,
      currentRouteLegs: [],
      selectedLegIndex: () => null,
      isInOverviewMode: false,
      showCollapsedInstructionsBar: false,
      trackedBusLineShortName: () => null,
      highlightedBusPosition: () => null,
      legToTrackInRealtime: () => null,
    );

    final otpService = _ref.read(otpServiceProvider);
    final now = DateTime.now();
    final String date =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final String time =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    print("[MapNotifier_Debug] searchRoute: Calling OtpService.planRoute...");

    try {
      final QueryResult result = await otpService.planRoute(
        fromLat: state.origenCoordinates!.lat,
        fromLon: state.origenCoordinates!.lng,
        toLat: state.destinoCoordinates!.lat,
        toLon: state.destinoCoordinates!.lng,
        date: date,
        time: time,
      );
      print("[MapNotifier_Debug] searchRoute: OtpService.planRoute finished.");

      if (result.hasException) {
        print(
          "[MapNotifier_Debug] searchRoute: GraphQL Error: ${result.exception.toString()}",
        );
        state = state.copyWith(
          isCalculatingRoute: false,
          availableItineraries: [],
          errorMessage:
              () => "Error al calcular la ruta: ${result.exception.toString()}",
          legToTrackInRealtime: () => null,
        );
        print("[MapNotifier_Debug] searchRoute: State updated with error.");
        return;
      }

      if (result.data != null) {
        final planData = result.data!['plan'];
        if (planData != null &&
            planData['itineraries'] != null &&
            (planData['itineraries'] as List).isNotEmpty) {
          print("[MapNotifier_Debug] searchRoute: Found itineraries.");
          final List<Itinerary> itineraries = Itinerary.listFromJson(
            planData['itineraries'],
          );
          state = state.copyWith(
            availableItineraries: itineraries,
            isCalculatingRoute: false,
            currentRouteLegs: [],
            selectedLegIndex: () => null,
            isInOverviewMode: false,
            showCollapsedInstructionsBar: false,
            trackedBusLineShortName: () => null,
            highlightedBusPosition: () => null,
            legToTrackInRealtime: () => null,
          );
          print(
            "[MapNotifier_Debug] searchRoute: State updated with availableItineraries.",
          );
        } else {
          print(
            "[MapNotifier_Debug] searchRoute: No itineraries found in response.",
          );
          state = state.copyWith(
            isCalculatingRoute: false,
            availableItineraries: [],
            errorMessage:
                () =>
                    "No se encontraron rutas para el origen y destino seleccionados.",
            legToTrackInRealtime: () => null,
          );
          print(
            "[MapNotifier_Debug] searchRoute: State updated, no routes found.",
          );
        }
      } else {
        print(
          "[MapNotifier_Debug] searchRoute: GraphQL response data is null.",
        );
        state = state.copyWith(
          isCalculatingRoute: false,
          availableItineraries: [],
          errorMessage:
              () => "Error al obtener respuesta del servidor de rutas.",
          legToTrackInRealtime: () => null,
        );
        print(
          "[MapNotifier_Debug] searchRoute: State updated, null response data.",
        );
      }
    } catch (e, s) {
      print("[MapNotifier_Debug] searchRoute: Exception: $e");
      print(s); // Print stack trace for exceptions
      state = state.copyWith(
        isCalculatingRoute: false,
        availableItineraries: [],
        errorMessage: () => "Ocurrió un error inesperado: ${e.toString()}",
        legToTrackInRealtime: () => null,
      );
      print("[MapNotifier_Debug] searchRoute: State updated after exception.");
    }
  }

  // Nuevo método para limpiar el mensaje de error
  void clearErrorMessage() {
    state = state.copyWith(errorMessage: () => null);
  }

  // --- Métodos de ayuda ---

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
