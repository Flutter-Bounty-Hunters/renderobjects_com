---
title: API Reference
description: Reference documentation for the key methods you override when building a custom render object.
layout: api
---

Every custom render object overrides a small, well-defined set of methods. This reference documents each one — what it's for, what the framework expects from your implementation, and what you must not do inside it.

## In this section

- [performLayout()](/api/perform-layout) — Sizing this render object and positioning its children.
- [paint()](/api/paint) — Drawing to the canvas at the given offset.
- [hitTest()](/api/hit-test) — Determining whether a pointer event falls within this render object.
