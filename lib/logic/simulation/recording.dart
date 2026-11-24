// Recorded sources: real captured responses (fixtures) to run the
// app and the tests without network.

import '../../contract/model.dart';
import '../ports.dart';
import '../services/otp.dart';

/// Always returns the recorded OTP plan, with the times shifted so that
/// the first itinerary departs ~[advance] after "now".
class RecordingPlanner implements TripPlanner {
  final Map<String, dynamic> planRaw;
  final Duration advance;

  RecordingPlanner(this.planRaw, {this.advance = const Duration(minutes: 1)});

  /// From a schemaVersion 2 fixture (`rawOtpPlan`).
  factory RecordingPlanner.fromFixture(Map<String, dynamic> fixture) =>
      RecordingPlanner(fixture['rawOtpPlan'] as Map<String, dynamic>);

  @override
  Future<List<PlannedTrip>> plan({
    required Coordinate origin,
    required Coordinate destination,
    required DateTime exit,
  }) async {
    final its =
        (planRaw['plan']['itineraries'] as List).cast<Map<String, dynamic>>();
    final first = its
        .map((i) => i['startTime'] as int)
        .reduce((a, b) => a < b ? a : b);
    final delta = exit.add(advance).millisecondsSinceEpoch - first;
    return interpretPlanOtp(_run(planRaw, delta) as Map<String, dynamic>);
  }

  static Object? _run(Object? json, int delta) {
    if (json is Map<String, dynamic>) {
      return {
        for (final e in json.entries)
          e.key:
              (e.key == 'startTime' || e.key == 'endTime') && e.value is int
                  ? (e.value as int) + delta
                  : _run(e.value, delta),
      };
    }
    if (json is List) return [for (final x in json) _run(x, delta)];
    return json;
  }
}

/// Known places in Montevideo for searches without network.
class FixedPlaces implements PlaceSearcher {
  final List<Place> places;
  const FixedPlaces(this.places);

  static const montevideo = FixedPlaces([
    Place(
      id: 'plaza-independencia',
      name: 'Plaza Independencia',
      detail: 'Ciudad Vieja, Montevideo',
      coordinate: Coordinate(-34.906971, -56.19946),
    ),
    Place(
      id: 'saldanha-3941',
      name: 'Saldanha da Gama 3941',
      detail: 'Malvín, Montevideo',
      coordinate: Coordinate(-34.902448, -56.12828),
    ),
    Place(
      id: 'tres-cruces',
      name: 'Terminal Tres Cruces',
      detail: 'Tres Cruces, Montevideo',
      coordinate: Coordinate(-34.8937, -56.1664),
    ),
    Place(
      id: 'estadio-centenario',
      name: 'Estadio Centenario',
      detail: 'Parque Batlle, Montevideo',
      coordinate: Coordinate(-34.8945, -56.1528),
    ),
    Place(
      id: 'mercado-puerto',
      name: 'Mercado del Puerto',
      detail: 'Ciudad Vieja, Montevideo',
      coordinate: Coordinate(-34.9064, -56.2126),
    ),
    Place(
      id: 'punta-carretas',
      name: 'Punta Carretas Shopping',
      detail: 'Punta Carretas, Montevideo',
      coordinate: Coordinate(-34.9237, -56.1590),
    ),
  ]);

  @override
  Future<List<Place>> suggestions(String text, {Coordinate? near}) async {
    final q = _normalize(text);
    if (q.isEmpty) return const [];
    return [
      for (final l in places)
        if (_normalize('${l.name} ${l.detail ?? ''}').contains(q)) l,
    ];
  }

  static String _normalize(String s) =>
      s
          .toLowerCase()
          .replaceAll(RegExp('[áà]'), 'a')
          .replaceAll(RegExp('[éè]'), 'e')
          .replaceAll(RegExp('[íì]'), 'i')
          .replaceAll(RegExp('[óò]'), 'o')
          .replaceAll(RegExp('[úùü]'), 'u')
          .trim();
}
