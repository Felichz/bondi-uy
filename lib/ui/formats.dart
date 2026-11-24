// Formats raw contract data as text, in the current language.
//
// A non-breaking space goes between a number and its unit: "580 m" never
// breaks across two lines.

import 'texts/texts.dart';

const _nb = '\u00A0';

String duration(int seconds) {
  final min = (seconds / 60).round();
  if (min < 1) return tx.underOneMin;
  if (min < 60) return '$min${_nb}min';
  final h = min ~/ 60, m = min % 60;
  return m == 0 ? '$h${_nb}h' : '$h${_nb}h $m${_nb}min';
}

/// "1 min", "12 min" for ETAs (no hours).
String minutes(int m) => m <= 0 ? tx.ya : '$m${_nb}min';

String distance(int meters) {
  if (meters < 1000) {
    // Rounded to 10 m: GPS precision does not support more.
    final m = meters < 20 ? meters : (meters / 10).round() * 10;
    return '$m${_nb}m';
  }
  final km = meters / 1000;
  final text = km < 10 ? km.toStringAsFixed(1) : km.round().toString();
  final decimal = tx.language == Language.es ? text.replaceAll('.', ',') : text;
  return '$decimal${_nb}km';
}

/// Montevideo time (UTC-3, no daylight saving), whatever the phone's
/// time zone: bus schedules are local.
String time(DateTime t) {
  final m = t.toUtc().subtract(const Duration(hours: 3));
  return '${m.hour.toString().padLeft(2, '0')}:${m.minute.toString().padLeft(2, '0')}';
}

/// Minutes walking at 4.5 km/h (a relaxed pace).
int secondsWalking(int meters) => (meters / 1.25).round();

String stops(int n) => tx.stops(n);

/// "Av 18 de Julio y Andes" -> "18 de Julio y Andes" is tempting, but the
/// official name is kept; only whitespace gets normalized.
String stopName(String name) => name.replaceAll(RegExp(r'\s+'), ' ').trim();
