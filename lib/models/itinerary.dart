import 'route_leg.dart';

class Itinerary {
  final int startTime;
  final int endTime;
  final List<RouteLeg> legs;

  Itinerary({
    required this.startTime,
    required this.endTime,
    required this.legs,
  });

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
