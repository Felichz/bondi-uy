import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import 'package:bondi_uy/backend/providers/app_logic_provider.dart';
import 'package:bondi_uy/map_manager/map_manager.dart';
import 'package:bondi_uy/ui/app_host.dart'; // Para acceder al mapManagerProvider

class RouteOptionsOverlay extends ConsumerStatefulWidget {
  final MapboxMap? mapboxMap;

  const RouteOptionsOverlay({super.key, required this.mapboxMap});

  @override
  ConsumerState<RouteOptionsOverlay> createState() =>
      _RouteOptionsOverlayState();
}

class _RouteOptionsOverlayState extends ConsumerState<RouteOptionsOverlay> {
  late PageController _pageController;
  int _currentOptionIndex = 0;
  bool _hasInitializedRecommendedOption = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentOptionIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCarousel();
    });
  }

  void _initializeCarousel() {
    final appUiState = ref.read(appLogicProvider);
    final routeOptionsState = appUiState.datosFaseOpcionesRuta;

    print(
      "[RouteOptionsOverlay] _initializeCarousel - opciones disponibles: ${routeOptionsState?.opcionesDeRuta.length ?? 'null'}",
    );

    if (routeOptionsState != null &&
        routeOptionsState.opcionesDeRuta.isNotEmpty) {
      print(
        "[RouteOptionsOverlay] Inicializando carousel con opción $_currentOptionIndex",
      );
      // Solo mostrar el preview inicial - la corrección del índice se maneja en didUpdateWidget
      _showInitialPreview();
    }
  }

  void _showInitialPreview() {
    // Primer intento inmediato
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        print("[RouteOptionsOverlay] Primer intento de preview inicial");
        _showRoutePreview(_currentOptionIndex);
      }
    });

    // Segundo intento con más delay para asegurar que el mapa esté listo
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        print("[RouteOptionsOverlay] Segundo intento de preview inicial");
        _showRoutePreview(_currentOptionIndex);
      }
    });

    // Tercer intento como backup
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        print("[RouteOptionsOverlay] Tercer intento de preview inicial");
        _showRoutePreview(_currentOptionIndex);
      }
    });
  }

  @override
  void didUpdateWidget(RouteOptionsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Si el mapa cambió, reinicializar
    if (oldWidget.mapboxMap != widget.mapboxMap) {
      print("[RouteOptionsOverlay] Mapa cambió, reinicializando...");
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showRoutePreview(_currentOptionIndex);
        }
      });
    }

    // Solo detectar cuando las opciones se cargan por primera vez (no cada cambio)
    if (!_hasInitializedRecommendedOption) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final appUiState = ref.read(appLogicProvider);
        final routeOptionsState = appUiState.datosFaseOpcionesRuta;

        if (routeOptionsState != null &&
            routeOptionsState.opcionesDeRuta.isNotEmpty) {
          // Buscar la opción recomendada
          final recommendedIndex = routeOptionsState.opcionesDeRuta.indexWhere(
            (opt) => opt.esRecomendada,
          );
          final correctIndex = recommendedIndex >= 0 ? recommendedIndex : 0;

          print(
            "[RouteOptionsOverlay] Primera carga de opciones. Índice recomendado: $correctIndex",
          );
          print("[RouteOptionsOverlay] Índice actual: $_currentOptionIndex");

          // Marcar como inicializado para evitar futuras correcciones
          _hasInitializedRecommendedOption = true;

          // Si el índice cambió, actualizar
          if (_currentOptionIndex != correctIndex) {
            print(
              "[RouteOptionsOverlay] Corrigiendo índice de $_currentOptionIndex a $correctIndex",
            );

            setState(() {
              _currentOptionIndex = correctIndex;
            });

            // Actualizar el PageController
            if (_pageController.hasClients) {
              _pageController.animateToPage(
                _currentOptionIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          }

          // SIEMPRE mostrar el preview inicial cuando se cargan las opciones por primera vez
          print(
            "[RouteOptionsOverlay] Mostrando preview inicial para índice: $_currentOptionIndex",
          );
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) {
              _showRoutePreview(_currentOptionIndex);
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showRoutePreview(int optionIndex) {
    final appUiState = ref.read(appLogicProvider);
    final routeOptionsState = appUiState.datosFaseOpcionesRuta;

    print(
      "[RouteOptionsOverlay] _showRoutePreview llamado para índice $optionIndex",
    );

    if (routeOptionsState == null) {
      print("[RouteOptionsOverlay] ERROR: routeOptionsState es null");
      return;
    }

    if (optionIndex < 0 ||
        optionIndex >= routeOptionsState.opcionesDeRuta.length) {
      print(
        "[RouteOptionsOverlay] ERROR: índice $optionIndex fuera de rango (0-${routeOptionsState.opcionesDeRuta.length - 1})",
      );
      return;
    }

    final option = routeOptionsState.opcionesDeRuta[optionIndex];
    print(
      "[RouteOptionsOverlay] Mostrando preview para opción: ${option.idOpcion}",
    );

    // Notificar a la lógica cual opción está siendo previsualizada
    ref
        .read(appLogicProvider.notifier)
        .seleccionarOpcionDeRutaParaPrevisualizar(option.idOpcion);

    // Mostrar preview en el mapa usando MapManager
    _displayRoutePreview(option);
  }

  Future<void> _displayRoutePreview(OpcionDeRutaMostrable ruta) async {
    print(
      "[RouteOptionsOverlay] Iniciando _displayRoutePreview para ruta: ${ruta.idOpcion}",
    );

    // Obtener MapManager del provider
    final mapManager = ref.read(mapManagerProvider);
    if (mapManager == null) {
      print("[RouteOptionsOverlay] ERROR: MapManager no disponible");
      return;
    }

    try {
      // Usar MapManager para mostrar el preview
      await mapManager.showRoutePreview(ruta);
      print("[RouteOptionsOverlay] Preview de ruta completado exitosamente");
    } catch (e) {
      print("[RouteOptionsOverlay] Error en _displayRoutePreview: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUiState = ref.watch(appLogicProvider);
    final appLogic = ref.read(appLogicProvider.notifier);
    final routeOptionsState = appUiState.datosFaseOpcionesRuta;

    // LISTENER para cambios en idOpcionRutaPrevisualizada del backend
    ref.listen(
      appLogicProvider.select((state) => state.idOpcionRutaPrevisualizada),
      (previous, next) {
        print(
          "[RouteOptionsOverlay] idOpcionRutaPrevisualizada cambió de $previous a $next",
        );

        if (next != null) {
          final currentAppUiState = ref.read(appLogicProvider);
          final currentRouteOptionsState =
              currentAppUiState.datosFaseOpcionesRuta;

          if (currentRouteOptionsState != null) {
            // Encontrar el índice de la opción previsualizada en el backend
            final backendSelectedIndex = currentRouteOptionsState.opcionesDeRuta
                .indexWhere((opt) => opt.idOpcion == next);

            // Si encontramos la opción y es diferente a la actual en UI
            if (backendSelectedIndex >= 0 &&
                backendSelectedIndex != _currentOptionIndex) {
              print(
                "[RouteOptionsOverlay] Sincronizando UI con backend: $_currentOptionIndex -> $backendSelectedIndex",
              );

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _currentOptionIndex = backendSelectedIndex;
                  });

                  // Actualizar PageController para sincronizar UI
                  if (_pageController.hasClients) {
                    _pageController.animateToPage(
                      _currentOptionIndex,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                    );
                  }

                  // Actualizar preview del mapa
                  final option =
                      currentRouteOptionsState
                          .opcionesDeRuta[backendSelectedIndex];
                  _displayRoutePreview(option);
                }
              });
            }
          }
        }
      },
    );

    if (routeOptionsState == null || routeOptionsState.opcionesDeRuta.isEmpty) {
      return _buildEmptyState(appLogic);
    }

    final options = routeOptionsState.opcionesDeRuta;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Stack(
      children: [
        // El mapa toma todo el espacio disponible (está en AppHost)
        Container(),

        // Panel draggable colapsable
        DraggableScrollableSheet(
          initialChildSize:
              isSmallScreen
                  ? 0.6
                  : 0.5, // Completamente expandido desde el inicio
          minChildSize: 0.1, // Colapsado - solo handle visible
          maxChildSize: isSmallScreen ? 0.6 : 0.5, // Máximo expandido
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24.0),
                  topRight: Radius.circular(24.0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle para drag
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Contenido scrollable
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          _buildHeader(appLogic, isSmallScreen),

                          // Carousel con altura específica según contenido
                          SizedBox(
                            height: isSmallScreen ? 210 : 250,
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: options.length,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentOptionIndex = index;
                                });
                                _showRoutePreview(index);
                              },
                              itemBuilder: (context, index) {
                                final option = options[index];
                                return _buildModernRouteCard(
                                  option,
                                  index == _currentOptionIndex,
                                  isSmallScreen,
                                );
                              },
                            ),
                          ),

                          // Footer
                          _buildFooter(options, appLogic, isSmallScreen),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeader(AppLogicNotifier appLogic, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        isSmallScreen ? 16 : 20,
        24,
        isSmallScreen ? 12 : 16,
      ),
      child: Row(
        children: [
          // Icono y título
          Container(
            width: isSmallScreen ? 36 : 40,
            height: isSmallScreen ? 36 : 40,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.alt_route,
              color: Colors.blue,
              size: isSmallScreen ? 18 : 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Opciones de Viaje',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                    fontSize: isSmallScreen ? 18 : null,
                  ),
                ),
                Text(
                  'Elige la mejor ruta para ti',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontSize: isSmallScreen ? 11 : null,
                  ),
                ),
              ],
            ),
          ),
          // Botón cancelar minimalista
          GestureDetector(
            onTap: () => appLogic.usuarioCanceloBusquedaOSeleccionRuta(),
            child: Container(
              width: isSmallScreen ? 32 : 36,
              height: isSmallScreen ? 32 : 36,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 18),
              ),
              child: Icon(
                Icons.close,
                color: Colors.grey[600],
                size: isSmallScreen ? 16 : 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernRouteCard(
    OpcionDeRutaMostrable option,
    bool isSelected,
    bool isSmallScreen,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: isSmallScreen ? 6.0 : 10.0,
      ),
      padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.grey[200]!,
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow:
            isSelected
                ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header con duración y recomendación
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDuration(option.duracionTotalSegundos),
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.blue[700] : Colors.grey[800],
                        height: 1.0,
                        fontSize: isSmallScreen ? 24 : 28,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Llegada: ${TimeOfDay.fromDateTime(option.horaLlegadaEstimada).format(context)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                        fontSize: isSmallScreen ? 12 : 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (option.esRecomendada) ...[
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 10 : 12,
                    vertical: isSmallScreen ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'RECOMENDADA',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: isSmallScreen ? 9 : 10,
                    ),
                  ),
                ),
              ],
            ],
          ),

          SizedBox(height: isSmallScreen ? 16 : 20),

          // Iconos de modos de transporte
          _buildModernModeIcons(
            context,
            option.secuenciaModosIconos,
            isSelected,
            isSmallScreen,
          ),

          SizedBox(height: isSmallScreen ? 16 : 20),

          // Información detallada
          Wrap(
            spacing: 12,
            children: [
              // ETA del próximo bus
              if (option.etaProximoBus != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 10 : 12,
                    vertical: isSmallScreen ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        option.etaProximoBus!.esTiempoReal
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color:
                              option.etaProximoBus!.esTiempoReal
                                  ? Colors.green
                                  : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${option.etaProximoBus!.minutosParaLlegada} min',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color:
                              option.etaProximoBus!.esTiempoReal
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                          fontSize: isSmallScreen ? 12 : 13,
                        ),
                      ),
                    ],
                  ),
                ),

              // Distancia de caminata
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 10 : 12,
                  vertical: isSmallScreen ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.directions_walk,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${option.distanciaTotalCaminataMetros}m',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                        fontSize: isSmallScreen ? 12 : 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Padding bottom para que no esté pegado al borde
          SizedBox(height: isSmallScreen ? 12 : 16),
        ],
      ),
    );
  }

  Widget _buildModernModeIcons(
    BuildContext context,
    List<TipoTramoViaje> modos,
    bool isSelected,
    bool isSmallScreen,
  ) {
    List<Widget> icons = [];
    Color iconColor = isSelected ? Colors.blue[600]! : Colors.grey[600]!;
    final iconSize = isSmallScreen ? 40.0 : 48.0;
    final iconInnerSize = isSmallScreen ? 20.0 : 24.0;

    for (int i = 0; i < modos.length; i++) {
      if (modos[i] == TipoTramoViaje.ESPERAR_BUS) continue;

      IconData iconData;
      switch (modos[i]) {
        case TipoTramoViaje.CAMINAR:
          iconData = Icons.directions_walk;
          break;
        case TipoTramoViaje.VIAJE_EN_BUS:
          iconData = Icons.directions_bus;
          break;
        default:
          iconData = Icons.help_outline;
      }

      icons.add(
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 14),
            border: Border.all(color: iconColor.withOpacity(0.2), width: 1),
          ),
          child: Icon(iconData, color: iconColor, size: iconInnerSize),
        ),
      );

      if (i < modos.length - 1 && modos[i + 1] != TipoTramoViaje.ESPERAR_BUS) {
        icons.add(SizedBox(width: isSmallScreen ? 8 : 12));
        icons.add(
          Container(
            width: isSmallScreen ? 16 : 24,
            height: 2,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
        icons.add(SizedBox(width: isSmallScreen ? 8 : 12));
      }
    }

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: icons);
  }

  Widget _buildFooter(
    List<OpcionDeRutaMostrable> options,
    AppLogicNotifier appLogic,
    bool isSmallScreen,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        isSmallScreen ? 8 : 12,
        24,
        isSmallScreen ? 16 : 20,
      ),
      child: Row(
        children: [
          // Indicadores de página modernos
          Row(
            children: List.generate(options.length, (index) {
              bool isActive = index == _currentOptionIndex;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? (isSmallScreen ? 14 : 16) : 5,
                height: isSmallScreen ? 5 : 6,
                decoration: BoxDecoration(
                  color: isActive ? Colors.blue : Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),

          const Spacer(),

          // Botón de confirmación moderno
          ElevatedButton(
            onPressed: () {
              appLogic.confirmarOpcionDeRutaEIniciarViaje(
                options[_currentOptionIndex].idOpcion,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 20 : 24,
                vertical: isSmallScreen ? 10 : 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: isSmallScreen ? 16 : 18),
                SizedBox(width: isSmallScreen ? 4 : 6),
                Text(
                  'Confirmar',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: isSmallScreen ? 13 : 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLogicNotifier appLogic) {
    return Container(
      child: Column(
        children: [
          const Spacer(),
          Container(
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.route_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No se encontraron rutas',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Intenta con otras ubicaciones',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed:
                      () => appLogic.usuarioCanceloBusquedaOSeleccionRuta(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Nueva Búsqueda'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours h ${minutes} min';
    }
    return '$minutes min';
  }
}
