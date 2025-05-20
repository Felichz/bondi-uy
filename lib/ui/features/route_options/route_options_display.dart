import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bondi_uy/backend/providers/app_logic_provider.dart'; // Para llamar a acciones
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart'; // Para el tipo OpcionDeRutaMostrable

class RouteOptionsDisplay extends ConsumerWidget {
  final List<OpcionDeRutaMostrable> opciones;
  const RouteOptionsDisplay({super.key, required this.opciones});

  Widget _buildTramoIcon(TipoTramoViaje tipo) {
    switch (tipo) {
      case TipoTramoViaje.CAMINAR:
        return const Icon(Icons.directions_walk, size: 20);
      case TipoTramoViaje.VIAJE_EN_BUS:
        return const Icon(Icons.directions_bus, size: 20);
      case TipoTramoViaje.ESPERAR_BUS:
        return const Icon(Icons.schedule, size: 20);
      // No hay default porque el enum es exhaustivo
    }
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    if (duration.inHours > 0) {
      return "${hours}h ${minutes}m";
    } else {
      return "${minutes}m";
    }
  }

  Widget _buildTramosRow(
    BuildContext context,
    List<TramoViajeMostrable> tramos,
  ) {
    List<Widget> widgets = [];
    for (int i = 0; i < tramos.length; i++) {
      final tramo = tramos[i];
      widgets.add(_buildTramoIcon(tramo.tipo)); // Corregido: tramo.tipo
      if (tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS &&
          tramo.nombreLineaBus != null) {
        // Corregido: VIAJE_EN_BUS
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Text(
              tramo.nombreLineaBus!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        );
      }
      if (i < tramos.length - 1) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.0),
            child: Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
          ),
        );
      }
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: widgets,
    );
  }

  Widget _buildAdvertenciaChip(
    BuildContext context,
    TipoAdvertenciaItinerario? advertencia,
  ) {
    if (advertencia == null) return const SizedBox.shrink();

    String textoAdvertencia;
    IconData iconoAdvertencia;
    Color colorAdvertencia;

    switch (advertencia) {
      case TipoAdvertenciaItinerario.TIEMPO_CAMINATA_EXCESIVO:
        textoAdvertencia = 'Caminata Larga';
        iconoAdvertencia = Icons.warning_amber_outlined;
        colorAdvertencia = Colors.orange.shade300;
        break;
      case TipoAdvertenciaItinerario.TRANSBORDO_AJUSTADO:
        textoAdvertencia = 'Transbordo Ajustado';
        iconoAdvertencia = Icons.timelapse;
        colorAdvertencia = Colors.blue.shade300;
        break;
      case TipoAdvertenciaItinerario.ETA_NO_DISPONIBLE_PARA_PRIMER_BUS:
        textoAdvertencia = 'ETA Bus No Disponible';
        iconoAdvertencia = Icons.bus_alert_outlined; // Un icono más específico
        colorAdvertencia = Colors.red.shade200;
        break;
      case TipoAdvertenciaItinerario.ETA_NO_ES_TIEMPO_REAL_PARA_PRIMER_BUS:
        textoAdvertencia = 'ETA Bus Estimada';
        iconoAdvertencia = Icons.departure_board_outlined;
        colorAdvertencia = Colors.amber.shade300;
        break;
      // Añadir más casos según necesidad o un default
      default:
        textoAdvertencia = 'Advertencia General'; // Texto genérico
        iconoAdvertencia = Icons.info_outline;
        colorAdvertencia = Colors.grey.shade400;
    }

    return Chip(
      avatar: Icon(iconoAdvertencia, size: 16, color: Colors.black54),
      label: Text(
        textoAdvertencia,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Colors.black54),
      ),
      backgroundColor: colorAdvertencia,
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 0),
      labelPadding: const EdgeInsets.only(left: 4.0, right: 6.0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logic = ref.read(appLogicProvider.notifier);

    if (opciones.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No se encontraron rutas o hubo un error al procesarlas.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Material(
      elevation: 4.0,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.45,
        ),
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 10.0,
                horizontal: 8.0,
              ),
              child: Text(
                'Opciones de Ruta Encontradas (${opciones.length})',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: opciones.length,
                itemBuilder: (context, index) {
                  final opcion = opciones[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 6.0,
                      horizontal: 4.0,
                    ),
                    elevation: 2.0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      side:
                          opcion.esRecomendada
                              ? BorderSide(
                                color: Theme.of(context).primaryColorLight,
                                width: 2,
                              )
                              : BorderSide.none,
                    ),
                    child: InkWell(
                      onTap: () {
                        logic.confirmarOpcionDeRutaEIniciarViaje(
                          opcion.idOpcion,
                        );
                      },
                      borderRadius: BorderRadius.circular(10.0),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Opción ${index + 1}: ${_formatDuration(opcion.duracionTotalSegundos)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Corregido: Usar costoEstimadoViaje y moneda en lugar de precioViaje
                                if (opcion.costoEstimadoViaje != null)
                                  Text(
                                    '\$${opcion.costoEstimadoViaje?.toStringAsFixed(opcion.costoEstimadoViaje! % 1 == 0 ? 0 : 2)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium?.copyWith(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: Colors.black54,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Llegada: ${opcion.horaLlegadaEstimada.hour}:${opcion.horaLlegadaEstimada.minute.toString().padLeft(2, '0')}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                if (opcion.etaProximoBus != null) ...[
                                  const SizedBox(width: 8),
                                  const Text('|'),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.departure_board,
                                    size: 16,
                                    color: Colors.blueAccent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Bus: ${opcion.etaProximoBus!.minutosParaLlegada} min ${opcion.etaProximoBus!.esTiempoReal ? "(Ahora)" : ""}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: Colors.blueAccent),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildTramosRow(context, opcion.tramosParaPreview),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8.0,
                              runSpacing: 4.0,
                              children: [
                                if (opcion.esRecomendada)
                                  Chip(
                                    avatar: Icon(
                                      Icons.star,
                                      size: 16,
                                      color: Colors.orange.shade800,
                                    ),
                                    label: Text(
                                      'Recomendada',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.copyWith(
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                    backgroundColor: Colors.orange.shade100,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6.0,
                                      vertical: 0,
                                    ),
                                    labelPadding: const EdgeInsets.only(
                                      left: 4.0,
                                      right: 6.0,
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                _buildAdvertenciaChip(
                                  context,
                                  opcion.advertenciaPrincipal,
                                ),
                                Chip(
                                  avatar: const Icon(
                                    Icons.directions_walk,
                                    size: 16,
                                  ),
                                  label: Text(
                                    'Caminata: ${opcion.distanciaTotalCaminataMetros}m',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  backgroundColor: Colors.grey.shade200,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6.0,
                                    vertical: 0,
                                  ),
                                  labelPadding: const EdgeInsets.only(
                                    left: 4.0,
                                    right: 6.0,
                                  ),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                if (opcion.tiempoTotalEsperaBusSegundos > 0)
                                  Chip(
                                    avatar: const Icon(
                                      Icons.schedule_outlined,
                                      size: 16,
                                    ),
                                    label: Text(
                                      'Espera: ${_formatDuration(opcion.tiempoTotalEsperaBusSegundos)}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    backgroundColor: Colors.grey.shade200,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6.0,
                                      vertical: 0,
                                    ),
                                    labelPadding: const EdgeInsets.only(
                                      left: 4.0,
                                      right: 6.0,
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
