import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../contrato_ui/app_ui_state.dart';
import '../services/montevideo_api_service_adapter.dart';
import '../services/itinerary_planning_service_adapter.dart';
import '../services/geocoding_service_adapter.dart';
import 'package:collection/collection.dart';
import '../../journey/journey_manager.dart';
import '../../journey/journey_step_state.dart';
import '../../devtools/trip_simulator.dart';
import '../../ui/app_host.dart';
import '../../map_manager/map_bus_realtime.dart';
import '../../utils/geometry_utils.dart';
import 'helpers/validation_helpers.dart';
import 'helpers/logging_helpers.dart';
import 'helpers/journey_event_handlers.dart';
import 'package:geolocator/geolocator.dart';

// El StateNotifierProvider para nuestro AppLogicNotifier.
// La UI usará este provider para acceder al estado (AppUiState) y a las acciones (métodos de AppLogicNotifier).
final geocodingServiceProvider = Provider<GeocodingServiceAdapter>((ref) {
  return GeocodingServiceAdapter();
});

final appLogicProvider = StateNotifierProvider<AppLogicNotifier, AppUiState>((
  ref,
) {
  final montevideoApiService = ref.watch(montevideoApiServiceProvider);
  final itineraryPlanningService = ref.watch(itineraryPlanningServiceProvider);
  final geocodingService = ref.watch(geocodingServiceProvider);
  return AppLogicNotifier(
    ref,
    montevideoApiService,
    itineraryPlanningService,
    geocodingService,
  );
});

const int _SEGUIMIENTO_BUS_INTERVALO_SEGUNDOS = 10;
// Debounce para las sugerencias de geocodificación
const int _GECODING_SUGGESTIONS_DEBOUNCE_MS = 300;

class AppLogicNotifier extends StateNotifier<AppUiState> implements IAppLogic {
  final Ref _ref;
  final MontevideoApiServiceAdapterBase _montevideoApiService;
  final ItineraryPlanningServiceAdapterBase _itineraryPlanningService;
  final GeocodingServiceAdapter _geocodingService;
  final bool isTestMode;
  Timer? _seguimientoBusTimer;
  Timer? _destinoDebounceTimer;
  Timer? _waitingForBusFallbackTimer; // Para detectar subida sin ETA

  // Journey Manager - Encapsula toda la lógica de navegación automática
  JourneyManager? _journeyManager;

  // Journey Event Handlers - Maneja eventos de JourneyManager
  late final JourneyEventHandlers _journeyEventHandlers;

  // Flag para controlar animaciones
  bool _animationsEnabled = true;

  // Dev recorder para grabar/reproducir eventos de ubicación y bus
  TripSimulator? _tripSimulator;
  DateTime? _lastDevBusPush;
  Coordenada? _lastDevBusPos;

  AppLogicNotifier(
    this._ref,
    this._montevideoApiService,
    this._itineraryPlanningService,
    this._geocodingService, {
    this.isTestMode = false,
  }) : super(AppUiState.inicial()) {
    // Inicializar event handlers
    _journeyEventHandlers = JourneyEventHandlers(
      ref: _ref,
      getState: () => state,
      setState: (newState) => state = newState,
    );

    // Obtener ubicación inicial del usuario
    _obtenerUbicacionInicial();
  }

  // Sobrescribir el setter de 'state' para manejar transiciones y limpiar recursos.
  @override
  set state(AppUiState newState) {
    final oldState = state;
    super.state = newState;

    // Solo logear cambios importantes de fase, no todos los cambios de estado
    if (oldState.faseActual != newState.faseActual) {
      print(
        "[AppUiState] Fase cambiada: ${oldState.faseActual} → ${newState.faseActual}",
      );
    }

    // Limpiar timer de seguimiento automáticamente si se sale de la fase de viaje activo
    _handlePhaseTransition(oldState, newState);
  }

  // Método privado para manejar transiciones de fase y limpiar recursos
  void _handlePhaseTransition(AppUiState oldState, AppUiState newState) {
    // Si salimos de la fase de viaje activo, detener el sondeo automáticamente
    if (oldState.faseActual == FaseApp.VIAJE_ACTIVO_EN_CURSO &&
        newState.faseActual != FaseApp.VIAJE_ACTIVO_EN_CURSO) {
      print(
        "[AppLogicNotifier] Saliendo de fase VIAJE_ACTIVO_EN_CURSO, deteniendo timer de seguimiento",
      );
      _seguimientoBusTimer?.cancel();
      _seguimientoBusTimer = null;
    }
  }

  // --- Implementación de IAppLogic ---

  /// Obtener ubicación inicial del usuario
  Future<void> _obtenerUbicacionInicial() async {
    try {
      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print("[AppLogic] ⚠️ Permisos de ubicación denegados");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print("[AppLogic] ⚠️ Permisos de ubicación denegados permanentemente");
        return;
      }

      // Obtener ubicación actual
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      final ubicacion = Coordenada(
        latitud: position.latitude,
        longitud: position.longitude,
      );

      print("[AppLogic] ✅ Ubicación inicial obtenida: ${ubicacion.latitud}, ${ubicacion.longitud}");

      if (mounted) {
        state = state.copyWith(ubicacionActualUsuario: ubicacion);
      }
    } catch (e) {
      print("[AppLogic] ❌ Error obteniendo ubicación inicial: $e");
    }
  }

  @override
  Future<void> cargarParadasInicialesDelViewport(
    Coordenada centroActual,
    double zoomActual,
  ) async {
    state = state.copyWith(mostrandoSpinnerGlobal: true);
    print(
      "[AppLogicNotifier] Cargando paradas iniciales para viewport: Centro: ${centroActual.latitud},${centroActual.longitud} Zoom: $zoomActual",
    );

    try {
      // 1. Llamar al servicio adaptado para obtener TODAS las paradas.
      final List<InfoParadaEnMapa> todasLasParadas =
          await _montevideoApiService.getAllStops();
      print(
        "[AppLogicNotifier] Todas las paradas obtenidas del servicio: ${todasLasParadas.length}",
      );

      // 2. Filtrar paradas por viewport
      //    Este es un filtrado muy básico y debería ser reemplazado por uno geométrico real.
      //    Idealmente, esta lógica de filtrado viviría en una clase de utilidad o
      //    incluso podría ser parte de una consulta más inteligente a `getAllStops` si soportara bounding box.
      final double latitudBuffer =
          0.005 * (1 / (zoomActual > 0 ? zoomActual / 10 : 0.1));
      final double longitudBuffer =
          0.01 * (1 / (zoomActual > 0 ? zoomActual / 10 : 0.1));

      final paradasFiltradas =
          todasLasParadas.where((parada) {
            return (parada.posicion.latitud >=
                    centroActual.latitud - latitudBuffer &&
                parada.posicion.latitud <=
                    centroActual.latitud + latitudBuffer &&
                parada.posicion.longitud >=
                    centroActual.longitud - longitudBuffer &&
                parada.posicion.longitud <=
                    centroActual.longitud + longitudBuffer);
          }).toList();

      print(
        "[AppLogicNotifier] Paradas filtradas para viewport: ${paradasFiltradas.length}",
      );

      if (mounted) {
        state = state.copyWith(
          faseActual: FaseApp.INICIAL_SIN_BUSQUEDA,
          // Actualizar el estado con las paradas filtradas y también guardar todas las paradas
          // para poder buscar detalles de paradas que no estén actualmente en el viewport
          // si fuera necesario, o simplificar la búsqueda de detalles.
          // Por ahora, solo guardamos las filtradas en datosFaseInicial.
          // Si se quisiera consultar una parada fuera del viewport actual, se necesitaría getAllStops() de nuevo
          // o almacenar `todasLasParadas` en el estado global (lo cual podría ser mucho).
          // La solución más simple es que la UI solo permita seleccionar paradas visibles.
          datosFaseInicial: EstadoFaseInicial(
            paradasVisiblesEnMapa: paradasFiltradas,
          ),
          mostrandoSpinnerGlobal: false,
        );
        print("[AppLogicNotifier] Paradas filtradas cargadas en el estado.");
      }
    } catch (e, s) {
      print("[AppLogicNotifier] Error cargando paradas iniciales: $e\n$s");
      if (mounted) {
        state = state.copyWith(
          mostrandoSpinnerGlobal: false,
          mensajeErrorGlobal: "Error al cargar paradas en el mapa.",
        );
      }
    }
  }

  @override
  Future<void> viewportDelMapaCambio(
    Coordenada nuevoCentro,
    double nuevoZoom,
    Coordenada esquinaSupIzq,
    Coordenada esquinaInfDer,
  ) async {
    print(
      "[AppLogicNotifier] Viewport cambió. Nuevo Centro: ${nuevoCentro.latitud},${nuevoCentro.longitud} Zoom: $nuevoZoom",
    );
    // TODO: Implementar lógica con debounce y umbral.
    await cargarParadasInicialesDelViewport(nuevoCentro, nuevoZoom);
  }

  @override
  Future<void> solicitarInformacionDetalladaParada(String idParada) async {
    // Buscar la información de la parada (nombre, posición) desde el estado actual.
    // Esto asume que la parada solicitada está entre las 'paradasVisiblesEnMapa'.
    InfoParadaEnMapa? paradaInfo;
    if (state.datosFaseInicial != null) {
      try {
        paradaInfo = state.datosFaseInicial!.paradasVisiblesEnMapa
            .firstWhereOrNull((p) => p.idParada == idParada);
      } catch (e) {
        // No encontrada en las visibles, lo cual podría ser un problema de flujo si se permite seleccionar
        // paradas no visibles, o si el viewport cambió y la lista no se actualizó aún.
        print(
          "[AppLogicNotifier_WARN] Parada con ID $idParada no encontrada en paradasVisiblesEnMapa. No se puede obtener nombre/posición.",
        );
      }
    }

    if (paradaInfo == null) {
      print(
        "[AppLogicNotifier_ERROR] No se pudo obtener la información base (nombre/posición) de la parada $idParada para solicitar ETAs.",
      );
      if (mounted) {
        state = state.copyWith(
          estadoInfoParadaConsultada: EstadoSolicitud.ERROR,
          clearInfoParadaConsultada: true, // Limpia cualquier dato anterior
          mensajeErrorGlobal:
              "Error interno: No se encontró info de la parada $idParada.",
        );
      }
      return;
    }

    state = state.copyWith(
      estadoInfoParadaConsultada: EstadoSolicitud.CARGANDO,
      clearInfoParadaConsultada: true,
    );
    print(
      "[AppLogicNotifier] Solicitando info detallada para parada ID: $idParada, Nombre: ${paradaInfo.nombre}, Pos: ${paradaInfo.posicion.latitud},${paradaInfo.posicion.longitud}",
    );

    try {
      // Usar paradaInfo.nombre y paradaInfo.posicion
      final InfoDetalladaParada? detalles = await _montevideoApiService
          .getStopDetailsWithEta(
            idParada,
            paradaInfo.nombre,
            paradaInfo.posicion,
          );

      if (mounted) {
        if (detalles != null) {
          state = state.copyWith(
            infoParadaConsultada: detalles,
            estadoInfoParadaConsultada: EstadoSolicitud.EXITO,
          );
          print(
            "[AppLogicNotifier] Info detallada para parada $idParada cargada desde servicio.",
          );
        } else {
          // Esto podría ocurrir si el servicio devuelve null (ej. API falla catastróficamente)
          // aunque getStopDetailsWithEta ahora debería devolver un objeto InfoDetalladaParada incluso sin ETAs.
          // Así que este 'else' es menos probable para 'detalles == null'.
          // Podría ser más relevante si el servicio lanzara una excepción que no capturamos arriba.
          state = state.copyWith(
            estadoInfoParadaConsultada: EstadoSolicitud.ERROR,
            mensajeErrorGlobal:
                "No se encontró información para la parada $idParada (servicio devolvió null).",
          );
          print(
            "[AppLogicNotifier_ERROR] Error: Servicio devolvió null para detalles de parada $idParada.",
          );
        }
      }
    } catch (e, s) {
      print(
        "[AppLogicNotifier_ERROR] Excepción solicitando info detallada parada: $e\n$s",
      );
      if (mounted) {
        state = state.copyWith(
          estadoInfoParadaConsultada: EstadoSolicitud.ERROR,
          mensajeErrorGlobal: "Error al obtener detalles de la parada.",
        );
      }
    }
  }

  @override
  Future<void> iniciarBusquedaDeRutas() async {
    // Log inicio de búsqueda
    LoggingHelpers.logSearchStart(
      currentPhase: state.faseActual,
      currentLocation: state.ubicacionActualUsuario,
      destination: state.puntoDestinoParaBusqueda,
    );

    // Validar requisitos usando helper
    final errorValidacion = ValidationHelpers.validateSearchRequirements(
      currentLocation: state.ubicacionActualUsuario,
      destination: state.puntoDestinoParaBusqueda,
    );

    if (errorValidacion != null) {
      LoggingHelpers.logValidationFailed(
        locationNull: state.ubicacionActualUsuario == null,
        destinationNull: state.puntoDestinoParaBusqueda == null,
      );

      if (mounted) {
        state = state.copyWith(mensajeErrorGlobal: errorValidacion);
      }
      return;
    }

    final Coordenada origenCoords = state.ubicacionActualUsuario!;
    final String origenNombreFinal = "Mi ubicación";
    final Coordenada destinoCoords = state.puntoDestinoParaBusqueda!;
    final String destinoNombreFinal =
        state.nombreLugarDestinoSeleccionado ?? "Destino";

    // Cambiar a fase de búsqueda
    if (mounted) {
      state = state.copyWith(
        faseActual: FaseApp.MOSTRANDO_OPCIONES_RUTA,
        mostrandoSpinnerGlobal: true,
        clearDatosFaseInicial: true,
        datosFaseOpcionesRuta: EstadoFaseOpcionesRuta(opcionesDeRuta: []),
        clearInfoParadaConsultada: true,
        estadoInfoParadaConsultada: EstadoSolicitud.INICIAL,
        clearIdOpcionRutaPrevisualizada: true,
      );
    }

    try {
      // Llamar servicio de planificación
      final List<OpcionDeRutaMostrable> opciones =
          await _itineraryPlanningService.planRoute(
            origenCoords: origenCoords,
            origenNombre: origenNombreFinal,
            destinoCoords: destinoCoords,
            destinoNombre: destinoNombreFinal,
          );

      LoggingHelpers.logSearchSuccess(opciones.length);

      if (mounted) {
        print("[ROUTE_SEARCH] 🎯 Seleccionando opción por defecto...");
        OpcionDeRutaMostrable? primeraOpcion;
        if (opciones.isNotEmpty) {
          primeraOpcion = opciones.firstWhere(
            (opt) => opt.esRecomendada,
            orElse: () => opciones.first,
          );
          print(
            "[ROUTE_SEARCH] 🎯 Opción seleccionada: ${primeraOpcion.idOpcion} (recomendada: ${primeraOpcion.esRecomendada})",
          );
        } else {
          print("[ROUTE_SEARCH] ⚠️ No se encontraron opciones de ruta");
        }

        state = state.copyWith(
          datosFaseOpcionesRuta: EstadoFaseOpcionesRuta(
            opcionesDeRuta: opciones,
          ),
          idOpcionRutaPrevisualizada: primeraOpcion?.idOpcion,
          mostrandoSpinnerGlobal: false,
        );
        print(
          "[ROUTE_SEARCH] ✅ Estado actualizado - mostrando carousel de opciones",
        );
        print(
          "[ROUTE_SEARCH] 📱 App muestra carousel con ${opciones.length} opciones",
        );
        print(
          "[ROUTE_SEARCH] 🗺️ Mapa muestra preview con zoom centrado para: ${primeraOpcion?.idOpcion}",
        );
        print("[ROUTE_SEARCH] ✅ === FIN BÚSQUEDA (ÉXITO) ====");
      }
    } catch (e, s) {
      print("[ROUTE_SEARCH] ❌ === EXCEPCIÓN EN BÚSQUEDA ====");
      print("[ROUTE_SEARCH] ❌ Error: $e");
      print("[ROUTE_SEARCH] ❌ Stack: $s");
      print("[ROUTE_SEARCH] ❌ Tipo: ${e.runtimeType}");
      if (mounted) {
        state = state.copyWith(
          mostrandoSpinnerGlobal: false,
          mensajeErrorGlobal: "Error al planificar la ruta.",
          // Regresar a la fase inicial si hay un error grave en la planificación
          faseActual: FaseApp.INICIAL_SIN_BUSQUEDA,
          datosFaseInicial: EstadoFaseInicial(
            paradasVisiblesEnMapa:
                state.datosFaseInicial?.paradasVisiblesEnMapa ?? [],
          ), // Restaurar paradas si es posible
          clearDatosFaseOpcionesRuta: true,
        );
        print("[ROUTE_SEARCH] ❌ Estado regresado a INICIAL_SIN_BUSQUEDA");
      }
      print("[ROUTE_SEARCH] ❌ === FIN BÚSQUEDA (ERROR) ====");
    }
  }

  @override
  Future<void> usuarioCanceloBusquedaOSeleccionRuta() async {
    _seguimientoBusTimer?.cancel();
    if (mounted) {
      // GRANDMA FIRST: Solo mantener destino, el origen siempre es ubicación actual
      final destinoActual = state.puntoDestinoParaBusqueda;
      final nombreDestinoActual = state.nombreLugarDestinoSeleccionado;
      final textoInputDestinoActual = state.textoInputDestinoActual;

      final paradasVisibles =
          state.datosFaseInicial?.paradasVisiblesEnMapa ?? [];

      state = AppUiState.inicial().copyWith(
        // Restaurar paradas visibles
        datosFaseInicial: EstadoFaseInicial(
          paradasVisiblesEnMapa: paradasVisibles,
        ),
        // Mantener destino si existe
        puntoDestinoParaBusqueda: destinoActual,
        nombreLugarDestinoSeleccionado: nombreDestinoActual,
        textoInputDestinoActual: textoInputDestinoActual,
      );
      print("[AppLogicNotifier] Búsqueda o selección de ruta cancelada.");
    }
  }

  @override
  Future<void> usuarioSeleccionoTramoDelViaje(
    String idViajeActivo,
    String idTramoSeleccionado,
  ) async {
    print(
      "[AppLogicNotifier] Usuario seleccionó tramo: $idTramoSeleccionado del viaje $idViajeActivo",
    );
    if (state.faseActual != FaseApp.VIAJE_ACTIVO_EN_CURSO ||
        state.datosFaseViajeActivo == null ||
        state.datosFaseViajeActivo!.idViajeActivoConfirmado != idViajeActivo) {
      print(
        "[AppLogicNotifier_ERROR] No se puede seleccionar tramo si no hay un viaje activo o el ID no coincide.",
      );
      return;
    }

    TramoViajeMostrable? tramoSeleccionado;
    try {
      tramoSeleccionado = state.datosFaseViajeActivo!.tramosDelViaje.firstWhere(
        (t) => t.idTramo == idTramoSeleccionado,
      );
    } catch (e) {
      print(
        "[AppLogicNotifier_ERROR] Tramo seleccionado con ID $idTramoSeleccionado no encontrado en el viaje activo.",
      );
      return;
    }

    // Actualizar el estado con el nuevo tramo seleccionado (implícito, ya que la UI lo gestionará basado en el id)
    // La lógica principal aquí es gestionar el inicio/detención del seguimiento en tiempo real.

    if (tramoSeleccionado.tipo == TipoTramoViaje.VIAJE_EN_BUS &&
        tramoSeleccionado.idParadaOrigenTramoBus != null &&
        tramoSeleccionado.nombreLineaBus != null) {
      print(
        "[AppLogicNotifier] El tramo seleccionado es un bus. Iniciando/actualizando seguimiento.",
      );
      // Llamamos a iniciarSeguimiento, que internamente cancela timers anteriores.
      await iniciarSeguimientoBusTiempoReal(
        idViajeActivo: idViajeActivo,
        idTramoBus: idTramoSeleccionado,
      );
    } else {
      print(
        "[AppLogicNotifier] El tramo seleccionado no es un bus o falta información. Deteniendo seguimiento.",
      );
      await detenerSeguimientoBusTiempoReal();
      // Adicionalmente, asegurar que el estado refleje que no hay seguimiento para este tramo no-bus.
      if (mounted && state.datosFaseViajeActivo != null) {
        state = state.copyWith(
          datosFaseViajeActivo: state.datosFaseViajeActivo!.copyWith(
            idTramoBusEnSeguimiento: null,
            clearIdTramoBusEnSeguimiento: true,
            seguimientoBusRealDisponibleEnTramoActual: false,
            clearPosicionActualBusReal: true,
            clearMinutosParaLlegadaBusReal: true,
          ),
        );
      }
    }
  }

  @override
  Future<void> usuarioDeseleccionoInformacionDeParada() async {
    print("[AppLogicNotifier] Usuario deseleccionó información de parada.");
    if (mounted) {
      state = state.copyWith(
        clearInfoParadaConsultada: true,
        estadoInfoParadaConsultada: EstadoSolicitud.INICIAL,
      );
    }
  }

  @override
  Future<void> limpiarMensajeDeErrorGlobal() async {
    if (mounted && state.mensajeErrorGlobal != null) {
      state = state.copyWith(clearMensajeErrorGlobal: true);
    }
  }

  // --- Inicio: Lógica de Sugerencias de Geocodificación ---
  // GRANDMA FIRST: Solo input de destino, el origen siempre es la ubicación actual

  @override
  Future<void> usuarioEscribioEnCampoDestino(String textoQuery) async {
    state = state.copyWith(
      textoInputDestinoActual: textoQuery,
      estadoSugerenciasDestino: EstadoSolicitud.CARGANDO,
      clearPuntoDestinoParaBusqueda: true,
      clearNombreLugarDestinoSeleccionado: true,
    );

    _destinoDebounceTimer?.cancel();
    _destinoDebounceTimer = Timer(
      const Duration(milliseconds: _GECODING_SUGGESTIONS_DEBOUNCE_MS),
      () async {
        if (!mounted) return;
        if (textoQuery.isEmpty) {
          state = state.copyWith(
            sugerenciasDestino: [],
            estadoSugerenciasDestino: EstadoSolicitud.INICIAL,
          );
          return;
        }
        try {
          final sugerencias = await _geocodingService.fetchSuggestions(
            textoQuery,
            proximity: null,
          );
          if (mounted) {
            state = state.copyWith(
              sugerenciasDestino: sugerencias,
              estadoSugerenciasDestino: EstadoSolicitud.EXITO,
            );
          }
        } catch (e) {
          print("Error obteniendo sugerencias de destino: $e");
          if (mounted) {
            state = state.copyWith(
              sugerenciasDestino: [],
              estadoSugerenciasDestino: EstadoSolicitud.ERROR,
            );
          }
        }
      },
    );
  }


  @override
  void seleccionarSugerenciaDestino(SugerenciaLugar sugerencia) {
    if (mounted) {
      state = state.copyWith(
        textoInputDestinoActual: sugerencia.nombreCompleto,
        puntoDestinoParaBusqueda: sugerencia.coordenadas,
        nombreLugarDestinoSeleccionado:
            sugerencia.nombreLugar ?? sugerencia.nombreCompleto,
        clearSugerenciasDestino: true,
      );
    }
  }


  @override
  void limpiarSugerenciasDestino() {
    state = state.copyWith(
      sugerenciasDestino: [],
      estadoSugerenciasDestino: EstadoSolicitud.INICIAL,
    );
  }


  @override
  void limpiarDestinoSeleccionado() {
    print("[AppLogicNotifier] limpiarDestinoSeleccionado llamado");
    if (mounted) {
      state = state.copyWith(
        textoInputDestinoActual: '',
        clearPuntoDestinoParaBusqueda: true,
        clearNombreLugarDestinoSeleccionado: true,
        clearSugerenciasDestino: true,
      );
    }
  }

  // GRANDMA FIRST: No necesitamos obtener ubicación manualmente como origen
  // La ubicación actual se obtiene automáticamente durante el inicio de la app
  // y se actualiza continuamente durante el viaje activo

  @override
  void seleccionarOpcionDeRutaParaPrevisualizar(String idOpcionRuta) {
    print("[ROUTE_PREVIEW] 🗺️ === INICIO PREVISUALIZACIÓN ====");
    print("[ROUTE_PREVIEW] 🗺️ Usuario seleccionó opción: $idOpcionRuta");
    print("[ROUTE_PREVIEW] 🗺️ Estado actual: ${state.faseActual}");

    if (mounted) {
      final opciones = state.datosFaseOpcionesRuta?.opcionesDeRuta ?? [];
      print("[ROUTE_PREVIEW] 📱 Opciones disponibles: ${opciones.length}");

      final opcionSeleccionada = opciones.firstWhereOrNull(
        (opt) => opt.idOpcion == idOpcionRuta,
      );

      if (opcionSeleccionada != null) {
        print(
          "[ROUTE_PREVIEW] ✅ Opción encontrada: ${opcionSeleccionada.idOpcion}",
        );
        print(
          "[ROUTE_PREVIEW] 🚌 ETA disponible: ${opcionSeleccionada.etaProximoBus != null}",
        );

        if (opcionSeleccionada.etaProximoBus != null) {
          print(
            "[ROUTE_PREVIEW] 🚌 ETA: ${opcionSeleccionada.etaProximoBus!.minutosParaLlegada}min",
          );
          print(
            "[ROUTE_PREVIEW] 🚌 Línea: ${opcionSeleccionada.etaProximoBus!.linea}",
          );
          print(
            "[ROUTE_PREVIEW] 🚌 Se visualizará bus en tiempo real + tramo verde",
          );
        } else {
          print("[ROUTE_PREVIEW] 📍 Solo se mostrará preview básico (sin ETA)");
        }
      } else {
        print("[ROUTE_PREVIEW] ❌ Opción no encontrada: $idOpcionRuta");
      }

      if (opcionSeleccionada != null) {
        print("[ROUTE_PREVIEW] 🗺️ Calculando puntos de la ruta...");
        final List<Coordenada> todosLosPuntosDeLaRuta = [];
        for (var tramo in opcionSeleccionada.tramosParaPreview) {
          if (tramo.geometriaPolilinea != null) {
            todosLosPuntosDeLaRuta.addAll(tramo.geometriaPolilinea!);
          }
          if (tramo.posicionPunto != null) {
            todosLosPuntosDeLaRuta.add(tramo.posicionPunto!);
          }
        }
        print(
          "[ROUTE_PREVIEW] 🗺️ Puntos totales: ${todosLosPuntosDeLaRuta.length}",
        );

        if (todosLosPuntosDeLaRuta.isNotEmpty) {
          state = state.copyWith(idOpcionRutaPrevisualizada: idOpcionRuta);
          print("[ROUTE_PREVIEW] ✅ Mapa actualizará con zoom centrado");
        } else {
          // Si la ruta no tiene puntos, no cambiamos el zoom target
          state = state.copyWith(idOpcionRutaPrevisualizada: idOpcionRuta);
          print("[ROUTE_PREVIEW] ⚠️ Ruta sin puntos - solo actualizando ID");
        }
      } else {
        // Opción no encontrada, solo actualizar el ID (o limpiarlo si se prefiere)
        state = state.copyWith(idOpcionRutaPrevisualizada: idOpcionRuta);
        print(
          "[ROUTE_PREVIEW] ❌ Opción no encontrada - actualizando ID por defecto",
        );
      }
      print("[ROUTE_PREVIEW] ✅ === FIN PREVISUALIZACIÓN ====");
    }
  }

  @override
  void limpiarSeleccionDeRutaPrevisualizada() {
    print("[AppLogicNotifier] Limpiando selección de ruta previsualizada.");
    if (mounted) {
      state = state.copyWith(clearIdOpcionRutaPrevisualizada: true);
    }
  }

  @override
  Future<void> confirmarOpcionDeRutaEIniciarViaje(
    String idOpcionSeleccionada,
  ) async {
    print("[JOURNEY_START] ▶️ === INICIO DE VIAJE ====");
    print(
      "[JOURNEY_START] ▶️ Usuario seleccionó opción e inicia viaje: $idOpcionSeleccionada",
    );
    print("[JOURNEY_START] ▶️ Estado actual: ${state.faseActual}");
    print(
      "[JOURNEY_START] ▶️ Opción previsualizada: ${state.idOpcionRutaPrevisualizada}",
    );
    print("[JOURNEY_START] ✅ Validando condiciones para iniciar viaje...");
    print(
      "[JOURNEY_START] ✅ Fase correcta: ${state.faseActual == FaseApp.MOSTRANDO_OPCIONES_RUTA}",
    );
    print(
      "[JOURNEY_START] ✅ Datos disponibles: ${state.datosFaseOpcionesRuta != null}",
    );
    print(
      "[JOURNEY_START] ✅ IDs coinciden: ${state.idOpcionRutaPrevisualizada == idOpcionSeleccionada}",
    );

    if (state.faseActual == FaseApp.MOSTRANDO_OPCIONES_RUTA &&
        state.datosFaseOpcionesRuta != null &&
        state.idOpcionRutaPrevisualizada == idOpcionSeleccionada) {
      print("[JOURNEY_START] 🔍 Buscando opción confirmada...");
      OpcionDeRutaMostrable? opcionConfirmada;
      try {
        opcionConfirmada = state.datosFaseOpcionesRuta!.opcionesDeRuta
            .firstWhere((opt) => opt.idOpcion == idOpcionSeleccionada);
        print(
          "[JOURNEY_START] ✅ Opción encontrada: ${opcionConfirmada.idOpcion}",
        );
      } catch (e) {
        print("[JOURNEY_START] ❌ Error buscando opción: $e");
      }

      if (opcionConfirmada == null) {
        print(
          "[JOURNEY_START] ❌ Opción confirmada no encontrada: $idOpcionSeleccionada",
        );
        state = state.copyWith(
          mensajeErrorGlobal: "Error al iniciar el viaje. Opción no válida.",
        );
        print("[JOURNEY_START] ❌ === FIN INICIO DE VIAJE (ERROR) ====");
        return;
      }

      print("[JOURNEY_START] 🎯 Iniciando ACTIVE TRIP...");
      print(
        "[JOURNEY_START] 🎯 Tramos del viaje: ${opcionConfirmada.tramosParaPreview.length}",
      );

      for (int i = 0; i < opcionConfirmada.tramosParaPreview.length; i++) {
        final tramo = opcionConfirmada.tramosParaPreview[i];
        print(
          "[JOURNEY_START] 🎯   Paso ${i + 1}: ${tramo.tipo} - ${tramo.descripcion}",
        );
        if (tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS) {
          print("[JOURNEY_START] 🎯     Línea: ${tramo.nombreLineaBus}");
        }
      }

      state = state.copyWith(
        faseActual: FaseApp.VIAJE_ACTIVO_EN_CURSO,
        datosFaseViajeActivo: EstadoFaseViajeActivo(
          idViajeActivoConfirmado: opcionConfirmada.idOpcion,
          tramosDelViaje: opcionConfirmada.tramosParaPreview,
          opcionDeRutaSeleccionada: opcionConfirmada,
        ),
        clearDatosFaseOpcionesRuta: true,
        clearIdOpcionRutaPrevisualizada: true,
      );
      print("[JOURNEY_START] ✅ Fase cambiada a VIAJE_ACTIVO_EN_CURSO");
      print("[JOURNEY_START] 🚌 Sondeo bus en tiempo real iniciado");

      // Iniciar seguimiento del primer tramo de bus automáticamente si existe
      print("[JOURNEY_START] 🔍 Buscando primer tramo de bus...");
      final primerTramoBus = opcionConfirmada.tramosParaPreview.firstWhere(
        (tramo) => tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS,
        orElse:
            () => TramoViajeMostrable(
              // Placeholder si no hay tramo de bus
              idTramo: "placeholder_no_bus_tramo",
              tipo: TipoTramoViaje.CAMINAR, // O cualquier tipo por defecto
              descripcion: "No bus leg",
              duracionEstimadaSegundos: 0,
            ),
      );

      if (primerTramoBus.idTramo != "placeholder_no_bus_tramo") {
        print(
          "[JOURNEY_START] 🚌 Primer tramo de bus encontrado: ${primerTramoBus.idTramo}",
        );
        print("[JOURNEY_START] 🚌 Línea: ${primerTramoBus.nombreLineaBus}");
        print("[JOURNEY_START] 🚌 Iniciando seguimiento en tiempo real...");
        iniciarSeguimientoBusTiempoReal(
          idViajeActivo: opcionConfirmada.idOpcion,
          idTramoBus: primerTramoBus.idTramo,
        );
      } else {
        print(
          "[JOURNEY_START] ⚠️ No se encontró tramo de bus para seguimiento",
        );
      }

      // DIFF: Inicializar JourneyManager
      print("[JOURNEY_START] 📍 Inicializando JourneyManager...");
      await _initializeJourneyManager(opcionConfirmada);
      print("[JOURNEY_START] ✅ === FIN INICIO DE VIAJE (ÉXITO) ====");
    } else {
      print("[JOURNEY_START] ❌ No se puede confirmar la ruta");
      print("[JOURNEY_START] ❌ Estado incorrecto: ${state.faseActual}");
      print(
        "[JOURNEY_START] ❌ Datos nulos: ${state.datosFaseOpcionesRuta == null}",
      );
      print(
        "[JOURNEY_START] ❌ IDs no coinciden: ${state.idOpcionRutaPrevisualizada} != $idOpcionSeleccionada",
      );
      state = state.copyWith(
        mensajeErrorGlobal: "No se pudo iniciar el viaje. Intenta de nuevo.",
      );
      print("[JOURNEY_START] ❌ === FIN INICIO DE VIAJE (ERROR) ====");
    }
  }

  @override
  Future<void> iniciarSeguimientoBusTiempoReal({
    required String idViajeActivo,
    required String idTramoBus,
  }) async {
    // SONDEO DE BUS EN TIEMPO REAL
    // Este método implementa el sondeo periódico de la posición y ETA del bus
    // para un tramo específico de bus durante un viaje activo.
    //
    // Funcionalidad:
    // 1. Valida que estemos en fase VIAJE_ACTIVO_EN_CURSO
    // 2. Cancela cualquier timer anterior para evitar múltiples sondeos
    // 3. Extrae los datos necesarios del tramo (parada origen, línea de bus)
    // 4. Ejecuta una primera consulta inmediata de ETA
    // 5. Configura un timer que se ejecuta cada 10 segundos para obtener actualizaciones
    // 6. Actualiza el estado con la posición del bus y ETA en tiempo real
    // 7. Se detiene automáticamente si el bus ya llegó o si hay errores

    if (state.faseActual != FaseApp.VIAJE_ACTIVO_EN_CURSO ||
        state.datosFaseViajeActivo == null ||
        state.datosFaseViajeActivo!.idViajeActivoConfirmado != idViajeActivo) {
      print(
        "[AppLogicNotifier_ERROR] No se puede iniciar seguimiento: viaje no activo o ID no coincide.",
      );
      return;
    }
    print(
      "[AppLogicNotifier] Iniciando seguimiento para Viaje: $idViajeActivo, TramoBus: $idTramoBus",
    );

    _seguimientoBusTimer?.cancel();

    final tramoTarget = state.datosFaseViajeActivo!.tramosDelViaje.firstWhere(
      (t) => t.idTramo == idTramoBus && t.tipo == TipoTramoViaje.VIAJE_EN_BUS,
      orElse: () {
        print(
          "[AppLogicNotifier_CRITICAL] Tramo target para seguimiento no encontrado: $idTramoBus",
        );
        // Devuelve un objeto dummy para evitar null pointer, pero loguea el error.
        return TramoViajeMostrable(
          idTramo: '',
          tipo: TipoTramoViaje.VIAJE_EN_BUS,
          descripcion: 'Error: Tramo no encontrado',
          duracionEstimadaSegundos: 0,
        );
      },
    );

    if (tramoTarget.idParadaOrigenTramoBus == null ||
        tramoTarget.nombreLineaBus == null ||
        tramoTarget.coordenadasParadaOrigen == null ||
        tramoTarget.nombreParadaOrigen == null ||
        tramoTarget.idParadaOrigenTramoBus!.isEmpty ||
        tramoTarget.nombreLineaBus!.isEmpty ||
        tramoTarget.nombreParadaOrigen!.isEmpty) {
      print(
        "[AppLogicNotifier_ERROR] Datos insuficientes en tramo para seguimiento.",
      );
      if (mounted) {
        state = state.copyWith(
          datosFaseViajeActivo: state.datosFaseViajeActivo!.copyWith(
            idTramoBusEnSeguimiento: idTramoBus,
            seguimientoBusRealDisponibleEnTramoActual: false,
            clearPosicionActualBusReal: true,
            clearMinutosParaLlegadaBusReal: true,
          ),
        );
      }
      return;
    }

    final String idParadaOrigen = tramoTarget.idParadaOrigenTramoBus!;
    final String lineaBus = tramoTarget.nombreLineaBus!;
    final Coordenada coordsParadaOrigen = tramoTarget.coordenadasParadaOrigen!;
    final String nombreParadaOrigen = tramoTarget.nombreParadaOrigen!;

    // Actualiza el estado para reflejar que se está intentando seguir este tramo.
    state = state.copyWith(
      datosFaseViajeActivo: state.datosFaseViajeActivo!.copyWith(
        idTramoBusEnSeguimiento: idTramoBus,
        seguimientoBusRealDisponibleEnTramoActual:
            false, // Se establecerá a true si fetchEta tiene éxito
        clearPosicionActualBusReal: true,
        clearMinutosParaLlegadaBusReal: true,
      ),
    );

    // Contador de intentos consecutivos SIN ETA para esta sesión de seguimiento
    int etaNoDataMisses = 0;
    const int NO_ETA_MAX_MISSES = 3; // tras 3 misses, aplicamos fallback

    Future<void> fetchEta() async {
      if (!mounted ||
          state.datosFaseViajeActivo?.idTramoBusEnSeguimiento != idTramoBus) {
        _seguimientoBusTimer?.cancel();
        return;
      }
      print(
        "[AppLogicNotifier_Timer] Ejecutando fetchEta para parada $idParadaOrigen, línea $lineaBus",
      );

      try {
        final InfoDetalladaParada? detallesParada = await _montevideoApiService
            .getStopDetailsWithEta(
              idParadaOrigen,
              nombreParadaOrigen,
              coordsParadaOrigen,
            );

        if (!mounted ||
            state.datosFaseViajeActivo?.idTramoBusEnSeguimiento != idTramoBus)
          return;

        if (detallesParada != null) {
          // Selección ROBUSTA del ETA: tomar la misma línea en tiempo real y
          // priorizar el bus que esté "antes" de la parada en la geometría del tramo.
          EtaMostrable? etaRelevante;
          final etasMismaLinea =
              detallesParada.etas
                  .where((eta) => eta.linea == lineaBus && eta.esTiempoReal)
                  .toList();

          if (etasMismaLinea.isNotEmpty) {
            // Si tenemos forma de validar con shape, filtrar por buses "antes" del stop
            // (para evitar elegir uno que ya está por delante o en otro tramo alejado).
            try {
              final active = state.datosFaseViajeActivo;
              final busTramo = active?.tramosDelViaje.firstWhere(
                (t) => t.tipo == TipoTramoViaje.VIAJE_EN_BUS,
              );
              if (busTramo != null) {
                final shape =
                    getFullShapeGeometry(busTramo.shapeId) ??
                    busTramo.geometriaPolilinea;
                if (shape != null &&
                    shape.length >= 2 &&
                    busTramo.coordenadasParadaOrigen != null) {
                  final stopIdx = findClosestPointIndexOnShape(
                    shape,
                    busTramo.coordenadasParadaOrigen!,
                  );
                  final destIdx =
                      busTramo.coordenadasParadaDestino != null
                          ? findClosestPointIndexOnShape(
                            shape,
                            busTramo.coordenadasParadaDestino!,
                          )
                          : -1;
                  final forward = destIdx >= 0 ? (destIdx > stopIdx) : true;

                  // Elegir el ETA cuyo bus esté antes del stop (por índice) y más cercano
                  etasMismaLinea.sort((a, b) {
                    final ai =
                        a.posicionBus != null
                            ? findClosestPointIndexOnShape(
                              shape,
                              a.posicionBus!,
                            )
                            : 1 << 30;
                    final bi =
                        b.posicionBus != null
                            ? findClosestPointIndexOnShape(
                              shape,
                              b.posicionBus!,
                            )
                            : 1 << 30;
                    // Ordenar por cercanía al stop en el sentido correcto
                    final ad = forward ? (stopIdx - ai) : (ai - stopIdx);
                    final bd = forward ? (stopIdx - bi) : (bi - stopIdx);
                    return ad.compareTo(bd);
                  });

                  // Tomar el primero que esté efectivamente "antes" del stop
                  etaRelevante = etasMismaLinea.firstWhere((e) {
                    if (e.posicionBus == null) return false;
                    final ei = findClosestPointIndexOnShape(
                      shape,
                      e.posicionBus!,
                    );
                    return forward ? (ei < stopIdx) : (ei > stopIdx);
                  }, orElse: () => etasMismaLinea.first);
                } else {
                  etaRelevante = etasMismaLinea.first;
                }
              } else {
                etaRelevante = etasMismaLinea.first;
              }
            } catch (_) {
              etaRelevante = etasMismaLinea.first;
            }
          }

          if (etaRelevante != null && etaRelevante.minutosParaLlegada > 0) {
            state = state.copyWith(
              datosFaseViajeActivo: state.datosFaseViajeActivo!.copyWith(
                posicionActualBusReal: etaRelevante.posicionBus,
                minutosParaLlegadaBusReal: etaRelevante.minutosParaLlegada,
                seguimientoBusRealDisponibleEnTramoActual: true,
              ),
            );

            // Actualizar JourneyManager con posición del bus
            if (_journeyManager != null && etaRelevante.posicionBus != null) {
              _journeyManager!.updateBusPosition(
                etaRelevante.posicionBus!,
                etaRelevante.minutosParaLlegada,
              );
            }

            // Eliminado: registro dev de bus update
            // Resetear contador de misses tras éxito
            etaNoDataMisses = 0;
            print(
              "[AppLogicNotifier_Timer] ETA real para $lineaBus: ${etaRelevante.minutosParaLlegada} min, Pos: ${etaRelevante.posicionBus}",
            );
          } else {
            state = state.copyWith(
              datosFaseViajeActivo: state.datosFaseViajeActivo!.copyWith(
                seguimientoBusRealDisponibleEnTramoActual: false,
                // No limpiar inmediatamente; conservar última posición válida para evitar parpadeos.
              ),
            );
            print(
              "[AppLogicNotifier_Timer] No ETA real (o ya pasó) para $lineaBus en $idParadaOrigen.",
            );
            // No cancelar el timer: continuar sondeando hasta obtener el próximo bus para la misma línea
            if (etaRelevante != null && etaRelevante.minutosParaLlegada <= 0) {
              print(
                "[AppLogicNotifier_Timer] Bus llegó/pasó. Continuando sondeo para detectar el PRÓXIMO bus de la línea $lineaBus...",
              );
            }

            // Incrementar misses y aplicar fallback si superamos el umbral
            etaNoDataMisses++;
            if (etaNoDataMisses >= NO_ETA_MAX_MISSES) {
              // Intentar usar el PRÓXIMO bus de la misma línea con minutos > 0
              EtaMostrable? fallbackEta;
              try {
                // Lista ya filtrada por línea y tiempo real (etasMismaLinea)
                final candidatos =
                    etasMismaLinea
                        .where((e) => e.minutosParaLlegada > 0)
                        .toList();
                if (candidatos.isNotEmpty) {
                  fallbackEta = candidatos.first;
                }
              } catch (_) {}

              if (fallbackEta != null) {
                state = state.copyWith(
                  datosFaseViajeActivo: state.datosFaseViajeActivo!.copyWith(
                    posicionActualBusReal: fallbackEta.posicionBus,
                    minutosParaLlegadaBusReal: fallbackEta.minutosParaLlegada,
                    seguimientoBusRealDisponibleEnTramoActual: true,
                  ),
                );
                // Eliminado: registro dev de bus update (fallback)
                print(
                  "[AppLogicNotifier_Timer] Fallback: usando PRÓXIMO bus de $lineaBus con ETA ${fallbackEta.minutosParaLlegada} min",
                );
              } else {
                // Sin próximos buses disponibles: limpiar para evitar sensación de congelado
                state = state.copyWith(
                  datosFaseViajeActivo: state.datosFaseViajeActivo!.copyWith(
                    seguimientoBusRealDisponibleEnTramoActual: false,
                    clearPosicionActualBusReal: true,
                    clearMinutosParaLlegadaBusReal: true,
                  ),
                );
                print(
                  "[AppLogicNotifier_Timer] Sin próximos buses con ETA. Limpiando icono/ETA (evitar freeze).",
                );
              }

              // Reiniciar ventana de misses para próximas detecciones
              etaNoDataMisses = 0;
            }
          }
        } else {
          state = state.copyWith(
            datosFaseViajeActivo: state.datosFaseViajeActivo!.copyWith(
              seguimientoBusRealDisponibleEnTramoActual: false,
              clearPosicionActualBusReal: true,
              clearMinutosParaLlegadaBusReal: true,
            ),
          );
          print(
            "[AppLogicNotifier_Timer_ERROR] Servicio no devolvió detalles para parada $idParadaOrigen.",
          );
        }
      } catch (e, s) {
        print("[AppLogicNotifier_Timer_ERROR] Error en fetchEta: $e\n$s");
        if (mounted &&
            state.datosFaseViajeActivo?.idTramoBusEnSeguimiento == idTramoBus) {
          state = state.copyWith(
            datosFaseViajeActivo: state.datosFaseViajeActivo!.copyWith(
              seguimientoBusRealDisponibleEnTramoActual: false,
              clearPosicionActualBusReal: true,
              clearMinutosParaLlegadaBusReal: true,
            ),
          );
        }
      }
    }

    await fetchEta(); // Primera ejecución inmediata
    if (mounted &&
        state.datosFaseViajeActivo?.idTramoBusEnSeguimiento == idTramoBus) {
      _seguimientoBusTimer = Timer.periodic(
        const Duration(seconds: _SEGUIMIENTO_BUS_INTERVALO_SEGUNDOS),
        (_) => fetchEta(),
      );
    }
  }

  @override
  Future<void> detenerSeguimientoBusTiempoReal() async {
    if (state.faseActual != FaseApp.VIAJE_ACTIVO_EN_CURSO ||
        state.datosFaseViajeActivo == null) {
      return;
    }
    print("[AppLogicNotifier] Deteniendo seguimiento de bus en tiempo real.");
    _seguimientoBusTimer?.cancel();
    if (mounted) {
      state = state.copyWith(
        datosFaseViajeActivo: state.datosFaseViajeActivo!.copyWith(
          clearIdTramoBusEnSeguimiento: true,
          clearPosicionActualBusReal: true,
          clearMinutosParaLlegadaBusReal: true,
          seguimientoBusRealDisponibleEnTramoActual:
              false, // Asegurar que se apague
        ),
      );
      print("[AppLogicNotifier] Seguimiento detenido y estado limpiado.");
    }
  }

  @override
  void setErrorGlobal(String? mensaje) {
    if (mounted) {
      state = state.copyWith(
        mensajeErrorGlobal: mensaje,
        clearMensajeErrorGlobal: mensaje == null,
      );
    }
  }

  // Inicializar JourneyManager con los tramos del viaje
  Future<void> _initializeJourneyManager(
    OpcionDeRutaMostrable option,
  ) async {
    print("[JOURNEY_MANAGER_INIT] 🎯 === INICIALIZANDO ====");
    print("[JOURNEY_MANAGER_INIT] 🎯 Opción de ruta: ${option.idOpcion}");
    print(
      "[JOURNEY_MANAGER_INIT] 🎯 Total de tramos: ${option.tramosParaPreview.length}",
    );

    try {
      // Crear JourneyManager
      _journeyManager = JourneyManager(
        tramos: option.tramosParaPreview,
        onEvent: _handleJourneyEvent,
        isTestMode: isTestMode,
      );
      print("[JOURNEY_MANAGER_INIT] ✅ JourneyManager creado");

      // Inicializar
      await _journeyManager!.initialize();
      print("[JOURNEY_MANAGER_INIT] ✅ JourneyManager inicializado");

      print("[JOURNEY_MANAGER_INIT] ✅ === INICIALIZACIÓN COMPLETADA ====");
    } catch (e, stackTrace) {
      print("[JOURNEY_MANAGER_INIT] ❌ === ERROR EN INICIALIZACIÓN ====");
      print("[JOURNEY_MANAGER_INIT] ❌ Error: $e");
      print("[JOURNEY_MANAGER_INIT] ❌ Stack trace: $stackTrace");

      // Si falla, mostrar error al usuario
      if (mounted) {
        state = state.copyWith(
          mensajeErrorGlobal: "Error al iniciar navegación automática. Por favor intenta de nuevo.",
        );
      }
      print("[JOURNEY_MANAGER_INIT] ❌ === FIN ERROR ====");
    }
  }

  // Handler de eventos del JourneyManager
  void _handleJourneyEvent(JourneyEvent event) {
    LoggingHelpers.logJourneyEvent(event.type.toString(), event.data);

    switch (event.type) {
      case JourneyEventType.LOCATION_UPDATED:
        _journeyEventHandlers.handleLocationUpdated(event);
        break;

      case JourneyEventType.STEP_TRANSITIONED:
        final newStep = event.data?['newStep'] as JourneyStepState?;
        final newIndex = event.data?['newIndex'] as int?;
        if (newStep != null && newIndex != null) {
          _handleStepTransitioned(newStep, newIndex);
        }
        break;

      case JourneyEventType.BUS_BOARDING_DETECTED:
        _journeyEventHandlers.handleBusBoardingDetected(event);
        break;

      case JourneyEventType.JOURNEY_COMPLETED:
        _journeyEventHandlers.handleJourneyCompleted(event);
        break;

      case JourneyEventType.PROGRESS_UPDATED:
        _journeyEventHandlers.handleProgressUpdated(event);
        break;

      case JourneyEventType.ARRIVAL_DETECTED:
        _journeyEventHandlers.handleArrivalDetected(event);
        break;

      case JourneyEventType.BUS_POSITION_UPDATED:
        _journeyEventHandlers.handleBusPositionUpdated(event);
        break;

      case JourneyEventType.BUS_EARLY_EXIT_DETECTED:
        _journeyEventHandlers.handleBusEarlyExit(event);
        break;

      case JourneyEventType.WALKING_ROUTE_UPDATED:
        _journeyEventHandlers.handleWalkingRouteUpdated(event);
        break;
    }
  }


  // Transición de paso
  void _handleStepTransitioned(JourneyStepState newStep, int newIndex) {
    print("[STEP_TRANSITION] 🔄 Nuevo paso: $newIndex - ${newStep.type}");

    // Notificar al MapManager para actualizar vista
    final mapManager = _ref.read(mapManagerProvider);
    final activeTripState = state.datosFaseViajeActivo;

    if (mapManager != null && activeTripState != null) {
      print("[STEP_TRANSITION] 🗺️ Actualizando MapManager al paso $newIndex");
      mapManager.updateCurrentLeg(newIndex, activeTripState.tramosDelViaje);
    }
  }


  // Completar viaje y limpiar estado
  void _completeJourney() {
    print("[JOURNEY_COMPLETE] 🏁 === VIAJE COMPLETADO AUTOMÁTICAMENTE ====");
    print(
      "[JOURNEY_COMPLETE] 🏁 Todos los pasos del viaje han sido completados",
    );

    // Actualizar estado de la UI antes de limpiar
    print("[JOURNEY_COMPLETE] 📱 Actualizando estado de la UI...");
    if (mounted) {
      state = state.copyWith(
        faseActual: FaseApp.INICIAL_SIN_BUSQUEDA,
        clearDatosFaseViajeActivo: true,
        mostrandoSpinnerGlobal: false,
        clearMensajeErrorGlobal: true,
      );
      print("[JOURNEY_COMPLETE] ✅ Estado de la UI actualizado");
    } else {
      print(
        "[JOURNEY_COMPLETE] ⚠️ Notifier disposed - no se puede actualizar UI",
      );
    }

    print("[JOURNEY_COMPLETE] 🏁 Limpiando JourneyManager...");
    _journeyManager?.dispose();
    _journeyManager = null;

    print("[JOURNEY_COMPLETE] 🏁 Deteniendo seguimiento activo...");
    detenerSeguimientoBusTiempoReal();

    // Cancelar todos los timers relacionados con el viaje
    print("[JOURNEY_COMPLETE] 🛑 Cancelando todos los timers...");
    _seguimientoBusTimer?.cancel();
    _seguimientoBusTimer = null;
    _waitingForBusFallbackTimer?.cancel();
    _waitingForBusFallbackTimer = null;
    print("[JOURNEY_COMPLETE] ✅ Timers cancelados");

    print("[JOURNEY_COMPLETE] 🎉 === VIAJE FINALIZADO EXITOSAMENTE ====");
    print("[JOURNEY_COMPLETE] 🎉 La app ha vuelto al estado inicial");
  }


  // Dev tool: Push mock user location to JourneyManager
  void devPushMockUserLocation(Coordenada location) {
    // Inject location directly to JourneyManager if active
    if (_journeyManager != null) {
      _journeyManager!.injectLocationUpdate(location);
    }
  }

  // ====== DEV: Simulación basada en la ruta actual (sin dataset) ======
  Future<void> devStartTripSimulation({double speed = 1.0}) async {
    // Capturar última posición real del bus ANTES de limpiar estado
    final lastBusPos = state.datosFaseViajeActivo?.posicionActualBusReal;
    // Apagar seguimiento API para no competir
    await detenerSeguimientoBusTiempoReal();
    final mapManager = _ref.read(mapManagerProvider);
    if (mapManager != null) {
      // En fases previas (caminar/espera) queremos mostrar aproximación del bus (API-like)
      // pero como no hay API, escribimos directo las posiciones + ETA en las capas main.
      // No cambiamos a USER_LOCATION aquí para que updateBusPosition pinte en active_trip.
    }

    // Reiniciar instancia para garantizar que tome la posición inicial más reciente
    _tripSimulator?.stop();
    _tripSimulator = TripSimulator(
      this,
      speed: speed,
      initialBusPosition: lastBusPos,
    );
    await _tripSimulator!.start();
    print('[DEV] Trip simulation started at ${speed}x');
  }

  void devStopTripSimulation() {
    _tripSimulator?.stop();
    _tripSimulator = null;
    print('[DEV] Trip simulation stopped');
  }

  void devSetTripSimulationSpeed(double speed) {
    _tripSimulator?.setSpeed(speed);
    print('[DEV] Trip simulation speed set to ${speed}x');
  }

  // Helpers para TripSimulator
  EstadoFaseViajeActivo? devGetActiveTripState() {
    return state.datosFaseViajeActivo;
  }

  void devPushRealtimeBusPosition(Coordenada pos, int etaMinutes) {
    print(
      '[DEV_SIM] Push bus realtime: pos=${pos.latitud},${pos.longitud} eta=$etaMinutes',
    );
    // Throttle anti-jitter para updates de bus simulados
    const int throttleMs = 700; // mínimo intervalo entre updates
    const double minMoveMeters = 4.0; // ignorar micro-movimientos
    final now = DateTime.now();
    if (_lastDevBusPush != null) {
      final diff = now.difference(_lastDevBusPush!).inMilliseconds;
      if (diff < throttleMs) {
        return;
      }
    }
    if (_lastDevBusPos != null) {
      final d = calculateHaversineDistance(
        _lastDevBusPos!.latitud,
        _lastDevBusPos!.longitud,
        pos.latitud,
        pos.longitud,
      );
      if (d < minMoveMeters) {
        return;
      }
    }
    _lastDevBusPush = now;
    _lastDevBusPos = pos;
    final active = state.datosFaseViajeActivo;
    if (active == null) return;
    state = state.copyWith(
      datosFaseViajeActivo: active.copyWith(
        posicionActualBusReal: pos,
        minutosParaLlegadaBusReal: etaMinutes,
        // Mantener disponible también cuando etaMinutes==0 al final de la aproximación
        // para no ocultar el bus justo al llegar. Lo dejamos true si venía siéndolo.
        seguimientoBusRealDisponibleEnTramoActual:
            (active.seguimientoBusRealDisponibleEnTramoActual ||
                etaMinutes >= 0),
      ),
    );
  }


  @override
  void dispose() {
    // Cancelar todos los timers primero
    _seguimientoBusTimer?.cancel();
    _seguimientoBusTimer = null;
    _destinoDebounceTimer?.cancel();
    _destinoDebounceTimer = null;
    _waitingForBusFallbackTimer?.cancel();
    _waitingForBusFallbackTimer = null;

    // Limpiar JourneyManager
    _journeyManager?.dispose();
    _journeyManager = null;

    // Llamar al dispose del padre
    super.dispose();
  }

  // Implementaciones de stubs para IAppLogic si es necesario (ejemplos)
  // Estos deben ser implementados completamente según los requisitos.

  @override
  void pantallaDeInicioCargada() {
    print("[AppLogicNotifier] pantallaDeInicioCargada NOP");
    // Podría usarse para cargar datos iniciales si no se hace en el constructor o vía otra acción.
    // Por ejemplo, si se necesita alguna configuración post-construcción.
    // if (state.faseActual == FaseApp.INICIAL_SIN_BUSQUEDA && state.datosFaseInicial == null) {
    //   // Ejemplo: Cargar paradas por defecto si no hay nada.
    //   // Esto es solo un ejemplo, la lógica actual las carga con `cargarParadasInicialesDelViewport`.
    //   // cargarParadasInicialesDelViewport(Coordenada(latitud: -34.906498, longitud: -56.185998), 14); // Centro de MVD
    // }
  }

  @override
  void usuarioMovioMapaManualente(Coordenada nuevoCentro, double nuevoZoom) {
    print(
      "[AppLogicNotifier] usuarioMovioMapaManualente NOP: Centro $nuevoCentro, Zoom $nuevoZoom",
    );
    // La lógica de recargar paradas está en viewportDelMapaCambio, que es llamado por la UI
    // cuando el mapa está 'idle' después del movimiento. Esta acción podría usarse para
    // lógica adicional si el movimiento manual tuviera otras implicaciones.
  }

  @override
  void usuarioHizoTapEnMapa(Coordenada tocada) {
    print("[AppLogicNotifier] usuarioHizoTapEnMapa NOP: $tocada");
    // Lógica si el tap en el mapa (sin ser parada) debe hacer algo a nivel de estado global.
    // Ej: Limpiar selección de parada, o si se implementara "poner un pin".
    if (state.infoParadaConsultada != null ||
        state.estadoInfoParadaConsultada == EstadoSolicitud.CARGANDO) {
      // Si había una parada seleccionada o cargando, la limpiamos.
      // cerrarDetallesDeParada(); // Esto también limpia el mensaje de error.
    }
  }

  @override
  void usuarioHizoTapEnParadaDelMapa(String idParada) {
    print(
      "[AppLogicNotifier] usuarioHizoTapEnParadaDelMapa llamado con ID: $idParada",
    );
    // La UI llama a solicitarInformacionDetalladaParada directamente.
    // Este método podría ser un punto intermedio si fuera necesario,
    // pero actualmente la UI invoca la acción más específica.
    // Si este método se usa, debería probablemente llamar a:
    solicitarInformacionDetalladaParada(idParada);
  }

  @override
  void cerrarDetallesDeParada() {
    print("[AppLogicNotifier] cerrarDetallesDeParada llamado");
    if (mounted) {
      state = state.copyWith(
        clearInfoParadaConsultada: true,
        estadoInfoParadaConsultada: EstadoSolicitud.INICIAL,
      );
    }
  }

  @override
  void navegarAAnteriorPasoInstrucciones() {
    print("[AppLogicNotifier] navegarAAnteriorPasoInstrucciones NOP");
    // Debe haber lógica para cambiar el tramo activo en `datosFaseViajeActivo`
  }

  @override
  void navegarASiguientePasoInstrucciones() {
    print("[AppLogicNotifier] navegarASiguientePasoInstrucciones NOP");
    // Debe haber lógica para cambiar el tramo activo en `datosFaseViajeActivo`
  }

  @override
  void usuarioSeleccionoPasoInstrucciones(int indicePaso) {
    print(
      "[AppLogicNotifier] usuarioSeleccionoPasoInstrucciones NOP: $indicePaso",
    );
    // Debe haber lógica para cambiar el tramo activo en `datosFaseViajeActivo`
  }

  @override
  void usuarioPresionoSeguirEsteViaje() {
    print("[AppLogicNotifier] usuarioPresionoSeguirEsteViaje NOP");
    // Cambiar a un modo de seguimiento más activo si es diferente del modo de VIAJE_ACTIVO_EN_CURSO inicial.
  }

  @override
  void detenerSeguimientoActivo() {
    print("[AppLogicNotifier] detenerSeguimientoActivo llamado");

    // Limpiar JourneyManager
    _journeyManager?.dispose();
    _journeyManager = null;

    // Detener el timer de seguimiento de bus en tiempo real
    if (_seguimientoBusTimer != null) {
      _seguimientoBusTimer!.cancel();
      _seguimientoBusTimer = null;
      print(
        "[AppLogicNotifier] Saliendo de fase VIAJE_ACTIVO_EN_CURSO, deteniendo timer de seguimiento",
      );
    }

    // Limpiar estado de viaje activo
    state = state.copyWith(
      faseActual: FaseApp.INICIAL_SIN_BUSQUEDA,
      datosFaseViajeActivo: null,
    );

    print("[AppLogicNotifier] Seguimiento activo detenido y estado limpiado.");
  }

  // DIFF: Getter para obtener modo de tracking actual
  BusTrackingMode get currentBusTrackingMode {
    final mapManager = _ref.read(mapManagerProvider);
    return mapManager?.busRealtime.trackingMode ?? BusTrackingMode.INACTIVE;
  }

  // DIFF: Getter y método para controlar animaciones
  bool get animationsEnabled => _animationsEnabled;

  void toggleAnimations() {
    _animationsEnabled = !_animationsEnabled;
    print(
      "[ANIMATIONS] 🎭 Animaciones ${_animationsEnabled ? 'ACTIVADAS' : 'DESACTIVADAS'}",
    );

    // Notificar al MapManager para actualizar animaciones
    final mapManager = _ref.read(mapManagerProvider);
    if (mapManager != null) {
      mapManager.routeRenderer.setAnimationsEnabled(_animationsEnabled);
    }

    // Actualizar estado para que la UI se refresque
    if (mounted) {
      state = state.copyWith(); // Trigger rebuild
    }
  }
}

// Extension para facilitar el acceso a los datos de la fase actual
// Esto es opcional y depende de las preferencias de estilo.
// extension AppUiStateFaseExtension on AppUiState {
//   EstadoFaseInicial? get datosFaseInicial =>
//       faseActual == FaseApp.INICIAL_SIN_BUSQUEDA ? datosExtrasFase as EstadoFaseInicial? : null;
//   DatosFaseOpcionesRuta? get datosFaseOpcionesRuta =>
//       faseActual == FaseApp.MOSTRANDO_OPCIONES_RUTA ? datosExtrasFase as DatosFaseOpcionesRuta? : null;
//   DatosFaseViajeActivo? get datosFaseViajeActivo =>
//       faseActual == FaseApp.VIAJE_ACTIVO_EN_CURSO ? datosExtrasFase as DatosFaseViajeActivo? : null;
// }
// ... FIN DEL ARCHIVO ... (añadir aquí si algo más es necesario)
