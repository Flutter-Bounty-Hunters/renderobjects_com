---
title: Show on Screen
description: Implement "show on screen" for custom Render Objects.
layout: guides
order: 70
---
# Implementing "Show on Screen" in a Custom Flutter Render Object

This guide walks experienced Flutter developers through the show-on-screen responsibilities of a custom `RenderObject`. By the end, you'll understand how Flutter's scroll-to-reveal mechanism works, when your render object needs to participate, and how to implement it correctly. We'll skip layout, painting, compositing, hit testing, lifecycle, semantics, diagnostics, and parent data — this is about showing on screen, and only showing on screen.

## What This Guide Covers

- **What "Show on Screen" Actually Is** — The framework mechanism that turns "make this visible" into actual scrolling.
- **The `showOnScreen` Method** — The single override that participates in the bubble-up reveal request.
- **When You Don't Need to Override** — The common cases where the default does the right thing.
- **When You Do Need to Override** — Scrollables, virtualized lists, and other render objects that control visibility.
- **Translating the Reveal Rectangle** — Mapping the requested rectangle through your own transform before passing it up.
- **Bringing a Descendant Into View** — The actual scroll-to-reveal logic in scrollable render objects.
- **Animation Curves and Duration** — Passing through animation parameters so the reveal feels coordinated.
- **Common Pitfalls** — The traps that produce broken focus traversal and accessibility navigation.

## What "Show on Screen" Actually Is

`showOnScreen` is the framework mechanism by which any code, anywhere in the tree, can say "please make this render object visible," and any scrollable ancestor that hears the request scrolls to bring it into view.

The mechanism powers more than you might think. `Scrollable.ensureVisible` calls it directly. Focus traversal — when the user tabs to a focusable widget that's currently scrolled out of sight — invokes it on the newly focused element so the scrollable scrolls to reveal it. Accessibility services use it when a screen reader user navigates to an off-screen element. Form validation can use it to scroll to the first invalid field. Any time the framework needs to bring an off-screen element into view, this is the API.

The way it works is a bubble-up: when something asks a render object to show itself on screen, the render object asks its parent to do the same, the parent asks *its* parent, and so on, up the tree. Each ancestor along the way has a chance to either handle the request (by scrolling to reveal the descendant) or pass it along unchanged. Scrollable render objects intercept the request, scroll to bring the descendant into view, and then continue the bubble-up so any *outer* scrollable can do the same with the now-updated position. Non-scrollable render objects just pass it through.

Your render object's job in this process depends on what kind of render object it is. Leaf render objects and most layout containers do nothing — the default implementation handles them. Render objects that apply transforms or clips may need to participate in mapping the reveal rectangle correctly. Scrollables (and anything that controls which descendants are currently visible) need to handle the request actively.

## The `showOnScreen` Method

`showOnScreen({RenderObject? descendant, Rect? rect, Duration duration, Curve curve})` is the override the framework calls to ask your render object to make either itself or a descendant visible.

The parameters describe what's being revealed:

- **`descendant`** — A descendant render object that should be made visible. `null` means "make myself visible."
- **`rect`** — A specific rectangle within `descendant` (or within yourself, if `descendant` is null) that should be visible. `null` means "make the whole thing visible."
- **`duration`** — How long the reveal animation should take. `Duration.zero` means an instant jump.
- **`curve`** — The animation curve for the reveal.

The default implementation in `RenderObject` is small and pass-through:

```dart
// Roughly what the base class does.
void showOnScreen({
  RenderObject? descendant,
  Rect? rect,
  Duration duration = Duration.zero,
  Curve curve = Curves.ease,
}) {
  if (parent is RenderObject) {
    final RenderObject renderParent = parent! as RenderObject;
    renderParent.showOnScreen(
      descendant: descendant ?? this,
      rect: rect,
      duration: duration,
      curve: curve,
    );
  }
}
```

The descendant defaults to `this` when bubbling up — meaning "if no specific descendant was requested, the thing being shown is me." This is what makes `someRenderObject.showOnScreen()` (with no arguments) do the right thing: it asks the parent to make `this` visible, and the parent in turn asks *its* parent, with `descendant` already set to the original render object.

Most render objects accept this default behavior and don't need to override anything.

## When You Don't Need to Override

A render object doesn't need to override `showOnScreen` when:

- **It's a leaf with no descendants.** Nothing below it can request to be shown, and its own request is handled fine by the default bubble-up.
- **It's a passive layout container.** A `Row`, a `Column`, a `Padding`, a `Stack` — anything that just arranges children in place — doesn't intercept the request because it doesn't control descendant visibility. The default bubble-up correctly routes the request to whatever scrollable ancestor exists above.
- **It applies only simple offsets to children.** The default handles offset-based positioning correctly; the parent's coordinate space is the same coordinate space the descendant lives in, modulo a translation that the framework already accounts for through `applyPaintTransform`.

In short: if your render object isn't a scrollable and doesn't apply any non-standard transform, you can skip this entirely.

## When You Do Need to Override

There are three reasons to override `showOnScreen`:

1. **Your render object is a scrollable.** This is the canonical case. You receive a reveal request for a descendant, you compute where that descendant currently sits, and you scroll your viewport so the descendant lands in the visible area. After scrolling, you continue the bubble-up so any *outer* scrollable can do the same.
2. **Your render object virtualizes its children.** A list that lazily instantiates children only when they enter the viewport (something like `ListView.builder`'s underlying viewport) needs to handle requests for children that don't currently exist as render objects yet. Reveal requests for those need to scroll first, then materialize, then complete.
3. **Your render object applies a transform that the framework doesn't already track.** If you apply a custom transform during paint that isn't expressed through `pushTransform` and isn't reported through `applyPaintTransform`, the bubbled rectangle won't match where you've visually placed children, and ancestor scrollables will scroll to the wrong place. The fix is usually to implement `applyPaintTransform` correctly (covered in the compositing guide), not to override `showOnScreen` — but in rare cases where the transform isn't expressible that way, the override becomes necessary.

The vast majority of overrides fall into the first category. The rest of the guide focuses on that case.

## Translating the Reveal Rectangle

Before getting into scrolling itself, there's a subtle point about coordinate spaces. When a descendant requests to be shown on screen, the `rect` parameter describes a region in *that descendant's* local coordinate space. As the request bubbles up through ancestors, each ancestor may need to interpret or transform that rectangle.

In practice, the framework handles the coordinate mapping automatically through `applyPaintTransform`. As long as you've correctly implemented `applyPaintTransform` for any transforms or offsets your render object applies, the rectangle will be interpreted correctly when ancestors map it into their own space. The reveal mechanism uses the same transform chain that hit testing and semantics use, so getting that one method right pays off across all three.

The takeaway is straightforward: if you've already implemented `applyPaintTransform` correctly for hit testing, you don't need to do anything special for `showOnScreen` coordinate handling. The reveal rectangle will travel through the tree correctly without additional work.

## Bringing a Descendant Into View

A scrollable's `showOnScreen` does the actual work of scrolling to reveal a descendant. The shape of the implementation looks like this:

```dart
@override
void showOnScreen({
  RenderObject? descendant,
  Rect? rect,
  Duration duration = Duration.zero,
  Curve curve = Curves.ease,
}) {
  // 1. Figure out where the target is in our own coordinate space.
  final Rect targetRect = _computeTargetRect(descendant, rect);

  // 2. Decide how much to scroll so the target lands in the visible area.
  final double newOffset = _computeScrollOffsetToReveal(targetRect);

  // 3. Animate (or jump) to the new scroll offset.
  if (newOffset != _currentOffset) {
    _scrollPosition.animateTo(
      newOffset,
      duration: duration,
      curve: curve,
    );
  }

  // 4. Continue the bubble-up so outer scrollables can also adjust.
  super.showOnScreen(
    descendant: descendant ?? this,
    rect: rect,
    duration: duration,
    curve: curve,
  );
}
```

Each step has nuances worth being explicit about.

**Computing the target rectangle.** If `descendant` is non-null, you need to map the rectangle (or the descendant's full bounds, if `rect` is null) from the descendant's local coordinate space into yours. The framework's `MatrixUtils.transformRect` combined with the descendant's `getTransformTo(this)` does this — or, more simply, the descendant's bounds in your coordinate space can be computed via the standard transform chain. If `descendant` is null, the target is `rect` (or `Offset.zero & size`) in your own space.

**Deciding how far to scroll.** The reveal logic is usually "scroll the minimum amount needed to make the target fully visible." If the target is already visible, don't scroll. If it's above the viewport, scroll up just enough to bring its top edge into view. If it's below, scroll down to bring its bottom edge in. If it's larger than the viewport, decisions need to be made about which edge to align — usually the leading edge.

**Animating or jumping.** Pass `duration` and `curve` through to whatever scroll position controller you're using. If `duration` is `Duration.zero`, jump immediately (`jumpTo`) rather than animating; otherwise animate with the given curve.

**Continuing the bubble-up.** This is the most easily forgotten step. After you scroll to reveal the descendant, an *outer* scrollable may need to also scroll to reveal *you* (since you may have just shifted within your own parent). Call `super.showOnScreen(...)` with the same descendant so the request keeps propagating. If you skip this, nested scrollables (a horizontal list inside a vertical list, for example) won't both scroll together when a deeply-nested element requests reveal.

## Animation Curves and Duration

The `duration` and `curve` parameters describe how the reveal should feel, and they're meant to flow through unchanged from caller to scrollable. Don't override them or substitute your own preferences. Doing so produces inconsistent feel across reveal sources — focus traversal animates one way, `ensureVisible` animates another, accessibility navigation animates a third.

Two exceptions are worth noting. First, `Duration.zero` always means "jump, don't animate." Even if your scrollable normally prefers smooth scrolling, respect the zero duration when it's passed — it's used in performance-sensitive paths and in tests. Second, if your scrollable has a custom physics simulation (a spring, a bounce, a snap-to-page behavior), you may need to translate `duration` and `curve` into whatever your physics expects. Just don't ignore them entirely.

Pass the same `duration` and `curve` through to the `super.showOnScreen` call as well, so the bubble-up reaches outer scrollables with consistent timing.

## Common Pitfalls

**Forgetting to bubble up after handling.** A scrollable that scrolls to reveal the descendant but doesn't call `super.showOnScreen` breaks nested scrollables: the inner one scrolls, the outer one doesn't realize the inner one is now in a different position relative to its own viewport, and the descendant ends up correctly revealed within the inner scrollable but still off-screen overall.

**Bubbling up without the descendant parameter.** Calling `super.showOnScreen()` without explicitly passing `descendant: descendant ?? this` causes the outer scrollable to receive a reveal request for the wrong target. The pattern is always to pass `descendant ?? this` — preserving the original descendant if there was one, falling back to yourself if the request originated at this level.

**Ignoring `Duration.zero`.** Scrollables that always animate, even when `Duration.zero` is passed, break tests (which expect immediate state changes) and produce subtle bugs in code paths that need instant repositioning. Always check the duration and jump when it's zero.

**Doing nothing when the descendant is already visible.** This is a feature, not a bug — but it can be a bug if your "already visible" check is too lenient. If the descendant is *partially* visible, callers usually want it brought fully into view. Compute visibility against the descendant's complete bounds, not just a single point.

**Overriding when you didn't need to.** A `Row` or `Column` that overrides `showOnScreen` to do something custom usually breaks the bubble-up rather than improving it. If your render object isn't a scrollable, doesn't virtualize children, and reports its transforms through the standard channels, leave the default alone. The default is correct for the common case.

**Forgetting to consider virtualization.** A virtualized list that's asked to reveal a child that hasn't been instantiated yet needs to scroll to where the child *would* be, materialize the child, and then potentially re-fire the reveal once the child exists with concrete bounds. Naively assuming the descendant is a live render object will fail in lazy-build scenarios.

That covers `showOnScreen` end to end. Most render objects don't need to touch it — the default behavior handles everything correctly. But for scrollables and other render objects that gate descendant visibility, getting it right is what makes focus traversal, accessibility navigation, and explicit reveal requests all work seamlessly together.