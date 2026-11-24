// Traces: the calls between the app's pieces, as they happen.
//
// The demo's web "under the hood" view uses them to show how the app works
// inside. The logic emits them at its seams (the actions it receives from the
// UI, the ports to the outside world, the core pieces), and the UI only reads
// them, the same way it reads the state. With nobody listening they cost nothing.

import 'dart:async';

/// The app's pieces between which calls travel.
enum Piece {
  /// The UI: the phone.
  interfaceValue,

  /// The core: implements the actions and publishes the state.
  controller,

  /// Detects the trip's progress with each GPS reading.
  navigator,

  /// Picks the incoming bus and its route to the stop.
  tracker,

  /// Sorts the options and picks the recommended one.
  recommender,

  // Ports to the outside world.
  planner,
  arrivals,
  location,
  catalog,
  places,
}

/// A call from [from] to [toward] (or its response, if [result]).
class Trace {
  final Piece from;
  final Piece toward;

  /// The call as it appears in the code: `llegadas("5296")`.
  final String call;

  /// What it returned, in a few words (null if not yet or not applicable).
  final String? result;
  final DateTime moment;

  const Trace(
    this.from,
    this.toward,
    this.call, {
    this.result,
    required this.moment,
  });
}

class Traces {
  final _exit = StreamController<Trace>.broadcast();

  Stream<Trace> get stream => _exit.stream;

  void emit(Piece from, Piece toward, String call, {String? result}) {
    if (!_exit.hasListener) return;
    _exit.add(
      Trace(from, toward, call, result: result, moment: DateTime.now()),
    );
  }

  void close() => _exit.close();
}
