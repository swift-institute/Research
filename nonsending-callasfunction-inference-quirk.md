---
title: nonisolated(nonsending) callAsFunction Inference Quirk
status: IN_PROGRESS
date: 2026-03-22
tier: 1
packages:
  - swift-async-primitives
provenance: 2026-03-22-nonsending-compiler-discovery-and-ecosystem-migration.md
---

# nonisolated(nonsending) callAsFunction Inference Quirk

## Context

When `callAsFunction` is annotated with `nonisolated(nonsending)`, using sugar syntax `let result = await callback()` causes the compiler to infer `result` as `() -> Value` (the method reference) rather than `Value`. Using explicit `.callAsFunction()` or a type annotation resolves it. Runtime behavior is correct in both cases.

## Question

Does this inference quirk affect production usage, or is it only visible in type reflection and string interpolation warnings? Should it be reported as a compiler bug?

## Analysis

_Pending investigation of production call sites._

## Outcome

_Pending._
