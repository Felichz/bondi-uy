// Estado propio de la UI: conceptos de presentación que la lógica no conoce.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contract/app_state.dart';
import 'mapa/mapa_bondi.dart';
import 'mapa/teselas/fuente_teselas.dart';

/// Opción del carrusel que el usuario está mirando.
final opcionEnfocadaProvider = StateProvider<String?>((_) => null);

/// Buscador abierto y campo con foco (null = cerrado).
final busquedaAbiertaProvider = StateProvider<CampoBusqueda?>((_) => null);

/// Alto de la tarjeta del paso en viaje (px lógicos): el mapa encuadra
/// debajo de ella.
final altoTarjetaViajeProvider = StateProvider<double>((_) => 200);

/// Alto de la hoja de opciones (px lógicos): el mapa encuadra encima.
final altoHojaOpcionesProvider = StateProvider<double>((_) => 320);

/// De dónde salen las teselas del mapa (los tests usan archivos locales).
final fuenteTeselasProvider = Provider<FuenteTeselas>(
  (_) => TeselasOpenFreeMap(),
);

/// Decodificar teselas en un isolate (en tests con tiempo falso: false).
final teselasEnIsolateProvider = Provider<bool>((_) => true);

final controladorMapaProvider = Provider<ControladorMapa>((ref) {
  final c = ControladorMapa();
  ref.onDispose(c.dispose);
  return c;
});
