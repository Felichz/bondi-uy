// The only two connection points between UI and logic.
//
// They are declared here (in the contract) and implemented by the composition root
// (main.dart), which overrides them with the logic layer. The UI imports this
// file and never anything from `lib/logic/`.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_actions.dart';
import 'app_state.dart';
import 'traces.dart';

/// App state (read-only for the UI).
final appStateProvider = Provider<AppState>(
  (_) =>
      throw UnimplementedError(
        'appStateProvider sin implementar: '
        'la raíz de composición debe sobreescribirlo',
      ),
);

/// Actions the UI can invoke.
final appActionsProvider = Provider<AppActions>(
  (_) => throw UnimplementedError('appActionsProvider sin implementar'),
);

/// Calls between the app's parts, if the logic reports them (the web demo,
/// to show the app from the inside); null otherwise.
final tracesProvider = Provider<Traces?>((_) => null);
