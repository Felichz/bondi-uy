import 'dart:async';

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/logic/app_controller.dart';
import 'package:bondi_uy/logic/puertos.dart';
import 'package:bondi_uy/logic/simulacion/grabado.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

const _origen = Coordenada(-34.902448, -56.12828);
const _plaza = Lugar(
  id: 'plaza',
  nombre: 'Plaza Independencia',
  coordenada: Coordenada(-34.906971, -56.19946),
);

class _Ubicacion implements FuenteUbicacion {
  final c = StreamController<MuestraUbicacion>.broadcast();
  PermisoUbicacion permiso = PermisoUbicacion.concedido;
  @override
  Future<PermisoUbicacion> asegurarPermiso() async => permiso;
  @override
  Future<MuestraUbicacion?> actual() async =>
      MuestraUbicacion(coordenada: _origen, momento: DateTime(2026));
  @override
  Stream<MuestraUbicacion> seguir() => c.stream;
}

class _Lugares implements BuscadorLugares {
  final pedidos = <String>[];
  @override
  Future<List<Lugar>> sugerencias(String texto, {Coordenada? cerca}) async {
    pedidos.add(texto);
    return [_plaza];
  }
}

class _Llegadas implements FuenteLlegadas {
  final pedidos = <String>[];
  List<LlegadaEnParada> respuesta = const [];
  @override
  Future<List<LlegadaEnParada>> llegadas(String idParada) async {
    pedidos.add(idParada);
    return respuesta;
  }
}

class _Catalogo implements CatalogoRed {
  @override
  Future<List<ParadaDeRed>> paradas() async => const [
    ParadaDeRed(
      parada: Parada(
        id: '5296',
        nombre: 'Rbla Armenia',
        coordenada: Coordenada(-34.8973, -56.1146),
      ),
      lineas: ['D1', '104'],
    ),
  ];
  @override
  Future<List<Coordenada>?> shape(String shapeId) async =>
      shapeDelAsset(shapeId);
}

void main() {
  late _Ubicacion ubicacion;
  late _Lugares lugares;
  late _Llegadas llegadas;

  AppController crear() {
    ubicacion = _Ubicacion();
    lugares = _Lugares();
    llegadas = _Llegadas();
    return AppController(
      planificador: PlanificadorGrabado.desdeFixture(fixture()),
      llegadas: llegadas,
      lugares: lugares,
      catalogo: _Catalogo(),
      ubicacion: ubicacion,
      reloj: () => DateTime(2026, 9, 28, 18),
    );
  }

  test('arrancar: carga paradas y ubicación', () {
    fakeAsync((f) {
      final c = crear()..arrancar();
      f.flushMicrotasks();
      expect(c.state.paradas, hasLength(1));
      expect(c.state.ubicacion.estado, EstadoUbicacion.disponible);
      expect(c.state.ubicacion.coordenada, _origen);
      c.dispose();
    });
  });

  test('sin permiso: estado sinPermiso y no se sigue el GPS', () {
    fakeAsync((f) {
      final c = crear();
      ubicacion.permiso = PermisoUbicacion.denegado;
      c.arrancar();
      f.flushMicrotasks();
      expect(c.state.ubicacion.estado, EstadoUbicacion.sinPermiso);
      expect(c.state.ubicacion.coordenada, isNull);
      c.dispose();
    });
  });

  test('sugerencias con debounce: solo se consulta el último texto', () {
    fakeAsync((f) {
      final c = crear();
      for (final t in ['p', 'pl', 'pla', 'plaz', 'plaza']) {
        c.escribirConsulta(CampoBusqueda.destino, t);
        f.elapse(const Duration(milliseconds: 100));
      }
      expect(c.state.busqueda.estadoSugerencias, EstadoSugerencias.cargando);
      f.elapse(const Duration(milliseconds: 400));
      expect(lugares.pedidos, ['plaza']);
      expect(c.state.busqueda.sugerencias.single.nombre, 'Plaza Independencia');
      expect(c.state.busqueda.estadoSugerencias, EstadoSugerencias.listo);
      c.dispose();
    });
  });

  test(
    'elegir destino, buscar: opciones con exactamente una recomendada y ETAs',
    () {
      fakeAsync((f) {
        final c = crear()..arrancar();
        f.flushMicrotasks();
        c.elegirLugar(CampoBusqueda.destino, _plaza);
        c.buscarViajes();
        expect((c.state.fase as FaseOpciones).estado, EstadoOpciones.cargando);
        f.flushMicrotasks();
        final fase = c.state.fase as FaseOpciones;
        expect(fase.estado, EstadoOpciones.listo);
        expect(fase.opciones.where((o) => o.recomendada), hasLength(1));
        expect(fase.opciones.first.recomendada, isTrue);
        expect(fase.origen, _origen);
        // Se piden ETAs de las paradas de subida (sin repetir).
        expect(llegadas.pedidos.toSet().length, llegadas.pedidos.length);
        c.dispose();
      });
    },
  );

  test('intercambiar y "Mi ubicación" nunca en los dos extremos', () {
    final c = crear();
    c.elegirLugar(CampoBusqueda.destino, _plaza);
    c.intercambiarOrigenYDestino();
    expect(c.state.busqueda.origen, const LugarElegido(_plaza));
    expect(c.state.busqueda.destino, const MiUbicacion());
    c.usarMiUbicacion(CampoBusqueda.origen);
    expect(c.state.busqueda.origen, const MiUbicacion());
    expect(c.state.busqueda.destino, isNull);
    c.dispose();
  });

  test('buscar sin destino avisa y no cambia de fase', () {
    final c = crear();
    c.buscarViajes();
    expect(c.state.aviso?.tipo, TipoAviso.faltaDestino);
    expect(c.state.fase, isA<FaseExplorar>());
    c.dispose();
  });

  test(
    'viaje: el sondeo sigue la espera del paso actual y se apaga arriba del bus',
    () {
      fakeAsync((f) {
        final c = crear()..arrancar();
        f.flushMicrotasks();
        c.elegirLugar(CampoBusqueda.destino, _plaza);
        c.buscarViajes();
        f.flushMicrotasks();
        final opcion = (c.state.fase as FaseOpciones).opciones.firstWhere(
          (o) => o.lineas.isNotEmpty,
        );
        final espera = opcion.tramos.whereType<TramoEsperar>().first;
        llegadas.respuesta = [
          LlegadaEnParada(
            LlegadaBus(linea: espera.linea, minutos: 4, enVivo: true),
            vehiculo: '1',
          ),
        ];
        llegadas.pedidos.clear();
        c.iniciarViaje(opcion.id);
        f.elapse(const Duration(seconds: 1));
        expect(llegadas.pedidos, contains(espera.parada.id));
        var viaje = c.state.fase as FaseViaje;
        expect(viaje.busEsperado?.minutos, 4);
        // Confirmar manualmente hasta estar arriba del bus.
        while ((c.state.fase as FaseViaje).tramoActual is! TramoBus) {
          c.confirmarPasoActual();
          f.elapse(const Duration(milliseconds: 10));
        }
        viaje = c.state.fase as FaseViaje;
        expect(
          viaje.busEsperado,
          isNull,
          reason: 'arriba del bus, el bus es el usuario',
        );
        llegadas.pedidos.clear();
        f.elapse(const Duration(seconds: 30));
        final hayOtraEspera = viaje.opcion.tramos
            .skip(viaje.pasoActual)
            .any((t) => t is TramoEsperar);
        if (!hayOtraEspera) expect(llegadas.pedidos, isEmpty);
        c.terminarViaje();
        expect(c.state.fase, isA<FaseExplorar>());
        c.dispose();
      });
    },
  );

  test('parada consultada: llegadas ordenadas y cierre', () {
    fakeAsync((f) {
      final c = crear()..arrancar();
      f.flushMicrotasks();
      llegadas.respuesta = const [
        LlegadaEnParada(LlegadaBus(linea: '104', minutos: 9, enVivo: false)),
        LlegadaEnParada(LlegadaBus(linea: 'D1', minutos: 2, enVivo: true)),
      ];
      c.consultarParada('5296');
      expect(c.state.paradaConsultada?.estado, EstadoConsulta.cargando);
      f.flushMicrotasks();
      final p = c.state.paradaConsultada!;
      expect(p.estado, EstadoConsulta.listo);
      expect(p.llegadas.map((l) => l.linea), ['D1', '104']);
      c.cerrarParada();
      expect(c.state.paradaConsultada, isNull);
      llegadas.pedidos.clear();
      f.elapse(const Duration(minutes: 1));
      expect(llegadas.pedidos, isEmpty, reason: 'sin sondeo después de cerrar');
      c.dispose();
    });
  });
}
