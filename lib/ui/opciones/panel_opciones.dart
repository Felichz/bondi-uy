// Fase opciones: la recomendada al frente; las demás, a un deslizamiento.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contract/app_state.dart';
import '../../contract/proveedores.dart';
import '../comunes.dart';
import '../estado_ui.dart';
import '../formatos.dart';
import '../tema/insignias.dart';
import '../tema/tema.dart';
import '../tema/lamina.dart';
import '../textos/textos.dart';

class PanelOpciones extends ConsumerWidget {
  const PanelOpciones({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(appStateProvider);
    final fase = estado.fase;
    if (fase is! FaseOpciones) return const SizedBox.shrink();
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            left: 12,
            right: 12,
            top: 8,
            child: _Encabezado(estado.busqueda),
          ),
          Positioned(
            right: 16,
            bottom: ref.watch(altoHojaOpcionesProvider) + 20,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BotonRecentrar(),
              ],
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Medido(
              alCambiar:
                  (t) =>
                      ref.read(altoHojaOpcionesProvider.notifier).state =
                          t.height,
              child: _Hoja(fase),
            ),
          ),
        ],
      ),
    );
  }
}

class _Encabezado extends ConsumerWidget {
  final Busqueda busqueda;
  const _Encabezado(this.busqueda);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ColoresBondi.of(context);
    final t = Theme.of(context).textTheme;
    return Lamina(
      key: const ValueKey('opciones-encabezado'),
      padding: const EdgeInsets.fromLTRB(4, 6, 14, 6),
      radio: BorderRadius.circular(26),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('opciones-cerrar'),
            tooltip: tx.volver,
            onPressed: () {
              ref.read(opcionEnfocadaProvider.notifier).state = null;
              ref.read(appActionsProvider).cerrarOpciones();
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: InkWell(
              key: const ValueKey('opciones-editar'),
              borderRadius: BorderRadius.circular(12),
              onTap:
                  () =>
                      ref.read(busquedaAbiertaProvider.notifier).state =
                          CampoBusqueda.destino,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.desde(nombrePunto(busqueda.origen)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyMedium?.copyWith(fontSize: 14),
                    ),
                    Text(
                      nombrePunto(busqueda.destino),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium?.copyWith(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Icon(Icons.edit_rounded, size: 20, color: c.textoTenue),
        ],
      ),
    );
  }
}

class _Hoja extends StatelessWidget {
  final FaseOpciones fase;
  const _Hoja(this.fase);

  @override
  Widget build(BuildContext context) {
    return Lamina(
      key: const ValueKey('opciones-hoja'),
      padding: EdgeInsets.zero,
      radio: BorderRadius.circular(30),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: switch (fase.estado) {
          EstadoOpciones.cargando => const _Cargando(),
          EstadoOpciones.error => _SinOpciones(
            icono: Icons.cloud_off_rounded,
            titulo: tx.errorPlanTitulo,
            texto: tx.errorPlanTexto,
            reintentar: true,
          ),
          EstadoOpciones.sinResultados => _SinOpciones(
            icono: Icons.directions_bus_outlined,
            titulo: tx.sinViajesTitulo,
            texto: tx.sinViajesTexto,
            reintentar: false,
          ),
          EstadoOpciones.listo => _Carrusel(fase),
        },
      ),
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      key: const ValueKey('opciones-cargando'),
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const SizedBox(
              width: 120,
              child: LinearProgressIndicator(minHeight: 4),
            ),
          ),
          const SizedBox(height: 20),
          Text(tx.buscandoViaje, style: t.titleLarge),
        ],
      ),
    );
  }
}

class _SinOpciones extends ConsumerWidget {
  final IconData icono;
  final String titulo;
  final String texto;
  final bool reintentar;
  const _SinOpciones({
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.reintentar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ColoresBondi.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      key: const ValueKey('opciones-vacio'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 38, color: c.textoTenue),
          const SizedBox(height: 12),
          Text(titulo, style: t.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(texto, style: t.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              if (reintentar) {
                ref.read(appActionsProvider).buscarViajes();
              } else {
                ref.read(busquedaAbiertaProvider.notifier).state =
                    CampoBusqueda.destino;
              }
            },
            child: Text(reintentar ? tx.reintentar : tx.cambiarDestino),
          ),
        ],
      ),
    );
  }
}

class _Carrusel extends ConsumerStatefulWidget {
  final FaseOpciones fase;
  const _Carrusel(this.fase);

  @override
  ConsumerState<_Carrusel> createState() => _CarruselState();
}

class _CarruselState extends ConsumerState<_Carrusel> {
  late final PageController _pagina;
  int _indice = 0;

  @override
  void initState() {
    super.initState();
    final ops = widget.fase.opciones;
    final previa = ref.read(opcionEnfocadaProvider);
    var i = ops.indexWhere((o) => o.id == previa);
    if (i < 0) i = ops.indexWhere((o) => o.recomendada);
    _indice = i < 0 ? 0 : i;
    _pagina = PageController(initialPage: _indice);
    WidgetsBinding.instance.addPostFrameCallback((_) => _enfocar(_indice));
  }

  void _enfocar(int i) {
    final ops = widget.fase.opciones;
    if (i >= ops.length) return;
    if (i != _indice) HapticFeedback.selectionClick();
    setState(() => _indice = i);
    ref.read(opcionEnfocadaProvider.notifier).state = ops[i].id;
    ref.read(appActionsProvider).enfocarOpcion(ops[i].id);
  }

  void _ir(int i) => _pagina.animateToPage(
    i,
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _pagina.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ops = widget.fase.opciones;
    final actual = ops[_indice.clamp(0, ops.length - 1)];
    // El alto de la tarjeta crece con la letra del sistema (accesibilidad).
    final escala = MediaQuery.textScalerOf(context).scale(1);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Asa(),
        SizedBox(
          height: 172 * escala.clamp(1.0, 1.6),
          child: PageView.builder(
            key: const ValueKey('opciones-carrusel'),
            controller: _pagina,
            itemCount: ops.length,
            onPageChanged: _enfocar,
            itemBuilder: (context, i) => _TarjetaOpcion(ops[i]),
          ),
        ),
        _Paginador(
          total: ops.length,
          actual: _indice,
          alAnterior: _indice > 0 ? () => _ir(_indice - 1) : null,
          alSiguiente: _indice < ops.length - 1 ? () => _ir(_indice + 1) : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: ColoresBondi.of(context).sombra,
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                  spreadRadius: -6,
                ),
              ],
            ),
            child: FilledButton.icon(
              key: const ValueKey('empezar-viaje'),
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(appActionsProvider).iniciarViaje(actual.id);
              },
              icon: const Icon(Icons.navigation_rounded),
              label: Text(tx.empezarViaje),
            ),
          ),
        ),
      ],
    );
  }
}

/// "‹ 1 de 6 ›": dónde estás en el carrusel, con flechas para quien no
/// descubre el deslizamiento.
class _Paginador extends StatelessWidget {
  final int total;
  final int actual;
  final VoidCallback? alAnterior;
  final VoidCallback? alSiguiente;
  const _Paginador({
    required this.total,
    required this.actual,
    this.alAnterior,
    this.alSiguiente,
  });

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    if (total <= 1) return const SizedBox(height: 8);
    Widget flecha(IconData i, VoidCallback? f, String etiqueta) => IconButton(
      onPressed: f,
      tooltip: etiqueta,
      visualDensity: VisualDensity.compact,
      icon: Icon(i, size: 22),
      color: c.texto,
      disabledColor: c.textoTenue.withValues(alpha: 0.35),
    );
    return Semantics(
      label: tx.opcionNdeM(actual + 1, total),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          flecha(Icons.chevron_left_rounded, alAnterior, tx.opcionAnterior),
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == actual ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color:
                    i == actual
                        ? c.texto
                        : c.textoTenue.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          flecha(Icons.chevron_right_rounded, alSiguiente, tx.opcionSiguiente),
        ],
      ),
    );
  }
}

class _TarjetaOpcion extends StatelessWidget {
  final OpcionViaje opcion;
  const _TarjetaOpcion(this.opcion);

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    final t = Theme.of(context).textTheme;
    final subida = opcion.primerBus?.subida;
    return Padding(
      key: ValueKey('opcion-${opcion.id}'),
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                duracion(opcion.duracionSegundos),
                key: ValueKey('opcion-${opcion.id}-duracion'),
                style: t.headlineMedium,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${hora(opcion.salida)} – ${hora(opcion.llegada)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (opcion.recomendada) const _SelloRecomendado(),
            ],
          ),
          const SizedBox(height: 12),
          _BarraTramos(opcion),
          const SizedBox(height: 14),
          _ProximoBus(opcion),
          const SizedBox(height: 3),
          Text(
            [
              if (subida != null) tx.subisEn(nombreParada(subida.nombre)),
              tx.caminas(distancia(opcion.caminataMetros)),
              if (opcion.transbordos > 0) tx.trasbordos(opcion.transbordos),
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.bodyMedium?.copyWith(fontSize: 14, color: c.textoSuave),
          ),
        ],
      ),
    );
  }
}

class _SelloRecomendado extends StatelessWidget {
  const _SelloRecomendado();

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    return Container(
      key: const ValueKey('sello-recomendado'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.enVivo.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 13, color: c.enVivo),
          const SizedBox(width: 4),
          Text(
            tx.recomendado,
            style: TextStyle(
              color: c.enVivo,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// El viaje como una barra: cada tramo ocupa lo que dura. Caminatas en
/// gris con su ícono, buses en rojo con la línea. La espera es el hueco
/// entre la caminata y el bus.
class _BarraTramos extends StatelessWidget {
  final OpcionViaje opcion;
  const _BarraTramos(this.opcion);

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    final tramos = [
      for (final t in opcion.tramos)
        if (t is! TramoEsperar) t,
    ];
    return Semantics(
      label: tx.barraTramos(opcion.lineas),
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, box) {
          const hueco = 4.0, minCaminar = 30.0, minBus = 62.0;
          final libre = box.maxWidth - hueco * (tramos.length - 1);
          double peso(Tramo t) => switch (t) {
            TramoCaminar(:final duracionSegundos) => duracionSegundos * 1.0,
            TramoBus(:final duracionSegundos) => duracionSegundos * 1.0,
            TramoEsperar() => 0,
          };
          double minimo(Tramo t) => t is TramoBus ? minBus : minCaminar;
          // Proporcional a la duración, sin que ningún tramo quede ilegible.
          final total = tramos.fold(0.0, (a, t) => a + peso(t));
          final anchos = [
            for (final t in tramos)
              math.max(minimo(t), libre * peso(t) / math.max(1, total)),
          ];
          final sobra = anchos.fold(0.0, (a, w) => a + w) - libre;
          if (sobra > 0) {
            final flexibles = [
              for (var i = 0; i < tramos.length; i++)
                if (anchos[i] > minimo(tramos[i])) i,
            ];
            final margen = flexibles.fold(
              0.0,
              (a, i) => a + anchos[i] - minimo(tramos[i]),
            );
            for (final i in flexibles) {
              final w = anchos[i] - minimo(tramos[i]);
              anchos[i] -= margen <= 0 ? 0 : sobra * w / margen;
            }
          }
          return Row(
            children: [
              for (var i = 0; i < tramos.length; i++) ...[
                if (i > 0) const SizedBox(width: hueco),
                SizedBox(
                  width: math.max(minimo(tramos[i]), anchos[i]),
                  height: 28,
                  child: switch (tramos[i]) {
                    final TramoBus b => _SegmentoBus(b.linea),
                    final TramoCaminar w => _SegmentoCaminar(
                      minutos: (w.duracionSegundos / 60).round(),
                      color: c,
                    ),
                    TramoEsperar() => const SizedBox.shrink(),
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SegmentoBus extends StatelessWidget {
  final String linea;
  const _SegmentoBus(this.linea);

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: c.bus,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.directions_bus_rounded,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              linea,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentoCaminar extends StatelessWidget {
  final int minutos;
  final ColoresBondi color;
  const _SegmentoCaminar({required this.minutos, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = color;
    return LayoutBuilder(
      builder:
          (context, box) => Container(
            decoration: BoxDecoration(
              color: c.capa,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: c.capaBorde),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.directions_walk_rounded,
                  size: 16,
                  color: c.textoSuave,
                ),
                if (box.maxWidth >= 54)
                  Text(
                    '$minutos',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.textoSuave,
                    ),
                  ),
              ],
            ),
          ),
    );
  }
}

class _ProximoBus extends StatelessWidget {
  final OpcionViaje opcion;
  const _ProximoBus(this.opcion);

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    final primero = opcion.primerBus;
    if (primero == null) {
      return _Linea(
        icono: Icons.directions_walk_rounded,
        texto: tx.todoAPie,
        color: c.textoSuave,
      );
    }
    final llegada = opcion.proximoBus;
    if (opcion.aviso == AvisoOpcion.primerBusPuedeNoAlcanzar &&
        llegada != null) {
      return _Linea(
        icono: Icons.warning_amber_rounded,
        texto: tx.pasaQuizasNoLlegues(primero.linea, minutos(llegada.minutos)),
        color: c.alerta,
      );
    }
    if (llegada != null && llegada.enVivo) {
      return Row(
        key: ValueKey('opcion-${opcion.id}-en-vivo'),
        children: [
          PuntoEnVivo(color: c.enVivo, tam: 8),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              tx.pasaEn(primero.linea, minutos(llegada.minutos)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.enVivo,
              ),
            ),
          ),
        ],
      );
    }
    if (llegada != null) {
      return _Linea(
        icono: Icons.schedule_rounded,
        texto: tx.pasariaEn(primero.linea, minutos(llegada.minutos)),
        color: c.alerta,
      );
    }
    return _Linea(
      icono: Icons.schedule_rounded,
      texto: tx.saleSinDatos(hora(opcion.salida)),
      color: c.textoSuave,
    );
  }
}

class _Linea extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color color;
  const _Linea({required this.icono, required this.texto, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icono, size: 18, color: color),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          texto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    ],
  );
}
