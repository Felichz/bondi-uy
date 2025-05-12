import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/route_leg.dart';
import '../providers/service_providers.dart';

class RouteOptionsModal extends ConsumerWidget {
  final List<RouteLeg> legs;

  const RouteOptionsModal({Key? key, required this.legs}) : super(key: key);

  String formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    if (duration.inHours > 0) {
      return "${duration.inHours}h ${twoDigitMinutes}min";
    } else {
      return "${twoDigitMinutes}min";
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (legs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Opciones de Ruta')),
        body: const Center(child: Text('No hay tramos para mostrar.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Opciones de Ruta')),
      body: ListView.builder(
        itemCount: legs.length,
        itemBuilder: (context, index) {
          final leg = legs[index];

          final stopGtfsId =
              leg.mode == 'BUS' && leg.from.stopGtfsId != null
                  ? leg.from.stopGtfsId
                  : null;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Tramo ${index + 1}: ${leg.mode}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('Desde: ${leg.from.name}'),
                  Text('Hasta: ${leg.to.name}'),
                  if (leg.duration != null)
                    Text('Duración: ${formatDuration(leg.duration.round())}'),
                  if (leg.distance != null)
                    Text(
                      'Distancia: ${(leg.distance! / 1000.0).toStringAsFixed(2)} km',
                    ),

                  const SizedBox(height: 8),
                  if (stopGtfsId != null) ...[
                    _buildEtaSection(
                      context,
                      ref,
                      stopGtfsId,
                      leg.trip?.gtfsId,
                      leg,
                    ),
                  ] else if (leg.mode == 'BUS') ...[
                    const Text(
                      'No se pudo obtener ETA (ID de parada faltante)',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ],

                  if (leg.steps != null && leg.steps!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Instrucciones:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...leg.steps!
                        .map(
                          (step) => Text(
                            '- ${step.relativeDirection ?? "N/A"} en ${step.streetName ?? "N/A"} (${step.distance?.round() ?? 0}m)',
                          ),
                        )
                        .toList(),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEtaSection(
    BuildContext context,
    WidgetRef ref,
    String stopGtfsId,
    String? tripGtfsId,
    RouteLeg leg,
  ) {
    final lineShortName = leg.route?.shortName;

    if (lineShortName == null || lineShortName.isEmpty) {
      return const Text(
        'Información de línea no disponible para ETA.',
        style: TextStyle(color: Colors.orange),
      );
    }

    final upcomingBusesFuture = ref
        .watch(montevideoApiServiceProvider)
        .fetchUpcomingBusesForStopAndLine(stopGtfsId, lineShortName);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: upcomingBusesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2.0),
          );
        } else if (snapshot.hasError) {
          print('Error fetching ETA for stop $stopGtfsId: ${snapshot.error}');
          return const Text(
            'Error al obtener ETA',
            style: TextStyle(color: Colors.red),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('No hay información de próximos ómnibus.');
        } else {
          final upcomingBuses = snapshot.data!;
          Map<String, dynamic> relevantBus = {};

          if (tripGtfsId != null && tripGtfsId.isNotEmpty) {
            relevantBus = upcomingBuses.firstWhere(
              (bus) => bus['trip_id']?.toString() == tripGtfsId,
              orElse: () => upcomingBuses.isNotEmpty ? upcomingBuses.first : {},
            );
          } else if (upcomingBuses.isNotEmpty) {
            relevantBus = upcomingBuses.first;
          }

          if (relevantBus.isEmpty) {
            return const Text('No hay información para este viaje específico.');
          }

          final arrivalTime = relevantBus['arrival_time'];
          final deviation = relevantBus['deviation'];

          String etaText = 'Próximo bus: ';
          if (arrivalTime != null) {
            try {
              final arrival = DateTime.fromMillisecondsSinceEpoch(
                arrivalTime * 1000,
              );
              etaText += DateFormat('HH:mm').format(arrival);
              if (deviation != null) {
                final deviationMinutes = (deviation / 60).round();
                if (deviationMinutes == 0) {
                  etaText += ' (en hora)';
                } else if (deviationMinutes > 0) {
                  etaText += ' (+${deviationMinutes}min)';
                } else {
                  etaText += ' (${deviationMinutes}min)';
                }
              }
            } catch (e) {
              print("Error formatting ETA: $e");
              etaText += ' Hora inválida';
            }
          } else {
            etaText += 'Hora desconocida';
          }
          return Text(
            etaText,
            style: const TextStyle(fontWeight: FontWeight.bold),
          );
        }
      },
    );
  }
}
