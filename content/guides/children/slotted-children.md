---
title: Slotted Children
description: Implement a Render Object with slotted children
layout: guides
order: 20
---
# Implementing a Custom Slotted-Children Element and Render Object

This guide walks through implementing a custom widget that manages a fixed set of named child slots — a header and a body, or a leading, primary, and trailing widget, or any similar layout where each child has a distinct semantic role rather than a position in a list.

The good news is that the Flutter framework provides nearly everything you need. `SlottedMultiChildRenderObjectWidget` and `SlottedContainerRenderObjectMixin` handle the wiring; you mostly just declare your slots and your children. We'll focus entirely on child management; layout and paint are out of scope.

## What This Guide Covers

- **When Slots Are the Right Model** — How to recognize that a slotted layout fits your needs better than a list of children.
- **The Pieces Involved** — The widget, element, and render object, and which the framework provides.
- **Defining the Slot Enum** — The named identifiers your slots will use.
- **Extending `SlottedMultiChildRenderObjectWidget`** — Declaring slots and exposing the child for each one.
- **Mixing In `SlottedContainerRenderObjectMixin`** — Letting your render object access children by slot.
- **How the Pieces Connect** — Where the framework hands off between widget, element, and render object.
- **What You Get For Free** — Reconciliation, mounting, updating, render-tree attachment, and reparenting, all handled for you.
- **Common Pitfalls** — The small set of mistakes that slotted setups still produce.

## When Slots Are the Right Model

Slots are the right model when your widget has a fixed set of children, each with a distinct role, exposed as separately-typed widget properties rather than as a list. Some signs:

- Your widget API looks like `MyLayout(header: ..., body: ..., footer: ...)` rather than `MyLayout(children: [...])`.
- Each child has a different meaning to the render object — header is painted at the top, footer at the bottom, body fills the middle.
- The number of slots is fixed at compile time. There's no "list of headers"; there's exactly one header or none.

If your children are interchangeable list elements (a row, a column, a stack), slots are the wrong model — use a multi-child setup instead. If your children are all the same type but logically grouped into a fixed structure (a `leading` and a `trailing` icon, for example), slots are a good fit even when both happen to be icons.

## The Pieces Involved

A slotted setup has three parts:

- A **widget** that exposes each slot as a separate property.
- An **element** that reconciles each slot independently.
- A **render object** that holds one child per slot.

The framework provides the element for free through `SlottedMultiChildRenderObjectWidget.createElement`, which returns a `SlottedRenderObjectElement`. You'll almost never subclass the element yourself.

The framework also provides a render-object mixin, `SlottedContainerRenderObjectMixin`, that handles slot-by-slot child storage on the render-object side.

What you write is: a slot identifier (usually an enum), the widget (extending a framework base class), and the render object (mixing in a framework mixin).

## Defining the Slot Enum

Slots need identifiers. The convention is to use an enum:

```dart
enum MySlot { header, body, footer }
```

Any value type works as a slot identifier — strings, integers, custom objects — but an enum is conventional because it documents the fixed set of slots at the type level. The framework will use these values to identify each slot when reconciling children and when calling back to attach or detach render objects.

## Extending `SlottedMultiChildRenderObjectWidget`

`SlottedMultiChildRenderObjectWidget` is the base class for widgets with named slots. It's parameterized by your slot type and the child render-object type:

```dart
class MyLayout extends SlottedMultiChildRenderObjectWidget<MySlot, RenderBox> {
  const MyLayout({
    super.key,
    this.header,
    this.body,
    this.footer,
    this.spacing = 0.0,
  });

  final Widget? header;
  final Widget? body;
  final Widget? footer;
  final double spacing;

  @override
  Iterable<MySlot> get slots => MySlot.values;

  @override
  Widget? childForSlot(MySlot slot) {
    switch (slot) {
      case MySlot.header:
        return header;
      case MySlot.body:
        return body;
      case MySlot.footer:
        return footer;
    }
  }

  @override
  RenderMyLayout createRenderObject(BuildContext context) {
    return RenderMyLayout(spacing: spacing);
  }

  @override
  void updateRenderObject(BuildContext context, RenderMyLayout renderObject) {
    renderObject.spacing = spacing;
  }
}
```

The two overrides specific to slotted widgets are:

- **`slots`** — An iterable of all slot identifiers. Usually `MySlot.values` for an enum.
- **`childForSlot(slot)`** — Given a slot identifier, return the widget for that slot (or `null` if the slot is currently empty).

The element uses these two methods together to reconcile each slot. It iterates over `slots`, calls `childForSlot` for each, and reconciles the result against whatever child element currently occupies that slot. Each slot is reconciled independently, with no cross-slot interactions.

You don't override `createElement`. The base class returns a `SlottedRenderObjectElement` automatically.

## Mixing In `SlottedContainerRenderObjectMixin`

Your render object holds one child per slot and needs methods to attach, detach, and look up children by slot. `SlottedContainerRenderObjectMixin` provides all of this.

```dart
class RenderMyLayout extends RenderBox
    with SlottedContainerRenderObjectMixin<MySlot, RenderBox> {
  RenderMyLayout({double spacing = 0.0}) : _spacing = spacing;

  double _spacing;
  double get spacing => _spacing;
  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  // Convenience getters for cleaner layout/paint code.
  RenderBox? get header => childForSlot(MySlot.header);
  RenderBox? get body => childForSlot(MySlot.body);
  RenderBox? get footer => childForSlot(MySlot.footer);
}
```

The mixin provides:

- **`childForSlot(MySlot slot)`** — Returns the current child render object for the given slot, or `null` if the slot is empty.
- **A default `visitChildren`** that visits every slot's child in slot-enum order.
- **Render-tree adoption and dropping** when slots are populated or cleared.
- **Attach and detach propagation** to children.

You don't write any of this. You just read children by slot inside your layout, paint, hit-test, and other methods.

The two type parameters mirror the widget's: the slot type (`MySlot`) and the child render-object type (`RenderBox`).

## How the Pieces Connect

When your widget first appears in the tree:

1. Flutter creates a `MyLayout` widget instance.
2. The framework calls `createElement`, which (via the base class) returns a new `SlottedRenderObjectElement`.
3. The element mounts and calls `createRenderObject`, which returns a `RenderMyLayout`.
4. The element iterates over `widget.slots`. For each slot, it calls `widget.childForSlot(slot)` and reconciles the result against the (currently nonexistent) child for that slot.
5. For each non-null slot widget, the element creates a child element, mounts it, and triggers `insertRenderObjectChild`, which routes the child render object to the correct slot in the render object via the mixin's storage.

On rebuilds:

1. The framework gives the existing element a new `MyLayout` widget.
2. The element calls `updateRenderObject`, forwarding non-child properties like `spacing`.
3. The element iterates over `widget.slots` again, calling `childForSlot` for each. Each slot is reconciled independently with `updateChild`.
4. Slot-by-slot updates produce slot-by-slot render-tree mutations through `insertRenderObjectChild`, `removeRenderObjectChild`, and `moveRenderObjectChild` (though the last is essentially never triggered for slotted setups, since children don't move between slots).

The key property of slotted reconciliation is that **each slot is independent**. A slot that contains a stateful widget keeps its state across rebuilds as long as that slot's widget remains compatible (same runtime type, same key). Changing the widget in the `header` slot doesn't affect the element in the `body` slot.

## What You Get For Free

Because you're extending the framework's base classes, you don't write:

- **Mount logic** — The element's `mount` method already creates initial child elements for each slot.
- **Update logic** — The element's `update` method already reconciles each slot independently.
- **`updateChild` calls** — Already invoked once per slot at the right moments.
- **`insertRenderObjectChild` / `removeRenderObjectChild`** — Already wired to call into the mixin's slot storage.
- **`visitChildren` / `forgetChild`** — Already implemented correctly across all slots.
- **Render-tree child adoption and dropping** — Handled by `SlottedContainerRenderObjectMixin`.
- **Attach/detach propagation** — Also handled by the mixin.
- **GlobalKey reparenting** — Handled by the framework's element implementation.

What you provide is:

- A slot enum (or other slot identifier type).
- A widget that extends `SlottedMultiChildRenderObjectWidget` with `slots` and `childForSlot` overrides.
- A render object that uses `SlottedContainerRenderObjectMixin` and reads children via `childForSlot`.
- `createRenderObject` and `updateRenderObject` for non-child widget properties.

## Common Pitfalls

**Forgetting a slot in `childForSlot`.** If you add a new slot to your enum but don't handle it in the `switch`, you'll either get a static analysis warning (good) or a silent `null` return (less good). A `switch` over an enum without a default case will surface missing cases at analysis time — prefer that pattern over a switch with a default.

**Returning the same widget from multiple slots.** Each slot must produce a distinct widget instance. Returning the same `Widget` object from two slots will cause the framework to try to mount it twice, which fails. If you want to repeat content, use separate widget instances or a factory.

**Treating slots as positional.** The order of slots in the enum doesn't determine paint order, layout order, or anything else visual. That's entirely up to your render object's layout and paint code. The slot identifier is just a name — what each slot means visually is whatever your render object decides.

**Trying to add or remove slots at runtime.** The set of slots is fixed by your enum and your `slots` getter. You can't conditionally add a "side panel" slot only when some flag is true — instead, always declare the slot and return `null` from `childForSlot` when it should be empty. The framework treats a `null` widget as "this slot is empty," which is what you want.

**Forgetting that empty slots are normal.** It's common for a layout to be designed with three slots but used with only the body filled in. Your render object's layout code needs to handle each slot being potentially null, since slots can be empty independently. Reading `childForSlot(MySlot.header)` returning `null` is not an error — it just means there's no header right now.

**Reading children in the render object's constructor.** Like with single-child setups, children aren't attached during the constructor. Read them in layout, paint, or hit-testing methods.

**Defining `slots` incorrectly.** The `slots` iterable must be stable and complete — it should return the same set of slot values every time, in a consistent order, regardless of the current widget configuration. Don't filter it based on whether each slot has a child; return all slot values and let `childForSlot` express which ones are currently populated.

That's the complete slotted-children setup. A slot enum, a widget that extends `SlottedMultiChildRenderObjectWidget` and tells the framework what slots exist and what's in each, and a render object that mixes in `SlottedContainerRenderObjectMixin` and reads children by slot. The framework handles all the reconciliation, attachment, and lifecycle work.