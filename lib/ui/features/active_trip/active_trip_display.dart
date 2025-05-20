import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bondi_uy/backend/providers/app_logic_provider.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';

class ActiveTripDisplay extends ConsumerWidget {
  final EstadoFaseViajeActivo viajeActivo;
  const ActiveTripDisplay({super.key, required this.viajeActivo});

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return "${hours}h ${minutes}m";
    } else if (duration.inMinutes > 0) {
      return "${minutes}m ${seconds}s";
    } else {
      return "${seconds}s";
    }
  }

  Widget _buildTramoTitle(BuildContext context, TramoViajeMostrable tramo) {
    switch (tramo.tipo) {
      case TipoTramoViaje.CAMINAR:
        return Text(
          "Caminar hacia ${tramo.nombreParadaDestino ?? tramo.descripcion}",
        );
      case TipoTramoViaje.ESPERAR_BUS:
        return Text(
          "Esperar en ${tramo.nombreParadaOrigen ?? tramo.descripcion}",
        );
      case TipoTramoViaje.VIAJE_EN_BUS:
        return Text(
          "Bus ${tramo.nombreLineaBus ?? ''} hacia ${tramo.destinoFinalDelBus ?? tramo.nombreParadaDestino ?? 'Destino'}",
        );
      default:
        return Text(tramo.descripcion);
    }
  }

  List<Widget> _buildTramoSubtitleWidgets(
    BuildContext context,
    TramoViajeMostrable tramo,
    EstadoFaseViajeActivo viajeActivoData,
  ) {
    List<Widget> widgets = [];

    widgets.add(
      Text("Duración: ${_formatDuration(tramo.duracionEstimadaSegundos)}"),
    );

    if (tramo.tipo == TipoTramoViaje.CAMINAR && tramo.distanciaMetros > 0) {
      widgets.add(Text("Distancia: ${tramo.distanciaMetros} m"));
    }

    if (tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS) {
      if (tramo.nombreParadaOrigen != null) {
        widgets.add(Text("Desde: ${tramo.nombreParadaOrigen}"));
      }
      if (tramo.nombreParadaDestino != null) {
        widgets.add(Text("Hasta: ${tramo.nombreParadaDestino}"));
      }
      // Mostrar info de seguimiento en tiempo real si este es el tramo activo
      if (viajeActivoData.idTramoBusEnSeguimiento == tramo.idTramo &&
          viajeActivoData.seguimientoBusRealDisponibleEnTramoActual) {
        widgets.add(
          Text(
            "Llega en: ${viajeActivoData.minutosParaLlegadaBusReal ?? '?'} min (En vivo)",
            style: TextStyle(
              color: Colors.green[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        if (viajeActivoData.posicionActualBusReal != null) {
          widgets.add(
            Text(
              "Posición: ${viajeActivoData.posicionActualBusReal!.latitud.toStringAsFixed(4)}, ${viajeActivoData.posicionActualBusReal!.longitud.toStringAsFixed(4)}",
              style: TextStyle(color: Colors.green[700]),
            ),
          );
        }
      } else if (viajeActivoData.idTramoBusEnSeguimiento == tramo.idTramo &&
          !viajeActivoData.seguimientoBusRealDisponibleEnTramoActual &&
          viajeActivoData.minutosParaLlegadaBusReal == null) {
        widgets.add(
          Text(
            "Seguimiento en tiempo real no disponible",
            style: TextStyle(color: Colors.orange[700]),
          ),
        );
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logic = ref.read(appLogicProvider.notifier);

    return Material(
      elevation: 4.0,
      child: Container(
        height:
            MediaQuery.of(context).size.height *
            0.45, // Un poco más alto para detalles del viaje
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Detalles de tu Viaje',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  // El botón de cerrar/cancelar ahora está en la AppBar de HomeScreen
                ],
              ),
            ),
            if (viajeActivo.idTramoBusEnSeguimiento != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Siguiendo bus del tramo: ${viajeActivo.idTramoBusEnSeguimiento}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (viajeActivo.seguimientoBusRealDisponibleEnTramoActual)
                      Text(
                        'Llega en: ${viajeActivo.minutosParaLlegadaBusReal ?? "?"} min',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      const Text(
                        'Seguimiento en tiempo real no disponible.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    if (viajeActivo.posicionActualBusReal != null)
                      Text(
                        'Posición Bus: ${viajeActivo.posicionActualBusReal!.latitud.toStringAsFixed(4)}, ${viajeActivo.posicionActualBusReal!.longitud.toStringAsFixed(4)}',
                      ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: viajeActivo.tramosDelViaje.length,
                itemBuilder: (context, index) {
                  final tramo = viajeActivo.tramosDelViaje[index];
                  bool isSelectedTramo =
                      viajeActivo.idTramoBusEnSeguimiento == tramo.idTramo &&
                      tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS;

                  IconData tramoIcon;
                  switch (tramo.tipo) {
                    case TipoTramoViaje.CAMINAR:
                      tramoIcon = Icons.directions_walk;
                      break;
                    case TipoTramoViaje.VIAJE_EN_BUS:
                      tramoIcon = Icons.directions_bus;
                      break;
                    case TipoTramoViaje.ESPERAR_BUS:
                      tramoIcon = Icons.schedule;
                      break;
                    default:
                      tramoIcon =
                          Icons
                              .error_outline; // Icono por defecto o para errores
                  }

                  return Card(
                    color:
                        isSelectedTramo
                            ? Colors.blue[50]
                            : Theme.of(context).cardColor,
                    margin: const EdgeInsets.symmetric(
                      vertical: 6.0,
                      horizontal: 4.0,
                    ),
                    elevation: isSelectedTramo ? 4.0 : 2.0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      side:
                          isSelectedTramo
                              ? BorderSide(
                                color: Theme.of(context).primaryColor,
                                width: 1.5,
                              )
                              : BorderSide.none,
                    ),
                    child: ListTile(
                      leading: Icon(
                        tramoIcon,
                        color:
                            isSelectedTramo
                                ? Theme.of(context).primaryColor
                                : Theme.of(context).iconTheme.color,
                        size: 30,
                      ),
                      title: _buildTramoTitle(context, tramo),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildTramoSubtitleWidgets(
                          context,
                          tramo,
                          viajeActivo,
                        ),
                      ),
                      onTap: () {
                        logic.usuarioSeleccionoTramoDelViaje(
                          viajeActivo.idViajeActivoConfirmado,
                          tramo.idTramo,
                        );
                      },
                      selected: isSelectedTramo,
                      selectedTileColor: Colors.blue[50]?.withOpacity(
                        0.5,
                      ), // sutil efecto al seleccionar
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
