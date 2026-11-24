// Translates the logic's notices into messages for the user.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contract/app_state.dart';
import '../contract/providers.dart';
import 'theme/app_theme.dart';
import 'texts/texts.dart';

({String text, IconData icon, bool important}) textNotice(NoticeType t) =>
    switch (t) {
      NoticeType.withoutLocation => (
        text: tx.noticeWithoutLocation,
        icon: Icons.location_off,
        important: false,
      ),
      NoticeType.withoutConnection => (
        text: tx.noticeWithoutConnection,
        icon: Icons.wifi_off,
        important: false,
      ),
      NoticeType.errorPlanning => (
        text: tx.noticeErrorPlanning,
        icon: Icons.error_outline,
        important: false,
      ),
      NoticeType.errorSuggestions => (
        text: tx.noticeErrorSuggestions,
        icon: Icons.search_off,
        important: false,
      ),
      NoticeType.errorStop => (
        text: tx.noticeErrorStop,
        icon: Icons.error_outline,
        important: false,
      ),
      NoticeType.missingDestination => (
        text: tx.noticeMissingDestination,
        icon: Icons.flag,
        important: false,
      ),
      NoticeType.getOffAtNext => (
        text: tx.noticegetOff,
        icon: Icons.notifications_active,
        important: true,
      ),
      NoticeType.busArriving => (
        text: tx.noticeBusArriving,
        icon: Icons.directions_bus,
        important: true,
      ),
    };

class NoticeListener extends ConsumerWidget {
  const NoticeListener({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<Notice?>(appStateProvider.select((s) => s.notice), (
      antes,
      notice,
    ) {
      if (notice == null || notice.id == antes?.id) return;
      final a = textNotice(notice.type);
      if (a.important) HapticFeedback.heavyImpact();
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          key: ValueKey('aviso-${notice.type.name}'),
          backgroundColor: a.important ? BondiColors.of(context).bus : null,
          duration: Duration(seconds: a.important ? 8 : 4),
          content: Row(
            children: [
              Icon(a.icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  a.text,
                  style: TextStyle(
                    fontSize: a.important ? 18 : 16,
                    fontWeight: a.important ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      ref.read(appActionsProvider).descartarNotice(notice.id);
    });
    return const SizedBox.shrink();
  }
}
