// Tracing: wraps the seams of the logic (the actions it receives from the
// UI and the ports toward the outside world) to report each call in [Traces],
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
    _t('start()');
    real.start();
  }

  @override
  void retryLocation() {
    _t('retryLocation()');
    real.retryLocation();
  }

  @override
  void writeQuery(SearchField field, String text) {
    _t('writeQuery(${field.name}, ${_q(text)})');
    real.writeQuery(field, text);
  }

  @override
  void choosePlace(SearchField field, Place place) {
    _t('choosePlace(${field.name}, ${_q(place.name)})');
    real.choosePlace(field, place);
  }

  @override
  void useMyLocation(SearchField field) {
    _t('useMyLocation(${field.name})');
    real.useMyLocation(field);
  }

  @override
  void cleanField(SearchField field) {
    _t('cleanField(${field.name})');
    real.cleanField(field);
  }

  @override
  void swapOriginAndDestination() {
    _t('swapOriginAndDestination()');
    real.swapOriginAndDestination();
  }

  @override
  void cancelQuery() {
    _t('cancelQuery()');
    real.cancelQuery();
  }

  @override
  void searchTrips() {
    _t('searchTrips()');
    real.searchTrips();
  }

  @override
  void focusOption(String idOption) {
    _t('focusOption(${_q(idOption)})');
    real.focusOption(idOption);
  }

  @override
  void closeOptions() {
    _t('closeOptions()');
    real.closeOptions();
  }

  @override
  void startTrip(String idOption) {
    _t('startTrip(${_q(idOption)})');
    real.startTrip(idOption);
  }

  @override
  void confirmCurrentStep() {
    _t('confirmCurrentStep()');
    real.confirmCurrentStep();
  }

  @override
  void finishTrip() {
    _t('finishTrip()');
    real.finishTrip();
  }

  @override
  void closeArrival() {
    _t('closeArrival()');
    real.closeArrival();
  }

  @override
  void queryStop(String idStop) {
    _t('queryStop(${_q(idStop)})');
    real.queryStop(idStop);
  }

  @override
  void closeStop() {
    _t('closeStop()');
    real.closeStop();
  }

  @override
  void dismissNotice(int idNotice) {
    _t('dismissNotice($idNotice)');
    real.dismissNotice(idNotice);
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
    final call = 'plan(${_c(origin)}, ${_c(destination)})';
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
      result: '${r.length} itineraries',
    );
    return r;
  }
}

class TracedArrivals implements ArrivalSource {
  final ArrivalSource real;
  final Traces traces;
  TracedArrivals(this.real, this.traces);

  @override
  Future<List<StopArrival>> arrivals(String idStop) async {
    final call = 'arrivals(${_q(idStop)})';
    traces.emit(Piece.controller, Piece.arrivals, call);
    final r = await real.arrivals(idStop);
    final live = r.where((l) => l.data.position != null).length;
    traces.emit(
      Piece.arrivals,
      Piece.controller,
      call,
      result: '${r.length} buses, $live live',
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
    final call = 'suggestions(${_q(text)})';
    traces.emit(Piece.controller, Piece.places, call);
    final r = await real.suggestions(text, near: near);
    traces.emit(
      Piece.places,
      Piece.controller,
      call,
      result: '${r.length} places',
    );
    return r;
  }
}

class TracedCatalog implements NetworkCatalog {
  final NetworkCatalog real;
  final Traces traces;
  TracedCatalog(this.real, this.traces);

  @override
  Future<List<NetworkStop>> stops() async {
    traces.emit(Piece.controller, Piece.catalog, 'stops()');
    final r = await real.stops();
    traces.emit(
      Piece.catalog,
      Piece.controller,
      'stops()',
      result: '${r.length} stops',
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
      result: r == null ? 'no shape' : '${r.length} points',
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
    traces.emit(Piece.controller, Piece.location, 'ensurePermission()');
    final r = await real.ensurePermission();
    traces.emit(
      Piece.location,
      Piece.controller,
      'ensurePermission()',
      result: r.name,
    );
    return r;
  }

  @override
  Future<LocationSample?> current() async {
    final r = await real.current();
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
    'location${_c(m.coordinate)}',
    result: m.velocity == null ? null : '${m.velocity!.toStringAsFixed(1)} m/s',
  );
}
