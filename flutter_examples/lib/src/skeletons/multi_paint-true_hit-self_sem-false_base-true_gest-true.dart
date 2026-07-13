import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// TODO: Write useful Dart Docs for this custom widget.
class MyWidget extends MultiChildRenderObjectWidget {
  const MyWidget({super.key, super.children = const <Widget>[]});

  @override
  MyRenderObject createRenderObject(BuildContext context) {
    return MyRenderObject();
  }

  @override
  void updateRenderObject(BuildContext context, MyRenderObject renderObject) {
    // TODO: Pass updated properties to renderObject (or delete if there are no properties).
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    // TODO: Report important info that's specific to this widget (or delete this method).
  }
}

// TODO: Write useful Dart Docs for this custom render object.
class MyRenderObject extends RenderBox with ContainerRenderObjectMixin<RenderBox, ContainerBoxParentData<RenderBox>> {
  @override
  void setupParentData(RenderObject child) {
    // TODO: Replace with creation of custom parent data, or delete if BoxParentData is what you want
    super.setupParentData(child);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    // TODO: Compute and return the size this render object would take given [constraints],
    //       without performing actual layout. For any children, call child.getDryLayout()
    //       rather than child.layout(). If your size can't be determined without a real
    //       layout pass, delete this method — the base class handles that case gracefully.
    throw UnimplementedError();
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
    // TODO: Pick a size based on `constraints`.
    // TODO: Layout your children.
    RenderBox? child = firstChild;
    while (child != null) {
      child.layout(constraints, parentUsesSize: true);
      child = childAfter(child);
    }
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
  bool hitTestSelf(Offset position) {
    // TODO: Return `true` if this render object can be interacted with.
    return false;
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    // TODO: Handle pointer events (e.g., pass them to a gesture recognizer).
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // TODO: Paint your content.
    throw UnimplementedError();
  }

  @override
  void debugPaint(PaintingContext context, Offset offset) {
    super.debugPaint(context, offset);

    if (debugPaintSizeEnabled) {
      // TODO: Paint useful debug shapes/lines (or delete this method).
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    // TODO: Report important info that's specific to this Render Object (or delete this method).
  }
}
