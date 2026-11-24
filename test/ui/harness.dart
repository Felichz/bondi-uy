// Harness to run the full app in widget tests (headless):
// - real pixel map with recorded tiles (test/fixtures/teselas)
// - real logic (AppController) with a recorded OTP plan and a simulated world
// - real fonts loaded so the screenshots are readable
// - fake time controlled by the test

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/contract/providers.dart';
import 'package:bondi_uy/contract/traces.dart';
import 'package:bondi_uy/logic/app_controller.dart';
import 'package:bondi_uy/logic/traced.dart';
import 'package:bondi_uy/logic/ports.dart';
import 'package:bondi_uy/logic/services/catalog_assets.dart';
import 'package:bondi_uy/logic/simulation/demo.dart';
import 'package:bondi_uy/logic/simulation/recording.dart';
import 'package:bondi_uy/logic/simulation/simulated_world.dart';
import 'package:bondi_uy/ui/app.dart';
import 'package:bondi_uy/ui/ui_status.dart';
import 'package:bondi_uy/ui/theme/theme_preference.dart';
import 'package:bondi_uy/ui/texts/language_preference.dart';
import 'package:bondi_uy/ui/texts/texts.dart';
import 'package:bondi_uy/ui/map/tiles/tile_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../logic/fixture.dart';

const originFixture = Coordinate(-34.902448, -56.12828);

/// Tiles preloaded in memory (fake time does not wait for real I/O).
class MemoryTiles implements TileSource {
  final Map<String, Uint8List> _data;
  MemoryTiles(this._data);

  static MemoryTiles? _cache;
  static MemoryTiles load() =>
      _cache ??= () {
        final data = <String, Uint8List>{};
        for (final f in Directory(
          'test/fixtures/teselas',
        ).listSync(recursive: true)) {
          if (f is! File || !f.path.endsWith('.pbf')) continue;
          final parts = f.uri.pathSegments;
          final n = parts.length;
          data['${parts[n - 3]}/${parts[n - 2]}/${parts[n - 1].split('.').first}'] =
              f.readAsBytesSync();
        }
        return MemoryTiles(data);
      }();

  @override
  Future<Uint8List?> bytes(int z, int x, int y) async => _data['$z/$x/$y'];
}

/// Bundle that reads assets from the project's disk.
class DiskBundle extends CachingAssetBundle {
  final Map<String, ByteData> _cache = {};
  @override
  Future<ByteData> load(String key) async =>
      _cache[key] ??= ByteData.sublistView(File(key).readAsBytesSync());

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      utf8.decode(File(key).readAsBytesSync());
}

bool _sourcesLoaded = false;

Future<void> loadSources() async {
  if (_sourcesLoaded) return;
  _sourcesLoaded = true;
  const base = '../bondi-uy-flutter/flutter/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final f in [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
  ]) {
    final file = File('$base/$f');
    if (file.existsSync()) {
      roboto.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons');
  final fileIcons = File('$base/materialicons-regular.otf');
  if (fileIcons.existsSync()) {
    icons.addFont(
      Future.value(ByteData.sublistView(fileIcons.readAsBytesSync())),
    );
    await icons.load();
  }
}

class Harness {
  final WidgetTester tester;
  final SimulatedWorld world;
  final AppController controller;
  final ProviderContainer container;

  /// Calls between parts (only when the web presentation wraps the app).
  AnnotatedTraces? traces;
  bool get frame => traces != null;
  Duration _elapsed = Duration.zero;
  int _capture = 0;
  final String prefix;

  Harness._(
    this.tester,
    this.world,
    this.controller,
    this.container,
    this.prefix,
  );

  static Future<Harness> mount(
    WidgetTester tester, {
    String prefix = 'flujo',
    double velocity = 10,
    Size size = const Size(412, 892),
    TripPlanner Function(TripPlanner real)? wrapPlan,
    LocationSource Function(LocationSource real)? wrapLocation,
    bool withoutAnimations = false,
    bool dark = false,
    bool demo = false,
    Language language = Language.es,
    // The web presentation around it (true: the "inside" view), with the
    // calls between parts reported.
    bool? frame,
  }) async {
    await loadSources();
    if (withoutAnimations) {
      // As on the emulator/phones with "Remove animations" enabled.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }
    // A phone at the density of a real one; the web presentation at the
    // density of a desktop screen.
    final density = frame == null ? 2.625 : 1.0;
    tester.view.physicalSize = size * density;
    tester.view.devicePixelRatio = density;
    late Harness harness;
    final catalog = CatalogAssets(bundle: DiskBundle());
    final traces = frame == null ? null : AnnotatedTraces();
    final world = SimulatedWorld(
      catalog: catalog,
      positionInitial: demo ? houseDemo : originFixture,
      p: SimulationParams(velocity: velocity, waitMin: 60),
      nowSimulated: DateTime(2026, 9, 28, 18),
      elapsed: () => harness._elapsed,
    );
    final base = RecordingPlanner.fromFixture(fixture());
    final plan = SimulatedPlanner(wrapPlan?.call(base) ?? base, world);
    final location = SimulatedLocation(world);
    final controller =
        demo
            ? createControllerDemo(
              world: world,
              catalog: catalog,
              bundle: DiskBundle(),
              traces: traces,
              config: const LogicConfig(pollBus: Duration(milliseconds: 1500)),
            )
            : AppController(
              planner: plan,
              arrivals: SimulatedArrivals(world),
              places: FixedPlaces.montevideo,
              catalog: catalog,
              location: wrapLocation?.call(location) ?? location,
              clock: world.now,
              config: LogicConfig(
                pollBus: Duration(milliseconds: (10000 / velocity).round()),
              ),
              onStartTrip: (o) => world.traverse(o, plan.shapesOf(o.id)),
              onFinishTrip: world.stop,
            );
    final container = ProviderContainer(
      overrides: [
        appStateProvider.overrideWith((ref) => ref.watch(_controllerProvider)),
        appActionsProvider.overrideWith((ref) {
          final actions = ref.watch(_controllerProvider.notifier);
          return traces == null ? actions : TracedActions(actions, traces);
        }),
        tracesProvider.overrideWithValue(traces),
        frameForcedProvider.overrideWithValue(frame),
        _controllerProvider.overrideWith((ref) => controller),
        sourceTilesProvider.overrideWithValue(MemoryTiles.load()),
        tilesInIsolateProvider.overrideWithValue(false),
        languageProvider.overrideWith(
          (_) => LanguagePreference(initial: language, persist: false),
        ),
        preferenceThemeProvider.overrideWith(
          (_) =>
              ThemePreference(persist: false)
                ..pin(dark ? ThemeMode.dark : ThemeMode.light),
        ),
      ],
    );
    harness = Harness._(tester, world, controller, container, prefix)
      ..traces = traces;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(key: _raiz, child: const BondiApp()),
      ),
    );
    await harness.wait(const Duration(milliseconds: 600));
    return harness;
  }

  /// Advances real (and simulated) time in steps, pumping frames.
  Future<void> wait(
    Duration d, {
    Duration step = const Duration(milliseconds: 100),
  }) async {
    var rest = d;
    while (rest > Duration.zero) {
      final p = rest < step ? rest : step;
      _elapsed += p;
      await tester.pump(p);
      rest -= p;
    }
  }

  /// Advances until [condicion] holds (or fails after [maximo]).
  Future<void> until(
    bool Function() condition, {
    Duration max = const Duration(minutes: 5),
    Duration step = const Duration(milliseconds: 250),
    String? reason,
  }) async {
    var t = Duration.zero;
    while (!condition()) {
      if (t > max) {
        fail('No se cumplió a tiempo: ${reason ?? ''}');
      }
      await wait(step, step: step);
      t += step;
    }
  }

  /// Current phase (shortcut for asserts).
  Phase get phase => controller.state.phase;

  Future<void> tocar(String clave) async {
    await tester.tap(find.byKey(ValueKey(clave)));
    await wait(const Duration(milliseconds: 400));
  }

  /// Searches for "plaza" and picks Plaza Independencia; waits for the options.
  Future<void> searchSquare() async {
    await tocar('buscar-destino');
    await tester.enterText(
      find.byKey(const ValueKey('campo-destino')),
      'plaza',
    );
    await wait(const Duration(milliseconds: 600));
    await tocar('sugerencia-plaza-independencia');
    await until(
      () =>
          phase is OptionsPhase &&
          (phase as OptionsPhase).status != OptionsStatus.loading,
      reason: 'opciones calculadas',
    );
    await wait(const Duration(milliseconds: 500));
  }

  /// Advances until the trip reaches step [paso] (or completes).
  Future<void> untilStep(
    int step, {
    Duration max = const Duration(minutes: 6),
  }) => until(
    () {
      final f = phase;
      return f is TripPhase &&
          (f.stepActual >= step || f.status == TripStatus.completed);
    },
    max: max,
    step: const Duration(milliseconds: 500),
    reason: 'llegar al paso $step',
  );

  /// Saves a PNG screenshot of the screen to build/capturas/.
  Future<void> capture(String name) async {
    await tester.pump();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_raiz),
    );
    await tester.runAsync(() async {
      // A phone, sharper; the desktop presentation, at real size.
      final img = await boundary.toImage(pixelRatio: frame ? 1.0 : 1.5);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      final f = File(
        'build/capturas/${prefix}_${(++_capture).toString().padLeft(2, '0')}_$name.png',
      );
      await f.parent.create(recursive: true);
      await f.writeAsBytes(png!.buffer.asUint8List());
    });
  }

  /// Unmounts the app (cancels timers) and releases the container.
  Future<void> close() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    container.dispose();
  }
}

/// Traces that also note which parts were called (without subscribing: a
/// subscription from the test blocks unmounting under fake time).
class AnnotatedTraces extends Traces {
  final calls = <(Piece, Piece)>{};

  @override
  void emit(Piece from, Piece toward, String call, {String? result}) {
    calls.add((from, toward));
    super.emit(from, toward, call, result: result);
  }
}

final _raiz = GlobalKey();
final _controllerProvider = StateNotifierProvider<AppController, AppState>(
  (ref) => throw UnimplementedError(),
);
