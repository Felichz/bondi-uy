// lib/ui/widgets/app_search_panel.dart

// Copiar y adaptar el contenido de old/lib/widgets/search_panel.dart aquí.
// Eliminar las dependencias directas a servicios y lógica interna.
// Reemplazar con observación de AppUiState y llamadas a IAppLogic.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bondi_uy/backend/providers/app_logic_provider.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
// TODO: Importar IAppLogic y el provider de IAppLogic
// Ejemplo: import 'package:bondi_uy/backend/contrato_ui/app_logic_interface.dart';
// Ejemplo: import 'package:bondi_uy/backend/providers/app_logic_provider.dart';

import 'app_compose_with_origin.dart'; // Importar el widget adaptado para los campos de texto con sugerencias

// Definición local del Enum
enum TipoCampoBusqueda { ORIGEN, DESTINO }

class AppSearchPanel extends ConsumerStatefulWidget {
  const AppSearchPanel({super.key});

  @override
  ConsumerState<AppSearchPanel> createState() => _AppSearchPanelState();
}

class _AppSearchPanelState extends ConsumerState<AppSearchPanel> {
  late FocusNode _origenFocusNode;
  late FocusNode _destinoFocusNode;
  bool _isPanelExpanded = false; // Estado interno de la UI

  @override
  void initState() {
    super.initState();
    _origenFocusNode = FocusNode();
    _destinoFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _origenFocusNode.dispose();
    _destinoFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appUiState = ref.watch(appLogicProvider);
    final appLogic = ref.read(appLogicProvider.notifier);
    final bool isPanelExpanded = _isPanelExpanded;

    // Escuchar errores de ubicación para mostrar snackbars
    ref.listen<AppUiState>(appLogicProvider, (previous, next) {
      if (previous?.mensajeErrorUbicacion != next.mensajeErrorUbicacion &&
          next.mensajeErrorUbicacion != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.mensajeErrorUbicacion!),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red[700],
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
              textColor: Colors.white,
            ),
          ),
        );
      }
    });

    void _handleSearchRoute() {
      if (appUiState.puntoOrigenParaBusqueda != null &&
          appUiState.puntoDestinoParaBusqueda != null) {
        appLogic.iniciarBusquedaDeRutas();
        // Colapsar el panel después de iniciar la búsqueda
        setState(() {
          _isPanelExpanded = false;
        });
        // Quitar foco de los campos
        _origenFocusNode.unfocus();
        _destinoFocusNode.unfocus();
      } else {
        // Opcional: Mostrar un mensaje si faltan origen/destino.
        // La capa de lógica también podría manejar esto y poner un mensaje en AppUiState.mensajeErrorGlobal.
        print("[AppSearchPanel] Origen o Destino no seleccionados.");
        // Podríamos mostrar un Snackbar o similar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecciona un origen y un destino.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child:
          isPanelExpanded
              ? Container(
                key: const ValueKey('expanded'),
                child: _buildExpandedSearchPanelUI(
                  context,
                  ref,
                  appUiState,
                  appLogic,
                  _handleSearchRoute,
                ),
              )
              : Container(
                key: const ValueKey('compact'),
                child: _buildCompactSearchPanelUI(
                  context,
                  ref,
                  appUiState,
                  appLogic,
                ),
              ),
    );
  }

  Widget _buildCompactSearchPanelUI(
    BuildContext context,
    WidgetRef ref,
    AppUiState appUiState,
    AppLogicNotifier appLogic,
  ) {
    final origenText =
        appUiState.nombreLugarOrigenSeleccionado ??
        appUiState.textoInputOrigenActual ??
        ""; // Vacío si no hay nada
    final destinoText =
        appUiState.nombreLugarDestinoSeleccionado ??
        appUiState.textoInputDestinoActual ??
        ""; // Vacío si no hay nada

    return SafeArea(
      child: Card(
        margin: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
        elevation: 3.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: InkWell(
          onTap: () {
            setState(() {
              _isPanelExpanded = true;
            });
          },
          borderRadius: BorderRadius.circular(10.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 10.0,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.trip_origin,
                  size: 22,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    origenText.isNotEmpty ? origenText : "Origen",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedScale(
                  scale: 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: IconButton(
                    icon: const Icon(Icons.swap_horiz, size: 22),
                    tooltip: "Intercambiar Origen/Destino",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      // Trigger scale animation
                      appLogic.intercambiarOrigenYDestino();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.flag_outlined,
                  size: 22,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    destinoText.isNotEmpty ? destinoText : "Destino",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_note_outlined, size: 26),
                  tooltip: "Modificar Viaje",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _isPanelExpanded = true;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedSearchPanelUI(
    BuildContext context,
    WidgetRef ref,
    AppUiState appUiState,
    AppLogicNotifier appLogic,
    VoidCallback onSearchRouteCallback,
  ) {
    final bool puedeBuscar =
        appUiState.puntoOrigenParaBusqueda != null &&
        appUiState.puntoDestinoParaBusqueda != null;

    // Determinar si mostrar el spinner en el botón de búsqueda
    final bool buscandoRutas =
        appUiState.estadoCalculoRuta == EstadoSolicitud.CARGANDO;

    return SafeArea(
      child: Card(
        margin: const EdgeInsets.fromLTRB(
          8.0,
          0.0,
          8.0,
          8.0,
        ), // Reducido el margen superior
        elevation: 3.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            16.0,
            12.0,
            16.0,
            12.0,
          ), // Ajustar padding
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fila para colapsar y título (opcional)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Podríamos añadir un título como "¿A dónde vamos?" o similar si hay espacio
                  // Expanded(child: Text("Planifica tu viaje", style: Theme.of(context).textTheme.titleMedium)),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up),
                    tooltip: "Colapsar",
                    onPressed: () {
                      setState(() {
                        _isPanelExpanded = false;
                      });
                      _origenFocusNode.unfocus();
                      _destinoFocusNode.unfocus();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Campo de Origen
              AppComposeWithOrigin(
                hintText: "Punto de Origen",
                suggestions: appUiState.sugerenciasOrigen ?? [],
                suggestionsState: appUiState.estadoSugerenciasOrigen,
                onTextChanged:
                    (text) => appLogic.usuarioEscribioEnCampoOrigen(text),
                onSuggestionSelected: (sug) {
                  appLogic.seleccionarSugerenciaOrigen(sug);
                  _destinoFocusNode.requestFocus(); // Mover foco al destino
                },
                onClear: () {
                  appLogic.limpiarOrigenSeleccionado();
                },
                onCurrentLocationTap: () {
                  appLogic.seleccionarUbicacionActualComoOrigen();
                },
                focusNode: _origenFocusNode,
                autoFocus: appUiState.puntoOrigenParaBusqueda == null,
                initialValue: appUiState.textoInputOrigenActual,
              ),
              const SizedBox(height: 12),

              // Campo de Destino
              AppComposeWithOrigin(
                hintText: "Punto de Destino",
                suggestions: appUiState.sugerenciasDestino ?? [],
                suggestionsState: appUiState.estadoSugerenciasDestino,
                onTextChanged:
                    (text) => appLogic.usuarioEscribioEnCampoDestino(text),
                onSuggestionSelected: (sug) {
                  appLogic.seleccionarSugerenciaDestino(sug);
                  _destinoFocusNode
                      .unfocus(); // Quitar foco después de seleccionar destino
                },
                onClear: () {
                  appLogic.limpiarDestinoSeleccionado();
                },
                focusNode: _destinoFocusNode,
                initialValue: appUiState.textoInputDestinoActual,
              ),
              const SizedBox(height: 16),

              // Fila con botón de Intercambiar y Buscar
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.swap_horiz),
                    tooltip: "Intercambiar Origen y Destino",
                    onPressed: () {
                      appLogic.intercambiarOrigenYDestino();
                      // Considerar si el foco debe cambiar o no. Por ahora, no.
                    },
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 1.0, end: puedeBuscar ? 1.0 : 0.95),
                      duration: const Duration(milliseconds: 200),
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: ElevatedButton.icon(
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child:
                                  buscandoRutas
                                      ? Container(
                                        key: const ValueKey('loading'),
                                        width: 20,
                                        height: 20,
                                        padding: const EdgeInsets.all(2.0),
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                      : const Icon(
                                        Icons.search,
                                        key: ValueKey('search'),
                                      ),
                            ),
                            label: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    puedeBuscar
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                color:
                                    puedeBuscar
                                        ? Theme.of(
                                          context,
                                        ).colorScheme.onPrimary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.6),
                              ),
                              child: const Text("Buscar Rutas"),
                            ),
                            onPressed:
                                puedeBuscar && !buscandoRutas
                                    ? onSearchRouteCallback
                                    : null,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              elevation: puedeBuscar ? 6 : 2,
                              backgroundColor:
                                  puedeBuscar
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.surface,
                              foregroundColor:
                                  puedeBuscar
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// TODO: Eliminar _suggestionToPointDart ya que la lógica de coordenadas debe estar en la capa de lógica/adaptadores
