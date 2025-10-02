import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../contrato_ui/app_ui_state.dart';
import '../services/montevideo_api_service_adapter.dart';
import '../services/itinerary_planning_service_adapter.dart';
import '../services/geocoding_service_adapter.dart';
import 'package:collection/collection.dart';
import '../../journey/location_tracker.dart';
import '../../journey/journey_step_state.dart';
import '../../journey/route_dynamic_calculator.dart';
// Eliminado: herramientas de grabación manual
import '../../devtools/trip_simulator.dart';
import 'package:bondi_uy/utils/feature_logger.dart';
import '../../ui/app_host.dart'; // Para acceder al mapManagerProvider
import '../../map_manager/map_bus_realtime.dart'; // Para BusTrackingMode
import '../../utils/geometry_utils.dart';

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
  Timer? _origenDebounceTimer;
  Timer? _destinoDebounceTimer;
  Timer? _waitingForBusFallbackTimer; // Para detectar subida sin ETA

  // DIFF: Nuevos componentes para tracking automático
  LocationTracker? _locationTracker;
  JourneyStepState? _currentJourneyStep;
  bool _automaticNavigationEnabled = true;
  Coordenada? _previousUserLocation; // Para análisis direccional
  DateTime? _lastLocationUpdate; // Para sincronización de timers

  // DIFF: Flag para controlar animaciones
  bool _animationsEnabled = true;

  // Dev recorder para grabar/reproducir eventos de ubicación y bus
  TripSimulator? _tripSimulator;
  DateTime? _lastDevMockPush; // Para throttle de simulador
  DateTime? _lastDevBusPush;
  Coordenada? _lastDevBusPos;
  // Histéresis de boarding
  int _busBoardingPositiveCount = 0;
  DateTime? _lastBusBoardingEval;
  static const int _busBoardingRequiredConsecutive = 5; // 5 positivos (~5s)
  static const Duration _busBoardingEvalMinSpacing = Duration(
    milliseconds: 900,
  ); // ventana ~1s
  static const double _departureThresholdMeters = 90.0; // abandono de parada

  AppLogicNotifier(
    this._ref,
    this._montevideoApiService,
    this._itineraryPlanningService,
    this._geocodingService, {
    this.isTestMode = false,
  }) : super(AppUiState.inicial()) {
    // Imprimir estado inicial
    print("[AppUiState Initial]: ${state.toString()}");
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
    print("[ROUTE_SEARCH] 🔍 === INICIO BÚSQUEDA DE RUTAS ====");
    print("[ROUTE_SEARCH] 🔍 Usuario presionó buscar");
    print("[ROUTE_SEARCH] 🔍 Estado actual: ${state.faseActual}");

    // Leer origen y destino desde el estado
    print("[ROUTE_SEARCH] 📍 Validando origen y destino...");
    print("[ROUTE_SEARCH] 📍 Origen: ${state.puntoOrigenParaBusqueda}");
    print("[ROUTE_SEARCH] 📍 Destino: ${state.puntoDestinoParaBusqueda}");

    if (state.puntoOrigenParaBusqueda == null ||
        state.puntoDestinoParaBusqueda == null) {
      print("[ROUTE_SEARCH] ❌ Validación fallida - origen o destino nulos");
      print(
        "[ROUTE_SEARCH] ❌ Origen nulo: ${state.puntoOrigenParaBusqueda == null}",
      );
      print(
        "[ROUTE_SEARCH] ❌ Destino nulo: ${state.puntoDestinoParaBusqueda == null}",
      );
      if (mounted) {
        state = state.copyWith(
          mensajeErrorGlobal:
              "Por favor, selecciona un origen y destino válidos.",
        );
      }
      print("[ROUTE_SEARCH] ❌ === FIN BÚSQUEDA (ERROR VALIDACIÓN) ====");
      return;
    }

    final Coordenada origenCoords = state.puntoOrigenParaBusqueda!;
    final String origenNombreFinal =
        state.nombreLugarOrigenSeleccionado ?? "Origen";
    final Coordenada destinoCoords = state.puntoDestinoParaBusqueda!;
    final String destinoNombreFinal =
        state.nombreLugarDestinoSeleccionado ?? "Destino";

    print("[ROUTE_SEARCH] ✅ Validación exitosa");
    print(
      "[ROUTE_SEARCH] 🗺️ Origen: $origenNombreFinal (${origenCoords.latitud}, ${origenCoords.longitud})",
    );
    print(
      "[ROUTE_SEARCH] 🗺️ Destino: $destinoNombreFinal (${destinoCoords.latitud}, ${destinoCoords.longitud})",
    );
    print("[ROUTE_SEARCH] 🔄 Cambiando a fase MOSTRANDO_OPCIONES_RUTA...");
    if (mounted) {
      state = state.copyWith(
        faseActual: FaseApp.MOSTRANDO_OPCIONES_RUTA,
        mostrandoSpinnerGlobal: true,
        clearDatosFaseInicial: true, // Limpiar datos de la fase anterior
        datosFaseOpcionesRuta: EstadoFaseOpcionesRuta(
          opcionesDeRuta: [],
        ), // Inicializar con lista vacía
        clearInfoParadaConsultada: true,
        estadoInfoParadaConsultada: EstadoSolicitud.INICIAL,
        clearIdOpcionRutaPrevisualizada:
            true, // Limpiar previsualización anterior
      );
    }

    try {
      print("[ROUTE_SEARCH] 🌐 Llamando servicio de planificación de rutas...");
      final List<OpcionDeRutaMostrable> opciones =
          await _itineraryPlanningService.planRoute(
            origenCoords: origenCoords, // Usar parámetro
            origenNombre: origenNombreFinal, // Usar parámetro procesado
            destinoCoords: destinoCoords, // Usar parámetro
            destinoNombre: destinoNombreFinal, // Usar parámetro procesado
          );
      print(
        "[ROUTE_SEARCH] ✅ Servicio respondió con ${opciones.length} opciones",
      );

      for (int i = 0; i < opciones.length; i++) {
        final opcion = opciones[i];
        print("[ROUTE_SEARCH] 📱 Opción $i: ${opcion.idOpcion}");
        print("[ROUTE_SEARCH] 📱   - Recomendada: ${opcion.esRecomendada}");
        print(
          "[ROUTE_SEARCH] 📱   - Duración: ${opcion.duracionTotalSegundos}s",
        );
        print(
          "[ROUTE_SEARCH] 📱   - Tramos: ${opcion.tramosParaPreview.length}",
        );
        print(
          "[ROUTE_SEARCH] 📱   - ETA próximo bus: ${opcion.etaProximoBus?.minutosParaLlegada}min",
        );
      }

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
      // Mantener origen y destino si ya estaban seteados
      final origenActual = state.puntoOrigenParaBusqueda;
      final nombreOrigenActual = state.nombreLugarOrigenSeleccionado;
      final textoInputOrigenActual = state.textoInputOrigenActual;

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
        // Mantener O/D si existen
        puntoOrigenParaBusqueda: origenActual,
        nombreLugarOrigenSeleccionado: nombreOrigenActual,
        textoInputOrigenActual: textoInputOrigenActual,
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
  @override
  Future<void> usuarioEscribioEnCampoOrigen(String textoQuery) async {
    state = state.copyWith(
      textoInputOrigenActual: textoQuery,
      estadoSugerenciasOrigen: EstadoSolicitud.CARGANDO,
      // Al escribir, limpiamos la selección previa para evitar inconsistencias
      // si el usuario edita el texto después de haber seleccionado una sugerencia.
      clearPuntoOrigenParaBusqueda: true,
      clearNombreLugarOrigenSeleccionado: true,
    );

    _origenDebounceTimer?.cancel();
    _origenDebounceTimer = Timer(
      const Duration(milliseconds: _GECODING_SUGGESTIONS_DEBOUNCE_MS),
      () async {
        if (!mounted) return;
        if (textoQuery.isEmpty) {
          state = state.copyWith(
            sugerenciasOrigen: [], // Limpiar lista
            estadoSugerenciasOrigen: EstadoSolicitud.INICIAL,
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
              sugerenciasOrigen: sugerencias,
              estadoSugerenciasOrigen: EstadoSolicitud.EXITO,
            );
          }
        } catch (e) {
          print("Error obteniendo sugerencias de origen: $e");
          if (mounted) {
            state = state.copyWith(
              sugerenciasOrigen: [],
              estadoSugerenciasOrigen: EstadoSolicitud.ERROR,
            );
          }
        }
      },
    );
  }

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
  void seleccionarSugerenciaOrigen(SugerenciaLugar sugerencia) {
    if (mounted) {
      state = state.copyWith(
        textoInputOrigenActual: sugerencia.nombreCompleto,
        puntoOrigenParaBusqueda: sugerencia.coordenadas,
        nombreLugarOrigenSeleccionado:
            sugerencia.nombreLugar ?? sugerencia.nombreCompleto,
        clearSugerenciasOrigen: true,
      );
    }
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
  void limpiarSugerenciasOrigen() {
    state = state.copyWith(
      sugerenciasOrigen: [],
      estadoSugerenciasOrigen: EstadoSolicitud.INICIAL,
      // Opcional: decidir si limpiar también puntoOrigenParaBusqueda y nombreLugarOrigenSeleccionado.
      // Por ahora, no los limpiamos aquí, se limpian cuando el usuario empieza a escribir de nuevo
      // o si se llama explícitamente a un método para limpiar toda la búsqueda.
    );
  }

  @override
  void limpiarSugerenciasDestino() {
    state = state.copyWith(
      sugerenciasDestino: [],
      estadoSugerenciasDestino: EstadoSolicitud.INICIAL,
    );
  }

  @override
  void limpiarOrigenSeleccionado() {
    print("[AppLogicNotifier] limpiarOrigenSeleccionado llamado");
    if (mounted) {
      state = state.copyWith(
        textoInputOrigenActual: '',
        clearPuntoOrigenParaBusqueda: true,
        clearNombreLugarOrigenSeleccionado: true,
        clearSugerenciasOrigen: true,
      );
    }
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

  @override
  void intercambiarOrigenYDestino() {
    if (mounted) {
      final origenActual = state.puntoOrigenParaBusqueda;
      final destinoActual = state.puntoDestinoParaBusqueda;
      final nombreOrigenActual = state.nombreLugarOrigenSeleccionado;
      final nombreDestinoActual = state.nombreLugarDestinoSeleccionado;
      final textoInputOrigenActual = state.textoInputOrigenActual;
      final textoInputDestinoActual = state.textoInputDestinoActual;

      var nuevoEstado = state.copyWith(
        textoInputOrigenActual: textoInputDestinoActual,
        textoInputDestinoActual: textoInputOrigenActual,
        puntoOrigenParaBusqueda: destinoActual,
        clearPuntoOrigenParaBusqueda: destinoActual == null,
        puntoDestinoParaBusqueda: origenActual,
        clearPuntoDestinoParaBusqueda: origenActual == null,
        nombreLugarOrigenSeleccionado: nombreDestinoActual,
        clearNombreLugarOrigenSeleccionado: nombreDestinoActual == null,
        nombreLugarDestinoSeleccionado: nombreOrigenActual,
        clearNombreLugarDestinoSeleccionado: nombreOrigenActual == null,
      );
      state = nuevoEstado; // Asignar el estado modificado
      print("[AppLogicNotifier] Origen y Destino intercambiados.");
    }
  }

  @override
  Future<void> seleccionarUbicacionActualComoOrigen() async {
    print("[LOCATION_FLOW] 📍 === INICIO FLUJO UBICACIÓN ACTUAL ====");
    print("[LOCATION_FLOW] 📍 Usuario solicitó ubicación actual como origen");
    print("[LOCATION_FLOW] 📍 Estado actual de la app: ${state.faseActual}");

    if (mounted) {
      state = state.copyWith(
        estadoUbicacionActual: EstadoSolicitud.CARGANDO,
        clearMensajeErrorUbicacion: true,
      );
      print("[LOCATION_FLOW] 📍 Estado cambiado a CARGANDO");
    }

    try {
      print("[LOCATION_FLOW] 🔐 Verificando permisos de ubicación...");
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      print("[LOCATION_FLOW] 🔐 Permiso actual: $permission");

      if (permission == LocationPermission.denied) {
        print("[LOCATION_FLOW] 🔐 Solicitando permisos de ubicación...");
        permission = await Geolocator.requestPermission();
        print("[LOCATION_FLOW] 🔐 Respuesta del usuario: $permission");
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        print("[LOCATION_FLOW] ❌ Permisos denegados - terminando flujo");
        if (mounted) {
          state = state.copyWith(
            estadoUbicacionActual: EstadoSolicitud.ERROR,
            mensajeErrorUbicacion:
                permission == LocationPermission.deniedForever
                    ? "Permisos de ubicación denegados permanentemente. Habilítalos en configuración."
                    : "Permisos de ubicación denegados",
          );
        }
        return;
      }

      print(
        "[LOCATION_FLOW] ✅ Permisos concedidos - obteniendo ubicación GPS...",
      );
      // Get current position
      final LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      print(
        "[LOCATION_FLOW] 📍 GPS obtenido: lat=${position.latitude}, lng=${position.longitude}",
      );
      print(
        "[LOCATION_FLOW] 📍 Precisión: ${position.accuracy}m, timestamp: ${position.timestamp}",
      );

      final Coordenada ubicacionActual = Coordenada(
        latitud: position.latitude,
        longitud: position.longitude,
      );

      // Try to get readable address via reverse geocoding
      print("[LOCATION_FLOW] 🗺️ Iniciando geocodificación inversa...");
      String nombreUbicacion = "Mi ubicación";
      try {
        final sugerencias = await _geocodingService.reverseGeocode(
          ubicacionActual,
        );
        print(
          "[LOCATION_FLOW] 🗺️ Geocoding devolvió ${sugerencias.length} sugerencias",
        );
        if (sugerencias.isNotEmpty) {
          nombreUbicacion = sugerencias.first.nombreCompleto;
          print("[LOCATION_FLOW] 🗺️ Dirección encontrada: $nombreUbicacion");
        } else {
          print(
            "[LOCATION_FLOW] 🗺️ No se encontraron direcciones - usando fallback",
          );
        }
      } catch (e) {
        print("[LOCATION_FLOW] ❌ Error en geocodificación inversa: $e");
        print("[LOCATION_FLOW] 🗺️ Usando nombre por defecto: Mi ubicación");
      }

      if (mounted) {
        state = state.copyWith(
          estadoUbicacionActual: EstadoSolicitud.EXITO,
          ubicacionActualUsuario: ubicacionActual,
          textoInputOrigenActual: nombreUbicacion,
          puntoOrigenParaBusqueda: ubicacionActual,
          nombreLugarOrigenSeleccionado: nombreUbicacion,
          clearSugerenciasOrigen: true,
        );
        print("[LOCATION_FLOW] ✅ Estado actualizado exitosamente");
        print("[LOCATION_FLOW] ✅ Origen configurado: $nombreUbicacion");
        print(
          "[LOCATION_FLOW] ✅ Coordenadas: ${ubicacionActual.latitud}, ${ubicacionActual.longitud}",
        );
        print("[LOCATION_FLOW] 📍 === FIN FLUJO UBICACIÓN (ÉXITO) ====");
      }
    } catch (e) {
      print("[LOCATION_FLOW] ❌ === EXCEPCIÓN EN FLUJO UBICACIÓN ====");
      print("[LOCATION_FLOW] ❌ Error: $e");
      print("[LOCATION_FLOW] ❌ Tipo: ${e.runtimeType}");
      if (mounted) {
        state = state.copyWith(
          estadoUbicacionActual: EstadoSolicitud.ERROR,
          mensajeErrorUbicacion:
              "Error obteniendo ubicación. Verifica que el GPS esté activado.",
        );
        print("[LOCATION_FLOW] ❌ Estado cambiado a ERROR");
      }
      print("[LOCATION_FLOW] ❌ === FIN FLUJO UBICACIÓN (ERROR) ====");
    }
  }

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
      final origenActual = state.puntoOrigenParaBusqueda;
      final destinoActual = state.puntoDestinoParaBusqueda;

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

      // DIFF: Inicializar tracking automático
      print("[JOURNEY_START] 📍 Inicializando tracking automático...");
      await _initializeAutomaticTracking(opcionConfirmada);

      // Actualizar estado con configuración automática inicial
      state = state.copyWith(
        isAutomaticNavigationEnabled: _automaticNavigationEnabled,
        currentJourneyStep: _currentJourneyStep,
        // CAMBIO: No inicializar currentStepProgress aquí, se hará en el primer update
      );
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

  // DIFF: Nuevo método para inicializar tracking automático
  Future<void> _initializeAutomaticTracking(
    OpcionDeRutaMostrable option,
  ) async {
    print("[AUTO_TRACKING] 🎯 === INICIALIZANDO TRACKING AUTOMÁTICO ====");
    print("[AUTO_TRACKING] 🎯 Opción de ruta: ${option.idOpcion}");
    print(
      "[AUTO_TRACKING] 🎯 Total de tramos: ${option.tramosParaPreview.length}",
    );

    try {
      print("[AUTO_TRACKING] 📍 Creando LocationTracker...");
      _locationTracker = LocationTracker(
        onLocationUpdate: _onUserLocationUpdate,
        onArrivalDetected: _onArrivalDetected,
        isTestMode: isTestMode,
      );
      print("[AUTO_TRACKING] ✅ LocationTracker creado exitosamente");

      // Configurar primer paso
      final primerTramo = option.tramosParaPreview[0];
      final stepType = _determineStepType(primerTramo);
      final destination = _getStepDestination(primerTramo);

      print("[AUTO_TRACKING] 🚶‍♂️ Configurando primer paso...");
      print("[AUTO_TRACKING] 🚶‍♂️   Tipo: $stepType");
      print("[AUTO_TRACKING] 🚶‍♂️   Destino: $destination");
      print("[AUTO_TRACKING] 🚶‍♂️   Descripción: ${primerTramo.descripcion}");

      // Get user's current location as the start of this step
      final userCurrentLocation = _locationTracker?.lastKnownLocation;

      _currentJourneyStep = JourneyStepState(
        stepIndex: 0,
        type: stepType,
        destination: destination,
        startLocation: userCurrentLocation,
        busLine: primerTramo.nombreLineaBus,
        instructions: _getStepInstructions(primerTramo),
        startTime: DateTime.now(),
      );
      print("[AUTO_TRACKING] ✅ Primer paso configurado");

      // Configurar geofences para primer paso
      print("[AUTO_TRACKING] 🎯 Configurando geofences...");
      _setupGeofencesForCurrentStep();
      print("[AUTO_TRACKING] ✅ Geofences configurados");

      // Iniciar tracking
      print("[AUTO_TRACKING] 📡 Iniciando LocationTracker...");
      await _locationTracker!.startTracking();
      print(
        "[AUTO_TRACKING] ✅ LocationTracker iniciado - actualizando cada 5 segundos",
      );

      print("[AUTO_TRACKING] ✅ === TRACKING AUTOMÁTICO INICIALIZADO ====");
    } catch (e) {
      print("[AUTO_TRACKING] ❌ === ERROR EN INICIALIZACIÓN ====");
      print("[AUTO_TRACKING] ❌ Error: $e");
      print("[AUTO_TRACKING] ❌ Tipo: ${e.runtimeType}");
      print("[AUTO_TRACKING] ❌ Fallback a modo manual");
      _automaticNavigationEnabled = false;
      print("[AUTO_TRACKING] ❌ === FIN ERROR ====");
    }
  }

  // DIFF: Callback de actualización de ubicación
  void _onUserLocationUpdate(Coordenada newLocation) {
    // Feature logs
    try {
      FeatureLogger().log(
        'auto_nav',
        'location_update',
        data: {
          'lat': newLocation.latitud,
          'lon': newLocation.longitud,
          'step': _currentJourneyStep?.stepIndex,
          'type': _currentJourneyStep?.type.toString(),
        },
      );
    } catch (_) {}
    // Eliminado: registro dev de ubicación del usuario
    print("[LOCATION_UPDATE] 📍 === NUEVA UBICACIÓN DETECTADA ====");
    print(
      "[LOCATION_UPDATE] 📍 Ubicación: ${newLocation.latitud}, ${newLocation.longitud}",
    );
    print(
      "[LOCATION_UPDATE] 📍 Paso actual: ${_currentJourneyStep?.stepIndex}",
    );
    print("[LOCATION_UPDATE] 📍 Tipo de paso: ${_currentJourneyStep?.type}");
    print(
      "[LOCATION_UPDATE] 📍 Navegación automática: $_automaticNavigationEnabled",
    );

    // CRITICAL FIX: Sincronización de timers
    final now = DateTime.now();
    if (_lastLocationUpdate != null) {
      final timeSinceLastUpdate =
          now.difference(_lastLocationUpdate!).inMilliseconds;
      print(
        "[TIMER_SYNC] ⏱️ Tiempo desde última actualización: ${timeSinceLastUpdate}ms",
      );

      // Si han pasado menos de 4 segundos, podría haber condición de carrera
      if (timeSinceLastUpdate < 4000) {
        print(
          "[TIMER_SYNC] ⚠️ Actualizaciones muy frecuentes - verificando sincronización",
        );
      }
    }
    _lastLocationUpdate = now;

    // Verificar si el notifier ya está disposed
    if (!mounted ||
        _currentJourneyStep == null ||
        !_automaticNavigationEnabled) {
      print("[LOCATION_UPDATE] ⚠️ Tracking no disponible - saliendo");
      return;
    }

    // NUEVO: si startLocation aún no está definido, usar la primera ubicación recibida
    if (_currentJourneyStep!.startLocation == null) {
      print("[LOCATION_UPDATE] 🏁 Estableciendo startLocation inicial");
      _currentJourneyStep = _currentJourneyStep!.copyWith(
        startLocation: newLocation,
      );
    }

    // DIFF: Actualizar ubicación del usuario en el mapa inmediatamente
    print(
      "[LOCATION_UPDATE] 🗺️ Actualizando ubicación en mapa inmediatamente...",
    );
    _updateUserLocationOnMap(newLocation);
    try {
      FeatureLogger().log(
        'journey',
        'user_loc_pushed_to_map',
        data: {'lat': newLocation.latitud, 'lon': newLocation.longitud},
      );
    } catch (_) {}

    // NUEVO: Detectar transición automática de WAITING_FOR_BUS a RIDING_BUS
    if (_currentJourneyStep!.type == JourneyStepType.WAITING_FOR_BUS) {
      _monitorDepartureFromStop(newLocation);
      _checkForBusBoarding(newLocation);
      try {
        FeatureLogger().log(
          'auto_nav',
          'waiting_bus_checks',
          data: {'step': _currentJourneyStep?.stepIndex},
        );
      } catch (_) {}
    }

    // DIFF: Manear tracking híbrido de bus
    _handleHybridBusTracking(newLocation);

    print("[LOCATION_UPDATE] 🧮 Calculando progreso dinámico...");
    // Calcular progreso dinámico de forma asíncrona
    _calculateStepProgress(newLocation)
        .then((progress) {
          if (_currentJourneyStep == null) {
            print("[LOCATION_UPDATE] ⚠️ Paso actual perdido durante cálculo");
            return;
          }

          print("[LOCATION_UPDATE] 📊 Progreso calculado:");
          print(
            "[LOCATION_UPDATE] 📊   Distancia restante: ${progress.remainingDistance.toStringAsFixed(0)}m",
          );
          print(
            "[LOCATION_UPDATE] 📊   Porcentaje: ${progress.percentageComplete.toStringAsFixed(1)}%",
          );
          print(
            "[LOCATION_UPDATE] 📊   Tiempo restante: ${progress.remainingTimeSeconds}s",
          );

          // Actualizar estado con nuevo progreso
          _currentJourneyStep = _currentJourneyStep!.copyWith(
            progressPercentage: progress.percentageComplete,
            remainingDistance: progress.remainingDistance,
            remainingTimeSeconds: progress.remainingTimeSeconds,
          );

          // Actualizar estado global
          state = state.copyWith(
            currentJourneyStep: _currentJourneyStep,
            currentStepProgress: progress,
          );
          try {
            FeatureLogger().log(
              'auto_nav',
              'progress',
              data: {
                'pct': progress.percentageComplete.toStringAsFixed(1),
                'remain_m': progress.remainingDistance.toStringAsFixed(0),
                'remain_s': progress.remainingTimeSeconds,
              },
            );
          } catch (_) {}

          print("[LOCATION_UPDATE] ✅ Estado actualizado con nuevo progreso");
        })
        .catchError((error) {
          print("[LOCATION_UPDATE] ❌ Error calculando progreso: $error");
        });

    // NUEVO: Guardar ubicación previa para análisis direccional
    _previousUserLocation = newLocation;

    print("[LOCATION_UPDATE] ✅ === FIN ACTUALIZACIÓN UBICACIÓN ====");
  }

  void devPushMockUserLocation(Coordenada location) {
    // Throttle específico para simulador para no sobrecargar progreso/UI.
    const int throttleMs = 500; // Intervalo mínimo entre updates simuladas
    final now = DateTime.now();
    if (_lastDevMockPush != null) {
      final diff = now.difference(_lastDevMockPush!).inMilliseconds;
      if (diff < throttleMs) {
        // Ignorar update demasiado cercana
        return;
      }
    }
    _lastDevMockPush = now;
    // Reusar pipeline real vía LocationTracker para mantener geofences/velocidad
    if (_locationTracker != null) {
      _locationTracker!.injectLocationUpdate(location);
    } else {
      _onUserLocationUpdate(location);
    }
  }

  // ====== DEV: Simulación basada en la ruta actual (sin dataset) ======
  Future<void> devStartTripSimulation({double speed = 1.0}) async {
    // Capturar última posición real del bus ANTES de limpiar estado
    final lastBusPos = state.datosFaseViajeActivo?.posicionActualBusReal;
    // Apagar seguimiento API para no competir
    await detenerSeguimientoBusTiempoReal();
    // Asegurar tracker en modo feed externo para mantener pipeline real
    if (_locationTracker == null) {
      final created = LocationTracker(
        onLocationUpdate: _onUserLocationUpdate,
        onArrivalDetected: _onArrivalDetected,
        isTestMode: false,
      );
      _locationTracker = created;
      await _locationTracker!.startTracking();
    }
    _locationTracker!.enterExternalFeedMode();
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

  // Eliminado: APIs de reproducción/recording manual

  // Pausar solo el LocationTracker sin limpiar el paso actual ni deshabilitar navegación automática
  void _pauseOnlyLocationTracker() {
    if (_locationTracker != null) {
      print(
        '[STOP_TRACKING] ⏸️ Pausando solo LocationTracker (mantener paso actual)',
      );
      _locationTracker?.dispose();
      _locationTracker = null;
      print('[STOP_TRACKING] ✅ LocationTracker pausado');
    }
    // Mantener _currentJourneyStep y _automaticNavigationEnabled como están
  }

  // NUEVO: Método para detectar subida al bus
  void _checkForBusBoarding(Coordenada userLocation) {
    print("[BUS_BOARDING] 🚌 === VERIFICANDO SUBIDA AL BUS ====");

    try {
      FeatureLogger().log(
        'auto_nav',
        'check_boarding',
        data: {
          'lat': userLocation.latitud,
          'lon': userLocation.longitud,
          'speed': (_locationTracker?.currentSpeed ?? 0.0).toStringAsFixed(2),
          'step': _currentJourneyStep?.stepIndex,
        },
      );
    } catch (_) {}

    final activeTripState = state.datosFaseViajeActivo;
    if (activeTripState == null) {
      print("[BUS_BOARDING] ⚠️ No hay viaje activo");
      return;
    }

    // Obtener velocidad real del usuario del LocationTracker
    final userSpeed = _locationTracker?.currentSpeed ?? 0.0;
    print(
      "[BUS_BOARDING] 🏃‍♂️ Velocidad del usuario: ${userSpeed.toStringAsFixed(2)} m/s (${(userSpeed * 3.6).toStringAsFixed(1)} km/h)",
    );

    // Buscar el próximo tramo de bus
    final currentStepIndex = _currentJourneyStep!.stepIndex;
    TramoViajeMostrable? nextBusSegment;

    for (
      int i = currentStepIndex;
      i < activeTripState.tramosDelViaje.length;
      i++
    ) {
      final tramo = activeTripState.tramosDelViaje[i];
      if (tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS) {
        nextBusSegment = tramo;
        break;
      }
    }

    if (nextBusSegment == null) {
      print("[BUS_BOARDING] ⚠️ No se encontró próximo tramo de bus");
      return;
    }

    // Gate 1: requerir posición del bus en tiempo real para evaluar si llegó/pasó la parada
    final busPos = activeTripState.posicionActualBusReal;
    if (busPos == null) {
      print(
        "[BUS_BOARDING] ⏳ Sin posición de bus en tiempo real → no evaluar subida",
      );
      print("[BUS_BOARDING] ✅ === FIN VERIFICACIÓN SUBIDA AL BUS ====");
      return;
    }

    // Gate 2: solo permitir boarding si el bus llegó a la parada de origen o ya la pasó
    final busAtOrPastStop = _busArrivedOrPassedOriginStop(
      nextBusSegment,
      busPos,
    );
    print("[BUS_BOARDING] 🔎 Gate busAtOrPastStop=$busAtOrPastStop");
    if (!busAtOrPastStop) {
      print(
        "[BUS_BOARDING] ⏳ Bus aún no llegó/pasó la parada → WAITING_FOR_BUS",
      );
      print("[BUS_BOARDING] ✅ === FIN VERIFICACIÓN SUBIDA AL BUS ====");
      return;
    }

    // FORZAR SUBIDA si el bus pasó/llegó a la parada y el usuario está en la parada (o muy cerca)
    try {
      final stopOrigin = nextBusSegment.coordenadasParadaOrigen;
      if (stopOrigin != null) {
        final distToStop = calculateHaversineDistance(
          userLocation.latitud,
          userLocation.longitud,
          stopOrigin.latitud,
          stopOrigin.longitud,
        );
        print(
          "[BUS_BOARDING] 📏 Distancia usuario a parada origen: ${distToStop.toStringAsFixed(1)}m",
        );
        // Umbral de 30m para considerar que el usuario está en la parada
        if (distToStop <= 30.0) {
          print(
            "[BUS_BOARDING] ✅ Gate: bus pasó/llegó + usuario en parada → SUBIDA FORZADA",
          );
          try {
            FeatureLogger().log(
              'auto_nav',
              'boarding_detected_gate',
              data: {'dist_m': distToStop.toStringAsFixed(1)},
            );
          } catch (_) {}
          _busBoardingPositiveCount = _busBoardingRequiredConsecutive;
          _transitionToNextStep();
          return;
        }
      }
    } catch (e) {
      print("[BUS_BOARDING] ⚠️ Error en gate forzado: $e");
    }

    // Obtener puntos de la ruta del bus desde geometriaPolilinea
    final busRoutePoints = nextBusSegment.geometriaPolilinea ?? [];
    if (busRoutePoints.isEmpty) {
      print("[BUS_BOARDING] ⚠️ No hay geometría de ruta para el bus");
      return;
    }

    print("[BUS_BOARDING] 🗺️ Verificando proximidad a ruta del bus...");
    print("[BUS_BOARDING] 🗺️ Puntos de ruta: ${busRoutePoints.length}");

    // Obtener bearing del usuario si tenemos ubicación previa
    double? userBearing;
    if (_previousUserLocation != null) {
      userBearing = _calculateBearing(_previousUserLocation!, userLocation);
      print(
        "[BUS_BOARDING] 🧭 Dirección del usuario: ${userBearing.toStringAsFixed(1)}°",
      );
    }

    // Usar detección de subida al bus con análisis direccional mejorado
    final busBoarding = RouteDynamicCalculator.detectBusBoarding(
      userLocation: userLocation,
      busRoutePoints: busRoutePoints,
      userSpeed: userSpeed,
      minBusSpeed:
          2.5, // RESTAURADO: 2.5 m/s (9 km/h) - velocidad mínima realista de bus
      routeThreshold: 50.0, // REDUCIDO: 50m de proximidad para ser más preciso
      previousLocation: _previousUserLocation,
      userBearing: userBearing,
    );

    print("[BUS_BOARDING] 🎯 Detección resultado: $busBoarding");
    print(
      "[BUS_BOARDING] 🎯   - Velocidad suficiente: ${userSpeed >= 2.5} (${userSpeed.toStringAsFixed(2)} >= 2.5 m/s)",
    );

    final now = DateTime.now();
    if (_lastBusBoardingEval != null &&
        now.difference(_lastBusBoardingEval!) < _busBoardingEvalMinSpacing) {
      print("[BUS_BOARDING] ⏳ Saltando evaluación (intervalo mínimo)");
    } else {
      _lastBusBoardingEval = now;
      if (busBoarding) {
        _busBoardingPositiveCount++;
      } else {
        _busBoardingPositiveCount = 0;
      }
      print(
        "[BUS_BOARDING] 🔁 Positivos consecutivos: $_busBoardingPositiveCount / $_busBoardingRequiredConsecutive",
      );
      if (_busBoardingPositiveCount >= _busBoardingRequiredConsecutive) {
        print("[BUS_BOARDING] ✅ Histéresis satisfecha → SUBIDA CONFIRMADA");
        _busBoardingPositiveCount = 0;
        _transitionToNextStep();
        print("[BUS_BOARDING] ✅ === FIN VERIFICACIÓN SUBIDA AL BUS ====");
        return;
      }
    }

    if (busBoarding) {
      print("[BUS_BOARDING] ⏳ Acumulando positivos para confirmar subida...");
    } else if (userSpeed < 2.5) {
      print(
        "[BUS_BOARDING] ⏳ Usuario lento (${(userSpeed * 3.6).toStringAsFixed(1)} km/h) - espera continúa",
      );
    } else {
      print("[BUS_BOARDING] ⏳ Proximidad / dirección insuficiente todavía");
    }

    print("[BUS_BOARDING] ✅ === FIN VERIFICACIÓN SUBIDA AL BUS ====");
  }

  // Detecta si el usuario se alejó demasiado de la parada mientras espera y revierte al paso de caminar previo.
  void _monitorDepartureFromStop(Coordenada userLocation) {
    final active = state.datosFaseViajeActivo;
    if (active == null || _currentJourneyStep == null) return;
    final idx = _currentJourneyStep!.stepIndex;
    if (idx <= 0 || idx >= active.tramosDelViaje.length) return;
    final waitingTramo = active.tramosDelViaje[idx];
    if (waitingTramo.tipo != TipoTramoViaje.ESPERAR_BUS) return;
    final stop =
        waitingTramo.coordenadasParadaOrigen ?? waitingTramo.posicionPunto;
    if (stop == null) return;
    final dist = calculateHaversineDistance(
      userLocation.latitud,
      userLocation.longitud,
      stop.latitud,
      stop.longitud,
    );
    if (dist > _departureThresholdMeters) {
      final prevIdx = idx - 1;
      if (prevIdx >= 0) {
        final prevTramo = active.tramosDelViaje[prevIdx];
        if (prevTramo.tipo == TipoTramoViaje.CAMINAR) {
          print(
            '[DEPARTURE] Usuario se alejó ${dist.toStringAsFixed(1)}m → volver a paso caminar index=$prevIdx',
          );
          _currentJourneyStep = JourneyStepState(
            stepIndex: prevIdx,
            type: JourneyStepType.WALKING_TO_STOP,
            destination: stop,
            startLocation: userLocation,
            busLine: prevTramo.nombreLineaBus,
            instructions: prevTramo.descripcion ?? 'Regresa a la parada',
            startTime: DateTime.now(),
            progressPercentage: 0.0,
          );
          _busBoardingPositiveCount = 0;
          _setupGeofencesForCurrentStep();
          state = state.copyWith(
            currentJourneyStep: _currentJourneyStep,
            currentStepProgress: RouteProgress(
              percentageComplete: 0.0,
              remainingDistance: dist,
              remainingTimeSeconds: 0,
              currentOptimalRoute: [],
              totalDistance: dist,
              completedDistance: 0.0,
            ),
          );
        }
      }
    }
  }

  // NUEVO: Helper - verifica si el bus ya llegó a la parada de origen o ya la pasó
  bool _busArrivedOrPassedOriginStop(
    TramoViajeMostrable tramoBus,
    Coordenada busPos,
  ) {
    final stop = tramoBus.coordenadasParadaOrigen;
    final dest = tramoBus.coordenadasParadaDestino;
    if (stop == null) {
      print("[BUS_GATE] ⚠️ Stop de origen no disponible");
      return false;
    }

    const double ARRIVAL_M = 50.0;
    const double PASS_PROJ_MIN_M = 25.0;
    const double CORRIDOR_M = 60.0;

    // Distancia directa bus → parada
    final distToStop = calculateHaversineDistance(
      busPos.latitud,
      busPos.longitud,
      stop.latitud,
      stop.longitud,
    );
    final arrived = distToStop <= ARRIVAL_M;

    // Preparar geometría (shape completo si está disponible, sino la polilínea del tramo)
    final shape =
        getFullShapeGeometry(tramoBus.shapeId) ?? tramoBus.geometriaPolilinea;
    final hasShape = shape != null && shape.isNotEmpty && shape.length >= 2;

    print("[BUS_GATE] --- Evaluando arribo/paso de parada origen ---");
    print(
      "[BUS_GATE] stop=(${stop.latitud.toStringAsFixed(6)}, ${stop.longitud.toStringAsFixed(6)}), bus=(${busPos.latitud.toStringAsFixed(6)}, ${busPos.longitud.toStringAsFixed(6)})",
    );
    print(
      "[BUS_GATE] distToStop=${distToStop.toStringAsFixed(1)}m, arrived=$arrived, hasShape=$hasShape",
    );

    if (arrived) {
      print("[BUS_GATE] ✅ Resultado: TRUE (arrived)");
      return true;
    }

    // 2) Detectar si ya pasó la parada usando la geometría del shape (preferido)
    if (hasShape) {
      final stopIdx = findClosestPointIndexOnShape(shape, stop);
      final busIdx = findClosestPointIndexOnShape(shape, busPos);
      final destIdx =
          dest != null ? findClosestPointIndexOnShape(shape, dest) : -1;
      final forward = destIdx >= 0 ? (destIdx > stopIdx) : true;

      // Distancia al corredor alrededor del índice del bus (segmentos adyacentes)
      double corridorDist = double.infinity;
      void checkSeg(int a, int b) {
        if (a >= 0 && b >= 0 && a < shape.length && b < shape.length) {
          final d = distanceToLineSegment(busPos, shape[a], shape[b]);
          if (d < corridorDist) corridorDist = d;
        }
      }

      checkSeg(busIdx, busIdx + 1);
      checkSeg(busIdx - 1, busIdx);

      final inCorridor = corridorDist <= CORRIDOR_M;
      final byIndexLoose = forward ? (busIdx > stopIdx) : (busIdx < stopIdx);
      final byIndexStrict =
          forward ? (busIdx > stopIdx + 1) : (busIdx < stopIdx - 1);

      // Proyección local desde la parada en dirección del siguiente punto del shape
      double projMeters = 0.0;
      if (stopIdx >= 0) {
        final nextIdx =
            forward
                ? (stopIdx + 1 < shape.length ? stopIdx + 1 : stopIdx)
                : (stopIdx - 1 >= 0 ? stopIdx - 1 : stopIdx);

        // Conversión aproximada a metros (equirectangular local)
        final ky = 111320.0;
        final kx = 111320.0 * cos(stop.latitud * pi / 180.0);
        final ax = (shape[nextIdx].longitud - stop.longitud) * kx;
        final ay = (shape[nextIdx].latitud - stop.latitud) * ky;
        final aLen = sqrt(ax * ax + ay * ay);
        if (aLen > 0) {
          final vx = (busPos.longitud - stop.longitud) * kx;
          final vy = (busPos.latitud - stop.latitud) * ky;
          projMeters = (vx * ax + vy * ay) / aLen;
        }
      }
      // Endurecer condición de "pasado": requerir proyección > 50 m
      final projOk = projMeters > 50.0;

      final passed = inCorridor && (byIndexStrict || (byIndexLoose && projOk));

      print(
        "[BUS_GATE] shapeLen=${shape.length}, stopIdx=$stopIdx, busIdx=$busIdx, destIdx=$destIdx, forward=$forward",
      );
      print(
        "[BUS_GATE] corridorDist=${corridorDist.toStringAsFixed(1)}m, inCorridor=$inCorridor",
      );
      print(
        "[BUS_GATE] byIndexLoose=$byIndexLoose, byIndexStrict=$byIndexStrict, proj=${projMeters.toStringAsFixed(1)}m, projOk=$projOk",
      );
      print(
        "[BUS_GATE] ✅ Resultado: ${passed ? 'TRUE' : 'FALSE'} (arrived=$arrived, passed=$passed)",
      );
      return passed;
    }

    // 3) Fallback sin shape: proyección en vector (parada origen → destino) + corredor al segmento
    if (dest == null) {
      print("[BUS_GATE] ⚠️ Sin shape ni destino → FALSE");
      print("[BUS_GATE] ✅ Resultado: FALSE");
      return false;
    }

    // Conversión aproximada a metros (equirectangular local)
    final ky = 111320.0;
    final kx = 111320.0 * cos(stop.latitud * pi / 180.0);
    final ux = (dest.longitud - stop.longitud) * kx;
    final uy = (dest.latitud - stop.latitud) * ky;
    final uLen = sqrt(ux * ux + uy * uy);
    final vx = (busPos.longitud - stop.longitud) * kx;
    final vy = (busPos.latitud - stop.latitud) * ky;
    final projMeters = uLen > 0 ? (vx * ux + vy * uy) / uLen : 0.0;

    final perpDist = distanceToLineSegment(busPos, stop, dest);
    final inCorridor = perpDist <= CORRIDOR_M;
    final projOk = projMeters > 50.0;
    final passed = inCorridor && projOk;

    print(
      "[BUS_GATE] (fallback) perpDist=${perpDist.toStringAsFixed(1)}m, inCorridor=$inCorridor, proj=${projMeters.toStringAsFixed(1)}m, projOk=$projOk",
    );
    print(
      "[BUS_GATE] ✅ Resultado: ${passed ? 'TRUE' : 'FALSE'} (arrived=$arrived, passed=$passed)",
    );
    return passed;
  }

  // DIFF: Callback de llegada detectada
  void _onArrivalDetected(String geofenceId) {
    try {
      FeatureLogger().log(
        'auto_nav',
        'arrival_detected',
        data: {
          'geofence': geofenceId,
          'step': _currentJourneyStep?.stepIndex,
          'type': _currentJourneyStep?.type.toString(),
        },
      );
    } catch (_) {}
    print("[ARRIVAL_DETECTION] 🎯 === LLEGADA DETECTADA ====");
    print("[ARRIVAL_DETECTION] 🎯 Geofence ID: $geofenceId");
    print(
      "[ARRIVAL_DETECTION] 🎯 Paso actual: ${_currentJourneyStep?.stepIndex}",
    );
    print("[ARRIVAL_DETECTION] 🎯 Tipo actual: ${_currentJourneyStep?.type}");

    // Verificar si el notifier ya está disposed
    if (!mounted) {
      print("[ARRIVAL_DETECTION] ⚠️ Notifier disposed - saliendo");
      return;
    }

    print("[ARRIVAL_DETECTION] 🎯 Iniciando transición automática...");
    _transitionToNextStep();
  }

  // DIFF: Transición automática al siguiente paso
  void _transitionToNextStep() {
    try {
      FeatureLogger().log(
        'auto_nav',
        'transition_start',
        data: {'from': _currentJourneyStep?.stepIndex},
      );
    } catch (_) {}
    print("[STEP_TRANSITION] 🔄 === TRANSICIÓN AUTOMÁTICA ====");
    print(
      "[STEP_TRANSITION] 🔄 Paso actual: ${_currentJourneyStep?.stepIndex}",
    );
    print(
      "[STEP_TRANSITION] 🔄 Navegación automática: $_automaticNavigationEnabled",
    );

    if (_currentJourneyStep == null || !_automaticNavigationEnabled) {
      print("[STEP_TRANSITION] ❌ Condiciones no válidas - abortando");
      try {
        FeatureLogger().log('auto_nav', 'transition_abort');
      } catch (_) {}
      return;
    }

    final currentStepIndex = _currentJourneyStep!.stepIndex;
    final nextStepIndex = currentStepIndex + 1;
    final activeTripState = state.datosFaseViajeActivo;

    print("[STEP_TRANSITION] 🔄 Siguiente paso será: $nextStepIndex");
    print(
      "[STEP_TRANSITION] 🔄 Total de tramos: ${activeTripState?.tramosDelViaje.length}",
    );

    if (activeTripState == null ||
        nextStepIndex >= activeTripState.tramosDelViaje.length) {
      print(
        "[STEP_TRANSITION] 🏁 VIAJE COMPLETADO - todos los pasos finalizados",
      );
      _completeJourney();
      try {
        FeatureLogger().log('auto_nav', 'journey_complete');
      } catch (_) {}
      return;
    }

    // Actualizar al siguiente paso
    final nextTramo = activeTripState.tramosDelViaje[nextStepIndex];
    final nextStepType = _determineStepType(nextTramo);
    final nextDestination = _getStepDestination(nextTramo);

    print("[STEP_TRANSITION] ➡️ Configurando nuevo paso:");
    print("[STEP_TRANSITION] ➡️   Índice: $nextStepIndex");
    print("[STEP_TRANSITION] ➡️   Tipo: $nextStepType");
    print("[STEP_TRANSITION] ➡️   Destino: $nextDestination");
    print("[STEP_TRANSITION] ➡️   Línea bus: ${nextTramo.nombreLineaBus}");
    print("[STEP_TRANSITION] ➡️   Descripción: ${nextTramo.descripcion}");

    _currentJourneyStep = JourneyStepState(
      stepIndex: nextStepIndex,
      type: nextStepType,
      destination: nextDestination,
      busLine: nextTramo.nombreLineaBus,
      instructions: _getStepInstructions(nextTramo),
      startTime: DateTime.now(),
    );
    print("[STEP_TRANSITION] ✅ Nuevo paso configurado");
    try {
      FeatureLogger().log(
        'journey',
        'step_configured',
        data: {'index': nextStepIndex, 'type': nextStepType.toString()},
      );
    } catch (_) {}

    // Reconfigurar geofences
    print("[STEP_TRANSITION] 🎯 Reconfigurando geofences...");
    _setupGeofencesForCurrentStep();
    print("[STEP_TRANSITION] ✅ Geofences reconfigurados");

    // DIFF: Configurar modo de tracking de bus apropiado
    print("[STEP_TRANSITION] 🚌 Configurando modo de tracking de bus...");
    _configureBusTrackingForStep(nextStepType);
    print("[STEP_TRANSITION] ✅ Tracking de bus configurado");
    try {
      FeatureLogger().log('journey', 'bus_tracking_configured');
    } catch (_) {}

    // Notificar cambio a UI
    print("[STEP_TRANSITION] 📱 Notificando cambio a UI...");
    _notifyStepTransition();
    print("[STEP_TRANSITION] ✅ UI notificada");
    try {
      FeatureLogger().log('journey', 'ui_notified_step');
    } catch (_) {}

    print("[STEP_TRANSITION] ✅ === TRANSICIÓN COMPLETADA ====");
    print(
      "[STEP_TRANSITION] ✅ Nuevo paso activo: $nextStepIndex (${nextStepType})",
    );
    try {
      FeatureLogger().log(
        'auto_nav',
        'transition_done',
        data: {'to': nextStepIndex},
      );
    } catch (_) {}
  }

  // DIFF: Métodos auxiliares
  JourneyStepType _determineStepType(TramoViajeMostrable tramo) {
    switch (tramo.tipo) {
      case TipoTramoViaje.CAMINAR:
        // Determinar si es caminar a parada o a destino final
        final activeTripState = state.datosFaseViajeActivo;
        if (activeTripState != null) {
          final currentIndex = activeTripState.tramosDelViaje.indexOf(tramo);
          final isLastStep =
              currentIndex == activeTripState.tramosDelViaje.length - 1;
          return isLastStep
              ? JourneyStepType.WALKING_TO_DESTINATION
              : JourneyStepType.WALKING_TO_STOP;
        }
        return JourneyStepType.WALKING_TO_STOP;
      case TipoTramoViaje.ESPERAR_BUS:
        return JourneyStepType.WAITING_FOR_BUS;
      case TipoTramoViaje.VIAJE_EN_BUS:
        return JourneyStepType.RIDING_BUS;
      default:
        return JourneyStepType.WALKING_TO_STOP;
    }
  }

  Coordenada? _getStepDestination(TramoViajeMostrable tramo) {
    switch (tramo.tipo) {
      case TipoTramoViaje.CAMINAR:
        // Para caminar, usar el último punto de la geometría
        if (tramo.geometriaPolilinea != null &&
            tramo.geometriaPolilinea!.isNotEmpty) {
          return tramo.geometriaPolilinea!.last;
        }
        return null;
      case TipoTramoViaje.ESPERAR_BUS:
        // Para esperar bus, usar la posición de la parada
        return tramo.posicionPunto ?? tramo.coordenadasParadaOrigen;
      case TipoTramoViaje.VIAJE_EN_BUS:
        // Para viaje en bus, usar la parada destino
        return tramo.coordenadasParadaDestino;
      default:
        return null;
    }
  }

  String _getStepInstructions(TramoViajeMostrable tramo) {
    switch (tramo.tipo) {
      case TipoTramoViaje.CAMINAR:
        return tramo.descripcion ?? 'Camina hacia el destino';
      case TipoTramoViaje.ESPERAR_BUS:
        return 'Espera el bus ${tramo.nombreLineaBus ?? ''}';
      case TipoTramoViaje.VIAJE_EN_BUS:
        return 'Viaja en el bus ${tramo.nombreLineaBus ?? ''}';
      default:
        return tramo.descripcion ?? 'Continúa el viaje';
    }
  }

  Future<RouteProgress> _calculateStepProgress(Coordenada userLocation) async {
    if (_currentJourneyStep == null ||
        _currentJourneyStep!.destination == null) {
      return RouteProgress(
        percentageComplete: 0,
        remainingDistance: 0,
        remainingTimeSeconds: 0,
        currentOptimalRoute: [],
        totalDistance: 0,
        completedDistance: 0,
      );
    }

    final active = state.datosFaseViajeActivo;
    if (active == null) {
      return RouteProgress(
        percentageComplete: 0,
        remainingDistance: 0,
        remainingTimeSeconds: 0,
        currentOptimalRoute: [],
        totalDistance: 0,
        completedDistance: 0,
      );
    }

    if (_currentJourneyStep!.stepIndex >= active.tramosDelViaje.length) {
      return RouteProgress(
        percentageComplete: 0,
        remainingDistance: 0,
        remainingTimeSeconds: 0,
        currentOptimalRoute: [],
        totalDistance: 0,
        completedDistance: 0,
      );
    }

    final tramo = active.tramosDelViaje[_currentJourneyStep!.stepIndex];
    final poly = tramo.geometriaPolilinea;
    // Si hay polilínea, usarla para progreso real
    if (poly != null && poly.length >= 2) {
      // Distancia total
      double total = 0.0;
      for (int i = 0; i < poly.length - 1; i++) {
        total += calculateHaversineDistance(
          poly[i].latitud,
          poly[i].longitud,
          poly[i + 1].latitud,
          poly[i + 1].longitud,
        );
      }
      // Metros recorridos usando proyección a segmento
      final completed = RouteDynamicCalculator.progressAlongPolyline(
        point: userLocation,
        polyline: poly,
      );
      final remaining = (total - completed).clamp(0.0, total);
      final pct =
          total > 0 ? ((completed / total) * 100.0).clamp(0.0, 100.0) : 0.0;
      int remainingSecs;
      // Reusar heurísticas: si es bus, usar velocidad bus (30km/h), si no caminar (5km/h)
      const double walkingSpeedMps = 1.4;
      const double busSpeedMps = 8.33;
      final speed =
          _currentJourneyStep!.type == JourneyStepType.RIDING_BUS
              ? busSpeedMps
              : walkingSpeedMps;
      remainingSecs = speed > 0 ? (remaining / speed).round() : 0;
      return RouteProgress(
        percentageComplete: pct,
        remainingDistance: remaining,
        remainingTimeSeconds: remainingSecs,
        currentOptimalRoute: poly,
        totalDistance: total,
        completedDistance: completed,
      );
    }

    // Fallback a cálculo por línea recta, diferenciando bus/caminar
    if (_currentJourneyStep!.type == JourneyStepType.RIDING_BUS) {
      return RouteDynamicCalculator.calculateBusProgress(
        startLocation: _currentJourneyStep!.startLocation ?? userLocation,
        currentLocation: userLocation,
        destination: _currentJourneyStep!.destination!,
      );
    }
    return RouteDynamicCalculator.calculateProgress(
      startLocation: _currentJourneyStep!.startLocation ?? userLocation,
      currentLocation: userLocation,
      destination: _currentJourneyStep!.destination!,
    );
  }

  void _setupGeofencesForCurrentStep() {
    print("[GEOFENCE_SETUP] 🎯 === CONFIGURANDO GEOFENCES ====");

    if (_locationTracker == null || _currentJourneyStep == null) {
      print("[GEOFENCE_SETUP] ⚠️ LocationTracker o paso actual no disponible");
      return;
    }

    // NUEVO: Para WAITING_FOR_BUS, NO configurar geofences automáticos
    // La transición debe ocurrir solo por detección de subida al bus
    if (_currentJourneyStep!.type == JourneyStepType.WAITING_FOR_BUS) {
      print(
        "[GEOFENCE_SETUP] 🚏 Paso WAITING_FOR_BUS - NO configurando geofences automáticos",
      );
      print(
        "[GEOFENCE_SETUP] 🚏 Transición ocurrirá solo por detección de subida al bus",
      );

      // Limpiar geofences existentes
      _locationTracker!.setupGeofencesForStep([], []);
      print("[GEOFENCE_SETUP] ✅ Geofences limpiados para WAITING_FOR_BUS");
      print("[GEOFENCE_SETUP] ✅ === FIN CONFIGURACIÓN GEOFENCES ====");
      return;
    }

    final destination = _currentJourneyStep!.destination;
    if (destination == null) {
      print(
        "[GEOFENCE_SETUP] ⚠️ No hay destino para el paso actual - saltando geofences",
      );
      return;
    }

    print(
      "[GEOFENCE_SETUP] 🎯 Configurando geofence para destino: ${destination.latitud}, ${destination.longitud}",
    );
    print("[GEOFENCE_SETUP] 🎯 Tipo de paso: ${_currentJourneyStep!.type}");
    print(
      "[GEOFENCE_SETUP] 🎯 Índice de paso: ${_currentJourneyStep!.stepIndex}",
    );

    final geofenceId = "step_${_currentJourneyStep!.stepIndex}_destination";
    print("[GEOFENCE_SETUP] 🎯 Creando geofence: $geofenceId");
    print(
      "[GEOFENCE_SETUP] 🎯   Centro: ${destination.latitud}, ${destination.longitud}",
    );
    print("[GEOFENCE_SETUP] 🎯   Radio: 50.0m");

    print("[GEOFENCE_SETUP] 🎯 Usando método setupGeofencesForStep");

    // Usar el método existente de LocationTracker
    _locationTracker!.setupGeofencesForStep([destination], [geofenceId]);
    try {
      FeatureLogger().log(
        'geofence',
        'configured',
        data: {
          'id': geofenceId,
          'lat': destination.latitud,
          'lon': destination.longitud,
          'type': _currentJourneyStep!.type.toString(),
        },
      );
    } catch (_) {}

    print("[GEOFENCE_SETUP] ✅ Geofence configurado exitosamente");
    print("[GEOFENCE_SETUP] ✅ === FIN CONFIGURACIÓN GEOFENCES ====");
  }

  void _updateUIWithLocationProgress() {
    print("[UI_UPDATE] 📱 === ACTUALIZANDO UI CON PROGRESO ====");
    print("[UI_UPDATE] 📱 Mounted: $mounted");
    print("[UI_UPDATE] 📱 Paso actual: ${_currentJourneyStep != null}");

    if (mounted && _currentJourneyStep != null) {
      final step = _currentJourneyStep!;
      final userLocation = _locationTracker?.lastKnownLocation;

      print("[UI_UPDATE] 📱 Datos del progreso:");
      print(
        "[UI_UPDATE] 📱   Progreso: ${step.progressPercentage?.toStringAsFixed(1)}%",
      );
      print(
        "[UI_UPDATE] 📱   Distancia restante: ${step.remainingDistance?.toStringAsFixed(0)}m",
      );
      print("[UI_UPDATE] 📱   Tiempo restante: ${step.remainingTimeSeconds}s");
      print("[UI_UPDATE] 📱   Tipo de paso: ${step.type}");
      print("[UI_UPDATE] 📱   Instrucciones: ${step.instructions}");
      print(
        "[UI_UPDATE] 📱   Ubicación usuario: ${userLocation?.latitud}, ${userLocation?.longitud}",
      );

      // Actualizar AppUiState con el progreso del tracking automático
      state = state.copyWith(
        currentJourneyStep: step,
        isAutomaticNavigationEnabled: _automaticNavigationEnabled,
        currentUserLocation: userLocation,
        currentStepProgress:
            _currentJourneyStep?.progressPercentage != null
                ? RouteProgress(
                  percentageComplete: step.progressPercentage ?? 0.0,
                  remainingDistance: step.remainingDistance ?? 0.0,
                  remainingTimeSeconds: step.remainingTimeSeconds ?? 0,
                  currentOptimalRoute: step.currentRoute ?? [],
                  totalDistance: step.remainingDistance ?? 0.0,
                  completedDistance: 0.0,
                )
                : null,
      );

      // ELIMINADO: La ubicación ya se actualiza en el callback principal (línea 1259)
      // Evitar duplicación que causa spam en logs y posibles problemas de rendimiento

      print("[UI_UPDATE] ✅ UI actualizada con estado automático exitosamente");
    } else {
      print(
        "[UI_UPDATE] ⚠️ No se puede actualizar UI - condiciones no válidas",
      );
    }
  }

  void _notifyStepTransition() {
    print("[STEP_NOTIFICATION] 📢 === NOTIFICANDO TRANSICIÓN A UI ====");
    print("[STEP_NOTIFICATION] 📢 Mounted: $mounted");

    if (mounted) {
      final step = _currentJourneyStep!;
      print("[STEP_NOTIFICATION] 📢 Notificando nuevo paso:");
      print("[STEP_NOTIFICATION] 📢   Índice: ${step.stepIndex}");
      print("[STEP_NOTIFICATION] 📢   Tipo: ${step.type}");
      print("[STEP_NOTIFICATION] 📢   Instrucciones: ${step.instructions}");

      // Actualizar AppUiState para notificar el cambio de paso a la UI
      state = state.copyWith(
        currentJourneyStep: step,
        isAutomaticNavigationEnabled: _automaticNavigationEnabled,
        currentUserLocation: _locationTracker?.lastKnownLocation,
      );
      print(
        "[STEP_NOTIFICATION] ✅ Transición notificada a ActiveTripOverlay via AppUiState",
      );
    } else {
      print(
        "[STEP_NOTIFICATION] ❌ No se puede notificar - componente no montado",
      );
    }
  }

  // DIFF: Nuevo método para manejar tracking híbrido de bus
  void _handleHybridBusTracking(Coordenada userLocation) {
    if (_currentJourneyStep == null) return;

    final activeTripState = state.datosFaseViajeActivo;
    if (activeTripState == null) return;

    // SOLO actualizar bus a ubicación del usuario cuando está MONTADO en el bus
    if (_currentJourneyStep!.type == JourneyStepType.RIDING_BUS) {
      print(
        "[HYBRID_BUS] 🚌 Usuario está en bus - usando ubicación del usuario",
      );

      // Obtener el tramo actual del viaje
      if (_currentJourneyStep!.stepIndex <
          activeTripState.tramosDelViaje.length) {
        final currentTramo =
            activeTripState.tramosDelViaje[_currentJourneyStep!.stepIndex];

        // Verificar si el usuario está realmente en la ruta del bus
        if (currentTramo.geometriaPolilinea != null &&
            currentTramo.geometriaPolilinea!.isNotEmpty) {
          final isOnBusRoute = RouteDynamicCalculator.isLocationNearRoute(
            userLocation: userLocation,
            routePoints: currentTramo.geometriaPolilinea!,
            thresholdMeters: 100.0, // 100m threshold for bus detection
          );

          // Solo si el usuario está cerca de la ruta del bus
          if (isOnBusRoute) {
            print("[HYBRID_BUS] 🎯 Usuario confirmado en ruta del bus");
            // Mantener icono de usuario default; no mover icono de bus al usuario
          } else {
            print(
              "[HYBRID_BUS] ⚠️ Usuario no está en la ruta del bus esperada",
            );
          }
        }
      }
    } else {
      print(
        "[HYBRID_BUS] 📍 Usuario en paso tipo: ${_currentJourneyStep!.type} - usando tracking API",
      );
      // IMPORTANTE: NO llamar _updateBusToUserLocation aquí
      // El bus real debe seguir mostrándose desde la API cuando está esperando
    }
  }

  // DIFF: Actualizar posición del bus a ubicación del usuario
  void _updateBusToUserLocation(Coordenada userLocation) {
    print(
      "[HYBRID_BUS] 🚌 _updateBusToUserLocation called - paso actual: ${_currentJourneyStep?.type}",
    );

    // Usar el MapManager para actualizar la posición del bus
    final mapManager = _ref.read(mapManagerProvider);
    if (mapManager != null) {
      print(
        "[HYBRID_BUS] 🚌 Llamando a mapManager.busRealtime.updateBusToUserLocation",
      );
      mapManager.busRealtime.updateBusToUserLocation(userLocation);
    } else {
      print("[HYBRID_BUS] ⚠️ MapManager no disponible para actualizar bus");
    }
  }

  // DIFF: Configurar modo de tracking de bus según el tipo de paso
  Future<void> _configureBusTrackingForStep(JourneyStepType stepType) async {
    final mapManager = _ref.read(mapManagerProvider);
    if (mapManager == null) return;

    switch (stepType) {
      case JourneyStepType.WALKING_TO_STOP:
      case JourneyStepType.WALKING_TO_DESTINATION:
        print(
          "[BUS_TRACKING_CONFIG] 🚶‍♂️ Paso de caminata - manteniendo tracking API",
        );
        // Durante caminata, mantener tracking API para mostrar buses que se acercan
        mapManager.busRealtime.startApiTracking();
        break;

      case JourneyStepType.WAITING_FOR_BUS:
        print(
          "[BUS_TRACKING_CONFIG] 🚏 Esperando bus - activando tracking API intensivo",
        );
        // Al esperar bus, usar tracking API para mostrar ETA en tiempo real
        mapManager.busRealtime.startApiTracking();

        // CRITICAL FIX: Implementar fallback para paradas sin ETA
        _setupWaitingForBusFallback();
        break;

      case JourneyStepType.RIDING_BUS:
        print(
          "[BUS_TRACKING_CONFIG] 🚌 En el bus - cambiando a tracking del usuario",
        );
        // No cambiar icono del usuario a icono de bus (mantener claridad visual)
        // Limpiar cualquier rastro de modo USER_LOCATION previo para evitar capas duplicadas
        mapManager.busRealtime.stopAllTracking();

        // Limpiar elementos de buses de preview/API que no correspondan en viaje
        await mapManager.cleanup.clearPreviewBusElements();

        // CRITICAL FIX: Detener timer de seguimiento ETA cuando usuario está en el bus
        print("[BUS_TRACKING_CONFIG] 🛑 Deteniendo timer de seguimiento ETA");
        _seguimientoBusTimer?.cancel();
        _seguimientoBusTimer = null;

        // CRITICAL FIX: Detener también timer de fallback
        print("[BUS_TRACKING_CONFIG] 🛑 Deteniendo timer de fallback sin ETA");
        _waitingForBusFallbackTimer?.cancel();
        _waitingForBusFallbackTimer = null;

        print("[BUS_TRACKING_CONFIG] ✅ Timers detenidos - ahorrando recursos");
        break;

      default:
        print(
          "[BUS_TRACKING_CONFIG] ❓ Tipo de paso desconocido - deteniendo tracking",
        );
        mapManager.busRealtime.stopAllTracking();
    }
  }

  // DIFF: Método para actualizar ubicación del usuario en el mapa
  void _updateUserLocationOnMap(Coordenada userLocation) {
    try {
      final mapManager = _ref.read(mapManagerProvider);
      if (mapManager != null) {
        print(
          "[USER_LOCATION] 🗺️ Actualizando ubicación con método LIMPIO...",
        );
        mapManager.updateUserLocationClean(userLocation);
        print("[USER_LOCATION] ✅ Ubicación actualizada en el mapa");
      } else {
        print("[USER_LOCATION] ⚠️ MapManager no disponible");
      }
    } catch (e) {
      print("[USER_LOCATION] ❌ Error actualizando ubicación en mapa: $e");
    }
  }

  // NUEVO: Calcular bearing entre dos coordenadas
  double _calculateBearing(Coordenada start, Coordenada end) {
    final lat1 = start.latitud * pi / 180;
    final lat2 = end.latitud * pi / 180;
    final deltaLon = (end.longitud - start.longitud) * pi / 180;

    final x = sin(deltaLon) * cos(lat2);
    final y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon);

    var bearing = atan2(x, y);
    bearing = bearing * 180 / pi;
    bearing = (bearing + 360) % 360; // Normalizar a 0-360

    return bearing;
  }

  // CRITICAL FIX: Sistema de fallback para paradas sin ETA
  void _setupWaitingForBusFallback() {
    print("[WAITING_FALLBACK] 🚏 === CONFIGURANDO FALLBACK SIN ETA ====");

    // Cancelar timer anterior si existe
    _waitingForBusFallbackTimer?.cancel();

    // Configurar timer para monitoreo activo cada 3 segundos cuando no hay ETA
    _waitingForBusFallbackTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkBusInteractionWithoutETA(),
    );

    print("[WAITING_FALLBACK] ✅ Timer de fallback configurado (cada 3s)");
    print("[WAITING_FALLBACK] ✅ === FALLBACK CONFIGURADO ====");
  }

  void _checkBusInteractionWithoutETA() {
    print("[WAITING_FALLBACK] 🔍 === VERIFICANDO INTERACCIÓN SIN ETA ====");

    // Verificar que seguimos en WAITING_FOR_BUS
    if (_currentJourneyStep?.type != JourneyStepType.WAITING_FOR_BUS) {
      print("[WAITING_FALLBACK] ✅ Ya no esperando bus - cancelando fallback");
      _waitingForBusFallbackTimer?.cancel();
      _waitingForBusFallbackTimer = null;
      return;
    }

    final activeTripState = state.datosFaseViajeActivo;
    if (activeTripState == null) {
      print("[WAITING_FALLBACK] ⚠️ No hay viaje activo");
      return;
    }

    // Verificar si hay ETA disponible
    final hasETA =
        activeTripState.seguimientoBusRealDisponibleEnTramoActual &&
        activeTripState.minutosParaLlegadaBusReal != null &&
        activeTripState.minutosParaLlegadaBusReal! > 0;

    if (hasETA) {
      print("[WAITING_FALLBACK] ✅ ETA disponible - fallback no necesario");
      return;
    }

    print(
      "[WAITING_FALLBACK] ⚠️ NO hay ETA disponible - activando detección intensiva",
    );

    // Sin ETA: usar detección basada solo en movimiento del usuario
    final userLocation = _locationTracker?.lastKnownLocation;
    if (userLocation != null) {
      final userSpeed = _locationTracker?.currentSpeed ?? 0.0;

      print(
        "[WAITING_FALLBACK] 🏃‍♂️ Velocidad del usuario: ${userSpeed.toStringAsFixed(2)} m/s",
      );

      // Criterio más permisivo para detección sin ETA
      // Velocidad mínima reducida a 1.5 m/s (5.4 km/h)
      if (userSpeed >= 1.5) {
        print(
          "[WAITING_FALLBACK] 🚌 DETECCIÓN SIN ETA: Usuario se mueve rápido",
        );
        print(
          "[WAITING_FALLBACK] 🚌 Velocidad: ${(userSpeed * 3.6).toStringAsFixed(1)} km/h >= 5.4 km/h",
        );

        // Verificar si hay un próximo tramo de bus para validar dirección
        final currentStepIndex = _currentJourneyStep!.stepIndex;
        TramoViajeMostrable? nextBusSegment;

        for (
          int i = currentStepIndex + 1;
          i < activeTripState.tramosDelViaje.length;
          i++
        ) {
          final tramo = activeTripState.tramosDelViaje[i];
          if (tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS) {
            nextBusSegment = tramo;
            break;
          }
        }

        if (nextBusSegment?.geometriaPolilinea != null &&
            nextBusSegment!.geometriaPolilinea!.isNotEmpty) {
          // Verificar si el usuario está cerca de la ruta del bus
          final busRoutePoints = nextBusSegment.geometriaPolilinea!;
          final isNearRoute = RouteDynamicCalculator.isLocationNearRoute(
            userLocation: userLocation,
            routePoints: busRoutePoints,
            thresholdMeters: 100.0, // Más permisivo: 100m
          );

          if (isNearRoute) {
            print(
              "[WAITING_FALLBACK] ✅ Usuario cerca de ruta + velocidad alta = SUBIDA DETECTADA",
            );
            try {
              FeatureLogger().log(
                'auto_nav',
                'boarding_detected',
                data: {'near_route': true},
              );
            } catch (_) {}
            _waitingForBusFallbackTimer?.cancel();
            _waitingForBusFallbackTimer = null;
            _transitionToNextStep();
            return;
          } else {
            print(
              "[WAITING_FALLBACK] ⏳ Velocidad alta pero no cerca de ruta del bus",
            );
            try {
              FeatureLogger().log('auto_nav', 'boarding_not_near_route');
            } catch (_) {}
          }
        } else {
          print(
            "[WAITING_FALLBACK] ⚠️ No hay geometría del bus para validación",
          );
          // Si no hay geometría, usar solo velocidad como criterio
          print(
            "[WAITING_FALLBACK] ✅ FALLBACK: Solo velocidad alta = SUBIDA DETECTADA",
          );
          _waitingForBusFallbackTimer?.cancel();
          _waitingForBusFallbackTimer = null;
          _transitionToNextStep();
          return;
        }
      } else {
        print("[WAITING_FALLBACK] ⏳ Usuario se mueve lento - aún esperando...");
      }
    } else {
      print("[WAITING_FALLBACK] ⚠️ No hay ubicación del usuario disponible");
    }

    print("[WAITING_FALLBACK] ✅ === FIN VERIFICACIÓN FALLBACK ====");
  }

  void _completeJourney() {
    print("[JOURNEY_COMPLETE] 🏁 === VIAJE COMPLETADO AUTOMÁTICAMENTE ====");
    print(
      "[JOURNEY_COMPLETE] 🏁 Todos los pasos del viaje han sido completados",
    );

    // CRITICAL FIX: Actualizar estado de la UI antes de limpiar
    print("[JOURNEY_COMPLETE] 📱 Actualizando estado de la UI...");
    if (mounted) {
      state = state.copyWith(
        faseActual: FaseApp.INICIAL_SIN_BUSQUEDA, // Volver al estado inicial
        clearDatosFaseViajeActivo: true, // Limpiar datos del viaje activo
        clearCurrentJourneyStep: true, // Limpiar paso actual
        clearCurrentStepProgress: true, // Limpiar progreso
        isAutomaticNavigationEnabled:
            false, // Deshabilitar navegación automática
        mostrandoSpinnerGlobal: false, // Asegurar que no hay spinner
        clearMensajeErrorGlobal: true, // Limpiar cualquier error
      );
      print("[JOURNEY_COMPLETE] ✅ Estado de la UI actualizado");
    } else {
      print(
        "[JOURNEY_COMPLETE] ⚠️ Notifier disposed - no se puede actualizar UI",
      );
    }

    print("[JOURNEY_COMPLETE] 🏁 Deteniendo tracking automático...");
    _stopAutomaticTracking();
    print("[JOURNEY_COMPLETE] 🏁 Deteniendo seguimiento activo...");
    detenerSeguimientoActivo();

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

  void _stopAutomaticTracking() {
    print("[STOP_TRACKING] 🛑 === DETENIENDO TRACKING AUTOMÁTICO ====");
    print(
      "[STOP_TRACKING] 🛑 LocationTracker activo: ${_locationTracker != null}",
    );
    print("[STOP_TRACKING] 🛑 Paso actual: ${_currentJourneyStep?.stepIndex}");

    if (_locationTracker != null) {
      print("[STOP_TRACKING] 🛑 Disposing LocationTracker...");
      _locationTracker?.dispose();
      _locationTracker = null;
      print("[STOP_TRACKING] ✅ LocationTracker detenido");
    }

    if (_currentJourneyStep != null) {
      print("[STOP_TRACKING] 🛑 Limpiando paso actual...");
      _currentJourneyStep = null;
      print("[STOP_TRACKING] ✅ Paso actual limpiado");
    }

    _automaticNavigationEnabled = true; // Reset para próximo viaje
    print(
      "[STOP_TRACKING] 🔄 Navegación automática habilitada para próximo viaje",
    );
    print("[STOP_TRACKING] ✅ === TRACKING DETENIDO ====");
  }

  @override
  void dispose() {
    // Cancelar todos los timers primero
    _seguimientoBusTimer?.cancel();
    _seguimientoBusTimer = null;
    _origenDebounceTimer?.cancel();
    _origenDebounceTimer = null;
    _destinoDebounceTimer?.cancel();
    _destinoDebounceTimer = null;
    _waitingForBusFallbackTimer?.cancel();
    _waitingForBusFallbackTimer = null;

    // Detener tracking automático
    _stopAutomaticTracking();

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

    // DIFF: Detener tracking automático
    _stopAutomaticTracking();

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
      // NUEVO: Limpiar estado de navegación automática
      currentJourneyStep: null,
      currentStepProgress: null,
      isAutomaticNavigationEnabled: false,
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
