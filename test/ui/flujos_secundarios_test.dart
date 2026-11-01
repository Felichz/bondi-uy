// Flujos secundarios y casos de borde, con la app completa.

import 'package:bondi_uy/contract/app_state.dart';
import 'package:bondi_uy/logic/puertos.dart';
import 'package:bondi_uy/ui/estado_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arnes.dart';

class _PlanQueFalla implements PlanificadorViajes {
  bool fallar = true;
  final PlanificadorViajes real;
  _PlanQueFalla(this.real);

  @override
  Future<List<ViajePlanificado>> planificar({
    required Coordenada origen,
    required Coordenada destino,
    required DateTime salida,
  }) async {
    if (fallar) throw const ErrorServicio('otp', 'sin conexión');
    return real.planificar(origen: origen, destino: destino, salida: salida);
  }
}

/// Deja solo los itinerarios con trasbordo (para ejercitar ese flujo).
class _SoloTrasbordos implements PlanificadorViajes {
  final PlanificadorViajes real;
  _SoloTrasbordos(this.real);

  @override
  Future<List<ViajePlanificado>> planificar({
    required Coordenada origen,
    required Coordenada destino,
    required DateTime salida,
  }) async => [
    for (final v in await real.planificar(
      origen: origen,
      destino: destino,
      salida: salida,
    ))
      if (v.opcion.lineas.length == 2) v,
  ];
}

class _PlanVacio implements PlanificadorViajes {
  @override
  Future<List<ViajePlanificado>> planificar({
    required Coordenada origen,
    required Coordenada destino,
    required DateTime salida,
  }) async => const [];
}

class _SinPermiso implements FuenteUbicacion {
  @override
  Future<PermisoUbicacion> asegurarPermiso() async => PermisoUbicacion.denegado;
  @override
  Future<MuestraUbicacion?> actual() async => null;
  @override
  Stream<MuestraUbicacion> seguir() => const Stream.empty();
}

void main() {
  testWidgets('trasbordo 526 -> 109: siete pasos, dos esperas en vivo', (
    tester,
  ) async {
    final a = await Arnes.montar(
      tester,
      prefijo: 'trasbordo',
      envolverPlan: (real) => _SoloTrasbordos(real),
    );
    await a.buscarPlaza();
    // Deslizar hasta la opción con dos buses.
    var intentos = 0;
    OpcionViaje enfocada() {
      final f = a.fase as FaseOpciones;
      final id = a.container.read(opcionEnfocadaProvider);
      return f.opciones.firstWhere(
        (o) => o.id == id,
        orElse: () => f.opciones.first,
      );
    }

    while (enfocada().lineas.length < 2 && intentos++ < 8) {
      await tester.drag(
        find.byKey(const ValueKey('opciones-carrusel')),
        const Offset(-300, 0),
      );
      await a.esperar(const Duration(milliseconds: 700));
    }
    final opcion = enfocada();
    expect(opcion.lineas.length, 2, reason: 'hay una opción con trasbordo');
    await a.capturar('opcion_trasbordo');
    await a.tocar('empezar-viaje');
    final total = (a.fase as FaseViaje).totalPasos;
    expect(total, 7);

    await a.hastaPaso(1);
    await a.esperar(const Duration(seconds: 2));
    expect(
      find.textContaining('Esperá el ${opcion.lineas[0]}'),
      findsOneWidget,
    );
    await a.capturar('espera_1');
    await a.hastaPaso(2);
    await a.esperar(const Duration(seconds: 2));
    expect(
      find.textContaining('Viajá en el ${opcion.lineas[0]}'),
      findsOneWidget,
    );
    // Arriba del bus no hay bus esperado: el bus es el usuario.
    expect((a.fase as FaseViaje).busEsperado, isNull);
    await a.capturar('en_bus_1');
    await a.hastaPaso(3);
    await a.esperar(const Duration(seconds: 1));
    expect(find.text('Caminá hasta la parada'), findsOneWidget);
    await a.capturar('trasbordo_caminando');
    await a.hastaPaso(4);
    await a.esperar(const Duration(seconds: 2));
    expect(
      find.textContaining('Esperá el ${opcion.lineas[1]}'),
      findsOneWidget,
    );
    final bus = (a.fase as FaseViaje).busEsperado;
    expect(
      bus?.linea,
      opcion.lineas[1],
      reason: 'el bus en vivo es de la segunda línea',
    );
    await a.capturar('espera_2');
    await a.hastaPaso(5);
    await a.hasta(
      () =>
          ((a.fase as FaseViaje).progreso.paradasRestantes ?? 99) == 0 ||
          (a.fase as FaseViaje).pasoActual > 5,
      maximo: const Duration(minutes: 5),
      razon: 'última parada',
    );
    if ((a.fase as FaseViaje).pasoActual == 5) {
      expect(find.text('¡Bajate en la próxima!'), findsOneWidget);
      await a.capturar('bajate');
    }
    await a.hastaPaso(6);
    await a.hasta(
      () => (a.fase as FaseViaje).estado == EstadoViaje.completado,
      maximo: const Duration(minutes: 4),
      razon: 'llegada',
    );
    await a.esperar(const Duration(seconds: 1));
    expect(find.text('¡Llegaste!'), findsOneWidget);
    // La tarjeta de llegada se cierra sola.
    await a.esperar(const Duration(seconds: 13));
    expect(a.fase, isA<FaseExplorar>());
    await a.cerrar();
  });

  testWidgets('volver desde opciones conserva el destino y permite repetir', (
    tester,
  ) async {
    final a = await Arnes.montar(tester, prefijo: 'volver');
    await a.buscarPlaza();
    await a.tocar('opciones-cerrar');
    expect(a.fase, isA<FaseExplorar>());
    expect(find.byKey(const ValueKey('buscar-completo')), findsOneWidget);
    expect(find.text('Plaza Independencia'), findsOneWidget);
    await a.capturar('destino_guardado');
    await a.tocar('ver-viajes');
    await a.hasta(
      () =>
          a.fase is FaseOpciones &&
          (a.fase as FaseOpciones).estado == EstadoOpciones.listo,
    );
    await a.cerrar();
  });

  testWidgets('terminar el viaje pide confirmación', (tester) async {
    final a = await Arnes.montar(tester, prefijo: 'terminar');
    await a.buscarPlaza();
    await a.tocar('empezar-viaje');
    await a.tocar('viaje-terminar');
    expect(find.text('¿Terminar el viaje?'), findsOneWidget);
    await a.capturar('confirmar');
    await tester.tap(find.text('Seguir'));
    await a.esperar(const Duration(milliseconds: 400));
    expect(a.fase, isA<FaseViaje>());
    await a.tocar('viaje-terminar');
    await a.tocar('viaje-terminar-confirmar');
    expect(a.fase, isA<FaseExplorar>());
    await a.cerrar();
  });

  testWidgets(
    'respaldo manual: "Ya estoy en la parada", "Ya subí", "Ya me bajé"',
    (tester) async {
      final a = await Arnes.montar(tester, prefijo: 'manual', velocidad: 1);
      await a.buscarPlaza();
      await a.tocar('empezar-viaje');
      expect(find.text('Ya estoy en la parada'), findsOneWidget);
      await a.tocar('viaje-confirmar-paso');
      expect((a.fase as FaseViaje).pasoActual, 1);
      expect((a.fase as FaseViaje).origenAvance, OrigenAvance.manual);
      expect(find.text('Ya subí al bus'), findsOneWidget);
      await a.tocar('viaje-confirmar-paso');
      expect((a.fase as FaseViaje).pasoActual, 2);
      expect(find.text('Ya me bajé'), findsOneWidget);
      await a.tocar('viaje-confirmar-paso');
      expect((a.fase as FaseViaje).pasoActual, 3);
      expect(find.text('Ya llegué'), findsOneWidget);
      await a.tocar('viaje-confirmar-paso');
      expect((a.fase as FaseViaje).estado, EstadoViaje.completado);
      await a.cerrar();
    },
  );

  testWidgets('tocar una parada muestra sus próximos buses', (tester) async {
    final a = await Arnes.montar(tester, prefijo: 'parada');
    await a.hasta(
      () => a.controlador.state.paradas.isNotEmpty,
      razon: 'red de paradas',
    );
    a.controlador.consultarParada('5296');
    await a.esperar(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('parada-nombre')), findsOneWidget);
    expect(find.byKey(const ValueKey('llegada-0')), findsOneWidget);
    await a.esperar(const Duration(seconds: 1));
    await a.capturar('hoja_parada');
    await a.tocar('parada-cerrar');
    expect(a.controlador.state.paradaConsultada, isNull);
    await a.cerrar();
  });

  testWidgets('intercambiar origen y destino', (tester) async {
    final a = await Arnes.montar(tester, prefijo: 'intercambiar');
    await a.buscarPlaza();
    await a.tocar('opciones-editar');
    await a.tocar('busqueda-intercambiar');
    final b = a.controlador.state.busqueda;
    expect(b.origen, isA<LugarElegido>());
    expect(b.destino, isA<MiUbicacion>());
    await a.capturar('intercambiado');
    await a.tocar('busqueda-volver');
    await a.cerrar();
  });

  testWidgets('si falla la planificación se puede reintentar', (tester) async {
    late _PlanQueFalla plan;
    final a = await Arnes.montar(
      tester,
      prefijo: 'error',
      envolverPlan: (real) => plan = _PlanQueFalla(real),
    );
    await a.buscarPlaza();
    expect((a.fase as FaseOpciones).estado, EstadoOpciones.error);
    expect(find.text('No pudimos calcular el viaje'), findsOneWidget);
    await a.capturar('error');
    plan.fallar = false;
    await tester.tap(find.text('Reintentar'));
    await a.hasta(
      () => (a.fase as FaseOpciones).estado == EstadoOpciones.listo,
    );
    await a.cerrar();
  });

  testWidgets('sin resultados ofrece cambiar el destino', (tester) async {
    final a = await Arnes.montar(
      tester,
      prefijo: 'vacio',
      envolverPlan: (_) => _PlanVacio(),
    );
    await a.buscarPlaza();
    expect((a.fase as FaseOpciones).estado, EstadoOpciones.sinResultados);
    expect(find.text('Cambiar destino'), findsOneWidget);
    await a.cerrar();
  });

  testWidgets('sin permiso de ubicación: aviso y búsqueda desde otro origen', (
    tester,
  ) async {
    final a = await Arnes.montar(
      tester,
      prefijo: 'sin_ubicacion',
      envolverUbicacion: (_) => _SinPermiso(),
    );
    await a.esperar(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('aviso-ubicacion')), findsOneWidget);
    await a.capturar('aviso');
    // Con "Mi ubicación" como origen no se puede planificar: avisa.
    await a.tocar('buscar-destino');
    await tester.enterText(
      find.byKey(const ValueKey('campo-destino')),
      'plaza',
    );
    await a.esperar(const Duration(milliseconds: 600));
    await a.tocar('sugerencia-plaza-independencia');
    await a.esperar(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('aviso-sinUbicacion')), findsOneWidget);
    expect(a.fase, isA<FaseExplorar>());
    // Elegir otro origen y buscar.
    await a.tocar('buscar-completo');
    await tester.tap(find.byKey(const ValueKey('campo-origen')));
    await a.esperar(const Duration(milliseconds: 300));
    await tester.enterText(
      find.byKey(const ValueKey('campo-origen')),
      'saldanha',
    );
    await a.esperar(const Duration(milliseconds: 600));
    await a.tocar('sugerencia-saldanha-3941');
    await a.hasta(
      () =>
          a.fase is FaseOpciones &&
          (a.fase as FaseOpciones).estado == EstadoOpciones.listo,
      razon: 'planifica desde el origen elegido',
    );
    await a.cerrar();
  });
}
