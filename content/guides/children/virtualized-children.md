---
title: Virtualized Children
description: Implement a Render Object with virtualized children
layout: guides
order: 50
---
# Implementing Virtualized Children in a Custom Flutter Element and Render Object

This guide walks through implementing a custom widget that virtualizes its children — building child widgets lazily, only for what's currently needed, rather than instantiating every child up front. The canonical example is a list view that scrolls through ten thousand items but only ever has a few dozen elements and render objects alive at once.

Virtualization is the most complex child management model. Unlike the single-child, slotted, list-based, and structured models, virtualized children aren't fully known when the widget is built. The widget describes how to produce children on demand, and the element materializes them as the parent's layout decides which are needed. We'll focus entirely on child management; the layout logic that drives virtualization (computing which children are visible) is out of scope.

## What This Guide Covers

- **What Virtualization Actually Is** — The shift from "the widget has children" to "the widget can produce children on demand."
- **Why Virtualization Needs a Custom Element** — The reconciliation model that breaks down when children aren't all instantiated.
- **The Pieces Involved** — Builder-based widget API, the custom element, parent data, and the render object.
- **The Builder-Based Widget API** — Replacing a flat list with a function that produces children by index or key.
- **Layout Drives Materialization** — Why the render object asks for children during layout, not during build.
- **The Custom Element's Storage** — In-memory storage that holds only currently-active children, indexed by their identity.
- **`createChild` During Layout** — The bridge from "the layout wants child N" to "an element exists for child N."
- **Removing Children No Longer Needed** — The element-side cleanup when layout decides a child is offscreen.
- **`BuildOwner.buildScope`** — Why building children mid-layout requires special framework support.
- **The Render Object Side** — Holding active children and providing the layout-driven materialization callbacks.
- **Keys and Identity** — How virtualized children preserve state across scrolling and reordering.
- **What You Get For Free, and What You Don't** — The boundary between framework and your code.
- **Common Pitfalls** — The traps specific to virtualization.

## What Virtualization Actually Is

A non-virtualized multi-child widget knows all its children at build time. A `Column` with `children: [...]` has its complete list of child widgets the moment it's constructed; the element walks that list and creates an element per widget; the render object lays them all out.

A virtualized widget doesn't work this way. Instead of receiving a list, it receives an **instruction for producing children on demand** — typically a builder function and a count, or some equivalent description. At build time, no children are produced. The element exists, the render object exists, but the children don't yet.

Children only come into existence when the layout decides it needs them. For a vertical list, that means: the render object knows the viewport's height, computes which indices are visible, and asks the element to materialize those indices into real elements and render objects. As the user scrolls and different indices become visible, new children are materialized and old ones are torn down.

The benefit is that you can have a logical list of millions of items but only ever pay for the few that are actually on screen.

## Why Virtualization Needs a Custom Element

None of the framework's standard element classes can do this:

- **`SingleChildRenderObjectElement`** assumes one child, known at build time.
- **`SlottedRenderObjectElement`** assumes a fixed set of slots, known at build time.
- **`MultiChildRenderObjectElement`** assumes a flat list of children, known at build time.

All three reconcile children **during the build phase** by comparing the new widget's children against the existing element children. For virtualization, this is the wrong time — at build time, we don't know which children are needed; only the layout knows that.

Virtualization inverts the lifecycle: children are created during **layout**, not during build. This requires a custom element that:

- Doesn't reconcile children at update time, because there's no list to reconcile against.
- Exposes hooks that the render object can call from within layout to materialize children on demand.
- Tracks which children currently exist and what their identity is (by index, by key, or both).
- Tears down children that the layout has decided are no longer needed.

The framework provides primitives that make this possible — most importantly `Element.updateChild` and `BuildOwner.buildScope` — but you compose them yourself.

## The Pieces Involved

A virtualized setup has four parts:

- A **widget** with a builder-based API rather than a children list.
- A **custom element** that materializes children on demand from the builder.
- A **parent data** type that includes an identity field (index, key, or both).
- A **render object** that holds currently-active children and asks the element to materialize or release children as layout dictates.

There's no framework base class for virtualized widgets in general, though Flutter's own `SliverMultiBoxAdaptorWidget` and `SliverMultiBoxAdaptorElement` (which back `ListView` and `GridView`'s lazy variants) are an excellent reference. The rest of this guide describes the pattern they implement, simplified.

## The Builder-Based Widget API

The widget exposes a way to produce children rather than a list of them:

```dart
typedef IndexedWidgetBuilder = Widget? Function(BuildContext context, int index);

class MyVirtualList extends RenderObjectWidget {
  const MyVirtualList({
    super.key,
    required this.itemBuilder,
    required this.itemCount,
    this.itemExtent = 50.0,
  });

  final IndexedWidgetBuilder itemBuilder;
  final int itemCount;
  final double itemExtent;

  @override
  MyVirtualListElement createElement() => MyVirtualListElement(this);

  @override
  RenderMyVirtualList createRenderObject(BuildContext context) {
    return RenderMyVirtualList(itemExtent: itemExtent);
  }

  @override
  void updateRenderObject(BuildContext context, RenderMyVirtualList renderObject) {
    renderObject.itemExtent = itemExtent;
  }
}
```

A few notes on the API design:

- **`itemBuilder` returns `Widget?`.** Returning `null` is allowed and is the conventional signal for "no widget at this index" (out of bounds, missing data, etc.).
- **`itemCount` is the total logical count.** Even though most of these children will never be instantiated, the count is needed for layout (to compute total scroll extent, jump to specific positions, etc.) and for bounds checking.
- **Layout properties like `itemExtent`** are passed through `updateRenderObject`. They affect which indices are visible at any moment.

More sophisticated virtualization widgets accept builders that produce children of varying size, builders keyed by something other than index, or multiple builders for different sections. The simple form above is enough to demonstrate the principles.

## Layout Drives Materialization

In a non-virtualized widget, the lifecycle is:

1. Widget rebuilds.
2. Element reconciles all children at build time.
3. Render object lays out all children.

In a virtualized widget, the lifecycle is:

1. Widget rebuilds.
2. Element does **not** reconcile children — there are no concrete children to reconcile against.
3. Render object's `performLayout` runs.
4. As part of layout, the render object computes which indices are visible.
5. For each newly-visible index, the render object asks the element to materialize that index into a child.
6. For each index that's no longer visible, the render object asks the element to release the child.
7. Layout completes with only the visible children laid out.

The render object is the driver. It's the only piece that knows about layout constraints, scroll position, viewport size, and which indices are visible. The element is the responder — when the render object asks for a child at index N, the element calls the builder, reconciles the resulting widget against any existing element at that index, and routes the resulting render object back to the render object.

## The Custom Element's Storage

The element holds whatever children are currently materialized. The natural storage is a map from index to element:

```dart
class MyVirtualListElement extends RenderObjectElement {
  MyVirtualListElement(MyVirtualList super.widget);

  final SplayTreeMap<int, Element> _children = SplayTreeMap<int, Element>();
  final Set<Element> _forgottenChildren = <Element>{};

  @override
  MyVirtualList get widget => super.widget as MyVirtualList;

  @override
  RenderMyVirtualList get renderObject => super.renderObject as RenderMyVirtualList;
  // ...
}
```

A few notes:

- **`SplayTreeMap`** keeps children sorted by index, which makes iterating in order cheap. Any ordered map works; the framework's own `SliverMultiBoxAdaptorElement` uses a similar structure.
- **Only currently-materialized children are stored.** If indices 5 through 12 are visible, the map has entries for 5 through 12 — nothing else.
- **The index is the slot.** When `insertRenderObjectChild` and friends fire, they'll carry the index as the slot identifier.

The forgotten children set serves its usual role for `GlobalKey` reparenting.

## `createChild` During Layout

The render object calls into the element when it needs a new child materialized. The conventional name for this method is `createChild`, taking an index and information about which sibling the new child sits next to:

```dart
void createChild(int index, {required RenderBox? after}) {
  assert(_currentlyUpdatingChildIndex == null);
  owner!.buildScope(this, () {
    _currentlyUpdatingChildIndex = index;
    try {
      final Widget? newWidget = widget.itemBuilder(this, index);
      final Element? newChild = updateChild(
        _children[index],
        newWidget,
        _IndexedSlot(index, after),
      );
      if (newChild != null) {
        _children[index] = newChild;
      } else {
        _children.remove(index);
      }
    } finally {
      _currentlyUpdatingChildIndex = null;
    }
  });
}

int? _currentlyUpdatingChildIndex;
```

This is the heart of virtualization. A few things are happening:

- **`owner!.buildScope`** wraps the work in a build scope. This is essential because we're about to build widgets and create elements mid-layout, which the framework normally doesn't allow. `buildScope` tells the framework "treat this as a sanctioned build, even though we're inside layout." We'll come back to this below.
- **`widget.itemBuilder(this, index)`** invokes the user's builder to produce a widget for the given index. The result may be `null`, which is treated as "no child at this index."
- **`updateChild`** is the same primitive as in every other custom element. Given the existing child (if any) and the new widget (if any), it handles the four reconciliation cases: create, update, replace, or remove.
- **`_IndexedSlot(index, after)`** is the slot identifier. It carries the index (for the element's storage) and the sibling render object the new child should be placed after (for the render-tree insertion).
- **`_currentlyUpdatingChildIndex`** is a guard against re-entrancy. Building a child can theoretically trigger nested operations; this field, plus the assertion, ensures we don't get confused about which child we're materializing.

The render object calls `createChild` once per index it wants materialized, during its `performLayout`. The element returns control after each call, having either created or updated the element at that index.

## Removing Children No Longer Needed

When the render object decides a child is no longer needed, it asks the element to release it:

```dart
void removeChild(RenderBox child) {
  final int index = renderObject._indexOf(child);
  assert(_currentlyUpdatingChildIndex == null);
  owner!.buildScope(this, () {
    _currentlyUpdatingChildIndex = index;
    try {
      updateChild(_children[index], null, null);
      _children.remove(index);
    } finally {
      _currentlyUpdatingChildIndex = null;
    }
  });
}
```

The pattern mirrors `createChild`. We're still inside a build scope (since this is also called mid-layout), we use `updateChild` with `null` as the new widget to trigger deactivation, and we remove the entry from our storage map.

Real implementations often distinguish between "remove permanently" and "keep alive but not visible" — for example, to preserve scrolled-past state for items that might come back. The framework's `SliverMultiBoxAdaptorElement` does this with a "keep-alive" mechanism. The simple version above just tears children down when they go offscreen.

## `BuildOwner.buildScope`

Calling `buildScope` is what makes mid-layout child building safe. Normally, building widgets and laying out render objects happen in separate, well-defined phases — building first, then laying out the resulting render tree. Mixing them is forbidden, because the framework's invariants depend on them being separate.

Virtualization is the exception. `BuildOwner.buildScope` opens a sanctioned window during layout where building is allowed for the specific element passed in. Inside that scope, the element can:

- Call its builder function.
- Create or update child elements via `updateChild`.
- Trigger render-tree insertions and removals through the standard callbacks.

Outside the scope, normal restrictions apply. The framework uses the scope boundary to enforce that you don't accidentally start building children from anywhere other than the controlled layout-driven path.

The render object never calls `buildScope` directly. The element wraps each materialization call in a scope so the render object can simply call `createChild` and `removeChild` without worrying about the underlying mechanism.

## The Render Object Side

The render object holds active children and provides the layout-driven materialization interface:

```dart
class MyVirtualListParentData extends ContainerBoxParentData<RenderBox> {
  int? index;
}

class RenderMyVirtualList extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, MyVirtualListParentData>,
         RenderBoxContainerDefaultsMixin<RenderBox, MyVirtualListParentData> {

  RenderMyVirtualList({required double itemExtent}) : _itemExtent = itemExtent;

  double _itemExtent;
  double get itemExtent => _itemExtent;
  set itemExtent(double value) {
    if (_itemExtent == value) return;
    _itemExtent = value;
    markNeedsLayout();
  }

  MyVirtualListElement? _element;
  set element(MyVirtualListElement? value) {
    _element = value;
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! MyVirtualListParentData) {
      child.parentData = MyVirtualListParentData();
    }
  }

  int _indexOf(RenderBox child) {
    return (child.parentData as MyVirtualListParentData).index!;
  }

  void _setIndex(RenderBox child, int index) {
    (child.parentData as MyVirtualListParentData).index = index;
  }

  // performLayout calls _element.createChild(index, after: ...) for each
  // newly-visible index, and _element.removeChild(child) for each child
  // that's no longer visible. The mechanics of figuring out which indices
  // are visible are layout-specific and out of scope here.
}
```

A few observations:

- **The render object holds a back-reference to the element.** This is the unusual part. Normally render objects don't know about their elements — but virtualization requires the render object to call back into the element during layout. The element sets this reference during `mount` and clears it during `unmount`.
- **Children are still stored in a linked list.** Even though materialization is on-demand, the children that *do* exist live in the linked list provided by `ContainerRenderObjectMixin`. Layout walks them in order; new children are inserted via the mixin's `insert` method.
- **The index lives in parent data.** Each child knows its logical index, which is what the render object uses to identify it for layout calculations and what the element uses to identify it in its storage map.

The render-tree bridge methods on the element are essentially identical to the list-based case, but with the slot type adapted:

```dart
@override
void insertRenderObjectChild(covariant RenderBox child, _IndexedSlot slot) {
  renderObject.insert(child, after: slot.after);
  renderObject._setIndex(child, slot.index);
}

@override
void moveRenderObjectChild(covariant RenderBox child, _IndexedSlot oldSlot, _IndexedSlot newSlot) {
  renderObject.move(child, after: newSlot.after);
  renderObject._setIndex(child, newSlot.index);
}

@override
void removeRenderObjectChild(covariant RenderBox child, _IndexedSlot slot) {
  renderObject.remove(child);
}
```

The slot type `_IndexedSlot` is a small data class carrying both the index and the previous-sibling reference. The index gets written to parent data; the sibling reference is used for linked-list insertion order.

## Mount, Update, and Lifecycle

The element's `mount` and `update` are simpler than for non-virtualized cases, because they don't reconcile children — children are only created during layout. They mostly just establish the back-reference to the render object:

```dart
@override
void mount(Element? parent, Object? newSlot) {
  super.mount(parent, newSlot);
  renderObject.element = this;
}

@override
void update(MyVirtualList newWidget) {
  final MyVirtualList oldWidget = widget;
  super.update(newWidget);
  // If itemCount or itemBuilder changed, every visible child may need
  // re-materialization. The render object handles this by re-running
  // its visibility computation during the next layout.
  if (newWidget.itemBuilder != oldWidget.itemBuilder ||
      newWidget.itemCount != oldWidget.itemCount) {
    renderObject.markNeedsLayout();
  }
}

@override
void unmount() {
  renderObject.element = null;
  super.unmount();
}

@override
void visitChildren(ElementVisitor visitor) {
  for (final child in _children.values) {
    if (!_forgottenChildren.contains(child)) {
      visitor(child);
    }
  }
}

@override
void forgetChild(Element child) {
  assert(_children.containsValue(child));
  _forgottenChildren.add(child);
  super.forgetChild(child);
}
```

Most of the heavy lifting happens in `createChild` and `removeChild`, not in the standard lifecycle methods.

## Keys and Identity

Keys work in virtualized widgets, but they're trickier. In a non-virtualized list, every child exists, so the framework's `updateChildren` algorithm can match keyed children across positions. In a virtualized list, most children don't exist — they haven't been built. The framework can't match what it doesn't have.

The practical implications:

- **Identity by index works automatically.** When the same index materializes a widget with the same runtime type as before, `updateChild` matches them and preserves state. This is the common case and works without keys.
- **Identity across index changes requires keys *and* extra work.** If item "Alice" moves from index 3 to index 5 because the list was sorted differently, you want the element representing Alice to be preserved. With keys, the framework will preserve identity if both the old and new elements happen to be materialized at the moment the change happens. If Alice was offscreen when she moved, her element wasn't materialized, so there's nothing to preserve — when she scrolls back into view at index 5, a fresh element is created.
- **State preservation for offscreen items** generally requires a "keep alive" mechanism — keeping the element alive even though the render object is no longer in the render tree. This is what `SliverMultiBoxAdaptorElement` and the `KeepAlive` widget do. Implementing it fully is beyond this guide's scope, but it's worth knowing that pure virtualization without keep-alive will lose state for any child that scrolls fully out of view.

For most virtualized lists, index-based identity is sufficient and correct. State that needs to survive scrolling should be stored outside the child element — in a parent's `State`, in a `Provider`, in app-level state — not in the child itself.

## What You Get For Free, and What You Don't

The framework provides:

- **`updateChild`** for per-position reconciliation, just as in every other model.
- **`BuildOwner.buildScope`** for sanctioned mid-layout building.
- **`ContainerRenderObjectMixin`** for linked-list child storage on the render object.
- **Element lifecycle plumbing** (mount, deactivate, unmount) for any children you do materialize.

What you write:

- **The builder-based widget API** and its conventions (what `itemCount` means, what `itemBuilder` returns, etc.).
- **The element's `createChild` and `removeChild` methods**, wrapped in `buildScope`.
- **The render-object's layout logic**, which decides which indices are needed and calls the element accordingly. (This is layout, not child management, so it's out of scope for this guide — but it's the most complex part of a real virtualized widget.)
- **The back-reference plumbing** between element and render object.
- **`visitChildren` and `forgetChild`** for your storage.
- **A slot type** that carries both the index and the previous-sibling reference.
- **Optionally, a keep-alive mechanism** for preserving state across scrolling.

The framework can't generalize virtualization because the layout logic that drives it is inherently widget-specific. A list virtualizes by visible range; a grid virtualizes by visible rectangle; a virtualized graph might virtualize by viewport-intersecting nodes. Each has a different layout algorithm, and each tells the element to materialize different children at different times.

## Common Pitfalls

**Building children outside `buildScope`.** Calling `updateChild` mid-layout without wrapping in `BuildOwner.buildScope` will trip framework assertions. The scope is what makes the operation legal.

**Forgetting to clear `_currentlyUpdatingChildIndex` after exceptions.** The `try`/`finally` pattern matters. If the builder throws, the guard field needs to be cleared anyway, or subsequent operations will see stale state and assertion failures.

**Not establishing the back-reference between element and render object.** The render object needs a way to call back into the element. Set the reference in `mount` and clear it in `unmount`. Forgetting either leaves a dangling reference or breaks layout-driven materialization.

**Calling `markNeedsLayout` from inside layout.** It's tempting, when the widget's `itemCount` or `itemBuilder` changes, to call `markNeedsLayout` from `update`. That's fine — `update` runs during build, not layout. But never call `markNeedsLayout` from inside `performLayout` itself; the framework asserts on this.

**Holding strong references to torn-down children.** When `removeChild` is called, the element is deactivated and (eventually) unmounted. If your code retains a reference to it elsewhere — for example, in a cache outside `_children` — you'll see assertion failures when the element is reused or accessed after unmount. Let go.

**Mistaking index-based identity for stable identity.** Children identified only by index are stable as long as the index doesn't change. The moment the list is reordered (sorted differently, an item inserted at the front), all subsequent indices shift, and every materialized child appears to be "the same widget at a different index" — but it's actually a different logical item now. Stateful children that need to survive reordering need keys *and* a keep-alive mechanism, not just keys.

**Materializing too many children.** Virtualization only saves work if the number of materialized children is bounded. If your layout algorithm accidentally materializes everything in the list (for example, because it iterates over `itemCount` instead of just the visible range), you've paid the cost of virtualization with none of the benefit. Profile materialization counts during scrolling.

**Forgetting to handle `null` from the builder.** `itemBuilder` returning `null` is a valid signal for "no widget here." Your `createChild` should handle it correctly — `updateChild` already does, returning `null` and tearing down any existing element at that index.

That's the complete virtualized-children setup. A builder-based widget API, an element that materializes children during layout via `buildScope`, a render object that drives materialization based on its layout, and the standard primitives — `updateChild`, `ContainerRenderObjectMixin`, parent data — handling the per-child mechanics. It's the most complex child-management model in Flutter, but the framework still provides the load-bearing pieces.