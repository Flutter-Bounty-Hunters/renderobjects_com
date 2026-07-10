import 'dart:math' show sqrt, pow, max;

import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class WatchAppGrid extends StatefulWidget {
  const WatchAppGrid({super.key, this.controller, this.childCount, required this.builder});

  final WatchAppGridController? controller;
  final int? childCount;
  final Widget? Function(BuildContext context, int index) builder;

  @override
  State<WatchAppGrid> createState() => _WatchAppGridState();
}

class _WatchAppGridState extends State<WatchAppGrid> with TickerProviderStateMixin {
  late WatchAppGridController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _attachController(widget.controller);
  }

  @override
  void didUpdateWidget(WatchAppGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detachController();
      _attachController(widget.controller);
    }
  }

  @override
  void dispose() {
    _detachController();
    super.dispose();
  }

  void _attachController(WatchAppGridController? provided) {
    if (provided != null) {
      _controller = provided;
      _ownsController = false;
    } else {
      _controller = WatchAppGridController();
      _ownsController = true;
    }
    _controller.attach(this);
  }

  void _detachController() {
    _controller.detach();
    if (_ownsController) {
      _controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        // dy is positive downward; scrolling down increases the vertical offset.
        _controller.applyScrollDelta(-details.delta.dy);
        _controller.applyHorizontalPanDelta(details.delta.dx);
      },
      onPanEnd: (details) {
        _controller.endPan(velocity: details.velocity.pixelsPerSecond);
      },
      child: WatchAppGridRenderObjectWidget(
        controller: _controller,
        childCount: widget.childCount,
        builder: widget.builder,
      ),
    );
  }
}

class WatchAppGridRenderObjectWidget extends RenderObjectWidget {
  const WatchAppGridRenderObjectWidget({super.key, required this.controller, this.childCount, required this.builder});

  final WatchAppGridController controller;
  final int? childCount;
  final Widget? Function(BuildContext context, int index) builder;

  @override
  WatchAppGridElement createElement() => WatchAppGridElement(this);

  @override
  RenderWatchAppGridLayout createRenderObject(BuildContext context) {
    return RenderWatchAppGridLayout(childManager: context as LazyChildDelegate, controller: controller);
  }

  @override
  void updateRenderObject(BuildContext context, RenderWatchAppGridLayout renderObject) {
    renderObject.controller = controller;
  }
}

class WatchAppGridElement extends RenderObjectElement implements LazyChildDelegate {
  WatchAppGridElement(super.widget);

  final Map<int, Element> _childElements = {};

  WatchAppGridRenderObjectWidget get _widget => widget as WatchAppGridRenderObjectWidget;

  @override
  RenderWatchAppGridLayout get renderObject => super.renderObject as RenderWatchAppGridLayout;

  @override
  int? get childCount => _widget.childCount;

  @override
  void didStartLayout() {}

  @override
  bool createOrUpdateChildDuringLayout(int index, {required RenderBox? after}) {
    bool produced = false;
    owner!.buildScope(this, () {
      final newChild = updateChild(_childElements[index], _widget.builder(this, index), after);
      if (newChild != null) {
        _childElements[index] = newChild;
        produced = true;
      } else {
        _childElements.remove(index);
      }
    });
    return produced;
  }

  @override
  void insertRenderObjectChild(RenderObject child, Object? slot) {
    renderObject.insert(child as RenderBox, after: slot as RenderBox?);
  }

  @override
  void moveRenderObjectChild(RenderObject child, Object? oldSlot, Object? newSlot) {
    renderObject.move(child as RenderBox, after: newSlot as RenderBox?);
  }

  @override
  void removeChildDuringLayout(RenderBox child) {
    final index = (child.parentData! as _WatchAppGridLayoutParentData).index!;
    owner!.buildScope(this, () {
      updateChild(_childElements[index], null, index);
    });
    _childElements.remove(index);
  }

  @override
  void forgetChild(Element child) {
    final index = (child.renderObject!.parentData! as _WatchAppGridLayoutParentData).index;
    _childElements.remove(index);
    super.forgetChild(child);
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    renderObject.remove(child as RenderBox);
  }

  @override
  void didFinishLayout() {}

  @override
  void visitChildren(ElementVisitor visitor) {
    _childElements.values.forEach(visitor);
  }
}

class RenderWatchAppGridLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _WatchAppGridLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _WatchAppGridLayoutParentData> {
  RenderWatchAppGridLayout({required LazyChildDelegate childManager, required WatchAppGridController controller})
    : _lazyChildDelegate = childManager,
      _controller = controller {
    _controller.addListener(_handleControllerChanged);
  }

  final LazyChildDelegate _lazyChildDelegate;

  WatchAppGridController _controller;
  WatchAppGridController get controller => _controller;
  set controller(WatchAppGridController value) {
    if (value == _controller) {
      return;
    }
    _controller.removeListener(_handleControllerChanged);
    _controller = value;
    _controller.addListener(_handleControllerChanged);
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  // Mirrors what the widget layer used to do on every controller
  // notification (rebuild, which pushed fresh offsets into setters that
  // called markNeedsLayout/markNeedsSemanticsUpdate) — except the render
  // object now listens directly, so a scroll tick no longer has to rebuild
  // the whole widget subtree just to reach this layout.
  void _handleControllerChanged() {
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! _WatchAppGridLayoutParentData) {
      child.parentData = _WatchAppGridLayoutParentData();
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.biggest;
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    _lazyChildDelegate.didStartLayout();

    final double verticalOffset = _controller.verticalOffset;
    final double horizontalOffset = _controller.horizontalOffset;

    // 3-4-3-4 Apple Watch honeycomb.
    // Every group of 7 icons fills two rows: 3 (even row) + 4 (odd row).
    //   Even row centers: W/4,  W/2,  3W/4          (xStart = cellWidth/2)
    //   Odd  row centers: W/8, 3W/8, 5W/8, 7W/8     (xStart = 0)
    const int evenRowColumns = 3;
    const int oddRowColumns = 4;

    final double cellWidth = size.width / oddRowColumns;
    final double rowHeight = cellWidth * sqrt(3) / 2;
    final double iconSize = cellWidth * 0.87;
    final double cx = size.width / 2.0;
    final double cy = size.height / 2.0;

    // The central 40% of the screen renders icons at full size; beyond that,
    // icons shrink toward zero as the normalized distance approaches dMax
    // (see the falloff below). Because a row's vertical distance doesn't
    // depend on column or horizontal offset, a row whose |ny| already
    // exceeds dMax is guaranteed to have every icon in it at scale == 0 —
    // which lets rows entirely outside the viewport be skipped below instead
    // of built and laid out just to render at zero size.
    const double innerRadius = 0.4;
    final double dMax = 2.0 - innerRadius;

    final int? maxCount = _lazyChildDelegate.childCount;

    // If the total icon count isn't a multiple of a full row, the final row
    // has fewer icons than its row size (3 for an even row, 4 for an odd
    // row). Precompute which row that is and how many icons it holds so
    // those icons can be centered within the row instead of packed to the
    // leading edge.
    int? lastRowIndex;
    int? lastRowCount;
    if (maxCount != null && maxCount > 0) {
      final int lastItemIndex = maxCount - 1;
      final int lastItemGroup = lastItemIndex ~/ 7;
      final int lastItemRem = lastItemIndex % 7;
      lastRowIndex = lastItemRem < evenRowColumns ? 2 * lastItemGroup : 2 * lastItemGroup + 1;
      lastRowCount = (lastItemRem < evenRowColumns ? lastItemRem : lastItemRem - evenRowColumns) + 1;
    }

    // First index of a group's row, given the row number.
    int firstIndexOfRow(int row) => row.isEven ? (row ~/ 2) * 7 : ((row - 1) ~/ 2) * 7 + evenRowColumns;

    // Smallest row whose grid-space center could land within dMax of the
    // (scroll-shifted) viewport center; every row above it is guaranteed to
    // be entirely invisible. One row of margin is kept to stay clear of
    // floating-point edge cases at the boundary.
    final double lowestVisibleY = verticalOffset + cy * (1.0 - dMax);
    final int rowMin = max(0, ((lowestVisibleY - rowHeight / 2.0) / rowHeight).floor() - 1);
    final int firstVisibleIndex = firstIndexOfRow(rowMin);

    // Evict children that have scrolled above the new window *before*
    // building anything. Slots below are tracked as "the previous sibling
    // RenderBox", by reference; if a stale child were left in place while
    // the loop below moves the new first child to the head of the list, the
    // stale child's removal would silently reparent the children after it
    // without their recorded slot changing, desyncing the list from what
    // the loop below believes it built and eventually asserting.
    RenderBox? leading = firstChild;
    while (leading != null) {
      final leadingData = leading.parentData! as _WatchAppGridLayoutParentData;
      final next = childAfter(leading);
      if (leadingData.index == null || leadingData.index! < firstVisibleIndex) {
        invokeLayoutCallback<BoxConstraints>((_) {
          _lazyChildDelegate.removeChildDuringLayout(leading!);
        });
      }
      leading = next;
    }

    RenderBox? precedingChild;
    int index = firstVisibleIndex;

    while (maxCount == null || index < maxCount) {
      // Map linear index → (row, col) in the 3-4-3-4 pattern.
      final int group = index ~/ 7;
      final int rem = index % 7;
      final int row = rem < evenRowColumns ? 2 * group : 2 * group + 1;
      final int col = rem < evenRowColumns ? rem : rem - evenRowColumns;

      // Rows increase monotonically with index, so once a row has scrolled
      // far enough past the bottom of the viewport to guarantee scale == 0,
      // every later row will too — stop instead of building icons nobody
      // can see.
      final double rowViewY = row * rowHeight + rowHeight / 2.0 - verticalOffset;
      if ((rowViewY - cy) / cy > dMax) {
        break;
      }

      bool hasChildAtIndex = false;
      invokeLayoutCallback<BoxConstraints>((_) {
        hasChildAtIndex = _lazyChildDelegate.createOrUpdateChildDuringLayout(index, after: precedingChild);
      });

      if (!hasChildAtIndex) {
        break;
      }

      final RenderBox? child = precedingChild == null ? firstChild : childAfter(precedingChild);
      assert(
        child != null,
        'createOrUpdateChildDuringLayout reported success but no child render '
        'object was found at index $index.',
      );
      if (child == null) {
        break;
      }

      final parentData = child.parentData! as _WatchAppGridLayoutParentData;
      parentData.index = index;

      // Grid-space centre of this icon. A full row is centered by
      // construction (evenRowColumns/oddRowColumns icons within
      // oddRowColumns cells); a partial final row is centered the same way,
      // just using however many icons it actually holds.
      final int rowSize = row.isOdd ? oddRowColumns : evenRowColumns;
      final int effectiveRowSize = (row == lastRowIndex && lastRowCount != null) ? lastRowCount : rowSize;
      final double xStart = (size.width - effectiveRowSize * cellWidth) / 2.0;
      final double gridX = xStart + col * cellWidth + cellWidth / 2;
      final double gridY = row * rowHeight + rowHeight / 2;

      // Viewport-space centre: apply scroll offsets.
      final double viewX = gridX + horizontalOffset;
      final double viewY = gridY - verticalOffset;

      // Distance vector from screen center.
      final double dx = viewX - cx;
      final double dy = viewY - cy;

      // Normalize distance by the respective screen dimensions.
      final double nx = dx / cx;
      final double ny = dy / cy;

      // Calculate superellipse distance (Minkowski distance with p=4).
      final double nx2 = nx * nx;
      final double ny2 = ny * ny;
      final double nx4 = nx2 * nx2;
      final double ny4 = ny2 * ny2;

      // DO NOT clamp to 1.0 here! We must evaluate virtual points outside
      // the screen bounds so they can be pulled inward to fill the edges.
      final double d = pow(nx4 + ny4, 0.25).toDouble();

      double scale = 1.0;
      double dPrime = d;

      if (d > innerRadius) {
        // The integral of our easing curve from 0 to 1 equals 0.5.
        // This means the displacement mathematically compresses the falloff zone by half.
        // To ensure the grid still reaches the screen edge (dPrime = 1.0) when scale drops to 0,
        // we must stretch the virtual falloff zone (dMax) to compensate.
        final double range = dMax - innerRadius;

        // Now we clamp the interpolation factor, not the raw distance.
        final double t = ((d - innerRadius) / range).clamp(0.0, 1.0);

        // Scaling easing curve.
        final double smooth = t * t * (3.0 - 2.0 * t);
        scale = 1.0 - smooth;

        // Integrate the scale curve to calculate the new compressed distance.
        // Integral of (1 - 3t^2 + 2t^3) is (t - t^3 + 0.5t^4).
        final double integral = t - (t * t * t) + 0.5 * (t * t * t * t);
        dPrime = innerRadius + range * integral;
      }

      final double scaledSize = iconSize * scale;

      // Radially displace the coordinates inward.
      final double ratio = d == 0.0 ? 0.0 : (dPrime / d);
      final double finalX = cx + (dx * ratio);
      final double finalY = cy + (dy * ratio);

      child.layout(BoxConstraints.tight(Size(scaledSize, scaledSize)));
      parentData.offset = Offset(finalX - scaledSize / 2, finalY - scaledSize / 2);

      precedingChild = child;
      index++;
    }

    // Remove any previously-live children that are no longer within the
    // built range: scrolled out above firstVisibleIndex, scrolled out below
    // where the loop stopped, or beyond a shrunk childCount.
    RenderBox? stale = firstChild;
    while (stale != null) {
      final staleData = stale.parentData as _WatchAppGridLayoutParentData;
      final next = childAfter(stale);
      if (staleData.index == null || staleData.index! < firstVisibleIndex || staleData.index! >= index) {
        invokeLayoutCallback<BoxConstraints>((_) {
          _lazyChildDelegate.removeChildDuringLayout(stale!);
        });
      }
      stale = next;
    }

    _lazyChildDelegate.didFinishLayout();

    // Report scroll extent to the controller. This reflects the extent of
    // the whole list, not just the (now partial) range built above, so it's
    // derived from the total childCount rather than the loop's final index.
    if (lastRowIndex != null) {
      final double contentHeight = (lastRowIndex + 1) * rowHeight + 2.0;
      final double firstRowCenterOffset = rowHeight / 2.0 - cy;
      final double previousMaxScrollExtent = _controller.maxScrollExtent;
      _controller.reportScrollExtent(
        contentHeight: contentHeight,
        viewportHeight: size.height,
        rowHeight: rowHeight,
        firstRowCenterOffset: firstRowCenterOffset,
      );
      if (_controller.maxScrollExtent != previousMaxScrollExtent) {
        markNeedsSemanticsUpdate();
      }
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    // This grid only truly scrolls vertically — horizontal offset is a
    // rubber-band tilt that always springs back to 0, not a way to reach
    // different content — so only the vertical axis is reported here.
    final double maxScrollExtent = _controller.maxScrollExtent;
    config
      ..isSemanticBoundary = true
      ..scrollPosition = _controller.verticalOffset
      ..scrollExtentMin = 0.0
      ..scrollExtentMax = maxScrollExtent
      ..scrollChildCount = _lazyChildDelegate.childCount;
    if (maxScrollExtent > 0.0) {
      config
        ..hasImplicitScrolling = true
        ..onScrollToOffset = (Offset targetOffset) => _controller.jumpTo(targetOffset.dy);
    }
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  void debugPaint(PaintingContext context, Offset offset) {
    assert(() {
      if (!debugPaintSizeEnabled) return true;
      final Paint crosshair = Paint()
        ..color = const Color(0xFFFF0000)
        ..strokeWidth = 1.0;
      final double cx = offset.dx + size.width / 2;
      final double cy = offset.dy + size.height / 2;
      context.canvas.drawLine(Offset(offset.dx, cy), Offset(offset.dx + size.width, cy), crosshair);
      context.canvas.drawLine(Offset(cx, offset.dy), Offset(cx, offset.dy + size.height), crosshair);
      return true;
    }());
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('childCount', childCount));
    properties.add(DoubleProperty('verticalOffset', _controller.verticalOffset));
    properties.add(DoubleProperty('horizontalOffset', _controller.horizontalOffset));
  }
}

class _WatchAppGridLayoutParentData extends ContainerBoxParentData<RenderBox> {
  int? index;
  double? layoutOffset;
}

/// Interface between [RenderWatchAppGridLayout] and [WatchAppGridElement] for
/// lazy child building during layout. Keeps the render object from calling
/// arbitrary Element methods that could corrupt the widget tree.
abstract interface class LazyChildDelegate {
  /// Total item count, or null if unbounded.
  int? get childCount;

  /// Build or update the child at [index], inserting it after [after].
  /// Returns true if a child was produced, false if the builder returned null.
  bool createOrUpdateChildDuringLayout(int index, {required RenderBox? after});

  /// Unmount and remove [child] from the tree.
  void removeChildDuringLayout(RenderBox child);

  /// Called at the start of each layout pass.
  void didStartLayout();

  /// Called at the end of each layout pass.
  void didFinishLayout();
}

class WatchAppGridController extends ChangeNotifier {
  double _verticalOffset = 0.0;
  double _horizontalOffset = 0.0;
  double _maxScrollExtent = 0.0;
  double _rowHeight = 1.0;
  double _firstRowCenterOffset = 0.0;
  bool _hasInitializedOffset = false;

  double get verticalOffset => _verticalOffset;
  double get horizontalOffset => _horizontalOffset;
  double get maxScrollExtent => _maxScrollExtent;

  static const double _kOverscrollFriction = 0.5;
  static const double _kHorizontalFriction = 0.3;

  TickerProvider? _vsync;
  AnimationController? _verticalFling;
  AnimationController? _horizontalSpring;

  void attach(TickerProvider vsync) {
    assert(_vsync == null, 'WatchAppGridController is already attached.');
    _vsync = vsync;
    _verticalFling = AnimationController.unbounded(vsync: vsync)..addListener(_onVerticalTick);
    _horizontalSpring = AnimationController.unbounded(vsync: vsync)..addListener(_onHorizontalTick);
  }

  void detach() {
    _verticalFling?.dispose();
    _horizontalSpring?.dispose();
    _verticalFling = null;
    _horizontalSpring = null;
    _vsync = null;
  }

  // Called by the render object at the end of every performLayout so the
  // controller knows the scroll bounds. Safe to call from within performLayout.
  void reportScrollExtent({
    required double contentHeight,
    required double viewportHeight,
    required double rowHeight,
    required double firstRowCenterOffset,
  }) {
    _rowHeight = rowHeight;
    _firstRowCenterOffset = firstRowCenterOffset;
    final double newMax = (contentHeight - viewportHeight).clamp(0.0, double.infinity);

    if (!_hasInitializedOffset) {
      _hasInitializedOffset = true;
      _maxScrollExtent = newMax;
      return;
    }

    if (newMax == _maxScrollExtent) {
      return;
    }
    _maxScrollExtent = newMax;
    if (_verticalOffset > _maxScrollExtent) {
      _verticalOffset = _maxScrollExtent;
      notifyListeners();
    }
  }

  // Invoked by assistive technology (e.g. iOS's VoiceOver focus engine) via
  // the render object's SemanticsAction.scrollToOffset handler.
  void jumpTo(double offset) {
    _verticalFling?.stop();
    _verticalOffset = offset.clamp(0.0, _maxScrollExtent);
    notifyListeners();
  }

  void applyScrollDelta(double dy) {
    _verticalFling?.stop();
    final double proposed = _verticalOffset + dy;
    if (_verticalOffset < 0.0) {
      _verticalOffset += dy * _kOverscrollFriction;
    } else if (_verticalOffset > _maxScrollExtent) {
      _verticalOffset += dy * _kOverscrollFriction;
    } else if (proposed < 0.0) {
      final double inBounds = -_verticalOffset;
      final double overBounds = dy - inBounds;
      _verticalOffset = overBounds * _kOverscrollFriction;
    } else if (proposed > _maxScrollExtent) {
      final double inBounds = _maxScrollExtent - _verticalOffset;
      final double overBounds = dy - inBounds;
      _verticalOffset = _maxScrollExtent + overBounds * _kOverscrollFriction;
    } else {
      _verticalOffset = proposed;
    }
    notifyListeners();
  }

  void applyHorizontalPanDelta(double dx) {
    _horizontalSpring?.stop();
    _horizontalOffset += dx * _kHorizontalFriction;
    notifyListeners();
  }

  void endPan({required Offset velocity}) {
    _verticalFling?.animateWith(
      _FlingSnapSimulation(
        position: _verticalOffset,
        velocity: -velocity.dy,
        leadingExtent: 0.0,
        trailingExtent: _maxScrollExtent,
        rowHeight: _rowHeight,
        firstRowCenterOffset: _firstRowCenterOffset,
      ),
    );

    _horizontalSpring?.animateWith(
      SpringSimulation(
        SpringDescription.withDampingRatio(mass: 1.0, stiffness: 300.0, ratio: 0.8),
        _horizontalOffset,
        0.0,
        velocity.dx * _kHorizontalFriction,
      ),
    );
  }

  void _onVerticalTick() {
    _verticalOffset = _verticalFling!.value;
    notifyListeners();
  }

  void _onHorizontalTick() {
    _horizontalOffset = _horizontalSpring!.value;
    notifyListeners();
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }
}

// Runs a ClampingScrollSimulation until its velocity drops below a threshold,
// then hands off seamlessly to a SpringSimulation that snaps to the nearest row.
// Because the handoff carries the live velocity, the two phases form one
// continuous curve with no perceptible gap or stutter.
class _FlingSnapSimulation extends Simulation {
  _FlingSnapSimulation({
    required double position,
    required double velocity,
    required double leadingExtent,
    required double trailingExtent,
    required double rowHeight,
    required double firstRowCenterOffset,
  }) : _fling = ClampingScrollSimulation(position: position, velocity: velocity, friction: _kFlingFriction),
       _rowHeight = rowHeight,
       _firstRowCenterOffset = firstRowCenterOffset,
       _leadingExtent = leadingExtent,
       _trailingExtent = trailingExtent;

  static const double _kFlingFriction = 0.025;
  static const double _kSnapVelocityThreshold = 200.0;

  final ClampingScrollSimulation _fling;
  final double _rowHeight;
  final double _firstRowCenterOffset;
  final double _leadingExtent;
  final double _trailingExtent;

  SpringSimulation? _snap;
  double _snapStartTime = 0.0;

  // Snaps in the momentum direction: ceil when moving forward, floor when
  // moving backward, round when stopped. This prevents the jarring backward
  // snap that round() causes when the fling slows and the nearest row is
  // behind the direction of travel.
  double _nearestRowOffset(double position, double velocity) {
    final double rFloat = (position - _firstRowCenterOffset) / _rowHeight;
    final int targetRow;
    if (velocity > 0) {
      targetRow = rFloat.ceil().toInt();
    } else if (velocity < 0) {
      targetRow = rFloat.floor().toInt();
    } else {
      targetRow = rFloat.round();
    }
    return (_firstRowCenterOffset + targetRow * _rowHeight).clamp(_leadingExtent, _trailingExtent);
  }

  void _maybeStartSnap(double time) {
    if (_snap != null) return;
    final double pos = _fling.x(time);
    final double vel = _fling.dx(time);
    // ClampingScrollSimulation has no notion of bounds, so once the fling
    // carries the position past the leading/trailing extent it would keep
    // coasting there under low friction. Cut the fling short the instant it
    // crosses a bound so the spring-back starts immediately instead of after
    // a long, distant overscroll.
    final bool outOfBounds = pos < _leadingExtent || pos > _trailingExtent;
    if (outOfBounds || vel.abs() < _kSnapVelocityThreshold || _fling.isDone(time)) {
      _snapStartTime = time;
      _snap = SpringSimulation(
        SpringDescription.withDampingRatio(mass: 1.0, stiffness: 400.0, ratio: 0.9),
        pos,
        _nearestRowOffset(pos, vel),
        vel,
      );
    }
  }

  @override
  double x(double time) {
    _maybeStartSnap(time);
    if (_snap != null) return _snap!.x(time - _snapStartTime);
    return _fling.x(time);
  }

  @override
  double dx(double time) {
    _maybeStartSnap(time);
    if (_snap != null) return _snap!.dx(time - _snapStartTime);
    return _fling.dx(time);
  }

  @override
  bool isDone(double time) {
    _maybeStartSnap(time);
    if (_snap != null) return _snap!.isDone(time - _snapStartTime);
    return false;
  }
}
