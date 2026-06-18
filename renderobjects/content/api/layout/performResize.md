---
title: performResize()
description: Implement the performResize() method in a custom Render Object.
layout: api
order: 13
---
`performResize()` sets the render object's `size` using only the incoming `BoxConstraints`, before children are laid out. It is only called when `sizedByParent` returns `true`.

Separating sizing from child layout has a performance benefit: if the constraints haven't changed since the last frame, the framework can skip `performResize()` and go straight to `performLayout()`. For render objects whose size depends only on constraints — not on child content — this avoids redundant work.

When `sizedByParent` is `true`:
- `performResize()` must set `size`. It may only use `constraints` — children are not accessible here.
- `performLayout()` must **not** set `size`. It runs afterward to position and lay out children.

## Default — Not Called

`sizedByParent` defaults to `false`, so `performResize()` is never called. Size is set inside `performLayout()` instead. This is the right choice whenever the render object's size depends on its children.

## Fill Available Space

The most common use — the render object always expands to fill whatever space the parent offers.

```dart
@override
bool get sizedByParent => true;

@override
void performResize() {
  size = constraints.biggest;
}

@override
void performLayout() {
  // Size is already set. Lay out and position children here.
  child?.layout(constraints, parentUsesSize: false);
}
```

## Shrink to Minimum

A render object that always takes the smallest allowed size — useful for a decorative element that should never push other content aside.

```dart
@override
bool get sizedByParent => true;

@override
void performResize() {
  size = constraints.smallest;
}
```

## Fixed Aspect Ratio

Derive height from the available width to maintain a specific aspect ratio, then clamp to the constraints.

```dart
// Width-to-height ratio (e.g. 16/9 for widescreen).
static const double _aspectRatio = 16 / 9;

@override
bool get sizedByParent => true;

@override
void performResize() {
  final double width = constraints.maxWidth;
  final double height = (width / _aspectRatio).clamp(
    constraints.minHeight,
    constraints.maxHeight,
  );
  size = Size(width, height);
}
```

## Fixed Natural Size Clamped to Constraints

A render object with a preferred size that yields to whatever constraints the parent imposes.

```dart
static const Size _naturalSize = Size(200, 48);

@override
bool get sizedByParent => true;

@override
void performResize() {
  size = constraints.constrain(_naturalSize);
}
```
