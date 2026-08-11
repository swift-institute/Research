# Canonical-Tier Rule Activation: Single-File Default Pack vs Lint/ Packages vs Configuration.defaults Factory

<!--
---
version: 1.0.0
last_updated: 2026-05-07
status: RECOMMENDATION
tier: 2
scope: cross-package
---
-->

## Context

After Phase B.1, `swift-linter`'s engine ships zero baked-in rules; rule activation
requires an explicit rule-pack binding by the consumer. The Phase A PoC
(`2026-05-07-poc-lint-nested-package.md`) introduced the `Lint/` nested-package
mechanism, which supports arbitrary rule-pack imports and per-rule activation via
a typed `Lint.Manifest`. The single-file `Lint.swift` form is preserved for
sugar-shape consumers, but in its current state it activates zero rules — the
mechanism for binding the institute-canonical default rule pack from inside a
single-file manifest has not shipped.

In parallel, the canonical Tier 1 / Tier 2 `Lint.swift` files
(`swift-institute/.github/Lint.swift`, per-org `.github/Lint.swift`) currently
declare empty rule lists. Phase 4 plans the institute-canonical rule activations,
but until they ship, consumers who inherit the canonical files via the
`// parent:` directive also see zero rules fire.

The combination — empty canonical files plus inert single-file fallback — leaves
the question open: **how should a consumer activate institute default rules
without authoring a `Lint/` nested SwiftPM package?**

## Question

What is the right shape for canonical-tier rule activation in `swift-linter`?

Three forms have been sketched in cohort discussion:

- **A.** A canonical default rule-pack module, imported by `Lint.swift` to activate
  the institute-canonical rules in a single-file manifest.
- **B.** The `Lint/` nested SwiftPM package as the canonical form; single-file
  `Lint.swift` deprecated or kept as a sugar form for narrow use cases.
- **C.** A `Lint.Manifest.defaults()` factory baked into the linter, populating
  configuration in-language.

The decision is structural: it determines how every consumer in the institute
ecosystem (and every third-party adopter) configures the linter for everyday use.

## Analysis

### Option A: Single-file `Lint.swift` + default rule-pack umbrella import

A canonical umbrella product (provisional name
`swift-linter-rules-default`) ships from `swift-foundations/swift-linter-rules`
or a sibling repo. The umbrella re-exports the institute-canonical rule set as a
single import target. Single-file `Lint.swift` activates the default set via:

```swift
// Lint.swift
import Linter
import Linter Rules Default

let manifest = Lint.Manifest(
    enabledRuleIDs: Linter.Rules.Default.allRuleIDs,
    disabledRuleIDs: ["chained_rawvalue_access"],  // per-package override
)
```

**Pros**:

- Preserves the single-file shape: no nested SwiftPM package required.
- Composable: consumers add additional rule packs by importing more umbrellas.
- Familiar to ESLint adopters (`extends: ['canonical-config']`) and SwiftLint
  adopters (`parent_config:`).

**Cons**:

- Single-file `Lint.swift` does not declare SwiftPM dependencies. The umbrella
  import implies a discovery mechanism the manifest compiler must supply
  (hardcoded rule-pack bundles? swift-manifest dep injection from a global
  registry?). The mechanism design is not yet specified.
- The "umbrella module" must be statically resolvable from a context where there
  is no `Package.swift` declaring its dep — a structural mismatch with regular
  SwiftPM module discovery.
- Mechanism complexity is hidden in the linter binary, not in the consumer's
  `Package.swift`; reasoning about activation requires reading linter
  documentation rather than the consumer's own manifest.

### Option B: `Lint/` nested package as the canonical form

The `Lint/` nested SwiftPM package becomes the canonical activation form for
every consumer. Single-file `Lint.swift` is preserved as a sugar form for
consumers who want to opt in to the canonical set without per-package
customization, but it is documented as terse-only — the form for "I accept the
defaults exactly" — not the form for everyday production use.

A scaffolding command (`swift-linter init`) generates the canonical `Lint/`
structure for new consumers, eliminating the boilerplate cost.

**Pros**:

- One canonical activation shape; the linter binary discovers rules through
  regular SwiftPM dep resolution.
- Rule-pack composition is regular SwiftPM authoring: add a dep on
  `swift-linter-rules-canonical` and the package's targets become the rule pack.
- Third-party rule pack adoption is mechanical: write a SwiftPM library that
  conforms to `Linter Primitives`, depend on it from `Lint/`.
- Aligns with how SwiftLint adopters structure config files alongside
  `.swiftlint.yml`, and with how `swift-format` consumers extend `.swift-format`
  via custom rule modules.
- Forces consumer awareness of which rule packs are active — the SwiftPM dep
  graph IS the activation manifest.

**Cons**:

- Higher onboarding overhead than single-file: "to lint your package, author a
  nested SwiftPM package." Mitigated by the scaffolding command.
- Loses the single-file form's terseness for the genuinely-default case (a
  consumer who wants every institute rule with no overrides). Mitigated by
  keeping single-file `Lint.swift` as the sugar form for that narrow case.

### Option C: `Lint.Configuration.defaults()` factory + inline registration

The linter binary exposes a static factory:

```swift
// Lint.swift
import Linter

let manifest = Lint.Manifest.defaults()
    .disabling(["chained_rawvalue_access"])
```

The factory returns a pre-populated `Lint.Manifest` with the institute-canonical
rules at default severity. Customization is in-language via fluent overrides.

**Pros**:

- Single-file shape preserved; activation is one method call.
- Type-checked at compile time (vs string-keyed YAML overrides).
- No swift-manifest dep-discovery complexity; the canonical rules ship in the
  linter binary.

**Cons**:

- Couples the linter binary to the canonical rule set. Adding, removing, or
  reweighting a rule in the canonical pack requires recompiling and shipping a
  new linter binary.
- Third-party rule packs cannot extend `Lint.Manifest.defaults()` from outside
  the linter binary; they must be added through a separate registration API,
  fragmenting the activation surface.
- Mixes the linter's *infrastructure* (engine, IO, reporters) with the
  ecosystem's *policy* (which rules are canonical at which severity). The two
  evolve on different cadences; the binary coupling collapses that distinction.
- Limits the institute's ability to ship rule-pack updates as ordinary
  semver-tagged library releases.

### Comparison

| Criterion | A (umbrella import) | B (`Lint/` canonical) | C (`defaults()` factory) |
|-----------|---------------------|------------------------|--------------------------|
| Single-file UX preserved | Yes | Sugar form only | Yes |
| Mechanism complexity | Medium (rule-pack discovery in single-file) | Low (regular SwiftPM) | Low (in-language) |
| Third-party rule pack adoption | Yes (additional umbrella imports) | Yes (additional SwiftPM deps) | Awkward (separate registration API) |
| Onboarding overhead | Low | Medium (mitigated by scaffolding) | Low |
| Linter binary coupling | Loose | Loose | Tight (canonical pack baked in) |
| Type-checked configuration | Yes | Yes | Yes |
| Default → custom override path | Add `disabledRuleIDs` | Add `Lint/` deps + `disabledRuleIDs` | `.defaults().disabling(...)` |
| Rule-pack release cadence | Independent | Independent | Coupled to linter binary |
| Fits the Phase A `Lint/` PoC | Sugar layer on top | Direct fit | Bypass — supersedes the PoC |

### Comparable patterns in adjacent tools

| Tool | Canonical-config mechanism | Sugar form | Plugin discovery |
|------|---------------------------|-----------|-----------------|
| ESLint | `extends: ['canonical']` in `.eslintrc` | Single config file | npm |
| SwiftLint | `parent_config: <url\|path>` in `.swiftlint.yml` | Single YAML file | (no plugin system) |
| swift-format | `.swift-format` JSON config | Single JSON file | (built-in only) |
| prettier | `.prettierrc` + plugins array | Single config file | npm |

The dominant pattern across surveyed tools is layered-config with a default
ruleset shipping as a separate distributable. ESLint's `extends:` is the closest
analog to Option A. None of the surveyed tools requires the consumer to author a
nested package — but none of them have Swift's type-checked-DSL advantage either,
so the comparison is illustrative, not normative. The tool whose structure is
closest to Option B is none of the above: the analog is how Apple's own
`swift-package-manager` consumers extend SwiftPM via `.swift-tools-version` +
`Package.swift` modules. SwiftPM's dep graph IS the configuration manifest;
that's the structural pattern Option B inherits.

(Comparable-pattern claims above are summarized from each tool's documentation
without per-claim subagent verification. The recommendation does not pivot on
these details — the load-bearing analysis is the structural comparison of A/B/C
in the institute's own architecture.)

## Outcome

**Status**: RECOMMENDATION

**Recommended primary form**: **Option B** — `Lint/` nested SwiftPM package as
the canonical activation form for production use, with a scaffolding command to
eliminate boilerplate. The Phase A PoC validates the mechanism; Phase 4 ships
the institute-canonical `Lint/` examples for consumers to copy.

**Recommended sugar form**: **Option A** — single-file `Lint.swift` with a
default rule-pack umbrella import, deferred to a Phase 5 follow-on. Until
Phase 5 ships the umbrella + the manifest-compiler dep-discovery mechanism,
single-file `Lint.swift` remains an inert sugar form documented as
"future-facing" in the README's Two consumer shapes section.

**Rejected**: **Option C** — the `defaults()` factory's binary-coupling cost is
unacceptable. The linter binary's infrastructure must remain decoupled from the
ecosystem's rule-pack policy so that rule packs ship on their own semver cadence
as ordinary SwiftPM libraries. Recompiling the linter to update a rule's
default severity is the failure mode this rejection is designed to prevent.

### Why RECOMMENDATION not DECISION

Phase 5 (the Option A sugar form) has not been scheduled. The mechanism question
"how does single-file `Lint.swift` resolve an umbrella import that has no
SwiftPM dep declaration?" needs a Phase 5 scoping pass before the recommendation
becomes a decision. Two candidates surface in cohort discussion:

1. **Bundled rule-pack registry**: the linter binary statically links a known
   set of canonical rule packs and resolves the umbrella import against the
   bundle.
2. **swift-manifest dep injection**: extend the manifest compilation pipeline to
   inject canonical rule-pack deps when a known umbrella import is seen,
   transparently to the consumer.

Both are viable; choosing between them requires implementation prototyping that
is out of scope for this design pass.

### Implementation order

1. **Phase 4 (in flight)**: ship Tier 1 / Tier 2 canonical `Lint/` examples. The
   examples are the working reference for institute consumers and the basis for
   the scaffolding command.
2. **Scaffolding command (post-Phase 4)**: `swift-linter init` generates the
   canonical `Lint/` structure with one command. Eliminates the onboarding cost
   that motivated Option A.
3. **Phase 5 (deferred)**: ship the default rule-pack umbrella + the
   single-file dep-discovery mechanism. Single-file `Lint.swift` becomes
   operational; the README's sugar-form caveat is removed.

Until Phase 5 ships, the README's Two consumer shapes section accurately
describes operational reality: `Lint/` is the canonical form, single-file
`Lint.swift` is the sugar form that will become operational once the umbrella
mechanism lands.

## References

- ESLint configuration: <https://eslint.org/docs/latest/use/configure/>
- SwiftLint configuration: <https://realm.github.io/SwiftLint/configuration.html>
- swift-format configuration: <https://github.com/apple/swift-format/blob/main/Documentation/Configuration.md>
- prettier configuration: <https://prettier.io/docs/en/configuration>
- Phase A PoC verification: `2026-05-07-poc-lint-nested-package.md`
- Phase B.1 decouple verification: `2026-05-07-phase-b1-decouple.md`
- Phase B.4 wave-1 migration: `2026-05-07-phase-b4-wave-1-migration.md`
