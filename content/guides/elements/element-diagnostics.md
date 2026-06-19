---
title: Element Diagnostics
description: Implement debugging diagnostics for custom Elements.
layout: guides
order: 40
---
# Implementing Diagnostics for a Custom Flutter Element

This guide walks through the diagnostics responsibilities of a custom `Element`. By the end, you'll understand how Flutter's element-tree diagnostic infrastructure works, what your element needs to do to plug into it, and why making the effort to do so pays off. We'll skip child management, rebuilding, inherited widgets, and other element responsibilities — this is about diagnostics, and only diagnostics.

A parallel guide exists for render-object diagnostics. The two share infrastructure but have different audiences and surface area, so they're worth treating separately.

## What This Guide Covers

- **Why Element Diagnostics Aren't Optional** — The cost of skipping diagnostic support at the element layer.
- **What Element Diagnostics Actually Is** — The framework's diagnostics infrastructure as it applies to elements.
- **`debugFillProperties` for Elements** — The single method that exposes your element's state to the inspector and tree dumps.
- **What Belongs in Element Diagnostics vs Widget Diagnostics** — Why both exist and how to decide where each property goes.
- **Choosing the Right `DiagnosticsProperty`** — Picking the correct property type so values display well.
- **Defaults and Levels** — Controlling what shows up by default.
- **Describing Children** — Letting tree-walking output understand your element's structure.
- **Element Tree Dumps in Practice** — What the output actually looks like for elements with and without diagnostics.
- **`toStringShort`** — The one-line summary used in compact contexts.
- **Debug-Only Invariants With `assert`** — Catching contract violations early without paying for them in release builds.
- **Common Pitfalls** — The traps that make element diagnostics less useful than they should be.

## Why Element Diagnostics Aren't Optional

The same logic that applies to render-object diagnostics applies here, with one extra wrinkle: elements are the layer where rebuild bugs, reconciliation bugs, and inherited-widget bugs actually surface. The widget tree describes what should happen; the render tree shows what got drawn; but if there's a mismatch — a widget that didn't trigger a rebuild, a child that lost its state across a reorder, an inherited widget that didn't notify its dependents — the diagnosis happens at the element layer.

The tools that surface those bugs all rely on element diagnostics:

- **The Flutter widget inspector** in DevTools shows the element tree alongside the widget tree, with each element's properties. A custom element without `debugFillProperties` appears as just a class name, telling you nothing about its state.
- **`debugDumpApp()`** prints the element tree to the console. Like its render-tree counterpart, it's invaluable for understanding the actual runtime structure. Without diagnostics, your element contributes a one-line type name and nothing more.
- **Framework error messages** about element lifecycle violations, reconciliation failures, and assertion failures include the element's diagnostic output as context. Without diagnostics, the context is empty.
- **The "select widget" inspector tool**, which highlights elements as you click on them in a running app, uses element diagnostics to populate the side panel showing what state the selected element holds.

Custom elements are rare enough that when developers do write them, they're almost always doing something subtle — custom child management, virtualization, structured children. Subtle code needs good debugging tools. An element with rich diagnostics is one you can debug interactively in the inspector; an element without them is one you debug by inserting `print` statements until you figure out what went wrong.

The cost is the same as for render objects: one method override, a few `DiagnosticsProperty` lines. The cost of not doing it compounds with every problem you or someone using your widget has to track down.

## What Element Diagnostics Actually Is

Element diagnostics is the element-tree side of Flutter's shared `Diagnosticable` infrastructure. `Element` extends `DiagnosticableTree`, just like `RenderObject` does, and the same set of consumers — DevTools, error reporters, tree dump methods — read element diagnostics through the same APIs.

Each element can describe itself with a structured list of properties (its widget, its slot, any internal state it holds) and a list of children. The framework walks these structures to produce whatever output a given consumer needs: a flat property list for DevTools, an indented tree for the console, a single-line summary for an error context.

You participate the same way you do for render objects: by overriding `debugFillProperties` to add entries to a `DiagnosticPropertiesBuilder`. The mechanism is shared; only what you put in the builder is different.

## `debugFillProperties` for Elements

`debugFillProperties(DiagnosticPropertiesBuilder properties)` is the override where you declare what state your element has and how each piece of state should be displayed. The pattern mirrors render-object diagnostics:

```dart
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  super.debugFillProperties(properties);
  properties.add(DiagnosticsProperty<int>('child count', _children.length));
  properties.add(DiagnosticsProperty<bool>('has forgotten children',
      _forgottenChildren.isNotEmpty,
      defaultValue: false));
  properties.add(IntProperty('currently updating index', _currentlyUpdatingChildIndex,
      defaultValue: null));
}
```

Always call `super.debugFillProperties` first. The base `Element` (and any intermediate classes like `RenderObjectElement`) contributes its own properties — things like the element's depth, lifecycle state, and the dirty flag. Skipping super discards all of that, leaving your element's output less informative than the default.

Keep `debugFillProperties` cheap. It's called whenever the framework needs the element's diagnostic representation — frequently in some scenarios. Avoid expensive computation or large allocations.

## What Belongs in Element Diagnostics vs Widget Diagnostics

A subtle and important point: widgets also have `debugFillProperties`. They're the more common place to expose properties, since `Widget` is also `Diagnosticable`. So what belongs in the element's diagnostics versus the widget's?

The dividing line is **state ownership**:

- **The widget's `debugFillProperties` exposes the configuration the widget was constructed with.** Fields like `color`, `padding`, `alignment`, `child`, `children` — anything passed in by the widget's user. These are recreated on every rebuild and live on the widget.
- **The element's `debugFillProperties` exposes the runtime state the element holds.** Things like the in-memory child storage layout, internal flags (`_currentlyUpdatingChildIndex`, `_forgottenChildren`), inherited-widget dependency information, and lifecycle state. These persist across rebuilds and live on the element.

For a custom element, this means: don't duplicate widget properties in the element. The widget tree and the element tree both appear in DevTools, and seeing `color: blue` listed on both is just noise. The element's properties should be what's *unique to the element* — what you'd want to know that isn't already visible from looking at the widget.

In practice, most custom elements have only a small amount of state worth exposing. The widget-level diagnostics already cover what's configured; the element only needs to expose the runtime bookkeeping.

## Choosing the Right `DiagnosticsProperty`

`DiagnosticsProperty` and its specialized subclasses work the same way for elements as they do for render objects. The most commonly useful types for elements are:

- **`IntProperty`** — Counts and indices.
- **`FlagProperty`** — Booleans, especially state flags that are usually one way and worth highlighting when they're the other.
- **`IterableProperty<T>`** — Collections, useful for things like "the set of currently materialized indices."
- **`DiagnosticsProperty<T>`** — The generic fallback.

Specialized types produce better-looking output and should be preferred. The render-object diagnostics guide goes into more detail; the same advice applies.

## Defaults and Levels

The `defaultValue` parameter has the same effect for elements as for render objects: when a property equals its default, it's hidden from the default output. This is what makes diagnostic output scannable — only properties whose values are interesting appear.

For element diagnostics, common defaults include:

- `defaultValue: 0` for child counts (no children is the boring case).
- `defaultValue: false` for state flags that are rarely true.
- `defaultValue: null` for transient state that's normally absent.

The same `DiagnosticLevel` values apply (`info`, `fine`, `hidden`, `warning`, `error`). Reach for them when you want a property hidden from default output but available in verbose dumps, or when you want to flag an unusual state as a warning.

## Describing Children

For elements that have children, you need to make those children discoverable through `visitChildren`. The framework's diagnostic infrastructure walks `visitChildren` to produce the children section of the element's tree dump.

You probably already have a correct `visitChildren` implementation as part of your child management code — it's the same method the framework uses for lifecycle propagation. If so, the diagnostic infrastructure picks it up automatically; you don't need a separate `debugDescribeChildren` override.

The default behavior labels children numerically. For elements with structured children — slotted, coordinate-based, virtualized — you may want to customize this so children are labeled by their meaningful identifier rather than by index:

```dart
@override
List<DiagnosticsNode> debugDescribeChildren() {
  final children = <DiagnosticsNode>[];
  for (final entry in _children.entries) {
    children.add(entry.value.toDiagnosticsNode(name: 'cell ${entry.key}'));
  }
  return children;
}
```

For a grid with `GridCoord` keys, this produces output like `cell GridCoord(row: 0, column: 1)` instead of `cell 0`, `cell 1`. The improvement is significant when debugging — you can find the element for a specific cell instantly.

## Element Tree Dumps in Practice

To make the value concrete: here's what `debugDumpApp()` produces for an element that hasn't implemented `debugFillProperties`. Notice how little the custom `MyGridElement` contributes compared to the framework-provided elements around it:

```
MyApp
└MaterialApp
 └Scaffold
  └Center
   └MyGrid
    └MyGridElement
      ├cell 0
      │ └Text("A")
      ├cell 1
      │ └Text("B")
      └cell 2
        └Text("C")
```

The element appears in the tree, and its children appear under it because `visitChildren` is correct, but the element itself has nothing to say about its own state.

With a minimal `debugFillProperties` override that exposes the child count and a state flag:

```dart
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  super.debugFillProperties(properties);
  properties.add(IntProperty('cells', _children.length));
  properties.add(DiagnosticsProperty<bool>(
    'has forgotten children',
    _forgottenChildren.isNotEmpty,
    defaultValue: false,
  ));
}
```

The output becomes:

```
MyGridElement(cells: 3)
 ├cell GridCoord(0, 0)
 │ └Text("A")
 ├cell GridCoord(0, 1)
 │ └Text("B")
 └cell GridCoord(1, 0)
   └Text("C")
```

The element's primary diagnostic — its cell count — now shows up inline in the one-line summary, and the structured-children labels make it obvious which element corresponds to which cell. If a forgotten-child state ever became true, it would appear here too.

When something goes wrong — for example, the element gets stuck mid-update because of an assertion failure — additional debug-only state can surface that:

```
MyGridElement(cells: 3, currently updating index: 2, has forgotten children)
```

That single line tells you immediately: an update was in progress for index 2 when something went wrong, and reparenting was also in flight. Without diagnostic support, you'd have nothing but a class name and a stack trace.

## `toStringShort`

`toStringShort` is the one-line summary used in compact diagnostic contexts. The default is the runtime type plus a hash. For most custom elements, this is fine. Override it when you have a distinguishing piece of state that would make error messages substantially clearer.

For most custom elements, the default is enough. Override only when there's a clear gain.

## Debug-Only Invariants With `assert`

Like render objects, custom elements benefit from `assert`-guarded invariant checks. The patterns are the same: check preconditions in setters, postconditions after operations, and invariants at the boundary of methods that maintain critical state.

Custom elements have their own typical invariants worth asserting:

```dart
@override
void mount(Element? parent, Object? newSlot) {
  super.mount(parent, newSlot);
  assert(_children.isEmpty, 'Element should not have children before mount');
}

void createChild(int index, {required RenderBox? after}) {
  assert(_currentlyUpdatingChildIndex == null,
      'Re-entrant child creation: already updating index $_currentlyUpdatingChildIndex');
  // ... rest of the method
}

@override
void forgetChild(Element child) {
  assert(_children.containsValue(child),
      'forgetChild called on a child this element does not own');
  super.forgetChild(child);
}
```

These checks document the element's contract and catch violations at the moment they happen. Like all `assert` statements, they cost nothing in release builds, so there's no reason to skip them.

The framework's own elements are heavily asserted. Anyone debugging your custom element will reach for asserts first when something goes wrong — make sure they fire with useful messages.

## Common Pitfalls

**Forgetting `super.debugFillProperties`.** The base `Element` class and `RenderObjectElement` contribute useful properties (depth, dirty state, slot). Skipping super means your custom element's output is less helpful than the default would have been.

**Duplicating widget properties on the element.** The widget already exposes its configuration through its own `debugFillProperties`. The element should only expose state that's unique to it — its in-memory storage layout, lifecycle flags, dependency information.

**Expensive computation in `debugFillProperties`.** Called more often than you'd expect, especially during inspector interactions and error formatting. Cache derived values if computing them is non-trivial.

**Missing `defaultValue` parameters.** Without defaults, every property appears in every dump, even when its value is uninteresting. The result is cluttered output that buries the actual signal.

**Not customizing children labels for structured children.** If your element manages children by some identifier other than a simple index — slots, coordinates, keys — the default numeric labeling makes diagnostics harder to read. Custom labels in `debugDescribeChildren` are usually a small change with a big readability win.

**Asserting on conditions that can legitimately fail.** Asserts are for "this should never happen, ever." If the condition can be true during normal (even unusual) operation, handle it explicitly. Asserts that fire on valid input train developers to ignore the next assert too.

**Skipping element diagnostics because the widget already has them.** The two layers expose different information. Even if your widget has rich diagnostics, the element layer is where reconciliation bugs and lifecycle bugs are visible, and an opaque element makes those harder to debug.

**Element diagnostics that lie.** If your element exposes a property and the value goes out of sync with the actual state (because of a missed update or a forgotten setter), the diagnostic actively misleads — worse than no diagnostic at all. When in doubt, recompute the value at diagnostic time rather than maintaining a separate field that has to be kept in sync.

That's element diagnostics end to end. It's the same shape as render-object diagnostics — `debugFillProperties`, `debugDescribeChildren`, `toStringShort`, asserts — applied to the element's runtime state rather than the render object's. The work is small; the payoff is that every tool that introspects the element tree gives you useful information about your custom element instead of an opaque class name.