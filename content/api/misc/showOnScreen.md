---
title: showOnScreen()
description: Implement the showOnScreen() method in a custom Render Object.
layout: api
order: 60
---
`showOnScreen()` is called by the framework when a render object needs to be made visible — for example, when a screen reader focuses an item inside a scrollable list, when `Scrollable.ensureVisible()` is called, or when a focused text field is obscured by the keyboard. The render object is responsible for scrolling, animating, or otherwise adjusting its viewport so the target becomes visible.

The method receives an optional `descendant` render object (the specific node to reveal), a `rect` within that descendant's coordinate space, and `duration`/`curve` parameters for any animation.

## Default Implementation

`RenderObject` forwards the call up the tree by calling `showOnScreen()` on the nearest ancestor. This means the default behavior is correct for most render objects — they simply pass the request upward until something that owns a viewport handles it.

No override is needed unless your render object owns a scrollable viewport or clips its content in a way that can be programmatically adjusted.

```dart
@override
void showOnScreen({
  RenderObject? descendant,
  Rect? rect,
  Duration duration = Duration.zero,
  Curve curve = Curves.ease,
}) {
  // Default: delegate to the nearest ancestor.
  super.showOnScreen(
    descendant: descendant,
    rect: rect,
    duration: duration,
    curve: curve,
  );
}
```

## Scrollable Viewport

A render object that owns a scroll offset intercepts the call, computes how far it needs to scroll to reveal the target, and applies the new offset. After scrolling, it forwards the call upward so outer viewports can also reveal it if needed.

```dart
@override
void showOnScreen({
  RenderObject? descendant,
  Rect? rect,
  Duration duration = Duration.zero,
  Curve curve = Curves.ease,
}) {
  // Compute the target rect in this render object's local coordinate space.
  final Rect targetRect = descendant != null
      ? MatrixUtils.transformRect(
          descendant.getTransformTo(this),
          rect ?? descendant.paintBounds,
        )
      : rect ?? paintBounds;

  // Determine how much to scroll to bring the target into view.
  final double currentOffset = _scrollOffset;
  final double viewportHeight = size.height;
  double newOffset = currentOffset;

  if (targetRect.top < currentOffset) {
    newOffset = targetRect.top;
  } else if (targetRect.bottom > currentOffset + viewportHeight) {
    newOffset = targetRect.bottom - viewportHeight;
  }

  if (newOffset != currentOffset) {
    if (duration == Duration.zero) {
      _setScrollOffset(newOffset);
    } else {
      _animateScrollOffset(newOffset, duration: duration, curve: curve);
    }
  }

  // Let outer viewports reveal this render object in turn.
  super.showOnScreen(
    descendant: this,
    rect: targetRect.shift(Offset(0, -newOffset)),
    duration: duration,
    curve: curve,
  );
}
```

## Clipping Container

A render object that clips its children but has no scroll offset still needs to report the visible portion of the target rect to its ancestors, so they know how much to reveal.

```dart
@override
void showOnScreen({
  RenderObject? descendant,
  Rect? rect,
  Duration duration = Duration.zero,
  Curve curve = Curves.ease,
}) {
  // Intersect the requested rect with our clip bounds so ancestors only
  // try to reveal the portion that is actually visible through this clip.
  final Rect targetRect = descendant != null
      ? MatrixUtils.transformRect(
          descendant.getTransformTo(this),
          rect ?? descendant.paintBounds,
        )
      : rect ?? paintBounds;

  final Rect clippedRect = targetRect.intersect(Offset.zero & size);

  super.showOnScreen(
    descendant: this,
    rect: clippedRect,
    duration: duration,
    curve: curve,
  );
}
```

## Blocking the Request

Some render objects should prevent scroll-into-view requests from propagating — a modal dialog, for example, should not cause the content behind it to scroll when an element inside the dialog receives focus.

Intercept the call and do not forward it to `super`:

```dart
@override
void showOnScreen({
  RenderObject? descendant,
  Rect? rect,
  Duration duration = Duration.zero,
  Curve curve = Curves.ease,
}) {
  // If the target is inside this render object, handle it internally
  // and do not allow the request to escape to ancestors.
  if (descendant != null && isDescendantOf(descendant)) {
    // Scroll internally if needed, but do not call super.
    return;
  }
  super.showOnScreen(
    descendant: descendant,
    rect: rect,
    duration: duration,
    curve: curve,
  );
}
```
