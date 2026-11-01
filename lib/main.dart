// Raíz de composición: conecta el contrato con la capa de lógica y monta la UI.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'logic/proveedores.dart';
import 'ui/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(overrides: overridesLogica, child: const BondiApp()));
}
