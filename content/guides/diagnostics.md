---
title: Diagnostics
description: Implement debug diagnostics for Render Objects
layout: guides
order: 50
---
# Implementing Diagnostics and Debugging in a Custom Flutter Render Object

This guide walks experienced Flutter developers through the diagnostics responsibilities of a custom `RenderObject`. By the end, you'll understand how Flutter's debugging infrastructure works, what your render object needs to do to plug into it, and why making the effort to do so pays off many times over. We'll skip layout, painting, compositing, hit testing, lifecycle, and semantics — this is about diagnostics, and only diagnostics.

## What This Guide Covers

- **Why Diagnostics Aren't Optional** — The real cost of skipping diagnostic support, and the cases where it bites you.
- **What Diagnostics Actually Is** — The shared infrastructure that powers DevTools, `toStringDeep`, error messages, and the widget inspector.
- **`debugFillProperties`** — The single method that exposes your render object's state to all of the above.
- **Choosing the Right `DiagnosticsProperty`** — Picking the correct property type so values display well.
- **Defaults, Hidden Values, and Levels** — Controlling what shows up by default and what only appears on demand.
- **Describing Children** — Letting tree-walking output understand your render object's structure.
- **`toStringShort`** — The one-line summary used in compact contexts.
- **Debug-Only Invariants With `assert`** — Catching contract violations early without paying for them in release builds.
- **Debug-Only State for Reproduction** — Tracking extra information in debug mode to make bugs reproducible.
- **Common Pitfalls** — The traps that make diagnostic support less useful than it should be.

## Why Diagnostics Aren't Optional

It's tempting to treat diagnostics as polish — something to add once the "real" functionality works, or maybe never, because none of it affects what the user sees. That instinct is wrong, and it's worth being explicit about why before getting into the API.

A custom render object without diagnostics support is a render object you can't debug. When something goes wrong — a layout that produces the wrong size, a paint pass that draws nothing, a hit test that misses — the tools you reach for first are all built on the same diagnostics infrastructure:

- **The Flutter widget inspector** in DevTools shows you a tree view of your render objects with their properties. Without diagnostic properties, your render object appears as just a class name with no useful information. Selecting it in the inspector tells you nothing about why it's behaving the way it is.
- **`debugDumpRenderTree()`** prints the entire render tree to the console with each render object's state inline. It's the fastest way to ask "what does the framework actually think this tree looks like right now?" Without diagnostics, your render object contributes a one-line type name to the dump and nothing else.
- **Framework error messages** include the relevant render object's `toStringDeep` output as context. A layout assertion failure points at your render object and tells you... almost nothing, because there's nothing to print.
- **`toString` and `toStringShort`** are used everywhere — in logs, in test failure messages, in IDE debugger inspectors, in your own `print` statements when you're trying to figure out what's going on. The default `Object.toString` gives you the class name and a hash code; usable for identity, useless for debugging.

The cost of adding diagnostic support is small: one method override, a few `DiagnosticsProperty` lines, maybe a `toStringShort` override. The cost of *not* adding it compounds every time you or someone using your render object has to debug a problem. You'll spend ten minutes inserting `print` statements to discover information you could have read in DevTools in two seconds. You'll watch test failures fly by with error messages that don't identify what was wrong with the object. You'll get bug reports that you can't reproduce because the report has no useful state in it.

There's also a robustness dimension. Debug-only `assert` statements that check your render object's invariants catch contract violations at the moment they happen, with a clear error message, instead of letting them propagate into a silent rendering glitch or a confusing crash five frames later. These checks cost nothing in release builds — Dart strips them entirely — so there's no performance argument for skipping them.

The shortest version of the case is this: every hour spent making your render object debuggable saves five hours of debugging it later. And that math gets dramatically worse if other developers — colleagues, library users — ever need to debug it without your help.

The rest of this guide is the mechanics.

## What Diagnostics Actually Is

Diagnostics is the shared infrastructure Flutter uses to introspect objects for human consumption — populating DevTools, formatting error messages, producing tree dumps, and answering "what does this thing currently look like?" anywhere a developer needs to know.

The core abstraction is `Diagnosticable`, which `RenderObject` extends. A diagnosticable object can describe itself via a structured list of named properties (color, value, size, isEnabled, and so on) and a list of children. The framework walks these structures to produce whatever output a given consumer needs — a flat property list for DevTools, an indented tree for the console, a single-line summary for an error context.

You participate by overriding `debugFillProperties`, which adds entries to a `DiagnosticPropertiesBuilder`. Everything downstream — `toString`, `toStringShallow`, `toStringDeep`, the inspector, error reporters — derives from that single method. Override it well and your render object becomes legible everywhere. Skip it and your render object is opaque everywhere.

To make this concrete, here's what `debugDumpRenderTree()` produces for a small tree where the custom render object hasn't implemented any diagnostics. Notice how little information `RenderCustomBadge` contributes compared to its framework-provided neighbors:

```
RenderView#a4f21
 │ debug mode enabled - macos
 │ view size: Size(1280.0, 800.0) (in physical pixels)
 │ device pixel ratio: 2.0 (physical pixels per logical pixel)
 │ configuration: BoxConstraints(w=640.0, h=400.0) at 2.0x (in logical pixels)
 │
 └─child: RenderPadding#b9c33
   │ parentData: <none>
   │ constraints: BoxConstraints(w=640.0, h=400.0)
   │ size: Size(640.0, 400.0)
   │ padding: EdgeInsets.all(16.0)
   │
   └─child: RenderCustomBadge#7d8e2
       parentData: offset=Offset(16.0, 16.0)
       constraints: BoxConstraints(w=608.0, h=368.0)
       size: Size(120.0, 32.0)
```

`RenderCustomBadge` shows up, but you can't tell what label it has, what color it is, whether it's enabled, or anything else about its actual state. The rest of this guide is about changing that.

## `debugFillProperties`

`debugFillProperties(DiagnosticPropertiesBuilder properties)` is the override where you declare what state your render object has and how each piece of state should be displayed.

The pattern is consistent: call `super`, then add a `DiagnosticsProperty` (or one of its specialized subclasses) for each piece of state worth exposing.

```dart
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  super.debugFillProperties(properties);
  properties.add(DoubleProperty('spacing', _spacing));
  properties.add(EnumProperty<Axis>('direction', _direction));
  properties.add(DiagnosticsProperty<Color>('color', _color));
  properties.add(FlagProperty(
    'enabled',
    value: _enabled,
    ifFalse: 'disabled',
  ));
}
```

With those four lines added, the same `debugDumpRenderTree()` output now reveals what's actually going on:

```
└─child: RenderCustomBadge#7d8e2
    parentData: offset=Offset(16.0, 16.0)
    constraints: BoxConstraints(w=608.0, h=368.0)
    size: Size(120.0, 32.0)
    spacing: 8.0
    direction: horizontal
    color: Color(0xff336699)
    disabled
```

Each property added to the builder appears as its own line in the dump, indented under the render object that produced it. Notice that `enabled` is rendered as the single word `disabled` because we used `FlagProperty` with `ifFalse`; we'll cover those choices shortly.

Always call `super.debugFillProperties` first. The base `RenderObject` (and any intermediate classes like `RenderBox`) contributes its own properties — things like size, constraints, and whether the object is currently attached. Skipping `super` discards all of that, which means your custom render object's diagnostic output ends up *less* informative than the default.

Keep `debugFillProperties` cheap. It's called whenever something asks for the object's diagnostic representation, which can be in hot paths in DevTools or during repeated test failures. Avoid expensive computation or large allocations.

## Choosing the Right `DiagnosticsProperty`

`DiagnosticsProperty` has many specialized subclasses, and using the right one means your values display sensibly in every consumer.

A non-exhaustive but practical list:

- **`StringProperty`** — Strings. Has options for quoting and showing/hiding empty values.
- **`IntProperty`, `DoubleProperty`** — Numbers. `DoubleProperty` formats reasonably (no infinite trailing zeros) and accepts a unit string for things like degrees or pixels.
- **`PercentProperty`** — A double in the 0.0–1.0 range, formatted as a percentage.
- **`EnumProperty<T>`** — Enum values. Displays just the enum case name (e.g., `Axis.horizontal`) rather than the full type-qualified form, which is what you almost always want.
- **`FlagProperty`** — Booleans, but with the option to display only when one of true/false is "interesting." For a flag that's almost always true, you can have it appear in output only when it's false.
- **`IterableProperty<T>`** — Collections. Renders as a comma-separated list with reasonable truncation.
- **`ColorProperty`** — Colors, displayed in human-readable form.
- **`IconDataProperty`** — Icons.
- **`TransformProperty`** — `Matrix4` instances, formatted as a multi-line transform matrix rather than a wall of opaque numbers.
- **`DiagnosticsProperty<T>`** — The generic catch-all for anything not covered by a specialized type.

The specialized types matter because they produce output that's actually readable. Compare these two versions of the same render object's properties — first using only the generic type:

```
└─child: RenderCustomBadge#7d8e2
    spacing: 8.0
    direction: Axis.horizontal
    color: Color(0xff336699)
    enabled: false
    progress: 0.75
    transform: [1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,20.0,0.0,0.0,1.0]
```

And now using the specialized types (`EnumProperty`, `ColorProperty`, `FlagProperty`, `PercentProperty`, `TransformProperty`):

```
└─child: RenderCustomBadge#7d8e2
    spacing: 8.0
    direction: horizontal
    color: Color(0xff336699)
    disabled
    progress: 75.0%
    transform:
      [0] 1.0,0.0,0.0,0.0
      [1] 0.0,1.0,0.0,0.0
      [2] 0.0,0.0,1.0,0.0
      [3] 20.0,0.0,0.0,1.0
```

Same data; dramatically different scannability. The transform alone is the difference between unreadable and obvious.

## Defaults, Hidden Values, and Levels

Several `DiagnosticsProperty` constructors take a `defaultValue` parameter, and using it well makes diagnostic output much more useful.

When a property's current value equals its `defaultValue`, that property is hidden from the default output. This sounds minor, but in practice it's the difference between a property list that shows you what's *interesting* and one that drowns you in noise. A render object with twenty properties, eighteen of which are at their defaults, should display two interesting properties — not all twenty.

```dart
properties.add(DoubleProperty('spacing', _spacing, defaultValue: 0.0));
properties.add(EnumProperty<Axis>('direction', _direction, defaultValue: Axis.horizontal));
properties.add(DiagnosticsProperty<Color>('color', _color, defaultValue: const Color(0xff000000)));
properties.add(PercentProperty('progress', _progress, defaultValue: 1.0));
```

When everything is at its default value, the dump shrinks to nothing but the framework-provided properties:

```
└─child: RenderCustomBadge#7d8e2
    parentData: offset=Offset(16.0, 16.0)
    constraints: BoxConstraints(w=608.0, h=368.0)
    size: Size(120.0, 32.0)
```

When something interesting changes — say, `spacing` is bumped to `8.0` and `progress` drops to `0.4` — only the non-default values appear, drawing your eye exactly where it should go:

```
└─child: RenderCustomBadge#7d8e2
    parentData: offset=Offset(16.0, 16.0)
    constraints: BoxConstraints(w=608.0, h=368.0)
    size: Size(120.0, 32.0)
    spacing: 8.0
    progress: 40.0%
```

You can also control verbosity with `level`:

- `DiagnosticLevel.info` is the default for normal properties.
- `DiagnosticLevel.fine` suppresses the property from default output but includes it in verbose dumps. Useful for properties that are technically state but rarely interesting.
- `DiagnosticLevel.hidden` is even more aggressive.
- `DiagnosticLevel.warning` flags the property as noteworthy.
- `DiagnosticLevel.error` flags it as a problem.

You rarely need the warning/error levels in your own properties, but they're how the framework surfaces things like "this render object was never laid out" in red, alarming output — which is also why a stuck render object often produces a dump like this:

```
└─child: RenderCustomBadge#7d8e2 NEEDS-LAYOUT NEEDS-PAINT
    parentData: offset=Offset(16.0, 16.0)
    constraints: MISSING
    size: MISSING
```

The capitalized warnings come from properties set at `DiagnosticLevel.warning` by the base class.

## Describing Children

For render objects with children, you need to make those children discoverable through the diagnostics system — otherwise tree dumps and the inspector show your render object as a leaf, even though it has descendants.

The method to override is `debugDescribeChildren`, which returns a list of `DiagnosticsNode` entries:

```dart
@override
List<DiagnosticsNode> debugDescribeChildren() {
  final children = <DiagnosticsNode>[];
  RenderBox? child = firstChild;
  int index = 0;
  while (child != null) {
    children.add(child.toDiagnosticsNode(name: 'child ${index++}'));
    child = childAfter(child);
  }
  return children;
}
```

Without this override (and without one of the standard child mixins providing it for you), a multi-child render object's tree dump looks misleadingly flat:

```
└─child: RenderCustomLayout#3f481
    parentData: offset=Offset(0.0, 0.0)
    constraints: BoxConstraints(w=400.0, h=600.0)
    size: Size(400.0, 600.0)
```

With the override above, the same tree dump shows the structure correctly, with each child labeled by its index:

```
└─child: RenderCustomLayout#3f481
  │ parentData: offset=Offset(0.0, 0.0)
  │ constraints: BoxConstraints(w=400.0, h=600.0)
  │ size: Size(400.0, 600.0)
  │
  ├─child 0: RenderParagraph#a1b2c
  │   parentData: offset=Offset(0.0, 0.0)
  │   constraints: BoxConstraints(w=400.0, 0.0<=h<=Infinity)
  │   size: Size(400.0, 24.0)
  │
  ├─child 1: RenderImage#d4e5f
  │   parentData: offset=Offset(0.0, 24.0)
  │   ...
  │
  └─child 2: RenderCustomBadge#7d8e2
      parentData: offset=Offset(0.0, 200.0)
      ...
```

The label you pass via `name:` shows up in the tree output as the prefix on each line. A render object with named slots is more useful with descriptive labels — `'header'` and `'body'` rather than `'child 0'` and `'child 1'`:

```
└─child: RenderHeaderBody#3f481
  │ size: Size(400.0, 600.0)
  │
  ├─header: RenderParagraph#a1b2c
  │   size: Size(400.0, 48.0)
  │
  └─body: RenderColumn#d4e5f
      size: Size(400.0, 552.0)
```

If you're using `ContainerRenderObjectMixin`, the `RenderBoxContainerDefaultsMixin` provides a default implementation that does the numeric-labeling version for you. For single-child render objects using `RenderObjectWithChildMixin`, the default also handles it. You only need to override `debugDescribeChildren` manually if you have a non-standard child structure (named slots, separate child collections) or want to customize the labeling.

## `toStringShort`

`toStringShort` is the one-line summary used in compact diagnostic contexts — error message references, list-style outputs, places where the full property dump would be overkill.

The default is your class name with a hash suffix, which produces output like this in an error message:

```
The following assertion was thrown during layout:
RenderCustomBadge#7d8e2 was given infinite width.
```

That tells you the type but doesn't help you distinguish this badge from any other on screen. Overriding `toStringShort` to include a distinguishing field makes errors much easier to scan:

```dart
@override
String toStringShort() {
  return '${objectRuntimeType(this, 'RenderCustomBadge')}(label: "$_label")';
}
```

The same error becomes:

```
The following assertion was thrown during layout:
RenderCustomBadge(label: "New") was given infinite width.
```

`objectRuntimeType` is a small helper that gives you the runtime class name in debug builds and a fallback in release. Use it instead of `runtimeType.toString()` in diagnostic contexts.

Don't go overboard. `toStringShort` appears in places where space is at a premium — half a screen of output per render object defeats the purpose. One or two distinguishing fields is the right scale.

## Debug-Only Invariants With `assert`

Diagnostic support extends beyond what's *displayed* — it also covers what's *checked*. Dart's `assert` statement runs only in debug mode (and is stripped from release builds), making it the right place for invariant checks that would be too expensive or too noisy to run in production.

A custom render object usually has invariants its callers must respect — a layout property must be positive, a paint-time precondition must hold, a child must be of a specific type. Assert those invariants:

```dart
set spacing(double value) {
  assert(value >= 0, 'spacing must be non-negative; got $value');
  if (_spacing == value) return;
  _spacing = value;
  markNeedsLayout();
}

@override
void performLayout() {
  assert(constraints.hasBoundedWidth,
      '$runtimeType requires a bounded width; received $constraints');
  // ... rest of layout
}
```

A few notes on writing useful asserts. **Include the offending value in the message.** "spacing must be non-negative" tells you the rule was violated; "spacing must be non-negative; got -3.0" tells you what the violation actually was. **Reference the render object in messages where it adds context** — `'$runtimeType requires...'` is more useful than a bare statement when the assert fires from somewhere far up the stack. **Don't assert preconditions that can legitimately be false during normal use** — an assert is for genuine bugs, not for cases that should produce ordinary error handling.

Asserts also document. A well-asserted render object communicates its contract through its checks: anyone reading the code can see what assumptions the implementation makes and what callers are expected to respect. This is documentation that can't go stale, because if it did, the asserts would fire.

## Debug-Only State for Reproduction

Sometimes the information needed to debug a problem isn't part of the render object's normal state — it's something transient, like "what constraints did I receive last time I was laid out?" or "when was the last frame I painted?" You can track this state in debug mode only, using fields gated by `kDebugMode` or `assert`:

```dart
BoxConstraints? _debugLastConstraints;

@override
void performLayout() {
  assert(() {
    _debugLastConstraints = constraints;
    return true;
  }());
  // ... rest of layout
}

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  super.debugFillProperties(properties);
  properties.add(DiagnosticsProperty<BoxConstraints>(
    'last constraints',
    _debugLastConstraints,
    defaultValue: null,
  ));
}
```

In a tree dump, this appears alongside the other properties, but only in debug builds:

```
└─child: RenderCustomBadge#7d8e2
    parentData: offset=Offset(16.0, 16.0)
    constraints: BoxConstraints(w=608.0, h=368.0)
    size: Size(120.0, 32.0)
    spacing: 8.0
    last constraints: BoxConstraints(w=608.0, h=368.0)
```

When the bug is "this widget was sized correctly on the first frame but wrong on the second," `last constraints` answering with a value that differs from the current `constraints` is often enough to diagnose the issue immediately.

The `assert(() { ...; return true; }())` idiom is the standard way to run arbitrary debug-only code. The assert expression is stripped in release builds, taking the entire closure and its side effects with it — so `_debugLastConstraints` stays `null` in production and the diagnostic property, having a `null` default value, contributes nothing to the output.

This is how the framework's own render objects expose information like "is this object dirty for layout?" and "what did this look like during its last paint?" — state that's wildly useful for debugging but has no place in release-mode memory footprint.

## Common Pitfalls

A few patterns that come up repeatedly:

**Forgetting `super.debugFillProperties`.** The base classes contribute useful properties (size, constraints, attached state, dirty flags). Skipping super means your custom render object's diagnostic output is *less* helpful than the default would have been. Always call super.

**Using `DiagnosticsProperty<T>` for everything.** The generic type works but produces uglier output than the specialized subclasses. A `Color` displayed via `DiagnosticsProperty<Color>` shows up as something like `Color(0xff336699)`; via `ColorProperty` it shows up much more readably. Reach for the specialized type when one exists.

**Omitting `defaultValue`.** Properties without a default value always display, even when they're at their default. The result is diagnostic output cluttered with noise — every property showing, with no visual hint about which ones are interesting. Always specify `defaultValue` when there is one.

**Expensive computation in `debugFillProperties`.** It's called more often than you might think — every time DevTools refreshes, every time a tree dump runs, every time an error message is formatted. Keep it cheap; cache derived values if computing them is non-trivial.

**Asserting things that aren't actually invariants.** An assert is for "this should never happen, and if it does there's a bug." If a condition can legitimately occur during normal operation — even unusual operation — handle it explicitly, not with an assert. Asserts that fire on valid input train developers to ignore asserts in general.

**Sensitive data in diagnostics.** Diagnostic output appears in logs, error reports, and developer tools. Don't include passwords, tokens, raw user content, or other sensitive data in property lists. If your render object holds such data, expose only its presence ("has value: true") or a redacted summary in diagnostics.

**Skipping diagnostics entirely.** The single biggest pitfall. It's tempting to defer this work indefinitely because nothing visibly breaks without it. But it doesn't break — it just makes everything related to the render object harder, slower, and more frustrating. Add the override early, even if it starts minimal. Future you will be grateful.