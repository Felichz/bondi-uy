import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'dart:typed_data';

// Constantes para la API de transporte de Montevideo
const String _BASE_URL = "https://api.montevideo.gub.uy/api/transportepublico";
const String _ACCESS_TOKEN_URL =
    "https://mvdapi-auth.montevideo.gub.uy/auth/realms/pci/protocol/openid-connect/token";
const String _CLIENT_ID = "93d925e7";
const String _CLIENT_SECRET = "2ac468b09443250d178653e7707ea9ad";

// Token de Mapbox (el mismo que se usa para inicializar el mapa y para Geocoding)
const String _MAPBOX_ACCESS_TOKEN =
    "pk.eyJ1IjoiZmVsaWNoeiIsImEiOiJjbWFieDgxOW0yaGJ0Mmxwd3RmMGdndTc2In0.NC4vimNVJuH-tOgZQDs0kw";

// Constante para la URL del servidor OTP local (REST API - se mantiene por si acaso)
// Asegúrate que la IP sea accesible desde el emulador/dispositivo
// 10.0.2.2 es para el localhost de la máquina host desde el emulador Android
const String _OTP_SERVER_URL_REST =
    "http://10.0.2.2:8080/otp/routers/default/plan";

// AÑADIDO: Constante para la URL del servidor OTP local (GraphQL API)
// MODIFICADO: Usar la IP local de tu Mac para pruebas en dispositivo físico
const String _OTP_SERVER_URL_GRAPHQL =
    "http://10.0.2.2:8080/otp/routers/default/index/graphql";

// AÑADIDO: Cliente GraphQL para interactuar con OTP
// Se inicializará en initState o se definirá como late final.
ValueNotifier<GraphQLClient>? _otpGqlClient;

void main() {
  // Configurar el token de acceso de Mapbox aquí
  WidgetsFlutterBinding.ensureInitialized(); // Necesario si se configura antes de runApp
  MapboxOptions.setAccessToken(_MAPBOX_ACCESS_TOKEN);

  // Asegúrate de que Mapbox SDK esté inicializado si es necesario para tu versión.
  // Para algunas versiones, la inicialización con el token se hace automáticamente
  // si está en AndroidManifest.xml o Info.plist.
  // MapboxOptions.setAccessToken("YOUR_MAPBOX_ACCESS_TOKEN"); // Opcional aquí si ya está en config nativa
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BondiUY',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? mapboxMap;
  final CameraOptions _initialCameraOptions = CameraOptions(
    center: Point(
      coordinates: Position(
        -56.164532, // Longitud de Montevideo
        -34.901112, // Latitud de Montevideo
      ),
    ),
    zoom: 12.0,
  );

  // Controladores para los campos de texto de Origen y Destino
  final _origenController = TextEditingController();
  final _destinoController = TextEditingController();

  // Coordenadas para Origen y Destino (se conservan)
  Point? _origenCoordinates;
  Point? _destinoCoordinates;

  // ID para la fuente de datos GeoJSON de las paradas
  static const String STOPS_SOURCE_ID = "stops-source";
  // ID para la capa que mostrará los íconos de las paradas
  static const String STOPS_LAYER_ID = "stops-layer";

  // AÑADIDO: IDs para las capas y fuentes de la ruta
  static const String ROUTE_WALK_ORIGIN_SOURCE_ID = "route-walk-origin-source";
  static const String ROUTE_WALK_ORIGIN_LAYER_ID = "route-walk-origin-layer";
  static const String ROUTE_BUS_SOURCE_ID = "route-bus-source";
  static const String ROUTE_BUS_LAYER_ID = "route-bus-layer";
  static const String ROUTE_WALK_DESTINATION_SOURCE_ID =
      "route-walk-destination-source";
  static const String ROUTE_WALK_DESTINATION_LAYER_ID =
      "route-walk-destination-layer";

  // AÑADIDO: IDs para la capa y fuente de las paradas específicas de la ruta
  static const String ROUTE_STOPS_SOURCE_ID = "route-stops-source";
  // static const String ROUTE_STOPS_LAYER_ID = "route-stops-layer"; // Comentada/Reemplazada

  // AÑADIDO: IDs para capas de paradas de ruta principal e intermedias
  static const String ROUTE_MAIN_STOPS_LAYER_ID = "route-main-stops-layer";
  static const String ROUTE_INTERMEDIATE_STOPS_LAYER_ID =
      "route-intermediate-stops-layer";

  // AÑADIDO: IDs para la capa y fuente de los buses en tiempo real
  static const String REALTIME_BUS_SOURCE_ID = "realtime-bus-source";
  static const String REALTIME_BUS_LAYER_ID = "realtime-bus-layer";
  static const String REALTIME_BUS_ICON_ID = "realtime-bus-icon";
  // AÑADIDO: ID para la capa de puntos rojos para buses irrelevantes
  static const String REALTIME_BUS_DOTS_LAYER_ID = "realtime-bus-dots-layer";
  // AÑADIDO: ID para el ícono del bus resaltado en tiempo real
  static const String HIGHLIGHTED_REALTIME_BUS_ICON_ID =
      "highlighted-realtime-bus-icon";

  // AÑADIDO: Para mantener un registro de las capas y fuentes de ruta añadidas dinámicamente
  final List<String> _dynamicRouteSourceIds = [];
  final List<String> _dynamicRouteLayerIds = [];

  bool _stopsAdded =
      false; // Mantenemos por si acaso, aunque la lógica principal está en onStyleLoaded
  String? _apiToken;

  // AÑADIDO: Para Overlay y Focus
  final FocusNode _origenFocusNode = FocusNode();
  final FocusNode _destinoFocusNode = FocusNode();
  final LayerLink _origenLayerLink = LayerLink();
  final LayerLink _destinoLayerLink = LayerLink();

  Timer? _debounceTimer;

  // AÑADIDO: IDs genéricos para segmentos de ruta OTP
  static const String OTP_ROUTE_SOURCE_PREFIX = "otp-route-source-";
  static const String OTP_ROUTE_LAYER_PREFIX = "otp-route-layer-";

  // AÑADIDO: Flag para controlar si ya se añadieron las imágenes al estilo
  bool _styleImagesAdded = false;

  // AÑADIDO: Variable de estado para controlar el indicador de carga
  bool _isCalculatingRoute = false;

  // AÑADIDO: Para controlar la visibilidad de la barra de instrucciones colapsada
  bool _showCollapsedInstructionsBar = false;
  // AÑADIDO: Para almacenar los tramos de la ruta actual para la barra/bottomsheet
  List<dynamic> _currentRouteLegs = [];

  // AÑADIDO: Para rastrear el tramo seleccionado y sus capas
  int? _selectedLegIndex;
  final Map<int, List<String>> _legLayerIds = {};

  // AÑADIDO: Para controlar el modo de vista general de la ruta
  bool _isInOverviewMode = false;

  // AÑADIDO: Para controlar la expansión del panel de búsqueda superior
  bool _isSearchPanelExpanded = false; // Iniciar expandido

  // AÑADIDO: Para almacenar los itinerarios disponibles y el seleccionado
  List<Map<String, dynamic>> _availableItineraries = [];
  // int? _selectedItineraryIndex; // No se usará directamente para seleccionar, sino para pasar el itinerario

  // AÑADIDO: Para el rastreo de buses en tiempo real
  Timer? _realtimeBusTimer;
  String? _trackedBusLineShortName;
  // AÑADIDO: Flag para el ícono de bus en tiempo real
  bool _realtimeBusIconLoaded = false;
  // AÑADIDO: Flag para el ícono de bus resaltado en tiempo real
  bool _highlightedBusIconLoaded = false;
  // AÑADIDO: Para almacenar las geometrías de shapes.geojson
  Map<String, List<Position>> _shapeGeometries = {};
  bool _shapesLoaded = false;

  // AÑADIDO: IDs para la capa y fuente del recorrido completo de la línea base
  static const String FULL_BUS_LINE_SHAPE_SOURCE_ID_PREFIX =
      "full-bus-line-shape-source-";
  static const String FULL_BUS_LINE_SHAPE_LAYER_ID_PREFIX =
      "full-bus-line-shape-layer-";
  // Para tener un ID único si necesitamos mostrar más de una (poco probable por ahora)
  String? _currentFullLineShapeId;

  // AÑADIDO: Para diferenciar buses que ya pasaron la parada de origen
  List<Position>? _currentFullShapeForBusLeg;
  int? _originStopIndexOnShape;
  // AÑADIDO: Para diferenciar buses que no están en el tramo relevante (hasta la parada de destino del usuario)
  int? _destinationStopIndexOnShape;

  // AÑADIDO: Para rastrear si el usuario movió el mapa manualmente
  bool _userManuallyMovedMap = false;
  // AÑADIDO: Para identificar movimientos de cámara programáticos
  bool _isProgrammaticCameraMove = false;

  // AÑADIDO: Para almacenar la posición del autobús resaltado en tiempo real
  Position? _highlightedBusPosition;

  // AÑADIDO: Para controlar si estamos esperando que el zoom inicial a un tramo termine
  bool _isWaitingForInitialLegZoomToComplete = false;

  // ANIMACIÓN FLOTANTE PARA EL TOOLTIP DEL BUS MÁS CERCANO
  Timer? _tooltipFloatTimer;
  double _tooltipFloatPhase = 0.0;
  double _lastTooltipOffset = 0.0;

  void _startTooltipFloatingAnimation() {
    _tooltipFloatTimer?.cancel();
    // 60 FPS aprox
    _tooltipFloatTimer = Timer.periodic(const Duration(milliseconds: 16), (
      timer,
    ) async {
      // Un ciclo cada 3 segundos (o el periodo que elijas)
      final double amplitude = 5.0; // píxeles
      final double period = 3.0; // segundos
      final double baseOffset = -5.0; // offset fijo para llevarlo más arriba
      _tooltipFloatPhase += (2 * math.pi) / (period * 1000 / 16);
      if (_tooltipFloatPhase > 2 * math.pi) _tooltipFloatPhase -= 2 * math.pi;
      final double offsetY =
          baseOffset - amplitude * math.sin(_tooltipFloatPhase);
      _lastTooltipOffset = offsetY;
      // Actualiza el iconOffset del tooltip layer
      if (mapboxMap != null) {
        try {
          await mapboxMap!.style.setStyleLayerProperty(
            'incoming-bus-tooltip-layer',
            'icon-offset',
            [0.0, offsetY],
          );
        } catch (_) {}
      }
    });
  }

  void _stopTooltipFloatingAnimation() {
    _tooltipFloatTimer?.cancel();
    _tooltipFloatTimer = null;
    _tooltipFloatPhase = 0.0;
    // Al detener, resetea el offset a 0
    if (mapboxMap != null) {
      mapboxMap!.style.setStyleLayerProperty(
        'incoming-bus-tooltip-layer',
        'icon-offset',
        [0.0, 0.0],
      );
    }
  }

  _onMapCreated(MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    // La carga de datos/imágenes se hará en _onStyleLoadedListener
  }

  // AÑADIDO: Helper para encontrar el índice del punto más cercano en una lista de Positions a un Point_dart
  // Esta función es necesaria para la lógica de isPastOrigin
  int _findClosestPointIndexOnShape(
    List<Position> shapePoints,
    Point_dart targetPoint,
  ) {
    if (shapePoints.isEmpty) return -1;

    int closestIndex = -1;
    double minDistance = double.infinity;

    for (int i = 0; i < shapePoints.length; i++) {
      final shapePosition = shapePoints[i];
      // Asegurarse de que lat/lng sean double.
      final double shapeLat =
          (shapePosition.lat is num)
              ? (shapePosition.lat as num).toDouble()
              : 0.0;
      final double shapeLng =
          (shapePosition.lng is num)
              ? (shapePosition.lng as num).toDouble()
              : 0.0;

      final distance = _calculateHaversineDistance(
        targetPoint.lat,
        targetPoint.lng,
        shapeLat,
        shapeLng,
      );
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  // MODIFICADO: Ahora se cargan imágenes y luego los datos de paradas
  void _onStyleLoadedListener(StyleLoadedEventData event) async {
    print("[BondiUY_Debug] Estilo cargado.");
    if (mapboxMap == null || _styleImagesAdded) {
      if (_styleImagesAdded)
        print("[BondiUY_Debug] Imágenes de estilo ya añadidas.");
      return;
    }

    try {
      print("[BondiUY_Debug] Añadiendo imágenes personalizadas al estilo...");
      // Cargar imagen del ícono de bus desde los assets
      final ByteData busIconByteData = await rootBundle.load(
        'assets/icons/bus_icon.png',
      );
      final Uint8List busIconImageData = busIconByteData.buffer.asUint8List();

      await mapboxMap!.style.addStyleImage(
        "bus-icon",
        1.0, // devicePixelRatio - generalmente 1.0 para PNGs normales
        MbxImage(
          width: 64,
          height: 64,
          data: busIconImageData,
        ), // MODIFICADO: Dimensiones 64x64
        false, // sdf = false para PNGs normales
        [],
        [],
        null,
      );
      print("[BondiUY_Debug] Imagen 'bus-icon' (64x64) añadida al estilo.");

      // AÑADIDO: Cargar ícono para bus en tiempo real
      try {
        final ByteData realtimeBusIconByteData = await rootBundle.load(
          'assets/icons/realtime_bus_icon.png',
        );
        final Uint8List realtimeBusIconImageData =
            realtimeBusIconByteData.buffer.asUint8List();
        await mapboxMap!.style.addStyleImage(
          REALTIME_BUS_ICON_ID,
          1.0, // devicePixelRatio
          MbxImage(
            width: 64, // MODIFICADO: Dimensiones 64x64
            height: 64, // MODIFICADO: Dimensiones 64x64
            data: realtimeBusIconImageData,
          ),
          false, // sdf = false
          [],
          [],
          null,
        );
        _realtimeBusIconLoaded = true;
        print(
          "[BondiUY_Debug] Imagen '$REALTIME_BUS_ICON_ID' (64x64) para buses en tiempo real añadida al estilo.",
        );
      } catch (e) {
        print(
          "[BondiUY_Debug] No se pudo cargar 'assets/icons/realtime_bus_icon.png' (64x64). Se usará 'bus-icon' como fallback para buses en tiempo real. Error: $e",
        );
        // Fallback: si no se puede cargar, se usará "bus-icon"
        // No es necesario hacer nada aquí, la lógica de _fetchAndDisplayRealtimeBusLocations se encargará.
      }

      // AÑADIDO: Cargar ícono para bus resaltado en tiempo real (nuevo: incoming_bus.png)
      try {
        final ByteData highlightedBusIconByteData = await rootBundle.load(
          'assets/icons/incoming_bus.png',
        );
        final Uint8List highlightedBusIconImageData =
            highlightedBusIconByteData.buffer.asUint8List();
        await mapboxMap!.style.addStyleImage(
          'incoming-bus',
          1.5, // devicePixelRatio
          MbxImage(width: 256, height: 256, data: highlightedBusIconImageData),
          false,
          [],
          [],
          null,
        );
        print(
          "[BondiUY_Debug] Imagen 'incoming-bus' (256x256) para bus resaltado añadida al estilo.",
        );
      } catch (e) {
        print(
          "[BondiUY_Debug] No se pudo cargar 'assets/icons/incoming_bus.png' (256x256). Error: $e",
        );
      }

      // AÑADIDO: Cargar ícono para tooltip del bus resaltado (nuevo: incoming_bus_tooltip.png)
      try {
        final ByteData tooltipIconByteData = await rootBundle.load(
          'assets/icons/incoming_bus_tooltip.png',
        );
        final Uint8List tooltipIconImageData =
            tooltipIconByteData.buffer.asUint8List();
        await mapboxMap!.style.addStyleImage(
          'incoming-bus-tooltip',
          1.5, // devicePixelRatio
          MbxImage(width: 256, height: 256, data: tooltipIconImageData),
          false,
          [],
          [],
          null,
        );
        print(
          "[BondiUY_Debug] Imagen 'incoming-bus-tooltip' (256x256) para tooltip añadida al estilo.",
        );
      } catch (e) {
        print(
          "[BondiUY_Debug] No se pudo cargar 'assets/icons/incoming_bus_tooltip.png' (256x256). Error: $e",
        );
      }

      _styleImagesAdded = true; // Marcar que ya se añadieron
      print(
        "[BondiUY_Debug] Llamando a _loadStopsData después de añadir imágenes...",
      );
      await _loadStopsData();

      // AÑADIDO/MANTENIDO: Ocultar la barra de escala del mapa
      if (mapboxMap != null) {
        try {
          // Esta es la forma preferida si `mapboxMap.scaleBar` y `ScaleBarSettings` existen.
          final scaleBar =
              mapboxMap!
                  .scaleBar; // Acceder al controlador de la barra de escala
          await scaleBar.updateSettings(
            ScaleBarSettings(enabled: false),
          ); // Deshabilitarla
          print(
            "[BondiUY_Debug] Barra de escala configurada para estar oculta (mapboxMap.scaleBar.updateSettings).",
          );
        } catch (e_scale) {
          print(
            "[BondiUY_Debug] Error al intentar ocultar la barra de escala vía mapboxMap.scaleBar: $e_scale",
          );
          // Aquí se podrían intentar otros métodos si el anterior falla y se conocen alternativas
          // para la versión específica de la librería Mapbox que se esté usando.
          // Por ejemplo, algunas versiones podrían tener algo como:
          // await mapboxMap.ornaments.updateSettings(OrnamentSettingsUpdate(scaleBarEnabled: false));
          // o similar. Sin la documentación exacta de la versión, es difícil adivinar.
        }
      }
    } catch (e, s) {
      print(
        "[BondiUY_Debug] Error añadiendo imagen de estilo o cargando datos: $e",
      );
      print(s);
    }
  }

  Future<void> _loadStopsData() async {
    if (mapboxMap == null) {
      print("[BondiUY_Debug] MapboxMap no listo en _loadStopsData.");
      return;
    }
    if (_stopsAdded) {
      // Volvemos a añadir la verificación por si acaso
      print(
        "[BondiUY_Debug] Paradas ya cargadas (flag _stopsAdded), ignorando.",
      );
      return;
    }
    print("[BondiUY_Debug] Iniciando _loadStopsData...");

    try {
      _stopsAdded = true; // Marcar que ya cargamos las paradas
      final String geoJsonData = await rootBundle.loadString(
        'assets/data/stops.geojson',
      );

      final sourceExists = await mapboxMap!.style.styleSourceExists(
        STOPS_SOURCE_ID,
      );
      if (!sourceExists) {
        await mapboxMap!.style.addSource(
          GeoJsonSource(id: STOPS_SOURCE_ID, data: geoJsonData),
        );
        print(
          "[BondiUY_Debug] GeoJsonSource '$STOPS_SOURCE_ID' añadida al estilo.",
        );
      } else {
        print("[BondiUY_Debug] GeoJsonSource '$STOPS_SOURCE_ID' ya existe.");
      }

      final layerExists = await mapboxMap!.style.styleLayerExists(
        STOPS_LAYER_ID,
      );
      if (!layerExists) {
        await mapboxMap!.style.addLayer(
          SymbolLayer(
            id: STOPS_LAYER_ID,
            sourceId: STOPS_SOURCE_ID,
            iconImage: "bus-icon", // Usar el ícono cargado
            iconSize:
                0.4, // AJUSTADO: Para imagen base de 64px (antes 0.8 para 32px)
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
            minZoom: 13.5,
          ),
        );
        await _printLayerOrder();
        print(
          "[BondiUY_Debug] SymbolLayer '$STOPS_LAYER_ID' para paradas generales añadida.",
        );
      } else {
        print("[BondiUY_Debug] SymbolLayer '$STOPS_LAYER_ID' ya existe.");
      }
    } catch (e, s) {
      print("[BondiUY_Debug] Error en _loadStopsData: $e");
      print("[BondiUY_Debug] Stack trace: $s");
    }
  }

  // CORREGIDO: Firma del listener para que coincida con la posible firma
  // que usa MapContentGestureContext, inferido de ejemplos de LongTapInteraction.
  void _onMapWidgetTap(MapContentGestureContext context) async {
    if (mapboxMap == null) return;

    // CORREGIDO: Usar context.touchPosition para obtener ScreenCoordinate
    final ScreenCoordinate screenCoordinate = context.touchPosition;

    final options = RenderedQueryOptions(
      layerIds: [STOPS_LAYER_ID],
      filter: null,
    );

    final List<QueriedRenderedFeature?> queriedFeaturesNullable =
        await mapboxMap!.queryRenderedFeatures(
          RenderedQueryGeometry.fromScreenCoordinate(screenCoordinate),
          options,
        );

    final List<QueriedRenderedFeature> features =
        queriedFeaturesNullable.whereType<QueriedRenderedFeature>().toList();

    if (features.isNotEmpty) {
      for (var queriedFeature in features) {
        // Acceder a través de QueriedRenderedFeature.queriedFeature y luego QueriedFeature.feature
        final innerQueriedFeature = queriedFeature.queriedFeature;
        final featureMap =
            innerQueriedFeature.feature; // Este es el Map<String?, Object?>

        final Map<String?, dynamic>? stopProperties;
        final rawProperties = featureMap['properties'];

        if (rawProperties is Map<String?, dynamic>) {
          stopProperties = rawProperties;
        } else if (rawProperties is Map) {
          stopProperties = Map<String?, dynamic>.from(rawProperties);
        } else {
          print(
            "Error: 'properties' no es un Map o es nulo para la feature: $featureMap",
          );
          stopProperties = null;
        }

        if (stopProperties != null) {
          final stopId = _getStringValue(stopProperties['stop_id']);
          final stopName = _getStringValue(stopProperties['stop_name']);

          if (stopId != null && stopId.isNotEmpty) {
            print("Parada tocada: ID=$stopId, Nombre=$stopName");
            _showBusLinesForStop(stopId, stopName ?? "Parada sin nombre");
          }
        }
      }
    }
  }

  String? _getStringValue(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  // MODIFICADO: Llamar a _fetchAndDisplayBusLines
  void _showBusLinesForStop(String stopId, String stopName) {
    print("Solicitando líneas para la parada: $stopName (ID: $stopId)");
    _fetchAndDisplayBusLines(stopId, stopName);
  }

  // NUEVA FUNCIÓN: Para obtener el token de acceso OAuth2
  Future<String?> _getApiToken() async {
    if (_apiToken != null) {
      // TODO: Idealmente, verificar la expiración del token antes de reusarlo.
      // Por ahora, lo reusamos si existe.
      // print("[BondiUY_Debug] Reusando token de acceso existente.");
      return _apiToken;
    }

    print("[BondiUY_Debug] Solicitando nuevo token de acceso...");
    try {
      final response = await http.post(
        Uri.parse(_ACCESS_TOKEN_URL),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _CLIENT_ID,
          'client_secret': _CLIENT_SECRET,
          'grant_type': 'client_credentials',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        _apiToken = responseData['access_token'];
        print("[BondiUY_Debug] Nuevo token de acceso obtenido.");
        // print("[BondiUY_Debug] Token: $_apiToken"); // Cuidado al imprimir tokens
        return _apiToken;
      } else {
        print(
          "[BondiUY_Debug] Error al obtener token: ${response.statusCode} - ${response.body}",
        );
        return null;
      }
    } catch (e) {
      print("[BondiUY_Debug] Excepción al obtener token: $e");
      return null;
    }
  }

  // MODIFICADO: Para obtener datos reales de la API
  Future<void> _fetchAndDisplayBusLines(String stopId, String stopName) async {
    print(
      "[BondiUY_Debug] Obteniendo líneas para stopId: $stopId desde la API...",
    );

    final String? token = await _getApiToken();
    if (token == null) {
      print("[BondiUY_Debug] No se pudo obtener el token. Abortando.");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error de autenticación con la API.")),
      );
      return;
    }

    List<Map<String, String>> busLinesData = [];
    String errorMessage = 'No hay información de líneas para esta parada.';

    try {
      final String apiUrl = "$_BASE_URL/buses/busstops/$stopId/lines";
      print("[BondiUY_Debug] API URL: $apiUrl");

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print("[BondiUY_Debug] Respuesta API Status: ${response.statusCode}");
      // Descomentar para ver el cuerpo de la respuesta si es necesario
      // print("[BondiUY_Debug] Respuesta API Body: ${response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> decodedData = json.decode(response.body);
        if (decodedData.isNotEmpty) {
          busLinesData =
              decodedData.map((lineInfo) {
                // La API devuelve "line" y "lineId".
                // Usaremos "line" para el nombre principal y "lineId" como subtítulo o para futura referencia.
                // El BottomSheet actual espera 'line' y 'destination'.
                // Vamos a adaptar para mostrar 'line' y 'lineId' como 'Línea X (ID: Y)'
                return {
                  'line': _getStringValue(lineInfo['line']) ?? 'N/A',
                  'lineId': _getStringValue(lineInfo['lineId']) ?? 'N/A',
                };
              }).toList();
          if (busLinesData.isEmpty) {
            // Esto podría pasar si decodedData es una lista vacía después del map, aunque el if anterior ya lo cubre
            errorMessage = 'No se encontraron líneas para esta parada.';
          }
        } else {
          errorMessage = 'Respuesta vacía de la API para las líneas.';
          print("[BondiUY_Debug] $errorMessage");
        }
      } else if (response.statusCode == 401) {
        errorMessage =
            "Error de autorización con la API (token inválido o expirado).";
        _apiToken =
            null; // Forzar la obtención de un nuevo token la próxima vez
        print(
          "[BondiUY_Debug] $errorMessage. StatusCode: ${response.statusCode}. Body: ${response.body}",
        );
      } else {
        errorMessage = "Error al obtener líneas: ${response.statusCode}";
        print("[BondiUY_Debug] $errorMessage. Body: ${response.body}");
      }
    } catch (e, s) {
      errorMessage = "Excepción al obtener líneas: $e";
      print("[BondiUY_Debug] $errorMessage");
      print("[BondiUY_Debug] StackTrace: $s");
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Container(
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                ListTile(
                  title: Text(
                    'Parada: $stopName (ID: $stopId)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const Divider(),
                if (busLinesData.isNotEmpty)
                  ...busLinesData.map(
                    (lineInfo) => ListTile(
                      leading: CircleAvatar(
                        child: Text(lineInfo['line'] ?? '?'),
                      ),
                      // MODIFICADO: Para mostrar 'line' y 'lineId'
                      title: Text('Línea: ${lineInfo['line']}'),
                      subtitle: Text('ID Variante: ${lineInfo['lineId']}'),
                      onTap: () {
                        Navigator.pop(context);
                        print(
                          "Línea ${lineInfo['line']} (ID: ${lineInfo['lineId']}) seleccionada para parada $stopId",
                        );
                        // TODO: Implementar visualización de la ruta de esta línea o información detallada
                      },
                    ),
                  )
                else
                  ListTile(title: Text(errorMessage)),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    // AÑADIDO: Inicialización del cliente GraphQL para OTP
    final HttpLink httpLink = HttpLink(_OTP_SERVER_URL_GRAPHQL);

    _otpGqlClient = ValueNotifier(
      GraphQLClient(
        link: httpLink,
        cache: GraphQLCache(store: InMemoryStore()), // Caché en memoria simple
      ),
    );

    // AÑADIDO: Cargar y parsear shapes.geojson
    _loadAndParseShapesGeoJson();
  }

  @override
  void dispose() {
    _origenController.dispose();
    _destinoController.dispose();
    _debounceTimer?.cancel();
    _stopTooltipFloatingAnimation(); // Limpia la animación si queda activa
    // AÑADIDO: Dispose FocusNodes y remover Overlays
    _origenFocusNode.dispose();
    _destinoFocusNode.dispose();
    // AÑADIDO: Detener rastreo de bus en tiempo real
    _stopTrackingBusLine();
    super.dispose();
  }

  // AÑADIDO: Cargar y parsear shapes.geojson
  Future<void> _loadAndParseShapesGeoJson() async {
    if (_shapesLoaded) {
      print("[BondiUY_Debug] shapes.geojson ya cargado.");
      return;
    }
    try {
      print("[BondiUY_Debug] Cargando y parseando shapes.geojson...");
      final String geoJsonString = await rootBundle.loadString(
        'assets/data/shapes.geojson',
      );
      final Map<String, dynamic> geoJsonData = json.decode(geoJsonString);
      final List<dynamic> features = geoJsonData['features'] ?? [];

      for (var feature in features) {
        final properties = feature['properties'];
        final geometry = feature['geometry'];

        if (properties != null && geometry != null) {
          final String? shapeId = _getStringValue(properties['shape_id']);
          if (shapeId != null &&
              shapeId.isNotEmpty &&
              geometry['type'] == 'LineString') {
            final List<dynamic> coordinates = geometry['coordinates'] ?? [];
            List<Position> positions =
                coordinates
                    .map(
                      (coord) =>
                          Position(coord[0] as double, coord[1] as double),
                    )
                    .toList();
            if (positions.length >= 2) {
              _shapeGeometries[shapeId] = positions;
            }
          }
        }
      }
      _shapesLoaded = true;
      print(
        "[BondiUY_Debug] Parseo de shapes.geojson completado. ${_shapeGeometries.length} shapes cargados.",
      );
      // AÑADIDO PARA DIAGNÓSTICO
      if (_shapeGeometries.isNotEmpty) {
        print("[BondiUY_Debug] Primeras 5 claves de _shapeGeometries:");
        _shapeGeometries.keys.take(5).forEach(print);
      }
      // FIN DE DIAGNÓSTICO
      if (_shapeGeometries.isEmpty) {
        print(
          "[BondiUY_Debug] ADVERTENCIA: No se cargaron geometrías de shapes. Verifica 'assets/data/shapes.geojson' y su estructura.",
        );
      }
    } catch (e, s) {
      print("[BondiUY_Debug] Error cargando o parseando shapes.geojson: $e");
      print(s);
    }
  }

  // NUEVA LÓGICA DE BÚSQUEDA DE RUTA USANDO OTP CON GRAPHQL
  Future<void> _handleSearchRouteWithGraphQl() async {
    if (_origenCoordinates == null || _destinoCoordinates == null) {
      print(
        "[BondiUY_Debug_GraphQL] Coordenadas de origen o destino faltantes.",
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona un origen y un destino.'),
        ),
      );
      return;
    }
    if (mapboxMap == null) {
      print("[BondiUY_Debug_GraphQL] Mapa no listo.");
      return;
    }
    if (_otpGqlClient == null) {
      print("[BondiUY_Debug_GraphQL] Cliente GraphQL no inicializado.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error interno: Cliente GraphQL no disponible.'),
        ),
      );
      return;
    }

    // AÑADIDO: Iniciar indicador de carga
    setState(() {
      _isCalculatingRoute = true;
    });

    try {
      print(
        "[BondiUY_Debug_GraphQL] Solicitando ruta a servidor OTP con GraphQL...",
      );
      await _clearPreviousRouteLayers(); // Limpiar rutas anteriores
      _userManuallyMovedMap = false; // MODIFICADO: Resetear flag aquí
      _isProgrammaticCameraMove =
          false; // MODIFICADO: Resetear flag aquí también

      // Formatear fecha y hora actuales para la consulta GraphQL
      final now = DateTime.now();
      // Formato YYYY-MM-DD para la fecha
      final String date =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      // Formato HH:MM:SS para la hora
      final String time =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

      // Definición de la consulta GraphQL como un string multilinea.
      // Incluye variables para origen, destino, fecha y hora.
      // Solicita información de los tramos (legs) como modo, geometría (polyline),
      // tiempos, distancias y detalles de la ruta de tránsito.
      String queryString = """
        query PlanRuta(
          \$fromLat: Float!, \$fromLon: Float!,
          \$toLat: Float!, \$toLon: Float!,
          \$date: String!, \$time: String!
        ) {
          plan(
            from: { lat: \$fromLat, lon: \$fromLon },
            to: { lat: \$toLat, lon: \$toLon },
            date: \$date,
            time: \$time,
            transportModes: [
              { mode: WALK }, 
              { mode: BUS } 
            ],
            numItineraries: 3, # Solicitar hasta 3 itinerarios
          ) {
            itineraries {
              startTime 
              endTime
              legs {
                mode
                startTime 
                endTime
                duration 
                distance 
                from {
                  name
                  lat
                  lon
                }
                to {
                  name
                  lat
                  lon
                }
                route {
                  gtfsId
                  longName
                  shortName
                  # shapeId NO ESTÁ AQUÍ
                }
                trip { # AÑADIDO/MODIFICADO: Asegurar que consultamos trip
                  gtfsId # Puedes necesitar el gtfsId del trip también
                  shapeId # MOVIDO AQUÍ
                }
                legGeometry {
                  points
                  length 
                }
                steps {
                  streetName
                  distance 
                  relativeDirection 
                  absoluteDirection 
                }
                intermediatePlaces { # AÑADIDO para paradas intermedias
                  name
                  lat
                  lon
                }
              }
            }
          }
        }
      """;

      // Configuración de las opciones para la consulta GraphQL,
      // incluyendo el documento (la query string) y las variables.
      final QueryOptions options = QueryOptions(
        document: gql(queryString),
        variables: <String, dynamic>{
          'fromLat': _origenCoordinates!.coordinates.lat,
          'fromLon': _origenCoordinates!.coordinates.lng,
          'toLat': _destinoCoordinates!.coordinates.lat,
          'toLon': _destinoCoordinates!.coordinates.lng,
          'date': date,
          'time': time,
          // ELIMINADO: Parámetros de optimización basados en _selectedRoutePreference
          // (ya no se pasan variables walkReluctance ni transferPenalty)
        },
        fetchPolicy: FetchPolicy.networkOnly,
      );

      // Ejecutar la consulta GraphQL usando el cliente.
      final QueryResult result = await _otpGqlClient!.value.query(options);

      // Manejo de excepciones durante la ejecución de la consulta.
      if (result.hasException) {
        print(
          "[BondiUY_Debug_GraphQL] Error en GraphQL: ${result.exception.toString()}",
        );
        _showNoRouteFoundMessage("Error al obtener ruta (GraphQL).");
        return;
      }

      // Procesamiento de los datos recibidos si la consulta fue exitosa.
      if (result.data != null) {
        // CORREGIDO: Ajustar el path para acceder a los datos según la query 'plan'
        final planData = result.data!['plan'];

        // Verificar si hay errores de planificación devueltos por OTP.
        // La query 'plan' podría no tener un campo 'planErrors' explícito.
        // Los errores podrían estar en la lista 'graphqlErrors' de 'result'.
        // O si la estructura de 'planData' no es la esperada (ej. 'itineraries' es nulo o vacío).

        // Verificar si se encontraron itinerarios.
        if (planData != null &&
            planData['itineraries'] != null &&
            (planData['itineraries'] as List).isNotEmpty) {
          final List itineraries = planData['itineraries'];

          // AÑADIDO: Log para ver los múltiples itinerarios
          print(
            "[BondiUY_Debug_GraphQL] Número de itinerarios recibidos: ${itineraries.length}",
          );
          for (int i = 0; i < itineraries.length; i++) {
            final itinerary = itineraries[i];
            print("[BondiUY_Debug_GraphQL] === Itinerario ${i + 1} ===");
            print("  StartTime: ${itinerary['startTime']}");
            print("  EndTime: ${itinerary['endTime']}");
            final legsList = itinerary['legs'] as List?;
            print("  Número de Tramos: ${legsList?.length ?? 0}");
            if (legsList != null) {
              for (int j = 0; j < legsList.length; j++) {
                final leg = legsList[j];
                print(
                  "    Tramo ${j + 1}: Modo = ${leg['mode']}, Distancia = ${leg['distance']}, Desde = ${leg['from']?['name']}, Hasta = ${leg['to']?['name']}",
                );
                // Considerar no imprimir la polyline completa aquí para no saturar el log
                // print("      Polyline: ${leg['legGeometry']?['points']?.substring(0, 30)}...");
              }
            }
            // Para ver la estructura completa (puede ser muy verboso):
            // print(jsonEncode(itinerary));
            print("[BondiUY_Debug_GraphQL] ========================");
          }
          // FIN DE LOG

          // MODIFICADO: En lugar de procesar el primero, guardar todos y mostrar opciones
          if (mounted) {
            setState(() {
              _availableItineraries = List<Map<String, dynamic>>.from(
                itineraries,
              );
              _currentRouteLegs = []; // Limpiar tramos actuales
              _selectedLegIndex = null;
              _isInOverviewMode =
                  false; // Aún no estamos en overview de UNA ruta
              _showCollapsedInstructionsBar = false;
            });
            _clearPreviousRouteLayers(); // Limpiar cualquier ruta anterior del mapa
            _showRouteOptionsPanel(); // Mostrar panel con opciones de ruta
          }

          // La lógica de procesar UN itinerario se moverá a una función llamada después de la selección
          // final Map<String, dynamic> itinerary = itineraries.first;
          // final List<dynamic> legs = itinerary['legs'] ?? [];
          // ... resto del procesamiento del primer itinerario ...
        } else {
          print(
            "[BondiUY_Debug_GraphQL] Respuesta de GraphQL no contiene itinerarios válidos o 'itineraries' es nulo/vacío.",
          );
          _showNoRouteFoundMessage("No se encontró ruta con GraphQL.");
        }
      } else {
        print(
          "[BondiUY_Debug_GraphQL] Respuesta de GraphQL vacía (result.data es null).",
        );
        _showNoRouteFoundMessage(
          "No se recibió respuesta del planificador (GraphQL).",
        );
      }
    } catch (e, s) {
      // Captura de excepciones generales durante el proceso.
      print(
        "[BondiUY_Debug_GraphQL] Excepción al obtener/dibujar ruta GraphQL: $e",
      );
      print(s); // Imprimir stacktrace para depuración.
      _showNoRouteFoundMessage("Error de conexión al planificador (GraphQL).");
    } finally {
      // AÑADIDO: Detener indicador de carga
      if (mounted) {
        // Verificar si el widget todavía está montado
        setState(() {
          _isCalculatingRoute = false;
        });
      }
    }
  }

  // Función adaptada para dibujar un segmento de ruta desde coordenadas
  Future<void> _drawRouteSegment(
    List<Position> positions,
    String sourceId,
    String layerId,
    Color lineColor,
    int legIndex, { // AÑADIDO: Índice del tramo
    double lineWidth = 4.0,
    double shadowWidth = 6.0, // AÑADIDO: anchos opcionales
  }) async {
    if (mapboxMap == null || positions.length < 2) return;

    // Crear geometría LineString
    final Map<String, dynamic> geometry = {
      'type': 'LineString',
      'coordinates': positions.map((p) => [p.lng, p.lat]).toList(),
    };

    // Crear FeatureCollection
    final Map<String, dynamic> geoJsonFeature = {
      "type": "FeatureCollection",
      "features": [
        {"type": "Feature", "geometry": geometry, "properties": {}},
      ],
    };
    final String geoJsonData = json.encode(geoJsonFeature);

    try {
      // Verificar si fuente/capas ya existen para evitar errores al redibujar rápido
      final sourceExists = await mapboxMap!.style.styleSourceExists(sourceId);
      if (!sourceExists) {
        await mapboxMap!.style.addSource(
          GeoJsonSource(id: sourceId, data: geoJsonData),
        );
      } else {
        // Si existe, actualizar datos (aunque para rutas, usualmente se limpia antes)
        final source =
            await mapboxMap!.style.getSource(sourceId) as GeoJsonSource?;
        await source?.updateGeoJSON(geoJsonData);
      }
      _dynamicRouteSourceIds.add(
        sourceId,
      ); // Registrar aunque ya existiera, para limpieza

      // --- Control de Orden de Capas (Sombra debajo de Línea) ---
      // Añadir las capas en el orden inverso al de dibujado: Sombra primero, luego línea principal.

      // 1. Añadir Capa de Sombra
      final shadowLayerId = "$layerId-shadow";
      final shadowLayerExists = await mapboxMap!.style.styleLayerExists(
        shadowLayerId,
      );
      if (!shadowLayerExists) {
        await mapboxMap!.style.addLayer(
          LineLayer(
            id: shadowLayerId,
            sourceId: sourceId,
            lineColor: Colors.black.withOpacity(0.4).value,
            lineWidth: shadowWidth, // USAR PARÁMETRO
            lineOpacity: 0.7,
            lineJoin: LineJoin.ROUND,
            lineCap: LineCap.ROUND,
          ),
        );
        await _printLayerOrder();
        _dynamicRouteLayerIds.add(shadowLayerId);
      }

      // 2. Añadir Capa Principal (se dibujará encima de la sombra)
      final mainLayerId = layerId; // Usamos el ID original
      final mainLayerExists = await mapboxMap!.style.styleLayerExists(
        mainLayerId,
      );
      if (!mainLayerExists) {
        await mapboxMap!.style.addLayer(
          LineLayer(
            id: mainLayerId,
            sourceId: sourceId,
            lineColor: lineColor.value,
            lineWidth: lineWidth, // USAR PARÁMETRO
            lineOpacity: 0.9,
            lineJoin: LineJoin.ROUND,
            lineCap: LineCap.ROUND,
          ),
        );
        await _printLayerOrder();
        _dynamicRouteLayerIds.add(mainLayerId);
      }
      // --- Fin Control de Orden ---

      print(
        "[BondiUY_Debug] Segmento de ruta ($mainLayerId) dibujado (con sombra).",
      );
      // AÑADIDO: Registrar IDs de capa para este tramo
      _legLayerIds[legIndex] = [mainLayerId, shadowLayerId];
    } catch (e) {
      print(
        "[BondiUY_Debug] Error añadiendo fuente/capa para segmento $layerId: $e",
      );
      // No relanzar, solo loguear, para que otros segmentos puedan dibujarse
    }
  }

  // Renombrado para claridad
  void _showNoRouteFoundMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    // AÑADIDO: Detener indicador de carga si se muestra mensaje de error
    // y no se ha detenido antes.
    if (_isCalculatingRoute && mounted) {
      setState(() {
        _isCalculatingRoute = false;
      });
    }
  }

  // Función para limpiar las capas de ruta previas
  Future<void> _clearPreviousRouteLayers() async {
    if (mapboxMap == null) return;
    print("[BondiUY_Debug] Limpiando capas y fuentes de ruta anteriores...");

    // AÑADIDO: Ocultar la barra de instrucciones colapsada y limpiar los datos de la ruta
    if (mounted) {
      setState(() {
        _showCollapsedInstructionsBar = false;
        _currentRouteLegs = [];
        _selectedLegIndex = null; // Limpiar selección
        _legLayerIds.clear(); // Limpiar mapeo de capas
        _isInOverviewMode = false; // Restablecer modo vista general
        _userManuallyMovedMap =
            false; // MODIFICADO: Resetear flag consistentemente
        _isProgrammaticCameraMove = false; // MODIFICADO: Y este también
        _highlightedBusPosition = null; // Limpiar posición del bus resaltado
      });
    }

    // Limpiar capas y fuentes de los segmentos de la ruta
    for (String layerId in _dynamicRouteLayerIds) {
      try {
        await mapboxMap!.style.removeStyleLayer(layerId);
      } catch (e) {
        print(
          "[BondiUY_Debug] Advertencia: No se pudo remover la capa de segmento $layerId: $e",
        );
      }
    }
    _dynamicRouteLayerIds.clear();

    for (String sourceId in _dynamicRouteSourceIds) {
      try {
        await mapboxMap!.style.removeStyleSource(sourceId);
      } catch (e) {
        print(
          "[BondiUY_Debug] Advertencia: No se pudo remover la fuente de segmento $sourceId: $e",
        );
      }
    }
    _dynamicRouteSourceIds.clear();

    // AÑADIDO: Limpiar también la capa y fuente de las paradas de ruta específicas
    try {
      // Eliminar capa de paradas principales de ruta
      if (await mapboxMap!.style.styleLayerExists(ROUTE_MAIN_STOPS_LAYER_ID)) {
        await mapboxMap!.style.removeStyleLayer(ROUTE_MAIN_STOPS_LAYER_ID);
        print(
          "[BondiUY_Debug_GraphQL] Capa de paradas principales de ruta ($ROUTE_MAIN_STOPS_LAYER_ID) eliminada.",
        );
      }
      // Eliminar capa de paradas intermedias de ruta
      if (await mapboxMap!.style.styleLayerExists(
        ROUTE_INTERMEDIATE_STOPS_LAYER_ID,
      )) {
        await mapboxMap!.style.removeStyleLayer(
          ROUTE_INTERMEDIATE_STOPS_LAYER_ID,
        );
        print(
          "[BondiUY_Debug_GraphQL] Capa de paradas intermedias de ruta ($ROUTE_INTERMEDIATE_STOPS_LAYER_ID) eliminada.",
        );
      }
    } catch (e) {
      print(
        "[BondiUY_Debug_GraphQL] Adv: No se pudo remover alguna de las capas de paradas de ruta: $e",
      );
    }
    try {
      if (await mapboxMap!.style.styleSourceExists(ROUTE_STOPS_SOURCE_ID)) {
        await mapboxMap!.style.removeStyleSource(ROUTE_STOPS_SOURCE_ID);
        print(
          "[BondiUY_Debug_GraphQL] Fuente de paradas de ruta ($ROUTE_STOPS_SOURCE_ID) eliminada.",
        );
      }
    } catch (e) {
      // No es un error crítico si no existen aún
      // print("[BondiUY_Debug_GraphQL] Adv: No se pudo remover la fuente de paradas de ruta $ROUTE_STOPS_SOURCE_ID: $e");
    }

    // AÑADIDO: Asegurar que la capa de paradas generales (STOPS_LAYER_ID) sea visible
    try {
      if (await mapboxMap!.style.styleLayerExists(STOPS_LAYER_ID)) {
        await mapboxMap!.style.setStyleLayerProperty(
          STOPS_LAYER_ID,
          "visibility",
          "visible",
        );
        print(
          "[BondiUY_Debug_GraphQL] Capa de paradas generales ($STOPS_LAYER_ID) restaurada a visible.",
        );
      }
    } catch (e) {
      print(
        "[BondiUY_Debug_GraphQL] Error restaurando visibilidad de capa $STOPS_LAYER_ID: $e",
      );
    }
  }

  // AÑADIDO: Función para limpiar y mostrar solo las paradas relevantes de la ruta actual.
  Future<void> _displayRelevantStops(List<dynamic> legs) async {
    if (mapboxMap == null) return;

    List<Map<String, dynamic>> relevantStopFeatures = [];
    // AÑADIDO: Conjunto para rastrear coordenadas de paradas ya añadidas y evitar duplicados
    Set<String> addedStopCoords = {};

    for (var leg in legs) {
      final String mode = leg['mode']?.toUpperCase() ?? '';
      if (mode == 'BUS' || mode == 'TRANSIT') {
        // Parada de inicio del tramo
        final fromPlace = leg['from'];
        if (fromPlace != null &&
            fromPlace['lat'] != null &&
            fromPlace['lon'] != null) {
          final String coordKey = "${fromPlace['lat']},${fromPlace['lon']}";
          if (!addedStopCoords.contains(coordKey)) {
            relevantStopFeatures.add({
              "type": "Feature",
              "geometry": {
                "type": "Point",
                "coordinates": [fromPlace['lon'], fromPlace['lat']],
              },
              "properties": {
                "name": fromPlace['name'] ?? 'Parada de subida',
                "type": "route_stop",
                "stop_type": "main_stop", // AÑADIDO
              },
            });
            addedStopCoords.add(coordKey);
          }
        }

        // MODIFICADO: Usar leg['intermediatePlaces'] en lugar de leg['steps']
        final List<dynamic>? intermediatePlaces =
            leg['intermediatePlaces'] as List<dynamic>?;
        if (intermediatePlaces != null) {
          for (var place in intermediatePlaces) {
            final placeLat = place['lat'] as double?;
            final placeLon = place['lon'] as double?;
            final placeName = place['name'] as String?;

            if (placeLat != null && placeLon != null) {
              final String coordKey = "$placeLat,$placeLon";
              // Evitar añadir si es la misma que la parada 'from' o 'to' del leg (poco probable para intermediatePlaces),
              // o si ya fue añadida.
              bool isFromPlace =
                  fromPlace != null &&
                  fromPlace['lat'] == placeLat &&
                  fromPlace['lon'] == placeLon;
              final toPlace =
                  leg['to']; // Necesitamos toPlace para la comparación
              bool isToPlace =
                  toPlace != null &&
                  toPlace['lat'] == placeLat &&
                  toPlace['lon'] == placeLon;

              if (!addedStopCoords.contains(coordKey) &&
                  !isFromPlace &&
                  !isToPlace) {
                relevantStopFeatures.add({
                  "type": "Feature",
                  "geometry": {
                    "type": "Point",
                    "coordinates": [placeLon, placeLat],
                  },
                  "properties": {
                    "name": placeName ?? 'Parada intermedia',
                    "type": "route_stop",
                    "stop_type": "intermediate_stop", // AÑADIDO
                  },
                });
                addedStopCoords.add(coordKey);
              }
            }
          }
        }

        // Parada de fin del tramo
        final toPlace = leg['to'];
        if (toPlace != null &&
            toPlace['lat'] != null &&
            toPlace['lon'] != null) {
          final String coordKey = "${toPlace['lat']},${toPlace['lon']}";
          if (!addedStopCoords.contains(coordKey)) {
            relevantStopFeatures.add({
              "type": "Feature",
              "geometry": {
                "type": "Point",
                "coordinates": [toPlace['lon'], toPlace['lat']],
              },
              "properties": {
                "name": toPlace['name'] ?? 'Parada de bajada',
                "type": "route_stop",
                "stop_type": "main_stop", // AÑADIDO
              },
            });
            addedStopCoords.add(coordKey);
          }
        }
      }
    }

    if (relevantStopFeatures.isEmpty) {
      print(
        "[BondiUY_Debug_GraphQL] No se encontraron paradas relevantes en la ruta para mostrar.",
      );
      // Asegurarse de que si no hay paradas relevantes, cualquier capa/fuente anterior de paradas de ruta se limpie.
      // Esto ya debería estar cubierto por _clearPreviousRouteLayers.
      // Pero por si acaso esta función se modifica para ser llamada en otros contextos:
      try {
        await mapboxMap!.style.removeStyleLayer(ROUTE_MAIN_STOPS_LAYER_ID);
        await mapboxMap!.style.removeStyleLayer(
          ROUTE_INTERMEDIATE_STOPS_LAYER_ID,
        );
      } catch (_) {}
      try {
        await mapboxMap!.style.removeStyleSource(ROUTE_STOPS_SOURCE_ID);
      } catch (_) {}
      return;
    }

    final Map<String, dynamic> geoJsonFeatureCollection = {
      "type": "FeatureCollection",
      "features": relevantStopFeatures,
    };
    final String geoJsonData = json.encode(geoJsonFeatureCollection);

    try {
      final sourceExists = await mapboxMap!.style.styleSourceExists(
        ROUTE_STOPS_SOURCE_ID,
      );
      if (!sourceExists) {
        await mapboxMap!.style.addSource(
          GeoJsonSource(id: ROUTE_STOPS_SOURCE_ID, data: geoJsonData),
        );
        print(
          "[BondiUY_Debug_GraphQL] GeoJsonSource '$ROUTE_STOPS_SOURCE_ID' para paradas de ruta añadida.",
        );
      } else {
        final source =
            await mapboxMap!.style.getSource(ROUTE_STOPS_SOURCE_ID)
                as GeoJsonSource?;
        await source?.updateGeoJSON(geoJsonData);
        print(
          "[BondiUY_Debug_GraphQL] GeoJsonSource '$ROUTE_STOPS_SOURCE_ID' actualizada.",
        );
      }

      // Capa para paradas PRINCIPALES de la ruta (inicio/fin de tramos de bus)
      final mainLayerExists = await mapboxMap!.style.styleLayerExists(
        ROUTE_MAIN_STOPS_LAYER_ID,
      );
      if (!mainLayerExists) {
        await mapboxMap!.style.addLayer(
          SymbolLayer(
            id: ROUTE_MAIN_STOPS_LAYER_ID,
            sourceId: ROUTE_STOPS_SOURCE_ID,
            filter: [
              '==',
              ['get', 'stop_type'],
              'main_stop',
            ],
            iconImage: "bus-icon",
            iconSize:
                0.5, // AJUSTADO: Para imagen base de 64px (antes 1.0 para 32px)
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
            minZoom: 10.0, // Visibles desde más lejos
          ),
        );
        await _printLayerOrder();
        print(
          "[BondiUY_Debug_GraphQL] SymbolLayer '$ROUTE_MAIN_STOPS_LAYER_ID' para paradas principales de ruta añadida.",
        );
      } else {
        print(
          "[BondiUY_Debug_GraphQL] SymbolLayer '$ROUTE_MAIN_STOPS_LAYER_ID' ya existe.",
        );
      }

      // Capa para paradas INTERMEDIAS de la ruta
      final intermediateLayerExists = await mapboxMap!.style.styleLayerExists(
        ROUTE_INTERMEDIATE_STOPS_LAYER_ID,
      );
      if (!intermediateLayerExists) {
        await mapboxMap!.style.addLayer(
          SymbolLayer(
            id: ROUTE_INTERMEDIATE_STOPS_LAYER_ID,
            sourceId: ROUTE_STOPS_SOURCE_ID,
            filter: [
              '==',
              ['get', 'stop_type'],
              'intermediate_stop',
            ],
            iconImage: "bus-icon",
            iconSize:
                0.4, // AJUSTADO: Para imagen base de 64px (antes 0.8 para 32px)
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
            minZoom: 13.0, // Visibles solo con más zoom
          ),
        );
        await _printLayerOrder();
        print(
          "[BondiUY_Debug_GraphQL] SymbolLayer '$ROUTE_INTERMEDIATE_STOPS_LAYER_ID' para paradas intermedias de ruta añadida.",
        );
      } else {
        print(
          "[BondiUY_Debug_GraphQL] SymbolLayer '$ROUTE_INTERMEDIATE_STOPS_LAYER_ID' ya existe.",
        );
      }
    } catch (e) {
      print(
        "[BondiUY_Debug_GraphQL] Error añadiendo/actualizando fuente/capa para paradas de ruta: $e",
      );
    }
  }

  // AÑADIDO: Función para calcular la caja delimitadora de una ruta.
  Future<CoordinateBounds?> _calculateBoundsForRoute(List<dynamic> legs) async {
    if (legs.isEmpty) return null;

    double? minLat, maxLat, minLon, maxLon;

    for (var leg in legs) {
      final String polylineString = leg['legGeometry']?['points'] ?? '';
      if (polylineString.isNotEmpty) {
        List<PointLatLng> decodedPoints = PolylinePoints().decodePolyline(
          polylineString,
        );
        for (var p in decodedPoints) {
          if (minLat == null || p.latitude < minLat) minLat = p.latitude;
          if (maxLat == null || p.latitude > maxLat) maxLat = p.latitude;
          if (minLon == null || p.longitude < minLon) minLon = p.longitude;
          if (maxLon == null || p.longitude > maxLon) maxLon = p.longitude;
        }
      } else {
        // Si no hay polyline, considerar las coordenadas de 'from' y 'to' del leg
        final fromPlace = leg['from'];
        final toPlace = leg['to'];
        if (fromPlace != null &&
            fromPlace['lat'] != null &&
            fromPlace['lon'] != null) {
          final lat = fromPlace['lat'] as double;
          final lon = fromPlace['lon'] as double;
          if (minLat == null || lat < minLat) minLat = lat;
          if (maxLat == null || lat > maxLat) maxLat = lat;
          if (minLon == null || lon < minLon) minLon = lon;
          if (maxLon == null || lon > maxLon) maxLon = lon;
        }
        if (toPlace != null &&
            toPlace['lat'] != null &&
            toPlace['lon'] != null) {
          final lat = toPlace['lat'] as double;
          final lon = toPlace['lon'] as double;
          if (minLat == null || lat < minLat) minLat = lat;
          if (maxLat == null || lat > maxLat) maxLat = lat;
          if (minLon == null || lon < minLon) minLon = lon;
          if (maxLon == null || lon > maxLon) maxLon = lon;
        }
      }
    }

    if (minLat != null && maxLat != null && minLon != null && maxLon != null) {
      // Asegurarse de que minLat <= maxLat y minLon <= maxLon
      // Esto es importante si solo hay un punto en la ruta.
      if (minLat == maxLat) {
        // Si solo hay un punto o todos los puntos están en la misma latitud
        maxLat =
            minLat +
            0.001; // Añadir un pequeño offset para crear un bounds válido
        minLat = minLat - 0.001;
      }
      if (minLon == maxLon) {
        // Si solo hay un punto o todos los puntos están en la misma longitud
        maxLon = minLon + 0.001; // Añadir un pequeño offset
        minLon = minLon - 0.001;
      }

      final Point southwest = Point(coordinates: Position(minLon, minLat));
      final Point northeast = Point(coordinates: Position(maxLon, maxLat));
      return CoordinateBounds(
        southwest: southwest,
        northeast: northeast,
        infiniteBounds: false,
      );
    }
    return null;
  }

  // AÑADIDO: Función para calcular la caja delimitadora a partir de una lista de Positions.
  Future<CoordinateBounds?> _calculateBoundsForPositions(
    List<Position> positions,
  ) async {
    if (positions.isEmpty) return null;

    double? minLat, maxLat, minLon, maxLon;

    for (var pos in positions) {
      final lat = pos.lat as double; // CORREGIDO: Cast a double
      final lon = pos.lng as double; // CORREGIDO: Cast a double

      if (minLat == null || lat < minLat) minLat = lat;
      if (maxLat == null || lat > maxLat) maxLat = lat;
      if (minLon == null || lon < minLon) minLon = lon;
      if (maxLon == null || lon > maxLon) maxLon = lon;
    }

    if (minLat != null && maxLat != null && minLon != null && maxLon != null) {
      // Asegurarse de que minLat <= maxLat y minLon <= maxLon
      // y añadir un pequeño offset si son iguales (para un solo punto o línea recta)
      if (minLat == maxLat) {
        maxLat = minLat + 0.001;
        minLat = minLat - 0.001;
      }
      if (minLon == maxLon) {
        maxLon = minLon + 0.001;
        minLon = minLon - 0.001;
      }

      final Point southwest = Point(coordinates: Position(minLon, minLat));
      final Point northeast = Point(coordinates: Position(maxLon, maxLat));
      return CoordinateBounds(
        southwest: southwest,
        northeast: northeast,
        infiniteBounds: false,
      );
    }
    return null;
  }

  // AÑADIDO: Función para hacer zoom y centrar el mapa en la ruta calculada.
  Future<void> _zoomToRouteBounds(List<dynamic> legs) async {
    if (mapboxMap == null || legs.isEmpty) return;

    final CoordinateBounds? routeBounds = await _calculateBoundsForRoute(legs);

    if (routeBounds != null) {
      try {
        // Define un padding alrededor de la ruta para que no quede pegada a los bordes.
        // El padding inferior puede ser mayor si planeas mostrar un BottomSheet con instrucciones.
        final MbxEdgeInsets padding = MbxEdgeInsets(
          top: 60.0,
          left: 40.0,
          bottom: 60.0,
          right: 40.0,
        );
        // Aumentado el padding superior e inferior

        // TEMPORALMENTE COMENTADO DEBIDO A LINTER ERROR: 'cameraForBounds' not defined.
        // Por favor, verifica la forma correcta de obtener CameraOptions desde CoordinateBounds
        // en tu versión de mapbox_maps_flutter y descomenta/adapta las siguientes líneas.
        // CORRECCIÓN: El método correcto es 'cameraForCoordinateBounds'
        final CameraOptions cameraOptions = await mapboxMap!
            .cameraForCoordinateBounds(
              routeBounds,
              padding,
              null, // bearing opcional
              null, // pitch opcional
              null, // maxZoom
              null, // offset
            );

        // Animar la cámara a la nueva vista.
        _isProgrammaticCameraMove = true;
        await mapboxMap!.flyTo(
          cameraOptions,
          MapAnimationOptions(duration: 1500),
        ); // Duración de 1.5 segundos
        // _isProgrammaticCameraMove = false; // REMOVED: Handled by _onMapIdle
        print(
          "[BondiUY_Debug_GraphQL] Cámara ajustada para mostrar la ruta completa.",
        );
      } catch (e) {
        _isProgrammaticCameraMove = false; // Reset on error
        print(
          "[BondiUY_Debug_GraphQL] Error al calcular o volar a los límites de la ruta: $e",
        );
      }
    } else {
      print(
        "[BondiUY_Debug_GraphQL] No se pudieron calcular los límites para la ruta.",
      );
    }
  }

  // Función auxiliar para distancia
  double _calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double R = 6371000; // Radio de la Tierra en metros

    double lat1Rad = math.pi * lat1 / 180;
    double lon1Rad = math.pi * lon1 / 180;
    double lat2Rad = math.pi * lat2 / 180;
    double lon2Rad = math.pi * lon2 / 180;

    double dLat = lat2Rad - lat1Rad;
    double dLon = lon2Rad - lon1Rad;

    double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return R * c; // Distancia en metros
  }

  // AÑADIDO: Función para actualizar el resaltado de la ruta en el mapa
  Future<void> _updateMapRouteHighlight() async {
    if (mapboxMap == null || _legLayerIds.isEmpty) return;

    for (final entry in _legLayerIds.entries) {
      final legIndex = entry.key;
      final layerIds = entry.value; // [mainLayerId, shadowLayerId]
      final mainLayerId = layerIds[0];
      final shadowLayerId = layerIds[1];

      final bool isSelected = legIndex == _selectedLegIndex;

      // Determinar propiedades basadas en la selección
      final mainOpacity = isSelected ? 0.9 : 0.35;
      final mainWidth = isSelected ? 6.0 : 3.0;
      final shadowOpacity = isSelected ? 0.7 : 0.25;
      final shadowWidth = isSelected ? 8.0 : 5.0;
      // Obtener el color original de la capa principal para no perderlo
      // Esto es un poco más complejo, ya que el color se definió al crear la capa.
      // Por simplicidad, asumiremos que podemos re-aplicar opacidad y grosor.
      // Si se necesitaran colores dinámicos, la lógica de _drawRouteSegment sería más compleja
      // o necesitaríamos almacenar el color original junto con los IDs de capa.

      try {
        // Actualizar capa principal
        await mapboxMap!.style.setStyleLayerProperty(
          mainLayerId,
          "line-opacity",
          mainOpacity,
        );
        await mapboxMap!.style.setStyleLayerProperty(
          mainLayerId,
          "line-width",
          mainWidth,
        );

        // Actualizar capa de sombra
        await mapboxMap!.style.setStyleLayerProperty(
          shadowLayerId,
          "line-opacity",
          shadowOpacity,
        );
        await mapboxMap!.style.setStyleLayerProperty(
          shadowLayerId,
          "line-width",
          shadowWidth,
        );
      } catch (e) {
        print(
          "[BondiUY_Debug] Error actualizando propiedades de capa para el tramo $legIndex: $e",
        );
      }
    }
    print(
      "[BondiUY_Debug] Resaltado de ruta actualizado. Tramo seleccionado: $_selectedLegIndex",
    );
  }

  // AÑADIDO: Función para construir la lista de Widgets de instrucciones.
  List<Widget> _buildInstructionListTiles(
    List<dynamic> legs,
    int? currentSelectedLegIndex,
    Function(int legIndex) onLegSelected,
  ) {
    List<Widget> instructionTiles = [];

    // Punto de inicio
    String origenDisplayName = legs.first['from']?['name'] ?? 'Punto de inicio';
    if (origenDisplayName.toLowerCase() == 'origin' &&
        _origenController.text.isNotEmpty) {
      origenDisplayName = _origenController.text;
    }
    instructionTiles.add(
      ListTile(
        leading: const Icon(Icons.flag_outlined),
        title: Text("Origen: $origenDisplayName"),
        dense: true,
      ),
    );

    for (int i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final String mode = leg['mode']?.toUpperCase() ?? '';
      final fromName = leg['from']?['name'] ?? 'Ubicación desconocida';
      final toName = leg['to']?['name'] ?? 'Ubicación desconocida';
      final distance =
          leg['distance'] != null ? (leg['distance'] as double).round() : 0;
      // AÑADIDO: Obtener y formatear duración
      final durationSeconds = leg['duration'] as double? ?? 0.0;
      final durationMinutes = (durationSeconds / 60).round();
      String durationText = " (~${durationMinutes} min)";
      if (durationMinutes == 0 && durationSeconds > 0) {
        durationText = " (< 1 min)"; // Para duraciones muy cortas
      } else if (durationMinutes == 0) {
        durationText = ""; // No mostrar si la duración es 0
      }

      if (mode == 'WALK') {
        final steps = leg['steps'] as List<dynamic>? ?? [];

        String walkDestinationDisplay = toName;
        // Si el destino de esta caminata es "Destination", este es el último leg de toda la ruta,
        // Y tenemos un texto en _destinoController, usamos ese texto para el display.
        if (toName.toLowerCase() == 'destination' &&
            i == legs.length - 1 &&
            _destinoController.text.isNotEmpty) {
          walkDestinationDisplay = _destinoController.text;
        }

        // Texto principal de la instrucción de caminata
        String walkTitle =
            "Caminar ${distance}m hacia $walkDestinationDisplay" + durationText;

        // AÑADIDO: Guardar el índice actual para el onTap
        final int currentLegIndexForTap = i;
        instructionTiles.add(
          ListTile(
            leading: const Icon(
              Icons.directions_walk,
              color: Colors.blueAccent,
            ),
            title: Text(walkTitle),
            dense: true,
            selected: currentSelectedLegIndex == i,
            selectedTileColor: Colors.blue.withOpacity(0.15),
            onTap: () => onLegSelected(currentLegIndexForTap),
          ),
        );
        // Código opcional para pasos individuales sigue comentado
        /* ... */
      } else if (mode == 'BUS' || mode == 'TRANSIT') {
        final route = leg['route'];
        final lineName =
            route?['shortName'] ?? route?['longName'] ?? 'Bus desconocido';
        // AÑADIDO: Guardar el índice actual para el onTap
        final int currentLegIndexForTap = i;
        instructionTiles.add(
          ListTile(
            leading: const Icon(
              Icons.directions_bus,
              color: Colors.deepOrangeAccent,
            ),
            title: Text("Tomar bus línea $lineName" + durationText),
            subtitle: Text("Desde: $fromName\nHasta: $toName"),
            isThreeLine: true,
            selected: currentSelectedLegIndex == i,
            selectedTileColor: Colors.orange.withOpacity(0.15),
            onTap: () => onLegSelected(currentLegIndexForTap),
          ),
        );
      }
      // Se pueden añadir más modos aquí (BICYCLE, CAR, etc.)
    }

    // Punto final
    String destinoDisplayName = legs.last['to']?['name'] ?? 'Punto final';
    if (destinoDisplayName.toLowerCase() == 'destination' &&
        _destinoController.text.isNotEmpty) {
      destinoDisplayName = _destinoController.text;
    }
    instructionTiles.add(
      ListTile(
        leading: const Icon(Icons.flag, color: Colors.green),
        title: Text("Destino: $destinoDisplayName"),
        dense: true,
      ),
    );

    return instructionTiles;
  }

  // AÑADIDO: Función para mostrar el BottomSheet con las instrucciones.
  void _showTripInstructionsBottomSheet(List<dynamic> legs) {
    if (legs.isEmpty) return;

    // Usar StatefulBuilder para permitir actualizaciones internas del BottomSheet
    // como el resaltado de la selección sin reconstruir toda la pantalla.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (BuildContext bc) {
        // Usar StatefulBuilder para manejar el estado de la selección dentro del BottomSheet
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // Construir los widgets de instrucción, pasando el índice seleccionado
            // y la función para manejar la selección.
            final instructionWidgets = _buildInstructionListTiles(
              legs,
              _selectedLegIndex, // Usar el _selectedLegIndex del _MapScreenState
              (int tappedLegIndex) {
                // Cuando un tramo es tocado en la lista:
                // 1. Actualizar el estado del _MapScreenState (afecta al mapa)
                setState(() {
                  _selectedLegIndex = tappedLegIndex;
                  _userManuallyMovedMap = false; // AÑADIDO: Resetear flag
                  _isWaitingForInitialLegZoomToComplete = true; // AÑADIDO
                });
                // 2. Actualizar el resaltado en el mapa
                _updateMapRouteHighlight();
                // 3. Enfocar el mapa en el tramo seleccionado
                _zoomToLeg(tappedLegIndex);
                // 4. Actualizar el estado del BottomSheet para reflejar la nueva selección
                setModalState(() {
                  // _selectedLegIndex ya está actualizado, no es necesario reasignarlo aquí
                  // si _buildInstructionListTiles lee directamente de la variable de estado de MapScreen.
                });
              },
            );

            return SafeArea(
              child: FractionallySizedBox(
                heightFactor: 0.6,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start, // Alinear título a la izquierda
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        16.0,
                        16.0,
                        16.0,
                        8.0,
                      ), // Ajustar padding
                      child: Text(
                        'Instrucciones de Viaje',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      // AÑADIDO: Padding alrededor del ListView
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: instructionWidgets.length,
                          itemBuilder:
                              (context, index) => instructionWidgets[index],
                          // Quitar separadores automáticos para controlar espaciado con padding/margins si se desea
                          // separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                          separatorBuilder:
                              (context, index) => const SizedBox(
                                height: 4,
                              ), // Espacio pequeño entre tiles
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // AÑADIDO: Widget para la barra de instrucciones colapsada
  Widget _buildCollapsedInstructionsBar() {
    if (!_showCollapsedInstructionsBar ||
        _currentRouteLegs.isEmpty ||
        _isInOverviewMode || // No mostrar en modo vista general
        _selectedLegIndex == null || // Asegurar que haya un tramo seleccionado
        _selectedLegIndex! >= _currentRouteLegs.length) {
      return const SizedBox.shrink();
    }

    final leg = _currentRouteLegs[_selectedLegIndex!];
    final String mode = leg['mode']?.toUpperCase() ?? '';
    final fromName = leg['from']?['name'] ?? 'Ubicación desconocida';
    final toName = leg['to']?['name'] ?? 'Ubicación desconocida';
    final distance = (leg['distance'] as double? ?? 0.0).round();
    final durationSeconds = leg['duration'] as double? ?? 0.0;
    final durationMinutes = (durationSeconds / 60).round();

    String durationText = " (~${durationMinutes} min)";
    if (durationMinutes == 0 && durationSeconds > 0) {
      durationText = " (< 1 min)";
    } else if (durationMinutes == 0) {
      durationText = "";
    }

    IconData legIconData = Icons.device_unknown;
    Color legIconColor = Colors.grey;
    String legTitle = "";
    String legSubtitle = "";

    if (mode == 'WALK') {
      legIconData = Icons.directions_walk;
      legIconColor = Colors.blueAccent;
      String walkDestinationDisplay = toName;
      // Si el destino de esta caminata es "Destination" y tenemos un texto en _destinoController,
      // y es el último tramo, usamos ese texto para el display.
      if (toName.toLowerCase() == 'destination' &&
          _selectedLegIndex == _currentRouteLegs.length - 1 &&
          _destinoController.text.isNotEmpty) {
        walkDestinationDisplay = _destinoController.text;
      }
      legTitle = "Caminar ${distance}m hacia $walkDestinationDisplay";
      legSubtitle = durationText.trim(); // Solo la duración para el subtítulo
    } else if (mode == 'BUS' || mode == 'TRANSIT') {
      legIconData = Icons.directions_bus;
      legIconColor = Colors.deepOrangeAccent;
      final route = leg['route'];
      final lineName =
          route?['shortName'] ?? route?['longName'] ?? 'Bus desconocido';
      legTitle = "Tomar bus línea $lineName";
      legSubtitle = "Desde: $fromName\nHasta: $toName$durationText";
    }

    return Positioned(
      bottom: 10, // Un pequeño margen desde abajo
      left: 10,
      right: 10,
      child: GestureDetector(
        onTap: () {
          // Este onTap es para la barra completa si se quitan las flechas del GestureDetector principal
          // Considerar si este GestureDetector general sigue siendo necesario o si la acción
          // de expandir se asocia solo a una parte específica.
          // Por ahora, lo dejamos para que toda la barra sea menos las flechas sea tappable.
          // _showTripInstructionsBottomSheet(_currentRouteLegs);
        },
        child: Material(
          elevation: 6.0,
          borderRadius: BorderRadius.circular(12.0),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surface, // Usar color del tema
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Row(
              children: <Widget>[
                // AÑADIDO: Botón de navegación - TRAMO ANTERIOR
                IconButton(
                  icon: Icon(Icons.chevron_left, size: 30),
                  onPressed:
                      (_selectedLegIndex! > 0) ? _navigateToPreviousLeg : null,
                  color: Theme.of(context).colorScheme.primary,
                  disabledColor: Colors.grey.withOpacity(0.5),
                ),
                // MODIFICADO: Contenido central ahora envuelto en Expanded y GestureDetector
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _showTripInstructionsBottomSheet(_currentRouteLegs);
                    },
                    child: Container(
                      // Container para asegurar que el tap funcione en área vacía
                      color:
                          Colors
                              .transparent, // Hacer el Container tappable pero invisible
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4.0,
                        vertical: 8.0,
                      ), // Padding interno
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(legIconData, color: legIconColor, size: 28),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  legTitle,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleSmall?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (legSubtitle.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      legSubtitle,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.7),
                                      ),
                                      maxLines:
                                          mode == 'BUS' || mode == 'TRANSIT'
                                              ? 2
                                              : 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // AÑADIDO: Botón de navegación - SIGUIENTE TRAMO
                IconButton(
                  icon: Icon(Icons.chevron_right, size: 30),
                  onPressed:
                      (_selectedLegIndex! < _currentRouteLegs.length - 1)
                          ? _navigateToNextLeg
                          : null,
                  color: Theme.of(context).colorScheme.primary,
                  disabledColor: Colors.grey.withOpacity(0.5),
                ),
                // Eliminado el Icon(Icons.keyboard_arrow_up) ya que el centro es tappable
              ],
            ),
          ),
        ),
      ),
    );
  }

  // AÑADIDO: Función para aplicar un estilo uniforme a la ruta en modo vista general
  Future<void> _applyOverviewRouteStyle() async {
    if (mapboxMap == null || _legLayerIds.isEmpty) return;

    const overviewOpacity = 0.8;
    const overviewWidth = 5.0;
    const overviewShadowOpacity = 0.6;
    const overviewShadowWidth = 7.0;

    for (final entry in _legLayerIds.entries) {
      final layerIds = entry.value; // [mainLayerId, shadowLayerId]
      final mainLayerId = layerIds[0];
      final shadowLayerId = layerIds[1];

      // AÑADIDO: Verificar existencia de la capa antes de modificarla
      bool mainLayerExists = await mapboxMap!.style.styleLayerExists(
        mainLayerId,
      );
      bool shadowLayerExists = await mapboxMap!.style.styleLayerExists(
        shadowLayerId,
      );

      try {
        // Actualizar capa principal
        if (mainLayerExists) {
          await mapboxMap!.style.setStyleLayerProperty(
            mainLayerId,
            "line-opacity",
            overviewOpacity,
          );
          await mapboxMap!.style.setStyleLayerProperty(
            mainLayerId,
            "line-width",
            overviewWidth,
          );
        }

        // Actualizar capa de sombra
        if (shadowLayerExists) {
          await mapboxMap!.style.setStyleLayerProperty(
            shadowLayerId,
            "line-opacity",
            overviewShadowOpacity,
          );
          await mapboxMap!.style.setStyleLayerProperty(
            shadowLayerId,
            "line-width",
            overviewShadowWidth,
          );
        }
      } catch (e) {
        print(
          "[BondiUY_Debug] Error aplicando estilo de vista general a capas ${entry.key}: $e",
        );
      }
    }
    print("[BondiUY_Debug] Estilo de vista general aplicado a la ruta.");
  }

  // AÑADIDO: Función para iniciar la navegación detallada (Paso 2 del wizard)
  void _startDetailedNavigation() {
    if (_currentRouteLegs.isEmpty) return;
    if (mounted) {
      setState(() {
        _isInOverviewMode = false;
        _selectedLegIndex = 0; // Seleccionar el primer tramo
        _showCollapsedInstructionsBar =
            true; // Mostrar la barra ahora que estamos en detalle
        _userManuallyMovedMap =
            false; // MODIFICADO: Resetear flag consistentemente
        _isWaitingForInitialLegZoomToComplete = true; // AÑADIDO
      });
    }
    _zoomToLeg(0); // Enfocar el primer tramo
    _updateMapRouteHighlight(); // Aplicar resaltado de selección

    // AÑADIDO: Iniciar rastreo si el primer tramo es un bus
    if (_currentRouteLegs.isNotEmpty) {
      // CORREGIDO: Añadir casteo explícito
      final firstLeg = _currentRouteLegs.first as Map<String, dynamic>;
      final String mode = firstLeg['mode']?.toUpperCase() ?? '';
      if (mode == 'BUS' || mode == 'TRANSIT') {
        _startTrackingBusLine(firstLeg);
      } else {
        _stopTrackingBusLine(); // Asegurar que no haya rastreo si no es bus
      }
    }
  }

  // AÑADIDO: Función para calcular los límites de un tramo específico
  Future<CoordinateBounds?> _calculateBoundsForLeg(
    int legIndex, {
    Position? additionalPoint,
  }) async {
    if (legIndex < 0 ||
        legIndex >= _currentRouteLegs.length ||
        _currentRouteLegs.isEmpty) {
      return null;
    }

    final leg = _currentRouteLegs[legIndex];
    List<Position> allPositionsForBounds = [];

    final String polylineString = leg['legGeometry']?['points'] ?? '';
    if (polylineString.isNotEmpty) {
      List<PointLatLng> decodedPoints = PolylinePoints().decodePolyline(
        polylineString,
      );
      if (decodedPoints.isNotEmpty) {
        allPositionsForBounds.addAll(
          decodedPoints.map((p) => Position(p.longitude, p.latitude)),
        );
      }
    }

    // Si no hay polyline o estaba vacía, usar puntos from/to del tramo
    if (allPositionsForBounds.isEmpty) {
      final fromPlace = leg['from'];
      final toPlace = leg['to'];
      if (fromPlace != null &&
          fromPlace['lat'] != null &&
          fromPlace['lon'] != null) {
        allPositionsForBounds.add(
          Position(fromPlace['lon'] as double, fromPlace['lat'] as double),
        );
      }
      if (toPlace != null && toPlace['lat'] != null && toPlace['lon'] != null) {
        allPositionsForBounds.add(
          Position(toPlace['lon'] as double, toPlace['lat'] as double),
        );
      }
    }

    // Añadir el punto adicional (bus resaltado) si se proporciona
    if (additionalPoint != null) {
      allPositionsForBounds.add(additionalPoint);
    }

    if (allPositionsForBounds.isEmpty)
      return null; // No hay puntos para el tramo

    return await _calculateBoundsForPositions(allPositionsForBounds);
  }

  // AÑADIDO: Función para hacer zoom a un tramo específico
  Future<void> _zoomToLeg(int legIndex) async {
    if (mapboxMap == null ||
        legIndex < 0 ||
        legIndex >= _currentRouteLegs.length)
      return;

    final currentLeg = _currentRouteLegs[legIndex];
    final String mode = currentLeg['mode']?.toUpperCase() ?? '';

    // Si es un tramo de bus y hay bus resaltado, solo enfocar parada de origen y bus
    if ((mode == 'BUS' || mode == 'TRANSIT') &&
        _highlightedBusPosition != null) {
      final fromPlace = currentLeg['from'];
      if (fromPlace != null &&
          fromPlace['lat'] != null &&
          fromPlace['lon'] != null) {
        final Position paradaOrigen = Position(
          (fromPlace['lon'] as num).toDouble(),
          (fromPlace['lat'] as num).toDouble(),
        );
        final Position busPos = _highlightedBusPosition!;

        // Calcular bounds solo con estos dos puntos
        const double paddingGrados = 0.002; // ~111 metros
        final double minLat =
            math.min(paradaOrigen.lat.toDouble(), busPos.lat.toDouble()) -
            paddingGrados;
        final double maxLat =
            math.max(paradaOrigen.lat.toDouble(), busPos.lat.toDouble()) +
            paddingGrados;
        final double minLon =
            math.min(paradaOrigen.lng.toDouble(), busPos.lng.toDouble()) -
            paddingGrados;
        final double maxLon =
            math.max(paradaOrigen.lng.toDouble(), busPos.lng.toDouble()) +
            paddingGrados;

        final Point southwest = Point(coordinates: Position(minLon, minLat));
        final Point northeast = Point(coordinates: Position(maxLon, maxLat));
        final CoordinateBounds bounds = CoordinateBounds(
          southwest: southwest,
          northeast: northeast,
          infiniteBounds: false,
        );

        final MbxEdgeInsets padding = MbxEdgeInsets(
          top: 80.0,
          left: 50.0,
          bottom: _showCollapsedInstructionsBar ? 100.0 : 80.0,
          right: 50.0,
        );
        final CameraOptions cameraOptions = await mapboxMap!
            .cameraForCoordinateBounds(bounds, padding, null, null, null, null);

        _isProgrammaticCameraMove = true;
        await mapboxMap!.flyTo(
          cameraOptions,
          MapAnimationOptions(duration: 1200),
        );
        print(
          "[BondiUY_Debug_GraphQL] Cámara ajustada para mostrar la ruta completa.",
        );
        return;
      }
    }

    Position? busPositionToInclude;
    // ... código existente ...
    if (mode == 'BUS' || mode == 'TRANSIT') {
      if (!_userManuallyMovedMap && _highlightedBusPosition != null) {
        busPositionToInclude = _highlightedBusPosition;
        print(
          "[BondiUY_Debug_ZoomToLeg] Incluyendo bus resaltado en bounds: ${_highlightedBusPosition!.toJson()}",
        );
      } else {
        print(
          "[BondiUY_Debug_ZoomToLeg] No se incluye bus resaltado. Manual move: $_userManuallyMovedMap, Bus pos: $_highlightedBusPosition",
        );
      }
    }

    final CoordinateBounds? legBounds = await _calculateBoundsForLeg(
      legIndex,
      additionalPoint: busPositionToInclude,
    );

    if (legBounds != null) {
      try {
        // Padding para un solo tramo, puede ser más ajustado o diferente
        final MbxEdgeInsets padding = MbxEdgeInsets(
          top: 80.0,
          left: 50.0,
          bottom:
              _showCollapsedInstructionsBar
                  ? 100.0
                  : 80.0, // Más padding si la barra está
          right: 50.0,
        );
        final CameraOptions cameraOptions = await mapboxMap!
            .cameraForCoordinateBounds(
              legBounds,
              padding,
              null, // bearing opcional
              null, // pitch opcional
              null, // maxZoom
              null, // offset
            );
        _isProgrammaticCameraMove = true;
        await mapboxMap!.flyTo(
          cameraOptions,
          MapAnimationOptions(duration: 1200),
        ); // Duración de 1.2 segundos
        // _isProgrammaticCameraMove = false; // REMOVED: Handled by _onMapIdle
        print(
          "[BondiUY_Debug_GraphQL] Cámara ajustada para mostrar el tramo $legIndex.",
        );
      } catch (e) {
        _isProgrammaticCameraMove = false; // Reset on error
        print(
          "[BondiUY_Debug_GraphQL] Error al calcular o volar a los límites del tramo $legIndex: $e",
        );
      }
    } else {
      print(
        "[BondiUY_Debug_GraphQL] No se pudieron calcular los límites para el tramo $legIndex.",
      );
    }
  }

  // AÑADIDO: Funciones para navegar entre tramos desde la barra colapsada
  void _navigateToPreviousLeg() {
    if (_selectedLegIndex == null || _selectedLegIndex! <= 0) return;
    setState(() {
      _selectedLegIndex = _selectedLegIndex! - 1;
      _userManuallyMovedMap =
          false; // MODIFICADO: Resetear flag consistentemente
      _isWaitingForInitialLegZoomToComplete = true; // AÑADIDO
    });
    _updateMapRouteHighlight();
    _zoomToLeg(_selectedLegIndex!);

    // AÑADIDO: Actualizar rastreo de bus
    // CORREGIDO: Añadir casteo explícito
    final currentLeg =
        _currentRouteLegs[_selectedLegIndex!] as Map<String, dynamic>;
    final String mode = currentLeg['mode']?.toUpperCase() ?? '';
    if (mode == 'BUS' || mode == 'TRANSIT') {
      _startTrackingBusLine(currentLeg);
    } else {
      _stopTrackingBusLine();
    }
  }

  void _navigateToNextLeg() {
    if (_selectedLegIndex == null ||
        _selectedLegIndex! >= _currentRouteLegs.length - 1)
      return;
    setState(() {
      _selectedLegIndex = _selectedLegIndex! + 1;
      _userManuallyMovedMap =
          false; // MODIFICADO: Resetear flag consistentemente
      _isWaitingForInitialLegZoomToComplete = true; // AÑADIDO
    });
    _updateMapRouteHighlight();
    _zoomToLeg(_selectedLegIndex!);

    // AÑADIDO: Actualizar rastreo de bus
    // CORREGIDO: Añadir casteo explícito
    final currentLeg =
        _currentRouteLegs[_selectedLegIndex!] as Map<String, dynamic>;
    final String mode = currentLeg['mode']?.toUpperCase() ?? '';
    if (mode == 'BUS' || mode == 'TRANSIT') {
      _startTrackingBusLine(currentLeg);
    } else {
      _stopTrackingBusLine();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BondiUY')),
      body: Stack(
        // MODIFICADO: Envolver Column en Stack para el botón "Iniciar Viaje"
        children: [
          Column(
            children: <Widget>[
              // MODIFICADO: Usar el nuevo panel de búsqueda condicional
              _buildTopSearchPanel(),
              // El botón Buscar Ruta ahora está dentro de _buildExpandedSearchPanelUI()
              // Padding(
              //   padding: const EdgeInsets.symmetric(vertical: 16.0),
              //   child: ElevatedButton(
              //     onPressed:
              //         (_isCalculatingRoute ||
              //                 _origenCoordinates == null ||
              //                 _destinoCoordinates == null)
              //             ? null
              //             : _handleSearchRouteWithGraphQl,
              //     child:
              //         _isCalculatingRoute
              //             ? const SizedBox(
              //                 height: 20.0,
              //                 width: 20.0,
              //                 child: CircularProgressIndicator(
              //                   strokeWidth: 2.0,
              //                   color: Colors.white,
              //                 ),
              //               )
              //             : const Text(
              //                 'Buscar Ruta',
              //               ),
              //   ),
              // ),
              Expanded(
                child: Stack(
                  children: [
                    MapWidget(
                      key: const ValueKey("mapWidget"),
                      onMapCreated: _onMapCreated,
                      onStyleLoadedListener: _onStyleLoadedListener,
                      cameraOptions: _initialCameraOptions,
                      styleUri: MapboxStyles.MAPBOX_STREETS,
                      onTapListener: _onMapWidgetTap,
                      onCameraChangeListener:
                          _onMapCameraChange, // CORREGIDO: de onMoveListener a onCameraChangeListener y el nombre del método
                      onMapIdleListener:
                          _onMapIdle, // AÑADIDO onMapIdleListener
                    ),
                    // AÑADIDO: Overlay de carga condicional
                    if (_isCalculatingRoute)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(
                            0.3,
                          ), // Fondo semitransparente
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                    // AÑADIDO: Barra de instrucciones colapsada
                    _buildCollapsedInstructionsBar(),
                  ],
                ),
              ),
            ],
          ),
          // AÑADIDO: Botón "Iniciar Viaje" condicional
          if (_isInOverviewMode && _currentRouteLegs.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                  ), // Hacer el botón más grande
                  textStyle: const TextStyle(fontSize: 16), // Texto más grande
                ),
                onPressed: _startDetailedNavigation,
                child: const Text("Iniciar Viaje"), // MODIFICADO TEXTO
              ),
            ),
          // AÑADIDO: Mensaje "Este será tu recorrido completo" condicional
          if (_isInOverviewMode && _currentRouteLegs.isNotEmpty)
            Positioned(
              bottom:
                  85, // Ajustar para que esté encima del botón (aprox. 20 + 50(botón) + 15(espacio))
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 10.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(10.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 2), // changes position of shadow
                    ),
                  ],
                ),
                child: const Text(
                  "Este será tu recorrido completo.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 15.0),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // AÑADIDO: Widget para decidir qué panel de búsqueda mostrar
  Widget _buildTopSearchPanel() {
    if (_isSearchPanelExpanded) {
      return _buildExpandedSearchPanelUI();
    } else {
      return _buildCompactSearchPanelUI();
    }
  }

  // AÑADIDO: Widget para el panel de búsqueda compacto
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
        onTap: () => setState(() => _isSearchPanelExpanded = true),
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
                  _origenController.text.isNotEmpty
                      ? _origenController.text
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
                  _destinoController.text.isNotEmpty
                      ? _destinoController.text
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
                onPressed: () => setState(() => _isSearchPanelExpanded = true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // AÑADIDO: Widget para el panel de búsqueda expandido
  Widget _buildExpandedSearchPanelUI() {
    return Container(
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
                if (_origenController.text.isNotEmpty &&
                    _destinoController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up, size: 28),
                    tooltip: "Colapsar",
                    onPressed:
                        () => setState(() => _isSearchPanelExpanded = false),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 4.0),
            child: ComposeWithOrigin(
              controller: _origenController,
              focusNode: _origenFocusNode,
              onLocationSelected: (place, center) {
                setState(() {
                  _origenCoordinates = Point(
                    coordinates: Position(center[0], center[1]),
                  );
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 8.0),
            child: ComposeWithOrigin(
              controller: _destinoController,
              focusNode: _destinoFocusNode,
              labelText: 'Destino',
              hintText: 'Escribe una dirección o lugar de destino',
              onLocationSelected: (place, center) {
                setState(() {
                  _destinoCoordinates = Point(
                    coordinates: Position(center[0], center[1]),
                  );
                });
              },
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
                  (_isCalculatingRoute ||
                          _origenCoordinates == null ||
                          _destinoCoordinates == null)
                      ? null
                      : () {
                        _handleSearchRouteWithGraphQl();
                        // No es necesario colapsar aquí explícitamente,
                        // se hará en _handleSearchRouteWithGraphQl al tener éxito.
                      },
              child:
                  _isCalculatingRoute
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
    );
  }

  // AÑADIDO: Función para mostrar el panel de opciones de ruta
  void _showRouteOptionsPanel() {
    if (_availableItineraries.isEmpty) return;

    // AÑADIDO: Limpiar cualquier rastreo de bus anterior al mostrar nuevas opciones
    _stopTrackingBusLine();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (BuildContext bc) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.5, // Ajustar altura según sea necesario
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Elige tu Ruta (${_availableItineraries.length} opciones)',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: _availableItineraries.length,
                    itemBuilder: (context, index) {
                      final itinerary = _availableItineraries[index];
                      final legs = itinerary['legs'] as List? ?? [];
                      final startTime = itinerary['startTime'] as int? ?? 0;
                      final endTime = itinerary['endTime'] as int? ?? 0;
                      final durationMs = endTime - startTime;
                      final durationMinutes =
                          (durationMs / (1000 * 60)).round();

                      // MODIFICADO: Crear una lista de Widgets de iconos para los modos
                      List<Widget> modeIcons = [];
                      // CORREGIDO: Declarar aquí para que estén en el alcance correcto
                      Map<String, dynamic>? firstBusLeg;
                      String? firstBusLegLineName;
                      String? firstBusLegFromStopGtfsId;

                      for (var leg in legs) {
                        String mode =
                            leg['mode']?.toString().toUpperCase() ?? '';
                        IconData iconData =
                            Icons.help_outline; // Icono por defecto
                        Color iconColor = Colors.grey;
                        String? shortName = leg["route"]?["shortName"];

                        if (mode == 'WALK') {
                          iconData = Icons.directions_walk;
                          iconColor = Colors.blueAccent;
                        } else if (mode == 'BUS' || mode == 'TRANSIT') {
                          iconData = Icons.directions_bus;
                          iconColor = Colors.deepOrangeAccent;
                          // CORREGIDO: Asignar aquí dentro del if y solo si firstBusLeg es null
                          if (firstBusLeg == null) {
                            firstBusLeg = leg;
                            firstBusLegLineName = _getStringValue(
                              leg['route']?['shortName'],
                            );
                            // Asumimos que 'from' contiene 'stop' que a su vez tiene 'gtfsId'
                            // Esta estructura depende de la respuesta de OTP
                            firstBusLegFromStopGtfsId = _getStringValue(
                              leg['from']?['stop']?['gtfsId'],
                            );
                          }
                        }

                        List<Widget> legWidgets = [
                          Icon(iconData, color: iconColor, size: 20),
                        ];
                        if (shortName != null && shortName.isNotEmpty) {
                          legWidgets.add(
                            const SizedBox(width: 2),
                          ); // Pequeño espacio
                          legWidgets.add(
                            Text(
                              shortName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }
                        modeIcons.add(
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2.0,
                            ), // Espacio entre iconos/grupos
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: legWidgets,
                            ),
                          ),
                        );
                      }

                      // Añadir flechas entre los iconos de modo, excepto para el último
                      List<Widget> interspersedModeIcons = [];
                      for (int i = 0; i < modeIcons.length; i++) {
                        interspersedModeIcons.add(modeIcons[i]);
                        if (i < modeIcons.length - 1) {
                          interspersedModeIcons.add(
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 3.0),
                              child: Icon(
                                Icons.arrow_forward_ios,
                                size: 10,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        }
                      }

                      Widget titleWidget = Text(
                        "Opción ${index + 1}: ${durationMinutes} min",
                      );
                      Widget subtitleWidget = SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: interspersedModeIcons),
                      );

                      // AÑADIDO: FutureBuilder para cargar y mostrar ETAs
                      if (firstBusLegLineName != null &&
                          firstBusLegFromStopGtfsId != null &&
                          firstBusLegFromStopGtfsId!.isNotEmpty) {
                        // ELIMINADO: Ya no se usa _stopIdMapping
                        // final String numericStopId = _stopIdMapping[firstBusLegFromStopGtfsId!]!;
                        final String numericStopId = firstBusLegFromStopGtfsId!;

                        return FutureBuilder<List<Map<String, dynamic>>>(
                          future: _fetchUpcomingBuses(
                            numericStopId, // Usar directamente el ID de OTP
                            firstBusLegLineName,
                          ),
                          builder: (context, snapshot) {
                            String etaText = "";
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              etaText = " (cargando ETA...)";
                            } else if (snapshot.hasError) {
                              etaText = " (error ETA)";
                              print(
                                "[BondiUY_Debug] Error obteniendo ETA para parada $numericStopId, línea $firstBusLegLineName: ${snapshot.error}",
                              );
                            } else if (snapshot.hasData &&
                                snapshot.data!.isNotEmpty) {
                              // Asumimos que la API devuelve `minutesToArrival`
                              // y que la lista está ordenada o tomamos el primero.
                              final upcomingBus = snapshot.data!.first;
                              final etaMinutes =
                                  upcomingBus['minutesToArrival'];
                              if (etaMinutes != null) {
                                etaText = " (próx. bus: ${etaMinutes} min)";
                              } else {
                                etaText = " (ETA no disp.)";
                              }
                            } else {
                              etaText = " (sin llegadas próx.)";
                            }

                            return ListTile(
                              title: Text(
                                "Opción ${index + 1}: ${durationMinutes} min$etaText",
                              ),
                              subtitle: subtitleWidget,
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.pop(
                                  context,
                                ); // Cerrar el bottom sheet
                                _processAndDisplaySelectedItinerary(itinerary);
                              },
                            );
                          },
                        );
                      } else {
                        // MODIFICADO: Ajustar mensajes de log
                        if (firstBusLegLineName != null &&
                            (firstBusLegFromStopGtfsId == null ||
                                firstBusLegFromStopGtfsId!.isEmpty)) {
                          print(
                            "[BondiUY_Debug] No se pudo obtener ETA para la opción ${index + 1}: firstBusLegFromStopGtfsId (ID de parada de OTP) es nulo o vacío.",
                          );
                        } else if (firstBusLegLineName == null &&
                            firstBusLegFromStopGtfsId != null) {
                          print(
                            "[BondiUY_Debug] No se pudo obtener ETA para la opción ${index + 1}: firstBusLegLineName es nulo.",
                          );
                        }

                        return ListTile(
                          title: titleWidget,
                          subtitle: subtitleWidget,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.pop(context); // Cerrar el bottom sheet
                            _processAndDisplaySelectedItinerary(itinerary);
                          },
                        );
                      }
                    },
                    separatorBuilder:
                        (context, index) =>
                            const Divider(indent: 16, endIndent: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // AÑADIDO: Función para procesar y mostrar el itinerario seleccionado por el usuario
  Future<void> _processAndDisplaySelectedItinerary(
    Map<String, dynamic> selectedItinerary,
  ) async {
    if (mapboxMap == null) {
      print(
        "[BondiUY_Debug] Mapa no listo para procesar itinerario seleccionado.",
      );
      return;
    }
    // AÑADIDO: Detener indicador de carga general si estaba activo
    if (_isCalculatingRoute && mounted) {
      setState(() {
        _isCalculatingRoute = false;
      });
    }

    final List<dynamic> legs = selectedItinerary['legs'] ?? [];
    if (legs.isEmpty) {
      _showNoRouteFoundMessage("El itinerario seleccionado no tiene tramos.");
      return;
    }

    // Actualizar estado y limpiar capas previas (aunque ya se hizo antes de mostrar opciones)
    // Esto es más para asegurar un estado limpio para el nuevo itinerario.
    await _clearPreviousRouteLayers(); // Asegura limpieza del mapa
    _legLayerIds.clear(); // Limpiar mapeos de capas anteriores

    if (mounted) {
      setState(() {
        _currentRouteLegs = legs;
        // _selectedItineraryIndex = ; // Ya no necesitamos rastrear el índice aquí, tenemos el objeto
        _selectedLegIndex = null; // Ningún tramo específico seleccionado aún
        _userManuallyMovedMap = false; // AÑADIDO: Resetear flag
      });
    }

    // Dibujar los tramos del itinerario seleccionado
    for (int i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final String mode = leg['mode'] ?? '';
      final String polylineString = leg['legGeometry']?['points'] ?? '';

      if (polylineString.isNotEmpty) {
        List<PointLatLng> decodedPoints = PolylinePoints().decodePolyline(
          polylineString,
        );
        List<Position> positions =
            decodedPoints
                .map((p) => Position(p.longitude, p.latitude))
                .toList();

        Color legColor = Colors.grey;
        if (mode.toUpperCase() == 'WALK') {
          legColor = Colors.blueAccent;
        } else if (mode.toUpperCase() == 'BUS' ||
            mode.toUpperCase() == 'TRANSIT') {
          legColor = Colors.deepOrangeAccent;
        }

        await _drawRouteSegment(
          positions,
          "$OTP_ROUTE_SOURCE_PREFIX$i",
          "$OTP_ROUTE_LAYER_PREFIX$i",
          legColor,
          i,
          // Los anchos por defecto se usarán aquí
        );
      } else {
        print(
          "[BondiUY_Debug_GraphQL] Tramo $i ('$mode') del itinerario seleccionado sin polyline.",
        );
      }
    }

    await _displayRelevantStops(legs);
    await _zoomToRouteBounds(legs);

    // Configurar para la vista general de la ruta seleccionada
    if (mounted) {
      setState(() {
        _isInOverviewMode = true;
        _isSearchPanelExpanded = false; // Colapsar panel de búsqueda
        _showCollapsedInstructionsBar =
            false; // No mostrar barra de detalle de tramo aún
      });
      _applyOverviewRouteStyle(); // Aplicar estilo uniforme a la nueva ruta

      // AÑADIDO: Ocultar capa de paradas generales
      try {
        if (await mapboxMap!.style.styleLayerExists(STOPS_LAYER_ID)) {
          await mapboxMap!.style.setStyleLayerProperty(
            STOPS_LAYER_ID,
            "visibility",
            "none",
          );
          print(
            "[BondiUY_Debug_GraphQL] Capa de paradas generales ($STOPS_LAYER_ID) ocultada.",
          );
        }
      } catch (e) {
        print(
          "[BondiUY_Debug_GraphQL] Error ocultando capa $STOPS_LAYER_ID: $e",
        );
      }
    }
    // El botón "Iniciar Viaje" se mostrará por el estado _isInOverviewMode
    // El SnackBar "Este será tu recorrido completo" también se mostrará por _isInOverviewMode
  }

  // AÑADIDO: Función para obtener ETAs de la API de Montevideo
  Future<List<Map<String, dynamic>>> _fetchUpcomingBuses(
    String stopId,
    String lineShortName,
  ) async {
    print(
      "[BondiUY_Debug_ETA] Solicitando ETAs para parada $stopId, línea $lineShortName",
    );
    final String? token = await _getApiToken();
    if (token == null) {
      print("[BondiUY_Debug_ETA] No se pudo obtener token para ETAs.");
      throw Exception("Error de autenticación");
    }

    // La API espera 'lines' como un array de strings, aunque solo pasemos uno.
    final String apiUrl =
        "$_BASE_URL/buses/busstops/$stopId/upcomingbuses?lines=$lineShortName&amountperline=3"; // Pedir hasta 3 por si acaso

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        print(
          "[BondiUY_Debug_ETA] Respuesta ETAs para $stopId, línea $lineShortName: $responseData",
        );
        // ASUNCIÓN IMPORTANTE:
        // La documentación NO especifica cómo viene el ETA.
        // Asumiremos que la respuesta es una lista de buses, y cada bus tiene:
        // - "line": "123SD" (String - el nombre corto de la línea)
        // - "destination": "MALVIN" (String - el destino de esa variante)
        // - "minutesToArrival": 15 (int - los minutos para llegar)
        // O podría ser "arrivalTime": "YYYY-MM-DDTHH:mm:ssZ" (String - un timestamp)
        // Vamos a tratar de adaptarnos a 'minutesToArrival' o un campo que parezca similar.

        List<Map<String, dynamic>> upcomingBuses = [];
        for (var busInfo in responseData) {
          if (busInfo is Map<String, dynamic>) {
            // Intentar encontrar un campo de ETA. Priorizar 'minutesToArrival'.
            dynamic etaValue;
            if (busInfo.containsKey('minutesToArrival')) {
              etaValue = busInfo['minutesToArrival'];
            } else if (busInfo.containsKey('arrivalMinutes')) {
              etaValue = busInfo['arrivalMinutes'];
            } else if (busInfo.containsKey('eta')) {
              etaValue = busInfo['eta'];
            }
            // Añadir más heurísticas si es necesario para otros nombres de campo comunes.
            // Si es un timestamp, se necesitaría parsearlo y calcular la diferencia con ahora.

            int? etaMinutes;
            if (etaValue is int) {
              etaMinutes = etaValue;
            } else if (etaValue is String) {
              etaMinutes = int.tryParse(etaValue);
            } else if (etaValue is double) {
              etaMinutes = etaValue.round();
            }

            // Solo añadir si tenemos un ETA válido y la línea coincide
            if (etaMinutes != null &&
                (_getStringValue(busInfo['line']) == lineShortName ||
                    _getStringValue(busInfo['lineId']) == lineShortName)) {
              upcomingBuses.add({
                'line': _getStringValue(busInfo['line']),
                'destination': _getStringValue(busInfo['destination']),
                'minutesToArrival': etaMinutes,
                // podrías añadir más campos si son útiles, como lineVariantId
              });
            }
          }
        }
        // Ordenar por minutesToArrival ascendente
        upcomingBuses.sort(
          (a, b) => (a['minutesToArrival'] as int).compareTo(
            b['minutesToArrival'] as int,
          ),
        );
        return upcomingBuses;
      } else {
        print(
          "[BondiUY_Debug_ETA] Error API obteniendo ETAs (${response.statusCode}): ${response.body}",
        );
        throw Exception("Error API: ${response.statusCode}");
      }
    } catch (e) {
      print("[BondiUY_Debug_ETA] Excepción obteniendo ETAs: $e");
      throw Exception("Excepción: $e");
    }
  }

  // AÑADIDO: Funciones para rastreo de buses en tiempo real
  Future<void> _fetchAndDisplayRealtimeBusLocations() async {
    if (mapboxMap == null ||
        _trackedBusLineShortName == null ||
        _trackedBusLineShortName!.isEmpty) {
      return;
    }
    if (!_styleImagesAdded) {
      // Asegurar que los íconos estén cargados
      print(
        "[BondiUY_Debug_RealtimeBus] Íconos de estilo no cargados aún. Abortando carga de buses en tiempo real.",
      );
      return;
    }

    print(
      "[BondiUY_Debug_RealtimeBus] Solicitando ubicaciones para línea: $_trackedBusLineShortName",
    );
    String? token = await _getApiToken(); // Usar variable local para el token
    if (token == null) {
      print(
        "[BondiUY_Debug_RealtimeBus] No se pudo obtener token inicial para buses en tiempo real.",
      );
      return;
    }

    final String apiUrl =
        "$_BASE_URL/buses?lines=$_trackedBusLineShortName&format=geojson";

    try {
      http.Response response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      // AÑADIDO: Lógica de reintento si hay error de autenticación
      if (response.statusCode == 401 || response.statusCode == 403) {
        print(
          "[BondiUY_Debug_RealtimeBus] Error de autenticación (${response.statusCode}). Forzando renovación de token y reintentando...",
        );
        _apiToken = null; // Invalidar token cacheado
        token = await _getApiToken(); // Obtener nuevo token

        if (token != null) {
          print("[BondiUY_Debug_RealtimeBus] Reintentando con nuevo token...");
          response = await http.get(
            Uri.parse(apiUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          );
        } else {
          print(
            "[BondiUY_Debug_RealtimeBus] No se pudo obtener nuevo token para reintento.",
          );
          // No se puede continuar sin token
          return;
        }
      }
      // FIN DE LÓGICA DE REINTENTO

      if (response.statusCode == 200) {
        final String responseBody = response.body;
        // La API devuelve un GeoJSON FeatureCollection
        final Map<String, dynamic> geoJsonData = json.decode(responseBody);
        final List<dynamic> features = geoJsonData['features'] ?? [];

        if (features.isNotEmpty) {
          print(
            "[BondiUY_Debug_RealtimeBus] ${features.length} buses encontrados para línea $_trackedBusLineShortName.",
          );

          // AÑADIDO: Lógica para identificar el bus más cercano que no ha pasado el origen
          int closestUpcomingBusIndex = -1;
          double minDistanceToOriginStop = double.infinity;
          _highlightedBusPosition =
              null; // AÑADIDO: Resetear al inicio de cada fetch

          if (_currentFullShapeForBusLeg != null &&
              _currentFullShapeForBusLeg!.isNotEmpty &&
              _originStopIndexOnShape != null) {
            for (int i = 0; i < features.length; i++) {
              var feature = features[i];
              if (feature is Map<String, dynamic> &&
                  feature['geometry'] != null &&
                  feature['geometry']['coordinates'] != null) {
                final coords = feature['geometry']['coordinates'];
                if (coords is List && coords.length == 2) {
                  final busPoint = Point_dart(
                    lat: (coords[1] as num).toDouble(),
                    lng: (coords[0] as num).toDouble(),
                  );
                  final busIndexOnShape = _findClosestPointIndexOnShape(
                    _currentFullShapeForBusLeg!,
                    busPoint,
                  );

                  bool isPastUserOrigin = false;
                  bool isRelevantToUserPath = false;

                  if (busIndexOnShape != -1) {
                    if (_originStopIndexOnShape != null) {
                      isPastUserOrigin =
                          busIndexOnShape > _originStopIndexOnShape!;
                    }
                    if (_destinationStopIndexOnShape != null) {
                      isRelevantToUserPath =
                          busIndexOnShape <= _destinationStopIndexOnShape!;
                    }
                  }
                  feature['properties'] = feature['properties'] ?? {};
                  feature['properties']['isPastOrigin'] = isPastUserOrigin;
                  feature['properties']['isRelevant'] = isRelevantToUserPath;
                  feature['properties']['isClosestUpcoming'] =
                      false; // Inicializar

                  // Comprobar si este bus es candidato para ser el más cercano
                  if (isRelevantToUserPath && !isPastUserOrigin) {
                    // Calcular distancia desde la parada de origen del usuario hasta la posición actual del bus EN EL SHAPE
                    // Esto es una aproximación de "cuánto le falta" al bus para llegar a la parada de origen del usuario,
                    // siguiendo el recorrido del shape.
                    // Nos interesa el bus con el busIndexOnShape MÁS PEQUEÑO pero AÚN NO HABIENDO LLEGADO (_originStopIndexOnShape).
                    // Corrección: Queremos el que está más cerca, no el que está más atrás en el shape.
                    // La distancia real es la que ya tenemos, _calculateHaversineDistance

                    // NO, queremos la distancia a lo largo del shape, si es posible.
                    // O, más simple: el que tiene el índice más cercano AL ÍNDICE DE LA PARADA DE ORIGEN, sin haberlo pasado.
                    // O sea, max(busIndexOnShape) tal que busIndexOnShape <= _originStopIndexOnShape.
                    // O más bien, min(distanciaHaversine) tal que busIndexOnShape <= _originStopIndexOnShape

                    if (busIndexOnShape <= _originStopIndexOnShape!) {
                      // Distancia a lo largo del shape (aproximada por diferencia de índices)
                      // O distancia directa Haversine a la parada de origen
                      // Para simplicidad, vamos a usar la distancia de Haversine desde el bus a la parada de origen DEL USUARIO
                      final Point_dart userOriginStopLocation = Point_dart(
                        lat:
                            (_currentFullShapeForBusLeg![_originStopIndexOnShape!]
                                        .lat
                                    as num)
                                .toDouble(),
                        lng:
                            (_currentFullShapeForBusLeg![_originStopIndexOnShape!]
                                        .lng
                                    as num)
                                .toDouble(),
                      );
                      final double distanceToUserOriginStop =
                          _calculateHaversineDistance(
                            busPoint.lat,
                            busPoint.lng,
                            userOriginStopLocation.lat,
                            userOriginStopLocation.lng,
                          );

                      if (distanceToUserOriginStop < minDistanceToOriginStop) {
                        minDistanceToOriginStop = distanceToUserOriginStop;
                        closestUpcomingBusIndex = i;
                      }
                    }
                  }
                }
              }
            }
            // Marcar el bus más cercano
            if (closestUpcomingBusIndex != -1) {
              (features[closestUpcomingBusIndex]['properties']
                      as Map<String, dynamic>)['isClosestUpcoming'] =
                  true;
              // AÑADIDO: Guardar la posición del bus resaltado
              final closestBusFeature = features[closestUpcomingBusIndex];
              if (closestBusFeature['geometry'] != null &&
                  closestBusFeature['geometry']['coordinates'] != null) {
                final coords =
                    closestBusFeature['geometry']['coordinates'] as List;
                if (coords.length == 2) {
                  _highlightedBusPosition = Position(
                    (coords[0] as num).toDouble(),
                    (coords[1] as num).toDouble(),
                  );
                  print(
                    "[BondiUY_Debug_RealtimeBus] Posición del bus resaltado actualizada: ${_highlightedBusPosition?.lng}, ${_highlightedBusPosition?.lat}",
                  );
                }
              }
              print(
                "[BondiUY_Debug_RealtimeBus] Bus más cercano (índice $closestUpcomingBusIndex) marcado como 'isClosestUpcoming'. Distancia: $minDistanceToOriginStop",
              );
            }
          } else {
            for (var feature in features) {
              if (feature is Map<String, dynamic>) {
                feature['properties'] = feature['properties'] ?? {};
                feature['properties']['isPastOrigin'] = false;
                feature['properties']['isRelevant'] = false;
                feature['properties']['isClosestUpcoming'] = false;
              }
            }
            print(
              "[BondiUY_Debug_RealtimeBus] No se pudo determinar 'isPastOrigin', 'isRelevant' o 'isClosestUpcoming' por falta de data del shape/paradas. Buses marcados con defaults.",
            );
          }

          final String modifiedGeoJsonString = json.encode(geoJsonData);

          final sourceExists = await mapboxMap!.style.styleSourceExists(
            REALTIME_BUS_SOURCE_ID,
          );
          if (!sourceExists) {
            await mapboxMap!.style.addSource(
              GeoJsonSource(
                id: REALTIME_BUS_SOURCE_ID,
                data: modifiedGeoJsonString,
              ),
            );
          } else {
            final source =
                await mapboxMap!.style.getSource(REALTIME_BUS_SOURCE_ID)
                    as GeoJsonSource?;
            await source?.updateGeoJSON(modifiedGeoJsonString);
          }

          final layerExists = await mapboxMap!.style.styleLayerExists(
            REALTIME_BUS_LAYER_ID,
          );

          final String iconToUse =
              _realtimeBusIconLoaded ? REALTIME_BUS_ICON_ID : "bus-icon";
          final double normalIconSize = _realtimeBusIconLoaded ? 0.5625 : 0.4;
          final double smallerRelevantIconSize = normalIconSize * 0.65;
          final double closestUpcomingIconSize =
              normalIconSize * 1.3; // 30% más grande

          // Determinar el ícono a usar para el bus resaltado, con fallback
          final String highlightedIcon =
              _highlightedBusIconLoaded
                  ? HIGHLIGHTED_REALTIME_BUS_ICON_ID
                  : iconToUse; // Si el resaltado no cargó, usa el normal

          if (!layerExists) {
            print(
              "[BondiUY_Debug_RealtimeBus] Preparando para añadir capa $REALTIME_BUS_LAYER_ID. Icono base: $iconToUse, Icono resaltado: $highlightedIcon, Tamaño base: $normalIconSize",
            );
            await mapboxMap!.style.addLayer(
              SymbolLayer(
                id: REALTIME_BUS_LAYER_ID,
                sourceId: REALTIME_BUS_SOURCE_ID,
                // MODIFICADO: iconImage a iconImageExpression
                iconImageExpression: <Object>[
                  'case',
                  ['get', 'isClosestUpcoming'],
                  'incoming-bus', // Ícono para el bus más cercano
                  iconToUse, // Ícono normal para otros buses relevantes
                ],
                iconAllowOverlap: true,
                iconIgnorePlacement: true,
                minZoom: 10.0,
                filter: <Object>[
                  '==',
                  ['get', 'isRelevant'],
                  true,
                ],
                // MODIFICADO: Usar xxxExpression y List<Object>
                iconSizeExpression: <Object>[
                  'case',
                  [
                    'get',
                    'isClosestUpcoming',
                  ], // Condition: Is it the closest upcoming bus?
                  closestUpcomingIconSize, // Result if true: Use large size for the highlighted bus
                  smallerRelevantIconSize, // Result if false: Use small size for all other relevant buses
                ],
                iconOpacityExpression: <Object>[
                  'case',
                  ['get', 'isClosestUpcoming'],
                  1.0,
                  ['get', 'isPastOrigin'],
                  0.7,
                  1.0,
                ],
                iconHaloColorExpression: <Object>[
                  'case',
                  ['get', 'isClosestUpcoming'],
                  'rgba(255, 255, 0, 0.8)', // Amarillo para el más cercano
                  'rgba(0, 0, 0, 0)', // Sin halo por defecto
                ],
                iconHaloWidthExpression: <Object>[
                  'case',
                  ['get', 'isClosestUpcoming'],
                  2.5,
                  0.0,
                ],
                iconHaloBlurExpression: <Object>[
                  'case',
                  ['get', 'isClosestUpcoming'],
                  1.5,
                  0.0,
                ],
                iconOffsetExpression: <Object>[
                  'case',
                  [
                    'get',
                    'isClosestUpcoming',
                  ], // Condition: Is it the closest upcoming bus?
                  [
                    0.0,
                    0.0,
                  ], // Offset if true (highlighted bus, move 0 units up)
                  [0.0, 0.0], // No offset otherwise
                ],
              ),
            );
            await _printLayerOrder();
            print(
              "[BondiUY_Debug_RealtimeBus] Capa '$REALTIME_BUS_LAYER_ID' añadida para buses relevantes con estilos dinámicos.",
            );
            // Añadir la capa del tooltip justo encima
            await mapboxMap!.style.addLayer(
              SymbolLayer(
                id: 'incoming-bus-tooltip-layer',
                sourceId: REALTIME_BUS_SOURCE_ID,
                iconImage: 'incoming-bus-tooltip',
                iconAllowOverlap: true,
                iconIgnorePlacement: true,
                minZoom: 10.0,
                filter: <Object>[
                  'all',
                  [
                    '==',
                    ['get', 'isRelevant'],
                    true,
                  ],
                  [
                    '==',
                    ['get', 'isClosestUpcoming'],
                    true,
                  ],
                ],
                iconSize: closestUpcomingIconSize,
                iconOffset: [0.0, 0.0],
              ),
            );
            await _printLayerOrder();
            print(
              "[BondiUY_Debug_RealtimeBus] Capa 'incoming-bus-tooltip-layer' añadida para el tooltip del bus resaltado.",
            );
            // INICIO ANIMACIÓN FLOTANTE SI EL TOOLTIP ESTÁ VISIBLE
            final bool tooltipVisible = features.any(
              (f) =>
                  f is Map &&
                  f['properties'] != null &&
                  f['properties']['isClosestUpcoming'] == true,
            );
            if (tooltipVisible) {
              _startTooltipFloatingAnimation();
            } else {
              _stopTooltipFloatingAnimation();
            }
          } else {
            // Actualizar filtro si ya existe la capa
            await mapboxMap!.style.setStyleLayerProperty(
              REALTIME_BUS_LAYER_ID,
              "filter",
              <Object>[
                '==',
                ['get', 'isRelevant'],
                true,
              ],
            );
            // Actualizar propiedades dinámicas
            await mapboxMap!.style.setStyleLayerProperty(
              REALTIME_BUS_LAYER_ID,
              "iconImageExpression",
              <Object>[
                'case',
                ['get', 'isClosestUpcoming'],
                'incoming-bus',
                iconToUse,
              ],
            );
            await mapboxMap!.style.setStyleLayerProperty(
              REALTIME_BUS_LAYER_ID,
              "iconSizeExpression",
              <Object>[
                'case',
                ['get', 'isClosestUpcoming'],
                closestUpcomingIconSize,
                smallerRelevantIconSize,
              ],
            );
            await mapboxMap!.style.setStyleLayerProperty(
              REALTIME_BUS_LAYER_ID,
              "iconOpacityExpression",
              <Object>[
                'case',
                ['get', 'isClosestUpcoming'],
                1.0,
                ['get', 'isPastOrigin'],
                0.7,
                1.0,
              ],
            );
            await mapboxMap!.style.setStyleLayerProperty(
              REALTIME_BUS_LAYER_ID,
              "iconHaloColorExpression",
              <Object>[
                'case',
                ['get', 'isClosestUpcoming'],
                'rgba(255, 255, 0, 0.8)', // Amarillo para el más cercano
                'rgba(0, 0, 0, 0)', // Sin halo por defecto
              ],
            );
            await mapboxMap!.style.setStyleLayerProperty(
              REALTIME_BUS_LAYER_ID,
              "iconHaloWidthExpression",
              <Object>[
                'case',
                ['get', 'isClosestUpcoming'],
                2.5,
                0.0,
              ],
            );
            await mapboxMap!.style.setStyleLayerProperty(
              REALTIME_BUS_LAYER_ID,
              "iconHaloBlurExpression",
              <Object>[
                'case',
                ['get', 'isClosestUpcoming'],
                1.5,
                0.0,
              ],
            );
            await mapboxMap!.style.setStyleLayerProperty(
              REALTIME_BUS_LAYER_ID,
              "iconOffsetExpression",
              <Object>[
                'case',
                [
                  'get',
                  'isClosestUpcoming',
                ], // Condition: Is it the closest upcoming bus?
                [
                  0.0,
                  -10.0,
                ], // Offset if true (highlighted bus, move 10 units up)
                [0.0, 0.0], // No offset otherwise
              ],
            );
            await _printLayerOrder();
            print(
              "[BondiUY_Debug_RealtimeBus] Propiedades dinámicas de capa '$REALTIME_BUS_LAYER_ID' actualizadas.",
            );
            // Actualizar o añadir la capa del tooltip
            final tooltipLayerExists = await mapboxMap!.style.styleLayerExists(
              'incoming-bus-tooltip-layer',
            );
            if (!tooltipLayerExists) {
              await mapboxMap!.style.addLayer(
                SymbolLayer(
                  id: 'incoming-bus-tooltip-layer',
                  sourceId: REALTIME_BUS_SOURCE_ID,
                  iconImage: 'incoming-bus-tooltip',
                  iconAllowOverlap: true,
                  iconIgnorePlacement: true,
                  minZoom: 10.0,
                  filter: <Object>[
                    'all',
                    [
                      '==',
                      ['get', 'isRelevant'],
                      true,
                    ],
                    [
                      '==',
                      ['get', 'isClosestUpcoming'],
                      true,
                    ],
                  ],
                  iconSize: closestUpcomingIconSize,
                  iconOffset: [0.0, 0.0],
                ),
              );
              print(
                "[BondiUY_Debug_RealtimeBus] Capa 'incoming-bus-tooltip-layer' añadida para el tooltip del bus resaltado.",
              );
              // INICIO ANIMACIÓN FLOTANTE SI EL TOOLTIP ESTÁ VISIBLE
              final bool tooltipVisible = features.any(
                (f) =>
                    f is Map &&
                    f['properties'] != null &&
                    f['properties']['isClosestUpcoming'] == true,
              );
              if (tooltipVisible) {
                _startTooltipFloatingAnimation();
              } else {
                _stopTooltipFloatingAnimation();
              }
            }
          }

          // Capa de puntos rojos para buses irrelevantes (sin cambios aquí, ya tiene su propio filtro)
          final dotsLayerExists = await mapboxMap!.style.styleLayerExists(
            REALTIME_BUS_DOTS_LAYER_ID,
          );
          if (!dotsLayerExists) {
            await mapboxMap!.style.addLayer(
              CircleLayer(
                id: REALTIME_BUS_DOTS_LAYER_ID,
                sourceId: REALTIME_BUS_SOURCE_ID,
                circleColor: Colors.red.value,
                circleRadius: 4.0,
                circleOpacity: 0.8,
                filter: <Object>[
                  '==',
                  ['get', 'isRelevant'],
                  false,
                ], // Mostrar solo si NO es relevante
              ),
            );
            print(
              "[BondiUY_Debug_RealtimeBus] Capa '$REALTIME_BUS_DOTS_LAYER_ID' añadida para buses irrelevantes.",
            );
          } else {
            // Si la capa ya existe, solo actualizar su filtro
            await mapboxMap!.style.setStyleLayerProperty(
              REALTIME_BUS_DOTS_LAYER_ID,
              "filter",
              <Object>[
                '==',
                ['get', 'isRelevant'],
                false,
              ],
            );
            print(
              "[BondiUY_Debug_RealtimeBus] Filtro de capa '$REALTIME_BUS_DOTS_LAYER_ID' actualizado.",
            );
            // INICIO/DETENCIÓN ANIMACIÓN FLOTANTE SI EL TOOLTIP ESTÁ VISIBLE
            final bool tooltipVisible = features.any(
              (f) =>
                  f is Map &&
                  f['properties'] != null &&
                  f['properties']['isClosestUpcoming'] == true,
            );
            if (tooltipVisible) {
              _startTooltipFloatingAnimation();
            } else {
              _stopTooltipFloatingAnimation();
            }
          }

          // AÑADIDO: Re-enfocar el mapa si un bus resaltado fue actualizado y aplica
          if (_highlightedBusPosition !=
                  null && // Un bus resaltado fue encontrado/actualizado
              !_userManuallyMovedMap && // El usuario no ha movido el mapa
              _selectedLegIndex != null && // Hay un tramo seleccionado
              _selectedLegIndex! < _currentRouteLegs.length) {
            // Y el índice es válido
            final currentLeg = _currentRouteLegs[_selectedLegIndex!];
            final String mode = currentLeg['mode']?.toUpperCase() ?? '';

            if (mode == 'BUS' || mode == 'TRANSIT') {
              // Y el tramo actual es de bus
              // Solo trigger re-zoom si no estamos esperando el zoom inicial del tramo Y el mapa no está en otro movimiento programático.
              if (!_isWaitingForInitialLegZoomToComplete &&
                  !_isProgrammaticCameraMove) {
                print(
                  "[BondiUY_Debug_RealtimeBus] Autobús resaltado actualizado. Re-enfocando el tramo $_selectedLegIndex para incluir el autobús.",
                );
                await _zoomToLeg(
                  _selectedLegIndex!,
                ); // Volver a hacer zoom al tramo, ahora con la posición del bus
              } else {
                print(
                  "[BondiUY_Debug_RealtimeBus] Autobús resaltado actualizado. Re-zoom diferido (waitingForInitial: $_isWaitingForInitialLegZoomToComplete, isProgrammaticMove: $_isProgrammaticCameraMove).",
                );
              }
            }
          }
        } else {
          print(
            "[BondiUY_Debug_RealtimeBus] No se encontraron buses en tiempo real para línea $_trackedBusLineShortName. Limpiando capa si existe.",
          );
          // Si no hay buses, remover la capa para que no muestre buses antiguos
          if (await mapboxMap!.style.styleLayerExists(REALTIME_BUS_LAYER_ID)) {
            await mapboxMap!.style.removeStyleLayer(REALTIME_BUS_LAYER_ID);
          }
          if (await mapboxMap!.style.styleLayerExists(
            REALTIME_BUS_DOTS_LAYER_ID,
          )) {
            await mapboxMap!.style.removeStyleLayer(REALTIME_BUS_DOTS_LAYER_ID);
          }
          // Opcionalmente, también remover la fuente si no se va a reusar pronto
          // if (await mapboxMap.style.styleSourceExists(REALTIME_BUS_SOURCE_ID)) {
          //   await mapboxMap.style.removeStyleSource(REALTIME_BUS_SOURCE_ID);
          // }
        }
      } else {
        print(
          "[BondiUY_Debug_RealtimeBus] Error API obteniendo buses (${response.statusCode}): ${response.body}",
        );
      }
    } catch (e, s) {
      print("[BondiUY_Debug_RealtimeBus] Excepción obteniendo buses: $e");
      print(s);
    }

    // === INICIO: NUEVA FUNCIÓN PARA DIBUJAR EL TRAMO ENTRE EL BUS Y LA PARADA DE ORIGEN ===
    await _drawIncomingBusSegment();
    // === FIN NUEVA FUNCIÓN ===
  }

  void _startTrackingBusLine(Map<String, dynamic> busLeg) async {
    // Convertido a async
    await _stopTrackingBusLine(); // Detener cualquier rastreo anterior

    final String? lineShortName = busLeg['route']?['shortName'] as String?;
    // MODIFICADO: Obtener shapeId desde trip en lugar de route
    final String? otpShapeId = busLeg['trip']?['shapeId'] as String?;
    String? shapeIdToSearch = otpShapeId;

    if (otpShapeId != null && otpShapeId.contains(':')) {
      final parts = otpShapeId.split(':');
      if (parts.length > 1) {
        shapeIdToSearch =
            parts.last; // Tomar solo la parte después del primer ':'
        print(
          "[BondiUY_Debug_RealtimeBus] Normalizando shapeId de OTP: '$otpShapeId' -> '$shapeIdToSearch'",
        );
      } else {
        // Esto no debería pasar si contiene ':' pero por si acaso.
        print(
          "[BondiUY_Debug_RealtimeBus] shapeId de OTP contiene ':' pero no se pudo splitear como se esperaba: $otpShapeId",
        );
      }
    }

    if (lineShortName == null || lineShortName.isEmpty) {
      print(
        "[BondiUY_Debug_RealtimeBus] No se puede rastrear: nombre corto de línea no disponible en el tramo.",
      );
      return;
    }

    _trackedBusLineShortName = lineShortName;
    print(
      "[BondiUY_Debug_RealtimeBus] Iniciando rastreo para línea: $_trackedBusLineShortName (Shape ID de OTP: $otpShapeId, Buscando por: $shapeIdToSearch)",
    );

    // AÑADIDO: Obtener y guardar el shape completo y el índice de la parada de origen
    if (shapeIdToSearch != null &&
        _shapeGeometries.containsKey(shapeIdToSearch)) {
      _currentFullShapeForBusLeg = _shapeGeometries[shapeIdToSearch];
      final busLegFrom = busLeg['from'];
      final busLegTo = busLeg['to']; // AÑADIDO: para la parada de destino

      if (_currentFullShapeForBusLeg != null &&
          _currentFullShapeForBusLeg!.isNotEmpty &&
          busLegFrom != null &&
          busLegFrom['lat'] != null &&
          busLegFrom['lon'] != null) {
        final userBoardingStopCoords = Point_dart(
          lat: (busLegFrom['lat'] as num).toDouble(),
          lng: (busLegFrom['lon'] as num).toDouble(),
        );
        _originStopIndexOnShape = _findClosestPointIndexOnShape(
          _currentFullShapeForBusLeg!,
          userBoardingStopCoords,
        );
        print(
          "[BondiUY_Debug_RealtimeBus] Parada de origen '${busLegFrom['name']}' en índice: $_originStopIndexOnShape.",
        );

        // AÑADIDO: Calcular índice para la parada de destino del usuario
        if (busLegTo != null &&
            busLegTo['lat'] != null &&
            busLegTo['lon'] != null) {
          final userAlightingStopCoords = Point_dart(
            lat: (busLegTo['lat'] as num).toDouble(),
            lng: (busLegTo['lon'] as num).toDouble(),
          );
          _destinationStopIndexOnShape = _findClosestPointIndexOnShape(
            _currentFullShapeForBusLeg!,
            userAlightingStopCoords,
          );
          print(
            "[BondiUY_Debug_RealtimeBus] Parada de destino '${busLegTo['name']}' en índice: $_destinationStopIndexOnShape.",
          );
        } else {
          _destinationStopIndexOnShape = null;
          print(
            "[BondiUY_Debug_RealtimeBus] No se pudieron obtener coordenadas de parada de destino del tramo. 'isRelevant' podría no ser preciso.",
          );
        }
        // FIN AÑADIDO
      } else {
        _currentFullShapeForBusLeg = null;
        _originStopIndexOnShape = null;
        _destinationStopIndexOnShape = null; // AÑADIDO
        print(
          "[BondiUY_Debug_RealtimeBus] No se pudieron obtener coordenadas de parada de origen o el shape está vacío. 'isPastOrigin'/'isRelevant' no se podrá determinar con precisión.",
        );
      }
    } else {
      _currentFullShapeForBusLeg = null;
      _originStopIndexOnShape = null;
      _destinationStopIndexOnShape = null; // AÑADIDO
      print(
        "[BondiUY_Debug_RealtimeBus] No se encontró shapeId '$shapeIdToSearch' en _shapeGeometries. 'isPastOrigin'/'isRelevant' no se podrá determinar.",
      );
    }
    // FIN AÑADIDO

    // AÑADIDO: Dibujar el shape completo de la línea si está disponible
    if (shapeIdToSearch != null &&
        _shapeGeometries.containsKey(shapeIdToSearch)) {
      final List<Position>? fullShapePositions =
          _shapeGeometries[shapeIdToSearch]; // Cambiado a fullShapePositions para claridad
      if (fullShapePositions != null && fullShapePositions.isNotEmpty) {
        _currentFullLineShapeId = shapeIdToSearch; // Guardar para limpieza
        final fullLineSourceId =
            "$FULL_BUS_LINE_SHAPE_SOURCE_ID_PREFIX$shapeIdToSearch";
        final fullLineLayerId =
            "$FULL_BUS_LINE_SHAPE_LAYER_ID_PREFIX$shapeIdToSearch";

        // LÓGICA PARA DETERMINAR targetBelowLayerId (ASEGURAR QUE ESTÉ DEFINIDO)
        String? determinedTargetBelowLayerId;
        final int currentLegIndex = _currentRouteLegs.indexOf(busLeg);
        if (currentLegIndex != -1 &&
            _legLayerIds.containsKey(currentLegIndex)) {
          final List<String>? legLayers = _legLayerIds[currentLegIndex];
          if (legLayers != null && legLayers.length == 2) {
            determinedTargetBelowLayerId =
                legLayers[1]; // ID de la capa de sombra del tramo actual
          }
        }
        // FIN DE LÓGICA PARA determinedTargetBelowLayerId

        // ---- INICIO DE NUEVOS LOGS ----
        print(
          "[BondiUY_Debug_RealtimeBus] Detalle de busLeg al intentar dibujar línea base:",
        );
        print("[BondiUY_Debug_RealtimeBus] busLeg: $busLeg");
        if (busLeg != null && busLeg['from'] != null) {
          final legFrom = busLeg['from'];
          print("[BondiUY_Debug_RealtimeBus] busLeg['from']: $legFrom");
          if (legFrom is Map) {
            print(
              "[BondiUY_Debug_RealtimeBus] busLeg['from']['lat']: ${legFrom['lat']}",
            );
            print(
              "[BondiUY_Debug_RealtimeBus] busLeg['from']['lon']: ${legFrom['lon']}",
            );
          } else {
            print("[BondiUY_Debug_RealtimeBus] busLeg['from'] no es un Map.");
          }
        } else {
          print("[BondiUY_Debug_RealtimeBus] busLeg o busLeg['from'] es null.");
        }
        // ---- FIN DE NUEVOS LOGS ----

        // OBTENER COORDENADAS DE LA PARADA DE SUBIDA DEL TRAMO DE BUS ACTUAL
        List<Position> positionsToDraw =
            fullShapePositions; // Por defecto, el shape completo.
        final busLegFrom = busLeg['from'];

        if (busLegFrom != null &&
            busLegFrom['lat'] != null &&
            busLegFrom['lon'] != null) {
          final userBoardingStopCoords = Point_dart(
            lat: (busLegFrom['lat'] as num).toDouble(),
            lng: (busLegFrom['lon'] as num).toDouble(),
          );
          print(
            "[BondiUY_Debug_RealtimeBus] Recortando shape hasta la parada: ${busLegFrom['name']} (${userBoardingStopCoords.lat}, ${userBoardingStopCoords.lng})",
          );
          positionsToDraw = _trimShapeToBoardingStop(
            fullShapePositions,
            userBoardingStopCoords,
          );
        } else {
          print(
            "[BondiUY_Debug_RealtimeBus] No se pudo recortar el shape: coordenadas de parada de subida no disponibles. Se usará el shape completo.",
          );
        }
        // FIN DE LÓGICA DE RECORTE

        try {
          await _drawFullBusLineShape(
            positionsToDraw, // Usar la lista de posiciones potentially recortada
            fullLineSourceId,
            fullLineLayerId,
            Colors.grey.withOpacity(0.7), // Color menos resaltado
            4.5, // AUMENTADO EL GROSOR DE 2.0 a 4.5 (o el valor que prefieras)
            targetBelowLayerId: determinedTargetBelowLayerId, // Pasar el ID
          );
          print(
            // MODIFICADO: Log para indicar qué versión de la línea se dibujó y su longitud
            "[BondiUY_Debug_RealtimeBus] Recorrido de línea base (shapeId: $shapeIdToSearch) dibujado. "
            "Usando ${positionsToDraw == fullShapePositions ? 'shape COMPLETO (fallback o no se pudo recortar)' : 'shape RECORTADO'}. "
            "Longitud dibujada: ${positionsToDraw.length}. "
            "Longitud completa original: ${fullShapePositions.length}.",
          );
        } catch (e) {
          print(
            "[BondiUY_Debug_RealtimeBus] Error dibujando recorrido completo de línea base: $e",
          );
        }
      } else {
        print(
          "[BondiUY_Debug_RealtimeBus] No se encontraron posiciones para shapeId normalizado: $shapeIdToSearch (original de OTP: $otpShapeId)",
        );
      }
    } else {
      if (shapeIdToSearch == null) {
        print(
          "[BondiUY_Debug_RealtimeBus] No se proporcionó shapeId para el tramo (busLeg['trip']?['shapeId'] fue nulo).",
        );
      } else {
        print(
          "[BondiUY_Debug_RealtimeBus] shapeId normalizado: $shapeIdToSearch (original de OTP: $otpShapeId) no encontrado en _shapeGeometries cargadas.",
        );
      }
    }

    _fetchAndDisplayRealtimeBusLocations(); // Carga inicial
    _realtimeBusTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchAndDisplayRealtimeBusLocations();
    });
  }

  // AÑADIDO: Función para recortar la geometría del shape hasta la parada de abordaje
  List<Position> _trimShapeToBoardingStop(
    List<Position> fullShapePositions,
    Point_dart userBoardingStopCoordinates,
  ) {
    print(
      "[BondiUY_Debug_Trim] Iniciando _trimShapeToBoardingStop. Parada: (${userBoardingStopCoordinates.lat}, ${userBoardingStopCoordinates.lng}). Longitud Shape Completo: ${fullShapePositions.length}",
    );
    if (fullShapePositions.isEmpty) {
      print(
        "[BondiUY_Debug_Trim] Shape completo vacío, devolviendo lista vacía.",
      );
      return [];
    }

    int closestPointIndex = -1;
    double minDistance = double.infinity;

    // Encuentra el punto en el shape más cercano a la parada de abordaje
    for (int i = 0; i < fullShapePositions.length; i++) {
      final shapePoint = fullShapePositions[i];
      final distance = _calculateHaversineDistance(
        userBoardingStopCoordinates.lat,
        userBoardingStopCoordinates.lng,
        (shapePoint.lat as num).toDouble(), // CORREGIDO Y VERIFICADO
        (shapePoint.lng as num).toDouble(), // CORREGIDO Y VERIFICADO
      );
      // Loguear algunas distancias para ver qué está pasando
      if (i % (fullShapePositions.length ~/ 10).clamp(1, 50) == 0) {
        // Loguear aprox 10 veces o cada 50 puntos
        print(
          "[BondiUY_Debug_Trim] Index $i: ShapePt(${shapePoint.lat}, ${shapePoint.lng}) -> Dist: $distance",
        );
      }
      if (distance < minDistance) {
        minDistance = distance;
        closestPointIndex = i;
      }
    }
    print(
      "[BondiUY_Debug_Trim] Punto más cercano en shape: Índice $closestPointIndex, Distancia Mín: $minDistance",
    );

    if (closestPointIndex != -1) {
      List<Position> trimmed = fullShapePositions.sublist(
        0,
        closestPointIndex + 1,
      );
      print(
        "[BondiUY_Debug_Trim] Shape recortado. Nueva longitud: ${trimmed.length}",
      );
      return trimmed;
    } else {
      print(
        "[BondiUY_Debug_Trim] No se encontró punto más cercano (closestPointIndex == -1). Devolviendo shape completo.",
      );
      return fullShapePositions;
    }
  }

  Future<void> _stopTrackingBusLine() async {
    _realtimeBusTimer?.cancel();
    _realtimeBusTimer = null;
    _trackedBusLineShortName = null;
    _stopTooltipFloatingAnimation(); // Limpia la animación si queda activa
    print("[BondiUY_Debug_RealtimeBus] Rastreo de buses detenido.");

    // AÑADIDO: Limpiar variables de shape y parada de origen
    _currentFullShapeForBusLeg = null;
    _originStopIndexOnShape = null;
    _destinationStopIndexOnShape = null; // AÑADIDO
    _highlightedBusPosition =
        null; // AÑADIDO: Limpiar posición del bus resaltado
    // FIN AÑADIDO

    if (mapboxMap != null) {
      // Limpiar capa de buses en tiempo real
      try {
        if (await mapboxMap!.style.styleLayerExists(REALTIME_BUS_LAYER_ID)) {
          await mapboxMap!.style.removeStyleLayer(REALTIME_BUS_LAYER_ID);
          print(
            "[BondiUY_Debug_RealtimeBus] Capa '$REALTIME_BUS_LAYER_ID' de buses en tiempo real eliminada.",
          );
        }
        // AÑADIDO: Limpiar capa de puntos rojos
        if (await mapboxMap!.style.styleLayerExists(
          REALTIME_BUS_DOTS_LAYER_ID,
        )) {
          await mapboxMap!.style.removeStyleLayer(REALTIME_BUS_DOTS_LAYER_ID);
          print(
            "[BondiUY_Debug_RealtimeBus] Capa '$REALTIME_BUS_DOTS_LAYER_ID' de puntos rojos eliminada.",
          );
        }

        // Opcional: remover fuente de buses en tiempo real si no se va a reusar inmediatamente
        // if (await mapboxMap.style.styleSourceExists(REALTIME_BUS_SOURCE_ID)) {
        //   await mapboxMap.style.removeStyleSource(REALTIME_BUS_SOURCE_ID);
        // }
      } catch (e) {
        print(
          "[BondiUY_Debug_RealtimeBus] Error limpiando capa/fuente de buses en tiempo real: $e",
        );
      }

      // AÑADIDO: Limpiar capa de recorrido completo de la línea base
      if (_currentFullLineShapeId != null) {
        final fullLineSourceId =
            "$FULL_BUS_LINE_SHAPE_SOURCE_ID_PREFIX$_currentFullLineShapeId";
        final fullLineLayerId =
            "$FULL_BUS_LINE_SHAPE_LAYER_ID_PREFIX$_currentFullLineShapeId";
        try {
          if (await mapboxMap!.style.styleLayerExists(fullLineLayerId)) {
            await mapboxMap!.style.removeStyleLayer(fullLineLayerId);
            print(
              "[BondiUY_Debug_RealtimeBus] Capa de recorrido base '$fullLineLayerId' eliminada.",
            );
          }
          if (await mapboxMap!.style.styleSourceExists(fullLineSourceId)) {
            await mapboxMap!.style.removeStyleSource(fullLineSourceId);
            print(
              "[BondiUY_Debug_RealtimeBus] Fuente de recorrido base '$fullLineSourceId' eliminada.",
            );
          }
        } catch (e) {
          print(
            "[BondiUY_Debug_RealtimeBus] Error limpiando capa/fuente de recorrido base de línea: $e",
          );
        }
        _currentFullLineShapeId = null; // Resetear
      }
    }
  }

  // AÑADIDO: Función para dibujar el shape completo de una línea de bus con estilo base
  Future<void> _drawFullBusLineShape(
    List<Position> positions,
    String sourceId,
    String layerId,
    Color lineColor,
    double lineWidth, {
    String? targetBelowLayerId, // CORREGIDO: Parámetro nombrado opcional
  }) async {
    if (mapboxMap == null || positions.length < 2) return;

    final Map<String, dynamic> geometry = {
      'type': 'LineString',
      'coordinates': positions.map((p) => [p.lng, p.lat]).toList(),
    };

    final Map<String, dynamic> geoJsonFeature = {
      "type": "FeatureCollection",
      "features": [
        {"type": "Feature", "geometry": geometry, "properties": {}},
      ],
    };
    final String geoJsonDataString = json.encode(geoJsonFeature);

    try {
      final sourceExists = await mapboxMap!.style.styleSourceExists(sourceId);
      if (!sourceExists) {
        await mapboxMap!.style.addSource(
          GeoJsonSource(id: sourceId, data: geoJsonDataString),
        );
      } else {
        final source =
            await mapboxMap!.style.getSource(sourceId) as GeoJsonSource?;
        await source?.updateGeoJSON(geoJsonDataString);
      }

      final layerExists = await mapboxMap!.style.styleLayerExists(layerId);
      if (!layerExists) {
        await mapboxMap!.style.addLayer(
          LineLayer(
            id: layerId,
            sourceId: sourceId,
            lineColor: lineColor.value,
            lineWidth: lineWidth,
            lineOpacity: 0.65, // Opacidad moderada para el recorrido base
            lineJoin: LineJoin.ROUND,
            lineCap: LineCap.ROUND,
          ),
        );
        // --- NUEVO: Mover la capa gris debajo de la verde si existe, o debajo de los segmentos de ruta ---
        try {
          if (await mapboxMap!.style.styleLayerExists(
            'incoming-bus-segment-layer',
          )) {
            await mapboxMap!.style.moveStyleLayer(
              layerId,
              LayerPosition(below: 'incoming-bus-segment-layer'),
            );
          } else if (await mapboxMap!.style.styleLayerExists(
            'otp-route-layer-0',
          )) {
            await mapboxMap!.style.moveStyleLayer(
              layerId,
              LayerPosition(below: 'otp-route-layer-0'),
            );
          }
        } catch (e) {
          print(
            '[BondiUY_Debug] Error moviendo capa gris: '
            '[31m$e[0m',
          );
        }
        // --- FIN NUEVO ---
      }
    } catch (e) {
      print(
        "[BondiUY_Debug] Error añadiendo fuente/capa para el recorrido completo de línea $layerId: $e",
      );
    }
  }

  // AÑADIDO: Listener para el movimiento del mapa por el usuario
  void _onMapCameraChange(CameraChangedEventData event) {
    // El evento onCameraChangeListener se dispara para CUALQUIER cambio de cámara.
    // Necesitamos una forma de distinguir si el cambio fue iniciado por el usuario
    // o programáticamente (por ejemplo, por flyTo).

    // Si _isProgrammaticCameraMove es true, significa que estamos en medio
    // de un movimiento de cámara iniciado por la app (ej. flyTo).
    // En este caso, no marcamos como movimiento manual.
    if (_isProgrammaticCameraMove) {
      // print("[BondiUY_Debug_MapMove] Cambio de cámara programático detectado. No se marca como manual.");
      return;
    }

    // Si hay una ruta activa (_currentRouteLegs no está vacía) y
    // no estamos en medio de un movimiento programático,
    // entonces cualquier cambio de cámara se considera manual.
    if (_currentRouteLegs.isNotEmpty && !_userManuallyMovedMap) {
      setState(() {
        _userManuallyMovedMap = true;
      });
      print(
        "[BondiUY_Debug_MapMove] El usuario movió el mapa. _userManuallyMovedMap = true.",
      );
    } else if (_currentRouteLegs.isEmpty && _userManuallyMovedMap) {
      // Si no hay ruta y el mapa se había marcado como movido, resetearlo.
      // Esto podría ser útil si el usuario movió el mapa y luego limpió la ruta.
      // setState(() {
      //   _userManuallyMovedMap = false;
      // });
      // print("[BondiUY_Debug_MapMove] No hay ruta, _userManuallyMovedMap reseteado a false (si estaba true).");
    }
    // Escenario para cuando no hay ruta y no es programático:
    // No hacemos nada con _userManuallyMovedMap, ya que su estado solo
    // importa cuando hay una ruta activa para el auto-zoom.
  }

  // AÑADIDO: Listener para cuando el mapa termina de moverse
  void _onMapIdle(MapIdleEventData data) {
    bool wasProgrammaticMoveWhenIdle = _isProgrammaticCameraMove;

    if (_isProgrammaticCameraMove) {
      // Un movimiento programático acaba de terminar.
      _isProgrammaticCameraMove = false; // Resetear inmediatamente
      // print("[BondiUY_Debug_MapIdle] Programmatic move finished. _isProgrammaticCameraMove = false.");
    }

    // Comprobar si este evento idle corresponde a la finalización de un zoom inicial de tramo
    if (wasProgrammaticMoveWhenIdle && _isWaitingForInitialLegZoomToComplete) {
      _isWaitingForInitialLegZoomToComplete =
          false; // Consumir el estado de espera
      // print("[BondiUY_Debug_MapIdle] Initial leg zoom completed.");

      // Ahora comprobar si necesitamos re-enfocar por el bus, y si el usuario no ha intervenido
      if (_highlightedBusPosition != null &&
          !_userManuallyMovedMap &&
          _selectedLegIndex != null &&
          _selectedLegIndex! < _currentRouteLegs.length) {
        final currentLeg = _currentRouteLegs[_selectedLegIndex!];
        final String mode = currentLeg['mode']?.toUpperCase() ?? '';
        if (mode == 'BUS' || mode == 'TRANSIT') {
          print(
            "[BondiUY_Debug_MapIdle] Bus resaltado disponible. Re-enfocando para incluir bus.",
          );
          _zoomToLeg(
            _selectedLegIndex!,
          ); // Esto establecerá _isProgrammaticCameraMove = true de nuevo
        }
      }
    }
    // Si _isProgrammaticCameraMove era false cuando se llamó a onMapIdle,
    // implica que el mapa se volvió inactivo después de un movimiento manual del usuario, o ya estaba inactivo.
    // En este caso, _userManuallyMovedMap habría sido establecido correctamente por _onMapCameraChange.
  }

  // === INICIO: NUEVA FUNCIÓN PARA DIBUJAR EL TRAMO ENTRE EL BUS Y LA PARADA DE ORIGEN ===
  Future<void> _drawIncomingBusSegment() async {
    // Definir IDs únicos para la fuente y capa
    const String sourceId = "incoming-bus-segment-source";
    const String layerId = "incoming-bus-segment-layer";

    // Limpiar capa/fuente anterior si existen
    if (mapboxMap != null) {
      try {
        if (await mapboxMap!.style.styleLayerExists(layerId)) {
          await mapboxMap!.style.removeStyleLayer(layerId);
        }
        if (await mapboxMap!.style.styleLayerExists("${layerId}-shadow")) {
          await mapboxMap!.style.removeStyleLayer("${layerId}-shadow");
        }
        if (await mapboxMap!.style.styleSourceExists(sourceId)) {
          await mapboxMap!.style.removeStyleSource(sourceId);
        }
      } catch (_) {}
    }

    // Validar que haya bus relevante y shape disponible
    if (_highlightedBusPosition == null ||
        _currentFullShapeForBusLeg == null ||
        _originStopIndexOnShape == null)
      return;

    // Buscar el índice del bus en el shape
    final busIndex = _findClosestPointIndexOnShape(
      _currentFullShapeForBusLeg!,
      Point_dart(
        lat: (_highlightedBusPosition!.lat as num).toDouble(),
        lng: (_highlightedBusPosition!.lng as num).toDouble(),
      ),
    );
    final originIndex = _originStopIndexOnShape!;
    if (busIndex == -1 || originIndex == -1) return;

    // Recortar el shape entre el bus y la parada de origen
    final start = busIndex < originIndex ? busIndex : originIndex;
    final end = busIndex < originIndex ? originIndex : busIndex;
    final segment = _currentFullShapeForBusLeg!.sublist(start, end + 1);
    if (segment.length < 2) return;

    // Dibujar la línea verde
    await _drawRouteSegment(
      segment,
      sourceId,
      layerId,
      Colors.green,
      9999, // Índice especial para que no interfiera con los tramos normales
      lineWidth: 6.0,
      shadowWidth: 8.0,
    );
    // Mover la capa principal y la sombra justo debajo de las paradas principales
    if (mapboxMap != null) {
      await mapboxMap!.style.moveStyleLayer(
        '${layerId}-shadow',
        LayerPosition(below: 'route-main-stops-layer'),
      );
      await mapboxMap!.style.moveStyleLayer(
        layerId,
        LayerPosition(below: 'route-main-stops-layer'),
      );
      await _printLayerOrder();
    }
  }

  // === FIN NUEVA FUNCIÓN ===

  // ================= ORDEN DE CAPAS MAPBOX (Z-INDEX) =================
  // Definición centralizada del orden de apilamiento de capas (de abajo hacia arriba):
  // 1. route-base-layer (shape completo de la línea, gris)
  // 2. route-segment-layer (tramos de la ruta del usuario, azul/naranja)
  // 3. incoming-bus-segment-layer (línea verde del bus en camino)
  // 4. route-main-stops-layer (íconos de paradas principales)
  // 5. route-intermediate-stops-layer (íconos de paradas intermedias)
  // 6. realtime-bus-layer (íconos de buses en tiempo real)
  // 7. incoming-bus-tooltip-layer (tooltip flotante)
  // ====================================================================
  String? getBelowLayerIdFor(String layerType) {
    switch (layerType) {
      case 'route-base':
        return null; // Va al fondo
      case 'route-segment':
        return 'route-base-layer';
      case 'incoming-bus-segment':
        return 'route-segment-layer';
      case 'route-main-stops':
        return 'incoming-bus-segment-layer';
      case 'route-intermediate-stops':
        return 'route-main-stops-layer';
      case 'realtime-bus':
        return 'route-intermediate-stops-layer';
      case 'incoming-bus-tooltip':
        return 'realtime-bus-layer';
      case 'stops-general':
        return 'route-base-layer'; // Paradas generales encima del shape base
      case 'bus-dots':
        return 'realtime-bus-layer'; // Puntos rojos debajo de buses relevantes
      default:
        return null;
    }
  }

  // Después de cada addLayer, mover la capa al lugar correcto si es necesario
  Future<void> _moveLayerIfNeeded(
    String layerId,
    String? belowLayerType,
  ) async {
    if (belowLayerType == null) return;
    final belowLayerId = getBelowLayerIdFor(belowLayerType);
    if (belowLayerId != null && mapboxMap != null) {
      try {
        await mapboxMap!.style.moveStyleLayer(
          layerId,
          LayerPosition(below: belowLayerId),
        );
      } catch (_) {}
    }
  }

  // Añadir función auxiliar para imprimir el orden de las capas
  Future<void> _printLayerOrder() async {
    if (mapboxMap == null) return;
    try {
      final layers = await mapboxMap!.style.getStyleLayers();
      print('[BondiUY_Debug] Orden actual de capas:');
      for (final l in layers) {
        print('  - [36m${l?.id ?? "(null)"}[0m');
      }
    } catch (e) {
      print('[BondiUY_Debug] Error obteniendo el orden de capas: $e');
    }
  }
}

class ComposeWithOrigin extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String labelText;
  final String hintText;
  final Function(String place, List<dynamic> center) onLocationSelected;

  const ComposeWithOrigin({
    Key? key,
    required this.controller,
    required this.focusNode,
    this.labelText = 'Origen',
    this.hintText = 'Escribe una dirección o lugar de origen',
    required this.onLocationSelected,
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
      final String mapboxGeocodingUrl =
          "https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json?access_token=$_MAPBOX_ACCESS_TOKEN&country=UY&language=es&autocomplete=true&limit=5";

      final response = await http.get(Uri.parse(mapboxGeocodingUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> features = data['features'] ?? [];

        _suggestions = List<Map<String, dynamic>>.from(
          features.map(
            (feature) => {
              'place_name':
                  feature['place_name_es'] ??
                  feature['place_name'], // Nombre completo para mostrar en la lista
              'text_street':
                  feature['text_es'] ??
                  feature['text'], // Nombre de la calle/lugar
              'address_number':
                  feature['address'], // Número de puerta (puede ser null)
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
                          // Si textStreet ya termina con el número de puerta (con un espacio antes) o es igual al número,
                          // no lo añadimos de nuevo para evitar duplicados como "NombreCalle 123 123".
                          if (textStreet.endsWith(" $addressNumber") ||
                              textStreet == addressNumber) {
                            valueForTextField = textStreet;
                          } else {
                            valueForTextField = "$textStreet $addressNumber";
                          }
                        } else {
                          // No hay número de puerta, usar solo el nombre de la calle/lugar.
                          valueForTextField = textStreet;
                        }
                      } else {
                        // Fallback al nombre completo si textStreet es nulo o vacío.
                        valueForTextField = displayNameInList;
                      }

                      return ListTile(
                        title: _buildHighlightedText(
                          displayNameInList, // Mostrar el nombre completo en la lista de sugerencias
                          widget.controller.text,
                        ),
                        onTap: () {
                          _debounceTimer?.cancel();
                          widget.controller.text =
                              valueForTextField; // Usar el valor construido
                          widget.onLocationSelected(
                            valueForTextField, // Pasar el valor construido
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

  // Método para resaltar el texto que coincide con la búsqueda
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

class Point_dart {
  final double lat;
  final double lng;
  Point_dart({required this.lat, required this.lng});
}
