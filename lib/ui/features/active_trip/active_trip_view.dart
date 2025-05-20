import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bondi_uy/backend/providers/app_logic_provider.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';

class ActiveTripView extends ConsumerWidget {
  const ActiveTripView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appLogicProvider);
    final logic = ref.read(appLogicProvider.notifier);

    final viajeActivo = appState.datosFaseViajeActivo;

    if (viajeActivo == null) {
      // Esto no debería pasar si estamos en esta fase, pero es buena práctica.
      return Scaffold(
        appBar: AppBar(title: const Text('Viaje Activo')),
        body: const Center(child: Text('Error: No hay datos de viaje activo.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Viaje en Curso'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            logic
                .usuarioCanceloBusquedaOSeleccionRuta(); // O una acción específica para cancelar viaje
          },
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'ID Viaje: ${viajeActivo.idViajeActivoConfirmado}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          if (viajeActivo.idTramoBusEnSeguimiento != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
              child: Column(
                children: [
                  Text(
                    'Siguiendo bus del tramo: ${viajeActivo.idTramoBusEnSeguimiento}',
                  ),
                  if (viajeActivo.seguimientoBusRealDisponibleEnTramoActual)
                    Text(
                      'Bus llega en: ${viajeActivo.minutosParaLlegadaBusReal ?? "?"} min',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    const Text(
                      'Seguimiento en tiempo real no disponible para este tramo.',
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
                // TODO: Mejorar la presentación de cada tramo
                return ListTile(
                  leading: Icon(
                    tramo.tipo == TipoTramoViaje.CAMINAR
                        ? Icons.directions_walk
                        : tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS
                        ? Icons.directions_bus
                        : Icons.access_time,
                  ),
                  title: Text(tramo.descripcion),
                  subtitle: Text(
                    'Duración: ${tramo.duracionEstimadaSegundos ~/ 60} min\n'
                    'Distancia: ${tramo.distanciaMetros} m',
                  ),
                  isThreeLine: true,
                  onTap: () {
                    logic.usuarioSeleccionoTramoDelViaje(
                      viajeActivo.idViajeActivoConfirmado,
                      tramo.idTramo,
                    );
                  },
                  selected:
                      viajeActivo.idTramoBusEnSeguimiento == tramo.idTramo &&
                      tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
