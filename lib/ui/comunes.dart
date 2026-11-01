// Piezas de UI compartidas entre fases.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contract/app_state.dart';
import 'estado_ui.dart';
import 'tema/tema.dart';
import 'tema/lamina.dart';
import 'textos/textos.dart';

/// Botón flotante para volver a encuadrar cuando el usuario movió el mapa.
class BotonRecentrar extends ConsumerWidget {
  const BotonRecentrar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctl = ref.watch(controladorMapaProvider);
    final c = ColoresBondi.of(context);
    return ListenableBuilder(
      listenable: ctl,
      builder:
          (context, _) => AnimatedScale(
            scale: ctl.libre ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: BotonLamina(
              key: const ValueKey('boton-recentrar'),
              icono: Icons.my_location_rounded,
              etiqueta: tx.recentrarMapa,
              color: c.caminar,
              onTap: ctl.recentrar,
            ),
          ),
    );
  }
}

/// Nombre visible de un punto de búsqueda.
String nombrePunto(PuntoBusqueda? p, {String? vacio}) => switch (p) {
  MiUbicacion() => tx.miUbicacion,
  LugarElegido(:final lugar) => lugar.nombre,
  null => vacio ?? tx.elegiUnLugar,
};

/// Asa de las hojas inferiores.
class Asa extends StatelessWidget {
  const Asa({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      decoration: BoxDecoration(
        color: ColoresBondi.of(context).textoTenue.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

/// Informa el tamaño de su hijo cada vez que cambia (después del cuadro).
class Medido extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> alCambiar;
  const Medido({super.key, required this.alCambiar, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMedido(alCambiar);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderMedido).alCambiar = alCambiar;
}

class _RenderMedido extends RenderProxyBox {
  ValueChanged<Size> alCambiar;
  Size? _antes;
  _RenderMedido(this.alCambiar);

  @override
  void performLayout() {
    super.performLayout();
    if (size == _antes) return;
    _antes = size;
    final t = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => alCambiar(t));
  }
}

const _minusculas = {
  'a',
  'al',
  'de',
  'del',
  'el',
  'en',
  'la',
  'las',
  'los',
  'por',
  'y',
};

/// Pasa "PLAZA INDEPENDENCIA" a "Plaza Independencia". Las siglas cortas
/// ("UAM", "CUTCSA") quedan en mayúsculas; los conectores, en minúscula.
String capitalizar(String s) {
  final palabras = s.split(' ');
  return [
    for (var i = 0; i < palabras.length; i++)
      () {
        final p = palabras[i];
        if (p.isEmpty) return p;
        final baja = p.toLowerCase();
        if (i > 0 && _minusculas.contains(baja)) return baja;
        final sigla =
            p == p.toUpperCase() &&
            p.length <= 3 &&
            !_minusculas.contains(baja) &&
            RegExp(r'^[A-ZÁÉÍÓÚÑ]+$').hasMatch(p) &&
            !_abreviaturas.contains(baja);
        if (sigla && palabras.length > 1) return p;
        return baja[0].toUpperCase() + baja.substring(1);
      }(),
  ].join(' ');
}

/// Abreviaturas de calles que no son siglas ("AV", "BV").
const _abreviaturas = {'av', 'bv', 'dr', 'gral', 'pte', 'cno', 'ing', 'sta'};
