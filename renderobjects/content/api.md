---
title: API Reference
description: Reference documentation for the key methods you override when building a custom render object.
layout: api
---

Every custom render object overrides a small, well-defined set of methods. This reference documents each one — what it's for, what the framework expects from your implementation, and what you must not do inside it.

## In this section

- [performLayout()](/api/layout/performLayout) — Sizing this render object and positioning its children.
- [performResize()](/api/layout/performResize) — Sizing from constraints alone, when `sizedByParent` is true.
- [setupParentData()](/api/layout/setupParentData) — Attaching parent data objects to children before layout.
- [paint()](/api/paint/paint) — Drawing to the canvas at the given offset.
- [paintBounds](/api/paint/paintBounds) — The region this render object may paint into.
- [hitTest()](/api/hit-testing/hittest) — Determining whether a pointer event falls within this render object.
- [describeSemanticsConfiguration()](/api/semantics/describeSemanticsConfiguration) — Declaring the accessibility role and properties of this render object.
- [debugFillProperties()](/api/debugging/debugFillProperties) — Exposing internal state to the Flutter diagnostic system.
