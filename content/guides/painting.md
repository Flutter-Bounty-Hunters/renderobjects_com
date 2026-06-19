---
title: Painting
description: How Flutter's paint phase works and how render objects participate in it.
layout: guides
order: 20
---
# Implementing Paint in a Custom Flutter Render Object

This guide walks experienced Flutter developers through the paint responsibilities of a custom `RenderObject`. By the end, you'll understand what the framework expects from your render object when it's time to draw, and how to deliver it correctly. We'll skip layout, hit testing, and most compositing details — this is about painting, and only painting.

## What This Guide Covers

- **The Paint Context and Offset** — Understanding the two parameters every paint method receives and what they mean.
- **Drawing With Canvas** — Issuing draw commands and respecting your own size and offset.
- **Painting Children** — Delegating paint to child render objects through the paint context.
- **Repaint Boundaries** — How Flutter isolates repaint work and when to opt in.
- **When Paint Re-Runs** — Marking yourself dirty correctly so the framework knows to repaint you.
- **Layers and `needsCompositing`** — When painting requires a real compositor layer instead of canvas commands.
- **Clipping and Transforms** — Applying effects that the framework provides helpers for, and when to use them.
- **Semantic Bounds** — Reporting where your visible content lives via `paintBounds`.
- **Performance Notes** — Small things that matter when your code runs every frame.

## The `paint` Method

Before diving into the topics above, it's worth establishing where they live in code. `paint(PaintingContext context, Offset offset)` is the single override the framework calls when it's time for your render object to draw, and it's where nearly everything in this guide is implemented. The handful of items that live outside `paint` — like the `isRepaintBoundary` getter, the `needsCompositing` flag, and property setters that mark you dirty — are still in close orbit around it, supporting or supplementing what happens during the paint pass.

Inside `paint`, you do some combination of three things:

1. Draw your own visual content onto `context.canvas`.
2. Paint each child by calling `context.paintChild(child, childOffset)`.
3. Optionally wrap any of the above in clips, transforms, or other effects via `context` helpers.

That's the whole job. The rest of the guide unpacks each piece.

## The Paint Context and Offset

The paint context and offset are the two pieces of information the framework gives you every time it asks you to paint, and getting comfortable with what each represents will save you a lot of confusion.

The `PaintingContext` is your interface to the rendering pipeline. It exposes a `canvas` for direct drawing, methods for painting children, and helpers for compositing effects like clips and transforms. You don't construct it — the framework hands it to you.

The `offset` is where your render object's local origin sits in the canvas's coordinate space. Your own coordinate system always starts at `(0, 0)` regardless of where you actually end up on screen — but the canvas is shared, so the framework tells you, "your origin is at `offset` from the canvas's perspective." To draw anything correctly, you translate your local coordinates by adding `offset` before issuing canvas commands.

Concretely, suppose you want to draw a 20×20 rectangle at the point `(50, 50)` in your own coordinate system. From the canvas's perspective, that rectangle's top-left corner is at `offset + Offset(50, 50)`:

```dart
@override
void paint(PaintingContext context, Offset offset) {
  final localTopLeft = const Offset(50, 50);
  final rect = (offset + localTopLeft) & const Size(20, 20);
  context.canvas.drawRect(rect, _paint);
}
```

If `offset` happens to be `(100, 200)` on this paint pass, the rectangle ends up at `(150, 250)` on the canvas — the right place. If you had forgotten to add `offset` and just drawn at `(50, 50)` on the canvas directly, the rectangle would appear in the wrong place any time your render object isn't sitting at the canvas origin.

> **Aside:** Forgetting to apply `offset` is one of the most common bugs in custom render objects. Your widget will paint correctly when it happens to sit at the canvas origin and mysteriously shift or disappear everywhere else. If something paints in the wrong place, this is the first thing to check.
> 

## Drawing With Canvas

Drawing with canvas is how you produce your render object's actual visual content — anything from a single rectangle to complex composited graphics.

`context.canvas` is a standard Flutter `Canvas`, with all the usual drawing methods: `drawRect`, `drawRRect`, `drawCircle`, `drawPath`, `drawImage`, `drawParagraph`, and so on. You combine these with `Paint` objects that describe color, stroke, blend mode, and shader options.

Two things to keep in mind. First, **everything you draw must be inside the bounds described by `offset & size`** — or at least, the framework assumes so. Painting outside your bounds works visually but breaks repaint optimization, hit testing, and clipping by ancestors. If you genuinely need to draw outside your bounds, see the section on semantic bounds below.

Second, **`Paint` objects are not free to allocate.** If you use the same paint configuration every frame, hold it as a field on your render object and mutate it only when its inputs change. Allocating a `Paint` inside `paint` itself is a small but real per-frame cost.

## Painting Children

Painting children is how you delegate drawing to the render objects beneath you in the tree — you don't paint their pixels yourself, you ask the framework to do it.

For each child, call:

```dart
context.paintChild(child, offset + childOffset);
```

The `childOffset` here is the offset you stored in the child's `parentData` during layout. You add it to your own incoming `offset` so that the child paints at the correct absolute position. The `paintChild` call handles everything else — including respecting whether the child is a repaint boundary, has its own compositing requirements, and so on.

For multi-child render objects using `ContainerRenderObjectMixin`, the helper `defaultPaint(context, offset)` walks your children in order and paints each one using the offset in its `BoxParentData`. If your paint order matches your child order and you have no effects to apply between children, this is all you need:

```dart
@override
void paint(PaintingContext context, Offset offset) {
  defaultPaint(context, offset);
}
```

If you need a custom paint order (back-to-front for a stack, for example, or skipping invisible children), iterate yourself and call `context.paintChild` for each one.

## Repaint Boundaries

Repaint boundaries are how Flutter isolates repaint work — they let a subtree repaint without forcing its ancestors or siblings to repaint along with it.

By default, a render object is *not* a repaint boundary. When it's marked dirty for paint, the framework walks up to the nearest ancestor repaint boundary and repaints from there. This is usually fine, but for render objects that repaint frequently (animations, video, scrolling content) or that have expensive ancestors, becoming a repaint boundary is a significant win.

To opt in, override `isRepaintBoundary` to return `true`:

```dart
@override
bool get isRepaintBoundary => true;
```

The framework will then give your render object its own layer, cached separately from the surrounding tree. When you repaint, only your own paint method runs; the ancestor layers reuse their cached output.

When you're a repaint boundary, the `offset` passed to your `paint` method is always `Offset.zero`. This is because your content lives in its own layer with its own coordinate space — the parent's transform is applied to the layer itself, not baked into your draw commands. You can write your paint method the same way regardless, since `offset + localPoint` just collapses to `localPoint` when `offset` is zero. Just be aware that an incoming `offset` of zero doesn't mean you're at the screen's origin; it means your layer's origin.

A few gotchas worth knowing:

- **Repaint boundaries cost memory.** Each one holds onto a layer, which is a GPU-side texture sized to your render object. A boundary around a large scrollable region or a full-screen widget can be substantial.
- **They don't help if the boundary itself repaints constantly.** If your render object is dirty every frame, the layer is rebuilt every frame and you've gained nothing while paying the memory cost.
- **They can mask paint bugs in ancestors.** Because ancestors no longer repaint when you do, a missing `markNeedsPaint()` somewhere upstream may go unnoticed during development.
- **They may force ancestors to composite.** Adding a layer in the middle of the tree raises `needsCompositing` for everything above you, which can promote previously cheap clips and transforms in ancestors into full compositor layers.

Use repaint boundaries deliberately — where you have a clear reason like high paint frequency, expensive surroundings, or a piece of UI that's logically independent from the rest of its tree.

## When Paint Re-Runs

Knowing when paint re-runs is essential because Flutter is aggressive about avoiding unnecessary paint work — your `paint` only runs when the framework thinks it needs to.

Your `paint` will be called when:

- Layout produced a new size or position.
- You're marked dirty via `markNeedsPaint()`.
- A descendant inside your repaint scope needs to repaint.

If you change any property on your render object that affects its appearance but not its layout, you must call `markNeedsPaint()` in the setter:

```dart
set color(Color value) {
  if (_color == value) return;
  _color = value;
  markNeedsPaint();
}
```

If the property affects layout *and* paint, call `markNeedsLayout()` instead — it implies a repaint. Don't call both; you'll just waste work. The early return matters too: marking dirty when nothing changed is wasted work and can cause unnecessary repaints to propagate.

## Layers and `needsCompositing`

Layers and compositing are the parts of painting that go beyond simple canvas commands — effects like opacity, clips with anti-aliasing, transforms, and shader masks that require the GPU compositor to handle properly.

Most of the time, you don't think about layers directly. When you call `context.pushClipRect`, `context.pushTransform`, `context.pushOpacity`, or similar, the context decides under the hood whether to apply the effect as a cheap canvas operation or as a full compositor layer. You just call the method and it works.

The catch is the `needsCompositing` flag. If your render object — or any descendant — actually produces a compositor layer, the framework needs to know so that ancestors can prepare for it. This is reported by the `needsCompositing` getter, which is computed for you automatically based on your children. You only need to intervene in two specific situations.

### Case 1: A property determines whether a layer is needed

The most common case is a render object with a property whose value decides whether compositing is required — opacity is the canonical example. An opacity of `1.0` doesn't need a layer; anything less does. Tell the framework about this by overriding `alwaysNeedsCompositing` and recomputing it when the property changes:

```dart
@override
bool get alwaysNeedsCompositing => _opacity > 0 && _opacity < 1;

set opacity(double value) {
  if (_opacity == value) return;
  final wasCompositing = alwaysNeedsCompositing;
  _opacity = value;
  if (alwaysNeedsCompositing != wasCompositing) {
    markNeedsCompositingBitsUpdate();
  }
  markNeedsPaint();
}
```

The `markNeedsCompositingBitsUpdate()` call lets the framework re-evaluate the compositing flag up the tree, since your answer just changed.

### Case 2: You always need a layer

If your render object unconditionally requires a layer — for example, because it always applies a backdrop filter or shader mask that can't be expressed without one — just return `true` from `alwaysNeedsCompositing`:

```dart
@override
bool get alwaysNeedsCompositing => true;
```

No setter dance is needed in this case because the answer never changes.

For everything else, use `pushClipRect`, `pushTransform`, and friends; trust the framework; and don't touch `alwaysNeedsCompositing`.

## Clipping and Transforms

Clipping and transforms are common visual effects that the `PaintingContext` provides first-class helpers for, so you should reach for those helpers rather than manipulating the canvas directly.

The pattern is consistent across these helpers: you call a `push*` method on the context, pass it a callback that does the actual painting, and the context applies the effect for the duration of that callback.

```dart
@override
void paint(PaintingContext context, Offset offset) {
  context.pushClipRect(
    // Pass through our own compositing flag so the helper can decide
    // whether the clip needs to become a real compositor layer.
    needsCompositing,
    // The position of our render object in the parent's coordinate space —
    // pushClipRect expects this to translate the clip rect into place.
    offset,
    // The clip rect itself, expressed in our LOCAL coordinate space
    // (origin at zero), since the helper will translate it using `offset`.
    Offset.zero & size,
    // The painting callback. The framework hands us a fresh context and
    // offset that already account for any layer it may have set up.
    (innerContext, innerOffset) {
      // Draw using innerContext and innerOffset — not the outer ones.
      innerContext.canvas.drawRect(innerOffset & size, _paint);
    },
  );
}
```

The subtle and easy-to-get-wrong part of this API is the relationship between `offset`, `innerOffset`, and the rect you pass to `pushClipRect`. Here's the rule:

- **The clip rect argument is in your local coordinate space.** That's why you pass `Offset.zero & size` rather than `offset & size`. The helper combines it with `offset` internally to position the clip on the canvas.
- **`offset` is your position in the parent's coordinate space**, the same value you received in `paint`.
- **`innerOffset` is what you should use to draw inside the callback** — it's the offset *into the clipped region* where your content should be drawn. In most cases `innerOffset` equals the original `offset`, but if the helper decided to push a new layer to implement the clip, `innerOffset` will be `Offset.zero` because the new layer has its own coordinate space starting at zero (just like the repaint boundary case earlier).

The practical takeaway: never use the outer `offset` inside the callback — always use `innerOffset`. If you mix them up, your content will paint correctly some of the time (when no layer was needed) and end up offset by your absolute position other times (when a layer was needed). That's a tough bug to track down.

Equivalent helpers exist for rounded-rect clips (`pushClipRRect`), path clips (`pushClipPath`), arbitrary transforms (`pushTransform`), opacity (`pushOpacity`), and color filters. Use them. Doing the math by hand with `canvas.save()`, `canvas.clipRect()`, and `canvas.restore()` works for simple non-anti-aliased cases but skips the framework's compositing logic, which means anti-aliasing quality suffers and the compositor can't optimize the result.

## Semantic Bounds

Semantic bounds describe where your render object's visible content actually lives, which is normally the same as your size — but not always.

By default, `paintBounds` returns `Offset.zero & size`, meaning your visual content fits exactly within your layout rectangle. The framework uses this for repaint region calculations and for some debugging tools.

If your render object draws outside its size — a shadow that extends past the layout box, a glow effect, decorative overflow — override `paintBounds` to return a rectangle large enough to include everything you actually draw:

```dart
@override
Rect get paintBounds {
  return (Offset.zero & size).inflate(_shadowExtent);
}
```

Without this, the framework may clip your repaint region too tightly and you'll see visual artifacts when the surrounding area redraws. Most layouts don't paint outside their bounds; override `paintBounds` only when yours genuinely does.

## Performance Notes

Performance matters in paint because `paint` can run every frame, so small inefficiencies compound quickly.

A few things to keep in mind:

- **Don't allocate `Paint` objects, `Path` objects, or `Rect`s inside `paint` if you can avoid it.** Cache them as fields and mutate them only when their inputs change.
- **Avoid expensive canvas operations on every frame.** Building a complex `Path` from scratch each paint is wasteful — build it once during layout (or when its inputs change) and reuse it.
- **Prefer the context's `push*` helpers over manual `canvas.save()`/`canvas.restore()` for clips and transforms.** The helpers cooperate with the compositor; manual canvas state does not.
- **Use repaint boundaries deliberately.** They cost memory but save paint work; the right balance depends on your widget's paint frequency and its position in the tree.