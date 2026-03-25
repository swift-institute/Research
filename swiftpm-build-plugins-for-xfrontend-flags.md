---
title: SwiftPM Build Plugins for -Xfrontend Flags
status: IN_PROGRESS
date: 2026-03-22
tier: 2
packages:
  - swift-buffer-primitives
  - swift-storage-primitives
provenance: 2026-03-21-rawlayout-experiment-consolidation-and-workaround-exhaustion.md
---

# SwiftPM Build Plugins for -Xfrontend Flags

## Context

Several experimental Swift features (e.g., `Lifetimes`, `RawLayout`) require `-Xfrontend -enable-experimental-feature` flags. Currently these are passed via `.unsafeFlags()` in Package.swift, which disables SPM dependency resolution for downstream consumers. This blocks adoption of packages using experimental features.

## Question

Can SwiftPM build plugins inject `-Xfrontend` flags without requiring `.unsafeFlags`? If so, what is the plugin API and what are the limitations (e.g., sandbox restrictions, platform support, CI compatibility)?

## Analysis

_Pending investigation._

## Outcome

_Pending._
