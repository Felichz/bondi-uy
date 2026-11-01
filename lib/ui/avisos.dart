// Traduce los avisos de la lógica a mensajes para el usuario.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contract/app_state.dart';
import '../contract/proveedores.dart';
import 'tema/tema.dart';
import 'textos/textos.dart';

({String texto, IconData icono, bool importante}) textoAviso(TipoAviso t) =>
    switch (t) {
      TipoAviso.sinUbicacion => (
        texto: tx.avisoSinUbicacion,
        icono: Icons.location_off,
        importante: false,
      ),
      TipoAviso.sinConexion => (
        texto: tx.avisoSinConexion,
        icono: Icons.wifi_off,
        importante: false,
      ),
      TipoAviso.errorPlanificacion => (
        texto: tx.avisoErrorPlanificacion,
        icono: Icons.error_outline,
        importante: false,
      ),
      TipoAviso.errorSugerencias => (
        texto: tx.avisoErrorSugerencias,
        icono: Icons.search_off,
        importante: false,
      ),
      TipoAviso.errorParada => (
        texto: tx.avisoErrorParada,
        icono: Icons.error_outline,
        importante: false,
      ),
      TipoAviso.faltaDestino => (
        texto: tx.avisoFaltaDestino,
        icono: Icons.flag,
        importante: false,
      ),
      TipoAviso.bajateEnLaProxima => (
        texto: tx.avisoBajate,
        icono: Icons.notifications_active,
        importante: true,
      ),
      TipoAviso.busLlegando => (
        texto: tx.avisoBusLlegando,
        icono: Icons.directions_bus,
        importante: true,
      ),
    };

class OyenteAvisos extends ConsumerWidget {
  const OyenteAvisos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<Aviso?>(appStateProvider.select((s) => s.aviso), (antes, aviso) {
      if (aviso == null || aviso.id == antes?.id) return;
      final a = textoAviso(aviso.tipo);
      if (a.importante) HapticFeedback.heavyImpact();
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          key: ValueKey('aviso-${aviso.tipo.name}'),
          backgroundColor: a.importante ? ColoresBondi.of(context).bus : null,
          duration: Duration(seconds: a.importante ? 8 : 4),
          content: Row(
            children: [
              Icon(a.icono, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  a.texto,
                  style: TextStyle(
                    fontSize: a.importante ? 18 : 16,
                    fontWeight:
                        a.importante ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      ref.read(appActionsProvider).descartarAviso(aviso.id);
    });
    return const SizedBox.shrink();
  }
}
