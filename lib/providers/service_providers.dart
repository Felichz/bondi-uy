import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../services/montevideo_api_service.dart';
import '../services/otp_service.dart';
import '../services/geocoding_service.dart';
import '../constants/otp_constants.dart';
import '../services/itinerary_planning_service.dart';

// Proveedor para MontevideoApiService
final montevideoApiServiceProvider = Provider<MontevideoApiService>((ref) {
  return MontevideoApiService();
});

// Proveedor para el cliente GraphQL de OTP
// TODO: Considerar mover la URL a constantes si aún no está allí.
final otpGraphQLClientProvider = Provider<GraphQLClient>((ref) {
  final HttpLink httpLink = HttpLink(OTP_SERVER_URL_GRAPHQL);
  return GraphQLClient(
    link: httpLink,
    cache: GraphQLCache(store: InMemoryStore()),
  );
});

// Proveedor para OtpService que depende del cliente GraphQL
final otpServiceProvider = Provider<OtpService>((ref) {
  final graphQLClient = ref.watch(otpGraphQLClientProvider);
  return OtpService(graphQLClient);
});

// Proveedor para GeocodingService
final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  // GeocodingService ahora obtiene el token de las constantes internas
  return GeocodingService();
});

// Nota: MapboxService no se provee aquí directamente porque necesita la instancia
// de MapboxMap que se crea en el widget MapScreen. Se manejará de forma diferente.

// Proveedor para el nuevo ItineraryPlanningService
final itineraryPlanningServiceProvider = Provider<ItineraryPlanningService>((
  ref,
) {
  final otpService = ref.watch(otpServiceProvider);
  return ItineraryPlanningService(otpService);
});
