// State the logic layer hands to the UI. It is the ONLY input to the UI.
//
// The app lives in one of three phases (explore, options, trip). Each phase
// carries only what the UI needs to draw it; what is purely presentational
// (which card of the carousel is focused, whether the search box is open,
// what the camera frames) is NOT here: it is UI state.

import 'package:flutter/foundation.dart' show immutable;

import 'model.dart';

export 'model.dart';

@immutable
class AppState {
  final UserLocation location;
  final Search search;
  final Phase phase;

  /// Network of stops for the exploration map (loaded once).
  final List<NetworkStop> stops;

  /// Stop the user tapped on the map (only in the explore phase).
  final StopQuery? stopQueried;

  /// Transient notice. [Aviso.id] changes with each new notice.
  final Notice? notice;

  /// Only in demo mode (recorded trips and simulated world); null in real use.
  final Demo? demo;

  const AppState({
    required this.location,
    required this.search,
    required this.phase,
    this.stops = const [],
    this.stopQueried,
    this.notice,
    this.demo,
  });

  factory AppState.initial() => const AppState(
    location: UserLocation(status: LocationStatus.searching),
    search: Search(),
    phase: ExplorePhase(),
  );

  AppState copyWith({
    UserLocation? location,
    Search? search,
    Phase? phase,
    List<NetworkStop>? stops,
    StopQuery? stopQueried,
    bool cleanStopQueried = false,
    Notice? notice,
    bool cleanNotice = false,
    Demo? demo,
  }) {
    return AppState(
      location: location ?? this.location,
      search: search ?? this.search,
      phase: phase ?? this.phase,
      stops: stops ?? this.stops,
      stopQueried: cleanStopQueried ? null : (stopQueried ?? this.stopQueried),
      notice: cleanNotice ? null : (notice ?? this.notice),
      demo: demo ?? this.demo,
    );
  }
}

// ---------------------------------------------------------------------------
// Demo
// ---------------------------------------------------------------------------

/// Demo mode: the user and the buses move on their own around Montevideo, over
/// real recorded trips, at a speed that can be changed.
@immutable
class Demo {
  /// Destinations with a recorded trip: the ones that can be tried.
  final List<Place> destinations;

  const Demo({required this.destinations});
}

// ---------------------------------------------------------------------------
// Location
// ---------------------------------------------------------------------------

enum LocationStatus { searching, available, withoutPermission, disabled, error }

@immutable
class UserLocation {
  final LocationStatus status;
  final Coordinate? coordinate;

  const UserLocation({required this.status, this.coordinate});

  bool get available => coordinate != null;
}

// ---------------------------------------------------------------------------
// Search (origin / destination)
// ---------------------------------------------------------------------------

enum SearchField { origin, destination }

enum SuggestionsStatus { inactive, loading, ready, error }

/// One end of the trip: the user's location or a chosen place.
@immutable
sealed class SearchPoint {
  const SearchPoint();
}

class MyLocation extends SearchPoint {
  const MyLocation();

  @override
  bool operator ==(Object other) => other is MyLocation;

  @override
  int get hashCode => 1;
}

class ChosenPlace extends SearchPoint {
  final Place place;
  const ChosenPlace(this.place);

  @override
  bool operator ==(Object other) =>
      other is ChosenPlace && other.place == place;

  @override
  int get hashCode => place.hashCode;
}

@immutable
class Search {
  /// Defaults to "Mi ubicación" (My location).
  final SearchPoint origin;

  /// null = not chosen yet.
  final SearchPoint? destination;

  /// Field whose text is being queried right now.
  final SearchField? fieldQueried;
  final String query;
  final List<Place> suggestions;
  final SuggestionsStatus statusSuggestions;

  const Search({
    this.origin = const MyLocation(),
    this.destination,
    this.fieldQueried,
    this.query = '',
    this.suggestions = const [],
    this.statusSuggestions = SuggestionsStatus.inactive,
  });

  bool get complete => destination != null && origin != destination;

  SearchPoint? punto(SearchField field) =>
      field == SearchField.origin ? origin : destination;

  Search withPoint(SearchField field, SearchPoint? punto) => Search(
    origin:
        field == SearchField.origin ? (punto ?? const MyLocation()) : origin,
    destination: field == SearchField.destination ? punto : destination,
  );

  Search withQuery({
    required SearchField field,
    required String text,
    List<Place>? suggestions,
    required SuggestionsStatus status,
  }) => Search(
    origin: origin,
    destination: destination,
    fieldQueried: field,
    query: text,
    suggestions: suggestions ?? this.suggestions,
    statusSuggestions: status,
  );

  Search withoutQuery() => Search(origin: origin, destination: destination);
}

// ---------------------------------------------------------------------------
// Phases
// ---------------------------------------------------------------------------

@immutable
sealed class Phase {
  const Phase();
}

/// No trip: the user looks at the map and the stops, and can search.
class ExplorePhase extends Phase {
  const ExplorePhase();
}

enum OptionsStatus { loading, ready, withoutResults, error }

/// Trip options computed for origin -> destination.
class OptionsPhase extends Phase {
  final OptionsStatus status;

  /// Starting point actually used for planning.
  final Coordinate? origin;
  final Coordinate? destination;

  /// Sorted by the logic; exactly one is `recomendada` when there are any.
  final List<TripOption> options;

  /// Live bus on the first bus leg of each option that the UI asked to
  /// follow (see `AppActions.enfocarOpcion`). Key: option id.
  final Map<String, BusInPath> busesInVivo;

  const OptionsPhase({
    required this.status,
    this.origin,
    this.destination,
    this.options = const [],
    this.busesInVivo = const {},
  });

  OptionsPhase copyWith({
    OptionsStatus? status,
    List<TripOption>? options,
    Map<String, BusInPath>? busesInVivo,
  }) {
    return OptionsPhase(
      status: status ?? this.status,
      origin: origin,
      destination: destination,
      options: options ?? this.options,
      busesInVivo: busesInVivo ?? this.busesInVivo,
    );
  }
}

enum TripStatus { inProgress, completed }

/// How the advance to the current step was detected.
enum OriginAdvance { inicio, automatic, manual }

/// Active trip, guided step by step.
class TripPhase extends Phase {
  final TripOption option;

  /// Index in `opcion.tramos` of the step in progress (the logic detects it through GPS
  /// or manual confirmation).
  final int stepActual;
  final OriginAdvance originAdvance;
  final ProgressStep progress;
  final TripStatus status;

  /// Last known location of the user.
  final Coordinate? user;

  /// Live bus heading to the stop of the current waiting step, or of the
  /// next one. Always null while traveling on the bus: there the bus IS
  /// the user.
  final BusInPath? busExpected;

  /// true if the live source answered without a usable bus for the line.
  final bool withoutLiveData;

  final DateTime inicio;
  final DateTime? fin;

  const TripPhase({
    required this.option,
    required this.stepActual,
    required this.originAdvance,
    required this.progress,
    required this.status,
    required this.inicio,
    this.user,
    this.busExpected,
    this.withoutLiveData = false,
    this.fin,
  });

  Leg get legActual => option.legs[stepActual];
  int get totalSteps => option.legs.length;

  TripPhase copyWith({
    int? stepActual,
    OriginAdvance? originAdvance,
    ProgressStep? progress,
    TripStatus? status,
    Coordinate? user,
    BusInPath? busExpected,
    bool cleanBusExpected = false,
    bool? withoutLiveData,
    DateTime? fin,
  }) {
    return TripPhase(
      option: option,
      stepActual: stepActual ?? this.stepActual,
      originAdvance: originAdvance ?? this.originAdvance,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      inicio: inicio,
      user: user ?? this.user,
      busExpected: cleanBusExpected ? null : (busExpected ?? this.busExpected),
      withoutLiveData: withoutLiveData ?? this.withoutLiveData,
      fin: fin ?? this.fin,
    );
  }
}

/// Numeric progress of the step in progress. All fields are optional
/// because they depend on having a location.
@immutable
class ProgressStep {
  /// Walking / bus: meters still missing, from the geometry.
  final int? metersRestantes;

  /// Meters of the step when it started (to compute progress).
  final int? metersTotals;

  /// Walking: remaining route along the street, from the user.
  final List<Coordinate>? routeRemaining;

  /// Bus: stops remaining before the alighting one (0 = get off at the next one).
  final int? stopsRestantes;

  /// Bus: next stop the bus passes.
  final Stop? nextStop;

  const ProgressStep({
    this.metersRestantes,
    this.metersTotals,
    this.routeRemaining,
    this.stopsRestantes,
    this.nextStop,
  });

  static const empty = ProgressStep();

  /// 0..1, or null if it cannot be computed.
  double? get fraction {
    final total = metersTotals, rest = metersRestantes;
    if (total == null || rest == null || total <= 0) return null;
    return (1 - rest / total).clamp(0.0, 1.0);
  }
}

// ---------------------------------------------------------------------------
// Queried stop
// ---------------------------------------------------------------------------

enum QueryStatus { loading, ready, error }

@immutable
class StopQuery {
  final Stop stop;
  final List<String> lines;
  final QueryStatus status;
  final List<BusArrival> arrivals;

  const StopQuery({
    required this.stop,
    required this.lines,
    required this.status,
    this.arrivals = const [],
  });
}

// ---------------------------------------------------------------------------
// Notices
// ---------------------------------------------------------------------------

/// Notice types. The UI decides the text and icon.
enum NoticeType {
  withoutLocation,
  withoutConnection,
  errorPlanning,
  errorSuggestions,
  errorStop,
  missingDestination,
  getOffAtNext,
  busArriving,
}

@immutable
class Notice {
  final int id;
  final NoticeType type;
  const Notice(this.id, this.type);
}
