// Composition root: connects the contract with the logic layer and mounts the UI.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'logic/providers.dart';
import 'ui/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(overrides: overridesLogic, child: const BondiApp()));
}
