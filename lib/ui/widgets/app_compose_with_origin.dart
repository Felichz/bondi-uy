import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'dart:async';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart'; // Para SugerenciaLugar y EstadoSolicitud
// TODO: Importar IAppLogic y su provider
// Ejemplo: import 'package:bondi_uy/backend/contrato_ui/app_logic_interface.dart';
// Ejemplo: import 'package:bondi_uy/backend/providers/app_logic_provider.dart';

class AppComposeWithOrigin extends ConsumerStatefulWidget {
  final String hintText;
  final List<SugerenciaLugar> suggestions;
  final EstadoSolicitud suggestionsState;
  final void Function(String) onTextChanged;
  final void Function(SugerenciaLugar) onSuggestionSelected;
  final void Function() onClear;
  final bool autoFocus;
  final FocusNode? focusNode;
  final String? initialValue;

  const AppComposeWithOrigin({
    super.key,
    required this.hintText,
    required this.suggestions,
    required this.suggestionsState,
    required this.onTextChanged,
    required this.onSuggestionSelected,
    required this.onClear,
    this.autoFocus = false,
    this.focusNode,
    this.initialValue,
  });

  @override
  ConsumerState<AppComposeWithOrigin> createState() =>
      _AppComposeWithOriginState();
}

class _AppComposeWithOriginState extends ConsumerState<AppComposeWithOrigin> {
  final TextEditingController _controller = TextEditingController();
  final SuggestionsController<SugerenciaLugar> _suggestionsController =
      SuggestionsController<SugerenciaLugar>();
  late FocusNode _focusNode;
  Timer? _debounceTimer;
  String _lastSearchTerm = '';
  List<SugerenciaLugar> _lastKnownSuggestions = [];

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
  }

  @override
  void didUpdateWidget(AppComposeWithOrigin oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Solo actualizar si viene de una selección externa (el initialValue cambió)
    if (widget.initialValue != null &&
        widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue!;
      _lastSearchTerm = widget.initialValue!;
    }

    // Si las sugerencias cambiaron y tenemos texto, actualizar el controller manualmente
    if (widget.suggestions != _lastKnownSuggestions &&
        _controller.text.length >= 2) {
      print(
        "[AppComposeWithOrigin] Suggestions changed (${_lastKnownSuggestions.length} -> ${widget.suggestions.length}) - updating suggestions manually",
      );
      _lastKnownSuggestions = List.from(widget.suggestions);

      // Refreshar las sugerencias manualmente sin rebuild completo
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focusNode.hasFocus && _controller.text.length >= 2) {
          print(
            "[AppComposeWithOrigin] Refreshing suggestions for current text: '${_controller.text}'",
          );
          _suggestionsController.refresh();
        }
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _suggestionsController.dispose();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    // Cancelar el timer anterior
    _debounceTimer?.cancel();

    // Solo hacer búsqueda si el texto es diferente y tiene al menos 2 caracteres
    if (value != _lastSearchTerm && value.length >= 2) {
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          _lastSearchTerm = value;
          widget.onTextChanged(value);
          print("[AppComposeWithOrigin] Debounced search for: '$value'");
        }
      });
    } else if (value.length < 2 && _lastSearchTerm.isNotEmpty) {
      // Limpiar si el texto es muy corto
      _lastSearchTerm = '';
      widget.onClear();
    }
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.length < 2) return Text(text);

    try {
      final RegExp regExp = RegExp(RegExp.escape(query), caseSensitive: false);
      final List<TextSpan> spans = [];
      int lastEnd = 0;

      for (final match in regExp.allMatches(text)) {
        final start = match.start;
        final end = match.end;

        if (start > lastEnd) {
          spans.add(
            TextSpan(
              text: text.substring(lastEnd, start),
              style: const TextStyle(color: Colors.black),
            ),
          );
        }

        spans.add(
          TextSpan(
            text: text.substring(start, end),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        );

        lastEnd = end;
      }

      if (lastEnd < text.length) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd),
            style: const TextStyle(color: Colors.black),
          ),
        );
      }

      return RichText(
        text: TextSpan(children: spans, style: const TextStyle(fontSize: 14.0)),
        overflow: TextOverflow.ellipsis,
      );
    } catch (e) {
      return Text(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TypeAheadField<SugerenciaLugar>(
      controller: _controller,
      focusNode: _focusNode,
      suggestionsController: _suggestionsController,

      builder: (context, controller, focusNode) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: widget.autoFocus,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12.0,
              horizontal: 10.0,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.suggestionsState == EstadoSolicitud.CARGANDO)
                  Container(
                    width: 24,
                    height: 24,
                    padding: const EdgeInsets.all(4.0),
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (controller.text.isNotEmpty &&
                    widget.suggestionsState != EstadoSolicitud.CARGANDO)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.clear();
                      _lastSearchTerm = '';
                      widget.onClear();
                    },
                  ),
              ],
            ),
          ),
          onChanged: _onTextChanged, // Usar nuestro método con debounce
        );
      },

      suggestionsCallback: (pattern) async {
        print(
          "[AppComposeWithOrigin] suggestionsCallback with pattern='$pattern', available: ${widget.suggestions.length}",
        );

        // Si el pattern es muy corto, no mostrar sugerencias
        if (pattern.length < 2) {
          return <SugerenciaLugar>[];
        }

        // Si el pattern corresponde exactamente a alguna sugerencia conocida (selección previa),
        // no mostrar dropdown para evitar dropdown vacío
        final isExactMatch = widget.suggestions.any(
          (sug) => sug.nombreCompleto == pattern,
        );
        if (isExactMatch) {
          print(
            "[AppComposeWithOrigin] Pattern is exact match - hiding dropdown",
          );
          return <SugerenciaLugar>[];
        }

        // Devolver las sugerencias que tenemos disponibles
        print(
          "[AppComposeWithOrigin] Returning ${widget.suggestions.length} suggestions",
        );
        return widget.suggestions;
      },

      itemBuilder: (context, SugerenciaLugar suggestion) {
        return ListTile(
          title: _buildHighlightedText(
            suggestion.nombreCompleto,
            _controller.text,
          ),
        );
      },

      onSelected: (SugerenciaLugar suggestion) {
        print("[AppComposeWithOrigin] Selected: ${suggestion.nombreCompleto}");
        // El controller se actualizará automáticamente con el texto de la sugerencia
        _lastSearchTerm = suggestion.nombreCompleto;
        widget.onSuggestionSelected(suggestion);
      },
    );
  }
}
