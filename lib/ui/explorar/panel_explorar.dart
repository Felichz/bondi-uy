// Fase explorar: buscador arriba, parada tocada abajo.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contract/app_state.dart';
import '../../contract/proveedores.dart';
import '../comunes.dart';
import '../demo/demo.dart';
import '../estado_ui.dart';
import '../formatos.dart';
import '../tema/insignias.dart';
import '../tema/preferencia_tema.dart';
import '../tema/tema.dart';
import '../tema/lamina.dart';
import '../textos/preferencia_idioma.dart';
import '../textos/textos.dart';

class PanelExplorar extends ConsumerWidget {
  const PanelExplorar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(appStateProvider);
    final parada = estado.paradaConsultada;
    final demo = estado.demo;
    final altoHoja = MediaQuery.sizeOf(context).height * 0.45;
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            left: 12,
            right: 12,
            top: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TarjetaBuscar(busqueda: estado.busqueda),
                if (!estado.ubicacion.disponible &&
                    estado.ubicacion.estado != EstadoUbicacion.buscando) ...[
                  const SizedBox(height: 10),
                  _AvisoUbicacion(estado.ubicacion.estado),
                ],
              ],
            ),
          ),
          if (demo != null && parada == null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Medido(
                alCambiar:
                    (t) =>
                        ref.read(altoTarjetaDemoProvider.notifier).state =
                            t.height,
                child: TarjetaDemo(demo),
              ),
            ),
          Positioned(
            right: 16,
            bottom:
                parada != null
                    ? altoHoja + 12
                    : demo != null
                    ? ref.watch(altoTarjetaDemoProvider) + 24
                    : 24,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BotonRecentrar(),
                SizedBox(height: 12),
                _BotonIdioma(),
                SizedBox(height: 12),
                _BotonTema(),
              ],
            ),
          ),
          if (parada != null)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              height: altoHoja - 8,
              child: _HojaParada(
                parada,
                key: ValueKey('parada-${parada.parada.id}'),
              ),
            ),
        ],
      ),
    );
  }
}

/// "EN" / "ES": muestra el idioma al que se pasa.
class _BotonIdioma extends ConsumerWidget {
  const _BotonIdioma();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ColoresBondi.of(context);
    final idioma = ref.watch(idiomaProvider);
    return Semantics(
      button: true,
      label: tx.idiomaEtiqueta,
      excludeSemantics: true,
      child: Presionable(
        child: Lamina(
          padding: EdgeInsets.zero,
          radio: BorderRadius.circular(28),
          elevado: false,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: const ValueKey('boton-idioma'),
              customBorder: const CircleBorder(),
              onTap: () => ref.read(idiomaProvider.notifier).alternar(),
              child: SizedBox(
                width: 52,
                height: 52,
                child: Center(
                  child: Text(
                    idioma == Idioma.es ? 'EN' : 'ES',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: c.texto,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BotonTema extends ConsumerWidget {
  const _BotonTema();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modo = ref.watch(preferenciaTemaProvider);
    final (icono, nombre) = switch (modo) {
      ThemeMode.system => (Icons.brightness_auto_rounded, tx.temaAutomatico),
      ThemeMode.light => (Icons.light_mode_rounded, tx.temaClaro),
      ThemeMode.dark => (Icons.dark_mode_rounded, tx.temaOscuro),
    };
    return BotonLamina(
      key: const ValueKey('boton-tema'),
      icono: icono,
      etiqueta: tx.temaEtiqueta(nombre),
      onTap: () {
        ref.read(preferenciaTemaProvider.notifier).siguiente();
        final nuevo = switch (ref.read(preferenciaTemaProvider)) {
          ThemeMode.system => tx.temaAvisoAutomatico,
          ThemeMode.light => tx.temaAvisoClaro,
          ThemeMode.dark => tx.temaAvisoOscuro,
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(nuevo),
              duration: const Duration(seconds: 2),
            ),
          );
      },
    );
  }
}

class _TarjetaBuscar extends ConsumerWidget {
  final Busqueda busqueda;
  const _TarjetaBuscar({required this.busqueda});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ColoresBondi.of(context);
    final t = Theme.of(context).textTheme;
    final destino = busqueda.destino;
    void abrir(CampoBusqueda campo) =>
        ref.read(busquedaAbiertaProvider.notifier).state = campo;
    if (destino == null) {
      return Lamina(
        padding: EdgeInsets.zero,
        radio: BorderRadius.circular(30),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const ValueKey('buscar-destino'),
            onTap: () => abrir(CampoBusqueda.destino),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 26, color: c.texto),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      tx.aDondeVas,
                      style: t.titleLarge?.copyWith(
                        color: c.textoSuave,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Lamina(
      key: const ValueKey('buscar-completo'),
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
      radio: BorderRadius.circular(26),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => abrir(CampoBusqueda.destino),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.desde(nombrePunto(busqueda.origen)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    nombrePunto(destino),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            key: const ValueKey('ver-viajes'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            onPressed: () => ref.read(appActionsProvider).buscarViajes(),
            child: Text(tx.verViajes),
          ),
        ],
      ),
    );
  }
}

class _AvisoUbicacion extends ConsumerWidget {
  final EstadoUbicacion estado;
  const _AvisoUbicacion(this.estado);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ColoresBondi.of(context);
    final texto = switch (estado) {
      EstadoUbicacion.desactivada => tx.ubicacionApagada,
      EstadoUbicacion.sinPermiso => tx.ubicacionSinPermiso,
      _ => tx.ubicacionNoEncontrada,
    };
    return Lamina(
      key: const ValueKey('aviso-ubicacion'),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      radio: BorderRadius.circular(20),
      elevado: false,
      child: Row(
        children: [
          Icon(Icons.location_off_rounded, color: c.alerta),
          const SizedBox(width: 12),
          Expanded(
            child: Text(texto, style: TextStyle(fontSize: 15, color: c.texto)),
          ),
          TextButton(
            onPressed: () => ref.read(appActionsProvider).reintentarUbicacion(),
            child: Text(tx.activar),
          ),
        ],
      ),
    );
  }
}

class _HojaParada extends ConsumerWidget {
  final ConsultaParada consulta;
  const _HojaParada(this.consulta, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ColoresBondi.of(context);
    final t = Theme.of(context).textTheme;
    return Lamina(
      padding: EdgeInsets.zero,
      radio: BorderRadius.circular(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Asa(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.capa,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.capaBorde),
                  ),
                  child: Icon(Icons.hail_rounded, color: c.texto),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombreParada(consulta.parada.nombre),
                        key: const ValueKey('parada-nombre'),
                        style: t.titleLarge,
                      ),
                      Text(
                        tx.paradaNumero(consulta.parada.id),
                        style: t.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('parada-cerrar'),
                  tooltip: tx.cerrar,
                  onPressed: () => ref.read(appActionsProvider).cerrarParada(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(child: _llegadas(context)),
        ],
      ),
    );
  }

  Widget _llegadas(BuildContext context) {
    final c = ColoresBondi.of(context);
    switch (consulta.estado) {
      case EstadoConsulta.cargando:
        return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
      case EstadoConsulta.error:
        return _Vacio(
          icono: Icons.cloud_off_rounded,
          texto: tx.paradaErrorLlegadas,
        );
      case EstadoConsulta.listo:
        if (consulta.llegadas.isEmpty) {
          return _Vacio(
            icono: Icons.schedule_rounded,
            texto:
                consulta.lineas.isEmpty
                    ? tx.paradaSinInfo
                    : tx.paradaSinProximos(consulta.lineas.join(', ')),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          itemCount: consulta.llegadas.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, i) {
            final l = consulta.llegadas[i];
            return Row(
              key: ValueKey('llegada-$i'),
              children: [
                SizedBox(
                  width: 78,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InsigniaLinea(l.linea),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    capitalizar(l.destino ?? ''),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, color: c.texto),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      minutos(l.minutos),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: c.texto,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (l.enVivo) PuntoEnVivo(tam: 6, color: c.enVivo),
                        Text(
                          l.enVivo ? tx.enVivo : tx.horario,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: l.enVivo ? c.enVivo : c.alerta,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        );
    }
  }
}

class _Vacio extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _Vacio({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 34, color: c.textoTenue),
          const SizedBox(height: 12),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: c.textoSuave),
          ),
        ],
      ),
    );
  }
}
