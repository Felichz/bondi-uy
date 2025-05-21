import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bondi_uy/providers/app_providers.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
// TODO: Importar el provider del AppUiState de la capa de lógica
// Ejemplo: import 'package:bondi_uy/backend/providers/app_logic_provider.dart';

import 'package:bondi_uy/ui/initial_phase_view.dart'; // Import InitialPhaseView
import 'package:bondi_uy/ui/route_options_view.dart'; // Importar la nueva vista
import 'package:bondi_uy/ui/active_trip_view.dart'; // Importar la nueva vista de viaje activo
// TODO: Importar las vistas para las otras fases (ej. ViajeActivoView)

class AppHost extends ConsumerWidget {
  const AppHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUiState = ref.watch(appUiStateProvider);

    // Determinar qué vista mostrar según la fase actual
    Widget currentView;
    switch (appUiState.faseActual) {
      case FaseApp.INICIAL_SIN_BUSQUEDA:
        currentView = const InitialPhaseView();
        break;
      case FaseApp.MOSTRANDO_OPCIONES_RUTA:
        currentView = const RouteOptionsView(); // Mostrar la nueva vista
        break;
      case FaseApp.VIAJE_ACTIVO_EN_CURSO:
        currentView =
            const ActiveTripView(); // Mostrar la vista de viaje activo
        break;
      default:
        // Fallback a la fase inicial si el estado es desconocido
        currentView = const InitialPhaseView();
    }

    return MaterialApp(
      // TODO: Configurar tema, etc.
      home: currentView,
      debugShowCheckedModeBanner: false,
    );
  }
}
