# Spec: Node sizing/emphasis model (#32)

Format per `DOC/templates/spec_design_template.md` (ADR-006). Owns the `Node.size` field and everything about how size is chosen — `alternate-views.md` (#34) cites this spec's CON-1 rather than redeciding it, to avoid the two specs disagreeing about whether size can vary per view. Filename kept as `box-sizing.md` (topic label tied to ticket #32) even though the entity is now Node — see `naming.md`.

**Revision note (2026-09-19): the three fixed tiers (S/M/L) are withdrawn in favor of a free, grid-unit size.** Decided during the #36 data-model discussion: a Node's size is an integer width × height measured in grid units (e.g. 2×2, 2×4), not one of three enumerated footprints. This makes size meaningful in both layout modes (`window-system.md`) with a single field — in a grid-layout View it is literally the cell span, in a freeform View it is the same unit scaled by zoom — and removes the need for a separate "tier → cell span" mapping that `window-system.md`'s open question had left undefined. The emphasis rationale is unchanged: the owner still deliberately chooses how big an idea is, size is still never inferred, and it is still one value per Node regardless of View.

## Objective

Decide how a node's size communicates the emphasis/importance of the idea it holds, before the canvas-core ticket (#37) locks in rendering behavior, in a way that works identically for the freeform canvas and for a grid-layout Map.

## Context

- Ticket: #32.
- Updates once accepted: `boxes-plan.md` §4 (replace the S/M/L tier table with the grid-unit size model); feeds the `Node.size` field into the data foundation ticket (#36).
- Supersedes this spec's own first draft, which resolved `boxes-plan.md` §4's "free-resize is the fastest way to turn a curated canvas into visual noise" concern by keeping three fixed tiers. The concern still stands as a UX risk to watch (the owner can now make arbitrary shapes), but it is accepted as the owner's own composition choice rather than prevented structurally.

## Decision

**A Node's size is `{w, h}`: two positive integers in grid units, with a system-wide minimum of 1 and a configurable maximum.** The grid unit is the same unit `Node.positions` uses (`alternate-views.md`), so a Node's footprint, its position, and a grid cell are all measured in one coordinate space. In a View that is currently laid out as a grid (`window-system.md`), a Node occupies a `w × h` block of cells. In a freeform View, the same `w × h` is its footprint, scaled uniformly by zoom. Soft-snap alignment guide behavior (`boxes-plan.md` §4) is unchanged and applies to freeform placement only.

How the owner edits a size (drag handle, numeric fields, or a preset shortcut list) is deliberately not decided here — that is a UI detail. What is decided is what the value *is*.

## Expected behaviors (`BHV-*`)

| ID | Statement | Testability check | Notes |
|---|---|---|---|
| BHV-1 | WHEN the owner sets a node's size, THE backend SHALL persist it as integer `w` and `h` within the allowed range, and SHALL reject a non-integer, zero/negative, or above-maximum value. | ✅ — integration test: submit sizes `0×1`, `1.5×2`, and `(max+1)×1`, assert each is rejected with a 4xx; submit `2×4`, assert it round-trips | Replaces the withdrawn three-option picker BHV. |
| BHV-2 | THE canvas SHALL render every node at a footprint of exactly its `w × h` grid units, scaled uniformly by the current zoom level. | ✅ — snapshot/measurement test at two zoom levels confirms two nodes of different sizes scale by the same factor | Carries forward the existing "grid-relative, not pixel-fixed" rule. |
| BHV-3 | WHEN a node is dragged near another node's edge or center in a freeform View, THE canvas SHALL show a soft alignment guide regardless of the two nodes' sizes. | ✅ — drag-simulation test with a 1×1 node near a 4×4 node's edge asserts the guide renders | Restates `boxes-plan.md` §4's existing soft-snap rule for completeness; not a new decision. |

## Constraints (`CON-*`)

| ID | Statement | Notes |
|---|---|---|
| CON-1 | A Node's `size` MUST be identical across every View of its Map — size does not vary per view. | Owning decision for this field; `alternate-views.md` cites this row rather than deciding it independently. |
| CON-2 | A Node's `size` MUST be a pair of integers `w`, `h`, each at least 1 and at most a configurable system-wide maximum. | Replaces the withdrawn "exactly three enumerated values" rule. The maximum is a tunable constant, not a product commitment — the suggested starting value is 12 (matching the grid's 12 columns, `window-system.md`), to be tuned as real use teaches us. |
| CON-3 | A Node's `size` MUST NOT be inferred automatically from its visualization state (`content-authoring.md` CON-7) or content length — it is always an explicit owner choice, with a fixed default only at creation (`node-link-lifecycle.md`). | Unchanged in substance from the first draft. |

## Open questions

- The grid's column count (and therefore how a Node whose `w` exceeds it behaves) and how a grid-layout View resolves overlapping blocks are `window-system.md`'s open questions, not this spec's.

## Out of scope

No implementation. Does not decide the size-editing affordance (drag handle vs. numeric input vs. presets) — a UI detail for the canvas-core/content-authoring UI tickets (#37/#39). Does not decide the grid layout algorithm itself (`window-system.md`).
