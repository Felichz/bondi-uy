// En una pantalla ancha (la demo web abierta en una computadora), la app se
// muestra dentro de un teléfono, con una presentación al costado. En un
// teléfono, o embebida con `?marco=0`, ocupa toda la pantalla como siempre; en
// un teléfono Android, con un aviso arriba para bajar la app (la presentación,
// con su botón, no entra), hasta que se cierra.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../plataforma/almacen.dart';
import '../plataforma/enlaces.dart';
import '../tema/tema.dart';
import '../textos/textos.dart';

/// Enlaces opcionales de la presentación (se definen al compilar).
const _urlApk = String.fromEnvironment('APK_URL');
const _urlCodigo = String.fromEnvironment('SOURCE_URL');

/// Tamaño de pantalla de un teléfono típico (px lógicos).
const _pantalla = Size(412, 892);

class MarcoWeb extends StatelessWidget {
  final Widget child;

  /// Mostrar el marco también fuera de la web (tests).
  final bool forzar;
  const MarcoWeb({super.key, required this.child, this.forzar = false});

  static bool get _desactivado => Uri.base.queryParameters['marco'] == '0';

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final tam = mq.size;
    if (!(kIsWeb || forzar) || _desactivado) return child;
    if (tam.width < 700 || tam.height < 560) {
      final android = defaultTargetPlatform == TargetPlatform.android;
      return kIsWeb && android && _urlApk.isNotEmpty
          ? _ConAviso(child: child)
          : child;
    }
    final c = ColoresBondi.of(context);
    // El teléfono entra entero en la ventana, con aire arriba y abajo.
    final escala = ((tam.height - 64) / (_pantalla.height + 24)).clamp(
      0.5,
      1.0,
    );
    final telefono = SizedBox(
      width: (_pantalla.width + 24) * escala,
      height: (_pantalla.height + 24) * escala,
      child: FittedBox(
        child: _Telefono(
          child: MediaQuery(
            data: mq.copyWith(
              size: _pantalla,
              padding: const EdgeInsets.only(top: 24, bottom: 16),
              viewPadding: const EdgeInsets.only(top: 24, bottom: 16),
            ),
            child: child,
          ),
        ),
      ),
    );
    final ancho = tam.width >= 1000;
    return ColoredBox(
      color:
          c.brillo == Brightness.dark
              ? const Color(0xFF0E1014)
              : const Color(0xFFEEF1F5),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ancho) ...[
              const SizedBox(width: 380, child: _Presentacion()),
              const SizedBox(width: 64),
            ],
            telefono,
          ],
        ),
      ),
    );
  }
}

class _Telefono extends StatelessWidget {
  final Widget child;
  const _Telefono({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _pantalla.width + 24,
      height: _pantalla.height + 24,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF15171C),
        borderRadius: BorderRadius.circular(56),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 60,
            offset: Offset(0, 30),
            spreadRadius: -10,
          ),
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(44),
        child: SizedBox.fromSize(size: _pantalla, child: child),
      ),
    );
  }
}

class _Presentacion extends StatelessWidget {
  const _Presentacion();

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    final t = Theme.of(context).textTheme;
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.bus,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.directions_bus_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'BondiUY',
                style: t.headlineMedium?.copyWith(letterSpacing: -0.8),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(tx.webLema, style: t.headlineSmall?.copyWith(height: 1.25)),
          const SizedBox(height: 14),
          Text(
            tx.webDemo,
            style: t.bodyLarge?.copyWith(color: c.textoSuave, height: 1.5),
          ),
          if (_urlApk.isNotEmpty || _urlCodigo.isNotEmpty) ...[
            const SizedBox(height: 26),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (_urlApk.isNotEmpty)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    onPressed: () => abrirEnlace(_urlApk),
                    icon: const Icon(Icons.android_rounded),
                    label: Text(tx.webDescargar),
                  ),
                if (_urlCodigo.isNotEmpty)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    onPressed: () => abrirEnlace(_urlCodigo),
                    icon: const Icon(Icons.code_rounded),
                    label: Text(tx.webCodigo),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          Text(
            '© OpenStreetMap · OpenFreeMap · Intendencia de Montevideo',
            style: t.bodySmall?.copyWith(color: c.textoTenue),
          ),
        ],
      ),
    );
  }
}

/// La app a pantalla completa, con el aviso de la app de Android arriba
/// mientras no se haya cerrado (se recuerda en el navegador).
class _ConAviso extends StatefulWidget {
  final Widget child;
  const _ConAviso({required this.child});

  @override
  State<_ConAviso> createState() => _ConAvisoState();
}

class _ConAvisoState extends State<_ConAviso> {
  static const _clave = 'avisoApp';

  /// Oculto hasta saber si ya se cerró, para que no aparezca y se vaya.
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    leerPreferencia(_clave).then((v) {
      if (mounted && v != 'cerrado') setState(() => _visible = true);
    });
  }

  void _cerrar() {
    setState(() => _visible = false);
    guardarPreferencia(_clave, 'cerrado');
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return widget.child;
    // El aviso ocupa su franja arriba y la app sigue debajo, entera: no tapa
    // la búsqueda.
    return Column(
      children: [
        _Aviso(onCerrar: _cerrar),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  final VoidCallback onCerrar;
  const _Aviso({required this.onCerrar});

  @override
  Widget build(BuildContext context) {
    final c = ColoresBondi.of(context);
    final t = Theme.of(context).textTheme;
    final arriba = MediaQuery.of(context).padding.top;
    return Material(
      color: c.laminaSolida,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, arriba + 10, 4, 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.separador)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.bus,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.directions_bus_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.avisoApp,
                    style: t.titleSmall?.copyWith(color: c.texto),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    tx.avisoAppDetalle,
                    style: t.bodySmall?.copyWith(color: c.textoSuave),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: () => abrirEnlace(_urlApk),
              icon: const Icon(Icons.android_rounded, size: 18),
              label: Text(tx.avisoAppDescargar),
            ),
            IconButton(
              tooltip: tx.avisoAppCerrar,
              onPressed: onCerrar,
              icon: Icon(Icons.close_rounded, color: c.textoSuave),
            ),
          ],
        ),
      ),
    );
  }
}
