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
                    String? firstBusLegFromStopId;

                    print(
                      "[RouteOptionsPanel_Debug] Procesando Opción ${index + 1} para itinerario con startTime: ${itinerary.startTime}",
                    );

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
                          print(
                            "[RouteOptionsPanel_Debug] Primer tramo de bus encontrado: Linea=${firstBusLegLineName}",
                          );
                          print(
                            "[RouteOptionsPanel_Debug]   Leg.from: name='${leg.from.name}', stopId='${leg.from.stopId}', stopGtfsId='${leg.from.stopGtfsId}'",
                          );

                          if (leg.from.stopId != null) {
                            firstBusLegFromStopId = _getStringValueLocal(
                              leg.from.stopId,
                            );
                            print(
                              "[RouteOptionsPanel_Debug]     Usando stopId de leg.from.stopId: ${firstBusLegFromStopId}",
                            );
                          } else if (leg.from.stopGtfsId != null) {
                            firstBusLegFromStopId = _getStringValueLocal(
                              leg.from.stopGtfsId,
                            );
                            print(
                              "[RouteOptionsPanel_Debug]     Usando stopId de leg.from.stopGtfsId: ${firstBusLegFromStopId}",
                            );
                          } else {
                            print(
                              "[RouteOptionsPanel_Debug]     No se encontró stopId en leg.from.stopId ni en leg.from.stopGtfsId. firstBusLegFromStopId sigue siendo null.",
                            );
                          }
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

                    Widget? etaWidget;
                    if (firstBusLeg != null &&
                        firstBusLegFromStopId != null &&
                        firstBusLegLineName != null) {
                      // MODIFICACIÓN: Extraer solo la parte numérica del stopId si contiene ":"
                      String finalStopIdForApi = firstBusLegFromStopId!;
                      if (finalStopIdForApi.contains(':')) {
                        final parts = finalStopIdForApi.split(':');
                        if (parts.length > 1) {
                          finalStopIdForApi = parts.last;
                          print(
                            "[RouteOptionsPanel_Debug] ID de parada normalizado para API: ${parts.last} (original: ${firstBusLegFromStopId})",
                          );
                        } else {
                          print(
                            "[RouteOptionsPanel_Debug] ID de parada contiene ':' pero no se pudo splitear: ${firstBusLegFromStopId}",
                          );
                          // Considerar si en este caso no se debe llamar a la API o si se usa el ID original
                        }
                      }

                      etaWidget = FutureBuilder<List<Map<String, dynamic>>>(
                        future: fetchUpcomingBuses(
                          finalStopIdForApi, // Usar el ID normalizado
                          firstBusLegLineName!,
                        ),
                        builder: (context, snapshot) {
                          print(
                            "[RouteOptionsPanel_Debug] FutureBuilder para ${firstBusLegLineName} (parada ${finalStopIdForApi} / original: ${firstBusLegFromStopId}):",
                          );
                          print(
                            "[RouteOptionsPanel_Debug]   ConnectionState: ${snapshot.connectionState}",
                          );
                          if (snapshot.hasError) {
                            print(
                              "[RouteOptionsPanel_Debug]   Error: ${snapshot.error}",
                            );
                          }
                          if (snapshot.hasData) {
                            print(
                              "[RouteOptionsPanel_Debug]   Data: ${snapshot.data}",
                            );
                          }

                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 4.0),
                              child: Text(
                                "Obteniendo ETA...",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          } else if (snapshot.hasError) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 4.0),
                              child: Text(
                                "No se pudo obtener ETA",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.redAccent,
                                ),
                              ),
                            );
                          } else if (snapshot.hasData &&
                              snapshot.data!.isNotEmpty) {
                            final etas = snapshot.data!;
                            final nextBus = etas.first;
                            final minutesToArrival =
                                nextBus['minutesToArrival'];
                            return Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                "Próximo bus en ${minutesToArrival} min",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          } else {
                            return const Padding(
                              padding: EdgeInsets.only(top: 4.0),
                              child: Text(
                                "No hay buses próximos",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orangeAccent,
                                ),
                              ),
                            );
                          }
                        },
                      );
                    }

                    return ListTile(
                      title: titleWidget,
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          subtitleWidget,
                          if (etaWidget != null) etaWidget,
                        ],
                      ),
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
