// Fuentes grabadas: respuestas reales capturadas (fixtures) para correr la
// app y los tests sin red.

import '../../contract/modelo.dart';
import '../puertos.dart';
import '../servicios/otp.dart';

/// Devuelve siempre el plan OTP grabado, con los horarios corridos para que
/// el primer itinerario salga ~[adelanto] después de "ahora".
class PlanificadorGrabado implements PlanificadorViajes {
  final Map<String, dynamic> planCrudo;
  final Duration adelanto;

  PlanificadorGrabado(
    this.planCrudo, {
    this.adelanto = const Duration(minutes: 1),
  });

  /// A partir de un fixture schemaVersion 2 (`rawOtpPlan`).
  factory PlanificadorGrabado.desdeFixture(Map<String, dynamic> fixture) =>
      PlanificadorGrabado(fixture['rawOtpPlan'] as Map<String, dynamic>);

  @override
  Future<List<ViajePlanificado>> planificar({
    required Coordenada origen,
    required Coordenada destino,
    required DateTime salida,
  }) async {
    final its =
        (planCrudo['plan']['itineraries'] as List).cast<Map<String, dynamic>>();
    final primero = its
        .map((i) => i['startTime'] as int)
        .reduce((a, b) => a < b ? a : b);
    final delta = salida.add(adelanto).millisecondsSinceEpoch - primero;
    return interpretarPlanOtp(
      _correr(planCrudo, delta) as Map<String, dynamic>,
    );
  }

  static Object? _correr(Object? json, int delta) {
    if (json is Map<String, dynamic>) {
      return {
        for (final e in json.entries)
          e.key:
              (e.key == 'startTime' || e.key == 'endTime') && e.value is int
                  ? (e.value as int) + delta
                  : _correr(e.value, delta),
      };
    }
    if (json is List) return [for (final x in json) _correr(x, delta)];
    return json;
  }
}

/// Lugares conocidos de Montevideo para búsquedas sin red.
class LugaresFijos implements BuscadorLugares {
  final List<Lugar> lugares;
  const LugaresFijos(this.lugares);

  static const montevideo = LugaresFijos([
    Lugar(
      id: 'plaza-independencia',
      nombre: 'Plaza Independencia',
      detalle: 'Ciudad Vieja, Montevideo',
      coordenada: Coordenada(-34.906971, -56.19946),
    ),
    Lugar(
      id: 'saldanha-3941',
      nombre: 'Saldanha da Gama 3941',
      detalle: 'Malvín, Montevideo',
      coordenada: Coordenada(-34.902448, -56.12828),
    ),
    Lugar(
      id: 'tres-cruces',
      nombre: 'Terminal Tres Cruces',
      detalle: 'Tres Cruces, Montevideo',
      coordenada: Coordenada(-34.8937, -56.1664),
    ),
    Lugar(
      id: 'estadio-centenario',
      nombre: 'Estadio Centenario',
      detalle: 'Parque Batlle, Montevideo',
      coordenada: Coordenada(-34.8945, -56.1528),
    ),
    Lugar(
      id: 'mercado-puerto',
      nombre: 'Mercado del Puerto',
      detalle: 'Ciudad Vieja, Montevideo',
      coordenada: Coordenada(-34.9064, -56.2126),
    ),
    Lugar(
      id: 'punta-carretas',
      nombre: 'Punta Carretas Shopping',
      detalle: 'Punta Carretas, Montevideo',
      coordenada: Coordenada(-34.9237, -56.1590),
    ),
  ]);

  @override
  Future<List<Lugar>> sugerencias(String texto, {Coordenada? cerca}) async {
    final q = _normalizar(texto);
    if (q.isEmpty) return const [];
    return [
      for (final l in lugares)
        if (_normalizar('${l.nombre} ${l.detalle ?? ''}').contains(q)) l,
    ];
  }

  static String _normalizar(String s) =>
      s
          .toLowerCase()
          .replaceAll(RegExp('[áà]'), 'a')
          .replaceAll(RegExp('[éè]'), 'e')
          .replaceAll(RegExp('[íì]'), 'i')
          .replaceAll(RegExp('[óò]'), 'o')
          .replaceAll(RegExp('[úùü]'), 'u')
          .trim();
}
