---
title: Swift 6.4-dev Compatibility Catalog
status: IN_PROGRESS
date: 2026-03-22
tier: 2
packages:
  - swift-primitives (superrepo)
provenance:
  - 2026-03-22-rawlayout-deinit-compiler-fix.md
  - 2026-03-22-swift-64-dev-compatibility-and-dual-compiler-discovery.md
---

# Swift 6.4-dev Compatibility Catalog

## Context

Multiple sessions have identified individual 6.4-dev compatibility issues in swift-primitives. These need systematic cataloguing rather than one-at-a-time fixing. Known categories: (1) `@_lifetime` on Escapable return types rejected, (2) static property resolution in protocol extensions changed, (3) `{ $0 }` identity closure IRGen crashes, (4) `@_lifetime` version skew for ~Escapable self methods, (5) DeinitDevirtualizer SIL assertion.

## Question

What is the full set of 6.4-dev compatibility changes needed for swift-primitives? Can they be categorized by fix type (removal, replacement, conditional compilation)? Which require dual-compiler compatibility and which are one-way migrations?

## Analysis

_Pending systematic audit._

## Outcome

_Pending._
