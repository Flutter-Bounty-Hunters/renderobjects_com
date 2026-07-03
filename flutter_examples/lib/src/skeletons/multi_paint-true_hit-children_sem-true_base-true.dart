import 'package:flutter/widgets.dart';

// Configuration: children=multi, paint=true, hit_test=children, semantics=true, baseline=true

// TODO: Write useful Dart Docs for this custom widget.
class MyWidget extends MultiChildRenderObjectWidget {
  const MyWidget({super.key, super.children = const <Widget>[]});

  @override
  MyRenderObject createRenderObject(BuildContext context) {
    return MyRenderObject();
  }

  @override
  void updateRenderObject(BuildContext context, MyRenderObject renderObject) {
    // TODO: Pass updated properties to renderObject.
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
    // TODO: Ensure child.parentData is the correct type for your container.
    super.setupParentData(child);
  }

  // TODO: Estimate your size given the `constraints`.
  @override
  Size computeDryLayout(BoxConstraints constraints) {
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
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
    // TODO: Implement hit-testing delegation to children (or delete this method).
    return super.hitTestChildren(result, position: position);
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
