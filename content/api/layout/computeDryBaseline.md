---
title: computeDryBaseline()
description: Implement the computeDryBaseline() method in a custom Render Object.
layout: api
order: 11
---
`computeDryBaseline()` returns the distance from the top of the render object to its text baseline — without performing a real layout. It is the dry counterpart to `getDistanceToBaseline()`, called when a parent needs baseline information before committing to a layout pass (for example, when aligning children by baseline in a row).

The method receives a `BoxConstraints` and a `TextBaseline` (either `TextBaseline.alphabetic` or `TextBaseline.ideographic`). It must return the baseline offset as a `double`, or `null` if this render object has no baseline.

Like all dry methods, `computeDryBaseline()` must be side-effect-free. Do not set `size`, position children, or call `child.layout()`. Use `child.getDryLayout()` to measure size and `child.computeDryBaseline()` to measure baselines of children.

## Default Implementation

The default implementation returns `null` — no baseline. This is correct for render objects that contain no text and should not participate in baseline alignment.

```dart
@override
double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
  return null;
}
```

## Leaf — Fixed Baseline

A render object with a known, fixed baseline distance — such as a custom text element with a fixed font size — returns a constant.

```dart
@override
double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
  // Baseline sits 14px from the top (ascent of the fixed font).
  return 14;
}
```

## Single Child — Passthrough

Delegate to the child. The child's baseline is measured in its own local coordinate space, so no offset adjustment is needed when the render object places the child at its own origin.

```dart
@override
double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
  return child?.computeDryBaseline(constraints, baseline);
}
```

## Single Child — With Padding

When the render object adds padding above the child, the child is shifted downward. Add the top padding to the child's baseline to bring it back into the parent's coordinate space.

```dart
static const double _paddingTop = 12;
static const double _paddingHorizontal = 16;

@override
double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
  if (child == null) return null;
  final BoxConstraints innerConstraints = constraints.deflate(
    const EdgeInsets.symmetric(horizontal: _paddingHorizontal, vertical: _paddingTop),
  );
  final double? childBaseline =
      child!.computeDryBaseline(innerConstraints, baseline);
  if (childBaseline == null) return null;
  return childBaseline + _paddingTop;
}
```

## Multiple Children — First Baseline

For containers that stack children vertically, the baseline is typically that of the first child that has one. Each child after the first is shifted down by the accumulated height of the children above it.

```dart
@override
double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
  double yOffset = 0;
  RenderBox? child = firstChild;
  while (child != null) {
    final Size childSize = child.getDryLayout(constraints);
    final double? childBaseline =
        child.computeDryBaseline(constraints, baseline);
    if (childBaseline != null) {
      return yOffset + childBaseline;
    }
    yOffset += childSize.height;
    child = (child.parentData! as ContainerBoxParentData<RenderBox>).nextSibling;
  }
  return null;
}
```

## Multiple Children — Baseline Alignment

For a row that aligns children along a shared baseline, the render object first finds the deepest baseline among all children, uses that to compute each child's vertical offset, then reports the shared baseline relative to its own top edge.

```dart
@override
double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
  // Find the maximum baseline distance among all children.
  double maxBaseline = 0;
  bool anyBaseline = false;
  RenderBox? child = firstChild;
  while (child != null) {
    final double? childBaseline =
        child.computeDryBaseline(constraints.loosen(), baseline);
    if (childBaseline != null) {
      if (childBaseline > maxBaseline) maxBaseline = childBaseline;
      anyBaseline = true;
    }
    child = (child.parentData! as ContainerBoxParentData<RenderBox>).nextSibling;
  }
  return anyBaseline ? maxBaseline : null;
}
```
