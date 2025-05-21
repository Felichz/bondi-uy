import 'dart:convert'; // Necesario para jsonEncode
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:bondi_uy/providers/app_providers.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';

// TODO: Importar widgets específicos si son necesarios (ej. un widget para el item de opción de ruta)

class RouteOptionsView extends ConsumerStatefulWidget {
  const RouteOptionsView({super.key});

  @override
  ConsumerState<RouteOptionsView> createState() => _RouteOptionsViewState();
}

class _RouteOptionsViewState extends ConsumerState<RouteOptionsView> {
  MapboxMap? mapboxMap;
  List<String> _activeRouteSourceIds = [];
  List<String> _activeRouteLayerIds = [];

  // Constantes para IDs de capas y fuentes de previsualización de ruta
  static const String PREVIEW_WALK_SOURCE_PREFIX = 'preview-walk-source-';
  static const String PREVIEW_WALK_LAYER_PREFIX = 'preview-walk-layer-';
  static const String PREVIEW_BUS_SOURCE_PREFIX = 'preview-bus-source-';
  static const String PREVIEW_BUS_LAYER_PREFIX = 'preview-bus-layer-';
  static const String PREVIEW_WAIT_SOURCE_PREFIX = 'preview-wait-source-';
  static const String PREVIEW_WAIT_LAYER_PREFIX = 'preview-wait-layer-';
  static const String PREVIEW_WAIT_ICON_IMAGE_ID =
      'preview-wait-icon'; // Si decidimos usar un ícono

  @override
  void initState() {
    super.initState();
    // La preselección de la ruta recomendada la maneja la capa de lógica al entrar en este estado.
    // El listener de idOpcionRutaPrevisualizada se encargará de dibujarla cuando el mapa esté listo.
  }

  void _onMapCreated(MapboxMap controller) {
    mapboxMap = controller;
    // No es necesario llamar a _displayRoutePreview aquí directamente,
    // el onStyleLoadedListener y el ref.listen se encargarán.
  }

  Future<void> _onStyleLoaded() async {
    if (mapboxMap == null) return;
    // Cargar íconos si fueran necesarios (ej. para puntos de espera)
    // Por ahora, usaremos CircleLayer para los puntos de espera, que no necesita ícono.

    // Si ya hay una ruta preseleccionada en el estado cuando el estilo carga, dibujarla.
    final appUiState = ref.read(appUiStateProvider);
    final idRutaPrevisualizada = appUiState.idOpcionRutaPrevisualizada;
    if (idRutaPrevisualizada != null &&
        appUiState.datosFaseOpcionesRuta != null) {
      try {
        final ruta = appUiState.datosFaseOpcionesRuta!.opcionesDeRuta
            .firstWhere((opt) => opt.idOpcion == idRutaPrevisualizada);
        await _displayRoutePreview(ruta);
      } catch (e) {
        print(
          "[_RouteOptionsViewState] Error al dibujar ruta preseleccionada inicial: $e",
        );
      }
    }
  }

  List<List<double>> _coordenadasToGeoJsonPositionList(
    List<Coordenada> coordenadas,
  ) {
    return coordenadas.map((c) => [c.longitud, c.latitud]).toList();
  }

  List<double> _coordenadaToGeoJsonPosition(Coordenada coordenada) {
    return [coordenada.longitud, coordenada.latitud];
  }

  Future<void> _displayRoutePreview(OpcionDeRutaMostrable ruta) async {
    if (mapboxMap == null) return;
    await _clearRoutePreview();

    List<Coordenada> todasLasCoordenadasDeLaRuta = [];

    for (int i = 0; i < ruta.tramosParaPreview.length; i++) {
      final tramo = ruta.tramosParaPreview[i];
      String sourceId = '';
      String layerId = '';
      Map<String, dynamic> geoJsonFeature;

      switch (tramo.tipo) {
        case TipoTramoViaje.CAMINAR:
          sourceId = '$PREVIEW_WALK_SOURCE_PREFIX$i';
          layerId = '$PREVIEW_WALK_LAYER_PREFIX$i';
          if (tramo.geometriaPolilinea != null &&
              tramo.geometriaPolilinea!.isNotEmpty) {
            todasLasCoordenadasDeLaRuta.addAll(tramo.geometriaPolilinea!);
            geoJsonFeature = {
              "type": "Feature",
              "geometry": {
                "type": "LineString",
                "coordinates": _coordenadasToGeoJsonPositionList(
                  tramo.geometriaPolilinea!,
                ),
              },
            };
            await mapboxMap!.style.addSource(
              GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)),
            );
            await mapboxMap!.style.addLayer(
              LineLayer(
                id: layerId,
                sourceId: sourceId,
                lineColor: Colors.blueGrey.value,
                lineWidth: 3.0,
                lineDasharray: [2, 2],
              ),
            );
            _activeRouteSourceIds.add(sourceId);
            _activeRouteLayerIds.add(layerId);
          }
          break;
        case TipoTramoViaje.VIAJE_EN_BUS:
          sourceId = '$PREVIEW_BUS_SOURCE_PREFIX$i';
          layerId = '$PREVIEW_BUS_LAYER_PREFIX$i';
          if (tramo.geometriaPolilinea != null &&
              tramo.geometriaPolilinea!.isNotEmpty) {
            todasLasCoordenadasDeLaRuta.addAll(tramo.geometriaPolilinea!);
            geoJsonFeature = {
              "type": "Feature",
              "geometry": {
                "type": "LineString",
                "coordinates": _coordenadasToGeoJsonPositionList(
                  tramo.geometriaPolilinea!,
                ),
              },
            };
            await mapboxMap!.style.addSource(
              GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)),
            );
            await mapboxMap!.style.addLayer(
              LineLayer(
                id: layerId,
                sourceId: sourceId,
                lineColor: Theme.of(context).colorScheme.primary.value,
                lineWidth: 4.0,
              ),
            );
            _activeRouteSourceIds.add(sourceId);
            _activeRouteLayerIds.add(layerId);
          }
          break;
        case TipoTramoViaje.ESPERAR_BUS:
          sourceId = '$PREVIEW_WAIT_SOURCE_PREFIX$i';
          layerId = '$PREVIEW_WAIT_LAYER_PREFIX$i';
          if (tramo.posicionPunto != null) {
            todasLasCoordenadasDeLaRuta.add(tramo.posicionPunto!);
            geoJsonFeature = {
              "type": "Feature",
              "geometry": {
                "type": "Point",
                "coordinates": _coordenadaToGeoJsonPosition(
                  tramo.posicionPunto!,
                ),
              },
            };
            await mapboxMap!.style.addSource(
              GeoJsonSource(id: sourceId, data: jsonEncode(geoJsonFeature)),
            );
            await mapboxMap!.style.addLayer(
              CircleLayer(
                id: layerId,
                sourceId: sourceId,
                circleColor: Colors.orange.value,
                circleRadius: 6.0,
                circleStrokeWidth: 1.0,
                circleStrokeColor: Colors.white.value,
              ),
            );
            _activeRouteSourceIds.add(sourceId);
            _activeRouteLayerIds.add(layerId);
          }
          break;
      }
    }

    // Zoom a la ruta
    if (todasLasCoordenadasDeLaRuta.isNotEmpty && mapboxMap != null) {
      final mapboxPoints =
          todasLasCoordenadasDeLaRuta
              .map((c) => Point(coordinates: Position(c.longitud, c.latitud)))
              .toList();
      try {
        final cameraOptions = await mapboxMap!.cameraForCoordinates(
          mapboxPoints,
          MbxEdgeInsets(
            top: 100.0,
            left: 40.0,
            bottom: (MediaQuery.of(context).size.height * 0.45),
            right: 40.0,
          ), // Consider panel height
          null,
          null,
        );
        mapboxMap!.flyTo(cameraOptions, MapAnimationOptions(duration: 1200));
      } catch (e) {
        print("[_RouteOptionsViewState] Error zooming to route preview: $e");
      }
    }
  }

  Future<void> _clearRoutePreview() async {
    if (mapboxMap == null) return;
    for (String layerId in _activeRouteLayerIds) {
      try {
        if (await mapboxMap!.style.styleLayerExists(layerId)) {
          await mapboxMap!.style.removeStyleLayer(layerId);
        }
      } catch (e) {
        print("[_RouteOptionsViewState] Error removing layer $layerId: $e");
      }
    }
    for (String sourceId in _activeRouteSourceIds) {
      try {
        if (await mapboxMap!.style.styleSourceExists(sourceId)) {
          await mapboxMap!.style.removeStyleSource(sourceId);
        }
      } catch (e) {
        print("[_RouteOptionsViewState] Error removing source $sourceId: $e");
      }
    }
    _activeRouteLayerIds.clear();
    _activeRouteSourceIds.clear();
  }

  @override
  Widget build(BuildContext context) {
    final appUiState = ref.watch(appUiStateProvider);
    final appLogic = ref.read(appLogicProvider);
    final routeOptionsState = appUiState.datosFaseOpcionesRuta;

    if (routeOptionsState == null) {
      // Esto no debería pasar si faseActual es MOSTRANDO_OPCIONES_RUTA
      // Podría ser un indicador de un problema de estado o una transición incorrecta.
      // Volver a la fase inicial o mostrar un error.
      Future.microtask(() => appLogic.usuarioCanceloBusquedaOSeleccionRuta());
      return const Scaffold(
        body: Center(
          child: Text("Error: Estado de opciones de ruta no disponible."),
        ),
      );
    }

    final opcionesDeRuta = routeOptionsState.opcionesDeRuta;
    final idRutaPrevisualizada = appUiState.idOpcionRutaPrevisualizada;
    OpcionDeRutaMostrable? rutaPrevisualizada;
    if (idRutaPrevisualizada != null) {
      try {
        rutaPrevisualizada = opcionesDeRuta.firstWhere(
          (opt) => opt.idOpcion == idRutaPrevisualizada,
        );
      } catch (e) {
        // Opción previsualizada no encontrada, podría haberse limpiado.
        // No hacer nada, se mostrará sin previsualización o la capa lógica corregirá.
      }
    }

    // Implementar el listener para actualizar la vista del mapa cuando cambia la rutaPrevisualizada.
    ref.listen<
      String?
    >(appUiStateProvider.select((s) => s.idOpcionRutaPrevisualizada), (
      prevId,
      nextId,
    ) {
      final opciones =
          ref.read(appUiStateProvider).datosFaseOpcionesRuta?.opcionesDeRuta ??
          [];
      if (nextId != null) {
        try {
          final ruta = opciones.firstWhere((opt) => opt.idOpcion == nextId);
          _displayRoutePreview(ruta);
        } catch (e) {
          print(
            "[_RouteOptionsViewState] Ruta previsualizada con ID $nextId no encontrada en opciones.",
          );
          _clearRoutePreview(); // Limpiar si la ruta no se encuentra
        }
      } else {
        _clearRoutePreview();
      }
    });

    // Cámara inicial del mapa: Centrar entre origen y destino si están disponibles
    Point initialCenter = Point(
      coordinates: Position(-56.164532, -34.901112),
    ); // Montevideo default
    double initialZoom = 12.0;
    final origen = appUiState.puntoOrigenParaBusqueda;
    final destino = appUiState.puntoDestinoParaBusqueda;

    if (origen != null && destino != null) {
      // Calcular centroide simple
      final centerLat = (origen.latitud + destino.latitud) / 2;
      final centerLng = (origen.longitud + destino.longitud) / 2;
      initialCenter = Point(coordinates: Position(centerLng, centerLat));
      // El zoom se ajustará al dibujar la ruta, pero podríamos tener un zoom inicial más cercano.
      initialZoom =
          11.0; // Un poco más alejado para ver ambos puntos antes de que la ruta dibuje y ajuste.
    } else if (origen != null) {
      initialCenter = Point(
        coordinates: Position(origen.longitud, origen.latitud),
      );
      initialZoom = 14.0;
    } else if (destino != null) {
      initialCenter = Point(
        coordinates: Position(destino.longitud, destino.latitud),
      );
      initialZoom = 14.0;
    }

    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Opciones de Ruta'),
      //   leading: IconButton(
      //     icon: const Icon(Icons.arrow_back),
      //     onPressed: () => appLogic.usuarioCanceloBusquedaOSeleccionRuta(),
      //   ),
      // ),
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey(
              "route_options_map",
            ), // Key para asegurar que el widget se reconstruya si es necesario
            cameraOptions: CameraOptions(
              center: initialCenter,
              zoom: initialZoom,
            ),
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: (_) => _onStyleLoaded(), // Añadido listener
          ),
          // Panel inferior con la lista de opciones de ruta
          _RouteOptionsPanel(
            opciones: opcionesDeRuta,
            idRutaPrevisualizada: idRutaPrevisualizada,
            onOptionSelected: (idOpcion) {
              appLogic.seleccionarOpcionDeRutaParaPrevisualizar(idOpcion);
            },
            onOptionConfirmed: (idOpcion) {
              appLogic.confirmarOpcionDeRutaEIniciarViaje(idOpcion);
            },
            onCancel: () {
              appLogic.usuarioCanceloBusquedaOSeleccionRuta();
            },
          ),
        ],
      ),
      // TODO: Añadir botones de acción principales (Confirmar, Cancelar/Nueva Búsqueda)
      // Podrían estar en un BottomAppBar o similar.
    );
  }
}

class _RouteOptionsPanel extends StatelessWidget {
  final List<OpcionDeRutaMostrable> opciones;
  final String? idRutaPrevisualizada;
  final Function(String) onOptionSelected;
  final Function(String) onOptionConfirmed;
  final VoidCallback onCancel;

  const _RouteOptionsPanel({
    required this.opciones,
    this.idRutaPrevisualizada,
    required this.onOptionSelected,
    required this.onOptionConfirmed,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (opciones.isEmpty) {
      return Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Card(
          margin: EdgeInsets.all(8.0),
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No se encontraron rutas.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onCancel,
                  child: Text('Nueva Búsqueda'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Encontrar la opción recomendada para destacarla o ponerla primero
    OpcionDeRutaMostrable? recomendada;
    List<OpcionDeRutaMostrable> otrasOpciones = List.from(opciones);
    try {
      recomendada = opciones.firstWhere((opt) => opt.esRecomendada);
      otrasOpciones.removeWhere((opt) => opt.esRecomendada);
      if (recomendada != null) {
        otrasOpciones.insert(0, recomendada); // Poner recomendada al principio
      }
    } catch (e) {
      // No hay recomendada, no hacer nada especial
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: DraggableScrollableSheet(
        initialChildSize: 0.4, // Altura inicial (40% de la pantalla)
        minChildSize:
            0.15, // Altura mínima (ej. solo una barra con "Ver opciones")
        maxChildSize: 0.6, // Altura máxima (60% de la pantalla)
        expand: false,
        builder: (BuildContext context, ScrollController scrollController) {
          return Card(
            elevation: 8.0,
            margin: const EdgeInsets.fromLTRB(
              8.0,
              8.0,
              8.0,
              0,
            ), // Margen para que no pegue al borde inferior si está minimizado
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.0),
                topRight: Radius.circular(16.0),
              ),
            ),
            child: Column(
              children: [
                // Handle para arrastrar (opcional, pero buena UX)
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Opciones de Viaje',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      TextButton(
                        onPressed: onCancel,
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: otrasOpciones.length, // Usar la lista reordenada
                    itemBuilder: (context, index) {
                      final opcion = otrasOpciones[index];
                      return _RouteOptionListItem(
                        opcion: opcion,
                        isSelected: opcion.idOpcion == idRutaPrevisualizada,
                        onSelected: () => onOptionSelected(opcion.idOpcion),
                        onConfirmed: () => onOptionConfirmed(opcion.idOpcion),
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
  }
}

class _RouteOptionListItem extends StatelessWidget {
  final OpcionDeRutaMostrable opcion;
  final bool isSelected;
  final VoidCallback onSelected;
  final VoidCallback
  onConfirmed; // Callback para el botón de confirmar esta opción específica

  const _RouteOptionListItem({
    required this.opcion,
    required this.isSelected,
    required this.onSelected,
    required this.onConfirmed,
  });

  // Helper para formatear duración (ej. "25 min", "1 h 10 min")
  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours h ${minutes} min';
    }
    return '$minutes min';
  }

  // Helper para construir la fila de íconos de modos de transporte
  Widget _buildModeIcons(BuildContext context, List<TipoTramoViaje> modos) {
    List<Widget> icons = [];
    for (int i = 0; i < modos.length; i++) {
      IconData iconData;
      Color iconColor = Theme.of(context).colorScheme.primary;
      switch (modos[i]) {
        case TipoTramoViaje.CAMINAR:
          iconData = Icons.directions_walk;
          break;
        case TipoTramoViaje.ESPERAR_BUS:
          iconData = Icons.time_to_leave; // O podría ser omitido o diferente
          iconColor = Colors.orange;
          // Podríamos no mostrar un ícono explícito para esperar o usar uno más sutil
          // For now, let's skip explicit wait icons to simplify the sequence
          continue;
        case TipoTramoViaje.VIAJE_EN_BUS:
          iconData = Icons.directions_bus;
          break;
        default:
          iconData = Icons.error_outline;
      }
      icons.add(Icon(iconData, color: iconColor, size: 20));
      if (i < modos.length - 1) {
        // No añadir chevron si el siguiente es ESPERAR_BUS y lo estamos omitiendo
        if (!(modos[i + 1] == TipoTramoViaje.ESPERAR_BUS && true)) {
          // el 'true' es para mantener la condición por si decidimos mostrarlo
          icons.add(Icon(Icons.chevron_right, color: Colors.grey, size: 16));
        }
      }
    }
    if (icons.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: icons);
  }

  // Helper para mostrar advertencias
  Widget? _buildWarningMessage(
    BuildContext context,
    TipoAdvertenciaItinerario? advertencia,
  ) {
    if (advertencia == null) return null;
    String message;
    Color color = Colors.orangeAccent;
    IconData icon = Icons.warning_amber_rounded;

    switch (advertencia) {
      case TipoAdvertenciaItinerario.TIEMPO_CAMINATA_EXCESIVO:
        message = 'Caminata larga';
        break;
      case TipoAdvertenciaItinerario.TRANSBORDO_AJUSTADO:
        message = 'Transbordo ajustado';
        break;
      case TipoAdvertenciaItinerario.ETA_NO_DISPONIBLE_PARA_PRIMER_BUS:
        message = 'Bus: ETA no disponible';
        color = Colors.grey;
        icon = Icons.info_outline_rounded;
        break;
      case TipoAdvertenciaItinerario.ETA_NO_ES_TIEMPO_REAL_PARA_PRIMER_BUS:
        message = 'Bus: ETA programada';
        color = Colors.blueGrey;
        icon = Icons.schedule_rounded;
        break;
      default:
        message = 'Advertencia';
    }
    return Chip(
      avatar: Icon(icon, color: color, size: 16),
      label: Text(message, style: TextStyle(fontSize: 12, color: color)),
      backgroundColor: color.withOpacity(0.1),
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final etaProximoBus = opcion.etaProximoBus;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onSelected,
      child: Card(
        elevation: isSelected ? 4.0 : 1.0,
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side:
              isSelected
                  ? BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2.0,
                  )
                  : BorderSide(color: Colors.grey.shade300, width: 1.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildModeIcons(context, opcion.secuenciaModosIconos),
                  Text(
                    _formatDuration(opcion.duracionTotalSegundos),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              if (opcion.esRecomendada)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Chip(
                    label: Text(
                      'RECOMENDADA',
                      style: textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    labelPadding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),

              Row(
                children: [
                  if (etaProximoBus != null)
                    Icon(
                      etaProximoBus.esTiempoReal
                          ? Icons.network_wifi
                          : Icons.schedule,
                      color:
                          etaProximoBus.esTiempoReal
                              ? Colors.green
                              : Colors.orange,
                      size: 16,
                    ),
                  if (etaProximoBus != null) const SizedBox(width: 4),
                  if (etaProximoBus != null)
                    Text(
                      'Bus: ${etaProximoBus.minutosParaLlegada} min (\${etaProximoBus.linea})',
                      style: textTheme.bodySmall,
                    ),
                  const Spacer(),
                  Text(
                    'Llegada: ${TimeOfDay.fromDateTime(opcion.horaLlegadaEstimada).format(context)}',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
              if (opcion.advertenciaPrincipal != null ||
                  (opcion.costoEstimadoViaje ?? 0) > 0)
                const SizedBox(height: 6.0),
              Wrap(
                spacing: 6.0,
                runSpacing: 4.0,
                children: [
                  if (opcion.advertenciaPrincipal != null)
                    _buildWarningMessage(
                          context,
                          opcion.advertenciaPrincipal,
                        ) ??
                        const SizedBox.shrink(),
                  if ((opcion.costoEstimadoViaje ?? 0) > 0)
                    Chip(
                      avatar: Icon(
                        Icons.paid_outlined,
                        color: Colors.purple.shade300,
                        size: 16,
                      ),
                      label: Text(
                        'Costo: \$${opcion.costoEstimadoViaje!.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.purple.shade300,
                        ),
                      ),
                      backgroundColor: Colors.purple.shade50.withOpacity(0.5),
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
              if (isSelected) ...[
                const SizedBox(height: 12.0),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Confirmar y Seguir Viaje'),
                    onPressed: onConfirmed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
