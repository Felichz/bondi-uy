import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Removed: import 'package:bondi_uy/ui/app.dart'; // Importaremos App en el siguiente paso

// TODO: Cuando creemos los providers en la capa de backend, los importaremos aquí.
// Ejemplo: import 'package:bondi_uy/backend/providers/app_logic_provider.dart';

// TODO: Cuando creemos el widget raíz de la UI, lo importaremos aquí.
// Ejemplo: import 'package:bondi_uy/ui/screens/app_shell.dart';

import 'package:bondi_uy/ui/app_host.dart'; // Import the new AppHost widget
import 'package:bondi_uy/utils/feature_logger.dart';

void main() async {
  // Cualquier inicialización previa a runApp (si es necesaria) iría aquí.
  // Por ejemplo, WidgetsFlutterBinding.ensureInitialized(); si se usan plugins
  // que lo requieran antes. Para Mapbox, esto es común.
  WidgetsFlutterBinding.ensureInitialized();
  // Init feature logger (clean logs each run)
  try {
    await FeatureLogger().init(clean: true);
  } catch (e) {
    // ignore: avoid_print
    print('FeatureLogger init error: $e');
  }

  // TODO: Configuración inicial de Mapbox si se requiere a nivel global aquí
  // como el token de acceso, aunque a veces se hace en el widget del mapa.
  // Ejemplo desde el código 'old': initializeAppConfig(MAPBOX_ACCESS_TOKEN);
  // Esto podría ser una función en tu capa de backend/core si prefieres.

  runApp(
    const ProviderScope(
      // ProviderScope hace que los providers de Riverpod estén disponibles.
      // TODO: Reemplazar PlaceholderApp con tu widget UI raíz (ej. AppShell)
      child: AppHost(), // Use AppHost instead of PlaceholderApp
    ),
  );
}

// Removed: class BondiApp extends StatelessWidget { ... }

// Removed: Placeholder for the new root UI widget
// Removed: class PlaceholderApp extends StatelessWidget { ... }
