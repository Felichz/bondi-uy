// Los dos únicos puntos de conexión entre UI y lógica.
//
// Se declaran acá (en el contrato) y los implementa la raíz de composición
// (main.dart) sobreescribiéndolos con la capa de lógica. La UI importa este
// archivo y nunca nada de `lib/logic/`.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_actions.dart';
import 'app_state.dart';
import 'trazas.dart';

/// Estado de la app (solo lectura para la UI).
final appStateProvider = Provider<AppState>(
  (_) =>
      throw UnimplementedError(
        'appStateProvider sin implementar: '
        'la raíz de composición debe sobreescribirlo',
      ),
);

/// Acciones que la UI puede invocar.
final appActionsProvider = Provider<AppActions>(
  (_) => throw UnimplementedError('appActionsProvider sin implementar'),
);

/// Las llamadas entre las piezas de la app, si la lógica las informa (la demo
/// web, para mostrar la app por dentro); null si no.
final trazasProvider = Provider<Trazas?>((_) => null);
