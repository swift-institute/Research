# Swift Package Export for LLM Consumption

<!--
---
version: 1.0.0
last_updated: 2026-01-29
status: RECOMMENDATION
tier: 1
---
-->

## Context

A common workflow involves exporting Swift packages to single `.swift` files in `/tmp` for sharing with ChatGPT. Requirements:

1. Sources export must include `Package.swift` at the top
2. Tests should optionally be exported separately
3. Output must maximize ChatGPT's comprehension of the codebase
4. ChatGPT's context window limits (32K for Plus, 128K for some models) constrain design

**Trigger**: Recurring manual task that should be automated via a Claude Code skill.

## Question

What is the optimal format for exporting Swift packages to single files for LLM consumption?

---

## Analysis

### ChatGPT Context Window Constraints

| Model | Context Window | Output Limit |
|-------|----------------|--------------|
| GPT-4 (ChatGPT Plus) | 32,000 tokens | 4,096 tokens |
| GPT-4o | 128,000 tokens | 4,096 tokens |
| GPT-5 (Plus) | 32,000 tokens | 4,096 tokens |
| GPT-5 (API) | 272,000 input | 128,000 output |
| o3/o4-mini | 200,000 tokens | 100,000 tokens |

**Key insight**: ChatGPT always reserves ~750-900 tokens for system overhead. A "128K" model provides ~127K for actual content.

**Token estimation**: ~4 characters per token for code. A 50KB file ≈ 12,500 tokens.

### Prior Art Survey

| Tool | Key Feature | Format |
|------|-------------|--------|
| [code2prompt](https://github.com/mufeedvh/code2prompt) | Source tree + templating | Markdown/text |
| [codebase-dump](https://github.com/frogermcs/codebase-dump) | LLM-ready dumps | Markdown/text |
| [combicode](https://github.com/aaurelions/combicode) | System prompt + file tree priming | Text |
| [srcpack](https://dev.to/koistya/how-i-bundle-my-codebase-so-chatgpt-can-actually-understand-it-lp1) | Domain-based bundling | Plain text |

**Common patterns**:
1. File tree overview first
2. Clear file path headers
3. Separator between files
4. Respecting .gitignore

### Option A: Minimal Format

```swift
// === Package.swift ===
// swift-tools-version: 6.2
import PackageDescription
...

// === Sources/Module/Type.swift ===
...
```

**Advantages**:
- Minimal overhead
- Maximum content space
- Simple to generate

**Disadvantages**:
- No structural context
- LLM must infer organization

### Option B: Structured Markdown Format

````markdown
# Package: swift-test-primitives

## Package.swift
```swift
// swift-tools-version: 6.2
import PackageDescription
...
```

## File Tree
```
Sources/
  Test Primitives/
    Test.swift
    Test.Case.swift
    ...
```

## Sources

### Sources/Test Primitives/Test.swift
```swift
...
```
````

**Advantages**:
- Clear structure for LLM parsing
- File tree provides orientation
- GitHub-flavored markdown renders well

**Disadvantages**:
- Markdown overhead (~10-15% token cost)
- Requires markdown-aware copy/paste

### Option C: LLM-Optimized Structured Text

```
<package name="swift-test-primitives">

<manifest>
// swift-tools-version: 6.2
import PackageDescription
...
</manifest>

<file-tree>
Sources/
  Test Primitives/
    Test.swift
    Test.Case.swift
</file-tree>

<sources>

<file path="Sources/Test Primitives/Test.swift">
...
</file>

<file path="Sources/Test Primitives/Test.Case.swift">
...
</file>

</sources>

</package>
```

**Advantages**:
- XML-like tags are well-understood by LLMs
- Explicit structure aids parsing
- Clear boundaries between files
- Path attribute enables navigation references

**Disadvantages**:
- Tag overhead (~5-8% token cost)
- Less human-readable than markdown

### Option D: Hybrid Format (Recommended)

```
# swift-test-primitives

## Package Manifest

// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "swift-test-primitives",
    ...
)

## File Structure

Sources/
  Test Primitives/
    Test.swift
    Test.Case.swift
    Test.ID.swift
    ...

## Source Files

### File: Sources/Test Primitives/Test.swift

public enum Test {}

### File: Sources/Test Primitives/Test.Case.swift

extension Test {
    public struct Case { ... }
}

---

## Tests (optional separate export)

### File: Tests/Test Primitives Tests/Test.swift

@testable import Test_Primitives
...
```

**Advantages**:
- Human-readable structure
- Minimal overhead (~3-5%)
- Clear file boundaries with `### File:` prefix
- Section separator `---` between sources and tests
- Works in plain text contexts

**Disadvantages**:
- Slightly more verbose than Option A

---

## Comparison

| Criterion | A: Minimal | B: Markdown | C: XML-like | D: Hybrid |
|-----------|------------|-------------|-------------|-----------|
| Token efficiency | ★★★★★ | ★★★☆☆ | ★★★★☆ | ★★★★☆ |
| LLM comprehension | ★★☆☆☆ | ★★★★☆ | ★★★★★ | ★★★★☆ |
| Human readability | ★★★☆☆ | ★★★★★ | ★★☆☆☆ | ★★★★☆ |
| Copy-paste friendly | ★★★★★ | ★★★☆☆ | ★★★★☆ | ★★★★★ |
| Structure clarity | ★★☆☆☆ | ★★★★☆ | ★★★★★ | ★★★★☆ |

---

## Outcome

**Status**: RECOMMENDATION

**Decision**: Use **Option D: Hybrid Format** with the following structure:

### Export Format Specification

```
# {package-name}

## Package Manifest

{contents of Package.swift, raw, no code fence}

## File Structure

{tree output of Sources/ directory}

## Source Files

### File: {relative-path}

{file contents, raw}

### File: {next-relative-path}

{file contents, raw}
```

### Separate Tests Export (when requested)

```
# {package-name} Tests

## Test File Structure

{tree output of Tests/ directory}

## Test Files

### File: {relative-path}

{file contents, raw}
```

### Skill Implementation Notes

The skill should:

1. Accept a package path argument (defaults to current directory)
2. Detect package root by finding `Package.swift`
3. Generate file tree using `find` or similar
4. Concatenate files in deterministic order (alphabetical by path)
5. Output to `/tmp/{package-name}-sources.swift` (and optionally `/tmp/{package-name}-tests.swift`)
6. Report token estimate (character count / 4)
7. Warn if estimated tokens exceed 32K (ChatGPT Plus limit)

### File Ordering

Files should be ordered to maximize LLM comprehension:

1. Namespace root files first (e.g., `Test.swift` before `Test.Case.swift`)
2. Then alphabetically within each directory
3. This ensures LLMs see type definitions before extensions

### Exclusions

Exclude from export:
- `.build/` directory
- `Package.resolved`
- `.git/` directory
- `.DS_Store`
- Any files matching `.gitignore`

---

## References

- [ChatGPT Token Limits 2025](https://www.datastudios.org/post/chatgpt-token-limits-and-context-windows-updated-for-all-models-in-2025)
- [GPT-4.1 Context Improvements](https://openai.com/index/gpt-4-1/)
- [code2prompt](https://github.com/mufeedvh/code2prompt)
- [codebase-dump](https://github.com/frogermcs/codebase-dump)
- [Context is King (WorkOS)](https://workos.com/blog/context-is-king-tools-for-feeding-your-code-and-website-to-llms)
- [How I Bundle My Codebase for ChatGPT](https://dev.to/koistya/how-i-bundle-my-codebase-so-chatgpt-can-actually-understand-it-lp1)
