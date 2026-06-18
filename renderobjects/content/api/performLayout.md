---
title: performLayout()
description: Implement the performLayout() method in a custom Render Object.
layout: api
order: 10
---
The `performLayout()` method has two responsibilities:
 * Run layout on any children and position them (if there are children)
 * Choose the size for the Render Object

## Default Implementation - There Is None
There is no default implementation for `performLayout()`. Every custom Render Object will have to do something in the `performLayout()` method, even if it's simple.

## No Children - Take Up All Space
Example where the custom Render Object takes up all the space that it can.

```dart
void performLayout() {
  // TODO:
}
```

## No Children - Expand Size Up To A Point
Example where the custom Render Object takes up all space, up to a point, and then stops growing.

```dart
void performLayout() {
  // TODO:
}
```

## One Child - Same Size As Child
Example where the custom Render Object sets its size to match its child.

```dart
void performLayout() {
  // TODO:
}
```

## One Child - Take Up All Space, Position the Child
Example where the custom Render Object takes up all space, and if its child is smaller, positions that child at a desired (x,y).

```dart
void performLayout() {
  // TODO:
}
```

## Multi-Child - Scaffold Layout
Example where the custom Render Object positions an app bar at the top, a nav bar at the bottom, and stretches the body content between the two.

```dart
void performLayout() {
  // TODO:
}
```

## Run Build During Layout
TODO:

## Multi-Child - Facepile Layout
TODO:

## Multi-Child - Virtualized Children
TODO: Maybe an example of a carousel