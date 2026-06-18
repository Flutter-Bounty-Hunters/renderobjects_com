---
title: compute[Min/Max]Intrinsic[Width/Height]()
description: "Implement intrinsic sizing methods"
layout: api
order: 9
---
The four intrinsic sizing methods answer hypothetical sizing questions without performing a real layout pass. They are called by `IntrinsicWidth`, `IntrinsicHeight`, and `Table` to measure render objects before constraints are known.

Each method receives the already-known dimension and returns a preferred size for the other:

| Method | Argument | Returns |
|---|---|---|
| `computeMinIntrinsicWidth(height)` | available height | smallest width that avoids clipping content |
| `computeMaxIntrinsicWidth(height)` | available height | width beyond which extra space adds no value |
| `computeMinIntrinsicHeight(width)` | available width | smallest height that avoids clipping content |
| `computeMaxIntrinsicHeight(width)` | available width | height beyond which extra space adds no value |

For most render objects, min and max intrinsic width are equal. They differ when content can reflow — a paragraph of text has a narrow min intrinsic width (the longest unbreakable word) and a wide max intrinsic width (the full text unwrapped on one line).

When measuring children from inside these methods, always call the public `child.getMinIntrinsicWidth()` / `child.getMaxIntrinsicWidth()` etc. — not the `compute*` variants directly.

## Default Implementation
All four methods return `0` by default. This is acceptable for render objects that only ever live inside a scrollable viewport.

To ensure that your render object is robust across many use-cases, you should implement all 4 methods.

## Leaf — Fixed Size
A render object with a fixed natural size ignores the argument and returns that size regardless of the available dimension.

```dart
static const double _width = 48;
static const double _height = 48;

@override
double computeMinIntrinsicWidth(double height) => _width;

@override
double computeMaxIntrinsicWidth(double height) => _width;

@override
double computeMinIntrinsicHeight(double width) => _height;

@override
double computeMaxIntrinsicHeight(double width) => _height;
```

## Single Child — Passthrough

Delegate directly to the child when the render object imposes no additional sizing logic of its own.

```dart
@override
double computeMinIntrinsicWidth(double height) =>
    child!.getMinIntrinsicWidth(height);

@override
double computeMaxIntrinsicWidth(double height) =>
    child!.getMaxIntrinsicWidth(height);

@override
double computeMinIntrinsicHeight(double width) =>
    child!.getMinIntrinsicHeight(width);

@override
double computeMaxIntrinsicHeight(double width) =>
    child!.getMaxIntrinsicHeight(width);
```

## Single Child — With Padding

Subtract padding from the argument before asking the child, then add it back to the result.

```dart
static const double _horizontal = 32; // left + right padding
static const double _vertical = 24;   // top + bottom padding

@override
double computeMinIntrinsicWidth(double height) =>
    child!.getMinIntrinsicWidth(math.max(0, height - _vertical)) + _horizontal;

@override
double computeMaxIntrinsicWidth(double height) =>
    child!.getMaxIntrinsicWidth(math.max(0, height - _vertical)) + _horizontal;

@override
double computeMinIntrinsicHeight(double width) =>
    child!.getMinIntrinsicHeight(math.max(0, width - _horizontal)) + _vertical;

@override
double computeMaxIntrinsicHeight(double width) =>
    child!.getMaxIntrinsicHeight(math.max(0, width - _horizontal)) + _vertical;
```

## Column Layout (Children Stacked Vertically)

Width is the maximum across all children. Height is the sum of all children's heights.

```dart
@override
double computeMinIntrinsicWidth(double height) {
  double maxWidth = 0;
  RenderBox? child = firstChild;
  while (child != null) {
    maxWidth = math.max(maxWidth, child.getMinIntrinsicWidth(double.infinity));
    child = (child.parentData! as ContainerBoxParentData<RenderBox>).nextSibling;
  }
  return maxWidth;
}

@override
double computeMaxIntrinsicWidth(double height) {
  double maxWidth = 0;
  RenderBox? child = firstChild;
  while (child != null) {
    maxWidth = math.max(maxWidth, child.getMaxIntrinsicWidth(double.infinity));
    child = (child.parentData! as ContainerBoxParentData<RenderBox>).nextSibling;
  }
  return maxWidth;
}

@override
double computeMinIntrinsicHeight(double width) {
  double totalHeight = 0;
  RenderBox? child = firstChild;
  while (child != null) {
    totalHeight += child.getMinIntrinsicHeight(width);
    child = (child.parentData! as ContainerBoxParentData<RenderBox>).nextSibling;
  }
  return totalHeight;
}

@override
double computeMaxIntrinsicHeight(double width) {
  double totalHeight = 0;
  RenderBox? child = firstChild;
  while (child != null) {
    totalHeight += child.getMaxIntrinsicHeight(width);
    child = (child.parentData! as ContainerBoxParentData<RenderBox>).nextSibling;
  }
  return totalHeight;
}
```

## Row Layout (Children Side by Side)

Width is the sum across all children. Height is the maximum across all children.

```dart
@override
double computeMinIntrinsicWidth(double height) {
  double totalWidth = 0;
  RenderBox? child = firstChild;
  while (child != null) {
    totalWidth += child.getMinIntrinsicWidth(height);
    child = (child.parentData! as ContainerBoxParentData<RenderBox>).nextSibling;
  }
  return totalWidth;
}

@override
double computeMaxIntrinsicWidth(double height) {
  double totalWidth = 0;
  RenderBox? child = firstChild;
  while (child != null) {
    totalWidth += child.getMaxIntrinsicWidth(height);
    child = (child.parentData! as ContainerBoxParentData<RenderBox>).nextSibling;
  }
  return totalWidth;
}

@override
double computeMinIntrinsicHeight(double width) {
  double maxHeight = 0;
  RenderBox? child = firstChild;
  while (child != null) {
    maxHeight = math.max(maxHeight, child.getMinIntrinsicHeight(double.infinity));
    child = (child.parentData! as ContainerBoxParentData<RenderBox>).nextSibling;
  }
  return maxHeight;
}

@override
double computeMaxIntrinsicHeight(double width) {
  double maxHeight = 0;
  RenderBox? child = firstChild;
  while (child != null) {
    maxHeight = math.max(maxHeight, child.getMaxIntrinsicHeight(double.infinity));
    child = (child.parentData! as ContainerBoxParentData<RenderBox>).nextSibling;
  }
  return maxHeight;
}
```
