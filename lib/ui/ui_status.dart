// The UI's own state: presentation concepts that the logic does not know about.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contract/app_state.dart';
import 'map/bondi_map.dart';
import 'map/tiles/tile_source.dart';

/// Option in the carousel that the user is looking at.
final optionFocusedProvider = StateProvider<String?>((_) => null);

/// Show the web presentation also outside the web (tests): null = no;
/// otherwise, true starts in the "inside" view.
final frameForcedProvider = Provider<bool?>((_) => null);

/// On a trip, the camera follows the approaching bus (true) or the user.
final verBusProvider = StateProvider<bool>((_) => false);

/// Search open and field with focus (null = closed).
final searchOpenProvider = StateProvider<SearchField?>((_) => null);

/// Height of the trip step card (logical px): the map is framed below it.
final heightCardTripProvider = StateProvider<double>((_) => 200);

/// Height of the options sheet (logical px): the map is framed above it.
final heightSheetOptionsProvider = StateProvider<double>((_) => 320);

/// Where the map tiles come from (the tests use local files).
final sourceTilesProvider = Provider<TileSource>((_) => OpenFreeMapTiles());

/// Decode tiles in an isolate (in tests with fake time: false).
final tilesInIsolateProvider = Provider<bool>((_) => true);

final controllerMapProvider = Provider<MapController>((ref) {
  final c = MapController();
  ref.onDispose(c.dispose);
  return c;
});
