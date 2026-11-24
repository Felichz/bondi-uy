// Access to the recorded fixture Saldanha da Gama 3941 -> Plaza Independencia.

import 'dart:convert';
import 'dart:io';

import 'package:bondi_uy/contract/model.dart';
import 'package:bondi_uy/logic/ports.dart';
import 'package:bondi_uy/logic/services/otp.dart';

const routeFixture = 'test/fixtures/trip_saldanha_plaza_otp_v2.json';

Map<String, dynamic>? _cache;
Map<String, dynamic> fixture() =>
    _cache ??=
        jsonDecode(File(routeFixture).readAsStringSync())
            as Map<String, dynamic>;

/// Planned trip corresponding to OTP itinerary [otpIndex].
PlannedTrip tripFromFixture(int otpIndex) {
  final trips = interpretPlanOtp(
    fixture()['rawOtpPlan'] as Map<String, dynamic>,
  );
  return trips.firstWhere((v) => v.option.id.startsWith('otp-$otpIndex-'));
}

Map<String, dynamic> optionFromFixture(int otpIndex) =>
    (fixture()['options'] as List).cast<Map<String, dynamic>>().firstWhere(
      (o) => o['otpIndex'] == otpIndex,
    );

/// Recorded GPS samples (one every 5 s) for the option.
List<LocationSample> samplesFromFixture(int otpIndex, DateTime start) {
  final samples =
      (optionFromFixture(otpIndex)['replay']['userSamples'] as List)
          .cast<Map<String, dynamic>>();
  return [
    for (final s in samples)
      LocationSample(
        coordinate: Coordinate(
          (s['lat'] as num).toDouble(),
          (s['lng'] as num).toDouble(),
        ),
        moment: start.add(Duration(seconds: (s['t'] as num).round())),
        velocity: (s['speedMps'] as num?)?.toDouble(),
        precision: 5,
      ),
  ];
}

/// Real polls of the Montevideo API recorded for the option.
List<Map<String, dynamic>> pollsFromFixture(int otpIndex) =>
    (optionFromFixture(otpIndex)['replay']['busPolls'] as List)
        .cast<Map<String, dynamic>>();

/// GTFS shape from the bundled asset.
List<Coordinate>? shapeFromAsset(String shapeId) {
  final json =
      jsonDecode(File('assets/data/shapes.geojson').readAsStringSync())
          as Map<String, dynamic>;
  for (final f in json['features'] as List) {
    if (f['properties']['shape_id'] == shapeId) {
      return [
        for (final c in f['geometry']['coordinates'] as List)
          Coordinate((c[1] as num).toDouble(), (c[0] as num).toDouble()),
      ];
    }
  }
  return null;
}
