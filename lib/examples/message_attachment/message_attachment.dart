import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// An attachment thumbnail, with an "x" button to remove the attachment.
class MessageAttachment extends SingleChildRenderObjectWidget {
  const MessageAttachment({super.key, this.onThumbnailTap, required this.onRemoveTap, required super.child});

  final VoidCallback? onThumbnailTap;
  final VoidCallback onRemoveTap;

  @override
  RenderMessageAttachment createRenderObject(BuildContext context) {
    return RenderMessageAttachment(
      onThumbnailTap: onThumbnailTap,
      onRemoveTap: onRemoveTap,
      textDirection: Directionality.of(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderMessageAttachment renderObject) {
    renderObject
      ..onThumbnailTap = onThumbnailTap
      ..onRemoveTap = onRemoveTap
      ..textDirection = Directionality.of(context);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(ObjectFlagProperty<VoidCallback?>.has('onThumbnailTap', onThumbnailTap))
      ..add(ObjectFlagProperty<VoidCallback>.has('onRemoveTap', onRemoveTap));
  }
}

class RenderMessageAttachment extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
  static const Radius _thumbnailCornerRadius = Radius.circular(12.0);

  static const double _removeButtonDiameter = 24.0;
  static const double _removeButtonRadius = _removeButtonDiameter / 2;

  // The distance down, and to the left, that he "remove button" circle overlaps the
  // top right corner of the thumbnail.
  static const double _removeButtonInset = 4.0;

  // The circular "remove button" partially overlaps the thumbnail, and partially
  // extends beyond the thumbnail - this is the distance the "remove button" extends
  // beyond the boundary of the thumbnail.
  //
  // The bounds of this render object is defined as the thumbnail bounds, plus this
  // distance on all 4 sides. Even though the "remove button" only pushes out to the
  // top and the right, we add this on all 4 sides for symmetry.
  static const double _removeButtonOverflowDistance = _removeButtonRadius - _removeButtonInset;

  // We extend the tap radius of the "remove button" beyond the painted
  // bounds so that it's not too small to touch.
  static const double _removeButtonHitRadius = _removeButtonRadius + 8;

  RenderMessageAttachment({
    VoidCallback? onThumbnailTap,
    VoidCallback? onRemoveTap,
    required TextDirection textDirection,
  }) : _onThumbnailTap = onThumbnailTap,
       _onRemoveTap = onRemoveTap,
       _textDirection = textDirection {
    _tap = TapGestureRecognizer()..onTapUp = _handleTapUp;
  }

  late final TapGestureRecognizer _tap;

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) {
      return;
    }
    _textDirection = value;
    markNeedsSemanticsUpdate();
  }

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  VoidCallback? _onThumbnailTap;
  set onThumbnailTap(VoidCallback? value) {
    if (_onThumbnailTap == value) {
      return;
    }
    _onThumbnailTap = value;
    markNeedsSemanticsUpdate();
  }

  VoidCallback? _onRemoveTap;
  set onRemoveTap(VoidCallback? value) {
    if (_onRemoveTap == value) {
      return;
    }
    _onRemoveTap = value;
    markNeedsSemanticsUpdate();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => child != null
      ? constraints.constrain(
          child!.getDryLayout(constraints.deflate(const EdgeInsets.all(_removeButtonOverflowDistance))) +
              const Offset(_removeButtonOverflowDistance * 2, _removeButtonOverflowDistance * 2),
        )
      : constraints.smallest;

  @override
  double computeMinIntrinsicWidth(double height) => child != null
      ? child!.getMinIntrinsicWidth((height - _removeButtonOverflowDistance * 2).clamp(0.0, double.infinity)) +
            _removeButtonOverflowDistance * 2
      : 0;

  @override
  double computeMaxIntrinsicWidth(double height) => child != null
      ? child!.getMaxIntrinsicWidth((height - _removeButtonOverflowDistance * 2).clamp(0.0, double.infinity)) +
            _removeButtonOverflowDistance * 2
      : 0;

  @override
  double computeMinIntrinsicHeight(double width) => child != null
      ? child!.getMinIntrinsicHeight((width - _removeButtonOverflowDistance * 2).clamp(0.0, double.infinity)) +
            _removeButtonOverflowDistance * 2
      : 0;

  @override
  double computeMaxIntrinsicHeight(double width) => child != null
      ? child!.getMaxIntrinsicHeight((width - _removeButtonOverflowDistance * 2).clamp(0.0, double.infinity)) +
            _removeButtonOverflowDistance * 2
      : 0;

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }

    // Layout the thumbnail child, but subtract the gap that we need for the "x" button
    // to slightly sit outside the thumbnail bounds.
    child.layout(constraints.deflate(const EdgeInsets.all(_removeButtonOverflowDistance)), parentUsesSize: true);

    // The "x" button sits slightly beyond the thumbnail bounds. We add this overflow gap
    // on all 4 sides of the thumbnail. So we need to position the thumbnail down, and to
    // the left, by that amount.
    (child.parentData! as BoxParentData).offset = const Offset(
      _removeButtonOverflowDistance,
      _removeButtonOverflowDistance,
    );

    // Our size is the size of the thumbnail, plus the "x" button overflow distance, added
    // to all 4 sides.
    size = constraints.constrain(
      Size(child.size.width + _removeButtonOverflowDistance * 2, child.size.height + _removeButtonOverflowDistance * 2),
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (size.contains(position)) {
      // Delegate to `hitTestSelf()` and `hitTestChildren()`.
      return super.hitTest(result, position: position);
    }

    if (_isWithinRemoveButtonHitArea(position)) {
      // Hit test location is outside our standard `RenderBox` bounds, but
      // the hit test location might still hit our circular "x" button because
      // the "x" button hit area is larger than its paint area.
      result.add(BoxHitTestEntry(this, position));
      return true;
    }

    return false;
  }

  @override
  bool hitTestSelf(Offset position) {
    if (child == null) {
      return false;
    }

    // Return `true` if the position is inside the thumbnail, or within the hit
    // area of the "x" button.
    return _thumbnailRRect!.contains(position) || _isWithinRemoveButtonHitArea(position);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => child != null
      ? result.addWithPaintOffset(
          offset: (child!.parentData! as BoxParentData).offset,
          position: position,
          hitTest: (result, transformed) => child!.hitTest(result, position: transformed),
        )
      : false;

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      _tap.addPointer(event);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    final Offset local = details.localPosition;

    if (_isWithinRemoveButtonHitArea(local)) {
      _onRemoveTap?.call();
      return;
    }

    final thumbnailRRect = _thumbnailRRect;
    if (thumbnailRRect != null && thumbnailRRect.contains(local)) {
      _onThumbnailTap?.call();
    }
  }

  bool _isWithinRemoveButtonHitArea(Offset position) {
    final buttonCenter = _buttonCenter;
    return buttonCenter != null &&
        (position - buttonCenter).distanceSquared <= _removeButtonHitRadius * _removeButtonHitRadius;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    final childRect = _thumbnailRect;
    if (child == null || childRect == null) {
      layer = null;
      return;
    }

    final childParentData = child.parentData! as BoxParentData;
    final Offset buttonCenter = _buttonCenter!;
    // Punch the remove button's circle out of the thumbnail's clip so the
    // child never paints underneath it.
    final Path clipPath = Path.combine(
      PathOperation.difference,
      Path()..addRRect(_thumbnailRRect!),
      Path()..addOval(Rect.fromCircle(center: buttonCenter, radius: _removeButtonHitRadius)),
    );
    layer = context.pushClipPath(
      needsCompositing,
      offset,
      childRect,
      clipPath,
      (context, offset) => context.paintChild(child, offset + childParentData.offset),
      oldLayer: layer as ClipPathLayer?,
    );

    _paintRemoveButton(context, offset + buttonCenter);
  }

  // Centered on the top-right corner, so it sits half on the thumbnail and half off it.
  void _paintRemoveButton(PaintingContext context, Offset center) {
    final canvas = context.canvas;

    canvas.drawCircle(center, _removeButtonRadius, Paint()..color = const Color(0xFF000000));

    const double crossArm = _removeButtonRadius * 0.35;
    final Paint crossPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center + const Offset(-crossArm, -crossArm), center + const Offset(crossArm, crossArm), crossPaint);
    canvas.drawLine(center + const Offset(-crossArm, crossArm), center + const Offset(crossArm, -crossArm), crossPaint);
  }

  @override
  void debugPaint(PaintingContext context, Offset offset) {
    super.debugPaint(context, offset);

    if (debugPaintSizeEnabled) {
      final thumbnailRRect = _thumbnailRRect;
      final buttonCenter = _buttonCenter;
      if (thumbnailRRect == null || buttonCenter == null) {
        return;
      }

      final Paint hitAreaPaint = Paint()
        ..color = const Color(0xFF00FF00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      // These mirror the exact shapes used for hit testing: the rounded
      // rect checked in `_handleTapUp`'s thumbnail branch, and the (larger
      // than the painted circle) radius checked in `_isWithinButtonHitArea`.
      context.canvas.drawRRect(thumbnailRRect.shift(offset), hitAreaPaint);
      context.canvas.drawCircle(offset + buttonCenter, _removeButtonHitRadius, hitAreaPaint);
    }
  }

  Rect? get _thumbnailRect {
    final child = this.child;
    if (child == null) {
      return null;
    }
    return (child.parentData! as BoxParentData).offset & child.size;
  }

  RRect? get _thumbnailRRect {
    final thumbnailRect = _thumbnailRect;
    return thumbnailRect == null ? null : RRect.fromRectAndRadius(thumbnailRect, _thumbnailCornerRadius);
  }

  Offset? get _buttonCenter {
    final childRect = _thumbnailRect;
    return childRect == null ? null : childRect.topRight + const Offset(-_removeButtonInset, _removeButtonInset);
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);

    // Force this render object to own a distinct SemanticsNode instead of
    // possibly merging upward into an ancestor's (which could silently drop
    // one of two conflicting `onTap` handlers, or trip the framework's
    // "incompatible configuration" assertion). Merge the child's semantics
    // (if it has any, e.g. an image label) down into this same node, since
    // a nested node under a generic "Attachment thumbnail" label would just
    // be a confusing extra stop for screen readers.
    config.isSemanticBoundary = true;
    config.isMergingSemanticsOfDescendants = true;

    if (_onThumbnailTap != null) {
      config.onTap = _onThumbnailTap;
    }

    // The remove button has no backing render object of its own — it's
    // custom-painted and custom-hit-tested by this render object — so its
    // action is exposed as a custom action on this same semantics node
    // rather than as a separate, independently-focusable node.
    config.textDirection = _textDirection;
    config.label = 'Attachment thumbnail';
    config.isButton = _onThumbnailTap != null;
    if (_onRemoveTap != null) {
      config.customSemanticsActions = <CustomSemanticsAction, VoidCallback>{
        const CustomSemanticsAction(label: 'Remove attachment'): _onRemoveTap!,
      };
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(ObjectFlagProperty<VoidCallback?>.has('onThumbnailTap', _onThumbnailTap))
      ..add(ObjectFlagProperty<VoidCallback>.has('onRemoveTap', _onRemoveTap))
      ..add(DiagnosticsProperty<Rect?>('thumbnailRect', _thumbnailRect, defaultValue: null))
      ..add(DiagnosticsProperty<Offset?>('buttonCenter', _buttonCenter, defaultValue: null))
      ..add(DoubleProperty('removeButtonHitRadius', _removeButtonHitRadius))
      ..add(EnumProperty<TextDirection>('textDirection', _textDirection));
  }
}
