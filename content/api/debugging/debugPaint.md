---
title: debugPaint()
description: Implement the debugPaint() method in a custom Render Object.
layout: api
order: 55
---
`debugPaint()` is called by the framework immediately after `paint()`, but only when `debugPaintSizeEnabled` or another debug painting flag is set. Override it to draw diagnostic overlays — bounding boxes, baselines, child slot outlines, padding regions — that help verify layout correctness without affecting release builds.

Everything drawn in `debugPaint()` is stripped from production: the method is guarded by `assert()` in the framework and the body is dead code in release mode.

The method receives the same `PaintingContext` and `Offset` as `paint()`. Draw directly onto `context.canvas` using `Paint` objects with distinctive colors. Avoid pushing new layers; stay on the current canvas.

## Default Implementation

The default implementation does nothing. Override it whenever your render object has internal geometry — padding regions, child slots, baselines, clip boundaries — that is invisible in normal painting but useful to verify during development.

```dart
@override
void debugPaint(PaintingContext context, Offset offset) {
  // Nothing by default.
}
```

## Bounding Box

Draw the render object's own bounds. Useful for confirming that `size` is what you expect and that the render object is positioned correctly within its parent.

```dart
@override
void debugPaint(PaintingContext context, Offset offset) {
  assert(() {
    context.canvas.drawRect(
      offset & size,
      Paint()
        ..color = const Color(0xFF00FFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    return true;
  }());
}
```

## Padding Region

Outline the padding insets to confirm that the inner content area and outer bounds are both sized correctly.

```dart
@override
void debugPaint(PaintingContext context, Offset offset) {
  assert(() {
    final Canvas canvas = context.canvas;
    final Paint outerPaint = Paint()
      ..color = const Color(0xFF00FFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final Paint innerPaint = Paint()
      ..color = const Color(0xFFFF9800)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Outer bounds.
    canvas.drawRect(offset & size, outerPaint);
    // Inner content area after padding.
    canvas.drawRect(_padding.deflateRect(offset & size), innerPaint);
    return true;
  }());
}
```

## Child Slot Outlines

For slotted render objects — those with named child slots such as a leading icon, title, and trailing action — draw each occupied slot's bounds to verify placement.

```dart
@override
void debugPaint(PaintingContext context, Offset offset) {
  assert(() {
    final Paint slotPaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    if (_leading != null) {
      final BoxParentData pd = _leading!.parentData! as BoxParentData;
      context.canvas.drawRect(
        (offset + pd.offset) & _leading!.size,
        slotPaint,
      );
    }
    if (_trailing != null) {
      final BoxParentData pd = _trailing!.parentData! as BoxParentData;
      context.canvas.drawRect(
        (offset + pd.offset) & _trailing!.size,
        slotPaint,
      );
    }
    return true;
  }());
}
```

## Baseline

Draw a horizontal line at the render object's reported baseline to confirm it aligns with neighboring content.

```dart
@override
void debugPaint(PaintingContext context, Offset offset) {
  assert(() {
    final double? baseline =
        getDistanceToBaseline(TextBaseline.alphabetic, onlyReal: true);
    if (baseline != null) {
      context.canvas.drawLine(
        Offset(offset.dx, offset.dy + baseline),
        Offset(offset.dx + size.width, offset.dy + baseline),
        Paint()
          ..color = const Color(0xFFFF4081)
          ..strokeWidth = 1.0,
      );
    }
    return true;
  }());
}
```

## Clip Boundary

Outline the region that the render object clips to, so you can see how much content is hidden.

```dart
@override
void debugPaint(PaintingContext context, Offset offset) {
  assert(() {
    context.canvas.drawRRect(
      _clipRRect.shift(offset),
      Paint()
        ..color = const Color(0xFFE040FB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    return true;
  }());
}
```
