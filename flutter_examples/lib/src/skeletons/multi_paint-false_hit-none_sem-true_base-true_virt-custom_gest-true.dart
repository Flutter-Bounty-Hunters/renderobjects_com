import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// TODO: Write useful Dart Docs for this custom widget.
class MyWidget extends RenderObjectWidget {
  const MyWidget({
    super.key,
    this.childCount,
    required this.builder,
  });

  final int? childCount;
  final Widget? Function(BuildContext context, ChildIndex index) builder;

  @override
  MyElement createElement() => MyElement(this);

  @override
  MyRenderObject createRenderObject(BuildContext context) {
    return MyRenderObject(childManager: context as LazyChildDelegate);
  }

  @override
  void updateRenderObject(BuildContext context, MyRenderObject renderObject) {
    // TODO: Pass updated properties to renderObject (or delete if there are no properties).
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('childCount', childCount));
    // TODO: Report important info that's specific to this widget.
  }
}

// TODO: Add fields that coordinate between MyParentData (set by the render object
//       during layout) and the builder (called by the element during the build phase).
//       Common fields include a logical index, a data key, or layout information
//       such as scroll offset or slot size.
class ChildIndex {}

class MyElement extends RenderObjectElement implements LazyChildDelegate {
  MyElement(super.widget);

  final Map<int, Element> _childElements = {};

  @override
  MyRenderObject get renderObject => super.renderObject as MyRenderObject;

  @override
  int? get childCount => (widget as MyWidget).childCount;

  @override
  void didStartLayout() {
    // TODO: Take an action when the render object starts layout, or leave as a no-op.
  }

  @override
  void createOrUpdateChildDuringLayout(int index, {required RenderBox? after}) {
    owner!.buildScope(this, () {
      // TODO: Build the widget for this index via updateChild,
      //       passing `after` as the slot so the render object is inserted
      //       in the correct position.
    });
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
    final index = (child.parentData! as MyParentData).index!;
    owner!.buildScope(this, () {
      updateChild(_childElements[index], null, index);
    });
    _childElements.remove(index);
  }

  @override
  void forgetChild(Element child) {
    final index = (child.renderObject!.parentData! as MyParentData).index;
    _childElements.remove(index);
    super.forgetChild(child);
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    renderObject.remove(child as RenderBox);
  }

  @override
  void didFinishLayout() {
    // TODO: Take an action when the render object finishes layout, or leave as a no-op.
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    _childElements.values.forEach(visitor);
  }
}

// TODO: Write useful Dart Docs for this custom render object.
class MyRenderObject extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, MyParentData>, RenderBoxContainerDefaultsMixin<RenderBox, MyParentData> {
  MyRenderObject({required LazyChildDelegate childManager})
      : _lazyChildDelegate = childManager;

  final LazyChildDelegate _lazyChildDelegate;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! MyParentData) {
      child.parentData = MyParentData();
    }
  }

  // TODO: If possible, choose intrinsic widths/heights. By doing so, you expand the variety of places where
  //       this render object can be used (otherwise, delete these methods).
  @override
  double computeMinIntrinsicWidth(double height) => 0.0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0.0;

  @override
  double computeMinIntrinsicHeight(double width) => 0.0;

  @override
  double computeMaxIntrinsicHeight(double width) => 0.0;

  @override
  void performLayout() {
    _lazyChildDelegate.didStartLayout();

    // TODO: Compute the range of visible child indices based on the current
    //       scroll offset and viewport dimensions.
    final firstVisibleIndex = 0; // TODO
    final lastVisibleIndex = 0;  // TODO

    // We need to run build during layout. This normally isn't allowed by the framework. We call this method to tell
    // Flutter that we're intentionally running build during layout to avoid an error.
    invokeLayoutCallback((_) {
      // Build all visible children and lay them out.
      RenderBox? precedingChild;
      for (var index = firstVisibleIndex; index <= lastVisibleIndex; index++) {
        // Ask the Element to run a widget build for us during layout, which adds this widget's render object to our child list.
        _lazyChildDelegate.createOrUpdateChildDuringLayout(index, after: precedingChild);
        final child = precedingChild == null ? firstChild : childAfter(precedingChild);
        if (child != null) {
          // TODO: Lay out child and record its position in MyParentData.
          //       e.g. child.layout(constraints, parentUsesSize: true);
          precedingChild = child;
        }
      }

      // Remove any previously-live children that are no longer visible.
      RenderBox? child = firstChild;
      while (child != null) {
        final index = (child.parentData as MyParentData).index!;
        final next = childAfter(child);
        if (index < firstVisibleIndex || index > lastVisibleIndex) {
          // Ask the Element to remove this child's widget subtree during layout, which removes it from our child list.
          _lazyChildDelegate.removeChildDuringLayout(child);
        }
        child = next;
      }
    });

    _lazyChildDelegate.didFinishLayout();
    size = constraints.biggest;
  }

  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
    // TODO: If you're painting text, report the expected baseline position (or delete this method).
    return super.computeDryBaseline(constraints, baseline);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    // TODO: If you're painting text, report the baseline position (or delete this method).
    return super.computeDistanceToActualBaseline(baseline);
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    // TODO: Handle pointer events (e.g., pass them to a gesture recognizer).
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    // TODO: Describe additional semantic meaning of this render object (or delete this method).
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    // TODO: Report important info that's specific to this Render Object (or delete this method).
  }
}

class MyParentData extends ContainerBoxParentData<RenderBox> {
  int? index;
  double? layoutOffset;
}

/// Interface to coordinate lazy child building during layout between the `RenderObject`, which
/// runs layout, and its associated `Element`, which runs child builds.
///
/// This interface is typically implemented by a custom `Element`, and then that `Element`
/// is passed into the `RenderObject`. This prevents the `RenderObject` from calling all
/// sorts of unrelated methods on `Element` that might corrupt the trees.
abstract interface class LazyChildDelegate {
  /// Called by the render object to determine how many children exist in the data source,
  /// or null if the count is unknown; the element should return the widget's childCount.
  int? get childCount;

  /// Called by the render object when a child at [index] needs to become visible; the element
  /// should build and insert that child into the tree after [after].
  void createOrUpdateChildDuringLayout(int index, {required RenderBox? after});

  /// Called by the render object when [child] is no longer visible; the element should
  /// unmount and remove that child from the tree.
  void removeChildDuringLayout(RenderBox child);

  /// Called by the render object at the start of each layout pass; the element should reset
  /// any bookkeeping used to track which children were visited.
  void didStartLayout();

  /// Called by the render object at the end of each layout pass; the element should discard
  /// any children that were not visited during layout.
  void didFinishLayout();
}
