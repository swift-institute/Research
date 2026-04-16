# Architecture

@Metadata {
    @TitleHeading("Swift Institute")
}

The organizational and architectural model of the Swift Institute ecosystem — why it looks the way it does, and how the parts fit together.

## Overview

The Swift Institute is a layered Swift package ecosystem. Three design decisions shape the architecture:

1. **Separate what cannot change from what must evolve.** A coordinate type is a mathematical concept — it should be stable for decades. An HTTP server composes OS syscalls and evolves with platform support. Bundling them forces everything to move at the speed of the most volatile piece.

2. **Dependencies flow one way.** Each layer depends only on layers below it. Circular dependencies are prohibited. This enables independent testing, incremental adoption, and clear reasoning about change impact.

3. **Layering enables flexible licensing.** Permissive licensing for foundational substrate where value comes from ubiquity; different licensing profiles are possible at higher layers where policy and opinion accumulate.

---

## The three active layers

Three layers carry released packages as of this alpha:

### Primitives

Irreducible, policy-free substrate. Types that standards require but do not define — algebra, geometry, memory, collections, concurrency, parsing, time, and kernel abstractions. Minimal surface area, no defaults, designed to be timeless.

Released at the [swift-primitives](https://github.com/swift-primitives) organization. See <doc:Swift-Primitives> for details.

### Standards

Faithful implementations of external normative specifications (RFCs, ISO standards, protocol formats, file formats), plus domain-concept packages that converge and stabilize them. Semantics are dictated externally; correctness is defined by conformance.

Standards span multiple organizations — one per authority body plus one aggregator for cross-body and convergence packages. See <doc:Swift-Standards> for details.

### Foundations

Composed building blocks from primitives and standards. Reusable across domains, infrastructure-level, minimal defaults.

Released at the [swift-foundations](https://github.com/swift-foundations) organization. See <doc:Swift-Foundations> for details.

---

## The full five-layer design

The architecture supports two additional layers that are not yet released:

- **Components** (planned) — Reusable, opinionated assemblies built on foundations. Defaults are present, trade-offs are encoded.
- **Applications** (planned) — End-user systems and domain workflows.

```
┌─────────────────────────────────────────────────┐
│  Applications                                   │   planned
│  End-user products                              │
└─────────────────────────────────────────────────┘
                        ↑
┌─────────────────────────────────────────────────┐
│  Components                                     │   planned
│  Opinionated assemblies                         │
└─────────────────────────────────────────────────┘
                        ↑
┌─────────────────────────────────────────────────┐
│  Foundations                                    │   released
│  Composed building blocks                       │
└─────────────────────────────────────────────────┘
                        ↑
┌─────────────────────────────────────────────────┐
│  Standards                                      │   released
│  Specification implementations                  │
└─────────────────────────────────────────────────┘
                        ↑
┌─────────────────────────────────────────────────┐
│  Primitives                                     │   released
│  Atomic building blocks                         │
└─────────────────────────────────────────────────┘
```

| Layer | Question answered | Policy content |
|-------|-------------------|----------------|
| Primitives | What must exist? | None |
| Standards | What is specified externally? | None (externally dictated) |
| Foundations | What can be composed safely? | Minimal |
| Components | What is reusable with defaults? | Moderate |
| Applications | What is an end-user system? | High |

Every repository is a standalone Swift package with its own version history, release tags, and `Package.swift`. Consumers depend on individual packages directly — a `.package(url: ...)` entry per dependency — rather than on an umbrella import. The superrepos (`swift-primitives`, `swift-standards`, `swift-foundations`) are git submodule aggregators that exist for browsing, not for consumption.

---

## Organizations

The ecosystem comprises multiple GitHub organizations. Each organization has a specific purpose; membership signals layer and authority at a glance.

| Organization | Purpose | Repository pattern |
|--------------|---------|-------------------|
| [swift-primitives](https://github.com/swift-primitives) | Primitives layer | `swift-{concept}-primitives` |
| [swift-ietf](https://github.com/swift-ietf) | IETF RFC implementations | `swift-rfc-{number}` |
| [swift-iso](https://github.com/swift-iso) | ISO standard implementations | `swift-iso-{number}` |
| [swift-w3c](https://github.com/swift-w3c) | W3C specification implementations | `swift-w3c-{name}` |
| [swift-whatwg](https://github.com/swift-whatwg) | WHATWG specification implementations | `swift-whatwg-{name}` |
| Additional per-authority organizations | Other standards bodies | Per-authority |
| [swift-standards](https://github.com/swift-standards) | Standards convergence + cross-body concepts | `swift-{concept}-standard` |
| [swift-foundations](https://github.com/swift-foundations) | Foundations layer | `swift-*` (clean names) |
| [swift-institute](https://github.com/swift-institute) | Documentation home | Not a package publisher |

The `swift-institute` organization itself is the documentation home, not a package publisher. This separation between identity and packaging delivers clear layer boundaries and independent versioning.

### Per-domain layering

A single domain concept may span up to four tiers across the architecture:

```
swift-foundations/swift-{concept}              Layer 3   Ecosystem integration
         ↑
swift-standards/swift-{concept}-standard       Layer 2   Convergence + stability
         ↑
swift-{body}/swift-{spec-id}                   Layer 2   Spec implementation
         ↑
swift-primitives/swift-{concept}-primitives    Layer 1   Primitive concept
```

Not every domain has all four tiers. The stable-vs-volatile separation is central: spec implementations and `-standard` packages rarely change, since specifications are stable documents. Foundations packages change more frequently as ecosystem integrations evolve.

---

## Licensing

Layering gives licensing flexibility. Lower layers — primitives and standards — are the substrate that everything else depends on; they benefit from maximum embeddability and are permissively licensed. Higher layers introduce policy and opinion, and can carry different terms where that is useful.

The practical effect: infrastructure that deserves to be ubiquitous stays ubiquitous, while the surfaces where policy accumulates have room to evolve differently.

Every repository carries its own `LICENSE.md` file.
