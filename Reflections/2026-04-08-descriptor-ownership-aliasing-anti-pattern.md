---
date: 2026-04-08
session_objective: Implement Phase 4a of Path Type Compliance (L1 path decomposition + POSIX conformance) and bring the swift-iso-9945 test target back to a passing state
packages:
  - swift-path-primitives
  - swift-iso-9945
  - swift-kernel-primitives
status: processed
---

# Constructing ~Copyable Resource Wrappers from Raw Values Implies Ownership

## What Happened

Goal was Phase 4a of Path Type Compliance: add `Path.Protocol` (decomposition API) at L1, conform `Path.View` to it in `swift-iso-9945` (POSIX), then move on to Phase 4b. The L1 + POSIX work landed in 3 commits across 2 superrepos:

- `swift-path-primitives` commit `a96dddf` — `Path.Protocol` with **static requirements** + protocol extension defaults under `where Self: ~Copyable, Self: ~Escapable` with `@_lifetime(copy self)`. Added `Path.init(_ span: Span<Char>)`.
- `swift-iso-9945` commit `a90491b` — POSIX conformance file `ISO 9945.Kernel.Path.View+Path.Protocol.swift`.

Verification required running `swift test` on `swift-iso-9945`. The test target had pre-existing compile errors from accumulated API drift. Fixing them turned into a full session in itself, with three sub-commits:

- `1ed0c86` — 13 test files migrated to current APIs (Mode `OptionSet → struct`, `Process.ID` no longer Tagged, `Memory.Map.Region` `withUnsafeBytes` → `span` accessors, etc.)
- `b347108` — **Real production bug fixed**: `Kernel.Lock.Token.init` was doing `self.descriptor = Kernel.Descriptor(_rawValue: descriptor._rawValue)` to "alias" the caller's `borrowing` descriptor. With ~Copyable Descriptor and auto-closing deinit, both the caller's and Token's instances called `close()` on the same fd. The second close hit a stale/recycled fd, surfacing as a misleading `.contention` error from `Lock.Immediate.lock` (actually EBADF being mapped through a generic error initializer). Fixed by changing `Token.init` to take `consuming Kernel.Descriptor`. `withExclusive` and `withShared` propagate `consuming`. Tests restructured to consume their fds.
- `1c43b43` — **Three test files** were independently hitting the same anti-pattern. `isValidTrueForValid` constructed `Kernel.Descriptor(_rawValue: 0/1/2)` for stdin/stdout/stderr — closing the test process's own standard streams when the temporaries deinit'd. swift-testing then crashed mid-run. Three Terminal.Stream.Read tests had the same pattern via `Terminal.Stream.stdin.rawValue`. Fixed/disabled.
- `06b5f1d` — Audit at `swift-iso-9945/Research/audit.md` inventories 22 test regressions (8 DEFERRED, 4 OPEN, 10 RESOLVED).

After all this: **527 tests in 258 suites pass, zero issues**.

A branching investigation handoff was created to audit the same anti-pattern across the rest of the ecosystem. The investigation completed during the session and **confirmed 3 CRITICAL production bugs and 4 HIGH/MEDIUM groups** spanning 14 call sites:

- `ISO 9945.Terminal.Stream.Read.swift:30` (production twin of the disabled tests — closes stdin/stdout/stderr)
- `Linux.Kernel.IO.Uring.Submission.Queue.Entry.swift:90` (getter returns owning Descriptor wrapping borrowed cValue.fd)
- `IO.Completion.IOCP.swift:86` (consumed into registry that aliases Channel's owned fd)
- `ISO 9945.Kernel.Descriptor.Duplicate.swift:75` (dup2 result wraps a fd the caller still owns)
- `Kernel.Readiness.Driver+Epoll.swift` × 4 sites (temporary Descriptor in `ctl` calls — already noted as latent footgun in 2026-04-06 epoll reflection)
- `IO.Completion.IOUring.swift` × 4 sites (same temporary-Descriptor pattern in submitStorage `prepare.*` calls)

So the three instances I fixed in `swift-iso-9945` are not isolated — they are tip-of-iceberg evidence of an ecosystem-wide pattern. The fix is structural: any SPI that takes `borrowing Kernel.Descriptor` is at risk of being called with `Kernel.Descriptor(_rawValue: someInt32)` as a temporary, which then deinit-closes the upstream owner's fd at end of statement. The kqueue driver is the model — it exposes a `register(rawDescriptor: Int32)` SPI to avoid this entirely.

## What Worked and What Didn't

**Worked**:

- The Phase 4a experiment-validation pipeline was strong. The `escapable-protocol-cross-module` experiment had already validated the cross-module protocol pattern (6/7 variants). Updating it to test static requirements rather than instance requirements was a small delta — and it caught the missing `where Self: ~Copyable, Self: ~Escapable` extension clause before that landed in production. Writing the experiment first, then porting to production, reused the validation directly.
- The "challenge implementations" rule from `CLAUDE.md` mattered. When the user proposed `ISO 9945.Kernel.Path+Path.Protocol.swift` as the conformance filename (dropping `.View`), I pushed back because the conformance is on `Path.View` specifically. The user then confirmed `.View` should be in the filename. Rubber-stamping would have produced a misnamed file.
- Splitting the `Kernel.Lock.Integration Tests.swift` rewrite to a subagent worked. The mechanical pattern (open fresh fd inside each `@Test`, replace bare `fd` with `testFile.fd` then later with `try openLockTestFile(path)`) was tedious but repetitive. The subagent did 11 test functions in one shot with no quality loss.

**Didn't work, until corrected**:

- I went into "propose options A/B/C" mode multiple times when the user wanted execution. The "I don't understand why this is so hard?" pushback was the corrective. The pattern: when the immediate task is mechanical (8 broken test files, each fixable in ≤20 lines), staging a discussion around scope and approach is friction. The right move is to grab one file, fix it, move to the next.
- My first instinct for the Token fix was to store the raw `Int32` fd (with `~Escapable` for compile-time safety). The user rejected this with "we cannot use raw fd. fix the actual ownership transfer." I had to back up and take the consuming-ownership approach. The lesson: if a fix involves a special "internally store the raw value but it's safe because of X" pattern, the design is probably wrong.
- The `[IMPL-081]` deviation for `component`'s return type — I noted it during the skill pass, raised it with the user, who chose to defer. It's still in the open questions list. This is fine, but it's an unresolved discrepancy between our shipped code and a documented MUST rule.

## Patterns and Root Causes

**The construction-implies-ownership trap.** `Kernel.Descriptor` is a `~Copyable` resource type with an auto-closing `deinit`. The constructor `Kernel.Descriptor(_rawValue: someInt32)` looks like a trivial wrapper, but it claims ownership of the fd: when the temporary or stored Descriptor goes out of scope, its deinit calls `close()` on the raw value. **Three independent code patterns hit this in one session**:

1. `Kernel.Lock.Token` storing a fresh Descriptor "aliased" to the caller's fd → double-close → caller's fd becomes EBADF → misleading `.contention` error
2. `isValidTrueForValid` test constructing `Descriptor(_rawValue: 0/1/2)` → closes test process's stdin/stdout/stderr → swift-testing harness crashes
3. `Terminal.Stream.Read` tests constructing `Descriptor(_rawValue: Terminal.Stream.stdin.rawValue)` → same as #2

The pattern is: code that was written when `Kernel.Descriptor` was Copyable used the constructor as a lightweight wrapper. When `Descriptor` migrated to `~Copyable` with auto-close, every such call site became a fd close. Some closes were on aliased fds (Token) — silent corruption. Some closes were on well-known fds (the tests) — process-level damage.

The signal to look for: any call site that constructs `T(_rawValue:)` where `T` is `~Copyable` with a resource-releasing deinit, AND the raw value comes from somewhere other than a syscall return that the caller now owns. Those are bugs by construction.

Generalized: **`~Copyable` types with auto-releasing deinit cannot have public constructors that take raw resource handles unless the caller is transferring ownership.** The `_rawValue` argument label is supposed to signal SPI/internal use, but the underscore is too quiet. The constructor's existence (even as SPI) is a footgun for any code path that thinks of Descriptor as "just a wrapper around an Int32."

**The static-protocol-requirement + `where Self: ~Copyable, ~Escapable` discovery.** When defining an instance API as a default on a static-requirement protocol, the protocol extension MUST carry an explicit `where Self: ~Copyable, Self: ~Escapable` clause. Without it, the compiler treats `Self` as potentially Escapable in the extension's body and rejects `@_lifetime(copy self)` with the misleading error "cannot copy the lifetime of an Escapable type, use '@_lifetime(borrow self)' instead." The error message is wrong — `borrow` is not a fix, it's a different (more restrictive) semantic. The actual fix is the `where` clause.

This is the kind of thing nobody discovers until they hit it the first time. The cross-module experiment caught it, but only because we updated the experiment to use static requirements (the original used instance requirements, which sidestepped the issue). Worth a skill update so the next person trying the static-requirements-with-lifetime pattern doesn't have to re-derive it.

**Test-target compile gate not being enforced.** `swift-iso-9945` had eight test files with significant API drift, all from prior refactors that didn't update tests. Per `[TEST-027]`, the test target should be a commit gate — fixing test rot in the same commit that introduces the API change. The fact that this session had to fix it all retroactively, in scope unrelated to its actual task (Phase 4a), is exactly the failure mode `[TEST-027]` warns about. If the gate had been enforced at the original refactor sites, we'd have spent ~30 minutes per refactor instead of half a session retroactively.

**Plan-vs-execute friction.** I noticed I was laddering up to "let me present option A/B/C" when the immediate work was mechanical. The user's "I don't understand why this is so hard?" was a corrective. The pattern: when there are 8 broken files and each is fixable in ≤20 lines, the answer isn't "should we fix them all? what's the strategy?" — the answer is "fix file 1, run build, fix file 2, run build." Stopping to discuss approach is appropriate when there's a real design fork; mechanical fixes aren't a design fork.

## Action Items

- [ ] **[skill]** memory-safety: Add a rule covering "Constructing a ~Copyable resource type from a raw value implies ownership; the fix is structural, not API-additive." The Descriptor example is canonical: `Kernel.Descriptor(_rawValue: Int32)` claims the fd, deinit closes it. Any code that constructs such a wrapper around an fd it doesn't own causes double-close (aliasing an owned fd) or process-level damage (aliasing well-known fds 0/1/2). **Per `feedback_language_features_over_custom_types.md`**, the remediation MUST use Swift's existing language features: refactor callers to hold the actual owned Descriptor and pass `borrowing`, change `borrowing → consuming` for ownership transfer, remove computed accessors that lie about ownership. Do NOT propose `Raw`/`Borrow` shadow types or raw-Int overloads. Reference the three manifestations from this session, the ecosystem audit findings (`HANDOFF-descriptor-ownership-audit.md` — 7 anti-patterns, 14 call sites), and the `b347108` Token consuming fix as the canonical remediation example.

- [ ] **[skill]** implementation: Document that protocol extensions providing instance API defaults for `~Copyable, ~Escapable` protocols MUST carry `where Self: ~Copyable, Self: ~Escapable` for `@_lifetime(copy self)` to work. Without the clause, the compiler treats Self as potentially Escapable and rejects `copy` with a misleading error ("cannot copy the lifetime of an Escapable type, use '@_lifetime(borrow self)' instead" — the suggested `borrow` is a different and more restrictive semantic, not a fix). Validated in `swift-institute/Experiments/escapable-protocol-cross-module/`. Cross-reference [IMPL-023] (static requirements pattern).

- [ ] **[experiment]** Validate `static func component(of view: borrowing Self) -> Self` where `Self: ~Copyable, ~Escapable` in the cross-module experiment, to determine whether `[IMPL-081]` (null-termination-aware return type for suffix sub-views) can be satisfied for `Path.Protocol.component` without giving up the static-requirement design. If the pattern works, update `Path.Protocol` in Phase 4b.
