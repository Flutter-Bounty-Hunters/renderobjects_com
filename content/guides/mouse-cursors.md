---
title: Mouse Cursors
description: Configure the type of mouse cover hovering over a custom render object.
layout: guides
order: 60
---
# Implementing Mouse Cursor and MouseTracker Integration in a Custom Flutter Render Object

This guide walks experienced Flutter developers through the mouse cursor and hover-tracking responsibilities of a custom `RenderObject`. By the end, you'll understand how Flutter handles cursor changes and hover events on desktop and web, when your render object needs to participate, and how to do it correctly. We'll skip layout, painting, compositing, hit testing, lifecycle, semantics, diagnostics, parent data, and show-on-screen — this is about mouse handling, and only mouse handling.

## What This Guide Covers

- **What MouseTracker Actually Is** — The framework subsystem that maps mouse positions to cursor shapes and hover events.
- **Widget-Level vs Render-Object-Level Mouse Handling** — Why most code uses `MouseRegion` and when a render-object approach makes sense.
- **The `MouseTrackerAnnotation` Mixin** — The interface render objects implement to participate in mouse tracking.
- **Declaring a Cursor** — Picking a `MouseCursor` and exposing it through the annotation.
- **Hover Enter, Exit, and Move Callbacks** — Responding to the mouse entering, leaving, or moving over your render object.
- **How Mouse Hit Regions Are Determined** — The relationship between hit testing and mouse tracking.
- **Updating Cursor State** — Telling the framework when your cursor choice has changed.
- **Stacking and Overlap** — What happens when multiple annotated render objects overlap.
- **Common Pitfalls** — The traps that produce sticky cursors, missed hover events, and platform inconsistencies.

## What MouseTracker Actually Is

`MouseTracker` is the framework subsystem that tracks where the mouse pointer is, decides what cursor shape should be shown, and dispatches hover events to interested render objects.

On platforms with mouse support (desktop and web), the engine reports raw pointer events to the framework: the pointer is at coordinates X, Y; it just moved; it just entered the window; a button was pressed. `MouseTracker` consumes those events and runs a hit test against the render tree, the same way pointer-down events are routed, but for the hover position rather than for a tap. The result is a list of render objects under the cursor. `MouseTracker` then asks each of those render objects: do you have an opinion about the cursor shape? Do you want to know about hover enter/exit/move?

The topmost render object with a cursor opinion wins, and its cursor shape is sent to the platform to update the system cursor. Every render object that wants hover notifications gets the appropriate callbacks as the cursor moves in and out of its region.

Your render object's job, if it cares about any of this, is to implement the `MouseTrackerAnnotation` mixin and declare what cursor it wants and which (if any) hover callbacks it wants to receive. That's it — the framework handles tracking, dispatching, and platform integration.

## Widget-Level vs Render-Object-Level Mouse Handling

Like semantics, most mouse-related work in a Flutter codebase happens at the widget layer, not the render-object layer. The `MouseRegion` widget wraps an arbitrary subtree and provides cursor selection and hover callbacks without anyone writing render-object code. Wrapping a custom button in `MouseRegion(cursor: SystemMouseCursors.click, onEnter: ..., onExit: ..., child: ...)` produces correct cursor behavior with no further effort.

You implement mouse handling at the render-object level in roughly the same situations as semantics: when your render object owns the relevant state, when it's a self-contained primitive, or when you're authoring a low-level reusable widget that should carry its behavior with it. A custom slider that paints its own track and thumb might want cursor changes that depend on whether the mouse is over the thumb specifically — that kind of region-specific cursor logic is hard to express with widget-level wrappers and natural to implement in the render object.

If your case doesn't fall into one of those buckets, prefer `MouseRegion`. The rest of this guide assumes render-object-level integration is the right choice.

## The `MouseTrackerAnnotation` Mixin

`MouseTrackerAnnotation` is the interface a render object implements to participate in mouse tracking. It's a mixin defined in the framework, and once a render object has it, the framework will consult it during mouse tracking.

The mixin declares three things you can override:

- **`cursor`** — A `MouseCursor` that should be shown when the pointer is over this annotation.
- **`onEnter`** — A callback invoked when the pointer enters the annotation's region.
- **`onExit`** — A callback invoked when the pointer exits the annotation's region.
- **`validForMouseTracker`** — A getter that returns whether this annotation should currently be considered.

The shape of a minimal implementation looks like this:

```dart
class RenderHoverableThing extends RenderProxyBox with MouseTrackerAnnotation {
  RenderHoverableThing({super.child});

  @override
  MouseCursor get cursor => SystemMouseCursors.click;

  @override
  PointerEnterEventListener? get onEnter => _handleEnter;

  @override
  PointerExitEventListener? get onExit => _handleExit;

  void _handleEnter(PointerEnterEvent event) {
    // ...
  }

  void _handleExit(PointerExitEvent event) {
    // ...
  }
}
```

There's no `onHover` directly on the mixin — move events between enter and exit are handled differently (covered below), and the most common case is just enter/exit. Override only what you care about.

The annotation only takes effect for render objects that actually pass hit testing. A `MouseTrackerAnnotation` on a render object that hit-tests as transparent won't be reached, because the hit test won't include it in the cursor's list of targets. This is why mouse tracking and hit testing are linked: same hit test result drives both.

## Declaring a Cursor

The `cursor` getter is where you declare what cursor shape should be shown when the mouse is over your render object.

The `MouseCursor` class has a small set of standard system cursors via `SystemMouseCursors` — `click`, `text`, `forbidden`, `grab`, `grabbing`, `resizeLeftRight`, and so on — plus a `defer` value for "don't have an opinion" and a `basic` value for the normal arrow.

The most common choices are:

- **`SystemMouseCursors.click`** for interactive elements like buttons and links.
- **`SystemMouseCursors.text`** for editable text regions.
- **`SystemMouseCursors.basic`** when you want to explicitly assert the default arrow, overriding any inherited choice.
- **`MouseCursor.defer`** when you want to let a parent or descendant decide. This is the default value of the `cursor` getter, and it's the right choice when your render object happens to participate in mouse tracking for other reasons (hover callbacks) but doesn't want to influence cursor shape.

The cursor can depend on render object state — different cursors for different regions, different states, different modes:

```dart
@override
MouseCursor get cursor {
  if (!_enabled) return SystemMouseCursors.forbidden;
  if (_isDragHandle) return SystemMouseCursors.grab;
  return SystemMouseCursors.click;
}
```

When the cursor depends on state that can change at runtime, you need to notify the framework when the choice changes — covered below in the section on updating cursor state.

The cursor is selected by the topmost annotated render object under the pointer that returns something other than `MouseCursor.defer`. If your render object returns `defer`, the framework looks at the next render object beneath it, and so on, falling back to the system default if nothing has an opinion. This stacking behavior is what makes nested cursor regions work naturally — a child can override the parent's cursor, or defer to it.

## Hover Enter, Exit, and Move Callbacks

`onEnter` and `onExit` are how you find out the pointer has entered or left your render object's region. These are the most common hover callbacks you'll want.

```dart
void _handleEnter(PointerEnterEvent event) {
  _hovering = true;
  markNeedsPaint(); // if hover affects appearance
}

void _handleExit(PointerExitEvent event) {
  _hovering = false;
  markNeedsPaint();
}
```

Enter fires once when the pointer first enters the region; exit fires once when it leaves. The events carry the pointer position and other details, but for many uses you just need to know "I'm being hovered now" and "I'm not anymore."

What about *move* events — the pointer moving within the region without entering or exiting? `MouseTrackerAnnotation` itself doesn't expose an `onHover` for these. If you need pointer move events, you have a few options:

- **For most cases, `onEnter` and `onExit` are enough.** You react to hover state changes; the pointer's exact position within the region usually doesn't matter for cursor logic or appearance.
- **If you need the position**, listen for `PointerHoverEvent` at the pointer event level by implementing the appropriate `handleEvent` override on your render object. This integrates with the general pointer event routing, separately from `MouseTrackerAnnotation`.
- **At the widget level**, `MouseRegion` has an `onHover` callback that handles this for you. If you find yourself wanting move-level granularity, ask whether a `MouseRegion` wrapping might be a better fit than a render-object-level approach.

The reason there isn't a built-in `onHover` on the mixin is performance: move events fire at the rate of pointer movement, which can be very high, and forcing every annotated render object to receive them whether they want them or not would be wasteful. The opt-in via `handleEvent` keeps the common case (enter/exit only) lean.

## How Mouse Hit Regions Are Determined

Mouse tracking uses the same hit test as pointer events — `MouseTracker` runs a hit test against the current pointer position and uses the result to find annotated render objects. This has several consequences worth being aware of.

**Your render object's mouse region is its hit-tested region.** Anything you've configured for hit testing — `hitTestSelf`, `hitTestChildren`, non-rectangular hit regions, expanded hit areas — applies equally to mouse tracking. A button that has a circular hit region also has a circular cursor region. A render object that returns `false` from `hitTestSelf` won't receive cursor or hover events, even if it has a `MouseTrackerAnnotation` mixed in.

**Visual extent and mouse region can differ.** Just like with hit testing, a render object that paints a shadow outside its bounds doesn't include the shadow in its mouse region by default — and that's correct. Mouse cursor changes when hovering a shadow would be as surprising as the shadow being tappable.

**Transparent overlays block cursor changes underneath.** A render object that hit-tests as opaque sits in front of anything beneath it for mouse-tracking purposes, even if it has no cursor opinion of its own. To let beneath-content cursors show through, the overlay needs to hit-test as transparent in the relevant regions — usually by returning `false` from `hitTestSelf` or by being implemented as a non-hit-testable visual decoration.

The general principle: if your render object is visible to the mouse hit test, it can participate in mouse tracking; if it's not, it can't. There's no separate mechanism for "mouse-only visibility" — the hit test is the single source of truth.

## Updating Cursor State

When your cursor choice depends on state that can change at runtime — enabled/disabled, hovered state, mode-dependent cursors — you need to tell the framework that the cursor needs to be re-evaluated.

The mechanism is more implicit than for layout or paint: there isn't a `markNeedsCursorUpdate` call. Instead, the framework re-runs cursor selection whenever it would do so anyway — which includes any frame after a hit test changes — so for most cases, simply changing your cursor-affecting state and triggering a repaint or relayout is enough.

The case to watch for is when a state change affects the cursor but *not* layout or paint. If your render object has, say, an `enabled` flag that toggles between `SystemMouseCursors.click` and `SystemMouseCursors.forbidden` but doesn't change appearance, the framework has no reason to re-run anything, and the cursor stays stuck on whichever value was last seen.

The right approach is to ensure your state-changing setters propagate enough to trigger a re-evaluation. In practice, this usually means making sure visual state and cursor state move together — an "enabled" change almost always affects how you paint anyway, so a `markNeedsPaint()` in the setter is enough to cycle mouse tracking. When it doesn't, you can prompt re-evaluation by calling `markNeedsPaint()` even if the paint itself is a no-op, since the cursor reconciliation happens during the normal pipeline pass.

The `validForMouseTracker` getter also plays a role here. If it returns `false`, your annotation is ignored entirely. The default is to return `true` while attached to the tree and `false` once detached. You can override this to selectively opt out — for example, to disable mouse tracking on a render object that's animating out — but most code shouldn't need to.

## Stacking and Overlap

When multiple annotated render objects sit under the cursor at the same point — a button inside a hoverable card, for instance — the framework needs to decide whose cursor and hover callbacks apply.

The rule is **topmost wins for cursor selection**, with `defer` allowing fall-through. The deepest (visually frontmost) render object that returns a non-`defer` cursor sets the system cursor. If the topmost defers, the framework looks at the next one down. This is what lets a small "click" region inside a larger "grab" region work intuitively — the inner element's cursor takes precedence when the mouse is over it, and the outer element's cursor takes over when the mouse moves to the surrounding area.

For hover callbacks, **all annotated render objects under the pointer fire their enter and exit events independently**. Entering an inner element doesn't fire the outer element's exit, because the pointer hasn't actually left the outer region. Similarly, leaving the inner element while still inside the outer doesn't fire an outer enter — it was already entered. The result is the natural behavior most developers expect: nested hover regions stack rather than override.

This is also why setting `cursor` and providing enter/exit callbacks are independent decisions. A render object can defer cursor selection to its parent but still want to know when it's being hovered, just for its own appearance updates. Conversely, a render object can declare a cursor without caring about enter/exit at all.

## Common Pitfalls

**Forgetting that mobile platforms don't have a mouse.** Mouse cursor and hover code runs only when a mouse-like pointer is present, which on most mobile devices means never. Don't make essential functionality depend on hover state — a custom widget that only reveals interactivity through cursor changes is unusable on touch. Hover is for affordance polish on desktop and web, not for primary interaction.

**Returning a cursor when you should defer.** Returning `SystemMouseCursors.basic` doesn't mean "I have no opinion" — it means "I explicitly want the basic arrow," which overrides any ancestor or descendant choice. The correct way to express "no opinion" is `MouseCursor.defer`. Defaulting to `basic` produces subtle bugs where nested cursor regions stop nesting correctly.

**Setting a cursor without a corresponding interaction.** If your render object shows `SystemMouseCursors.click`, users expect clicking to do something. If clicking does nothing, the cursor is lying. Either provide the interaction or use a different cursor (or defer).

**Forgetting to trigger re-evaluation when cursor state changes.** A cursor choice that depends on runtime state needs the framework to re-check it. If the state change doesn't naturally trigger a pipeline pass, the cursor stays stuck. When in doubt, `markNeedsPaint()` in setters that affect cursor — it's cheap and reliably refreshes mouse tracking.

**Heavy work in enter/exit callbacks.** These callbacks fire during normal pointer routing, on the UI thread. Allocating expensive objects, kicking off synchronous work, or rebuilding large widget subtrees in response to a hover produces noticeable jank. Keep callbacks lightweight — flip a flag, mark dirty, move on.

**Listening for hover position when you don't need it.** Implementing `handleEvent` for `PointerHoverEvent` opts you into every mouse-move frame, which can be dozens or hundreds of events per second. Only do this when you genuinely need per-pixel hover position; for most cases, enter/exit is sufficient.

**Overlapping hit-testable elements without thinking about cursors.** Any time you stack hit-testable elements (a tooltip overlay, a custom popup, a decorative banner), think about what the cursor should do. An overlay that hit-tests as opaque but doesn't declare a cursor will produce the default arrow, even if interactive content sits beneath. Either declare a cursor explicitly, defer to descendants, or make the overlay hit-test as transparent in regions where it shouldn't intercept.

That covers `MouseTrackerAnnotation` end to end. It's a small surface — declare a cursor, optionally take enter/exit callbacks — but it's the difference between a custom widget that feels native on desktop and one that feels half-finished.