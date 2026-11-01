// Búsqueda de origen y destino.
//
// Flujo "abuelita first": se abre con el destino enfocado y el origen en
// "Mi ubicación". Al elegir el destino, se buscan los viajes enseguida.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contract/app_state.dart';
import '../../contract/proveedores.dart';
import '../estado_ui.dart';
import '../tema/tema.dart';
import '../tema/lamina.dart';
import '../textos/textos.dart';

class PantallaBusqueda extends ConsumerStatefulWidget {
  const PantallaBusqueda({super.key});

  @override
  ConsumerState<PantallaBusqueda> createState() => _PantallaBusquedaState();
}

class _PantallaBusquedaState extends ConsumerState<PantallaBusqueda> {
  final _ctlOrigen = TextEditingController();
  final _ctlDestino = TextEditingController();
  final _focoOrigen = FocusNode();
  final _focoDestino = FocusNode();
  late CampoBusqueda _campo;

  @override
  void initState() {
    super.initState();
    _campo = ref.read(busquedaAbiertaProvider) ?? CampoBusqueda.destino;
    _sincronizarTextos();
    _focoOrigen.addListener(() {
      if (_focoOrigen.hasFocus) _enfocar(CampoBusqueda.origen);
    });
    _focoDestino.addListener(() {
      if (_focoDestino.hasFocus) _enfocar(CampoBusqueda.destino);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      (_campo == CampoBusqueda.origen ? _focoOrigen : _focoDestino)
          .requestFocus();
    });
  }

  void _enfocar(CampoBusqueda c) {
    if (_campo == c) return;
    setState(() => _campo = c);
    ref.read(appActionsProvider).cancelarConsulta();
    _sincronizarTextos();
  }

  /// El campo enfocado muestra lo que se escribe; si el punto es "Mi
  /// ubicación" se arranca vacío para escribir directo.
  void _sincronizarTextos() {
    final b = ref.read(appStateProvider).busqueda;
    String texto(PuntoBusqueda? p) => p is LugarElegido ? p.lugar.nombre : '';
    _ctlOrigen.text = texto(b.origen);
    _ctlDestino.text = texto(b.destino);
  }

  void _cerrar() {
    ref.read(appActionsProvider).cancelarConsulta();
    ref.read(busquedaAbiertaProvider.notifier).state = null;
  }

  void _alElegir(CampoBusqueda campo, {Lugar? lugar}) {
    final acciones = ref.read(appActionsProvider);
    if (lugar != null) {
      acciones.elegirLugar(campo, lugar);
    } else {
      acciones.usarMiUbicacion(campo);
    }
    final b = ref.read(appStateProvider).busqueda;
    _sincronizarTextos();
    if (b.destino == null) {
      _focoDestino.requestFocus();
      return;
    }
    if (b.completa) {
      FocusScope.of(context).unfocus();
      ref.read(busquedaAbiertaProvider.notifier).state = null;
      acciones.buscarViajes();
    }
  }

  @override
  void dispose() {
    _ctlOrigen.dispose();
    _ctlDestino.dispose();
    _focoOrigen.dispose();
    _focoDestino.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    final b = ref.watch(appStateProvider.select((s) => s.busqueda));
    final acciones = ref.read(appActionsProvider);
    final consultaDeEste = b.campoConsultado == _campo;
    final otro = b.punto(
      _campo == CampoBusqueda.origen
          ? CampoBusqueda.destino
          : CampoBusqueda.origen,
    );
    final ofrecerMiUbicacion =
        b.punto(_campo) is! MiUbicacion &&
        !(_campo == CampoBusqueda.destino && b.origen is MiUbicacion) &&
        otro is! MiUbicacion;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cerrar();
      },
      child: Lamina(
        conSombra: false,
        padding: EdgeInsets.zero,
        radio: BorderRadius.zero,
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 10, 10, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: IconButton(
                          key: const ValueKey('busqueda-volver'),
                          tooltip: tx.volver,
                          onPressed: _cerrar,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            _Campo(
                              clave: 'campo-origen',
                              ayuda:
                                  b.origen is MiUbicacion
                                      ? tx.miUbicacion
                                      : tx.desdeCampo,
                              icono: Icons.trip_origin_rounded,
                              controlador: _ctlOrigen,
                              foco: _focoOrigen,
                              esMiUbicacion: b.origen is MiUbicacion,
                              onCambiar:
                                  (t) => acciones.escribirConsulta(
                                    CampoBusqueda.origen,
                                    t,
                                  ),
                              onLimpiar: () {
                                acciones.limpiarCampo(CampoBusqueda.origen);
                                _ctlOrigen.clear();
                              },
                            ),
                            const SizedBox(height: 8),
                            _Campo(
                              clave: 'campo-destino',
                              ayuda:
                                  b.destino is MiUbicacion
                                      ? tx.miUbicacion
                                      : tx.aDondeVas,
                              icono: Icons.place_rounded,
                              controlador: _ctlDestino,
                              foco: _focoDestino,
                              esMiUbicacion: b.destino is MiUbicacion,
                              onCambiar:
                                  (t) => acciones.escribirConsulta(
                                    CampoBusqueda.destino,
                                    t,
                                  ),
                              onLimpiar: () {
                                acciones.limpiarCampo(CampoBusqueda.destino);
                                _ctlDestino.clear();
                              },
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 30, left: 2),
                        child: IconButton(
                          key: const ValueKey('busqueda-intercambiar'),
                          tooltip: tx.intercambiar,
                          onPressed:
                              b.destino == null
                                  ? null
                                  : () {
                                    acciones.intercambiarOrigenYDestino();
                                    _sincronizarTextos();
                                  },
                          icon: const Icon(Icons.swap_vert_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 2,
                  child:
                      consultaDeEste &&
                              b.estadoSugerencias == EstadoSugerencias.cargando
                          ? const LinearProgressIndicator(minHeight: 2)
                          : const Divider(),
                ),
                Expanded(
                  child: ListView(
                    key: const ValueKey('busqueda-sugerencias'),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      if (ofrecerMiUbicacion)
                        _FilaSugerencia(
                          clave: 'sugerencia-mi-ubicacion',
                          icono: Icons.my_location_rounded,
                          colorIcono: c.caminar,
                          titulo: tx.miUbicacion,
                          onTap: () => _alElegir(_campo),
                        ),
                      if (consultaDeEste)
                        for (final l in b.sugerencias)
                          _FilaSugerencia(
                            clave: 'sugerencia-${l.id}',
                            icono: Icons.place_outlined,
                            titulo: l.nombre,
                            detalle: l.detalle,
                            onTap: () => _alElegir(_campo, lugar: l),
                          ),
                      if (consultaDeEste &&
                          b.estadoSugerencias == EstadoSugerencias.listo &&
                          b.sugerencias.isEmpty)
                        _Mensaje(tx.lugarNoEncontrado),
                      if (consultaDeEste &&
                          b.estadoSugerencias == EstadoSugerencias.error)
                        _Mensaje(tx.errorBuscarLugares),
                      if (!consultaDeEste || b.consulta.trim().length < 2)
                        _Mensaje(tx.ayudaBusqueda, suave: true),
                    ],
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

class _Campo extends StatelessWidget {
  final String clave;
  final String ayuda;
  final IconData icono;
  final TextEditingController controlador;
  final FocusNode foco;
  final bool esMiUbicacion;
  final ValueChanged<String> onCambiar;
  final VoidCallback onLimpiar;

  const _Campo({
    required this.clave,
    required this.ayuda,
    required this.icono,
    required this.controlador,
    required this.foco,
    required this.esMiUbicacion,
    required this.onCambiar,
    required this.onLimpiar,
  });

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    return ListenableBuilder(
      listenable: controlador,
      builder:
          (context, _) => TextField(
            key: ValueKey(clave),
            controller: controlador,
            focusNode: foco,
            onChanged: onCambiar,
            textInputAction: TextInputAction.search,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: c.texto,
            ),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: Icon(
                esMiUbicacion ? Icons.my_location_rounded : icono,
                color: esMiUbicacion ? c.caminar : c.textoSuave,
              ),
              hintText: ayuda,
              hintStyle: TextStyle(
                color: esMiUbicacion ? c.caminar : c.textoTenue,
                fontWeight: esMiUbicacion ? FontWeight.w600 : FontWeight.w400,
              ),
              suffixIcon:
                  controlador.text.isEmpty
                      ? null
                      : IconButton(
                        tooltip: tx.borrar,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: onLimpiar,
                      ),
            ),
          ),
    );
  }
}

class _FilaSugerencia extends StatelessWidget {
  final String clave;
  final IconData icono;
  final Color? colorIcono;
  final String titulo;
  final String? detalle;
  final VoidCallback onTap;

  const _FilaSugerencia({
    required this.clave,
    required this.icono,
    required this.titulo,
    this.detalle,
    required this.onTap,
    this.colorIcono,
  });

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    return InkWell(
      key: ValueKey(clave),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.superficie,
                shape: BoxShape.circle,
              ),
              child: Icon(icono, color: colorIcono ?? c.textoSuave, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: c.texto,
                    ),
                  ),
                  if (detalle != null)
                    Text(
                      detalle!,
                      style: TextStyle(fontSize: 14, color: c.textoSuave),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  final String texto;
  final bool suave;
  const _Mensaje(this.texto, {this.suave = false});

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 15,
          color: suave ? c.textoTenue : c.texto,
          height: 1.4,
        ),
      ),
    );
  }
}
