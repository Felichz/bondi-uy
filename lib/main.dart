import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bondi_uy/ui/app.dart'; // Importaremos App en el siguiente paso

// TODO: Cuando creemos los providers en la capa de backend, los importaremos aquí.
// Ejemplo: import 'package:bondi_uy/backend/providers/app_logic_provider.dart';

// TODO: Cuando creemos el widget raíz de la UI, lo importaremos aquí.
// Ejemplo: import 'package:bondi_uy/ui/screens/app_shell.dart';

void main() {
  // Cualquier inicialización previa a runApp (si es necesaria) iría aquí.
  // Por ejemplo, WidgetsFlutterBinding.ensureInitialized(); si se usan plugins
  // que lo requieran antes. Para Mapbox, esto es común.
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: Configuración inicial de Mapbox si se requiere a nivel global aquí
  // como el token de acceso, aunque a veces se hace en el widget del mapa.
  // Ejemplo desde el código 'old': initializeAppConfig(MAPBOX_ACCESS_TOKEN);
  // Esto podría ser una función en tu capa de backend/core si prefieres.

  runApp(
    const ProviderScope(
      // ProviderScope hace que los providers de Riverpod estén disponibles.
      child: App(),
    ),
  );
}

class BondiApp extends StatelessWidget {
  const BondiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BondiUY', // Puedes cambiar esto
      theme: ThemeData(
        // Define tu tema base aquí si lo deseas
        primarySwatch: Colors.blue,
        useMaterial3: true, // Recomendado para nuevos proyectos Flutter
      ),
      // TODO: Reemplazar Scaffold con tu widget UI raíz (ej. AppShell)
      // que consumirá el AppUiState.
      home: const Scaffold(
        body: Center(child: Text("BondiUY App - Capa UI (Próximamente)")),
      ),
      // Ejemplo de cómo se vería con un AppShell:
      // home: AppShell(),
    );
  }
}
