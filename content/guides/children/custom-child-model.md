---
title: Custom Child Model
description: Implement a Render Object with a custom child model
layout: guides
order: 40
---
# Implementing a Custom Element and Render Object for a Structured Child Collection

This guide walks through implementing a custom widget whose API takes a structured collection of children — something other than a flat `List<Widget>`. The canonical example is a grid whose `children` parameter is a custom `GridChildren` type that exposes children by row and column. Other examples include `List<List<Widget>>` for rows of cells, `Map<Coord, Widget>` for sparse layouts, or any custom data structure that the parent walks to access children.

Unlike the single-child, slotted, and list-based models, there's no framework base class that does the heavy lifting here. You'll write a custom `RenderObjectElement` that knows how to walk your data structure and reconcile children from it. This is meaningfully more involved than the other multi-child models, but the framework still provides the core primitives — you compose them rather than reimplement them.

We'll focus entirely on child management. Layout, paint, and other concerns are out of scope.

## What This Guide Covers

- **When You Need a Custom Element** — Recognizing widget APIs that don't fit the list-based or slotted models.
- **A Running Example: `MyGrid`** — The structured-children widget we'll build throughout the guide.
- **The Pieces Involved** — The widget, the structured children type, the element, the parent data, and the render object.
- **Designing the Children Data Structure** — What `GridChildren` looks like and how it exposes children.
- **The Widget** — Why it can't extend the standard base classes and what it does instead.
- **The Custom Element** — In-memory storage, slot design, mount, update, and the render-tree bridge.
- **`updateChild` as the Core Primitive** — How a single framework method handles each child position.
- **Slots for Structured Children** — How slot identifiers carry your structure's coordinates.
- **Reconciling the Whole Structure** — Iterating over old and new structures to compute the diff.
- **The Render Object** — Holding children by coordinate rather than in a linked list.
- **`visitChildren` and `forgetChild`** — Exposing your storage to the framework's tree walks.
- **What You Get For Free, and What You Don't** — The boundary between framework and your code.
- **Common Pitfalls** — The specific bugs structured-child setups produce.

## When You Need a Custom Element

The standard child-management models all assume a particular widget API shape:

- **Single child** assumes one `child` field.
- **Slotted children** assume a fixed set of named slots, each with at most one child.
- **List-based children** assume a flat `List<Widget>`.

If your widget's API doesn't fit any of these — because its children are exposed through a richer data structure than a flat list — you need a custom `RenderObjectElement`. Some examples that need this approach:

- **A grid that takes `List<List<Widget>>`** (rows of cells, where the row structure is part of the API).
- **A sparse layout that takes `Map<GridCoord, Widget>`** (children keyed by coordinate, not by index).
- **A custom widget that takes a domain-specific structure** with its own accessors (e.g., a calendar with a `MonthData` containing days, each day containing events).
- **A widget that combines child models** — say, a `header` single child and a `Map<Coord, Widget>` body.

The unifying property: the widget's API exposes children through something other than a flat list, and the parent treats children differently based on their position or key in that structure.

## A Running Example: `MyGrid`

We'll build `MyGrid` — a widget that lays out cells on a 2D grid, where users specify children by row and column rather than by list position. Its API will look like:

```dart
MyGrid(
  children: GridChildren()
    ..set(row: 0, column: 0, child: Text('Top-left'))
    ..set(row: 0, column: 2, child: Text('Top-right'))
    ..set(row: 1, column: 1, child: Text('Center')),
)
```

The grid is sparse — not every coordinate has a child — and the user-facing API uses coordinates rather than a list. The framework's `MultiChildRenderObjectElement` can't reconcile this; we'll write our own.

## The Pieces Involved

A structured-children setup has five parts:

- A **children data structure** (`GridChildren`) that exposes children by coordinate.
- A **widget** (`MyGrid`) that holds the data structure and creates the custom element.
- A **custom element** (`MyGridElement`) that reconciles children by coordinate against the widget's structure.
- A **parent data** type (`MyGridParentData`) that holds each child's grid coordinate on the render object.
- A **render object** (`RenderMyGrid`) that stores children by coordinate and provides methods to insert, move, and remove them.

The framework doesn't provide a base widget or element for this case. You'll extend `RenderObjectWidget` and `RenderObjectElement` directly. The render-object side still benefits from framework utilities, but it doesn't use `ContainerRenderObjectMixin` because that mixin assumes a linked-list structure.

## Designing the Children Data Structure

The data structure is the user-facing API for specifying children. Its design is part of the widget's UX and isn't dictated by the framework — pick whatever makes sense for your widget.

For `MyGrid`, a sparse map keyed by coordinate is a natural fit:

```dart
@immutable
class GridChildren {
  GridChildren();

  final Map<GridCoord, Widget> _children = <GridCoord, Widget>{};

  void set({required int row, required int column, required Widget child}) {
    _children[GridCoord(row, column)] = child;
  }

  Widget? childAt(GridCoord coord) => _children[coord];

  Iterable<GridCoord> get coords => _children.keys;
}

@immutable
class GridCoord {
  const GridCoord(this.row, this.column);
  final int row;
  final int column;

  @override
  bool operator ==(Object other) =>
      other is GridCoord && other.row == row && other.column == column;

  @override
  int get hashCode => Object.hash(row, column);
}
```

A few design notes:

- **Coordinates need value equality.** `GridCoord` overrides `==` and `hashCode` so it can be used as a map key. This is essential for reconciliation — the element will use coordinates to match old children against new ones.
- **The structure should support enumeration.** Reconciliation needs to iterate over all coordinates, so expose them via something like `coords` or by implementing `Iterable`.
- **The structure should support lookup by coordinate.** The element looks up the widget for each coordinate during reconciliation.

You can design this however you like — the framework doesn't care. What matters is that the element can iterate over the structure and look up children by their identifying key (coordinate, in this case).

## The Widget

Because no framework base class covers this case, `MyGrid` extends `RenderObjectWidget` directly:

```dart
class MyGrid extends RenderObjectWidget {
  const MyGrid({super.key, required this.children, this.gap = 0.0});

  final GridChildren children;
  final double gap;

  @override
  MyGridElement createElement() => MyGridElement(this);

  @override
  RenderMyGrid createRenderObject(BuildContext context) {
    return RenderMyGrid(gap: gap);
  }

  @override
  void updateRenderObject(BuildContext context, RenderMyGrid renderObject) {
    renderObject.gap = gap;
  }
}
```

Compared to the simpler models, the only difference here is the explicit `createElement` override returning a custom element type. Everything else — `createRenderObject` and `updateRenderObject` for non-child properties — follows the same pattern as any other `RenderObjectWidget`.

## The Custom Element

This is where the real work happens. The element extends `RenderObjectElement` and stores children by coordinate.

```dart
class MyGridElement extends RenderObjectElement {
  MyGridElement(MyGrid super.widget);

  final Map<GridCoord, Element> _children = <GridCoord, Element>{};
  final Set<Element> _forgottenChildren = <Element>{};

  @override
  MyGrid get widget => super.widget as MyGrid;

  @override
  RenderMyGrid get renderObject => super.renderObject as RenderMyGrid;

  // Mount, update, visitChildren, forgetChild, and render-tree bridge methods
  // follow below.
}
```

The storage mirrors the widget's structure: a map from `GridCoord` to `Element`. The forgotten children set is the standard pattern for handling `GlobalKey` reparenting (covered below).

The element doesn't need to be more complex than that for storage — your data structure dictates how children are organized, and your element just mirrors it.

## `updateChild` as the Core Primitive

The base `Element` class provides `updateChild(Element? oldChild, Widget? newWidget, Object? newSlot)`, and it does the heavy lifting for each child position. Its semantics are uniform regardless of child model:

- **Both null:** nothing happens; returns null.
- **Old null, new non-null:** creates and mounts a new child element; returns it.
- **Old non-null, new null:** deactivates the existing element; returns null.
- **Both non-null:** updates in place if the runtime type and key match, replaces otherwise.

You call `updateChild` once per coordinate in your structure. The coordinate is the slot.

This is the primitive that makes structured-children reconciliation tractable. You don't write reconciliation from scratch — you call `updateChild` for each position, and the framework handles the per-position logic, including triggering the render-tree callbacks when the result requires inserting, moving, or removing render objects.

## Slots for Structured Children

The `slot` parameter to `updateChild` (and to the render-tree callbacks) identifies *where in the parent's child structure* a particular child lives. For a list, slots are typically `IndexedSlot(index, previousSibling)`. For named slots, the slot is the slot name. For a grid, the natural slot is the grid coordinate:

```dart
_children[coord] = updateChild(_children[coord], widget.children.childAt(coord), coord)!;
```

The slot — `coord` — gets passed through to `insertRenderObjectChild`, `moveRenderObjectChild`, and `removeRenderObjectChild`, where you'll use it to tell the render object which coordinate the child belongs to.

Slots can be any object as long as the element and the render object agree on what each one means. For a grid, `GridCoord` works directly because it's already a value type with `==` and `hashCode`.

## Reconciling the Whole Structure

Mount and update are where you walk the widget's structure and call `updateChild` for each coordinate.

### Mount

```dart
@override
void mount(Element? parent, Object? newSlot) {
  super.mount(parent, newSlot);
  for (final coord in widget.children.coords) {
    final childWidget = widget.children.childAt(coord);
    _children[coord] = updateChild(null, childWidget, coord)!;
  }
}
```

On mount, there are no existing children, so `oldChild` is always `null`. Each `updateChild` call creates and mounts a new element, and (if it owns a render object) triggers `insertRenderObjectChild` with the coordinate as the slot.

### Update

Update is the interesting case. The widget might have added, removed, moved, or replaced children since the last build. You need to handle all four:

```dart
@override
void update(MyGrid newWidget) {
  super.update(newWidget);

  final newCoords = widget.children.coords.toSet();
  final oldCoords = _children.keys.toSet();

  // Update or insert: every coord in the new structure gets an updateChild call.
  for (final coord in newCoords) {
    final newChildWidget = widget.children.childAt(coord);
    _children[coord] = updateChild(_children[coord], newChildWidget, coord)!;
  }

  // Remove: every coord that was in the old structure but isn't anymore.
  for (final coord in oldCoords.difference(newCoords)) {
    if (!_forgottenChildren.contains(_children[coord])) {
      updateChild(_children[coord], null, coord);
    }
    _children.remove(coord);
  }

  _forgottenChildren.clear();
}
```

The pattern: iterate over the new structure and call `updateChild` for every coordinate (handling updates and insertions), then iterate over coordinates that no longer appear in the new structure and call `updateChild` with `null` (handling removals).

**Keys still work the same way.** If a child at one coordinate has a `Key`, and a child at a *different* coordinate has the same key in the new structure, you'd want to preserve element identity across the move. The simple loop above doesn't do that — it matches purely by coordinate. If you need cross-coordinate key matching, you'd need to identify keyed children separately, match them up, and route them through `updateChild` so they're moved rather than recreated. For most structured-children widgets this is unnecessary; coordinate-based identity is the right model. But it's worth knowing the cost — the framework's list-based `updateChildren` does key matching for free, and your custom reconciliation only does it if you write it.

## The Render Object

The render object stores children by coordinate and provides methods for the element to call.

```dart
class MyGridParentData extends BoxParentData {
  GridCoord? coord;
}

class RenderMyGrid extends RenderBox {
  RenderMyGrid({double gap = 0.0}) : _gap = gap;

  double _gap;
  double get gap => _gap;
  set gap(double value) {
    if (_gap == value) return;
    _gap = value;
    markNeedsLayout();
  }

  final Map<GridCoord, RenderBox> _children = <GridCoord, RenderBox>{};

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! MyGridParentData) {
      child.parentData = MyGridParentData();
    }
  }

  void insertChild(RenderBox child, GridCoord coord) {
    assert(!_children.containsKey(coord), 'a child already exists at $coord');
    _children[coord] = child;
    (child.parentData as MyGridParentData).coord = coord;
    adoptChild(child);
  }

  void moveChild(RenderBox child, GridCoord oldCoord, GridCoord newCoord) {
    assert(_children[oldCoord] == child);
    assert(!_children.containsKey(newCoord));
    _children.remove(oldCoord);
    _children[newCoord] = child;
    (child.parentData as MyGridParentData).coord = newCoord;
    // Adoption doesn't change; the child is already adopted.
    markNeedsLayout();
  }

  void removeChild(RenderBox child, GridCoord coord) {
    assert(_children[coord] == child);
    _children.remove(coord);
    dropChild(child);
  }

  RenderBox? childAt(GridCoord coord) => _children[coord];

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    for (final child in _children.values) {
      child.attach(owner);
    }
  }

  @override
  void detach() {
    super.detach();
    for (final child in _children.values) {
      child.detach();
    }
  }

  @override
  void redepthChildren() {
    for (final child in _children.values) {
      redepthChild(child);
    }
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    for (final child in _children.values) {
      visitor(child);
    }
  }

  // Layout, paint, hit-test, etc., go here. They walk _children by coordinate.
}
```

Compared to `ContainerRenderObjectMixin`, you write three things by hand:

- **The storage** — a `Map<GridCoord, RenderBox>` instead of a linked list.
- **Insert, move, and remove methods** — manually calling `adoptChild` and `dropChild`, the lower-level render-object APIs that handle parent pointers, attach state, and depth bookkeeping.
- **`attach`, `detach`, `redepthChildren`, and `visitChildren`** — propagating to children, since the mixin isn't doing it for you.

Each of those is short. The mixin's value is bundling them up for the common linked-list case; you're writing the same shape of code but for a map.

## The Render-Tree Bridge

The element's three render-tree callbacks tie everything together. The framework calls these in response to `updateChild`:

```dart
@override
void insertRenderObjectChild(covariant RenderBox child, GridCoord slot) {
  renderObject.insertChild(child, slot);
}

@override
void moveRenderObjectChild(covariant RenderBox child, GridCoord oldSlot, GridCoord newSlot) {
  renderObject.moveChild(child, oldSlot, newSlot);
}

@override
void removeRenderObjectChild(covariant RenderBox child, GridCoord slot) {
  renderObject.removeChild(child, slot);
}
```

The `covariant` keyword lets you narrow the slot type to `GridCoord` and the child type to `RenderBox`, which avoids casts in the body. The framework guarantees that the slots and children passed in here are the ones you originally passed to `updateChild`, so the typing is safe.

These three callbacks are the entire interface between the element's reconciliation and the render object's storage. Element decides what changed; render object carries out the mutation.

## `visitChildren` and `forgetChild`

`visitChildren` exposes the element's children to the framework's tree walks:

```dart
@override
void visitChildren(ElementVisitor visitor) {
  for (final child in _children.values) {
    if (!_forgottenChildren.contains(child)) {
      visitor(child);
    }
  }
}
```

Skip forgotten children, since they're in the process of being adopted by a different parent.

`forgetChild` handles `GlobalKey` reparenting:

```dart
@override
void forgetChild(Element child) {
  assert(_children.containsValue(child));
  _forgottenChildren.add(child);
  super.forgetChild(child);
}
```

The pattern is the standard one: track forgotten children in a set, skip them in `visitChildren`, and consult the set during `update` so you don't try to reconcile them.

## What You Get For Free, and What You Don't

The framework still provides the most important pieces:

- **`updateChild`** handles per-position reconciliation, including creating, updating, replacing, and deactivating child elements.
- **The render-tree callbacks** fire automatically as a consequence of `updateChild`'s decisions. You write the implementations, but you don't decide when they fire.
- **Lifecycle plumbing for child elements** (mount, deactivate, unmount) is handled by the framework.
- **GlobalKey reparenting** works correctly as long as you implement `forgetChild` and skip forgotten children in `visitChildren`.

What you write that the standard models give you for free:

- **The mount and update logic** — walking your data structure and calling `updateChild` for each position. The list-based and slotted elements do this in their bases; you do it by hand.
- **`visitChildren` and `forgetChild`** — implementing both to match your storage. The standard mixins implement these for you.
- **Cross-position key matching, if you want it** — `MultiChildRenderObjectElement.updateChildren` does this automatically; your structured reconciliation doesn't, unless you write it.
- **Render-object child storage and adoption** — you store children in a `Map` (or whatever) instead of a linked list, and you call `adoptChild` and `dropChild` directly instead of relying on `ContainerRenderObjectMixin.insert` / `remove`.
- **`attach`, `detach`, `redepthChildren`** propagation on the render object.

The work is real but bounded. Each piece is a short, well-defined method.

## Common Pitfalls

**Forgetting to call `adoptChild` and `dropChild`.** Without `ContainerRenderObjectMixin`, you're responsible for these. `adoptChild` sets the child's parent pointer, calls `setupParentData`, propagates attach state, and handles depth. `dropChild` reverses it. Skipping them produces children that aren't really part of the render tree.

**Not propagating `attach`, `detach`, and `redepthChildren`.** The base `RenderObject` doesn't know about your custom storage, so its default `attach` and `detach` won't reach your children. Override them and call the corresponding method on each child.

**Not skipping forgotten children in `visitChildren`.** A forgotten child is being adopted by a different parent. Walking it from the old parent will cause it to be deactivated as part of the old parent's lifecycle, which destroys the state that `GlobalKey` reparenting is meant to preserve.

**Conflating coordinate matching with key matching.** Coordinate matching (matching children whose coordinates are the same in old and new) is what your `update` loop does naturally. Key matching (matching children with the same `Key` across different coordinates) requires extra work — separating keyed children, finding their new coordinates, and routing them through `updateChild` so they're preserved. If your widget genuinely needs cross-coordinate identity preservation, you have to write that logic.

**Storing widgets instead of elements.** Your `_children` map holds elements, not widgets. The widget tree is rebuilt every frame; the element tree persists.

**Mismatched slot types.** The slot you pass to `updateChild` is the slot you'll receive in `insertRenderObjectChild`, `moveRenderObjectChild`, and `removeRenderObjectChild`. If your slot is a `GridCoord`, the `covariant` declaration on those overrides should be `GridCoord` too, not `Object?` or some inconsistent type.

**Forgetting to clear `_forgottenChildren` after `update`.** The set should be cleared once per update pass, after reconciliation is done. Leaving entries in the set across multiple updates produces silent bugs where children are skipped in tree walks indefinitely.

**Trying to use `ContainerRenderObjectMixin`.** The mixin assumes a linked-list child structure. For structured children, it doesn't fit — you can't usefully order children by `previousSibling` and `nextSibling` if their primary identity is a coordinate, not a position. Write the storage and lifecycle methods directly.

That's the complete structured-children setup. A custom data structure for the widget's API, a custom element that walks the structure and calls `updateChild` for each position, a render object that stores children by coordinate with manual lifecycle propagation, and the standard render-tree bridge methods. It's more code than the standard models, but the framework still does the most important work — per-position reconciliation, element lifecycle, and global-key reparenting — through `updateChild` and its companions.