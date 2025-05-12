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
  }) async {
    final String queryString = """
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
          numItineraries: 3,
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
              from { name lat lon }
              to { name lat lon }
              route { gtfsId longName shortName }
              trip { gtfsId shapeId }
              legGeometry { points length }
              steps { streetName distance relativeDirection absoluteDirection }
              intermediatePlaces { name lat lon }
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
      },
      fetchPolicy: FetchPolicy.networkOnly,
    );

    return await client.query(options);
  }
}
