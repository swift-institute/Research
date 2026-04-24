# Kernel.Signal.Information Dual-Declaration Resolution

**Status**: DECIDED 2026-04-24 — Option A (unify) selected. See § Principal Decisions (Stamped 2026-04-24) below.

**Tracker**: `swift-institute/Audits/platform-compliance-2026-04-21.md` § Post-Cycle-3 Re-verification → P2.9 (HIGH).

**Companion to**: Doc 3 (`swift-iso/swift-iso-9945/Research/signal-action-siginfo-l2-wrapper-design.md`). Doc 3 authored the iso-9945 side of this collision during Cycle 2; this doc resolves the collision with swift-linux-standard's pre-existing declaration that Cycle 2's narrower gate failed to surface.

## Issue

Two declarations of `Kernel.Signal.Information` coexist in the ecosystem. Both extend `Kernel.Signal` via the `[PLAT-ARCH-004]` typealias chain (`ISO_9945.Kernel = Kernel_Primitives_Core.Kernel`; `Linux.Kernel = Kernel_Primitives.Kernel`), so both land on the same fully-qualified type. On Linux consumers that import both modules (e.g., swift-kernel "Kernel File" target building on Docker Linux), this is a redeclaration.

Surfaced as Cycle 3 gate (d) blocker (Phase 2 commit body `[SUPER-015]` #5 in `swift-foundations/swift-posix` `0bdc8b0`). Latent between 2026-04-11 and 2026-04-24 because no prior cycle built swift-kernel on Linux — each cycle's gate scope was tighter than the collision's visibility.

### Declaration A — `swift-iso-9945` (Cycle 2 β', `2a5e5fe`, 2026-04-22)

Location: `swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel Signal/ISO 9945.Kernel.Signal.Information.swift:56`.

```swift
@safe
public struct Information: @unchecked Sendable {
    internal var cValue: siginfo_t

    @unsafe
    public init(pointee: siginfo_t) { unsafe (self.cValue = pointee) }
}
```

Accessors (same file :73–186): `.number: ISO_9945.Kernel.Signal.Number`, `.sender: Kernel.Process.ID?`, `.fault: UInt?`. Each dispatches on `si_code` with Darwin / Glibc / Musl `#if canImport` branches to handle platform-specific union field naming.

**Role**: read-side snapshot. Consumer copies `infoPtr.pointee` inside a `Handler.customInfo` body. Typed accessors read `cValue` directly — async-signal-safety designed.

**Scope**: POSIX-general (all three `#if canImport` platform branches).

### Declaration B — `swift-linux-standard` (`fd04244`, 2026-04-11)

Location: `swift-linux-foundation/swift-linux-standard/Sources/Linux Kernel System Standard/Linux.Kernel.Signal.Information.swift:19`.

```swift
public struct Information: @unchecked Sendable {
    internal var cValue: siginfo_t

    public init() { self.cValue = siginfo_t() }
}
```

Accessors (same file :31–61): `.signal: Int32`, `.error: Int32`, `.code: Code` (nested type), `.pid: Kernel.Process.ID`, `.uid: Kernel.User.ID`, `.status: Int32`. Raw Glibc union access (`cValue._sifields._kill.si_pid`, `cValue._sifields._sigchld.si_status`).

Nested type at `Linux.Kernel.Signal.Information.Code.swift:16`: `struct Code: RawRepresentable<Int32>` with static constants `.exited / .killed / .dumped / .trapped / .stopped / .continued` (`CLD_*`).

**Role**: callee-filled buffer. Consumer allocates via `init()`, hands `UnsafeMutablePointer<Information>` to a kernel interface that fills it, then reads fields.

**Scope**: Linux-only (`#if os(Linux)`), but the consumer also `public import ISO_9945_Kernel_Signal` at :5 (pulling declaration A into scope).

### Single external consumer

`swift-linux-foundation/swift-linux-standard/Sources/Linux Kernel IO Uring Standard/Linux.Kernel.IO.Uring.Submission.Queue.Entry+Prepare.swift:1369`:

```swift
public mutating func waitid(
    kind: Kernel.Process.Wait.Kind,
    id: Kernel.Process.ID,
    info: UnsafeMutablePointer<Kernel.Signal.Information>,
    options: Kernel.Process.Wait.Options,
    flags: Kernel.IO.Uring.Wait.Options,
    data: Kernel.IO.Uring.Operation.Data
)
```

`info` is the io_uring `IORING_OP_WAITID` target buffer; the kernel writes `siginfo_t` bytes into `info.pointee`. The consumer needs declaration B's `init()` and mutable-buffer semantics.

No other external consumer exists (full-workspace `grep Kernel\.Signal\.Information`).

## Canonical Home

Per `[PLAT-ARCH-007]`: POSIX code shared by Darwin + Linux belongs in swift-iso-9945. Both `siginfo_t` and the `CLD_*` `si_code` constants are POSIX.1. Declaration A is POSIX-general; declaration B is Linux-only by file guard but expresses a POSIX-general concept (callee-filled siginfo_t buffer).

Therefore:
- Declaration A's type shape is canonical.
- Declaration B's `.Code` enum is POSIX-general and should migrate to iso-9945.
- Declaration B's buffer-semantics role is POSIX-general as a CAPABILITY, but only Linux has a wire-level consumer today (io_uring). Darwin's equivalent would be `sigwaitinfo`/`sigtimedwait`, which swift-darwin-standard does not yet wrap.

## Options

### Option A — Unify: augment A, delete B, distribute accessors

Keep only declaration A's struct. Extend it to cover B's role:
- Add `public init()` to declaration A (zeroed buffer; POSIX-general; sibling to `init(pointee:)`).
- Move `.Code` from B to iso-9945 (POSIX-general; accessors-of-A gain a typed-`Code` refactor as drive-by or deferred).
- Split B's remaining accessors (`.signal / .error / .code / .pid / .uid / .status`) into:
  - Drop `.signal` / `.pid` (redundant — A has `.number` / `.sender`, differing only in null-handling; unify per OQ-1).
  - `.error: Int32` → add to iso-9945 as `.errorCode: Int32` (POSIX `si_errno`; general). Or typed via `Kernel.Error.Code` — see OQ-2.
  - `.uid: Kernel.User.ID` → add to iso-9945 as `.senderUser: Kernel.User.ID?` (POSIX `si_uid`; platform-branched like `.sender`).
  - `.status: Int32` → add to iso-9945 as `.childStatus: Int32?` (POSIX `si_status`; SIGCHLD-gated via `si_code`).
- io_uring consumer: unchanged site (`UnsafeMutablePointer<Kernel.Signal.Information>` still resolves); build passes because there's now one declaration.

**Scope**:
- iso-9945: Edit `ISO 9945.Kernel.Signal.Information.swift` (+1 init, +2 accessors, re-typed `.number`/`.sender` via `.Code`). Add new `ISO 9945.Kernel.Signal.Information.Code.swift` (moved in from B's file).
- linux-standard: Delete `Linux.Kernel.Signal.Information.swift`. Delete `Linux.Kernel.Signal.Information.Code.swift`.
- io_uring consumer: no source change.

**Pros**: one type; consistent accessor surface; `.Code` becomes POSIX-general and types A's `.sender/.fault` dispatch; structurally correct (A and B share a single `siginfo_t` storage with same layout-compatibility contract — they are a type-with-two-initializers, not two types).

**Cons**: async-signal-safety re-verification required for any B-origin accessors ported to A's platform-branched pattern — bounded scope, mechanical via POSIX.1-2017 `siginfo_t` field-layout cross-reference per `si_code` class; no pre-flight experiment required.

**Draft-time Cons retracted at Principal review (2026-04-24, preserved as record)**: (a) ~~"merges two accessor styles"~~ — Principal: "not a con; this IS the fix. One style is correct." (b) ~~"coupling to P2.3 #3 `.fault → Memory.Address?` upgrade"~~ — Principal: "spurious — `.fault` is A-only; B has no `.fault` accessor. Unifying does not touch `.fault`. `.fault: UInt?` stays. Optic.Prism cascade remains deferred, decoupled." (c) Async-signal-safety Con was under-scoped in the original draft — Principal: "real but bounded; verification is mechanical."

### Option B — Co-exist: rename B as a sibling under A

Keep declaration A unchanged. Rename declaration B to `Information.Storage` (or `.Buffer` / `.Mutable` — OQ-3):

```swift
// swift-linux-standard, renamed file
extension Kernel.Signal.Information {
    public struct Storage: @unchecked Sendable {
        internal var cValue: siginfo_t
        public init() { self.cValue = siginfo_t() }
    }
}
```

Accessors move to `Information.Storage.{signal,error,code,pid,uid,status}`.
`.Code` moves to iso-9945 (POSIX-general; also consumed by A's accessors on refactor).

io_uring consumer site: change `UnsafeMutablePointer<Kernel.Signal.Information>` → `UnsafeMutablePointer<Kernel.Signal.Information.Storage>`. One edit.

**Scope**:
- iso-9945: new file `ISO 9945.Kernel.Signal.Information.Code.swift` (Code type moved in).
- linux-standard: rename `Information` → `Information.Storage` in-place (same file, renamed content; layout unchanged). Delete `Information.Code.swift` (moved).
- io_uring consumer: one parameter-type edit.

**Pros**: preserves A unchanged; distinct semantics encoded in name; smallest touch to A's verified async-signal-safety contract; no coupling to P2.3 #3.

**Cons**: two sibling types where one could suffice under Option A; consumers writing `Information` vs `Information.Storage` must remember which.

### Option C — Demote B to io_uring-local

Move B's declaration from `Linux Kernel System Standard` to `Linux Kernel IO Uring Standard` as a local type (e.g., `Kernel.IO.Uring.Wait.Info` or `Kernel.IO.Uring.Signal.Info`). Delete the public `Kernel.Signal.Information` declaration in linux-standard entirely.

**Scope**:
- linux-standard: delete `Information.swift` + `Information.Code.swift` under System Standard. Add equivalent type under IO Uring Standard, re-scoped to `Kernel.IO.Uring.*`.
- io_uring consumer: parameter-type edit to the new local name.
- iso-9945: gain `.Code` if the POSIX-general salvage is kept; otherwise unchanged.

**Pros**: no `Kernel.Signal` collision; io_uring-local type is semantically accurate (io_uring is the only consumer today).

**Cons**: naming drift from POSIX-general concept (siginfo_t is not io_uring-specific); future Linux consumer of `sigtimedwait(2)` / `rt_sigqueueinfo(2)` / `waitid(2)` outside io_uring would re-create the same type. Worst-of-both.

### Option D — Deprecate B, DI shim

Leave A unchanged. Add a typealias in linux-standard: `public typealias Information = ISO_9945.Kernel.Signal.Information`. Simultaneously delete B's struct declaration and relocate B's accessors as extensions on A within linux-standard's target.

`init()` on A would be needed for the io_uring waitid call-site to construct a zeroed buffer.

**Scope**:
- iso-9945: add `init()` (same as Option A).
- linux-standard: delete struct declaration from `Information.swift`; convert file to extension-adding-accessors form. Delete `Information.Code.swift` after moving `.Code` to iso-9945.
- io_uring consumer: unchanged.

**Pros**: same as Option A without fully unifying accessor design upfront.

**Cons**: typealiases for type unification are forbidden per `[API-NAME-004]` (this is a unification bridge, not an adoption typealias — the type is the same, only visibility is re-exported). Option D is structurally an Option A in disguise; flagged as not recommended.

## Principal Decisions (Stamped 2026-04-24)

Principal redirect 2026-04-24: Option A, not B. Doc 4's original framing treated "lowest-risk diff" as the goal; the actual goal is the structurally correct shape. A and B share a single `siginfo_t` storage with the same layout-compatibility contract — they are a type-with-two-initializers, not two types. All seven OQs answered below; doc amended in-place per these decisions.

1. **Option = A (unify).** Delete B's declaration; augment A with B's role via a zeroed `init()`. `.Code` migrates to iso-9945 (POSIX-general).

2. **OQ-1 accessor consolidation = A's shape wins.** `.number` (typed `ISO_9945.Kernel.Signal.Number`) supersedes `.signal: Int32`. `.sender: Kernel.Process.ID?` (null-safe, platform-branched on `si_code`) supersedes `.pid: Kernel.Process.ID` (unconditional union read). **Conditional next step** — before implementing, grep linux-standard for internal consumers of B's **six** accessors (`.signal / .error / .code / .pid / .uid / .status`). If unused → drop them entirely (minimal unification). If used → port to A's pattern: `.errorCode: Int32` (POSIX `si_errno`), `.code: Code` (non-optional; body `Code(rawValue: cValue.si_code)`; `.Code` as `RawRepresentable<Int32>` wraps any `si_code` regardless of class; consumer pattern-matches `case .exited: … default: …` catches unknown; non-optional because `si_code` is always populated), `.senderUser: Kernel.User.ID?` (platform-branched like `.sender`), `.childStatus: Int32?` (SIGCHLD-gated via `si_code`). Report grep result at the Phase 0.5 intervention point before proceeding to Phase 1.

3. **OQ-2 `.Code` scope = minimal — CLD_* only, as B has today.** Adding `SEGV_*/BUS_*/ILL_*/FPE_*/SI_USER/SI_QUEUE` cases is speculative-consumer scope-creep (would violate "don't design for hypothetical future requirements"). Design `.Code` as `RawRepresentable<Int32>` with extensible static-constant surface so future cases land additively without ABI break.

4. **OQ-3 `.Storage` name = N/A** (Option A — no sibling type to name).

5. **OQ-4 P2.3 #3 `.fault` coupling = decoupled.** `.fault: UInt?` unchanged. `Optic.Prism` cascade stays deferred. Spurious coupling in the draft-time Cons was retracted per § Option A Cons.

6. **OQ-5 async-signal-safety re-verification = in-scope for this cycle, no pre-flight experiment.** Adopt A's platform-branched pattern for any inherited-from-B accessors; verify by POSIX header cross-reference at implementation time.

7. **OQ-6/OQ-7 gate requirement = HARD gate.** Docker Linux `swift build --build-tests` clean on swift-kernel `"Kernel File"` target is the terminal gate for this cycle (Cycle 3 Doc 1 Decision #5 precedent; Cycle 3 gate (d) blocker is P2.9's surfacing event).

## Option Matrix

| Option | iso-9945 edits | linux-standard edits | io_uring consumer | `.Code` migration | Couples to P2.3 #3 `.fault` | Future-proof |
|--------|----------------|----------------------|-------------------|--------------------|------------------------------|--------------|
| A (unify) | +init() + optional accessors (Phase 0.5 contingent) + Code type | delete Information.swift + Code.swift | unchanged (`UnsafeMutablePointer<Kernel.Signal.Information>` now resolves unambiguously to A with `init()`) | yes (from B) | **no (B has no `.fault` accessor — original "yes" was spurious, retracted by Principal 2026-04-24)** | yes |
| B (sibling) | +Code type | rename Information → Information.Storage; delete Code file | 1 parameter edit | yes (from B) | no (decoupled) | yes |
| C (io_uring-local) | +Code type (optional salvage) | delete both; recreate in IO Uring target | 1 parameter edit + rename | partial (from B, if salvaged) | no | no (regresses on non-io_uring consumers) |
| D (typealias shim) | +init() | delete struct + convert to extension | unchanged | yes (from B) | yes (forced) | yes but violates `[API-NAME-004]` |

## Recommendation

**Principal override 2026-04-24**: Option A selected. See § Principal Decisions (Stamped 2026-04-24) above.

**Principal's critique of the draft-stage framing (recorded for future Doc-authoring discipline)**: "Doc 4's framing treats 'lowest-risk diff' as the goal. The actual goal is the structurally correct shape. Structurally, A and B are the same type (single stored `siginfo_t`, same layout-compatibility contract) with (a) different initializers and (b) partial accessor overlap. That is a type-with-two-initializers, not two types." The draft Cons attributed to Option A were overstated: (1) "merges two accessor styles" is the fix, not a con; (2) P2.3 #3 `.fault` coupling was spurious (B has no `.fault`); (3) async-signal-safety re-verification is real but bounded-mechanical, not blocking. Future investigation Docs should prefer "structurally correct" over "minimum diff" when the two diverge.

---

**Draft-stage recommendation (preserved as investigation record; SUPERSEDED by Principal override above)**:

~~**Option B** (co-exist, rename B → `Information.Storage`) is the lowest-risk path:~~

1. ~~Does not touch declaration A's verified async-signal-safety contract (zero re-verification).~~
2. ~~Does not couple to P2.3 #3's deferred `.fault` upgrade (Optic.Prism cascade remains deferred).~~
3. ~~Preserves distinct semantics encoded in the sibling-type name.~~
4. ~~Single io_uring consumer edit; reversible.~~
5. ~~Future Darwin `sigwaitinfo`/`sigtimedwait` wrappers gain a natural home (`Information.Storage` is POSIX-general under A — promote to iso-9945 when the second consumer arrives per the speculative-namespace rule `[API-NAME-001a]`).~~

~~**Option A** is the clean end-state but forces both the async-signal-safety re-verification and the P2.3 #3 `.fault` coupling. Recommend A as a future cycle when those dependencies resolve.~~

**Option C** is rejected on future-proof grounds.

**Option D** is ruled out on `[API-NAME-004]` grounds.

## Implementation Cycle Scope (Option A — Principal Stamped 2026-04-24)

| Phase | Repo | Files | Verification | Intervention |
|-------|------|-------|--------------|--------------|
| Phase 0 | swift-institute/Research | Doc 4 amendment (this revision) — status + Principal Decisions + Cons retraction + Matrix + Implementation Scope + Grep-Result placeholder. No source edits. | Principal reviews amended document. | Report Phase 0 completion; await Principal confirmation before Phase 0.5. |
| Phase 0.5 | swift-linux-standard | Consumer grep per Principal Decision 2 to determine B-accessor disposition: `grep -rn '\.signal\|\.error\|\.\(pid\|uid\|status\)\b' Sources/ --include='*.swift' \| grep -iE 'signal\|info'` and `grep -rn 'Information\.Code' Sources/`. No source edits. | Principal confirms accessor disposition (drop-all vs port). | Report grep results verbatim; await Principal confirmation before Phase 1. |
| Phase 1 | swift-iso-9945 | (a) Add `public init()` to `Sources/ISO 9945 Kernel Signal/ISO 9945.Kernel.Signal.Information.swift` (zeroed-buffer init; sibling to `@unsafe init(pointee:)`). (b) New `Sources/ISO 9945 Kernel Signal/ISO 9945.Kernel.Signal.Information.Code.swift` (POSIX-general; CLD_* cases from B verbatim; `public struct Code: RawRepresentable<Int32>, Sendable, Equatable, Hashable` with extensible static-constant surface). (c) **Contingent on Phase 0.5**: if B's accessors are used in linux-standard → add `.errorCode: Int32`, `.senderUser: Kernel.User.ID?`, `.childStatus: Int32?` accessors with platform-branched pattern; if unused → skip. | macOS `swift build --build-tests` clean on swift-iso-9945 AND Docker Linux swift:6.3.1 `swift build --build-tests` clean on swift-iso-9945. | Principal reviews iso-9945 diff. |
| Phase 2 | swift-linux-standard | Delete `Sources/Linux Kernel System Standard/Linux.Kernel.Signal.Information.swift` (struct B — now superseded by A's `init()`). Delete `Sources/Linux Kernel System Standard/Linux.Kernel.Signal.Information.Code.swift` (`.Code` migrated to iso-9945 in Phase 1). | macOS `swift build --build-tests` clean on swift-linux-standard AND Docker Linux swift:6.3.1 `swift build --build-tests` clean on swift-linux-standard. Any orphan references surface as compile errors. | Principal reviews linux-standard deletions; verifies no orphan references. |
| Phase 3 | swift-foundations/swift-kernel | **No source edits** — terminal gate verification. **Outcome 2026-04-24: substantive canary via Phase 2 (Docker Linux `swift build --build-tests` on swift-linux-standard clean, 21.01s, with unified A + post-deletion linux-standard in scope together). Full swift-kernel `"Kernel File"` gate deferred by Cycle 3 gate (b)/(d) precedent — blocked on unrelated upstream drift in `swift-foundations/swift-linux/Sources/Linux Kernel Random/Linux.Random.swift:54` (Swift 6.3 `MemberImportVisibility` violation on `Kernel.Random.Error`; missing `public import Kernel_Random_Primitives`). Drift logged as new D5 observation in tracker § Post-Cycle-3 Re-verification.** | HARD gate per Principal Decision 7 — satisfied via canary substitution per Cycle 3 precedent; Principal-authorized 2026-04-24. | Principal confirmed canary evidence (Phase 2 `--build-tests` clean proves the ambiguity the terminal gate was designed to test: both A and the post-B-deletion linux-standard module composed in one consumer build graph with zero redeclaration / orphan-reference diagnostic). |
| Phase 4 | swift-institute/Audits | Update `platform-compliance-2026-04-21.md` P2.9 row → RESOLVED with Phase 1/2 commit SHAs + one-line evidence. Update § Post-Cycle-3 Re-verification scoreboard to reflect P2.9 disposition change. No build verification needed (tracker-only). | Principal reviews tracker diff. | Principal authorizes commit. |

**Actual commit graph** (2026-04-24 close): 4 commits across 4 repos (Phase 1 swift-iso-9945 `6cdb3f7`; Phase 2 swift-linux-standard `565d9ac`; Phase 4 tracker swift-institute/Audits; Phase 4 Doc 4 swift-institute/Research — this commit). Phase 0 + 0.5 + 3 produced no commits (Phase 3 canary substitution satisfied by Phase 2 gate). **Actual effort**: ~6 hours including Docker daemon recovery detour + Phase 2 principal-authorized consumer import scope relaxation.

**io_uring consumer under Option A** (post-Cycle-4 actual): `UnsafeMutablePointer<Kernel.Signal.Information>` at `Linux.Kernel.IO.Uring.Submission.Queue.Entry+Prepare.swift:1369` resolves unambiguously to unified A with `init()` available, **plus** a new `public import ISO_9945_Kernel_Signal` at `:29` inside the `#if os(Linux)` block. The draft-stage zero-migration claim was half-true — no parameter-type edit needed, but the import edit was required to preserve Swift 6.3 `MemberImportVisibility` because pre-deletion B's presence in `Linux_Kernel_System_Standard` provided accidental transitive visibility. See § Supervision below for the scope-relaxation detail.

**Supervision**: subordinate self-supervised against a `/supervise` ground-rules block authored at Phase 0.5 close. Block scope-locked to Option A + stamped decisions + drop-all disposition. **Principal-authorized scope relaxations** (2026-04-24):

1. **Phase 1 `unsafe (...)` wrap**: principal-interpreted ground-rule #2 "non-@unsafe" as attribute-only (init declaration has no `@unsafe`); the body's `unsafe (self.cValue = siginfo_t())` wrap is [MEM-SAFE-002] expression-granularity acknowledgment of `siginfo_t`'s unsafe-storage classification under Swift 6.3's `StrictMemorySafety`. Consistent with the sibling `@unsafe init(pointee:)` body wrap.

2. **Phase 2 io_uring consumer import**: principal-relaxed ground-rule #4 (MUST NOT touch io_uring consumer) to exactly one line — `public import ISO_9945_Kernel_Signal` placed next to the existing `public import ISO_9945_Kernel_File` at `:29`. Required because `waitid(info: UnsafeMutablePointer<Kernel.Signal.Information>, …)` at `:1369` references an iso-9945 type in its public signature; Swift 6.3 `MemberImportVisibility` requires the explicit import. Phase 0.5's grep-only methodology had found zero external consumers of the type name but did not verify import visibility at consumer sites — meta-note for future Doc-class audit methodology.

3. **Phase 3 substantive-canary substitution**: principal-accepted Phase 2 Docker Linux `swift build --build-tests` on swift-linux-standard (21.01s clean; both A and post-deletion linux-standard in one consumer build graph; zero ambiguity/orphan diagnostic) in lieu of the blocked swift-kernel `"Kernel File"` terminal gate, per Cycle 3 gate (b)/(d) precedent. The blocker was an unrelated upstream Swift 6.3 `MemberImportVisibility` drift in `swift-foundations/swift-linux/Sources/Linux Kernel Random/Linux.Random.swift:54` (tracker D5); orthogonal to P2.9 (different package, type, defect class).

Intervention points per the table's Intervention column executed in order: Phase 0 (Doc 4 amendment) → Phase 0.5 (grep + disposition) → Phase 1 (iso-9945 diff + gate) → Phase 2 (linux-standard diff + gate) → Phase 3 (canary acceptance) → Phase 4 (tracker + Doc 4 commits). Principal confirmed at each boundary via user-relay pattern.

## Grep-Result (Phase 0.5)

**Status**: RUN 2026-04-24. Awaiting Principal confirmation of disposition.

**Commands executed** (per Principal's improved version with scope widened to three repos + exclusion filters, plus a fourth sanity-sweep for indirect `.pointee./.cValue.` accessor patterns):

```bash
# (1) Kernel.Signal.Information references outside declaration files, in all three reachable repos
for dir in swift-linux-foundation swift-foundations swift-iso; do
  echo "=== $dir ==="
  grep -rn 'Kernel\.Signal\.Information' "$dir/" --include='*.swift' 2>/dev/null \
    | grep -v 'Research/\|Documentation.docc/\|\.md:' \
    | grep -v '/Linux\.Kernel\.Signal\.Information\.swift:\|/Linux\.Kernel\.Signal\.Information\.Code\.swift:\|/ISO 9945\.Kernel\.Signal\.Information\.swift:'
done

# (2) waitid callers (the only function that takes a Kernel.Signal.Information parameter)
for dir in ...; do grep -rn '\.waitid(' "$dir" --include='*.swift' ...; done

# (3) Raw siginfo_t / si_* field access patterns that would bypass typed accessors
for dir in ...; do grep -rn 'siginfo_t\|\.si_signo\|\.si_errno\|\.si_code\b\|\.si_pid\|\.si_uid\|\.si_status' "$dir" --include='*.swift' ...; done

# (4) Information.Code and static-constant consumer references
for dir in ...; do grep -rn 'Information\.Code\|Information\.\(exited\|killed\|dumped\|trapped\|stopped\|continued\)' "$dir" --include='*.swift' ...; done

# (5) Indirect accessor patterns via .pointee or .cValue that would reference B's six accessors without naming the type
for dir in ...; do grep -rnE '\.(pointee|cValue)\.(signal|error|code|pid|uid|status)\b' "$dir" --include='*.swift' ...; done
```

**Output verbatim**:

```
# (1) Kernel.Signal.Information references
=== swift-linux-foundation ===
swift-linux-foundation/swift-linux-standard/Sources/Linux Kernel IO Uring Standard/Linux.Kernel.IO.Uring.Submission.Queue.Entry+Prepare.swift:1369:            info: UnsafeMutablePointer<Kernel.Signal.Information>,
=== swift-foundations ===
=== swift-iso ===

# (2) waitid callers
=== swift-linux-foundation === (no matches)
=== swift-foundations === (no matches)
=== swift-iso === (no matches)

# (3) Raw siginfo_t / si_* field access patterns
=== swift-linux-foundation === (no matches)
=== swift-foundations === (no matches)
=== swift-iso ===
swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel Signal/ISO 9945.Kernel.Signal.Action.Handler.swift:79:        ///     - `siginfo_t*`: Extended signal information (sender PID, etc.)
swift-iso/swift-iso-9945/Sources/ISO 9945 Kernel Signal/ISO 9945.Kernel.Signal.Action.Handler.swift:84:        case customInfo(@convention(c) (Int32, UnsafeMutablePointer<siginfo_t>?, UnsafeMutableRawPointer?) -> Void)

# (4) Information.Code and static-constant references
=== swift-linux-foundation === (no matches)
=== swift-foundations === (no matches)
=== swift-iso === (no matches)

# (5) Indirect accessor patterns via .pointee/.cValue
=== swift-linux-foundation === (no matches)
=== swift-foundations === (no matches)
=== swift-iso === (no matches)
```

**Per-accessor disposition**:

| Accessor | Consumers found | Disposition |
|----------|-----------------|-------------|
| `.signal: Int32` | 0 | Drop |
| `.error: Int32` | 0 | Drop |
| `.code: Code` | 0 | Drop |
| `.pid: Kernel.Process.ID` | 0 | Drop |
| `.uid: Kernel.User.ID` | 0 | Drop |
| `.status: Int32` | 0 | Drop |
| `Information.Code` (nested type) | 0 | **Migrate to iso-9945 anyway per Principal Decision 3** (POSIX-general `CLD_*` concept; migration is principled independent of consumer count; avoids bikeshedding) |
| `Information.Code` static constants (`.exited / .killed / …`) | 0 | Migrate with the `.Code` type (atomic move) |

**Type-level references**:

| Reference | Location | Disposition |
|-----------|----------|-------------|
| `UnsafeMutablePointer<Kernel.Signal.Information>` parameter on `waitid(info:)` | `swift-linux-foundation/swift-linux-standard/.../Linux.Kernel.IO.Uring.Submission.Queue.Entry+Prepare.swift:1369` | **Unchanged** — under Option A the name resolves unambiguously to the unified A with `init()` available; no consumer edit required. |
| `waitid(info:)` callers | none found across three repos | Informational: the function has zero callers. Not a P2.9 concern; flag as ecosystem observation. |

**Secondary observation (informational, not a disposition entry)**: the grep for raw `siginfo_t` / `si_*` field access returned only the two P2.3 #3 deferred-half surface sites at `ISO 9945.Kernel.Signal.Action.Handler.swift:79` (docstring) and `:84` (the `.customInfo` case signature `@convention(c) (Int32, UnsafeMutablePointer<siginfo_t>?, …) → Void`). These are the Swift-@objc-representability-blocked case-signature leak that Cycle 2 β' deferred. Orthogonal to P2.9; do not act.

**Disposition conclusion** (awaiting Principal confirmation):

- [x] **Drop-all** — minimal unification. Zero consumers of any B accessor (`.signal / .error / .code / .pid / .uid / .status`) across all three reachable repos. Zero consumers of `Information.Code` or its `CLD_*` static constants.
- [ ] ~~Port~~ — unused path; none of B's accessors require A's-pattern translation.

**Phase 1 scope confirmed**: only (a) `public init()` on A's existing struct and (b) `ISO 9945.Kernel.Signal.Information.Code.swift` (POSIX-general `.Code` type; CLD_* cases from B verbatim). Skip (c) — no `.errorCode / .code: Code / .senderUser / .childStatus` accessor additions needed.

## References

- Cycle 3 Phase 2 commit body `[SUPER-015]` #5 (swift-foundations/swift-posix `0bdc8b0`).
- Cycle 3 close reflection: `swift-institute/Research/Reflections/2026-04-24-cycle-3-close-and-inlinable-spi-cascade-non-fire.md` § Patterns → "Cross-cycle latent ambiguity from cycle-local gate scopes".
- Doc 3 ancestor: `swift-iso/swift-iso-9945/Research/signal-action-siginfo-l2-wrapper-design.md` (P2.3 #3 — iso-9945 Information landing).
- Tracker: `swift-institute/Audits/platform-compliance-2026-04-21.md` § Post-Cycle-3 Re-verification → P2.9.
- `[PLAT-ARCH-007]` — POSIX code belongs in ISO 9945.
- `[PLAT-ARCH-004]` — Platform root namespaces + `.Kernel` typealias chain.
- `[API-NAME-001a]` — Single-type-no-namespace (speculative namespace rule; relevant to future Darwin consumer of `Information.Storage`).
- `[API-NAME-004]` — No typealiases for type unification (rules out Option D).
