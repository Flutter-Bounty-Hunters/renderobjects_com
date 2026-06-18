---
title: setupParentData()
description: Implement the setupParentData() method in a custom Render Object.
layout: api
order: 15
---
`setupParentData()` is called by the framework whenever a child render object is attached to a parent. Its job is to attach a `ParentData` object to the child — a small data structure that the parent owns and uses to store per-child layout information such as position offsets, flex factors, or grid coordinates.

Parent data is written by the parent during `performLayout()` and read back during `paint()` and `hitTest()`. The child render object never reads or writes its own parent data.

## Default Implementation
`RenderObject` provides a default implementation that attaches a plain `ParentData` instance when the child has none. This is rarely sufficient — if your render object positions children, it almost always needs at least a `BoxParentData` so it can record each child's `Offset`.

Always check the type before replacing parent data. A child might already have been given richer parent data by a subclass, and overwriting it would destroy that information.

```dart
@override
void setupParentData(RenderObject child) {
  if (child.parentData is! BoxParentData) {
    child.parentData = BoxParentData();
  }
}
```

## No Children

Leaf render objects have no children, so `setupParentData()` is never called. No override is needed.

```dart
// Nothing to do — leaf render objects don't manage children.
```

## Configure Parent Data During Layout
The `setupParentData()` method is only responsible for instantiating the parent data, not to configure it.

Parent data is configured during layout.

```dart
@override
void performLayout() {
  child!.layout(constraints, parentUsesSize: true);

  // 1. Get a reference to the parent data (which was initialized in `setupParentData`), which is
  //    attached to this child.
  final BoxParentData childParentData = child!.parentData! as BoxParentData;
  // 2. Configure the parent data that's attached to this child.
  childParentData.offset = Offset(16, 16);

  size = constraints.biggest;
}
```

## Custom Parent Data
When children need to carry extra per-child information beyond an offset, extend `ContainerBoxParentData` with additional fields.

The following example implements a wrapping layout. The parent assigns each child to a line during layout and records the line index in the child's parent data. The paint method can then read `lineIndex` to, for example, alternate background colors between lines.

```dart
class WrapParentData extends ContainerBoxParentData<RenderBox> {
  int lineIndex = 0;
}

class MyWrapRenderBox extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, WrapParentData>,
         RenderBoxContainerDefaultsMixin<RenderBox, WrapParentData> {

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! WrapParentData) {
      child.parentData = WrapParentData();
    }
  }

  @override
  void performLayout() {
    double x = 0;
    double y = 0;
    double lineHeight = 0;
    int currentLine = 0;

    RenderBox? child = firstChild;
    while (child != null) {
      final WrapParentData pd = child.parentData! as WrapParentData;
      child.layout(constraints.loosen(), parentUsesSize: true);

      if (x + child.size.width > constraints.maxWidth && x > 0) {
        y += lineHeight;
        x = 0;
        lineHeight = 0;
        currentLine++;
      }

      pd.offset = Offset(x, y);
      pd.lineIndex = currentLine; // Store the line index on every child's parent data

      x += child.size.width;
      if (child.size.height > lineHeight) lineHeight = child.size.height;
      child = pd.nextSibling;
    }

    size = Size(constraints.maxWidth, y + lineHeight);
  }
}
```

## Configuring Parent Data from the Widget Tree
Custom parent data fields can be set from the widget tree with `ParentDataWidget`. `ParentDataWidget` calls `applyParentData()` on the child render object, writes the new value, then notifies the parent to re-run layout.

Example of a `Flexible` widget, which can be used within a `Row` or `Column`:

```dart
Row(
  children: [
    //... children to the left
    Flexible(
      flex: 1.0,
      child: Placeholder(),
    ),
    //... children to the right
  ],
);
```

The implementation of `Flexible` looks something like this:

```dart
class Flexible extends ParentDataWidget<FlexParentData> {
  const Flexible({
    super.key,
    required this.flex, 
    required super.child, 
  });

  final double flex;

  @override
  void applyParentData(RenderObject renderObject) {
    final FlexParentData parentData = renderObject.parentData! as FlexParentData;
    if (parentData.flex != flex) {
      parentData.flex = flex;
      // Notify the parent that layout needs to re-run.
      final AbstractNode? targetParent = renderObject.parent;
      if (targetParent is RenderObject) {
        targetParent.markNeedsLayout();
      }
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => MyFlexWidget;
}
```

The `Row` or `Column` read the `FlexParentData` off of its children and then honor the flex factor that was set by the `Flexible` widget.

```dart
@override
void performLayout() {
  double totalFlex = 0;
  RenderBox? child = firstChild;
  while (child != null) {
    final FlexParentData pd = child.parentData! as FlexParentData;
    totalFlex += pd.flex;
    child = pd.nextSibling;
  }
  
  final double spacePerFlex = constraints.maxWidth / totalFlex;
  double xOffset = 0;

  child = firstChild;
  while (child != null) {
    // Get a reference to the child's parent data, which was configured by the `Flexible` widget.
    final FlexParentData pd = child.parentData! as FlexParentData;

    // Pull out the flex factor from the `FlexParentData` attached to the child.
    final double childWidth = spacePerFlex * pd.flex;

    child.layout(
      BoxConstraints.tightFor(width: childWidth, height: constraints.maxHeight),
      parentUsesSize: true,
    );
    pd.offset = Offset(xOffset, 0);
    xOffset += childWidth;
    child = pd.nextSibling;
  }
  size = constraints.biggest;
}
```
