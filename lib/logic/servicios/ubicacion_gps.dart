// Ubicación real del dispositivo con geolocator.

import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../contract/modelo.dart';
import '../puertos.dart';

class UbicacionGps implements FuenteUbicacion {
  @override
  Future<PermisoUbicacion> asegurarPermiso() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return PermisoUbicacion.servicioApagado;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    return switch (p) {
      LocationPermission.always ||
      LocationPermission.whileInUse => PermisoUbicacion.concedido,
      LocationPermission.deniedForever => PermisoUbicacion.denegadoParaSiempre,
      _ => PermisoUbicacion.denegado,
    };
  }

  @override
  Future<MuestraUbicacion?> actual() async {
    try {
      final ultima = await Geolocator.getLastKnownPosition();
      if (ultima != null &&
          DateTime.now().difference(ultima.timestamp) <
              const Duration(seconds: 30)) {
        return _muestra(ultima);
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return _muestra(p);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<MuestraUbicacion> seguir() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 3,
    ),
  ).map(_muestra);

  MuestraUbicacion _muestra(Position p) => MuestraUbicacion(
    coordenada: Coordenada(p.latitude, p.longitude),
    momento: p.timestamp,
    velocidad: p.speed >= 0 ? p.speed : null,
    precision: p.accuracy > 0 ? p.accuracy : null,
  );
}
