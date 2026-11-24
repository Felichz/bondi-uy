// "Ver todo el viaje" (See the whole trip): the full list of steps, with what
// is done, the current one and what is left. For someone who wants to plan
// ahead (where do I get off? how far do I walk at the end?) without losing the
// card for the current step.

import 'package:flutter/material.dart';

import '../../contract/app_state.dart';
import '../common.dart';
import '../formats.dart';
import '../theme/app_theme.dart';
import '../theme/sheet.dart';
import '../texts/texts.dart';

Future<void> mostrarItinerary(
  BuildContext context,
  TripPhase f,
  String destination,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black.withValues(alpha: 0.25),
  builder: (context) => _Itinerary(f, destination),
);

class _Itinerary extends StatelessWidget {
  final TripPhase f;
  final String destination;
  const _Itinerary(this.f, this.destination);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final height = MediaQuery.sizeOf(context).height;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: ConstrainedBox(
        key: const ValueKey('itinerario'),
        constraints: BoxConstraints(maxHeight: height * 0.78),
        child: Sheet(
          padding: EdgeInsets.zero,
          radio: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Asa(),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tx.yourTrip, style: t.titleLarge),
                          Text(
                            tx.toDestinationArrive(
                              destination,
                              time(f.option.arrival),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('itinerario-cerrar'),
                      tooltip: tx.close,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  children: [
                    for (var i = 0; i < f.totalSteps; i++)
                      _Fila(
                        f.option.legs[i],
                        status:
                            i < f.stepActual
                                ? _Status.done
                                : i == f.stepActual
                                ? _Status.actual
                                : _Status.pending,
                        last: i == f.totalSteps - 1,
                        destination: destination,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Status { done, actual, pending }

class _Fila extends StatelessWidget {
  final Leg leg;
  final _Status status;
  final bool last;
  final String destination;
  const _Fila(
    this.leg, {
    required this.status,
    required this.last,
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    final (color, icon, title, detail) = switch (leg) {
      WalkLeg(
        :final distanceMeters,
        :final durationSeconds,
        :final towardStop,
      ) =>
        (
          c.walk,
          Icons.directions_walk_rounded,
          tx.walks(distance(distanceMeters)),
          '${towardStop == null ? tx.untilDestination(destination) : tx.untilTheStop(stopName(towardStop.name))} · ${duration(durationSeconds)}',
        ),
      WaitLeg(:final line, :final stop, :final destinationLine) => (
        c.live,
        Icons.hail_rounded,
        tx.wait(line),
        [
          tx.stop(stopName(stop.name)),
          if (destinationLine != null) tx.toward(capitalize(destinationLine)),
        ].join(' · '),
      ),
      BusLeg(
        :final line,
        :final alighting,
        :final stopsIntermediate,
        :final durationSeconds,
      ) =>
        (
          c.bus,
          Icons.directions_bus_rounded,
          tx.travelsIn(line),
          tx.getOffSummary(
            stopName(alighting.name),
            stops(stopsIntermediate.length + 1),
            duration(durationSeconds),
          ),
        ),
    };
    final done = status == _Status.done;
    final actual = status == _Status.actual;
    final tone = done ? c.textFaint : color;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: actual ? tone : tone.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    done ? Icons.check_rounded : icon,
                    size: 20,
                    color: actual ? Colors.white : tone,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            done
                                ? c.textFaint.withValues(alpha: 0.4)
                                : tone.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 6, bottom: last ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight:
                                actual ? FontWeight.w700 : FontWeight.w600,
                            color: done ? c.textFaint : c.text,
                            decoration:
                                done ? TextDecoration.lineThrough : null,
                            decorationColor: c.textFaint,
                          ),
                        ),
                      ),
                      if (actual) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: c.text,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tx.nowUpper,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: c.sheetSolid,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.3,
                      color: done ? c.textFaint : c.textSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
