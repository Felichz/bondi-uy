import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bondi_uy/backend/providers/app_logic_provider.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';

class RouteOptionsView extends ConsumerWidget {
  const RouteOptionsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appLogicProvider);
    final logic = ref.read(appLogicProvider.notifier);

    final opciones = appState.datosFaseOpcionesRuta?.opcionesDeRuta ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Opciones de Ruta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            logic.usuarioCanceloBusquedaOSeleccionRuta();
          },
        ),
      ),
      body:
          opciones.isEmpty
              ? const Center(
                child: Text('No se encontraron rutas o hubo un error.'),
              )
              : ListView.builder(
                itemCount: opciones.length,
                itemBuilder: (context, index) {
                  final opcion = opciones[index];
                  // TODO: Formatear la duración y la hora de llegada adecuadamente
                  // TODO: Mostrar los íconos de secuencia de modos
                  // TODO: Mostrar advertencia principal
                  return ListTile(
                    title: Text(
                      'Opción ${index + 1}: ${opcion.duracionTotalSegundos ~/ 60} min',
                    ),
                    subtitle: Text(
                      'Llegada: ${opcion.horaLlegadaEstimada.hour}:${opcion.horaLlegadaEstimada.minute.toString().padLeft(2, '0')}\n'
                      'Score: ${opcion.score} ${opcion.esRecomendada ? "(Recomendada)" : ""}\n'
                      'Caminata: ${opcion.distanciaTotalCaminataMetros}m, Espera: ${opcion.tiempoTotalEsperaBusSegundos ~/ 60}min',
                    ),
                    isThreeLine: true,
                    onTap: () {
                      logic.confirmarOpcionDeRutaEIniciarViaje(opcion.idOpcion);
                    },
                  );
                },
              ),
    );
  }
}
