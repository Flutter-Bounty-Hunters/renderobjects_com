---
title: Parent Data
description: Implement parent data for Render Objects
layout: guides
order: 5
---
# Implementing Parent Data Setup in a Custom Flutter Render Object

This guide walks experienced Flutter developers through the parent data responsibilities of a custom `RenderObject`. By the end, you'll understand what parent data is for, when you need a custom subclass of it, and how to wire one up correctly. We'll skip layout, painting, compositing, hit testing, lifecycle, semantics, and diagnostics — this is about parent data, and only parent data.

## What This Guide Covers

- **What Parent Data Actually Is** — Per-child storage that the parent owns, used to remember things between layout passes.
- **When You Need a Custom Subclass** — The signals that you've outgrown the default.
- **`setupParentData`** — The one override that installs your custom subclass on children.
- **The `ParentDataWidget` Companion** — How widgets attach parent data values from the widget tree.
- **Lifecycle and Ownership** — Who creates parent data, who reads it, and who clears it.
- **Common Pitfalls** — The small set of bugs this surface tends to produce.

## What Parent Data Actually Is

Parent data is per-child storage that lives on each child render object but is owned and managed by the parent. Each child has a `parentData` field; the parent reads and writes it; nobody else touches it.

The most visible use of parent data is positioning. After layout, every child needs to know where it sits within its parent's coordinate space, and that position is stored on the child's parent data — specifically, as the `offset` field on `BoxParentData`. The parent reads it during paint to call `context.paintChild(child, offset + childParentData.offset)`. Without parent data, there'd be nowhere to put that offset; it doesn't belong on the parent (which has many children) and it doesn't really belong on the child (since it depends on which parent the child currently has).

`BoxParentData` is the default for box children, and it carries just the offset. For most parents, that's all you need — the offset is enough to position children, and any other state the parent needs to remember can live on the parent itself.

Some parents, however, need to remember *additional* per-child information across layout passes. A flex layout needs to remember each child's flex factor and fit. A stack needs to remember each child's positioning constraints (top, left, right, bottom, width, height). A custom grid might need to remember which row and column each child belongs to. That extra state goes on a custom parent data subclass, and that's what the rest of this guide covers.

## When You Need a Custom Subclass

You need a custom `ParentData` subclass when:

- **The widget tree assigns per-child layout information** that the render object needs at layout time. Anything you'd express by wrapping a child in a `ParentDataWidget` like `Flexible`, `Expanded`, `Positioned`, or `LayoutId` requires custom parent data.
- **The parent needs to remember per-child computed state** between layout passes — for example, a baseline offset, a measured intrinsic size used by sibling layout, or a cached calculation that depends on a specific child.

You don't need a custom subclass when:

- **The only per-child information you need is the offset.** `BoxParentData` already provides that.
- **All the per-child state can be derived from the child's own properties or its position in the child list.** If the child knows everything about itself, there's nothing to remember on parent data.

If you're not sure, start without a custom subclass and add one when you find yourself wanting per-child state that doesn't fit elsewhere.

## `setupParentData`

`setupParentData(RenderObject child)` is the single override that installs your custom parent data subclass on children as they're adopted into your render object.

The framework calls it for every child, once, as part of `adoptChild`. Your job is to make sure the child's `parentData` is an instance of your subclass:

```dart
class GridParentData extends BoxParentData {
  int row = 0;
  int column = 0;
  int rowSpan = 1;
  int columnSpan = 1;
}

class RenderCustomGrid extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, GridParentData>,
         RenderBoxContainerDefaultsMixin<RenderBox, GridParentData> {

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! GridParentData) {
      child.parentData = GridParentData();
    }
  }
}
```

A few details worth noting. **Subclass `BoxParentData`, not `ParentData` directly**, when working with box children — you want the offset field that `BoxParentData` provides. **Check the type before replacing** because if the same child was just moved from another parent that also used `GridParentData`, the existing instance can be reused. The `is!` check handles this correctly.

The mixin type parameter (`ContainerRenderObjectMixin<RenderBox, GridParentData>`) tells the framework that your children's parent data is of type `GridParentData`. Set this on both `ContainerRenderObjectMixin` and `RenderBoxContainerDefaultsMixin` if you're using both, and the linked-list accessors (`firstChild`, `childAfter`, etc.) will work without casts.

## The `ParentDataWidget` Companion

A render object can hold custom parent data, but the values that populate it usually come from the widget tree. The mechanism is `ParentDataWidget`, the same pattern Flutter uses for `Flexible`, `Positioned`, and `LayoutId`.

A `ParentDataWidget` wraps a child and applies values to that child's parent data when the element tree updates. It's a thin coupling between a widget-level API and a render-object-level data structure.

```dart
class GridCell extends ParentDataWidget<GridParentData> {
  const GridCell({
    super.key,
    required this.row,
    required this.column,
    this.rowSpan = 1,
    this.columnSpan = 1,
    required super.child,
  });

  final int row;
  final int column;
  final int rowSpan;
  final int columnSpan;

  @override
  void applyParentData(RenderObject renderObject) {
    final parentData = renderObject.parentData! as GridParentData;
    bool needsLayout = false;
    if (parentData.row != row) { parentData.row = row; needsLayout = true; }
    if (parentData.column != column) { parentData.column = column; needsLayout = true; }
    if (parentData.rowSpan != rowSpan) { parentData.rowSpan = rowSpan; needsLayout = true; }
    if (parentData.columnSpan != columnSpan) { parentData.columnSpan = columnSpan; needsLayout = true; }

    if (needsLayout) {
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => CustomGrid;
}
```

Two important details. **Mark the parent dirty when parent data changes**, not the child — the parent is the one that uses these values, so it's the parent whose layout needs to re-run. Going through `renderObject.parent?.markNeedsLayout()` is the standard idiom. **Only mark dirty when something actually changed.** The `needsLayout` flag pattern above avoids triggering layout for no-op updates, which can otherwise produce cascading dirty marks on every rebuild.

The `debugTypicalAncestorWidgetClass` getter tells Flutter what widget your `ParentDataWidget` is supposed to be a descendant of. If a developer accidentally puts a `GridCell` inside a `Column` (rather than inside a `CustomGrid`), the framework produces a helpful error pointing at the mismatch.

## Lifecycle and Ownership

A short overview of who does what:

- **The parent owns the parent data.** It chooses the type via `setupParentData`, reads it during layout and paint, and updates fields like `offset` during layout.
- **The framework manages installation.** `adoptChild` calls `setupParentData` once when a child joins, and `dropChild` clears the parent data when a child leaves.
- **`ParentDataWidget`s populate values** by calling `applyParentData` whenever the widget tree updates. They write the per-child configuration that the parent reads.
- **Children never read their own parent data.** It belongs to the parent and is only meaningful in the parent's context. A child being moved to a different parent gets fresh parent data; relying on parent data values to persist across reparenting is a bug.

The result is a clean separation: widgets configure, render objects store, parents consume, the framework wires it all together.

## Common Pitfalls

**Forgetting the `is!` check in `setupParentData`.** Unconditionally assigning a new instance discards values that may have just been applied by a `ParentDataWidget` during the same frame. The check ensures you only replace parent data when the type is actually wrong.

**Forgetting to set the mixin type parameter.** If you use `ContainerRenderObjectMixin<RenderBox, BoxParentData>` (the default) when your children actually have `GridParentData`, every access through the mixin's accessors will cast incorrectly. Set the type parameter to your custom subclass.

**Marking the wrong render object dirty.** When parent data changes, the parent's layout needs to re-run — not the child's. Calling `markNeedsLayout()` on the child does nothing useful and may produce confusing dirty-flag propagation.

**Storing data on parent data that doesn't need to be there.** Parent data is per-child storage; if a piece of state isn't specific to one child, it belongs on the parent itself, not duplicated across every child's parent data.

**Reading parent data on a detached child.** A child that's been removed from your render object may not have valid parent data — its parent data could be cleared, or it could be a different subclass if the child was adopted by a different parent. Only read parent data on children currently owned by your render object.

That covers parent data end to end. It's a small surface — a subclass, a `setupParentData` override, and usually a `ParentDataWidget` to populate it — but a critical one for any layout that needs more than just child offsets.