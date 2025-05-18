import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bondi_uy/models/route_leg.dart';
import 'package:bondi_uy/providers/map_notifier.dart';
import 'package:bondi_uy/controllers/route_display_controller.dart';

class TripInstructionsSheet extends ConsumerStatefulWidget {
  final List<RouteLeg> legs;
  final String origenControllerText;
  final String destinoControllerText;
  final RouteDisplayController routeDisplayController;
  final Function(int) onLegSelected;

  const TripInstructionsSheet({
    super.key,
    required this.legs,
    required this.origenControllerText,
    required this.destinoControllerText,
    required this.routeDisplayController,
    required this.onLegSelected,
  });

  @override
  ConsumerState<TripInstructionsSheet> createState() =>
      _TripInstructionsSheetState();
}

class _TripInstructionsSheetState extends ConsumerState<TripInstructionsSheet> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<Widget> _buildInstructionListTiles(
    BuildContext context, // Necesario para Theme
    List<RouteLeg> currentLegs,
    int? currentSelectedLeg,
    Function(int legIndex) onLegSelected,
  ) {
    List<Widget> instructionTiles = [];
    String origenDisplayName = currentLegs.first.from.name ?? 'Punto de inicio';
    if (origenDisplayName.toLowerCase() == 'origin' &&
        widget.origenControllerText.isNotEmpty) {
      origenDisplayName = widget.origenControllerText;
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
            widget.destinoControllerText.isNotEmpty) {
          walkDestinationDisplay = widget.destinoControllerText;
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
        widget.destinoControllerText.isNotEmpty) {
      destinoDisplayName = widget.destinoControllerText;
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
  Widget build(BuildContext context) {
    ref.listen<int?>(
      mapNotifierProvider.select((state) => state.currentLegIndex),
      (previous, next) {
        if (next != null &&
            _pageController.hasClients &&
            _pageController.page?.round() != next) {
          _pageController.animateToPage(
            next,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
    );

    final initialLegIndex = ref.read(mapNotifierProvider).currentLegIndex;
    if (initialLegIndex != null) {
      final instructionWidgets = _buildInstructionListTiles(
        context,
        widget.legs,
        initialLegIndex,
        widget.onLegSelected,
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: instructionWidgets.length,
                    itemBuilder: (context, index) => instructionWidgets[index],
                    separatorBuilder:
                        (context, index) => const SizedBox(height: 4),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  }
}
