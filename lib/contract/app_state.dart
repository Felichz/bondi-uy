// Estado que la capa de lógica entrega a la UI. Es la ÚNICA entrada de la UI.
//
// La app vive en una de tres fases (explorar, opciones, viaje). Cada fase
// trae solo lo que la UI necesita para dibujarla; lo que es puramente
// presentacional (qué tarjeta del carrusel está enfocada, si el buscador está
// abierto, a qué encuadra la cámara) NO está acá: es estado de la UI.

import 'package:flutter/foundation.dart' show immutable;

import 'modelo.dart';

export 'modelo.dart';

@immutable
class AppState {
  final UbicacionUsuario ubicacion;
  final Busqueda busqueda;
  final Fase fase;

  /// Red de paradas para el mapa de exploración (se carga una vez).
  final List<ParadaDeRed> paradas;

  /// Parada que el usuario tocó en el mapa (solo en fase explorar).
  final ConsultaParada? paradaConsultada;

  /// Aviso transitorio. [Aviso.id] cambia en cada aviso nuevo.
  final Aviso? aviso;

  /// Solo en modo demo (viajes grabados y mundo simulado); null en uso real.
  final Demo? demo;

  const AppState({
    required this.ubicacion,
    required this.busqueda,
    required this.fase,
    this.paradas = const [],
    this.paradaConsultada,
    this.aviso,
    this.demo,
  });

  factory AppState.inicial() => const AppState(
    ubicacion: UbicacionUsuario(estado: EstadoUbicacion.buscando),
    busqueda: Busqueda(),
    fase: FaseExplorar(),
  );

  AppState copyWith({
    UbicacionUsuario? ubicacion,
    Busqueda? busqueda,
    Fase? fase,
    List<ParadaDeRed>? paradas,
    ConsultaParada? paradaConsultada,
    bool limpiarParadaConsultada = false,
    Aviso? aviso,
    bool limpiarAviso = false,
    Demo? demo,
  }) {
    return AppState(
      ubicacion: ubicacion ?? this.ubicacion,
      busqueda: busqueda ?? this.busqueda,
      fase: fase ?? this.fase,
      paradas: paradas ?? this.paradas,
      paradaConsultada:
          limpiarParadaConsultada
              ? null
              : (paradaConsultada ?? this.paradaConsultada),
      aviso: limpiarAviso ? null : (aviso ?? this.aviso),
      demo: demo ?? this.demo,
    );
  }
}

// ---------------------------------------------------------------------------
// Demo
// ---------------------------------------------------------------------------

/// Modo demo: el usuario y los buses se mueven solos por Montevideo, sobre
/// viajes reales grabados, a una velocidad que se puede cambiar.
@immutable
class Demo {
  /// Destinos con viaje grabado: los que se pueden probar.
  final List<Lugar> destinos;

  const Demo({required this.destinos});
}

// ---------------------------------------------------------------------------
// Ubicación
// ---------------------------------------------------------------------------

enum EstadoUbicacion { buscando, disponible, sinPermiso, desactivada, error }

@immutable
class UbicacionUsuario {
  final EstadoUbicacion estado;
  final Coordenada? coordenada;

  const UbicacionUsuario({required this.estado, this.coordenada});

  bool get disponible => coordenada != null;
}

// ---------------------------------------------------------------------------
// Búsqueda (origen / destino)
// ---------------------------------------------------------------------------

enum CampoBusqueda { origen, destino }

enum EstadoSugerencias { inactivo, cargando, listo, error }

/// Un extremo del viaje: la ubicación del usuario o un lugar elegido.
@immutable
sealed class PuntoBusqueda {
  const PuntoBusqueda();
}

class MiUbicacion extends PuntoBusqueda {
  const MiUbicacion();

  @override
  bool operator ==(Object other) => other is MiUbicacion;

  @override
  int get hashCode => 1;
}

class LugarElegido extends PuntoBusqueda {
  final Lugar lugar;
  const LugarElegido(this.lugar);

  @override
  bool operator ==(Object other) =>
      other is LugarElegido && other.lugar == lugar;

  @override
  int get hashCode => lugar.hashCode;
}

@immutable
class Busqueda {
  /// Por defecto "Mi ubicación".
  final PuntoBusqueda origen;

  /// null = todavía no elegido.
  final PuntoBusqueda? destino;

  /// Campo cuyo texto está siendo consultado ahora mismo.
  final CampoBusqueda? campoConsultado;
  final String consulta;
  final List<Lugar> sugerencias;
  final EstadoSugerencias estadoSugerencias;

  const Busqueda({
    this.origen = const MiUbicacion(),
    this.destino,
    this.campoConsultado,
    this.consulta = '',
    this.sugerencias = const [],
    this.estadoSugerencias = EstadoSugerencias.inactivo,
  });

  bool get completa => destino != null && origen != destino;

  PuntoBusqueda? punto(CampoBusqueda campo) =>
      campo == CampoBusqueda.origen ? origen : destino;

  Busqueda conPunto(CampoBusqueda campo, PuntoBusqueda? punto) => Busqueda(
    origen:
        campo == CampoBusqueda.origen ? (punto ?? const MiUbicacion()) : origen,
    destino: campo == CampoBusqueda.destino ? punto : destino,
  );

  Busqueda conConsulta({
    required CampoBusqueda campo,
    required String texto,
    List<Lugar>? sugerencias,
    required EstadoSugerencias estado,
  }) => Busqueda(
    origen: origen,
    destino: destino,
    campoConsultado: campo,
    consulta: texto,
    sugerencias: sugerencias ?? this.sugerencias,
    estadoSugerencias: estado,
  );

  Busqueda sinConsulta() => Busqueda(origen: origen, destino: destino);
}

// ---------------------------------------------------------------------------
// Fases
// ---------------------------------------------------------------------------

@immutable
sealed class Fase {
  const Fase();
}

/// Sin viaje: el usuario mira el mapa, las paradas y puede buscar.
class FaseExplorar extends Fase {
  const FaseExplorar();
}

enum EstadoOpciones { cargando, listo, sinResultados, error }

/// Opciones de viaje calculadas para origen -> destino.
class FaseOpciones extends Fase {
  final EstadoOpciones estado;

  /// Punto de partida efectivamente usado para planificar.
  final Coordenada? origen;
  final Coordenada? destino;

  /// Ordenadas por la lógica; exactamente una es `recomendada` cuando hay.
  final List<OpcionViaje> opciones;

  /// Bus en vivo del primer tramo de bus de cada opción que la UI pidió
  /// seguir (ver `AppActions.enfocarOpcion`). Clave: id de la opción.
  final Map<String, BusEnCamino> busesEnVivo;

  const FaseOpciones({
    required this.estado,
    this.origen,
    this.destino,
    this.opciones = const [],
    this.busesEnVivo = const {},
  });

  FaseOpciones copyWith({
    EstadoOpciones? estado,
    List<OpcionViaje>? opciones,
    Map<String, BusEnCamino>? busesEnVivo,
  }) {
    return FaseOpciones(
      estado: estado ?? this.estado,
      origen: origen,
      destino: destino,
      opciones: opciones ?? this.opciones,
      busesEnVivo: busesEnVivo ?? this.busesEnVivo,
    );
  }
}

enum EstadoViaje { enCurso, completado }

/// Cómo se detectó el avance al paso actual.
enum OrigenAvance { inicio, automatico, manual }

/// Viaje activo, guiado paso a paso.
class FaseViaje extends Fase {
  final OpcionViaje opcion;

  /// Índice en `opcion.tramos` del paso en curso (lo detecta la lógica por GPS
  /// o por confirmación manual).
  final int pasoActual;
  final OrigenAvance origenAvance;
  final ProgresoPaso progreso;
  final EstadoViaje estado;

  /// Última ubicación conocida del usuario.
  final Coordenada? usuario;

  /// Bus en vivo que viene a la parada del paso de espera actual o del
  /// próximo. Siempre null mientras se viaja arriba del bus: ahí el bus ES
  /// el usuario.
  final BusEnCamino? busEsperado;

  /// true si la fuente en vivo respondió sin un bus utilizable para la línea.
  final bool sinDatosEnVivo;

  final DateTime inicio;
  final DateTime? fin;

  const FaseViaje({
    required this.opcion,
    required this.pasoActual,
    required this.origenAvance,
    required this.progreso,
    required this.estado,
    required this.inicio,
    this.usuario,
    this.busEsperado,
    this.sinDatosEnVivo = false,
    this.fin,
  });

  Tramo get tramoActual => opcion.tramos[pasoActual];
  int get totalPasos => opcion.tramos.length;

  FaseViaje copyWith({
    int? pasoActual,
    OrigenAvance? origenAvance,
    ProgresoPaso? progreso,
    EstadoViaje? estado,
    Coordenada? usuario,
    BusEnCamino? busEsperado,
    bool limpiarBusEsperado = false,
    bool? sinDatosEnVivo,
    DateTime? fin,
  }) {
    return FaseViaje(
      opcion: opcion,
      pasoActual: pasoActual ?? this.pasoActual,
      origenAvance: origenAvance ?? this.origenAvance,
      progreso: progreso ?? this.progreso,
      estado: estado ?? this.estado,
      inicio: inicio,
      usuario: usuario ?? this.usuario,
      busEsperado:
          limpiarBusEsperado ? null : (busEsperado ?? this.busEsperado),
      sinDatosEnVivo: sinDatosEnVivo ?? this.sinDatosEnVivo,
      fin: fin ?? this.fin,
    );
  }
}

/// Progreso numérico del paso en curso. Todos los campos son opcionales
/// porque dependen de tener ubicación.
@immutable
class ProgresoPaso {
  /// Caminar / bus: metros que faltan por la geometría.
  final int? metrosRestantes;

  /// Metros del paso al comenzarlo (para calcular el avance).
  final int? metrosTotales;

  /// Caminar: recorrido restante por la calle, desde el usuario.
  final List<Coordenada>? recorridoRestante;

  /// Bus: paradas que faltan antes de la de bajada (0 = bajate en la próxima).
  final int? paradasRestantes;

  /// Bus: próxima parada por la que pasa el bus.
  final Parada? proximaParada;

  const ProgresoPaso({
    this.metrosRestantes,
    this.metrosTotales,
    this.recorridoRestante,
    this.paradasRestantes,
    this.proximaParada,
  });

  static const vacio = ProgresoPaso();

  /// 0..1, o null si no se puede calcular.
  double? get fraccion {
    final total = metrosTotales, resto = metrosRestantes;
    if (total == null || resto == null || total <= 0) return null;
    return (1 - resto / total).clamp(0.0, 1.0);
  }
}

// ---------------------------------------------------------------------------
// Parada consultada
// ---------------------------------------------------------------------------

enum EstadoConsulta { cargando, listo, error }

@immutable
class ConsultaParada {
  final Parada parada;
  final List<String> lineas;
  final EstadoConsulta estado;
  final List<LlegadaBus> llegadas;

  const ConsultaParada({
    required this.parada,
    required this.lineas,
    required this.estado,
    this.llegadas = const [],
  });
}

// ---------------------------------------------------------------------------
// Avisos
// ---------------------------------------------------------------------------

/// Tipos de aviso. La UI decide texto e ícono.
enum TipoAviso {
  sinUbicacion,
  sinConexion,
  errorPlanificacion,
  errorSugerencias,
  errorParada,
  faltaDestino,
  bajateEnLaProxima,
  busLlegando,
}

@immutable
class Aviso {
  final int id;
  final TipoAviso tipo;
  const Aviso(this.id, this.tipo);
}
