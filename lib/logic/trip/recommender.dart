// Sorts, cleans up and picks the recommended option.
//
// "grandma test" criterion: what matters most is what time you arrive; after
// that, avoid transfers and long walks. OTP usually returns the same
// combination of lines at several times: the one that arrives earlier is kept.

import '../../contract/model.dart';
import '../ports.dart';

class RecommendationWeights {
  /// Equivalent minutes of penalty for each transfer.
  final double byTransfer;

  /// Meters of "free" walking before penalizing.
  final double walkFree;

  /// Penalty minutes for each extra 100 m of walking.
  final double byHundredMeters;

  const RecommendationWeights({
    this.byTransfer = 7,
    this.walkFree = 500,
    this.byHundredMeters = 1.5,
  });
}

/// Cost of an option in "perceived minutes".
double costOption(
  TripOption o,
  DateTime now, [
  RecommendationWeights p = const RecommendationWeights(),
]) {
  final minutesUntilArrive = o.arrival.difference(now).inSeconds / 60.0;
  final extraWalk =
      (o.walkMeters - p.walkFree).clamp(0, double.infinity) / 100.0;
  return minutesUntilArrive +
      o.transfers * p.byTransfer +
      extraWalk * p.byHundredMeters;
}

List<PlannedTrip> sortAndRecommend(
  List<PlannedTrip> trips,
  DateTime now, {
  int max = 6,
  RecommendationWeights weights = const RecommendationWeights(),
}) {
  // 1) Deduplicate by sequence of lines + stops.
  final bySignature = <String, PlannedTrip>{};
  for (final v in trips) {
    final signature = _signature(v.option);
    final previous = bySignature[signature];
    if (previous == null ||
        v.option.arrival.isBefore(previous.option.arrival)) {
      bySignature[signature] = v;
    }
  }
  // 2) Sort by cost.
  final list =
      bySignature.values.toList()..sort(
        (a, b) => costOption(
          a.option,
          now,
          weights,
        ).compareTo(costOption(b.option, now, weights)),
      );
  final top = list.take(max).toList();
  // 3) Exactly one recommended: the first one.
  return [
    for (var i = 0; i < top.length; i++)
      PlannedTrip(
        top[i].option.withRecommended(i == 0),
        shapeByLeg: top[i].shapeByLeg,
      ),
  ];
}

String _signature(TripOption o) {
  final buses = [
    for (final t in o.legs)
      if (t is BusLeg) '${t.line}@${t.boarding.id}>${t.alighting.id}',
  ];
  return buses.isEmpty ? 'walk' : buses.join('|');
}

/// Main warning for an option, if applicable.
NoticeOption? noticeOfOption(TripOption o, {BusArrival? next}) {
  final firstWalk = o.legs.first is WalkLeg ? o.legs.first as WalkLeg : null;
  if (next != null && firstWalk != null) {
    final minutesWalking = firstWalk.durationSeconds / 60.0;
    if (next.minutes < minutesWalking - 0.5) {
      return NoticeOption.firstBusMayNotReach;
    }
  }
  if (o.walkMeters > 1500) return NoticeOption.longWalk;
  // Transfer waits (not the first one) of less than one minute.
  final waits = o.legs.whereType<WaitLeg>().skip(1);
  if (waits.any((e) => e.waitScheduledSeconds < 60)) {
    return NoticeOption.transferAdjusted;
  }
  return null;
}
