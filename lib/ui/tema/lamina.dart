// Material de las superficies: láminas opacas con un degradé sutil.
//
// Nada de transparencia: el texto se lee con el contraste de una hoja de
// papel sobre cualquier parte del mapa. La profundidad la dan un degradé
// apenas perceptible (más luminoso arriba), un filo que brilla arriba y se
// asienta abajo, y una sombra larga y limpia que no deja franja gris.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tema.dart';

/// Láminas planas, sin degradé ni filo (alto contraste, tests de píxel).
final laminaSolidaProvider = Provider<bool>((_) => false);

class Lamina extends ConsumerWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius radio;

  /// Sombra más marcada para paneles flotantes principales.
  final bool elevado;

  /// Sin sombra (pantallas completas).
  final bool conSombra;

  const Lamina({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radio = const BorderRadius.all(Radius.circular(24)),
    this.elevado = true,
    this.conSombra = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ColoresBondi.of(context);
    final plana =
        ref.watch(laminaSolidaProvider) || MediaQuery.highContrastOf(context);
    final contenido = ClipRRect(
      borderRadius: radio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: plana ? c.laminaSolida : null,
          gradient:
              plana
                  ? null
                  : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c.laminaArriba, c.laminaAbajo],
                  ),
        ),
        child: CustomPaint(
          foregroundPainter:
              plana
                  ? null
                  : _Filo(radio: radio, luz: c.bordeLuz, sombra: c.bordeSombra),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    if (!conSombra) return contenido;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radio,
        boxShadow: [
          // Larga y difusa, recogida hacia adentro: flota sin ensuciar.
          BoxShadow(
            color: c.sombra,
            blurRadius: elevado ? 48 : 24,
            offset: Offset(0, elevado ? 20 : 8),
            spreadRadius: elevado ? -18 : -10,
          ),
          // De contacto: define el borde contra el mapa.
          BoxShadow(
            color: c.sombraCerca,
            blurRadius: elevado ? 8 : 4,
            offset: const Offset(0, 2),
            spreadRadius: -2,
          ),
        ],
      ),
      child: contenido,
    );
  }
}

class _Filo extends CustomPainter {
  final BorderRadius radio;
  final Color luz;
  final Color sombra;
  const _Filo({required this.radio, required this.luz, required this.sombra});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      radio.toRRect(rect).deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [luz, sombra],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_Filo o) =>
      o.radio != radio || o.luz != luz || o.sombra != sombra;
}

/// Capa sobre la lámina (filas, fichas internas).
class Capa extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius radio;
  final Color? color;
  const Capa({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radio = const BorderRadius.all(Radius.circular(16)),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.capa,
        borderRadius: radio,
        border: Border.all(color: c.capaBorde, width: 1),
      ),
      child: child,
    );
  }
}

/// Se hunde apenas al tocarlo (respuesta física, antes de que pase nada).
class Presionable extends StatefulWidget {
  final Widget child;
  const Presionable({super.key, required this.child});

  @override
  State<Presionable> createState() => _PresionableState();
}

class _PresionableState extends State<Presionable> {
  bool _abajo = false;

  void _poner(bool v) {
    if (_abajo != v) setState(() => _abajo = v);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _poner(true),
    onPointerUp: (_) => _poner(false),
    onPointerCancel: (_) => _poner(false),
    child: AnimatedScale(
      scale: _abajo ? 0.94 : 1,
      duration: Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 140,
      ),
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}

/// Botón redondo (recentrar, tema, cerrar, itinerario).
class BotonLamina extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final VoidCallback onTap;
  final Color? color;

  const BotonLamina({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    return Presionable(
      child: Lamina(
        padding: EdgeInsets.zero,
        radio: BorderRadius.circular(28),
        elevado: false,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 52,
              height: 52,
              child: Icon(
                icono,
                color: color ?? c.texto,
                semanticLabel: etiqueta,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
