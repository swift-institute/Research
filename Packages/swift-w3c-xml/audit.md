# swift-w3c-xml — Investigation / Audit Record

## 2026-06-27 — `W3C_XML.parse` runtime SIGSEGV (catalog §A9, new site)

- **Severity**: HIGH (every `W3C_XML.parse` call SIGSEGVs at runtime on Swift 6.3.x —
  even `W3C_XML.parse("<root/>")`). Builds green; crashes on execution.
- **Classification** ([ISSUE-010]): runtime crash → Swift-runtime metadata-instantiation
  defect. `EXC_BAD_ACCESS (code=1, address=0x10)`.
- **Location**:
  - Symptom site: `Sources/W3C XML/W3C_XML.Parse.Document.swift:497`
    (`machineParser.parse(&input)`), crashing in
    `swift-parser-machine-primitives` `Parser.Machine.Parser.parse`.
  - Trigger type: `Parser.Machine.Parser<Byte.Input, W3C_XML.Element, W3C_XML.Parse.Error>`,
    where `Byte.Input = Input.Slice<Array<Column.Shared<Byte>>>` and
    `Input.Slice.Index == Tagged_Primitives.Tagged<Element, Ordinal>`.
- **Finding**: **Catalog §A9** — `Tagged` forced to materialize its full value-witness
  table inside a generic container, hitting incomplete `SuppressedAssociatedTypes` codegen
  on Swift 6.3.x (`swift_getTypeByMangledName` → `TypeLookupError("unknown error")` → null
  metadata → `0x10` deref). A **new site** of the documented family (cf. the `Set<Index>.Ordered`
  / graph site). NOT a w3c-xml defect, NOT caused by the `Byte.Input` migration (`57ebb7d`),
  NOT a logic/ownership bug. Confirmed by: identical `0x10` signature; `__swift_instantiateConcreteTypeFromMangledNameV2`
  at the call site; `instantiateWitnessTable` crash on the protocol-witness path; the
  `SWIFT_DEBUG_FAILED_TYPE_LOOKUP=1` "`failed type lookup … unknown error`" marker; and a
  3-package standalone reproducer (zero w3c-xml code) that crashes identically. `-Onone` and
  `-O` both crash; getter, getter-only, and direct-method paths all crash.
- **Status**: **WORKAROUND** (version-gated test skip). No source/manifest change; the
  `Byte.Input` migration is correct and retained. The 5 `parse`-exercising suites + 2 `parse`
  tests in `Character Validation` are `.disabled(if: Toolchain.hasTaggedMetadataSIGSEGV, …)`
  gated on `compiler(<6.4)` (`Tests/W3C XML Tests/{Toolchain.swift, ParserTests.swift}`).
  `swift test` on 6.3.3: 72 tests, 24 run+passed, 48 skipped, exit 0. Auto-recovers on 6.4+.
- **Resolution path** ([ISSUE-008]): no Institute-side code fix (the §A9 raw-storage wrapper
  was reverted on correctness grounds); require Swift 6.4+ for `Parser.Machine.Parser<Byte.Input, …>`
  paths; wait for the Swift 6.5 release.
- **Tracking**:
  - Catalog: `swift-institute/Research/swift-compiler-bug-catalog.md` §A9 →
    "§A9 New Site (2026-06-27) — `Parser.Machine.Parser<Byte.Input, …>.parse`".
  - Investigation brief + full Findings: `.handoffs/HANDOFF-w3c-xml-machine-parser-byte-input-segfault.md`.
  - Standalone reproducer: scratchpad `MachineRepro/` (empirical scratch; not committed).
- **Principal decision (2026-06-27)**: accept the "require 6.4+" stance — no `Byte.Input` change,
  no flatter backing. `Byte.Input`'s `Tagged`-bearing `Index` makes the entire byte-domain
  machine-parser surface §A9-affected on 6.3.x (not only w3c-xml); every such site inherits the
  same stance. The `compiler(<6.4)` guards retire when the workspace adopts Swift 6.4 at its
  ~September 2026 launch; the 6.3.x coverage gap until then is accepted.
