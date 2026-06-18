---
title: computeDistanceToActualBaseline()
description: Implement the computeDistanceToActualBaseline() method in a custom Render Object.
layout: api
order: 12
---
`computeDistanceToActualBaseline()` returns the distance from the top of the render object to its text baseline, measured in the render object's own local coordinate space. It is called after layout by `getDistanceToBaseline()`, which handles caching and the `onlyReal` flag before delegating here.

Override this method — not `getDistanceToBaseline()` — in `RenderBox` subclasses. It is called once per layout cycle; the result is cached until the next layout.

Because layout has already run when this is called, child sizes and positions are known. Query children with `child.getDistanceToBaseline()` and add the child's vertical offset from its parent data to convert the result into the parent's coordinate space.

## Default Implementation

Returns `null` — no baseline. Correct for any render object that contains no text and should not participate in baseline alignment.

```dart
@override
double? computeDistanceToActualBaseline(TextBaseline baseline) {
  return null;
}
```

## Leaf — Fixed Baseline

Return a constant when the baseline is determined by a fixed font or design specification rather than live text layout.

```dart
@override
double? computeDistanceToActualBaseline(TextBaseline baseline) {
  return baseline == TextBaseline.alphabetic ? 14.0 : null;
}
```

## Single Child — Passthrough

Delegate to the child when the render object places the child at its own origin. The child's baseline is already expressed in the parent's coordinate space.

```dart
@override
double? computeDistanceToActualBaseline(TextBaseline baseline) {
  return child?.getDistanceToBaseline(baseline, onlyReal: true);
}
```

## Single Child — With Offset

When the child is positioned at a non-zero offset (due to padding or explicit placement computed during layout), add the child's vertical offset to its baseline distance.

```dart
@override
double? computeDistanceToActualBaseline(TextBaseline baseline) {
  if (child == null) return null;
  final BoxParentData childParentData = child!.parentData! as BoxParentData;
  final double? childBaseline =
      child!.getDistanceToBaseline(baseline, onlyReal: true);
  if (childBaseline == null) return null;
  return childBaseline + childParentData.offset.dy;
}
```

## Multiple Children — First Baseline

For vertically stacked children, report the first baseline found, adjusted by that child's vertical position within the parent.

```dart
@override
double? computeDistanceToActualBaseline(TextBaseline baseline) {
  RenderBox? child = firstChild;
  while (child != null) {
    final BoxParentData childParentData = child.parentData! as BoxParentData;
    final double? childBaseline =
        child.getDistanceToBaseline(baseline, onlyReal: true);
    if (childBaseline != null) {
      return childBaseline + childParentData.offset.dy;
    }
    child = childParentData.nextSibling;
  }
  return null;
}
```

## Multiple Children — Baseline Alignment

For a row whose children were aligned to a shared baseline during layout, each child's offset already encodes the alignment. Any child with a baseline gives the same answer — its baseline plus its vertical offset equals the shared baseline distance from the parent's top edge.

```dart
@override
double? computeDistanceToActualBaseline(TextBaseline baseline) {
  RenderBox? child = firstChild;
  while (child != null) {
    final BoxParentData childParentData = child.parentData! as BoxParentData;
    final double? childBaseline =
        child.getDistanceToBaseline(baseline, onlyReal: true);
    if (childBaseline != null) {
      return childBaseline + childParentData.offset.dy;
    }
    child = childParentData.nextSibling;
  }
  return null;
}
```
