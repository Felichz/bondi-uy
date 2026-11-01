// Piezas chicas reutilizables: insignia de línea, punto en vivo.

import 'package:flutter/material.dart';

import 'tema.dart';
import '../textos/textos.dart';

/// Insignia de línea de bus: la misma forma que el badge del mapa.
class InsigniaLinea extends StatelessWidget {
  final String linea;
  final bool grande;
  const InsigniaLinea(this.linea, {super.key, this.grande = false});

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    final tam = grande ? 20.0 : 15.0;
    return Semantics(
      label: tx.linea(linea),
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: grande ? 10 : 7,
          vertical: grande ? 7 : 4,
        ),
        decoration: BoxDecoration(
          color: c.bus,
          borderRadius: BorderRadius.circular(grande ? 12 : 8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_bus_rounded,
              size: tam + 2,
              color: Colors.white,
            ),
            SizedBox(width: grande ? 5 : 3),
            Text(
              linea,
              style: TextStyle(
                color: Colors.white,
                fontSize: tam,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Punto que late: indica dato en tiempo real.
class PuntoEnVivo extends StatefulWidget {
  final Color? color;
  final double tam;
  const PuntoEnVivo({super.key, this.color, this.tam = 9});

  @override
  State<PuntoEnVivo> createState() => _PuntoEnVivoState();
}

class _PuntoEnVivoState extends State<PuntoEnVivo>
    with SingleTickerProviderStateMixin {
  // Se crea en initState: si las animaciones están desactivadas, build no lo
  // toca y dispose no debe crearlo tarde (ver test "sin animaciones").
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? ColoresBondi.of(context).enVivo;
    final punto = Container(
      width: widget.tam,
      height: widget.tam,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    if (MediaQuery.disableAnimationsOf(context)) return punto;
    return SizedBox(
      width: widget.tam * 2.2,
      height: widget.tam * 2.2,
      child: AnimatedBuilder(
        animation: _c,
        builder:
            (_, child) => Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: widget.tam * (1 + 1.2 * _c.value),
                  height: widget.tam * (1 + 1.2 * _c.value),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.35 * (1 - _c.value)),
                    shape: BoxShape.circle,
                  ),
                ),
                child!,
              ],
            ),
        child: punto,
      ),
    );
  }
}
