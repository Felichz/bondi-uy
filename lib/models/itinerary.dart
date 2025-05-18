import 'route_leg.dart';
import 'leg_mode_constants.dart';

class Itinerary {
  final int startTime;
  final int endTime;
  final List<RouteLeg> legs;

  Itinerary({
    required this.startTime,
    required this.endTime,
    required this.legs,
  });

  // Getter para la duración total en segundos
  int get duration {
    return (endTime - startTime) ~/ 1000; // Convertir de ms a s
  }

  // Getter para el tiempo total de caminata en segundos
  int get walkTime {
    int totalWalkTimeSeconds = 0;
    for (var leg in legs) {
      if (leg.mode == LegModeConstants.walk) {
        // Usar LegModeConstants.walk
        totalWalkTimeSeconds +=
            leg.duration.toInt(); // Asumiendo que leg.duration es en segundos
      }
    }
    return totalWalkTimeSeconds;
  }

  factory Itinerary.fromJson(Map<String, dynamic> json) {
    return Itinerary(
      startTime: (json['startTime'] as num?)?.toInt() ?? 0,
      endTime: (json['endTime'] as num?)?.toInt() ?? 0,
      legs: RouteLeg.listFromJson(json['legs'] as List<dynamic>? ?? []),
    );
  }

  // Helper para convertir una lista de dynamic/Map a List<Itinerary>
  static List<Itinerary> listFromJson(List<dynamic> list) {
    return list
        .map((e) => Itinerary.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
