# swift-institute Insights

<!--
---
title: swift-institute Insights
version: 1.0.0
last_updated: 2026-03-31
applies_to: [swift-institute]
normative: false
---
-->

Design decisions, implementation patterns, and lessons learned specific to this package.

## Overview

This document captures insights that emerged during development of swift-institute.
These are not API requirements — they are recorded decisions and patterns that inform
future work on this package.

**Document type**: Non-normative (recorded decisions, not requirements).

**Consolidation source**: Reflection entries tagged with `[package: swift-institute]`.

---

## Glacier-Style Persistent Regression Corpus (2026-03-31)

**Date**: 2026-03-31

**Context**: The issue-investigation literature study identified Rust's `rust-lang/glacier` as a model for persistent regression tracking — a directory of minimal reproducers for known compiler bugs, run against each new toolchain to detect fixes and regressions automatically.

Consider creating a similar directory in swift-institute containing one `.swift` file per known compiler bug (with the swiftlang/swift issue number). Run against each new dev toolchain to (a) detect when workarounds can be removed (regression now passes), and (b) detect when a previously-fixed bug regresses.

Current candidates: #85743 (CopyPropagation ~Copyable enum), #88022 (CopyPropagation ~Escapable mark_dependence), DeinitDevirtualizer ICE on value-generic deinit.

**Applies to**: swift-institute tooling, CI pipeline
