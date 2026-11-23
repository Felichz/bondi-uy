// Piezas del modo demo: la tarjeta para elegir un viaje con un toque y el
// control de velocidad del mundo simulado.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contract/app_state.dart';
import '../../contract/proveedores.dart';
import '../tema/lamina.dart';
import '../tema/tema.dart';
import '../textos/textos.dart';

/// Alto de la tarjeta de la demo en el inicio (px lógicos).
final altoTarjetaDemoProvider = StateProvider<double>((_) => 0);

/// "Probá un viaje": los destinos grabados, a un toque.
class TarjetaDemo extends ConsumerWidget {
  final Demo demo;
  const TarjetaDemo(this.demo, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ColoresBondi.of(context);
    final t = Theme.of(context).textTheme;
    return Lamina(
      key: const ValueKey('demo-tarjeta'),
      radio: BorderRadius.circular(28),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: c.caminar.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'DEMO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: c.caminar,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(tx.probaUnViaje, style: t.titleMedium)),
            ],
          ),
          const SizedBox(height: 6),
          Text(tx.demoExplicacion, style: t.bodyMedium?.copyWith(fontSize: 14)),
          const SizedBox(height: 12),
          // Una fila que se desliza: la tarjeta no tapa el mapa.
          SizedBox(
            height: 42,
            child: ListView.separated(
              key: const ValueKey('demo-destinos'),
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: demo.destinos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final d = demo.destinos[i];
                return _Destino(
                  d,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    final a = ref.read(appActionsProvider);
                    a.elegirLugar(CampoBusqueda.destino, d);
                    a.buscarViajes();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Destino extends StatelessWidget {
  final Lugar lugar;
  final VoidCallback onTap;
  const _Destino(this.lugar, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    return Presionable(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey('demo-destino-${lugar.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(10, 9, 14, 9),
            decoration: BoxDecoration(
              color: c.capa,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.capaBorde),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.place_rounded, size: 17, color: c.bus),
                const SizedBox(width: 6),
                Text(
                  lugar.nombre,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: c.texto,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

