# Connect EINTR Investigation

## Status: OPEN

## Summary

EINTR on `connect()` does NOT mean "retry the call." It means the connection attempt is **in progress** and was interrupted before completion. This is fundamentally different from the retry-on-EINTR pattern used for read/write/accept.

## POSIX Semantics

Per IEEE 1003.1, when `connect()` returns EINTR:

1. The connection attempt is **not abandoned** — it continues asynchronously
2. Calling `connect()` again on the same socket returns `EALREADY`
3. The correct recovery is to **poll for completion**, not retry

## Correct Handling Pattern

```
connect() → EINTR
    ↓
poll(fd, POLLOUT) — wait for connection to complete
    ↓
getsockopt(fd, SOL_SOCKET, SO_ERROR) — check result
    ↓
error == 0 → connected
error != 0 → connection failed with that error
```

## Design Implications

- **Not a retry loop**: Cannot use the `while true { do { try connect() } catch where ... }` pattern
- **Needs poll infrastructure**: Requires `Kernel.Event.Poll` or equivalent at L2
- **Separate from EINTR wrappers**: This is a distinct design question, not part of the read/write/accept EINTR wrapper work
- **Non-blocking connect uses the same pattern**: Even without EINTR, non-blocking connect requires poll-based completion

## Recommendation

Design a `POSIX.Kernel.Socket.Connect` that handles both blocking+EINTR and non-blocking cases via poll-based completion. This depends on `ISO 9945 Kernel Poll` infrastructure.

## References

- POSIX connect(2): "If connect() is interrupted by a signal [...] the connection attempt shall not be aborted"
- Linux connect(2): "EINTR: The system call was interrupted by a signal that was caught"
- Session 2 handoff: identified this as a separate design question from EINTR retry
