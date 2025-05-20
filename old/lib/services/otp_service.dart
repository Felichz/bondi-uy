import 'package:graphql_flutter/graphql_flutter.dart';

class OtpService {
  final GraphQLClient client;

  OtpService(this.client);

  Future<QueryResult> planRoute({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    required String date,
    required String time,
    int numItineraries = 3,
  }) async {
    final String queryString = """
      query PlanRuta(
        \$fromLat: Float!, \$fromLon: Float!,
        \$toLat: Float!, \$toLon: Float!,
        \$date: String!, \$time: String!,
        \$numItineraries: Int!
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
          numItineraries: \$numItineraries,
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
              from { name lat lon stop { gtfsId } }
              to { name lat lon stop { gtfsId } }
              route { gtfsId longName shortName }
              trip { gtfsId shapeId }
              legGeometry { points length }
              steps { streetName distance relativeDirection absoluteDirection }
              intermediatePlaces { name lat lon stop { gtfsId } }
            }
          }
        }
      }
    """;

    final QueryOptions options = QueryOptions(
      document: gql(queryString),
      variables: <String, dynamic>{
        'fromLat': fromLat,
        'fromLon': fromLon,
        'toLat': toLat,
        'toLon': toLon,
        'date': date,
        'time': time,
        'numItineraries': numItineraries,
      },
      fetchPolicy: FetchPolicy.networkOnly,
    );

    print("[OtpService_DEBUG] Intentando ejecutar consulta GraphQL a OTP...");
    try {
      final result = await client.query(options);
      print("[OtpService_DEBUG] Consulta GraphQL a OTP completada.");
      if (result.hasException) {
        print(
          "[OtpService_ERROR] Excepción en consulta GraphQL: ${result.exception.toString()}",
        );
      }
      return result;
    } catch (e, s) {
      print(
        "[OtpService_ERROR] Error CATCH ejecutando client.query: ${e.toString()}\n$s",
      );
      // Re-lanzar la excepción para que sea manejada por ItineraryPlanningService
      rethrow;
    }
  }
}
