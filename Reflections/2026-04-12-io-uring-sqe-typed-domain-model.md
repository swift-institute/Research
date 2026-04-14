---
date: 2026-04-12
session_objective: Restore @inlinable on 65 io_uring Prepare methods via typed SQE field accessors
packages:
  - swift-linux-standard
status: processed
---

# io_uring SQE Typed Domain Model — Design Convergence

## What Happened

Session began from a HANDOFF requesting @inlinable restoration on 65 io_uring Prepare methods. The underlying problem: Prepare method bodies referenced `internal var cValue: io_uring_sqe`, making them incompatible with @inlinable (which requires all referenced declarations to be public or @usableFromInline).

Three design iterations occurred before convergence:

1. **Mechanical C-field wrappers** (`_fd: Int32`, `_rawFlags: UInt32`) — reverted immediately. Named after C struct layout, not domain concepts. Violated [IMPL-INTENT] and [IMPL-002].

2. **Flat semantic accessors** (`spliceFlags: Kernel.Pipe.Splice.Options`, `socketDomain: Kernel.Socket.Address.Family`) — rejected after plan review. 42 compound-named accessors on Entry violated [API-NAME-002]. New types (Timeout.Options, Poll.Options) were good, but the accessor layer was still too low-level for an L2 spec wrapper.

3. **Pointer-backed view types on Prepare** — approved and implemented. 13 opcode-specific views (Splice, Socket, Buffer, Poll, Timeout, Futex, Xattr, Statx, Waitid, Epoll, Rename, Link, Message) with nonmutating set through the SQE pointer. Zero-copy, non-compound nested names (`splice.flags`, `socket.domain`), raw conversion absorbed inside opaque @usableFromInline bodies.

Final delivery: 65/65 @inlinable, 2 new OptionSet types, Target.none for fd=-1 sentinels, 13 view types, 15 single-field accessors on Entry. Build clean on swift:6.3.

Experiment `backtick-protocol-type-member` discovered that `Outer.\`Protocol\`(rawValue:)` fails in expression position (Swift 6.3 parser ambiguity). Fix: `.init(rawValue:)` implicit member expression.

## What Worked and What Didn't

**Worked well:**
- The pointer-backed view with nonmutating set pattern ([IMPL-071] applied to Copyable type through UnsafeMutablePointer) was the key architectural insight. Zero-copy writes, clean nesting, correct @inlinable chain.
- Creating Timeout.Options and Poll.Options as proper OptionSet types immediately simplified the computed-flag timeout/poll methods.
- Target.none replaced 10 scattered `cValue.fd = -1` writes with one semantic case.
- The experiment workflow quickly resolved the backtick-Protocol ambiguity.

**Didn't work:**
- First two design iterations wasted significant context. The progression from "thin wrappers" → "flat typed accessors" → "view types" was predictable in hindsight — the user's ecosystem has clear conventions that should have been applied from the start.
- The systematic fix phase (bash sed for imports, @usableFromInline placement) was error-prone. Four rebuild cycles were needed to resolve: missing CLinuxKernelShim imports, Sendable on pointer types, @usableFromInline at var vs accessor level, parameter name shadowing (buffer, futex).

## Patterns and Root Causes

**Design level matters more than accessor count.** The first iteration (42 accessors) and third iteration (13 views + 15 accessors) have similar total counts. The difference is architectural: views group semantically related fields under opcode namespaces, eliminating compound names and providing a natural home for pointer/descriptor conversion methods. The lesson: when wrapping a C union struct, the right abstraction level is per-opcode view types, not per-field accessors.

**Property.View doesn't cover all cases.** [IMPL-021] says "MUST NOT hand-roll accessor structs" and directs to Property.View. But Property.View is designed for ~Copyable bases with _read/_modify coroutines. The SQE case — Copyable value type accessed via UnsafeMutablePointer in shared ring buffer memory — requires a different mechanism (nonmutating set through pointer). This is a genuine gap in the Property infrastructure. The deviation is justified per [PATTERN-016] with a WHEN TO REMOVE clause.

**Parameter name shadowing is systematic.** `buffer`, `futex`, `flags`, `mask` appear as both method parameters and view accessor names. Every view accessor needs `self.` disambiguation when a Prepare method parameter happens to share the name. This affected 4 views (Buffer, Futex, and two others). A naming convention that avoids collision — or a lint — would prevent these.

## Action Items

- [ ] **[skill]** implementation: Add [IMPL-021] exception for pointer-backed views on Copyable types accessed via UnsafeMutablePointer — nonmutating set pattern distinct from _read/_modify coroutines
- [ ] **[experiment]** backtick-protocol-type-member: File Swift bug for `Outer.\`Protocol\`(rawValue:)` failing in expression position while working in type annotation position
- [ ] **[package]** swift-linux-standard: Remaining [IMPL-002] site — `openat` combines `access.rawValue | options.rawValue` into opFlags; could model as a combined OpenFlags type
