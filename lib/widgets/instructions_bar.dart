import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/route_leg.dart';

// Modelo de datos para un tramo de ruta (leg).
// Necesitaremos una definición o importación si no está globalmente disponible.
// Asumimos por ahora que `leg` es un Map<String, dynamic> como se usa en main.dart

// Callbacks
typedef OnLegSelectedCallback = void Function(int legIndex);
typedef VoidCallback = void Function();

class TripInstructions extends StatelessWidget {
  final List<RouteLeg> currentRouteLegs;
  final int? selectedLegIndex;
  final bool showCollapsedInstructionsBar;
  final String origenControllerText;
  final String destinoControllerText;
  final bool
  isInOverviewMode; // Para la lógica de visibilidad de la barra colapsada

  final OnLegSelectedCallback onLegSelectedInBottomSheet;
  final VoidCallback onNavigateToPreviousLeg;
  final VoidCallback onNavigateToNextLeg;
  final VoidCallback? onExpandInstructionsTap; // Añadir nuevo callback opcional

  const TripInstructions({
    Key? key,
    required this.currentRouteLegs,
    required this.selectedLegIndex,
    required this.showCollapsedInstructionsBar,
    required this.origenControllerText,
    required this.destinoControllerText,
    required this.isInOverviewMode,
    required this.onLegSelectedInBottomSheet,
    required this.onNavigateToPreviousLeg,
    required this.onNavigateToNextLeg,
    this.onExpandInstructionsTap, // Añadir al constructor
  }) : super(key: key);

  // Método para construir los tiles de la lista de instrucciones (movido de _MapScreenState)
  List<Widget> _buildInstructionListTiles(
    BuildContext context, // Necesario para Theme.of(context)
    List<RouteLeg> legs,
    int? currentSelectedLegIndex,
    OnLegSelectedCallback onLegSelected,
  ) {
    List<Widget> instructionTiles = [];

    String origenDisplayName = legs.first.from.name ?? 'Punto de inicio';
    if (origenDisplayName.toLowerCase() == 'origin' &&
        origenControllerText.isNotEmpty) {
      origenDisplayName = origenControllerText;
    }
    instructionTiles.add(
      ListTile(
        leading: const Icon(Icons.flag_outlined),
        title: Text("Origen: $origenDisplayName"),
        dense: true,
      ),
    );

    for (int i = 0; i < legs.length; i++) {
      final RouteLeg leg = legs[i];
      final String mode = leg.mode.toUpperCase();
      final String fromName = leg.from.name ?? 'Ubicación desconocida';
      final String toName = leg.to.name ?? 'Ubicación desconocida';
      final int distance = leg.distance.round();
      final double durationSeconds = leg.duration;
      final durationMinutes = (durationSeconds / 60).round();
      String durationText = " (~${durationMinutes} min)";
      if (durationMinutes == 0 && durationSeconds > 0) {
        durationText = " (< 1 min)";
      } else if (durationMinutes == 0) {
        durationText = "";
      }

      if (mode == 'WALK') {
        String walkDestinationDisplay = toName;
        if (toName.toLowerCase() == 'destination' &&
            i == legs.length - 1 &&
            destinoControllerText.isNotEmpty) {
          walkDestinationDisplay = destinoControllerText;
        }
        String walkTitle =
            "Caminar ${distance}m hacia $walkDestinationDisplay" + durationText;
        final int currentLegIndexForTap = i;
        instructionTiles.add(
          ListTile(
            leading: const Icon(
              Icons.directions_walk,
              color: Colors.blueAccent,
            ),
            title: Text(walkTitle),
            dense: true,
            selected: currentSelectedLegIndex == i,
            selectedTileColor: Colors.blue.withOpacity(0.15),
            onTap: () => onLegSelected(currentLegIndexForTap),
          ),
        );
      } else if (mode == 'BUS' || mode == 'TRANSIT') {
        final LegRoute? route = leg.route;
        final String lineName =
            route?.shortName ?? route?.longName ?? 'Bus desconocido';
        final int currentLegIndexForTap = i;
        instructionTiles.add(
          ListTile(
            leading: const Icon(
              Icons.directions_bus,
              color: Colors.deepOrangeAccent,
            ),
            title: Text("Tomar bus línea $lineName" + durationText),
            subtitle: Text("Desde: $fromName\nHasta: $toName"),
            isThreeLine: true,
            selected: currentSelectedLegIndex == i,
            selectedTileColor: Colors.orange.withOpacity(0.15),
            onTap: () => onLegSelected(currentLegIndexForTap),
          ),
        );
      }
    }

    String destinoDisplayName = legs.last.to.name ?? 'Punto final';
    if (destinoDisplayName.toLowerCase() == 'destination' &&
        destinoControllerText.isNotEmpty) {
      destinoDisplayName = destinoControllerText;
    }
    instructionTiles.add(
      ListTile(
        leading: const Icon(Icons.flag, color: Colors.green),
        title: Text("Destino: $destinoDisplayName"),
        dense: true,
      ),
    );

    return instructionTiles;
  }

  // Método para mostrar el BottomSheet (movido de _MapScreenState)
  void _showTripInstructionsBottomSheet(
    BuildContext context,
    List<RouteLeg> legs,
  ) {
    if (legs.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (BuildContext bc) {
        // Usar StatefulBuilder para manejar el estado de la selección dentro del BottomSheet
        // Aunque en este caso, como pasamos el selectedLegIndex y el callback,
        // el StatefulBuilder podría no ser estrictamente necesario aquí si el padre se reconstruye.
        // Pero para mantener la estructura original y si se quisiera añadir estado local al sheet:
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final instructionWidgets = _buildInstructionListTiles(
              context, // Pasar el BuildContext del builder
              legs,
              selectedLegIndex, // Usar el selectedLegIndex del widget TripInstructions
              (int tappedLegIndex) {
                // Cuando un tramo es tocado en la lista:
                onLegSelectedInBottomSheet(
                  tappedLegIndex,
                ); // Llamar al callback pasado desde el padre
                // El padre (MapScreen) se encargará de actualizar el estado y el mapa.
                setModalState(() {
                  // Esto reconstruirá el BottomSheet para reflejar la selección si es necesario
                });
              },
            );

            return SafeArea(
              child: FractionallySizedBox(
                heightFactor: 0.6,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                      child: Text(
                        'Instrucciones de Viaje',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: instructionWidgets.length,
                          itemBuilder:
                              (context, index) => instructionWidgets[index],
                          separatorBuilder:
                              (context, index) => const SizedBox(height: 4),
                        ),
                      ),
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

  // Método para construir la barra de instrucciones colapsada (movido de _MapScreenState)
  Widget _buildCollapsedInstructionsBar(BuildContext context) {
    if (!showCollapsedInstructionsBar ||
        currentRouteLegs.isEmpty ||
        isInOverviewMode || // No mostrar en modo vista general
        selectedLegIndex == null ||
        selectedLegIndex! >= currentRouteLegs.length) {
      return const SizedBox.shrink();
    }

    final RouteLeg leg = currentRouteLegs[selectedLegIndex!];
    final String mode = leg.mode.toUpperCase();
    final String fromName = leg.from.name ?? 'Ubicación desconocida';
    final String toName = leg.to.name ?? 'Ubicación desconocida';
    final int distance = leg.distance.round();
    final double durationSeconds = leg.duration;
    final durationMinutes = (durationSeconds / 60).round();

    String durationText = " (~${durationMinutes} min)";
    if (durationMinutes == 0 && durationSeconds > 0) {
      durationText = " (< 1 min)";
    } else if (durationMinutes == 0) {
      durationText = "";
    }

    IconData legIconData = Icons.device_unknown;
    Color legIconColor = Colors.grey;
    String legTitle = "";
    String legSubtitle = "";

    if (mode == 'WALK') {
      legIconData = Icons.directions_walk;
      legIconColor = Colors.blueAccent;
      String walkDestinationDisplay = toName;
      if (toName.toLowerCase() == 'destination' &&
          selectedLegIndex == currentRouteLegs.length - 1 &&
          destinoControllerText.isNotEmpty) {
        walkDestinationDisplay = destinoControllerText;
      }
      legTitle =
          "Caminar ${distance}m hacia $walkDestinationDisplay" + durationText;
    } else if (mode == 'BUS' || mode == 'TRANSIT') {
      legIconData = Icons.directions_bus;
      legIconColor = Colors.deepOrangeAccent;
      final LegRoute? route = leg.route;
      final String lineName =
          route?.shortName ?? route?.longName ?? 'Bus desconocido';
      legTitle = "Tomar bus línea $lineName" + durationText;
    } else {
      legTitle = "$mode ${distance}m$durationText";
    }

    return Positioned(
      bottom: 10,
      left: 10,
      right: 10,
      child: GestureDetector(
        onTap:
            () => _showTripInstructionsBottomSheet(context, currentRouteLegs),
        child: Material(
          elevation: 6.0,
          borderRadius: BorderRadius.circular(12.0),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Row(
              children: <Widget>[
                IconButton(
                  icon: Icon(Icons.chevron_left, size: 30),
                  onPressed:
                      (selectedLegIndex! > 0) ? onNavigateToPreviousLeg : null,
                  color: Theme.of(context).colorScheme.primary,
                  disabledColor: Colors.grey.withOpacity(0.5),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap:
                        () => _showTripInstructionsBottomSheet(
                          context,
                          currentRouteLegs,
                        ),
                    child: Container(
                      color: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(legIconData, color: legIconColor, size: 28),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  legTitle,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleSmall?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (legSubtitle.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      legSubtitle,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.7),
                                      ),
                                      maxLines:
                                          mode == 'BUS' || mode == 'TRANSIT'
                                              ? 2
                                              : 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, size: 30),
                  onPressed:
                      (selectedLegIndex! < currentRouteLegs.length - 1)
                          ? onNavigateToNextLeg
                          : null,
                  color: Theme.of(context).colorScheme.primary,
                  disabledColor: Colors.grey.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Este widget principalmente devuelve la barra colapsada.
    // La lógica para *mostrar* el bottom sheet es llamada desde la barra.
    return _buildCollapsedInstructionsBar(context);
  }
}
