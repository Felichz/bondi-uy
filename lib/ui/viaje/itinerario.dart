// "Ver todo el viaje": la lista completa de pasos, con lo hecho, lo actual y
// lo que falta. Para quien quiere anticiparse (¿dónde me bajo?, ¿cuánto
// camino al final?) sin perder la tarjeta del paso actual.

import 'package:flutter/material.dart';

import '../../contract/app_state.dart';
import '../comunes.dart';
import '../formatos.dart';
import '../tema/tema.dart';
import '../tema/lamina.dart';
import '../textos/textos.dart';

Future<void> mostrarItinerario(
  BuildContext context,
  FaseViaje f,
  String destino,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black.withValues(alpha: 0.25),
  builder: (context) => _Itinerario(f, destino),
);

class _Itinerario extends StatelessWidget {
  final FaseViaje f;
  final String destino;
  const _Itinerario(this.f, this.destino);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final alto = MediaQuery.sizeOf(context).height;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: ConstrainedBox(
        key: const ValueKey('itinerario'),
        constraints: BoxConstraints(maxHeight: alto * 0.78),
        child: Lamina(
          padding: EdgeInsets.zero,
          radio: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Asa(),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tx.tuViaje, style: t.titleLarge),
                          Text(
                            tx.aDestinoLlegas(destino, hora(f.opcion.llegada)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('itinerario-cerrar'),
                      tooltip: tx.cerrar,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  children: [
                    for (var i = 0; i < f.totalPasos; i++)
                      _Fila(
                        f.opcion.tramos[i],
                        estado:
                            i < f.pasoActual
                                ? _Estado.hecho
                                : i == f.pasoActual
                                ? _Estado.actual
                                : _Estado.pendiente,
                        ultimo: i == f.totalPasos - 1,
                        destino: destino,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Estado { hecho, actual, pendiente }

class _Fila extends StatelessWidget {
  final Tramo tramo;
  final _Estado estado;
  final bool ultimo;
  final String destino;
  const _Fila(
    this.tramo, {
    required this.estado,
    required this.ultimo,
    required this.destino,
  });

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    final (color, icono, titulo, detalle) = switch (tramo) {
      TramoCaminar(
        :final distanciaMetros,
        :final duracionSegundos,
        :final haciaParada,
      ) =>
        (
          c.caminar,
          Icons.directions_walk_rounded,
          tx.camina(distancia(distanciaMetros)),
          '${haciaParada == null ? tx.hastaDestino(destino) : tx.hastaLaParada(nombreParada(haciaParada.nombre))} · ${duracion(duracionSegundos)}',
        ),
      TramoEsperar(:final linea, :final parada, :final destinoLinea) => (
        c.enVivo,
        Icons.hail_rounded,
        tx.espera(linea),
        [
          tx.parada(nombreParada(parada.nombre)),
          if (destinoLinea != null) tx.hacia(capitalizar(destinoLinea)),
        ].join(' · '),
      ),
      TramoBus(
        :final linea,
        :final bajada,
        :final paradasIntermedias,
        :final duracionSegundos,
      ) =>
        (
          c.bus,
          Icons.directions_bus_rounded,
          tx.viajaEn(linea),
          tx.bajateEnResumen(
            nombreParada(bajada.nombre),
            paradas(paradasIntermedias.length + 1),
            duracion(duracionSegundos),
          ),
        ),
    };
    final hecho = estado == _Estado.hecho;
    final actual = estado == _Estado.actual;
    final tono = hecho ? c.textoTenue : color;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: actual ? tono : tono.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hecho ? Icons.check_rounded : icono,
                    size: 20,
                    color: actual ? Colors.white : tono,
                  ),
                ),
                if (!ultimo)
                  Expanded(
                    child: Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            hecho
                                ? c.textoTenue.withValues(alpha: 0.4)
                                : tono.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 6, bottom: ultimo ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          titulo,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight:
                                actual ? FontWeight.w700 : FontWeight.w600,
                            color: hecho ? c.textoTenue : c.texto,
                            decoration:
                                hecho ? TextDecoration.lineThrough : null,
                            decorationColor: c.textoTenue,
                          ),
                        ),
                      ),
                      if (actual) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: c.texto,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tx.ahoraMayus,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: c.laminaSolida,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detalle,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.3,
                      color: hecho ? c.textoTenue : c.textoSuave,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
