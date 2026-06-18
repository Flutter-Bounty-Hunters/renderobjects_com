---
title: applyPaintTransform()
description: Implement the applyPaintTransform() method in a custom Render Object.
layout: api
order: 31
---
`applyPaintTransform()` mutates a `Matrix4` to describe the coordinate transformation from the parent's paint coordinate space to a given child's paint coordinate space. The framework accumulates these matrices up the tree to implement `localToGlobal()`, `globalToLocal()`, hit testing with transforms, and the widget inspector's highlight overlays.

The method receives the child render object and a `Matrix4` that already contains the parent's accumulated transform. Mutate `transform` in place — do not replace it. The most common mutation is a translation by the child's paint offset.

Override this method whenever your render object positions children at a non-zero offset or applies a transform (scale, rotation, perspective) during painting.

## Default Implementation

`RenderBox` provides a default implementation that applies the child's `BoxParentData.offset` as a translation. If all your children are placed via `BoxParentData.offset` and you paint them with `context.paintChild(child, offset + childParentData.offset)`, the default is correct and no override is needed.

```dart
// Default in RenderBox — no override required when using BoxParentData.offset.
@override
void applyPaintTransform(RenderObject child, Matrix4 transform) {
  final BoxParentData childParentData = child.parentData! as BoxParentData;
  transform.translate(childParentData.offset.dx, childParentData.offset.dy);
}
```

## Explicit Offset

When your layout code stores child positions in a field rather than in `BoxParentData`, apply that offset manually.

```dart
// _childOffset is computed and stored during performLayout().
Offset _childOffset = Offset.zero;

@override
void applyPaintTransform(RenderObject child, Matrix4 transform) {
  transform.translate(_childOffset.dx, _childOffset.dy);
}
```

## Scale and Translate

When a child is both positioned and scaled during painting, apply the translation first, then the scale — matching the order the operations are applied on the canvas.

```dart
@override
void applyPaintTransform(RenderObject child, Matrix4 transform) {
  final BoxParentData childParentData = child.parentData! as BoxParentData;
  transform
    ..translate(childParentData.offset.dx, childParentData.offset.dy)
    ..scale(_scale, _scale);
}
```

## Arbitrary Transform Matrix

When a child is painted with a full transform matrix (rotation, skew, perspective), multiply that matrix directly into the accumulated transform.

```dart
// _childTransform is a Matrix4 computed during performLayout() and
// stored in the child's parent data.
@override
void applyPaintTransform(RenderObject child, Matrix4 transform) {
  final TransformParentData childParentData =
      child.parentData! as TransformParentData;
  transform.multiply(childParentData.transform);
}
```

## Multiple Children

With multiple children, look up the specific child's offset from its parent data. This is identical to the single-child case — the method is called once per child, so the same implementation handles all of them.

```dart
@override
void applyPaintTransform(RenderObject child, Matrix4 transform) {
  final BoxParentData childParentData = child.parentData! as BoxParentData;
  transform.translate(childParentData.offset.dx, childParentData.offset.dy);
}
```

## Conditionally Hidden Child

When a child is not painted at all in certain states — an off-screen page, a collapsed panel — `applyPaintTransform()` is still called. Apply an irreversible transform (such as zeroing the matrix) so that hit testing and coordinate conversion correctly report that the child is unreachable.

```dart
@override
void applyPaintTransform(RenderObject child, Matrix4 transform) {
  if (!_isVisible) {
    // Child is not painted; zero the matrix so coordinate conversion
    // produces a non-invertible result and hit tests are rejected.
    transform.setZero();
  } else {
    final BoxParentData childParentData = child.parentData! as BoxParentData;
    transform.translate(childParentData.offset.dx, childParentData.offset.dy);
  }
}
```
