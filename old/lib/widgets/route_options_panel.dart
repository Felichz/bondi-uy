import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/processed_itinerary.dart';
import '../models/consolidated_itinerary.dart';
import '../models/consolidated_itinerary_leg.dart';
import '../models/route_leg.dart';
import '../models/leg_mode_constants.dart';
import '../providers/map_notifier.dart';
import '../state/map_state.dart';
import '../models/itinerary_warning.dart';

// Helper function (réplica de _getStringValue de main.dart para uso local)
String? _getStringValueLocal(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

void showRouteOptionsModal({
  required BuildContext context,
  required void Function(ConsolidatedItinerary selectedItinerary)
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
      // Usamos un Consumer para acceder a Riverpod
      return Consumer(
        builder: (context, ref, child) {
          final mapState = ref.watch(mapNotifierProvider);
          final mapNotifier = ref.read(mapNotifierProvider.notifier);

          if (mapState.planningStatus == PlanningStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          } else if (mapState.planningStatus == PlanningStatus.error) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "No se pudieron cargar las opciones de ruta. Intente nuevamente.",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          } else if (mapState.consolidatedItineraries.isEmpty &&
              mapState.planningStatus == PlanningStatus.success) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No se encontraron rutas.'),
              ),
            );
          }

          final consolidatedItineraries = mapState.consolidatedItineraries;

          return SafeArea(
            child: FractionallySizedBox(
              heightFactor: 0.5, // Ajustar altura según sea necesario
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      mapState.planningStatus == PlanningStatus.success
                          ? 'Elige tu Ruta (${consolidatedItineraries.length} opciones)'
                          : 'Opciones de Ruta',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _buildContent(
                      context,
                      mapState.planningStatus,
                      consolidatedItineraries,
                      processAndDisplaySelectedItinerary,
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

// Widget helper para construir el contenido principal del modal
Widget _buildContent(
  BuildContext context,
  PlanningStatus planningStatus,
  List<ConsolidatedItinerary> consolidatedItineraries,
  void Function(ConsolidatedItinerary selectedItinerary)
  processAndDisplaySelectedItinerary,
) {
  switch (planningStatus) {
    case PlanningStatus.loading:
      return const Center(child: CircularProgressIndicator());
    case PlanningStatus.error:
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "No se pudieron cargar las opciones de ruta. Intente nuevamente.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    case PlanningStatus.success:
      if (consolidatedItineraries.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No se encontraron rutas.'),
          ),
        );
      }
      return ListView.separated(
        itemCount: consolidatedItineraries.length,
        itemBuilder: (context, index) {
          final ConsolidatedItinerary consolidatedItinerary =
              consolidatedItineraries[index];

          // Extraer información del ConsolidatedItinerary
          final durationMinutes =
              consolidatedItinerary.estimatedTotalDuration.inMinutes;
          final totalWalkDurationMinutes =
              (consolidatedItinerary.totalWalkDuration.inSeconds / 60).round();
          final firstBusWaitDurationMinutes =
              consolidatedItinerary.firstBusWaitDuration.inMinutes;

          List<Widget> modeIcons = [];
          for (ConsolidatedItineraryLeg leg in consolidatedItinerary.legs) {
            String legModeUpper = leg.mode.toUpperCase();
            IconData iconData = Icons.help_outline;
            Color iconColor = Colors.grey;
            List<Widget> legDetailWidgets = [];

            if (legModeUpper == LegModeConstants.walk) {
              iconData = Icons.directions_walk;
              iconColor = Colors.blueAccent;
              legDetailWidgets.add(Icon(iconData, color: iconColor, size: 20));
            } else if (legModeUpper == LegModeConstants.bus) {
              iconData = Icons.directions_bus;
              iconColor = Colors.deepOrangeAccent;
              legDetailWidgets.add(Icon(iconData, color: iconColor, size: 20));
              legDetailWidgets.add(const SizedBox(width: 4));

              if (leg.isConsolidatedBusLeg &&
                  leg.alternativeLineShortNames!.isNotEmpty) {
                String linesText = leg.alternativeLineShortNames!.join(' / ');
                legDetailWidgets.add(
                  Text(
                    linesText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              } else if (leg.representativeRoute?.shortName != null) {
                legDetailWidgets.add(
                  Text(
                    leg.representativeRoute!.shortName!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }
            } else {
              legDetailWidgets.add(Icon(iconData, color: iconColor, size: 20));
            }

            modeIcons.add(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: legDetailWidgets,
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
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color:
                  consolidatedItinerary.canReachFirstBus
                      ? null
                      : Colors.orange.shade700,
            ),
          );

          Widget subtitleWidget = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: interspersedModeIcons),
          );

          List<Widget> additionalInfo = [];

          // Mostrar todos los ETAs alternativos si existen
          if (consolidatedItinerary.alternativeFirstBusETAs.isNotEmpty) {
            String etasString = consolidatedItinerary.alternativeFirstBusETAs
                .map((eta) {
                  String realOrProg = eta.isReal ? "(R)" : "(P)";
                  return "${eta.lineShortName}: ${eta.minutesToArrival}m ${realOrProg}";
                })
                .join(", ");

            additionalInfo.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: Text(
                  "Buses: $etasString",
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Colors
                            .green
                            .shade800, // Un color general para la lista de ETAs
                  ),
                ),
              ),
            );
          } else if (consolidatedItinerary.representativeFirstBusETAInfo !=
              null) {
            // Fallback al ETA representativo si no hay lista de alternativas (ej. para NO_BUS_LEG)
            final etaInfo =
                consolidatedItinerary.representativeFirstBusETAInfo!;
            additionalInfo.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: Text(
                  etaInfo.isReal
                      ? 'Bus: ${etaInfo.lineShortName}: ${etaInfo.minutesToArrival} min (Real)'
                      : 'Bus: ${etaInfo.lineShortName}: ${etaInfo.minutesToArrival} min (Prog.)',
                  style: TextStyle(
                    fontSize: 12,
                    color: etaInfo.isReal ? Colors.green : Colors.black54,
                  ),
                ),
              ),
            );
          } else if (firstBusWaitDurationMinutes > 0 &&
              consolidatedItinerary.legs.any(
                (leg) => leg.mode == LegModeConstants.bus,
              )) {
            // Solo mostrar espera programada si realmente hay un tramo de bus
            additionalInfo.add(
              Text(
                'Espera bus: ${firstBusWaitDurationMinutes} min (Prog.)',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            );
          }

          additionalInfo.add(
            Text(
              'Caminata total: ${totalWalkDurationMinutes} min',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          );

          if (!consolidatedItinerary.canReachFirstBus) {
            additionalInfo.add(
              const Text(
                'Quizás no llegues al primer bus.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }

          for (var warning in consolidatedItinerary.warnings) {
            if (warning == ItineraryWarningType.NO_REALTIME_ETA_AVAILABLE &&
                consolidatedItinerary.representativeFirstBusETAInfo == null) {
              continue;
            }
            if (warning == ItineraryWarningType.WALK_TIME_EXCEEDS_ETA &&
                !consolidatedItinerary.canReachFirstBus) {}

            additionalInfo.add(
              Text(
                _getWarningMessage(warning),
                style: const TextStyle(fontSize: 12, color: Colors.amber),
              ),
            );
          }

          return ListTile(
            title: titleWidget,
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                subtitleWidget,
                const SizedBox(height: 4),
                ...additionalInfo,
              ],
            ),
            isThreeLine: additionalInfo.length > 1,
            onTap: () {
              processAndDisplaySelectedItinerary(consolidatedItinerary);
            },
          );
        },
        separatorBuilder: (context, index) => const Divider(),
      );
    default: // idle o cualquier otro estado no manejado explícitamente
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Selecciona origen y destino para ver rutas.'),
        ),
      );
  }
}

String _getWarningMessage(ItineraryWarningType warning) {
  switch (warning) {
    case ItineraryWarningType.WALK_TIME_EXCEEDS_ETA:
      return 'Advertencia: Es posible que no llegues al primer bus a tiempo.';
    case ItineraryWarningType.NO_REALTIME_ETA_AVAILABLE:
      return 'Info: ETA del bus es programado, no en tiempo real.';
    case ItineraryWarningType.NO_BUS_ETA_FOUND:
      return 'Info: No se encontró ETA para el bus especificado.';
    case ItineraryWarningType.ETA_API_ERROR:
      return 'Error: No se pudo consultar el ETA del bus.';
    case ItineraryWarningType.ETA_LOOKUP_SKIPPED_LIMIT_REACHED:
      return 'Info: ETA no consultado para este bus (límite alcanzado).';
    case ItineraryWarningType.FIRST_LEG_TOO_SHORT_FOR_REALTIME:
      return 'Info: Tramo de bus muy corto para ETA útil.';
    case ItineraryWarningType.LONG_WALK:
      return 'Info: Considera que la caminata total es larga.';
    case ItineraryWarningType.LONG_WAIT:
      return 'Info: Considera que la espera total es larga.';
    case ItineraryWarningType.UNKNOWN_OTP_ERROR:
      return 'Error: Problema al planificar la ruta.';
    default:
      return 'Advertencia sobre el itinerario.';
  }
}
