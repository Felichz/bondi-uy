import 'dart:math' as math;

double calculateHaversineDistance(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const double R = 6371000; // Radio de la Tierra en metros

  double lat1Rad = math.pi * lat1 / 180;
  double lon1Rad = math.pi * lon1 / 180;
  double lat2Rad = math.pi * lat2 / 180;
  double lon2Rad = math.pi * lon2 / 180;

  double dLat = lat2Rad - lat1Rad;
  double dLon = lon2Rad - lon1Rad;

  double a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1Rad) *
          math.cos(lat2Rad) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

  return R * c; // Distancia en metros
}
