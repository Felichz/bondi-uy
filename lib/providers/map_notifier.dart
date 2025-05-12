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
    );
  }

  void setUserManuallyMovedMap(bool value) {
    if (state.userManuallyMovedMap != value) {
      // Solo actualizar si cambia
      state = state.copyWith(userManuallyMovedMap: value);
    }
  }

  void setSelectedLegIndex(int? index) {
    state = state.copyWith(
      selectedLegIndex: () => index,
      userManuallyMovedMap: false,
    );
    // La lógica de rastreo de bus se iniciará/detendrá desde el widget
    // basado en el cambio de estado de selectedLegIndex y currentRouteLegs.
  }

  void setAvailableItineraries(List<Itinerary> itineraries) {
    state = state.copyWith(availableItineraries: itineraries);
  }

  void processSelectedItinerary(Itinerary selectedItinerary) {
    if (selectedItinerary.legs.isNotEmpty) {
      state = state.copyWith(
        currentRouteLegs: selectedItinerary.legs,
        selectedLegIndex: () => null,
        isInOverviewMode: true,
        showCollapsedInstructionsBar: false,
        userManuallyMovedMap: false,
        trackedBusLineShortName: () => null,
        highlightedBusPosition: () => null,
        isCalculatingRoute: false,
      );
    } else {
      state = state.copyWith(isCalculatingRoute: false);
    }
  }

  void startDetailedNavigation() {
    if (state.currentRouteLegs.isNotEmpty) {
      final RouteLeg firstLeg = state.currentRouteLegs.first;
      final String mode = firstLeg.mode.toUpperCase();
      String? initialTrackedBusLine;
      if (mode == 'BUS' || mode == 'TRANSIT') {
        initialTrackedBusLine = firstLeg.route?.shortName;
      }

      state = state.copyWith(
        isInOverviewMode: false,
        selectedLegIndex: () => 0,
        showCollapsedInstructionsBar: true,
        userManuallyMovedMap: false,
        trackedBusLineShortName: () => initialTrackedBusLine,
      );
    }
  }

  // Método principal para buscar ruta
  Future<void> searchRoute() async {
    if (state.origenCoordinates == null || state.destinoCoordinates == null) {
      state = state.copyWith(
        errorMessage: () => "Por favor, selecciona un origen y destino.",
      );
      return;
    }

    state = state.copyWith(
      isCalculatingRoute: true,
      errorMessage: () => null,
    ); // Limpiar error anterior

    final otpService = _ref.read(otpServiceProvider);
    final now = DateTime.now();
    final String date =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final String time =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    try {
      final QueryResult result = await otpService.planRoute(
        fromLat: state.origenCoordinates!.lat,
        fromLon: state.origenCoordinates!.lng,
        toLat: state.destinoCoordinates!.lat,
        toLon: state.destinoCoordinates!.lng,
        date: date,
        time: time,
      );

      if (result.hasException) {
        print("Error en GraphQL: ${result.exception.toString()}");
        state = state.copyWith(
          isCalculatingRoute: false,
          availableItineraries: [],
          errorMessage:
              () => "Error al calcular la ruta: ${result.exception.toString()}",
        );
        return;
      }

      if (result.data != null) {
        final planData = result.data!['plan'];
        if (planData != null &&
            planData['itineraries'] != null &&
            (planData['itineraries'] as List).isNotEmpty) {
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
          );
        } else {
          print("Respuesta de GraphQL no contiene itinerarios válidos.");
          state = state.copyWith(
            isCalculatingRoute: false,
            availableItineraries: [],
            errorMessage:
                () =>
                    "No se encontraron rutas para el origen y destino seleccionados.",
          );
        }
      } else {
        print("Respuesta de GraphQL vacía.");
        state = state.copyWith(
          isCalculatingRoute: false,
          availableItineraries: [],
          errorMessage:
              () => "Error al obtener respuesta del servidor de rutas.",
        );
      }
    } catch (e) {
      print("Excepción al obtener ruta GraphQL: $e");
      state = state.copyWith(
        isCalculatingRoute: false,
        availableItineraries: [],
        errorMessage: () => "Ocurrió un error inesperado: ${e.toString()}",
      );
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
