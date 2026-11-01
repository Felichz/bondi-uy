// Ordena, depura y elige la opción recomendada.
//
// Criterio "abuelita first": lo que más importa es a qué hora llegás; después
// evitar trasbordos y caminatas largas. OTP suele devolver la misma
// combinación de líneas en varios horarios: se conserva la que llega antes.

import '../../contract/modelo.dart';
import '../puertos.dart';

class PesosRecomendacion {
  /// Minutos equivalentes de penalización por cada trasbordo.
  final double porTrasbordo;

  /// Metros de caminata "gratis" antes de penalizar.
  final double caminataLibre;

  /// Minutos de penalización por cada 100 m extra de caminata.
  final double porCienMetros;

  const PesosRecomendacion({
    this.porTrasbordo = 7,
    this.caminataLibre = 500,
    this.porCienMetros = 1.5,
  });
}

/// Costo en "minutos percibidos" de una opción.
double costoOpcion(
  OpcionViaje o,
  DateTime ahora, [
  PesosRecomendacion p = const PesosRecomendacion(),
]) {
  final minutosHastaLlegar = o.llegada.difference(ahora).inSeconds / 60.0;
  final extraCaminata =
      (o.caminataMetros - p.caminataLibre).clamp(0, double.infinity) / 100.0;
  return minutosHastaLlegar +
      o.transbordos * p.porTrasbordo +
      extraCaminata * p.porCienMetros;
}

List<ViajePlanificado> ordenarYRecomendar(
  List<ViajePlanificado> viajes,
  DateTime ahora, {
  int maximo = 6,
  PesosRecomendacion pesos = const PesosRecomendacion(),
}) {
  // 1) Deduplicar por secuencia de líneas + paradas.
  final porFirma = <String, ViajePlanificado>{};
  for (final v in viajes) {
    final firma = _firma(v.opcion);
    final previo = porFirma[firma];
    if (previo == null || v.opcion.llegada.isBefore(previo.opcion.llegada)) {
      porFirma[firma] = v;
    }
  }
  // 2) Ordenar por costo.
  final lista =
      porFirma.values.toList()..sort(
        (a, b) => costoOpcion(
          a.opcion,
          ahora,
          pesos,
        ).compareTo(costoOpcion(b.opcion, ahora, pesos)),
      );
  final top = lista.take(maximo).toList();
  // 3) Exactamente una recomendada: la primera.
  return [
    for (var i = 0; i < top.length; i++)
      ViajePlanificado(
        top[i].opcion.conRecomendada(i == 0),
        shapePorTramo: top[i].shapePorTramo,
      ),
  ];
}

String _firma(OpcionViaje o) {
  final buses = [
    for (final t in o.tramos)
      if (t is TramoBus) '${t.linea}@${t.subida.id}>${t.bajada.id}',
  ];
  return buses.isEmpty ? 'caminata' : buses.join('|');
}

/// Advertencia principal de una opción, si corresponde.
AvisoOpcion? avisoDeOpcion(OpcionViaje o, {LlegadaBus? proximo}) {
  final primerCaminar =
      o.tramos.first is TramoCaminar ? o.tramos.first as TramoCaminar : null;
  if (proximo != null && primerCaminar != null) {
    final minutosCaminando = primerCaminar.duracionSegundos / 60.0;
    if (proximo.minutos < minutosCaminando - 0.5) {
      return AvisoOpcion.primerBusPuedeNoAlcanzar;
    }
  }
  if (o.caminataMetros > 1500) return AvisoOpcion.caminataLarga;
  // Esperas de trasbordo (no la primera) de menos de un minuto.
  final esperas = o.tramos.whereType<TramoEsperar>().skip(1);
  if (esperas.any((e) => e.esperaProgramadaSegundos < 60)) {
    return AvisoOpcion.transbordoAjustado;
  }
  return null;
}
