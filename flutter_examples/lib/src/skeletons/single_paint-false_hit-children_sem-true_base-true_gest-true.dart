import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// TODO: Write useful Dart Docs for this custom widget.
class MyWidget extends SingleChildRenderObjectWidget {
  const MyWidget({super.key, super.child});

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
class MyRenderObject extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
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
    // TODO: Layout your single child.
    final child = this.child;
    if (child != null) {
      child.layout(constraints, parentUsesSize: true);
      size = child.size;
    } else {
      size = constraints.biggest;
    }
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
    return child?.hitTest(result, position: position) ?? false;
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    // TODO: Handle pointer events (e.g., pass them to a gesture recognizer).
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    // TODO: Describe additional semantic meaning of this render object (or delete this method).
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) context.paintChild(child!, offset);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    // TODO: Report important info that's specific to this Render Object (or delete this method).
  }
}
