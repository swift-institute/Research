# State-stack pop-ordering investigation — empirical findings

> Sub-investigation of `HANDOFF-state-stack-pop-ordering.md` (Phase B of
> `HANDOFF-swift-pdf-render-parity.md` Rev 7). Authored 2026-05-12 after
> Phase A.1'/A.0/A.3/A.4 landed.
>
> Prior research baseline: `Research/css-fidelity-gap-inventory.md`
> §Addendum 2026-05-11 hypothesized a state-stack pop-ordering bug
> between sibling top-level tables based on 24-invoice instrumentation
> showing tables 4-5 pushing with `context.table != nil`.

## TL;DR

**The minimal-reproducer-first investigation per `[META-016]` did NOT
reproduce a state-stack pop-ordering defect.** Four progressively richer
reproducers all render correctly:

1. Two sibling top-level tables, each with `.css.width(.percent(N))`
   hints on cells → both columns honored at the correct split ratio.
2. Two sibling top-level tables, each with width hints PLUS
   `.css.border(.properties(width: .px(1), style: .solid, color: .red))`
   → both tables draw their borders and honor column widths.
3. Three sibling top-level tables in invoice-like sequence
   (nested-tables Letter.Header / metadata table / line-items with
   per-table border) → all three render correctly with 50/50, 60/40,
   70/30 column allocations.
4. Letter.Header pattern: single 2-col table with three Paragraphs in
   each cell → both cells render side-by-side, paragraphs flow downward
   within each cell.

The hypothesis-level claim from
`Research/css-fidelity-gap-inventory.md` §Addendum (2026-05-11) — that
sibling table 4's `_pushElement` reads `context.table != nil` due to a
missed pop — is NOT empirically supported by these reproducers.

## Reproducer authored

`Tests/PDF HTML Rendering Tests/BaselineEmpiricalTests.swift` test 5
(replaces the prior `.disabled` placeholder):

```swift
@Test
func `sibling tables: second table column-width hints reach their state`() throws {
    struct TestView: HTML.View {
        var body: some HTML.View {
            Table {
                TableRow {
                    TableDataCell { "A1" }.css.width(.percent(60))
                    TableDataCell { "B1" }.css.width(.percent(40))
                }
            }
            Table {
                TableRow {
                    TableDataCell { "A2" }.css.width(.percent(60))
                    TableDataCell { "B2" }.css.width(.percent(40))
                }
            }
        }
    }
    // ...
    #expect(b1.x > 50) // sibling 1 honors width hints
    #expect(b2.x > 50) // sibling 2 honors width hints
    #expect(abs(b1.x - b2.x) < 5) // both sibling allocators agree
}
```

**Result**: PASSES. B1.x ≈ B2.x ≈ 270.77pt (matches Test 6 isolated-case
60% × 451 = 270.6).

## Code-path read

`_popElement` at `PDF.HTML.Context+Rendering.swift:457-493` DOES restore
`context.table` via the table-specific `popBlockElement` switch case at
line 793-806:

```swift
case "table":
    // Draw table right and bottom borders
    if let tc = context.table {
        HTML.Element.Tag<Never>.drawTableRightAndBottomBorders(
            tableCtx: tc, context: &context
        )
    }
    context.pdf.advance(...)
    // Restore saved table context from scope
    context.table = scope.savedTable
```

The save side is line 384-386 of the same file:

```swift
let scope = Element.Scope(
    ...
    savedTable: tagName == "table" ? context.table : nil,
    ...
)
```

So `savedTable` IS captured on push for tables (and nil for non-tables;
non-table pops do not touch `context.table`). The restore IS wired for
table pops. The hypothesis "pops not firing" / "savedTable not
restored" is contradicted by the code as it stands today
(2026-05-12 HEAD).

## Iterative renderer trace (theoretical)

For a Tuple of two CSS-wrapped sibling tables
`[T1.css.border(), T2.css.border()]`:

1. `Render._Tuple._render` pushes `T2outer`, `T1outer` onto `_stack`,
   reverses → stack `[T2outer, T1outer]`; popLast → `T1outer` first.
2. Pop `T1outer` (HTML.CSS<Styled<T1, Border>>) → default `_render`
   pushes itself with `Thunk(view: Self.self)` → stack
   `[T2outer, T1outer_viewthunk]`.
3. Pop `T1outer_viewthunk` → dispatch `Styled<T1, Border>._render`:
   - `open(.push(.style), .pop(.style))` fires `_pushStyle` immediately
     and queues `popStyleT1` → stack `[T2outer, popStyleT1]`.
   - `apply(inlineStyle: borderProp)` — at this moment `context.table`
     is nil (T1 hasn't pushed yet) → writes γ-slot
     `pendingTableBorderWidth`.
   - `Content._render(T1, ctx)` calls `HTML.Element.Tag._render(T1)`:
     - `open(.push(.element(table)), .pop(.element(true)))` fires
       `_pushElement` which sets `context.table = T1`, drains γ-slot
       (`T1.borderWidth = pendingTableBorderWidth`). Queues
       `popElementT1` → stack `[T2outer, popStyleT1, popElementT1]`.
     - `Content._render(T1.content)` runs synchronously; children push
       onto stack above `popElementT1`.
     - Returns.
   - Returns.
4. Main loop processes T1's children. Eventually:
   - Stack `[T2outer, popStyleT1, popElementT1]`.
   - Pop `popElementT1` → `_popElement` fires → `popBlockElement` for
     `"table"` → `context.table = scope.savedTable = nil` ✓.
   - Pop `popStyleT1` → `_popStyle` (does NOT touch `context.table`,
     verified via `Style.Snapshot` only capturing style/margin/padding/
     constraint/layoutBoxLLX/URX/break flags).
5. Pop `T2outer` → repeats steps 2-4 with `context.table = nil` at
   modifier-apply time, then T2's own table state and pop sequence.

By this trace, `T2._pushElement` MUST see `context.table = nil`. The
empirical evidence at #1-4 of `## TL;DR` agrees with this trace.

## Discrepancy with `css-fidelity-gap-inventory.md` §Addendum

The inventory addendum reports (24-invoice instrumentation,
2026-05-11):

```
_pushElement table; context.table was nil: true   <- table 1 ✓
_pushElement table; context.table was nil: false  <- table 2 (nested) ✓
_pushElement table; context.table was nil: true   <- table 3 ✓
[Border modifier fires; table == nil: false]
_pushElement table; context.table was nil: false  <- table 4 UNEXPECTED ✗
```

Possible reconciliation paths:

- **(R1) The defect was inadvertently fixed by Phase A.** A.1' (commit
  `c443ddf`) rewrote the column-width allocator's recording mechanism
  in `finalizeFirstRow`, which interacts with the table state. If the
  pre-A.1' recording had a leak that A.1' closed, the 2026-05-11 trace
  is now stale.
- **(R2) The defect requires structural conditions not present in
  any reproducer above.** Candidates: a specific CSS modifier
  combination on a TD/TR (not the table itself); a thematic break
  between tables; a page-break interrupting between sibling tables;
  a specific element type immediately above one table that the others
  don't have.
- **(R3) The defect was misdiagnosed.** The inventory's instrumentation
  may have been racing against modifier dispatch in a way that
  recorded `context.table != nil` at a moment the renderer was actually
  inside an inner element scope, not at a top-level sibling push.

## Empirical impact on factuur-21 (post-Phase-A)

`pdfinfo` factuur-21: 3 pages (same as factuur-17 reference under
today's renderer).
`countStrokes` factuur-21: 1 stroke total (consistent with A.3 default
borderWidth = 0 plus one thematicBreak `<hr/>` line). No heavy borders.

`pdftotext -bbox-layout` factuur-21 page 1:

- Recipient (left, y=89.5-296.5): renders at `xMin=72-145` ✓
- Factuur+meta (right, y=95.08-141.18): renders at `xMin=380.85` ✓
  Side-by-side with recipient.
- Sender (left, y=362.4-526.6): renders at `xMin=72-145` (below
  recipient, in the same column).
- Contact info (left, y=558.2-745.18): below sender, in the left
  column.

The Letter.Header 2-col **IS** rendering side-by-side at row 1
(recipient/Factuur meta). The visual impression of "vertical stack" may
come from row 2 of the Letter.Header (sender on left, empty / missing
content on right), making the overall block APPEAR as a stack when
read top-to-bottom.

If the Letter.Header source structure is two rows where row 2's right
cell is empty, the visual is correct table behavior — not a state-stack
bug. Confirming this requires inspection of the user's source
(`tenthijeboonkkamp/timekeeping/Sources/...`), which is "Do Not Touch"
WIP per parent dispatch.

## Recommendation

Per `[META-016]` (reproducer first) and `[SUPER-029]` (surface-don't-
expand), the appropriate next step is **NOT to land a fix** but to
surface this finding for orchestrator adjudication. Options:

- **(P1) Close Phase B as "no defect reproducible at primitive level"**
  if R1 (Phase A inadvertently fixed it) is the working theory. Add a
  regression test that exercises the original failure shape and lock
  it in. Move to Phase C (visual inspection of factuur-21).
- **(P2) Continue Phase B with targeted-reproducer hunt**: add
  diagnostic prints in `_pushElement` for the actual `swift run
  Invoices` run; capture today's trace and compare to the 2026-05-11
  trace. If the 2026-05-11 trace pattern is no longer reproducible,
  conclude R1.
- **(P3) Investigate user-suspected page-1 vertical-stack at the
  source level**: the user's `Letter.Header` view is the structural
  source of the rendered Letter.Header table. With explicit
  authorization, read-only inspection (not edit) of that source would
  let us discriminate "table has empty right cell on row 2" vs
  "rendering corrupts the right cell". This is class-(c) escalation
  territory.

## References

- `Research/css-fidelity-gap-inventory.md` §Addendum (2026-05-11) —
  prior hypothesis.
- `Tests/PDF HTML Rendering Tests/BaselineEmpiricalTests.swift` test 5
  — minimal reproducer (passes).
- `Sources/PDF HTML Rendering/PDF.HTML.Context+Rendering.swift:457-493`
  — `_popElement`.
- `Sources/PDF HTML Rendering/PDF.HTML.Context+Rendering.swift:793-806`
  — `popBlockElement` table case (savedTable restore).
- `Sources/PDF HTML Rendering/PDF.HTML.Context+Rendering.swift:384-386`
  — `_pushElement` savedTable capture.
- `swift-render-primitives/Sources/Render Primitives Core/Render.Context.swift:165-186`
  — iterative `_stack` renderer.
- `swift-render-primitives/Sources/Render Primitives Core/Render._Tuple.swift:21-43`
  — sibling stack-push pattern.
- `swift-render-primitives/Sources/Render Primitives Core/Render.View.swift:18-34`
  — default `_render` (push-with-Thunk(view:) deferred dispatch).
