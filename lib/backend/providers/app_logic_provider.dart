import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../contrato_ui/app_ui_state.dart';
import '../services/montevideo_api_service_adapter.dart';
import '../services/itinerary_planning_service_adapter.dart';
import '../services/geocoding_service_adapter.dart';
import 'package:collection/collection.dart';

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
  Timer? _seguimientoBusTimer;
  Timer? _origenDebounceTimer;
  Timer? _destinoDebounceTimer;

  AppLogicNotifier(
    this._ref,
    this._montevideoApiService,
    this._itineraryPlanningService,
    this._geocodingService,
  ) : super(AppUiState.inicial()) {
    // Imprimir estado inicial
    print("[AppUiState Initial]: ${state.toString()}");
  }

  // Sobrescribir el setter de 'state' para imprimir cada cambio.
  // Esto es más centralizado que añadir prints en cada método.
  @override
  set state(AppUiState newState) {
    final oldState = state;
    super.state = newState;
    print("[AppUiState Update]: ${newState.toString()}");

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
    // Leer origen y destino desde el estado
    if (state.puntoOrigenParaBusqueda == null ||
        state.puntoDestinoParaBusqueda == null) {
      print(
        "[AppLogicNotifier_ERROR] Origen o destino no seleccionados para la búsqueda.",
      );
      if (mounted) {
        state = state.copyWith(
          mensajeErrorGlobal:
              "Por favor, selecciona un origen y destino válidos.",
        );
      }
      return;
    }

    final Coordenada origenCoords = state.puntoOrigenParaBusqueda!;
    final String origenNombreFinal =
        state.nombreLugarOrigenSeleccionado ?? "Origen";
    final Coordenada destinoCoords = state.puntoDestinoParaBusqueda!;
    final String destinoNombreFinal =
        state.nombreLugarDestinoSeleccionado ?? "Destino";

    print(
      "[AppLogicNotifier] Iniciando búsqueda de rutas: ${origenNombreFinal} (${origenCoords.latitud},${origenCoords.longitud}) -> ${destinoNombreFinal} (${destinoCoords.latitud},${destinoCoords.longitud})",
    );
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
      final List<OpcionDeRutaMostrable> opciones =
          await _itineraryPlanningService.planRoute(
            origenCoords: origenCoords, // Usar parámetro
            origenNombre: origenNombreFinal, // Usar parámetro procesado
            destinoCoords: destinoCoords, // Usar parámetro
            destinoNombre: destinoNombreFinal, // Usar parámetro procesado
          );
      print(
        "[AppLogicNotifier] Opciones de ruta obtenidas del servicio: ${opciones.length}",
      );

      if (mounted) {
        OpcionDeRutaMostrable? primeraOpcion;
        if (opciones.isNotEmpty) {
          primeraOpcion = opciones.firstWhere(
            (opt) => opt.esRecomendada,
            orElse: () => opciones.first,
          );
        }

        state = state.copyWith(
          datosFaseOpcionesRuta: EstadoFaseOpcionesRuta(
            opcionesDeRuta: opciones,
          ),
          idOpcionRutaPrevisualizada: primeraOpcion?.idOpcion,
          mostrandoSpinnerGlobal: false,
        );
        print(
          "[AppLogicNotifier] Opciones de ruta cargadas en el estado. Previsualizando: ${primeraOpcion?.idOpcion}",
        );
      }
    } catch (e, s) {
      print("[AppLogicNotifier] Error buscando rutas: $e\n$s");
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
      }
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
  void seleccionarOpcionDeRutaParaPrevisualizar(String idOpcionRuta) {
    if (mounted) {
      final opciones = state.datosFaseOpcionesRuta?.opcionesDeRuta ?? [];
      final opcionSeleccionada = opciones.firstWhereOrNull(
        (opt) => opt.idOpcion == idOpcionRuta,
      );

      if (opcionSeleccionada != null) {
        final List<Coordenada> todosLosPuntosDeLaRuta = [];
        for (var tramo in opcionSeleccionada.tramosParaPreview) {
          if (tramo.geometriaPolilinea != null) {
            todosLosPuntosDeLaRuta.addAll(tramo.geometriaPolilinea!);
          }
          if (tramo.posicionPunto != null) {
            todosLosPuntosDeLaRuta.add(tramo.posicionPunto!);
          }
        }

        if (todosLosPuntosDeLaRuta.isNotEmpty) {
          state = state.copyWith(idOpcionRutaPrevisualizada: idOpcionRuta);
        } else {
          // Si la ruta no tiene puntos, no cambiamos el zoom target
          state = state.copyWith(idOpcionRutaPrevisualizada: idOpcionRuta);
        }
      } else {
        // Opción no encontrada, solo actualizar el ID (o limpiarlo si se prefiere)
        state = state.copyWith(idOpcionRutaPrevisualizada: idOpcionRuta);
      }
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
  void confirmarOpcionDeRutaEIniciarViaje(String idOpcionSeleccionada) {
    print(
      "[AppLogicNotifier] Confirmando opción para iniciar viaje: $idOpcionSeleccionada",
    );
    if (state.faseActual == FaseApp.MOSTRANDO_OPCIONES_RUTA &&
        state.datosFaseOpcionesRuta != null &&
        state.idOpcionRutaPrevisualizada == idOpcionSeleccionada) {
      OpcionDeRutaMostrable? opcionConfirmada;
      try {
        opcionConfirmada = state.datosFaseOpcionesRuta!.opcionesDeRuta
            .firstWhere((opt) => opt.idOpcion == idOpcionSeleccionada);
      } catch (e) {
        /* ya se maneja abajo si es null */
      }

      if (opcionConfirmada == null) {
        print(
          "[AppLogicNotifier_ERROR] Opción confirmada no encontrada: $idOpcionSeleccionada",
        );
        state = state.copyWith(
          mensajeErrorGlobal: "Error al iniciar el viaje. Opción no válida.",
        );
        return;
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
      print("[AppLogicNotifier] Fase cambiada a VIAJE_ACTIVO_EN_CURSO.");

      // Iniciar seguimiento del primer tramo de bus automáticamente si existe
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
        iniciarSeguimientoBusTiempoReal(
          idViajeActivo: opcionConfirmada.idOpcion,
          idTramoBus: primerTramoBus.idTramo,
        );
      }
    } else {
      print(
        "[AppLogicNotifier_ERROR] No se puede confirmar la ruta. Estado incorrecto o previsualización no coincide.",
      );
      state = state.copyWith(
        mensajeErrorGlobal: "No se pudo iniciar el viaje. Intenta de nuevo.",
      );
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
          EtaMostrable? etaRelevante;
          try {
            etaRelevante = detallesParada.etas.firstWhere(
              (eta) => eta.linea == lineaBus && eta.esTiempoReal,
            );
          } catch (e) {
            /* No encontrado o no es tiempo real */
          }

          if (etaRelevante != null && etaRelevante.minutosParaLlegada > 0) {
            state = state.copyWith(
              datosFaseViajeActivo: state.datosFaseViajeActivo!.copyWith(
                posicionActualBusReal: etaRelevante.posicionBus,
                minutosParaLlegadaBusReal: etaRelevante.minutosParaLlegada,
                seguimientoBusRealDisponibleEnTramoActual: true,
              ),
            );
            print(
              "[AppLogicNotifier_Timer] ETA real para $lineaBus: ${etaRelevante.minutosParaLlegada} min, Pos: ${etaRelevante.posicionBus}",
            );
          } else {
            state = state.copyWith(
              datosFaseViajeActivo: state.datosFaseViajeActivo!.copyWith(
                seguimientoBusRealDisponibleEnTramoActual: false,
                clearPosicionActualBusReal: true,
                clearMinutosParaLlegadaBusReal: true,
              ),
            );
            print(
              "[AppLogicNotifier_Timer] No ETA real (o ya pasó) para $lineaBus en $idParadaOrigen.",
            );
            if (etaRelevante != null && etaRelevante.minutosParaLlegada <= 0) {
              _seguimientoBusTimer?.cancel();
              print(
                "[AppLogicNotifier_Timer] Bus parece haber llegado/pasado. Deteniendo timer para $lineaBus.",
              );
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

  @override
  void dispose() {
    _seguimientoBusTimer?.cancel();
    _origenDebounceTimer?.cancel();
    _destinoDebounceTimer?.cancel();
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
    // Detener el timer de seguimiento de bus si está activo
    _seguimientoBusTimer?.cancel();
    _seguimientoBusTimer = null;

    if (mounted) {
      state = state.copyWith(
        faseActual: FaseApp.INICIAL_SIN_BUSQUEDA, // Volver al estado inicial
        clearDatosFaseViajeActivo: true,
        clearDatosFaseOpcionesRuta: true, // También limpiar opciones de ruta
        clearIdOpcionRutaPrevisualizada: true,
        clearMensajeErrorGlobal: true,
        clearMensajeInfoGlobal: true,
      );
      print(
        "[AppLogicNotifier] Seguimiento activo detenido y estado limpiado.",
      );
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
