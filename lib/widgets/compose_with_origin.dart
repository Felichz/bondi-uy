import 'dart:async';

import 'package:flutter/material.dart';
// TODO: Es probable que necesitemos importar servicios aquí si _fetchSuggestions los usa directamente.
// Por ahora, asumimos que _geocodingService es accesible a través de una instancia global o pasada.
// Si _geocodingService es una variable global definida en main.dart, necesitaremos una forma de acceder a ella.
// Una mejor práctica sería pasar GeocodingService como parámetro al widget o usar un gestor de estado.
// Por el momento, voy a asumir que está global o que se ajustará después.
// import '../services/geocoding_service.dart'; // Potencial import
// import '../main.dart'; // Necesario si _geocodingService es global en main.dart

// Estas son las variables globales de main.dart que _ComposeWithOriginState usa.
// Se deberán pasar como parámetros o acceder de otra forma.
// GeocodingService? _geocodingService;

class ComposeWithOrigin extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String labelText;
  final String hintText;
  final Function(String place, List<dynamic> center) onLocationSelected;
  // AÑADIDO: Para pasar el servicio de geocodificación
  final dynamic
  geocodingService; // Usar dynamic temporalmente, idealmente sería GeocodingService

  const ComposeWithOrigin({
    Key? key,
    required this.controller,
    required this.focusNode,
    this.labelText = 'Origen',
    this.hintText = 'Escribe una dirección o lugar de origen',
    required this.onLocationSelected,
    required this.geocodingService, // AÑADIDO
  }) : super(key: key);

  @override
  _ComposeWithOriginState createState() => _ComposeWithOriginState();
}

class _ComposeWithOriginState extends State<ComposeWithOrigin> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  Timer? _debounceTimer;
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      if (!widget.focusNode.hasFocus) {
        _hideOverlay();
      } else if (widget.controller.text.length >= 3) {
        _fetchSuggestions(widget.controller.text);
      }
    });

    widget.controller.addListener(() {
      if (widget.focusNode.hasFocus && widget.controller.text.length >= 3) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 500), () {
          _fetchSuggestions(widget.controller.text);
        });
      } else if (widget.controller.text.length < 3) {
        _hideOverlay();
      }
    });
  }

  @override
  void dispose() {
    _hideOverlay();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.length < 3) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // MODIFICADO: Usar widget.geocodingService
      if (widget.geocodingService == null) {
        print(
          "[BondiUY_Debug] GeocodingService no proporcionado a ComposeWithOrigin.",
        );
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final List<Map<String, dynamic>> features = await widget.geocodingService!
          .fetchSuggestions(query);

      _suggestions = List<Map<String, dynamic>>.from(
        features.map(
          (feature) => {
            'place_name': feature['place_name_es'] ?? feature['place_name'],
            'text_street': feature['text_es'] ?? feature['text'],
            'address_number': feature['address'],
            'center': feature['center'],
          },
        ),
      );

      print(
        "[BondiUY_Debug] ${_suggestions.length} sugerencias obtenidas para '$query'",
      );

      if (_suggestions.isNotEmpty) {
        _showOverlay();
      } else {
        _hideOverlay();
      }
    } catch (e) {
      print("[BondiUY_Debug] Error obteniendo sugerencias: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) {
      _hideOverlay();
    }

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            width: size.width,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0.0, size.height),
              child: Material(
                elevation: 4.0,
                child: Container(
                  constraints: BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _suggestions[index];
                      final String displayNameInList =
                          suggestion['place_name'] ?? '';

                      final String? textStreet =
                          suggestion['text_street'] as String?;
                      final dynamic addressNumberRaw =
                          suggestion['address_number'];
                      final String? addressNumber =
                          addressNumberRaw?.toString();

                      String valueForTextField;

                      if (textStreet != null && textStreet.isNotEmpty) {
                        if (addressNumber != null && addressNumber.isNotEmpty) {
                          if (textStreet.endsWith(" $addressNumber") ||
                              textStreet == addressNumber) {
                            valueForTextField = textStreet;
                          } else {
                            valueForTextField = "$textStreet $addressNumber";
                          }
                        } else {
                          valueForTextField = textStreet;
                        }
                      } else {
                        valueForTextField = displayNameInList;
                      }

                      return ListTile(
                        title: _buildHighlightedText(
                          displayNameInList,
                          widget.controller.text,
                        ),
                        onTap: () {
                          _debounceTimer?.cancel();
                          widget.controller.text = valueForTextField;
                          widget.onLocationSelected(
                            valueForTextField,
                            suggestion['center'],
                          );
                          _hideOverlay();
                          widget.focusNode.unfocus();
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            vertical: 12.0,
            horizontal: 10.0,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoading)
                Container(
                  width: 24,
                  height: 24,
                  padding: const EdgeInsets.all(4.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              if (widget.controller.text.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    widget.controller.clear();
                    _hideOverlay();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.length < 3) return Text(text);

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
              style: TextStyle(color: Colors.black),
            ),
          );
        }

        spans.add(
          TextSpan(
            text: text.substring(start, end),
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
          ),
        );

        lastEnd = end;
      }

      if (lastEnd < text.length) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd),
            style: TextStyle(color: Colors.black),
          ),
        );
      }

      return RichText(
        text: TextSpan(children: spans, style: TextStyle(fontSize: 14.0)),
        overflow: TextOverflow.ellipsis,
      );
    } catch (e) {
      print("[BondiUY_Debug] Error resaltando texto: $e");
      return Text(text);
    }
  }
}
