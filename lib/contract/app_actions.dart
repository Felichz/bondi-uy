// Actions the UI can ask the logic to perform. This is the ONLY output of the UI.
//
// Each action expresses a user intent, not an implementation detail. The
// logic decides how to fulfill it and responds by changing the AppState.

import 'app_state.dart';

abstract interface class AppActions {
  // --- Startup and location ---

  /// The UI is ready (map mounted). Requests location and loads the stop network.
  void start();

  /// Retries getting the location (e.g. after the permission is granted).
  void retryLocation();

  // --- Search ---

  /// The user typed in a field. Triggers suggestions (with debounce).
  void writeQuery(SearchField field, String text);

  void choosePlace(SearchField field, Place place);

  /// Uses "Mi ubicación" (My location) in the field.
  void useMyLocation(SearchField field);

  /// Clears the field (the origin goes back to "Mi ubicación" (My location)).
  void cleanField(SearchField field);

  void swapOriginAndDestination();

  /// Closes the suggestions dropdown without choosing.
  void cancelQuery();

  /// Plans origin -> destination and moves to the options phase.
  void searchTrips();

  // --- Options ---

  /// The UI is showing this option: follow its first bus live.
  void focusOption(String idOption);

  /// Goes back to exploring, keeping origin and destination.
  void closeOptions();

  void startTrip(String idOption);

  // --- Active trip ---

  /// Manual fallback: the user confirms they completed the current step
  /// (the UI labels, in Spanish: "Ya llegué a la parada", "Ya subí", "Ya me bajé", "Ya llegué").
  void confirmCurrentStep();

  /// Abandons the trip in progress.
  void finishTrip();

  /// Closes the arrival confirmation and goes back to exploring.
  void closeArrival();

  // --- Stops ---

  void queryStop(String idStop);
  void closeStop();

  // --- Notices ---
  void dismissNotice(int idNotice);
}
