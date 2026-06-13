---
title: Accessing Inherited Widgets
description: Access and depend upon ancestor Inherited Widgets from a custom Element.
layout: guides
order: 10
---
# Accessing Inherited Widgets from Elements and Render Objects

This guide walks through how `InheritedWidget`s connect to the element tree, how custom elements can read inherited state, and how render objects can stay in sync with inherited values that affect their behavior. It assumes you understand what an `InheritedWidget` is from a widget-author perspective (`Theme.of(context)`, `MediaQuery.of(context)`, etc.); the focus here is on how the machinery works underneath and what changes when you're writing custom elements and render objects rather than ordinary widgets.

## What This Guide Covers

- **What Inherited Widgets Actually Are** — How the framework propagates ambient state through the element tree without an explicit pipeline.
- **Why Inherited Widgets Belong to Elements, Not Render Objects** — The reason render objects can't read inherited state directly.
- **`dependOnInheritedWidgetOfExactType` vs `getInheritedWidgetOfExactType`** — Two ways to look up inherited widgets, and when each is appropriate.
- **The Dependency Set** — How elements record which inherited widgets they care about.
- **Notification and Rebuilds** — What happens when an inherited widget's data changes.
- **`didChangeDependencies`** — The hook that fires when a dependency notifies.
- **Reading Inherited Widgets from a Custom Element** — Where in the element lifecycle to do the lookup and how to handle changes.
- **Forwarding Inherited Values to a Render Object** — The standard pattern for keeping a render object configured with ambient state.
- **Reading During Build vs Reading During Layout or Paint** — Why the rules differ and what you can and can't do at each phase.
- **`InheritedModel` and Aspect-Based Dependencies** — A more granular alternative when you only care about part of an inherited widget.
- **Common Pitfalls** — The traps that this surface tends to produce.

## What Inherited Widgets Actually Are

An `InheritedWidget` is a widget that exposes data to all of its descendants without the data having to be passed explicitly through constructor parameters. It's how Flutter handles ambient information that's broadly useful — themes, locale, media queries, navigation state, dependency injection — without forcing every intermediate widget to forward every value.

The mechanism is the element tree. When an element wants to read an inherited widget, it walks up the element tree until it finds the nearest ancestor element whose widget is of the requested type. That widget's data becomes available to the descendant. The lookup is fast because each element maintains a map of inherited widget types found above it in the tree, so walking the tree isn't required at lookup time — only when the map is first populated.

The interesting part isn't the lookup. It's the change notification. When an `InheritedWidget` rebuilds with new data, the framework asks the new widget's `updateShouldNotify(oldWidget)` method whether the change is significant. If so, every descendant element that has registered a dependency on that widget is marked dirty and will rebuild. This is what lets `Theme.of(context)` not just return the current theme but also re-run the build of every widget that read it, automatically, whenever the theme changes.

## Why Inherited Widgets Belong to Elements, Not Render Objects

A natural question: why don't render objects participate in inherited-widget lookup directly? After all, they need ambient state too — a render object that draws text in the ambient text style, or a render object that adjusts its layout based on the ambient text direction, conceptually depends on inherited widgets just as much as any normal widget does.

The answer is that inherited widgets live in the widget tree, and the widget tree is connected through the element tree. Render objects don't have a `BuildContext`, don't participate in dependency tracking, and aren't rebuilt — they're updated by their element. Looking up inherited widgets requires being part of the element tree, which render objects aren't.

The practical consequence: **render objects don't read inherited widgets themselves**. Instead, the element reads inherited widgets (typically during build) and forwards the relevant values to the render object as explicit properties. The render object exposes setters for those properties and reacts appropriately when they change (marking layout or paint dirty). This is the same pattern you already use when wiring up a `RenderObjectWidget` — `updateRenderObject` passes widget fields to render-object properties. Inherited values flow through the same channel.

This is also why `Directionality.of(context)`, `MediaQuery.of(context)`, and similar lookups happen in the *widget's* `build` or `createRenderObject` / `updateRenderObject`, not in the render object itself. The element does the lookup; the render object receives the value.

## `dependOnInheritedWidgetOfExactType` vs `getInheritedWidgetOfExactType`

There are two distinct ways to read an inherited widget from an element, and they differ in one critical way: whether the element becomes a *dependent* of the inherited widget.

- **`dependOnInheritedWidgetOfExactType<T>()`** — Registers the calling element as a dependent of the nearest ancestor inherited widget of type `T`. When that inherited widget later notifies, the calling element will be marked dirty and rebuilt. This is what `Theme.of(context)` and similar `.of()` methods use under the hood.
- **`getInheritedWidgetOfExactType<T>()`** — Returns the same inherited widget but does **not** register a dependency. The calling element will *not* be rebuilt when the inherited widget changes.

Both methods are accessed through the `BuildContext`, which an `Element` implements. So calling them from inside a custom element looks the same as calling them from a `build` method:

```dart
final theme = dependOnInheritedWidgetOfExactType<MyTheme>();
```

The choice between them depends on what you'll do with the value. If you'll use it once and have no need to react when it changes — perhaps in a one-shot computation, or in a context where you're already invalidating yourself for other reasons — `getInheritedWidgetOfExactType` is the right call. If you'll use the value and want to stay in sync with it across rebuilds, `dependOnInheritedWidgetOfExactType` is what you want.

The wrong choice in either direction produces real problems. Using `dependOnInheritedWidgetOfExactType` everywhere creates unnecessary rebuilds when inherited widgets change. Using `getInheritedWidgetOfExactType` when you needed a dependency means your element silently goes out of sync — it has stale ambient values and no mechanism to notice when they've changed.

## The Dependency Set

When an element calls `dependOnInheritedWidgetOfExactType`, the framework adds the calling element to the inherited widget's *dependent set*. This is a `Set<Element>` maintained by the `InheritedElement` (the element backing the inherited widget). The dependency relationship is one-to-many: a single inherited element may have thousands of dependents, and a single dependent may depend on multiple inherited elements.

The dependency set is cleared at the start of every rebuild of the dependent element. This is what makes dependencies dynamic: an element that conditionally reads `Theme.of(context)` only inside an `if` branch will only be a dependent during rebuilds where that branch executes. The next time the element rebuilds without reading the theme, it stops being a dependent.

For custom element authors, this means: dependencies are recorded *during build* (or during whatever phase you do the lookup), and they expire at the start of the next build. You don't manage the set yourself; the framework handles it. But you do need to call `dependOnInheritedWidgetOfExactType` again on every rebuild where you want the dependency to persist.

## Notification and Rebuilds

When an inherited widget rebuilds, the framework compares the new widget to the old via the new widget's `updateShouldNotify(oldWidget)` method. If `updateShouldNotify` returns `false`, nothing happens — the data is considered semantically unchanged. If it returns `true`, every element in the dependent set is marked dirty.

The dirty elements are added to the build owner's dirty list and will be rebuilt in the next build phase. From the dependent element's perspective, the rebuild is indistinguishable from one triggered by `markNeedsBuild` — the same `performRebuild` path runs, the same widgets are re-evaluated, the same render objects get their `updateRenderObject` calls.

The notification doesn't happen synchronously inside `updateShouldNotify`. It happens during the build owner's normal processing of the dirty list. This is important for custom elements because it means you can't rely on the inherited widget change being visible immediately during the same frame's other operations — you'll observe it during your element's own rebuild.

## `didChangeDependencies`

`didChangeDependencies` is the lifecycle method that fires when an inherited widget your element depends on has notified. It's called:

1. Once after `mount`, immediately before the first build.
2. Whenever an inherited widget your element depends on has called `updateShouldNotify` and returned `true`.

The base `Element` implementation does nothing. You override it when you need to perform work *between* learning about a dependency change and the next build — typically to update non-rebuild-driven state.

For a custom element forwarding inherited values to a render object, `didChangeDependencies` is a natural place to push the new value:

```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  final newDirectionality = dependOnInheritedWidgetOfExactType<Directionality>();
  renderObject.textDirection = newDirectionality!.textDirection;
}
```

In practice, most custom elements don't need to override `didChangeDependencies` because their inherited-widget reads happen during build (via `performRebuild` or the widget's `build` method), and the rebuild itself is what propagates the new value. `didChangeDependencies` is the right place when you need to react to dependency changes outside the normal build flow — for example, if your element holds state that depends on an inherited value and needs to be recomputed when that value changes, but doesn't otherwise rebuild.

## Reading Inherited Widgets from a Custom Element

The most common reason a custom element reads inherited widgets is to forward ambient values to a render object. The standard pattern looks like this:

```dart
class MyDirectionalElement extends SingleChildRenderObjectElement {
  MyDirectionalElement(MyDirectionalWidget super.widget);

  @override
  RenderMyDirectional get renderObject => super.renderObject as RenderMyDirectional;

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _updateRenderObjectFromInherited();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateRenderObjectFromInherited();
  }

  void _updateRenderObjectFromInherited() {
    final directionality = dependOnInheritedWidgetOfExactType<Directionality>();
    renderObject.textDirection = directionality?.textDirection ?? TextDirection.ltr;
  }
}
```

A few notes:

- **`dependOnInheritedWidgetOfExactType` is called in both `mount` (via `didChangeDependencies`) and on subsequent dependency changes.** Once dependencies are registered, future changes to that inherited widget will trigger `didChangeDependencies` automatically.
- **Each call to `dependOnInheritedWidgetOfExactType` re-registers the dependency.** This is fine — registration is idempotent within a single build, and the dependency set is cleared at each rebuild so re-registration is required anyway.
- **The render object exposes a setter that handles the property change correctly** (marks needs-layout or needs-paint as appropriate). The element just writes the new value; the render object decides what to do about it.

For widgets that already use `RenderObjectWidget`, the conventional approach is even simpler: do the lookup in the widget's `createRenderObject` and `updateRenderObject`, not in a custom element. That works because both methods receive a `BuildContext`, and they're called at the right times. A custom element is only necessary when you need to do the work outside those methods or when you want the lookup to drive other custom-element behavior.

## Forwarding Inherited Values to a Render Object

The general pattern for any inherited value that affects a render object is:

1. The element reads the inherited widget with `dependOnInheritedWidgetOfExactType`.
2. The element passes the resulting value to the render object via a setter on the render object's class.
3. The setter, on the render object, compares the new value to the old, stores it, and calls `markNeedsLayout`, `markNeedsPaint`, `markNeedsSemanticsUpdate`, or whichever invalidation is appropriate.
4. When the inherited widget changes, the dependency mechanism rebuilds the element, the element re-runs step 1–2, the setter detects the change, and the render object reacts.

The render object never knows that the value came from an inherited widget. From its perspective, the value is just a property that gets set. This separation is what lets render objects stay agnostic about the widget machinery.

For widgets that don't have a custom element, this whole pattern collapses into the widget's `updateRenderObject`:

```dart
@override
void updateRenderObject(BuildContext context, RenderMyWidget renderObject) {
  renderObject.textDirection = Directionality.of(context);
  // ...other properties
}
```

`Directionality.of(context)` is a static helper that calls `context.dependOnInheritedWidgetOfExactType<Directionality>()` under the hood. The widget reads the inherited value during update, pushes it to the render object, and the rest is handled by the dependency mechanism rebuilding the widget when `Directionality` changes.

## Reading During Build vs Reading During Layout or Paint

A critical rule: **you cannot read inherited widgets during layout, paint, hit testing, or any other render-tree phase.** Inherited widget lookups belong to the build phase. Doing the lookup elsewhere produces stale data, assertion failures, or both.

Why? Two reasons:

- **Inherited widget lookups happen through `BuildContext`, which is the element.** Render objects don't have a `BuildContext`. There's no way to call `dependOnInheritedWidgetOfExactType` from `performLayout` or `paint`.
- **Even if there were, the dependency mechanism couldn't react.** A render object that read an inherited widget during paint would have no way to notice when that inherited widget changed — render objects aren't rebuildable. The dependency would be one-way and silently stale.

The practical implication is that any inherited value a render object needs must be pushed to it as a property *before* the layout or paint phase. The widget's build, or the element's `mount`/`update`/`didChangeDependencies`, is the right time. Once layout begins, the render object's values are fixed for that phase.

This is sometimes inconvenient — for example, a render object that wants to behave differently based on `MediaQuery` can't just query it during paint. But the constraint is fundamental: the element-tree side of the framework runs first, computes what each render object needs to know, and pushes the values down. The render-tree side then runs with a complete, stable picture.

## `InheritedModel` and Aspect-Based Dependencies

`InheritedModel` is a more granular alternative to `InheritedWidget` for cases where dependents only care about specific *aspects* of the inherited data. The canonical example is something like a complex theme: most widgets only care about the colors, some care about typography, a few care about animation durations. With a regular `InheritedWidget`, any change to any aspect rebuilds every dependent. With `InheritedModel`, dependents can register interest in specific aspects, and the model decides which dependents to notify based on what changed.

From an element's perspective, the lookup is similar:

```dart
final colors = InheritedModel.inheritFrom<MyAppModel>(this, aspect: MyAppAspect.colors);
```

The mechanism mirrors `dependOnInheritedWidgetOfExactType` — a dependency is registered, and the model's `updateShouldNotifyDependent(oldWidget, dependencies)` method gets to decide, for each dependent, whether its specific aspect changed. Aspect-based dependencies are useful when the cost of unnecessary rebuilds is high and the inherited data has natural sub-structure.

For most custom-element work, regular inherited widgets are sufficient. Reach for `InheritedModel` when profiling shows that an inherited widget is causing many unnecessary rebuilds, and the rebuilds can be substantively reduced by partitioning the data into aspects.

## Common Pitfalls

**Using `getInheritedWidgetOfExactType` when you needed a dependency.** This is the most insidious bug in the inherited-widget API. The lookup returns the right value, so nothing looks wrong at first — but the element doesn't register as a dependent, so when the inherited widget changes, the element doesn't rebuild and the value goes silently stale. If your element reads an inherited widget and needs to react to changes, use `dependOnInheritedWidgetOfExactType`.

**Reading inherited widgets from render objects.** It's not possible (render objects don't have a `BuildContext`), but custom code sometimes tries to work around this with cached references or back-channels to elements. Don't. Push values into the render object from the element, where the dependency mechanism can keep them current.

**Reading inherited widgets during layout or paint.** Same problem as above. The render object doesn't have the right machinery, and the framework can't make the read reactive. All inherited values must be in place before the render-tree phases begin.

**Forgetting that dependencies are cleared at the start of each rebuild.** If your element only conditionally reads an inherited widget, it only conditionally remains a dependent. This is correct behavior, but it can surprise you if you expect dependencies to be sticky. They aren't — re-register on every rebuild where you want the dependency to persist.

**Not implementing `updateShouldNotify` correctly on a custom inherited widget.** If `updateShouldNotify` always returns `true`, every rebuild of the inherited widget triggers a rebuild of every dependent. If it always returns `false`, dependents never rebuild even when the data changes. The right implementation compares the new and old widget's data and returns `true` only when the change is semantically significant.

**Querying inherited widgets in `initState` of a `State` object.** Inherited widget lookups in `initState` register a dependency but cause assertions in debug mode, because the element's dependencies aren't yet fully set up. Move the lookup to `didChangeDependencies`, which is called once immediately after `initState` and is the correct place for this kind of work in a `State`.

**Pushing inherited values to the render object only in `mount` and not in `didChangeDependencies`.** If you do the lookup once in `mount` and never again, the render object will have the value from the initial frame and never see updates. The dependency mechanism will rebuild your element when the inherited widget changes, but if your element's only update path is `update` (which is called when the widget rebuilds) and not `didChangeDependencies` (which is called when an inherited dependency changes), the render object never gets the new value. Both paths need to push the value.

**Holding a stale reference to an inherited widget across builds.** Inherited widget instances change every time the inherited widget rebuilds. Storing a reference to one and reading from it later gives you the old data, not the current data. Always re-query through the dependency mechanism in each build.

That's the complete picture. Inherited widgets are an element-tree concept; they don't reach the render tree directly. Custom elements read inherited widgets through `BuildContext` (which they implement) and push the resulting values to their render objects as ordinary properties. The dependency mechanism rebuilds the element whenever the inherited widget changes, which re-runs the property push automatically. Render objects stay simple: they receive values and react to changes via setters, never knowing or caring where the values came from.