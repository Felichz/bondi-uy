// Arnés para correr la app completa en widget tests (headless):
// - mapa pixel real con teselas grabadas (test/fixtures/teselas)
// - lógica real (AppController) con plan OTP grabado y mundo simulado
// - fuentes reales cargadas para capturas legibles
// - tiempo falso controlado por el test

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/contract/proveedores.dart';
import 'package:bondi_uy/contract/trazas.dart';
import 'package:bondi_uy/logic/app_controller.dart';
import 'package:bondi_uy/logic/trazado.dart';
import 'package:bondi_uy/logic/puertos.dart';
import 'package:bondi_uy/logic/servicios/catalogo_assets.dart';
import 'package:bondi_uy/logic/simulacion/demo.dart';
import 'package:bondi_uy/logic/simulacion/grabado.dart';
import 'package:bondi_uy/logic/simulacion/mundo_simulado.dart';
import 'package:bondi_uy/ui/app.dart';
import 'package:bondi_uy/ui/estado_ui.dart';
import 'package:bondi_uy/ui/tema/preferencia_tema.dart';
import 'package:bondi_uy/ui/textos/preferencia_idioma.dart';
import 'package:bondi_uy/ui/textos/textos.dart';
import 'package:bondi_uy/ui/mapa/teselas/fuente_teselas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../logica/fixture.dart';

const origenFixture = Coordenada(-34.902448, -56.12828);

/// Teselas precargadas en memoria (el tiempo falso no espera I/O real).
class TeselasEnMemoria implements FuenteTeselas {
  final Map<String, Uint8List> _datos;
  TeselasEnMemoria(this._datos);

  static TeselasEnMemoria? _cache;
  static TeselasEnMemoria cargar() =>
      _cache ??= () {
        final datos = <String, Uint8List>{};
        for (final f in Directory(
          'test/fixtures/teselas',
        ).listSync(recursive: true)) {
          if (f is! File || !f.path.endsWith('.pbf')) continue;
          final partes = f.uri.pathSegments;
          final n = partes.length;
          datos['${partes[n - 3]}/${partes[n - 2]}/${partes[n - 1].split('.').first}'] =
              f.readAsBytesSync();
        }
        return TeselasEnMemoria(datos);
      }();

  @override
  Future<Uint8List?> bytes(int z, int x, int y) async => _datos['$z/$x/$y'];
}

/// Bundle que lee assets del disco del proyecto.
class BundleDisco extends CachingAssetBundle {
  final Map<String, ByteData> _cache = {};
  @override
  Future<ByteData> load(String key) async =>
      _cache[key] ??= ByteData.sublistView(File(key).readAsBytesSync());

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      utf8.decode(File(key).readAsBytesSync());
}

bool _fuentesCargadas = false;

Future<void> cargarFuentes() async {
  if (_fuentesCargadas) return;
  _fuentesCargadas = true;
  const base = '../bondi-uy-flutter/flutter/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final f in [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
  ]) {
    final archivo = File('$base/$f');
    if (archivo.existsSync()) {
      roboto.addFont(
        Future.value(ByteData.sublistView(archivo.readAsBytesSync())),
      );
    }
  }
  await roboto.load();
  final iconos = FontLoader('MaterialIcons');
  final archivoIconos = File('$base/materialicons-regular.otf');
  if (archivoIconos.existsSync()) {
    iconos.addFont(
      Future.value(ByteData.sublistView(archivoIconos.readAsBytesSync())),
    );
    await iconos.load();
  }
}

class Arnes {
  final WidgetTester tester;
  final MundoSimulado mundo;
  final AppController controlador;
  final ProviderContainer container;

  /// Las llamadas entre piezas (solo con la presentación web alrededor).
  TrazasAnotadas? trazas;
  bool get marco => trazas != null;
  Duration _transcurrido = Duration.zero;
  int _captura = 0;
  final String prefijo;

  Arnes._(
    this.tester,
    this.mundo,
    this.controlador,
    this.container,
    this.prefijo,
  );

  static Future<Arnes> montar(
    WidgetTester tester, {
    String prefijo = 'flujo',
    double velocidad = 10,
    Size tam = const Size(412, 892),
    PlanificadorViajes Function(PlanificadorViajes real)? envolverPlan,
    FuenteUbicacion Function(FuenteUbicacion real)? envolverUbicacion,
    bool sinAnimaciones = false,
    bool oscuro = false,
    bool demo = false,
    Idioma idioma = Idioma.es,
    // La presentación web alrededor (true: la vista "por dentro"), con las
    // llamadas entre piezas informadas.
    bool? marco,
  }) async {
    await cargarFuentes();
    if (sinAnimaciones) {
      // Como en el emulador/teléfonos con "Quitar animaciones" activado.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }
    // Un teléfono a la densidad de uno real; la presentación web, a la de
    // una pantalla de escritorio.
    final densidad = marco == null ? 2.625 : 1.0;
    tester.view.physicalSize = tam * densidad;
    tester.view.devicePixelRatio = densidad;
    late Arnes arnes;
    final catalogo = CatalogoAssets(bundle: BundleDisco());
    final trazas = marco == null ? null : TrazasAnotadas();
    final mundo = MundoSimulado(
      catalogo: catalogo,
      posicionInicial: demo ? casaDemo : origenFixture,
      p: ParametrosSimulacion(velocidad: velocidad, esperaMinima: 60),
      ahoraSimulado: DateTime(2026, 9, 28, 18),
      transcurrido: () => arnes._transcurrido,
    );
    final base = PlanificadorGrabado.desdeFixture(fixture());
    final plan = PlanificadorSimulado(envolverPlan?.call(base) ?? base, mundo);
    final ubicacion = UbicacionSimulada(mundo);
    final controlador =
        demo
            ? crearControladorDemo(
              mundo: mundo,
              catalogo: catalogo,
              bundle: BundleDisco(),
              trazas: trazas,
              config: const ConfigLogica(
                sondeoBus: Duration(milliseconds: 1500),
              ),
            )
            : AppController(
              planificador: plan,
              llegadas: LlegadasSimuladas(mundo),
              lugares: LugaresFijos.montevideo,
              catalogo: catalogo,
              ubicacion: envolverUbicacion?.call(ubicacion) ?? ubicacion,
              reloj: mundo.ahora,
              config: ConfigLogica(
                sondeoBus: Duration(milliseconds: (10000 / velocidad).round()),
              ),
              alIniciarViaje: (o) => mundo.recorrer(o, plan.shapesDe(o.id)),
              alTerminarViaje: mundo.detener,
            );
    final container = ProviderContainer(
      overrides: [
        appStateProvider.overrideWith((ref) => ref.watch(_controladorProvider)),
        appActionsProvider.overrideWith((ref) {
          final acciones = ref.watch(_controladorProvider.notifier);
          return trazas == null ? acciones : AccionesTrazadas(acciones, trazas);
        }),
        trazasProvider.overrideWithValue(trazas),
        marcoForzadoProvider.overrideWithValue(marco),
        _controladorProvider.overrideWith((ref) => controlador),
        fuenteTeselasProvider.overrideWithValue(TeselasEnMemoria.cargar()),
        teselasEnIsolateProvider.overrideWithValue(false),
        idiomaProvider.overrideWith(
          (_) => PreferenciaIdioma(inicial: idioma, persistir: false),
        ),
        preferenciaTemaProvider.overrideWith(
          (_) =>
              PreferenciaTema(persistir: false)
                ..fijar(oscuro ? ThemeMode.dark : ThemeMode.light),
        ),
      ],
    );
    arnes = Arnes._(tester, mundo, controlador, container, prefijo)
      ..trazas = trazas;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(key: _raiz, child: const BondiApp()),
      ),
    );
    await arnes.esperar(const Duration(milliseconds: 600));
    return arnes;
  }

  /// Avanza el tiempo real (y el simulado) de a pasos, bombeando cuadros.
  Future<void> esperar(
    Duration d, {
    Duration paso = const Duration(milliseconds: 100),
  }) async {
    var resto = d;
    while (resto > Duration.zero) {
      final p = resto < paso ? resto : paso;
      _transcurrido += p;
      await tester.pump(p);
      resto -= p;
    }
  }

  /// Avanza hasta que [condicion] se cumpla (o falla tras [maximo]).
  Future<void> hasta(
    bool Function() condicion, {
    Duration maximo = const Duration(minutes: 5),
    Duration paso = const Duration(milliseconds: 250),
    String? razon,
  }) async {
    var t = Duration.zero;
    while (!condicion()) {
      if (t > maximo) {
        fail('No se cumplió a tiempo: ${razon ?? ''}');
      }
      await esperar(paso, paso: paso);
      t += paso;
    }
  }

  /// Fase actual (atajo para asserts).
  Fase get fase => controlador.state.fase;

  Future<void> tocar(String clave) async {
    await tester.tap(find.byKey(ValueKey(clave)));
    await esperar(const Duration(milliseconds: 400));
  }

  /// Busca "plaza" y elige Plaza Independencia; espera las opciones.
  Future<void> buscarPlaza() async {
    await tocar('buscar-destino');
    await tester.enterText(
      find.byKey(const ValueKey('campo-destino')),
      'plaza',
    );
    await esperar(const Duration(milliseconds: 600));
    await tocar('sugerencia-plaza-independencia');
    await hasta(
      () =>
          fase is FaseOpciones &&
          (fase as FaseOpciones).estado != EstadoOpciones.cargando,
      razon: 'opciones calculadas',
    );
    await esperar(const Duration(milliseconds: 500));
  }

  /// Avanza hasta que el viaje llegue al paso [paso] (o se complete).
  Future<void> hastaPaso(
    int paso, {
    Duration maximo = const Duration(minutes: 6),
  }) => hasta(
    () {
      final f = fase;
      return f is FaseViaje &&
          (f.pasoActual >= paso || f.estado == EstadoViaje.completado);
    },
    maximo: maximo,
    paso: const Duration(milliseconds: 500),
    razon: 'llegar al paso $paso',
  );

  /// Guarda una captura PNG de la pantalla en build/capturas/.
  Future<void> capturar(String nombre) async {
    await tester.pump();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_raiz),
    );
    await tester.runAsync(() async {
      // Un teléfono, más nítido; la presentación de escritorio, a tamaño real.
      final img = await boundary.toImage(pixelRatio: marco ? 1.0 : 1.5);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      final f = File(
        'build/capturas/${prefijo}_${(++_captura).toString().padLeft(2, '0')}_$nombre.png',
      );
      await f.parent.create(recursive: true);
      await f.writeAsBytes(png!.buffer.asUint8List());
    });
  }

  /// Desmonta la app (cancela timers) y libera el contenedor.
  Future<void> cerrar() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    container.dispose();
  }
}

/// Trazas que además anotan qué piezas se llamaron (sin suscribirse: una
/// suscripción desde el test traba el desmontaje con el tiempo falso).
class TrazasAnotadas extends Trazas {
  final llamadas = <(Pieza, Pieza)>{};

  @override
  void emitir(Pieza desde, Pieza hacia, String llamada, {String? resultado}) {
    llamadas.add((desde, hacia));
    super.emitir(desde, hacia, llamada, resultado: resultado);
  }
}

final _raiz = GlobalKey();
final _controladorProvider = StateNotifierProvider<AppController, AppState>(
  (ref) => throw UnimplementedError(),
);
