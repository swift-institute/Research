# bare string dependency

**1,377 findings** — fourth-largest class in the fleet compliance ledger of 2026-08-02.
Citation `swift-institute-linter-rules#4`. Predicate:
[`Lint.Rule.Manifest.BareStringDependency.swift`](../Sources/Institute%20Linter%20Rule%20Manifest/Lint.Rule.Manifest.BareStringDependency.swift).

Read [remediation-mechanics.md](remediation-mechanics.md) first.

---

## What the convention means

A target's dependencies are spelled through the typed accessors — `.target(name:)` for a
same-package target, `.product(name:package:)` for a product of a package dependency — never as a
bare string.

SwiftPM resolves a bare string as `.byName`, which **binds to whatever it resolves first**. The
manifest says "some dependency called `Foo`" and lets the resolver decide which one that is. When
a same-package target and a dependency's product share a name, or when a product appears later
that shadows a target, the graph silently changes and the manifest that produced it did not.
Nothing errors; the build is simply of something other than what was intended.

The bare-string form is the idiom in most external Swift material, which is why it arrives with
copied code rather than being chosen. That is the whole reason this class is large.

## What the predicate actually flags

Surface: a package manifest — `Package.swift` or a versioned `Package@swift-*.swift`, including
nested test manifests. Nothing else.

Within it, each element of the `dependencies:` array of a target-declaring call — `.target`,
`.testTarget`, `.executableTarget`, `.macro`, `.plugin` — that resolves to a bare string:

- a **string literal**: `dependencies: ["Foo"]`;
- a **`.byName(name:)` call**: `dependencies: [.byName(name: "Foo")]` — the explicit spelling of
  exactly the resolution ambiguity a bare string produces, not a safer alternative to it;
- a **reference to a file-scope string constant**: `let owner = "Foo"` used as an element. The
  finding is reported at the *reference*, not at the constant, because the use site is what you
  fix.

The array itself is resolved through a file-scope array constant, and through a `+`-concatenated
sequence of such arrays. A manifest is a single file by construction, so every one of those
bindings is in the file the rule is already parsing.

### The documented residue — and why a zero here is weaker than elsewhere

An element or array whose value is **computed** — a function call, a `.map`, a `for`-built array
— is not resolved and is **silently unreported**. This is the rule's one documented limitation
and it is worth taking seriously: a manifest that hoists every dependency array behind a computed
value reports zero findings while being entirely non-compliant.

So for this rule specifically, before you record a package as clean, look at how its manifest
builds its dependency arrays. A recorded disposition does not count as compliance merely because
it is recorded.

---

## Step 1 — there is no rewriter yet

The mechanically-safe subset of this class is well understood, but it cannot be applied. Fix
application is gated on the declared SwiftPM target roots, and `Package.swift` sits at the package
root, outside every declared target root — so the manifest is walked for detection and unreachable
for application. A manifest fix scope must be added to the engine first, filed as
[swift-linter#32](https://github.com/swift-foundations/swift-linter/issues/32).

That change deserves the care it is getting: the manifest is the one file whose corruption stops
the package resolving at all, and the engine's guard is a re-parse, not a typecheck.

Until it lands, everything below is manual.

When it does land, the subset it will take is **exactly case A below** — a name matching a target
declared in the same manifest. Cases B and after will remain manual, because they require
information that is not in the file.

---

## Step 2 — the decision tree

Every finding is one question: **what does this string actually denote?**

### A. It names a target declared in this same manifest

Rewrite to `.target(name: "X")`.

This is safe in the strongest sense available: `byName` resolution binds a same-package target
exactly this way, so the resolved graph is unchanged. You are writing down the binding SwiftPM was
already making.

Check it by reading the manifest's own `targets:` array for a target whose `name:` equals the
string. Match exactly — target names in this ecosystem contain spaces, and a near-match is a
different target or none.

### B. It names a product of a package dependency

Rewrite to `.product(name: "X", package: "<repo>")`.

Two things to get right, and only one of them is in this file:

- **`name:`** is the product's name, which is the string you started with.
- **`package:`** is the **package identity**, which for a URL dependency is the **repository name
  from the URL** — never the on-disk directory basename, which resolves only against a
  machine-local mirror. Take it from the `.package(url:)` line, not from your checkout.

The part that is not in this file is **which** dependency exports the product. The manifest lists
the package dependencies and it lists the product name you need, but the mapping between them
lives in each dependency's own manifest. That is the specific reason this case cannot be
mechanized: deriving the owner from a URL's last path component is a guess, not a derivation, and
it is wrong exactly when a package's repository name differs from the product it exports — which
in this ecosystem is the normal case, not the exception.

To resolve it, read the `products:` array of each declared dependency's manifest until you find
the one exporting that product name. If two do, you have just found the ambiguity the rule exists
to prevent, and the typed accessor is what disambiguates it.

### C. It names something in neither list

Then the manifest currently does not resolve, or resolves to something you have not accounted for.
Stop and establish which before writing anything. This case is rarer than B but is the one where a
mechanical rewrite would do real damage.

### D. The element is a reference to a file-scope string constant

```swift
let core = "Core Primitives"
…
.target(name: "Consumer", dependencies: [core])
```

Fix at the **use site**, which is where the finding is reported — replace the reference with the
typed accessor. Whether the constant itself survives depends on what else uses it; a constant that
existed only to be a dependency element should go with it.

### E. The element is an interpolated string literal

Do not rewrite mechanically. Resolve what it interpolates to, then apply A or B with the literal
result. If the interpolation is doing real work — building a name from a shared prefix across many
targets — the honest fix is usually to write the names out, since a manifest whose target graph
you cannot read is the underlying problem.

### F. The dependency array is computed

You are not looking at a finding, because the rule did not report one. You are looking at the
residue. If you are remediating a package, this is the case to go looking for deliberately: a
`.map`, a function call, or a `for`-built array feeding `dependencies:`. The compliant shape is to
write the arrays out; the rule cannot help you find them.

### G. The manifest has a top-level `#if`

Target declarations become clause-dependent, and both branches need remediating. Handle each
clause independently and confirm the resolve under each configuration you support.

---

## Two hazards while you are editing manifests

Neither is this rule's concern, and both are cheap to trip while remediating it.

**Do not introduce a second spelling of a dependency's identity.** A published package's
dependency is spelled exactly `https://github.com/<org>/<repo>.git` — current org home, `.git`
suffix, no bare form, no retired org spelling. Two spellings of one identity place it under two
canonical locations and fire SwiftPM's conflicting-identity branch, which enumerates every
distinct dependency path — an effective hang on an ecosystem-scale graph, from one divergent edge.
If a `.product(package:)` you add does not match an existing `.package(url:)`, fix the mismatch;
do not add a second URL.

**The one lawful path-form dependency** is a nested test manifest reaching its own parent as
`.package(path: "..")`, which resolves identically on every machine because the parent is always
exactly there. Leave those alone.

And `Package.resolved` is generated state: do not commit, hand-edit, copy, or delete it to force a
resolution. If your change altered it, that is a finding about your change.

---

## Worked examples

### Case A — a same-package target, with the contrast visible in one file

`swift-sockets-standard`, `Package.swift`:

```swift
    targets: [
        .target(
            name: "Sockets Standard",
            dependencies: [
                .product(name: "RFC 768", package: "swift-rfc-768"),
                .product(name: "RFC 791", package: "swift-rfc-791"),
                .product(name: "RFC 9293", package: "swift-rfc-9293"),
            ]
        ),
        .testTarget(
            name: "Sockets Standard Tests",
            dependencies: [
                "Sockets Standard"
            ]
        ),
    ],
```

One finding, on `"Sockets Standard"`. The manifest is already writing the typed form correctly for
its three external dependencies, which makes the shape of the omission clear: the external ones
were typed because they had to be, and the local one was left bare because `byName` happened to
work.

`Sockets Standard` is declared as a `.target` in this same manifest, so this is case A:

```swift
        .testTarget(
            name: "Sockets Standard Tests",
            dependencies: [
                .target(name: "Sockets Standard")
            ]
        ),
```

The resolved graph is identical. This is the case a rewriter will take once
[swift-linter#32](https://github.com/swift-foundations/swift-linter/issues/32) lands.

Note what does **not** fire in this file: the `.library(name: "Sockets Standard", targets: ["Sockets
Standard"])` product declaration also holds a bare string, and the rule ignores it. The predicate
inspects the `dependencies:` array of a target-declaring call, and a product's `targets:` array is
neither. Do not "fix" it while you are there — a product's `targets:` list has no typed-accessor
form.

### Case B — a product of a dependency

```swift
dependencies: [
    .package(url: "https://github.com/swift-foundations/swift-linter.git", branch: "main"),
],
targets: [
    .target(name: "Rules", dependencies: ["Linter"]),
]
```

`Linter` is not a target in this manifest. It is a product of `swift-linter`, whose identity is
the repository name:

```swift
    .target(
        name: "Rules",
        dependencies: [.product(name: "Linter", package: "swift-linter")]
    ),
```

Note that the product name and the repository name differ — which is why the owner had to be
looked up rather than derived.

**How often case B actually occurs is worth knowing before you plan the work.** A read-only survey
of the `swift-primitives`, `swift-standards`, and `swift-foundations` checkouts at authoring time
found that essentially every bare dependency string names a target declared in its own manifest,
and did not find one naming a product of an external package: external dependencies in this
ecosystem are consistently written with `.product(name:package:)` already. That survey is a source
scan over three checkout trees, not a lint measurement and not the ledger, so treat it as a
planning expectation rather than a count — but the expectation it sets is that this class is
overwhelmingly case A, which is the mechanically-safe subset, and that the manifest fix scope in
[swift-linter#32](https://github.com/swift-foundations/swift-linter/issues/32) would therefore
reach most of it.

`.byName(name:)` was likewise not found in any production manifest in that survey — only in
deliberate test fixtures for the manifest model, which are not findings to remediate.

### Case A with a different target kind

One real variant worth recognizing. `swift-image-magick`, `Package.swift`:

```swift
        .target(
            name: "SwiftImageMagick",
            dependencies: ["imagemagick"]
        ),
```

`imagemagick` is not a `.target`, `.testTarget`, or `.executableTarget` — it is a
`.systemLibrary(name: "imagemagick", …)` declared in the same manifest. It is still case A, and
`.target(name: "imagemagick")` is still the correct typed form, because a system library is a
target. The point is only that when you check "is this name declared in this manifest", the answer
lives across **every** target-declaring factory including `.systemLibrary` and `.binaryTarget` —
not just the three obvious ones.

### The `.byName` spelling

```swift
dependencies: [.byName(name: "Core Primitives")]
```

Fires, and correctly: this is the same resolution ambiguity written out longhand. Apply A or B as
above; `.byName` is never the answer.

### The residue, which reports nothing

```swift
let shared = ["Core Primitives", "Logging"].map { $0 }

.target(name: "Consumer", dependencies: shared)
```

Zero findings. The `.map` makes the array a computed value, and the rule does not resolve it. Both
elements are non-compliant.

---

## Suppression: essentially none is lawful

This rule is close to unique in the ledger: **the fix is always available and always local**. A
bare string denotes something, and writing down what it denotes is the whole remediation. There is
no ripple — no call site anywhere observes the change, because the resolved graph is unchanged when
the rewrite is correct and the build fails immediately when it is not.

The one shape with a defensible reason is a manifest this repository does not author — an upstream
manifest kept byte-identical to keep merges tractable in a fork:

```swift
// swift-linter:disable:next bare string dependency
// REASON: this manifest is carried verbatim from upstream to keep merges
// clean; the dependency spelling is upstream's and is not ours to change.
dependencies: ["Upstream Core"]
```

These do **not** qualify: "it resolves fine today" — that is the property the rule says you cannot
rely on; "the typed form is more verbose"; "this is how the upstream tutorial writes it".

If you find yourself wanting to suppress case B because the owning package is tedious to find,
that is the finding doing its job. The tedium is the ambiguity, made visible.

---

## Verification

Per [remediation-mechanics.md §5](remediation-mechanics.md#5-verify-per-finding-and-verify-the-whole-file), plus one
check specific to manifests — a manifest edit is a graph edit, and reading it is not enough:

```sh
workspace package resolve --package-path <package>
workspace package build   --package-path <package>
workspace package lint    --package-path <package>
```

The evidence that a case-A rewrite was correct is that **resolve succeeds and the resolved graph
is unchanged**. The evidence that a case-B rewrite was correct is that resolve succeeds and the
build links — a wrong `package:` fails at resolve, and a wrong `name:` fails at link.

A full build, not a resolve and not a manifest dump, is also what emits SwiftPM's own
unused-dependency warning — the authoritative signal if your remediation left a dependency behind.

Do not use `swift package show-dependencies` to inspect the graph; its dumpers are independently
exponential on large graphs. Never invoke `swift package` directly in any case.

---

## Honest limitations

- **The residue is the real limit.** A clean run means the rule found no bare string it can
  resolve. It does not mean the manifest has none.
- **The rule checks spelling, not correctness.** `.product(name: "X", package: "y")` naming a
  product that does not exist is not this rule's concern — resolve is. A manifest can be fully
  compliant with this rule and still describe the wrong graph.
