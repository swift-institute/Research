# Q4 proposal — Foundation.Date replacement for the N5 certificates tree

Requires lead sign-off BEFORE landing (Q4 adjudication, Research 871b356).

## Proposal

Replace `Foundation.Date` with **`Instant` from `swift-primitives/swift-time-primitives`,
product/target `Time Primitive`** (12-byte value: `secondsSinceUnixEpoch: Int64`
+ `nanosecondFraction: Int32`; Sendable/Hashable/Comparable; typed-throws init;
Foundation-free L1).

## Why it fits

- The verifier needs exactly: (a) a UTC wall-clock instant decoded from
  UTCTime/GeneralizedTime (second precision — nanosecondFraction stays 0),
  (b) `Comparable` for the ExpiryPolicy window check, (c) an injected
  validation instant (fixtures pin it; production callers supply it — no
  system-clock read inside the verifier, matching the fixture-corpus design).
- The Wave-3 record's DAG already declares `Certificates -> RFC 5280 + ASN.1 +
  Byte/Time primitives` (record :215) — this selects the concrete Time
  primitive; no new edge shape.
- Upstream `TimeCalculations.swift` (civil y/m/d/h/m/s ↔ epoch seconds) is
  retained in-fork per Q5 (in-fork profile law until the L2 lane), retargeted
  from `Date` to `Instant`: the existing conversions already produce epoch
  seconds, so the swap is `Date(timeIntervalSince1970:)` →
  `Instant(secondsSinceUnixEpoch:)` at 6 sites in Time.swift/TimeCalculations,
  plus signature swaps in Certificate (notValidBefore/After), Validity,
  ExpiryPolicy (4), RFC5280Policy (3).

## Alternatives considered

- `swift-clock-primitives` — clock/monotonic domain; verification time is
  wall-clock evidence, not a clock read. Rejected.
- `swift-standards/swift-time-standard` (L2 Time Standard) — calendar/format
  law; heavier than the verifier's need, and the civil-time conversion the
  fork carries is RFC 5280 cutover law that transfers to the L2 5280 lane
  later, not general calendar law. Rejected for slice 1.
- Fork-local `Certificate.Instant` type — duplicates an existing L1 primitive;
  violates ecosystem-reuse ([IMPL-060]). Rejected.

## Consequence for the manifest

`swift-certificates` gains dep `swift-time-primitives` (path dep pre-publish,
canonical-URL marker per [swift-package] pre-publish rule), product
`Time Primitive`. Public API surfaces `Instant` (no Foundation type),
satisfying the N5 STOP "Foundation import in an Institute main target".
