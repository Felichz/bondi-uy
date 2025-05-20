import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import 'package:bondi_uy/backend/providers/app_logic_provider.dart';

import 'package:bondi_uy/ui/common/map/main_map_view.dart';
// import 'package:bondi_uy/ui/features/initial_search/initial_search_elements.dart'; // Ya no se usa directamente
import 'package:bondi_uy/ui/features/initial_search/search_input_panel.dart'; // Nuevo widget para búsqueda
import 'package:bondi_uy/ui/features/route_options/route_options_display.dart';
import 'package:bondi_uy/ui/features/active_trip/active_trip_display.dart';
// import 'package:bondi_uy/ui/common/widgets/stop_details_panel.dart'; // Lo haremos un widget reutilizable luego

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appLogicProvider);
    final logic = ref.read(appLogicProvider.notifier); // Para acciones

    return Scaffold(
      appBar: _buildAppBar(context, appState, logic),
      body: Stack(
        children: [
          // 1. Mapa Persistente
          const MainMapView(),

          // 2. Widgets de UI específicos de la Fase
          _buildPhaseSpecificUI(context, appState, logic),

          // 3. Widgets Globales/Flotantes (ej. panel de detalles de parada)
          if (appState.infoParadaConsultada != null &&
              appState.faseActual ==
                  FaseApp
                      .INICIAL_SIN_BUSQUEDA) // Mostrar solo en fase inicial por ahora
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildStopDetailsPanel(
                context,
                appState.infoParadaConsultada!,
                logic,
              ),
            ),

          // 4. Spinner Global
          if (appState.mostrandoSpinnerGlobal)
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black45),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),

          // TODO: Snackbar para mensajeErrorGlobal
        ],
      ),
      // floatingActionButton: _buildFloatingActionButton(
      //   context,
      //   appState,
      //   logic,
      // ), // Podríamos quitarlo por ahora
    );
  }

  PreferredSizeWidget? _buildAppBar(
    BuildContext context,
    AppUiState appState,
    IAppLogic logic,
  ) {
    String title = 'BondiUY';
    List<Widget> actions = [];
    Widget? leading;
    bool showAppBar = true;

    switch (appState.faseActual) {
      case FaseApp.INICIAL_SIN_BUSQUEDA:
        // En esta fase, el SearchInputPanel es la UI principal para la entrada.
        // No mostramos el AppBar para dar más espacio al panel y al mapa.
        showAppBar = false;
        // title = 'Explorar'; // Ya no es necesario si no se muestra
        break;
      case FaseApp.MOSTRANDO_OPCIONES_RUTA:
        title = 'Selecciona tu Ruta';
        leading = IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => logic.usuarioCanceloBusquedaOSeleccionRuta(),
        );
        break;
      case FaseApp.VIAJE_ACTIVO_EN_CURSO:
        title = 'Tu Viaje'; // Título más corto
        leading = IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => logic.usuarioCanceloBusquedaOSeleccionRuta(),
        );
        break;
    }
    if (!showAppBar) return null;
    return AppBar(title: Text(title), actions: actions, leading: leading);
  }

  Widget _buildPhaseSpecificUI(
    BuildContext context,
    AppUiState appState,
    IAppLogic logic,
  ) {
    switch (appState.faseActual) {
      case FaseApp.INICIAL_SIN_BUSQUEDA:
        // Aquí mostramos el panel de búsqueda de origen/destino
        return const Align(
          alignment: Alignment.topCenter,
          child: SearchInputPanel(),
        );
      case FaseApp.MOSTRANDO_OPCIONES_RUTA:
        // Si el spinner global está activo (appState.mostrandoSpinnerGlobal == true),
        // el spinner se mostrará sobre cualquier cosa que este método devuelva.
        // Una vez que el spinner desaparece, debemos mostrar RouteOptionsDisplay,
        // que internamente maneja el caso de una lista vacía de opciones.
        if (appState.datosFaseOpcionesRuta != null) {
          return Align(
            alignment: Alignment.bottomCenter, // O donde prefieras
            child: RouteOptionsDisplay(
              opciones: appState.datosFaseOpcionesRuta!.opcionesDeRuta,
            ),
          );
        }
        // Este return solo se alcanzaría si datosFaseOpcionesRuta es null.
        // Si mostrandoSpinnerGlobal es true, el spinner lo cubrirá.
        // Si mostrandoSpinnerGlobal es false y datosFaseOpcionesRuta sigue siendo null,
        // podría indicar un estado anómalo o un retraso muy corto antes de que datosFaseOpcionesRuta se popule.
        return const Center(
          child: Text(
            'Cargando opciones...',
          ), // Texto más genérico para este caso improbable
        );
      case FaseApp.VIAJE_ACTIVO_EN_CURSO:
        if (appState.datosFaseViajeActivo != null) {
          return Align(
            alignment: Alignment.bottomCenter, // O donde prefieras
            child: ActiveTripDisplay(
              viajeActivo: appState.datosFaseViajeActivo!,
            ),
          );
        }
        return const Center(
          child: Text('No hay información del viaje activo.'),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // Widget? _buildFloatingActionButton(
  //   BuildContext context,
  //   AppUiState appState,
  //   IAppLogic logic,
  // ) {
  //   // Ejemplo: FAB para recentrar mapa o acción específica de fase
  //   // if (appState.faseActual == FaseApp.INICIAL_SIN_BUSQUEDA) {
  //   //   return FloatingActionButton(onPressed: () {}, child: Icon(Icons.my_location));
  //   // }
  //   return null;
  // }

  Widget _buildStopDetailsPanel(
    BuildContext context,
    InfoDetalladaParada paradaInfo,
    IAppLogic logic,
  ) {
    return Card(
      margin: const EdgeInsets.all(12.0), // Más margen
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ), // Bordes redondeados
      elevation: 6, // Más elevación
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch, // Estirar botón
          children: [
            Text(
              paradaInfo.nombreParada, // Nombre más prominente
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text('Líneas que pasan: ${paradaInfo.lineasQuePasan.join(', ')}'),
            const SizedBox(height: 12),
            Text(
              'Próximos Ómnibus:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            if (paradaInfo.etas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'No hay próximos arribos disponibles en este momento.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: 120,
                ), // Limitar altura de ETAs
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: paradaInfo.etas.length,
                  itemBuilder: (ctx, i) {
                    final eta = paradaInfo.etas[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text(
                        'Línea ${eta.linea} ${eta.destino != null ? "(${eta.destino})" : ""}: ${eta.minutosParaLlegada} min ${eta.esTiempoReal ? "(Ahora)" : "(Estimado)"}',
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => logic.usuarioDeseleccionoInformacionDeParada(),
              child: const Text("Cerrar", style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
