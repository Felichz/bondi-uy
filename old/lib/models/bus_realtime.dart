class BusRealtime {
  final String line;
  final String destination;
  final int minutesToArrival;

  BusRealtime({
    required this.line,
    required this.destination,
    required this.minutesToArrival,
  });

  factory BusRealtime.fromJson(Map<String, dynamic> json) => BusRealtime(
    line: json['line'] ?? '',
    destination: json['destination'] ?? '',
    minutesToArrival: (json['minutesToArrival'] as num?)?.toInt() ?? 0,
  );
}
