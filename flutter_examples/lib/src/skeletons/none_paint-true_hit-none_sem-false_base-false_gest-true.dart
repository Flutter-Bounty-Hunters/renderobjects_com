import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// TODO: Write useful Dart Docs for this custom widget.
class MyWidget extends LeafRenderObjectWidget {
  const MyWidget({super.key});

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
class MyRenderObject extends RenderBox {
  @override
  Size computeDryLayout(BoxConstraints constraints) {
    // TODO: Compute and return the size this render object would take given [constraints],
    //       without performing actual layout. For any children, call child.getDryLayout()
    //       rather than child.layout(). If your size can't be determined without a real
    //       layout pass, delete this method — the base class handles that case gracefully.
    throw UnimplementedError();
  }

  @override
  void performLayout() {
    // TODO: Pick a size based on `constraints`.
    throw UnimplementedError();
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
