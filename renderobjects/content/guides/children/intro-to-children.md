---
title: Intro to Child Management
description: Learn how Elements and Render Objects manage children.
layout: guides
order: 0
---
# Understanding Elements, Render Objects, and Children in Flutter

This guide is a conceptual survey of how Flutter's element tree and render tree fit together, with a focus on how children are managed and why the responsibility is divided the way it is. It doesn't show you how to implement any specific child arrangement. The goal is to give you a clear mental model so that when you implement custom children later, you understand what you're doing.

## What This Guide Covers

- **The Three Trees** — Widgets, elements, and render objects, and what each one is for.
- **Why Widgets Need Elements** — The role elements play in connecting widgets to a running app.
- **Why Render Objects Aren't Enough** — Why the framework doesn't hand widgets straight to render objects.
- **Where Children Live** — In the element tree, the render tree, or both.
- **Why Elements Orchestrate Child Management** — Why this responsibility doesn't sit in the render tree or the framework.
- **The Child Models** — A brief survey of single, multi, slotted, grouped, and dynamically-built children.
- **Reconciliation in Plain Terms** — What the diff between widget configurations actually does.
- **Lifecycle Coordination** — Ordered sequences of element and render-object operations in common and exceptional cases.
- **How the Two Trees Stay in Sync** — The handoff between element-side operations and render-tree side effects.
- **Mental Model Summary** — A compact restatement of the relationships, useful as a reference.

## The Three Trees

A Flutter app has three parallel trees that describe the UI from different angles.

The **widget tree** is the description you write. Widgets are immutable, lightweight configuration objects. They're recreated on every rebuild and describe what the UI should look like, but they don't do anything by themselves.

The **element tree** is the running instance of your widget tree. Each widget corresponds to an element, and elements persist across rebuilds. When a widget rebuilds and produces a new widget instance with the same type and key in the same position, the existing element is reused with the new widget as its configuration. Elements know where they sit in the tree, track their parents and children, and hold any state that needs to live longer than a single build.

The **render tree** is the geometric and visual representation. Render objects perform layout, paint pixels, handle hit tests, and report semantics. Not every widget corresponds to a render object — many widgets are purely structural — but every render object is owned by some element above it.

These three trees are tightly coupled: widgets configure elements, elements own render objects, and the render tree carries out the work the widget tree describes.

## Why Widgets Need Elements

If widgets describe the UI and render objects do the work, what is the element tree for?

The answer is that widgets are recreated on every rebuild. A `setState` call produces a fresh widget tree from that point downward. If render objects were tied directly to widgets, every rebuild would mean recreating render objects from scratch, losing layout caches, scroll positions, and animation state.

Elements solve this by being long-lived. An element is created once when a widget first appears in the tree and lives until the widget is removed. During each rebuild, the element receives a new widget instance, compares it to the previous one, and decides what to do — usually just update its render object's properties from the new widget's fields, leaving the render object itself in place.

Widgets are cheap to throw away because elements absorb the churn. Every widget needs an element because every widget needs that stability layer.

## Why Render Objects Aren't Enough

Render objects already have child management — parent/child pointers, methods to add and remove children. Why not let widgets directly manipulate render-object children?

Because the widget tree contains far more nodes than the render tree. Most widgets — `Padding`, `Center`, `Builder`, every `StatelessWidget` you write — don't produce render objects of their own; they produce other widgets. A `StatelessWidget` produces whatever its `build` method returns. The widget tree is deep and structurally rich; the render tree is shallower and only contains nodes that actually render.

Elements bridge this gap. The element tree mirrors the widget tree one-to-one, but only some elements own render objects. The rest (called *component elements*) are pure structural passthrough: they have parents and children in the element tree but no render object. Their descendants' render objects are attached to whatever render-object-owning ancestor sits above them.

This means the render tree is built by walking the element tree, skipping elements that don't own render objects, and attaching the ones that do. Render objects can't do this walk by themselves because most of the structure — the `StatelessWidget`s, the `Builder`s — is invisible to them. Only the element tree has the complete picture.

## Where Children Live

Children exist in both trees, but they mean different things.

In the **element tree**, a child is a sub-element that an element created and is responsible for. Element-tree children mirror the widget structure exactly: a `Column` widget with three children produces a `Column` element with three child elements.

In the **render tree**, a child is a child render object. Render-tree children are sparser than element-tree children because most elements don't own render objects. A `Padding` element has one child element, which might be a `StatelessWidget` element, which has one child element, which is a `Text` element. The `RenderPadding`'s single child is the render object produced by the `Text` element — three levels down in the element tree, but one level down in the render tree.

This is why custom child management often involves both trees: adding a child to your element adds it to the element tree, and the corresponding render object also has to end up in the right place in the render tree. The two operations are linked but distinct, and your element performs both.

## Why Elements Orchestrate Child Management

A natural follow-up question: a lot of child management code already lives in the base `Element` class as generic behavior. Why doesn't the framework generalize it all the way, so developers never have to write custom child management?

The answer is that the framework already generalizes everything that *can* be generalized. The reconciliation algorithm itself — the part that decides which children to update in place, which to replace, which to insert, and which to remove — lives in framework code (`updateChild` for single positions, `updateChildren` for ordered lists). What can't be generalized is **how a particular widget exposes its children**, because that varies widget by widget.

Consider what would be needed for the framework to manage children generically. It would need to know:

- **Which fields on the widget are children**, and which are something else. A widget has many fields (colors, padding values, callbacks); only some of them are children. There's no language-level way to say "this field is a child" that the framework can introspect.
- **How children should be matched up.** A widget with a single `child` field and a widget with a `children` list need entirely different reconciliation: the first has one position, the second has many with key-based matching. A widget with named `header` and `footer` fields needs slot-by-slot reconciliation, not list-based reconciliation. The framework can't pick the right approach without knowing the widget's design.
- **What each child means to the render object.** A flex layout's children all get the same treatment; a custom layout with `decoration` children and `content` children treats them differently. The element has to tell the render object which group each child belongs to.

Here are two concrete examples of why developers need control:

- **A `Scaffold`like widget with named slots.** The widget exposes `appBar`, `body`, `floatingActionButton`, `bottomNavigationBar`, and `drawer` as separately-typed properties. These aren't a list — they're distinct positions with distinct types and distinct render-tree placements. A generic framework can't reconcile these correctly without knowing what each property means. The element does: it reconciles each named slot independently and tells the render object which slot each child belongs to.
- **A widget with two unrelated child lists.** A custom chart widget might have a `series` list (the data) and an `annotations` list (overlays on top of the data). Both are ordered lists with keyed reconciliation, but they're not interchangeable — a chart annotation isn't a series, and they're painted differently by the render object. The framework can't combine them into one list and reconcile them together; the element has to reconcile each list separately.

In both cases, the *reconciliation algorithm* is the same generic code the framework already provides. What's custom is the wiring: which widget fields are children, how to organize them in memory, and what to tell the render tree about each one. That wiring can't be generalized because it's specific to each widget's API.

## The Child Models

Different widgets expose their children in different ways. A brief survey of the common models:

- **A single child.** The widget has one optional `child` property. The element holds at most one child element. Reconciliation considers just one position.
- **An ordered list of children.** The widget has a `children` list. The element holds an ordered list of child elements. This is where key-based reconciliation matters most — keyed children can be reordered without losing state.
- **Slotted children.** The widget has multiple named child properties — `header`, `body`, `footer`, or `leading`, `trailing`. The element holds children identified by slot name rather than by position. Each slot is reconciled independently.
- **Multiple groups of children.** The widget has more than one list of children, where each group has its own meaning to the parent render object. The element holds several lists, reconciles each one independently, and tells the render tree which group each child belongs to.
- **Dynamically built children.** The widget produces children by calling a builder function during build, often based on runtime information like layout constraints. The element triggers the builder at the right time and reconciles the resulting widgets.

The underlying principles — reconciliation, slot identification, render-tree attachment — work the same way across all of these. What differs is the in-memory data structure the element uses to hold its children and how the element maps that structure to the render tree.

## Reconciliation in Plain Terms

Reconciliation is the work an element does to keep its children consistent with its widget. Given a new widget configuration and an existing set of child elements, the element figures out the minimum set of operations needed to match the new configuration.

The operations fall into four buckets:

- **Update in place.** If the new widget at a position has the same runtime type and key as the existing child element's widget, the element is reused. It gets the new widget as its configuration, and its render object is updated from the new widget's fields. State is preserved.
- **Replace.** If the new widget at a position doesn't match the existing child element (different type or different key), the old element is torn down and a new one is created from the new widget. State is lost.
- **Insert.** If the new widget configuration has positions the old configuration didn't, new elements are created and mounted.
- **Remove.** If the old configuration had positions the new one doesn't, those elements are deactivated and eventually unmounted.

Keyed children complicate this because keys allow matching across positions, not just at the same index. A keyed child that moves from index 3 to index 1 is preserved as the same element, not torn down and recreated. This is what makes reorderable lists work without losing state.

The reconciliation algorithm itself is provided by the framework — your custom element doesn't reinvent it. What your element provides is the wiring: which in-memory positions correspond to which parts of the widget, and what slot identifies each child to the render tree.

## Lifecycle Coordination

Element children and render-object children don't always come and go at the same moments. A child element can be in the active tree, in transit between parents, or scheduled for disposal. The render object follows along, but not always at the same time. Here are the common cases, broken down by step.

### Adding a new child

The simplest case. When an element gains a new child:

1. The parent element creates a new child element from the new widget.
2. The child element is mounted: its state is initialized, and its `mount` method runs.
3. If the child element owns a render object, it's created during mount.
4. The framework calls `insertRenderObjectChild` on the nearest render-object-owning ancestor, passing the new render object and its slot.
5. The ancestor element attaches the render object to its render object's child structure.

### Updating an existing child in place

When an existing child element is reused with a new widget:

1. The parent element calls `updateChild` with the existing child element and the new widget.
2. The framework verifies the type and key match.
3. The child element receives the new widget and updates its render object's properties.
4. No render-tree attachment changes occur — the render object stays where it is.

### Removing a child

When a child element is no longer needed:

1. The parent element calls `updateChild` with the existing child element and `null` (no new widget).
2. The framework deactivates the child element.
3. The render object is detached from its parent render object via `removeRenderObjectChild` on the nearest render-object-owning ancestor.
4. At the end of the frame, if the child element hasn't been reactivated elsewhere, it's unmounted and its render object is disposed.

### Reordering keyed children

When a keyed child moves to a new position within the same parent:

1. The parent element identifies the keyed child in both the old and new configurations.
2. The child element is reused in its new position.
3. The framework calls `moveRenderObjectChild` on the nearest render-object-owning ancestor with the new slot.
4. The ancestor element repositions the render object within its render object's child structure.

### Deactivation: a child held in limbo

When a child element is removed from the active tree but might come back, it enters a deactivated state. The parent element still holds a reference to the child throughout this process — it's a deliberate part of the design that the parent retains the deactivated child long enough for any potential reparenting to happen. The element isn't gone; it's just not currently active.

1. The child element is deactivated. The framework removes it from the active element tree.
2. The render object is detached from its parent render object.
3. The framework's inactive elements list now holds a reference to the child.
4. At the end of the frame, if nothing has reactivated the child, it's unmounted permanently.
5. If the child *is* reactivated within the same frame, it rejoins the active tree, and its render object is reattached — possibly to a new parent.

### GlobalKey reparenting

This is the canonical reason deactivation exists. When a widget with a `GlobalKey` moves from one parent to another:

1. During the new frame's build, the framework discovers the global-key widget at its new location.
2. The framework looks up the element previously associated with that global key — it's still in its old parent's children.
3. The old parent is told to forget the child via `forgetChild`. The old parent removes the child from its children but does *not* deactivate it. The child element keeps its state and its render object.
4. The render object is detached from the old parent's render object.
5. The child element is moved to its new parent in the element tree. The new parent treats it as one of its children.
6. The render object is attached to the new render-object-owning ancestor via `insertRenderObjectChild`.
7. The child element receives the new widget configuration (via `update`) and finishes reconciliation in its new position.

The element's state and render object are preserved through this entire process. The handoff happens atomically within a single frame. The `forgetChild` hook exists because the old parent needs to remove the child from its bookkeeping without deactivating it — deactivation would tear down the very state that the global key is meant to preserve.

## How the Two Trees Stay in Sync

The element tree and render tree stay synchronized through a clear separation of responsibilities. The element tree is *authoritative* — it decides what should exist, where, and in what order. The render tree is *reactive* — it carries out the mutations the element tree requests.

The flow is consistent. A reconciliation decision happens on the element side (a child is added, removed, or moved). The framework then calls back into the parent element to perform the corresponding render-tree mutation through three methods on `RenderObjectElement`: `insertRenderObjectChild`, `moveRenderObjectChild`, and `removeRenderObjectChild`. Each is given a render object and a *slot* — an opaque identifier that tells the parent element where in the render tree's child structure this render object belongs.

The slot is the bridge between the two trees. The element decides what slot a child occupies (a list index, a named slot, an ordered position with a previous-sibling reference — whatever fits the widget's API), and the slot is what gets passed to the parent render object when wiring up the child. Both sides agree on what each slot means.

Because the element tree is authoritative, all child management starts there. You never call methods directly on the render object to add or remove its children; you call element-side methods that drive the render tree as a consequence. This discipline is what keeps the two trees consistent.

## Mental Model Summary

A compact summary of the relationships:

- **Widgets** are disposable configuration. They're recreated on every rebuild and describe what the UI should be.
- **Elements** are persistent instances that mirror the widget tree. They absorb the churn of rebuilds and decide how the UI changes.
- **Render objects** do the visual and geometric work. They're owned by some (but not all) elements and form a sparser tree than the element tree.
- **The widget tree and element tree are one-to-one.** Every widget has an element.
- **The element tree and render tree are not one-to-one.** Only some elements own render objects; the rest are pure structure.
- **Children exist in both trees with different layouts.** An element-tree child may not correspond to a same-level render-tree child; the render tree skips component elements and attaches descendant render objects to shallower ancestor render objects.
- **Elements orchestrate child management because elements have the information.** Render objects know geometry; elements know widgets, keys, and types — the things that determine reconciliation.
- **The framework can't generalize child management fully** because each widget exposes its children differently. The reconciliation algorithm is generic, but the wiring (which fields are children, how they're organized, how they map to the render tree) is widget-specific.
- **Reconciliation is the diff between the new widget configuration and the existing child elements.** It produces a set of update, replace, insert, and remove operations.
- **The element tree is authoritative; the render tree is reactive.** Element-side operations drive render-tree mutations through insert/move/remove callbacks identified by slots.
- **Deactivation holds a child in limbo.** The parent retains the deactivated child until the end of the frame, allowing for global-key reparenting without losing state.

With this mental model in place, the mechanics of implementing any specific child arrangement become considerably easier to reason about. Each arrangement is a different way of organizing in-memory storage and slots, but the underlying principles — elements decide, render objects react, slots bridge them, the framework provides the reconciliation primitives — are the same across all of them.