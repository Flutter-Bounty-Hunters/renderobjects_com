---
title: semanticBounds
description: Implement the semanticBounds property in a custom Render Object.
layout: api
order: 41
---
`semanticBounds` is a `Rect` that defines the region the accessibility framework associates with a semantic node, expressed in the render object's own local coordinate space. Screen readers use it to position highlight overlays, and the framework uses it to route accessibility gestures to the correct node.

Unlike `paintBounds`, which must be a conservative overestimate, `semanticBounds` should be accurate: it represents the region a user is logically interacting with, not the region that might receive a repaint.

Override `semanticBounds` when the logical accessibility region differs from the layout box — a small icon whose touch target should be larger, a padded container where only the inner content carries meaning, or a clipped render object where occluded area should not be reachable by assistive technology.

## Default Implementation

`RenderBox` returns `Offset.zero & size` — the layout box. This is correct for the vast majority of render objects.

```dart
// Default in RenderBox — no override needed for standard box content.
@override
Rect get semanticBounds => Offset.zero & size;
```

## Minimum Touch Target

Elements smaller than the platform-recommended minimum (48 × 48 logical pixels on Material platforms) should expand their semantic bounds so that assistive technology can reliably target them.

```dart
static const double _minTargetSize = 48.0;

@override
Rect get semanticBounds {
  return Rect.fromCenter(
    center: size.center(Offset.zero),
    width: size.width.clamp(_minTargetSize, double.infinity),
    height: size.height.clamp(_minTargetSize, double.infinity),
  );
}
```

## Content Area Only

When the render object has padding, border, or decorative chrome that should not be included in the semantic region, return the inner content rect.

```dart
// _padding is an EdgeInsets stored by the render object.
@override
Rect get semanticBounds => _padding.deflateRect(Offset.zero & size);
```

## Clipped Bounds

When the render object clips its content, the semantic region should cover only the visible portion so that assistive technology does not target occluded area.

```dart
// _clipRect is computed during performLayout() and used in paint().
@override
Rect get semanticBounds => _clipRect;
```

For a rounded clip, use the bounding rect of the clip shape:

```dart
@override
Rect get semanticBounds => _clipRRect.outerRect;
```

## No Semantic Region

A purely decorative or structural render object that carries no accessibility meaning should return `Rect.zero`. Pair it with `excludeFromSemantics` to ensure the node does not appear in the semantics tree at all.

```dart
@override
Rect get semanticBounds => Rect.zero;

@override
bool get excludeFromSemantics => true;
```
