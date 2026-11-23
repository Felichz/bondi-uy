// Composición de la capa de lógica y punto de acceso para la UI.
//
// La UI solo usa `appStateProvider` (lee AppState) y `appActionsProvider`
// (invoca AppActions). Todo lo demás es interno de la lógica.
//
// Modo de ejecución (`--dart-define=BONDI_MODO=...`):
//   real      OTP + API de Montevideo + GPS del teléfono (por defecto)
//   demo      sin servidores: viajes reales grabados desde Malvín a varios
//             destinos, el usuario y los buses se mueven solos, a la
//             velocidad que se elija (por defecto en web)
//   simulado  OTP real, pero el usuario y los buses se mueven solos
//   grabado   sin red: un solo plan OTP grabado + mundo simulado (tests)

import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contract/app_state.dart';
import '../contract/proveedores.dart';
import 'app_controller.dart';
import 'puertos.dart';
import 'servicios/catalogo_assets.dart';
import 'servicios/lugares.dart';
import 'servicios/montevideo.dart';
import 'servicios/otp.dart';
import 'servicios/ubicacion_gps.dart';
import 'simulacion/demo.dart';
import 'simulacion/grabado.dart';
import 'simulacion/mundo_simulado.dart';

enum ModoApp { real, demo, simulado, grabado }

ModoApp modoDesdeEntorno() => switch (const String.fromEnvironment(
  'BONDI_MODO',
)) {
  'demo' => ModoApp.demo,
  'simulado' => ModoApp.simulado,
  'grabado' => ModoApp.grabado,
  'real' => ModoApp.real,
  // En la web no hay GPS confiable ni servidores propios: demo.
  _ => kIsWeb ? ModoApp.demo : ModoApp.real,
};

/// Origen del usuario simulado (por defecto, el del fixture grabado).
const _origenSimulado = Coordenada(-34.902448, -56.12828);

const fixtureGrabado = 'test/fixtures/trip_saldanha_plaza_otp_v2.json';

final modoAppProvider = Provider<ModoApp>((_) => modoDesdeEntorno());

final appControllerProvider = StateNotifierProvider<AppController, AppState>((
  ref,
) {
  final modo = ref.watch(modoAppProvider);
  final catalogo = CatalogoAssets();
  switch (modo) {
    case ModoApp.real:
      return AppController(
        planificador: PlanificadorOtp(),
        llegadas:
            llegadasMontevideoConfiguradas
                ? LlegadasMontevideo()
                : const _SinLlegadas(),
        lugares: buscadorLugaresPorDefecto(),
        catalogo: catalogo,
        ubicacion: UbicacionGps(),
      );
    case ModoApp.demo:
      return crearControladorDemo(
        mundo: MundoSimulado(
          catalogo: catalogo,
          posicionInicial: casaDemo,
          // La demo fija la escala según el paso del viaje (EscalasDemo).
          p: const ParametrosSimulacion(velocidad: 1),
        ),
        catalogo: catalogo,
      );
    case ModoApp.simulado:
    case ModoApp.grabado:
      final mundo = MundoSimulado(
        catalogo: catalogo,
        posicionInicial: _origenSimulado,
        p: const ParametrosSimulacion(velocidad: 6),
      );
      final base =
          modo == ModoApp.simulado
              ? PlanificadorOtp()
              : _PlanificadorDeAsset(fixtureGrabado);
      final plan = PlanificadorSimulado(base, mundo);
      return AppController(
        planificador: plan,
        llegadas: LlegadasSimuladas(mundo),
        lugares:
            modo == ModoApp.simulado
                ? buscadorLugaresPorDefecto()
                : LugaresFijos.montevideo,
        catalogo: catalogo,
        ubicacion: UbicacionSimulada(mundo),
        reloj: mundo.ahora,
        config: ConfigLogica(
          sondeoBus: Duration(
            milliseconds: (10000 / mundo.p.velocidad).round(),
          ),
        ),
        alIniciarViaje: (o) => mundo.recorrer(o, plan.shapesDe(o.id)),
        alTerminarViaje: mundo.detener,
      );
  }
});

/// Conecta el contrato con esta capa de lógica (usar en la raíz de
/// composición: `ProviderScope(overrides: overridesLogica)`).
final overridesLogica = <Override>[
  appStateProvider.overrideWith((ref) => ref.watch(appControllerProvider)),
  appActionsProvider.overrideWith(
    (ref) => ref.watch(appControllerProvider.notifier),
  ),
];

class _SinLlegadas implements FuenteLlegadas {
  const _SinLlegadas();
  @override
  Future<List<LlegadaEnParada>> llegadas(String idParada) async => const [];
}

class _PlanificadorDeAsset implements PlanificadorViajes {
  final String asset;
  PlanificadorGrabado? _plan;
  _PlanificadorDeAsset(this.asset);

  @override
  Future<List<ViajePlanificado>> planificar({
    required Coordenada origen,
    required Coordenada destino,
    required DateTime salida,
  }) async {
    _plan ??= PlanificadorGrabado.desdeFixture(
      jsonDecode(await rootBundle.loadString(asset)) as Map<String, dynamic>,
    );
    return _plan!.planificar(origen: origen, destino: destino, salida: salida);
  }
}
