// Fase viaje: una instrucción clara por paso, que avanza sola.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contract/app_state.dart';
import '../../contract/proveedores.dart';
import '../comunes.dart';
import '../demo/demo.dart';
import '../estado_ui.dart';
import '../formatos.dart';
import '../tema/insignias.dart';
import '../tema/tema.dart';
import '../tema/lamina.dart';
import 'itinerario.dart';
import '../textos/textos.dart';

class PanelViaje extends ConsumerStatefulWidget {
  const PanelViaje({super.key});

  @override
  ConsumerState<PanelViaje> createState() => _PanelViajeState();
}

class _PanelViajeState extends ConsumerState<PanelViaje> {
  /// Confirmación breve de un avance ("Subiste al D1").
  ({int id, String texto, IconData icono})? _avance;
  Timer? _ocultarAvance;
  int _ids = 0;

  @override
  void dispose() {
    _ocultarAvance?.cancel();
    super.dispose();
  }

  void _alCambiarFase(Fase? antes, Fase ahora) {
    if (antes is! FaseViaje || ahora is! FaseViaje) return;
    final avanzo =
        ahora.pasoActual > antes.pasoActual ||
        (ahora.estado == EstadoViaje.completado &&
            antes.estado != EstadoViaje.completado);
    // Un aviso del paso anterior ("¡Bajate en la próxima!", "Tu bus está
    // llegando") ya no corresponde: se va, y no tapa lo que sigue.
    if (avanzo) ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    if (ahora.estado == EstadoViaje.completado &&
        antes.estado != EstadoViaje.completado) {
      HapticFeedback.heavyImpact();
      return;
    }
    if (ahora.pasoActual <= antes.pasoActual) return;
    final (texto, icono) = switch (antes.tramoActual) {
      TramoCaminar() => (tx.llegasteAParada, Icons.hail_rounded),
      TramoEsperar(:final linea) => (
        tx.subisteAl(linea),
        Icons.directions_bus_rounded,
      ),
      TramoBus(:final linea) => (
        tx.tebajasteDel(linea),
        Icons.directions_walk_rounded,
      ),
    };
    HapticFeedback.mediumImpact();
    _ocultarAvance?.cancel();
    setState(() => _avance = (id: ++_ids, texto: texto, icono: icono));
    _ocultarAvance = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _avance = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<Fase>(appStateProvider.select((s) => s.fase), _alCambiarFase);
    final estado = ref.watch(appStateProvider);
    final fase = estado.fase;
    if (fase is! FaseViaje) return const SizedBox.shrink();
    final destino = nombrePunto(estado.busqueda.destino, vacio: tx.tuDestino);
    final completado = fase.estado == EstadoViaje.completado;
    final avance = _avance;
    return SafeArea(
      child: Stack(
        children: [
          if (!completado)
            Positioned(
              left: 12,
              right: 12,
              top: 8,
              child: Medido(
                alCambiar:
                    (t) =>
                        ref.read(altoTarjetaViajeProvider.notifier).state =
                            t.height,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  layoutBuilder:
                      (actual, previos) => Stack(
                        alignment: Alignment.topCenter,
                        children: [...previos, if (actual != null) actual],
                      ),
                  transitionBuilder:
                      (c, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0.04, 0),
                            end: Offset.zero,
                          ).animate(a),
                          child: c,
                        ),
                      ),
                  child: _TarjetaPaso(
                    fase,
                    destino,
                    key: ValueKey('paso-${fase.pasoActual}'),
                  ),
                ),
              ),
            ),
          if (!completado)
            // Por encima de la confirmación de avance ("Subiste al D1").
            const Positioned(
              right: 16,
              bottom: 136,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BotonRecentrar(),
                  SizedBox(height: 12),
                  BotonVelocidadDemo(),
                ],
              ),
            ),
          if (!completado)
            Positioned(
              left: 12,
              right: 12,
              bottom: 78,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutBack,
                  transitionBuilder:
                      (c, a) => FadeTransition(
                        opacity: a,
                        child: ScaleTransition(scale: a, child: c),
                      ),
                  child:
                      avance == null
                          ? const SizedBox.shrink()
                          : _PildoraAvance(
                            avance.texto,
                            avance.icono,
                            key: ValueKey('avance-${avance.id}'),
                          ),
                ),
              ),
            ),
          if (!completado)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _BarraInferior(fase, destino),
            ),
          if (completado)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _Llegada(fase, destino),
            ),
        ],
      ),
    );
  }
}

/// "✓ Subiste al D1": confirma que el viaje avanzó solo.
class _PildoraAvance extends StatelessWidget {
  final String texto;
  final IconData icono;
  const _PildoraAvance(this.texto, this.icono, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(7, 7, 16, 7),
        decoration: BoxDecoration(
          color: c.accion,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: c.sombra,
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: c.enVivo,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Icon(icono, size: 18, color: c.sobreAccion.withValues(alpha: 0.7)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                texto,
                key: const ValueKey('viaje-avance'),
                style: TextStyle(
                  color: c.sobreAccion,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta de instrucción
// ---------------------------------------------------------------------------

class _TarjetaPaso extends StatelessWidget {
  final FaseViaje f;
  final String destino;
  const _TarjetaPaso(this.f, this.destino, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = f.tramoActual;
    final urgente = t is TramoBus && f.progreso.paradasRestantes == 0;
    return _Resaltado(
      activo: urgente,
      child: Lamina(
        key: const ValueKey('viaje-tarjeta'),
        radio: BorderRadius.circular(28),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Cabecera(f),
            const SizedBox(height: 10),
            _TiraPasos(f),
            const SizedBox(height: 16),
            switch (t) {
              TramoCaminar() => _PasoCaminar(f, t, destino),
              TramoEsperar() => _PasoEsperar(f, t),
              TramoBus() => _PasoBus(f, t),
            },
          ],
        ),
      ),
    );
  }
}

/// Borde que late alrededor de la tarjeta: "bajate en la próxima".
class _Resaltado extends StatefulWidget {
  final bool activo;
  final Widget child;
  const _Resaltado({required this.activo, required this.child});

  @override
  State<_Resaltado> createState() => _ResaltadoState();
}

class _ResaltadoState extends State<_Resaltado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sincronizar();
  }

  @override
  void didUpdateWidget(_Resaltado old) {
    super.didUpdateWidget(old);
    _sincronizar();
  }

  void _sincronizar() {
    final latir = widget.activo && !MediaQuery.disableAnimationsOf(context);
    if (latir && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!latir && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.activo) return widget.child;
    final c = ColoresBondi.of(context);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder:
          (context, child) => DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: c.bus.withValues(
                  alpha: _c.isAnimating ? 0.45 + 0.55 * _c.value : 1,
                ),
                width: 3,
              ),
            ),
            child: child,
          ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  final FaseViaje f;
  const _Cabecera(this.f);

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    final estilo = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: c.textoSuave,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Row(
      children: [
        Text(
          tx.pasoNdeM(f.pasoActual + 1, f.totalPasos),
          key: const ValueKey('viaje-paso'),
          style: estilo,
        ),
        const Spacer(),
        Icon(Icons.flag_rounded, size: 15, color: c.textoSuave),
        const SizedBox(width: 4),
        Text(
          tx.llegas(hora(f.opcion.llegada)),
          key: const ValueKey('viaje-llegas'),
          style: estilo,
        ),
      ],
    );
  }
}

class _TiraPasos extends StatelessWidget {
  final FaseViaje f;
  const _TiraPasos(this.f);

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    Color color(Tramo t) => switch (t) {
      TramoCaminar() => c.caminar,
      TramoEsperar() => c.enVivo,
      TramoBus() => c.bus,
    };
    final fraccion = f.progreso.fraccion;
    return Row(
      children: [
        for (var i = 0; i < f.totalPasos; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            flex: f.opcion.tramos[i] is TramoBus ? 3 : 2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color:
                          i < f.pasoActual
                              ? c.texto.withValues(alpha: 0.55)
                              : i == f.pasoActual
                              ? color(
                                f.opcion.tramos[i],
                              ).withValues(alpha: 0.25)
                              : c.separador,
                    ),
                    // El paso actual se llena con su avance.
                    if (i == f.pasoActual)
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor:
                            fraccion == null ? 1 : math.max(0.12, fraccion),
                        child: ColoredBox(color: color(f.opcion.tramos[i])),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Titulo extends StatelessWidget {
  final Widget icono;
  final String titulo;
  final String? detalle;
  const _Titulo({required this.icono, required this.titulo, this.detalle});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        icono,
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                key: const ValueKey('viaje-instruccion'),
                style: t.headlineSmall,
              ),
              if (detalle != null) ...[
                const SizedBox(height: 2),
                Text(
                  detalle!,
                  key: const ValueKey('viaje-detalle'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Cifra extends StatelessWidget {
  final String grande;
  final String? chica;
  final Color? color;
  const _Cifra(this.grande, {this.chica, this.color});

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    final numero = Text(
      grande,
      key: ValueKey(grande),
      maxLines: 1,
      style: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
        height: 1.15,
        color: color ?? c.texto,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    return Row(
      key: const ValueKey('viaje-cifra'),
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // Solo la cifra grande se anima, y solo cuando cambia ("Faltan 9
        // paradas" -> "Faltan 8 paradas"): la nueva sube con un fundido.
        Flexible(
          child: AnimatedSwitcher(
            duration: Duration(
              milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 260,
            ),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder:
                (actual, previos) => Stack(
                  alignment: Alignment.centerLeft,
                  children: [...previos, if (actual != null) actual],
                ),
            transitionBuilder:
                (hijo, a) => ClipRect(
                  child: FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(a),
                      child: hijo,
                    ),
                  ),
                ),
            child: numero,
          ),
        ),
        if (chica != null) ...[
          const SizedBox(width: 12),
          Text(
            chica!,
            maxLines: 1,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: c.textoSuave,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}

class _IconoRedondo extends StatelessWidget {
  final IconData icono;
  final Color color;
  final double? progreso;
  const _IconoRedondo(this.icono, this.color, {this.progreso});

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    final p = progreso;
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
          ),
          if (p != null)
            SizedBox(
              width: 54,
              height: 54,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: p),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder:
                    (_, v, __) => CircularProgressIndicator(
                      key: const ValueKey('viaje-progreso'),
                      value: v,
                      strokeWidth: 3.5,
                      strokeCap: StrokeCap.round,
                      backgroundColor: c.separador,
                      color: color,
                    ),
              ),
            ),
          Icon(icono, color: color, size: 26),
        ],
      ),
    );
  }
}

class _PasoCaminar extends StatelessWidget {
  final FaseViaje f;
  final TramoCaminar t;
  final String nombreDestino;
  const _PasoCaminar(this.f, this.t, this.nombreDestino);

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    final destino =
        t.haciaParada != null
            ? tx.parada(nombreParada(t.haciaParada!.nombre))
            : nombreDestino;
    final resto = f.progreso.metrosRestantes ?? t.distanciaMetros;
    final siguiente =
        f.pasoActual + 1 < f.totalPasos
            ? f.opcion.tramos[f.pasoActual + 1]
            : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Titulo(
          icono: _IconoRedondo(
            Icons.directions_walk_rounded,
            c.caminar,
            progreso: f.progreso.fraccion ?? 0,
          ),
          titulo: t.esAlDestino ? tx.caminaAlDestino : tx.caminaALaParada,
          detalle: destino,
        ),
        const SizedBox(height: 12),
        _Cifra(
          distancia(resto),
          chica: tx.caminando(duracion(segundosCaminando(resto))),
        ),
        if (!t.esAlDestino && f.busEsperado != null) ...[
          const SizedBox(height: 12),
          _BusQueViene(f.busEsperado!, segundosCaminando(resto)),
        ] else if (siguiente is TramoEsperar) ...[
          const SizedBox(height: 10),
          _Despues(tx.despuesEspera(siguiente.linea)),
        ],
      ],
    );
  }
}

/// Qué viene después, en chico.
class _Despues extends StatelessWidget {
  final String texto;
  const _Despues(this.texto);

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    return Row(
      children: [
        Icon(
          Icons.subdirectory_arrow_right_rounded,
          size: 18,
          color: c.textoTenue,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, color: c.textoSuave),
          ),
        ),
      ],
    );
  }
}

/// Mientras caminás a la parada: cuándo pasa tu bus y si llegás.
class _BusQueViene extends StatelessWidget {
  final BusEnCamino bus;
  final int segundosHastaParada;
  const _BusQueViene(this.bus, this.segundosHastaParada);

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    final justo = bus.minutos * 60 < segundosHastaParada;
    final color = !bus.enVivo || justo ? c.alerta : c.enVivo;
    return Capa(
      key: const ValueKey('viaje-bus-que-viene'),
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
      child: Row(
        children: [
          InsigniaLinea(bus.linea),
          const SizedBox(width: 10),
          if (bus.enVivo) PuntoEnVivo(color: color),
          if (bus.enVivo) const SizedBox(width: 4),
          Expanded(
            child: Text(
              justo
                  ? tx.pasaApurate(minutos(bus.minutos))
                  : tx.pasaEnCorto(minutos(bus.minutos), enVivo: bus.enVivo),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasoEsperar extends StatefulWidget {
  final FaseViaje f;
  final TramoEsperar t;
  const _PasoEsperar(this.f, this.t);

  @override
  State<_PasoEsperar> createState() => _PasoEsperarState();
}

class _PasoEsperarState extends State<_PasoEsperar> {
  /// La mayor distancia a la que vimos al bus en este paso: el 0 % de la pista.
  int? _metrosInicio;

  /// El bus en vivo estaba por llegar. Cuando llega a la parada deja de
  /// "venir" (la fuente ya no lo informa): no es "sin datos", es que llegó.
  bool _estabaLlegando = false;

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    final f = widget.f, t = widget.t;
    final bus = f.busEsperado;
    final metros = bus != null && bus.enVivo ? bus.metrosHastaParada : null;
    if (metros != null && metros > (_metrosInicio ?? 0)) {
      _metrosInicio = metros;
    }
    if (bus != null && bus.enVivo) {
      _estabaLlegando = bus.minutos <= 1 || (metros != null && metros <= 300);
    }
    final llego = bus == null && _estabaLlegando;
    final inicio = _metrosInicio;
    final Widget cifra;
    if (llego) {
      cifra = Row(
        key: const ValueKey('viaje-llego-bus'),
        children: [
          PuntoEnVivo(tam: 11, color: c.enVivo),
          const SizedBox(width: 6),
          Expanded(child: _Cifra(tx.llegoTuBus, color: c.enVivo)),
        ],
      );
    } else if (bus != null && bus.enVivo) {
      cifra = Row(
        children: [
          PuntoEnVivo(tam: 11, color: c.enVivo),
          const SizedBox(width: 6),
          Expanded(
            child: _Cifra(
              bus.minutos <= 0 ? tx.llegando : tx.llegaEn(minutos(bus.minutos)),
              chica: metros != null ? tx.aDistancia(distancia(metros)) : null,
              color: c.enVivo,
            ),
          ),
        ],
      );
    } else if (bus != null) {
      cifra = _Cifra(
        tx.enAprox(minutos(bus.minutos)),
        chica: tx.segunHorario,
        color: c.alerta,
      );
    } else {
      cifra = Text(
        tx.sinDatosBus,
        key: const ValueKey('viaje-sin-datos'),
        style: TextStyle(fontSize: 16, color: c.textoSuave),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Titulo(
          icono: InsigniaLinea(t.linea, grande: true),
          titulo: tx.espera(t.linea),
          detalle: [
            if (t.destinoLinea != null) tx.hacia(capitalizar(t.destinoLinea!)),
            tx.parada(nombreParada(t.parada.nombre)),
          ].join(' · '),
        ),
        const SizedBox(height: 12),
        cifra,
        if ((metros != null || llego) && inicio != null) ...[
          const SizedBox(height: 14),
          _PistaBus(metros: metros ?? 0, metrosInicio: inicio),
        ],
        if (llego) ...[
          const SizedBox(height: 12),
          Text(
            tx.hacelSeniaSubi,
            style: TextStyle(fontSize: 15, color: c.textoSuave),
          ),
        ] else if (bus != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              _Etiqueta(
                bus.enVivo ? tx.enVivoMayus : tx.horarioMayus,
                color: bus.enVivo ? c.enVivo : c.alerta,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bus.enVivo ? tx.hacelSenia : tx.puedeVariar,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: c.textoSuave),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;
  const _Etiqueta(this.texto, {required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      texto,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: color,
      ),
    ),
  );
}

/// El bus acercándose a tu parada: una pista con el bus que avanza.
class _PistaBus extends StatelessWidget {
  final int metros;
  final int metrosInicio;
  const _PistaBus({required this.metros, required this.metrosInicio});

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    final avance =
        metrosInicio <= 0 ? 1.0 : (1 - metros / metrosInicio).clamp(0.0, 1.0);
    const icono = 30.0, parada = 26.0;
    return Semantics(
      label: tx.busADistancia(distancia(metros)),
      excludeSemantics: true,
      child: SizedBox(
        key: const ValueKey('viaje-pista-bus'),
        height: icono,
        child: LayoutBuilder(
          builder: (context, box) {
            final recorrido = box.maxWidth - icono - parada;
            return TweenAnimationBuilder<double>(
              tween: Tween(end: avance),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOut,
              builder:
                  (context, v, _) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Pista: lo recorrido en verde, lo que falta en gris.
                      Positioned(
                        left: icono / 2,
                        right: parada / 2,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: c.separador,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Positioned(
                        left: icono / 2,
                        width: recorrido * v + 1,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: c.enVivo,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Tu parada, al final.
                      Positioned(
                        right: 0,
                        child: Container(
                          width: parada,
                          height: parada,
                          decoration: BoxDecoration(
                            color: c.laminaSolida,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.bus, width: 3),
                          ),
                          child: Icon(
                            Icons.north_rounded,
                            size: 14,
                            color: c.bus,
                          ),
                        ),
                      ),
                      Positioned(
                        left: recorrido * v,
                        child: Container(
                          width: icono,
                          height: icono,
                          decoration: BoxDecoration(
                            color: c.bus,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.enVivo, width: 2.5),
                          ),
                          child: const Icon(
                            Icons.directions_bus_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
            );
          },
        ),
      ),
    );
  }
}

class _PasoBus extends StatelessWidget {
  final FaseViaje f;
  final TramoBus t;
  const _PasoBus(this.f, this.t);

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    final faltan = f.progreso.paradasRestantes;
    final ultima = faltan == 0;
    final proxima = f.progreso.proximaParada;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Titulo(
          icono: InsigniaLinea(t.linea, grande: true),
          titulo: ultima ? tx.bajateEnLaProxima : tx.viajaEn(t.linea),
          detalle: tx.bajateEn(nombreParada(t.bajada.nombre)),
        ),
        const SizedBox(height: 12),
        if (ultima)
          Container(
            key: const ValueKey('viaje-bajate'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: c.bus,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tx.tocaElTimbre,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          _Cifra(
            faltan == null
                ? distancia(t.distanciaMetros)
                : tx.faltan(paradas(faltan + 1)),
            chica:
                f.progreso.metrosRestantes != null
                    ? distancia(f.progreso.metrosRestantes!)
                    : null,
          ),
          if (faltan != null) ...[
            const SizedBox(height: 10),
            _TiraParadas(
              total: t.paradasIntermedias.length + 1,
              faltan: faltan,
            ),
          ],
          if (proxima != null && proxima.id != t.bajada.id) ...[
            const SizedBox(height: 8),
            Row(
              key: const ValueKey('viaje-proxima'),
              children: [
                _Etiqueta(tx.proximaMayus, color: c.bus),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nombreParada(proxima.nombre),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: c.texto,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

/// Las paradas del tramo en bus como una línea de puntos: las que pasaron,
/// dónde vas, y la tuya al final.
class _TiraParadas extends StatelessWidget {
  final int total;
  final int faltan;
  const _TiraParadas({required this.total, required this.faltan});

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    return Semantics(
      label: tx.faltanParaBajarte(paradas(faltan + 1)),
      excludeSemantics: true,
      child: SizedBox(
        key: const ValueKey('viaje-tira-paradas'),
        height: 24,
        width: double.infinity,
        child: CustomPaint(
          painter: _PintorTiraParadas(
            total: total,
            hechas: (total - faltan - 1).clamp(0, total),
            bus: c.bus,
            hecho: c.textoTenue,
            fondo: c.laminaSolida,
            tinta: c.texto,
          ),
        ),
      ),
    );
  }
}

class _PintorTiraParadas extends CustomPainter {
  final int total, hechas;
  final Color bus, hecho, fondo, tinta;
  _PintorTiraParadas({
    required this.total,
    required this.hechas,
    required this.bus,
    required this.hecho,
    required this.fondo,
    required this.tinta,
  });

  @override
  void paint(Canvas c, Size s) {
    final y = s.height / 2;
    const margen = 10.0;
    final ancho = s.width - 2 * margen;
    // 0 = la subida, [total] = tu parada.
    double x(num i) => margen + ancho * i / math.max(1, total);
    final vos = x(hechas + 0.5);
    Paint trazo(Color color) =>
        Paint()
          ..color = color
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
    c.drawLine(
      Offset(margen, y),
      Offset(vos, y),
      trazo(hecho.withValues(alpha: 0.45)),
    );
    c.drawLine(Offset(vos, y), Offset(x(total), y), trazo(bus));
    // Paradas intermedias, raleadas si son muchas.
    final salto = total > 28 ? 2 : 1;
    for (var i = 1; i < total; i += salto) {
      final p = Offset(x(i), y);
      final pasada = i <= hechas;
      final siguiente = i == hechas + 1;
      final r = siguiente ? 5.5 : 3.2;
      c.drawCircle(p, r, Paint()..color = fondo);
      c.drawCircle(
        p,
        r,
        Paint()
          ..color = pasada ? hecho : bus
          ..style = PaintingStyle.stroke
          ..strokeWidth = siguiente ? 2.6 : 1.8,
      );
    }
    // Tu parada.
    final fin = Offset(x(total), y);
    c.drawCircle(fin, 9, Paint()..color = tinta);
    c.drawCircle(fin, 3.8, Paint()..color = fondo);
    // Vos, en el bus.
    c.drawCircle(Offset(vos, y), 7.5, Paint()..color = fondo);
    c.drawCircle(Offset(vos, y), 5, Paint()..color = bus);
  }

  @override
  bool shouldRepaint(_PintorTiraParadas o) =>
      o.total != total ||
      o.hechas != hechas ||
      o.bus != bus ||
      o.fondo != fondo;
}

// ---------------------------------------------------------------------------
// Barra inferior: terminar, itinerario y respaldo manual
// ---------------------------------------------------------------------------

class _BarraInferior extends ConsumerWidget {
  final FaseViaje f;
  final String destino;
  const _BarraInferior(this.f, this.destino);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ColoresBondi.of(context);
    final t = f.tramoActual;
    final esUltimo = f.pasoActual == f.totalPasos - 1;
    final texto = switch (t) {
      TramoCaminar() when esUltimo => tx.yaLlegue,
      TramoCaminar() => tx.yaEstoyEnLaParada,
      TramoEsperar() => tx.yaSubi,
      TramoBus() => tx.yaMeBaje,
    };
    return Row(
      children: [
        BotonLamina(
          key: const ValueKey('viaje-terminar'),
          icono: Icons.close_rounded,
          etiqueta: tx.terminarViaje,
          onTap: () => _confirmarTerminar(context, ref),
        ),
        const SizedBox(width: 10),
        BotonLamina(
          key: const ValueKey('viaje-itinerario'),
          icono: Icons.format_list_bulleted_rounded,
          etiqueta: tx.verTodoElViaje,
          onTap: () => mostrarItinerario(context, f, destino),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Presionable(
            child: Lamina(
              padding: EdgeInsets.zero,
              radio: BorderRadius.circular(26),
              elevado: false,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  key: const ValueKey('viaje-confirmar-paso'),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(appActionsProvider).confirmarPasoActual();
                  },
                  child: SizedBox(
                    height: 52,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            size: 20,
                            color: c.textoSuave,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              texto,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: c.texto,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmarTerminar(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(tx.terminarPregunta),
            content: Text(tx.terminarTexto),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tx.seguir),
              ),
              TextButton(
                key: const ValueKey('viaje-terminar-confirmar'),
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                  foregroundColor: ColoresBondi.of(ctx).peligro,
                ),
                child: Text(tx.terminar),
              ),
            ],
          ),
    );
    if (ok == true) ref.read(appActionsProvider).terminarViaje();
  }
}

// ---------------------------------------------------------------------------
// Llegada
// ---------------------------------------------------------------------------

class _Llegada extends ConsumerStatefulWidget {
  final FaseViaje f;
  final String destino;
  const _Llegada(this.f, this.destino);

  @override
  ConsumerState<_Llegada> createState() => _LlegadaState();
}

class _LlegadaState extends ConsumerState<_Llegada> {
  Timer? _cierre;

  @override
  void initState() {
    super.initState();
    _cierre = Timer(const Duration(seconds: 12), () {
      if (mounted) ref.read(appActionsProvider).cerrarLlegada();
    });
  }

  @override
  void dispose() {
    _cierre?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    final t = Theme.of(context).textTheme;
    final f = widget.f;
    final segundos = f.fin?.difference(f.inicio).inSeconds;
    final check = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: c.enVivo.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.check_rounded, color: c.enVivo, size: 42),
    );
    return Lamina(
      key: const ValueKey('viaje-llegada'),
      radio: BorderRadius.circular(28),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child:
                MediaQuery.disableAnimationsOf(context)
                    ? check
                    : TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 750),
                      curve: Curves.elasticOut,
                      builder:
                          (_, v, child) =>
                              Transform.scale(scale: v, child: child),
                      child: check,
                    ),
          ),
          const SizedBox(height: 16),
          Text(
            tx.llegaste,
            textAlign: TextAlign.center,
            style: t.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            widget.destino,
            key: const ValueKey('viaje-llegada-destino'),
            textAlign: TextAlign.center,
            style: t.titleMedium,
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (segundos != null)
                _Dato(Icons.schedule_rounded, duracion(segundos)),
              if (f.opcion.caminataMetros > 0)
                _Dato(
                  Icons.directions_walk_rounded,
                  distancia(f.opcion.caminataMetros),
                ),
              for (final l in f.opcion.lineas) InsigniaLinea(l),
            ],
          ),
          const SizedBox(height: 22),
          FilledButton(
            key: const ValueKey('viaje-listo'),
            onPressed: () => ref.read(appActionsProvider).cerrarLlegada(),
            child: Text(tx.listo),
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _Dato(this.icono, this.texto);

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    return Capa(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      radio: BorderRadius.circular(10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: c.textoSuave),
          const SizedBox(width: 5),
          Text(
            texto,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.texto,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
