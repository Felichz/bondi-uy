// Formateo de datos crudos del contrato a texto, en el idioma actual.
//
// Entre número y unidad va un espacio no separable: "580 m" nunca se parte
// en dos renglones.

import 'textos/textos.dart';

const _nb = '\u00A0';

String duracion(int segundos) {
  final min = (segundos / 60).round();
  if (min < 1) return tx.menosDeUnMin;
  if (min < 60) return '$min${_nb}min';
  final h = min ~/ 60, m = min % 60;
  return m == 0 ? '$h${_nb}h' : '$h${_nb}h $m${_nb}min';
}

/// "1 min", "12 min" para ETAs (sin horas).
String minutos(int m) => m <= 0 ? tx.ya : '$m${_nb}min';

String distancia(int metros) {
  if (metros < 1000) {
    // Redondeo a 10 m: la precisión de GPS no da para más.
    final m = metros < 20 ? metros : (metros / 10).round() * 10;
    return '$m${_nb}m';
  }
  final km = metros / 1000;
  final texto = km < 10 ? km.toStringAsFixed(1) : km.round().toString();
  final decimal = tx.idioma == Idioma.es ? texto.replaceAll('.', ',') : texto;
  return '$decimal${_nb}km';
}

/// Hora de Montevideo (UTC-3, sin horario de verano), sea cual sea la zona
/// del teléfono: los horarios de los buses son locales.
String hora(DateTime t) {
  final m = t.toUtc().subtract(const Duration(hours: 3));
  return '${m.hour.toString().padLeft(2, '0')}:${m.minute.toString().padLeft(2, '0')}';
}

/// Minutos caminando a 4,5 km/h (ritmo tranquilo).
int segundosCaminando(int metros) => (metros / 1.25).round();

String paradas(int n) => tx.paradas(n);

/// "Av 18 de Julio y Andes" -> "18 de Julio y Andes" es tentador, pero se
/// respeta el nombre oficial; solo se normalizan espacios.
String nombreParada(String nombre) =>
    nombre.replaceAll(RegExp(r'\s+'), ' ').trim();
