// Tracing: wraps the seams of the logic (the actions it receives from the
// UI and the ports toward the outside world) to report each call in [Trazas],
// without changing what they do. The web demo uses it to show the app from
// the inside.

import '../contract/app_actions.dart';
import '../contract/app_state.dart';
import '../contract/traces.dart';
import 'ports.dart';

String _c(Coordinate c) =>
    '(${c.lat.toStringAsFixed(4)}, ${c.lng.toStringAsFixed(4)})';

String _q(String s) => '"$s"';

/// The UI actions, reported when they reach the controller.
class TracedActions implements AppActions {
  final AppActions real;
  final Traces traces;
  TracedActions(this.real, this.traces);

  void _t(String call) =>
      traces.emit(Piece.interfaceValue, Piece.controller, call);

  @override
  void start() {
    _t('arrancar()');
    real.start();
  }

  @override
  void retryLocation() {
    _t('reintentarUbicacion()');
    real.retryLocation();
  }

  @override
  void writeQuery(SearchField field, String text) {
    _t('escribirConsulta(${field.name}, ${_q(text)})');
    real.writeQuery(field, text);
  }

  @override
  void choosePlace(SearchField field, Place place) {
    _t('elegirLugar(${field.name}, ${_q(place.name)})');
    real.choosePlace(field, place);
  }

  @override
  void useMyLocation(SearchField field) {
    _t('usarMiUbicacion(${field.name})');
    real.useMyLocation(field);
  }

  @override
  void cleanField(SearchField field) {
    _t('limpiarCampo(${field.name})');
    real.cleanField(field);
  }

  @override
  void swapOriginYDestination() {
    _t('intercambiarOrigenYDestino()');
    real.swapOriginYDestination();
  }

  @override
  void cancelarQuery() {
    _t('cancelarConsulta()');
    real.cancelarQuery();
  }

  @override
  void searchTrips() {
    _t('buscarViajes()');
    real.searchTrips();
  }

  @override
  void focusOption(String idOption) {
    _t('enfocarOpcion(${_q(idOption)})');
    real.focusOption(idOption);
  }

  @override
  void closeOptions() {
    _t('cerrarOpciones()');
    real.closeOptions();
  }

  @override
  void startTrip(String idOption) {
    _t('iniciarViaje(${_q(idOption)})');
    real.startTrip(idOption);
  }

  @override
  void confirmStepActual() {
    _t('confirmarPasoActual()');
    real.confirmStepActual();
  }

  @override
  void finishTrip() {
    _t('terminarViaje()');
    real.finishTrip();
  }

  @override
  void closeArrival() {
    _t('cerrarLlegada()');
    real.closeArrival();
  }

  @override
  void queryStop(String idStop) {
    _t('consultarParada(${_q(idStop)})');
    real.queryStop(idStop);
  }

  @override
  void closeStop() {
    _t('cerrarParada()');
    real.closeStop();
  }

  @override
  void descartarNotice(int idNotice) {
    _t('descartarAviso($idNotice)');
    real.descartarNotice(idNotice);
  }
}

class TracedPlanner implements TripPlanner {
  final TripPlanner real;
  final Traces traces;
  TracedPlanner(this.real, this.traces);

  @override
  Future<List<PlannedTrip>> plan({
    required Coordinate origin,
    required Coordinate destination,
    required DateTime exit,
  }) async {
    final call = 'planificar(${_c(origin)}, ${_c(destination)})';
    traces.emit(Piece.controller, Piece.planner, call);
    final r = await real.plan(
      origin: origin,
      destination: destination,
      exit: exit,
    );
    traces.emit(
      Piece.planner,
      Piece.controller,
      call,
      result: '${r.length} itinerarios',
    );
    return r;
  }
}

class TracedArrivals implements SourceArrivals {
  final SourceArrivals real;
  final Traces traces;
  TracedArrivals(this.real, this.traces);

  @override
  Future<List<StopArrival>> arrivals(String idStop) async {
    final call = 'llegadas(${_q(idStop)})';
    traces.emit(Piece.controller, Piece.arrivals, call);
    final r = await real.arrivals(idStop);
    final live = r.where((l) => l.data.position != null).length;
    traces.emit(
      Piece.arrivals,
      Piece.controller,
      call,
      result: '${r.length} buses, $live en vivo',
    );
    return r;
  }
}

class TracedPlaces implements PlaceSearcher {
  final PlaceSearcher real;
  final Traces traces;
  TracedPlaces(this.real, this.traces);

  @override
  Future<List<Place>> suggestions(String text, {Coordinate? near}) async {
    final call = 'sugerencias(${_q(text)})';
    traces.emit(Piece.controller, Piece.places, call);
    final r = await real.suggestions(text, near: near);
    traces.emit(
      Piece.places,
      Piece.controller,
      call,
      result: '${r.length} lugares',
    );
    return r;
  }
}

class TracedCatalog implements CatalogRed {
  final CatalogRed real;
  final Traces traces;
  TracedCatalog(this.real, this.traces);

  @override
  Future<List<NetworkStop>> stops() async {
    traces.emit(Piece.controller, Piece.catalog, 'paradas()');
    final r = await real.stops();
    traces.emit(
      Piece.catalog,
      Piece.controller,
      'paradas()',
      result: '${r.length} paradas',
    );
    return r;
  }

  @override
  Future<List<Coordinate>?> shape(String shapeId) async {
    final call = 'shape(${_q(shapeId.split(':').last)})';
    traces.emit(Piece.controller, Piece.catalog, call);
    final r = await real.shape(shapeId);
    traces.emit(
      Piece.catalog,
      Piece.controller,
      call,
      result: r == null ? 'sin recorrido' : '${r.length} puntos',
    );
    return r;
  }
}

class TracedLocation implements LocationSource {
  final LocationSource real;
  final Traces traces;
  TracedLocation(this.real, this.traces);

  @override
  Future<LocationPermissionState> ensurePermission() async {
    traces.emit(Piece.controller, Piece.location, 'asegurarPermiso()');
    final r = await real.ensurePermission();
    traces.emit(
      Piece.location,
      Piece.controller,
      'asegurarPermiso()',
      result: r.name,
    );
    return r;
  }

  @override
  Future<LocationSample?> actual() async {
    final r = await real.actual();
    if (r != null) _sample(r);
    return r;
  }

  @override
  Stream<LocationSample> follow() => real.follow().map((m) {
    _sample(m);
    return m;
  });

  void _sample(LocationSample m) => traces.emit(
    Piece.location,
    Piece.controller,
    'ubicacion${_c(m.coordinate)}',
    result: m.velocity == null ? null : '${m.velocity!.toStringAsFixed(1)} m/s',
  );
}
