# Toolchain selection on a development machine

This document describes **machine-local configuration, not committed state.** Nothing here is
enforced by this repository, checked by `institute doctor`, or reproduced by cloning. It records
the convention a machine should be configured to, and — more importantly — how to answer the
question *"which toolchain produced this result?"* without guessing.

That question has been a live source of error. Treat the answer as something you measure, not
something you assume.

## The convention

**The system toolchain is the default.** An ordinary `swift` invocation uses whatever
`xcode-select` points at. Additional toolchains — release toolchains matching the CI gate,
development snapshots, toolchains carrying Embedded/Wasm support — stay installed and are
selected **explicitly, per invocation**.

The consequence that matters: `swift --version` gives the same answer in a login shell, a
non-login shell, and a script. If it does not, the machine is misconfigured — see
[Restoring the convention](#restoring-the-convention).

## Answering "which toolchain am I using"

```sh
swift --version
```

This is the authority. It works in every shell, needs no tooling, and reports the toolchain that
will actually compile. Prefer it to reasoning from `PATH`, from `which swift`, or from what a
previous session wrote down.

`which swift` is **not** a reliable proxy. If [swiftly](https://swiftlang.github.io/swiftly) is
installed, its shim directory sits ahead of `/usr/bin` on a login shell's `PATH`, so `which swift`
answers `~/.swiftly/bin/swift` while the shim forwards to the system toolchain. Different path,
same compiler. Only the version output distinguishes them.

If swiftly is installed, two further commands are useful:

```sh
swiftly use            # the selected toolchain, e.g. "xcode (default)"
swiftly use -p         # its absolute path
swiftly list           # every installed toolchain
```

These read swiftly's own configuration file and so give the same answer regardless of shell.

**When reporting a build result, quote `swift --version` output rather than a toolchain name.**
Names like "the snapshot" or "6.4" have collided repeatedly; version strings have not.

## Selecting a toolchain explicitly

### With swiftly (preferred, if installed)

```sh
swiftly run +6.3.3 swift build
swiftly run +main-snapshot-2026-07-11 swift build -c release
```

The `+<toolchain>` selector takes any name `swiftly list` prints. This is per-invocation and
leaves the default untouched.

### Without swiftly, via `TOOLCHAINS`

`xcrun` — and therefore `/usr/bin/swift`, `swiftc`, and `xcodebuild` — honours the `TOOLCHAINS`
environment variable:

```sh
TOOLCHAINS=org.swift.633202606251a swift build
```

**`TOOLCHAINS` must be given the toolchain's bundle identifier, not its directory name.** This is
a trap that has already cost time: an unrecognised value does **not** fail. It silently falls back
to the default toolchain and exits `0`, so a run you believe used 6.3.3 actually used the system
compiler and you get no signal.

```sh
# WRONG — silently uses the default toolchain, rc=0, no warning
TOOLCHAINS=swift-6.3.3-RELEASE swift --version

# RIGHT
TOOLCHAINS=org.swift.633202606251a swift --version
```

Read identifiers off disk rather than copying them from documentation — they encode a build date
and change with every snapshot:

```sh
for p in ~/Library/Developer/Toolchains/*.xctoolchain /Library/Developer/Toolchains/*.xctoolchain; do
  [ -e "$p" ] || continue
  printf '%s\t' "$(basename "$p")"
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$p/Info.plist"
done
```

Always confirm the selection took effect by running `swift --version` under the same environment
before trusting the build beneath it.

Note that `swift-latest.xctoolchain` is a symlink to whichever snapshot was installed most
recently, and shares that snapshot's bundle identifier. Selecting "latest" is selecting an
unnamed moving target; name the toolchain you mean.

### Full path

```sh
/Library/Developer/Toolchains/<name>.xctoolchain/usr/bin/swift build
```

Unambiguous, and works when nothing else is configured. Verbose, but it is the fallback that
cannot silently do something else.

**Use the real path, never a symlink to it.** A symlink pointing at a toolchain's `swift`
resolves back to the *default* toolchain and reports its version, exit 0, with no warning:

```sh
ln -s …/swift-6.3.3-RELEASE.xctoolchain/usr/bin/swift shim/swift
shim/swift --version     # reports 6.4 — the default toolchain, not the one named
```

Invoking the toolchain's own `usr/bin/swift` directly, or reaching it through `PATH`, reports
6.3.3 correctly. The driver locates its resources relative to the *resolved* executable, and a
symlink placed elsewhere resolves elsewhere.

This is the same fail-open class as `TOOLCHAINS`: the wrong answer is indistinguishable from
the right one, so nothing tells you the selection did not take. It is worth naming because it
defeats the very thing a fallback is for — the drill that found it lost a control to it, and
caught that only because the control failed to bite. Build a shim directory of symlinks to
pin a toolchain and you will silently measure the default.

## Why other toolchains stay installed

Do not "clean up" by uninstalling. Toolchains beyond the system one are load-bearing:

- A toolchain matching the version in `swift-tools-version` and the CI gate, for reproducing a
  CI result locally, and for isolating behaviour differences between it and the system compiler.
- A `main` development snapshot, for Embedded Swift and WebAssembly work — Embedded targets need
  a swift.org toolchain, and Xcode's clang has no WebAssembly backend.
- Branch snapshots, for confirming whether a defect reproduces on an unreleased compiler.

Removing one of these does not simplify the machine; it removes the only way to answer a question
someone is actively asking.

## Restoring the convention

If `swift --version` disagrees between a login and a non-login shell, something has put a
toolchain shim ahead of the system one on the login-shell `PATH`. Installing swiftly does this by
appending a line to `~/.zprofile`.

Prefer swiftly's own mechanism for stepping aside over editing shell startup files:

```sh
swiftly use --global-default xcode
```

`xcode` is a swiftly selector meaning "whatever `xcode-select` currently points at". After this,
the shim forwards to the system toolchain, both shell kinds report the same version, every
installed toolchain remains available through `swiftly run +<name>`, and `swiftly use` states the
default plainly. Verify:

```sh
zsh -l -c 'swift --version'   # login shell
zsh -f -c 'swift --version'   # no startup files at all
```

Both must print the same version. To point the default back at a swiftly toolchain, name it:
`swiftly use --global-default 6.3.3`.

Editing `~/.zprofile` to remove swiftly's `PATH` line also works, but it takes `swiftly` itself
off `PATH` along with the shim, so every explicit selection then needs a full path. Prefer the
command above.

## What this does not cover

`xcode-select`, Swift SDK (cross-compilation) installation, and the version in
`swift-tools-version` are separate concerns. In particular, **do not raise
`swift-tools-version` in a manifest to match a newer local compiler** — manifests are pinned to
what the gating CI container can parse, and a local toolchain change is not a reason to move them.
