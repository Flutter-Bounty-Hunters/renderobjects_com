---
title: hitTest()
description: Implement the hitTest() method in a custom Render Object.
layout: api
order: 20
---
The `hitTest()` method in a `RenderBox` reports where the `RenderBox` appears on screen by logging or ignoring a hit test.

If the hit test is logged by the `RenderBox`, the `RenderBox` is saying "I'm beneath that point". If the `RenderBox` logs nothing, then it's saying "I'm not beneath that point".

Note: The `hitTest()` behavior is most often associated with finger and mouse gesture detection, but the method isn't limited to gesture interactions. The `hitTest()` method technically answers the question "Which Render Objects sit beneath this point on the screen?". That question is far broader than just gesture recognition.

## Default Implementation
Typically, `RenderBox` implementations mixin `RenderBoxContainerDefaultsMixin`. When using that mixin, the following implementation is all that's needed to correctly implement hit testing.

```dart
class MyRenderBox extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, BoxParentData>,
         RenderBoxContainerDefaultsMixin<RenderBox, BoxParentData> {

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (size.contains(position)) {
      defaultHitTestChildren(result, position: position);
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}
```

## Children Hittable First, Parent Second (with Child Offsets)
Hit-test children first, accounting for the child offset within the parent. Then hit-test the parent.

```dart
bool hitTeset(BoxHitTestResult result, {required Offset position}) {
  // Hit test our children.
  ChildType? child = lastChild;
  while (child != null) {
    // The x, y parameters have the top left of the node's box as the origin.
    final childParentData = child.parentData! as ParentDataType;
    final bool isHit = result.addWithPaintOffset(
      offset: childParentData.offset,
      position: position,
      hitTest: (BoxHitTestResult result, Offset localPosition) {
        assert(localPosition == position - childParentData.offset);
        return child!.hitTest(result, position: localPosition);
      },
    );
    if (isHit) {
      return true;
    }
    child = childParentData.previousSibling;
  }

  // Hit test us (the parent).
  if (size.contains(position)) {
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  return false;
}
```

## Only Children Hittable (with Child Offsets)
Hit-test the children, accounting for the child offset within the parent. Don't hit test the parent.

```dart
bool hitTeset(BoxHitTestResult result, {required Offset position}) {
  ChildType? child = lastChild;
  while (child != null) {
    // The x, y parameters have the top left of the node's box as the origin.
    final childParentData = child.parentData! as ParentDataType;
    final bool isHit = result.addWithPaintOffset(
      offset: childParentData.offset,
      position: position,
      hitTest: (BoxHitTestResult result, Offset localPosition) {
        assert(localPosition == position - childParentData.offset);
        return child!.hitTest(result, position: localPosition);
      },
    );
    if (isHit) {
      return true;
    }
    child = childParentData.previousSibling;
  }
  return false;
}
```

## Transformed Children
`RenderBox`s whose children are transformed with more than just an offset (e.g., rotation, scale, skew) must report a full transform matrix.

```dart
bool hitTest(BoxHitTestResult result, {required Offset position}) {
  // Hit test our children, applying their transforms.
  ChildType? child = lastChild;
  while (child != null) {
    // This assumes that your layout code calculated each child's transformation
    // matrix and stored it with the child's parent data.
    final childParentData = child.parentData! as ParentDataType;

    final bool isHit = result.addWithPaintTransform(
      transform: childParentData.transform,
      position: position,
      hitTest: (BoxHitTestResult result, Offset localPosition) {
        return child!.hitTest(result, position: localPosition);
      },
    );
    if (isHit) {
      return true;
    }
    child = childParentData.previousSibling;
  }

  // Hit test us (the parent).
  if (size.contains(position)) {
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  return false;
}
```