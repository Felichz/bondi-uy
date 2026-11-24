// Real location of the device, via geolocator.

import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../contract/model.dart';
import '../ports.dart';

class GpsLocation implements LocationSource {
  @override
  Future<LocationPermissionState> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermissionState.serviceOff;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    return switch (p) {
      LocationPermission.always ||
      LocationPermission.whileInUse => LocationPermissionState.granted,
      LocationPermission.deniedForever =>
        LocationPermissionState.deniedParaAlways,
      _ => LocationPermissionState.denied,
    };
  }

  @override
  Future<LocationSample?> actual() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null &&
          DateTime.now().difference(last.timestamp) <
              const Duration(seconds: 30)) {
        return _sample(last);
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return _sample(p);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<LocationSample> follow() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 3,
    ),
  ).map(_sample);

  LocationSample _sample(Position p) => LocationSample(
    coordinate: Coordinate(p.latitude, p.longitude),
    moment: p.timestamp,
    velocity: p.speed >= 0 ? p.speed : null,
    precision: p.accuracy > 0 ? p.accuracy : null,
  );
}
