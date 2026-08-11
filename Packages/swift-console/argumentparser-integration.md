# ArgumentParser Integration

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
establishes that the console library should be "fully independent" from Apple's Swift
ArgumentParser — "no coupling, no convenience bridge, not even as a stretch goal."
This document provides the evidence base for that decision through a comprehensive
survey of how argument parsing and terminal interaction relate across ecosystems.

## Question

Should the console library have any dependency on, integration with, or awareness of
argument parsing? If so, at what layer?

Sub-questions:
1. Are argument parsing and terminal interaction fundamentally orthogonal?
2. What happens when libraries bundle both concerns?
3. Where does the "prompt for missing arguments" integration point belong?
4. Should a bridge package exist?

## Analysis

### Cross-Ecosystem Survey

| Ecosystem | Parser | Terminal | Integrated? | Outcome |
|-----------|--------|----------|:-----------:|---------|
| Rust | clap | console-rs (dialoguer, indicatif) | No | Gold standard separation |
| Python | Click/Typer | Built into Click | Yes | Elegant API, validation ordering bug |
| Node | Commander | Inquirer | No | Clean composition |
| Node | oclif | Minimal built-in + external | Partial | Trending toward separation |
| Go | Cobra | promptui | No | Clean composition |
| Kotlin | Clikt | Built into Clikt | Yes | Click-inspired, same tradeoffs |
| Swift | ArgumentParser | None built-in | N/A | GSoC interactive mode never merged |
| Swift | ConsoleKit | Bundled | Yes | **Deprecated parser, kept terminal** |
| Swift | N/A | Noora | No | Modern, independent, testable |

**7 of 9 ecosystems** treat them as independent. 2 integrate them (Click, Clikt). 1
bundled then unbundled (ConsoleKit).

### Case Study: Vapor ConsoleKit (Bundled → Unbundled)

ConsoleKit originally combined argument parsing, terminal output, interactive prompts,
progress indicators, and logging in a single package.

**Timeline**:
1. Split into `ConsoleKitTerminal` + `ConsoleKitCommands` + `ConsoleKit` umbrella
2. `ConsoleKitCommands` soft-deprecated in favor of ArgumentParser
3. Vapor Toolbox [rewritten](https://blog.vapor.codes/posts/toolbox-rewrite/) to use
   ArgumentParser, dropping ConsoleKit commands entirely
4. Vapor 5 ([PR #3403](https://github.com/vapor/vapor/pull/3403)) removed ConsoleKit
   commands, retained only ConsoleLogger

Quote from the Vapor blog: "ConsoleKit was developed before Swift Argument Parser was
introduced" and its "argument handling capabilities are now considered obsolete."

**Lesson**: Bundling argument parsing with terminal interaction creates upgrade friction.
When a better parser arrives, the library cannot be cleanly adopted without untangling.

### Case Study: Click's Integrated Model

Click embeds prompting directly in the argument parsing phase:

```python
@click.option('--name', prompt='Your name')
def hello(name): ...
```

**The appeal**: single declaration defines the flag and its interactive fallback.
Non-interactive compatibility is preserved.

**The failure**: [Click issue #1369](https://github.com/pallets/click/issues/1369) —
prompts fire during parameter processing, **before all arguments are validated**. Users
answer every prompt only to get an error about an unrelated invalid argument. The Click
maintainer confirmed this is fundamental to the architecture: "The order of processing
matters, because each parameter and command can affect the values that later processing
sees."

The recommended workaround is the same pattern used by every other ecosystem:
```python
@click.command()
@click.option('--name')
def cli(name):
    if name is None:
        name = click.prompt("Name")  # Prompt in command body, after validation
```

### Case Study: Swift ArgumentParser Interactive Mode (Never Merged)

A Google Summer of Code 2022 project ([#449](https://github.com/apple/swift-argument-parser/issues/449))
implemented interactive mode for ArgumentParser: `ask()`, `check()`, `choose()`, automatic
prompting for missing values, typo suggestions. A PR was opened January 2023 and **closed
without merging**. The feature remains on a `feature/interactive` branch.

This confirms Apple's own assessment: interactive prompting does not belong inside the
argument parser.

### Case Study: Rust clap — Explicit Rejection

clap has had multiple feature requests for built-in prompting
([#1471](https://github.com/clap-rs/clap/issues/1471),
[#1634](https://github.com/clap-rs/clap/issues/1634),
[#2570](https://github.com/clap-rs/clap/issues/2570)). The maintainer response has been
consistent: **prompts do not belong in clap**. They proposed a more general "hooks"
mechanism (`default_with`, `confirm_with` callbacks) that remains unimplemented.

### Execution Phase Analysis

The concerns map to different execution phases:

| Phase | Concern | Owner |
|-------|---------|-------|
| Pre-execution | Parse argv, validate structure, generate help | Argument parser |
| Execution | Read input, show progress, display output | Terminal interaction |
| Post-execution | Exit codes, error reporting | Both |

The one natural integration point is **prompting for missing required values**. But even
here, the Click experience shows that embedding prompts in the parsing phase creates
ordering problems.

The correct pattern (used by Rust, Go, Node, Swift/Noora):
```
1. Parse all arguments (fail fast on errors)
2. Check for missing values
3. Prompt interactively if TTY, error if not
```

### Coupling Analysis: Console Library Depending on ArgumentParser

If the console library took a dependency on ArgumentParser:
- **Build overhead**: All consumers compile ArgumentParser even if they don't use it
- **Version conflicts**: ArgumentParser 0.x to 1.x had breaking changes
- **Dependency lock-in**: Consumers using a different parser (or none) carry dead weight
- **This is the exact Vapor problem**: ConsoleKit's parser prevented clean ArgumentParser adoption

### The Bridge Package Pattern

The pattern used across ecosystems when integration is needed:

```
Layer 3: Console (terminal I/O, prompts, progress)
Layer 3: ArgumentParser (argument parsing)
Layer 4: Console.ArgumentParser (optional bridge)
```

Real-world examples:
- Rust `interactive-clap`: bridges clap with prompts via derive macros
- Swift Noora + ArgumentParser: optional `@Option` with fallback to Noora prompts

The bridge package would provide:
- `@Option` fallback-to-prompt extensions
- Styled help rendering using Console's output
- Entirely optional — consumers who want either library alone get it cleanly

### Integration Points Inventory

| Integration Point | Belongs At |
|---|---|
| Prompt for missing required arguments | Bridge package (L4) |
| Styled help output | Bridge package (L4) |
| Progress bars during execution | Console alone |
| Interactive command selection | Bridge package (L4) |
| Colored error messages | Console alone |
| Shell completion | ArgumentParser alone |

**Most terminal features need zero knowledge of argument parsing.** Only two points
genuinely require both: prompting for missing parsed values, and rendering help with
terminal styling.

### The CLI Guidelines

The [Command Line Interface Guidelines](https://clig.dev/) reinforces separation: "Only
use prompts or interactive elements if stdin is an interactive terminal (a TTY). Always
provide a way of passing input with flags or arguments." This positions prompts as a
conditional fallback, not a primary mechanism — meaning they belong in command execution,
not in the parser.

## Outcome

**Status**: DECISION

### No Dependency, No Coupling

The console library (`swift-console`) MUST NOT depend on ArgumentParser. The concerns
are fundamentally orthogonal:
- ArgumentParser is command *structure* (argv parsing, validation, help, completions)
- Console is terminal *interaction* (events, prompts, progress, styled output)

### Composition Pattern

The libraries compose trivially in application code without any bridge:

```swift
import ArgumentParser
import Console_Prompts

@main struct Deploy: ParsableCommand {
    @Option var environment: String?

    mutating func run() throws {
        let env = environment ?? Console.Prompt.Select(
            "Target environment?",
            options: ["staging", "production"]
        ).run()

        guard Console.Prompt.Confirm("Deploy to \(env)?").run() else { return }
        // proceed
    }
}
```

### Bridge Package — Layer 4, Not In Scope

If someone later wants:
- `@PromptOption` property wrapper for ArgumentParser integration
- Styled help rendering using Console
- Interactive subcommand selection

That is a Layer 4 Component concern. It would import both `Console Prompts` and
`ArgumentParser`, providing the integration without forcing either dependency on
consumers of the other.

### Rationale

The evidence is overwhelming:
1. 7/9 ecosystems keep them separate
2. Vapor bundled both, spent years unbundling
3. Click's integration has a fundamental validation ordering bug
4. Apple's own GSoC effort to add prompts to ArgumentParser was never merged
5. clap explicitly rejected prompting features
6. The composition pattern requires zero infrastructure

## References

- Vapor ConsoleKit: https://github.com/vapor/console-kit
- Vapor Toolbox rewrite: https://blog.vapor.codes/posts/toolbox-rewrite/
- Vapor PR #3403 (remove ConsoleKit): https://github.com/vapor/vapor/pull/3403
- Click issue #1369 (validation ordering): https://github.com/pallets/click/issues/1369
- ArgumentParser GSoC interactive mode: https://github.com/apple/swift-argument-parser/issues/449
- clap issue #1634 (prompts rejected): https://github.com/clap-rs/clap/issues/1634
- dialoguer (Rust): https://github.com/console-rs/dialoguer
- Noora (Swift): https://github.com/tuist/Noora
- interactive-clap (Rust): https://github.com/near-cli-rs/interactive-clap
- CLI Guidelines: https://clig.dev/
- Inquirer.js: https://github.com/SBoudrias/Inquirer.js
- promptui (Go): https://github.com/manifoldco/promptui
