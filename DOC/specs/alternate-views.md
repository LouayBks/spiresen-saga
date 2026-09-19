# Spec: Alternate views (≤3 per Map) (#34)

Format per `DOC/templates/spec_design_template.md` (ADR-006). Owns per-view position and Link storage. Cites `box-sizing.md` CON-1 rather than redeciding it: size does not vary by view. Does not touch `content-authoring.md`'s fields (`note`/`urls`/article body) — those stay identical across every view of a node, same as its inferred visualization state (`content-authoring.md` CON-8).

**Revision note (2026-09-18, part 1):** updated for `naming.md`'s rename — the top-level per-user collection is now **Map** (schema/code term), not "Saga." "Saga" is reserved for the product's public brand name and no longer appears in schema/key patterns.

**Revision note (2026-09-18, part 2):** updated for `naming.md`'s further rename — the individual canvas item is now **Node** (schema/code term), not "Box." See `naming.md` for the full rename table.

**Revision note (2026-09-18, part 3):** this spec's rules apply to *any* Map, not just the top-level one. A node with 2+ children contains its own nested Map (`application_architecture.md`'s correction, `window-system.md`) — that nested Map gets the same ≤3-View system this spec already defines generically. Nothing below needed rewording; "a Map" already meant any Map.

**Revision note (2026-09-18, part 4):** `kind` is retired as a stored field (`naming.md`, `content-authoring.md`). CON-2 below is updated accordingly.

**Amendment (2026-09-18, `ADR-006`):** this spec originally decided physical DynamoDB key/item shapes for `Link` and `View` (literal `PK`/`SK` patterns, an explicit "own item" call for View, a chosen-over comparison against a `VIEWPOS#{viewId}#{nodeId}` item type). `ADR-006`'s amendment retroactively rules that out of a spec's scope — a spec decides the domain model and the requirements storage must satisfy, never the physical shape. The Decisions and Constraints below are rewritten accordingly: the domain-level calls (Link is view-scoped, View is a first-class entity, positions vary per view) stand unchanged: only the literal key syntax and item-type reasoning are replaced with requirement statements for `#36` (Data foundation) to satisfy.

**Revision note (2026-09-19):** (1) `tier` → `size` throughout, per `box-sizing.md`'s revision (free grid-unit `{w, h}`, still identical across Views). (2) `positions[viewId]` `{x, y}` is measured in the same grid units as `size`. (3) A View's layout mode (grid vs. freeform) is derived from whether that View has any Link (`window-system.md` CON-6) — this spec's Link and position rules are unchanged by it, but note it is the reason a View's Link count matters beyond Link display.

## Objective

Replace `boxes-plan.md`'s auto-computed Timeline/Theme layout engine — confirmed speculative scope added during mockup drafting, not a real requirement — with the actual requirement: up to 3 owner-arranged Views per Map, each a distinct arrangement of the same nodes' positions and links.

## Context

- Ticket: #34.
- Updates once accepted: `boxes-plan.md` §3 (replace the Timeline/Theme auto-layout description). Feeds `#36` ("Data foundation"), which owns the actual `Node`/`Link`/`View` storage shape and, once decided, updates `application_architecture.md`'s schema section — this spec supplies the requirements that shape must satisfy (below), not the shape itself.
- Resolves the ticket's two open data-model questions explicitly (see Decisions) — this spec is the deciding document `application_architecture.md` currently has no answer for; the physical storage answering them is `#36`'s.

## Decisions

- **Positions vary per View: `Node.positions` is a map keyed by `viewId`, not a single fixed position.** `Node.positions: { [viewId]: {x, y} }` replaces the single `Node.position {x, y}` field — a domain-model fact about Node, not a storage decision. **Anticipated requirement for #36:** storing up to 3 views' worth of position data per node MUST NOT require an item count that scales with (nodes × views), and repositioning one node in one view MUST be a single, narrow write — not a write that touches every view's data or a separate record per view. How that's achieved (one field vs. a separate item type vs. something else) is #36's call, not decided here.
- **Links are view-scoped, not shared across views.** A `Link` belongs to exactly one View — `viewId` is an intrinsic, non-optional part of what identifies a Link, never a shared/multi-view reference. This is the literal reading of the ticket's own objective — "a different arrangement of positions *and links*" — a theme-clustering view and a timeline view plausibly want different connective structure between the same nodes, not merely a different layout of one fixed link set. If the same relationship genuinely belongs in two views, it's modeled as two separate Links (one per view), not one Link referenced twice — keeps authorization/deletion unambiguous (deleting a view cleanly deletes exactly its own links, nothing shared to orphan-check).
- **View is a first-class entity, sibling to Node and Link under the same Map, with a `name` and an optional `order`.** Named here explicitly since the first draft implied but never actually specified it as its own entity. **Anticipated requirement for #36:** a Map's Nodes, Links, and Views MUST be fetchable together in one request — introducing View as an entity MUST NOT force a second round-trip or a per-view endpoint. The physical storage representation (its own item, embedded, or otherwise) is #36's decision.
- **Every Map always has at least one View.** A Map is created with exactly one default View; a Map's last remaining View cannot be deleted. This avoids an empty-view broken state and matches the existing mockup default (Freeform is always populated).
- **New nodes get a position in every existing View.** When a node is created, the backend seeds a positions entry for every View the Map currently has (same coordinates initially is acceptable — the owner repositions per view afterward) — otherwise a node created while viewing View A would be invisible/undefined when switching to View B.
- **View creation/naming/switching UI is explicitly out of scope here** (belongs to #40) — this spec fixes the data-model contract those UI pieces are built against; #36 fixes the storage contract underneath that.

## Expected behaviors (`BHV-*`)

| ID | Statement | Testability check | Notes |
|---|---|---|---|
| BHV-1 | WHEN a Map is created, THE backend SHALL create exactly one default View for it. | ✅ — integration test: create a Map, assert exactly one View record exists | |
| BHV-2 | IF the owner requests a new View on a Map that already has 3 Views, THEN THE backend SHALL reject the request. | ✅ — integration test: create a 4th View on a 3-View Map, assert 4xx | |
| BHV-3 | IF the owner requests deletion of a Map's only remaining View, THEN THE backend SHALL reject the request. | ✅ — integration test: delete the sole View, assert 4xx and the View still exists | |
| BHV-4 | WHEN a node is dragged and dropped while a given View is active, THE backend SHALL update only that node's `positions[viewId]` entry, leaving its position in every other View unchanged. | ✅ — integration test: move a node in View A, fetch View B, assert its position there is untouched | Debounced on `pointerup`, per `boxes-plan.md` §2's existing drag-persistence rule — not reopened here. |
| BHV-5 | WHEN the owner switches the active View, THE canvas SHALL re-render every node at its `positions[viewId]` for the newly active View and SHALL render only Links whose `viewId` matches it. | ✅ — component test: switch views, assert rendered node coordinates and rendered link set both change to match the new `viewId` | |
| BHV-6 | WHEN a node is created, THE backend SHALL seed a `positions` entry for that node in every existing View of the Map. | ✅ — integration test: create a node while Views A and B both exist, assert the node has a position entry for both | |

## Constraints (`CON-*`)

| ID | Statement | Notes |
|---|---|---|
| CON-1 | A Map MUST have between 1 and 3 Views (inclusive) at all times. | Enforced by BHV-1 (floor) and BHV-2/BHV-3 (ceiling/floor on mutation). |
| CON-2 | A Node's inferred visualization state, `size`, `note`, `urls`, and content body MUST be identical across every View — only `positions[viewId]` and View-scoped Links vary. | Cross-references `box-sizing.md` CON-1 (size) and `content-authoring.md` CON-8 (visualization inference) rather than re-deciding either. Updated from "`kind`," now retired. |
| CON-3 | A `Link` MUST belong to exactly one View — `viewId` MUST be an intrinsic part of what identifies a Link, not a shared/multi-view reference. | The relationship-in-two-views case is modeled as two separate Links, not one shared one — see Decisions. Storage realization (whether `viewId` is literally part of a physical key) is #36's decision. |
| CON-4 | A Map's Nodes, Links, and Views MUST remain fetchable together in a single request — introducing View as an entity MUST NOT require a second request or a per-view endpoint. | Anticipated requirement for #36, preserving the Lambda-lean, single-request-per-Map design named in `application_architecture.md`, without asserting how #36 achieves it. |
| CON-5 | Deleting a View MUST delete only that View's own Links and its nodes' `positions[viewId]` entries — it MUST NOT delete the nodes themselves or their other Views' data. | Direct consequence of CON-3's per-view Link ownership. |

## Open questions

None blocking — the ticket's data-model and link-scoping questions are both resolved above; the physical storage shape realizing them is #36's open decision, not this spec's.

## Out of scope

No implementation, no DynamoDB key/item shape or transaction mechanics — that's #36's decision, informed by the "Anticipated requirement for #36" callouts above. Does not decide View creation/naming/switching UI (#40) or how a View's name is chosen/validated beyond existing (that's a UI-copy detail for #40, not a modeling decision).
