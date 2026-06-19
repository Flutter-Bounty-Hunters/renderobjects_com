---
title: describeSemanticsConfiguration()
description: Implement the describeSemanticsConfiguration() method in a custom Render Object.
layout: api
order: 40
---
`describeSemanticsConfiguration()` is called by the Flutter framework when building the semantics tree — the parallel tree consumed by screen readers (TalkBack, VoiceOver), accessibility services, and widget tests. Override it to declare what your render object represents and how a user can interact with it.

The method receives a `SemanticsConfiguration` object. Write to this object to describe the node's role, label, current value, and any actions the user can perform.

## Default Implementation

The default implementation does nothing. A render object that leaves the configuration untouched is invisible to the semantics tree — screen readers skip it entirely, and any semantic nodes produced by its children are merged upward into the nearest ancestor that does have semantics.

No override is needed for render objects that carry no accessibility meaning of their own.

## Label Only

Use `label` to name a non-interactive element — a custom image, an icon, or a data visualization. Always pair a label with `textDirection`.

```dart
@override
void describeSemanticsConfiguration(SemanticsConfiguration config) {
  super.describeSemanticsConfiguration(config);
  config
    ..label = 'Monthly revenue chart, ${'$_currentMonth'}'
    ..textDirection = TextDirection.ltr
    ..isImage = true;
}
```

## Tappable Element

Mark a render object as a button by setting `isButton` and providing an `onTap` handler. Screen readers announce the label and instruct the user to double-tap to activate. Set `isEnabled` so assistive technology knows whether the action is currently available.

```dart
@override
void describeSemanticsConfiguration(SemanticsConfiguration config) {
  super.describeSemanticsConfiguration(config);
  config
    ..label = 'Submit'
    ..hint = 'Submits the form'
    ..textDirection = TextDirection.ltr
    ..isButton = true
    ..isEnabled = _enabled
    ..onTap = _enabled ? _handleTap : null;
}
```

## Value and Range

Sliders, progress indicators, and other value-bearing elements expose their current state as a human-readable string via `value`. Provide `onIncrease` and `onDecrease` handlers so assistive technology can offer a seek control.

```dart
@override
void describeSemanticsConfiguration(SemanticsConfiguration config) {
  super.describeSemanticsConfiguration(config);
  config
    ..label = 'Volume'
    ..value = '${(_volume * 100).round()}%'
    ..textDirection = TextDirection.ltr
    ..onIncrease = () => _setVolume((_volume + 0.1).clamp(0.0, 1.0))
    ..onDecrease = () => _setVolume((_volume - 0.1).clamp(0.0, 1.0));
}
```

## Checked State

Checkboxes, radio buttons, and toggle switches expose a boolean state through `isChecked`. Pair it with a tap handler so the user can toggle the value.

```dart
@override
void describeSemanticsConfiguration(SemanticsConfiguration config) {
  super.describeSemanticsConfiguration(config);
  config
    ..label = 'Receive notifications'
    ..textDirection = TextDirection.ltr
    ..isEnabled = true
    ..isChecked = _isChecked
    ..onTap = _handleToggle;
}
```

## Excluding a Subtree from Semantics

Purely decorative render objects — animated backgrounds, shimmer effects, visual noise — can opt their entire subtree out of the semantics tree. This prevents screen readers from announcing meaningless content and keeps the semantics tree lean.

```dart
@override
void describeSemanticsConfiguration(SemanticsConfiguration config) {
  super.describeSemanticsConfiguration(config);
  config.isSemanticBoundary = true;
  config.explicitChildNodes = false;
  // Do not set a label or any actions — the node exists only to
  // block descendants from appearing in the semantics tree.
}
```

Alternatively, override `excludeFromSemantics` directly on the render object when no configuration is needed at all:

```dart
@override
bool get excludeFromSemantics => true;
```
