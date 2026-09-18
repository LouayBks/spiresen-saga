# Spec: Node sizing/emphasis model (#32)

Format per `DOC/templates/spec_design_template.md` (ADR-006). Owns the `Node.tier` field and everything about how size is chosen — `alternate-views.md` (#34) cites this spec's CON-1 rather than redeciding it, to avoid the two specs disagreeing about whether size can vary per view. Filename kept as `box-sizing.md` (topic label tied to ticket #32) even though the entity is now Node — see `naming.md`.

## Objective

Decide how a node's size communicates the emphasis/importance of the idea it holds, before the canvas-core ticket (#37) locks in rendering behavior around `boxes-plan.md` §4's three fixed tiers.

## Context

- Ticket: #32.
- Updates once accepted: `boxes-plan.md` §4 (reframe the tier table's purpose explicitly as an emphasis mechanic, not just a footprint spec); flags the `Node.tier` schema field for the data foundation ticket (#36).
- Resolves against `boxes-plan.md` §4's own reasoning: free-resize is explicitly flagged there as "the fastest way to turn a curated canvas into visual noise" — the correction that size should "emphasize certain ideas" is read as *why* the owner picks a tier, not as a reason to abandon fixed tiers for free resize.

## Decision

**Keep the three fixed tiers (S/M/L), reframed explicitly as a deliberate emphasis choice** — not a footprint picked by content type or defaulted automatically. The owner picks S for a passing mention, M for a notable item, L for a featured/headline idea. A picker (not drag-resize handles) is the editing affordance: it keeps the "exactly three, deliberately chosen" model textually honest — a resize handle implies continuous choice, which is exactly what `boxes-plan.md` §4 already argued against. Soft-snap alignment guide behavior is unchanged from the existing spec (`boxes-plan.md` §4) — nothing about emphasis-driven tier selection affects how edges/centers snap on drag, so it isn't relitigated here.

**Revision note (2026-09-18):** in freeform contexts (the outer canvas, or a nested Map that's switched to freeform per `window-system.md`), tier means what this spec already says — a footprint scaled by zoom. In a nested Map still in its default **grid** layout (`window-system.md` BHV-12/13), tier additionally determines a fixed grid-cell span, Android-homescreen-widget style (e.g. S = 1×1 cell, M/L = larger spans) — the exact spans aren't settled here, flagged in `window-system.md`'s Open questions as needing its own design pass. This doesn't change anything in this spec's own decision — tier is still the same three-value, owner-chosen field either way; grid mode just gives it a second meaning (cell span) alongside footprint.

## Expected behaviors (`BHV-*`)

| ID | Statement | Testability check | Notes |
|---|---|---|---|
| BHV-1 | WHEN the owner creates or edits a node, THE editor SHALL present exactly three size choices (S, M, L), each with a one-line description of its intended emphasis (e.g. "a passing mention" / "a featured idea"). | ✅ — component test asserting exactly 3 options render, none of them a free-text/numeric size input | |
| BHV-2 | THE canvas SHALL render every node at one of exactly three fixed footprints (per `boxes-plan.md` §4's grid-relative units), scaled uniformly by the current zoom level. | ✅ — snapshot/measurement test at two zoom levels confirms the three footprints scale by the same factor | Carries forward the existing "grid-relative, not pixel-fixed" rule; not reopened. |
| BHV-3 | WHEN a node is dragged near another node's edge or center, THE canvas SHALL show a soft alignment guide regardless of the two nodes' tiers. | ✅ — drag-simulation test with an S node near an L node's edge asserts the guide renders | Restates `boxes-plan.md` §4's existing soft-snap rule for completeness; not a new decision. |

## Constraints (`CON-*`)

| ID | Statement | Notes |
|---|---|---|
| CON-1 | A Node's `tier` MUST be identical across every View of its Map — tier does not vary per view. | Owning decision for this field; `alternate-views.md` cites this row rather than deciding it independently. |
| CON-2 | A Node's `tier` MUST be one of exactly three enumerated values (`S`, `M`, `L`) — no free-form or numeric size field. | Flagged for #36's `Node` schema. |
| CON-3 | A Node's `tier` MUST NOT be inferred automatically from its visualization state (`content-authoring.md` CON-8) or content length — it is always an explicit owner choice. | Updated from "`kind`" now that visualization is inferred, not stored — tier stays orthogonal to it either way. |
| CON-4 | The editing UI MUST NOT expose drag-to-resize handles on a node. | Direct consequence of rejecting free resize; keeps the picker as the only path to changing tier. |

## Open questions

None — the ticket's tasks are fully resolved above; nothing here blocks #36/#37.

## Out of scope

No implementation. Does not decide the picker's visual design (icon vs. label vs. preview thumbnail per option) — left to the content-authoring/canvas-core UI tickets (#39/#37) as an implementation detail, not a modeling decision.
