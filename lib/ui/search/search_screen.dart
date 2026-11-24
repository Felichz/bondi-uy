// Origin and destination search.
//
// "grandma test" flow: it opens with the destination focused and the origin
// set to "Mi ubicación". When the destination is chosen, trips are searched right away.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contract/app_state.dart';
import '../../contract/providers.dart';
import '../ui_status.dart';
import '../theme/app_theme.dart';
import '../theme/sheet.dart';
import '../texts/texts.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctlOrigin = TextEditingController();
  final _ctlDestination = TextEditingController();
  final _focusOrigin = FocusNode();
  final _focusDestination = FocusNode();
  late SearchField _field;

  @override
  void initState() {
    super.initState();
    _field = ref.read(searchOpenProvider) ?? SearchField.destination;
    _synchronizeTexts();
    _focusOrigin.addListener(() {
      if (_focusOrigin.hasFocus) _focus(SearchField.origin);
    });
    _focusDestination.addListener(() {
      if (_focusDestination.hasFocus) _focus(SearchField.destination);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      (_field == SearchField.origin ? _focusOrigin : _focusDestination)
          .requestFocus();
    });
  }

  void _focus(SearchField c) {
    if (_field == c) return;
    setState(() => _field = c);
    ref.read(appActionsProvider).cancelQuery();
    _synchronizeTexts();
  }

  /// The focused field shows what is typed; if the point is "Mi
  /// ubicación" it starts empty so you can type directly.
  void _synchronizeTexts() {
    final b = ref.read(appStateProvider).search;
    String text(SearchPoint? p) => p is ChosenPlace ? p.place.name : '';
    _ctlOrigin.text = text(b.origin);
    _ctlDestination.text = text(b.destination);
  }

  void _close() {
    ref.read(appActionsProvider).cancelQuery();
    ref.read(searchOpenProvider.notifier).state = null;
  }

  void _onChoose(SearchField field, {Place? place}) {
    final actions = ref.read(appActionsProvider);
    if (place != null) {
      actions.choosePlace(field, place);
    } else {
      actions.useMyLocation(field);
    }
    final b = ref.read(appStateProvider).search;
    _synchronizeTexts();
    if (b.destination == null) {
      _focusDestination.requestFocus();
      return;
    }
    if (b.complete) {
      FocusScope.of(context).unfocus();
      ref.read(searchOpenProvider.notifier).state = null;
      actions.searchTrips();
    }
  }

  @override
  void dispose() {
    _ctlOrigin.dispose();
    _ctlDestination.dispose();
    _focusOrigin.dispose();
    _focusDestination.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    final b = ref.watch(appStateProvider.select((s) => s.search));
    final actions = ref.read(appActionsProvider);
    final queryOfEast = b.fieldQueried == _field;
    final other = b.point(
      _field == SearchField.origin
          ? SearchField.destination
          : SearchField.origin,
    );
    final offerMyLocation =
        b.point(_field) is! MyLocation &&
        !(_field == SearchField.destination && b.origin is MyLocation) &&
        other is! MyLocation;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Sheet(
        withShadow: false,
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
                          key: const ValueKey('search-back'),
                          tooltip: tx.back,
                          onPressed: _close,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            _Field(
                              keyId: 'field-origin',
                              help:
                                  b.origin is MyLocation
                                      ? tx.myLocation
                                      : tx.fromField,
                              icon: Icons.trip_origin_rounded,
                              controller: _ctlOrigin,
                              focus: _focusOrigin,
                              isMyLocation: b.origin is MyLocation,
                              onChanged:
                                  (t) =>
                                      actions.writeQuery(SearchField.origin, t),
                              onClean: () {
                                actions.cleanField(SearchField.origin);
                                _ctlOrigin.clear();
                              },
                            ),
                            const SizedBox(height: 8),
                            _Field(
                              keyId: 'field-destination',
                              help:
                                  b.destination is MyLocation
                                      ? tx.myLocation
                                      : tx.whereAreYouGoing,
                              icon: Icons.place_rounded,
                              controller: _ctlDestination,
                              focus: _focusDestination,
                              isMyLocation: b.destination is MyLocation,
                              onChanged:
                                  (t) => actions.writeQuery(
                                    SearchField.destination,
                                    t,
                                  ),
                              onClean: () {
                                actions.cleanField(SearchField.destination);
                                _ctlDestination.clear();
                              },
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 30, left: 2),
                        child: IconButton(
                          key: const ValueKey('search-swap'),
                          tooltip: tx.swap,
                          onPressed:
                              b.destination == null
                                  ? null
                                  : () {
                                    actions.swapOriginAndDestination();
                                    _synchronizeTexts();
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
                      queryOfEast &&
                              b.statusSuggestions == SuggestionsStatus.loading
                          ? const LinearProgressIndicator(minHeight: 2)
                          : const Divider(),
                ),
                Expanded(
                  child: ListView(
                    key: const ValueKey('search-suggestions'),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      if (offerMyLocation)
                        _SuggestionRow(
                          keyId: 'suggestion-my-location',
                          icon: Icons.my_location_rounded,
                          colorIcon: c.walk,
                          title: tx.myLocation,
                          onTap: () => _onChoose(_field),
                        ),
                      if (queryOfEast)
                        for (final l in b.suggestions)
                          _SuggestionRow(
                            keyId: 'suggestion-${l.id}',
                            icon: Icons.place_outlined,
                            title: l.name,
                            detail: l.detail,
                            onTap: () => _onChoose(_field, place: l),
                          ),
                      if (queryOfEast &&
                          b.statusSuggestions == SuggestionsStatus.ready &&
                          b.suggestions.isEmpty)
                        _Message(tx.placeNotFound),
                      if (queryOfEast &&
                          b.statusSuggestions == SuggestionsStatus.error)
                        _Message(tx.errorSearchPlaces),
                      if (!queryOfEast || b.query.trim().length < 2)
                        _Message(tx.helpSearch, soft: true),
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

class _Field extends StatelessWidget {
  final String keyId;
  final String help;
  final IconData icon;
  final TextEditingController controller;
  final FocusNode focus;
  final bool isMyLocation;
  final ValueChanged<String> onChanged;
  final VoidCallback onClean;

  const _Field({
    required this.keyId,
    required this.help,
    required this.icon,
    required this.controller,
    required this.focus,
    required this.isMyLocation,
    required this.onChanged,
    required this.onClean,
  });

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder:
          (context, _) => TextField(
            key: ValueKey(keyId),
            controller: controller,
            focusNode: focus,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: c.text,
            ),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: Icon(
                isMyLocation ? Icons.my_location_rounded : icon,
                color: isMyLocation ? c.walk : c.textSoft,
              ),
              hintText: help,
              hintStyle: TextStyle(
                color: isMyLocation ? c.walk : c.textFaint,
                fontWeight: isMyLocation ? FontWeight.w600 : FontWeight.w400,
              ),
              suffixIcon:
                  controller.text.isEmpty
                      ? null
                      : IconButton(
                        tooltip: tx.clear,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: onClean,
                      ),
            ),
          ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final String keyId;
  final IconData icon;
  final Color? colorIcon;
  final String title;
  final String? detail;
  final VoidCallback onTap;

  const _SuggestionRow({
    required this.keyId,
    required this.icon,
    required this.title,
    this.detail,
    required this.onTap,
    this.colorIcon,
  });

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    return InkWell(
      key: ValueKey(keyId),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: colorIcon ?? c.textSoft, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  if (detail != null)
                    Text(
                      detail!,
                      style: TextStyle(fontSize: 14, color: c.textSoft),
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

class _Message extends StatelessWidget {
  final String text;
  final bool soft;
  const _Message(this.text, {this.soft = false});

  @override
  Widget build(BuildContext context) {
    final c = BondiColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          color: soft ? c.textFaint : c.text,
          height: 1.4,
        ),
      ),
    );
  }
}
