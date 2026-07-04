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
class MyRenderObject extends RenderBox with ContainerRenderObjectMixin<RenderBox, ContainerBoxParentData<RenderBox>>, RenderBoxContainerDefaultsMixin<RenderBox, ContainerBoxParentData<RenderBox>> {
  @override
  void setupParentData(RenderObject child) {
    // TODO: Replace with creation of custom parent data, or delete if BoxParentData is what you want
    super.setupParentData(child);
  }

  // TODO: Estimate your size given the `constraints`.
  @override
  Size computeDryLayout(BoxConstraints constraints) {
    throw UnimplementedError();
  }

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
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
    return defaultHitTestChildren(result, position: position);
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
    defaultPaint(context, offset);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    // TODO: Report important info that's specific to this Render Object (or delete this method).
  }
}
