---
title: Semantics
description: Implement semantics for Render Objects
layout: guides
order: 40
---
# Implementing Semantics in a Custom Flutter Render Object

This guide walks experienced Flutter developers through the semantics responsibilities of a custom `RenderObject`. By the end, you'll understand how Flutter exposes the rendered UI to assistive technologies, what your render object's role is in producing that representation, and how to do it correctly. We'll skip layout, painting, compositing, hit testing, and lifecycle — this is about semantics, and only semantics.

## What This Guide Covers

- **What Semantics Actually Is** — How Flutter builds a parallel tree for screen readers and other assistive technology.
- **The `describeSemanticsConfiguration` Method** — The single override where you describe what your render object means.
- **The `SemanticsConfiguration` Object** — The bundle of properties, flags, and actions you populate.
- **Labels, Hints, and Values** — The textual content that assistive technology actually reads aloud.
- **Flags and Roles** — Declaring that your render object is a button, header, image, checkbox, and so on.
- **Actions** — Exposing operations like tap, scroll, increment, and dismiss to assistive technology.
- **Merging and Isolation** — Controlling how your semantics combine with descendants and ancestors.
- **Blocking, Excluding, and Hiding** — Removing nodes from the semantics tree on purpose.
- **`markNeedsSemanticsUpdate`** — Telling the framework when your semantic state has changed.
- **Coordinate-Affecting Operations** — When semantics need to know about transforms and clips.
- **Common Pitfalls** — The specific bugs this surface tends to produce.

## Widget-Level vs Render-Object-Level Semantics

Before getting into the render object API, it's worth setting expectations about where semantics work usually happens in a Flutter codebase. Most of it happens at the widget layer — not at the render object layer.

The widget framework provides `Semantics`, `MergeSemantics`, `ExcludeSemantics`, `BlockSemantics`, and a handful of related widgets that wrap arbitrary subtrees and contribute semantic information without anyone writing render-object code. Wrapping a custom button in `Semantics(button: true, label: 'Submit', onTap: ..., child: ...)` produces correct screen reader behavior without the underlying render objects needing to know anything about it. This is the right answer for the vast majority of cases. If your custom widget is *composed* of existing widgets (containers, paint primitives, gesture detectors), the right place to add semantics is at the widget layer using these wrappers.

You implement semantics at the render-object level in three situations. First, when your render object is the only thing that has the information needed to populate the configuration — for example, a custom scrollable that knows its own scroll extent and needs to expose scroll actions that depend on layout state. Second, when you're building a self-contained custom widget whose corresponding render object naturally owns the semantic identity — a custom slider with its own painting, gesture handling, and value state, where the render object is the slider. Third, when you're authoring a low-level reusable primitive (a library widget meant to be composed into other widgets) and you want the semantics behavior to ride along with the primitive itself, so consumers don't have to remember to wrap it.

If none of those apply, prefer the widget layer. Render-object semantics is fully featured but more verbose, more tied to the specific render object, and less composable than wrapping with `Semantics`. The rest of this guide assumes you've decided you need the render-object-level approach for one of the reasons above.

## Where Semantics Code Lives

Semantics has its own dedicated entry point: `describeSemanticsConfiguration(SemanticsConfiguration config)`. This is the single method you override to describe what your render object means to assistive technology, and almost everything else in this guide happens inside it. A small number of related members live outside — `markNeedsSemanticsUpdate` for invalidation, occasionally overrides like `assembleSemanticsNode` for advanced cases — but the main work is the configuration method.

A render object with no override produces an empty configuration, which means it contributes nothing of its own to the semantics tree. Its children's semantics still flow through, but the render object itself is invisible to screen readers. This is the correct default for purely structural render objects (a custom `Row`, a `Stack`) — they're geometric, not semantic. Override `describeSemanticsConfiguration` only when your render object has semantic meaning of its own: it's a button, it's a label, it's an interactive control, it represents an image.

## What Semantics Actually Is

Semantics is the process by which Flutter produces a parallel tree of `SemanticsNode` objects that describes the rendered UI in terms assistive technology can understand — labels, roles, actions, and relationships — rather than in terms of pixels and geometry.

Screen readers (TalkBack on Android, VoiceOver on iOS, NVDA on Windows, and so on), switch control devices, and various accessibility services on each platform need to know things like: "this is a button labeled 'Submit' that can be activated," "this is a text field with current value 'hello' that accepts text input," "this is a header that introduces the following section." None of that is recoverable from the pixel buffer. Flutter constructs it from the render tree by walking each render object and asking what semantic information it contributes.

The semantics tree is built parallel to (and computed from) the render tree, the way the layer tree is. Every frame where semantics state has changed, the framework walks render objects with semantics enabled, builds (or updates) corresponding `SemanticsNode` objects, and ships the resulting tree to the platform's accessibility services. Your render object participates by populating a `SemanticsConfiguration` with its semantic properties. The framework handles tree construction, node identity across frames, change notifications to the platform, and everything else downstream.

A render object's job is narrow: describe yourself. You don't construct semantics nodes, you don't manage the tree, you don't decide how merging happens globally — you just answer "what do I mean, in accessibility terms?"

## The `describeSemanticsConfiguration` Method

`describeSemanticsConfiguration(SemanticsConfiguration config)` is the override the framework calls to ask your render object what it contributes to the semantics tree.

You receive a `SemanticsConfiguration` to populate and return nothing — the framework owns the object. You set properties on it, add actions, set flags, and that becomes your semantic identity. The simplest possible override looks like this:

```dart
@override
void describeSemanticsConfiguration(SemanticsConfiguration config) {
  super.describeSemanticsConfiguration(config);
  config.label = 'Submit';
  config.isButton = true;
  config.onTap = _handleTap;
}
```

Always call `super` first. The base implementation is empty in `RenderObject`, but subclasses you may extend (proxy boxes, container types) can contribute their own configuration, and skipping super will discard that contribution.

The method is called whenever the framework rebuilds your semantics node, which is whenever you've been marked dirty for semantics (via `markNeedsSemanticsUpdate`) and the next semantics pass runs. This means the method may be called frequently in some scenarios, so keep it cheap — don't do expensive work or allocate large objects here. If your label is computed from inputs, compute it lazily and cache it where possible.

## The `SemanticsConfiguration` Object

The `SemanticsConfiguration` is the bundle of state you fill in during `describeSemanticsConfiguration` — a single object that holds everything an assistive technology needs to know about your render object.

It has a wide surface: text properties (`label`, `value`, `hint`, `increasedValue`, `decreasedValue`), boolean flags (`isButton`, `isHeader`, `isImage`, `isChecked`, `isSelected`, `isFocused`, and dozens more), action handlers (`onTap`, `onLongPress`, `onScrollUp`, `onIncrease`, `onSetText`, and so on), and structural controls (`isSemanticBoundary`, `explicitChildNodes`, `isBlockingSemanticsOfPreviouslyPaintedNodes`).

You don't have to set most of them. Anything you don't touch stays at its default, which generally means "no opinion" or "not applicable." Set only what's actually true of your render object.

Once you return, the framework reads the configuration and uses it to construct or update your `SemanticsNode`. After that, the configuration object is reused or discarded as the framework sees fit; you don't hold onto it.

## Labels, Hints, and Values

Labels, hints, and values are the three main textual properties on a `SemanticsConfiguration`, and the distinction between them is more meaningful than it might first appear.

**`label`** is the primary identification of what the element is. For a button, the label is the button's text or purpose: "Submit," "Close," "Add to cart." A screen reader speaks this when focus lands on the element. Every interactive element should have a label.

**`value`** is the current state or content of the element. For a slider, the value is the slider's current numeric position (formatted as text). For a checkbox, the framework derives the spoken state from the `isChecked` flag rather than from `value`, so `value` is usually empty for boolean controls. For a text field, the value is the current text content. Use `value` when the element has *state* that's distinct from its identity.

**`hint`** is supplementary instruction about what happens when the element is activated. For a button labeled "Delete," a hint might be "Double tap to delete this item." Hints are read after a delay by most screen readers, and many users have them disabled — so a hint should add information, not be load-bearing. Anything essential belongs in the label.

```dart
@override
void describeSemanticsConfiguration(SemanticsConfiguration config) {
  super.describeSemanticsConfiguration(config);
  config.label = 'Volume';                // What it is.
  config.value = '${(_volume * 100).round()}%';  // Its current state.
  config.hint = 'Slide to adjust';        // Supplementary action info.
}
```

A note on language: these strings are spoken verbatim by the screen reader, so they should be localized just like any visible text. Don't hardcode English strings in a custom render object that ships to multiple locales — accept the strings as inputs from the corresponding widget, which can localize them via the normal `Intl`/`AppLocalizations` mechanisms.

There's also `increasedValue` and `decreasedValue`, which are the values that *would* be reached by an increment or decrement action. These are useful for sliders and other adjustable controls — screen readers may announce them when the user invokes the corresponding action, and some platforms use them to preview the change.

## Flags and Roles

Flags on `SemanticsConfiguration` declare what *kind* of thing your render object is — button, header, image, text field, checkbox, and so on. They affect how assistive technology announces the element and what gestures it offers.

A few of the most important flags:

- **`isButton`** — The element is activatable in a button-like way. Combined with `onTap`, this tells screen readers to announce "button" after the label and to offer tap-to-activate.
- **`isHeader`** — The element introduces a section. Screen readers offer fast navigation between headers, so marking section titles correctly matters a lot for navigation efficiency.
- **`isImage`** — The element is an image. Screen readers announce it as such and may offer image-description services.
- **`isTextField`** — The element accepts text input. This unlocks text editing gestures and announcements.
- **`isLink`** — The element behaves as a hyperlink.
- **`isChecked` / `isToggled` / `isSelected` / `isFocused` / `isEnabled`** — State flags. These are *current state*, not capability; pair them with the appropriate `is*` flag for the role (e.g., `isCheckbox` plus `isChecked`).
- **`isLiveRegion`** — Changes to this element should be announced as they happen, even when focus is elsewhere. Useful for status messages and notifications.
- **`isObscured`** — The visible text is obscured (a password field). Screen readers behave differently to preserve privacy.

Set flags honestly. A common mistake is to mark something `isButton` because it looks like a button visually, even though it doesn't respond to taps. Screen reader users who invoke it then get nothing — the role implied an affordance that doesn't exist. The rule is: if you set a role flag, provide the corresponding action.

## Actions

Actions are the operations your render object exposes to assistive technology — things like tap, long-press, scroll, increment, dismiss, copy, paste, set selection, and so on.

Each action is a callback you assign on the configuration:

```dart
config.onTap = () => _activate();
config.onLongPress = () => _showContextMenu();
config.onIncrease = () => _setValue(_value + _step);
config.onDecrease = () => _setValue(_value - _step);
```

When you assign one of these, the framework automatically declares that the action is *available*, and the platform's accessibility services offer it through their own UI — VoiceOver's rotor, TalkBack's local-context menu, a switch device's action list. The user picks the action and the platform invokes your callback.

Two things to be aware of. First, the actions you expose should be the same set the element supports through ordinary gestures. If a `GestureDetector` higher up handles taps and that's what activates your custom render object, the *render object itself* doesn't need an `onTap` — the gesture detector probably already provides one through its own semantics. Putting it in both places creates duplicate semantic actions, which is confusing.

Second, actions like `onIncrease` and `onDecrease` are for adjustable elements (sliders, steppers, volume controls). They're not generic "do something" actions; they specifically signal "this is an element with a value range, and these are the primitives for changing it." Screen readers expose them through dedicated gestures (a vertical swipe on iOS, for example), so providing them correctly makes your control natively adjustable through accessibility gestures without any extra work.

There are many more actions: `onScrollUp`, `onScrollDown`, `onScrollLeft`, `onScrollRight`, `onDismiss`, `onCopy`, `onPaste`, `onSetSelection`, `onSetText`, `onDidGainAccessibilityFocus`, `onDidLoseAccessibilityFocus`, and others. Use them as their names suggest, only where the action genuinely applies.

## Merging and Isolation

Merging and isolation control how your render object's semantics combine with those of its descendants — and getting this right is what determines whether a screen reader treats a complex composition as one element or many.

By default, every render object that contributes semantics produces its own node in the semantics tree, and a parent's semantics sit alongside its descendants'. This is correct for layouts where each piece is independently meaningful — a list of buttons, a row of distinct controls. But it's wrong for composite elements that the user should perceive as a single thing, and there are several controls for changing that behavior. Each one solves a different problem.

### Use case: a button composed of an icon and a label

A custom "Submit" button paints an icon, a label, and a background, and the whole thing is one tap target. Without intervention, the icon, label, and background would each produce their own semantics node, and the user would have to navigate through all three to traverse a single button.

The fix is **`isMergingSemanticsOfDescendants = true`** on the button's render object. Descendants' semantics — the icon's `isImage` flag, the label's text — fold into this node. The screen reader sees one "Submit button" with everything combined.

```dart
@override
void describeSemanticsConfiguration(SemanticsConfiguration config) {
  super.describeSemanticsConfiguration(config);
  config.isButton = true;
  config.label = 'Submit';
  config.onTap = _handleTap;
  // Roll up the icon and label into this single semantic node.
  config.isMergingSemanticsOfDescendants = true;
}
```

This is the most common merging case, and probably the one you'll reach for most often.

### Use case: a card containing an inline "remove" button

A card displays an item with a title, description, and an inline "X" button that removes the item. The card as a whole is tappable (it opens a detail view), but the "X" button needs to remain a separately-focusable element so screen reader users can dismiss the item directly.

If the card uses `isMergingSemanticsOfDescendants = true` naively, the "X" button gets absorbed into the card and disappears as a distinct target. The fix is for the "X" button's render object to declare itself as a **semantic boundary** via `isSemanticBoundary = true`. Merges don't cross semantic boundaries, so the card's merge stops at the button, and the button retains its identity.

```dart
// On the inline "Remove" button's render object:
@override
void describeSemanticsConfiguration(SemanticsConfiguration config) {
  super.describeSemanticsConfiguration(config);
  config.isButton = true;
  config.label = 'Remove';
  config.onTap = _handleRemove;
  // Prevent the ancestor card from absorbing this button into its merge.
  config.isSemanticBoundary = true;
}
```

The semantic boundary is the protection mechanism: any time an ancestor might be tempted to merge an inner interactive element away, the inner element opts out by declaring itself a boundary.

### Use case: a complex layout with deliberate child structure

A composite element — say, a custom data row that contains multiple distinct, separately-focusable fields — needs its children to appear as siblings under a single parent node, regardless of how ancestors above it might be configured for merging. You want a stable, explicit tree shape that's robust to ancestor changes.

The control for this is **`explicitChildNodes = true`**. It declares that this node has explicitly-defined child structure and that the framework shouldn't auto-merge children into it. The children remain individually addressable, and the structure is preserved.

```dart
// On a custom data row render object whose children should each remain distinct:
@override
void describeSemanticsConfiguration(SemanticsConfiguration config) {
  super.describeSemanticsConfiguration(config);
  config.label = 'Order summary';
  // Children below us produce their own nodes, sibling-style, under this one.
  config.explicitChildNodes = true;
}
```

This is the rarest of the three and you usually don't need it. Reach for it when you're building something with deliberately structured semantics — a table, a tree, a list with specific child relationships — and you want the structure to be authoritative rather than discovered.

### The mental model

To summarize the three controls:

- **`isMergingSemanticsOfDescendants`** — Collapse everything below me into one node. Use for composite single-element experiences (buttons, list tiles, named groups).
- **`isSemanticBoundary`** — Stop a merge from absorbing me. Use on inner interactive elements that need to stay focusable inside a merged ancestor.
- **`explicitChildNodes`** — Preserve my child structure explicitly. Use for deliberately-shaped semantic trees where children are siblings of each other under me.

In practice, merging is the most common need, semantic boundaries are the protection you add when nesting interactive elements, and explicit child nodes is the escape hatch for unusual structural needs.

## Blocking, Excluding, and Hiding

Sometimes you want to remove things from the semantics tree, not add them. There are three related controls, each for a different reason.

**Excluding** means "this render object and its descendants contribute no semantics." Set `config.isSemanticBoundary = true` and don't populate any other properties, and the subtree is effectively invisible to accessibility. The more direct way is to wrap with `ExcludeSemantics` at the widget level, but at the render-object level you can simply produce an empty configuration and ensure descendants don't slip through (covered below by blocking).

**Blocking** is the stronger version: `config.isBlockingSemanticsOfPreviouslyPaintedNodes = true` tells the framework to discard the semantics of anything painted *before* this render object that would otherwise be visible underneath it. The canonical use case is a modal overlay — the screen behind the modal is technically still in the render tree and still producing semantics, but a screen reader shouldn't be able to focus on it while the modal is open. Blocking removes the underlying nodes from consideration entirely.

**Hiding**, via `config.isHidden = true`, is rarer. It means the node still exists in the semantics tree but is marked as currently invisible — useful for animations where a node is fading out and shouldn't receive focus, but still needs to be present for transition continuity. Most code shouldn't need this; widgets like `Offstage` and `Visibility` handle the common cases at a higher level.

The distinction matters because each one has different effects on what assistive technology sees. Excluding makes the subtree silent. Blocking makes earlier-painted nodes silent. Hiding makes the node present but skipped for focus. Choose deliberately.

## `markNeedsSemanticsUpdate`

`markNeedsSemanticsUpdate` is how you tell the framework that your render object's semantic state has changed and that `describeSemanticsConfiguration` needs to be called again.

If a property that affects semantics changes — your label, your value, whether you're checked, whether you're enabled — you must call `markNeedsSemanticsUpdate` in the setter. The pattern mirrors `markNeedsLayout` and `markNeedsPaint`:

```dart
set label(String value) {
  if (_label == value) return;
  _label = value;
  markNeedsSemanticsUpdate();
}
```

Without this, the platform's accessibility service keeps reporting the *previous* label, value, or state — which produces the classic "the checkbox visibly toggled but the screen reader still says 'unchecked'" bug. The visual update happens (because you called `markNeedsPaint`), but the semantics weren't told to refresh.

A subtle point: `markNeedsLayout` does *not* imply `markNeedsSemanticsUpdate`. Layout and semantics are independent dirty channels. If a change affects both layout and semantics — for example, you're a scrollable that just scrolled, which changes both where children paint *and* which children are visible to accessibility — you may need to call both. Most of the time, a single semantic-affecting property change just needs `markNeedsSemanticsUpdate`.

The early-return pattern matters here too. Marking semantics dirty triggers a tree walk and a platform-level update; doing it for a no-op change is wasteful and, at scale, can produce noticeable accessibility-side jank.

## Coordinate-Affecting Operations

The semantics tree carries spatial information — each node has a bounding rectangle in screen space — so the same transforms that affect paint and hit testing also affect semantics, and the framework needs to know about them.

For most render objects this happens automatically. The framework derives semantic node bounds from your `size` and your position in the tree, and it understands the standard transforms applied by `pushTransform`, `pushOffset`, repaint boundaries, and so on. You don't override anything.

You do need to think about it in two cases. First, if you've implemented `applyPaintTransform` for hit testing (because you push a custom `TransformLayer` or use `pushTransform`), the same implementation is used by the semantics pass — semantics and hit testing share this transform-reporting hook. Get `applyPaintTransform` right and semantics gets the same correct answer.

Second, if your render object reorders children in ways that paint and hit testing already account for (a reverse-painted stack, for example), semantics also follows the order implied by `visitChildren`, which is *not* necessarily the paint order. If the order matters for screen reader traversal — and it usually does, since screen readers walk semantics in tree order — you may need to override `visitChildrenForSemantics`, which lets you provide a separate iteration order specifically for semantics. This is uncommon but worth knowing about for unusual layouts.

## Common Pitfalls

Semantics bugs have a distinctive quality: they're invisible to sighted developers and only surface when someone actually enables a screen reader. A few patterns to watch for:

**Forgetting `markNeedsSemanticsUpdate`.** The most common bug. The visible state updates because you called `markNeedsPaint`, but the screen reader keeps reading the old state. Anything you announce semantically — labels, values, flags — needs its own dirty signal when it changes.

**Setting a role flag without the action, or an action without the role.** `isButton` without `onTap` produces an element that announces as a button but does nothing when activated. `onTap` without `isButton` produces an actionable element with no role announced. Pair them.

**Hardcoded English labels.** A custom render object that lives in a reusable library and bakes in `"Submit"` as a literal string ships an English-only experience to users in every other locale. Strings come from the corresponding widget, which localizes them.

**Over-merging.** Setting `isMergingSemanticsOfDescendants = true` on a large region can absorb inner interactive elements that should stay focusable. Use semantic boundaries to protect them, or be more granular about where merging happens.

**Under-merging.** The opposite: composing a "button" out of an icon and a label without merging, so the user has to focus three times to traverse what should be a single element. If your composite has a single interaction, it's a single semantic node.

**Trusting visual hierarchy.** Just because something looks like a section header doesn't mean the framework will figure that out — `isHeader` has to be set explicitly. Same for `isImage`, `isLink`, and the rest. Visual styling and semantic role are independent.

**Putting accessibility text in the hint instead of the label.** Hints are optional, delayed, and often disabled. Anything essential ("This button deletes the item") belongs in the label, possibly combined with the action's effect.

**Leaving semantics off entirely.** A custom render object with no semantics override is invisible to screen readers. For purely structural render objects this is correct — but for anything that has meaning, anything interactive, anything users need to perceive, no override means no accessibility. The default isn't "the framework figures it out"; it's "this element doesn't exist to assistive tech."

Getting semantics right is mostly about treating it as a first-class output of your render object, equal in weight to paint and hit testing. The visual rendering, the touch handling, and the accessibility tree are three parallel representations of the same UI — and shipping a render object that only handles two of the three means shipping a render object that's broken for a real portion of your users.