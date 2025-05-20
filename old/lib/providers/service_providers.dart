import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../services/montevideo_api_service.dart';
import '../services/otp_service.dart';
import '../services/geocoding_service.dart';
import '../constants/otp_constants.dart';
import '../services/itinerary_planning_service.dart';
import '../services/eta_fetcher_service.dart';
import 'dart:io'; // Para HttpClient de dart:io
import 'package:http/io_client.dart'; // Para IOClient

// Proveedor para MontevideoApiService
final montevideoApiServiceProvider = Provider<MontevideoApiService>((ref) {
  return MontevideoApiService();
});

// Nuevo proveedor para la interfaz ETAFetcherService
// Actualmente, su implementación es MontevideoApiService
final etaFetcherServiceProvider = Provider<ETAFetcherService>((ref) {
  return ref.watch(montevideoApiServiceProvider);
});

// Proveedor para el cliente GraphQL de OTP
final otpGraphQLClientProvider = Provider<GraphQLClient>((ref) {
  // 1. Crear y configurar HttpClient de dart:io
  final HttpClient dartIoHttpClient =
      HttpClient()
        ..connectionTimeout = const Duration(
          seconds: 20,
        ) // Timeout para establecer la conexión
        ..idleTimeout = const Duration(
          seconds: 30,
        ); // Timeout si la conexión está inactiva (esperando respuesta)

  // 2. Crear un IOClient que use el HttpClient configurado
  final IOClient ioClient = IOClient(dartIoHttpClient);

  // 3. Usar el IOClient al crear el HttpLink
  final HttpLink httpLink = HttpLink(
    OTP_SERVER_URL_GRAPHQL,
    httpClient: ioClient, // Pasar el cliente configurado
  );

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

// Proveedor para el ItineraryPlanningService
// Ahora depende de la abstracción ETAFetcherService
final itineraryPlanningServiceProvider = Provider<ItineraryPlanningService>((
  ref,
) {
  final otpService = ref.watch(otpServiceProvider);
  final etaFetcher = ref.watch(etaFetcherServiceProvider);
  return ItineraryPlanningService(
    otpService: otpService,
    etaFetcherService: etaFetcher,
  );
});
