# Mouse Protocol Selection

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
establishes that mouse input is part of the `Terminal Input Primitives` module (L1) and
the `Console Events` module (L3). The architecture document resolved that mouse capture
should be "opt-in, disabled by default" but deferred the detailed protocol analysis:
which tracking modes to support, which encoding to use, how to handle terminal
multiplexers, and what the security implications are.

Mouse capture fundamentally changes terminal UX: it steals text selection, scroll wheel
control, and right-click context menus from the terminal emulator. Every implementation
surveyed treats this as an invasive mode change that requires explicit user/developer
consent.

## Question

What mouse tracking mode(s) and encoding(s) should the console library support, and
what should the default/opt-in behavior be?

Sub-questions:
1. Which tracking modes (X10, Normal, Button-event, Any-event)?
2. Which encoding modes (X10 default, UTF-8, SGR, URXVT, SGR-Pixels)?
3. Should the API offer granularity (e.g., clicks-only vs all-motion)?
4. What cleanup discipline is required?
5. How does mouse capture interact with tmux/screen?

## Analysis

### Tracking Modes

All modes use DECSET (`CSI ? Pm h`) to enable and DECRST (`CSI ? Pm l`) to disable.

| Mode | CSI | Name | Events Reported |
|------|-----|------|-----------------|
| 9 | `?9h` | X10 | Button press only (no release, no modifiers) |
| 1000 | `?1000h` | Normal/VT200 | Press + release + modifiers |
| 1002 | `?1002h` | Button-event | Press + release + drag motion |
| 1003 | `?1003h` | Any-event | Press + release + ALL motion (including hover) |

Mode 1001 (Hilite tracking) is rarely used and not implemented by modern libraries.

### Encoding Modes

Tracking and encoding are orthogonal — one tracking mode is combined with one encoding.

| Mode | CSI | Name | Format | Max Coord | Status |
|------|-----|------|--------|-----------|--------|
| (default) | — | X10 | `CSI M Cb Cx Cy` (bytes+32) | 223 | Legacy |
| 1005 | `?1005h` | UTF-8 | `CSI M Cb Cx Cy` (UTF-8) | 2015 | **Deprecated** — ambiguous, poor support |
| 1006 | `?1006h` | SGR | `CSI < Pb;Px;Py M/m` | Unlimited | **Recommended** — universal |
| 1015 | `?1015h` | URXVT | `CSI Pb;Px;Py M` | Unlimited | **Not recommended** — ambiguous with DL/SD |
| 1016 | `?1016h` | SGR-Pixels | Same as 1006, pixel coords | Unlimited | Niche — limited support |

SGR (1006) is the clear winner:
- No coordinate limit (decimal integers, 1-based)
- Unambiguous press (`M`) vs release (`m`) final character
- Reports actual button on release (X10 encoding loses this — always reports button=3)
- Clean parsing (semicolon-separated decimal integers)
- Universal support in modern terminals

### Prior Art Survey

| Library | Default | Tracking | Encoding | Granularity |
|---------|---------|----------|----------|-------------|
| crossterm (Rust) | OFF | 1003 (all-or-nothing) | SGR + URXVT | None |
| prompt_toolkit (Python) | OFF | 1003 | SGR + URXVT | None |
| Bubbletea (Go) | OFF | 1002 or 1003 (configurable) | SGR | Cell-motion vs all-motion |
| ratatui (Rust) | OFF | Delegates to crossterm | Delegates | Delegates |
| dialoguer (Rust) | N/A | None — keyboard only | N/A | N/A |
| indicatif (Rust) | N/A | None — output only | N/A | N/A |
| blessed (Node) | OFF | Auto-enable on mouse handler bind | X10/SGR/URXVT | allMotion option |

**Consensus**: Mouse OFF by default. SGR (1006) universally preferred. Most enable the
most aggressive tracking mode (1003) and provide no per-event-type filtering. Bubbletea
is the notable exception, offering cell-motion (1002) vs all-motion (1003) as a choice.

### UX Impact of Mouse Capture

When enabled:
1. **Text selection breaks** — terminal emulator no longer handles click-and-drag
2. **Copy/paste disrupted** — double-click/triple-click word/line select stops working
3. **Scroll wheel hijacked** — scroll goes to app, not terminal scrollback
4. **Shift bypass** — most terminals allow Shift+click to restore native selection

Ghostty introduces `XTSHIFTESCAPE` to let applications request Shift NOT be intercepted,
creating a potential conflict with the standard escape hatch.

### Terminal Multiplexer Interaction

**tmux**: Intercepts mouse events. With `set -g mouse on`, tmux handles pane selection,
resizing, and text selection. Supports SGR (1006) bidirectionally. tmux tracks mouse
state per-pane and informs the outer terminal when focus changes. `allow-passthrough`
(tmux 3.3+) affects escape sequence forwarding.

**GNU Screen**: Limited mouse support. Does not natively support SGR extended mode.
Applications inside screen are limited to X10/1000 with the 223-coordinate cap.

### Security Considerations

- Mouse capture itself is low-risk compared to other terminal escapes
- URXVT (1015) response format is ambiguous with DL/SD sequences — avoid
- State leakage on crash: if the app dies without disabling capture, the terminal
  remains in capture mode, generating garbage on stdin
- Cleanup discipline: always install signal handlers (SIGTERM, SIGINT, SIGHUP) to
  disable capture before exit; pair with alternate screen buffer where appropriate

### Passive Mouse Tracking (Future)

Contour Terminal proposes `CSI ? 2029 h` — "passive" mouse tracking where the terminal
continues handling text selection natively while also forwarding events to the application.
Not yet widely adopted but addresses the fundamental UX tension.

### Option Comparison

| Criterion | All-or-nothing (crossterm) | Configurable (Bubbletea) | Our proposed design |
|-----------|--------------------------|-------------------------|-------------------|
| Simplicity | High | Medium | Medium |
| Bandwidth control | None | Yes (1002 vs 1003) | Yes |
| API surface | Minimal | Slightly larger | Slightly larger |
| Prior art alignment | crossterm, prompt_toolkit | Bubbletea | Best of both |

## Outcome

**Status**: DECISION

### Protocol Selection

- **Encoding**: SGR (1006) only. No URXVT fallback (ambiguous), no UTF-8 (deprecated),
  no SGR-Pixels (too niche). If a terminal doesn't support SGR 1006, mouse events
  will fall back to X10 default encoding with its 223-coordinate limit — acceptable
  degradation for rare legacy terminals.
- **Tracking modes**: Support all three useful modes as an enum:
  - `.normal` — 1000 (click + release)
  - `.buttonEvent` — 1002 (click + release + drag)
  - `.anyEvent` — 1003 (click + release + all motion)
- **Default**: Disabled. Opt-in per `Console.Events.Configuration`.

### Enabling Sequence

When mouse is enabled, emit both the tracking mode and SGR encoding:
```
CSI ? {tracking} h    (1000, 1002, or 1003)
CSI ? 1006 h          (SGR encoding)
```

When disabling, reverse order:
```
CSI ? 1006 l
CSI ? {tracking} l
```

### API Design

```swift
Console.Events.Configuration.Mouse (enum)
├── .disabled                          // default
├── .normal                            // click + release (1000)
├── .buttonEvent                       // + drag (1002)
└── .anyEvent                          // + all motion (1003)
```

### Event Type (in Terminal Input Primitives)

```swift
Terminal.Input.Mouse (struct)
├── kind: Terminal.Input.Mouse.Kind
│   └── .press(Button), .release(Button), .move, .drag(Button),
│       .scrollUp, .scrollDown, .scrollLeft, .scrollRight
├── column: UInt16
├── row: UInt16
└── modifiers: Terminal.Input.Key.Modifiers

Terminal.Input.Mouse.Button (enum)
└── .left, .right, .middle, .backward, .forward
```

### Cleanup

- Signal handlers (SIGTERM, SIGINT, SIGHUP) MUST disable mouse capture before exit
- Pair with `Terminal.Mode.Raw.Token` (~Copyable) for RAII-style cleanup
- `Console.Events.Stream` manages the lifecycle automatically

### Rationale

The Bubbletea-style configurable tracking (over crossterm's all-or-nothing) gives
consumers control over bandwidth: a prompt widget only needs `.normal` (clicks), while
a TUI framework needs `.anyEvent` (all motion). SGR-only encoding avoids the URXVT
ambiguity problem that crossterm works around by sending both.

## References

- XTerm Control Sequences: https://invisible-island.net/xterm/ctlseqs/ctlseqs.html
- ESPTerm xterm reference: https://espterm.github.io/docs/espterm-xterm.html
- crossterm EnableMouseCapture: https://docs.rs/crossterm/latest/crossterm/event/struct.EnableMouseCapture.html
- crossterm Issue #640 (selective mouse): https://github.com/crossterm-rs/crossterm/issues/640
- Bubbletea mouse options: https://github.com/charmbracelet/bubbletea/blob/main/mouse.go
- prompt_toolkit Issue #168 (mouse breaks scrolling): https://github.com/prompt-toolkit/python-prompt-toolkit/issues/168
- Contour passive mouse tracking: https://github.com/contour-terminal/vt-extensions/blob/master/passive-mouse-tracking.md
- Ghostty XTSHIFTESCAPE: https://ghostty.org/docs/vt/csi/xtshiftescape
- tmux mouse FAQ: https://github.com/tmux/tmux/wiki/FAQ
