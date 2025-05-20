import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bondi_uy/backend/providers/app_logic_provider.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';

class InitialSearchView extends ConsumerWidget {
  const InitialSearchView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appLogicProvider);
    final logic = ref.read(appLogicProvider.notifier);

    // Ejemplo de cómo acceder a los datos específicos de esta fase:
    final paradas = appState.datosFaseInicial?.paradasVisiblesEnMapa ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('BondiUY - Búsqueda Inicial'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implementar la acción para iniciar una búsqueda de rutas
              // Ejemplo: Mostrar un diálogo para ingresar origen/destino
              // y luego llamar a logic.iniciarBusquedaDeRutas(...)
              print('Botón de búsqueda presionado');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Mapa (placeholder). Toca una parada o busca una ruta.',
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child:
                paradas.isEmpty
                    ? const Center(child: Text('No hay paradas visibles.'))
                    : ListView.builder(
                      itemCount: paradas.length,
                      itemBuilder: (context, index) {
                        final parada = paradas[index];
                        return ListTile(
                          title: Text(parada.nombre),
                          subtitle: Text('ID: ${parada.idParada}'),
                          onTap: () {
                            logic.solicitarInformacionDetalladaParada(
                              parada.idParada,
                            );
                          },
                        );
                      },
                    ),
          ),
          if (appState.infoParadaConsultada != null)
            Card(
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Info Parada: ${appState.infoParadaConsultada!.nombreParada}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'Líneas: ${appState.infoParadaConsultada!.lineasQuePasan.join(', ')}',
                    ),
                    const SizedBox(height: 8),
                    const Text('Próximos arribos (ETAs):'),
                    if (appState.infoParadaConsultada!.etas.isEmpty)
                      const Text('No hay ETAs disponibles.')
                    else
                      ...appState.infoParadaConsultada!.etas.map(
                        (eta) => Text(
                          'Línea ${eta.linea}: ${eta.minutosParaLlegada} min ${eta.esTiempoReal ? "(Real)" : "(Estimado)"}',
                        ),
                      ),
                    ElevatedButton(
                      onPressed:
                          () => logic.usuarioDeseleccionoInformacionDeParada(),
                      child: const Text("Cerrar info parada"),
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
