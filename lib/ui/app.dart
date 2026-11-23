// Raíz de la UI: un mapa persistente y, encima, el panel de la fase actual.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contract/app_state.dart';
import '../contract/proveedores.dart';
import 'avisos.dart';
import 'busqueda/pantalla_busqueda.dart';
import 'demo/demo.dart';
import 'estado_ui.dart';
import 'explorar/panel_explorar.dart';
import 'mapa/encuadre.dart';
import 'mapa/escena.dart';
import 'mapa/mapa_bondi.dart';
import 'opciones/panel_opciones.dart';
import 'tema/preferencia_tema.dart';
import 'textos/preferencia_idioma.dart';
import 'textos/textos.dart';
import 'tema/tema.dart';
import 'viaje/panel_viaje.dart';
import 'web/marco_web.dart';

class BondiApp extends ConsumerWidget {
  const BondiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idioma = ref.watch(idiomaProvider);
    fijarIdioma(idioma);
    return MaterialApp(
      title: 'BondiUY',
      debugShowCheckedModeBanner: false,
      theme: temaBondi(Brightness.light),
      darkTheme: temaBondi(Brightness.dark),
      themeMode: ref.watch(preferenciaTemaProvider),
      locale:
          idioma == Idioma.es ? const Locale('es', 'UY') : const Locale('en'),
      // Al cambiar de idioma se reconstruye todo con los textos nuevos (la
      // lógica y su estado viven fuera, en los providers: no se pierde nada).
      home: PantallaPrincipal(key: ValueKey(idioma)),
      // En la web, en pantallas anchas, dentro de un teléfono.
      builder: (context, child) => MarcoWeb(child: child!),
    );
  }
}

class PantallaPrincipal extends ConsumerStatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  ConsumerState<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends ConsumerState<PantallaPrincipal> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appActionsProvider).arrancar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(appStateProvider);
    final buscando = ref.watch(busquedaAbiertaProvider);
    final uiMapa = EstadoUiMapa(
      opcionEnfocada: ref.watch(opcionEnfocadaProvider),
      verBus: ref.watch(verBusProvider),
    );
    // Cada viaje empieza siguiéndote a vos.
    ref.listen<bool>(appStateProvider.select((s) => s.fase is FaseViaje), (
      antes,
      enViaje,
    ) {
      if (enViaje && antes == false) {
        ref.read(verBusProvider.notifier).state = false;
      }
    });
    final c = ColoresBondi.of(context);
    final alto = MediaQuery.sizeOf(context).height;
    final seguro = MediaQuery.paddingOf(context);

    // Zonas del mapa tapadas por los paneles de cada fase.
    final margenes = switch (estado.fase) {
      FaseExplorar() => EdgeInsets.only(
        top: seguro.top + 84,
        bottom:
            estado.paradaConsultada != null
                ? alto * 0.45
                : estado.demo != null
                ? seguro.bottom + 12 + ref.watch(altoTarjetaDemoProvider)
                : 24,
      ),
      FaseOpciones() => EdgeInsets.only(
        top: seguro.top + 84,
        bottom: seguro.bottom + 16 + ref.watch(altoHojaOpcionesProvider),
      ),
      final FaseViaje v => EdgeInsets.only(
        top: seguro.top + 8 + ref.watch(altoTarjetaViajeProvider),
        bottom: v.estado == EstadoViaje.completado ? alto * 0.42 : 100,
      ),
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (c.brillo == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: MapaBondi(
                key: const ValueKey('mapa'),
                escena: construirEscena(estado, uiMapa),
                encuadre: encuadreDe(estado, uiMapa),
                estilo: c.mapa,
                margenes: margenes,
                controlador: ref.watch(controladorMapaProvider),
                fuente: ref.watch(fuenteTeselasProvider),
                decodificarEnIsolate: ref.watch(teselasEnIsolateProvider),
                onTocarParada:
                    estado.fase is FaseExplorar
                        ? ref.read(appActionsProvider).consultarParada
                        : null,
                onTocarMapa:
                    estado.paradaConsultada != null
                        ? ref.read(appActionsProvider).cerrarParada
                        : null,
              ),
            ),
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder:
                    (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.03),
                          end: Offset.zero,
                        ).animate(a),
                        child: child,
                      ),
                    ),
                child: switch (estado.fase) {
                  FaseExplorar() => const PanelExplorar(
                    key: ValueKey('fase-explorar'),
                  ),
                  FaseOpciones() => const PanelOpciones(
                    key: ValueKey('fase-opciones'),
                  ),
                  FaseViaje() => const PanelViaje(key: ValueKey('fase-viaje')),
                },
              ),
            ),
            if (buscando != null)
              const Positioned.fill(
                child: PantallaBusqueda(key: ValueKey('busqueda')),
              ),
            const OyenteAvisos(),
          ],
        ),
      ),
    );
  }
}
