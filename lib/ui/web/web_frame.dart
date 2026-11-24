// On a wide screen (the web demo opened on a computer), the app is shown inside
// a phone, with a presentation alongside; or, in the "inside" view (`?vista=core`
// or the selector above), plugged into a board where the calls between its
// pieces are seen (por_dentro.dart). On a phone, or embedded with `?marco=0`, it
// fills the whole screen as always; on an Android phone, with a notice on top to
// download the app (the presentation, with its button, does not fit), until it
// is closed.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contract/providers.dart';

import '../platform/storage.dart';
import '../platform/links.dart';
import '../theme/app_theme.dart';
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

  /// Start in the "inside" view (otherwise the URL decides).
  final bool? underTheHood;
  const WebFrame({
    super.key,
    required this.child,
    this.force = false,
    this.underTheHood,
  });

  @override
  ConsumerState<WebFrame> createState() => _WebFrameState();
}

class _WebFrameState extends ConsumerState<WebFrame> {
  static bool get _disabled => Uri.base.queryParameters['marco'] == '0';

  final _phoneKey = GlobalKey();

  late bool _underTheHood =
      widget.underTheHood ?? Uri.base.queryParameters['vista'] == 'core';

  Widget get child => widget.child;
  bool get force => widget.force;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    if (!(kIsWeb || force) || _disabled) return child;
    if (size.width < 700 || size.height < 560) {
      final android = defaultTargetPlatform == TargetPlatform.android;
      return kIsWeb && android && _urlApk.isNotEmpty
          ? _WithNotice(child: child)
          : child;
    }
    final c = BondiColors.of(context);
    // The phone fits entirely in the window, with some room above and below.
    final scale = ((size.height - 64) / (_screen.height + 24)).clamp(0.5, 1.0);
    // With a global key: when switching views, the app moves without being
    // unmounted (the trip, the map and the camera stay as they were).
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
    // Inside view: only if the logic reports its calls (the demo) and it fits
    // whole (the story, the phone and the board, without shrinking texts).
    final sizeCore = phoneSizeUnderTheHood(size.height);
    final underTheHoodPossible =
        ref.watch(tracesProvider) != null &&
        size.height >= heightMinUnderTheHood &&
        size.width >= widthMinUnderTheHood(sizeCore.width);
    final selector =
        underTheHoodPossible
            ? _Selector(
              underTheHood: _underTheHood,
              dark: c.brightness == Brightness.dark,
              onChange: (v) => setState(() => _underTheHood = v),
            )
            : null;
    if (underTheHoodPossible && _underTheHood) {
      final light = c.brightness == Brightness.light;
      return ColoredBox(
        color: light ? const Color(0xFFDDE1E6) : const Color(0xFF06080B),
        child: UnderTheHood(
          light: light,
          sizePhone: sizeCore,
          phone: FittedBox(child: device),
          // If they do not fit in one line, the selector moves to the next.
          header: Wrap(
            spacing: 24,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [_Marker(dark: !light), selector!],
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
              SizedBox(width: 380, child: _Presentation(selector: selector)),
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
  final Widget? selector;
  const _Presentation({this.selector});

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
          if (selector != null) ...[selector!, const SizedBox(height: 28)],
          _Marker(dark: c.brightness == Brightness.dark),
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

/// Chooses the presentation view: the usual one or "inside".
class _Selector extends StatelessWidget {
  final bool underTheHood;
  final bool dark;
  final ValueChanged<bool> onChange;
  const _Selector({
    required this.underTheHood,
    required this.dark,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final background = dark ? const Color(0xFF151A21) : const Color(0xFFFFFFFF);
    final border = dark ? const Color(0xFF2A323D) : const Color(0xFFDDE2EA);
    final active = dark ? const Color(0xFFF2F4F7) : const Color(0xFF111318);
    final overActive = dark ? const Color(0xFF111318) : Colors.white;
    final inactive = dark ? const Color(0xFFA7AEBA) : const Color(0xFF5C616C);
    Widget option(String text, bool current, bool value) => Material(
      color: current ? active : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: ValueKey(value ? 'view-under-the-hood' : 'view-presentation'),
        borderRadius: BorderRadius.circular(20),
        onTap: current ? null : () => onChange(value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: current ? overActive : inactive,
            ),
          ),
        ),
      ),
    );
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            option(tx.webViewPresentation, !underTheHood, false),
            const SizedBox(width: 2),
            option(tx.webViewInside, underTheHood, true),
          ],
        ),
      ),
    );
  }
}
