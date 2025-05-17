import 'package:intl/intl.dart';
import '../models/itinerary.dart';
import '../models/point_dart.dart';
import 'otp_service.dart'; // Asumimos que OtpService está en el mismo directorio o se importa correctamente
import 'package:graphql_flutter/graphql_flutter.dart';

class ItineraryPlanningException implements Exception {
  final String message;
  ItineraryPlanningException(this.message);

  @override
  String toString() => message;
}

class ItineraryPlanningService {
  final OtpService _otpService;

  ItineraryPlanningService(this._otpService);

  Future<List<Itinerary>> getItineraries({
    required Point_dart fromPoint,
    required Point_dart toPoint,
    required DateTime dateTime,
  }) async {
    final String date = DateFormat('yyyy-MM-dd').format(dateTime);
    final String time = DateFormat('HH:mm').format(dateTime);

    try {
      final QueryResult result = await _otpService.planRoute(
        fromLat: fromPoint.lat,
        fromLon: fromPoint.lng,
        toLat: toPoint.lat,
        toLon: toPoint.lng,
        date: date,
        time: time,
      );

      if (result.hasException) {
        print(
          "[ItineraryPlanningService_ERROR] GraphQL Exception: ${result.exception.toString()}",
        );
        throw ItineraryPlanningException(
          "Error al comunicarse con el planificador de rutas. Detalles: ${result.exception.toString()}",
        );
      }

      if (result.data == null || result.data!['plan']?['itineraries'] == null) {
        print(
          "[ItineraryPlanningService_ERROR] No data or itineraries found in OTP response. Data: ${result.data}",
        );
        // Podrías querer devolver una lista vacía si es un escenario esperado
        // o lanzar una excepción si consideras que siempre debería haber itinerarios o un error más específico.
        // Por ahora, lanzamos una excepción si 'plan' o 'itineraries' es null.
        if (result.data!['plan'] == null) {
          throw ItineraryPlanningException(
            "Respuesta inesperada del planificador: sección 'plan' faltante.",
          );
        }
        if (result.data!['plan']['itineraries'] == null) {
          // Esto puede pasar si OTP no encuentra rutas, lo cual es un caso válido.
          // Devolvemos una lista vacía en este caso.
          print(
            "[ItineraryPlanningService_INFO] No itineraries found for the given request.",
          );
          return [];
        }
      }

      // Asegurarnos que 'itineraries' es una lista antes de pasarla a Itinerary.listFromJson
      final itinerariesData = result.data!['plan']['itineraries'];
      if (itinerariesData is List) {
        return Itinerary.listFromJson(itinerariesData);
      } else {
        print(
          "[ItineraryPlanningService_ERROR] 'itineraries' no es una lista. Data: $itinerariesData",
        );
        throw ItineraryPlanningException(
          "Formato de respuesta inesperado del planificador: 'itineraries' no es una lista.",
        );
      }
    } catch (e) {
      print(
        "[ItineraryPlanningService_ERROR] Error en getItineraries: ${e.toString()}",
      );
      if (e is ItineraryPlanningException) {
        rethrow; // Relanzar excepciones propias
      }
      // Para otras excepciones, envolverlas o manejarlas
      throw ItineraryPlanningException(
        "Ocurrió un error inesperado al planificar la ruta: ${e.toString()}",
      );
    }
  }
}
