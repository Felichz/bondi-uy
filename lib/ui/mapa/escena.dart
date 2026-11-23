// Escena del mapa: descripción declarativa de lo que se dibuja.
//
// `construirEscena` es una función pura de (AppState, estado de UI). El
// widget del mapa solo sabe pintar escenas; así cada fase del flujo tiene un
// mapa predecible y testeable sin render.

import 'package:flutter/foundation.dart';

import '../../contract/app_state.dart';
import '../formatos.dart';
import '../textos/textos.dart';

enum EstiloTrazo {
  /// Caminata del paso actual / de la opción enfocada.
  caminar,

  /// Caminata de otro paso del viaje (contexto).
  caminarTenue,

  /// Recorrido en bus del paso actual / de la opción enfocada.
  bus,
  busTenue,

  /// Parte del recorrido en bus que ya se hizo.
  busHecho,

  /// Bus en vivo -> parada (sobre el shape GTFS).
  aproximacion,
}

@immutable
class TrazoMapa {
  final EstiloTrazo estilo;
  final List<Coordenada> puntos;
  const TrazoMapa(this.estilo, this.puntos);
}

// ---------------------------------------------------------------------------
// Globos: rótulos flotantes anclados a un punto del mapa
// ---------------------------------------------------------------------------

enum TonoGlobo {
  /// Blanco (grafito en oscuro), texto de tinta.
  normal,

  /// Relleno del color del bus: el momento de actuar ("Bajate acá").
  urgente,
}

/// Un rótulo que flota sobre un marcador, con una punta hacia él.
@immutable
class Globo {
  final String titulo;
  final String? detalle;

  /// Insignia de línea al comienzo ("D1").
  final String? linea;

  /// Detalle en color de "en vivo" con su punto que late.
  final bool enVivo;

  /// Detalle en color de "horario".
  final bool programado;
  final TonoGlobo tono;

  /// Si dos globos chocan, gana el de mayor prioridad (el otro se corre o se
  /// oculta).
  final int prioridad;

  const Globo(
    this.titulo, {
    this.detalle,
    this.linea,
    this.enVivo = false,
    this.programado = false,
    this.tono = TonoGlobo.normal,
    this.prioridad = 50,
  });
}

// ---------------------------------------------------------------------------
// Marcas
// ---------------------------------------------------------------------------

enum RolParada { subida, bajada }

/// Parada intermedia de un recorrido en bus.
enum EstadoParadaRecorrido {
  /// Ya se pasó (viajando en el bus).
  pasada,

  /// Todavía no.
  futura,

  /// La próxima por la que pasa el bus.
  proxima,
}

@immutable
sealed class MarcaMapa {
  final Coordenada coordenada;
  final Globo? globo;
  const MarcaMapa(this.coordenada, {this.globo});

  /// Por dónde se mueve un marcador móvil (la calle que se camina, el
  /// recorrido del bus): el mapa predice su avance entre lecturas por ahí.
  List<Coordenada>? get camino => null;

  /// La misma marca en otra posición (marcadores que se mueven).
  MarcaMapa movidaA(Coordenada c, {double? rumbo});
}

class MarcaUsuario extends MarcaMapa {
  /// Camina (con flecha de rumbo si se conoce) o está quieto.
  final bool caminando;
  final double? rumbo;
  @override
  final List<Coordenada>? camino;

  /// Se espera que no se mueva (esperando el bus, llegó): el mapa no
  /// predice su avance, lo lleva a cada lectura.
  final bool quieto;
  const MarcaUsuario(
    super.coordenada, {
    this.caminando = false,
    this.rumbo,
    this.camino,
    this.quieto = false,
    super.globo,
  });

  @override
  MarcaUsuario movidaA(Coordenada c, {double? rumbo}) => MarcaUsuario(
    c,
    caminando: caminando,
    rumbo: rumbo ?? this.rumbo,
    camino: camino,
    quieto: quieto,
    globo: globo,
  );
}

/// El usuario arriba del bus: un solo marcador, el bus.
class MarcaUsuarioEnBus extends MarcaMapa {
  final String linea;
  final double? rumbo;
  @override
  final List<Coordenada>? camino;
  const MarcaUsuarioEnBus(
    super.coordenada, {
    required this.linea,
    this.rumbo,
    this.camino,
    super.globo,
  });

  @override
  MarcaUsuarioEnBus movidaA(Coordenada c, {double? rumbo}) => MarcaUsuarioEnBus(
    c,
    linea: linea,
    rumbo: rumbo ?? this.rumbo,
    globo: globo,
  );
}

/// Un bus que viene (en vivo o por horario). Su globo dice cuándo llega.
class MarcaBus extends MarcaMapa {
  final String linea;
  final bool enVivo;

  /// Minutos que le faltan para llegar (para el indicador de borde).
  final int minutos;
  final double? rumbo;

  /// La parada a la que viene: la predicción de su movimiento no la pasa.
  final Coordenada? limite;
  @override
  final List<Coordenada>? camino;
  const MarcaBus(
    super.coordenada, {
    required this.linea,
    required this.enVivo,
    this.minutos = 0,
    this.rumbo,
    this.limite,
    this.camino,
    super.globo,
  });

  @override
  MarcaBus movidaA(Coordenada c, {double? rumbo}) => MarcaBus(
    c,
    linea: linea,
    enVivo: enVivo,
    minutos: minutos,
    rumbo: rumbo ?? this.rumbo,
    limite: limite,
    camino: camino,
    globo: globo,
  );
}

class MarcaParada extends MarcaMapa {
  final RolParada rol;

  /// true si es la parada del paso actual (se resalta).
  final bool activa;

  /// Relleno del color del bus: bajate en esta.
  final bool urgente;
  const MarcaParada(
    super.coordenada, {
    required this.rol,
    this.activa = false,
    this.urgente = false,
    super.globo,
  });

  @override
  MarcaParada movidaA(Coordenada c, {double? rumbo}) => this;
}

/// Parada intermedia del recorrido de un bus.
class MarcaParadaRecorrido extends MarcaMapa {
  final EstadoParadaRecorrido estado;
  const MarcaParadaRecorrido(super.coordenada, this.estado, {super.globo});

  @override
  MarcaParadaRecorrido movidaA(Coordenada c, {double? rumbo}) => this;
}

class MarcaDestino extends MarcaMapa {
  const MarcaDestino(super.coordenada, {super.globo});

  @override
  MarcaDestino movidaA(Coordenada c, {double? rumbo}) => this;
}

class MarcaOrigen extends MarcaMapa {
  const MarcaOrigen(super.coordenada, {super.globo});

  @override
  MarcaOrigen movidaA(Coordenada c, {double? rumbo}) => this;
}

/// Parada tocada en exploración.
class MarcaParadaConsultada extends MarcaMapa {
  const MarcaParadaConsultada(super.coordenada, {super.globo});

  @override
  MarcaParadaConsultada movidaA(Coordenada c, {double? rumbo}) => this;
}

/// Rótulo chico sobre un tramo de la opción ("🚶 4 min", "D1").
class MarcaTramo extends MarcaMapa {
  final bool caminar;
  final String texto;
  const MarcaTramo(
    super.coordenada, {
    required this.caminar,
    required this.texto,
  });

  @override
  MarcaTramo movidaA(Coordenada c, {double? rumbo}) => this;
}

/// Lo que el usuario busca ahora (la parada, la bajada, el destino). Si queda
/// fuera de la vista, un indicador en el borde apunta hacia él.
@immutable
class ObjetivoMapa {
  final Coordenada coordenada;
  final String texto;

  /// false: solo se señala si el usuario movió el mapa (en el bus el
  /// recorrido ya muestra hacia dónde se va).
  final bool siempre;
  const ObjetivoMapa(this.coordenada, this.texto, {this.siempre = true});
}

@immutable
class EscenaMapa {
  final List<TrazoMapa> trazos;
  final List<MarcaMapa> marcas;

  /// Red de paradas: tocables al explorar; tenues (solo contexto) en viaje.
  final List<ParadaDeRed> paradasRed;
  final bool paradasRedTenues;
  final ObjetivoMapa? objetivo;

  /// Marcas a medio aparecer o desvanecerse (por identidad; 1 si no está).
  final Map<MarcaMapa, double> opacidades;

  const EscenaMapa({
    this.trazos = const [],
    this.marcas = const [],
    this.paradasRed = const [],
    this.paradasRedTenues = false,
    this.objetivo,
    this.opacidades = const {},
  });

  double opacidad(MarcaMapa m) => opacidades[m] ?? 1;

  static const vacia = EscenaMapa();

  EscenaMapa con({
    List<MarcaMapa>? marcas,
    List<TrazoMapa>? trazos,
    Map<MarcaMapa, double>? opacidad,
  }) => EscenaMapa(
    trazos: trazos ?? this.trazos,
    marcas: marcas ?? this.marcas,
    paradasRed: paradasRed,
    paradasRedTenues: paradasRedTenues,
    objetivo: objetivo,
    opacidades: opacidad ?? opacidades,
  );

  /// Hay algo vivo que late, avanza o flota: el reloj de animación corre.
  bool get tieneLatido =>
      trazos.any((t) => t.estilo == EstiloTrazo.aproximacion) ||
      marcas.any(
        (m) =>
            m.globo != null ||
            m is MarcaUsuario ||
            m is MarcaBus ||
            m is MarcaUsuarioEnBus ||
            m is MarcaParadaConsultada ||
            (m is MarcaParada && m.activa) ||
            (m is MarcaParadaRecorrido &&
                m.estado == EstadoParadaRecorrido.proxima),
      );
}

/// Estado de UI que influye en el mapa (no viene de la lógica).
@immutable
class EstadoUiMapa {
  /// Opción enfocada en el carrusel.
  final String? opcionEnfocada;
  const EstadoUiMapa({this.opcionEnfocada});
}

// ---------------------------------------------------------------------------
// Construcción
// ---------------------------------------------------------------------------

EscenaMapa construirEscena(AppState s, EstadoUiMapa ui) {
  final usuario = s.ubicacion.coordenada;
  final nombreDestino = switch (s.busqueda.destino) {
    LugarElegido(:final lugar) => lugar.nombre,
    _ => null,
  };
  switch (s.fase) {
    case FaseExplorar():
      final consultada = s.paradaConsultada;
      return EscenaMapa(
        paradasRed: s.paradas,
        marcas: [
          if (consultada != null)
            MarcaParadaConsultada(
              consultada.parada.coordenada,
              globo: Globo(
                _corto(nombreParada(consultada.parada.nombre)),
                detalle:
                    consultada.lineas.isEmpty
                        ? null
                        : _lineasCortas(consultada.lineas),
                prioridad: 90,
              ),
            ),
          if (usuario != null) MarcaUsuario(usuario),
        ],
      );

    case final FaseOpciones f:
      final opcion = _enfocada(f, ui.opcionEnfocada);
      final marcas = <MarcaMapa>[];
      final trazos = <TrazoMapa>[];
      if (opcion != null) {
        _dibujarOpcion(
          opcion,
          trazos,
          marcas,
          pasoActual: null,
          nombreDestino: nombreDestino,
        );
        final bus = f.busesEnVivo[opcion.id];
        if (bus != null && bus.posicion != null) {
          if (bus.aproximacion != null) {
            trazos.add(TrazoMapa(EstiloTrazo.aproximacion, bus.aproximacion!));
          }
          marcas.add(
            _marcaBus(bus, parada: opcion.primerBus?.subida.coordenada),
          );
        }
      } else {
        if (f.origen != null) marcas.add(MarcaOrigen(f.origen!));
        if (f.destino != null) marcas.add(MarcaDestino(f.destino!));
      }
      if (usuario != null) marcas.add(MarcaUsuario(usuario));
      return EscenaMapa(trazos: trazos, marcas: marcas);

    case final FaseViaje f:
      final trazos = <TrazoMapa>[];
      final marcas = <MarcaMapa>[];
      final pos = f.usuario ?? usuario;
      if (f.estado == EstadoViaje.completado) {
        return EscenaMapa(
          marcas: [
            MarcaDestino(_fin(f.opcion)),
            if (pos != null) MarcaUsuario(pos, quieto: true),
          ],
        );
      }
      _dibujarOpcion(
        f.opcion,
        trazos,
        marcas,
        pasoActual: f.pasoActual,
        progreso: f.progreso,
        nombreDestino: nombreDestino,
      );
      final actual = f.tramoActual;
      final bus = f.busEsperado;
      final subiendo = _subiendo(f);
      if (bus != null &&
          bus.posicion != null &&
          actual is! TramoBus &&
          subiendo == null) {
        if (bus.aproximacion != null) {
          trazos.add(TrazoMapa(EstiloTrazo.aproximacion, bus.aproximacion!));
        }
        marcas.add(_marcaBus(bus, parada: _paradaDeEspera(f)));
      }
      if (pos != null) {
        switch (actual) {
          case TramoEsperar() when subiendo != null:
            // Ya va arriba del bus aunque la lógica todavía no lo confirmó:
            // el bus y el usuario son uno (sin esperar a los 60 m).
            marcas.add(
              MarcaUsuarioEnBus(
                pos,
                linea: subiendo.linea,
                camino: subiendo.geometria,
              ),
            );
          case TramoBus(:final linea, :final geometria):
            marcas.add(MarcaUsuarioEnBus(pos, linea: linea, camino: geometria));
          case TramoCaminar(:final geometria):
            marcas.add(MarcaUsuario(pos, caminando: true, camino: geometria));
          case TramoEsperar():
            marcas.add(MarcaUsuario(pos, quieto: true));
        }
      }
      return EscenaMapa(
        trazos: trazos,
        marcas: marcas,
        paradasRed: s.paradas,
        paradasRedTenues: true,
        objetivo: _objetivo(f, nombreDestino),
      );
  }
}

/// La parada donde se espera el bus del paso actual o del siguiente.
Coordenada? _paradaDeEspera(FaseViaje f) {
  for (final i in [f.pasoActual, f.pasoActual + 1]) {
    if (i >= f.totalPasos) break;
    final t = f.opcion.tramos[i];
    if (t is TramoEsperar) return t.parada.coordenada;
  }
  return null;
}

/// Metros que el usuario se aleja de la parada, con su bus ahí, para
/// mostrarlo ya arriba del bus.
const metrosSubiendo = 25;

/// El bus del paso siguiente si el usuario ya se está yendo en él: su bus
/// está en la parada y el usuario se alejó de ella.
TramoBus? _subiendo(FaseViaje f) {
  final t = f.tramoActual;
  if (t is! TramoEsperar || f.pasoActual + 1 >= f.totalPasos) return null;
  final bus = f.busEsperado;
  final lejos = f.progreso.metrosRestantes;
  if (bus == null || lejos == null) return null;
  final enLaParada = bus.minutos == 0 && (bus.metrosHastaParada ?? 0) <= 30;
  if (!enLaParada || lejos < metrosSubiendo) return null;
  final siguiente = f.opcion.tramos[f.pasoActual + 1];
  return siguiente is TramoBus ? siguiente : null;
}

MarcaBus _marcaBus(BusEnCamino bus, {Coordenada? parada}) => MarcaBus(
  bus.posicion!,
  linea: bus.linea,
  enVivo: bus.enVivo,
  minutos: bus.minutos,
  rumbo: bus.rumbo,
  limite: parada,
  camino: bus.camino ?? bus.aproximacion,
  globo: Globo(
    bus.minutos <= 0 ? tx.llegando : tx.llegaEn(minutos(bus.minutos)),
    linea: bus.linea,
    detalle: [
      bus.enVivo ? tx.enVivoMayus : tx.horarioMayus,
      if (bus.metrosHastaParada != null)
        tx.aDistancia(distancia(bus.metrosHastaParada!)),
    ].join(' · '),
    enVivo: bus.enVivo,
    programado: !bus.enVivo,
    prioridad: 100,
  ),
);

/// Lo que se busca en el paso actual, para señalarlo si sale de la vista.
ObjetivoMapa? _objetivo(FaseViaje f, String? nombreDestino) {
  final resto = f.progreso.metrosRestantes;
  final a = resto == null ? '' : ' · ${distancia(resto)}';
  return switch (f.tramoActual) {
    TramoCaminar(:final haciaParada, :final fin) =>
      haciaParada != null
          ? ObjetivoMapa(haciaParada.coordenada, '${tx.tuParada}$a')
          : ObjetivoMapa(fin, '${tx.tuDestino}$a'),
    TramoEsperar(:final parada) => ObjetivoMapa(parada.coordenada, tx.tuParada),
    TramoBus(:final bajada) => ObjetivoMapa(
      bajada.coordenada,
      '${tx.teBajas}$a',
      siempre: false,
    ),
  };
}

OpcionViaje? _enfocada(FaseOpciones f, String? id) {
  if (f.opciones.isEmpty) return null;
  for (final o in f.opciones) {
    if (o.id == id) return o;
  }
  return f.opciones.firstWhere(
    (o) => o.recomendada,
    orElse: () => f.opciones.first,
  );
}

/// Trazos, paradas y globos de una opción. Con [pasoActual] (en viaje) se
/// resalta ese paso, lo hecho se atenúa o desaparece y lo que sigue queda
/// como contexto.
void _dibujarOpcion(
  OpcionViaje o,
  List<TrazoMapa> trazos,
  List<MarcaMapa> marcas, {
  required int? pasoActual,
  ProgresoPaso? progreso,
  String? nombreDestino,
}) {
  final enViaje = pasoActual != null;
  final tenuesPrimero = <TrazoMapa>[];
  final activos = <TrazoMapa>[];
  for (var i = 0; i < o.tramos.length; i++) {
    final t = o.tramos[i];
    final activo = !enViaje || pasoActual == i;
    // Lo ya hecho no se dibuja: solo lo que falta.
    if (enViaje && i < pasoActual) continue;
    switch (t) {
      case TramoCaminar():
        final puntos =
            (pasoActual == i && progreso?.recorridoRestante != null)
                ? progreso!.recorridoRestante!
                : t.geometria;
        (activo ? activos : tenuesPrimero).add(
          TrazoMapa(
            activo ? EstiloTrazo.caminar : EstiloTrazo.caminarTenue,
            puntos,
          ),
        );
      case TramoBus():
        if (pasoActual == i) {
          // Arriba del bus: el recorrido entero, gris, debajo; lo que falta
          // (desde donde va el bus, lo mide la lógica) en rojo encima, que lo
          // tapa. Lo gris que se ve es lo hecho.
          tenuesPrimero.add(TrazoMapa(EstiloTrazo.busHecho, t.geometria));
          final resto = progreso?.recorridoRestante;
          if (resto != null && resto.length >= 2) {
            activos.add(TrazoMapa(EstiloTrazo.bus, resto));
          } else if (progreso?.metrosRestantes == null) {
            // Recién subió y todavía no se midió: todo por delante.
            activos.add(TrazoMapa(EstiloTrazo.bus, t.geometria));
          }
          continue;
        }
        final resaltar = activo || pasoActual == i - 1; // esperando este bus
        (resaltar ? activos : tenuesPrimero).add(
          TrazoMapa(
            resaltar ? EstiloTrazo.bus : EstiloTrazo.busTenue,
            t.geometria,
          ),
        );
      case TramoEsperar():
        break;
    }
  }
  trazos
    ..addAll(tenuesPrimero)
    ..addAll(activos);

  // Rótulos de tramo en la vista previa: cuánto se camina, qué línea.
  if (!enViaje) {
    for (final t in o.tramos) {
      switch (t) {
        case TramoCaminar(:final geometria, :final duracionSegundos):
          if (duracionSegundos < 90) continue;
          marcas.add(
            MarcaTramo(
              _medio(geometria),
              caminar: true,
              texto: '${(duracionSegundos / 60).round()} min',
            ),
          );
        case TramoBus(:final geometria, :final linea):
          marcas.add(
            MarcaTramo(_medio(geometria), caminar: false, texto: linea),
          );
        case TramoEsperar():
          break;
      }
    }
  }

  // Paradas de cada bus que todavía importa.
  var primerBus = true;
  for (var i = 0; i < o.tramos.length; i++) {
    final t = o.tramos[i];
    if (t is! TramoBus) continue;
    final esPrimero = primerBus;
    primerBus = false;
    if (enViaje && i < pasoActual) continue;
    final arriba = pasoActual == i;
    // Esperando este bus o caminando hacia su parada.
    final hacia = enViaje && (pasoActual == i - 1 || pasoActual == i - 2);
    final faltan = arriba ? progreso?.paradasRestantes : null;
    final proxima = arriba ? progreso?.proximaParada : null;
    final ultima = arriba && faltan == 0;

    // Paradas intermedias: contexto del recorrido; en el bus, las que ya
    // pasaron se apagan y la próxima se resalta.
    final idxProxima =
        proxima == null
            ? -1
            : t.paradasIntermedias.indexWhere((p) => p.id == proxima.id);
    for (var k = 0; k < t.paradasIntermedias.length; k++) {
      final p = t.paradasIntermedias[k];
      final estado =
          !arriba
              ? EstadoParadaRecorrido.futura
              : idxProxima < 0
              ? (proxima != null && proxima.id == t.bajada.id
                  ? EstadoParadaRecorrido.pasada
                  : EstadoParadaRecorrido.futura)
              : k < idxProxima
              ? EstadoParadaRecorrido.pasada
              : k == idxProxima
              ? EstadoParadaRecorrido.proxima
              : EstadoParadaRecorrido.futura;
      marcas.add(
        MarcaParadaRecorrido(
          p.coordenada,
          estado,
          globo:
              estado == EstadoParadaRecorrido.proxima
                  ? Globo(
                    _corto(nombreParada(p.nombre)),
                    detalle: tx.proximaParadaMayus,
                    prioridad: 70,
                  )
                  : null,
        ),
      );
    }

    marcas.add(
      MarcaParada(
        t.subida.coordenada,
        rol: RolParada.subida,
        activa: hacia,
        globo:
            (hacia || (!enViaje && esPrimero))
                ? Globo(
                  esPrimero ? tx.subisAl(t.linea) : tx.cambiasAl(t.linea),
                  detalle: _corto(nombreParada(t.subida.nombre)),
                  prioridad: 80,
                )
                : (!enViaje)
                ? Globo(tx.cambiasAl(t.linea), prioridad: 55)
                : null,
      ),
    );
    marcas.add(
      MarcaParada(
        t.bajada.coordenada,
        rol: RolParada.bajada,
        activa: arriba,
        urgente: ultima,
        globo:
            arriba
                ? Globo(
                  ultima ? tx.bajateEnEsta : tx.teBajasAca,
                  detalle:
                      ultima
                          ? tx.tocaElTimbreMayus
                          : faltan == null
                          ? _corto(nombreParada(t.bajada.nombre))
                          : tx.enParadas(paradas(faltan + 1)),
                  tono: ultima ? TonoGlobo.urgente : TonoGlobo.normal,
                  prioridad: 95,
                )
                : null,
      ),
    );
  }

  final ultimo = o.tramos.last;
  final llegandoAPie =
      ultimo is TramoCaminar && enViaje && pasoActual == o.tramos.length - 1;
  marcas.add(
    MarcaDestino(
      _fin(o),
      globo:
          !enViaje
              ? Globo(tx.llegas(hora(o.llegada)), prioridad: 60)
              : llegandoAPie
              ? Globo(
                nombreDestino == null ? tx.tuDestino : _corto(nombreDestino),
                detalle: tx.tuDestinoMayus,
                prioridad: 90,
              )
              : null,
    ),
  );
  if (!enViaje) {
    final primero = o.tramos.first;
    marcas.add(
      MarcaOrigen(switch (primero) {
        TramoCaminar(:final geometria) => geometria.first,
        TramoEsperar(:final parada) => parada.coordenada,
        TramoBus(:final subida) => subida.coordenada,
      }),
    );
  }
}

Coordenada _fin(OpcionViaje o) => switch (o.tramos.last) {
  TramoCaminar(:final fin) => fin,
  TramoBus(:final bajada) => bajada.coordenada,
  TramoEsperar(:final parada) => parada.coordenada,
};

/// Punto a mitad de camino de una polilínea (por cantidad de vértices,
/// suficiente para ubicar un rótulo).
Coordenada _medio(List<Coordenada> g) => g[g.length ~/ 2];

/// Los nombres de parada son largos ("Bv Gral Artigas - Lord Ponsomby"): en
/// un globo se recortan.
String _corto(String s, {int max = 24}) =>
    s.length <= max ? s : '${s.substring(0, max - 1).trimRight()}…';

String _lineasCortas(List<String> lineas) {
  const max = 5;
  final vistas = lineas.take(max).join(' · ');
  return lineas.length > max ? '$vistas +${lineas.length - max}' : vistas;
}
