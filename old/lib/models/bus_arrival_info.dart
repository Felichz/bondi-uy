// lib/models/bus_arrival_info.dart
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'; // Para Position

class BusArrivalInfo {
  final int minutesToArrival;
  final bool isReal;
  final String lineShortName;
  final String? destination;
  final Position? position;
  final DateTime? requestTime;
  final DateTime? arrivalTime;
  final String? lineVariantCode;
  final bool? isClosestUpcoming;

  BusArrivalInfo({
    required this.minutesToArrival,
    required this.isReal,
    required this.lineShortName,
    this.destination,
    this.position,
    this.requestTime,
    this.arrivalTime,
    this.lineVariantCode,
    this.isClosestUpcoming,
  });

  factory BusArrivalInfo.fromJson(Map<String, dynamic> json) {
    DateTime? parsedRequestTime;
    if (json['requestTime'] != null) {
      parsedRequestTime = DateTime.tryParse(json['requestTime']);
    }
    DateTime? parsedArrivalTime;
    if (json['arrivalTime'] != null) {
      parsedArrivalTime = DateTime.tryParse(json['arrivalTime']);
    }
    Position? busPosition;
    if (json['position'] != null &&
        json['position']['lat'] != null &&
        json['position']['lng'] != null) {
      try {
        busPosition = Position(
          (json['position']['lng'] as num).toDouble(),
          (json['position']['lat'] as num).toDouble(),
        );
      } catch (e) {
        print("[BusArrivalInfo] Error parsing position: $e");
        busPosition = null;
      }
    }

    return BusArrivalInfo(
      lineShortName: json['lineShortName'] ?? '',
      destination: json['destination'],
      minutesToArrival: json['minutesToArrival'] ?? 0,
      position: busPosition,
      isReal: json['isReal'] ?? false,
      requestTime: parsedRequestTime,
      arrivalTime: parsedArrivalTime,
      lineVariantCode: json['lineVariantCode'],
      isClosestUpcoming: json['isClosestUpcoming'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lineShortName': lineShortName,
      'destination': destination,
      'minutesToArrival': minutesToArrival,
      'position':
          position != null
              ? {'lat': position!.lat, 'lng': position!.lng}
              : null,
      'isReal': isReal,
      'requestTime': requestTime?.toIso8601String(),
      'arrivalTime': arrivalTime?.toIso8601String(),
      'lineVariantCode': lineVariantCode,
      'isClosestUpcoming': isClosestUpcoming,
    };
  }

  BusArrivalInfo copyWith({
    String? lineShortName,
    String? destination,
    int? minutesToArrival,
    Position? position,
    bool? isReal,
    DateTime? requestTime,
    DateTime? arrivalTime,
    String? lineVariantCode,
    bool? isClosestUpcoming,
    bool allowNullPosition = false,
  }) {
    return BusArrivalInfo(
      lineShortName: lineShortName ?? this.lineShortName,
      destination: destination ?? this.destination,
      minutesToArrival: minutesToArrival ?? this.minutesToArrival,
      position: allowNullPosition ? position : (position ?? this.position),
      isReal: isReal ?? this.isReal,
      requestTime: requestTime ?? this.requestTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      lineVariantCode: lineVariantCode ?? this.lineVariantCode,
      isClosestUpcoming: isClosestUpcoming ?? this.isClosestUpcoming,
    );
  }
}
