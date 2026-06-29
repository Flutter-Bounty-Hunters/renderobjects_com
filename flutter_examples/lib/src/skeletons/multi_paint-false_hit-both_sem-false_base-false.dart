import 'package:flutter/rendering.dart';

// TODO: Write useful Dart Docs for this custom render object.
// Configuration: children=multi, paint=false, hit_test=both, semantics=false, baseline=false
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
  bool hitTestSelf(Offset position) {
    // TODO: Return `true` if this render object can be interacted with.
    return false;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
    // TODO: Implement hit-testing delegation to children (or delete this method).
    return super.hitTestChildren(result, position: position);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    // TODO: Report important info that's specific to this Render Object (or delete this method).
  }
}
