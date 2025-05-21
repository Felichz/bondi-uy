import 'dart:convert'; // Para jsonEncode
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:bondi_uy/providers/app_providers.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';

// TODO: Importar widgets específicos si son necesarios (ej. para mostrar cada tramo de instrucción)

class ActiveTripView extends ConsumerStatefulWidget {
  const ActiveTripView({super.key});

  @override
  ConsumerState<ActiveTripView> createState() => _ActiveTripViewState();
}

class _ActiveTripViewState extends ConsumerState<ActiveTripView> {
  MapboxMap? mapboxMap;
  List<String> _activeRouteSourceIds = [];
  List<String> _activeRouteLayerIds = [];

  // Constantes para IDs de capas y fuentes de la ruta activa
  static const String ACTIVE_WALK_SOURCE_PREFIX = 'active-walk-source-';
  static const String ACTIVE_WALK_LAYER_PREFIX = 'active-walk-layer-';
  static const String ACTIVE_BUS_SOURCE_PREFIX = 'active-bus-source-';
  static const String ACTIVE_BUS_LAYER_PREFIX = 'active-bus-layer-';
  static const String ACTIVE_WAIT_SOURCE_PREFIX = 'active-wait-source-';
  static const String ACTIVE_WAIT_LAYER_PREFIX = 'active-wait-layer-';
  // TODO: Podríamos necesitar íconos para inicio/fin de tramos o paradas específicas del viaje activo.

  @override
  void initState() {
    super.initState();
    // La lógica de dibujar la ruta se moverá a _onStyleLoaded para asegurar que el mapa esté listo.
  }

  void _onMapCreated(MapboxMap controller) {
    mapboxMap = controller;
    // El listener onStyleLoaded se encargará de dibujar la ruta cuando el estilo esté listo.
  }

  Future<void> _onStyleLoaded() async {
    if (mapboxMap == null) return;
    // TODO: Cargar íconos específicos para esta vista si son necesarios (ej. marcador de bus en tiempo real).

    final activeTripState = ref.read(appUiStateProvider).datosFaseViajeActivo;
    if (activeTripState != null) {
      // Dibujar la ruta completa del viaje activo.
      // Usamos activeTripState.tramosDelViaje que es la lista autoritativa para esta fase.
      await _displayActiveRoute(
        activeTripState.tramosDelViaje,
        0,
      ); // TODO: Usar el índice del tramo actual real
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

  Future<void> _displayActiveRoute(
    List<TramoViajeMostrable> tramos,
    int tramoActualIndex,
  ) async {
    if (mapboxMap == null) return;
    await _clearActiveRoute();

    List<Coordenada> todasLasCoordenadasDeLaRuta = [];

    for (int i = 0; i < tramos.length; i++) {
      final tramo = tramos[i];
      String sourceId = '';
      String layerId = '';
      Map<String, dynamic> geoJsonFeature;
      // bool esTramoActual = i == tramoActualIndex; // TODO: Usar para resaltar

      switch (tramo.tipo) {
        case TipoTramoViaje.CAMINAR:
          sourceId = '$ACTIVE_WALK_SOURCE_PREFIX$i';
          layerId = '$ACTIVE_WALK_LAYER_PREFIX$i';
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
                lineColor:
                    Colors
                        .blueGrey
                        .shade300
                        .value, // Color más tenue para no actual
                lineWidth: 3.0,
                lineDasharray: [2, 2],
              ),
            );
            _activeRouteSourceIds.add(sourceId);
            _activeRouteLayerIds.add(layerId);
          }
          break;
        case TipoTramoViaje.VIAJE_EN_BUS:
          sourceId = '$ACTIVE_BUS_SOURCE_PREFIX$i';
          layerId = '$ACTIVE_BUS_LAYER_PREFIX$i';
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
                lineColor:
                    Theme.of(
                      context,
                    ).colorScheme.secondary.value, // Usar color secundario
                lineWidth: 4.0,
              ),
            );
            _activeRouteSourceIds.add(sourceId);
            _activeRouteLayerIds.add(layerId);
          }
          break;
        case TipoTramoViaje.ESPERAR_BUS:
          sourceId = '$ACTIVE_WAIT_SOURCE_PREFIX$i';
          layerId = '$ACTIVE_WAIT_LAYER_PREFIX$i';
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
                circleColor: Colors.orangeAccent.value,
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

    if (todasLasCoordenadasDeLaRuta.isNotEmpty && mapboxMap != null) {
      final mapboxPoints =
          todasLasCoordenadasDeLaRuta
              .map((c) => Point(coordinates: Position(c.longitud, c.latitud)))
              .toList();
      try {
        final cameraOptions = await mapboxMap!.cameraForCoordinates(
          mapboxPoints,
          MbxEdgeInsets(
            top: 80.0,
            left: 40.0,
            bottom: (MediaQuery.of(context).size.height * 0.35),
            right: 40.0,
          ), // Ajustar padding para panel de instrucciones
          null,
          null,
        );
        mapboxMap!.flyTo(cameraOptions, MapAnimationOptions(duration: 1200));
      } catch (e) {
        print("[_ActiveTripViewState] Error zooming to active route: $e");
      }
    }
    // TODO: Llamar a _highlightCurrentLeg(tramoActualIndex) después de dibujar todo.
  }

  Future<void> _clearActiveRoute() async {
    if (mapboxMap == null) return;
    for (String layerId in _activeRouteLayerIds) {
      try {
        if (await mapboxMap!.style.styleLayerExists(layerId)) {
          await mapboxMap!.style.removeStyleLayer(layerId);
        }
      } catch (e) {
        print("Error removing layer $layerId: $e");
      }
    }
    for (String sourceId in _activeRouteSourceIds) {
      try {
        if (await mapboxMap!.style.styleSourceExists(sourceId)) {
          await mapboxMap!.style.removeStyleSource(sourceId);
        }
      } catch (e) {
        print("Error removing source $sourceId: $e");
      }
    }
    _activeRouteLayerIds.clear();
    _activeRouteSourceIds.clear();
  }

  // TODO: Función para actualizar la posición del bus en tiempo real en el mapa.
  // Future<void> _updateRealTimeBusPosition(Coordenada posicionBus) async { ... }

  // TODO: Función para resaltar el tramo actual en el mapa.
  // Future<void> _highlightCurrentLeg(int tramoIndex) async { ... }

  @override
  Widget build(BuildContext context) {
    final appUiState = ref.watch(appUiStateProvider);
    final appLogic = ref.read(appLogicProvider);
    final activeTripState = appUiState.datosFaseViajeActivo;

    if (activeTripState == null) {
      // Esto no debería pasar si faseActual es VIAJE_ACTIVO_EN_CURSO.
      // Podría indicar un problema de estado. Volver a la fase inicial.
      Future.microtask(
        () => appLogic.usuarioCanceloBusquedaOSeleccionRuta(),
      ); // O una acción más específica para error en viaje activo.
      return const Scaffold(
        body: Center(
          child: Text("Error: Estado de viaje activo no disponible."),
        ),
      );
    }

    final OpcionDeRutaMostrable viajeConfirmado =
        activeTripState.opcionDeRutaSeleccionada;
    final List<TramoViajeMostrable> tramosDelViaje =
        activeTripState.tramosDelViaje;
    // TODO: Obtener el índice del tramo actual (la lógica debería proveerlo o la UI derivarlo).
    // final int tramoActualIndex = activeTripState.indiceTramoActual ?? 0;

    // TODO: Implementar listeners para cambios en posicionActualBusReal, etc.
    // ref.listen<Coordenada?>(appUiStateProvider.select((s) => s.datosFaseViajeActivo?.posicionActualBusReal), (prev, next) {
    //   if (next != null) { // _updateRealTimeBusPosition(next); }
    // });

    // ref.listen<int?>(appUiStateProvider.select((s) => s.datosFaseViajeActivo?.indiceTramoActual), (prev, next) {
    //    if (next != null) { // _highlightCurrentLeg(next); }
    // });

    return Scaffold(
      // appBar: AppBar(
      //   title: Text('Viaje: ${viajeConfirmado.idOpcion}'), // O un título más descriptivo
      //   leading: IconButton(
      //     icon: const Icon(Icons.close), // O un "Finalizar Viaje"
      //     onPressed: () => appLogic.detenerSeguimientoActivo(),
      //   ),
      // ),
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey("active_trip_map"),
            cameraOptions: CameraOptions(
              // TODO: Establecer cámara inicial adecuada (zoom a la ruta)
              center: Point(
                coordinates: Position(-56.164532, -34.901112),
              ), // Montevideo default
              zoom: 12.0,
            ),
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: (_) => _onStyleLoaded(), // Añadido listener
          ),
          // Panel de Instrucciones Mejorado
          _ActiveTripInstructionsPanel(
            tramos: tramosDelViaje,
            // TODO: Pasar el índice del tramo actual cuando esté disponible en AppUiState
            // tramoActualIndex: activeTripState.indiceTramoActual ?? 0,
            onFinalizarViaje: () => appLogic.detenerSeguimientoActivo(),
            // TODO: Conectar acciones de navegación de tramos
            // onSeleccionarTramo: (index) => appLogic.usuarioSeleccionoPasoInstrucciones(index),
            // onSiguienteTramo: () => appLogic.navegarASiguientePasoInstrucciones(),
            // onAnteriorTramo: () => appLogic.navegarAAnteriorPasoInstrucciones(),
          ),
        ],
      ),
    );
  }

  IconData _getIconForTramo(TipoTramoViaje tipo) {
    switch (tipo) {
      case TipoTramoViaje.CAMINAR:
        return Icons.directions_walk;
      case TipoTramoViaje.ESPERAR_BUS:
        return Icons.time_to_leave;
      case TipoTramoViaje.VIAJE_EN_BUS:
        return Icons.directions_bus;
      default:
        return Icons.device_unknown;
    }
  }

  @override
  void dispose() {
    _clearActiveRoute(); // Limpiar la ruta del mapa al salir de la vista
    mapboxMap = null;
    super.dispose();
  }
}

// --- Panel de Instrucciones de Viaje Activo ---
class _ActiveTripInstructionsPanel extends StatelessWidget {
  final List<TramoViajeMostrable> tramos;
  // final int tramoActualIndex; // Descomentar cuando esté disponible
  final VoidCallback onFinalizarViaje;
  // final Function(int) onSeleccionarTramo; // Descomentar
  // final VoidCallback onSiguienteTramo; // Descomentar
  // final VoidCallback onAnteriorTramo; // Descomentar

  const _ActiveTripInstructionsPanel({
    required this.tramos,
    // required this.tramoActualIndex, // Descomentar
    required this.onFinalizarViaje,
    // required this.onSeleccionarTramo, // Descomentar
    // required this.onSiguienteTramo, // Descomentar
    // required this.onAnteriorTramo, // Descomentar
  });

  @override
  Widget build(BuildContext context) {
    if (tramos.isEmpty) {
      return const SizedBox.shrink(); // No mostrar nada si no hay tramos
    }

    // TODO: Determinar información del tramo actual para mostrar en la parte superior del panel (cuando esté colapsado)
    // final TramoViajeMostrable tramoActual = tramos[tramoActualIndex];

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: DraggableScrollableSheet(
        initialChildSize:
            0.3, // Altura inicial (más pequeño que en opciones de ruta)
        minChildSize:
            0.15, // Altura mínima (ej. solo una barra con info del tramo actual)
        maxChildSize: 0.7, // Altura máxima
        expand: false,
        builder: (BuildContext context, ScrollController scrollController) {
          return Card(
            elevation: 8.0,
            margin: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.0),
                topRight: Radius.circular(16.0),
              ),
            ),
            child: Column(
              children: [
                // Handle para arrastrar
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
                  padding: const EdgeInsets.fromLTRB(
                    16.0,
                    0,
                    8.0,
                    0,
                  ), // Reducido padding vertical
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // TODO: Mostrar información resumida del tramo actual aquí
                      // Ejemplo: Text(tramoActual.descripcion, style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        "Instrucciones del Viaje",
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.close),
                        label: const Text("Finalizar"),
                        onPressed: onFinalizarViaje,
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                // Placeholder para botones de navegación Anterior/Siguiente
                // TODO: Implementar lógica y visibilidad de estos botones
                // Padding(
                //   padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0),
                //   child: Row(
                //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //     children: [
                //       IconButton(icon: Icon(Icons.arrow_back_ios), onPressed: () { /* onAnteriorTramo */ }),
                //       IconButton(icon: Icon(Icons.arrow_forward_ios), onPressed: () { /* onSiguienteTramo */ }),
                //     ],
                //   ),
                // ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: tramos.length,
                    itemBuilder: (context, index) {
                      final tramo = tramos[index];
                      // bool esTramoActual = index == tramoActualIndex; // Descomentar
                      return _TramoInstruccionListItem(
                        tramo: tramo,
                        // esTramoActual: esTramoActual, // Descomentar
                        // onTap: () => onSeleccionarTramo(index), // Descomentar
                      );
                    },
                    separatorBuilder: (context, index) => const Divider(),
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

// --- Widget para cada ítem de instrucción en la lista ---
class _TramoInstruccionListItem extends StatelessWidget {
  final TramoViajeMostrable tramo;
  // final bool esTramoActual; // Descomentar
  // final VoidCallback? onTap; // Descomentar

  const _TramoInstruccionListItem({
    required this.tramo,
    // required this.esTramoActual, // Descomentar
    // this.onTap, // Descomentar
  });

  IconData _getIconForTramo(TipoTramoViaje tipo) {
    switch (tipo) {
      case TipoTramoViaje.CAMINAR:
        return Icons.directions_walk;
      case TipoTramoViaje.ESPERAR_BUS:
        return Icons.time_to_leave;
      case TipoTramoViaje.VIAJE_EN_BUS:
        return Icons.directions_bus;
      default:
        return Icons.device_unknown; // Icono por defecto
    }
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes;
    if (minutes < 1) return "< 1 min";
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    // bool esTramoActual = index == tramoActualIndex; // TODO: Cuando esté disponible
    // Color tileColor = esTramoActual ? colorScheme.primary.withOpacity(0.1) : Colors.transparent;
    // Color iconColor = esTramoActual ? colorScheme.primary : colorScheme.onSurfaceVariant;
    // FontWeight titleFontWeight = esTramoActual ? FontWeight.bold : FontWeight.w500;
    Color iconColor = colorScheme.secondary; // Color por defecto para íconos
    FontWeight titleFontWeight = FontWeight.w500;
    Color tileColor = Colors.transparent;

    return InkWell(
      // onTap: onTap, // Descomentar cuando la lógica de selección de tramo esté
      //splashColor: colorScheme.primary.withOpacity(0.2),
      child: Container(
        // color: tileColor, // Descomentar para resaltar tramo actual
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_getIconForTramo(tramo.tipo), size: 32, color: iconColor),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tramo.descripcion,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: titleFontWeight,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    "Duración: ${_formatDuration(tramo.duracionEstimadaSegundos)}${tramo.distanciaMetros > 0 ? '  •  Distancia: ${tramo.distanciaMetros} m' : ''}",
                    style: textTheme.bodyMedium?.copyWith(
                      color: textTheme.bodySmall?.color,
                      height: 1.2,
                    ),
                  ),
                  if (tramo.tipo == TipoTramoViaje.VIAJE_EN_BUS &&
                      tramo.nombreLineaBus != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        "Línea: ${tramo.nombreLineaBus}${tramo.destinoFinalDelBus != null ? ' (Destino: ${tramo.destinoFinalDelBus})' : ''}",
                        style: textTheme.bodySmall?.copyWith(height: 1.2),
                      ),
                    ),
                  if (tramo.tipo == TipoTramoViaje.ESPERAR_BUS &&
                      tramo.nombreLineaBus != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        "Esperar Línea: ${tramo.nombreLineaBus}${tramo.destinoFinalDelBus != null ? ' (Destino: ${tramo.destinoFinalDelBus})' : ''}",
                        style: textTheme.bodySmall?.copyWith(height: 1.2),
                      ),
                    ),
                  // TODO: Mostrar ETA del bus si está disponible para este tramo
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
