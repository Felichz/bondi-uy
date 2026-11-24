// On a wide screen (the web demo opened on a computer), the landing: the app
// inside a phone, plugged into a board where the calls between its pieces are
// seen (under_the_hood.dart). If the window is too small for the whole board,
// a simpler presentation with the phone alongside. On a phone, or embedded with
// `?marco=0`, the app fills the whole screen as always; on an Android phone,
// with a notice on top to download the app, until it is closed.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contract/providers.dart';

import '../platform/storage.dart';
import '../platform/links.dart';
import '../theme/app_theme.dart';
import '../theme/theme_preference.dart';
import '../texts/texts.dart';
import 'under_the_hood.dart';

/// Optional links for the presentation (defined at compile time).
const _urlApk = String.fromEnvironment('APK_URL');
const _urlCode = String.fromEnvironment('SOURCE_URL');

/// Screen size of a typical phone (logical px).
const _screen = Size(412, 892);

/// The phone of the "inside" view in a window of [alto].
Size phoneSizeUnderTheHood(double height) {
  final scale = ((height - 96) / (_screen.height + 24)).clamp(0.5, 0.92);
  return Size((_screen.width + 24) * scale, (_screen.height + 24) * scale);
}

/// Minimum window height for the "inside" view.
const heightMinUnderTheHood = 680.0;

class WebFrame extends ConsumerStatefulWidget {
  final Widget child;

  /// Show the frame also outside the web (tests).
  final bool force;
  const WebFrame({super.key, required this.child, this.force = false});

  @override
  ConsumerState<WebFrame> createState() => _WebFrameState();
}

class _WebFrameState extends ConsumerState<WebFrame> {
  static bool get _disabled => Uri.base.queryParameters['marco'] == '0';

  final _phoneKey = GlobalKey();

  Widget get child => widget.child;
  bool get force => widget.force;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    if (!(kIsWeb || force) || _disabled) return child;
    if (size.width < 700 || size.height < 560) {
      final android = defaultTargetPlatform == TargetPlatform.android;
      final app =
          kIsWeb && android && _urlApk.isNotEmpty
              ? _WithNotice(child: child)
              : child;
      // On a phone, the board lives in a sheet under the app (the demo only:
      // it is the one that reports its calls).
      return ref.watch(tracesProvider) == null ? app : _Pocket(child: app);
    }
    final c = BondiColors.of(context);
    // The phone fits entirely in the window, with some room above and below.
    final scale = ((size.height - 64) / (_screen.height + 24)).clamp(0.5, 1.0);
    // With a global key: when the window changes between the board and the
    // simple presentation, the app moves without being unmounted (the trip,
    // the map and the camera stay as they were).
    final device = _Phone(
      key: _phoneKey,
      child: MediaQuery(
        data: mq.copyWith(
          size: _screen,
          padding: const EdgeInsets.only(top: 24, bottom: 16),
          viewPadding: const EdgeInsets.only(top: 24, bottom: 16),
        ),
        child: child,
      ),
    );
    final phone = SizedBox(
      width: (_screen.width + 24) * scale,
      height: (_screen.height + 24) * scale,
      child: FittedBox(child: device),
    );
    // The board: only if the logic reports its calls (the demo) and it fits
    // whole (the story, the phone and the board, without shrinking texts).
    final sizeCore = phoneSizeUnderTheHood(size.height);
    final underTheHoodPossible =
        ref.watch(tracesProvider) != null &&
        size.height >= heightMinUnderTheHood &&
        size.width >= widthMinUnderTheHood(sizeCore.width);
    final dark = c.brightness == Brightness.dark;
    if (underTheHoodPossible) {
      return ColoredBox(
        color: dark ? const Color(0xFF06080B) : const Color(0xFFDDE1E6),
        child: UnderTheHood(
          light: !dark,
          sizePhone: sizeCore,
          phone: FittedBox(child: device),
          header: Row(
            children: [
              _Marker(dark: dark),
              const Spacer(),
              _ThemeButton(dark: dark),
            ],
          ),
        ),
      );
    }
    final width = size.width >= 1000;
    return ColoredBox(
      color:
          c.brightness == Brightness.dark
              ? const Color(0xFF0E1014)
              : const Color(0xFFEEF1F5),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (width) ...[
              const SizedBox(width: 380, child: _Presentation()),
              const SizedBox(width: 64),
            ],
            phone,
          ],
        ),
      ),
    );
  }
}

class _Phone extends StatelessWidget {
  final Widget child;
  const _Phone({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _screen.width + 24,
      height: _screen.height + 24,
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
        child: SizedBox.fromSize(size: _screen, child: child),
      ),
    );
  }
}

class _Presentation extends StatelessWidget {
  const _Presentation();

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    final t = Theme.of(context).textTheme;
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Marker(dark: c.brightness == Brightness.dark),
              const Spacer(),
              _ThemeButton(dark: c.brightness == Brightness.dark),
            ],
          ),
          const SizedBox(height: 20),
          Text(tx.webMotto, style: t.headlineSmall?.copyWith(height: 1.25)),
          const SizedBox(height: 14),
          Text(
            tx.webDemo,
            style: t.bodyLarge?.copyWith(color: c.textSoft, height: 1.5),
          ),
          if (_urlApk.isNotEmpty || _urlCode.isNotEmpty) ...[
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
                    onPressed: () => openLink(_urlApk),
                    icon: const Icon(Icons.android_rounded),
                    label: Text(tx.webDownload),
                  ),
                if (_urlCode.isNotEmpty)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    onPressed: () => openLink(_urlCode),
                    icon: const Icon(Icons.code_rounded),
                    label: Text(tx.webCode),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          Text(
            '© OpenStreetMap · OpenFreeMap · Intendencia de Montevideo',
            style: t.bodySmall?.copyWith(color: c.textFaint),
          ),
        ],
      ),
    );
  }
}

/// The app full screen over a strip that opens into the board's sheet. Open,
/// the sheet covers the bottom of the app, which stays live and usable above.
class _Pocket extends StatefulWidget {
  final Widget child;
  const _Pocket({required this.child});

  @override
  State<_Pocket> createState() => _PocketState();
}

class _PocketState extends State<_Pocket> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final inset = mq.padding.bottom;
    final closed = UnderTheHoodPocket.stripHeight + inset;
    final open = math.min(
      UnderTheHoodPocket.sheetHeight(inset),
      mq.size.height * 0.62,
    );
    final light = BondiColors.of(context).brightness == Brightness.light;
    return Stack(
      children: [
        // The app above the strip: it is told the screen ends there.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: closed,
          child: MediaQuery(
            data: mq.copyWith(
              size: Size(mq.size.width, mq.size.height - closed),
              padding: mq.padding.copyWith(bottom: 0),
              viewPadding: mq.viewPadding.copyWith(bottom: 0),
            ),
            child: widget.child,
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
          left: 0,
          right: 0,
          bottom: 0,
          height: _open ? open : closed,
          child: Padding(
            padding: EdgeInsets.only(bottom: inset),
            child: UnderTheHoodPocket(
              light: light,
              open: _open,
              bottomInset: inset,
              onToggle: () => setState(() => _open = !_open),
            ),
          ),
        ),
      ],
    );
  }
}

/// The app full screen, with the Android app notice on top until it is
/// closed (remembered in the browser).
class _WithNotice extends StatefulWidget {
  final Widget child;
  const _WithNotice({required this.child});

  @override
  State<_WithNotice> createState() => _WithNoticeState();
}

class _WithNoticeState extends State<_WithNotice> {
  static const _noticeKey = 'avisoApp';

  /// Hidden until it is known whether it was already closed, so it does not appear and then vanish.
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    readPreference(_noticeKey).then((v) {
      if (mounted && v != 'cerrado') setState(() => _visible = true);
    });
  }

  void _close() {
    setState(() => _visible = false);
    savePreference(_noticeKey, 'cerrado');
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return widget.child;
    // The notice takes its strip on top and the app stays below, whole: it
    // does not cover the search.
    return Column(
      children: [
        _Notice(onClose: _close),
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

class _Notice extends StatelessWidget {
  final VoidCallback onClose;
  const _Notice({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    final t = Theme.of(context).textTheme;
    final topInset = MediaQuery.of(context).padding.top;
    return Material(
      color: c.sheetSolid,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, topInset + 10, 4, 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.separator)),
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
                    tx.noticeApp,
                    style: t.titleSmall?.copyWith(color: c.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    tx.noticeAppDetail,
                    style: t.bodySmall?.copyWith(color: c.textSoft),
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
              onPressed: () => openLink(_urlApk),
              icon: const Icon(Icons.android_rounded, size: 18),
              label: Text(tx.noticeAppDownload),
            ),
            IconButton(
              tooltip: tx.noticeAppClose,
              onPressed: onClose,
              icon: Icon(Icons.close_rounded, color: c.textSoft),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo and name.
class _Marker extends StatelessWidget {
  final bool dark;
  const _Marker({required this.dark});

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
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
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            letterSpacing: -0.8,
            color: dark ? const Color(0xFFF2F4F7) : const Color(0xFF111318),
          ),
        ),
      ],
    );
  }
}

/// Switches between light and dark (and remembers it).
class _ThemeButton extends ConsumerWidget {
  final bool dark;
  const _ThemeButton({required this.dark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A label for screen readers (a Tooltip needs an Overlay, and the frame
    // lives above the app's Navigator).
    return Semantics(
      button: true,
      label: dark ? tx.webThemeToLight : tx.webThemeToDark,
      child: Material(
        color: dark ? const Color(0xFF151A21) : Colors.white,
        shape: CircleBorder(
          side: BorderSide(
            color: dark ? const Color(0xFF2A323D) : const Color(0xFFD5DAE1),
          ),
        ),
        child: InkWell(
          key: const ValueKey('theme-toggle'),
          customBorder: const CircleBorder(),
          onTap:
              () => ref
                  .read(preferenceThemeProvider.notifier)
                  .choose(dark ? ThemeMode.light : ThemeMode.dark),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 20,
              color: dark ? const Color(0xFFE9EDF3) : const Color(0xFF111318),
            ),
          ),
        ),
      ),
    );
  }
}
