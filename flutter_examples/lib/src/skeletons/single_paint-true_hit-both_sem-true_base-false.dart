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
  bool hitTestSelf(Offset position) {
    // TODO: Return `true` if this render object can be interacted with.
    return false;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
    return child?.hitTest(result, position: position) ?? false;
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
