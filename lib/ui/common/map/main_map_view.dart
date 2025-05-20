import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bondi_uy/backend/providers/app_logic_provider.dart';
// TODO: Importar librería de Mapbox una vez que la identifiquemos y configuremos.

class MainMapView extends ConsumerStatefulWidget {
  const MainMapView({super.key});

  @override
  ConsumerState<MainMapView> createState() => _MainMapViewState();
}

class _MainMapViewState extends ConsumerState<MainMapView> {
  // TODO: Aquí iría el controlador del mapa de Mapbox
  // MapboxMapController? _mapController;

  @override
  void initState() {
    super.initState();
    // TODO: Cualquier inicialización del mapa o lógica que deba ocurrir una vez.
    // Por ejemplo, obtener la ubicación inicial y paradas si es la primera vez.
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   final logic = ref.read(appLogicProvider.notifier);
    //   // Suponiendo que tenemos una forma de saber si es la carga inicial
    //   // logic.cargarParadasInicialesDelViewport(centroInicial, zoomInicial);
    // });
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appLogicProvider);
    final logic = ref.read(appLogicProvider.notifier);

    // TODO: Aquí construiríamos el widget del mapa de Mapbox
    // y le pasaríamos los datos del appState para dibujar:
    // - appState.datosFaseInicial?.paradasVisiblesEnMapa
    // - appState.datosFaseOpcionesRuta?.opcionesDeRuta (para polilíneas de ruta)
    // - appState.datosFaseViajeActivo?.tramosDelViaje (para polilínea del viaje activo)
    // - appState.datosFaseViajeActivo?.posicionActualBusReal
    // - etc.

    // Ejemplo de cómo el mapa podría notificar cambios en el viewport:
    // onMapIdle: (CameraPosition position) {
    //   logic.viewportDelMapaCambio(
    //     Coordenada(latitud: position.target.latitude, longitud: position.target.longitude),
    //     position.zoom,
    //     // TODO: Calcular esquinas del viewport
    //     Coordenada(latitud: 0, longitud: 0), // Placeholder
    //     Coordenada(latitud: 0, longitud: 0), // Placeholder
    //   );
    // }

    // Ejemplo de cómo manejar taps en marcadores de parada (si el SDK lo permite directamente)
    // onStopMarkerTapped: (String stopId) {
    //   logic.solicitarInformacionDetalladaParada(stopId);
    // }

    return Container(
      color:
          Colors.lightBlue[100], // Color de fondo mientras no está el mapa real
      child: const Center(
        child: Text(
          'Mapa Principal Aquí (MainMapView)\nMostrando paradas, rutas, etc. basado en AppUiState',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
