import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

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
  static const String ROUTE_STOPS_LAYER_ID = "route-stops-layer";

  // AÑADIDO: Para mantener un registro de las capas y fuentes de ruta añadidas dinámicamente
  final List<String> _dynamicRouteSourceIds = [];
  final List<String> _dynamicRouteLayerIds = [];

  bool _stopsAdded = false; // AÑADIDO: flag para evitar carga duplicada
  String?
  _apiToken; // Renombrado de _accessToken para evitar confusión con el de Mapbox

  // AÑADIDO: Para Overlay y Focus
  final FocusNode _origenFocusNode = FocusNode();
  final FocusNode _destinoFocusNode = FocusNode();
  final LayerLink _origenLayerLink = LayerLink();
  final LayerLink _destinoLayerLink = LayerLink();

  Timer? _debounceTimer;

  // AÑADIDO: IDs genéricos para segmentos de ruta OTP
  static const String OTP_ROUTE_SOURCE_PREFIX = "otp-route-source-";
  static const String OTP_ROUTE_LAYER_PREFIX = "otp-route-layer-";

  _onMapCreated(MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    // No cargamos las paradas aquí para evitar agregar la fuente antes de que el estilo esté listo
  }

  Future<void> _loadStopsData() async {
    if (mapboxMap == null) {
      print(
        "[BondiUY_Debug] MapboxMap no está listo, no se pueden cargar las paradas.",
      );
      return;
    }
    if (_stopsAdded) {
      print("[BondiUY_Debug] Paradas ya cargadas, ignorando.");
      return;
    }
    print("[BondiUY_Debug] Iniciando _loadStopsData...");

    try {
      _stopsAdded = true; // Marcar que ya cargamos las paradas
      final String geoJsonData = await rootBundle.loadString(
        'assets/stops.geojson',
      );
      print(
        "[BondiUY_Debug] stops.geojson cargado, longitud: ${geoJsonData.length}",
      );
      // Descomenta para ver un fragmento si es necesario:
      // if (geoJsonData.length > 500) {
      //   print("[BondiUY_Debug] Primeros 500 caracteres de stops.geojson: ${geoJsonData.substring(0, 500)}");
      // } else {
      //   print("[BondiUY_Debug] stops.geojson: $geoJsonData");
      // }

      await mapboxMap!.style.addSource(
        GeoJsonSource(id: STOPS_SOURCE_ID, data: geoJsonData),
      );
      print(
        "[BondiUY_Debug] GeoJsonSource '$STOPS_SOURCE_ID' añadida al estilo.",
      );

      await mapboxMap!.style.addLayer(
        CircleLayer(
          id: STOPS_LAYER_ID,
          sourceId: STOPS_SOURCE_ID,
          circleColor: Colors.red.value,
          circleRadius: 6.0,
          circleStrokeColor: Colors.white.value,
          circleStrokeWidth: 1.5,
          circleOpacity: 0.8,
          minZoom: 14.0,
        ),
      );
      print(
        "[BondiUY_Debug] CircleLayer '$STOPS_LAYER_ID' añadida con círculos rojos.",
      );

      // Opcional: Imprimir el estilo completo para verificación avanzada
      // final styleJson = await mapboxMap!.style.getStyle();
      // print("[BondiUY_Debug] Estilo actual del mapa (JSON): $styleJson");
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

  // AÑADIDO: Listener que se dispara cuando el estilo ha terminado de cargarse
  void _onStyleLoadedListener(StyleLoadedEventData event) async {
    print("[BondiUY_Debug] Estilo cargado, llamando a _loadStopsData...");
    await _loadStopsData();
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
  }

  @override
  void dispose() {
    _origenController.dispose();
    _destinoController.dispose();
    _debounceTimer?.cancel();
    // AÑADIDO: Dispose FocusNodes y remover Overlays
    _origenFocusNode.dispose();
    _destinoFocusNode.dispose();
    super.dispose();
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

    print(
      "[BondiUY_Debug_GraphQL] Solicitando ruta a servidor OTP con GraphQL...",
    );
    await _clearPreviousRouteLayers(); // Limpiar rutas anteriores

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
      # CORREGIDO: Usar la query 'plan' y ajustar la estructura de los argumentos y variables
      # según el ejemplo de la documentación de OTP GTFS GraphQL API.
      query PlanRuta(
        \$fromLat: Float!, \$fromLon: Float!,
        \$toLat: Float!, \$toLon: Float!,
        \$date: String!, \$time: String! # Mantener String para date y time según el ejemplo
      ) {
        plan(
          from: { lat: \$fromLat, lon: \$fromLon },
          to: { lat: \$toLat, lon: \$toLon },
          date: \$date,
          time: \$time,
          transportModes: [
            { mode: WALK }, 
            { mode: BUS } # Usaremos BUS primero, si falla, probaremos TRANSIT
            # { mode: TRANSIT } # Alternativa si BUS no es un enum válido para 'mode' aquí
          ],
          numItineraries: 1 # Este argumento podría no ser válido para 'plan', lo verificaremos
        ) {
          # ESTRUCTURA DE RESPUESTA PARA 'plan' (puede ser diferente a 'planConnection')
          # Consultar el ejemplo de docs.txt para los campos correctos.
          itineraries {
            startTime # Ejemplo: 1676457420000 (epoch ms)
            endTime   # Ejemplo: 1676460420000 (epoch ms)
            legs {
              mode
              startTime 
              endTime
              duration # AÑADIDO: duración del tramo en segundos (según planConnection)
              distance # AÑADIDO: distancia del tramo en metros (según planConnection)
              from {
                name
                lat
                lon
                # departureTime # El ejemplo en docs.txt las tiene aquí
                # arrivalTime
              }
              to {
                name
                lat
                lon
                # departureTime
                # arrivalTime
              }
              route {
                gtfsId
                longName
                shortName
              }
              legGeometry {
                points
                length # AÑADIDO: longitud de la geometría (según planConnection)
              }
              steps { # Si se necesitan instrucciones de caminata -> DESCOMENTADO Y AÑADIDO
                streetName
                distance # Distancia del paso en metros
                relativeDirection # Ej: "LEFT", "RIGHT", "CONTINUE"
                absoluteDirection # Ej: "NORTH", "SOUTHWEST"
                # Podrían existir otros campos útiles como 'stayOn', 'area', 'exit' etc.
                # Revisar el schema/respuesta real si se necesita más detalle.
              }
            }
          }
          # planErrors { # 'plan' podría no tener planErrors directamente aquí.
          #   message
          #   code
          # }
        }
      }
    """;

    // Configuración de las opciones para la consulta GraphQL,
    // incluyendo el documento (la query string) y las variables.
    final QueryOptions options = QueryOptions(
      document: gql(
        queryString,
      ), // gql() parsea el string a un documento GraphQL.
      variables: <String, dynamic>{
        'fromLat': _origenCoordinates!.coordinates.lat,
        'fromLon': _origenCoordinates!.coordinates.lng,
        'toLat': _destinoCoordinates!.coordinates.lat,
        'toLon': _destinoCoordinates!.coordinates.lng,
        'date': date,
        'time': time,
      },
      fetchPolicy:
          FetchPolicy.networkOnly, // Siempre obtener datos frescos de la red.
    );

    try {
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
          // Tomar el primer itinerario de la lista.
          // La estructura de 'itinerary' dentro de 'plan' puede ser directa, no un 'node'.
          final Map<String, dynamic> itinerary = itineraries.first;
          final List<dynamic> legs = itinerary['legs'] ?? [];

          print(
            "[BondiUY_Debug_GraphQL] Itinerario GraphQL ('plan') recibido con ${legs.length} tramos.",
          );

          // Iterar sobre cada tramo del itinerario para dibujarlo en el mapa.
          for (int i = 0; i < legs.length; i++) {
            final leg = legs[i];
            final String mode = leg['mode'] ?? '';
            final String polylineString = leg['legGeometry']?['points'] ?? '';

            if (polylineString.isNotEmpty) {
              // Decodificar la polyline para obtener una lista de coordenadas.
              List<PointLatLng> decodedPoints = PolylinePoints().decodePolyline(
                polylineString,
              );
              List<Position> positions =
                  decodedPoints
                      .map((p) => Position(p.longitude, p.latitude))
                      .toList();

              // Determinar el color del tramo según el modo de transporte.
              Color legColor = Colors.grey; // Color por defecto.
              if (mode.toUpperCase() == 'WALK') {
                legColor = Colors.blueAccent;
              } else if (mode.toUpperCase() == 'BUS' ||
                  mode.toUpperCase() == 'TRANSIT') {
                legColor = Colors.deepOrangeAccent;
              } // Se pueden añadir más condiciones para otros modos (RAIL, SUBWAY, etc.)

              // Dibujar el segmento de ruta en el mapa.
              await _drawRouteSegment(
                positions,
                "$OTP_ROUTE_SOURCE_PREFIX$i", // ID único para la fuente del segmento.
                "$OTP_ROUTE_LAYER_PREFIX$i", // ID único para la capa del segmento.
                legColor,
              );
            } else {
              print(
                "[BondiUY_Debug_GraphQL] Tramo GraphQL $i ('$mode') sin geometría polyline.",
              );
            }
          }
          // AÑADIDO: Lógica para mostrar las paradas relevantes de la ruta
          await _displayRelevantStops(legs);

          // AÑADIDO: Ajustar el zoom del mapa para mostrar la ruta completa
          await _zoomToRouteBounds(legs);

          // AÑADIDO: Mostrar las instrucciones del viaje en un BottomSheet
          _showTripInstructionsBottomSheet(legs);
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
    }
  }

  // Función adaptada para dibujar un segmento de ruta desde coordenadas
  Future<void> _drawRouteSegment(
    List<Position> positions,
    String sourceId,
    String layerId,
    Color lineColor,
  ) async {
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
      // Añadir fuente GeoJSON
      await mapboxMap!.style.addSource(
        GeoJsonSource(id: sourceId, data: geoJsonData),
      );
      _dynamicRouteSourceIds.add(sourceId);

      // Añadir LineLayer
      await mapboxMap!.style.addLayer(
        LineLayer(
          id: layerId,
          sourceId: sourceId,
          lineColor: lineColor.value,
          lineWidth:
              (lineColor == Colors.green) ? 4.0 : 3.0, // Más gruesa para bus
          lineOpacity: 0.8,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
        ),
      );
      _dynamicRouteLayerIds.add(layerId);
      print("[BondiUY_Debug] Segmento de ruta ($layerId) dibujado.");
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
  }

  // Función para limpiar las capas de ruta previas
  Future<void> _clearPreviousRouteLayers() async {
    if (mapboxMap == null) return;
    print("[BondiUY_Debug] Limpiando capas y fuentes de ruta anteriores...");

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
      await mapboxMap!.style.removeStyleLayer(ROUTE_STOPS_LAYER_ID);
      print(
        "[BondiUY_Debug_GraphQL] Capa de paradas de ruta ($ROUTE_STOPS_LAYER_ID) eliminada.",
      );
    } catch (e) {
      // No es un error crítico si no existen aún
      // print("[BondiUY_Debug_GraphQL] Adv: No se pudo remover la capa de paradas de ruta $ROUTE_STOPS_LAYER_ID: $e");
    }
    try {
      await mapboxMap!.style.removeStyleSource(ROUTE_STOPS_SOURCE_ID);
      print(
        "[BondiUY_Debug_GraphQL] Fuente de paradas de ruta ($ROUTE_STOPS_SOURCE_ID) eliminada.",
      );
    } catch (e) {
      // No es un error crítico si no existen aún
      // print("[BondiUY_Debug_GraphQL] Adv: No se pudo remover la fuente de paradas de ruta $ROUTE_STOPS_SOURCE_ID: $e");
    }
  }

  // AÑADIDO: Función para limpiar y mostrar solo las paradas relevantes de la ruta actual.
  Future<void> _displayRelevantStops(List<dynamic> legs) async {
    if (mapboxMap == null) return;

    // No es necesario limpiar explícitamente aquí si _clearPreviousRouteLayers ya lo hace.
    // Sin embargo, si esta función se llamara independientemente, la limpieza aquí sería útil.
    // Por ahora, se asume que _clearPreviousRouteLayers se llama antes de una nueva planificación.

    List<Map<String, dynamic>> relevantStopFeatures = [];

    for (var leg in legs) {
      final String mode = leg['mode']?.toUpperCase() ?? '';
      // Considerar solo tramos de BUS o TRANSIT para las paradas
      if (mode == 'BUS' || mode == 'TRANSIT') {
        final fromPlace = leg['from'];
        final toPlace = leg['to'];

        if (fromPlace != null &&
            fromPlace['lat'] != null &&
            fromPlace['lon'] != null) {
          relevantStopFeatures.add({
            "type": "Feature",
            "geometry": {
              "type": "Point",
              "coordinates": [fromPlace['lon'], fromPlace['lat']],
            },
            "properties": {
              "name": fromPlace['name'] ?? 'Parada de subida',
              "type":
                  "route_stop", // Propiedad para identificar estas paradas si es necesario
            },
          });
        }
        if (toPlace != null &&
            toPlace['lat'] != null &&
            toPlace['lon'] != null) {
          relevantStopFeatures.add({
            "type": "Feature",
            "geometry": {
              "type": "Point",
              "coordinates": [toPlace['lon'], toPlace['lat']],
            },
            "properties": {
              "name": toPlace['name'] ?? 'Parada de bajada',
              "type": "route_stop",
            },
          });
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
        await mapboxMap!.style.removeStyleLayer(ROUTE_STOPS_LAYER_ID);
      } catch (_) {}
      try {
        await mapboxMap!.style.removeStyleSource(ROUTE_STOPS_SOURCE_ID);
      } catch (_) {}
      return;
    }

    // Crear la FeatureCollection para las paradas relevantes
    final Map<String, dynamic> geoJsonFeatureCollection = {
      "type": "FeatureCollection",
      "features": relevantStopFeatures,
    };
    final String geoJsonData = json.encode(geoJsonFeatureCollection);

    try {
      // Intentar remover fuente y capa existentes antes de añadir nuevas,
      // para evitar errores si ya existen de una llamada anterior y _clearPreviousRouteLayers falló o no se llamó.
      try {
        await mapboxMap!.style.removeStyleLayer(ROUTE_STOPS_LAYER_ID);
      } catch (_) {
        /* Ignorar si no existe */
      }
      try {
        await mapboxMap!.style.removeStyleSource(
          ROUTE_STOPS_SOURCE_ID,
        ); // ERROR DE ESCRITURA PREVIO: STOTS -> STOPS
      } catch (_) {
        /* Ignorar si no existe */
      }

      // Añadir la nueva fuente GeoJSON para las paradas de la ruta
      await mapboxMap!.style.addSource(
        GeoJsonSource(id: ROUTE_STOPS_SOURCE_ID, data: geoJsonData),
      );
      print(
        "[BondiUY_Debug_GraphQL] GeoJsonSource '$ROUTE_STOPS_SOURCE_ID' para paradas de ruta añadida.",
      );

      // Añadir la nueva capa para las paradas de la ruta
      // Estas paradas se mostrarán siempre, sin minZoom, y con un estilo distintivo.
      await mapboxMap!.style.addLayer(
        CircleLayer(
          id: ROUTE_STOPS_LAYER_ID,
          sourceId: ROUTE_STOPS_SOURCE_ID,
          circleColor: Colors.purple.value, // Color distintivo (ej. morado)
          circleRadius: 7.0, // Un poco más grandes
          circleStrokeColor: Colors.white.value,
          circleStrokeWidth: 2.0,
          circleOpacity: 0.9,
          // minZoom: 0, // Opcional: explícitamente sin mínimo de zoom (o un valor muy bajo)
        ),
      );
      print(
        "[BondiUY_Debug_GraphQL] CircleLayer '$ROUTE_STOPS_LAYER_ID' para paradas de ruta añadida.",
      );
    } catch (e) {
      print(
        "[BondiUY_Debug_GraphQL] Error añadiendo fuente/capa para paradas de ruta: $e",
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
        await mapboxMap!.flyTo(
          cameraOptions,
          MapAnimationOptions(duration: 1500),
        ); // Duración de 1.5 segundos
        print(
          "[BondiUY_Debug_GraphQL] Cámara ajustada para mostrar la ruta completa.",
        );
      } catch (e) {
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

  // AÑADIDO: Función para construir la lista de Widgets de instrucciones.
  List<Widget> _buildInstructionListTiles(List<dynamic> legs) {
    List<Widget> instructionTiles = [];

    instructionTiles.add(
      ListTile(
        leading: Icon(Icons.flag_outlined),
        title: Text(
          "Origen: ${legs.first['from']?['name'] ?? 'Punto de inicio'}",
        ),
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
      // final duration = leg['duration'] != null ? (leg['duration'] as double / 60).round() : 0; // Duración en minutos

      if (mode == 'WALK') {
        final steps = leg['steps'] as List<dynamic>? ?? [];
        if (steps.isNotEmpty) {
          instructionTiles.add(
            ListTile(
              leading: Icon(Icons.directions_walk, color: Colors.blueAccent),
              title: Text("Caminar ${distance}m hacia ${toName}"),
              subtitle:
                  steps.length > 1 ? Text("(${steps.length} pasos)") : null,
              dense: true,
            ),
          );
          // Opcional: Mostrar cada paso individualmente (puede ser muy detallado)
          /*
          for (var step in steps) {
            final stepDistance = (step['distance'] as double?)?.round() ?? 0;
            final streetName = step['streetName'] ?? 'calle desconocida';
            final relativeDir = step['relativeDirection'] ?? 'CONTINUE'; 
            String instruction = "$relativeDir en $streetName (${stepDistance}m)"; 
            // TODO: Traducir/mejorar el texto de la instrucción basado en relativeDirection
            instructionTiles.add(Padding(
              padding: const EdgeInsets.only(left: 40.0), // Indentación para los pasos
              child: ListTile(
                leading: Icon(Icons.subdirectory_arrow_right, size: 18),
                title: Text(instruction),
                dense: true,
              ),
            ));
          }
          */
        } else {
          // Si no hay steps, mostrar una instrucción general de caminata
          instructionTiles.add(
            ListTile(
              leading: Icon(Icons.directions_walk, color: Colors.blueAccent),
              title: Text("Caminar ${distance}m desde $fromName hasta $toName"),
              dense: true,
            ),
          );
        }
      } else if (mode == 'BUS' || mode == 'TRANSIT') {
        final route = leg['route'];
        final lineName =
            route?['shortName'] ?? route?['longName'] ?? 'Bus desconocido';
        instructionTiles.add(
          ListTile(
            leading: Icon(Icons.directions_bus, color: Colors.deepOrangeAccent),
            title: Text("Tomar bus línea $lineName"),
            subtitle: Text("Desde: $fromName\nHasta: $toName"),
            isThreeLine: true,
          ),
        );
      }
      // Se pueden añadir más modos aquí (BICYCLE, CAR, etc.)
    }

    instructionTiles.add(
      ListTile(
        leading: Icon(Icons.flag, color: Colors.green),
        title: Text("Destino: ${legs.last['to']?['name'] ?? 'Punto final'}"),
        dense: true,
      ),
    );

    return instructionTiles;
  }

  // AÑADIDO: Función para mostrar el BottomSheet con las instrucciones.
  void _showTripInstructionsBottomSheet(List<dynamic> legs) {
    if (legs.isEmpty) return;

    final instructionWidgets = _buildInstructionListTiles(legs);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que el BottomSheet sea más alto
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (BuildContext bc) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor:
                0.6, // Ocupa máximo el 60% de la altura de la pantalla
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Instrucciones de Viaje',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: instructionWidgets.length,
                    itemBuilder: (context, index) => instructionWidgets[index],
                    separatorBuilder:
                        (context, index) =>
                            const Divider(height: 1, indent: 16, endIndent: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BondiUY')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
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
            padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 8.0),
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
          // AÑADIDO: Botón para Buscar Ruta
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: ElevatedButton(
              onPressed: () {
                if (_origenCoordinates != null && _destinoCoordinates != null) {
                  _handleSearchRouteWithGraphQl();
                } else {
                  print("Origen y/o Destino no seleccionados.");
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Por favor, selecciona un origen y un destino.',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Buscar Ruta'),
            ),
          ),
          Expanded(
            child: MapWidget(
              key: const ValueKey("mapWidget"),
              onMapCreated: _onMapCreated,
              onStyleLoadedListener: _onStyleLoadedListener,
              cameraOptions: _initialCameraOptions,
              styleUri: MapboxStyles.MAPBOX_STREETS,
              onTapListener: _onMapWidgetTap,
            ),
          ),
        ],
      ),
    );
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
              'place_name': feature['place_name'],
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
                      return ListTile(
                        title: _buildHighlightedText(
                          _suggestions[index]['place_name'] ?? '',
                          widget.controller.text,
                        ),
                        onTap: () {
                          widget.controller.text =
                              _suggestions[index]['place_name'] ?? '';
                          widget.onLocationSelected(
                            _suggestions[index]['place_name'] ?? '',
                            _suggestions[index]['center'],
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
