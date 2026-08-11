# PDF Text Encoding Trace — Mojibake in `/ActualText` Literal Strings

<!--
---
version: 1.0.0
last_updated: 2026-05-11
status: RECOMMENDATION
---
-->

## Context

`tenthijeboonkkamp/timekeeping`'s `swift run Invoices`, post-migration from
`coenttb/swift-html-to-pdf` to `swift-foundations/swift-pdf` (commit `d3767e9`),
produces invoices where `€` and `ë` appear as mojibake when text is copied
from the PDF or extracted by accessibility tools. The reference invoice
(coenttb-html-to-pdf chain, `Invoices/100+/20260211/...factuur-17.pdf`)
copies cleanly; the post-migration invoice
(institute swift-pdf chain, `Invoices/100+/20260511/...factuur-21.pdf`)
returns the documented mojibake `€ → â‚¬` and `ë → Ã«` shape.

Per the parent dispatch's supervisor block (acceptance criterion #1), this
research doc presents the on-disk byte evidence and locates the bug.

## Question

Where does the Swift `String` containing `€` and `ë` become incorrectly
encoded PDF bytes in the institute swift-pdf chain, and what is the correct
fix path?

## Analysis

### On-disk evidence (REFUTES "encoding is correct" hypothesis)

Two PDF byte-streams isolated from the reproducer
`Invoices/100+/20260511/20260507 Ten Thije Boonkkamp factuur 29IOVCDMKT-21.pdf`:

| Site | Field | On-disk bytes | Decode-as-WinAnsi | Decode-as-PDFDocEncoding |
|------|-------|---------------|-------------------|--------------------------|
| Content stream | `(€ 150,12) Tj` | `80 A0 31 35 30 2C 31 32` | **`€<NBSP>150,12`** ✓ | (not declared encoding) |
| Marked-content property | `/ActualText (€ 150,12)` | `E2 82 AC C2 A0 31 35 30 2C 31 32` | `â‚¬Â<NBSP>150,12` | **`â‚¬Â<NBSP>150,12`** ✗ |
| Content stream | `(Cliëntnummer) Tj` | `43 6C 69 EB 6E 74 6E 75 6D 6D 65 72` | **`Cliëntnummer`** ✓ | (not declared encoding) |
| Marked-content property | `/ActualText (Cliëntnummer)` | `43 6C 69 C3 AB 6E 74 6E 75 6D 6D 65 72` | `CliÃ«ntnummer` | **`CliÃ«ntnummer`** ✗ |

Font dictionary: `<< /BaseFont /Times-Roman /Encoding /WinAnsiEncoding
/Subtype /Type1 /Type /Font >>` — declares WinAnsi for content streams.

**The content stream is encoded correctly** — `€` → `0x80`, `ë` → `0xEB`
(see WinAnsi table entries at `swift-iso-32000.../ISO_32000.WinAnsiEncoding.swift:157,270,302,406`).
The visual glyphs render correctly when a PDF viewer respects `/Encoding /WinAnsiEncoding`.

**The `/ActualText` literal string is encoded incorrectly** — Swift's
`String.utf8` bytes are emitted verbatim into a PDF literal string `(...)`.
Per ISO 32000-2:2020 §7.9.2.2 (Text string type):

> "Text strings shall be encoded in either PDFDocEncoding or UTF-16BE."
> "If a text string is encoded in UTF-16BE, the first two bytes shall be 254 followed by 255."

UTF-8 is not a valid PDF text-string encoding. When a viewer decodes the
literal string as PDFDocEncoding (the default per §7.9.2.2), it produces
the documented mojibake.

The handoff's reported shape `€ → â‡¬Â€` is the visible form when text is
copied from the PDF or read by a screen reader — `/ActualText` is the
accessibility / copy-paste source, and a PDF/UA-conformant viewer or
text-extractor takes `/ActualText` over the visible glyph stream.

### Root-cause location

`swift-iso/swift-iso-32000/Sources/ISO 32000 7 Syntax/7.3 Objects.swift`
lines 1131–1148:

```swift
extension ISO_32000.`7`.`3`.COS.StringValue: Binary.Serializable {
    /// Serialize a PDF String to bytes
    ///
    /// Strings are serialized as literal strings: `(Hello)`
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ str: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(.ascii.leftParenthesis)
        for byte in str.value.utf8 {                              // ❌ raw UTF-8
            if let escaped = ISO_32000.`7`.`3`.Table.`3`.escapeTable[byte] {
                buffer.append(contentsOf: escaped)
            } else {
                buffer.append(byte)
            }
        }
        buffer.append(.ascii.rightParenthesis)
    }
}
```

`str.value.utf8` is the Swift `String`'s UTF-8 view. The function emits UTF-8
bytes wrapped in `(...)`. This produces malformed PDF text strings for any
non-ASCII content.

The package's own
`ISO 32000/ISO_32000.COS.StringValue.swift:26-64` already implements the
correct algorithm under `asLiteral()`:

```swift
public func asLiteral() -> [UInt8] {
    var result: [UInt8] = [.ascii.leftParenthesis]
    if canUsePDFDocEncoding {
        // PDFDocEncoding path
        for scalar in value.unicodeScalars {
            if let byte = ISO_32000.PDFDocEncoding.encode(scalar) {
                // … escape and append
            }
        }
    } else {
        // UTF-16BE with BOM (0xFE 0xFF)
        result.append(0xFE)
        result.append(0xFF)
        for scalar in value.unicodeScalars { /* UTF-16BE encode + escape */ }
    }
    // …
}
```

The defect is that `Binary.Serializable.serialize(_:into:)` does NOT call
`asLiteral()`. It is the load-bearing path for `/ActualText` and any other
`.string(...)` value embedded in a `COS.Dictionary` — the only places that
escape this branch use `asLiteralWinAnsi()` (content streams) or hex strings
explicitly.

### Call path that surfaces the bug

```
PDF.HTML.Context.text(_:)
    PDF.Context.Text.Run.runsWithSymbolSupport(text:font:…)   // OK: encodes content stream WinAnsi
PDF.HTML.Context.text(_:) → flush.inline()
    PDF.Context.Text.Run.renderRuns(runs:context:)
        ↓
        buildActualText(from: runs)                            // returns Swift String "€ 150,12"
        context.currentPageBuilder.beginActualTextSpan(actualText)
            ↓
            ContentStream.Builder.beginActualTextSpan(_ actualText: String)
                properties = [.actualText: .string(actualText)]  // COS.Object.string(StringValue)
                emit(.beginMarkedContentWithProperties(tag: .span, properties: properties))
            ↓
            Operator.serialize(.beginMarkedContentWithProperties(...)):
                COS.Dictionary.serialize(properties, into: &buffer)
                    COS.serialize(object, into: &buffer)
                        case .string(let str):
                            StringValue.serialize(str, into: &buffer)   // ❌ ROOT CAUSE
                                buffer.append(contentsOf: str.value.utf8)
```

Code site:
`swift-pdf-render/Sources/PDF Rendering/PDF.Context.Text.Run+Rendering.swift:25-33`
calls `beginActualTextSpan(actualText)` with the Swift `String`. The defect
manifests one layer below at the `swift-iso-32000` `StringValue.serialize`
implementation.

## Outcome

**Status**: RECOMMENDATION

**Diagnosis**:

The institute PDF chain encodes content-stream text correctly (WinAnsi) but
encodes `/ActualText` (and, by extension, any other COS string value embedded
in a dictionary — info-dictionary `/Title`, `/Author`, outline titles, link
URIs that contain non-ASCII, etc.) as raw UTF-8 bytes wrapped in `(...)`,
violating ISO 32000-2 §7.9.2.2. PDF readers, accessibility tools, and text
extractors decode the malformed bytes as PDFDocEncoding, producing the
documented mojibake.

The fix has three candidate paths, evaluated below. Path (a) is the structural
fix; path (b) is a workaround inside the relaxed package set; path (c) is a
documented deferral.

### Fix options

#### (a) Targeted patch to `swift-iso-32000` (RECOMMENDED — structural)

Change `StringValue.serialize(_:into:)` at
`swift-iso-32000/Sources/ISO 32000 7 Syntax/7.3 Objects.swift:1135-1148` to
delegate to the existing `StringValue.asLiteral()` method that already
implements the correct PDFDocEncoding/UTF-16BE switching algorithm:

```swift
public static func serialize<Buffer: RangeReplaceableCollection>(
    _ str: Self,
    into buffer: inout Buffer
) where Buffer.Element == UInt8 {
    let bytes = str.asLiteral()      // ISO 32000-2 §7.9.2.2 compliant
    buffer.append(contentsOf: bytes)
}
```

The `asLiteral()` method already lives at
`swift-iso-32000/Sources/ISO 32000/ISO_32000.COS.StringValue.swift:26-64`
and implements both branches correctly. The fix is one function-body swap;
the existing institute snapshot tests cover ASCII-only text strings (which
PDFDocEncoding handles identically per Annex D), so no snapshot churn for
the common case. Tests for non-ASCII text strings are missing and would
need to be added.

**Authorization gate**: `swift-iso-32000` is OUTSIDE the relaxed set per
supervisor-block fact #2; this is a class-(c) escalation per ask #6
(diagnosis requires editing an institute package outside the relaxed set).

#### (b) Workaround in `swift-pdf-render` (relaxed package)

Skip `beginActualTextSpan` entirely from
`PDF.Context.Text.Run+Rendering.swift:23-33` when the actualText contains
non-ASCII characters. The visual glyph rendering would be unaffected; the
only loss is accessibility / copy-paste fidelity for non-ASCII spans
(equivalent to the pre-`ActualText` state). This is sound for monolingual
ASCII corpora but materially worse for the timekeeping invoices, which
contain Dutch (`Cliëntnummer`) and currency text (`€`) on every line.

A second workaround variant: emit `ActualText` only for the ASCII subset
of each run. This requires splitting runs on the ASCII/non-ASCII boundary
and is more invasive than option (a).

**Authorization gate**: edits live entirely in the relaxed set; standard
per-finding YES.

#### (c) Deferral

Defer the fix; document the gap in `swift-pdf-render/Research/`. Acceptable
only if the user prefers to keep the bug visible until a broader text-string
encoding sweep (info dict, outline titles, link URIs, etc.) is undertaken.

### Recommendation

Path (a) — the structural fix. The existing `asLiteral()` algorithm is the
canonical resolution; the duplicate `serialize(_:into:)` implementation is a
historic shortcut from an era when text strings were assumed ASCII. The fix
is small, mechanically correct against the existing tests, and fixes the
class of defects rather than the current symptom. The class-(c) authorization
gate is the right shape: an absent supervisor cannot self-authorize an
edit to a FROZEN package; the user adjudicates.

### Verification gates (per acceptance criterion #1)

- ✓ Bug existence: on-disk hex bytes `E2 82 AC C2 A0` inside `/ActualText (...)`
- ✓ Bug location: `swift-iso-32000/Sources/ISO 32000 7 Syntax/7.3 Objects.swift:1140`
- ✓ Bytes-level evidence: documented above with side-by-side decode comparison
- ✓ Misinterpretation identified: PDFDocEncoding read of UTF-8 bytes

### Related text-string sites likely to share the bug

Each of these emits a `COS.Object.string(StringValue)` value into a dictionary
via the same `serialize` path:

| Site | File | Affected scenarios |
|------|------|---------------------|
| Document Info dictionary | `swift-pdf-render` Document.Info emission | Title / Author / Subject / Keywords containing non-ASCII |
| Outline (bookmark) titles | `ISO_32000.Outline` | Headings containing `ë`, `€`, etc. |
| Link annotations URI | `PDF.HTML.Configuration.Annotation` path | URIs with percent-encoded non-ASCII (decoded to String first) |
| Marked-content `/ActualText` | `ContentStream.beginActualTextSpan` | Documented above |
| Structure-tree text values | tagged-PDF structure tree | Alt text, expansion |

A single fix at the `StringValue.serialize` site repairs all of these.

## References

- ISO 32000-2:2020 §7.9.2.2 — Text string type (PDFDocEncoding / UTF-16BE)
- ISO 32000-2:2020 §7.3.4 — String objects (literal vs hexadecimal syntax)
- ISO 32000-2:2020 Annex D — Character sets and encodings (PDFDocEncoding,
  WinAnsiEncoding, MacRomanEncoding, StandardEncoding)
- ISO 32000-2:2020 §14.9.4 — Replacement Text (`/ActualText`)
- ISO 32000-2:2020 §14.8 — Tagged PDF / accessibility text-extraction model
- `swift-iso-32000.../ISO_32000.COS.StringValue.swift:26-64` — existing
  correct `asLiteral()` implementation
- `swift-iso-32000.../ISO 32000 7 Syntax/7.3 Objects.swift:1131-1148` —
  defective `StringValue.serialize(_:into:)` implementation
- `swift-pdf-render.../PDF.Context.Text.Run+Rendering.swift:23-33` — entry
  point where `/ActualText` is emitted
