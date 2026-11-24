// Floating controls over the map (the camera button, the re-center button, a
// notice) tell the map where they are, so it keeps its balloons and street
// names out from under them.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the floating controls are, in screen coordinates.
class MapObstacles extends ChangeNotifier {
  final Map<Object, Rect> _rects = {};

  Iterable<Rect> get rects => _rects.values;

  /// [rect] null: the control is gone (or hidden).
  void report(Object id, Rect? rect) {
    if (rect == null) {
      if (_rects.remove(id) == null) return;
    } else {
      if (_rects[id] == rect) return;
      _rects[id] = rect;
    }
    notifyListeners();
  }
}

final mapObstaclesProvider = Provider<MapObstacles>((ref) {
  final o = MapObstacles();
  ref.onDispose(o.dispose);
  return o;
});

/// Marks [child] as something that covers the map while [active].
class MapObstacle extends ConsumerStatefulWidget {
  final Widget child;
  final bool active;
  const MapObstacle({super.key, required this.child, this.active = true});

  @override
  ConsumerState<MapObstacle> createState() => _MapObstacleState();
}

class _MapObstacleState extends ConsumerState<MapObstacle> {
  final _id = Object();
  late MapObstacles _obstacles;

  void _measure() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (!widget.active || box is! RenderBox || !box.hasSize) {
      _obstacles.report(_id, null);
      return;
    }
    _obstacles.report(
      _id,
      MatrixUtils.transformRect(
        box.getTransformTo(null),
        Offset.zero & box.size,
      ),
    );
  }

  @override
  void dispose() {
    // After the frame: its listeners rebuild, and this is no time for that.
    final obstacles = _obstacles, id = _id;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => obstacles.report(id, null),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _obstacles = ref.watch(mapObstaclesProvider);
    // Measured once laid out, every time it is rebuilt.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    return widget.child;
  }
}
