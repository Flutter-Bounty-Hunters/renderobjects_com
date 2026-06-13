---
title: Compositing
description: How Flutter's composite phase works and how render objects participate in it.
layout: guides
order: 30
---
# Implementing Compositing in a Custom Flutter Render Object

This guide walks experienced Flutter developers through the compositing responsibilities of a custom `RenderObject`. By the end, you'll understand how layers fit into Flutter's rendering pipeline, when your render object needs to participate in compositing directly, and how to do so correctly. We'll skip layout, hit testing, and most direct-canvas painting — this is about compositing, and only compositing.

## What This Guide Covers

- **What Compositing Actually Is** — The role of layers in Flutter's rendering pipeline and how they differ from canvas drawing.
- **The `needsCompositing` Flag** — How the framework tracks whether your subtree requires a compositor layer.
- **The `alwaysNeedsCompositing` Override** — Telling the framework that your render object produces a layer.
- **Pushing Layers With `pushLayer`** — The mechanism for adding your own compositor layers to the tree.
- **The `OffsetLayer` and Repaint Boundaries** — How becoming a repaint boundary plugs you into the layer system.
- **Reusing Layers Across Frames** — Caching layer objects to avoid allocation and lost compositor state.
- **Updating Layer Properties** — Mutating an existing layer to change effects without repainting children.
- **Transforming Coordinates Through Layers** — Why your layer's transform may need to be reported via `applyPaintTransform`.
- **When Compositing Bits Need Updating** — Marking the compositing flag dirty when your answer changes.
- **Performance Notes** — Small things that matter when working with the compositor.

## The `paint` Method (Again)

Compositing happens inside the same `paint(PaintingContext, Offset)` method that handles drawing. The difference is that instead of (or in addition to) issuing canvas commands, you tell the framework to insert a `Layer` into the scene. A few related members live outside `paint` — `alwaysNeedsCompositing`, `layer`, `applyPaintTransform`, and `markNeedsCompositingBitsUpdate` — but they all support what happens during the paint pass.

Most render objects never need to think about compositing directly. The high-level helpers like `pushClipRect` and `pushOpacity` manage layers internally, and you get correct results without writing layer code. This guide is for the cases when those helpers aren't enough — when you need to push a layer yourself, reuse one across frames, or coordinate compositing flags up the tree.

## What Compositing Actually Is

Compositing is the act of building the rendered frame out of independent GPU-accelerated pieces — *layers* — rather than rasterizing everything into a single image with canvas commands.

When Flutter paints, two different things can happen. Canvas commands like `drawRect` and `drawPath` are recorded into a *picture* that the GPU rasterizes into a single bitmap region. That's cheap and fast for most content. Layers, on the other hand, are tree nodes that the compositor handles as separate units — each layer can have its own transform, opacity, clip, or backdrop filter applied entirely on the GPU, without re-rasterizing the pictures inside it. Effects like animated opacity, backdrop blur, and arbitrary transforms work this way because the alternative — repainting every pixel every frame — would be unacceptably expensive.

The layer tree is parallel to, but distinct from, the render tree. Every frame, the framework walks the render tree's paint methods to build (or update) a corresponding layer tree, and then hands that layer tree to the engine for compositing. Your render object participates in this process by either drawing into the current layer's picture or by introducing new layers of its own.

## The `needsCompositing` Flag

`needsCompositing` is a bit propagated up the render tree that tells each ancestor whether its subtree contains anything that requires a compositor layer.

The framework computes this flag for you automatically: if any descendant has `alwaysNeedsCompositing` set to `true`, or is a repaint boundary, then every ancestor's `needsCompositing` is also `true`. You read this flag — you don't write it.

Why does it matter? Because when you call helpers like `pushClipRect`, the helper consults your `needsCompositing` to decide whether to implement the clip as a cheap canvas operation or as a real compositor layer. If something downstream needs a layer, the clip *must* be a layer too. The reason is that canvas-level clipping only applies to canvas commands recorded into the same picture — but once a descendant introduces its own layer, that layer is no longer part of the surrounding picture; it's a sibling node in the layer tree, handed to the compositor independently. A canvas clip simply can't reach it. The clip has to be expressed as a `ClipRectLayer` so the compositor itself applies it to the descendant layer when assembling the frame.

This is why `pushClipRect` takes a `needsCompositing` argument — and why you should pass through your own `needsCompositing` value verbatim:

```dart
context.pushClipRect(needsCompositing, offset, clipRect, paintCallback);
```

Getting this wrong (passing `false` when you should pass `true`) produces visible rendering bugs: clips don't apply to descendant layers, transforms get bypassed, and so on.

## The `alwaysNeedsCompositing` Override

`alwaysNeedsCompositing` is how you tell the framework that *this specific render object* produces a compositor layer during its paint pass, and therefore that ancestors need to know.

The default is `false`. Override it if your render object pushes a layer of its own — either unconditionally or conditionally based on a property:

```dart
@override
bool get alwaysNeedsCompositing => true;
```

Or, conditionally:

```dart
@override
bool get alwaysNeedsCompositing => _filter != null;
```

The framework reads this getter when it computes the propagated `needsCompositing` bit. If your answer can change at runtime — for example, you set `_filter` to a non-null value where it was null before — you must tell the framework so it can re-propagate the bit upward. See the section on compositing bit updates below.

## Pushing Layers With `pushLayer`

`pushLayer` is the lower-level API for adding a `Layer` to the compositor tree from your paint method, used when the high-level helpers don't cover what you need.

The shape is similar to `pushClipRect` and friends: you pass a layer, a painting callback for content that lives inside the layer, and an offset. The framework attaches the layer to the current layer tree position, runs the callback to paint child content into the new layer, and then continues.

```dart
@override
void paint(PaintingContext context, Offset offset) {
  // Create or reuse a layer that applies some effect — here, a color filter.
  final ColorFilterLayer filterLayer = ColorFilterLayer(colorFilter: _filter!);
  // Push the layer and paint children into it.
  context.pushLayer(filterLayer, _paintContents, offset);
}

void _paintContents(PaintingContext context, Offset offset) {
  // Paint your children or other content here. They will be rasterized
  // inside the new layer's coordinate space.
  if (child != null) context.paintChild(child!, offset);
}
```

The painting callback receives a fresh `PaintingContext` because the framework may have started recording into a new picture inside the layer. The `offset` you receive in the callback is the position at which to paint, in whatever coordinate space the layer establishes — usually it's just the same `offset` you passed in.

Also note that `pushLayer` only makes sense when `alwaysNeedsCompositing` reports `true` for whatever condition produced this layer. Otherwise the framework won't have propagated `needsCompositing` correctly, and ancestors won't have made the right decisions.

The code snippet above allocates a fresh layer object every paint, which is *not* what you want in real code — reusing the same layer object across frames is essential for compositor performance, and it's covered in its own section below.

## The `OffsetLayer` and Repaint Boundaries

When you set `isRepaintBoundary` to `true`, the framework automatically creates and manages an `OffsetLayer` for your render object, and that layer becomes the root of an independently-cached layer subtree.

The most visible consequence is how your render object's paint offset is handled. For a non-repaint-boundary render object, you bake the offset into your canvas commands manually:

```dart
// Non-repaint-boundary: apply the offset to every draw call.
@override
void paint(PaintingContext context, Offset offset) {
  context.canvas.drawRect(offset & size, _paint);
}
```

For a repaint boundary, the framework instead sets the offset on the `OffsetLayer` itself — and then passes you `Offset.zero` for the paint call, because your content lives inside the layer's own coordinate space:

```dart
// Repaint boundary: offset is always Offset.zero. The OffsetLayer
// the framework manages for you carries the actual position.
@override
bool get isRepaintBoundary => true;

@override
void paint(PaintingContext context, Offset offset) {
  assert(offset == Offset.zero);
  context.canvas.drawRect(Offset.zero & size, _paint);
}
```

In practice you can write your paint method the same way regardless, because `offset + localPoint` collapses to `localPoint` when `offset` is zero. But it's worth understanding *why* this works: the framework has moved the offset out of your draw commands and into the layer.

The `OffsetLayer` is stored on your render object's `layer` property. **This is the same `layer` property used for any layer your render object owns**, including a layer you push yourself. The render object has exactly one slot. A render object that is a repaint boundary uses the slot for an `OffsetLayer` managed by the framework. A render object that is not a repaint boundary but pushes its own layer uses the slot for that layer. A render object that does neither has `layer` set to `null`. You don't typically own both at once — repaint boundaries are managed end-to-end by the framework, and the layer-pushing patterns in this guide apply to render objects that aren't repaint boundaries.

## Reusing Layers Across Frames

Reusing layers across frames is the standard pattern for any render object that pushes its own layer — allocating a fresh layer object every paint pass wastes work and discards the engine's per-layer state.

The `layer` property is your storage slot for the layer. As mentioned in the previous section, the framework manages this slot when your render object is a repaint boundary (it sets it to an `OffsetLayer`). When your render object isn't a repaint boundary but pushes its own layer via `pushLayer`, you manage the slot — you write to it, you reuse it, you clear it when no layer is needed:

```dart
@override
void paint(PaintingContext context, Offset offset) {
  if (_filter == null) {
    // No effect is active — clear our slot and just paint children directly.
    layer = null;
    if (child != null) context.paintChild(child!, offset);
    return;
  }
  // Reuse the existing layer if we have one; otherwise allocate.
  final ColorFilterLayer filterLayer =
      (layer as ColorFilterLayer?) ?? ColorFilterLayer();
  // Update its properties in place.
  filterLayer.colorFilter = _filter!;
  // Remember it for next frame.
  layer = filterLayer;
  // Push it.
  context.pushLayer(filterLayer, _paintContents, offset);
}
```

`ColorFilterLayer`, `OpacityLayer`, `TransformLayer`, and so on are mutable. You can change their properties between frames without creating new objects.

A common question is whether layer reuse really matters — after all, a repaint boundary's whole point is that ancestors don't repaint when the boundary's contents change, and that benefit is preserved whether you reuse layers or not. That's correct, and it's worth being clear about: even with fresh layers each frame, you still get the *ancestor isolation* benefit of compositing. The boundary still prevents the surrounding tree from being walked and repainted.

What you lose by recreating layers is a *different* benefit: the engine's ability to skip re-rasterizing the layer's own children when only an effect property changed. With layer reuse, changing an `OpacityLayer.alpha` from frame to frame lets the engine reuse the rasterized picture inside the layer and just re-composite it at a different opacity — essentially free. Without layer reuse, the engine sees a brand-new layer, has no cached picture for it, and must re-rasterize the entire contents. The ancestor savings are still there, but the within-layer savings are gone.

So: not the entire purpose, but a large part of it, and the part that makes per-frame animations cheap. Always reuse.

## Updating Layer Properties

Updating layer properties is what you do when only a layer's effect changed — its opacity value, its transform matrix, its filter — and the content inside the layer is identical to the previous frame.

Because layers are mutable, you can change a property on an existing layer and then ask the framework to hand the updated layer tree to the engine without re-running your paint method at all. The engine will skip re-rasterizing the layer's contents and just re-composite with the new effect value. The trigger is `markNeedsCompositingBitsUpdate`'s less-known cousin: simply calling `markNeedsPaint()` after mutating the layer property would also work, but it does extra work — re-running `paint`, re-recording the picture inside the layer — that the optimization is meant to avoid.

The optimized path is to mutate the layer directly and rely on the fact that the layer is already part of the layer tree. The framework will pick up the change at the next compositing pass:

```dart
set opacity(double value) {
  if (_opacity == value) return;
  _opacity = value;
  // Mutate the live layer if we have one. The framework will composite
  // the updated layer tree without rerunning paint or re-rasterizing
  // the picture inside the layer.
  final opacityLayer = layer as OpacityLayer?;
  if (opacityLayer != null) {
    opacityLayer.alpha = _alphaFromOpacity(value);
  } else {
    // We don't have a layer yet (e.g. first frame), so a full paint is needed.
    markNeedsPaint();
  }
}
```

The rule of thumb: if the property change only affects a *layer property* and not the content drawn inside the layer, mutate the layer and skip `markNeedsPaint()`. If the change affects what gets drawn inside the layer (a child's appearance, the shape of a clip path, a color used in a `drawRect` call inside `_paintContents`), call `markNeedsPaint()` because the picture inside the layer needs to be re-recorded.

In practice, this optimization is most valuable for animated properties — an opacity tween, a transform animation — where you want every frame to be as cheap as possible. For one-off changes, just calling `markNeedsPaint()` is simpler and the cost is negligible.

## Transforming Coordinates Through Layers

`applyPaintTransform(RenderObject child, Matrix4 transform)` is how your render object reports the coordinate transformation it applies to a given child — and you need to override it whenever your paint method applies a transform that the default implementation doesn't know about.

The framework calls `applyPaintTransform` when it needs to map a point between coordinate spaces — for example, to compute the screen-space position of a descendant for hit testing or for `localToGlobal`. The default implementation handles the simple case: it adds the child's offset (from its `BoxParentData`) to the matrix.

The override requirement isn't tied specifically to `pushLayer`; it's tied to whether you apply any non-trivial transform during paint. That includes:

- **Calling `pushLayer` with a `TransformLayer` you constructed yourself** — clearly needs an override.
- **Calling `context.pushTransform(...)`** — also needs an override. The helper applies the transform, but it has no way to report it back through `applyPaintTransform` on your behalf.
- **Calling `context.pushClipRect`, `pushClipRRect`, or `pushClipPath`** — does *not* need a transform override. Clipping doesn't change coordinates.
- **Calling `context.pushOpacity` or `pushColorFilter`** — does *not* need a transform override. These don't affect coordinates either.

So the rule is: any time your paint method moves descendants in space relative to your render object, override `applyPaintTransform`:

```dart
@override
void applyPaintTransform(RenderObject child, Matrix4 transform) {
  // Apply our own transform first (the same one we apply in our layer
  // or via context.pushTransform).
  transform.multiply(_transform);
  // Then let the default handle the child's BoxParentData offset.
  super.applyPaintTransform(child, transform);
}
```

If you skip this, hit testing on descendants beneath the transform will be off by exactly the transform you applied. The bug is subtle — paint looks correct, but taps miss — and it's worth getting right from the start.

## When Compositing Bits Need Updating

The compositing bit (`needsCompositing`) is computed during a dedicated tree walk separate from layout and paint, and you need to tell the framework when your answer to `alwaysNeedsCompositing` changes.

The trigger is `markNeedsCompositingBitsUpdate()`. Call it from any setter where the change might flip `alwaysNeedsCompositing` between `true` and `false`:

```dart
set filter(ColorFilter? value) {
  if (_filter == value) return;
  final wasCompositing = alwaysNeedsCompositing;
  _filter = value;
  if (alwaysNeedsCompositing != wasCompositing) {
    markNeedsCompositingBitsUpdate();
  }
  markNeedsPaint();
}
```

The early-return-when-unchanged pattern matters here too. Marking compositing bits dirty walks part of the tree, and doing it for a no-op change is wasteful. Equally important, *not* calling `markNeedsCompositingBitsUpdate` when the answer genuinely changed leaves stale flags in your ancestors, which leads to the same kind of "clip doesn't apply to layer" bugs described earlier.

## Performance Notes

Compositing performance is mostly about respecting the layer cache the engine maintains — small mistakes can erase its benefits.

A few things to keep in mind:

- **Reuse layer objects across frames.** Allocating a new layer per paint forces the engine to re-rasterize the layer's contents, erasing the within-layer caching benefit even though the ancestor isolation benefit remains.
- **Prefer mutating layer properties over re-pushing layers.** Changing `OpacityLayer.alpha` between frames is essentially free; replacing the `OpacityLayer` with a new one is not.
- **Don't push layers you don't need.** A compositor layer has fixed per-frame overhead and a memory cost proportional to its size on screen. Use canvas operations when the effect can be expressed without a layer.
- **Pass `needsCompositing` through helpers honestly.** The framework can only optimize correctly when the flag accurately reflects your subtree.
- **Audit `applyPaintTransform` whenever you add a transforming layer or call `pushTransform`.** Hit testing depends on it being correct, and the bug doesn't show up visually.