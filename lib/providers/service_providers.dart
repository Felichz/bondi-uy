import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../services/montevideo_api_service.dart';
import '../services/otp_service.dart';
import '../services/geocoding_service.dart';

// Proveedor para MontevideoApiService
final montevideoApiServiceProvider = Provider<MontevideoApiService>((ref) {
  return MontevideoApiService();
});

// Proveedor para el cliente GraphQL de OTP
// TODO: Considerar mover la URL a constantes si aún no está allí.
final otpGraphQLClientProvider = Provider<GraphQLClient>((ref) {
  const String otpServerUrlGraphql =
      "http://10.0.2.2:8080/otp/routers/default/index/graphql"; // O IP host
  final HttpLink httpLink = HttpLink(otpServerUrlGraphql);
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
