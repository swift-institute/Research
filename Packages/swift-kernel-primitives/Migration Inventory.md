# swift-kernel-primitives Migration Inventory
<!--
---
version: 1.0.0
last_updated: 2026-01-15
status: RECOMMENDATION
---
-->

## Summary

- **Total files**: 224
- **OPS files** (contain syscalls, must move): 54
- **TYPES files** (pure types, stay): 170

---

## OPS Files (54) — Must Move

These files contain `Kernel.Syscall.require`, `Darwin.*`, `Glibc.*`, `WinSDK.*` calls.

### Core I/O (POSIX: `<unistd.h>`)
| File | POSIX Function | Destination |
|------|----------------|-------------|
| `Kernel.Close.swift` | `close()` | ISO_9945.Unistd |
| `Kernel.IO.Read.swift` | `read()` | ISO_9945.Unistd |
| `Kernel.IO.Write.swift` | `write()` | ISO_9945.Unistd |
| `Kernel.Seek.swift` | `lseek()` | ISO_9945.Unistd |
| `Kernel.Dup.swift` | `dup()`, `dup2()` | ISO_9945.Unistd |
| `Kernel.Pipe.swift` | `pipe()` | ISO_9945.Unistd |
| `Kernel.Sync.swift` | `fsync()`, `fdatasync()` | ISO_9945.Unistd |

### File Operations (POSIX: `<fcntl.h>`, `<sys/stat.h>`)
| File | POSIX Function | Destination |
|------|----------------|-------------|
| `Kernel.File.Open.swift` | `open()`, `openat()` | ISO_9945.Fcntl |
| `Kernel.File.Control.swift` | `fcntl()` | ISO_9945.Fcntl |
| `Kernel.File.Stats.swift` | (partial) | ISO_9945.Sys.Stat |
| `Kernel.File.Stats.Get.swift` | `stat()`, `fstat()`, `lstat()` | ISO_9945.Sys.Stat |
| `Kernel.File.Chmod.swift` | `chmod()`, `fchmod()` | ISO_9945.Sys.Stat |
| `Kernel.File.Chown.swift` | `chown()`, `fchown()` | ISO_9945.Unistd |
| `Kernel.File.Utimensat.swift` | `utimensat()` | ISO_9945.Sys.Stat |
| `Kernel.File.Clone.swift` | `clonefile()` (Darwin) | darwin-primitives |
| `Kernel.File.Direct.swift` | `fcntl(F_NOCACHE)` | ISO_9945.Fcntl |
| `Kernel.File.System.Stats.swift` | `statfs()`, `fstatfs()` | ISO_9945.Sys.Statvfs |
| `Kernel.File.Rename.swift` | `rename()`, `renameat()` | ISO_9945.Stdio |

### Directory Operations (POSIX: `<dirent.h>`, `<unistd.h>`)
| File | POSIX Function | Destination |
|------|----------------|-------------|
| `Kernel.Directory.swift` | `opendir()`, `readdir()`, `closedir()` | ISO_9945.Dirent |
| `Kernel.Directory.Working.swift` | `getcwd()`, `chdir()` | ISO_9945.Unistd |
| `Kernel.Mkdir.swift` | `mkdir()`, `mkdirat()` | ISO_9945.Sys.Stat |
| `Kernel.Rmdir.swift` | `rmdir()` | ISO_9945.Unistd |
| `Kernel.Unlink.swift` | `unlink()`, `unlinkat()` | ISO_9945.Unistd |
| `Kernel.Rename.swift` | `rename()` | ISO_9945.Stdio |
| `Kernel.Link.swift` | `link()`, `symlink()`, `readlink()` | ISO_9945.Unistd |
| `Kernel.Symlink.swift` | `symlink()`, `readlink()` | ISO_9945.Unistd |
| `Kernel.Path.Canonical.swift` | `realpath()` | ISO_9945.Stdlib |

### Memory Operations (POSIX: `<sys/mman.h>`)
| File | POSIX Function | Destination |
|------|----------------|-------------|
| `Kernel.Memory.Map.swift` | `mmap()`, `munmap()` | ISO_9945.Sys.Mman |
| `Kernel.Memory.Map.Anonymous.swift` | `mmap(MAP_ANONYMOUS)` | ISO_9945.Sys.Mman |
| `Kernel.Memory.Map.File.swift` | `mmap()` file-backed | ISO_9945.Sys.Mman |
| `Kernel.Memory.Shared.swift` | `shm_open()`, `shm_unlink()` | ISO_9945.Sys.Mman |
| `Kernel.Lock.swift` | `flock()` | ISO_9945.Sys.File |

### Socket Operations (POSIX: `<sys/socket.h>`)
| File | POSIX Function | Destination |
|------|----------------|-------------|
| `Kernel.Socket.swift` | `socket()`, `bind()`, `listen()`, `accept()`, `connect()` | ISO_9945.Sys.Socket |
| `Kernel.Socket.Shutdown.swift` | `shutdown()` | ISO_9945.Sys.Socket |
| `Kernel.Socket.Backlog.swift` | (uses SOMAXCONN) | ISO_9945.Sys.Socket |

### Process/Thread Operations (POSIX: `<pthread.h>`, `<unistd.h>`)
| File | POSIX Function | Destination |
|------|----------------|-------------|
| `Kernel.Thread.swift` | `pthread_create()`, `pthread_join()` | ISO_9945.Pthread |
| `Kernel.Thread.Handle.swift` | `pthread_self()` | ISO_9945.Pthread |
| `Kernel.Thread.Error.swift` | (errno mapping) | types-only or ISO_9945 |
| `Kernel.Thread.Affinity.Error.swift` | (errno mapping) | types-only |

### Environment (POSIX: `<stdlib.h>`)
| File | POSIX Function | Destination |
|------|----------------|-------------|
| `Kernel.Environment.swift` | `getenv()`, `setenv()`, `unsetenv()` | ISO_9945.Stdlib |

### Time/Clock (POSIX: `<time.h>`)
| File | POSIX Function | Destination |
|------|----------------|-------------|
| `Kernel.Clock.Continuous.swift` | `clock_gettime()` | ISO_9945.Time |
| `Kernel.Clock.Suspending.swift` | `clock_gettime()` | ISO_9945.Time |
| `Kernel.Time.swift` | `gettimeofday()`, `nanosleep()` | ISO_9945.Time |

### Event Descriptors (Mixed)
| File | POSIX Function | Destination |
|------|----------------|-------------|
| `Kernel.Event.Descriptor.swift` | `eventfd()` (Linux-specific) | linux-primitives |

### Console/TTY (POSIX: `<termios.h>`)
| File | POSIX Function | Destination |
|------|----------------|-------------|
| `Kernel.Console.Buffer+Query.swift` | Windows-specific | windows-primitives |
| `Kernel.Console.Mode+Get.swift` | `tcgetattr()` / Windows | split |
| `Kernel.Console.Mode+Set.swift` | `tcsetattr()` / Windows | split |
| `Kernel.Console.Error.swift` | (errno mapping) | types-only |

### Error Infrastructure
| File | POSIX Function | Destination |
|------|----------------|-------------|
| `Kernel.Error.swift` | `errno` access | ISO_9945 or ISO_9899 |
| `Kernel.Error.Code.swift` | `errno` constants | ISO_9945 or ISO_9899 |
| `Kernel.Error.Number.swift` | `errno` bridging | ISO_9945 or ISO_9899 |
| `Kernel.Syscall.swift` | syscall wrapper utility | ISO_9945 (internal) |

### Copy/Clone (Platform-specific)
| File | POSIX Function | Destination |
|------|----------------|-------------|
| `Kernel.Copy.Clone.swift` | `clonefile()` (Darwin), `copy_file_range()` (Linux) | platform-specific |

### Random (Platform-specific)
| File | POSIX Function | Destination |
|------|----------------|-------------|
| `Kernel.Random.swift` | `arc4random()`, `getrandom()` | platform-specific |

---

## TYPES Files (170) — Stay in swift-kernel-primitives

These files contain only type definitions, enums, protocols, error types.
No platform imports or syscalls.

### Core Types
- `Kernel.swift`
- `Kernel.Descriptor.swift`
- `Kernel.Descriptor.Validity.swift`
- `Kernel.Descriptor.Validity.Error.swift`
- `Kernel.Descriptor.Validity.Error.Limit.swift`

### Error Types (no syscalls)
- `Kernel.Close.Error.swift`
- `Kernel.IO.Error.swift`
- `Kernel.IO.Read.Error.swift`
- `Kernel.IO.Write.Error.swift`
- `Kernel.IO.Blocking.Error.swift`
- `Kernel.File.Open.Error.swift`
- `Kernel.File.Handle.Error.swift`
- `Kernel.File.Control.Error.swift`
- `Kernel.File.Clone.Error.swift`
- `Kernel.File.Clone.Error.Operation.swift`
- `Kernel.File.Clone.Error.Syscall.swift`
- `Kernel.File.Direct.Error.swift`
- `Kernel.File.Direct.Error.Operation.swift`
- `Kernel.File.Direct.Error.Syscall.swift`
- `Kernel.File.Stats.Error.swift`
- `Kernel.File.System.Stats.Error.swift`
- `Kernel.Memory.Error.swift`
- `Kernel.Memory.Lock.Error.swift`
- `Kernel.Memory.Map.Error.swift`
- `Kernel.Memory.Map.Error.Validation.swift`
- `Kernel.Memory.Shared.Error.swift`
- `Kernel.Lock.Error.swift`
- `Kernel.Socket.Error.swift`
- `Kernel.Socket.Shutdown.Error.swift`
- `Kernel.Pipe.Error.swift`
- `Kernel.Unlink.Error.swift`
- `Kernel.Permission.Error.swift`
- `Kernel.Storage.Error.swift`
- `Kernel.Path.Resolution.Error.swift`
- `Kernel.Path.Canonical.Error.swift`
- `Kernel.Directory.Working.Error.swift`
- `Kernel.Environment.Error.swift`
- `Kernel.Glob.Error.swift`
- `Kernel.Glob.Error.IO.swift`
- `Kernel.Glob.Error.Parse.swift`

### Option/Flag Types
- `Kernel.File.Open.Mode.swift`
- `Kernel.File.Open.Options.swift`
- `Kernel.File.Open.Blocking.swift`
- `Kernel.File.Open.Cache.swift`
- `Kernel.File.Open.Exec.swift`
- `Kernel.File.Open.Exec.Close.swift`
- `Kernel.File.Permissions.swift`
- `Kernel.File.Offset.swift`
- `Kernel.File.Size.swift`
- `Kernel.File.Clone.Behavior.swift`
- `Kernel.File.Clone.Capability.swift`
- `Kernel.File.Clone.Result.swift`
- `Kernel.File.Direct.Capability.swift`
- `Kernel.File.Direct.Mode.swift`
- `Kernel.File.Direct.Mode.Policy.swift`
- `Kernel.File.Direct.Mode.Resolved.swift`
- `Kernel.File.Direct.Requirements.swift`
- `Kernel.File.Direct.Requirements.Alignment.swift`
- `Kernel.File.Direct.Requirements.Alignment.Buffer.swift`
- `Kernel.File.Direct.Requirements.Alignment.Length.swift`
- `Kernel.File.Direct.Requirements.Alignment.Offset.swift`
- `Kernel.File.Direct.Requirements.Reason.swift`
- `Kernel.File.Stats.Kind.swift`
- `Kernel.File.Stats.Kind.Device.swift`
- `Kernel.File.Stats.Kind.Link.swift`
- `Kernel.File.System.Block.swift`
- `Kernel.File.System.File.swift`
- `Kernel.File.System.ID.swift`
- `Kernel.File.System.Kind.swift`
- `Kernel.File.System.Name.swift`
- `Kernel.Memory.Map.Advice.swift`
- `Kernel.Memory.Map.Flags.swift`
- `Kernel.Memory.Map.Protection.swift`
- `Kernel.Memory.Map.Region.swift`
- `Kernel.Memory.Map.Sync.swift`
- `Kernel.Memory.Map.Sync.Flags.swift`
- `Kernel.Memory.Shared.Access.swift`
- `Kernel.Memory.Shared.Options.swift`
- `Kernel.Memory.Lock.All.swift`
- `Kernel.Socket.Flags.swift`
- `Kernel.Socket.Descriptor.swift`
- `Kernel.Socket.Shutdown.How.swift`
- `Kernel.Lock.Acquire.swift`
- `Kernel.Lock.Kind.swift`
- `Kernel.Lock.Range.swift`
- `Kernel.Lock.Token.swift`
- `Kernel.Seek.Origin.swift`

### Value Types
- `Kernel.Device.swift`
- `Kernel.Inode.swift`
- `Kernel.User.swift`
- `Kernel.Group.swift`
- `Kernel.Process.swift`
- `Kernel.Memory.Address.swift`
- `Kernel.Memory.Page.swift`
- `Kernel.Memory.Space.swift`
- `Kernel.Path.swift`
- `Kernel.Path.String.swift`
- `Kernel.Path.Resolution.swift`
- `Kernel.System.Path.swift`
- `Kernel.System.Processor.swift`

### Namespace/Container Types
- `Kernel.File.swift`
- `Kernel.File.Handle.swift`
- `Kernel.File.Handle.Operation.swift`
- `Kernel.File.System.swift`
- `Kernel.IO.swift`
- `Kernel.IO.Blocking.swift`
- `Kernel.Memory.swift`
- `Kernel.Memory.Allocation.swift` (needs review - may have platform code)
- `Kernel.Memory.Lock.swift` (needs review)
- `Kernel.Socket.swift` (needs review - main file has syscalls)
- `Kernel.Console.swift`
- `Kernel.Console.Buffer.swift`
- `Kernel.Console.Handle.swift`
- `Kernel.Console.Mode.swift`
- `Kernel.Event.swift`
- `Kernel.Event.Counter.swift`
- `Kernel.Event.Flags.swift`
- `Kernel.Event.ID.swift`
- `Kernel.Event.Interest.swift`
- `Kernel.Event.Descriptor.Error.swift`
- `Kernel.Event.Descriptor.Flags.swift`
- `Kernel.Termios.swift`
- `Kernel.Termios.Attributes.swift`
- `Kernel.TTY.swift`
- `Kernel.TTY.Size.swift`
- `Kernel.TTY.isTTY.swift`
- `Kernel.Clock.swift`
- `Kernel.Time.Deadline.swift`
- `Kernel.Time.Deadline.Next.swift`
- `Kernel.Thread.Affinity.swift`
- `Kernel.Thread.Affinity.Kind.swift`
- `Kernel.Thread.Affinity.Support.swift`
- `Kernel.Thread.Affinity.Failure.swift`
- `Kernel.Thread.Condition.swift` (needs review - may have pthread calls)
- `Kernel.Thread.Mutex.swift` (needs review - may have pthread calls)
- `Kernel.Thread.Mutex.Value.swift`
- `Kernel.Thread.Yield.swift` (needs review)
- `Kernel.Interrupt.swift`
- `Kernel.Outcome.swift`
- `Kernel.Permission.swift`
- `Kernel.Storage.swift`
- `Kernel.String.swift`
- `Kernel.System.swift` (needs review)

### Atomic Types
- `Kernel.Atomic.swift`
- `Kernel.Atomic.Flag.swift`
- `Kernel.Atomic.Load.swift`
- `Kernel.Atomic.Load.Ordering.swift`
- `Kernel.Atomic.Store.swift`
- `Kernel.Atomic.Store.Ordering.swift`

### Glob Types
- `Kernel.Glob.swift`
- `Kernel.Glob.Atom.swift`
- `Kernel.Glob.Options.swift`
- `Kernel.Glob.Options.Dotfile.swift`
- `Kernel.Glob.Options.Error.swift`
- `Kernel.Glob.Options.Error.Policy.swift`
- `Kernel.Glob.Options.Ordering.swift`
- `Kernel.Glob.Pattern.swift`
- `Kernel.Glob.Scalar.swift`
- `Kernel.Glob.Scalar.Class.swift`
- `Kernel.Glob.Segment.swift`

### Environment Types
- `Kernel.Environment.Entry.swift`
- `Kernel.Environment.Entries.swift`

### Error Mapping (shared infrastructure)
- `Kernel.Error.Mapping.swift`

### Exports
- `Exports.swift`

---

## Decision Points

### 1. Errno Strategy
**Recommendation**: ISO_9945 depends on ISO_9899.Errno (reuse)
- Errno is C standard, not POSIX-specific
- Avoids duplicate errno worlds

### 2. Kernel.Descriptor Location
**Recommendation**: Stay in swift-kernel-primitives (types-only)
- ISO_9945 uses `Int32` fd at boundary
- swift-kernel (foundations) wraps in `Kernel.Descriptor`

### 3. Platform-Specific Files
Files like `Kernel.Event.Descriptor.swift` (eventfd), `Kernel.Copy.Clone.swift` (clonefile):
- Move to respective platform packages (linux-primitives, darwin-primitives)
- Not POSIX standard

### 4. Mixed POSIX/Windows Files
Files like `Kernel.Console.Mode+Get.swift`:
- Split: POSIX part → ISO_9945, Windows part → windows-primitives
- Or: Keep unified in swift-kernel (foundations)

---

## Phase 1 Priority: Minimal POSIX Surface

First batch to move to ISO_9945 (unblocks migration):

1. `ISO_9945.Unistd.close(_:)`
2. `ISO_9945.Unistd.read(_:into:count:)`
3. `ISO_9945.Unistd.write(_:from:count:)`
4. `ISO_9945.Unistd.lseek(_:offset:whence:)`
5. `ISO_9945.Fcntl.open(_:flags:mode:)`

These 5 syscalls cover the core I/O path and validate the architecture.
