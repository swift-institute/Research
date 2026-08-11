# Kitty Keyboard Protocol

<!--
---
version: 1.0.0
last_updated: 2026-03-03
status: DECISION
tier: 2
---
-->

## Context

The console library architecture ([console-library-architecture.md](console-library-architecture.md))
establishes that the Kitty keyboard protocol should be supported via "progressive
enhancement" — the `Terminal.Input.Key` type accommodates Kitty data from day one, but
the protocol is not required or default-enabled. This document provides the detailed
specification analysis, terminal support matrix, and type design rationale.

Legacy terminal input encoding has a fundamental problem: many key combinations produce
identical byte sequences. Tab and Ctrl+i both produce `0x09`. Enter and Ctrl+m both
produce `0x0D`. Escape and Ctrl+[ both produce `0x1B`. The Kitty keyboard protocol
(2021, by Kovid Goyal) solves this with a progressive enhancement model built on the
CSI u encoding from Paul Evans' fixterms proposal (2008).

## Question

How should the console library support the Kitty keyboard protocol? What type design
accommodates both legacy and enhanced terminals? What terminal support gaps affect the
default behavior?

Sub-questions:
1. Which enhancement flags to support?
2. What is the correct Key type design for dual-mode operation?
3. How to detect protocol support at runtime?
4. How does tmux interaction affect the design?

## Analysis

### The Five Progressive Enhancement Flags

| Bit | Value | Flag | Effect |
|-----|-------|------|--------|
| 1 | 1 | Disambiguate escape codes | Tab ≠ Ctrl+i, Enter ≠ Ctrl+m, Escape ≠ Ctrl+[. Keypad keys get dedicated codes. |
| 2 | 2 | Report event types | Adds repeat (`:2`) and release (`:3`) suffixes. Press is `:1` (omitted). |
| 4 | 4 | Report alternate keys | Sends shifted key and base-layout key. Critical for international keyboards. |
| 8 | 8 | Report all keys as escape codes | ALL keys produce CSI sequences, including plain `a`, `1`. Required for repeat/release on text keys. |
| 16 | 16 | Report associated text | Embeds Unicode codepoints of the text the key would produce. |

Flags are combinable via bitwise OR. The push/pop stack model (`CSI > flags u` / `CSI < n u`)
enables nested applications (shell → editor → file picker) to each manage their own
keyboard mode without interference. Separate stacks exist for main and alternate screens.

### CSI u Encoding

Key events are encoded as:
```
CSI unicode-key-code:shifted-key:base-layout-key ; modifiers:event-type ; text-as-codepoints u
```

Only the unicode-key-code is mandatory. All other components are omitted when they equal
default values.

Modifier encoding: transmitted value = 1 + (modifier bits). Shift=1, Alt=2, Ctrl=4,
Super=8, Hyper=16, Meta=32, CapsLock=64, NumLock=128. Example: Ctrl+Shift = 1+(4+1) = 6.

### Disambiguated Keys

With flag 1 enabled:

| Legacy byte | Previously ambiguous | Disambiguated |
|-------------|---------------------|---------------|
| `0x09` | Tab or Ctrl+i | Tab → `CSI 9 u`; Ctrl+i → `CSI 105 ; 5 u` |
| `0x0D` | Enter or Ctrl+m | Enter → `CSI 13 u`; Ctrl+m → `CSI 109 ; 5 u` |
| `0x1B` | Escape or Ctrl+[ | Escape → `CSI 27 u`; Ctrl+[ → `CSI 91 ; 5 u` |
| `0x7F` | Backspace or Ctrl+? | Backspace → `CSI 127 u` |

### Terminal Support Matrix (early 2026)

| Terminal | Full Kitty Protocol | Notes |
|----------|:------------------:|-------|
| Kitty | Yes | Reference implementation |
| Ghostty | Yes | All flags; macOS keybinding conflicts with Alt |
| foot | Yes | Matches Kitty closely |
| Alacritty (0.13+) | Yes | Minor encoding discrepancies being resolved |
| iTerm2 | Yes | Deprecated own CSI u in favor of Kitty |
| WezTerm | Partial | `enable_kitty_keyboard = true` (default false); alternate key incomplete |
| Rio | Yes | Enabled by default |
| VS Code terminal (1.109+) | Yes | Via xterm.js |
| Warp, Contour | Yes | — |
| **macOS Terminal.app** | **No** | No support whatsoever |
| **PuTTY** | **No** | — |
| **GNOME Terminal/VTE** | **No** | Patches under review |
| **Windows Terminal** | **No** | Issue filed |

| Multiplexer | Status |
|-------------|--------|
| tmux 3.2+ | Forwards CSI u with `extended-keys`; no full push/pop stack |
| Zellij 0.41+ | Enhancement level 1 |
| GNU Screen | Drops extended sequences |
| mosh | No support |

**Critical gap**: macOS Terminal.app has zero support and Apple shows no intent to add it.
Many macOS developers use Terminal.app as their default. This makes Kitty protocol
unsuitable as a required feature.

### Prior Art Survey

#### crossterm (Rust) — Unified KeyEvent

```rust
pub struct KeyEvent {
    pub code: KeyCode,
    pub modifiers: KeyModifiers,
    pub kind: KeyEventKind,      // Press, Repeat, Release
    pub state: KeyEventState,    // Extra Kitty-only state
}
```

A **single type for both legacy and Kitty modes**. `kind` defaults to `Press` when Kitty
is not active. Application code works against `KeyEvent` regardless of mode — Kitty just
populates more fields.

Supports 3 of 5 flags: disambiguate, report event types, report all keys. Does NOT yet
support alternate keys or associated text.

#### Bubbletea (Go) — Separate Message Types

```go
type Key struct {
    Text        string
    Mod         KeyMod
    Code        KeyCode
    ShiftedCode KeyCode   // Only with Kitty
    BaseCode    KeyCode   // Only with Kitty
    IsRepeat    bool      // Only with Kitty
}
```

Two message types: `KeyPressMsg` and `KeyReleaseMsg`, both implementing `KeyMsg`.
Release events are a distinct type — cannot accidentally match them.

#### Blessed (Python) — Context Manager

```python
with term.enable_kitty_keyboard(disambiguate=True, report_events=True):
    keystroke = term.inkey()
```

Graceful degradation: on unsupported terminals, the context manager does nothing and
keyboard input continues working normally.

### Key Type Design Patterns

| Pattern | Used By | Pros | Cons |
|---------|---------|------|------|
| Unified struct, optional fields | crossterm | One code path; legacy ignores extras | Some variants unreachable in legacy |
| Separate message types | Bubbletea | Release is distinct type | Two types to handle |
| Context manager + fallback | Blessed | Zero code changes for fallback | Python-specific |

### fixterms vs Kitty

The fixterms CSI u encoding (2008) is the **foundation** of Kitty. Kitty corrected errata,
added the push/pop stack, event types, alternate keys, associated text, and a detection
mechanism. The ecosystem has converged on Kitty's version. Implementing fixterms alone is
insufficient for modern applications.

| Feature | fixterms (2008) | Kitty (2021) |
|---------|:-:|:-:|
| Push/pop stack | No | Yes (per-screen) |
| Event types | Press only | Press, repeat, release |
| Alternate keys | No | Yes |
| Associated text | No | Yes |
| Detection | No | `CSI ? u` + DA1 probe |
| Super/Hyper/Meta | No | Yes |

## Outcome

**Status**: DECISION

### Type Design — Unified Struct (crossterm model)

```swift
Terminal.Input.Key (struct)
├── code: Terminal.Input.Key.Code       // Always present, same enum for both modes
├── modifiers: Terminal.Input.Key.Modifiers  // Always present (OptionSet)
├── text: String?                       // nil in legacy; populated with Kitty flag 16
└── kind: Terminal.Input.Key.Kind?      // nil in legacy; .press/.repeat/.release with Kitty flag 2

Terminal.Input.Key.Modifiers (OptionSet)
└── .shift, .control, .alt, .super, .hyper, .meta, .capsLock, .numLock
```

The unified struct with optional fields is correct for our design:
- Consumer code matches on `code` and `modifiers` — works in both modes
- `kind` is `nil` in legacy mode (consumers can treat nil as press)
- `text` is `nil` in legacy mode
- No separate press/release message types at the primitive level — the event enum
  already distinguishes `Terminal.Input.Event.key(Terminal.Input.Key)` from other
  event kinds

### Enhancement Flags Supported

Support all 5 flags. The parser maps each to the corresponding `Terminal.Input.Key` field:
- Flag 1 (disambiguate): affects `code` — more precise key identification
- Flag 2 (event types): populates `kind`
- Flag 4 (alternate keys): future extension (reserved field or separate accessor)
- Flag 8 (all keys as escape codes): affects which keys produce CSI u vs raw bytes
- Flag 16 (associated text): populates `text`

### Default Behavior

```swift
Console.Events.Stream(configuration: .init(keyboard: .legacy))  // default
Console.Events.Stream(configuration: .init(keyboard: .kitty))   // opt-in
Console.Events.Stream(configuration: .init(keyboard: .kitty(flags: [.disambiguate, .reportEventTypes])))
```

Legacy by default because:
1. macOS Terminal.app has zero Kitty support — our users are primarily macOS developers
2. tmux lacks full push/pop stack support
3. Legacy mode is universally compatible
4. The type design accommodates Kitty data without requiring the protocol

### Detection

When `.kitty` is requested, the event stream:
1. Sends `CSI ? u` (query current flags)
2. Sends DA1 (`CSI c`) as a sentinel
3. If the terminal responds to the query, push requested flags via `CSI > flags u`
4. If only DA1 responds (no query response), fall back to legacy silently
5. On cleanup, pop via `CSI < 1 u`

### Lifecycle

Kitty protocol uses the push/pop stack, which naturally integrates with our RAII pattern:
- `Console.Events.Stream` pushes flags on creation, pops on destruction
- Signal handlers pop the stack as part of terminal cleanup
- Separate stacks for main/alternate screen are handled by the terminal — transparent to us

## References

- Kitty Keyboard Protocol Specification: https://sw.kovidgoyal.net/kitty/keyboard-protocol/
- fixterms specification: http://www.leonerd.org.uk/hacks/fixterms/
- xterm modified keys: https://invisible-island.net/xterm/modified-keys.html
- crossterm KeyEvent: https://docs.rs/crossterm/latest/crossterm/event/struct.KeyEvent.html
- crossterm PushKeyboardEnhancementFlags: https://docs.rs/crossterm/latest/crossterm/event/struct.PushKeyboardEnhancementFlags.html
- Bubbletea key.go: https://github.com/charmbracelet/bubbletea/blob/main/key.go
- Blessed Kitty keyboard docs: https://blessed.readthedocs.io/en/latest/keyboard_kitty.html
- iTerm2 CSI u docs: https://iterm2.com/documentation-csiu.html
- tmux extended-keys: https://github.com/tmux/tmux/issues/3335
- Terminal keyboard protocol blog: https://blog.fsck.com/releases/2026/02/26/terminal-keyboard-protocol/
