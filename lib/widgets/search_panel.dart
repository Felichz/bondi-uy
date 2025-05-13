import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../services/geocoding_service.dart';
import '../models/point_dart.dart';
// import 'compose_with_origin.dart'; // Eliminar, ya no se usa aquí
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/service_providers.dart'; // Importar para geocodingServiceProvider

// typedef OnLocationSelectedCallback = Function(String place, List<dynamic> center);
// typedef SearchRouteCallback = Future<void> Function();

class SearchPanel extends ConsumerStatefulWidget {
  final TextEditingController origenController;
  final TextEditingController destinoController;
  final FocusNode origenFocusNode;
  final FocusNode destinoFocusNode;
  final Point_dart? origenCoordinates; // Usar Point_dart
  final Point_dart? destinoCoordinates; // Usar Point_dart
  final GeocodingService geocodingService;
  final bool isCalculatingRoute;
  final VoidCallback onSearchRoute;
  final Function(Point_dart?) onOrigenSelected; // Usar Point_dart
  final Function(Point_dart?) onDestinoSelected; // Usar Point_dart
  final bool initialExpandedState;
  final VoidCallback onOrigenClear;
  final VoidCallback onDestinoClear;

  const SearchPanel({
    Key? key,
    required this.origenController,
    required this.destinoController,
    required this.origenFocusNode,
    required this.destinoFocusNode,
    this.origenCoordinates,
    this.destinoCoordinates,
    required this.geocodingService,
    required this.isCalculatingRoute,
    required this.onSearchRoute,
    required this.onOrigenSelected,
    required this.onDestinoSelected,
    this.initialExpandedState = false, // Por defecto no expandido
    required this.onOrigenClear,
    required this.onDestinoClear,
  }) : super(key: key);

  @override
  ConsumerState<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends ConsumerState<SearchPanel> {
  late bool _isSearchPanelExpanded;

  @override
  void initState() {
    super.initState();
    _isSearchPanelExpanded = widget.initialExpandedState;
  }

  @override
  void didUpdateWidget(SearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si la propiedad que indica si debe estar expandido cambió...
    if (widget.initialExpandedState != oldWidget.initialExpandedState) {
      // ... y el widget todavía está montado...
      if (mounted) {
        // ... actualizar el estado interno para que coincida.
        setState(() {
          _isSearchPanelExpanded = widget.initialExpandedState;
        });
      }
    }
  }

  // Método para alternar la expansión
  void _toggleSearchPanel() {
    setState(() {
      _isSearchPanelExpanded = !_isSearchPanelExpanded;
    });
  }

  // Widget para decidir qué panel de búsqueda mostrar
  Widget _buildTopSearchPanel() {
    if (_isSearchPanelExpanded) {
      return _buildExpandedSearchPanelUI();
    } else {
      return _buildCompactSearchPanelUI();
    }
  }

  // Widget para el panel de búsqueda compacto
  Widget _buildCompactSearchPanelUI() {
    return Card(
      margin: const EdgeInsets.fromLTRB(
        8.0,
        8.0,
        8.0,
        0,
      ), // margen solo arriba y costados
      elevation: 3.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: InkWell(
        onTap: _toggleSearchPanel, // Usar el método para alternar
        borderRadius: BorderRadius.circular(10.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
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
                  widget.origenController.text.isNotEmpty
                      ? widget.origenController.text
                      : "Origen",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_right_alt, size: 22, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Icon(
                Icons.flag_outlined,
                size: 22,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.destinoController.text.isNotEmpty
                      ? widget.destinoController.text
                      : "Destino",
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
                onPressed: _toggleSearchPanel, // Usar el método para alternar
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget para el panel de búsqueda expandido
  Widget _buildExpandedSearchPanelUI() {
    return Card(
      margin: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 8.0),
      elevation: 3.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: Container(
        padding: const EdgeInsets.only(top: 8.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    " Planifica tu Viaje",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Solo mostrar la flecha para colapsar si ambos campos tienen texto
                  // o si se desea que siempre esté visible cuando está expandido.
                  // Por ahora, se muestra si está expandido y los campos no están vacíos (para permitir colapsar después de buscar)
                  if (widget.origenController.text.isNotEmpty &&
                      widget.destinoController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up, size: 28),
                      tooltip: "Colapsar",
                      onPressed:
                          _toggleSearchPanel, // Usar el método para alternar
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 4.0),
              child: _buildTypeAheadField(
                controller: widget.origenController,
                focusNode: widget.origenFocusNode,
                hintText: "Origen",
                onSelectedCallback: (Point_dart? point) {
                  widget.onOrigenSelected(point);
                  if (point != null) {
                    widget.destinoFocusNode.requestFocus();
                  }
                },
                onClear: widget.onOrigenClear,
                autoFocus: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 8.0),
              child: _buildTypeAheadField(
                controller: widget.destinoController,
                focusNode: widget.destinoFocusNode,
                hintText: "Destino",
                onSelectedCallback: (Point_dart? point) {
                  widget.onDestinoSelected(point);
                  if (point != null) {
                    FocusScope.of(context).unfocus();
                  }
                },
                onClear: widget.onDestinoClear,
                autoFocus: false,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 12,
                  ),
                ),
                onPressed:
                    (widget.isCalculatingRoute ||
                            widget.origenCoordinates == null ||
                            widget.destinoCoordinates == null)
                        ? null
                        : () {
                          widget.onSearchRoute();
                          // Considerar si colapsar automáticamente después de buscar
                          // if (_isSearchPanelExpanded) {
                          //   _toggleSearchPanel();
                          // }
                        },
                child:
                    widget.isCalculatingRoute
                        ? const SizedBox(
                          height: 20.0,
                          width: 20.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            color: Colors.white,
                          ),
                        )
                        : const Text(
                          'Buscar Ruta',
                          style: TextStyle(fontSize: 16),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildTopSearchPanel(); // Este método ahora decide qué UI mostrar
  }

  // Este es el método que CONSTRUYE el campo de búsqueda
  Widget _buildTypeAheadField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required Function(Point_dart?) onSelectedCallback,
    required VoidCallback onClear,
    required bool autoFocus,
  }) {
    return TypeAheadField<Map<String, dynamic>>(
      controller: controller,
      focusNode: focusNode,
      builder: (context, controller, focusNode) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: autoFocus,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: hintText,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 15),
            suffixIcon:
                controller.text.isNotEmpty
                    ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        controller.clear();
                        onClear();
                        focusNode.requestFocus();
                      },
                    )
                    : null,
          ),
        );
      },
      suggestionsCallback: (pattern) async {
        if (pattern.isEmpty) {
          return [];
        }
        final geocodingService = ref.read(geocodingServiceProvider);
        return await geocodingService.fetchSuggestions(pattern);
      },
      itemBuilder: (context, Map<String, dynamic> suggestion) {
        return ListTile(
          title: Text(suggestion['place_name'] ?? 'Sugerencia inválida'),
        );
      },
      onSelected: (Map<String, dynamic> suggestion) {
        final String label = suggestion['place_name'] ?? '';
        controller.text = label;
        Point_dart? point;
        final coordinates = suggestion['geometry']?['coordinates'];
        if (coordinates != null && coordinates.length == 2) {
          point = Point_dart(lat: coordinates[1], lng: coordinates[0]);
        }
        onSelectedCallback(point);
      },
    );
  }

  // Helper para convertir sugerencia a Point_dart
  Point_dart? _suggestionToPointDart(Map<String, dynamic> suggestion) {
    final List? center = suggestion['center'] as List?;
    if (center != null && center.length == 2) {
      final lon = center[0];
      final lat = center[1];
      if (lon is num && lat is num) {
        return Point_dart(lat: lat.toDouble(), lng: lon.toDouble());
      }
    }
    return null;
  }
}
