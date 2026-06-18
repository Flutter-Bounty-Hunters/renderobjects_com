---
title: paintBounds
description: Implement the paintBounds property in a custom Render Object.
layout: api
order: 31
---
`paintBounds` is a `Rect` that describes the region a render object may paint into, expressed in the render object's own local coordinate space. The framework uses it to decide which parts of the screen to repaint, to cull layers that are off-screen, and to size debug overlays in the widget inspector.

The value must be a conservative overestimate — it is safe to return a rect that is larger than necessary, but returning one that is too small will cause visible tearing as painted content outside the rect is not repainted when it should be.

Override `paintBounds` when your render object paints outside its layout box: drop shadows, glows, overflow text, or any transform that moves pixels beyond the box boundary.

## Default Implementation

`RenderBox` returns `Offset.zero & size` — exactly the layout box. This is correct for the vast majority of render objects that paint only within their own bounds.

```dart
// Default in RenderBox — no override needed for standard box content.
@override
Rect get paintBounds => Offset.zero & size;
```

## Drop Shadow

Expand the box outward by the shadow's spread to account for pixels the shadow paints outside the layout boundary.

```dart
static const double _shadowBlur = 12.0;
static const Offset _shadowOffset = Offset(0, 4);

@override
Rect get paintBounds {
  // Inflate by blur radius on all sides, then shift to cover the shadow offset.
  return (Offset.zero & size).expandToInclude(
    Offset(_shadowOffset.dx, _shadowOffset.dy) &
        Size(size.width + _shadowBlur * 2, size.height + _shadowBlur * 2),
  ).inflate(_shadowBlur);
}
```

A simpler approximation that is guaranteed to be a safe overestimate:

```dart
@override
Rect get paintBounds => (Offset.zero & size).inflate(_shadowBlur + _shadowOffset.distance);
```

## Painting Beyond the Box

When your render object deliberately draws outside its layout bounds — an overflow label, an indicator badge positioned at a corner — return a rect that covers all drawn content.

```dart
static const double _badgeRadius = 8.0;

@override
Rect get paintBounds {
  // Badge is centered on the top-right corner of the box.
  final Rect base = Offset.zero & size;
  final Rect badge = Rect.fromCircle(
    center: Offset(size.width, 0),
    radius: _badgeRadius,
  );
  return base.expandToInclude(badge);
}
```

## Transformed Content

When a child is painted with a rotation or scale that may push pixels outside the layout box, compute the axis-aligned bounding rect of the transformed box.

```dart
// _transform is a Matrix4 applied to the child during paint().
@override
Rect get paintBounds {
  // Map the four corners of the child through the transform and take
  // the bounding rect of the results.
  return MatrixUtils.transformRect(_transform, Offset.zero & size);
}
```

## No Painting

A render object that paints nothing — a pure layout node, a sizing proxy — can return `Rect.zero` to tell the framework there is nothing to repaint.

```dart
@override
Rect get paintBounds => Rect.zero;
```
