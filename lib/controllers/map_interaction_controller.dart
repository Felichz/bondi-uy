import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../models/bus_realtime.dart';
import '../providers/map_notifier.dart';
import '../providers/service_providers.dart';
import '../services/mapbox_service.dart';
import '../state/map_state.dart'; // Para UserMapInteractionState
import '../models/bus_arrival_info.dart'; // AÑADIR IMPORTACIÓN

class MapInteractionController {
  final MapboxService mapboxService;
  final WidgetRef ref;

  MapInteractionController({required this.mapboxService, required this.ref});

  void onMapCameraChangeListener(CameraChangedEventData eventData) {
    // print("[MapInteractionController_DEBUG] Map CAMERA CHANGE detected.");
    final mapState = ref.read(mapNotifierProvider);
    if (mapState.userMapInteraction == UserMapInteractionState.idle) {
      // print("[MapInteractionController_DEBUG] Camera change while user was idle. Assuming manual move start.");
      ref.read(mapNotifierProvider.notifier).mapInteractionStarted();
    }
  }

  void onMapIdleListener(MapIdleEventData data) {
    // print("[MapInteractionController_DEBUG] Map IDLE detected.");
    ref.read(mapNotifierProvider.notifier).mapInteractionEnded();
  }

  Future<void> handleMapTapEvent(
    MapContentGestureContext mapTapContext,
    BuildContext uiContext,
  ) async {
    // mapboxMap no es necesario directamente si mapboxService lo encapsula
    // if (mapboxService == null) return; // mapboxService es non-null por constructor
    ref.read(mapNotifierProvider.notifier).mapInteractionStarted();
    // Pasamos uiContext al callback para que pueda ser usado por _requestBusLinesForStopModal
    await mapboxService.handleMapTap(mapTapContext, (stopId, stopName) {
      _requestBusLinesForStopModal(stopId, stopName, uiContext);
    });
    ref.read(mapNotifierProvider.notifier).mapInteractionEnded();
  }

  Future<void> handleMapLongPressEvent(MapContentGestureContext context) async {
    // Implementar la lógica para el evento de pulsación larga en el mapa.
    // Por ejemplo, obtener las coordenadas y hacer algo con ellas.
    final point = context.point;
    print(
      "[MapInteractionController_DEBUG] Map long press detected at: Lat=${point.coordinates.lat}, Lng=${point.coordinates.lng}",
    );
    // Aquí se podría, por ejemplo, iniciar una geocodificación inversa o permitir al usuario soltar un pin.
    // Por ahora, solo notificamos que la interacción comenzó y terminó.
    ref.read(mapNotifierProvider.notifier).mapInteractionStarted();
    // Lógica de long press...
    ref.read(mapNotifierProvider.notifier).mapInteractionEnded();
  }

  void onMapLoadErrorListener(MapLoadingErrorEventData data) {
    // Este método puede ser llamado desde MapScreen si se necesita una lógica más compleja
    // que simplemente imprimir el error.
    print(
      "[MapInteractionController_ERROR] Map loading error (from controller): Type=${data.type}, Message=${data.message}, SourceID=${data.sourceId}, TileID=${data.tileId}",
    );
    // Podrías querer actualizar algún estado o mostrar un mensaje al usuario de forma más elaborada.
  }

  // Método privado para encapsular la lógica de fetch y display del modal
  Future<void> _requestBusLinesForStopModal(
    String stopId,
    String stopName,
    BuildContext uiContext,
  ) async {
    print(
      "[MapInteractionController_Debug] Obteniendo líneas para stopId: $stopId (invocado desde MapInteractionController)...",
    );
    final montevideoApiService = ref.read(montevideoApiServiceProvider);
    List<Map<String, dynamic>> busLinesData = [];
    String errorMessage = 'No hay información de líneas para esta parada.';
    bool isLoadingLines = true; // Para manejar el estado de carga en el modal

    // Primero, obtenemos los datos de las líneas.
    try {
      busLinesData = await montevideoApiService.fetchBusLinesForStop(stopId);
      if (busLinesData.isEmpty) {
        errorMessage =
            'No se encontraron líneas para esta parada (respuesta del servicio vacía).';
      }
    } catch (e, s) {
      errorMessage = "Excepción al obtener líneas desde el servicio: $e";
      print("[MapInteractionController_Debug] $errorMessage");
      print("[MapInteractionController_Debug] StackTrace: $s");
    } finally {
      // Ya no necesitamos mounted check aquí, el modal manejará su propio ciclo de vida.
      isLoadingLines = false;
    }

    // Usamos el uiContext pasado para mostrar el modal
    // if (!mounted) return; // No es aplicable aquí de la misma forma

    String? _expandedLineId; // Estado para el panel expandido dentro del modal

    // Método helper para obtener y filtrar arribos para una línea específica en la parada
    // Esto evita llamar múltiples veces a la red si _getUpcomingBusesForStop fuera inteligente (pero no lo es aún sin cache a nivel de servicio)
    // Sin embargo, asegura que usamos la nueva interfaz.
    Future<List<BusArrivalInfo>> _fetchSpecificLineArrivals(
      String currentStopId,
      String lineShortNameForFilter,
    ) async {
      // montevideoApiService ya está disponible en el scope de _requestBusLinesForStopModal
      final allArrivals = await montevideoApiService.getUpcomingBusesForStop(
        currentStopId,
      );
      return allArrivals
          .where((arrival) => arrival.lineShortName == lineShortNameForFilter)
          .toList();
    }

    showModalBottomSheet(
      context: uiContext, // Usar el BuildContext proporcionado
      isScrollControlled: true,
      builder: (BuildContext bc) {
        // Usar un StatefulBuilder para manejar el estado interno del modal (como _expandedLineId)
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(uiContext).size.height *
                      0.6, // Usar uiContext para MediaQuery
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Parada: $stopName (ID: $stopId)',
                        style:
                            Theme.of(
                              uiContext,
                            ).textTheme.titleLarge, // Usar uiContext para Theme
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child:
                          isLoadingLines
                              ? const Center(child: CircularProgressIndicator())
                              : busLinesData.isNotEmpty
                              ? ListView.builder(
                                shrinkWrap: true,
                                itemCount: busLinesData.length,
                                itemBuilder: (context, index) {
                                  final lineInfo = busLinesData[index];
                                  final String currentLineId =
                                      lineInfo['lineId'] as String? ?? '';
                                  final String currentLineShortName =
                                      lineInfo['line'] as String? ?? '?';
                                  final bool isExpanded =
                                      _expandedLineId == currentLineId;

                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: CircleAvatar(
                                          child: Text(currentLineShortName),
                                        ),
                                        title: Text(
                                          'Línea: $currentLineShortName',
                                        ),
                                        subtitle: Text(
                                          'ID Variante: $currentLineId',
                                        ),
                                        trailing: Icon(
                                          isExpanded
                                              ? Icons.expand_less
                                              : Icons.expand_more,
                                        ),
                                        onTap: () {
                                          setModalState(() {
                                            if (isExpanded) {
                                              _expandedLineId = null;
                                            } else {
                                              _expandedLineId = currentLineId;
                                            }
                                          });
                                        },
                                      ),
                                      if (isExpanded)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16.0,
                                            vertical: 8.0,
                                          ),
                                          child: FutureBuilder<
                                            List<BusArrivalInfo>
                                          >(
                                            future: _fetchSpecificLineArrivals(
                                              stopId,
                                              currentLineShortName,
                                            ),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState ==
                                                  ConnectionState.waiting) {
                                                return const Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2.0,
                                                      ),
                                                );
                                              }
                                              if (snapshot.hasError) {
                                                return Text(
                                                  'Error al cargar ETAs: ${snapshot.error}',
                                                  style: const TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                );
                                              }

                                              final List<BusArrivalInfo>? etas =
                                                  snapshot.data;

                                              if (etas == null ||
                                                  etas.isEmpty) {
                                                return const Text(
                                                  'No hay próximos arribos para esta línea.',
                                                );
                                              }

                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children:
                                                    etas.map((etaInfo) {
                                                      // Renombrar para evitar conflicto con variable externa si existiera
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              left: 16.0,
                                                              top: 4.0,
                                                              bottom: 4.0,
                                                            ),
                                                        child: Text(
                                                          // Acceder a los campos de BusArrivalInfo directamente
                                                          '• Próximo en ${etaInfo.minutesToArrival} min ${etaInfo.isReal ? "(Real)" : ""}',
                                                          style:
                                                              Theme.of(
                                                                uiContext,
                                                              ) // Usar uiContext para Theme
                                                              .textTheme.bodyMedium,
                                                        ),
                                                      );
                                                    }).toList(),
                                              );
                                            },
                                          ),
                                        ),
                                      const Divider(
                                        height: 0.5,
                                        indent: 16,
                                        endIndent: 16,
                                      ),
                                    ],
                                  );
                                },
                              )
                              : ListTile(title: Text(errorMessage)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void dispose() {
    // Para cualquier limpieza futura
  }
}
