import 'dart:convert';
import 'package:flutter/services.dart'
    show rootBundle; // Necesario para rootBundle
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../contrato_ui/app_ui_state.dart'; // Para usar Coordenada, InfoParadaEnMapa, InfoDetalladaParada, EtaMostrable

// TODO: Crear un archivo similar a api_constants.dart en la nueva estructura
// y mover estas constantes allí. Por ahora, las definimos aquí temporalmente.
// const String LEGACY_BASE_URL = "https://api.montevideo.gub.uy";
const String ACCESS_TOKEN_URL =
    "https://mvdapi-auth.montevideo.gub.uy/auth/realms/pci/protocol/openid-connect/token";
const String CLIENT_ID = "93d925e7";
const String CLIENT_SECRET = "2ac468b09443250d178653e7707ea9ad";
const String ARRIVALS_BASE_URL = "https://api.montevideo.gub.uy/transporteRest";

// Interfaz para el servicio adaptador de la API de Montevideo (o similar)
abstract class MontevideoApiServiceAdapterBase {
  /// Obtiene todas las paradas de ómnibus.
  /// En una implementación real, esto podría obtener datos de una API o DB local.
  Future<List<InfoParadaEnMapa>> getAllStops();

  /// Obtiene la información detallada de una parada específica, incluyendo ETAs.
  /// [idParada]: El identificador único de la parada.
  Future<InfoDetalladaParada?> getStopDetailsWithEta(
    String idParada,
    String nombreParadaOriginal,
    Coordenada posicionParadaOriginal,
  );
}

// Implementación del adaptador del servicio
class MontevideoApiServiceAdapter implements MontevideoApiServiceAdapterBase {
  String? _accessToken;
  DateTime? _tokenExpiration;

  MontevideoApiServiceAdapter(); // Constructor simple por ahora

  Future<String?> _getApiToken() async {
    if (_accessToken != null &&
        _tokenExpiration != null &&
        DateTime.now().isBefore(_tokenExpiration!)) {
      return _accessToken;
    }

    try {
      print("[MontevideoApiServiceAdapter] Solicitando nuevo token de API...");
      final response = await http.post(
        Uri.parse(ACCESS_TOKEN_URL),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': CLIENT_ID,
          'client_secret': CLIENT_SECRET,
          'grant_type': 'client_credentials',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        final expiresIn = data['expires_in'] as int?;
        if (expiresIn != null) {
          // Guardar la expiración restando unos minutos por seguridad
          _tokenExpiration = DateTime.now().add(
            Duration(seconds: expiresIn - 120),
          );
          print(
            "[MontevideoApiServiceAdapter] Nuevo token obtenido. Expira en: $_tokenExpiration",
          );
        } else {
          _tokenExpiration = DateTime.now().add(
            const Duration(hours: 1),
          ); // Default si no viene expires_in
          print(
            "[MontevideoApiServiceAdapter] Nuevo token obtenido. Sin info de expiración, asumiendo 1 hora.",
          );
        }
        return _accessToken;
      } else {
        print(
          "[MontevideoApiServiceAdapter_ERROR] Fallo al obtener token API: ${response.statusCode} ${response.body}",
        );
        _accessToken = null;
        _tokenExpiration = null;
        return null;
      }
    } catch (e) {
      print(
        "[MontevideoApiServiceAdapter_ERROR] Excepción al obtener token API: $e",
      );
      _accessToken = null;
      _tokenExpiration = null;
      return null;
    }
  }

  @override
  Future<List<InfoParadaEnMapa>> getAllStops() async {
    print(
      "[MontevideoApiServiceAdapter] Solicitando todas las paradas desde assets/data/stops.geojson...",
    );
    try {
      final String geoJsonString = await rootBundle.loadString(
        'assets/data/stops.geojson',
      );
      final Map<String, dynamic> geoJson = json.decode(geoJsonString);

      if (geoJson['type'] == 'FeatureCollection' &&
          geoJson['features'] is List) {
        final List features = geoJson['features'];
        final List<InfoParadaEnMapa> paradas = [];

        for (var feature in features) {
          if (feature is Map<String, dynamic> &&
              feature['geometry'] is Map<String, dynamic> &&
              feature['geometry']['type'] == 'Point' &&
              feature['geometry']['coordinates'] is List &&
              feature['properties'] is Map<String, dynamic>) {
            final properties = feature['properties'] as Map<String, dynamic>;
            final coordinates = feature['geometry']['coordinates'] as List;

            // GeoJSON es [longitud, latitud]
            final String? idParada =
                properties['stop_id']?.toString() ??
                properties['id']
                    ?.toString(); // Intentar con 'id' si 'stop_id' no existe
            final String nombreParada =
                properties['stop_name']?.toString() ??
                properties['name']?.toString() ??
                'Parada sin nombre';

            if (idParada != null &&
                coordinates.length == 2 &&
                coordinates[0] is num &&
                coordinates[1] is num) {
              paradas.add(
                InfoParadaEnMapa(
                  idParada: idParada,
                  posicion: Coordenada(
                    longitud: (coordinates[0] as num).toDouble(),
                    latitud: (coordinates[1] as num).toDouble(),
                  ),
                  nombre: nombreParada,
                ),
              );
            } else {
              print(
                "[MontevideoApiServiceAdapter_WARN] Feature de parada con datos incompletos o mal formados: $feature",
              );
            }
          } else {
            print(
              "[MontevideoApiServiceAdapter_WARN] Feature GeoJSON no válida encontrada: $feature",
            );
          }
        }
        print(
          "[MontevideoApiServiceAdapter] ${paradas.length} paradas cargadas desde GeoJSON.",
        );
        return paradas;
      } else {
        print(
          "[MontevideoApiServiceAdapter_ERROR] Formato GeoJSON inválido en assets/data/stops.geojson. No es FeatureCollection o no tiene features.",
        );
        return [];
      }
    } catch (e, s) {
      print(
        "[MontevideoApiServiceAdapter_ERROR] Error cargando o parseando stops.geojson: $e\n$s",
      );
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchArrivalsForStopAPI(
    String stopId,
  ) async {
    final token = await _getApiToken();
    if (token == null) {
      print(
        "[MontevideoApiServiceAdapter_ERROR] No se pudo obtener token para _fetchArrivalsForStopAPI.",
      );
      return [];
    }

    final url = Uri.parse('$ARRIVALS_BASE_URL/siguientesParada/$stopId');
    print(
      "[MontevideoApiServiceAdapter_DEBUG] Consultando llegadas para parada $stopId desde $url",
    );

    try {
      http.Response response;
      try {
        response = await http
            .get(url, headers: {'Authorization': 'Bearer $token'})
            .timeout(const Duration(seconds: 10)); // Timeout de 10 segundos
      } catch (e) {
        // Captura específica para TimeoutException o SocketException
        print(
          "[MontevideoApiServiceAdapter_ERROR] Timeout o error de red consultando $url: $e",
        );
        return []; // Devolver lista vacía en caso de error de red o timeout
      }

      if (response.statusCode == 200) {
        final decodedBody = json.decode(response.body);
        if (decodedBody is List) {
          // Asegurarse de que todos los elementos sean Map<String, dynamic>
          return List<Map<String, dynamic>>.from(
            decodedBody.whereType<Map<String, dynamic>>(),
          );
        } else {
          print(
            "[MontevideoApiServiceAdapter_ERROR] Formato de respuesta inesperado para parada $stopId. Esperado: List, Obtenido: ${decodedBody.runtimeType}. Body: ${response.body}",
          );
          return [];
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        print(
          "[MontevideoApiServiceAdapter_WARN] Token expirado/inválido para parada $stopId. Reintentando una vez...",
        );
        _accessToken = null; // Invalidar token para forzar la renovación
        _tokenExpiration = null;
        final newToken = await _getApiToken();
        if (newToken != null) {
          http.Response retryResponse;
          try {
            retryResponse = await http
                .get(url, headers: {'Authorization': 'Bearer $newToken'})
                .timeout(const Duration(seconds: 10)); // Timeout en reintento
          } catch (e) {
            print(
              "[MontevideoApiServiceAdapter_ERROR] Timeout o error de red en reintento para $url: $e",
            );
            return [];
          }

          if (retryResponse.statusCode == 200) {
            final decodedRetryBody = json.decode(retryResponse.body);
            if (decodedRetryBody is List) {
              return List<Map<String, dynamic>>.from(
                decodedRetryBody.whereType<Map<String, dynamic>>(),
              );
            } else {
              print(
                "[MontevideoApiServiceAdapter_ERROR] Formato de respuesta inesperado para parada $stopId después de reintento. Esperado: List, Obtenido: ${decodedRetryBody.runtimeType}. Body: ${retryResponse.body}",
              );
              return [];
            }
          } else {
            print(
              "[MontevideoApiServiceAdapter_ERROR] Fallo al obtener llegadas para parada $stopId después de reintento: ${retryResponse.statusCode} ${retryResponse.body}",
            );
          }
        } else {
          print(
            "[MontevideoApiServiceAdapter_ERROR] No se pudo obtener nuevo token para reintento.",
          );
        }
        return []; // Devolver lista vacía si el reintento falla
      } else {
        // Manejar otros errores, como 404 (si la parada no existe) o 429 (rate limit)
        print(
          "[MontevideoApiServiceAdapter_ERROR] Fallo al obtener llegadas para parada $stopId: ${response.statusCode} ${response.body}",
        );
        return [];
      }
    } catch (e, s) {
      // Captura genérica para otros errores (ej. de parseo de JSON si no es válido)
      print(
        "[MontevideoApiServiceAdapter_ERROR] Excepción al obtener llegadas para parada $stopId: $e\n$s",
      );
      return [];
    }
  }

  @override
  Future<InfoDetalladaParada?> getStopDetailsWithEta(
    String idParada,
    String nombreParadaOriginal,
    Coordenada posicionParadaOriginal,
  ) async {
    print(
      "[MontevideoApiServiceAdapter] Solicitando detalles (ETAs) para parada ID: $idParada, Nombre: $nombreParadaOriginal",
    );

    final List<Map<String, dynamic>> rawArrivalData =
        await _fetchArrivalsForStopAPI(idParada);

    // Siempre devolver un objeto InfoDetalladaParada, incluso si no hay ETAs.
    // La UI decidirá cómo mostrar esto (ej. "No hay próximos arribos").
    final List<EtaMostrable> etas = [];
    final Set<String> lineasQuePasan = {};

    if (rawArrivalData.isEmpty) {
      print(
        "[MontevideoApiServiceAdapter_INFO] No se recibieron datos de llegada para parada $idParada desde _fetchArrivalsForStopAPI. Devolviendo info de parada sin ETAs.",
      );
    } else {
      for (var arrivalMap in rawArrivalData) {
        if (arrivalMap.isEmpty) continue;

        final minutosDynamic = arrivalMap['minutos'];
        final isReal = arrivalMap['real'] as bool? ?? false;
        // El campo 'linea' viene en cada objeto del array JSON
        final linea = arrivalMap['linea'] as String?;
        // El campo 'destino' no parece estar en /siguientesParada, pero lo dejamos por si acaso
        final destino = arrivalMap['descripcionDestino'] as String?;

        if (linea == null || linea.isEmpty) {
          print(
            "[MontevideoApiServiceAdapter_WARN] ETA recibida sin nombre de línea para parada $idParada. Saltando esta ETA: $arrivalMap",
          );
          continue;
        }
        lineasQuePasan.add(linea);

        int minutosParaLlegada;
        if (minutosDynamic is int) {
          minutosParaLlegada = minutosDynamic;
        } else if (minutosDynamic is double) {
          minutosParaLlegada = minutosDynamic.round();
        } else if (minutosDynamic is String) {
          minutosParaLlegada = int.tryParse(minutosDynamic) ?? 0;
        } else {
          // Si 'minutos' es nulo o de un tipo inesperado, asumir 0 o algún valor por defecto.
          // El valor 0 podría significar "llegando ahora" o "ya pasó".
          // Dependiendo de la API, podría ser mejor filtrar estas ETAs.
          print(
            "[MontevideoApiServiceAdapter_WARN] Minutos para llegada con formato inesperado o nulo para línea $linea en parada $idParada: $minutosDynamic. Usando 0.",
          );
          minutosParaLlegada = 0;
        }

        Coordenada? busPosition;
        // La API de /siguientesParada devuelve las coordenadas como una lista [longitud, latitud]
        // dentro del campo 'coordinates'.
        final coordinatesData = arrivalMap['coordinates'];
        if (coordinatesData is List) {
          if (coordinatesData.length == 2 &&
              coordinatesData[0] is num &&
              coordinatesData[1] is num) {
            // Evitar posición (0,0) si esto indica ausencia de datos reales
            if (!((coordinatesData[0] as num) == 0.0 &&
                (coordinatesData[1] as num) == 0.0)) {
              busPosition = Coordenada(
                // JSON es [longitud, latitud]
                longitud: (coordinatesData[0] as num).toDouble(),
                latitud: (coordinatesData[1] as num).toDouble(),
              );
            } else {
              print(
                "[MontevideoApiServiceAdapter_DEBUG] Posición de bus (0,0) recibida para línea $linea en parada $idParada. Se tratará como nula.",
              );
            }
          } else {
            print(
              "[MontevideoApiServiceAdapter_WARN] Coordenadas de bus con formato inesperado para línea $linea en parada $idParada: $coordinatesData",
            );
          }
        } else if (coordinatesData != null) {
          print(
            "[MontevideoApiServiceAdapter_WARN] Campo 'coordinates' no es una lista para línea $linea en parada $idParada: $coordinatesData",
          );
        }

        etas.add(
          EtaMostrable(
            linea: linea,
            destino: destino, // Será null si no viene de la API o es vacío
            minutosParaLlegada: minutosParaLlegada,
            esTiempoReal: isReal,
            posicionBus: busPosition,
          ),
        );
      }
    }

    if (etas.isEmpty && rawArrivalData.isNotEmpty) {
      // Esto es una advertencia: recibimos datos pero no pudimos parsearlos a ETAs mostrables.
      print(
        "[MontevideoApiServiceAdapter_WARN] Se procesaron ${rawArrivalData.length} llegadas crudas para $idParada, pero resultaron 0 ETAs mostrables. Verificar logs anteriores para detalles de parseo.",
      );
    }

    return InfoDetalladaParada(
      idParada: idParada,
      nombreParada: nombreParadaOriginal,
      posicion: posicionParadaOriginal,
      lineasQuePasan:
          lineasQuePasan.toList()..sort(), // Ordenar alfabéticamente
      etas: etas,
    );
  }

  // TODO: Implementar fetchBusLinesForStop y fetchRealtimeBusLocations si son necesarios
  // para la nueva arquitectura, adaptando la lógica del servicio antiguo.
}

// Provider para el MontevideoApiServiceAdapter.
// Usamos un Provider simple ya que el servicio en sí no gestiona un estado mutable
// que necesite ser observado directamente por la UI de la misma forma que un StateNotifier.
// AppLogicNotifier lo usará para obtener datos.
final montevideoApiServiceProvider = Provider<MontevideoApiServiceAdapterBase>((
  ref,
) {
  return MontevideoApiServiceAdapter();
});
