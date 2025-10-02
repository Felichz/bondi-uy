import 'dart:convert';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:bondi_uy/backend/contrato_ui/app_ui_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'map_route_renderer.dart';
import 'package:bondi_uy/providers/app_providers.dart';
import 'map_bus_realtime.dart';
import 'map_icons_loader.dart';
import 'map_camera_controller.dart';
import 'map_cleanup.dart';
import 'package:bondi_uy/utils/feature_logger.dart';

/// Módulo unificado para el manejo completo del estado del mapa
/// Centraliza toda la lógica de renderizado, animaciones y estado
class MapManager {
  final MapboxMap? mapboxMap;
  final WidgetRef? ref;

  // Submódulos especializados
  late final MapRouteRenderer _routeRenderer;
  late final MapBusRealtime _busRealtime;
  late final MapIconsLoader _iconsLoader;
  late final MapCameraController _cameraController;
  late final MapCleanup _cleanup;

  // Estado interno
  bool _isInitialized = false;
  String? _currentPhase;
  List<String> _activeSources = [];
  List<String> _activeLayers = [];

  // Trackear la opción actualmente en preview para optimizar transiciones
  String? _currentPreviewOptionId;

  MapManager(this.mapboxMap, {this.ref}) {
    _routeRenderer = MapRouteRenderer(mapboxMap, this);
    _busRealtime = MapBusRealtime(mapboxMap, this);
    _iconsLoader = MapIconsLoader(mapboxMap, this);
    _cameraController = MapCameraController(mapboxMap, this);
    _cleanup = MapCleanup(mapboxMap, this);
  }

  /// Inicializar el manager (cargar iconos, configurar mapa)
  Future<void> initialize() async {
    if (_isInitialized || mapboxMap == null) return;

    print("[MapManager] Initializing map manager");

    try {
      await _iconsLoader.loadAllIcons();
      await _hideCityLabels();
      _isInitialized = true;
      print("[MapManager] Map manager initialized successfully");
    } catch (e) {
      print("[MapManager] Error initializing: $e");
      rethrow;
    }
  }

  /// Mostrar preview de ruta (para RouteOptionsOverlay)
  Future<void> showRoutePreview(OpcionDeRutaMostrable route) async {
    if (!_isInitialized) await initialize();

    print("[MapManager] Showing route preview for: ${route.idOpcion}");
    print("[MapManager] Current preview option: $_currentPreviewOptionId");
    print("[MapManager] Current phase: $_currentPhase");

    // Solo limpiar si es una opción diferente a la actual
    bool needsRedraw = false;
    if (_currentPreviewOptionId != route.idOpcion) {
      print(
        "[MapManager] Different option ($_currentPreviewOptionId → ${route.idOpcion}), clearing previous route",
      );
      await _cleanup.clearRoute();
      needsRedraw = true;
    } else {
      print(
        "[MapManager] Same option (${route.idOpcion}), keeping existing route",
      );
    }

    _currentPhase = 'route_preview';
    _currentPreviewOptionId = route.idOpcion;

    // Renderizar nueva ruta (solo si cambió o no hay capas)
    if (needsRedraw || _activeLayers.isEmpty) {
      print(
        "[MapManager] Rendering route (needsRedraw: $needsRedraw, activeLayers: ${_activeLayers.length})",
      );
      await _routeRenderer.renderRoute(route.tramosParaPreview);

      // Mostrar buses en tiempo real
      await _busRealtime.displayRealtimeBusesForPreview(route);
    } else {
      print("[MapManager] Skipping route rendering (already displayed)");
    }

    // Ajustar zoom
    await _cameraController.zoomToRoutePreview(route);
  }

  /// Mostrar viaje activo (para ActiveTripOverlay)
  Future<void> showActiveTrip(EstadoFaseViajeActivo activeTripState) async {
    if (!_isInitialized) await initialize();

    print("[MapManager] Showing active trip");
    print("[MapManager] Current phase: $_currentPhase");

    // OPTIMIZACIÓN: Si venimos del preview de la misma ruta, no redibujamos
    final isTransitionFromPreview = _currentPhase == 'route_preview';

    if (isTransitionFromPreview) {
      print(
        "[MapManager] ✅ OPTIMIZED TRANSITION: Keeping route elements (route_preview → active_trip)",
      );
      // Solo iniciar tracking sin redibujar
      await _startActiveTripTracking(activeTripState);
    } else {
      print(
        "[MapManager] 🔄 FULL REDRAW: Coming from different phase ($_currentPhase → active_trip)",
      );

      // Limpiar elementos anteriores
      await _cleanup.clearAll();

      // Renderizar ruta activa desde cero
      await _routeRenderer.renderRoute(activeTripState.tramosDelViaje);

      // Configurar tracking inicial
      await _busRealtime.initializeActiveTripTracking(activeTripState);
    }

    // Inicializar visualización de ubicación del usuario
    print(
      "[MapManager] 📍 Inicializando visualización de ubicación del usuario...",
    );
    await _initializeUserLocationVisualization();
    print("[MapManager] 📍 Visualización de ubicación inicializada");

    print("[MapManager] 🏁 Cambiando fase a 'active_trip'...");
    _currentPhase = 'active_trip';
    _currentPreviewOptionId = null; // Limpiar preview tracking
    print(
      "[MapManager] ✅ Fase cambiada a 'active_trip' - listo para recibir ubicaciones del usuario",
    );
  }

  /// Iniciar tracking para viaje activo (simplificado)
  Future<void> _startActiveTripTracking(
    EstadoFaseViajeActivo activeTripState,
  ) async {
    print("[MapManager] Starting active trip tracking");

    try {
      // 1) Detener animaciones del preview
      _busRealtime.stopPreviewAnimations();

      // 2) LIMPIEZA CRÍTICA: eliminar elementos de buses del preview
      //    para evitar que en active_trip se mezclen con los elementos "main".
      //    Esto previene que updateBusPosition escriba en fuentes/capas de preview
      //    y muestre buses de otros segmentos.
      await _cleanup.clearPreviewBusElements();

      // 3) Configurar tracking de bus para active trip
      await _busRealtime.initializeActiveTripTracking(activeTripState);

      // 4) Ajustar zoom para active trip
      await _cameraController.zoomToActiveTrip(activeTripState.tramosDelViaje);

      print("[MapManager] Successfully started active trip tracking");
    } catch (e) {
      print("[MapManager] Error starting active trip tracking: $e");
      // Si falla, hacer fallback a redibujado completo
      print("[MapManager] Falling back to full redraw");
      await _cleanup.clearAll();
      await _routeRenderer.renderRoute(activeTripState.tramosDelViaje);
      await _busRealtime.initializeActiveTripTracking(activeTripState);
    }
  }

  /// Actualizar tramo actual en viaje activo
  Future<void> updateCurrentLeg(
    int legIndex,
    List<TramoViajeMostrable> tramos,
  ) async {
    if (_currentPhase != 'active_trip') return;

    print("[MapManager] Updating current leg to: $legIndex");

    await _routeRenderer.highlightCurrentLeg(legIndex, tramos);
    await _cameraController.zoomToCurrentLeg(legIndex, tramos);
    await _busRealtime.updateBusTrackingForLeg(legIndex, tramos);
  }

  /// Actualizar posición de bus en tiempo real
  Future<void> updateBusPosition(
    Coordenada position,
    int etaMinutes,
    bool isRealTime,
  ) async {
    // Si estamos en RIDING_BUS y ya pegamos la ubicación del usuario al bus,
    // evitamos actualizar el símbolo de bus realtime para no alternar entre user y bus.
    bool skipBusSymbolUpdate = false;
    try {
      if (_currentPhase == 'active_trip' && ref != null) {
        final appState = ref!.read(appUiStateProvider);
        final currentStep = appState.currentJourneyStep;
        if (currentStep != null &&
            currentStep.type.toString().contains('RIDING_BUS')) {
          skipBusSymbolUpdate = true;
        }
      }
    } catch (_) {}
    if (!skipBusSymbolUpdate) {
      await _busRealtime.updateBusPosition(position, etaMinutes, isRealTime);
    }
    try {
      FeatureLogger().log(
        'journey',
        'bus_pos',
        data: {
          'lat': position.latitud,
          'lon': position.longitud,
          'eta': etaMinutes,
          'rt': isRealTime,
        },
      );
    } catch (_) {}
    // Cámara dinámica durante espera: si estamos en active_trip y el tramo actual es WAITING_FOR_BUS
    try {
      if (_currentPhase == 'active_trip' && ref != null) {
        final appState = ref!.read(
          appUiStateProvider,
        ); // requiere provider global
        final active = appState.datosFaseViajeActivo;
        final currentStep = appState.currentJourneyStep;
        if (active != null && currentStep != null) {
          if (currentStep.stepIndex < active.tramosDelViaje.length) {
            final tramo = active.tramosDelViaje[currentStep.stepIndex];
            if (tramo.tipo == TipoTramoViaje.ESPERAR_BUS && etaMinutes >= 0) {
              final userPos = getCurrentUserLocation();
              await _cameraController.updateWaitingBusViewport(
                waitingLeg: tramo,
                busPosition: position,
                userPosition: userPos,
              );
              FeatureLogger().camera(
                'dynamic_wait_viewport',
                data: {
                  'eta_min': etaMinutes,
                  'step': currentStep.stepIndex,
                  'hasUser': userPos != null,
                },
              );
            }
          }
        }
      }
    } catch (e) {
      FeatureLogger().camera(
        'dynamic_wait_viewport:error',
        data: {'e': e.toString()},
      );
    }
  }

  /// Mostrar fase inicial (para InitialPhaseOverlay)
  Future<void> showInitialPhase() async {
    if (!_isInitialized) await initialize();

    print("[MapManager] Showing initial phase");

    await _cleanup.clearAll();
    _currentPhase = 'initial';
    _currentPreviewOptionId = null;

    // TODO: Implementar renderizado de paradas de bus para fase inicial
    // await _routeRenderer.renderBusStops();
  }

  /// Limpiar todo el contenido del mapa
  Future<void> clearAll() async {
    print("[MapManager] Clearing all map content");
    await _cleanup.clearAll();
    _currentPhase = null;
    _currentPreviewOptionId = null;
  }

  /// Registrar fuente activa para tracking
  void registerSource(String sourceId) {
    if (!_activeSources.contains(sourceId)) {
      _activeSources.add(sourceId);
    }
  }

  /// Registrar capa activa para tracking
  void registerLayer(String layerId) {
    if (!_activeLayers.contains(layerId)) {
      _activeLayers.add(layerId);
    }
  }

  /// Obtener todas las fuentes activas
  List<String> get activeSources => List.unmodifiable(_activeSources);

  /// Obtener todas las capas activas
  List<String> get activeLayers => List.unmodifiable(_activeLayers);

  /// Limpiar registros de fuentes y capas
  void clearRegistrations() {
    _activeSources.clear();
    _activeLayers.clear();
  }

  /// Ocultar etiquetas de ciudad que interfieren
  Future<void> _hideCityLabels() async {
    if (mapboxMap == null) return;

    try {
      final labelLayerIds = [
        'settlement-major-label',
        'settlement-minor-label',
        'state-label',
        'country-label',
        'place-city-large-s',
        'place-city-medium-s',
        'place-city-small-s',
        'admin-1-boundary-label',
        'admin-0-boundary-label',
      ];

      for (String layerId in labelLayerIds) {
        try {
          if (await mapboxMap!.style.styleLayerExists(layerId)) {
            await mapboxMap!.style.setStyleLayerProperty(
              layerId,
              'visibility',
              'none',
            );
          }
        } catch (e) {
          // Continuar con el siguiente si este falla
        }
      }
    } catch (e) {
      print("[MapManager] Error hiding city labels: $e");
    }
  }

  /// Verificar si el manager está inicializado
  bool get isInitialized => _isInitialized;

  /// Obtener la fase actual
  String? get currentPhase => _currentPhase;

  /// Obtener posición actual del bus en tiempo real
  Coordenada? getCurrentBusPosition() {
    return _busRealtime.currentBusPosition;
  }

  // NUEVO: Notificar interacción manual del usuario con la cámara (gesto pan/zoom/rotate)
  void notifyUserCameraInteraction() {
    FeatureLogger().camera('gesture:camera_interaction');
    _cameraController.notifyManualInteraction();
  }

  // NUEVO: Fallback para style reload - re-crear capas críticas si desaparecieron
  Future<void> verifyAndRestoreStyleElements() async {
    if (mapboxMap == null) return;
    print(
      '[MapManager] 🔁 Verificando elementos críticos tras style reload...',
    );
    try {
      // Usuario
      const userSource = 'user-location-source';
      const userLayer = 'user-location-layer';
      final userSourceExists = await mapboxMap!.style.styleSourceExists(
        userSource,
      );
      final userLayerExists = await mapboxMap!.style.styleLayerExists(
        userLayer,
      );
      if (!userSourceExists || !userLayerExists) {
        print(
          '[MapManager] ♻️ Restaurando user location (source=$userSourceExists, layer=$userLayerExists)',
        );
        _currentUserLocation != null
            ? await updateUserLocationClean(_currentUserLocation!)
            : await _createUserLocationClean(userSource, userLayer, {
              'type': 'FeatureCollection',
              'features': [],
            });
      }

      // TODO: Agregar restauración de capas de ruta y buses si se detecta su ausencia
      // (Requiere conocer IDs exactos usados en MapRouteRenderer / MapBusRealtime)
    } catch (e) {
      print('[MapManager] ❌ Error en verifyAndRestoreStyleElements: $e');
    }
  }

  /// Almacenar y exponer ubicación actual del usuario para cálculos de cámara
  Coordenada? _currentUserLocation;
  Coordenada? getCurrentUserLocation() => _currentUserLocation;

  /// Inicializar visualización de ubicación del usuario
  Future<void> _initializeUserLocationVisualization() async {
    if (mapboxMap == null) return;

    print("[MapManager] Initializing user location visualization");

    try {
      // No cargar icono - usaremos CircleLayer directamente en updateUserLocation()
      print(
        "[MapManager] User location visualization initialized - using CircleLayer approach",
      );
    } catch (e) {
      print("[MapManager] Error initializing user location visualization: $e");
    }
  }

  /// Actualizar ubicación del usuario en el mapa
  Future<void> updateUserLocation(Coordenada userLocation) async {
    print("[MapManager] === INICIO ACTUALIZACIÓN UBICACIÓN USUARIO ===");
    print(
      "[MapManager] Ubicación recibida: ${userLocation.latitud}, ${userLocation.longitud}",
    );
    print("[MapManager] MapboxMap disponible: ${mapboxMap != null}");
    print("[MapManager] Fase actual: $_currentPhase");

    if (mapboxMap == null) {
      print("[MapManager] ❌ Condiciones no válidas para actualizar ubicación");
      print("[MapManager] MapboxMap nulo: ${mapboxMap == null}");
      return;
    }

    // CORREGIDO: Permitir ubicación del usuario en TODAS las fases
    print("[MapManager] ✅ Condiciones válidas - procediendo con actualización");

    // DEBUGGING ADICIONAL: Verificar el estado actual del mapa
    print("[MapManager] 🔍 === ESTADO DEL MAPA ANTES DE ACTUALIZAR ===");
    const String sourceId = 'user-location-source';
    const String layerId = 'user-location-layer';

    try {
      final sourceExists = await mapboxMap!.style.styleSourceExists(sourceId);
      final layerExists = await mapboxMap!.style.styleLayerExists(layerId);
      print("[MapManager] 🔍 Fuente '$sourceId' existe: $sourceExists");
      print("[MapManager] 🔍 Capa '$layerId' existe: $layerExists");

      if (sourceExists) {
        // Intentar obtener datos actuales de la fuente
        try {
          await mapboxMap!.style.getSource(sourceId) as GeoJsonSource;
          print("[MapManager] 🔍 Fuente obtenida exitosamente");
          // TODO: No podemos obtener los datos directamente, pero al menos sabemos que existe
        } catch (e) {
          print("[MapManager] 🔍 Error obteniendo fuente: $e");
        }
      }

      if (layerExists) {
        // Verificar propiedades de la capa
        try {
          // Obtener visibilidad
          final visibility = await mapboxMap!.style.getStyleLayerProperty(
            layerId,
            'visibility',
          );
          print("[MapManager] 🔍 Visibilidad de capa: $visibility");

          // Obtener opacidad
          final opacity = await mapboxMap!.style.getStyleLayerProperty(
            layerId,
            'circle-opacity',
          );
          print("[MapManager] 🔍 Opacidad de capa: $opacity");

          // Obtener color
          final color = await mapboxMap!.style.getStyleLayerProperty(
            layerId,
            'circle-color',
          );
          print("[MapManager] 🔍 Color de capa: $color");

          // Obtener radio
          final radius = await mapboxMap!.style.getStyleLayerProperty(
            layerId,
            'circle-radius',
          );
          print("[MapManager] 🔍 Radio de capa: $radius");
        } catch (e) {
          print("[MapManager] 🔍 Error obteniendo propiedades de capa: $e");
        }
      }

      // Verificar orden de capas
      try {
        final allLayers = await mapboxMap!.style.getStyleLayers();
        final layerIndex = allLayers.indexWhere(
          (layer) => layer?.id == layerId,
        );
        print(
          "[MapManager] 🔍 Capa '$layerId' está en posición: $layerIndex de ${allLayers.length} capas totales",
        );

        // Mostrar las últimas 5 capas para ver si nuestra capa está siendo tapada
        if (allLayers.length > 5) {
          final lastLayers =
              allLayers.skip(allLayers.length - 5).map((l) => l?.id).toList();
          print("[MapManager] 🔍 Últimas 5 capas (en orden): $lastLayers");
        }
      } catch (e) {
        print("[MapManager] 🔍 Error obteniendo capas: $e");
      }
    } catch (e) {
      print("[MapManager] 🔍 Error en verificación de estado: $e");
    }

    print("[MapManager] 🔍 === FIN ESTADO DEL MAPA ===");

    try {
      const String sourceId = 'user-location-source';
      const String layerId = 'user-location-layer';

      print("[MapManager] 🗺️ Verificando si fuente '$sourceId' ya existe...");
      final sourceExists = await mapboxMap!.style.styleSourceExists(sourceId);
      print("[MapManager] 🗺️ Fuente existe: $sourceExists");

      // Validar coordenadas
      if (userLocation.latitud.isNaN ||
          userLocation.longitud.isNaN ||
          userLocation.latitud.abs() > 90 ||
          userLocation.longitud.abs() > 180) {
        print(
          "[MapManager] ❌ Coordenadas inválidas: ${userLocation.latitud}, ${userLocation.longitud}",
        );
        return;
      }

      // Crear feature de ubicación del usuario
      final userLocationFeature = {
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [userLocation.longitud, userLocation.latitud],
        },
        "properties": {"type": "user-location"},
      };

      final sourceData = {
        "type": "FeatureCollection",
        "features": [userLocationFeature],
      };

      print(
        "[MapManager] 📄 GeoJSON válido creado para coordenadas: [${userLocation.longitud}, ${userLocation.latitud}]",
      );

      if (sourceExists) {
        print("[MapManager] 🔄 Actualizando fuente existente...");
        print(
          "[MapManager] 🔄 Coordenadas anteriores vs nuevas para detectar cambio visual...",
        );
        try {
          final source =
              await mapboxMap!.style.getSource(sourceId) as GeoJsonSource;
          await source.updateGeoJSON(json.encode(sourceData));
          print(
            "[MapManager] ✅ Fuente GeoJSON actualizada - DEBERÍAMOS ver movimiento visual",
          );

          // DEBUGGING: Verificar que la fuente realmente contiene los nuevos datos
          try {
            await mapboxMap!.style.getSource(sourceId) as GeoJsonSource;
            print(
              "[MapManager] 🔍 Verificación post-actualización: fuente obtenida correctamente",
            );
            print(
              "[MapManager] 🔍   - Nuevas coordenadas deberían ser: [${userLocation.longitud}, ${userLocation.latitud}]",
            );
          } catch (verifyError) {
            print(
              "[MapManager] ⚠️ Error verificando actualización: $verifyError",
            );
          }
        } catch (e) {
          print("[MapManager] ❌ Error actualizando fuente existente: $e");
          print("[MapManager] 🔄 Intentando recrear fuente...");

          // Si falla la actualización, intentar eliminar y recrear
          try {
            await mapboxMap!.style.removeStyleSource(sourceId);
            print("[MapManager] 🗑️ Fuente eliminada");
          } catch (removeError) {
            print("[MapManager] ⚠️ Error eliminando fuente: $removeError");
          }

          // Recrear la fuente
          await _createUserLocationSourceAndLayer(
            sourceId,
            layerId,
            sourceData,
          );
        }
      } else {
        print("[MapManager] 🆕 Creando nueva fuente y capa...");
        await _createUserLocationSourceAndLayer(sourceId, layerId, sourceData);
      }

      print(
        "[MapManager] ✅ === UBICACIÓN USUARIO ACTUALIZADA EXITOSAMENTE ===",
      );

      // DEBUGGING ADICIONAL: Verificar el estado DESPUÉS de la actualización
      print("[MapManager] 🔍 === ESTADO DEL MAPA DESPUÉS DE ACTUALIZAR ===");

      try {
        final sourceExistsAfter = await mapboxMap!.style.styleSourceExists(
          sourceId,
        );
        final layerExistsAfter = await mapboxMap!.style.styleLayerExists(
          layerId,
        );
        print("[MapManager] 🔍 POST-UPDATE: Fuente existe: $sourceExistsAfter");
        print("[MapManager] 🔍 POST-UPDATE: Capa existe: $layerExistsAfter");

        if (layerExistsAfter) {
          // Verificar propiedades críticas después de la actualización
          try {
            final visibilityAfter = await mapboxMap!.style
                .getStyleLayerProperty(layerId, 'visibility');
            final opacityAfter = await mapboxMap!.style.getStyleLayerProperty(
              layerId,
              'circle-opacity',
            );
            final colorAfter = await mapboxMap!.style.getStyleLayerProperty(
              layerId,
              'circle-color',
            );
            final radiusAfter = await mapboxMap!.style.getStyleLayerProperty(
              layerId,
              'circle-radius',
            );

            print("[MapManager] 🔍 POST-UPDATE: Visibilidad: $visibilityAfter");
            print("[MapManager] 🔍 POST-UPDATE: Opacidad: $opacityAfter");
            print("[MapManager] 🔍 POST-UPDATE: Color: $colorAfter");
            print("[MapManager] 🔍 POST-UPDATE: Radio: $radiusAfter");

            // Verificar si la capa está visible
            final isVisible = visibilityAfter != 'none';
            final hasOpacity =
                opacityAfter.toString() != 'none' &&
                opacityAfter.toString() != '0';
            final hasRadius =
                radiusAfter.toString() != 'none' &&
                radiusAfter.toString() != '0';

            print("[MapManager] 🔍 POST-UPDATE: ¿Visible?: $isVisible");
            print("[MapManager] 🔍 POST-UPDATE: ¿Con opacidad?: $hasOpacity");
            print("[MapManager] 🔍 POST-UPDATE: ¿Con radio?: $hasRadius");

            if (!isVisible || !hasOpacity || !hasRadius) {
              print(
                "[MapManager] ⚠️ PROBLEMA POTENCIAL: La capa puede no ser visible",
              );
              print(
                "[MapManager] ⚠️   - Visibility = '$visibilityAfter' (debería ser 'visible' o no 'none')",
              );
              print(
                "[MapManager] ⚠️   - Opacity = '$opacityAfter' (debería ser > 0)",
              );
              print(
                "[MapManager] ⚠️   - Radius = '$radiusAfter' (debería ser > 0)",
              );
            } else {
              print(
                "[MapManager] ✅ La capa parece estar configurada correctamente para ser visible",
              );
            }
          } catch (propError) {
            print(
              "[MapManager] 🔍 Error obteniendo propiedades post-actualización: $propError",
            );
          }
        }

        // Verificar si hay problemas de orden de capas
        try {
          final allLayersAfter = await mapboxMap!.style.getStyleLayers();
          final userLayerIndex = allLayersAfter.indexWhere(
            (layer) => layer?.id == layerId,
          );

          print(
            "[MapManager] 🔍 POST-UPDATE: Posición de capa usuario: $userLayerIndex de ${allLayersAfter.length}",
          );

          // Contar cuántas capas están encima de la capa del usuario
          final layersAbove = allLayersAfter.length - 1 - userLayerIndex;
          print(
            "[MapManager] 🔍 POST-UPDATE: Capas encima del usuario: $layersAbove",
          );

          if (layersAbove > 10) {
            print(
              "[MapManager] ⚠️ POSIBLE PROBLEMA: Muchas capas ($layersAbove) encima de la ubicación del usuario",
            );
            print(
              "[MapManager] ⚠️ La capa del usuario podría estar siendo tapada por otras capas",
            );

            // Mostrar las capas que están encima
            final upperLayers =
                allLayersAfter
                    .skip(userLayerIndex + 1)
                    .take(5)
                    .map((l) => l?.id)
                    .toList();
            print(
              "[MapManager] ⚠️ Primeras 5 capas que la tapan: $upperLayers",
            );
          }
        } catch (layerOrderError) {
          print(
            "[MapManager] 🔍 Error verificando orden de capas: $layerOrderError",
          );
        }

        // Intento experimental: Forzar re-renderizado moviendo la capa al final
        try {
          print(
            "[MapManager] 🔬 EXPERIMENTO: Moviendo capa al final para asegurar visibilidad...",
          );
          await mapboxMap!.style.moveStyleLayer(
            layerId,
            null,
          ); // null = mover al final
          print("[MapManager] 🔬 Capa movida al final exitosamente");
        } catch (moveError) {
          print("[MapManager] 🔬 Error moviendo capa al final: $moveError");
        }
      } catch (postUpdateError) {
        print(
          "[MapManager] 🔍 Error en verificación post-actualización: $postUpdateError",
        );
      }

      print("[MapManager] 🔍 === FIN ESTADO POST-ACTUALIZACIÓN ===");
    } catch (e) {
      print("[MapManager] ❌ === ERROR ACTUALIZANDO UBICACIÓN USUARIO ===");
      print("[MapManager] ❌ Error: $e");
      print("[MapManager] ❌ Tipo: ${e.runtimeType}");
      print("[MapManager] ❌ Stack trace: ${StackTrace.current}");
    }
  }

  /// Crear fuente y capa de ubicación del usuario
  Future<void> _createUserLocationSourceAndLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> sourceData,
  ) async {
    print("[MapManager] 🆕 === CREANDO FUENTE Y CAPA DE UBICACIÓN ===");

    try {
      // Verificar si la capa existe y eliminarla
      print("[MapManager] 🗑️ Verificando si capa '$layerId' existe...");
      final layerExists = await mapboxMap!.style.styleLayerExists(layerId);
      if (layerExists) {
        print("[MapManager] 🗑️ Eliminando capa existente...");
        await mapboxMap!.style.removeStyleLayer(layerId);
      }

      // Crear fuente nueva
      print("[MapManager] 📂 Creando nueva fuente '$sourceId'...");
      try {
        await mapboxMap!.style.addSource(
          GeoJsonSource(id: sourceId, data: json.encode(sourceData)),
        );
        registerSource(sourceId);
        print("[MapManager] ✅ Fuente '$sourceId' creada y registrada");
      } catch (e) {
        if (e.toString().contains('already exists') ||
            e.toString().contains('Source \'$sourceId\' already exists')) {
          print(
            "[MapManager] ⚠️ Fuente '$sourceId' ya existe - actualizando en su lugar...",
          );
          try {
            final source =
                await mapboxMap!.style.getSource(sourceId) as GeoJsonSource;
            await source.updateGeoJSON(json.encode(sourceData));
            print(
              "[MapManager] ✅ Fuente '$sourceId' actualizada después de error 'already exists'",
            );
          } catch (updateError) {
            print(
              "[MapManager] ❌ Error actualizando fuente después de 'already exists': $updateError",
            );
            rethrow;
          }
        } else {
          print("[MapManager] ❌ Error creando fuente '$sourceId': $e");
          rethrow;
        }
      }

      // Crear capa del círculo azul para la ubicación del usuario
      // CRUCIAL: Agregar la capa AL FINAL (encima de todas las demás) para asegurar visibilidad
      print("[MapManager] 🔵 Creando capa de círculo azul '$layerId'...");
      try {
        // EXPERIMENTO: Crear capa con propiedades más agresivas para debug
        await mapboxMap!.style.addLayer(
          CircleLayer(
            id: layerId,
            sourceId: sourceId,
            circleRadius: 15.0, // Radio más grande para debug
            circleColor: 0xFFFF0000, // ROJO para debug (más visible)
            circleStrokeWidth: 3.0, // Borde más grueso
            circleStrokeColor: 0xFFFFFFFF, // Borde blanco
            circleOpacity: 1.0, // Máxima opacidad
            circleStrokeOpacity: 1.0,
            // visibility: 'visible', // No podemos usar string, omitir para usar por defecto
          ),
        );
        registerLayer(layerId);
        print(
          "[MapManager] ✅ Capa '$layerId' creada - ROJO DEBUG, radio: 15px, borde: 3px",
        );

        // Verificaciones exhaustivas INMEDIATAS
        final layerExists = await mapboxMap!.style.styleLayerExists(layerId);
        final sourceExistsAfterLayer = await mapboxMap!.style.styleSourceExists(
          sourceId,
        );
        print("[MapManager] 🔍 Verificación INMEDIATA después de crear capa:");
        print("[MapManager] 🔍   - Capa '$layerId' existe: $layerExists");
        print(
          "[MapManager] 🔍   - Fuente '$sourceId' existe: $sourceExistsAfterLayer",
        );

        if (!layerExists) {
          print(
            "[MapManager] ❌ PROBLEMA CRÍTICO: La capa no existe después de crearla!",
          );
          throw Exception("Layer $layerId was not created successfully");
        }

        // Verificar propiedades inmediatamente después de crear
        try {
          final immediateVisibility = await mapboxMap!.style
              .getStyleLayerProperty(layerId, 'visibility');
          final immediateOpacity = await mapboxMap!.style.getStyleLayerProperty(
            layerId,
            'circle-opacity',
          );
          final immediateColor = await mapboxMap!.style.getStyleLayerProperty(
            layerId,
            'circle-color',
          );
          final immediateRadius = await mapboxMap!.style.getStyleLayerProperty(
            layerId,
            'circle-radius',
          );

          print(
            "[MapManager] 🔍 Propiedades INMEDIATAS de la capa recién creada:",
          );
          print("[MapManager] 🔍   - Visibilidad: $immediateVisibility");
          print("[MapManager] 🔍   - Opacidad: $immediateOpacity");
          print("[MapManager] 🔍   - Color: $immediateColor");
          print("[MapManager] 🔍   - Radio: $immediateRadius");

          // Verificar si las propiedades son las esperadas
          final expectedColor = 0xFFFF0000; // ROJO
          final expectedRadius = 15.0;

          if (immediateColor != expectedColor) {
            print(
              "[MapManager] ⚠️ Color no coincide: esperado $expectedColor, obtenido $immediateColor",
            );
          }
          if (immediateRadius != expectedRadius) {
            print(
              "[MapManager] ⚠️ Radio no coincide: esperado $expectedRadius, obtenido $immediateRadius",
            );
          }
        } catch (immediatePropError) {
          print(
            "[MapManager] ❌ Error obteniendo propiedades inmediatas: $immediatePropError",
          );
        }

        // EXPERIMENTO ADICIONAL: Forzar que la capa esté al final inmediatamente
        try {
          print("[MapManager] 🔬 Moviendo capa recién creada al final...");
          await mapboxMap!.style.moveStyleLayer(layerId, null);
          print(
            "[MapManager] 🔬 Capa movida al final inmediatamente después de crear",
          );

          // Verificar posición después de mover
          final layersAfterMove = await mapboxMap!.style.getStyleLayers();
          final positionAfterMove = layersAfterMove.indexWhere(
            (layer) => layer?.id == layerId,
          );
          print(
            "[MapManager] 🔬 Posición después de mover: $positionAfterMove de ${layersAfterMove.length}",
          );

          if (positionAfterMove != layersAfterMove.length - 1) {
            print("[MapManager] ⚠️ La capa NO está al final después de mover!");
          } else {
            print("[MapManager] ✅ La capa está correctamente al final");
          }
        } catch (moveError) {
          print("[MapManager] ❌ Error moviendo capa al final: $moveError");
        }
      } catch (e) {
        if (e.toString().contains('already exists') ||
            e.toString().contains('Layer \'$layerId\' already exists')) {
          print(
            "[MapManager] ⚠️ Capa '$layerId' ya existe - actualizando propiedades...",
          );

          // Si la capa ya existe, actualizar sus propiedades para hacerla más visible
          try {
            await mapboxMap!.style.setStyleLayerProperty(
              layerId,
              'circle-radius',
              8.0,
            );
            await mapboxMap!.style.setStyleLayerProperty(
              layerId,
              'circle-color',
              0xFF2196F3,
            );
            await mapboxMap!.style.setStyleLayerProperty(
              layerId,
              'circle-opacity',
              1.0,
            );
            print(
              "[MapManager] ✅ Propiedades de capa existente actualizadas a AZUL y radio 8",
            );
          } catch (propError) {
            print("[MapManager] ❌ Error actualizando propiedades: $propError");
          }

          registerLayer(layerId); // Asegurar que esté registrada
        } else {
          print("[MapManager] ❌ Error creando capa '$layerId': $e");
          rethrow;
        }
      }
      print("[MapManager] ✅ === FUENTE Y CAPA CREADAS EXITOSAMENTE ===");
    } catch (e) {
      print("[MapManager] ❌ === ERROR CREANDO FUENTE Y CAPA ===");
      print("[MapManager] ❌ Error: $e");
      print("[MapManager] ❌ Tipo: ${e.runtimeType}");
      rethrow;
    }
  }

  /// VERSIÓN LIMPIA: Actualizar ubicación del usuario (simplificada)
  Future<void> updateUserLocationClean(Coordenada userLocation) async {
    print(
      "[MapManager] [CLEAN] Updating user location: ${userLocation.latitud}, ${userLocation.longitud}",
    );
    print("[MapManager] [CLEAN] Current phase: $_currentPhase");

    if (mapboxMap == null) {
      print("[MapManager] [CLEAN] Cannot update - mapboxMap is null");
      return;
    }

    // CORREGIDO: Permitir ubicación en TODAS las fases, no solo active_trip
    print(
      "[MapManager] [CLEAN] Phase validation passed - proceeding with location update",
    );

    // Guardar última ubicación del usuario para zooms contextuales
    _currentUserLocation = userLocation;

    try {
      const String sourceId = 'user-location-source';
      const String layerId = 'user-location-layer';

      // Validar coordenadas
      if (userLocation.latitud.isNaN ||
          userLocation.longitud.isNaN ||
          userLocation.latitud.abs() > 90 ||
          userLocation.longitud.abs() > 180) {
        print("[MapManager] [CLEAN] Invalid coordinates");
        return;
      }

      // Crear GeoJSON para la ubicación
      final sourceData = {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "geometry": {
              "type": "Point",
              "coordinates": [userLocation.longitud, userLocation.latitud],
            },
            "properties": {"type": "user-location"},
          },
        ],
      };

      // Actualizar o crear fuente
      final sourceExists = await mapboxMap!.style.styleSourceExists(sourceId);
      if (sourceExists) {
        print("[MapManager] [CLEAN] 🔄 About to call updateGeoJSON...");
        final source =
            await mapboxMap!.style.getSource(sourceId) as GeoJsonSource;
        await source.updateGeoJSON(json.encode(sourceData));
        print(
          "[MapManager] [CLEAN] ✅ updateGeoJSON completed - MAP SHOULD UPDATE NOW",
        );
        print(
          "[MapManager] [CLEAN] 📍 New coordinates pushed to map: [${userLocation.longitud}, ${userLocation.latitud}]",
        );
        print(
          "[MapManager] [CLEAN] 🔵 CÍRCULO AZUL DEBERÍA MOVERSE VISUALMENTE AHORA - ${DateTime.now()}",
        );
        print("[MapManager] [CLEAN] User location source updated");
      } else {
        await _createUserLocationClean(sourceId, layerId, sourceData);
      }
    } catch (e) {
      print("[MapManager] [CLEAN] Error updating user location: $e");
    }
  }

  /// VERSIÓN LIMPIA: Crear fuente y capa de ubicación del usuario
  Future<void> _createUserLocationClean(
    String sourceId,
    String layerId,
    Map<String, dynamic> sourceData,
  ) async {
    try {
      // Limpiar capa existente si existe
      final layerExists = await mapboxMap!.style.styleLayerExists(layerId);
      if (layerExists) {
        await mapboxMap!.style.removeStyleLayer(layerId);
      }

      // Crear fuente nueva
      print("[MapManager] [CLEAN] 📂 About to create GeoJSON source...");
      await mapboxMap!.style.addSource(
        GeoJsonSource(id: sourceId, data: json.encode(sourceData)),
      );
      print(
        "[MapManager] [CLEAN] ✅ GeoJSON source created - DATA LOADED TO MAP",
      );
      registerSource(sourceId);

      // Crear capa del círculo azul - SIMPLIFICADA
      print("[MapManager] [CLEAN] 🔵 About to create CircleLayer...");
      await mapboxMap!.style.addLayer(
        CircleLayer(
          id: layerId,
          sourceId: sourceId,
          circleRadius: 8.0,
          circleColor: 0xFF2196F3, // Azul Material Design
          circleStrokeWidth: 2.0,
          circleStrokeColor: 0xFFFFFFFF, // Borde blanco
          circleOpacity: 1.0,
          circleStrokeOpacity: 1.0,
        ),
      );
      registerLayer(layerId);
      print(
        "[MapManager] [CLEAN] ✅ CircleLayer created - CIRCLE SHOULD BE VISIBLE NOW",
      );
      print(
        "[MapManager] [CLEAN] 📍 Circle created at: [${sourceData['features'][0]['geometry']['coordinates'][0]}, ${sourceData['features'][0]['geometry']['coordinates'][1]}]",
      );

      print("[MapManager] [CLEAN] User location layer created successfully");
    } catch (e) {
      print("[MapManager] [CLEAN] Error creating user location layer: $e");
      rethrow;
    }
  }

  /// Acceso directo a submódulos para casos específicos
  MapRouteRenderer get routeRenderer => _routeRenderer;
  MapBusRealtime get busRealtime => _busRealtime;
  MapIconsLoader get iconsLoader => _iconsLoader;
  MapCameraController get cameraController => _cameraController;
  MapCleanup get cleanup => _cleanup;

  // Called when auto-follow resumes to perform semantic recenter (e.g., WAITING_FOR_BUS leg)
  Future<void> handleAutoFollowResumed() async {
    try {
      if (_currentPhase != 'active_trip' || ref == null) return;
      final appState = ref!.read(appUiStateProvider);
      final active = appState.datosFaseViajeActivo;
      final currentStep = appState.currentJourneyStep;
      if (active == null || currentStep == null) return;
      if (currentStep.stepIndex >= active.tramosDelViaje.length) return;
      final tramo = active.tramosDelViaje[currentStep.stepIndex];
      final busPos = getCurrentBusPosition();
      final userPos = getCurrentUserLocation();
      final List<Coordenada> coords = [];
      // Construir coords según tipo de tramo
      switch (tramo.tipo) {
        case TipoTramoViaje.ESPERAR_BUS:
          if (tramo.coordenadasParadaOrigen != null) {
            coords.add(tramo.coordenadasParadaOrigen!);
          } else if (tramo.posicionPunto != null) {
            coords.add(tramo.posicionPunto!);
          }
          if (busPos != null) coords.add(busPos);
          if (userPos != null) coords.add(userPos);
          break;
        case TipoTramoViaje.CAMINAR:
          if (tramo.geometriaPolilinea != null &&
              tramo.geometriaPolilinea!.isNotEmpty) {
            coords.addAll(tramo.geometriaPolilinea!.take(30)); // sample inicial
          }
          if (tramo.coordenadasParadaDestino != null)
            coords.add(tramo.coordenadasParadaDestino!);
          if (userPos != null) coords.add(userPos);
          if (busPos != null)
            coords.add(
              busPos,
            ); // contexto si cercano (filtro interno ya aplicado antes)
          break;
        case TipoTramoViaje.VIAJE_EN_BUS:
          if (tramo.geometriaPolilinea != null &&
              tramo.geometriaPolilinea!.isNotEmpty) {
            coords.addAll(tramo.geometriaPolilinea!.take(40));
          }
          if (busPos != null) coords.add(busPos);
          if (tramo.coordenadasParadaDestino != null)
            coords.add(tramo.coordenadasParadaDestino!);
          if (userPos != null) coords.add(userPos);
          break;
        default:
          if (tramo.geometriaPolilinea != null &&
              tramo.geometriaPolilinea!.isNotEmpty) {
            coords.addAll(tramo.geometriaPolilinea!);
          } else if (tramo.posicionPunto != null) {
            coords.add(tramo.posicionPunto!);
          }
          if (userPos != null) coords.add(userPos);
          if (busPos != null) coords.add(busPos);
      }

      if (coords.length < 2) {
        FeatureLogger().camera(
          'auto_follow:semantic_recentering_skip_insufficient',
        );
        return;
      }
      _cameraController.prepareImmediateAnimation();
      FeatureLogger().camera(
        'auto_follow:semantic_recentering',
        data: {
          'coords': coords.length,
          'hasUser': userPos != null,
          'hasBus': busPos != null,
          'tipo': tramo.tipo.toString(),
        },
      );
      if (tramo.tipo == TipoTramoViaje.ESPERAR_BUS &&
          busPos != null &&
          (tramo.coordenadasParadaOrigen != null ||
              tramo.posicionPunto != null)) {
        await _cameraController.updateWaitingBusViewport(
          waitingLeg: tramo,
          busPosition: busPos,
          userPosition: userPos,
        );
      } else {
        await _cameraController.zoomToCurrentLeg(
          currentStep.stepIndex,
          active.tramosDelViaje,
        );
      }
    } catch (e) {
      FeatureLogger().camera(
        'auto_follow:semantic_recentering_error',
        data: {'e': e.toString()},
      );
    }
  }
}
