# Collection.Slice.Protocol ~Escapable Index — Swift 6.5-dev Toolchain Fallout

<!--
---
version: 1.1.0
last_updated: 2026-06-02
status: DECISION
changelog: "v1.1.0 (2026-06-02) — DECISION: Option A adopted + implemented. swift-collection-primitives 4042d2c spells out `where Index: Swift.Comparable & Swift.Escapable` on Collection.Slice.Protocol; verified green on BOTH 6.3.2 and 6.5-dev; unblocks GAP-A's 6.5-dev downstream. Executes collection-index-escapable-consumer-fallout.md v1.3.0; Option B rejected (proven-degenerate self-slice storage; Tier-3 reopening). v1.0.0 RECOMMENDATION analysis preserved below."
tier: 2
scope: cross-package
trigger: "swift-collection-primitives fails to build on Swift 6.5-dev (toolchain org.swift.64202605121a) at HEAD ad59898; green on Swift 6.3.2. All errors are Collection.Slice.Protocol's Range<Index> requirement + its PartialRange default subscripts: `type 'Self.Index' does not conform to protocol 'Escapable'` and `'..<' on 'Comparable' requires 'Self.Index' conform to 'Escapable'`. Investigation dispatched via HANDOFF-collection-slice-escapable-index.md to decide, from first principles, how Collection.Slice.Protocol should reconcile range-based slicing with the institute's ~Escapable-support principle — validated on BOTH toolchains."
preceded_by:
  - swift-institute/Research/collection-index-escapable-consumer-fallout.md (DECISION v1.3.0, 2026-05-27) — KEEP ~Escapable on the BASE Collection.Protocol.Index; established the escape-operation migration pattern: "escape-operations pin it [Escapable]." Its migration table names Collection.Slice.Protocol as an escape-operation carrying `where Index: Escapable`. THIS doc executes that prescription, forced into visibility by the 6.5-dev toolchain. EXTENDS, does not supersede.
  - swift-institute/Research/collection-slice-stdlib-subscript-ambiguity.md (RECOMMENDATION v1.0.0, 2026-06-02) — a DISTINCT axis on the same protocol: the `& Swift.Collection` dual-subscript ambiguity. Orthogonal mechanism (overload ambiguity vs Index-not-Escapable); co-located in the same parser files for some consumers. Cited + distinguished.
  - swift-institute/Research/phantom-parameter-suppressed-protocol-bound.md (RECOMMENDATION v1.0.0, 2026-06-01) — the PHANTOM-parameter axis (the `Element` of `Index<Element>`, `Tag` of `Tagged`). DISTINCT from this doc's VALUE-index axis (the `Index` associatedtype is a stored/compared value, not a phantom). Cited + distinguished.
  - swift-collection-primitives/Research/escapable-protocol-foreach-count-view.md (DEFERRED-TOOLCHAIN-PRUNED v1.2.0, 2026-05-09) — precedent for the institute's discipline of NOT shipping hypothetical ~Escapable widenings whose consumer path is uncompilable/absent.
---
-->

## Context

`swift-collection-primitives` at HEAD `ad59898` (working tree clean) **fails to build on Swift 6.5-dev** (toolchain `org.swift.64202605121a`, `swift-DEVELOPMENT-SNAPSHOT-2026-05-12-a`) and is **green on Swift 6.3.2** (Xcode default). All failures localize to `Collection.Slice.Protocol`:

```
Collection.Slice.Protocol.swift:39          error: type 'Self.Index' does not conform to protocol 'Escapable'
Collection.Slice.Protocol+defaults.swift:27 error: type 'Self.Index' does not conform to protocol 'Escapable'
Collection.Slice.Protocol+defaults.swift:29 error: referencing operator function '..<' on 'Comparable' requires that 'Self.Index' conform to 'Escapable'
   note: 'where Self: Escapable' is implicit here   (Swift.Comparable)
…  (same class at :38/:40, :54/:55, :63/:64)
```

The current shapes (`[Verified: 2026-06-02]` against source at `ad59898`):

```swift
// Collection.Protocol.swift:65 — base Index is ~Escapable-ADMITTING (the standing v1.3.0 DECISION)
associatedtype Index: Comparison.`Protocol` & ~Escapable = Index_Primitives.Index<Element>

// Collection.Slice.Protocol.swift:32,39 — the self-slicing refinement
public protocol `Protocol`: Collection.`Protocol` & ~Copyable where Index: Swift.Comparable {
    subscript(bounds: Range<Index>) -> Self { get }
}
```

This is a **toolchain-surfaced regression of a constraint that was always intended to require Escapable** — not a fresh design question. The slice protocol's own comment (`Collection.Slice.Protocol.swift:28–31`) already states the intent: *"stdlib `Range` requires `Swift.Comparable` (which also requires Escapable) … `~Escapable` / custom-domain indices are excluded from slicing **by design**."* The parenthetical *"(which also requires Escapable)"* was **true on 6.3.2 and is now false on 6.4+** — that stale premise is the whole story (see Root Cause).

This arc is independent of, but composes with, two prior docs on the same protocol family (`preceded_by`). It is **also** the unblocker the parent context needs: a parallel GAP-A session (Equatable/Hashable on equation/hash/array/stack-primitives, committed, green on 6.3.2) has its **6.5-dev** downstream builds blocked by this slicing gap.

## Question

How should `Collection.Slice.Protocol` reconcile **range-based slicing** (`subscript(bounds: Range<Index>) -> Self`) with the institute's *"support `~Copyable`/`~Escapable` where possible"* principle — given that `Range<Bound>` requires `Bound: Escapable` and the base `Collection.Protocol.Index` is `~Escapable`-admitting?

Stated neutrally per the dispatch: **(A)** make the slice's Index `Comparable & Escapable` explicit (the documented exclusion, now load-bearing), **(B)** redesign slicing to admit `~Escapable` indices via a non-`Range` API, or **(?)** anything the research surfaces. The dispatch disclosed two priors to *test, not inherit*: the parent session leaned (A); the principal pushed back toward (B) invoking the ~Escapable principle. Both are adjudicated below from first principles.

## Methodology

- **Toolchains** (`[Verified: 2026-06-02]` via `swift --version`): Apple Swift **6.3.2** (`swiftlang-6.3.2.1.108`, default) and Apple Swift **6.5-dev** (`org.swift.64202605121a`, LLVM `7c86461e21cca7e`, Swift `6da4da7153e8252`), `arm64-apple-macos26.0`. Per `[PKG-BUILD-001]` the nightly is selected via the `TOOLCHAINS` env var; per `[PKG-BUILD-011]` only 6.3 stable + dev nightly are in scope.
- **Authoritative baseline**: `rm -rf .build && swift build --target "Collection Slice Primitives"` (per `[PKG-BUILD-010]` clean-first), once per toolchain, serially (per `[PKG-BUILD-009]` no parallel builds). No parallel `swift-build`/`swift-frontend` was running when builds were performed (`pgrep` checked).
- **Fix validation (real package)**: applied the one-token Candidate-A edit, built on both toolchains, then **reverted the edit** (manual edit-back, NOT `git checkout`/`restore`/`stash` per `[feedback_never_revert_or_checkout]`/`[feedback_no_git_stash]`). Working tree re-verified clean at `ad59898` (`git status -s` empty, `git diff --stat` empty).
- **Mechanism isolation (/tmp probe)**: per `[feedback_inpkg_iter_over_tmp_probes]`, a /tmp probe is the prescribed venue here (multi-toolchain check + the package is consumed by a parallel session). Probes use `swiftc` **full compiles** (not `-typecheck`, which gave a documented false positive in `escapable-protocol-foreach-count-view.md` §J) with the package's own feature flags (`Lifetimes`, `SuppressedAssociatedTypes`, `LifetimeDependence`, `swift-version 6`). Probe at `/tmp/slice-escapable-probe/`.
- **Prior art** (`[RES-019]`/`[HANDOFF-013]`): greped `swift-institute/Research/` and `swift-collection-primitives/Research/` for escapable/slice/Range/Comparable; read the three `preceded_by` docs + `range-sequence-collection-semantic-analysis.md` + the 2026-06-01 single-root-refactor reflection before writing.

## Root Cause — a stale type-system premise, surfaced by the toolchain

The mechanism is a single transitive implication that **silently disappeared** between toolchains:

| | Swift 6.3.2 | Swift 6.5-dev (SE-0499 family landed) |
|---|---|---|
| `Swift.Comparable` / `Swift.Equatable` | require `Escapable` (`where Self: Escapable` implicit) | declared `~Copyable, ~Escapable` — **no longer require Escapable** |
| `Comparison.Protocol` (institute) | own fork, `: Equation.Protocol, ~Copyable, ~Escapable` | **typealias to `Swift.Comparable`** (`Comparison Primitives.docc:53` `[Verified: 2026-06-02]`) |
| `where Index: Swift.Comparable` (slice refinement) | ⟹ `Index: Escapable` **transitively** | does **not** imply Escapable |
| `Range<Index>` / `..<` (needs `Bound: Escapable`) | satisfied | **not satisfied** → error |

The compiler's own note is the smoking gun: `'where Self: Escapable' is implicit here` pointing at `Swift.Comparable`. On 6.3.2 that implicit clause supplied the `Escapable` the `Range<Index>` subscript and the `..<` default subscripts depend on. On 6.5-dev the implicit clause is gone (SE-0499 relaxed the stdlib comparison protocols to `~Escapable`), the base `Collection.Protocol.Index`'s `& ~Escapable` admission is no longer overridden, and slicing — which is intrinsically range-based — can no longer prove its abstract `Self.Index` is `Escapable`.

This is `[HANDOFF-016]` *premise-staleness* at the type-system level: a constraint that relied on an implicit upstream implication broke when the implication was removed upstream. The handoff's framing ("all errors are in the defaults file") is refined by the build: `Collection.Slice.Protocol.swift:39` (the protocol *requirement* itself) **also** errors, not only the defaults extensions.

## Empirical Results (BOTH toolchains)

### Real package — authoritative (`[Verified: 2026-06-02]`)

| Build (`swift build --target "Collection Slice Primitives"`, clean) | 6.3.2 | 6.5-dev |
|---|---|---|
| **Unfixed** (HEAD `ad59898`) | ✅ GREEN (24.2s) | ❌ FAIL (`Self.Index` not `Escapable`; `..<`/`Range<Index>` require Escapable; cascade `Range<Self.Index>`→`Self.Index`, `Self.Element`→yield `Self`) |
| **Candidate A** (`where Index: Swift.Comparable & Swift.Escapable`) | ✅ GREEN (14.1s, clean — no redundant-constraint error/warning-as-error) | ✅ GREEN (2.3s) |

Edit applied, both builds run, edit reverted; tree re-verified clean at `ad59898`.

### /tmp probe — mechanism isolation (`[Verified: 2026-06-02]`)

A minimal faithful mirror (institute-style `~Escapable`-admitting comparable in the base; `Swift.Comparable` re-stated on the slice; `Range<Index>` subscript + PartialRange defaults):

- **Unfixed @ 6.5-dev** reproduces the **exact** real-package errors (`type 'Self.Index' does not conform to protocol 'Escapable'`, `'..<' … requires 'Self.Index' conform to 'Escapable'`, note `'where Self: Escapable' is implicit here`). On 6.3.2 the probe shows **zero Index-Escapable errors** (the implication holds).
- **Candidate A @ 6.5-dev** compiles green, including a realized concrete Escapable-index conformer (`IntIndex`/`Slice0`).
- *(Probe caveat: a Tier-1 `_read` subscript over a `~Copyable Self` triggers an orthogonal `@_lifetime`-inference requirement on 6.3.2 in the minimal probe; this is a probe artifact — the real package's concrete `Index<Element>` + `@inlinable` defaults compile green on 6.3.2, as the authoritative build confirms. The Index/Range/Escapable mechanism is unaffected by it.)*

### Candidate B viability — storage obstruction (`[Verified: 2026-06-02]`, identical on both toolchains)

A self-slice (`SubSequence == Self`) is an independent value that must encode its bound positions. Storing a `~Escapable` index in such a value fails on **both** toolchains:

```
error: stored property 'lower' of 'Escapable'-conforming struct 'EscapableSlice' has non-Escapable type 'NEIndex'
```

The obstruction is toolchain-independent and fundamental (see Analysis → Option B).

## Analysis

**Criteria** (`[RES-022]`: structural correctness primary; diff/risk are tiebreakers, not selectors): (1) structural fidelity to the standing `Collection.Protocol.Index` DECISION and the Collection/Sequence detachment; (2) evergreen across the 6.3/6.5 toolchain split; (3) blast radius / non-breaking; (4) supply (realized conformers served); (5) diff/risk (tiebreaker).

### Option A — make the implicit Escapable requirement explicit
`where Index: Swift.Comparable` → `where Index: Swift.Comparable & Swift.Escapable` on `Collection.Slice.Protocol` (and refresh the now-stale comment).

- **Structural**: This is the literal execution of the `collection-index-escapable-consumer-fallout.md` **v1.3.0 DECISION**, whose rule is *"Escapable is an **operation-level** requirement … escape-operations pin it"* and whose migration table names **`Collection.Slice.Protocol`** as an escape-operation that carries `where Index: Escapable`. The base keeps its `~Escapable`-admitting Index (DECISION unchanged); only the slicing *refinement* constrains — the canonical "base permits, refinement constrains" shape the DECISION endorsed. ✓
- **Evergreen**: an explicit `Escapable` constraint is correct regardless of whether `Comparable` happens to imply Escapable on a given toolchain. It is robust to exactly the upstream change that broke 6.5-dev. ✓
- **Non-breaking / supply**: the fallout doc's ecosystem grep found **zero `~Escapable`-index conformers**; every realized Index is Escapable (`Index<Element>`, `Int`, `Tagged<_,Ordinal>`, `Array.Index`). On 6.3.2 the constraint set `Comparable & Escapable` is *identical* to today's (Comparable already implied Escapable), so no current conformer is excluded; on 6.5-dev only the (non-existent) `~Escapable`-indexed conformers are excluded — which the protocol already excluded "by design." ✓
- **Empirical**: green on **both** toolchains in the real package. ✓✓
- **Diff**: one token + one comment line.

### Option B — admit ~Escapable indices via a non-Range API (the principal's disclosed lean)
Replace `Range<Index>` with a borrowing two-index API (`subscript(from: borrowing Index, upTo: borrowing Index) -> Self`) that never stores indices in a `Range`.

- **Fatal first-principles obstruction (empirical)**: the `Range` is not the real constraint — *storing the bounds in the slice result* is. A self-slice must encode its bound positions in the returned `Self`. The probe shows an escapable struct **cannot** store a `~Escapable` index field (both toolchains). So B has only two degenerate resolutions: **(i)** make the slice (= `Self`, the collection type) `~Escapable` so it can hold `~Escapable` bounds — which cascades `~Escapable` onto the whole Collection surface, breaks the independent-value `SubSequence == Self` model, and serves no realized consumer; or **(ii)** store an *Escapable* coordinate (Ordinal/Int) extracted from the index — but then the index's position *is* escapable, contradicting the `~Escapable` premise (per the fallout doc §1, "an index is essentially a storable escapable coordinate"). Either way B does **not** deliver `~Escapable`-index slicing.
- **Reopens a closed DECISION**: B directly contradicts `collection-index-escapable-consumer-fallout.md` v1.3.0 ("`~Escapable` indices excluded from slicing by design") and the slice protocol's own comment. *This is the precise point to flag to the principal:* the disclosed B-lean is in tension with the principal's **own** prior DECISION. Reopening it is a Tier-3 act, not a 6.5-dev unblock.
- **Supply / institute principle**: `[RES-018]`/`[feedback_correctness_and_evergreen]` judge `~Escapable` adoption on **structural correctness + evergreen, not consumer count** — and B fails the *structural* test (the storage obstruction), independently of its zero realized demand. The institute's maximal-`~Escapable`-support heuristic is grounded in *payoff*; for a slice bound the payoff is structurally unrealizable.
- **Blast radius**: changes the protocol requirement + every `input[lo..<hi]` call site + abandons stdlib `Range`/`SubSequence` interop. Large, for negative structural value.

### Option C — pin to the concrete `where Index == Index_Primitives.Index<Element>`
Compiles on both toolchains, but **over-constrains**: it regresses the custom-Escapable-index-domain capability the v1.3.0 DECISION deliberately preserved (real supply: `Int`, `Tagged<_,Ordinal>`, `Array.Index`). Rejected for the same reason the fallout doc rejected its "c1" revert-to-concrete. (The fallout migration table offers this pin only as a fallback "when the concrete Ordinal API is needed" — slicing needs only `Comparable & Escapable`, not Ordinal arithmetic, so the pin is unwarranted here.)

### Option D — a `~Escapable`-admitting Range/bound primitive (new type)
A `BorrowingRange<Bound: ~Escapable>` that doesn't store bounds by value. Gated by `[DS-020]`/`[RES-018]` (new cross-cutting primitive ⇒ composition-check + cross-domain-fit). Even if built, it does not solve B's storage obstruction (a `~Escapable` range is itself `~Escapable` and cannot be stored in an escapable slice). Massive scope, zero realized demand. Rejected.

### Option E — split the slice protocol (base-without-Range + Range refinement)
The slice protocol's entire purpose **is** the `Range<Index>` self-slicing subscript; the base `Collection.Protocol` already *is* the no-slicing tier. "Splitting" reconstructs what already exists. No value. Rejected.

### Comparison

| Criterion | A (explicit `& Escapable`) | B (non-Range API) | C (concrete pin) | D (new range primitive) |
|---|:--:|:--:|:--:|:--:|
| Structural (`[RES-022]`; fidelity to v1.3.0 DECISION) | ✓ executes the escape-op prescription | ✗ reopens it; storage-degenerate | ~ over-constrains | ✗ doesn't solve storage |
| Evergreen across 6.3/6.5 | ✓ | ~ | ✓ | ~ |
| Non-breaking (realized conformers) | ✓ (0 excluded) | ✗ cascades ~Escapable onto Self | ✗ drops custom domains | ~ |
| Serves real supply | ✓ (all Escapable indices) | ✗ (0 ~Escapable-index conformers) | ✗ | ✗ |
| Empirically green BOTH toolchains | ✓✓ | n/a (not viable) | ✓ (untested; over-constrains) | n/a |
| Diff / risk (tiebreaker) | 1 token | very large | small | very large |

## Outcome

**Status: DECISION — Option A, implemented** (swift-collection-primitives `4042d2c`, 2026-06-02): `where Index: Swift.Comparable & Swift.Escapable` on `Collection.Slice.Protocol`, with the now-stale "(which also requires Escapable)" comment refreshed. Verified green on BOTH 6.3.2 and 6.5-dev; unblocks GAP-A's 6.5-dev downstream builds.

Option A is the **structurally-correct realization of the standing `collection-index-escapable-consumer-fallout.md` v1.3.0 DECISION** — slicing is an escape-operation; escape-operations pin `Escapable`; the base keeps its `~Escapable`-admitting Index. It was not needed explicitly on 6.3.2 only because `Swift.Comparable` implied `Escapable` there; the 6.5-dev SE-0499 relaxation removed that implication and made the long-intended constraint load-bearing. It is empirically green on **both** toolchains, non-breaking (zero realized conformers excluded), and evergreen.

The two disclosed priors are adjudicated, not inherited:
- **(A) — affirmed, but recontextualized**: not a *new* exclusion decision; it makes explicit a constraint the protocol's own comment and the v1.3.0 DECISION already mandated.
- **(B) — recommended against, for principled reasons**: (1) a toolchain-independent storage obstruction (a self-slice cannot carry `~Escapable` bounds without becoming `~Escapable` itself — empirically shown on both toolchains); (2) it contradicts the principal's **own** v1.3.0 DECISION ("`~Escapable` indices excluded from slicing by design"); (3) zero realized `~Escapable`-index supply, and it fails `[RES-018]`'s *structural* test independently of demand. **Co-architect flag (per the workspace collaboration protocol):** the principal's in-the-moment B-lean is in direct tension with their durable v1.3.0 DECISION; choosing B is a Tier-3 reopening of a closed contract, not a 6.5-dev unblock.

**Tier 2** per `[RES-020]`: cross-package scope (collection-primitives protocol + version/glob/input consumers + ecosystem 6.5-dev readiness + the GAP-A downstream unblock), but **not precedent-setting** — it applies an existing DECISION rather than establishing a new semantic contract; reversible (one token).

### Recommended change (not applied — report-not-fix scope)

```diff
- // Slicing is inherently range-based (`Range<Index>`), and stdlib `Range`
- // requires `Swift.Comparable` (which also requires Escapable). So a slicing
- // collection's `Index` must be `Swift.Comparable` — the default `Index<Element>`
- // is; `~Escapable` / custom-domain indices are excluded from slicing by design.
- public protocol `Protocol`: Collection.`Protocol` & ~Copyable where Index: Swift.Comparable {
+ // Slicing is inherently range-based (`Range<Index>`), and stdlib `Range` requires
+ // `Bound: Escapable` (it stores both bounds by value). `Swift.Comparable` implied
+ // `Escapable` before Swift 6.4 (SE-0499 relaxed `Comparable`/`Equatable` to ~Escapable),
+ // so the requirement is now spelled explicitly. The base `Collection.Protocol.Index`
+ // stays `~Escapable`-admitting (per collection-index-escapable-consumer-fallout.md
+ // v1.3.0); this refinement pins `Escapable` because slicing is an escape-operation.
+ // `~Escapable` / custom-domain indices remain excluded from slicing by design.
+ public protocol `Protocol`: Collection.`Protocol` & ~Copyable where Index: Swift.Comparable & Swift.Escapable {
      subscript(bounds: Range<Index>) -> Self { get }
  }
```

### Execution notes (principal owns sequencing)
- **No source changed by this investigation** (the Candidate-A edit was applied for validation then reverted; tree clean at `ad59898`).
- The change is **package-local to `Collection.Slice.Protocol.swift`**; the defaults extensions inherit the protocol constraint (validated — no per-extension edit needed).
- Independent of `collection-slice-stdlib-subscript-ambiguity.md` (the `& Swift.Collection` ambiguity) and of the GAP-A Equatable/Hashable work; this single token unblocks the **6.5-dev** builds the slice protocol gates.
- Verify after applying per the standard discipline: `rm -rf .build && swift build` on 6.3.2 **and** `TOOLCHAINS=org.swift.64202605121a` on 6.5-dev (both already validated for the target here).

## References

- **The breakage**: `swift-collection-primitives@ad59898` — `Sources/Collection Slice Primitives/Collection.Slice.Protocol.swift:32,39`; `…/Collection.Slice.Protocol+defaults.swift:27,29,38,40,54,55,63,64`; base `…/Collection Protocol Primitives/Collection.Protocol.swift:65`.
- **The mechanism**: `swift-comparison-primitives/Sources/Comparison Protocol Primitives/Comparison.Protocol.swift:62` (`~Copyable, ~Escapable` fork); `Comparison Primitives.docc:53` (typealias-to-`Swift.Comparable` on 6.4+) `[Verified: 2026-06-02]`.
- **Standing DECISION (executed by this doc)**: `swift-institute/Research/collection-index-escapable-consumer-fallout.md` (DECISION v1.3.0) — escape-operation migration pattern; KEEP `~Escapable` on the base Index.
- **Orthogonal sibling**: `swift-institute/Research/collection-slice-stdlib-subscript-ambiguity.md` (RECOMMENDATION v1.0.0) — `& Swift.Collection` dual-subscript ambiguity (different axis, same protocol family).
- **Distinct phantom axis**: `swift-institute/Research/phantom-parameter-suppressed-protocol-bound.md` (RECOMMENDATION v1.0.0) — the phantom `Element`/`Tag`, not the value `Index`.
- **Precedent (prune hypothetical ~Escapable widenings)**: `swift-collection-primitives/Research/escapable-protocol-foreach-count-view.md` (DEFERRED-TOOLCHAIN-PRUNED v1.2.0).
- **Empirical baseline + probe**: `swift build` matrix (6.3.2 GREEN / 6.5-dev FAIL→GREEN-under-A), Apple Swift 6.3.2 + 6.5-dev (`org.swift.64202605121a`), arm64-apple-macos26.0, collection-primitives@`ad59898`, 2026-06-02; probe at `/tmp/slice-escapable-probe/`.
- **Governing rules**: `[RES-018]` + `[feedback_correctness_and_evergreen]` (judge ~Escapable on structural correctness + evergreen, not consumer count); `[RES-022]` (structural over min-diff); `[PKG-BUILD-001]`/`[PKG-BUILD-009]`/`[PKG-BUILD-010]`/`[PKG-BUILD-011]` (toolchain/build discipline); `[HANDOFF-016]` (premise staleness); `[feedback_never_revert_or_checkout]`/`[feedback_no_git_stash]`/`[feedback_inpkg_iter_over_tmp_probes]` (validation venue + tree discipline).
