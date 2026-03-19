---
title: "Time API Naming: Literature Review"
version: 1.0.0
status: COMPLETE
last_updated: 2026-02-27
---

# Time API Naming: Literature Review

<!--
---
type: research
status: COMPLETE
created: 2026-02-27
scope: API naming patterns for unit conversion properties
---
-->

## Purpose

Survey academic and practitioner literature on API naming conventions for unit conversion properties, with emphasis on time duration APIs. This informs naming decisions for Swift Institute primitives and standards layers.

---

## 1. Academic Literature

### 1.1 Bloch — "How to Design a Good API and Why It Matters" (2006)

**Source**: Joshua Bloch, OOPSLA 2006 companion / Google Research.

Key principles relevant to unit conversion naming:

- **Names matter**: "Every API is a little language, and people must learn to read and write it. If you get an API right, code will read like prose."
- **Self-explanatory, consistent, symmetric**: The same word must mean the same thing throughout the API. Symmetry in naming (if you have `toSeconds`, the user expects `toMilliseconds`) reduces cognitive load.
- **Principle of least astonishment**: "Every method should do the least surprising thing it could, given its name." A property named `.seconds` on a multi-component duration is surprising if it returns only the seconds component rather than the total.
- **If names don't fall into place, redesign**: Difficulty naming is a design smell. When names fall into place naturally, the abstraction is correct.

**Effective Java naming conventions for conversion methods** (Bloch, Item 68):

| Prefix | Semantics | Example |
|--------|-----------|---------|
| `to` | Converts to independent object of different type | `toString()`, `toArray()` |
| `as` | Returns a live view of the same data | `asList()` |
| `get` | Retrieves a component or property | `getSeconds()` |

The `to`/`as` distinction is critical: `to` severs the connection (new independent value), `as` maintains a live link.

**Relevance**: A property like `.inSeconds` or `toSeconds()` is a `to`-style conversion (the Duration becomes a scalar). A property like `.seconds` on a composite is ambiguous — is it `get` (component) or `to` (total)?

### 1.2 Myers & Stylos — "Improving API Usability" (CACM, 2016)

**Source**: Brad A. Myers and Jeffrey Stylos, Communications of the ACM 59(6), pp. 62–69.

Key findings:

- **Naming drives discoverability**: "Trying to guess the names of classes and methods is the key way users search and browse for needed functionality." Names must align with the mental model of the caller, not the implementor.
- **Consistency over cleverness**: There is no correlation between the number of elements in an API and its usability, "as long as they had appropriate names and were well organized." Distinct prefixes for different method categories enable code-completion-driven discovery.
- **Factory pattern antipattern**: Empirical studies showed significant usability penalties when the factory pattern obscured how objects are acquired. Different object-acquisition-method names ("create", "new", "of", "from") create confusion. The lesson extends to conversion methods: inconsistent prefixes across an API harm usability.
- **Simplicity wins empirically**: Simplifying the API surface — fewer patterns to learn, more regular naming — consistently improves usability in controlled studies.

**Relevance**: A conversion API should use one consistent pattern. Mixing `.seconds` (bare noun), `.toSeconds()` (verb), and `.inSeconds` (prepositional) within the same API or ecosystem is empirically harmful.

### 1.3 Avidan & Feitelson — "Effects of Variable Names on Comprehension" (ICPC, 2017)

**Source**: E. Avidan and D.G. Feitelson, 25th International Conference on Program Comprehension.

Key findings from controlled experiment with 9 professional developers on 6 production methods:

- **Parameter names matter more than local variables** for comprehension.
- **Misleading names are worse than meaningless names**: Bad names actively mislead; single-letter names merely slow comprehension. A `.seconds` property that returns a component rather than total seconds is a misleading name.
- **Fully spelled names outperform abbreviations**: Perceived as more understandable and lead to faster comprehension times.

### 1.4 Feitelson et al. — "How Developers Choose Names" (IEEE TSE, 2022)

**Source**: Dror G. Feitelson, Ayelet Mizrahi, Nofar Noy, et al., IEEE Transactions on Software Engineering 48(1).

The study proposes a three-step cognitive model of naming:

1. **Select concepts** to include in the name
2. **Choose words** to represent each concept
3. **Construct a name** from those words

Key finding: The probability that two developers independently choose the same name is only 6.9% (median across 47 scenarios with 334 subjects). However, once a name is chosen, it is usually understood by the majority.

**Relevance**: This validates the importance of convention over intuition. Without an established convention, developers will produce wildly different names for the same concept. An API that establishes a clear pattern (e.g., `in` + unit) dramatically narrows the search space.

### 1.5 Schankin et al. — "Descriptive Compound Identifier Names Improve Source Code Comprehension" (ICPC, 2018)

**Source**: A. Schankin, A. Berger, D.V. Holt, J.C. Hofmeister, T. Riedel, M. Beigl, 26th International Conference on Program Comprehension.

Web-based study with 88 Java developers locating semantic defects:

- Developers using **descriptive compound identifiers** found defects ~14% faster than those using short identifiers.
- This effect was pronounced for **experienced developers** but not novices.
- The effect **disappeared for syntax errors** — descriptive names help only when deep semantic understanding is required.
- Developers with descriptive names spent more time on lines *before* the defect, suggesting better sequential comprehension.

**Relevance**: Compound names like `inWholeSeconds` or `totalSeconds` carry more semantic information than bare `seconds`. The empirical evidence supports descriptive naming for semantic comprehension tasks, which is exactly what unit conversion is.

---

## 2. Practitioner Literature

### 2.1 Casey Muratori — "Semantic Compression" (2014)

**Source**: https://caseymuratori.com/blog_0015

Core philosophy: Treat code like a dictionary compressor. Names should emerge from the problem domain, not from predetermined architectural schemes.

Key principles:

- **Domain-driven vocabulary**: Names become "the real 'language' of the problem" because "those things that are expressed most often are given their own names and are used consistently."
- **Make code usable before reusable**: Wait for at least two concrete instances before extracting shared abstractions.
- **Let implementation reveal structure**: The `Panel_Layout` abstraction in his example emerged from concrete button-drawing code, not from upfront design. Its methods (`push_button()`, `window_title()`, `complete()`) mirror the domain, not an architectural pattern.

**Relevance**: Muratori would likely argue that the naming pattern for "give me this duration as seconds" should mirror how practitioners actually think about the operation. Practitioners say "in seconds" or "as seconds" — they do not say "the seconds component of the two-part representation." The `components` accessor is implementor vocabulary; `inSeconds` is practitioner vocabulary.

### 2.2 Martin Fowler — "Fluent Interface" (2005, updated 2008)

**Source**: https://martinfowler.com/bliki/FluentInterface.html

Key principles:

- **DSL-like readability**: "The intent is to do something along the lines of an internal Domain Specific Language." API calls should read like domain prose.
- **Names may not make sense in isolation**: Methods like `with` "don't make much sense on their own" — their meaning emerges from the call chain. This is an accepted tradeoff.
- **True fluency is more than chaining**: "Many people seem to equate fluent interfaces with Method Chaining. Certainly chaining is a common technique to use with fluent interfaces, but true fluency is much more than that." Nested functions and object scoping are equally valid techniques.
- **Cost of fluency**: "The price of this fluency is more effort, both in thinking and in the API construction itself."

**Relevance**: A nested accessor pattern like `duration.in.seconds` is a fluent interface technique (object scoping), not just method chaining. Fowler explicitly endorses nested functions and scoping as valid fluency techniques. However, the tradeoff is implementation cost and the fact that intermediate objects (the `.in` accessor) may not make sense in isolation.

### 2.3 Stephen Colebourne — "Common Java Method Names" (2011)

**Source**: https://blog.joda.org/2011/08/common-java-method-names.html

Colebourne (author of Joda-Time and lead of JSR-310/java.time) codifies prefix semantics:

| Prefix | Semantics | Connection to original |
|--------|-----------|----------------------|
| `to` | Converts to independent object of another type | Severed — new independent value |
| `as` | Converts while maintaining live link | Maintained — view of same data |
| `get` | Retrieves component or property | Access — part of the object |
| `of` | Static factory, almost certain to succeed | N/A — construction |
| `from` | Static factory, loose conversion, may fail | N/A — construction |

**Relevance**: `toSeconds()` follows the `to` convention — it converts the Duration to an independent scalar. `getSeconds()` would imply accessing a stored component. The Java `Duration.toSeconds()` API correctly uses `to` because it performs a conversion, not component access.

### 2.4 Swift API Design Guidelines

**Source**: https://www.swift.org/documentation/api-design-guidelines/

Key principles:

- **Clarity at the point of use** is the most important goal.
- **Fluent usage**: "Prefer method and function names that make use sites form grammatical English phrases." E.g., `x.insert(y, at: z)` reads as "x, insert y at z."
- **Omit needless words**: Every word must convey salient information. But also: "Include all the words needed to avoid ambiguity."
- **Value-preserving conversions** use unlabeled `init`: `Int64(someUInt32)`.
- **Narrowing conversions** use descriptive labels: `init(truncating:)`, `init(saturating:)`.
- **Properties read as nouns**: Names of properties "should read as nouns."
- **Mutating/nonmutating distinction**: `x.sort()` vs `x.sorted()`, `y.formUnion(z)` vs `y.union(z)`.

**Gap**: The guidelines do not address the specific pattern of "property that returns the same value expressed in a different unit." This is neither a type conversion (same type, different scale) nor a component access (the value is the whole, not a part). It falls in an unaddressed naming gap.

---

## 3. Cross-Language Survey: Duration Conversion APIs

### 3.1 Comparison Table

| Language | Type | Pattern | Examples | Return type |
|----------|------|---------|----------|-------------|
| **Swift** | `Duration` | `components` tuple | `.components.seconds`, `.components.attoseconds` | `(Int64, Int64)` |
| **Kotlin** | `Duration` | `inWhole` + unit | `.inWholeSeconds`, `.inWholeMilliseconds` | `Long` |
| **Java** | `Duration` | `to` + unit | `.toSeconds()`, `.toMillis()`, `.toNanos()` | `long` |
| **Rust** | `Duration` | `as_` + unit | `.as_secs()`, `.as_millis()`, `.as_nanos()` | `u64` / `u128` |
| **Go** | `Duration` | bare unit name | `.Seconds()`, `.Milliseconds()`, `.Nanoseconds()` | `float64` / `int64` |
| **C#** | `TimeSpan` | `Total` + unit | `.TotalSeconds`, `.TotalMilliseconds` | `double` |
| **Python** | `timedelta` | `total_` + unit | `.total_seconds()` | `float` |

### 3.2 The Component vs Total Ambiguity

The most instructive design lesson comes from APIs that expose **both** component access and total conversion:

**C# TimeSpan**:
- `.Seconds` — returns only the seconds component (0-59)
- `.TotalSeconds` — returns the entire duration expressed in seconds

**Python timedelta**:
- `.seconds` — returns only the seconds component (0-86399)
- `.total_seconds()` — returns the entire duration in seconds

This ambiguity is a documented source of bugs. Python's documentation explicitly warns that `.seconds` vs `.total_seconds()` confusion is "a somewhat common bug." C#'s `Total` prefix exists precisely to disambiguate.

**Swift's SE-0329 resolution**: The Swift team explicitly rejected having both `.seconds` (component) and any `totalSeconds`-like property. Instead, they chose a single `components` accessor returning a tuple `(seconds: Int64, attoseconds: Int64)`. The naming evolution was:
1. Initially `.seconds` and `.nanoseconds` — rejected because `.nanoseconds` didn't round-trip and names collided with static factory methods
2. Then `.secondsPortion` and `.nanosecondsPortion` — debated suffixes ("Portion" vs "Slice" vs "Component")
3. Finally `.components` as a single tuple property — accepted because it makes the composite nature explicit

### 3.3 The Prefix Pattern Taxonomy

Across languages, four distinct prefix patterns emerge:

| Pattern | Languages | Semantics |
|---------|-----------|-----------|
| `to` + unit | Java | Conversion to independent value |
| `in` + unit | Kotlin | Expression of value in a unit |
| `as_` + unit | Rust | Reinterpretation / cast-like |
| `total` + unit | C#, Python | Disambiguate from component access |
| bare unit | Go | Implicit total conversion |

**The `in` pattern** (Kotlin) reads most naturally in English: "the duration *in* seconds." It maps directly to how practitioners describe the operation verbally. Kotlin further refines this with `inWhole` to signal truncation of fractional parts.

**The `to` pattern** (Java) follows Bloch/Colebourne's conversion semantics but reads less naturally as a property: `duration.toSeconds()` reads as a command ("convert to seconds") rather than a description ("the duration in seconds").

**The `as_` pattern** (Rust) follows Rust's general convention for cheap reinterpretation, distinct from `to_` (expensive conversion) and `into_` (consuming conversion).

**The `total` pattern** (C#, Python) exists solely to disambiguate from component access. It is defensive naming — necessary only when the API also exposes bare component properties.

---

## 4. The Nested Accessor Pattern

### 4.1 `duration.in.seconds` vs `duration.inSeconds`

The nested accessor pattern (`duration.in.seconds`) is a form of fluent interface design using object scoping. Evidence for and against:

**Arguments for nested accessors**:
- Fowler explicitly endorses "nested functions and object scoping" as valid fluency techniques beyond method chaining
- Avoids compound identifiers (`inSeconds`, `inWholeMilliseconds`), which grow unwieldy with longer unit names
- Creates a natural namespace: `duration.in.seconds`, `duration.in.milliseconds`, `duration.in.nanoseconds`
- Reads as grammatical English: "duration in seconds"
- Enables IDE discoverability: typing `duration.in.` reveals all available units

**Arguments against nested accessors**:
- Intermediate objects (the `In` type returned by `.in`) may not be meaningful in isolation — Fowler acknowledges this tradeoff
- Additional type machinery (the `In` struct/enum) increases API surface
- Schankin et al. (2018) found that descriptive compound names help experienced developers; splitting the compound across dots may reduce this benefit
- No empirical study directly compares `duration.in.seconds` vs `duration.inSeconds` for comprehension
- The bare `.in` conflicts with Swift's `in` keyword, requiring backtick escaping or alternative naming

**Arguments for compound identifiers** (`inSeconds`):
- Single token — greppable, refactorable, unambiguous in isolation
- Schankin et al.'s empirical evidence supports descriptive compound identifiers for comprehension
- Simpler type system — no intermediate accessor type needed
- Consistent with Kotlin's established `inWholeSeconds` pattern

### 4.2 Empirical Gap

No published study directly compares nested accessor patterns against compound identifier patterns for API usability. The evidence from Schankin et al. supports compound descriptive names, but their study compared short names vs long names, not flat vs nested access. The question of whether `duration.in.seconds` is cognitively equivalent to `duration.inSeconds` remains empirically unresolved.

---

## 5. SE-0329 Discussion: Duration API Design

### 5.1 Review Timeline

SE-0329 (Clock, Instant, and Duration) underwent four review cycles:
- **First review** (December 2021): Returned for revision. Major feedback on Duration representation.
- **Second review** (January 7, 2022): Extensive debate on component naming.
- **Third review** (January 24, 2022): Converged on `components` tuple.
- **Extended review** (February 2022): Final acceptance on February 14, 2022.

### 5.2 Key Design Decisions

**Rejection of bare `.seconds` / `.nanoseconds`**:
- Naming collision with static factory methods `.seconds(_:)` / `.nanoseconds(_:)`
- Semantic confusion: `.nanoseconds` returned only the sub-second portion, so `Duration(nanoseconds: x).nanoseconds` did not round-trip
- Violated principle of least astonishment

**The components approach**:
- Single property `var components: (seconds: Int64, attoseconds: Int64)` returns a named tuple
- Initializer: `init(secondsComponent: Int64, attosecondsComponent: Int64)`
- Makes the two-part representation explicit rather than hiding it behind individual properties
- Philippe Hausler noted this would likely be deprecated when Swift gains `Int128`

**Alternatives discussed in reviews**:
- `.secondsPortion` / `.nanosecondsPortion` — "Portion" suffix debated vs "Slice" vs "Component"
- `.secondsComponent` / `.nanosecondsPortion` — mixing suffixes for consistency with `DateComponents`
- `components(with scale:)` method with flexible unit parameter
- `.wholeSeconds` property + `.fractionalSeconds(as:)` method (Dave DeLong's synthesis)

**What was NOT provided**: Swift's Duration has no `totalSeconds`, `inSeconds`, or `toSeconds()` API. To get the total number of seconds, users must access `.components.seconds` (which gives only the whole-seconds portion) and manually combine with `.components.attoseconds`. This was a deliberate choice to prevent precision loss from Double conversion and to avoid the component-vs-total ambiguity.

### 5.3 Implications for Primitives

Swift's Duration deliberately chose *not* to provide convenient total-unit accessors. This creates a gap that primitives-layer types must fill if they need scalar unit access (e.g., for interop with C APIs or serialization). Any such API must:

1. Choose a consistent prefix pattern
2. Clarify whether the value is truncated (whole units) or fractional
3. Avoid the component-vs-total ambiguity documented in C# and Python

---

## 6. Synthesis and Recommendations

### 6.1 What the Literature Supports

1. **Consistency is paramount** (Bloch, Myers & Stylos): One pattern throughout. Do not mix `toSeconds`, `inSeconds`, and `.seconds` in the same ecosystem.

2. **Descriptive compound names aid comprehension** (Schankin et al.): `inWholeSeconds` is empirically better than `seconds` for semantic understanding tasks.

3. **The `in` preposition reads most naturally** (cross-language survey): "Duration in seconds" is how practitioners verbalize the concept. Kotlin's `inWholeSeconds` pattern is the most linguistically natural.

4. **Disambiguate total from component** (C#/Python bug history): If an API exposes both component access and total conversion, the names MUST be unambiguous. Python's `.seconds` vs `.total_seconds()` bug pattern is well-documented.

5. **Domain vocabulary over implementor vocabulary** (Muratori): Users think "give me this in seconds," not "give me the seconds component of the two-part attosecond representation."

6. **Naming drives discoverability** (Myers & Stylos): A consistent prefix (`in`, `to`, `as`) enables code-completion-driven exploration. Users type the prefix and discover all available units.

7. **Misleading names are worse than no names** (Avidan & Feitelson): A `.seconds` property that returns a component rather than the total duration in seconds actively harms comprehension.

### 6.2 Open Questions

- **Nested vs flat**: `duration.in.seconds` vs `duration.inSeconds` has no empirical resolution. The nested pattern has stronger fluency properties but higher implementation cost and potential keyword conflicts.
- **Truncation signaling**: Kotlin's `inWhole` prefix explicitly signals truncation. Is this necessary, or does the return type (`Int64` vs `Double`) suffice?
- **Prefix choice**: `in` (Kotlin), `to` (Java), `as` (Rust), or a Swift-native pattern? The Swift API Design Guidelines do not address this specific case.

---

## References

### Academic

- Avidan, E. and Feitelson, D.G. (2017). "Effects of Variable Names on Comprehension: An Empirical Study." ICPC 2017.
- Bloch, J. (2006). "How to Design a Good API and Why It Matters." OOPSLA 2006. https://dl.acm.org/doi/10.1145/1176617.1176622
- Feitelson, D.G., Mizrahi, A., Noy, N., et al. (2022). "How Developers Choose Names." IEEE TSE 48(1). https://arxiv.org/abs/2103.07487
- Myers, B.A. and Stylos, J. (2016). "Improving API Usability." CACM 59(6), pp. 62-69. https://dl.acm.org/doi/10.1145/2896587
- Schankin, A., Berger, A., Holt, D.V., et al. (2018). "Descriptive Compound Identifier Names Improve Source Code Comprehension." ICPC 2018. https://dl.acm.org/doi/10.1145/3196321.3196332

### Practitioner

- Bloch, J. (2018). *Effective Java*, 3rd ed. Item 68: Naming Conventions.
- Colebourne, S. (2011). "Common Java Method Names." https://blog.joda.org/2011/08/common-java-method-names.html
- Fowler, M. (2005, updated 2008). "Fluent Interface." https://martinfowler.com/bliki/FluentInterface.html
- Muratori, C. (2014). "Semantic Compression." https://caseymuratori.com/blog_0015
- Swift API Design Guidelines. https://www.swift.org/documentation/api-design-guidelines/

### Language Documentation

- Go: `time.Duration` — https://pkg.go.dev/time
- Java: `java.time.Duration` — https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/time/Duration.html
- Kotlin: `kotlin.time.Duration` — https://kotlinlang.org/api/core/kotlin-stdlib/kotlin.time/-duration/
- Kotlin KEEP: Durations and Time Measurement — https://github.com/Kotlin/KEEP/blob/master/proposals/stdlib/durations-and-time-measurement.md
- Python: `datetime.timedelta` — https://docs.python.org/3/library/datetime.html
- Rust: `std::time::Duration` — https://doc.rust-lang.org/std/time/struct.Duration.html
- C#: `System.TimeSpan` — https://learn.microsoft.com/en-us/dotnet/api/system.timespan

### Swift Evolution

- SE-0329: Clock, Instant, and Duration — https://github.com/swiftlang/swift-evolution/blob/main/proposals/0329-clock-instant-duration.md
- SE-0329 First Review — https://forums.swift.org/t/se-0329-clock-instant-date-and-duration/53309
- SE-0329 Second Review — https://forums.swift.org/t/se-0329-second-review-clock-instant-and-duration/54509
- SE-0329 Third Review — https://forums.swift.org/t/se-0329-third-review-clock-instant-and-duration/54727
- SE-0329 Extended Review — https://forums.swift.org/t/review-extended-se-0329-clock-instant-and-duration/55033
