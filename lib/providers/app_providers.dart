import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';

// Assuming AppUiStateNotifier manages the AppUiState
class AppUiStateNotifier extends StateNotifier<AppUiState> {
  AppUiStateNotifier() : super(AppUiState.inicial());

  // Methods to update state based on IAppLogic actions
  // These methods would be called by the IAppLogic implementation
  void updateState(AppUiState newState) {
    state = newState;
  }

  // You can add more specific state update methods here if needed
}

final appUiStateProvider =
    StateNotifierProvider<AppUiStateNotifier, AppUiState>((ref) {
      return AppUiStateNotifier();
    });

// A Provider for the IAppLogic implementation
// This provider will be responsible for creating and managing the instance
// of the class that implements IAppLogic (e.g., AppLogicImplementation)
// and providing it to other parts of the app.
final appLogicProvider = Provider<IAppLogic>((ref) {
  // Implementación hipotética (reemplazar con la implementación real):
  // return AppLogicImplementation(
  //   // Pasar dependencias que AppLogicImplementation necesite
  //   ref.read(someServiceOrProvider),
  //   ref.read(anotherDependency),
  // );

  // Placeholder implementation (you'll replace this with your actual logic layer)
  // Passing the notifier to the mock logic so it can update the state
  return _MockAppLogic(ref.read(appUiStateProvider.notifier));
});

// Mock implementation of IAppLogic for placeholder purposes
class _MockAppLogic implements IAppLogic {
  final AppUiStateNotifier _appUiStateNotifier;

  _MockAppLogic(this._appUiStateNotifier);

  // Helper to update the state using the notifier
  void _updateState(AppUiState newState) {
    _appUiStateNotifier.updateState(newState);
  }

  @override
  Future<void> cargarParadasInicialesDelViewport(
    Coordenada centroActual,
    double zoomActual,
  ) async {
    print("_MockAppLogic: cargarParadasInicialesDelViewport called");
    // Simulate loading stops and updating state
    final List<InfoParadaEnMapa> simulatedStops = [
      InfoParadaEnMapa(
        idParada: '1',
        posicion: Coordenada(latitud: -34.9, longitud: -56.18),
        nombre: 'Parada 1',
      ),
      InfoParadaEnMapa(
        idParada: '2',
        posicion: Coordenada(latitud: -34.91, longitud: -56.17),
        nombre: 'Parada 2',
      ),
    ];
    _updateState(
      _appUiStateNotifier.state.copyWith(
        datosFaseInicial: EstadoFaseInicial(
          paradasVisiblesEnMapa: simulatedStops,
        ),
      ),
    );
  }

  @override
  Future<void> viewportDelMapaCambio(
    Coordenada nuevoCentro,
    double nuevoZoom,
    Coordenada esquinaSupIzq,
    Coordenada esquinaInfDer,
  ) async {
    print("_MockAppLogic: viewportDelMapaCambio called");
    // Simulate loading stops based on new viewport
    // For this mock, we'll just call the initial loading logic
    cargarParadasInicialesDelViewport(
      nuevoCentro,
      nuevoZoom,
    ); // Reuse initial loading logic
  }

  @override
  Future<void> solicitarInformacionDetalladaParada(String idParada) async {
    print(
      "_MockAppLogic: solicitarInformacionDetalladaParada called for ID: $idParada",
    );
    _updateState(
      _appUiStateNotifier.state.copyWith(
        estadoInfoParadaConsultada: EstadoSolicitud.CARGANDO,
        infoParadaConsultada: null,
      ),
    );
    await Future.delayed(Duration(seconds: 1)); // Simulate network delay
    final simulatedInfo = InfoDetalladaParada(
      idParada: idParada,
      nombreParada: 'Parada de Prueba $idParada',
      posicion: Coordenada(latitud: -34.9, longitud: -56.18), // Example coords
      lineasQuePasan: ['L1', 'L2'],
      etas: [
        EtaMostrable(linea: 'L1', minutosParaLlegada: 5, esTiempoReal: true),
        EtaMostrable(
          linea: 'L2',
          minutosParaLlegada: 10,
          esTiempoReal: false,
          destino: 'Centro',
        ),
      ],
    );
    _updateState(
      _appUiStateNotifier.state.copyWith(
        estadoInfoParadaConsultada: EstadoSolicitud.EXITO,
        infoParadaConsultada: simulatedInfo,
      ),
    );
  }

  @override
  Future<void> usuarioDeseleccionoInformacionDeParada() async {
    print("_MockAppLogic: usuarioDeseleccionoInformacionDeParada called");
    _updateState(
      _appUiStateNotifier.state.copyWith(
        clearInfoParadaConsultada: true,
        estadoInfoParadaConsultada: EstadoSolicitud.INICIAL,
      ),
    );
  }

  @override
  Future<void> usuarioEscribioEnCampoOrigen(String textoQuery) async {
    print("_MockAppLogic: usuarioEscribioEnCampoOrigen: $textoQuery");
    _updateState(
      _appUiStateNotifier.state.copyWith(
        textoInputOrigenActual: textoQuery,
        estadoSugerenciasOrigen: EstadoSolicitud.CARGANDO,
        clearSugerenciasOrigen: true,
      ),
    );
    await Future.delayed(Duration(milliseconds: 500)); // Simulate network delay
    final simulatedSuggestions = [
      SugerenciaLugar(
        id: 'ori1',
        nombreCompleto: 'Sugerencia Origen 1',
        coordenadas: Coordenada(latitud: -34.9, longitud: -56.1),
      ), // Example coords
      SugerenciaLugar(
        id: 'ori2',
        nombreCompleto: 'Sugerencia Origen 2',
        coordenadas: Coordenada(latitud: -34.8, longitud: -56.2),
      ), // Example coords
    ];
    _updateState(
      _appUiStateNotifier.state.copyWith(
        estadoSugerenciasOrigen: EstadoSolicitud.EXITO,
        sugerenciasOrigen: simulatedSuggestions,
      ),
    );
  }

  @override
  Future<void> usuarioEscribioEnCampoDestino(String textoQuery) async {
    print("_MockAppLogic: usuarioEscribioEnCampoDestino: $textoQuery");
    _updateState(
      _appUiStateNotifier.state.copyWith(
        textoInputDestinoActual: textoQuery,
        estadoSugerenciasDestino: EstadoSolicitud.CARGANDO,
        clearSugerenciasDestino: true,
      ),
    );
    await Future.delayed(Duration(milliseconds: 500)); // Simulate network delay
    final simulatedSuggestions = [
      SugerenciaLugar(
        id: 'dest1',
        nombreCompleto: 'Sugerencia Destino A',
        coordenadas: Coordenada(latitud: -34.95, longitud: -56.15),
      ), // Example coords
      SugerenciaLugar(
        id: 'dest2',
        nombreCompleto: 'Sugerencia Destino B',
        coordenadas: Coordenada(latitud: -34.85, longitud: -56.25),
      ), // Example coords
    ];
    _updateState(
      _appUiStateNotifier.state.copyWith(
        estadoSugerenciasDestino: EstadoSolicitud.EXITO,
        sugerenciasDestino: simulatedSuggestions,
      ),
    );
  }

  @override
  void seleccionarSugerenciaOrigen(SugerenciaLugar sugerencia) {
    print(
      "_MockAppLogic: seleccionarSugerenciaOrigen: ${sugerencia.nombreCompleto}",
    );
    _updateState(
      _appUiStateNotifier.state.copyWith(
        puntoOrigenParaBusqueda: sugerencia.coordenadas,
        nombreLugarOrigenSeleccionado: sugerencia.nombreCompleto,
        textoInputOrigenActual:
            sugerencia.nombreCompleto, // Update text field as well
        clearSugerenciasOrigen: true,
        estadoSugerenciasOrigen: EstadoSolicitud.INICIAL, // Reset state
      ),
    );
  }

  @override
  void seleccionarSugerenciaDestino(SugerenciaLugar sugerencia) {
    print(
      "_MockAppLogic: seleccionarSugerenciaDestino: ${sugerencia.nombreCompleto}",
    );
    _updateState(
      _appUiStateNotifier.state.copyWith(
        puntoDestinoParaBusqueda: sugerencia.coordenadas,
        nombreLugarDestinoSeleccionado: sugerencia.nombreCompleto,
        textoInputDestinoActual:
            sugerencia.nombreCompleto, // Update text field as well
        clearSugerenciasDestino: true,
        estadoSugerenciasDestino: EstadoSolicitud.INICIAL, // Reset state
      ),
    );
  }

  @override
  void limpiarSugerenciasOrigen() {
    print("_MockAppLogic: limpiarSugerenciasOrigen");
    _updateState(
      _appUiStateNotifier.state.copyWith(
        clearSugerenciasOrigen: true,
        estadoSugerenciasOrigen: EstadoSolicitud.INICIAL,
      ),
    );
  }

  @override
  void limpiarSugerenciasDestino() {
    print("_MockAppLogic: limpiarSugerenciasDestino");
    _updateState(
      _appUiStateNotifier.state.copyWith(
        clearSugerenciasDestino: true,
        estadoSugerenciasDestino: EstadoSolicitud.INICIAL,
      ),
    );
  }

  @override
  void limpiarOrigenSeleccionado() {
    print("_MockAppLogic: limpiarOrigenSeleccionado");
    _updateState(
      _appUiStateNotifier.state.copyWith(
        clearPuntoOrigenParaBusqueda: true,
        clearNombreLugarOrigenSeleccionado: true,
        textoInputOrigenActual: '',
      ),
    );
    limpiarSugerenciasOrigen(); // Also clear suggestions
  }

  @override
  void limpiarDestinoSeleccionado() {
    print("_MockAppLogic: limpiarDestinoSeleccionado");
    _updateState(
      _appUiStateNotifier.state.copyWith(
        clearPuntoDestinoParaBusqueda: true,
        clearNombreLugarDestinoSeleccionado: true,
        textoInputDestinoActual: '',
      ),
    );
    limpiarSugerenciasDestino(); // Also clear suggestions
  }

  @override
  Future<void> iniciarBusquedaDeRutas() async {
    print("_MockAppLogic: iniciarBusquedaDeRutas called");
    // Check if both origin and destination are selected
    if (_appUiStateNotifier.state.puntoOrigenParaBusqueda == null ||
        _appUiStateNotifier.state.puntoDestinoParaBusqueda == null) {
      print("_MockAppLogic: Origen o destino no seleccionados.");
      _updateState(
        _appUiStateNotifier.state.copyWith(
          mensajeErrorGlobal: 'Por favor, selecciona origen y destino.',
        ),
      );
      return;
    }

    _updateState(
      _appUiStateNotifier.state.copyWith(
        mostrandoSpinnerGlobal: true,
        mensajeErrorGlobal: null, // Clear previous errors
      ),
    );

    await Future.delayed(Duration(seconds: 2)); // Simulate planning time

    // Simulate successful route planning results
    final simulatedRoutes = [
      // Placeholder consolidated routes based on the contract
      OpcionDeRutaMostrable(
        idOpcion: 'route1',
        duracionTotalSegundos: 1800, // 30 min
        horaLlegadaEstimada: DateTime.now().add(Duration(minutes: 30)),
        secuenciaModosIconos: [
          TipoTramoViaje.CAMINAR,
          TipoTramoViaje.VIAJE_EN_BUS,
          TipoTramoViaje.CAMINAR,
        ],
        distanciaTotalCaminataMetros: 500,
        tiempoTotalEsperaBusSegundos: 300, // 5 min
        esRecomendada: true,
        score: 100,
        tramosParaPreview: [
          // Placeholder tramos for preview
          TramoViajeMostrable(
            idTramo: 'walk1',
            tipo: TipoTramoViaje.CAMINAR,
            descripcion: 'Caminar a parada X',
            duracionEstimadaSegundos: 300, // 5 min
            distanciaMetros: 500,
            geometriaPolilinea: [
              Coordenada(latitud: -34.9, longitud: -56.1),
              Coordenada(latitud: -34.905, longitud: -56.105),
            ], // Example coords
          ),
          TramoViajeMostrable(
            idTramo: 'wait1',
            tipo: TipoTramoViaje.ESPERAR_BUS,
            descripcion: 'Esperar bus 145',
            duracionEstimadaSegundos: 300, // 5 min
            posicionPunto: Coordenada(latitud: -34.905, longitud: -56.105),
          ),
          TramoViajeMostrable(
            idTramo: 'bus1',
            tipo: TipoTramoViaje.VIAJE_EN_BUS,
            descripcion: 'Bus 145 a Y',
            duracionEstimadaSegundos: 900, // 15 min
            nombreLineaBus: '145',
            geometriaPolilinea: [
              Coordenada(latitud: -34.905, longitud: -56.105),
              Coordenada(latitud: -34.92, longitud: -56.12),
            ], // Example coords
          ),
          TramoViajeMostrable(
            idTramo: 'walk2',
            tipo: TipoTramoViaje.CAMINAR,
            descripcion: 'Caminar a destino',
            duracionEstimadaSegundos: 300, // 5 min
            distanciaMetros: 300,
            geometriaPolilinea: [
              Coordenada(latitud: -34.92, longitud: -56.12),
              Coordenada(latitud: -34.925, longitud: -56.125),
            ], // Example coords
          ),
        ],
      ),
      OpcionDeRutaMostrable(
        idOpcion: 'route2',
        duracionTotalSegundos: 2100, // 35 min
        horaLlegadaEstimada: DateTime.now().add(Duration(minutes: 35)),
        secuenciaModosIconos: [
          TipoTramoViaje.CAMINAR,
          TipoTramoViaje.VIAJE_EN_BUS,
          TipoTramoViaje.CAMINAR,
        ],
        distanciaTotalCaminataMetros: 700,
        tiempoTotalEsperaBusSegundos: 180, // 3 min
        esRecomendada: false,
        score: 80,
        tramosParaPreview: [
          // Placeholder tramos for preview (slightly different)
          TramoViajeMostrable(
            idTramo: 'walkA',
            tipo: TipoTramoViaje.CAMINAR,
            descripcion: 'Caminar a parada Z',
            duracionEstimadaSegundos: 420, // 7 min
            distanciaMetros: 700,
            geometriaPolilinea: [
              Coordenada(latitud: -34.9, longitud: -56.1),
              Coordenada(latitud: -34.91, longitud: -56.11),
            ], // Example coords
          ),
          TramoViajeMostrable(
            idTramo: 'waitA',
            tipo: TipoTramoViaje.ESPERAR_BUS,
            descripcion: 'Esperar bus 103',
            duracionEstimadaSegundos: 180, // 3 min
            posicionPunto: Coordenada(latitud: -34.91, longitud: -56.11),
          ),
          TramoViajeMostrable(
            idTramo: 'busA',
            tipo: TipoTramoViaje.VIAJE_EN_BUS,
            descripcion: 'Bus 103 a W',
            duracionEstimadaSegundos: 1200, // 20 min
            nombreLineaBus: '103',
            geometriaPolilinea: [
              Coordenada(latitud: -34.91, longitud: -56.11),
              Coordenada(latitud: -34.93, longitud: -56.13),
            ], // Example coords
          ),
          TramoViajeMostrable(
            idTramo: 'walkB',
            tipo: TipoTramoViaje.CAMINAR,
            descripcion: 'Caminar a destino',
            duracionEstimadaSegundos: 300, // 5 min
            distanciaMetros: 300,
            geometriaPolilinea: [
              Coordenada(latitud: -34.93, longitud: -56.13),
              Coordenada(latitud: -34.935, longitud: -56.135),
            ], // Example coords
          ),
        ],
      ),
    ];

    _updateState(
      _appUiStateNotifier.state.copyWith(
        faseActual: FaseApp.MOSTRANDO_OPCIONES_RUTA,
        datosFaseOpcionesRuta: EstadoFaseOpcionesRuta(
          opcionesDeRuta: simulatedRoutes,
        ),
        clearDatosFaseInicial: true, // Clear initial phase data
        mostrandoSpinnerGlobal: false,
      ),
    );
  }

  @override
  Future<void> usuarioCanceloBusquedaOSeleccionRuta() async {
    print("_MockAppLogic: usuarioCanceloBusquedaOSeleccionRuta called");
    _updateState(
      _appUiStateNotifier.state.copyWith(
        faseActual: FaseApp.INICIAL_SIN_BUSQUEDA,
        datosFaseInicial: EstadoFaseInicial(
          paradasVisiblesEnMapa: [],
        ), // Maybe reload stops for current viewport?
        clearDatosFaseOpcionesRuta: true,
        clearPuntoOrigenParaBusqueda: true, // Clear selected places
        clearPuntoDestinoParaBusqueda: true,
        clearNombreLugarOrigenSeleccionado: true,
        clearNombreLugarDestinoSeleccionado: true,
        textoInputOrigenActual: '', // Clear input text
        textoInputDestinoActual: '',
        clearSugerenciasOrigen: true, // Clear suggestions
        clearSugerenciasDestino: true,
        mostrandoSpinnerGlobal: false,
        mensajeErrorGlobal: null,
        mensajeInfoGlobal: null,
      ),
    );
  }

  @override
  void seleccionarOpcionDeRutaParaPrevisualizar(String idOpcionRuta) {
    print(
      "_MockAppLogic: seleccionarOpcionDeRutaParaPrevisualizar: $idOpcionRuta",
    );
    _updateState(
      _appUiStateNotifier.state.copyWith(
        idOpcionRutaPrevisualizada: idOpcionRuta,
      ),
    );
  }

  @override
  void limpiarSeleccionDeRutaPrevisualizada() {
    print("_MockAppLogic: limpiarSeleccionDeRutaPrevisualizada");
    _updateState(
      _appUiStateNotifier.state.copyWith(clearIdOpcionRutaPrevisualizada: true),
    );
  }

  @override
  void confirmarOpcionDeRutaEIniciarViaje(String idOpcionRuta) {
    print("_MockAppLogic: confirmarOpcionDeRutaEIniciarViaje: $idOpcionRuta");
    // Find the selected route from the options
    final selectedOption = _appUiStateNotifier
        .state
        .datosFaseOpcionesRuta
        ?.opcionesDeRuta
        .firstWhere(
          (opt) => opt.idOpcion == idOpcionRuta,
          orElse:
              () =>
                  throw Exception(
                    "Selected route option not found",
                  ), // Should not happen in a real app
        );

    if (selectedOption != null) {
      _updateState(
        _appUiStateNotifier.state.copyWith(
          faseActual: FaseApp.VIAJE_ACTIVO_EN_CURSO,
          datosFaseViajeActivo: EstadoFaseViajeActivo(
            idViajeActivoConfirmado: idOpcionRuta, // Reuse id
            tramosDelViaje:
                selectedOption
                    .tramosParaPreview, // Use tramos for the active journey
            opcionDeRutaSeleccionada: selectedOption,
          ),
          clearDatosFaseOpcionesRuta: true, // Clear options data
          clearIdOpcionRutaPrevisualizada: true, // Clear preview state
          clearPuntoOrigenParaBusqueda: true, // Clear search places
          clearPuntoDestinoParaBusqueda: true,
          clearNombreLugarOrigenSeleccionado: true,
          clearNombreLugarDestinoSeleccionado: true,
          textoInputOrigenActual: '', // Clear input text
          textoInputDestinoActual: '',
          clearSugerenciasOrigen: true, // Clear suggestions
          clearSugerenciasDestino: true,
          mostrandoSpinnerGlobal: false,
        ),
      );
    }
  }

  @override
  Future<void> iniciarSeguimientoBusTiempoReal({
    required String idViajeActivo,
    required String idTramoBus,
  }) async {
    print(
      "_MockAppLogic: iniciarSeguimientoBusTiempoReal called for journey $idViajeActivo, leg $idTramoBus",
    );
    _updateState(
      _appUiStateNotifier.state.copyWith(
        datosFaseViajeActivo: _appUiStateNotifier.state.datosFaseViajeActivo
            ?.copyWith(
              idTramoBusEnSeguimiento: idTramoBus,
              seguimientoBusRealDisponibleEnTramoActual: true,
            ),
      ),
    );
    // Simulate receiving real-time updates
    await Future.delayed(Duration(seconds: 5));
    _updateState(
      _appUiStateNotifier.state.copyWith(
        datosFaseViajeActivo: _appUiStateNotifier.state.datosFaseViajeActivo
            ?.copyWith(
              posicionActualBusReal: Coordenada(
                latitud: -34.915,
                longitud: -56.115,
              ), // Simulate bus moving - Example coords
              minutosParaLlegadaBusReal: 3, // Simulate updated ETA
            ),
      ),
    );
  }

  @override
  Future<void> detenerSeguimientoBusTiempoReal() async {
    print("_MockAppLogic: detenerSeguimientoBusTiempoReal called");
    _updateState(
      _appUiStateNotifier.state.copyWith(
        datosFaseViajeActivo: _appUiStateNotifier.state.datosFaseViajeActivo
            ?.copyWith(
              clearIdTramoBusEnSeguimiento: true,
              clearPosicionActualBusReal: true,
              clearMinutosParaLlegadaBusReal: true,
              seguimientoBusRealDisponibleEnTramoActual: false,
            ),
      ),
    );
  }

  @override
  Future<void> usuarioSeleccionoTramoDelViaje(
    String idViajeActivo,
    String idTramoSeleccionado,
  ) async {
    print(
      "_MockAppLogic: usuarioSeleccionoTramoDelViaje called for journey $idViajeActivo, leg $idTramoSeleccionado",
    );
    // TODO: Implement logic to find the index of the selected leg and update state
    _updateState(
      _appUiStateNotifier.state.copyWith(
        // Update state to reflect selected leg index if needed
      ),
    );
    // If the selected leg is a bus leg, initiate tracking
    // Example check (you'd need to find the actual leg object):
    // final selectedLeg = _appUiStateNotifier.state.datosFaseViajeActivo?.tramosDelViaje.firstWhere((l) => l.idTramo == idTramoSeleccionado);
    // if (selectedLeg?.tipo == TipoTramoViaje.VIAJE_EN_BUS && selectedLeg?.idTramoBusEnSeguimiento != null) {
    //   iniciarSeguimientoBusTiempoReal(idViajeActivo: idViajeActivo, idTramoBus: selectedLeg!.idTramoBusEnSeguimiento!);
    // }
  }

  // --- Acciones Generales ---
  @override
  Future<void> limpiarMensajeDeErrorGlobal() async {
    print("_MockAppLogic: limpiarMensajeDeErrorGlobal called");
    _updateState(
      _appUiStateNotifier.state.copyWith(clearMensajeErrorGlobal: true),
    );
  }

  // --- Acciones Adicionales (Asegurar que estén) ---
  @override
  void pantallaDeInicioCargada() {
    print("_MockAppLogic: pantallaDeInicioCargada called");
    // Simulate initial stop loading
    cargarParadasInicialesDelViewport(
      Coordenada(latitud: -34.9, longitud: -56.16),
      12.0,
    ); // Example initial view
  }

  @override
  void usuarioMovioMapaManualente(Coordenada nuevoCentro, double nuevoZoom) {
    print(
      "_MockAppLogic: usuarioMovioMapaManualente: center=$nuevoCentro, zoom=$nuevoZoom",
    );
    // TODO: Potentially trigger reloading stops for the new viewport here or on idle
  }

  @override
  void usuarioHizoTapEnMapa(Coordenada tocada) {
    print("_MockAppLogic: usuarioHizoTapEnMapa: $tocada");
    // TODO: Implement logic to check if a stop was tapped, and if so, call solicitarInformacionDetalladaParada
    // For now, deselect any active stop details
    usuarioDeseleccionoInformacionDeParada();
  }

  @override
  void usuarioHizoTapEnParadaDelMapa(String idParada) {
    print("_MockAppLogic: usuarioHizoTapEnParadaDelMapa: $idParada");
    solicitarInformacionDetalladaParada(idParada);
  }

  @override
  void cerrarDetallesDeParada() {
    print("_MockAppLogic: cerrarDetallesDeParada called");
    usuarioDeseleccionoInformacionDeParada();
  }

  @override
  void navegarAAnteriorPasoInstrucciones() {
    print("_MockAppLogic: navegarAAnteriorPasoInstrucciones called");
    // TODO: Implement logic to decrement currentLegIndex in state
  }

  @override
  void navegarASiguientePasoInstrucciones() {
    print("_MockAppLogic: navegarASiguientePasoInstrucciones called");
    // TODO: Implement logic to increment currentLegIndex in state
  }

  @override
  void usuarioSeleccionoPasoInstrucciones(int indicePaso) {
    print("_MockAppLogic: usuarioSeleccionoPasoInstrucciones: $indicePaso");
    // TODO: Implement logic to set currentLegIndex in state
  }

  @override
  void usuarioPresionoSeguirEsteViaje() {
    print("_MockAppLogic: usuarioPresionoSeguirEsteViaje called");
    // This action is already handled by confirmarOpcionDeRutaEIniciarViaje
    // or might be used in a different UI context?
  }

  @override
  void detenerSeguimientoActivo() {
    print("_MockAppLogic: detenerSeguimientoActivo called");
    // This likely means stopping bus tracking if active
    detenerSeguimientoBusTiempoReal();
    // And maybe returning to initial phase?
    usuarioCanceloBusquedaOSeleccionRuta(); // Or a different action to end journey
  }
}
