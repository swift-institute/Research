# ISO 9945 Kernel System Decomposition Investigation

Date: 2026-04-10

## Problem

`ISO 9945 Kernel System` groups four semantically distinct POSIX domains in a single target: Clock, Time, Random, and System Info (uname). Per [MOD-008], these should be evaluated for splitting.

## File Inventory

| File | Domain | L1 Dependency |
|------|--------|---------------|
| `ISO 9945.Kernel.Clock.swift` | Clock | Kernel Clock Primitives |
| `ISO 9945.Clock.Continuous.swift` | Clock | Clock Primitives |
| `ISO 9945.Kernel.Time.swift` | Time | Kernel Time Primitives |
| `ISO 9945.Kernel.Random.swift` | Random | Kernel Random Primitives |
| `ISO 9945.Kernel.System.swift` | System Info | Kernel System Primitives |
| `ISO 9945.Kernel.System.Name.swift` | System Info | Kernel System Primitives |
| `CPU.Atomic.Flag.swift` | Utility | (none specific) |

## MOD-008 Criteria

| Criterion | Result |
|-----------|--------|
| Different dependency sets | **YES** — Clock needs Clock+Time Primitives; System needs System Primitives; Random needs Random Primitives |
| Independent consumer value | **YES** — timer-only consumers shouldn't pull Random/uname |
| Depended-on by siblings | **WEAK** — only Lock depends on System.sleep() |
| Semantic independence | **YES** — Clock/Time = POSIX §2.8 (Timers); System = §2.9.2.1 (System Info) |

No types are shared between domains.

## Recommendation: Split into Three Targets

### 1. `ISO 9945 Kernel Clock` (2 files)
- `ISO 9945.Kernel.Clock.swift`
- `ISO 9945.Clock.Continuous.swift`
- Dependencies: `Kernel Clock Primitives`, `Clock Primitives`

### 2. `ISO 9945 Kernel Time` (1 file)
- `ISO 9945.Kernel.Time.swift`
- Dependencies: `Kernel Time Primitives`

### 3. `ISO 9945 Kernel System` (3-4 files, retains name)
- `ISO 9945.Kernel.System.swift`
- `ISO 9945.Kernel.System.Name.swift`
- `CPU.Atomic.Flag.swift`
- `ISO 9945.Kernel.Random.swift` (absorb here — one error alias, not worth its own target)
- Dependencies: `Kernel System Primitives`, `Kernel Random Primitives`

### Impact
- **Lock** target: change dep from monolithic System to granular System target (only needs `System.sleep`)
- **Umbrella**: add Clock, Time to dependency list alongside System
- **Downstream**: transparent if using umbrella import
- **Build parallelism**: three independent targets compile in parallel
