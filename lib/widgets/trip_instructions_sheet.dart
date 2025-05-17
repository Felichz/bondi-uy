import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bondi_uy/models/route_leg.dart';
import 'package:bondi_uy/providers/map_notifier.dart';
import 'package:bondi_uy/controllers/route_display_controller.dart';

class TripInstructionsSheet extends ConsumerWidget {
  final List<RouteLeg> legs;
  final String origenControllerText;
  final String destinoControllerText;
  final RouteDisplayController routeDisplayController;
  // Aunque pasamos los textos, mantenemos los controladores por si la lógica original los usaba de otra forma.
  // Sin embargo, la lógica actual solo usa .text, así que los textos son suficientes.
  // Para simplificar, usaremos los textos directamente como se planeó.

  const TripInstructionsSheet({
    super.key,
    required this.legs,
    required this.origenControllerText,
    required this.destinoControllerText,
    required this.routeDisplayController,
  });

  List<Widget> _buildInstructionListTiles(
    BuildContext context, // Necesario para Theme
    List<RouteLeg> currentLegs,
    int? currentSelectedLeg,
    Function(int legIndex) onLegSelected,
  ) {
    List<Widget> instructionTiles = [];
    String origenDisplayName = currentLegs.first.from.name ?? 'Punto de inicio';
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

    for (int i = 0; i < currentLegs.length; i++) {
      final RouteLeg leg = currentLegs[i];
      final String mode = leg.mode.toUpperCase();
      final String fromName = leg.from.name ?? 'Ubicación desconocida';
      final String toName = leg.to.name ?? 'Ubicación desconocida';
      final int distance = leg.distance.round();
      final int durationMinutes = (leg.duration / 60).round();
      String durationText = " (~${durationMinutes} min)";
      if (durationMinutes == 0 && leg.duration > 0)
        durationText = " (< 1 min)";
      else if (durationMinutes == 0)
        durationText = "";

      IconData iconData = Icons.help_outline;
      Color iconColor = Colors.grey;
      String title = "";
      String subtitle = "";
      bool isThreeLine = false;

      if (mode == 'WALK') {
        iconData = Icons.directions_walk;
        iconColor = Colors.blueAccent;
        String walkDestinationDisplay = toName;
        if (toName.toLowerCase() == 'destination' &&
            i == currentLegs.length - 1 &&
            destinoControllerText.isNotEmpty) {
          walkDestinationDisplay = destinoControllerText;
        }
        title =
            "Caminar ${distance}m hacia $walkDestinationDisplay$durationText";
      } else if (mode == 'BUS' || mode == 'TRANSIT') {
        iconData = Icons.directions_bus;
        iconColor = Colors.deepOrangeAccent;
        final lineName =
            leg.route?.shortName ?? leg.route?.longName ?? 'Bus desconocido';
        title = "Tomar bus línea $lineName$durationText";
        subtitle = "Desde: $fromName \nHasta: $toName";
        isThreeLine = true;
      } else {
        title = "$mode ${distance}m$durationText";
        subtitle = "Desde: $fromName, Hasta: $toName";
        isThreeLine = true;
      }
      final int currentLegIndexForTap = i;
      instructionTiles.add(
        ListTile(
          leading: Icon(iconData, color: iconColor),
          title: Text(title),
          subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
          isThreeLine: isThreeLine,
          dense: true,
          selected: currentSelectedLeg == i,
          selectedTileColor: iconColor.withOpacity(0.15),
          onTap: () => onLegSelected(currentLegIndexForTap),
        ),
      );
    }
    String destinoDisplayName = currentLegs.last.to.name ?? 'Punto final';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapState = ref.watch(mapNotifierProvider);
    final mapNotifier = ref.read(mapNotifierProvider.notifier);
    // El StatefulBuilder es para actualizar el estado local del bottom sheet (tile seleccionado)
    // inmediatamente después del onTap, sin esperar a que el estado global se propague si hay demora.
    return StatefulBuilder(
      builder: (BuildContext modalContext, StateSetter setModalState) {
        // Leer el selectedLegIndex actual desde el estado global para el resaltado
        int? currentSelectedLegIndex = ref.watch(
          mapNotifierProvider.select((state) => state.selectedLegIndex),
        );

        final instructionWidgets = _buildInstructionListTiles(
          modalContext, // Usar el contexto del modal para Theme, etc.
          legs, // Usar las legs pasadas al widget
          currentSelectedLegIndex, // Usar el índice del estado global
          (int tappedLegIndex) {
            mapNotifier.setSelectedLegIndex(tappedLegIndex);
            routeDisplayController.updateMapRouteHighlight();
            // No es necesario llamar a setModalState aquí si el widget se reconstruye por ref.watch
            // Sin embargo, si hay otros estados locales que StatefulBuilder maneja, se mantendría.
            // Por ahora, para asegurar la actualización visual inmediata del tile seleccionado:
            setModalState(() {});
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
                    style: Theme.of(modalContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
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
  }
}
