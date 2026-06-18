---
title: paint()
description: Implement the paint() method in a custom Render Object.
layout: api
order: 30
---
The paint method is responsible for running `Canvas` commands, pushing engine layers, and running paint on any children.

Typically, a Render Object just paints its children in the `paint()` method. But sometimes a Render Object needs to add some decorations, visual effects, and transformations of its own.

TODO: Aside - link to relevant guides

TODO: Aside - link to default mixin documentation

## Default Implementation - Passthrough
In the simplest and most common cases, a custom Render Object forwards the call to its children, and nothing else.

The following example assumes all children are `RenderBox`s, which is usually true.

```dart
void paint(PaintingContext context, Offset offset) {
  RenderBox? child = firstChild;
  while (child != null) {
    final BoxParentData childParentData = child.parentData! as BoxParentData;
    context.paintChild(child, offset + childParentData.offset);
    child = childParentData.nextSibling;
  }
}
```

## Paint a Thermostat

## Transform Children
TODO: Maybe paint example of the same carousel as the performLayout section

TODO: Resources/Further Reading - link to relevant use-cases