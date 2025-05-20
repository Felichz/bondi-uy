class BusStop {
  final String id;
  final String name;
  final double lat;
  final double lon;

  BusStop({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
  });

  factory BusStop.fromJson(Map<String, dynamic> json) => BusStop(
    id: json['stop_id'] ?? '',
    name: json['stop_name'] ?? '',
    lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
    lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
  );
}
