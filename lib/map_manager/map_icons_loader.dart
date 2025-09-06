import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Módulo especializado en cargar y manejar iconos del mapa
class MapIconsLoader {
  final MapboxMap? mapboxMap;
  final dynamic mapManager; // Usar dynamic para evitar referencia circular

  bool _iconsLoaded = false;

  // Constantes para iconos
  static const String STOP_ICON_IMAGE_ID = 'stop-icon';
  static const String BUS_ICON_IMAGE_ID = 'bus-icon';
  static const String BUS_TOOLTIP_ICON_ID = 'incoming-bus-tooltip';
  static const String PREVIEW_BUS_TOOLTIP_ICON_ID =
      'incoming-bus-tooltip-preview';
  static const String USER_LOCATION_ICON_ID = 'user-location-icon';

  MapIconsLoader(this.mapboxMap, this.mapManager);

  /// Cargar todos los iconos necesarios
  Future<void> loadAllIcons() async {
    if (mapboxMap == null || _iconsLoaded) return;

    print("[MapIconsLoader] Loading map icons");

    try {
      // Cargar icono de parada
      final MbxImage stopImage = await _loadIconImageFromAsset('stop_icon.png');
      await mapboxMap!.style.addStyleImage(
        STOP_ICON_IMAGE_ID,
        1.0,
        stopImage,
        false,
        [],
        [],
        null,
      );

      // Cargar icono de bus
      final MbxImage busImage = await _loadIconImageFromAsset(
        'incoming_bus.png',
      );
      await mapboxMap!.style.addStyleImage(
        BUS_ICON_IMAGE_ID,
        1.0,
        busImage,
        false,
        [],
        [],
        null,
      );

      // Cargar icono del tooltip del bus
      final MbxImage tooltipImage = await _loadIconImageFromAsset(
        'incoming_bus_tooltip.png',
      );
      await mapboxMap!.style.addStyleImage(
        BUS_TOOLTIP_ICON_ID,
        1.0,
        tooltipImage,
        false,
        [],
        [],
        null,
      );

      // Cargar icono del tooltip para preview
      await mapboxMap!.style.addStyleImage(
        PREVIEW_BUS_TOOLTIP_ICON_ID,
        1.0,
        tooltipImage, // Reutilizar la misma imagen
        false,
        [],
        [],
        null,
      );

      _iconsLoaded = true;
      print("[MapIconsLoader] All icons loaded successfully");
    } catch (e) {
      print("[MapIconsLoader] Error loading icons: $e");
      rethrow;
    }
  }

  /// Cargar imagen de asset y convertir a MbxImage
  Future<MbxImage> _loadIconImageFromAsset(String assetName) async {
    final ByteData data = await rootBundle.load('assets/icons/$assetName');
    final Uint8List bytes = data.buffer.asUint8List();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image image = frameInfo.image;

    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (byteData == null) {
      throw Exception('Failed to encode image to PNG');
    }

    final Uint8List pngBytes = byteData.buffer.asUint8List();
    return MbxImage(width: image.width, height: image.height, data: pngBytes);
  }

  /// Cargar icono de ubicación del usuario
  Future<void> loadUserLocationIcon() async {
    if (mapboxMap == null) return;

    print("[MapIconsLoader] Loading user location icon");

    try {
      // Crear un círculo azul programáticamente para la ubicación del usuario
      final userLocationImage = await _createUserLocationIcon();
      await mapboxMap!.style.addStyleImage(
        USER_LOCATION_ICON_ID,
        1.0,
        userLocationImage,
        false,
        [],
        [],
        null,
      );

      print("[MapIconsLoader] User location icon loaded successfully");
    } catch (e) {
      print("[MapIconsLoader] Error loading user location icon: $e");
      rethrow;
    }
  }

  /// Crear icono de ubicación del usuario programáticamente
  Future<MbxImage> _createUserLocationIcon() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint();

    // Configurar el tamaño del icono
    const double size = 32.0;
    const double radius = size / 2;

    // Dibujar círculo azul con borde blanco
    paint.color = ui.Color(0xFFFFFFFF); // Blanco para el borde
    canvas.drawCircle(Offset(radius, radius), radius, paint);

    paint.color = ui.Color(0xFF2196F3); // Azul material
    canvas.drawCircle(Offset(radius, radius), radius - 2, paint);

    // Dibujar punto central más pequeño
    paint.color = ui.Color(0xFFFFFFFF); // Blanco para el centro
    canvas.drawCircle(Offset(radius, radius), 4, paint);

    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(size.toInt(), size.toInt());

    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (byteData == null) {
      throw Exception('Failed to create user location icon');
    }

    final Uint8List pngBytes = byteData.buffer.asUint8List();
    return MbxImage(width: size.toInt(), height: size.toInt(), data: pngBytes);
  }

  /// Verificar si los iconos están cargados
  bool get areIconsLoaded => _iconsLoaded;
}
