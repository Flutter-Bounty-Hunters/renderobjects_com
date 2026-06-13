---
title: Layout
description: How Flutter's layout phase works and how render objects participate in it.
layout: guides
order: 10
---
This guide walks experienced Flutter developers through the layout responsibilities of a custom `RenderObject`. By the end, you'll understand what the framework expects from your render object during a layout pass and how to deliver it correctly. We'll skip painting, hit testing, and compositing entirely — this is about layout, and only layout.

## What This Guide Covers

- **Working With Children** — Measuring children with `child.layout(...)` and positioning them via their parent data offsets.
- **Determining Your Own Size** — Choosing a size that satisfies the constraints handed down by your parent.
- **Parent Data** — Attaching custom per-child information that your layout needs.
- **Intrinsic Sizing** — Answering questions about your size before a real layout happens.
- **Dry Layout** — Reporting what your size would be under hypothetical constraints.
- **Baselines** — Supporting text baseline alignment when it's meaningful.
- **When Layout Re-Runs** — Marking yourself dirty correctly so the framework knows to relayout you.
- **Relayout Boundaries** — How Flutter localizes layout work and how your choices affect it.
- **Text Direction** — Responding to LTR/RTL when your layout is directional.
- **Performance Notes** — Small things that matter when your code runs every frame.

## The `performLayout` Method

Before diving into the topics above, it's worth establishing where they live in code. `performLayout` is the single override the framework calls when it's time for your render object to do its work, and it's where nearly everything in this guide is implemented. The handful of items that live outside `performLayout` — like `setupParentData`, intrinsic sizing methods, and property setters that mark you dirty — are still in close orbit around it, supporting or supplementing what happens during the layout pass.

Inside `performLayout`, you do three things, in this order:

1. Lay out each child by calling `child.layout(...)`.
2. Decide your own size and assign it to the `size` property.
3. Position each child by writing to its `parentData.offset`.

That's the whole job. The order matters more than you might expect, and the rest of the guide unpacks each piece.

## Working With Children

Working with children is a two-part responsibility: measuring them by handing them constraints, and then positioning them within your own coordinate space.

### Measuring

To measure a child, call `child.layout(childConstraints, parentUsesSize: true)`. The constraints you pass tell the child what sizes are acceptable. They can be the same constraints you received, tightened, loosened, or completely synthesized — that's your call as the parent.

The `parentUsesSize` flag is one of those details that's easy to miss but matters a lot. **Set it to `true` if your own size or layout depends on the child's size.** If you don't, Flutter assumes the child's size is irrelevant to you and may skip notifying you when the child relayouts, which leads to stale layouts that are very hard to debug. When in doubt, set it to true. The cost is a tiny bit of extra dirty-tracking; the cost of getting it wrong is silently broken layouts.

After `child.layout(...)` returns, you can read `child.size` only if you passed `parentUsesSize: true`. Otherwise the framework treats reading `child.size` as a contract violation and will assert in debug mode.

### Positioning

Once children are measured (and you've sized yourself, if your size depends on theirs), place each child by writing to its parent data offset:

```dart
final childParentData = child.parentData! as BoxParentData;
childParentData.offset = Offset(x, y);
```

The offset is relative to your own top-left corner. The framework uses it later during painting and hit testing — you don't apply it manually. The `parentData` field belongs to you as the parent; the next section covers how to customize it.

## Determining Your Own Size

Determining your own size is the act of choosing a width and height for yourself that satisfies the constraints your parent handed down.

Once you know your children's sizes (if you have any), assign your own size:

```dart
size = constraints.constrain(Size(width, height));
```

`constraints.constrain(...)` clamps a desired size into the legal range defined by your parent's constraints. **Your final size must satisfy the incoming constraints** — if it doesn't, you'll trip an assertion in debug builds. Use `constrain`, `biggest`, `smallest`, or `tighten` on the constraints object to stay within bounds.

A subtle point: you must always set `size`, even if you have no content. A render box without a size is an error.

## Parent Data

Parent data is the per-child storage that the parent owns and uses for layout bookkeeping — at minimum it holds the child's offset, but you can extend it to carry whatever information your layout needs.

If you need to attach extra per-child information (an index, a flex factor, a custom alignment, etc.), subclass `BoxParentData` and override `setupParentData` to install your subclass when a child is adopted:

```dart
@override
void setupParentData(RenderBox child) {
  if (child.parentData is! MyParentData) {
    child.parentData = MyParentData();
  }
}
```

This method is called for every child as it's attached. It's the only sanctioned place to initialize parent data.

## Intrinsic Sizing

Intrinsic sizing is the framework's way of asking your render object hypothetical questions about its size before a real layout happens — questions like "what's the smallest width you can be without overflowing?"

If your render object might be placed inside something that asks for intrinsic sizes — like `IntrinsicHeight`, `IntrinsicWidth`, or certain `Table` configurations — override these four methods to answer:

- `computeMinIntrinsicWidth(double height)`
- `computeMaxIntrinsicWidth(double height)`
- `computeMinIntrinsicHeight(double width)`
- `computeMaxIntrinsicHeight(double height)`

Intrinsic sizing is expensive — it often requires laying out children speculatively — and Flutter loudly discourages overusing it. If nothing in your tree calls these, you can skip them. But if your render object claims to support intrinsic sizing, the answers must be consistent with what you'd actually produce during `performLayout`. Lying here causes layout glitches that are nearly impossible to track down.

> **Aside:** A common mistake is computing intrinsics by calling `child.layout(...)` inside these methods. Don't. Use the child's own intrinsic methods (`child.getMinIntrinsicWidth(...)`, etc.). Laying out a child during intrinsic measurement corrupts its layout state.
> 

## Dry Layout

Dry layout is a way to report what your size *would* be under a given set of constraints, without actually performing layout or mutating any state.

`computeDryLayout(BoxConstraints constraints)` is used by widgets that need to peek at sizes — `IntrinsicHeight` is a common caller. If your layout can be computed without laying out children (or by calling `child.getDryLayout(...)` on each), implement it. If it genuinely can't — for example, your size depends on a baseline that requires real layout — return `Size.zero` and the framework will fall back, though this is increasingly considered a smell. As of recent Flutter versions, returning a meaningful dry layout is the expected default.

## Baselines

Baselines describe how your render object aligns to a text baseline, which matters when you're placed inside something like a `Row` with `CrossAxisAlignment.baseline`.

If baseline alignment is meaningful for your widget, override `computeDistanceToActualBaseline(TextBaseline baseline)`. Return the distance from your top edge to the baseline in question, or `null` if you have no baseline. For containers, the answer is usually "the baseline of my first/relevant child, plus that child's offset."

```dart
@override
double? computeDistanceToActualBaseline(TextBaseline baseline) {
  final child = firstChild;
  if (child == null) return null;
  final childBaseline = child.getDistanceToActualBaseline(baseline);
  if (childBaseline == null) return null;
  final childOffset = (child.parentData! as BoxParentData).offset;
  return childBaseline + childOffset.dy;
}
```

Most layouts don't need this. Implement it only if baseline alignment is meaningful for your widget.

## When Layout Re-Runs

Knowing when layout re-runs is essential because Flutter is aggressive about avoiding unnecessary layout work — your `performLayout` only runs when the framework thinks it needs to.

Your `performLayout` will be called when:

- Your constraints change.
- You're marked dirty via `markNeedsLayout()`.
- A child you said you cared about (remember `parentUsesSize`) changes size.

If you change any property on your render object that affects layout, you must call `markNeedsLayout()` in the setter. Forgetting this is the single most common bug in custom render objects — the property changes, but the screen doesn't update because nothing told the framework to relayout.

```dart
set spacing(double value) {
  if (_spacing == value) return;
  _spacing = value;
  markNeedsLayout();
}
```

The early return matters too: marking dirty when nothing changed is wasted work and can cause infinite layout loops in pathological cases.

## Relayout Boundaries

Relayout boundaries are how Flutter localizes layout work — points in the tree where a child's relayout cannot affect its parent, so dirtying a descendant doesn't propagate upward.

A render object automatically becomes a relayout boundary when its constraints are tight (i.e., a single size satisfies them) or when its parent isn't using its size. You don't usually manage this manually, but it explains why `parentUsesSize: true` matters: it disables this optimization, intentionally, when you need to know about child changes. The framework gets this right if you communicate honestly through `parentUsesSize`.

## Text Direction

Text direction matters when your layout has a notion of "start" and "end" rather than strictly "left" and "right" — for example, a row that should place its first child on the left in English locales but on the right in Arabic or Hebrew locales. If your layout is purely geometric (centered, stacked, absolute-positioned), you can ignore text direction entirely.

The text direction can change at runtime: a user might switch their app's locale, or a subtree might be wrapped in a `Directionality` widget that overrides the ambient direction. Render objects don't read from `BuildContext`, so the value has to be pushed down to you. The conventional pattern is for the corresponding widget to read `Directionality.of(context)` in its `build`-equivalent and forward the result to the render object — both at creation and on update. For a `RenderObjectWidget`, that means implementing both `createRenderObject` and `updateRenderObject`:

```dart
class MyDirectionalWidget extends SingleChildRenderObjectWidget {
  const MyDirectionalWidget({super.key, super.child});

  @override
  MyRenderObject createRenderObject(BuildContext context) {
    return MyRenderObject(textDirection: Directionality.of(context));
  }

  @override
  void updateRenderObject(BuildContext context, MyRenderObject renderObject) {
    renderObject.textDirection = Directionality.of(context);
  }
}
```

On the render object side, expose `textDirection` as a property that marks the render object dirty whenever it changes:

```dart
TextDirection _textDirection;
TextDirection get textDirection => _textDirection;
set textDirection(TextDirection value) {
  if (_textDirection == value) return;
  _textDirection = value;
  markNeedsLayout();
}
```

`Directionality.of(context)` sets up the dependency on the nearest `Directionality` widget, so when the ambient text direction changes, the framework rebuilds your widget and `updateRenderObject` runs with the new value. Inside `performLayout`, branch on `_textDirection` when deciding where children go — there's no automatic mirroring, your render object owns this entirely.

## Performance Notes

Performance matters in layout because `performLayout` can run every frame, so small inefficiencies compound quickly.

A few things to keep in mind:

- **Don't allocate inside `performLayout` if you can avoid it.** Reuse objects where reasonable.
- **Lay each child out at most once per layout pass.** Multiple `child.layout(...)` calls on the same child in one pass are legal but expensive and usually indicate a design problem. If you genuinely need to (some layouts inherently require two passes, like baseline-aligned rows), be deliberate about it.
- **Don't read `child.size` before calling `child.layout(...)`.** The size from a previous frame may be stale, and the framework will assert.