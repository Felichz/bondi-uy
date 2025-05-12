import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:bondi_uy/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'constants/mapbox_constants.dart';
import 'app.dart' show initializeAppConfig;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initializeAppConfig(MAPBOX_ACCESS_TOKEN);

  runApp(const ProviderScope(child: MyApp()));
}
