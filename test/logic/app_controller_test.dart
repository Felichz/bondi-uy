import 'dart:async';

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/logic/app_controller.dart';
import 'package:bondi_uy/logic/ports.dart';
import 'package:bondi_uy/logic/simulation/recording.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

const _origin = Coordinate(-34.902448, -56.12828);
const _square = Place(
  id: 'plaza',
  name: 'Plaza Independencia',
  coordinate: Coordinate(-34.906971, -56.19946),
);

class _Location implements LocationSource {
  final c = StreamController<LocationSample>.broadcast();
  LocationPermissionState permission = LocationPermissionState.granted;
  @override
  Future<LocationPermissionState> ensurePermission() async => permission;
  @override
  Future<LocationSample?> actual() async =>
      LocationSample(coordinate: _origin, moment: DateTime(2026));
  @override
  Stream<LocationSample> follow() => c.stream;
}

class _Places implements PlaceSearcher {
  final requests = <String>[];
  @override
  Future<List<Place>> suggestions(String text, {Coordinate? near}) async {
    requests.add(text);
    return [_square];
  }
}

class _Arrivals implements SourceArrivals {
  final requests = <String>[];
  List<StopArrival> answer = const [];
  @override
  Future<List<StopArrival>> arrivals(String idStop) async {
    requests.add(idStop);
    return answer;
  }
}

class _Catalog implements CatalogRed {
  @override
  Future<List<NetworkStop>> stops() async => const [
    NetworkStop(
      stop: Stop(
        id: '5296',
        name: 'Rbla Armenia',
        coordinate: Coordinate(-34.8973, -56.1146),
      ),
      lines: ['D1', '104'],
    ),
  ];
  @override
  Future<List<Coordinate>?> shape(String shapeId) async =>
      shapeDelAsset(shapeId);
}

void main() {
  late _Location location;
  late _Places places;
  late _Arrivals arrivals;

  AppController create() {
    location = _Location();
    places = _Places();
    arrivals = _Arrivals();
    return AppController(
      planner: RecordingPlanner.fromFixture(fixture()),
      arrivals: arrivals,
      places: places,
      catalog: _Catalog(),
      location: location,
      clock: () => DateTime(2026, 9, 28, 18),
    );
  }

  test('arrancar: carga paradas y ubicación', () {
    fakeAsync((f) {
      final c = create()..start();
      f.flushMicrotasks();
      expect(c.state.stops, hasLength(1));
      expect(c.state.location.status, LocationStatus.available);
      expect(c.state.location.coordinate, _origin);
      c.dispose();
    });
  });

  test('sin permiso: estado sinPermiso y no se sigue el GPS', () {
    fakeAsync((f) {
      final c = create();
      location.permission = LocationPermissionState.denied;
      c.start();
      f.flushMicrotasks();
      expect(c.state.location.status, LocationStatus.withoutPermission);
      expect(c.state.location.coordinate, isNull);
      c.dispose();
    });
  });

  test('sugerencias con debounce: solo se consulta el último texto', () {
    fakeAsync((f) {
      final c = create();
      for (final t in ['p', 'pl', 'pla', 'plaz', 'plaza']) {
        c.writeQuery(SearchField.destination, t);
        f.elapse(const Duration(milliseconds: 100));
      }
      expect(c.state.search.statusSuggestions, SuggestionsStatus.loading);
      f.elapse(const Duration(milliseconds: 400));
      expect(places.requests, ['plaza']);
      expect(c.state.search.suggestions.single.name, 'Plaza Independencia');
      expect(c.state.search.statusSuggestions, SuggestionsStatus.ready);
      c.dispose();
    });
  });

  test(
    'elegir destino, buscar: opciones con exactamente una recomendada y ETAs',
    () {
      fakeAsync((f) {
        final c = create()..start();
        f.flushMicrotasks();
        c.choosePlace(SearchField.destination, _square);
        c.searchTrips();
        expect((c.state.phase as OptionsPhase).status, OptionsStatus.loading);
        f.flushMicrotasks();
        final phase = c.state.phase as OptionsPhase;
        expect(phase.status, OptionsStatus.ready);
        expect(phase.options.where((o) => o.recommended), hasLength(1));
        expect(phase.options.first.recommended, isTrue);
        expect(phase.origin, _origin);
        // ETAs are requested for the boarding stops (without repeating).
        expect(arrivals.requests.toSet().length, arrivals.requests.length);
        c.dispose();
      });
    },
  );

  test('intercambiar y "Mi ubicación" nunca en los dos extremos', () {
    final c = create();
    c.choosePlace(SearchField.destination, _square);
    c.swapOriginYDestination();
    expect(c.state.search.origin, const ChosenPlace(_square));
    expect(c.state.search.destination, const MyLocation());
    c.useMyLocation(SearchField.origin);
    expect(c.state.search.origin, const MyLocation());
    expect(c.state.search.destination, isNull);
    c.dispose();
  });

  test('buscar sin destino avisa y no cambia de fase', () {
    final c = create();
    c.searchTrips();
    expect(c.state.notice?.type, NoticeType.missingDestination);
    expect(c.state.phase, isA<ExplorePhase>());
    c.dispose();
  });

  test(
    'viaje: el sondeo sigue la espera del paso actual y se apaga arriba del bus',
    () {
      fakeAsync((f) {
        final c = create()..start();
        f.flushMicrotasks();
        c.choosePlace(SearchField.destination, _square);
        c.searchTrips();
        f.flushMicrotasks();
        final option = (c.state.phase as OptionsPhase).options.firstWhere(
          (o) => o.lines.isNotEmpty,
        );
        final wait = option.legs.whereType<WaitLeg>().first;
        arrivals.answer = [
          StopArrival(
            BusArrival(line: wait.line, minutes: 4, live: true),
            vehicle: '1',
          ),
        ];
        arrivals.requests.clear();
        c.startTrip(option.id);
        f.elapse(const Duration(seconds: 1));
        expect(arrivals.requests, contains(wait.stop.id));
        var trip = c.state.phase as TripPhase;
        expect(trip.busExpected?.minutes, 4);
        // Confirm manually until on board the bus.
        while ((c.state.phase as TripPhase).legActual is! BusLeg) {
          c.confirmStepActual();
          f.elapse(const Duration(milliseconds: 10));
        }
        trip = c.state.phase as TripPhase;
        expect(
          trip.busExpected,
          isNull,
          reason: 'arriba del bus, el bus es el usuario',
        );
        arrivals.requests.clear();
        f.elapse(const Duration(seconds: 30));
        final hasAnotherWait = trip.option.legs
            .skip(trip.stepActual)
            .any((t) => t is WaitLeg);
        if (!hasAnotherWait) expect(arrivals.requests, isEmpty);
        c.finishTrip();
        expect(c.state.phase, isA<ExplorePhase>());
        c.dispose();
      });
    },
  );

  test('parada consultada: llegadas ordenadas y cierre', () {
    fakeAsync((f) {
      final c = create()..start();
      f.flushMicrotasks();
      arrivals.answer = const [
        StopArrival(BusArrival(line: '104', minutes: 9, live: false)),
        StopArrival(BusArrival(line: 'D1', minutes: 2, live: true)),
      ];
      c.queryStop('5296');
      expect(c.state.stopQueried?.status, QueryStatus.loading);
      f.flushMicrotasks();
      final p = c.state.stopQueried!;
      expect(p.status, QueryStatus.ready);
      expect(p.arrivals.map((l) => l.line), ['D1', '104']);
      c.closeStop();
      expect(c.state.stopQueried, isNull);
      arrivals.requests.clear();
      f.elapse(const Duration(minutes: 1));
      expect(
        arrivals.requests,
        isEmpty,
        reason: 'sin sondeo después de cerrar',
      );
      c.dispose();
    });
  });
}
