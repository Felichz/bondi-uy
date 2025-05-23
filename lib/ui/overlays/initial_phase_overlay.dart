import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:bondi_uy/backend/providers/app_logic_provider.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import 'package:bondi_uy/ui/widgets/app_search_panel.dart';

class InitialPhaseOverlay extends ConsumerStatefulWidget {
  final MapboxMap? mapboxMap;

  const InitialPhaseOverlay({super.key, required this.mapboxMap});

  @override
  ConsumerState<InitialPhaseOverlay> createState() =>
      _InitialPhaseOverlayState();
}

class _InitialPhaseOverlayState extends ConsumerState<InitialPhaseOverlay> {
  @override
  Widget build(BuildContext context) {
    final appUiState = ref.watch(appLogicProvider);

    // Escuchar cambios de estado para mostrar modal de parada
    ref.listen<AppUiState>(appLogicProvider, (previous, next) {
      if (previous?.infoParadaConsultada != next.infoParadaConsultada) {
        if (next.infoParadaConsultada != null) {
          _showStopInfoModal(context, next.infoParadaConsultada!);
        }
      }
    });

    return Stack(
      children: [
        // Panel de búsqueda superpuesto sobre el mapa
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 10,
          right: 10,
          child: const AppSearchPanel(),
        ),
      ],
    );
  }

  void _showStopInfoModal(
    BuildContext context,
    InfoDetalladaParada infoParada,
  ) {
    final appLogic = ref.read(appLogicProvider.notifier);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext bc) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.4,
            minChildSize: 0.25,
            maxChildSize: 0.75,
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    topRight: Radius.circular(20.0),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            infoParada.nombreParada,
                            style: Theme.of(context).textTheme.titleLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            Navigator.pop(context);
                            appLogic.usuarioDeseleccionoInformacionDeParada();
                          },
                        ),
                      ],
                    ),
                    Text(
                      "Parada ID: ${infoParada.idParada}",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    if (infoParada.lineasQuePasan.isNotEmpty) ...[
                      Text(
                        "Líneas que pasan:",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Wrap(
                        spacing: 8.0,
                        children:
                            infoParada.lineasQuePasan
                                .map((linea) => Chip(label: Text(linea)))
                                .toList(),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      "Próximas llegadas (ETAs):",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Expanded(
                      child:
                          infoParada.etas.isEmpty
                              ? const Center(
                                child: Text(
                                  "No hay ETAs disponibles en este momento.",
                                ),
                              )
                              : ListView.builder(
                                controller: scrollController,
                                itemCount: infoParada.etas.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final eta = infoParada.etas[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4.0,
                                    ),
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.directions_bus,
                                        color:
                                            eta.esTiempoReal
                                                ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                                : Colors.grey,
                                      ),
                                      title: Text(
                                        "Línea ${eta.linea}" +
                                            (eta.destino != null
                                                ? " (dir. ${eta.destino})"
                                                : ""),
                                      ),
                                      subtitle: Text(
                                        "${eta.minutosParaLlegada} min" +
                                            (eta.esTiempoReal
                                                ? " (tiempo real)"
                                                : " (programado)"),
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
