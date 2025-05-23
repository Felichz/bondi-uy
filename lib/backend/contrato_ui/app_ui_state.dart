// lib/backend/contrato_ui/app_ui_state.dart

// Este archivo define el contrato de datos y estados que la capa de lógica (backend)
// proveerá a la capa de UI. La UI consumirá este estado para renderizarse.

// --- Definiciones Base (reutilizables en varios estados) ---

class Coordenada {
  final double latitud;
  final double longitud;

  Coordenada({required this.latitud, required this.longitud});

  // TODO: Considerar añadir toJson/fromJson para debugging o si la lógica los usa internamente.
  // bool operator == (Object other) => other is Coordenada && other.latitud == latitud && other.longitud == longitud;
  // int get hashCode => latitud.hashCode ^ longitud.hashCode;
}

// Nueva definición de SugerenciaLugar
class SugerenciaLugar {
  final String id;
  final String nombreCompleto;
  final String?
  nombreLugar; // Nombre principal del lugar (ej. "Estadio Centenario")
  final String?
  direccion; // Dirección o contexto (ej. "Av. Ricaldoni, Montevideo")
  final Coordenada coordenadas;

  SugerenciaLugar({
    required this.id,
    required this.nombreCompleto,
    this.nombreLugar,
    this.direccion,
    required this.coordenadas,
  });

  factory SugerenciaLugar.fromJson(Map<String, dynamic> json) {
    final properties = json['properties'];
    final context = properties?['context'];
    String? direccionExtract;
    if (context != null) {
      final relevantContext =
          (context as List)
              .where(
                (c) =>
                    c.containsKey('id') &&
                    (c['id'].startsWith('neighborhood') ||
                        c['id'].startsWith('locality') ||
                        c['id'].startsWith('place')),
              )
              .toList();
      if (relevantContext.isNotEmpty) {
        direccionExtract = relevantContext
            .map((c) => c['text'] as String?)
            .join(', ');
      }
    }
    if (json['address'] != null && json['text'] != null) {
      // Priorizar el 'address' de Mapbox si está junto con 'text' a nivel raíz,
      // ya que 'text' suele ser el nombre del POI y 'address' la calle y número.
      direccionExtract =
          "${json['address'] as String} ${json['text'] as String}, ${direccionExtract ?? ''}"
              .trim();
    } else if (json['text'] != null && properties?['address'] != null) {
      // A veces 'address' está dentro de 'properties'.
      direccionExtract =
          "${properties!['address'] as String}, ${direccionExtract ?? ''}"
              .trim();
    } else {
      // Fallback a place_name si los otros campos no son suficientes.
      // Se omite el primer componente de place_name (suele ser el nombreLugar/text)
      // para evitar redundancia si ya lo tenemos.
      direccionExtract =
          direccionExtract?.isNotEmpty == true
              ? direccionExtract
              : json['place_name']?.split(',').skip(1).join(',').trim();
    }

    // Mapbox devuelve [longitud, latitud] para las coordenadas
    final coordsList = json['geometry']?['coordinates'] as List?;
    Coordenada coordenadasLugar;
    if (coordsList != null && coordsList.length == 2) {
      coordenadasLugar = Coordenada(
        longitud: coordsList[0] as double,
        latitud: coordsList[1] as double,
      );
    } else {
      // Fallback a cero si no hay coordenadas. Considerar lanzar error o manejarlo de otra forma.
      coordenadasLugar = Coordenada(longitud: 0.0, latitud: 0.0);
    }

    return SugerenciaLugar(
      id: json['id'] ?? '',
      nombreCompleto: json['place_name'] ?? '',
      nombreLugar: json['text'] ?? '', // 'text' suele ser el nombre más conciso
      direccion: direccionExtract,
      coordenadas: coordenadasLugar,
    );
  }
}

class InfoParadaEnMapa {
  // Para dibujar en el mapa general
  final String idParada;
  final Coordenada posicion;
  final String nombre;

  InfoParadaEnMapa({
    required this.idParada,
    required this.posicion,
    required this.nombre,
  });
}

// Información para el panel de detalles de una parada específica
class EtaMostrable {
  final String linea;
  final String? destino;
  final int minutosParaLlegada; // La UI formatea esto.
  final bool esTiempoReal;
  final Coordenada? posicionBus;

  EtaMostrable({
    required this.linea,
    this.destino,
    required this.minutosParaLlegada,
    required this.esTiempoReal,
    this.posicionBus,
  });
}

class InfoDetalladaParada {
  final String idParada;
  final String nombreParada;
  final Coordenada posicion;
  final List<String> lineasQuePasan; // Lista de nombres cortos de líneas
  final List<EtaMostrable> etas;

  InfoDetalladaParada({
    required this.idParada,
    required this.nombreParada,
    required this.posicion,
    required this.lineasQuePasan,
    required this.etas,
  });
}

enum EstadoSolicitud { INICIAL, CARGANDO, EXITO, ERROR }

// --- Definiciones para Tramos de Viaje y Opciones de Ruta ---

enum TipoTramoViaje { CAMINAR, ESPERAR_BUS, VIAJE_EN_BUS }

class TramoViajeMostrable {
  final String idTramo; // Identificador único para este tramo en este viaje
  final TipoTramoViaje tipo;
  final List<Coordenada>? geometriaPolilinea; // Para CAMINAR y VIAJE_EN_BUS
  final Coordenada? posicionPunto; // Para ESPERAR_BUS (marcador en la parada)
  final String
  descripcion; // Texto descriptivo genérico provisto por la lógica si es útil (ej. nombre de calle principal, destino del bus)
  final int
  duracionEstimadaSegundos; // En segundos. La UI lo formatea (ej: "5 min", "1h 10m")
  final int
  distanciaMetros; // En metros. La UI lo formatea (ej: "500 m") o decide no mostrarlo.

  // Específico para VIAJE_EN_BUS (y quizás ESPERAR_BUS)
  final String? nombreLineaBus;
  final String?
  destinoFinalDelBus; // Destino final de la línea de ese bus en particular
  final String? idParadaOrigenTramoBus;
  final String? idParadaDestinoTramoBus;
  final Coordenada? coordenadasParadaOrigen;
  final String? nombreParadaOrigen;
  final Coordenada? coordenadasParadaDestino;
  final String? nombreParadaDestino;
  
  // Campo para acceder a la geometría completa de la línea de bus
  final String? shapeId; // Para obtener geometría completa desde shapes.geojson

  // Campos para ETA del primer bus en una opción de ruta
  final int? minutosEstimadosLlegadaBus;
  final bool? esTiempoRealBus;
  final Coordenada? posicionActualBus;

  TramoViajeMostrable({
    required this.idTramo,
    required this.tipo,
    this.geometriaPolilinea,
    this.posicionPunto,
    required this.descripcion,
    required this.duracionEstimadaSegundos,
    this.distanciaMetros = 0,
    this.nombreLineaBus,
    this.destinoFinalDelBus,
    this.idParadaOrigenTramoBus,
    this.idParadaDestinoTramoBus,
    this.coordenadasParadaOrigen,
    this.nombreParadaOrigen,
    this.coordenadasParadaDestino,
    this.nombreParadaDestino,
    // Nuevo campo para shapeId
    this.shapeId,
    // Campos para ETA
    this.minutosEstimadosLlegadaBus,
    this.esTiempoRealBus,
    this.posicionActualBus,
  }) {
    if (tipo == TipoTramoViaje.CAMINAR || tipo == TipoTramoViaje.VIAJE_EN_BUS) {
      assert(
        geometriaPolilinea != null && geometriaPolilinea!.isNotEmpty,
        "Geometría no puede estar vacía para tramos de caminar o bus.",
      );
    }
    if (tipo == TipoTramoViaje.ESPERAR_BUS) {
      assert(
        posicionPunto != null,
        "PosiciónPunto no puede ser nulo para tramos de espera.",
      );
      assert(
        distanciaMetros == 0,
        "Distancia debe ser 0 para tramos de espera.",
      );
    }
    if (tipo == TipoTramoViaje.CAMINAR) {
      assert(
        distanciaMetros > 0,
        "Distancia debe ser mayor a 0 para tramos de caminar.",
      );
    }
  }

  // Getter to consolidate coordinates for drawing on map or other uses
  List<Coordenada> get coordenadasDelTramo {
    if (tipo == TipoTramoViaje.CAMINAR || tipo == TipoTramoViaje.VIAJE_EN_BUS) {
      return geometriaPolilinea ?? [];
    }
    if (tipo == TipoTramoViaje.ESPERAR_BUS) {
      return posicionPunto != null ? [posicionPunto!] : [];
    }
    return []; // Should not happen given the types
  }
}

// Enum para tipos de advertencia, la UI mapea esto a texto/iconos
// Ejemplos, pueden expandirse mucho más.
enum TipoAdvertenciaItinerario {
  TIEMPO_CAMINATA_EXCESIVO,
  TRANSBORDO_AJUSTADO,
  RUTA_NO_ACCESIBLE_SILLA_RUEDAS, // Ejemplo
  SERVICIO_NOCTURNO_LIMITADO, // Ejemplo
  POSIBLE_DEMORA_EVENTO_ESPECIAL, // Ejemplo
  ETA_NO_DISPONIBLE_PARA_PRIMER_BUS,
  ETA_NO_ES_TIEMPO_REAL_PARA_PRIMER_BUS,
}

class OpcionDeRutaMostrable {
  final String idOpcion; // Identificador único para esta opción de ruta
  final int duracionTotalSegundos; // En segundos
  final DateTime horaLlegadaEstimada; // DateTime absoluto
  final List<TipoTramoViaje>
  secuenciaModosIconos; // Para UI ej: [WALK, BUS, WALK]
  final int distanciaTotalCaminataMetros;
  final int tiempoTotalEsperaBusSegundos;
  final double? costoEstimadoViaje;
  final TipoAdvertenciaItinerario?
  advertenciaPrincipal; // Renombrado desde tipoAdvertenciaPrincipal
  final bool esRecomendada;
  final int score; // La lógica lo calcula, la UI podría usarlo o no.
  final List<TramoViajeMostrable> tramosParaPreview;
  final EtaMostrable? etaProximoBus; // ETA para el primer bus de esta opción

  OpcionDeRutaMostrable({
    required this.idOpcion,
    required this.duracionTotalSegundos,
    required this.horaLlegadaEstimada,
    required this.secuenciaModosIconos,
    required this.distanciaTotalCaminataMetros,
    required this.tiempoTotalEsperaBusSegundos,
    this.costoEstimadoViaje,
    this.advertenciaPrincipal,
    required this.esRecomendada,
    required this.score,
    required this.tramosParaPreview,
    this.etaProximoBus,
  });

  OpcionDeRutaMostrable copyWith({
    String? idOpcion,
    int? duracionTotalSegundos,
    DateTime? horaLlegadaEstimada,
    List<TipoTramoViaje>? secuenciaModosIconos,
    int? distanciaTotalCaminataMetros,
    int? tiempoTotalEsperaBusSegundos,
    double? costoEstimadoViaje,
    bool allowNullCostoEstimadoViaje = false,
    TipoAdvertenciaItinerario? advertenciaPrincipal,
    bool allowNullAdvertenciaPrincipal = false,
    bool? esRecomendada,
    int? score,
    List<TramoViajeMostrable>? tramosParaPreview,
    EtaMostrable? etaProximoBus,
    bool? clearAdvertenciaPrincipal, // Para poder limpiar el campo opcional
    bool? clearCostoEstimadoViaje, // Para poder limpiar el campo opcional
    bool? clearEtaProximoBus,
  }) {
    return OpcionDeRutaMostrable(
      idOpcion: idOpcion ?? this.idOpcion,
      duracionTotalSegundos:
          duracionTotalSegundos ?? this.duracionTotalSegundos,
      horaLlegadaEstimada: horaLlegadaEstimada ?? this.horaLlegadaEstimada,
      secuenciaModosIconos: secuenciaModosIconos ?? this.secuenciaModosIconos,
      distanciaTotalCaminataMetros:
          distanciaTotalCaminataMetros ?? this.distanciaTotalCaminataMetros,
      tiempoTotalEsperaBusSegundos:
          tiempoTotalEsperaBusSegundos ?? this.tiempoTotalEsperaBusSegundos,
      costoEstimadoViaje:
          allowNullCostoEstimadoViaje
              ? costoEstimadoViaje
              : costoEstimadoViaje ?? this.costoEstimadoViaje,
      advertenciaPrincipal:
          allowNullAdvertenciaPrincipal
              ? advertenciaPrincipal
              : advertenciaPrincipal ?? this.advertenciaPrincipal,
      esRecomendada: esRecomendada ?? this.esRecomendada,
      score: score ?? this.score,
      tramosParaPreview: tramosParaPreview ?? this.tramosParaPreview,
      etaProximoBus:
          clearEtaProximoBus == true
              ? null
              : etaProximoBus ?? this.etaProximoBus,
    );
  }

  /* // Comentando factory problemático temporalmente
  factory OpcionDeRutaMostrable.inicial() { //TODO: Revisar si este factory es necesario o si se puede eliminar y usar valores default en constructor
    // Devuelve una instancia con valores por defecto o vacíos
    return OpcionDeRutaMostrable(
      idOpcion: 'inicial_opcion',
      duracionTotalSegundos: 0,
      horaLlegadaEstimada: DateTime.now(),
      secuenciaModosIconos: [],
      distanciaTotalCaminataMetros: 0,
      tiempoTotalEsperaBusSegundos: 0,
      // costoEstimadoViaje: null, // Ya es nullable por defecto
      // advertenciaPrincipal: null, // Ya es nullable por defecto
      esRecomendada: false,
      score: 0,
      tramosParaPreview: [],
      // etaProximoBus: null, // Ya es nullable por defecto
    );
  }
  */
}

// --- Estado Principal de la UI y sus Fases ---
enum FaseApp {
  INICIAL_SIN_BUSQUEDA,
  MOSTRANDO_OPCIONES_RUTA,
  VIAJE_ACTIVO_EN_CURSO,
}

// --- Datos específicos para cada Fase ---
class EstadoFaseInicial {
  final List<InfoParadaEnMapa> paradasVisiblesEnMapa;
  EstadoFaseInicial({required this.paradasVisiblesEnMapa});
}

class EstadoFaseOpcionesRuta {
  final List<OpcionDeRutaMostrable> opcionesDeRuta;
  // La UI maneja internamente cuál de estas opciones está "enfocada" o "previsualizada".
  // La capa de lógica ya proveyó los tramosParaPreview para cada una.
  EstadoFaseOpcionesRuta({required this.opcionesDeRuta});
}

class EstadoFaseViajeActivo {
  final String idViajeActivoConfirmado;
  final List<TramoViajeMostrable> tramosDelViaje;
  final String? idTramoBusEnSeguimiento;
  final Coordenada? posicionActualBusReal;
  final int? minutosParaLlegadaBusReal;
  final bool seguimientoBusRealDisponibleEnTramoActual;
  final OpcionDeRutaMostrable opcionDeRutaSeleccionada;
  final Coordenada? ubicacionActualUsuario; // Nueva propiedad

  EstadoFaseViajeActivo({
    required this.idViajeActivoConfirmado,
    required this.tramosDelViaje,
    required this.opcionDeRutaSeleccionada,
    this.idTramoBusEnSeguimiento,
    this.posicionActualBusReal,
    this.minutosParaLlegadaBusReal,
    this.seguimientoBusRealDisponibleEnTramoActual = false,
    this.ubicacionActualUsuario, // Nueva propiedad
  });

  EstadoFaseViajeActivo copyWith({
    String? idViajeActivoConfirmado,
    List<TramoViajeMostrable>? tramosDelViaje,
    OpcionDeRutaMostrable? opcionDeRutaSeleccionada,
    String? idTramoBusEnSeguimiento,
    bool clearIdTramoBusEnSeguimiento = false,
    Coordenada? posicionActualBusReal,
    bool clearPosicionActualBusReal = false,
    int? minutosParaLlegadaBusReal,
    bool clearMinutosParaLlegadaBusReal = false,
    bool? seguimientoBusRealDisponibleEnTramoActual,
    Coordenada? ubicacionActualUsuario, // Nueva propiedad
    bool clearUbicacionActualUsuario = false, // Nueva propiedad
  }) {
    return EstadoFaseViajeActivo(
      idViajeActivoConfirmado:
          idViajeActivoConfirmado ?? this.idViajeActivoConfirmado,
      tramosDelViaje: tramosDelViaje ?? this.tramosDelViaje,
      opcionDeRutaSeleccionada:
          opcionDeRutaSeleccionada ?? this.opcionDeRutaSeleccionada,
      idTramoBusEnSeguimiento:
          clearIdTramoBusEnSeguimiento
              ? null
              : idTramoBusEnSeguimiento ?? this.idTramoBusEnSeguimiento,
      posicionActualBusReal:
          clearPosicionActualBusReal
              ? null
              : posicionActualBusReal ?? this.posicionActualBusReal,
      minutosParaLlegadaBusReal:
          clearMinutosParaLlegadaBusReal
              ? null
              : minutosParaLlegadaBusReal ?? this.minutosParaLlegadaBusReal,
      seguimientoBusRealDisponibleEnTramoActual:
          seguimientoBusRealDisponibleEnTramoActual ??
          this.seguimientoBusRealDisponibleEnTramoActual,
      ubicacionActualUsuario:
          clearUbicacionActualUsuario
              ? null
              : ubicacionActualUsuario ?? this.ubicacionActualUsuario,
    );
  }
}

// Clase principal que agrupa todo el estado de la UI
class AppUiState {
  final FaseApp faseActual;

  // Datos específicos de cada fase (solo uno de estos será no nulo)
  final EstadoFaseInicial? datosFaseInicial;
  final EstadoFaseOpcionesRuta? datosFaseOpcionesRuta;
  final EstadoFaseViajeActivo? datosFaseViajeActivo;

  // Para mostrar info de una parada consultada (relevante en varias fases)
  final InfoDetalladaParada? infoParadaConsultada;
  final EstadoSolicitud estadoInfoParadaConsultada;

  // Campos para la búsqueda de origen y destino (relevante en FaseApp.INICIAL_SIN_BUSQUEDA)
  final String? textoInputOrigenActual;
  final List<SugerenciaLugar>? sugerenciasOrigen;
  final EstadoSolicitud estadoSugerenciasOrigen;

  final String? textoInputDestinoActual;
  final List<SugerenciaLugar>? sugerenciasDestino;
  final EstadoSolicitud estadoSugerenciasDestino;

  // Nuevos campos para almacenar el origen y destino seleccionados para la búsqueda de ruta
  final Coordenada? puntoOrigenParaBusqueda;
  final String? nombreLugarOrigenSeleccionado;
  final Coordenada? puntoDestinoParaBusqueda;
  final String? nombreLugarDestinoSeleccionado;

  // Para la previsualización de rutas en el mapa (fase MOSTRANDO_OPCIONES_RUTA)
  final String? idOpcionRutaPrevisualizada;

  // Campos generales
  final bool mostrandoSpinnerGlobal;
  final String? mensajeErrorGlobal;
  final String? mensajeInfoGlobal; // Para mensajes no críticos

  // Nuevo campo para el estado de cálculo de ruta
  final EstadoSolicitud estadoCalculoRuta;

  AppUiState({
    required this.faseActual,
    this.datosFaseInicial,
    this.datosFaseOpcionesRuta,
    this.datosFaseViajeActivo,
    this.infoParadaConsultada,
    this.estadoInfoParadaConsultada = EstadoSolicitud.INICIAL,
    this.textoInputOrigenActual,
    this.sugerenciasOrigen,
    this.estadoSugerenciasOrigen = EstadoSolicitud.INICIAL,
    this.textoInputDestinoActual,
    this.sugerenciasDestino,
    this.estadoSugerenciasDestino = EstadoSolicitud.INICIAL,
    this.puntoOrigenParaBusqueda,
    this.nombreLugarOrigenSeleccionado,
    this.puntoDestinoParaBusqueda,
    this.nombreLugarDestinoSeleccionado,
    this.idOpcionRutaPrevisualizada,
    this.mostrandoSpinnerGlobal = false,
    this.mensajeErrorGlobal,
    this.mensajeInfoGlobal,

    this.estadoCalculoRuta = EstadoSolicitud.INICIAL,
  }) {
    // Validaciones de consistencia de estado
    if (faseActual == FaseApp.INICIAL_SIN_BUSQUEDA &&
        datosFaseInicial == null) {
      // throw ArgumentError("datosFaseInicial no puede ser null en fase INICIAL_SIN_BUSQUEDA");
      // En la práctica, se inicializa con datosFaseInicial no nulo.
      // Podríamos hacer más robusta la inicialización para evitar este throw si es problemático.
    }
    if (faseActual == FaseApp.MOSTRANDO_OPCIONES_RUTA &&
        datosFaseOpcionesRuta == null) {
      // throw ArgumentError("datosFaseOpcionesRuta no puede ser null en fase MOSTRANDO_OPCIONES_RUTA");
    }
    if (faseActual == FaseApp.VIAJE_ACTIVO_EN_CURSO &&
        datosFaseViajeActivo == null) {
      // throw ArgumentError("datosFaseViajeActivo no puede ser null en fase VIAJE_ACTIVO_EN_CURSO");
    }
    // Asegurar que solo los datos de la fase actual estén presentes podría ser una opción,
    // pero para copyWith es más fácil permitir que los otros sean null y solo actualizar el relevante.
  }

  factory AppUiState.inicial() {
    return AppUiState(
      faseActual: FaseApp.INICIAL_SIN_BUSQUEDA,
      datosFaseInicial: EstadoFaseInicial(paradasVisiblesEnMapa: []),
      infoParadaConsultada: null,
      estadoInfoParadaConsultada: EstadoSolicitud.INICIAL,
      textoInputOrigenActual: "", // Iniciar vacío en lugar de null
      sugerenciasOrigen: [], // Iniciar vacío
      estadoSugerenciasOrigen: EstadoSolicitud.INICIAL,
      textoInputDestinoActual: "", // Iniciar vacío
      sugerenciasDestino: [], // Iniciar vacío
      estadoSugerenciasDestino: EstadoSolicitud.INICIAL,
      puntoOrigenParaBusqueda: null, // Nuevo
      nombreLugarOrigenSeleccionado: null, // Nuevo
      puntoDestinoParaBusqueda: null, // Nuevo
      nombreLugarDestinoSeleccionado: null, // Nuevo
      idOpcionRutaPrevisualizada: null,
      mostrandoSpinnerGlobal: false,
      mensajeErrorGlobal: null,
      mensajeInfoGlobal: null,

      estadoCalculoRuta: EstadoSolicitud.INICIAL,
    );
  }

  AppUiState copyWith({
    FaseApp? faseActual,
    EstadoFaseInicial? datosFaseInicial,
    bool clearDatosFaseInicial = false,
    EstadoFaseOpcionesRuta? datosFaseOpcionesRuta,
    bool clearDatosFaseOpcionesRuta = false,
    EstadoFaseViajeActivo? datosFaseViajeActivo,
    bool clearDatosFaseViajeActivo = false,
    InfoDetalladaParada? infoParadaConsultada,
    bool clearInfoParadaConsultada = false,
    EstadoSolicitud? estadoInfoParadaConsultada,
    String? textoInputOrigenActual,
    List<SugerenciaLugar>? sugerenciasOrigen,
    bool clearSugerenciasOrigen = false,
    EstadoSolicitud? estadoSugerenciasOrigen,
    String? textoInputDestinoActual,
    List<SugerenciaLugar>? sugerenciasDestino,
    bool clearSugerenciasDestino = false,
    EstadoSolicitud? estadoSugerenciasDestino,
    Coordenada? puntoOrigenParaBusqueda,
    bool clearPuntoOrigenParaBusqueda = false,
    String? nombreLugarOrigenSeleccionado,
    bool clearNombreLugarOrigenSeleccionado = false,
    Coordenada? puntoDestinoParaBusqueda,
    bool clearPuntoDestinoParaBusqueda = false,
    String? nombreLugarDestinoSeleccionado,
    bool clearNombreLugarDestinoSeleccionado = false,
    String? idOpcionRutaPrevisualizada,
    bool clearIdOpcionRutaPrevisualizada = false,
    bool? mostrandoSpinnerGlobal,
    String? mensajeErrorGlobal,
    bool clearMensajeErrorGlobal = false,
    String? mensajeInfoGlobal,
    bool clearMensajeInfoGlobal = false,
    EstadoSolicitud? estadoCalculoRuta,
  }) {
    return AppUiState(
      faseActual: faseActual ?? this.faseActual,
      datosFaseInicial:
          clearDatosFaseInicial
              ? null
              : datosFaseInicial ?? this.datosFaseInicial,
      datosFaseOpcionesRuta:
          clearDatosFaseOpcionesRuta
              ? null
              : datosFaseOpcionesRuta ?? this.datosFaseOpcionesRuta,
      datosFaseViajeActivo:
          clearDatosFaseViajeActivo
              ? null
              : datosFaseViajeActivo ?? this.datosFaseViajeActivo,
      infoParadaConsultada:
          clearInfoParadaConsultada
              ? null
              : infoParadaConsultada ?? this.infoParadaConsultada,
      estadoInfoParadaConsultada:
          estadoInfoParadaConsultada ?? this.estadoInfoParadaConsultada,
      textoInputOrigenActual:
          textoInputOrigenActual ?? this.textoInputOrigenActual,
      sugerenciasOrigen:
          clearSugerenciasOrigen
              ? [] // Cambiado de null a [] para consistencia con inicial()
              : sugerenciasOrigen ?? this.sugerenciasOrigen,
      estadoSugerenciasOrigen:
          estadoSugerenciasOrigen ?? this.estadoSugerenciasOrigen,
      textoInputDestinoActual:
          textoInputDestinoActual ?? this.textoInputDestinoActual,
      sugerenciasDestino:
          clearSugerenciasDestino
              ? [] // Cambiado de null a []
              : sugerenciasDestino ?? this.sugerenciasDestino,
      estadoSugerenciasDestino:
          estadoSugerenciasDestino ?? this.estadoSugerenciasDestino,
      puntoOrigenParaBusqueda:
          clearPuntoOrigenParaBusqueda
              ? null
              : puntoOrigenParaBusqueda ?? this.puntoOrigenParaBusqueda,
      nombreLugarOrigenSeleccionado:
          clearNombreLugarOrigenSeleccionado
              ? null
              : nombreLugarOrigenSeleccionado ??
                  this.nombreLugarOrigenSeleccionado,
      puntoDestinoParaBusqueda:
          clearPuntoDestinoParaBusqueda
              ? null
              : puntoDestinoParaBusqueda ?? this.puntoDestinoParaBusqueda,
      nombreLugarDestinoSeleccionado:
          clearNombreLugarDestinoSeleccionado
              ? null
              : nombreLugarDestinoSeleccionado ??
                  this.nombreLugarDestinoSeleccionado,
      idOpcionRutaPrevisualizada:
          clearIdOpcionRutaPrevisualizada
              ? null
              : idOpcionRutaPrevisualizada ?? this.idOpcionRutaPrevisualizada,
      mostrandoSpinnerGlobal:
          mostrandoSpinnerGlobal ?? this.mostrandoSpinnerGlobal,
      mensajeErrorGlobal:
          clearMensajeErrorGlobal
              ? null
              : mensajeErrorGlobal ?? this.mensajeErrorGlobal,
      mensajeInfoGlobal:
          clearMensajeInfoGlobal
              ? null
              : mensajeInfoGlobal ?? this.mensajeInfoGlobal,
      estadoCalculoRuta: estadoCalculoRuta ?? this.estadoCalculoRuta,
    );
  }

  @override
  String toString() {
    return '''AppUiState(
      faseActual: $faseActual,
      mostrandoSpinnerGlobal: $mostrandoSpinnerGlobal,
      datosFaseOpcionesRuta: ${datosFaseOpcionesRuta != null ? 'Presente (${datosFaseOpcionesRuta!.opcionesDeRuta.length} opciones)' : 'null'},
      textoInputOrigen: "$textoInputOrigenActual", Sugerencias Origen: ${sugerenciasOrigen?.length ?? 0},
      textoInputDestino: "$textoInputDestinoActual", Sugerencias Destino: ${sugerenciasDestino?.length ?? 0},
      origenParaBusqueda: ${puntoOrigenParaBusqueda != null ? nombreLugarOrigenSeleccionado ?? 'Coordenada' : 'null'},
      destinoParaBusqueda: ${puntoDestinoParaBusqueda != null ? nombreLugarDestinoSeleccionado ?? 'Coordenada' : 'null'},
      idOpcionRutaPrevisualizada: $idOpcionRutaPrevisualizada,
      infoParadaConsultada: ${infoParadaConsultada != null ? 'Parada ID: ${infoParadaConsultada!.idParada}' : 'null'},
      mensajeErrorGlobal: $mensajeErrorGlobal
    )''';
  }
}

// --- Acciones/Interfaz que la Capa de Lógica (Backend) expondrá ---
// Esto es conceptual. En Riverpod, esto se traduciría a los métodos públicos
// de un StateNotifier o las funciones de un Provider.
abstract class IAppLogic {
  // -- Para FaseApp.INICIAL_SIN_BUSQUEDA y manejo de paradas --
  Future<void> cargarParadasInicialesDelViewport(
    Coordenada centroActual,
    double zoomActual,
  );
  Future<void> viewportDelMapaCambio(
    Coordenada nuevoCentro,
    double nuevoZoom,
    Coordenada esquinaSupIzq,
    Coordenada esquinaInfDer,
  );
  Future<void> solicitarInformacionDetalladaParada(String idParada);
  Future<void> usuarioDeseleccionoInformacionDeParada();

  // -- Para la búsqueda y sugerencias de origen/destino --
  Future<void> usuarioEscribioEnCampoOrigen(String textoQuery);
  Future<void> usuarioEscribioEnCampoDestino(String textoQuery);
  void seleccionarSugerenciaOrigen(SugerenciaLugar sugerencia);
  void seleccionarSugerenciaDestino(SugerenciaLugar sugerencia);
  void limpiarSugerenciasOrigen();
  void limpiarSugerenciasDestino();
  void limpiarOrigenSeleccionado();
  void limpiarDestinoSeleccionado();
  void intercambiarOrigenYDestino();

  Future<void> iniciarBusquedaDeRutas();
  Future<void> usuarioCanceloBusquedaOSeleccionRuta();

  // -- Para FaseApp.MOSTRANDO_OPCIONES_RUTA --
  void seleccionarOpcionDeRutaParaPrevisualizar(String idOpcionRuta);
  void limpiarSeleccionDeRutaPrevisualizada();
  void confirmarOpcionDeRutaEIniciarViaje(String idOpcionRuta);

  // -- Para FaseApp.VIAJE_ACTIVO_EN_CURSO --
  Future<void> iniciarSeguimientoBusTiempoReal({
    required String idViajeActivo,
    required String idTramoBus,
  });
  Future<void> detenerSeguimientoBusTiempoReal();
  Future<void> usuarioSeleccionoTramoDelViaje(
    String idViajeActivo,
    String idTramoSeleccionado,
  );

  // --- Acciones Generales ---
  Future<void> limpiarMensajeDeErrorGlobal();
  void setErrorGlobal(String? mensaje);

  // --- Acciones Adicionales (Asegurar que estén) ---
  void pantallaDeInicioCargada();
  void usuarioMovioMapaManualente(Coordenada nuevoCentro, double nuevoZoom);
  void usuarioHizoTapEnMapa(Coordenada tocada);
  void usuarioHizoTapEnParadaDelMapa(String idParada);
  void cerrarDetallesDeParada();
  void navegarAAnteriorPasoInstrucciones();
  void navegarASiguientePasoInstrucciones();
  void usuarioSeleccionoPasoInstrucciones(int indicePaso);
  void usuarioPresionoSeguirEsteViaje();
  void detenerSeguimientoActivo();
}
