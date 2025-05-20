import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import 'package:bondi_uy/backend/providers/app_logic_provider.dart';

class SearchInputPanel extends ConsumerStatefulWidget {
  const SearchInputPanel({super.key});

  @override
  ConsumerState<SearchInputPanel> createState() => _SearchInputPanelState();
}

class _SearchInputPanelState extends ConsumerState<SearchInputPanel> {
  final TextEditingController _origenController = TextEditingController();
  final TextEditingController _destinoController = TextEditingController();
  final FocusNode _origenFocusNode = FocusNode();
  final FocusNode _destinoFocusNode = FocusNode();

  Timer? _debounceTimerOrigen;
  Timer? _debounceTimerDestino;

  // OverlayEntry para las sugerencias
  OverlayEntry? _origenSuggestionsOverlayEntry;
  OverlayEntry? _destinoSuggestionsOverlayEntry;

  // LayerLinks para conectar los TextFields con sus overlays de sugerencias
  final LayerLink _origenLayerLink = LayerLink();
  final LayerLink _destinoLayerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appState = ref.read(appLogicProvider);
      _origenController.text = appState.textoInputOrigenActual ?? '';
      _destinoController.text = appState.textoInputDestinoActual ?? '';
    });

    _origenFocusNode.addListener(_handleOrigenFocusChange);
    _destinoFocusNode.addListener(_handleDestinoFocusChange);
  }

  void _removeOrigenSuggestionsOverlay() {
    _origenSuggestionsOverlayEntry?.remove();
    _origenSuggestionsOverlayEntry = null;
  }

  void _removeDestinoSuggestionsOverlay() {
    _destinoSuggestionsOverlayEntry?.remove();
    _destinoSuggestionsOverlayEntry = null;
  }

  void _handleOrigenFocusChange() {
    if (!mounted) return;
    if (_origenFocusNode.hasFocus) {
      // Potencialmente mostrar sugerencias si hay texto y datos.
      // La lógica de actualización de sugerencias se encargará.
      _updateOrigenSuggestions();
    } else {
      // Retrasar un poco para permitir clics en las sugerencias
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        _removeOrigenSuggestionsOverlay();
      });
    }
  }

  void _handleDestinoFocusChange() {
    if (!mounted) return;
    if (_destinoFocusNode.hasFocus) {
      _updateDestinoSuggestions();
    } else {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        _removeDestinoSuggestionsOverlay();
      });
    }
  }

  void _onOrigenChanged(String query) {
    if (_debounceTimerOrigen?.isActive ?? false) _debounceTimerOrigen!.cancel();
    _debounceTimerOrigen = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(appLogicProvider.notifier).usuarioEscribioEnCampoOrigen(query);
      // Las sugerencias se actualizarán a través del watch en `build` y `addPostFrameCallback`
      // que llamará a _updateOrigenSuggestions si es necesario.
    });
  }

  void _onDestinoChanged(String query) {
    if (_debounceTimerDestino?.isActive ?? false)
      _debounceTimerDestino!.cancel();
    _debounceTimerDestino = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(appLogicProvider.notifier).usuarioEscribioEnCampoDestino(query);
      // Similar a origen, el watch se encargará de llamar a _updateDestinoSuggestions.
    });
  }

  OverlayEntry _createSuggestionsOverlayEntry({
    required BuildContext context,
    required List<SugerenciaLugar> suggestions,
    required Function(SugerenciaLugar) onSelected,
    required LayerLink layerLink,
    required TextEditingController controller, // Para obtener el ancho
  }) {
    final RenderBox textFieldRenderBox =
        context.findRenderObject() as RenderBox;
    final textFieldWidth = textFieldRenderBox.size.width;

    return OverlayEntry(
      builder:
          (context) => Positioned(
            width:
                textFieldWidth, // Hacer que el overlay tenga el mismo ancho que el TextField
            child: CompositedTransformFollower(
              link: layerLink,
              showWhenUnlinked: false,
              offset: const Offset(
                0.0,
                kToolbarHeight / 2 + 8,
              ), // Ajustar offset según sea necesario
              child: Material(
                // Material para que el texto y los temas funcionen correctamente
                elevation: 4.0, // Sombra similar al Card
                borderRadius: BorderRadius.circular(8.0),
                child: Container(
                  // Este es el contenedor que antes estaba en _buildSuggestionsList
                  constraints: const BoxConstraints(
                    maxHeight: 200,
                  ), // Aumentado un poco
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor, // Usar color del tema
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8.0),
                    // La sombra ya está en Material, podemos quitarla de aquí si se duplica
                    // boxShadow: [
                    //   BoxShadow(
                    //     color: Colors.grey.withOpacity(0.2),
                    //     spreadRadius: 1,
                    //     blurRadius: 3,
                    //     offset: const Offset(0, 2),
                    //   ),
                    // ],
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: suggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = suggestions[index];
                      return ListTile(
                        title: Text(
                          suggestion.nombreLugar ?? suggestion.nombreCompleto,
                        ),
                        subtitle: Text(suggestion.direccion ?? ''),
                        onTap: () {
                          onSelected(suggestion);
                          // Los overlays se removerán en las funciones de onSelected
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
    );
  }

  void _updateOrigenSuggestions() {
    if (!mounted ||
        !_origenFocusNode.hasFocus ||
        _origenController.text.isEmpty) {
      _removeOrigenSuggestionsOverlay();
      return;
    }
    final appState = ref.read(appLogicProvider);
    if (appState.sugerenciasOrigen != null &&
        appState.sugerenciasOrigen!.isNotEmpty) {
      _removeOrigenSuggestionsOverlay(); // Remover el anterior si existe
      _origenSuggestionsOverlayEntry = _createSuggestionsOverlayEntry(
        context:
            context, // Usar el context del TextField/CompositedTransformTarget
        suggestions: appState.sugerenciasOrigen!,
        onSelected: (sugerencia) {
          final logicNotifier = ref.read(appLogicProvider.notifier);
          logicNotifier.seleccionarSugerenciaOrigen(sugerencia);
          _origenController.text = sugerencia.nombreCompleto;
          _origenFocusNode
              .unfocus(); // Esto llamará a _handleOrigenFocusChange que quitará el overlay.
          // _removeOrigenSuggestionsOverlay(); // Ya no es necesario aquí explícitamente.
        },
        layerLink: _origenLayerLink,
        controller: _origenController,
      );
      Overlay.of(context).insert(_origenSuggestionsOverlayEntry!);
    } else {
      _removeOrigenSuggestionsOverlay();
    }
  }

  void _updateDestinoSuggestions() {
    if (!mounted ||
        !_destinoFocusNode.hasFocus ||
        _destinoController.text.isEmpty) {
      _removeDestinoSuggestionsOverlay();
      return;
    }
    final appState = ref.read(appLogicProvider);
    if (appState.sugerenciasDestino != null &&
        appState.sugerenciasDestino!.isNotEmpty) {
      _removeDestinoSuggestionsOverlay();
      _destinoSuggestionsOverlayEntry = _createSuggestionsOverlayEntry(
        context: context,
        suggestions: appState.sugerenciasDestino!,
        onSelected: (sugerencia) {
          final logicNotifier = ref.read(appLogicProvider.notifier);
          logicNotifier.seleccionarSugerenciaDestino(sugerencia);
          _destinoController.text = sugerencia.nombreCompleto;
          _destinoFocusNode.unfocus();
          // _removeDestinoSuggestionsOverlay();
        },
        layerLink: _destinoLayerLink,
        controller: _destinoController,
      );
      Overlay.of(context).insert(_destinoSuggestionsOverlayEntry!);
    } else {
      _removeDestinoSuggestionsOverlay();
    }
  }

  @override
  void dispose() {
    _removeOrigenSuggestionsOverlay();
    _removeDestinoSuggestionsOverlay();
    _origenController.dispose();
    _destinoController.dispose();
    _origenFocusNode.removeListener(_handleOrigenFocusChange);
    _destinoFocusNode.removeListener(_handleDestinoFocusChange);
    _origenFocusNode.dispose();
    _destinoFocusNode.dispose();
    _debounceTimerOrigen?.cancel();
    _debounceTimerDestino?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appLogicProvider);
    final logicNotifier = ref.read(appLogicProvider.notifier);

    // Reaccionar a los cambios en las sugerencias del estado de la app
    // Esto se llama cada vez que appState cambia.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Si el foco está y el texto no está vacío, intenta actualizar/mostrar.
      if (_origenFocusNode.hasFocus && _origenController.text.isNotEmpty) {
        _updateOrigenSuggestions();
      }
      if (_destinoFocusNode.hasFocus && _destinoController.text.isNotEmpty) {
        _updateDestinoSuggestions();
      }
    });

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: SingleChildScrollView(
          // Mantenemos SingleChildScrollView por si el contenido del Card en sí mismo es grande
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 20.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CompositedTransformTarget(
                  // Envolver el TextField con CompositedTransformTarget
                  link: _origenLayerLink,
                  child: TextField(
                    controller: _origenController,
                    focusNode: _origenFocusNode,
                    onChanged: _onOrigenChanged,
                    decoration: InputDecoration(
                      labelText: 'Origen',
                      hintText: 'Escribe una dirección o lugar',
                      prefixIcon: const Icon(Icons.looks_one),
                      suffixIcon:
                          _origenController.text.isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _origenController.clear();
                                  logicNotifier.usuarioEscribioEnCampoOrigen(
                                    '',
                                  );
                                  _removeOrigenSuggestionsOverlay(); // Asegurarse de quitar el overlay
                                },
                              )
                              : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16.0), // Espacio entre los TextFields
                CompositedTransformTarget(
                  link: _destinoLayerLink,
                  child: TextField(
                    controller: _destinoController,
                    focusNode: _destinoFocusNode,
                    onChanged: _onDestinoChanged,
                    decoration: InputDecoration(
                      labelText: 'Destino',
                      hintText: 'Escribe una dirección o lugar',
                      prefixIcon: const Icon(Icons.looks_two),
                      suffixIcon:
                          _destinoController.text.isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _destinoController.clear();
                                  logicNotifier.usuarioEscribioEnCampoDestino(
                                    '',
                                  );
                                  _removeDestinoSuggestionsOverlay();
                                },
                              )
                              : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    textStyle: const TextStyle(fontSize: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  onPressed:
                      (appState.puntoOrigenParaBusqueda != null &&
                              appState.puntoDestinoParaBusqueda != null)
                          ? () {
                            _origenFocusNode.unfocus();
                            _destinoFocusNode.unfocus();
                            logicNotifier.iniciarBusquedaDeRutas();
                          }
                          : null, // Deshabilitado si no hay origen y destino
                  child: const Text('Buscar Ruta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
