import 'package:flutter/material.dart';
import '../models/itinerary.dart';
import '../models/route_leg.dart';

// Helper function (réplica de _getStringValue de main.dart para uso local)
String? _getStringValueLocal(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

void showRouteOptionsModal({
  required BuildContext context,
  required List<Itinerary> availableItineraries,
  required Future<List<Map<String, dynamic>>> Function(
    String stopId,
    String lineShortName,
  )
  fetchUpcomingBuses,
  required void Function(Itinerary selectedItinerary)
  processAndDisplaySelectedItinerary,
}) {
  // La llamada a _stopTrackingBusLine() se hace en el llamador (_MapScreenState)
  // antes de invocar esta función.

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
    ),
    builder: (BuildContext bc) {
      return SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.5, // Ajustar altura según sea necesario
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Elige tu Ruta (${availableItineraries.length} opciones)',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: availableItineraries.length,
                  itemBuilder: (context, index) {
                    final Itinerary itinerary = availableItineraries[index];
                    final List<RouteLeg> legs = itinerary.legs;
                    final int startTime = itinerary.startTime;
                    final int endTime = itinerary.endTime;
                    final durationMs = endTime - startTime;
                    final durationMinutes = (durationMs / (1000 * 60)).round();

                    List<Widget> modeIcons = [];
                    RouteLeg? firstBusLeg;
                    String? firstBusLegLineName;
                    String? firstBusLegFromStopGtfsId;

                    for (RouteLeg leg in legs) {
                      String mode = leg.mode.toUpperCase();
                      IconData iconData = Icons.help_outline;
                      Color iconColor = Colors.grey;
                      String? shortName = leg.route?.shortName;

                      if (mode == 'WALK') {
                        iconData = Icons.directions_walk;
                        iconColor = Colors.blueAccent;
                      } else if (mode == 'BUS' || mode == 'TRANSIT') {
                        iconData = Icons.directions_bus;
                        iconColor = Colors.deepOrangeAccent;
                        if (firstBusLeg == null) {
                          firstBusLeg = leg;
                          firstBusLegLineName = leg.route?.shortName;
                          firstBusLegFromStopGtfsId = null;
                        }
                      }

                      List<Widget> legWidgets = [
                        Icon(iconData, color: iconColor, size: 20),
                      ];
                      if (shortName != null && shortName.isNotEmpty) {
                        legWidgets.add(const SizedBox(width: 2));
                        legWidgets.add(
                          Text(
                            shortName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      modeIcons.add(
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: legWidgets,
                          ),
                        ),
                      );
                    }

                    List<Widget> interspersedModeIcons = [];
                    for (int i = 0; i < modeIcons.length; i++) {
                      interspersedModeIcons.add(modeIcons[i]);
                      if (i < modeIcons.length - 1) {
                        interspersedModeIcons.add(
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 3.0),
                            child: Icon(
                              Icons.arrow_forward_ios,
                              size: 10,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      }
                    }

                    Widget titleWidget = Text(
                      "Opción ${index + 1}: ${durationMinutes} min",
                    );
                    Widget subtitleWidget = SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: interspersedModeIcons),
                    );

                    return ListTile(
                      title: titleWidget,
                      subtitle: subtitleWidget,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(context);
                        processAndDisplaySelectedItinerary(itinerary);
                      },
                    );
                  },
                  separatorBuilder:
                      (context, index) =>
                          const Divider(indent: 16, endIndent: 16),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
