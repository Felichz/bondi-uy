// Acceso al fixture grabado Saldanha da Gama 3941 -> Plaza Independencia.

import 'dart:convert';
import 'dart:io';

import 'package:bondi_uy/contract/modelo.dart';
import 'package:bondi_uy/logic/puertos.dart';
import 'package:bondi_uy/logic/servicios/otp.dart';

const rutaFixture = 'test/fixtures/trip_saldanha_plaza_otp_v2.json';

Map<String, dynamic>? _cache;
Map<String, dynamic> fixture() =>
    _cache ??=
        jsonDecode(File(rutaFixture).readAsStringSync())
            as Map<String, dynamic>;

/// Viaje planificado correspondiente al itinerario OTP [otpIndex].
ViajePlanificado viajeDelFixture(int otpIndex) {
  final viajes = interpretarPlanOtp(
    fixture()['rawOtpPlan'] as Map<String, dynamic>,
  );
  return viajes.firstWhere((v) => v.opcion.id.startsWith('otp-$otpIndex-'));
}

Map<String, dynamic> opcionDelFixture(int otpIndex) =>
    (fixture()['options'] as List).cast<Map<String, dynamic>>().firstWhere(
      (o) => o['otpIndex'] == otpIndex,
    );

/// Muestras GPS grabadas (una cada 5 s) de la opción.
List<MuestraUbicacion> muestrasDelFixture(int otpIndex, DateTime inicio) {
  final samples =
      (opcionDelFixture(otpIndex)['replay']['userSamples'] as List)
          .cast<Map<String, dynamic>>();
  return [
    for (final s in samples)
      MuestraUbicacion(
        coordenada: Coordenada(
          (s['lat'] as num).toDouble(),
          (s['lng'] as num).toDouble(),
        ),
        momento: inicio.add(Duration(seconds: (s['t'] as num).round())),
        velocidad: (s['speedMps'] as num?)?.toDouble(),
        precision: 5,
      ),
  ];
}

/// Sondeos reales de la API de Montevideo grabados para la opción.
List<Map<String, dynamic>> sondeosDelFixture(int otpIndex) =>
    (opcionDelFixture(otpIndex)['replay']['busPolls'] as List)
        .cast<Map<String, dynamic>>();

/// Shape GTFS desde el asset empaquetado.
List<Coordenada>? shapeDelAsset(String shapeId) {
  final json =
      jsonDecode(File('assets/data/shapes.geojson').readAsStringSync())
          as Map<String, dynamic>;
  for (final f in json['features'] as List) {
    if (f['properties']['shape_id'] == shapeId) {
      return [
        for (final c in f['geometry']['coordinates'] as List)
          Coordenada((c[1] as num).toDouble(), (c[0] as num).toDouble()),
      ];
    }
  }
  return null;
}
