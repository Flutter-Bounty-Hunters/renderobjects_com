---
title: Global Key Reparenting
description: Reparent children with Global Keys within a custom Element.
layout: guides
order: 30
---
# Implementing Global Key Reparenting in a Custom Flutter Element

Global key reparenting is the mechanism that lets a widget with a `GlobalKey` move between parents in the tree while preserving its element, its state, and its render object. For most custom elements, the framework's defaults handle this correctly — you don't write any special code for it.

This guide is targeted at the specific case where the defaults aren't enough: when you've written a custom `RenderObjectElement` with custom child storage. We'll cover what global key reparenting requires from your element, the minimum amount of code needed, and the common ways to get it wrong.

## What Global Key Reparenting Actually Requires

When a widget with a `GlobalKey` moves to a new parent, the framework needs to:

1. Find the existing element associated with the global key.
2. Detach it from its old parent without tearing down its state.
3. Attach it to its new parent.
4. Move its render object accordingly.

The framework does steps 1, 3, and 4 itself. What it needs from the old parent is a single thing: **stop tracking this child as one of yours, but don't deactivate it.** That's what `forgetChild` is for.

Deactivation would tear down the very state that global key reparenting is meant to preserve. The framework needs a way to say "remove this child from your bookkeeping" without triggering the normal removal lifecycle. `forgetChild` is that way.

## When You Don't Need to Do Anything

If your custom element extends `SingleChildRenderObjectElement`, `SlottedRenderObjectElement`, or `MultiChildRenderObjectElement`, you don't need to implement anything. The framework's base classes already implement `forgetChild` correctly for their respective child storage models.

You only need to handle global key reparenting yourself when you've written a custom `RenderObjectElement` directly — typically for structured children or virtualized children, where the framework's base classes don't apply.

## The Minimum Implementation

You need three things working together:

1. **A set tracking which children have been forgotten** so you can skip them in tree walks and during reconciliation.
2. **A `forgetChild` override** that adds the forgotten child to that set.
3. **A `visitChildren` implementation** that skips forgotten children.

The set must be cleared after each reconciliation so forgotten entries don't accumulate. Here's the complete pattern:

```dart
final Set<Element> _forgottenChildren = <Element>{};

@override
void forgetChild(Element child) {
  assert(_children.containsValue(child));
  _forgottenChildren.add(child);
  super.forgetChild(child);
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
void update(MyWidget newWidget) {
  super.update(newWidget);
  // ... your reconciliation logic, which must skip forgotten children
  _forgottenChildren.clear();
}
```

The pattern works for any storage layout. Replace `_children` with whatever your element actually uses — a map, multiple lists, a custom data structure. What matters is that `visitChildren` skips forgotten children, your reconciliation logic doesn't try to process them, and the set is cleared once per update pass.

## What the Framework Does With This

When a global key widget moves:

1. The framework looks up the existing element by global key.
2. The framework calls `forgetChild` on the old parent, passing the moving element. Your `forgetChild` records the child in `_forgottenChildren`. The child is no longer "yours" from the framework's perspective.
3. The framework moves the element to the new parent. Its state and render object are preserved throughout — neither was deactivated.
4. The framework triggers `removeRenderObjectChild` on the old parent and `insertRenderObjectChild` on the new parent. Your existing implementations of these handle the render-tree mutation.
5. The next time your element's `update` runs, your reconciliation logic skips the forgotten child (it's still in your storage map, but it's in the forgotten set, so reconciliation ignores it). After reconciliation, you clear the set and remove the child from storage.

The key insight is that `forgetChild` doesn't actually remove the child from your storage — it just marks it for skipping. The actual storage cleanup happens during the next reconciliation pass, when you process the forgotten set. This is intentional: between the moment `forgetChild` is called and the moment your element next runs `update`, the framework may need to walk children for various reasons (debug operations, layout dependencies, etc.), and your storage needs to remain in a consistent state.

## Render-Tree Side

You don't need any special render-tree code for global key reparenting. The standard render-object child management methods — `adoptChild` and `dropChild`, or `ContainerRenderObjectMixin.insert` / `remove` — handle the render-tree handoff correctly when called by `removeRenderObjectChild` and `insertRenderObjectChild`.

The one thing to be careful of is `setupParentData`. When a child render object is adopted by a new parent, `setupParentData` is called. The conventional implementation uses an `is!` check to avoid replacing existing parent data unnecessarily:

```dart
@override
void setupParentData(RenderBox child) {
  if (child.parentData is! MyParentData) {
    child.parentData = MyParentData();
  }
}
```

This matters for global key reparenting because the moving child arrives with parent data that was set by its previous parent. If both parents use the same parent data type, the check prevents the framework from discarding values that may have been set by a `ParentDataWidget` and not yet replaced. If the types differ, the check correctly replaces the parent data.

## Common Pitfalls

**Forgetting to clear `_forgottenChildren` after `update`.** If the set isn't cleared, forgotten entries accumulate across updates. The corresponding elements will be skipped in `visitChildren` indefinitely, even after they've been removed from your storage. Always clear the set at the end of your reconciliation pass.

**Removing the forgotten child from storage in `forgetChild` directly.** This breaks the framework's expectation that children are still findable during the period between `forgetChild` and your element's next `update`. Mark them with the set; clean up storage during reconciliation.

**Not skipping forgotten children in your reconciliation logic.** If `update` runs and naively iterates over your storage including forgotten children, it will try to reconcile them — which means either replacing them (defeating the reparenting) or producing incorrect render-tree operations. Filter against `_forgottenChildren` everywhere your reconciliation reads from storage.

**Calling `deactivateChild` from inside `forgetChild`.** That tears down the state that global key reparenting is supposed to preserve. The framework will handle reattachment without deactivation; your job is to step back and let it happen.

**Skipping the `super.forgetChild(child)` call.** The base class does necessary bookkeeping. Always call super.

**Implementing `forgetChild` but not `visitChildren`.** They're a matched pair. `forgetChild` marks; `visitChildren` skips. If `visitChildren` doesn't filter against the forgotten set, the framework will walk to the forgotten child from its old parent during operations like deactivation, which will tear down the state you're trying to preserve.

That's all of it. Three methods that cooperate — `forgetChild`, `visitChildren`, and your reconciliation in `update` — plus a single `Set<Element>` to coordinate between them. The framework handles everything else: finding the element by global key, moving it to the new parent, preserving its render object, and triggering the render-tree mutations.