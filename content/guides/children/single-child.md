---
title: Single Child
description: Implement a Render Object with a single child
layout: guides
order: 10
---
# Implementing a Custom Single-Child Element and Render Object

This guide walks through implementing a custom widget that manages exactly one optional child. We'll focus entirely on child management. Layout, paint, and other render-object responsibilities are out of scope.

The good news is that for a single-child setup, the Flutter framework provides nearly everything you need. You don't need a custom element — the standard `SingleChildRenderObjectElement` handles reconciliation perfectly, and `RenderObjectWithChildMixin` handles the render-object side. Your job is to wire them together correctly.

## What This Guide Covers

- **The Pieces Involved** — The widget, element, and render object, and which ones the framework provides for free.
- **Extending `SingleChildRenderObjectWidget`** — The widget base class that wires everything together.
- **Mixing In `RenderObjectWithChildMixin`** — The render-object plumbing for a single child.
- **How the Pieces Connect** — Where the framework hands off between widget, element, and render object.
- **What You Get For Free** — Reconciliation, mounting, updating, render-tree attachment, and reparenting, all handled by the framework.
- **Common Pitfalls** — The few traps that single-child setups still produce.

## The Pieces Involved

A single-child widget setup has three parts:

- A **widget** that exposes a `child` property.
- An **element** that reconciles the child element against the widget's `child` field.
- A **render object** that holds the resulting child render object.

The framework provides the element for free: `SingleChildRenderObjectWidget.createElement` returns a `SingleChildRenderObjectElement`, which already implements all the child-management logic you'd otherwise have to write. You almost never need to subclass the element for single-child widgets.

The framework also provides a render-object mixin (`RenderObjectWithChildMixin`) that gives your custom render object the single-child plumbing it needs.

That leaves two things you actually write: the widget (which extends a framework base class) and the render object (which mixes in a framework mixin).

## Extending `SingleChildRenderObjectWidget`

`SingleChildRenderObjectWidget` is the framework's base class for widgets with exactly one optional child. It already declares the `child` field and overrides `createElement` to return a `SingleChildRenderObjectElement`. You just extend it and provide your render object:

```dart
class MyContainer extends SingleChildRenderObjectWidget {
  const MyContainer({super.key, super.child, this.padding = 0.0});

  final double padding;

  @override
  RenderMyContainer createRenderObject(BuildContext context) {
    return RenderMyContainer(padding: padding);
  }

  @override
  void updateRenderObject(BuildContext context, RenderMyContainer renderObject) {
    renderObject.padding = padding;
  }
}
```

A few things to note:

- **`super.child`** forwards the child parameter to the base class's `child` field. You don't redeclare `child` yourself.
- **`createRenderObject`** is called once when the element first mounts.
- **`updateRenderObject`** is called on subsequent rebuilds to forward new widget-level properties (like `padding` here) to the existing render object. Child management is not your concern in this method — the element handles it separately.

You don't override `createElement`. The base class's default returns a `SingleChildRenderObjectElement`, which is what you want.

## Mixing In `RenderObjectWithChildMixin`

Your render object needs a place to store its single child and methods to attach, detach, and visit it. `RenderObjectWithChildMixin` provides all of this.

```dart
class RenderMyContainer extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  RenderMyContainer({double padding = 0.0}) : _padding = padding;

  double _padding;
  double get padding => _padding;
  set padding(double value) {
    if (_padding == value) return;
    _padding = value;
    markNeedsLayout();
  }

  // Layout, paint, etc. go here. They use the inherited `child` getter.
}
```

The mixin gives your render object:

- A **`child` getter and setter** of type `RenderBox?` (or whatever child type you parameterize the mixin with). Assigning to `child` automatically adopts the new child and drops the previous one. Setting it to `null` drops the existing child.
- A **default `visitChildren` implementation** that visits the single child if present.
- **`attach` and `detach` propagation** to the child.
- **`redepthChildren` support** so the framework's depth bookkeeping stays correct.

You don't have to write any of those yourself. You just read `child` when you need it during layout, paint, hit testing, and so on.

The type parameter (`RenderBox` in this example) constrains what kind of child render object you accept. For a child that must be a `RenderBox`, parameterize with `RenderBox`. If you have a sliver child, use `RenderSliver` instead.

## How the Pieces Connect

Here's the flow when your widget first appears in the tree:

1. Flutter creates a `MyContainer` widget instance.
2. The framework calls `createElement` on it, which (via the base class) returns a new `SingleChildRenderObjectElement`.
3. The element is mounted. During mount, it calls `createRenderObject` on the widget, which returns a `RenderMyContainer`.
4. The element calls `updateChild(null, widget.child, ...)`. If `widget.child` is non-null, this creates a child element, mounts it, and (if the child element owns a render object) triggers an `insertRenderObjectChild` callback.
5. The element's `insertRenderObjectChild` implementation (provided by `SingleChildRenderObjectElement`) sets your render object's `child` property.
6. The mixin's setter adopts the new child render object, updating the render tree.

On rebuilds, the flow is:

1. The framework hands a new `MyContainer` widget to the existing element.
2. The element calls `updateRenderObject`, which forwards non-child properties (`padding`, etc.) to the render object.
3. The element calls `updateChild(_child, widget.child, ...)`. This reconciles the existing child element against the new child widget — updating in place if compatible, replacing if not, removing if the new child is null, or creating if there wasn't one before.
4. Render-tree mutations happen automatically through the same insert/remove callbacks.

Removal and disposal are handled the same way in reverse, and `GlobalKey` reparenting just works — the framework's `SingleChildRenderObjectElement` already implements `forgetChild` correctly.

## What You Get For Free

Because you're extending the framework's base classes, you don't write any of the following:

- **Mount logic** — The element's `mount` method already creates the initial child element from `widget.child`.
- **Update logic** — The element's `update` method already reconciles the child against the new widget.
- **`updateChild` calls** — Already invoked at the right moments.
- **`insertRenderObjectChild` / `removeRenderObjectChild`** — Already wired to set the render object's `child` property.
- **`visitChildren` / `forgetChild`** — Already implemented correctly.
- **Render-tree child adoption and dropping** — Handled by `RenderObjectWithChildMixin`.
- **Render-tree attach/detach propagation** — Also handled by the mixin.
- **GlobalKey reparenting** — Handled by the framework's element implementation.

What you provide is:

- A widget that extends `SingleChildRenderObjectWidget` and forwards `child` via `super.child`.
- A render object that uses `RenderObjectWithChildMixin<...>` and accesses its child via the inherited `child` getter.
- `createRenderObject` and `updateRenderObject` overrides to handle non-child widget properties.

That's all the child management you need to write — none of it, in fact, since the framework provides everything.

## Common Pitfalls

Even though most of this is handled for you, there are a few small mistakes that come up:

**Redeclaring `child` on your widget.** `SingleChildRenderObjectWidget` already declares a `final Widget? child` field. If you declare it again on your subclass, you'll shadow the base-class field and break the framework's reconciliation, since the element reads `widget.child` through the base-class field. Always forward via `super.child` in your constructor.

**Forgetting to forward non-child properties in `updateRenderObject`.** Child management is handled separately, but anything else on your widget (padding, color, alignment, callbacks) needs to be pushed to the render object in `updateRenderObject` on every rebuild. Forgetting this produces the classic "the widget rebuilt with new values but the screen didn't update" bug.

**Reading the render object's `child` before it's attached.** During the render object's constructor or early initialization, `child` is `null`. Layout, paint, and hit-testing methods can safely read `child`, but constructor logic can't. If you need to do something with the child as soon as it appears, do it in your layout or paint code, not in the constructor.

**Choosing the wrong child type parameter for the mixin.** `RenderObjectWithChildMixin<RenderBox>` restricts the child to `RenderBox`. If you want to allow slivers or some other render-object type, parameterize accordingly. The type is enforced at the moment the child is adopted, so a mismatch produces an immediate error rather than a confusing later failure.

**Trying to manage the child yourself.** It's tempting, especially if you've written custom elements before, to override `mount`, `update`, or the insert/remove callbacks. For a single-child widget you almost never should — the defaults are correct and well-tested. If you find yourself wanting to override these, ask whether the behavior really needs custom child management, or whether it can be expressed through widget properties forwarded to the render object via `updateRenderObject`.

That's the complete single-child setup. A widget that extends `SingleChildRenderObjectWidget`, a render object that mixes in `RenderObjectWithChildMixin`, and a handful of property overrides. The framework handles everything related to child management itself.