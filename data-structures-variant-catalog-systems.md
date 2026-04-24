# Variant Catalog: System Packages

Catalog of all public types in banned-umbrella packages with variant modules.

Generated: 2026-04-03

---

## 1. swift-kernel-primitives

22 variant modules + 1 umbrella + 4 C shim modules.

### Kernel Primitives Core

Module: `Kernel_Primitives_Core`
Re-exports: `Binary_Primitives`, `CPU_Primitives`, `Cardinal_Primitives`, `Dimension_Primitives`, `Time_Primitives`, `Error_Primitives`, `ASCII_Primitives`, `Memory_Primitives_Core`, platform arch primitives

| Type | Kind | File |
|------|------|------|
| `Kernel` | enum (namespace) | Kernel.swift |
| `Kernel.File` | enum (namespace) | Kernel.File.swift |
| `Kernel.File.Space` | enum (namespace) | Kernel.File.swift |
| `Kernel.File.Offset` | (extension) | Kernel.File.Offset.swift |
| `Kernel.File.Size` | (extension) | Kernel.File.Size.swift |
| `Kernel.Memory` | enum | Kernel.Memory.swift |

### Kernel Primitives (Umbrella)

Module: `Kernel_Primitives`
Re-exports all 22 variant modules (Kernel_String_Primitives is `internal import`).

No additional public types. Provides `Kernel.Event.ID` + Socket extension.

### Kernel Clock Primitives

Module: `Kernel_Clock_Primitives`

| Type | Kind |
|------|------|
| `Kernel.Clock` | enum (namespace) |
| `Kernel.Clock.Continuous` | enum (namespace) |
| `Kernel.Clock.Suspending` | enum (namespace) |

### Kernel Descriptor Primitives

Module: `Kernel_Descriptor_Primitives`

| Type | Kind |
|------|------|
| `Kernel.Descriptor` | struct (~Copyable, Sendable) |
| `Kernel.Descriptor.Duplicate` | enum (namespace) |
| `Kernel.Descriptor.Validity` | enum (namespace) |
| `Kernel.Descriptor.Validity.Error` | enum (Error) |
| `Kernel.Descriptor.Validity.Error.Limit` | enum |
| `Kernel.Close` | enum (namespace) |
| `Kernel.Close.Error` | enum (Error) |

### Kernel Environment Primitives

Module: `Kernel_Environment_Primitives`

| Type | Kind |
|------|------|
| `Kernel.Environment` | enum (namespace) |
| `Kernel.Environment.Entry` | struct (~Copyable, ~Escapable) |
| `Kernel.Environment.Entries` | (extension, iteration) |
| `Kernel.Environment.Error` | enum (Error) |
| `Kernel.Environment.Error.Invalid` | enum (Error) |

### Kernel Error Primitives

Module: `Kernel_Error_Primitives`

| Type | Kind |
|------|------|
| `Kernel.Error` | struct (Error, Sendable) |
| `Kernel.Error.Code` | enum (namespace) |
| `Kernel.Error.Code.POSIX` | enum (namespace, platform codes) |
| `Kernel.Error.Code.Windows` | enum (namespace, platform codes) |
| `Kernel.Error.Number` | (extension) |
| `Kernel.Error.Mapping` | (extension) |

### Kernel Event Primitives

Module: `Kernel_Event_Primitives`

| Type | Kind |
|------|------|
| `Kernel.Event` | struct (Sendable, Equatable) |
| `Kernel.Event.ID` | (Tagged<Kernel.Event, UInt>) |
| `Kernel.Event.Counter` | struct (RawRepresentable) |
| `Kernel.Event.Flags` | struct (OptionSet) |
| `Kernel.Event.Interest` | struct (OptionSet) |
| `Kernel.Event.Descriptor` | enum (namespace) |
| `Kernel.Event.Descriptor.Flags` | struct (Sendable) |
| `Kernel.Event.Descriptor.Error` | enum (Error) |

### Kernel File Primitives

Module: `Kernel_File_Primitives`

| Type | Kind |
|------|------|
| `Kernel.File.Descriptor` | (extension on Kernel.File) |
| `Kernel.File.Handle` | struct (~Copyable, Sendable) |
| `Kernel.File.Handle.Error` | enum (Error) |
| `Kernel.File.Handle.Operation` | enum |
| `Kernel.File.Open` | struct |
| `Kernel.File.Open.Error` | enum (Error) |
| `Kernel.File.Open.Blocking` | enum |
| `Kernel.File.Open.Cache` | enum |
| `Kernel.File.Open.Exec` | enum (namespace) |
| `Kernel.File.Open.Exec.Close` | enum |
| `Kernel.File.Permissions` | struct (RawRepresentable) |
| `Kernel.File.Attributes` | enum (namespace) |
| `Kernel.File.Stats` | struct (Sendable, Equatable) |
| `Kernel.File.Stats.Error` | enum (Error) |
| `Kernel.File.Stats.Kind` | struct (RawRepresentable) |
| `Kernel.File.Stats.Kind.Device` | struct (RawRepresentable) |
| `Kernel.File.Stats.Kind.Link` | enum |
| `Kernel.File.Seek` | enum (namespace) |
| `Kernel.File.Seek.Origin` | enum |
| `Kernel.File.Flush` | enum (namespace) |
| `Kernel.File.Rename` | enum (namespace) |
| `Kernel.File.Move` | enum (namespace) |
| `Kernel.File.Delete` | enum (namespace) |
| `Kernel.File.Chown` | enum (namespace) |
| `Kernel.File.Times` | enum (namespace) |
| `Kernel.File.Control` | enum (namespace) |
| `Kernel.File.Control.Error` | enum (Error) |
| `Kernel.File.Copy` | enum (namespace) |
| `Kernel.File.Copy.Error` | enum (Error) |
| `Kernel.File.Copy.Options` | struct (Sendable) |
| `Kernel.File.Clone` | enum (namespace) |
| `Kernel.File.Clone.Behavior` | enum |
| `Kernel.File.Clone.Capability` | enum |
| `Kernel.File.Clone.Result` | enum |
| `Kernel.File.Clone.Error` | enum (Error) |
| `Kernel.File.Clone.Error.Operation` | enum (Error) |
| `Kernel.File.Clone.Error.Syscall` | enum (Error) |
| `Kernel.File.Direct` | enum (namespace) |
| `Kernel.File.Direct.Capability` | enum |
| `Kernel.File.Direct.Mode` | enum (namespace) |
| `Kernel.File.Direct.Mode.Policy` | enum |
| `Kernel.File.Direct.Mode.Resolved` | enum |
| `Kernel.File.Direct.Error` | enum (Error) |
| `Kernel.File.Direct.Error.Operation` | enum (Error) |
| `Kernel.File.Direct.Error.Syscall` | enum (Error) |
| `Kernel.File.Direct.Requirements` | enum (namespace) |
| `Kernel.File.Direct.Requirements.Alignment` | struct (Sendable) |
| `Kernel.File.Direct.Requirements.Alignment.Buffer` | struct (Sendable) |
| `Kernel.File.Direct.Requirements.Alignment.Length` | struct (Sendable) |
| `Kernel.File.Direct.Requirements.Alignment.Offset` | struct (Sendable) |
| `Kernel.File.Direct.Requirements.Reason` | enum |
| `Kernel.File.System` | enum (namespace) |
| `Kernel.File.System.Stats` | struct (Sendable) |
| `Kernel.File.System.Stats.Error` | enum (Error) |
| `Kernel.File.System.Kind` | enum (Sendable) |
| `Kernel.File.System.Block` | enum (namespace) |
| `Kernel.File.System.File` | enum (namespace) |
| `Kernel.File.System.ID` | (extension) |
| `Kernel.File.System.Name` | enum (namespace) |
| `Kernel.Directory` | enum (namespace) |
| `Kernel.Directory.Create` | enum (namespace) |
| `Kernel.Directory.Remove` | enum (namespace) |
| `Kernel.Directory.Entry` | struct (Sendable) |
| `Kernel.Directory.Error` | enum (Error) |
| `Kernel.Directory.Working` | enum (namespace) |
| `Kernel.Directory.Working.Error` | enum (Error) |
| `Kernel.Device` | enum (Sendable) |
| `Kernel.Inode` | struct (RawRepresentable) |
| `Kernel.Link` | enum (namespace) |
| `Kernel.Link.Symbolic` | enum (namespace) |
| `Kernel.Lock` | enum (namespace) |
| `Kernel.Lock.Acquire` | enum |
| `Kernel.Lock.Error` | enum (Error) |
| `Kernel.Lock.Kind` | enum |
| `Kernel.Lock.Range` | enum (namespace) |
| `Kernel.Lock.Token` | (extension) |
| `Kernel.Pipe` | enum (namespace) |
| `Kernel.Pipe.Error` | enum (Error) |
| `Kernel.Storage` | enum (namespace) |
| `Kernel.Storage.Error` | enum (Error) |
| `Kernel.Copy` | enum (namespace) |
| `Kernel.Copy.Clone` | (extension) |
| `Kernel.Copy.Error` | enum (Error) |
| `Kernel.Copy.Range` | (extension) |
| `Kernel.IO.Blocking` | enum (namespace) |
| `Kernel.IO.Blocking.Error` | enum (Error) |
| `Kernel.IO.Read` | enum (namespace) |
| `Kernel.IO.Read.Error` | enum (Error) |
| `Kernel.IO.Write` | enum (namespace) |
| `Kernel.IO.Write.Error` | enum (Error) |

### Kernel Glob Primitives

Module: `Kernel_Glob_Primitives`

| Type | Kind |
|------|------|
| `Kernel.Glob` | enum (namespace) |
| `Kernel.Glob.Pattern` | struct (Sendable, Hashable) |
| `Kernel.Glob.Options` | struct (Sendable, Hashable) |
| `Kernel.Glob.Options.Dotfile` | enum |
| `Kernel.Glob.Options.Ordering` | enum |
| `Kernel.Glob.Options.Error` | enum (namespace) |
| `Kernel.Glob.Options.Error.Policy` | enum |
| `Kernel.Glob.Error` | enum (namespace, Error) |
| `Kernel.Glob.Error.IO` | enum (Error) |
| `Kernel.Glob.Error.Parse` | enum |
| `Kernel.Glob.Atom` | enum |
| `Kernel.Glob.Segment` | enum |
| `Kernel.Glob.Scalar` | enum (namespace) |
| `Kernel.Glob.Scalar.Class` | struct (Sendable, Hashable) |

### Kernel IO Primitives

Module: `Kernel_IO_Primitives`

| Type | Kind |
|------|------|
| `Kernel.IO` | enum (namespace) |
| `Kernel.IO.Error` | enum (Error) |

### Kernel Memory Primitives

Module: `Kernel_Memory_Primitives`

| Type | Kind |
|------|------|
| `Kernel.Memory.Address` | (Tagged<Kernel, Memory.Address>) |
| `Kernel.Memory.Allocation` | enum (namespace) |
| `Kernel.Memory.Error` | enum (Error) |
| `Kernel.Memory.Lock` | enum (namespace) |
| `Kernel.Memory.Lock.All` | enum (namespace) |
| `Kernel.Memory.Lock.Error` | enum (Error) |
| `Kernel.Memory.Page` | enum (namespace) |
| `Kernel.Memory.Map` | enum (namespace) |
| `Kernel.Memory.Map.Advice` | struct (Sendable) |
| `Kernel.Memory.Map.Flags` | struct (Sendable) |
| `Kernel.Memory.Map.Protection` | struct (Sendable, OptionSet-like) |
| `Kernel.Memory.Map.Region` | struct (Sendable) |
| `Kernel.Memory.Map.Anonymous` | enum (namespace) |
| `Kernel.Memory.Map.File` | enum (namespace) |
| `Kernel.Memory.Map.Error` | enum (Error) |
| `Kernel.Memory.Map.Error.Validation` | enum (Error) |
| `Kernel.Memory.Map.Sync` | enum (namespace) |
| `Kernel.Memory.Map.Sync.Flags` | struct (Sendable) |
| `Kernel.Memory.Shared` | enum (namespace) |
| `Kernel.Memory.Shared.Error` | enum (Error) |

### Kernel Outcome Primitives

Module: `Kernel_Outcome_Primitives`

| Type | Kind |
|------|------|
| `Kernel.Outcome<Failure>` | enum (Sendable) |
| `Kernel.Outcome.Value<Success>` | enum (Sendable) |
| `Kernel.Outcome.Value.GetError` | enum (Error) |
| `Kernel.Interrupt` | enum (Sendable, Hashable) |
| `Kernel.Interrupt.Thrown` | struct (Error) |

### Kernel Path Primitives

Module: `Kernel_Path_Primitives`

| Type | Kind |
|------|------|
| `Kernel.Path` | (extension, re-exports Path_Primitives) |
| `Path.Canonical.Error` | enum (Error) |
| `Path.Resolution.Error` | (extension) |

### Kernel Permission Primitives

Module: `Kernel_Permission_Primitives`

| Type | Kind |
|------|------|
| `Kernel.Permission` | enum (namespace) |
| `Kernel.Permission.Error` | enum (Error) |

### Kernel Process Primitives

Module: `Kernel_Process_Primitives`

| Type | Kind |
|------|------|
| `Kernel.Process` | enum (namespace) |
| `Kernel.Process.ID` | struct (RawRepresentable) |
| `Kernel.User` | enum (namespace, Tagged<Kernel.User, UInt32>) |
| `Kernel.Group` | enum (namespace, Tagged<Kernel.Group, UInt32>) |

### Kernel Random Primitives

Module: `Kernel_Random_Primitives`

| Type | Kind |
|------|------|
| `Kernel.Random` | enum (namespace) |
| `Kernel.Random.Error` | enum (Error) |

### Kernel Socket Primitives

Module: `Kernel_Socket_Primitives`

| Type | Kind |
|------|------|
| `Kernel.Socket` | enum (namespace) |
| `Kernel.Socket.Descriptor` | struct (~Copyable, Sendable) |
| `Kernel.Socket.Backlog` | struct (RawRepresentable) |
| `Kernel.Socket.Flags` | struct (OptionSet) |
| `Kernel.Socket.Error` | enum (Error) |
| `Kernel.Socket.Shutdown` | enum (namespace) |
| `Kernel.Socket.Shutdown.How` | enum (Int32) |
| `Kernel.Socket.Shutdown.Error` | enum (Error) |

### Kernel String Primitives

Module: `Kernel_String_Primitives` (internal to umbrella)

| Type | Kind |
|------|------|
| `Kernel.String` | typealias (Tagged<Kernel, String_Primitives.String>) |

### Kernel Syscall Primitives

Module: `Kernel_Syscall_Primitives`

| Type | Kind |
|------|------|
| `Kernel.Syscall` | enum (namespace) |
| `Kernel.Syscall.Rule<T>` | struct (Sendable) |

### Kernel System Primitives

Module: `Kernel_System_Primitives`

| Type | Kind |
|------|------|
| `Kernel.System` | enum (namespace) |
| `Kernel.System.Name` | struct (Sendable, Hashable) |
| `Kernel.System.Path` | enum (namespace) |
| `Kernel.System.Memory` | enum (namespace) |
| `Kernel.System.Processor` | enum (namespace) |
| `Kernel.System.Processor.Physical` | enum (namespace) |

### Kernel Terminal Primitives

Module: `Kernel_Terminal_Primitives`

| Type | Kind |
|------|------|
| `Kernel.Console` | enum (namespace) |
| `Kernel.Console.Buffer` | struct (Sendable, Hashable) |
| `Kernel.Console.Error` | struct (Error) |
| `Kernel.Console.Handle` | struct (Sendable, Hashable) |
| `Kernel.Console.Mode` | struct (RawRepresentable) |
| `Kernel.TTY` | enum (namespace) |
| `Kernel.TTY.Size` | struct (Sendable, Hashable) |
| `Kernel.Termios` | enum (namespace) |
| `Kernel.Termios.Attributes` | struct (Sendable) |
| `Kernel.Termios.Attributes.Storage` | struct (Sendable) |

### Kernel Thread Primitives

Module: `Kernel_Thread_Primitives`

| Type | Kind |
|------|------|
| `Kernel.Thread` | enum (namespace) |
| `Kernel.Thread.Handle` | (extension) |
| `Kernel.Thread.Error` | enum (Error) |
| `Kernel.Thread.Condition` | (extension) |
| `Kernel.Thread.Mutex` | (extension) |
| `Kernel.Thread.Yield` | (extension) |
| `Kernel.Thread.Affinity` | struct (Sendable) |
| `Kernel.Thread.Affinity.Error` | enum (Error) |
| `Kernel.Thread.Affinity.Kind` | enum |
| `Kernel.Thread.Affinity.Support` | enum |
| `Kernel.Thread.Affinity.Failure` | enum |

### Kernel Time Primitives

Module: `Kernel_Time_Primitives`

| Type | Kind |
|------|------|
| `Kernel.Time` | (extension on namespace) |
| `Kernel.Time.Deadline` | struct (Sendable, Hashable, Comparable) |
| `Kernel.Time.Deadline.Next` | (extension) |

### C Shim Modules (non-Swift, platform bridging)

- `CDarwinShim` -- C shim for macOS/Darwin
- `CLinuxShim` -- C shim for Linux
- `CPosixShim` -- C shim for POSIX
- `CWindowsShim` -- C shim for Windows

---

## 2. swift-async-primitives

11 variant modules + 1 umbrella.

### Async Primitives Core

Module: `Async_Primitives_Core`
Re-exports: `Buffer_Primitives`, `Queue_Primitives`, `Tagged_Primitives`

| Type | Kind |
|------|------|
| `Async` | enum (namespace) |
| `Async.Array` | enum (namespace) |
| `Async.Lifecycle` | enum (namespace) |
| `Async.Lifecycle.State` | enum (Sendable, Equatable) |
| `Async.Lifecycle.State.Shutdown` | struct (~Copyable, ~Escapable) |
| `Async.Precedence` | enum (namespace) |
| `Async.Callback<Value>` | struct |
| `Async.Continuation<T>` | struct (Sendable) |
| `Async.Continuation.Unsafe` | struct (Sendable) |

### Async Primitives (Umbrella)

Module: `Async_Primitives`
Re-exports all 11 variant modules.

No additional public types.

### Async Mutex Primitives

Module: `Async_Mutex_Primitives`

| Type | Kind |
|------|------|
| `Async.Mutex<Value: ~Copyable>` | struct (~Copyable) |
| `Async.Mutex.Locked` | struct (~Copyable) |

### Async Bridge Primitives

Module: `Async_Bridge_Primitives`

| Type | Kind |
|------|------|
| `Async.Bridge<Element: ~Copyable & Sendable>` | final class (Sendable) |

### Async Promise Primitives

Module: `Async_Promise_Primitives`

| Type | Kind |
|------|------|
| `Async.Promise<Value: Sendable>` | final class (Sendable) |
| `Async.Gate` | typealias (= `Async.Promise<Void>`) |

### Async Publication Primitives

Module: `Async_Publication_Primitives`

| Type | Kind |
|------|------|
| `Async.Publication<Value: Sendable>` | final class (Sendable) |

### Async Barrier Primitives

Module: `Async_Barrier_Primitives`

| Type | Kind |
|------|------|
| `Async.Barrier` | final class (Sendable) |

### Async Completion Primitives

Module: `Async_Completion_Primitives`

| Type | Kind |
|------|------|
| `Async.Completion<Success, Failure>` | final class (Sendable) |
| `Async.Completion.Error` | enum (Error) |
| `Async.Completion.State` | enum (UInt8, AtomicRepresentable) |
| `Async.Completion.Transition` | enum (namespace) |
| `Async.Completion.Transition.Error` | enum (Error) |

### Async Channel Primitives

Module: `Async_Channel_Primitives`

| Type | Kind |
|------|------|
| `Async.Channel<Element: ~Copyable>` | struct (namespace) |
| `Async.Channel.Error` | typealias (= `Async._ChannelError`) |
| `Async._ChannelError` | enum (Error) |
| `Async.Channel.Bounded` | struct (~Copyable, Sendable) |
| `Async.Channel.Bounded.Ends` | struct (~Copyable, Sendable) |
| `Async.Channel.Bounded.Sender` | struct (Sendable) |
| `Async.Channel.Bounded.Receiver` | struct (~Copyable, Sendable) |
| `Async.Channel.Bounded.Receiver.Receive` | struct (Sendable) |
| `Async.Channel.Bounded.Sender.Send` | struct (Sendable) |
| `Async.Channel.Bounded.Elements` | struct (AsyncSequence) |
| `Async.Channel.Bounded.Elements.Iterator` | struct (AsyncIteratorProtocol) |
| `Async.Channel.Bounded.Take` | struct (~Copyable, Sendable) |
| `Async.Channel.Unbounded` | struct (~Copyable, Sendable) |
| `Async.Channel.Unbounded.Ends` | struct (~Copyable, Sendable) |
| `Async.Channel.Unbounded.Sender` | struct (Sendable) |
| `Async.Channel.Unbounded.Receiver` | struct (~Copyable, Sendable) |
| `Async.Channel.Unbounded.Elements` | struct (AsyncSequence) |
| `Async.Channel.Unbounded.Elements.Iterator` | struct (AsyncIteratorProtocol) |
| `Async.Channel.Unbounded.Take` | struct (~Copyable, Sendable) |

### Async Broadcast Primitives

Module: `Async_Broadcast_Primitives`

| Type | Kind |
|------|------|
| `Async.Broadcast<Element: Sendable>` | final class (Sendable) |
| `Async.Broadcast.Error` | enum (Error) |
| `Async.Broadcast.Next` | enum (namespace) |
| `Async.Broadcast.Subscription` | struct (Sendable) |
| `Async.Broadcast.Subscription.AsyncIterator` | struct (AsyncIteratorProtocol) |

### Async Timer Primitives

Module: `Async_Timer_Primitives`

| Type | Kind |
|------|------|
| `Async.Timer` | enum (namespace) |
| `Async.Timer.Wheel<C: Clock>` | struct (~Copyable, Sendable) |
| `Async.Timer.Wheel.Config` | struct (Sendable, Hashable) |
| `Async.Timer.Wheel.Config.Level` | struct (Sendable) |
| `Async.Timer.Wheel.Config.Range` | struct (Sendable) |
| `Async.Timer.Wheel.Config.Slot` | struct (Sendable) |
| `Async.Timer.Wheel.Config.Ticks` | struct (Sendable) |
| `Async.Timer.Wheel.Entry` | struct (Sendable, Hashable) |
| `Async.Timer.Wheel.ID` | (extension) |
| `Async.Timer._Entry` | enum (namespace) |

### Async Waiter Primitives

Module: `Async_Waiter_Primitives`

| Type | Kind |
|------|------|
| `Async.Waiter` | enum (namespace) |
| `Async.Waiter.Entry<Outcome, Metadata>` | struct (~Copyable, Sendable) |
| `Async.Waiter.Flag` | final class (Sendable) |
| `Async.Waiter.Flag.Reason` | enum (Sendable) |
| `Async.Waiter.Resumption` | struct (~Copyable, Sendable) |
| `Async.Waiter.Queue` | enum (namespace) |
| `Async.Waiter.Queue.Bounded<Outcome, Metadata>` | typealias (= Queue<Entry>.Fixed) |
| `Async.Waiter.Queue.Unbounded<Outcome, Metadata>` | typealias (= Queue<Entry>) |
| `Async.Waiter.Queue.Drain<Element>` | typealias (= Queue<Element>) |
| `Async.Waiter.Queue.Flagged<Outcome, Metadata>` | struct (~Copyable, Sendable) |
| `Async.Waiter.Queue.Flagged.Split` | struct (~Copyable, Sendable) |
| `Async.Waiter.Queue.MetadataTag` | enum (phantom tag) |
| `Async.Waiter.Queue.Metadata` | typealias (= Tagged<MetadataTag, UInt64>) |

---

## 3. swift-graph-primitives

16 variant modules + 1 umbrella.

### Graph Primitives Core

Module: `Graph_Primitives_Core`
Re-exports: `Tagged_Primitives`, `Index_Primitives`, `Array_Primitives`

| Type | Kind |
|------|------|
| `Graph` | enum (namespace) |
| `Graph.Node<Tag>` | typealias (= `Index<Tag>`) |
| `Graph.Adjacency` | enum (namespace) |
| `Graph.Adjacency.List<Tag>` | struct (Sendable) |
| `Graph.Adjacency.Extract<Payload, Tag, Adjacent>` | struct |
| `Graph.Default` | enum (namespace) |
| `Graph.Default.Value<Payload>` | struct |
| `Graph.Remappable` | enum (namespace) |
| `Graph.Remappable.Remap<Payload, Tag, Adjacent>` | struct |
| `Graph.Traversal` | enum (namespace) |
| `Graph.Traversal.First` | enum (namespace) |
| `Graph.Sequential<Tag, Payload>` | struct (Sendable) |
| `Graph.Sequential.Builder` | struct (~Copyable) |
| `Graph.Sequential.Traverse` | struct (Sendable) |
| `Graph.Sequential.Analyze<Adjacent>` | struct |
| `Graph.Sequential.Path<Adjacent>` | struct |
| `Graph.Sequential.Reverse<Adjacent>` | struct |
| `Graph.Sequential.Transform` | struct |

### Graph Primitives (Umbrella)

Module: `Graph_Primitives`
Re-exports all 16 variant modules.

No additional public types.

### Graph DFS Primitives

Module: `Graph_DFS_Primitives`

| Type | Kind |
|------|------|
| `Graph.Traversal.First.Depth<Tag, Payload, Adjacent>` | struct (~Copyable, Iterator) |

### Graph BFS Primitives

Module: `Graph_BFS_Primitives`

| Type | Kind |
|------|------|
| `Graph.Traversal.First.Breadth<Tag, Payload, Adjacent>` | struct (~Copyable, Iterator) |

### Graph Topological Primitives

Module: `Graph_Topological_Primitives`

| Type | Kind |
|------|------|
| `Graph.Traversal.Topological<Tag, Payload, Adjacent>` | struct (Sequence) |

Extensions: `Graph.Sequential.Traverse.Topological` (methods).

### Graph Reachable Primitives

Module: `Graph_Reachable_Primitives`

No new types. Extensions: `Graph.Sequential.Analyze.reachable(from:)` methods.

### Graph Dead Primitives

Module: `Graph_Dead_Primitives`

No new types. Extensions: `Graph.Sequential.Analyze.dead(roots:)` methods.

### Graph SCC Primitives

Module: `Graph_SCC_Primitives`

No new types. Extensions: `Graph.Sequential.Analyze.stronglyConnectedComponents()` methods.

### Graph Cycles Primitives

Module: `Graph_Cycles_Primitives`

No new types. Extensions: `Graph.Sequential.Analyze.cycles()` methods.

### Graph Transitive Closure Primitives

Module: `Graph_Transitive_Closure_Primitives`

No new types. Extensions: `Graph.Sequential.Analyze.transitiveClosure()` methods.

### Graph Path Exists Primitives

Module: `Graph_Path_Exists_Primitives`

No new types. Extensions: `Graph.Sequential.Path.exists(from:to:)` methods.

### Graph Shortest Path Primitives

Module: `Graph_Shortest_Path_Primitives`

No new types. Extensions: `Graph.Sequential.Path.shortest(from:to:)` methods.

### Graph Weighted Path Primitives

Module: `Graph_Weighted_Path_Primitives`

No new types. Extensions: `Graph.Sequential.Path.weighted(from:to:)` methods.

### Graph Payload Map Primitives

Module: `Graph_Payload_Map_Primitives`

No new types. Extensions: `Graph.Sequential.Transform.payloads(mapping:)` methods.

### Graph Subgraph Primitives

Module: `Graph_Subgraph_Primitives`

No new types. Extensions: `Graph.Sequential.Transform.subgraph(keeping:)` methods.

### Graph Reverse Primitives

Module: `Graph_Reverse_Primitives`

No new types. Extensions: `Graph.Sequential.Reverse.graph()` methods.

### Graph Backward Reachable Primitives

Module: `Graph_Backward_Reachable_Primitives`

No new types. Extensions: `Graph.Sequential.Reverse.reachable(from:)` methods.

---

## 4. swift-ascii-parser-primitives

4 variant modules + 1 umbrella.

### ASCII Parser Primitives Core (internal)

Module: `ASCII_Parser_Primitives_Core`
Re-exports: `Parser_Primitives_Core`, `ASCII_Primitives`

No public types. Provides shared infrastructure for parser variants.

### ASCII Parser Primitives (Umbrella)

Module: `ASCII_Parser_Primitives`
Re-exports: `ASCII_Decimal_Parser_Primitives`, `ASCII_Hexadecimal_Parser_Primitives`, `Parseable_Integer_Primitives`

| Type | Kind |
|------|------|
| `ASCII.Parser` | enum (namespace) |

### ASCII Decimal Parser Primitives

Module: `ASCII_Decimal_Parser_Primitives`

| Type | Kind |
|------|------|
| `ASCII.Decimal.Error` | enum (Error) |
| `ASCII.Decimal.Parser<Input, T>` | struct (Sendable, Parser.Protocol) |

### ASCII Hexadecimal Parser Primitives

Module: `ASCII_Hexadecimal_Parser_Primitives`

| Type | Kind |
|------|------|
| `ASCII.Hexadecimal.Error` | enum (Error) |
| `ASCII.Hexadecimal.Parser<Input, T>` | struct (Sendable, Parser.Protocol) |

### Parseable Integer Primitives

Module: `Parseable_Integer_Primitives`

No new types. Retroactive conformance extensions:

| Extension | Conformance |
|-----------|-------------|
| `Int: Parseable` | @retroactive |
| `UInt: Parseable` | @retroactive |
| `Int8: Parseable` | @retroactive |
| `Int16: Parseable` | @retroactive |
| `Int32: Parseable` | @retroactive |
| `Int64: Parseable` | @retroactive |
| `UInt8: Parseable` | @retroactive |
| `UInt16: Parseable` | @retroactive |
| `UInt32: Parseable` | @retroactive |
| `UInt64: Parseable` | @retroactive |

---

## 5. swift-ascii-serializer-primitives

4 variant modules + 1 umbrella.

### ASCII Serializer Primitives Core (internal)

Module: `ASCII_Serializer_Primitives_Core`
Re-exports: `Serializer_Primitives_Core`, `ASCII_Primitives`

No public types. Provides shared infrastructure for serializer variants.

### ASCII Serializer Primitives (Umbrella)

Module: `ASCII_Serializer_Primitives`
Re-exports: `ASCII_Decimal_Serializer_Primitives`, `ASCII_Hexadecimal_Serializer_Primitives`, `Serializable_Integer_Primitives`

| Type | Kind |
|------|------|
| `ASCII.Serializer` | enum (namespace) |

### ASCII Decimal Serializer Primitives

Module: `ASCII_Decimal_Serializer_Primitives`

| Type | Kind |
|------|------|
| `ASCII.Decimal.Serializer<T>` | struct (Sendable, Serializer.Protocol) |

### ASCII Hexadecimal Serializer Primitives

Module: `ASCII_Hexadecimal_Serializer_Primitives`

| Type | Kind |
|------|------|
| `ASCII.Hexadecimal.Serializer<T>` | struct (Sendable, Serializer.Protocol) |

### Serializable Integer Primitives

Module: `Serializable_Integer_Primitives`

No new types. Retroactive conformance extensions:

| Extension | Conformance |
|-----------|-------------|
| `Int: Serializable` | @retroactive |
| `UInt: Serializable` | @retroactive |
| `Int8: Serializable` | @retroactive |
| `Int16: Serializable` | @retroactive |
| `Int32: Serializable` | @retroactive |
| `Int64: Serializable` | @retroactive |
| `UInt8: Serializable` | @retroactive |
| `UInt16: Serializable` | @retroactive |
| `UInt32: Serializable` | @retroactive |
| `UInt64: Serializable` | @retroactive |

---

## 6. swift-queue-primitives

7 variant modules + 1 umbrella.

### Queue Primitives Core (internal)

Module: `Queue_Primitives_Core`
Re-exports: `Index_Primitives`, `Input_Primitives`, `Collection_Primitives`, `List_Primitives`

| Type | Kind |
|------|------|
| `Queue<Element: ~Copyable>` | struct (~Copyable) |
| `Queue.Index` | (extension, position enum) |
| `Queue.Index.Position` | enum (Sendable, Equatable) |
| `Queue.Error` | enum (Error) |
| `Queue.Fixed` | struct (~Copyable) |
| `Queue.Fixed.Error` | enum (Error) |
| `Queue.Static<let capacity: Int>` | struct (~Copyable) |
| `Queue.Static.Error` | enum (Error) |
| `Queue.Small<let inlineCapacity: Int>` | struct (~Copyable) |
| `Queue.Linked` | struct (~Copyable) |
| `Queue.Linked.Error` | enum (Error) |
| `Queue.Linked.Fixed` | struct (~Copyable) |
| `Queue.Linked.Fixed.Error` | enum (Error) |
| `Queue.Linked.Inline<let capacity: Int>` | struct (~Copyable) |
| `Queue.Linked.Inline.Error` | enum (Error) |
| `Queue.Linked.Small<let inlineCapacity: Int>` | struct (~Copyable) |
| `Queue.Linked.Small.Error` | enum (Error) |
| `Queue.DoubleEnded` | struct (~Copyable) |
| `Queue.DoubleEnded.Error` | enum (Error) |
| `Queue.DoubleEnded.Fixed` | struct (~Copyable) |
| `Queue.DoubleEnded.Fixed.Error` | enum (Error) |
| `Queue.DoubleEnded.Static<let capacity: Int>` | struct (~Copyable) |
| `Queue.DoubleEnded.Static.Error` | enum (Error) |
| `Queue.DoubleEnded.Small<let inlineCapacity: Int>` | struct (~Copyable) |
| `Queue.DoubleEnded.Small.Error` | enum (Error) |

### Queue Primitives (Umbrella)

Module: `Queue_Primitives`
Re-exports: `Queue_Primitives_Core`, `Queue_Dynamic_Primitives`, `Queue_Fixed_Primitives`, `Queue_Static_Primitives`, `Queue_Small_Primitives`, `Queue_Linked_Primitives`, `Queue_DoubleEnded_Primitives`

No additional public types.

### Queue Dynamic Primitives (internal)

Module: `Queue_Dynamic_Primitives`

| Type | Kind |
|------|------|
| `Queue.Iterator` | struct (Sequence.Iterator.Protocol) |

Extensions: `Queue: Collection`, `Queue: BidirectionalCollection`, `Queue: RandomAccessCollection`, `Queue: Equatable`, `Queue: Hashable`, `Queue: ExpressibleByArrayLiteral`, `Queue: Input.Protocol`, `Queue: Input.Streaming`, `Queue: Sequence.Protocol`, `Queue: Sequence.Clearable`, `Queue: Sequence.Drain.Protocol`.

Provides `Queue` dynamic (growable) Copyable and ~Copyable API surface.

### Queue Fixed Primitives (internal)

Module: `Queue_Fixed_Primitives`

| Type | Kind |
|------|------|
| `Queue.Fixed.Iterator` | struct (Sequence.Iterator.Protocol) |
| `Queue.Bounded` | (extension alias pattern) |

Extensions: `Queue.Fixed: Input.Protocol`, `Queue.Fixed: Input.Streaming`, `Queue.Fixed: Sequence.Protocol`, `Queue.Fixed: Sequence.Clearable`, `Queue.Fixed: Sequence.Drain.Protocol`.

### Queue Static Primitives (internal)

Module: `Queue_Static_Primitives`

| Type | Kind |
|------|------|
| `Queue.Static.Iterator` | struct (Sequence.Iterator.Protocol) |

Extensions: `Queue.Static: Input.Protocol`, `Queue.Static: Input.Streaming`, `Queue.Static: Sequence.Protocol`, `Queue.Static: Sequence.Clearable`, `Queue.Static: Sequence.Drain.Protocol`.

### Queue Small Primitives (internal)

Module: `Queue_Small_Primitives`

| Type | Kind |
|------|------|
| `Queue.Small.Iterator` | struct (Sequence.Iterator.Protocol) |

Extensions: `Queue.Small: Input.Protocol`, `Queue.Small: Input.Streaming`, `Queue.Small: Sequence.Protocol`, `Queue.Small: Sequence.Clearable`, `Queue.Small: Sequence.Drain.Protocol`.

### Queue Linked Primitives (internal)

Module: `Queue_Linked_Primitives`

| Type | Kind |
|------|------|
| `Queue.Linked.Iterator` | struct (Sequence.Iterator.Protocol) |
| `Queue.Linked.Fixed.Iterator` | struct (Sequence.Iterator.Protocol) |

Extensions: `Queue.Linked: Sequence.Protocol`, `Queue.Linked: Sequence.Clearable`, `Queue.Linked: Sequence.Drain.Protocol`, `Queue.Linked: Equatable`, `Queue.Linked: Hashable`. Also `Queue.Linked.Fixed` Sequence, Equatable, Hashable conformances. `Queue.Linked.Inline` and `Queue.Linked.Small` Copyable-only API.

### Queue DoubleEnded Primitives / Deque

Module: `Queue_DoubleEnded_Primitives`

| Type | Kind |
|------|------|
| `Queue.DoubleEnded.Front` | enum (namespace, position accessor) |
| `Queue.DoubleEnded.Back` | enum (namespace, position accessor) |
| `Queue.DoubleEnded.PeekAccessor` | struct (Copyable read-only accessor) |
| `Queue.DoubleEnded.Iterator` | struct (Sequence.Iterator.Protocol) |
| `Queue.DoubleEnded.Fixed.Iterator` | struct (Sequence.Iterator.Protocol) |
| `Queue.DoubleEnded.Static.Iterator` | struct (Sequence.Iterator.Protocol) |
| `Queue.DoubleEnded.Small.Iterator` | struct (Sequence.Iterator.Protocol) |

Extensions: `Queue.DoubleEnded: Collection.Indexed`, `Queue.DoubleEnded: Collection.Bidirectional`, `Queue.DoubleEnded: Collection.Protocol`, `Queue.DoubleEnded: Collection.Access.Random`, `Queue.DoubleEnded: Swift.Collection`, `Queue.DoubleEnded: Swift.BidirectionalCollection`, `Queue.DoubleEnded: Swift.RandomAccessCollection`, `Queue.DoubleEnded: Sequence.Protocol`, `Queue.DoubleEnded: Sequence.Clearable`, `Queue.DoubleEnded: Sequence.Drain.Protocol`, `Queue.DoubleEnded: Equatable`, `Queue.DoubleEnded: Hashable`, `Queue.DoubleEnded: ExpressibleByArrayLiteral`.

Same suite of conformances for `Queue.DoubleEnded.Fixed`, `.Static`, `.Small` variants.

Property.View.Typed extensions for `Queue.DoubleEnded.Front` and `Queue.DoubleEnded.Back` provide ~Copyable-safe accessor patterns.

---

## Summary

| Package | Variant Modules | Total Public Types (approx.) |
|---------|----------------|------------------------------|
| swift-kernel-primitives | 22 + umbrella | ~200+ |
| swift-async-primitives | 11 + umbrella | ~60 |
| swift-graph-primitives | 16 + umbrella | ~20 (mostly extension-only algorithms) |
| swift-ascii-parser-primitives | 4 + umbrella | ~5 + 10 retroactive conformances |
| swift-ascii-serializer-primitives | 4 + umbrella | ~4 + 10 retroactive conformances |
| swift-queue-primitives | 7 + umbrella | ~30 |
