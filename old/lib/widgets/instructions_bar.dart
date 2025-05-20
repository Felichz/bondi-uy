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
  final int? realtimeEtaMinutes; // NUEVO: ETA en tiempo real en minutos
  final String?
  trackedBusLineShortNameForEta; // NUEVO: Nombre corto de la línea para el ETA
  final bool?
  isHighlightedBusReal; // NUEVO: Flag para saber si el bus del ETA es real

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
    this.realtimeEtaMinutes, // NUEVO
    this.trackedBusLineShortNameForEta, // NUEVO
    this.isHighlightedBusReal, // NUEVO
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
        isInOverviewMode) {
      // No mostrar en modo vista general
      return const SizedBox.shrink();
    }

    if (selectedLegIndex == null ||
        selectedLegIndex! >= currentRouteLegs.length) {
      print(
        "[TripInstructions_Debug] selectedLegIndex es nulo o fuera de rango, no se puede mostrar la barra colapsada.",
      );
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
    Widget? titleWidget; // Para usar RichText condicionalmente

    if (mode == 'WALK') {
      legIconData = Icons.directions_walk;
      legIconColor = Colors.blueAccent;
      String walkDestinationDisplay = toName;
      if (toName.toLowerCase() == 'destination' &&
          selectedLegIndex == currentRouteLegs.length - 1 &&
          destinoControllerText.isNotEmpty) {
        walkDestinationDisplay = destinoControllerText;
      }

      // Cálculo de durationText para WALK
      final double durationSecondsWalk = leg.duration;
      final durationMinutesWalk = (durationSecondsWalk / 60).round();
      String currentDurationTextWalk = "";
      if (durationMinutesWalk > 0) {
        currentDurationTextWalk = " (~${durationMinutesWalk} min)";
      } else if (durationSecondsWalk > 0) {
        currentDurationTextWalk = " (< 1 min)";
      }

      legTitle =
          "Caminar ${distance}m hacia $walkDestinationDisplay" +
          currentDurationTextWalk;
      legSubtitle = ""; // No hay subtítulo para caminar en la barra colapsada
    } else if (mode == 'BUS') {
      legIconData = Icons.directions_bus;
      legIconColor = Colors.deepOrangeAccent;
      final LegRoute? route = leg.route;
      final String lineName =
          route?.shortName ?? route?.longName ?? 'Bus desconocido';

      String currentDurationTextBus;
      Color etaTextColor =
          Theme.of(context).textTheme.titleSmall?.color ??
          Colors.black; // Color por defecto

      if (realtimeEtaMinutes != null &&
          trackedBusLineShortNameForEta == lineName &&
          lineName.isNotEmpty) {
        currentDurationTextBus = " (~$realtimeEtaMinutes min)"; // Usar ETA real
        if (isHighlightedBusReal ?? false) {
          etaTextColor = Colors.green;
        } else {
          // Mantener el color por defecto o uno específico para ETA no real si se desea
          etaTextColor = Colors.orangeAccent; // Por ejemplo
        }
      } else {
        final double durationSecondsBus = leg.duration;
        final durationMinutesBus = (durationSecondsBus / 60).round();
        if (durationMinutesBus > 0) {
          currentDurationTextBus = " (~${durationMinutesBus} min)";
        } else if (durationSecondsBus > 0) {
          currentDurationTextBus = " (< 1 min)";
        } else {
          currentDurationTextBus = "";
        }
      }
      legTitle = "Tomar bus línea $lineName";
      legSubtitle = "Desde: $fromName";

      titleWidget = RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ), // Estilo base del título
          children: <TextSpan>[
            TextSpan(text: legTitle),
            if (currentDurationTextBus.isNotEmpty)
              TextSpan(
                text: currentDurationTextBus,
                style: TextStyle(color: etaTextColor),
              ),
          ],
        ),
        overflow: TextOverflow.ellipsis,
      );
    }

    return GestureDetector(
      onTap: () => _showTripInstructionsBottomSheet(context, currentRouteLegs),
      child: Material(
        elevation: 6.0,
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
                child: InkWell(
                  onTap:
                      onExpandInstructionsTap ??
                      () => _showTripInstructionsBottomSheet(
                        context,
                        currentRouteLegs,
                      ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              titleWidget ??
                                  Text(
                                    // Usar titleWidget si fue creado, sino el Text normal
                                    legTitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              if (legSubtitle.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    legSubtitle,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    // Este widget principalmente devuelve la barra colapsada.
    // La lógica para *mostrar* el bottom sheet es llamada desde la barra.
    return _buildCollapsedInstructionsBar(context);
  }
}
