---
title: computeDryLayout()
description: Implement the computeDryLayout() method in a custom Render Object.
layout: api
order: 8
---
`computeDryLayout()` answers the question "what size would you be under these constraints?" without actually performing layout. It is the engine behind `getDryLayout()`, which is called by `IntrinsicWidth`, `IntrinsicHeight`, and any other render object that needs to measure a child before committing to a layout pass.

Unlike `performLayout()`, `computeDryLayout()` must not have side effects. It cannot set `size`, position children, or call `child.layout()`. It may only call `child.getDryLayout()` to measure children, then return a `Size`.

## Default Implementation

The default implementation throws an `UnsupportedError`. Any render object that could appear inside an `IntrinsicWidth` or `IntrinsicHeight` must override this method. If your render object will never be used in that context, override it to assert instead of silently failing.

```dart
@override
Size computeDryLayout(BoxConstraints constraints) {
  assert(debugCannotComputeDryLayout(
    reason: 'MyRenderBox does not support dry layout.',
  ));
  return Size.zero;
}
```

## No Children — Return a Fixed Size

A leaf render object simply applies the constraints to its natural size with no children to measure.

```dart
@override
Size computeDryLayout(BoxConstraints constraints) {
  return constraints.constrain(const Size(200, 48));
}
```

## No Children — Take Up All Available Space

```dart
@override
Size computeDryLayout(BoxConstraints constraints) {
  return constraints.biggest;
}
```

## One Child — Match Child Size

Measure the child with `getDryLayout()` and return that size directly. This mirrors the `performLayout()` pattern but uses the dry-layout equivalents throughout.

```dart
@override
Size computeDryLayout(BoxConstraints constraints) {
  final Size childSize = child!.getDryLayout(constraints);
  return constraints.constrain(childSize);
}
```

## One Child — Add Padding

Apply padding to the constraints before measuring the child, then add it back to the returned size.

```dart
@override
Size computeDryLayout(BoxConstraints constraints) {
  const EdgeInsets padding = EdgeInsets.all(16);
  final BoxConstraints innerConstraints = constraints.deflate(padding);
  final Size childSize = child!.getDryLayout(innerConstraints);
  return constraints.constrain(padding.inflateSize(childSize));
}
```

## Multiple Children — Largest Child Determines Size

Measure every child and return the size of the largest one. Useful for stack-like layouts where all children occupy the same space.

```dart
@override
Size computeDryLayout(BoxConstraints constraints) {
  Size largest = Size.zero;
  RenderBox? child = firstChild;
  while (child != null) {
    final Size childSize = child.getDryLayout(constraints);
    if (childSize.width > largest.width || childSize.height > largest.height) {
      largest = childSize;
    }
    child = (child.parentData! as ContainerBoxParentData<RenderBox>).nextSibling;
  }
  return constraints.constrain(largest);
}
```

## Multiple Children — Sum Along an Axis

For row or column layouts, sum child sizes along the main axis and take the maximum along the cross axis.

```dart
@override
Size computeDryLayout(BoxConstraints constraints) {
  double totalWidth = 0;
  double maxHeight = 0;
  RenderBox? child = firstChild;
  while (child != null) {
    final Size childSize = child.getDryLayout(constraints.loosen());
    totalWidth += childSize.width;
    if (childSize.height > maxHeight) maxHeight = childSize.height;
    child = (child.parentData! as ContainerBoxParentData<RenderBox>).nextSibling;
  }
  return constraints.constrain(Size(totalWidth, maxHeight));
}
```
