---
title: debugFillProperties()
description: Implement the debugFillProperties() method in a custom Render Object.
layout: api
order: 50
---
`debugFillProperties()` is called by the Flutter framework when producing a debug description of a render object — in the widget inspector, in `toString()` output, and in the diagnostics printed when an assertion fails. Override it to expose the properties that matter for understanding and debugging your render object's state.

The method receives a `DiagnosticPropertiesBuilder`. Call `properties.add(...)` once for each property you want to surface, choosing the `DiagnosticsProperty` subclass that matches the value's type.

## Default Implementation

`RenderObject` provides a default implementation that reports the render object's size and a few other base properties. Call `super.debugFillProperties(properties)` first so those base properties are included before your own.

```dart
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  super.debugFillProperties(properties);
  // Add your properties here.
}
```

## Primitive Values

For `bool`, `int`, `double`, `String`, and `Color` values, use the matching typed property class. Flutter uses the type to format the value appropriately in the inspector.

```dart
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  super.debugFillProperties(properties);
  properties.add(StringProperty('label', _label));
  properties.add(ColorProperty('color', _color));
  properties.add(DoubleProperty('strokeWidth', _strokeWidth));
  properties.add(IntProperty('itemCount', _itemCount));
  properties.add(FlagProperty('enabled', value: _enabled, ifTrue: 'enabled', ifFalse: 'disabled'));
}
```

## Enums and Arbitrary Objects

Use `EnumProperty` for enum values and `DiagnosticsProperty<T>` for any other type.

```dart
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  super.debugFillProperties(properties);
  properties.add(EnumProperty<Axis>('direction', _direction));
  properties.add(DiagnosticsProperty<EdgeInsets>('padding', _padding));
  properties.add(DiagnosticsProperty<BorderRadius>('borderRadius', _borderRadius));
}
```

## Iterables

Use `IterableProperty` to surface lists and sets. Each element is printed on its own line in the inspector.

```dart
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  super.debugFillProperties(properties);
  properties.add(IterableProperty<String>('labels', _labels));
}
```

## Conditional and Null Properties

Properties that are only meaningful in certain states can be hidden when they don't apply. Pass `defaultValue` to suppress the property when it matches the uninteresting case, or `level` to reduce its visibility.

```dart
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  super.debugFillProperties(properties);
  // Hidden when null — only shown in the inspector when a color is set.
  properties.add(ColorProperty('highlightColor', _highlightColor, defaultValue: null));

  // Hidden when false — only shown when the render object is in an error state.
  properties.add(FlagProperty(
    'hasError',
    value: _hasError,
    ifTrue: 'ERROR',
    level: _hasError ? DiagnosticLevel.warning : DiagnosticLevel.hidden,
  ));
}
```
