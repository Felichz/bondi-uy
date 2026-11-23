// Modo demo: viajes reales planificados por OTP y grabados, desde una casa
// en Malvín a cinco destinos de Montevideo. Funciona sin ningún servidor
// propio (solo las teselas del mapa vienen de internet), así que sirve para
// que cualquiera pruebe la app en la web o en el teléfono.
//
// Los planes se grabaron con `tool/capture_trip.dart` contra el OTP local
// (GTFS de la Intendencia + OSM de Uruguay) y se guardan reducidos al plan
// crudo en `assets/demo/<id>.json`. Los horarios se corren al momento en
// que se pide el viaje.

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../contract/app_state.dart';
import '../app_controller.dart';
import '../geo/geo.dart';
import '../puertos.dart';
import 'grabado.dart';
import 'mundo_simulado.dart';

/// Donde vive el usuario de la demo (todos los viajes salen de acá).
const casaDemo = Coordenada(-34.902448, -56.12828);

/// Cuántas veces más rápido que el real corre el mundo de la demo en cada
/// parte del viaje. Mirando las opciones, al llegar y explorando corre a
/// tiempo real: el bus de la vista previa es el que se alcanza al empezar (a
/// 15x, unos segundos leyendo serían minutos y ese bus ya habría pasado).
class EscalasDemo {
  /// Caminando.
  final double caminar;

  /// Esperando el bus y arriba de él.
  final double bus;

  const EscalasDemo({this.caminar = 30, this.bus = 60});

  /// La escala para el estado [s].
  double para(AppState s) {
    final f = s.fase;
    if (f is! FaseViaje || f.estado != EstadoViaje.enCurso) return 1;
    return f.tramoActual is TramoCaminar ? caminar : bus;
  }
}

/// Destinos con viaje grabado. El id es el nombre del asset.
const destinosDemo = [
  Lugar(
    id: 'plaza-independencia',
    nombre: 'Plaza Independencia',
    detalle: 'Ciudad Vieja, Montevideo',
    coordenada: Coordenada(-34.906971, -56.19946),
  ),
  Lugar(
    id: 'tres-cruces',
    nombre: 'Terminal Tres Cruces',
    detalle: 'Tres Cruces, Montevideo',
    coordenada: Coordenada(-34.8937, -56.1664),
  ),
  Lugar(
    id: 'estadio-centenario',
    nombre: 'Estadio Centenario',
    detalle: 'Parque Batlle, Montevideo',
    coordenada: Coordenada(-34.8945, -56.1528),
  ),
  Lugar(
    id: 'mercado-puerto',
    nombre: 'Mercado del Puerto',
    detalle: 'Ciudad Vieja, Montevideo',
    coordenada: Coordenada(-34.9064, -56.2126),
  ),
  Lugar(
    id: 'punta-carretas',
    nombre: 'Punta Carretas Shopping',
    detalle: 'Punta Carretas, Montevideo',
    coordenada: Coordenada(-34.9237, -56.1590),
  ),
];

/// Devuelve el viaje grabado al destino pedido. Sin grabación (otro
/// destino u otro origen), no hay viajes: la UI lo dice como en la vida
/// real.
class PlanificadorDemo implements PlanificadorViajes {
  final AssetBundle _bundle;
  final Map<String, PlanificadorGrabado> _cargados = {};

  PlanificadorDemo({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  /// A esta distancia (m) un punto pedido se considera el grabado.
  static const tolerancia = 400.0;

  @override
  Future<List<ViajePlanificado>> planificar({
    required Coordenada origen,
    required Coordenada destino,
    required DateTime salida,
  }) async {
    if (distancia(origen, casaDemo) > tolerancia) return const [];
    Lugar? lugar;
    for (final l in destinosDemo) {
      if (distancia(destino, l.coordenada) <= tolerancia) lugar = l;
    }
    if (lugar == null) return const [];
    final plan =
        _cargados[lugar.id] ??= PlanificadorGrabado.desdeFixture(
          jsonDecode(await _bundle.loadString('assets/demo/${lugar.id}.json'))
              as Map<String, dynamic>,
        );
    return plan.planificar(origen: origen, destino: destino, salida: salida);
  }
}

/// El controlador de la app en modo demo, sobre [mundo] (los tests le
/// inyectan un reloj falso).
AppController crearControladorDemo({
  required MundoSimulado mundo,
  required CatalogoRed catalogo,
  AssetBundle? bundle,
  EscalasDemo escalas = const EscalasDemo(),
  // En tiempo real, sin importar la escala: el bus se consulta seguido y la
  // predicción del mapa suaviza entre lecturas.
  ConfigLogica config = const ConfigLogica(
    sondeoBus: Duration(milliseconds: 1500),
  ),
}) {
  final plan = PlanificadorSimulado(PlanificadorDemo(bundle: bundle), mundo);
  final c = AppController(
    planificador: plan,
    llegadas: LlegadasSimuladas(mundo),
    lugares: const LugaresFijos(destinosDemo),
    catalogo: catalogo,
    ubicacion: UbicacionSimulada(mundo),
    reloj: mundo.ahora,
    config: config,
    alIniciarViaje: (o) => mundo.recorrer(o, plan.shapesDe(o.id)),
    // Llegó: se queda en el destino mientras se ve "¡Llegaste!".
    alLlegar: mundo.detener,
    // Terminó (cerró la llegada o abandonó): vuelve a casa, de donde sale
    // el próximo viaje.
    alTerminarViaje: () {
      mundo.detener();
      mundo.posicionInicial = casaDemo;
    },
    demo: const _ControlDemo(),
  );
  // El reloj del mundo sigue al paso del viaje (sin saltar al cambiar). Al
  // arrancar no hace falta: explorando nada se mueve.
  c.addListener((s) {
    final v = escalas.para(s);
    if (v != mundo.velocidad) mundo.velocidad = v;
  }, fireImmediately: false);
  return c;
}

class _ControlDemo implements ControlDemo {
  const _ControlDemo();

  @override
  List<Lugar> get destinos => destinosDemo;
}
