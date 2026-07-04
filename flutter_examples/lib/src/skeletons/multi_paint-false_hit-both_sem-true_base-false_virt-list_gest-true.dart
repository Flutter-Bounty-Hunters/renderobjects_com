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
  final Widget? Function(BuildContext context, int index) builder;

  @override
  MyElement createElement() => MyElement(this);

  @override
  MyRenderObject createRenderObject(BuildContext context) {
    return MyRenderObject(childManager: context as _LazyChildDelegate);
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

class MyElement extends RenderObjectElement implements _LazyChildDelegate {
  MyElement(super.widget);

  final Map<int, Element> _childElements = {};

  @override
  MyRenderObject get renderObject => super.renderObject as MyRenderObject;

  @override
  int? get childCount => (widget as MyWidget).childCount;

  @override
  void insertRenderObjectChild(RenderObject child, Object? slot) {
    renderObject.insert(child as RenderBox, after: slot as RenderBox?);
  }

  @override
  void moveRenderObjectChild(RenderObject child, Object? oldSlot, Object? newSlot) {
    renderObject.move(child as RenderBox, after: newSlot as RenderBox?);
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
  void didStartLayout() {
    // TODO: Take an action when the render object starts layout, or leave as a no-op.
  }

  @override
  void createChildDuringLayout(int index, {required RenderBox? after}) {
    owner!.buildScope(this, () {
      final newChild = updateChild(
        _childElements[index],
        (widget as MyWidget).builder(this, index),
        after,
      );
      if (newChild != null) {
        _childElements[index] = newChild;
      } else {
        _childElements.remove(index);
      }
    });
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
  MyRenderObject({required _LazyChildDelegate childManager})
      : _lazyChildDelegate = childManager;

  final _LazyChildDelegate _lazyChildDelegate;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! MyParentData) {
      child.parentData = MyParentData();
    }
  }

  @override
  void performLayout() {
    _lazyChildDelegate.didStartLayout();
    // TODO: Determine which child indices are visible given the current
    //       scroll offset and viewport extent.
    // TODO: For each visible index, call _lazyChildDelegate.createChildDuringLayout(index, after: precedingChild)
    //       if that child is not already live.
    // TODO: Lay out each live child.
    // TODO: Remove off-screen children via _lazyChildDelegate.removeChildDuringLayout(child).
    _lazyChildDelegate.didFinishLayout();
    size = constraints.biggest;
  }

  @override
  bool hitTestSelf(Offset position) {
    // TODO: Return `true` if this render object can be interacted with.
    return false;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
    return defaultHitTestChildren(result, position: position);
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
abstract interface class _LazyChildDelegate {
  /// Called by the render object to determine how many children exist in the data source,
  /// or null if the count is unknown; the element should return the widget's childCount.
  int? get childCount;

  /// Called by the render object when a child at [index] needs to become visible; the element
  /// should build and insert that child into the tree after [after].
  void createChildDuringLayout(int index, {required RenderBox? after});

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
