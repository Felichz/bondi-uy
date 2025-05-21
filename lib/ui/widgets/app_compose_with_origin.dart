import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart'; // Para SugerenciaLugar y EstadoSolicitud
// TODO: Importar IAppLogic y su provider
// Ejemplo: import 'package:bondi_uy/backend/contrato_ui/app_logic_interface.dart';
// Ejemplo: import 'package:bondi_uy/backend/providers/app_logic_provider.dart';

class AppComposeWithOrigin extends ConsumerWidget {
  // TODO: Adaptar los parámetros para recibir del AppUiState:
  // - Texto inicial del campo (en lugar de TextEditingController interno)
  // - Lista de sugerencias (SugerenciaLugar)
  // - Estado de las sugerencias (EstadoSolicitud: CARGANDO, ERROR, EXITO, INICIAL)
  // - El tipo de campo (origen/destino) para saber qué acción de IAppLogic llamar.
  // Y para las acciones, recibir callbacks o usar ref.read(appLogicProvider)

  final String hintText;
  final String currentText; // Texto actual desde AppUiState
  final List<SugerenciaLugar> suggestions; // Sugerencias desde AppUiState
  final EstadoSolicitud suggestionsState; // Estado desde AppUiState (Corregido)
  final void Function(String) onTextChanged; // Callback para escribir
  final void Function(SugerenciaLugar)
  onSuggestionSelected; // Callback para seleccionar
  final void Function() onClear; // Callback para limpiar
  final bool autoFocus; // ¿Debería tener autofocus?
  final FocusNode? focusNode; // Añadir FocusNode aquí

  const AppComposeWithOrigin({
    super.key,
    required this.hintText,
    required this.currentText,
    required this.suggestions,
    required this.suggestionsState,
    required this.onTextChanged,
    required this.onSuggestionSelected,
    required this.onClear,
    this.autoFocus = false,
    this.focusNode, // Añadir a constructor
  });

  // TODO: Adaptar _buildHighlightedText si es necesario (probablemente no cambie)
  Widget _buildHighlightedText(String text, String query) {
    // Implementación copiada de old/lib/widgets/compose_with_origin.dart
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // No necesitamos TextEditingController interno, TypeAheadField puede manejarlo con initialValue
    // Pero usaremos el builder para tener control del TextField.

    // TODO: Leer IAppLogic provider
    // final appLogic = ref.read(appLogicProvider);

    return TypeAheadField<SugerenciaLugar>(
      // Usar initialValue si es necesario o manejar a través del builder controller
      // initialValue: currentText, // Considerar usar esto si TypeAheadField lo soporta bien con un controller externo/builder

      // Usamos el builder para pasar nuestro currentText y manejar los cambios
      builder: (context, controller, focusNode) {
        // Sincronizar el controller interno con el texto que viene del estado
        // Solo actualizar si el texto del estado es diferente para evitar loops
        if (controller.text != currentText) {
          controller.text =
              currentText; // Esto puede causar problemas de selección/cursor si no se maneja bien
          // Una alternativa es usar un TextEditingController pasado desde el padre que observe el estado
        }

        return TextField(
          controller:
              controller, // Usar el controller proporcionado por TypeAheadField
          focusNode:
              this.focusNode ??
              focusNode, // Usar el focusNode pasado si existe, sino el del builder
          autofocus: autoFocus,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: hintText,
            border:
                OutlineInputBorder(), // Mantener el estilo original o adaptar
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              vertical: 12.0,
              horizontal: 10.0,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Indicador de carga
                if (suggestionsState == EstadoSolicitud.CARGANDO) // Corregido
                  Container(
                    width: 24,
                    height: 24,
                    padding: const EdgeInsets.all(4.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                // Botón de limpiar
                if (currentText.isNotEmpty &&
                    suggestionsState !=
                        EstadoSolicitud
                            .CARGANDO) // Mostrar limpiar solo si hay texto y no cargando (Corregido)
                  IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: () {
                      controller.clear();
                      onClear(); // Llamar al callback de limpiar que notificará a la lógica
                      // No necesitamos focusNode.requestFocus() aquí, la lógica decidirá
                    },
                  ),
              ],
            ),
          ),
          // Listener para cuando el texto cambia
          onChanged:
              onTextChanged, // Llamar al callback que notificará a la lógica
        );
      },

      // suggestionsCallback ya no necesita hacer el fetch, solo retornar las sugerencias del estado
      suggestionsCallback: (pattern) async {
        // El pattern ya está implícito en currentText, pero TypeAheadField lo requiere.
        // Simplemente retornamos las sugerencias actuales del estado.
        // No necesitamos async si no hay fetch.
        return suggestions; // Retornar la lista de SugerenciaLugar del estado
      },

      itemBuilder: (context, SugerenciaLugar suggestion) {
        // Usar la SugerenciaLugar para construir el ListTile
        return ListTile(
          // Mostrar el place_name o la descripción de la sugerencia
          title: _buildHighlightedText(
            suggestion.nombreCompleto, // Corregido: usar nombreCompleto
            currentText, // Texto actual para resaltar
          ),
          // subtitle: Text(suggestion.direccion ?? ''), // Si existe y se quiere mostrar
        );
      },

      onSelected: (SugerenciaLugar suggestion) {
        // Al seleccionar, notificar a la lógica con la sugerencia completa
        onSuggestionSelected(suggestion);
        // La lógica actualizará el estado y el texto del campo a través de currentText
        // No necesitamos setear controller.text = suggestion.placeName aquí, ya que viene del estado.
        // Ni ocultar el overlay o unfocus; la lógica lo maneja al actualizar el estado.
      },

      // Opcional: para mostrar un indicador de no sugerencias o error
      // Comentados temporalmente por posibles problemas de compatibilidad de la versión de TypeAheadField
      // noItemsFoundBuilder: (context) {
      //    if (suggestionsState == EstadoSolicitud.ERROR) {
      //       return Padding(padding: const EdgeInsets.all(8.0), child: Text('Error al cargar sugerencias.', style: TextStyle(color: Colors.red)));
      //    } else if (suggestionsState == EstadoSolicitud.EXITO && suggestions.isEmpty && currentText.length >= 3) {
      //       return Padding(padding: const EdgeInsets.all(8.0), child: Text('No se encontraron sugerencias.'));
      //    }
      //    return SizedBox.shrink(); // No mostrar nada en otros estados
      // },
      //  loadingBuilder: (context) {
      //    // El indicador de carga ya está en el suffixIcon, así que no mostramos otro aquí
      //    return SizedBox.shrink();
      //  },
    );
  }

  // Helper para convertir SugerenciaLugar a texto para el campo (si TypeAheadField lo necesitara)
  // String _suggestionToText(SugerenciaLugar suggestion) {
  //   return suggestion.nombreCompleto; // O la representación deseada
  // }
}
