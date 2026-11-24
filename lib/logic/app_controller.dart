// Implementation of AppActions: the app's data "chef".
//
// Receives intents from the UI, queries the ports (OTP, Montevideo API,
// geocoding, GPS, GTFS catalog) and publishes a new AppState. It knows nothing
// about widgets, maps, colors or texts.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contract/app_actions.dart';
import '../contract/app_state.dart';
import '../contract/traces.dart';
import 'geo/geo.dart';
import 'ports.dart';
import 'trip/trip_navigator.dart';
import 'trip/recommender.dart';
import 'trip/bus_tracker.dart';

class LogicConfig {
  final Duration pollBus;
  final Duration pollStop;
  final Duration debounceSuggestions;
  final NavigationRules rules;

  /// Stops whose ETAs are requested when showing options.
  final int maxStopsEta;

  const LogicConfig({
    this.pollBus = const Duration(seconds: 10),
    this.pollStop = const Duration(seconds: 20),
    this.debounceSuggestions = const Duration(milliseconds: 350),
    this.rules = const NavigationRules(),
    this.maxStopsEta = 4,
  });
}

class AppController extends StateNotifier<AppState> implements AppActions {
  final TripPlanner _planner;
  final ArrivalSource _arrivals;
  final PlaceSearcher _places;
  final NetworkCatalog _catalog;
  final LocationSource _location;
  final Clock _now;
  final LogicConfig config;

  /// Hooks for demo mode (GPS simulation over the chosen trip).
  final void Function(TripOption option)? onStartTrip;
  final void Function()? onFinishTrip;

  /// On arrival at the destination (if not given, [onFinishTrip] is used).
  final void Function()? onArrive;

  /// Reports calls to the core pieces (the web demo shows them).
  final Traces? traces;

  AppController({
    required TripPlanner planner,
    required ArrivalSource arrivals,
    required PlaceSearcher places,
    required NetworkCatalog catalog,
    required LocationSource location,
    Clock? clock,
    this.config = const LogicConfig(),
    this.onStartTrip,
    this.onFinishTrip,
    this.onArrive,
    this.traces,
    DemoControl? demo,
    AppState? statusInitial,
  }) : _planner = planner,
       _arrivals = arrivals,
       _places = places,
       _catalog = catalog,
       _location = location,
       _now = clock ?? DateTime.now,
       super(
         (statusInitial ?? AppState.initial()).copyWith(
           demo: demo == null ? null : Demo(destinations: demo.destinations),
         ),
       );

  // --- internal state (not visible to the UI) ---
  bool _started = false;
  StreamSubscription<LocationSample>? _gps;
  Timer? _debounce;
  int _secQuery = 0;
  int _secSearch = 0;
  int _secNotice = 0;

  final Map<String, PlannedTrip> _planned = {};
  final Map<String, BusTracker> _optionTrackers = {};
  Timer? _timerOptions;
  String? _optionFocused;

  TripNavigator? _nav;
  Timer? _timerTrip;
  BusTracker? _trackerTrip;
  int? _trackedWait;
  int _secTrip = 0;
  final Set<String> _noticesGiven = {};

  Timer? _timerStop;
  int _secStop = 0;

  // =====================================================================
  // Startup and location
  // =====================================================================

  @override
  void start() {
    if (_started) return;
    _started = true;
    unawaited(_loadStops());
    unawaited(_startLocation());
  }

  Future<void> _loadStops() async {
    try {
      final stops = await _catalog.stops();
      if (mounted) state = state.copyWith(stops: stops);
    } catch (_) {
      // Without the stops network the app keeps working (stops just aren't shown).
    }
  }

  @override
  void retryLocation() => unawaited(_startLocation());

  Future<void> _startLocation() async {
    _publishLocation(LocationStatus.searching, state.location.coordinate);
    final LocationPermissionState permission;
    try {
      permission = await _location.ensurePermission();
    } catch (_) {
      _publishLocation(LocationStatus.error, null);
      return;
    }
    if (!mounted) return;
    switch (permission) {
      case LocationPermissionState.granted:
        break;
      case LocationPermissionState.serviceOff:
        _publishLocation(LocationStatus.disabled, null);
        return;
      case LocationPermissionState.denied:
      case LocationPermissionState.deniedForever:
        _publishLocation(LocationStatus.withoutPermission, null);
        return;
    }
    await _gps?.cancel();
    _gps = _location.follow().listen(_onSample, onError: (_) {});
    final first = await _location.current();
    if (!mounted) return;
    if (first != null) {
      _onSample(first);
    } else if (state.location.coordinate == null) {
      _publishLocation(LocationStatus.error, null);
    }
  }

  void _publishLocation(LocationStatus status, Coordinate? c) {
    if (!mounted) return;
    state = state.copyWith(
      location: UserLocation(status: status, coordinate: c),
    );
  }

  void _onSample(LocationSample m) {
    if (!mounted) return;
    final previous = state.location.coordinate;
    final phase = state.phase;
    final move =
        previous == null ||
        distance(previous, m.coordinate) > 2 ||
        state.location.status != LocationStatus.available;

    if (phase is TripPhase &&
        phase.status == TripStatus.inProgress &&
        _nav != null) {
      final r = _nav!.process(m);
      traces?.emit(
        Piece.controller,
        Piece.navigator,
        'process(sample)',
        result: _summaryStep(r),
      );
      var fresh = phase.copyWith(
        currentStep: r.step,
        progress: r.progress,
        user: m.coordinate,
        originAdvance: r.advanced ? OriginAdvance.automatic : null,
      );
      if (r.completed) {
        fresh = fresh.copyWith(status: TripStatus.completed, end: _now());
      }
      state = state.copyWith(
        location: UserLocation(
          status: LocationStatus.available,
          coordinate: m.coordinate,
        ),
        phase: fresh,
      );
      if (r.advanced || r.completed) _onStepChange();
      _pollIfLeaving();
      _noticesOfProgress();
      return;
    }
    if (move) {
      _publishLocation(LocationStatus.available, m.coordinate);
    }
  }

  // =====================================================================
  // Search
  // =====================================================================

  @override
  void writeQuery(SearchField field, String text) {
    final t = text.trim();
    final seq = ++_secQuery;
    _debounce?.cancel();
    if (t.length < 2) {
      state = state.copyWith(
        search: state.search.withQuery(
          field: field,
          text: text,
          suggestions: const [],
          status: SuggestionsStatus.inactive,
        ),
      );
      return;
    }
    state = state.copyWith(
      search: state.search.withQuery(
        field: field,
        text: text,
        status: SuggestionsStatus.loading,
      ),
    );
    _debounce = Timer(config.debounceSuggestions, () async {
      try {
        final res = await _places.suggestions(
          t,
          near: state.location.coordinate,
        );
        if (!mounted || seq != _secQuery) return;
        state = state.copyWith(
          search: state.search.withQuery(
            field: field,
            text: text,
            suggestions: res,
            status: SuggestionsStatus.ready,
          ),
        );
      } catch (_) {
        if (!mounted || seq != _secQuery) return;
        state = state.copyWith(
          search: state.search.withQuery(
            field: field,
            text: text,
            suggestions: const [],
            status: SuggestionsStatus.error,
          ),
        );
      }
    });
  }

  @override
  void cancelQuery() {
    _debounce?.cancel();
    _secQuery++;
    state = state.copyWith(search: state.search.withoutQuery());
  }

  @override
  void choosePlace(SearchField field, Place place) {
    _debounce?.cancel();
    _secQuery++;
    state = state.copyWith(
      search: state.search.withPoint(field, ChosenPlace(place)),
    );
  }

  @override
  void useMyLocation(SearchField field) {
    _secQuery++;
    final current = state.search;
    // "Mi ubicación" can't be both origin and destination at the same time.
    if (field == SearchField.destination && current.origin is MyLocation) {
      state = state.copyWith(search: current.withoutQuery());
      return;
    }
    var b = current.withPoint(field, const MyLocation());
    if (field == SearchField.origin && b.destination is MyLocation) {
      b = b.withPoint(SearchField.destination, null);
    }
    state = state.copyWith(search: b);
    if (state.location.coordinate == null) retryLocation();
  }

  @override
  void cleanField(SearchField field) {
    _secQuery++;
    state = state.copyWith(search: state.search.withPoint(field, null));
  }

  @override
  void swapOriginAndDestination() {
    final b = state.search;
    if (b.destination == null) return;
    state = state.copyWith(
      search: Search(origin: b.destination!, destination: b.origin),
    );
  }

  Coordinate? _resolver(SearchPoint? p) => switch (p) {
    MyLocation() => state.location.coordinate,
    ChosenPlace(:final place) => place.coordinate,
    null => null,
  };

  @override
  void searchTrips() => unawaited(_searchTrips());

  Future<void> _searchTrips() async {
    final b = state.search;
    if (b.destination == null) {
      _postNotice(NoticeType.missingDestination);
      return;
    }
    final origin = _resolver(b.origin);
    final destination = _resolver(b.destination);
    if (origin == null || destination == null) {
      _postNotice(NoticeType.withoutLocation);
      if (state.location.coordinate == null) retryLocation();
      return;
    }
    final seq = ++_secSearch;
    _stopOptions();
    _planned.clear();
    state = state.copyWith(
      search: b.withoutQuery(),
      cleanStopQueried: true,
      phase: OptionsPhase(
        status: OptionsStatus.loading,
        origin: origin,
        destination: destination,
      ),
    );
    _closeStopInternal();

    final List<PlannedTrip> trips;
    try {
      final raw = await _planner.plan(
        origin: origin,
        destination: destination,
        exit: _now(),
      );
      trips = sortAndRecommend(raw, _now());
      traces?.emit(
        Piece.controller,
        Piece.recommender,
        'sortAndRecommend(${raw.length} trips)',
        result:
            trips.isEmpty
                ? 'no options'
                : '${trips.length} options, one recommended',
      );
    } catch (_) {
      if (!mounted || seq != _secSearch) return;
      state = state.copyWith(
        phase: OptionsPhase(
          status: OptionsStatus.error,
          origin: origin,
          destination: destination,
        ),
      );
      // The options phase in `error` state already conveys this: no extra notice.
      return;
    }
    if (!mounted || seq != _secSearch || state.phase is! OptionsPhase) return;
    for (final v in trips) {
      _planned[v.option.id] = v;
    }
    state = state.copyWith(
      phase: OptionsPhase(
        status:
            trips.isEmpty ? OptionsStatus.withoutResults : OptionsStatus.ready,
        origin: origin,
        destination: destination,
        options: [
          for (final v in trips)
            v.option.withNextBus(null, notice: noticeOfOption(v.option)),
        ],
      ),
    );
    if (trips.isNotEmpty) unawaited(_optionEtas(seq));
  }

  /// Requests ETAs for the boarding stop of each option's first bus.
  Future<void> _optionEtas(int seq) async {
    final phase = state.phase;
    if (phase is! OptionsPhase) return;
    final stops = <String>{};
    for (final o in phase.options) {
      final b = o.firstBus;
      if (b != null && stops.length < config.maxStopsEta)
        stops.add(b.boarding.id);
    }
    final results = <String, List<StopArrival>>{};
    await Future.wait([
      for (final id in stops)
        _arrivals
            .arrivals(id)
            .then((l) => results[id] = l)
            .catchError((_) => const <StopArrival>[]),
    ]);
    if (!mounted || seq != _secSearch) return;
    final current = state.phase;
    if (current is! OptionsPhase) return;
    final options = <TripOption>[];
    for (final o in current.options) {
      final b = o.firstBus;
      final list = b == null ? null : results[b.boarding.id];
      if (b == null || list == null) {
        options.add(o);
        continue;
      }
      final seg = _trackerOption(o.id);
      final bus = (await seg)?.choose(list, retain: false);
      _traceChoice(list, bus);
      final arrival =
          bus == null
              ? null
              : BusArrival(
                line: bus.line,
                minutes: bus.minutes,
                live: bus.live,
                position: bus.position,
              );
      options.add(
        o.withNextBus(
          arrival,
          notice:
              noticeOfOption(o, next: arrival) ??
              (arrival == null || !arrival.live
                  ? NoticeOption.withoutLiveDataFirstBus
                  : null),
        ),
      );
      if (bus != null && bus.position != null) {
        _setOptionBus(o.id, bus);
      }
    }
    final f = state.phase;
    if (!mounted || seq != _secSearch || f is! OptionsPhase) return;
    state = state.copyWith(phase: f.copyWith(options: options));
  }

  void _setOptionBus(String id, BusInPath bus) {
    final f = state.phase;
    if (f is! OptionsPhase) return;
    state = state.copyWith(
      phase: f.copyWith(liveBuses: {...f.liveBuses, id: bus}),
    );
  }

  final Map<String, Future<BusTracker?>> _optionTrackerFutures = {};

  Future<BusTracker?> _trackerOption(String idOption) {
    return _optionTrackerFutures[idOption] ??= () async {
      final v = _planned[idOption];
      final bus = v?.option.firstBus;
      if (v == null || bus == null) return null;
      final seg = BusTracker(
        line: bus.line,
        route: await _route(v, bus),
        clock: _now,
      );
      _optionTrackers[idOption] = seg;
      return seg;
    }();
  }

  Future<RouteLine?> _route(PlannedTrip v, BusLeg bus) async {
    final shapeId = v.shapeByLeg[bus.id];
    List<Coordinate>? shape;
    if (shapeId != null) {
      try {
        shape = await _catalog.shape(shapeId);
      } catch (_) {}
    }
    return RouteLine.ofLeg(bus, shape);
  }

  @override
  void focusOption(String idOption) {
    if (state.phase is! OptionsPhase) return;
    if (_optionFocused == idOption && _timerOptions != null) return;
    _optionFocused = idOption;
    _timerOptions?.cancel();
    final seq = _secSearch;
    unawaited(_pollOption(idOption, seq));
    _timerOptions = Timer.periodic(
      config.pollBus,
      (_) => _pollOption(idOption, seq),
    );
  }

  Future<void> _pollOption(String idOption, int seq) async {
    final v = _planned[idOption];
    final bus = v?.option.firstBus;
    if (v == null || bus == null) return;
    final List<StopArrival> list;
    try {
      list = await _arrivals.arrivals(bus.boarding.id);
    } catch (_) {
      return;
    }
    final seg = await _trackerOption(idOption);
    if (!mounted || seq != _secSearch || _optionFocused != idOption) return;
    // In the preview nobody waits at the stop: the bus that passed makes room
    // for the next one.
    final chosen = seg?.choose(list, retain: false);
    _traceChoice(list, chosen);
    final f = state.phase;
    if (f is! OptionsPhase) return;
    final buses = Map.of(f.liveBuses);
    if (chosen == null || chosen.position == null) {
      buses.remove(idOption);
    } else {
      buses[idOption] = chosen;
    }
    final options = [
      for (final o in f.options)
        if (o.id == idOption && chosen != null)
          o.withNextBus(
            BusArrival(
              line: chosen.line,
              minutes: chosen.minutes,
              live: chosen.live,
              position: chosen.position,
            ),
          )
        else
          o,
    ];
    state = state.copyWith(
      phase: f.copyWith(options: options, liveBuses: buses),
    );
  }

  void _stopOptions() {
    _timerOptions?.cancel();
    _timerOptions = null;
    _optionFocused = null;
    _optionTrackers.clear();
    _optionTrackerFutures.clear();
  }

  @override
  void closeOptions() {
    _secSearch++;
    _stopOptions();
    state = state.copyWith(phase: const ExplorePhase());
  }

  // =====================================================================
  // Active trip
  // =====================================================================

  @override
  void startTrip(String idOption) {
    final f = state.phase;
    if (f is! OptionsPhase) return;
    TripOption? option;
    for (final o in f.options) {
      if (o.id == idOption) option = o;
    }
    if (option == null) return;
    _stopOptions();
    _secTrip++;
    _noticesGiven.clear();
    _nav = TripNavigator(option, rules: config.rules);
    final user = state.location.coordinate;
    var phase = TripPhase(
      option: option,
      currentStep: 0,
      originAdvance: OriginAdvance.start,
      progress: ProgressStep.empty,
      status: TripStatus.inProgress,
      start: _now(),
      user: user,
      // We were already following the first leg's bus in the preview.
      busExpected: f.liveBuses[idOption],
    );
    if (user != null) {
      final r = _nav!.process(LocationSample(coordinate: user, moment: _now()));
      phase = phase.copyWith(currentStep: r.step, progress: r.progress);
    }
    state = state.copyWith(phase: phase);
    _onStepChange();
    onStartTrip?.call(option);
  }

  @override
  void confirmCurrentStep() {
    final f = state.phase;
    if (f is! TripPhase || f.status != TripStatus.inProgress || _nav == null)
      return;
    final r = _nav!.confirmStep();
    var fresh = f.copyWith(
      currentStep: r.step,
      progress: r.progress,
      originAdvance: OriginAdvance.manual,
    );
    if (r.completed) {
      fresh = fresh.copyWith(status: TripStatus.completed, end: _now());
    }
    state = state.copyWith(phase: fresh);
    _onStepChange();
  }

  @override
  void finishTrip() {
    if (state.phase is! TripPhase) return;
    _stopTrip();
    state = state.copyWith(phase: const ExplorePhase());
  }

  @override
  void closeArrival() {
    final f = state.phase;
    if (f is! TripPhase) return;
    _stopTrip();
    state = state.copyWith(phase: const ExplorePhase(), search: const Search());
  }

  void _stopTrip() {
    _secTrip++;
    _timerTrip?.cancel();
    _timerTrip = null;
    _trackerTrip = null;
    _trackedWait = null;
    _nav = null;
    onFinishTrip?.call();
    // Where the user is right now (the demo sends them home): the next phase
    // doesn't wait for the next GPS reading to show it.
    unawaited(
      _location.current().then((m) {
        if (m != null) _onSample(m);
      }, onError: (_) {}),
    );
  }

  /// Reconfigures bus tracking for the current step.
  void _onStepChange() {
    final f = state.phase;
    if (f is! TripPhase) return;
    if (f.status == TripStatus.completed) {
      _timerTrip?.cancel();
      _timerTrip = null;
      _trackerTrip = null;
      _trackedWait = null;
      if (f.busExpected != null) {
        state = state.copyWith(phase: f.copyWith(cleanBusExpected: true));
      }
      (onArrive ?? onFinishTrip)?.call();
      return;
    }
    final wait = _waitToFollow(f);
    if (wait == _trackedWait) return;
    _trackedWait = wait;
    _timerTrip?.cancel();
    _timerTrip = null;
    _trackerTrip = null;
    final seq = ++_secTrip;
    // On the bus (or with no more buses) there is no bus to wait for: the bus
    // is the user. It's cleared right away so no data from another stage shows.
    final keep =
        wait != null &&
        f.busExpected != null &&
        f.busExpected!.line == (f.option.legs[wait] as WaitLeg).line;
    state = state.copyWith(
      phase: f.copyWith(cleanBusExpected: !keep, withoutLiveData: false),
    );
    if (wait == null) return;
    unawaited(() async {
      final bus = f.option.legs[wait + 1] as BusLeg;
      final v = _planned[f.option.id] ?? PlannedTrip(f.option);
      final route = await _route(v, bus);
      if (!mounted || seq != _secTrip) return;
      _trackerTrip = BusTracker(line: bus.line, route: route, clock: _now);
      await _pollTrip(seq);
      if (!mounted || seq != _secTrip) return;
      _timerTrip = Timer.periodic(config.pollBus, (_) => _pollTrip(seq));
    }());
  }

  /// Index of the next wait leg to follow, or null if already on the bus.
  int? _waitToFollow(TripPhase f) {
    for (var i = f.currentStep; i < f.option.legs.length; i++) {
      final t = f.option.legs[i];
      if (t is BusLeg) return null;
      if (t is WaitLeg) return i;
    }
    return null;
  }

  /// Waiting for the bus: if the user walks away from the stop (leaving with
  /// the bus), the bus is queried right away, without waiting for the next
  /// poll, so the bus and the user don't look separated.
  void _pollIfLeaving() {
    final f = state.phase;
    if (f is! TripPhase || f.status != TripStatus.inProgress) return;
    if (f.currentLeg is! WaitLeg) return;
    if ((f.progress.metersLeft ?? 0) < 10) return;
    final bus = f.busExpected;
    if (bus != null && bus.minutes == 0 && (bus.metersUntilStop ?? 0) <= 30) {
      return;
    }
    final last = _lastPollTrip;
    if (last != null && _now().difference(last) < const Duration(seconds: 5)) {
      return;
    }
    unawaited(_pollTrip(_secTrip));
  }

  DateTime? _lastPollTrip;

  Future<void> _pollTrip(int seq) async {
    _lastPollTrip = _now();
    final f0 = state.phase;
    final seg = _trackerTrip;
    final wait = _trackedWait;
    if (f0 is! TripPhase || seg == null || wait == null) return;
    final stop = (f0.option.legs[wait] as WaitLeg).stop;
    List<StopArrival>? list;
    try {
      list = await _arrivals.arrivals(stop.id);
    } catch (_) {
      list = null;
    }
    if (!mounted || seq != _secTrip) return;
    final f = state.phase;
    if (f is! TripPhase || f.status != TripStatus.inProgress) return;
    if (list == null) return; // network error: the last value is kept
    // Keeps the bus that arrived only if the user is waiting for it at the
    // stop; while walking toward it, one that already passed is of no use.
    final waiting = f.currentLeg is WaitLeg;
    final bus = seg.choose(
      list,
      retain: waiting,
      // While waiting, progress is the distance to the stop.
      userAtTheStop: waiting && (f.progress.metersLeft ?? 99) <= 15,
      user: f.user,
    );
    _traceChoice(list, bus);
    state = state.copyWith(
      phase: f.copyWith(
        busExpected: bus,
        cleanBusExpected: bus == null,
        withoutLiveData: bus == null || !bus.live,
      ),
    );
    _noticesOfProgress();
  }

  /// Milestones that deserve a notice (once per step only).
  void _noticesOfProgress() {
    final f = state.phase;
    if (f is! TripPhase || f.status != TripStatus.inProgress) return;
    final t = f.currentLeg;
    if (t is BusLeg &&
        f.progress.stopsLeft == 0 &&
        _noticesGiven.add('get-off-${t.id}')) {
      _postNotice(NoticeType.getOffAtNext);
    }
    final bus = f.busExpected;
    if (t is WaitLeg &&
        bus != null &&
        bus.live &&
        bus.minutes <= 1 &&
        _noticesGiven.add('arrives-${t.id}')) {
      _postNotice(NoticeType.busArriving);
    }
  }

  // =====================================================================
  // Stops
  // =====================================================================

  @override
  void queryStop(String idStop) {
    if (state.phase is! ExplorePhase) return;
    NetworkStop? networkStop;
    for (final p in state.stops) {
      if (p.stop.id == idStop) networkStop = p;
    }
    if (networkStop == null) return;
    final seq = ++_secStop;
    _timerStop?.cancel();
    state = state.copyWith(
      stopQueried: StopQuery(
        stop: networkStop.stop,
        lines: networkStop.lines,
        status: QueryStatus.loading,
      ),
    );
    final r = networkStop;
    Future<void> poll() async {
      try {
        final l = await _arrivals.arrivals(idStop);
        if (!mounted || seq != _secStop) return;
        final arrivals = [for (final x in l) x.data]
          ..sort((a, b) => a.minutes.compareTo(b.minutes));
        state = state.copyWith(
          stopQueried: StopQuery(
            stop: r.stop,
            lines: r.lines,
            status: QueryStatus.ready,
            arrivals: arrivals,
          ),
        );
      } catch (_) {
        if (!mounted || seq != _secStop) return;
        final previous = state.stopQueried;
        if (previous != null && previous.status == QueryStatus.ready) return;
        state = state.copyWith(
          stopQueried: StopQuery(
            stop: r.stop,
            lines: r.lines,
            status: QueryStatus.error,
          ),
        );
      }
    }

    unawaited(poll());
    _timerStop = Timer.periodic(config.pollStop, (_) => poll());
  }

  @override
  void closeStop() {
    _closeStopInternal();
    state = state.copyWith(cleanStopQueried: true);
  }

  void _closeStopInternal() {
    _secStop++;
    _timerStop?.cancel();
    _timerStop = null;
  }

  // =====================================================================
  // Notices
  // =====================================================================

  void _postNotice(NoticeType type) {
    if (!mounted) return;
    state = state.copyWith(notice: Notice(++_secNotice, type));
  }

  @override
  void dismissNotice(int idNotice) {
    if (state.notice?.id == idNotice) {
      state = state.copyWith(cleanNotice: true);
    }
  }

  // =====================================================================
  // Traces
  // =====================================================================

  String _summaryStep(NavigationStatus r) {
    if (r.completed) return 'arrived';
    final m = r.progress.metersLeft;
    return 'step ${r.step + 1}${m == null ? '' : ', $m m left'}';
  }

  void _traceChoice(List<StopArrival> list, BusInPath? bus) {
    final t = traces;
    if (t == null) return;
    t.emit(
      Piece.controller,
      Piece.tracker,
      'choose(${list.length} arrivals)',
      result:
          bus == null
              ? 'none coming'
              : '${bus.line} in ${bus.minutes} min'
                  '${bus.metersUntilStop == null ? '' : ', ${bus.metersUntilStop} m'}',
    );
  }

  @override
  void dispose() {
    _gps?.cancel();
    _debounce?.cancel();
    _timerOptions?.cancel();
    _timerTrip?.cancel();
    _timerStop?.cancel();
    super.dispose();
  }
}
