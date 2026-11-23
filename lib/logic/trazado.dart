// Trazado: envuelve las costuras de la lógica (las acciones que recibe de la
// UI y los puertos hacia el mundo) para informar cada llamada en [Trazas],
// sin cambiar lo que hacen. Lo usa la demo web para mostrar la app por
// dentro.

import '../contract/app_actions.dart';
import '../contract/app_state.dart';
import '../contract/trazas.dart';
import 'puertos.dart';

String _c(Coordenada c) =>
    '(${c.lat.toStringAsFixed(4)}, ${c.lng.toStringAsFixed(4)})';

String _q(String s) => '"$s"';

/// Las acciones de la UI, informadas al llegar al controlador.
class AccionesTrazadas implements AppActions {
  final AppActions real;
  final Trazas trazas;
  AccionesTrazadas(this.real, this.trazas);

  void _t(String llamada) =>
      trazas.emitir(Pieza.interfaz, Pieza.controlador, llamada);

  @override
  void arrancar() {
    _t('arrancar()');
    real.arrancar();
  }

  @override
  void reintentarUbicacion() {
    _t('reintentarUbicacion()');
    real.reintentarUbicacion();
  }

  @override
  void escribirConsulta(CampoBusqueda campo, String texto) {
    _t('escribirConsulta(${campo.name}, ${_q(texto)})');
    real.escribirConsulta(campo, texto);
  }

  @override
  void elegirLugar(CampoBusqueda campo, Lugar lugar) {
    _t('elegirLugar(${campo.name}, ${_q(lugar.nombre)})');
    real.elegirLugar(campo, lugar);
  }

  @override
  void usarMiUbicacion(CampoBusqueda campo) {
    _t('usarMiUbicacion(${campo.name})');
    real.usarMiUbicacion(campo);
  }

  @override
  void limpiarCampo(CampoBusqueda campo) {
    _t('limpiarCampo(${campo.name})');
    real.limpiarCampo(campo);
  }

  @override
  void intercambiarOrigenYDestino() {
    _t('intercambiarOrigenYDestino()');
    real.intercambiarOrigenYDestino();
  }

  @override
  void cancelarConsulta() {
    _t('cancelarConsulta()');
    real.cancelarConsulta();
  }

  @override
  void buscarViajes() {
    _t('buscarViajes()');
    real.buscarViajes();
  }

  @override
  void enfocarOpcion(String idOpcion) {
    _t('enfocarOpcion(${_q(idOpcion)})');
    real.enfocarOpcion(idOpcion);
  }

  @override
  void cerrarOpciones() {
    _t('cerrarOpciones()');
    real.cerrarOpciones();
  }

  @override
  void iniciarViaje(String idOpcion) {
    _t('iniciarViaje(${_q(idOpcion)})');
    real.iniciarViaje(idOpcion);
  }

  @override
  void confirmarPasoActual() {
    _t('confirmarPasoActual()');
    real.confirmarPasoActual();
  }

  @override
  void terminarViaje() {
    _t('terminarViaje()');
    real.terminarViaje();
  }

  @override
  void cerrarLlegada() {
    _t('cerrarLlegada()');
    real.cerrarLlegada();
  }

  @override
  void consultarParada(String idParada) {
    _t('consultarParada(${_q(idParada)})');
    real.consultarParada(idParada);
  }

  @override
  void cerrarParada() {
    _t('cerrarParada()');
    real.cerrarParada();
  }

  @override
  void descartarAviso(int idAviso) {
    _t('descartarAviso($idAviso)');
    real.descartarAviso(idAviso);
  }
}

class PlanificadorTrazado implements PlanificadorViajes {
  final PlanificadorViajes real;
  final Trazas trazas;
  PlanificadorTrazado(this.real, this.trazas);

  @override
  Future<List<ViajePlanificado>> planificar({
    required Coordenada origen,
    required Coordenada destino,
    required DateTime salida,
  }) async {
    final llamada = 'planificar(${_c(origen)}, ${_c(destino)})';
    trazas.emitir(Pieza.controlador, Pieza.planificador, llamada);
    final r = await real.planificar(
      origen: origen,
      destino: destino,
      salida: salida,
    );
    trazas.emitir(
      Pieza.planificador,
      Pieza.controlador,
      llamada,
      resultado: '${r.length} itinerarios',
    );
    return r;
  }
}

class LlegadasTrazadas implements FuenteLlegadas {
  final FuenteLlegadas real;
  final Trazas trazas;
  LlegadasTrazadas(this.real, this.trazas);

  @override
  Future<List<LlegadaEnParada>> llegadas(String idParada) async {
    final llamada = 'llegadas(${_q(idParada)})';
    trazas.emitir(Pieza.controlador, Pieza.llegadas, llamada);
    final r = await real.llegadas(idParada);
    final enVivo = r.where((l) => l.datos.posicion != null).length;
    trazas.emitir(
      Pieza.llegadas,
      Pieza.controlador,
      llamada,
      resultado: '${r.length} buses, $enVivo en vivo',
    );
    return r;
  }
}

class LugaresTrazados implements BuscadorLugares {
  final BuscadorLugares real;
  final Trazas trazas;
  LugaresTrazados(this.real, this.trazas);

  @override
  Future<List<Lugar>> sugerencias(String texto, {Coordenada? cerca}) async {
    final llamada = 'sugerencias(${_q(texto)})';
    trazas.emitir(Pieza.controlador, Pieza.lugares, llamada);
    final r = await real.sugerencias(texto, cerca: cerca);
    trazas.emitir(
      Pieza.lugares,
      Pieza.controlador,
      llamada,
      resultado: '${r.length} lugares',
    );
    return r;
  }
}

class CatalogoTrazado implements CatalogoRed {
  final CatalogoRed real;
  final Trazas trazas;
  CatalogoTrazado(this.real, this.trazas);

  @override
  Future<List<ParadaDeRed>> paradas() async {
    trazas.emitir(Pieza.controlador, Pieza.catalogo, 'paradas()');
    final r = await real.paradas();
    trazas.emitir(
      Pieza.catalogo,
      Pieza.controlador,
      'paradas()',
      resultado: '${r.length} paradas',
    );
    return r;
  }

  @override
  Future<List<Coordenada>?> shape(String shapeId) async {
    final llamada = 'shape(${_q(shapeId.split(':').last)})';
    trazas.emitir(Pieza.controlador, Pieza.catalogo, llamada);
    final r = await real.shape(shapeId);
    trazas.emitir(
      Pieza.catalogo,
      Pieza.controlador,
      llamada,
      resultado: r == null ? 'sin recorrido' : '${r.length} puntos',
    );
    return r;
  }
}

class UbicacionTrazada implements FuenteUbicacion {
  final FuenteUbicacion real;
  final Trazas trazas;
  UbicacionTrazada(this.real, this.trazas);

  @override
  Future<PermisoUbicacion> asegurarPermiso() async {
    trazas.emitir(Pieza.controlador, Pieza.ubicacion, 'asegurarPermiso()');
    final r = await real.asegurarPermiso();
    trazas.emitir(
      Pieza.ubicacion,
      Pieza.controlador,
      'asegurarPermiso()',
      resultado: r.name,
    );
    return r;
  }

  @override
  Future<MuestraUbicacion?> actual() async {
    final r = await real.actual();
    if (r != null) _muestra(r);
    return r;
  }

  @override
  Stream<MuestraUbicacion> seguir() => real.seguir().map((m) {
    _muestra(m);
    return m;
  });

  void _muestra(MuestraUbicacion m) => trazas.emitir(
    Pieza.ubicacion,
    Pieza.controlador,
    'ubicacion${_c(m.coordenada)}',
    resultado:
        m.velocidad == null ? null : '${m.velocidad!.toStringAsFixed(1)} m/s',
  );
}
