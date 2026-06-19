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
  size = constraints.biggest;
}
```

## No Children - Expand Size Up To A Point
Example where the custom Render Object has a preferred size but yields to whatever constraints the parent imposes.

```dart
static const Size _preferredSize = Size(300, 200);

void performLayout() {
  size = constraints.constrain(_preferredSize);
}
```

## One Child - Same Size As Child
Example where the custom Render Object sets its size to match its child. The child is given the same constraints so it can shrink or grow up to the available space.

```dart
void performLayout() {
  if (child != null) {
    child!.layout(constraints, parentUsesSize: true);
    size = child!.size;
  } else {
    size = constraints.smallest;
  }
}
```

## One Child - Take Up All Space, Position the Child
Example where the custom Render Object takes up all space, and if its child is smaller, centers it. The child receives loose constraints so it can size itself naturally.

```dart
void performLayout() {
  size = constraints.biggest;
  if (child != null) {
    child!.layout(constraints.loosen(), parentUsesSize: true);
    final BoxParentData childParentData = child!.parentData! as BoxParentData;
    childParentData.offset = Offset(
      (size.width - child!.size.width) / 2,
      (size.height - child!.size.height) / 2,
    );
  }
}
```

## Multi-Child - Scaffold Layout
Example where the custom Render Object positions an app bar at the top, a nav bar at the bottom, and stretches the body content between the two.

The app bar and bottom nav are given the full width and their natural height. The body fills whatever vertical space remains between them.

```dart
void performLayout() {
  size = constraints.biggest;
  double top = 0;
  double bottom = size.height;

  // App bar: full width, natural height, pinned to the top.
  if (_appBar != null) {
    _appBar!.layout(
      BoxConstraints.tightFor(width: size.width),
      parentUsesSize: true,
    );
    (_appBar!.parentData! as BoxParentData).offset = Offset.zero;
    top += _appBar!.size.height;
  }

  // Bottom nav: full width, natural height, pinned to the bottom.
  if (_bottomNav != null) {
    _bottomNav!.layout(
      BoxConstraints.tightFor(width: size.width),
      parentUsesSize: true,
    );
    bottom -= _bottomNav!.size.height;
    (_bottomNav!.parentData! as BoxParentData).offset = Offset(0, bottom);
  }

  // Body: fills the remaining space between app bar and bottom nav.
  if (_body != null) {
    _body!.layout(
      BoxConstraints.tightFor(width: size.width, height: (bottom - top).clamp(0, double.infinity)),
      parentUsesSize: false,
    );
    (_body!.parentData! as BoxParentData).offset = Offset(0, top);
  }
}
```

## Run Build During Layout
Some render objects need to trigger a widget build during layout — typically to pass the incoming constraints to a widget builder callback, as `LayoutBuilder` does. This is only possible using `LayoutCallbackMixin`, which provides `invokeLayoutCallback`. Calling `setState` or `markNeedsBuild` directly during layout is illegal and will throw.

Mix `LayoutCallbackMixin` into the class, store the callback, and call it inside `performLayout()`.

```dart
// class RenderMyBuilder extends RenderBox
//     with RenderObjectWithChildMixin<RenderBox>, LayoutCallbackMixin {

LayoutCallback<BoxConstraints>? _callback;

void updateCallback(LayoutCallback<BoxConstraints> value) {
  if (value == _callback) return;
  _callback = value;
  markNeedsLayout();
}

void performLayout() {
  assert(_callback != null);
  // invokeLayoutCallback is the only sanctioned way to trigger a build
  // during layout. It is guarded by the framework to prevent re-entrant
  // layout or illegal tree mutations.
  invokeLayoutCallback(_callback!);
  if (child != null) {
    child!.layout(constraints, parentUsesSize: true);
    size = child!.size;
  } else {
    size = constraints.smallest;
  }
}
```

## Multi-Child - Facepile Layout
A facepile is a row of partially overlapping avatars. Each avatar is given the same fixed size, and each one is offset horizontally by less than its full width so they stack with an overlap.

```dart
static const double _avatarSize = 40.0;
static const double _overlap = 12.0;

void performLayout() {
  final BoxConstraints childConstraints = BoxConstraints.tight(
    const Size(_avatarSize, _avatarSize),
  );

  double x = 0;
  RenderBox? child = firstChild;
  while (child != null) {
    child.layout(childConstraints, parentUsesSize: false);
    final BoxParentData childParentData = child.parentData! as BoxParentData;
    childParentData.offset = Offset(x, 0);
    child = childParentData.nextSibling;
    x += _avatarSize - _overlap;
  }

  // The last avatar is not overlapped on its right side, so add back
  // the overlap that was subtracted in the final iteration.
  final double totalWidth = childCount == 0
      ? 0
      : x - (_avatarSize - _overlap) + _avatarSize;
  size = constraints.constrain(Size(totalWidth, _avatarSize));
}
```

## Multi-Child - Virtualized Children
For large lists or carousels, laying out every child regardless of visibility wastes CPU time. The pattern below lays out only children whose positions fall within the visible viewport, determined by a scroll offset tracked on the render object.

Children outside the viewport still exist in the child list and retain their parent data offsets, but `layout()` is not called for them. They are skipped in `paint()` as well.

```dart
static const double _itemExtent = 160.0;

double _scrollOffset = 0.0;

void performLayout() {
  size = constraints.biggest;

  final double viewportStart = _scrollOffset;
  final double viewportEnd = _scrollOffset + size.width;

  RenderBox? child = firstChild;
  int index = 0;
  while (child != null) {
    final BoxParentData childParentData = child.parentData! as BoxParentData;
    final double itemStart = index * _itemExtent;
    final double itemEnd = itemStart + _itemExtent;

    if (itemEnd > viewportStart && itemStart < viewportEnd) {
      // Child is at least partially visible — lay it out.
      child.layout(
        BoxConstraints.tightFor(width: _itemExtent, height: size.height),
        parentUsesSize: false,
      );
    }

    // Store the position in layout space; paint() applies the scroll offset.
    childParentData.offset = Offset(itemStart, 0);

    child = childParentData.nextSibling;
    index++;
  }
}
```
