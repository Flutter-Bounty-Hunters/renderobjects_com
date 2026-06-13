---
title: Hit Testing
description: Implement hit testing in custom render objects.
layout: guides
order: 35
---
# Implementing Hit Testing in a Custom Flutter Render Object

This guide walks experienced Flutter developers through the hit testing responsibilities of a custom `RenderObject`. By the end, you'll understand how Flutter routes pointer events through the render tree, what your render object's role is in that process, and how to implement hit testing correctly for both leaf and container render objects. We'll skip layout, painting, and gesture recognition itself — this is about hit testing, and only hit testing.

## What This Guide Covers

- **What Hit Testing Actually Is** — How Flutter turns a pointer position into a list of render objects that care.
- **The `hitTest` Method** — The entry point the framework calls to ask whether a point lands on you.
- **The `BoxHitTestResult`** — The accumulator you add yourself to when a hit lands.
- **Testing Yourself With `hitTestSelf`** — Declaring whether your own pixels are hittable, independent of children.
- **Testing Children With `hitTestChildren`** — Delegating the hit test to descendants and translating coordinates.
- **The Add-Order Rule** — Why the order in which entries are added to the result matters more than you'd expect.
- **Non-Rectangular Hit Regions** — Hit testing shapes that aren't axis-aligned rectangles.
- **Hit Testing Through Transforms and Layers** — Inverting transforms to map screen-space points into local space.
- **Hit Testing Outside Your Bounds** — When and how to accept hits that fall outside your size.
- **Performance Notes** — Small things that matter when hit testing runs on every pointer event.

## The `hitTest` Method

Hit testing for box render objects happens inside `hitTest(BoxHitTestResult result, {required Offset position})`. This is the single override the framework calls when a pointer event needs to know whether your render object is interested in it, and it's where most of your hit testing logic lives. A few related members exist outside `hitTest` — `hitTestSelf`, `hitTestChildren`, and (for transformed render objects) coordinate-inverting helpers — but they all support what happens during the hit test pass.

The default `RenderBox.hitTest` implementation does the right thing for the common case: it checks whether the position is inside your `size`, asks your children, asks yourself, and adds you to the result if either says yes. You usually don't override `hitTest` directly. Instead, you override the two methods it calls: `hitTestSelf` (does your own content care about this point?) and `hitTestChildren` (do any descendants care?). The rest of the guide focuses on those overrides and the surrounding details.

## What Hit Testing Actually Is

Hit testing is the process by which a single position — say, the coordinates of a tap — is converted into an ordered list of render objects that have declared interest in that point.

When a hit test runs, the framework starts at the root of the render tree and walks downward, asking each render object: "does this position fall on you?" The render object can answer in three ways: it can say no (the point isn't on me, and I have no children that care), it can say yes for itself (I want this point), or it can defer to its children (one of them is interested, and so transitively am I). The accumulated answer is a list called the *hit test result* — every render object on the path from the root to the deepest interested descendant gets an entry.

A few clarifications are worth making up front, because hit testing is often confused with related concepts.

**Hit testing isn't necessarily about gestures.** While pointer events are the most common reason a hit test runs, the framework (and your own code) can run hit tests for other reasons too. For example, `WidgetTester.tapAt` runs a hit test under the hood during widget tests; `MouseRegion` uses hit testing to determine which render objects the mouse cursor is over; tooling like the widget inspector uses it to figure out which widget you're pointing at. The hit test API itself is just a geometric query that asks "which render objects are interested in this point" — what the caller does with the answer is a separate concern.

**Hit testing has no relationship to `GestureDetector` or the gesture arena.** Gesture recognizers consume the output of a hit test (the list of render objects), but they don't participate in the hit test itself. Your render object doesn't know or care about gesture detectors, gesture arenas, recognizer priority, or "winning" a gesture. Its job is narrow: given a point in your local coordinate space, decide whether your content covers that point, and decide whether any of your children's content does. You answer the geometric question; everything downstream of that — dispatching events, running recognizers, resolving conflicts — is the framework's problem.

## The `BoxHitTestResult`

The `BoxHitTestResult` is the accumulator passed to your `hitTest` method — when a hit lands on you, you add yourself to it.

You don't construct it; the framework hands it to you. When you decide that a point hits your render object, you add an entry like this:

```dart
result.add(BoxHitTestEntry(this, position));
```

The entry records *which* render object was hit and *where* in that render object's local coordinate space the hit occurred. The framework uses both pieces of information later: the render object to route the event to, and the local position so downstream consumers can reason about it in your coordinate space.

Most of the time, you don't construct entries directly. The default `hitTest` implementation calls `hitTestChildren` and `hitTestSelf` for you and adds the entries as appropriate. You only construct your own `BoxHitTestEntry` when you override `hitTest` itself, which is rare.

## Testing Yourself With `hitTestSelf`

`hitTestSelf(Offset position)` is your render object's way of declaring that its *own pixels* — independent of any children — should receive the hit.

The default returns `false`, meaning: I have no content of my own that wants to be tapped; only my children can be hit. This is the correct answer for transparent container render objects like a custom `Row` or `Stack`, where the parent is just an arrangement of children with no clickable surface of its own.

If your render object draws something the user is supposed to interact with — a button background, a colored panel, a custom-drawn shape — override `hitTestSelf` to return `true` for points inside your hittable area:

```dart
@override
bool hitTestSelf(Offset position) => true;
```

The `position` argument is in your local coordinate space (origin at zero), so for the typical "I'm a rectangle of `size`" case, you don't even need to check the position — the default `hitTest` has already verified the point is within your `size` before calling you. You only need to inspect `position` when your hittable area is something more constrained than your full bounds — a circular button inside a square render object, for example.

> **Aside: should shadows be hittable?** If your render object paints a drop shadow or glow that extends beyond its visual edge, the answer is almost always *no* — shadows should not contribute to the hit region. Users perceive shadows as decoration, not as part of the object, and treating them as hittable produces confusing taps that register on nothing visible. The same applies to subtle hover effects, atmospheric glows, and other purely decorative overflow. Limit `hitTestSelf` to the visually meaningful surface.
> 

There's also a relationship between hit testing and your render object's *semantic paint bounds* — the `paintBounds` you may have overridden to report drawing outside your layout size. **`paintBounds` does not affect hit testing.** The default `hitTest` filters by `size` (your layout rectangle), not by `paintBounds`. A point inside your shadow but outside your layout box is rejected before `hitTestSelf` ever runs, which is consistent with the rule above. If you genuinely want to accept hits outside your layout size — for an oversized touch target, not a shadow — you have to opt in explicitly by overriding `hitTest` itself, which is covered in the section on hit testing outside your bounds.

## Testing Children With `hitTestChildren`

`hitTestChildren(BoxHitTestResult result, {required Offset position})` is how you delegate the hit test to your children, translating the incoming position into each child's local coordinate space first.

For a render object with no children, the default implementation returns `false` and you don't override it. For container render objects, you need to walk your children (typically in *reverse paint order*, since the topmost child should get first crack) and call `child.hitTest(result, position: childLocalPosition)` on each. If any child reports a hit, you return `true`.

The standard pattern for a multi-child render object using `ContainerRenderObjectMixin` looks like this:

```dart
@override
bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
  // Walk children in reverse paint order so the topmost child is tested first.
  RenderBox? child = lastChild;
  while (child != null) {
    final childParentData = child.parentData! as BoxParentData;
    final bool isHit = result.addWithPaintOffset(
      offset: childParentData.offset,
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) {
        return child!.hitTest(result, position: transformed);
      },
    );
    if (isHit) return true;
    child = childParentData.previousSibling;
  }
  return false;
}
```

`result.addWithPaintOffset` handles the coordinate translation for you: it subtracts the child's offset from `position` and passes the resulting child-local position to your callback. If the child reports a hit, the helper also records the inverse offset transformation on the result, which is what lets the framework correctly compute local coordinates for the entries you added.

The `RenderBoxContainerDefaultsMixin` provides a `defaultHitTestChildren(result, position: position)` helper that does exactly this — reverse iteration, offset translation, short-circuit on first hit — for you. Use it when your paint order matches your child-list order:

```dart
@override
bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
  return defaultHitTestChildren(result, position: position);
}
```

If your paint order is anything other than the default (a stack that paints in a custom z-order, a layout that reorders for display), you need to write the iteration yourself and walk children in the reverse of *your* paint order.

> **Aside:** Walking children in reverse paint order is what makes the topmost (visually frontmost) child get hit first. If you walk in forward order instead, taps on overlapping children will hit whatever is *underneath* — the kind of bug that looks fine on a static screen and falls apart the moment two children overlap.
> 

## The Add-Order Rule

The order in which entries are added to the `BoxHitTestResult` is significant: it determines the order in which downstream consumers (most commonly gesture recognizers) consider the result, with deepest-first semantics.

The convention is: **add child entries before adding your own entry**. The default `hitTest` implementation enforces this by calling `hitTestChildren` before `hitTestSelf`. If a child wants the hit, it's added first; then if `hitTestSelf` also returns `true`, the current render object is added after. The result is an ordered list that runs from deepest to shallowest.

If you override `hitTest` directly (rare, but possible), preserve this order. Adding yourself before your children produces subtle routing bugs where downstream consumers consider entries in the wrong order — a parent claiming events that should have gone to a child, for example.

The other implication is that **a hit on a child does not preclude a hit on the parent**. Both can be added, and both will be in the result. Whether anything downstream treats a deeper entry as preempting a shallower one isn't your concern — your job is just to honestly report who's geometrically interested.

## Non-Rectangular Hit Regions

Non-rectangular hit regions are how you express that only part of your render object's bounding box should receive hits — a circular button, a polygon, a region defined by an alpha mask.

The mechanism is `hitTestSelf`: inspect the incoming `position` and return `true` only when it falls inside your real hit shape. For a circular button:

```dart
@override
bool hitTestSelf(Offset position) {
  final center = size.center(Offset.zero);
  final radius = size.shortestSide / 2;
  return (position - center).distanceSquared <= radius * radius;
}
```

For more complex shapes, build a `Path` once (cached as a field, ideally rebuilt only when its inputs change) and use `path.contains(position)`:

```dart
@override
bool hitTestSelf(Offset position) => _hitPath.contains(position);
```

The default `hitTest` still does the initial check against your `size`, so anything that falls outside the bounding box is rejected before `hitTestSelf` is called. If you need hits *outside* your size — for an effect that extends beyond your bounds — see the section on hit testing outside your bounds below.

## Hit Testing Through Transforms and Layers

When your render object applies a transform during paint — via `pushTransform` or a custom `TransformLayer` — hit testing needs to reverse that transform so that the position passed to children is in their (untransformed) local coordinate space.

The framework provides `result.addWithPaintTransform` for this. You supply the transform you used during paint, the original `position`, and a callback; the helper inverts the transform, passes the inverted position to your callback, and records the transformation on the result for later coordinate-mapping use:

```dart
@override
bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
  if (child == null) return false;
  return result.addWithPaintTransform(
    transform: _transform,
    position: position,
    hitTest: (BoxHitTestResult result, Offset transformed) {
      return child!.hitTest(result, position: transformed);
    },
  );
}
```

A few notes. First, the transform must match the one you actually applied in paint — if they disagree, hit testing will be off by exactly the difference, producing the classic "the button is in the wrong place" bug. Second, if the transform isn't invertible (a fully degenerate scale-to-zero, for example), `addWithPaintTransform` returns `false` and skips the callback, which is the correct behavior since no point in the parent space could possibly hit the collapsed child.

There are related helpers — `addWithReverseTransform` if you have the inverse already, `addWithOutOfBandPosition` for more exotic cases — but `addWithPaintTransform` is the one you'll reach for most often. Use the same family of helpers (`addWithPaintOffset`, `addWithPaintTransform`) consistently whenever you've applied a coordinate change in paint.

It's tempting to skip these helpers and just invert the math yourself before recursing — it's only a couple of lines, after all:

```dart
// Don't do this — the geometric check works, but the result loses
// the coordinate-transformation bookkeeping it needs later.
@override
bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
  if (child == null) return false;
  final inverse = Matrix4.tryInvert(_transform);
  if (inverse == null) return false;
  final transformed = MatrixUtils.transformPoint(inverse, position);
  return child!.hitTest(result, position: transformed);
}
```

The geometric question is answered correctly — the child gets a properly-transformed position and reports whether it was hit. What breaks is that the `BoxHitTestResult` no longer knows about the transform you applied. Later calls that depend on the recorded transform chain — `BoxHitTestEntry.localPosition` for entries added by the child, or `globalToLocal`/`localToGlobal` computed against the hit path — will be wrong by exactly the inverse of your transform. The bug is silent: taps register on the right render object, but any code that asks "where did the tap land in this child's local coordinates?" gets the answer for the *untransformed* parent space, not the post-transform child space. Use `addWithPaintTransform` and the bookkeeping is handled for you.

## Hit Testing Outside Your Bounds

By default, the framework rejects any point outside your `size` before your hit test methods are even called — but there are cases where you legitimately want to accept hits outside your bounds, and that requires overriding `hitTest` directly.

The most common case is a touch target that's visually smaller than its hittable area — a small icon that should still register taps over a generous surrounding region. Another is hit testing through a child that paints outside its parent's bounds.

To accept out-of-bounds hits, override `hitTest` itself rather than `hitTestSelf`:

```dart
@override
bool hitTest(BoxHitTestResult result, {required Offset position}) {
  final expanded = Offset.zero & size.inflate(_extraHitSlop);
  if (!expanded.contains(position)) return false;
  if (hitTestChildren(result, position: position) || hitTestSelf(position)) {
    result.add(BoxHitTestEntry(this, position));
    return true;
  }
  return false;
}
```

This bypasses the default's strict `size`-based gate while preserving the rest of its logic — children first, then self, then add the entry if either reported a hit. Be conservative with this. Hit regions that extend significantly past visible content surprise users; small extensions (a few logical pixels around tiny targets) are usually fine.

The mirror-image issue is **content drawn inside your bounds that shouldn't be hittable** — a decorative overlay, for example. There's no "rejection" hook for this; you handle it by returning `false` from `hitTestSelf` for those regions. The default `hitTest` always checks `hitTestChildren` first, so a non-hittable parent above hittable children works correctly out of the box.

## Performance Notes

Hit testing runs on every pointer event — every touch-down, every move, every up — so per-event cost matters even though it's far less hot than paint.

A few things to keep in mind:

- **Don't allocate inside `hitTest` if you can avoid it.** Cache `Path` objects, precomputed centers, or hit rects as fields and reuse them. A pointer drag can fire dozens of move events per second.
- **Avoid `path.contains` when a simpler check suffices.** A rect containment check is dramatically cheaper than a path containment check; use the cheapest check that's geometrically correct.
- **Walk children in reverse paint order and short-circuit on the first hit.** Once a child has reported a hit, you don't need to keep walking — the default helpers already do this, but if you're hand-rolling the iteration, preserve the short-circuit.
- **Use the framework's `addWith*` helpers.** They keep the coordinate transformations correct for later use, and they handle non-invertible cases gracefully. Reinventing them by hand is a frequent source of subtle bugs.