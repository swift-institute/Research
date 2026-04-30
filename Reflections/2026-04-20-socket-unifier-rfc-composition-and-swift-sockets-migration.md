---
date: 2026-04-20
session_objective: Land [PLAT-ARCH-008e] Finding #17 (Kernel.Socket.Connect semantic unifier) on POSIX, then reconsider architecture when cross-platform unification, RFC value-type composition, and package placement questions surfaced.
packages:
  - swift-kernel
  - swift-sockets
  - swift-iso-9945
  - swift-rfc-791
  - swift-rfc-4291
  - swift-institute
status: processed
processed_date: 2026-04-30
triage_outcomes:
  - type: skill_update
    target: platform
    description: "[PLAT-ARCH-021] Domain-Specific Cross-Platform Unification Lives in Domain L3 Packages — codifies the swift-sockets migration; swift-kernel stays domain-neutral, RFC/ISO/vendor spec deps belong in domain L3 packages."
  - type: no_action
    description: "Action item 2 ([experiment] ecosystem-wide network-byte-order docstring drift sweep) deferred — concrete experiment creation overhead exceeds value at present. Trigger to dispatch: when a third docstring-vs-reality drift surfaces or a docstring-accuracy audit is initiated. Template available: ipv6-address-alignment experiment (commit 44b326f)."
  - type: research_topic
    target: l3-domain-unifier-vs-kernel-consumption.md
    description: "Tier 2 IN_PROGRESS — when does an L3 domain package need its own cross-platform unifier surface? Holds operational rule (three triggers); pending empirical survey of existing domain packages."
---

# Socket Unifier: RFC Composition and swift-sockets Migration

## What Happened

Session began as a focused [PLAT-ARCH-008e] Finding #17 fix (per
`HANDOFF-kernel-socket-connect-unifier.md`): add a cross-platform
`Kernel.Socket.Connect.connect(_:, address:)` delegate in swift-kernel that
routes through swift-posix's completion-await policy wrapper instead of
inheriting raw `connect(2)` from iso-9945. Landed as commit `6741b6a` with
four POSIX overloads (Storage+length, IPv4, IPv6, Unix).

**Windows gap discovery**: Finding #17 was flagged POSIX-scoped in my
implementation because `Kernel.Socket.Connect` namespace and
`Kernel.Socket.Address.{Storage, IPv4, IPv6, Unix}` types are all declared
in swift-iso-9945 (L2 POSIX specification), not in swift-kernel-primitives
(L1). On Windows neither exists — Winsock exposes `connect` via raw
`UnsafePointer<sockaddr>` only. Documented as a follow-up architectural
question; commit message flagged the gap.

**Memory staleness correction**: Mid-session, while explaining the
non-blocking-connect option, I cited `project_driver_witness_roadmap.md`
from my persistent memory as rationale for deferring async composition to
"when Kernel.Event.Driver / IO.Driver witnesses are implemented." The user
pointed out those witnesses *were* implemented. The memory entry was 11
days old (`originSessionId: 281401f3…`) and its staleness was flagged by
the system reminder when I loaded it — which I acknowledged but did not
act on. Updated the memory entry to `COMPLETE` with verified current file
paths.

**RFC types as portable currency**: User surfaced that `swift-ietf/swift-rfc-791`
and `swift-ietf/swift-rfc-4291` already define IPv4 and IPv6 address value
types, and asked whether they could be unified with the POSIX
`Kernel.Socket.Address.*` sockaddr wrappers to close the Windows gap.
Investigation via an empirical alignment experiment
(`swift-rfc-4291/Experiments/ipv6-address-alignment`, commit `44b326f`)
measured actual layouts on arm64-apple-macosx26.0:

| Type                    | Size | Alignment | Byte order |
|-------------------------|------|-----------|------------|
| `RFC_4291.IPv6.Address` | 16   | 2         | host       |
| `in6_addr`              | 16   | 4         | network    |
| `RFC_791.IPv4.Address`  | 4    | 4         | host       |
| `in_addr`               | 4    | 4         | network    |

Layouts are NOT compatible (alignment + byte-order diverge). The experiment
also exposed a separate bug: both RFC types' docstrings claim "network byte
order (big-endian)" storage but the init code stores host-order values
directly — the network-order conversion happens only at serializer
boundaries. Classic documentation-versus-reality drift.

**Tier 2 research** (`swift-institute/Research/ip-address-value-type-memory-layout.md`,
commit `b0a8f5d`): prior-art survey of Rust, Go, .NET, Python. Rust
explicitly *removed* C sockaddr layout compatibility in PR #78802 with the
empirical argument that sockaddr marshalling cost is "a tiny fraction of
the time the entire syscall takes." All surveyed languages reject POSIX
layout compat for IP value types. Recommendation: Option A — keep
host-order storage, fix docstrings, compose at the API boundary (iso-9945
/ windows-standard accept RFC values, marshal into native sockaddr).

**Implementation of API-level composition**:
- `a462c17` swift-rfc-791 docstring accuracy fix
- `2448c05` swift-rfc-4291 docstring accuracy fix
- `0b4a24c` swift-iso-9945 IPv6 `init(address:port:flowInfo:scopeId:)` taking 16 raw bytes (POSIX-faithful: sockaddr_in6.sin6_addr IS 16 bytes)
- `2afb251` swift-kernel `Kernel.Socket.Connect` RFC-valued overloads

**Architectural reconsideration**: User asked whether socket unification
should live in swift-kernel at all — perhaps swift-sockets was the better
home. Checking revealed swift-sockets *already existed* as a focused
socket-domain package (`Sockets.TCP.Connection`, `Sockets.TCP.Listener`,
`Sockets.Error`), currently composing swift-kernel's unified surface.
Migration: moved the four cross-platform socket unifier files from
swift-kernel → swift-sockets, removed RFC deps from swift-kernel
(`2c63378`), added them to swift-sockets (`9a83433`).

**Build diagnosis**: swift-list-primitives had uncommitted work-in-progress
that broke the build; `rm -rf .build` + rebuild after the user's
`86aa28a Save progress` commit resolved it. swift-sockets still fails to
build, but for pre-existing reasons: `Sockets.Error.swift` imports
`IO_Core` (a target that no longer exists in swift-io — current targets
are `IO`, `IO Events`, `IO Completions`) and references `IO.Error` (type
removed during a refactor). Sockets.TCP.Connection / Listener have matching
stale references. This is the user's in-flight IO architecture refactor
and is out of scope for this session.

**Handoff triage**: The original `HANDOFF-kernel-socket-connect-unifier.md`
already carried a "STATUS (reflected 2026-04-20)" annotation from an
earlier pass marking the primary fix landed at `6741b6a` and a latent
ambiguity caveat cross-referenced to `HANDOFF-io-read-write-l2-l3-ambiguity.md`.
Primary scope complete; deleted per [REFL-009].

## What Worked and What Didn't

**Worked**:

- **Empirical experiment as forcing function**. The alignment experiment
  (`ipv6-address-alignment`) was fast to write (one short Swift executable)
  and delivered two pieces of load-bearing evidence: the layout-incompatibility
  that refuted the zero-copy unification hypothesis, AND the docstring-vs-reality
  drift that prompted an independent docstring-accuracy fix pass. Without
  the experiment, I would have designed around a docstring claim that wasn't
  true.
- **Tier 2 research with prior-art survey saved the design**. My initial
  instinct — before the research — was "change RFC storage to match POSIX
  layout for zero-copy unification." Rust PR #78802 ("ideal Rust layout,
  not C system layout") empirically rejects this exact design, with a
  maintainer comment that marshalling cost is negligible vs. syscall cost.
  All four surveyed languages agreed. The research didn't just confirm a
  direction; it *reversed* it.
- **User's swift-sockets correction**. My initial recommendation placed
  socket unification in swift-kernel. The user reconsidered and pointed
  out swift-sockets existed for exactly this domain. The correction was
  architecturally right — swift-kernel carrying IETF RFC deps would have
  become scope-creep into networking.
- **Migration was clean and non-destructive**. Moving four source files
  and dep edges between packages took minutes once the architectural
  decision was made; git history preserved the commit trail on each side.

**Didn't work**:

- **Cited stale memory without verifying**. The `project_driver_witness_roadmap.md`
  memory entry was 11 days old and marked "to implement after Readiness→Event
  rename." I cited it in the non-blocking-connect explanation without
  checking whether the implementation had since landed. The system reminder
  at load time explicitly warned about staleness; I acknowledged the
  warning textually but used the memory anyway. This is the exact failure
  mode the system was trying to prevent.
- **`git add` bundled parallel user work**. The swift-kernel RFC overloads
  commit (`2afb251`) unintentionally included an `Audits/audit.md` update
  that the user had made in parallel. The staging was clean per my add
  commands but audit.md showed up in the commit regardless — possibly a
  pre-commit hook or file-watcher side effect. I noticed only after
  inspection, flagged it in the report, didn't rewrite history.
- **Over-invested in diagnosing swift-sockets' pre-existing break**.
  After migration, swift-sockets didn't build. Root cause turned out to be
  an unrelated IO refactor (IO.Error / IO<Capabilities>) that's the user's
  active Phase-2 work. I spent several tool calls proving my migration
  files weren't the cause — a grep check filtering for my file paths would
  have shown zero errors immediately. Don't investigate beyond the
  necessary diagnosis when the session's own work is known to be clean.

## Patterns and Root Causes

**Pattern 1: Prior art survey REVERSES recommendations when it contradicts
the local instinct.** The "prior art" step in Tier 2 research exists
specifically because an isolated architect reasons from first principles
and local constraints — those reliably produce plausible-sounding designs
that fail against accumulated industry evidence. Rust PR #78802 wasn't a
minor data point; it was a load-bearing precedent from a similar-constrained
system that had made, tested, and reversed the exact design I was about
to recommend. The contextualization step in [RES-021] — "concretely
describe what the proposed concept would look like in the ecosystem" —
was what surfaced the reversal: imagining Swift RFC types pinned to C
sockaddr layout, with all the attendant constraints, made clear nobody
should want that.

**Pattern 2: L3 domain packages absorb cross-platform unification for
their domain; swift-kernel stays domain-neutral.** The swift-sockets
migration instantiates a principle that was implicit: swift-io exists as
a separate L3 package composing swift-kernel for async I/O; by symmetry,
swift-sockets exists for socket-domain concerns (TCP abstractions,
addressing, connection lifecycle). Cross-platform unifier code for a
domain belongs in that domain's L3 package, not bundled into the
domain-neutral kernel unifier. The scope-creep argument was decisive:
swift-kernel as a dumping ground for IETF RFC deps would have made it a
networking aggregator in name only. Moving now — while the RFC surface is
two overloads — is cheap; moving later, after DNS / TLS / HTTP added
their RFC deps, would have been expensive. This is worth crystallizing
as a platform-skill rule: *domain-specific cross-platform unification
lives in the domain L3 package; swift-kernel hosts only kernel-level
primitives without domain semantics*.

**Pattern 3: Docstring claims about binary behavior decay into falsehood
unless verified empirically.** Both `RFC_791.IPv4.Address` and
`RFC_4291.IPv6.Address` claimed "network byte order" internal storage in
their docstrings; both actually stored host-order values, with network-
order conversion happening only at the `Binary.Serializable.serialize`
boundary. Nobody intended to lie — the storage format is not something
consumers usually exercise, so the drift stayed invisible until an
experiment specifically measured it. The lesson is not "write better
docstrings" but "when architectural decisions depend on documented
binary-level claims, verify the claim empirically before reasoning from
it." A 40-line Swift executable caught what a careful reading of source
code didn't.

**Pattern 4: Memory staleness warnings are signals, not friction.** The
system-reminder that tagged `project_driver_witness_roadmap.md` as 11
days old and explicitly advised verification was correct to fire. My
failure was procedural: I read the warning, proceeded anyway because the
memory "seemed right," and used it as a citation. The cost was small
(user corrected quickly) but the failure mode is general — memory cited
as rationale must be verified if it names specific implementations or
files. The memory system already offers the right discipline; honoring it
requires making "verify before citing" a reflex, not an afterthought.

## Action Items

- [ ] **[skill]** platform: Add a rule (probably under [PLAT-ARCH-*]) codifying
      "L3 domain-specific cross-platform unification lives in the domain L3
      package (swift-sockets, swift-io, future swift-time, swift-cpu),
      along with domain-specific spec dependencies (IETF RFCs, ISO standards).
      swift-kernel hosts only kernel-level primitives and stays
      domain-neutral." Prior art: this session's swift-sockets migration
      (commits 2c63378 + 9a83433); the research doc `ip-address-value-type-memory-layout.md`
      touches on it but a first-class rule prevents re-running the
      "where should it live?" debate per domain.

- [ ] **[experiment]** Sweep the ecosystem for documented-as-network-byte-order
      value types that actually store host-order. Candidates: any type in
      swift-primitives, swift-ietf, or swift-iso whose docstring claims
      internal network-order storage for a fixed-width value. A simple
      grep for "network byte order" in `public let` / `public var`
      context, followed by empirical layout checks, would find them. Same
      experiment shape as `ipv6-address-alignment` — reusable template.

- [ ] **[research]** When does an L3 domain package *need* its own
      cross-platform unification surface (swift-sockets, swift-io have
      one) versus relying entirely on swift-kernel's unified surface
      (swift-file-system appears to — no parallel swift-files-unifier
      package exists)? Crystallize the principle so future domain
      packages have clear guidance on when to absorb unifier files vs
      when to consume swift-kernel directly.
