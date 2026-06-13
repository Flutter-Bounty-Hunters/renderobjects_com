---
title: List of Children
description: Implement a Render Object with a list of children
layout: guides
order: 30
---
# Implementing a Custom List-Based Multi-Child Element and Render Object

This guide walks through implementing a custom widget whose API takes a flat list of children — a `List<Widget>` parameter where each entry is one child, and the parent treats all children uniformly except for whatever per-child information their parent data carries. Rows, columns, stacks, wraps, and flow layouts all fit this pattern.

For this list-based model, the Flutter framework provides nearly everything you need. `MultiChildRenderObjectWidget` and `ContainerRenderObjectMixin` handle the reconciliation and render-tree wiring; your job is to extend them correctly and provide the per-child layout state your render object needs. We'll focus entirely on child management; layout and paint are out of scope.

## What This Guide Covers

- **When the List-Based Model Fits** — Recognizing widget APIs that match what `MultiChildRenderObjectWidget` provides.
- **When You Need a Different Approach** — Pointers to where the list-based model breaks down.
- **The Pieces Involved** — The widget, element, parent data, and render object, and which the framework provides.
- **Extending `MultiChildRenderObjectWidget`** — Exposing the children list.
- **Defining Parent Data for Children** — The per-child state that lives on each child render object.
- **Mixing In `ContainerRenderObjectMixin`** — Giving your render object a linked list of children.
- **List Order vs Visual Order** — Why the children list isn't always the same as the layout's visual sequence.
- **How the Pieces Connect** — Where the framework hands off between widget, element, parent data, and render object.
- **Keys and Reconciliation** — Why keyed children preserve state across reorderings.
- **`ParentDataWidget`s** — How widgets attach per-child layout information from the widget tree.
- **What You Get For Free** — Reconciliation, mounting, updating, render-tree attachment, reordering, and reparenting.
- **Common Pitfalls** — The traps that list-based multi-child setups produce.

## When the List-Based Model Fits

`MultiChildRenderObjectWidget` is designed for widgets whose API takes a flat `List<Widget>` of children. The defining trait is the API shape: a single `children` parameter typed as `List<Widget>`, with optional `ParentDataWidget`s wrapping individual children to attach per-child layout instructions.

Some canonical examples:

- **`Row` and `Column`.** Children are ordered along a single axis. List position is the position in the layout.
- **`Stack`.** Children are layered on top of each other. List order is paint order; `Positioned` parent data optionally specifies absolute placement.
- **`Wrap` and `Flow`.** Children are arranged by the parent's algorithm. List order is iteration order; placement is computed during layout.
- **`ListBody`.** Children are stacked along an axis with their natural intrinsic sizes.

The common thread is that the children list is flat. Each entry represents one child, and the framework's reconciliation algorithm works directly against that list — matching new and old entries by position and key, deciding which to update, reorder, insert, or remove.

## When You Need a Different Approach

If your widget's API takes anything other than a flat `List<Widget>` of children, the standard model doesn't fit. Some examples that need a custom element instead:

- A grid that takes `List<List<Widget>>` (rows of cells).
- A sparse layout that takes `Map<GridCoord, Widget>`.
- A widget with a custom child data structure that exposes per-coordinate or per-key access.
- A widget that mixes child models — for example, one `header` slot and a `List<Widget>` for items.

For those cases, you need a custom `RenderObjectElement` that knows how to walk your specific structure and reconcile children from it. That's covered in a separate guide on custom structured children. The rest of this guide assumes your widget's API is a flat list.

## The Pieces Involved

A list-based multi-child setup has four parts:

- A **widget** that exposes a `children` list of type `List<Widget>`.
- An **element** that reconciles the list — matching keys, handling reordering, insertion, and removal.
- A **parent data** type that holds per-child layout state on each child render object.
- A **render object** that holds a linked list of children and provides methods to insert, move, and remove them.

The framework provides the element for free: `MultiChildRenderObjectWidget.createElement` returns a `MultiChildRenderObjectElement`, which implements the reconciliation logic correctly, including the keyed-matching algorithm. You'll almost never subclass it.

The framework also provides `ContainerRenderObjectMixin` and `ContainerParentDataMixin` for the render-object side. Together they handle the linked-list bookkeeping, child adoption and dropping, and visitation.

What you write is: the widget (extending a framework base class), a parent data type (extending `ContainerBoxParentData`), and the render object (mixing in `ContainerRenderObjectMixin` and `RenderBoxContainerDefaultsMixin`).

## Extending `MultiChildRenderObjectWidget`

`MultiChildRenderObjectWidget` is the framework's base class for list-based multi-child widgets. It already declares the `children` field:

```dart
class MyStack extends MultiChildRenderObjectWidget {
  const MyStack({
    super.key,
    super.children,
    this.alignment = Alignment.topLeft,
  });

  final Alignment alignment;

  @override
  RenderMyStack createRenderObject(BuildContext context) {
    return RenderMyStack(alignment: alignment);
  }

  @override
  void updateRenderObject(BuildContext context, RenderMyStack renderObject) {
    renderObject.alignment = alignment;
  }
}
```

A few notes:

- **`super.children`** forwards the children list to the base class. You don't redeclare it.
- **`createRenderObject`** and **`updateRenderObject`** handle non-child widget properties (`alignment` here). Child management is not your concern in these methods — the element handles it separately.
- **`createElement`** is inherited from the base class and returns a `MultiChildRenderObjectElement`. You don't override it.

## Defining Parent Data for Children

Multi-child render objects use parent data for two things: linked-list bookkeeping (the `previousSibling` and `nextSibling` pointers that `ContainerParentDataMixin` adds) and per-child layout state.

For an ordered layout like a row or column, the existing `ContainerBoxParentData<RenderBox>` is enough — it gives you offset plus sibling pointers, which is everything you need.

For layouts where each child needs additional layout information, you subclass `ContainerBoxParentData` and add fields. For a stack with positioned children:

```dart
class MyStackParentData extends ContainerBoxParentData<RenderBox> {
  double? top;
  double? right;
  double? bottom;
  double? left;
  double? width;
  double? height;
}
```

For a flex layout:

```dart
class MyFlexParentData extends ContainerBoxParentData<RenderBox> {
  int flex = 0;
  FlexFit fit = FlexFit.loose;
}
```

The pattern is the same across both: subclass `ContainerBoxParentData<RenderBox>` and add fields for the per-child layout state your render object needs. These fields are usually populated by a `ParentDataWidget` (covered below), and the render object reads them during layout.

You'll install this parent data type on children via `setupParentData` on the render object, covered in the next section.

## Mixing In `ContainerRenderObjectMixin`

Your render object holds children in a linked list and provides methods to insert, move, and remove them. Two mixins work together:

- **`ContainerRenderObjectMixin<ChildType, ParentDataType>`** — The linked-list bookkeeping. Provides `firstChild`, `lastChild`, `childCount`, `insert`, `move`, and `remove`.
- **`RenderBoxContainerDefaultsMixin<ChildType, ParentDataType>`** — Convenient defaults for common box operations like `defaultPaint`, `defaultHitTestChildren`, and `defaultComputeDistanceToFirstActualBaseline`.

```dart
class RenderMyStack extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, MyStackParentData>,
         RenderBoxContainerDefaultsMixin<RenderBox, MyStackParentData> {

  RenderMyStack({Alignment alignment = Alignment.topLeft})
      : _alignment = alignment;

  Alignment _alignment;
  Alignment get alignment => _alignment;
  set alignment(Alignment value) {
    if (_alignment == value) return;
    _alignment = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! MyStackParentData) {
      child.parentData = MyStackParentData();
    }
  }

  // Layout, paint, etc. go here. They iterate via firstChild + childAfter.
}
```

The important pieces:

- **The type parameters** on both mixins — `RenderBox` for the child type, `MyStackParentData` for the parent data type. They must match.
- **`setupParentData`** installs your parent data subclass on each child as it's adopted. The `is!` check preserves existing parent data if it's already the right type, which matters for keyed reparenting and for parent data that was already populated by a `ParentDataWidget`.

The mixin gives you:

- A **linked list of children** accessible via `firstChild`, `lastChild`, `childBefore(child)`, `childAfter(child)`, and `childCount`.
- Methods to **insert, move, and remove children** that handle adoption, dropping, and parent-data setup automatically.
- A default **`visitChildren`** that walks children in linked-list order.
- **Attach/detach propagation** to children.
- **Render-tree adoption and dropping** when children are inserted or removed.

You don't write any of those yourself. Your layout, paint, and hit-test methods iterate over the linked list and read each child's parent data to decide placement.

## List Order vs Visual Order

A point worth being explicit about: the order of the `children` list in your widget is the order the framework uses for **reconciliation and linked-list storage**. It's not necessarily the order children appear visually.

For an ordered layout like a row, the two coincide: index 0 in the list is the leftmost child visually, index 1 is next, and so on. The render object iterates `firstChild` → `lastChild` and lays them out in that order.

For a stack with `Positioned` children, list order doesn't determine where children appear — parent data does. The `children` list might be `[a, b, c]`, but each child's `top`, `left`, etc. determine its actual placement. What the list order does control is:

- Which child element corresponds to which widget during reconciliation (matched by position and key).
- The order in which children appear in the render-object's linked list, which affects paint order (and therefore z-order in case of overlap), hit-test order, and the order of `visitChildren`.

The practical implication is that you can use the list-based model for any layout whose API is a flat list of children, regardless of whether visual placement comes from list position or from parent data. The list is for identity and reconciliation; visual layout is up to your render object.

## How the Pieces Connect

When your widget first appears in the tree:

1. Flutter creates a `MyStack` widget instance.
2. The framework calls `createElement`, which returns a new `MultiChildRenderObjectElement`.
3. The element mounts and calls `createRenderObject`, which returns a `RenderMyStack`.
4. The element calls its internal `updateChildren` helper with the new children list. This creates a child element for each widget in the list, in order.
5. Each child element is mounted, and (if it owns a render object) the framework calls `insertRenderObjectChild` on the parent element with the new render object and an `IndexedSlot` identifying its position.
6. The element's `insertRenderObjectChild` implementation calls `renderObject.insert(child, after: ...)` to add the child to the linked list at the right place.
7. As each child is adopted, the render object's `setupParentData` runs and installs the right parent data type.

On rebuilds:

1. The framework hands the existing element a new `MyStack` widget.
2. The element calls `updateRenderObject`, forwarding non-child properties like `alignment`.
3. The element calls `updateChildren` with the new children list. The reconciliation algorithm walks the old and new lists together, matching by runtime type and key:
    - Children that match are updated in place.
    - Children that moved (matched by key but at different positions) trigger `moveRenderObjectChild` calls, which call `renderObject.move(child, after: ...)`.
    - Children that no longer appear trigger `removeRenderObjectChild`, which calls `renderObject.remove(child)`.
    - New children trigger `insertRenderObjectChild`.

The framework handles all of this. You don't write any reconciliation logic — you just provide the storage shape via the mixins.

## Keys and Reconciliation

The reconciliation algorithm distinguishes between children based on a combination of runtime type and key. Two scenarios highlight why this matters:

- **No keys.** When children don't have keys, the algorithm matches them positionally. If the first child in the new list has the same runtime type as the first child in the old list, they're considered the same element and updated in place. If a child is inserted in the middle, every child after the insertion point shifts and is treated as a new element — even if it represents the "same" widget logically. Stateful children at shifted positions lose their state.
- **With keys.** When children have keys, the algorithm matches them across positions. A keyed child that moves from index 3 to index 1 is recognized as the same element and preserved, with its render object simply moved within the linked list (via `moveRenderObjectChild`). State, animation progress, scroll position — all preserved.

For lists where children might be inserted or reordered (a sortable list, a reorderable column), keys are essential. For lists where the set of children never changes, keys are optional but cost very little.

The framework handles all of this for you through the reconciliation algorithm. Your job is to ensure your widget's `children` list reflects the intended logical structure, including keys for anything that should preserve identity across reorderings.

## `ParentDataWidget`s

When per-child layout state needs to come from the widget tree rather than from the parent computing it, the standard mechanism is a `ParentDataWidget`. These wrap a child and write values to its parent data when the element tree updates.

The familiar examples are `Positioned` (writes to `StackParentData`), `Expanded` and `Flexible` (write to `FlexParentData`), and `LayoutId` (writes to `MultiChildLayoutParentData`).

For your custom stack, you'd provide a `ParentDataWidget` that writes positioning to each child:

```dart
class MyPositioned extends ParentDataWidget<MyStackParentData> {
  const MyPositioned({
    super.key,
    this.top,
    this.right,
    this.bottom,
    this.left,
    this.width,
    this.height,
    required super.child,
  });

  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final double? width;
  final double? height;

  @override
  void applyParentData(RenderObject renderObject) {
    final parentData = renderObject.parentData! as MyStackParentData;
    bool needsLayout = false;
    if (parentData.top != top) { parentData.top = top; needsLayout = true; }
    if (parentData.right != right) { parentData.right = right; needsLayout = true; }
    if (parentData.bottom != bottom) { parentData.bottom = bottom; needsLayout = true; }
    if (parentData.left != left) { parentData.left = left; needsLayout = true; }
    if (parentData.width != width) { parentData.width = width; needsLayout = true; }
    if (parentData.height != height) { parentData.height = height; needsLayout = true; }

    if (needsLayout) {
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => MyStack;
}
```

Users of your widget can then wrap children that need positioning:

```dart
MyStack(
  children: [
    Container(color: Colors.red),
    MyPositioned(
      top: 20,
      left: 20,
      child: Text('Overlay'),
    ),
  ],
)
```

This is how positioning information flows from the widget API to the render object's per-child state without forcing the parent's widget to know each child's specific layout. The parent data guide covers `ParentDataWidget` in more detail.

## What You Get For Free

Because you're extending the framework's base classes, you don't write:

- **Reconciliation logic** — The element's `updateChildren` already handles the keyed-matching algorithm, including reordering, insertion, and removal.
- **Mount and update logic** — The element handles both, calling reconciliation at the right times.
- **`insertRenderObjectChild` / `moveRenderObjectChild` / `removeRenderObjectChild`** — Already wired to call the render-object mixin's `insert`, `move`, and `remove` methods.
- **`visitChildren` / `forgetChild`** — Already implemented correctly.
- **Linked-list bookkeeping** — Handled by `ContainerRenderObjectMixin`.
- **Adoption and dropping** — Also handled by the mixin, including `setupParentData` calls.
- **Render-tree attach/detach propagation** — Handled by the mixin.
- **GlobalKey reparenting** — Handled by the framework's element implementation.

What you provide is:

- A widget that extends `MultiChildRenderObjectWidget` and forwards `children` via `super.children`.
- A parent data type (often `ContainerBoxParentData<RenderBox>` directly, or a subclass with extra fields).
- A render object that uses `ContainerRenderObjectMixin` and `RenderBoxContainerDefaultsMixin`, with a `setupParentData` override.
- `createRenderObject` and `updateRenderObject` for non-child widget properties.
- Optionally, a `ParentDataWidget` for users to attach per-child layout state from the widget tree.

## Common Pitfalls

**Redeclaring `children` on your widget.** `MultiChildRenderObjectWidget` already declares `final List<Widget> children`. If you redeclare it, you'll shadow the base-class field and break reconciliation. Always forward via `super.children`.

**Mismatched type parameters on the mixins.** `ContainerRenderObjectMixin<RenderBox, MyStackParentData>` must match `RenderBoxContainerDefaultsMixin<RenderBox, MyStackParentData>`. If they don't agree, the mixin's helper methods won't compile.

**Forgetting the `is!` check in `setupParentData`.** Unconditionally creating a new parent data instance discards values that may have been just written by a `ParentDataWidget`. The check ensures you only replace parent data when the type is actually wrong.

**Using positional reconciliation when keys are needed.** If children can be reordered (sortable lists, filterable lists, anything that changes the order in the `children` list across rebuilds), they need keys. Without keys, reordering looks to the framework like deletion and insertion at every shifted position, and stateful children lose their state.

**Assuming list order equals visual order.** This is true for ordered layouts (rows, columns), but not for stacks with positioned children or any layout where placement comes from parent data. The list order determines reconciliation order and paint order, not visual placement.

**Marking the wrong render object dirty in `applyParentData`.** When a `ParentDataWidget` writes to a child's parent data, it's the parent's layout that needs to re-run — not the child's. Use `renderObject.parent?.markNeedsLayout()`, not `renderObject.markNeedsLayout()`.

**Trying to manage children manually.** It's tempting to override `mount`, `update`, or the insert/move/remove callbacks. Almost always, the default `MultiChildRenderObjectElement` does exactly what you want. If you find yourself reaching for a custom element, ask whether your widget's API could be reshaped as a flat list with parent data — and if it genuinely can't, you're in the territory of the custom-structured-children guide rather than this one.

That's the complete list-based multi-child setup. A widget that extends `MultiChildRenderObjectWidget`, a parent data type for per-child layout state, and a render object that mixes in `ContainerRenderObjectMixin` and `RenderBoxContainerDefaultsMixin`. The framework handles everything related to reconciliation, attachment, and lifecycle.