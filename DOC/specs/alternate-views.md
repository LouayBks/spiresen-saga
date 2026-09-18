# Spec: Alternate views (≤3 per Map) (#34)

Format per `DOC/templates/spec_design_template.md` (ADR-006). Owns per-view position and Link storage. Cites `box-sizing.md` CON-1 rather than redeciding it: tier does not vary by view. Does not touch `content-authoring.md`'s fields (`note`/`urls`/article body) — those stay identical across every view of a node, same as `kind`.

**Revision note (2026-09-18, part 1):** updated for `naming.md`'s rename — the top-level per-user collection is now **Map** (schema/code term), not "Saga." "Saga" is reserved for the product's public brand name and no longer appears in schema/key patterns.

**Revision note (2026-09-18, part 2):** updated for `naming.md`'s further rename — the individual canvas item is now **Node** (schema/code term), not "Box." See `naming.md` for the full rename table.

**Revision note (2026-09-18, part 3):** this spec's rules apply to *any* Map, not just the top-level one. A `group`-kind Node contains its own nested Map (`application_architecture.md`'s correction, `window-system.md`) — that nested Map gets the same ≤3-View system this spec already defines generically. Nothing below needed rewording; "a Map" already meant any Map.

## Objective

Replace `boxes-plan.md`'s auto-computed Timeline/Theme layout engine — confirmed speculative scope added during mockup drafting, not a real requirement — with the actual requirement: up to 3 owner-arranged Views per Map, each a distinct arrangement of the same nodes' positions and links.

## Context

- Ticket: #34.
- Updates once accepted: `boxes-plan.md` §3 (replace the Timeline/Theme auto-layout description) and `application_architecture.md`'s schema section (`Node`/`Link` shape changes below).
- Resolves the ticket's two open storage-shape questions explicitly (see Decisions) — this spec is the deciding document `application_architecture.md` currently has no answer for.

## Decisions

- **Positions: a per-Node map keyed by view, not separate per-view position records.** `Node.positions: { [viewId]: {x, y} }` replaces the single `Node.position {x, y}` field. Chosen over a separate `VIEWPOS#{viewId}#{nodeId}` item type because it keeps one item per node (no item-count explosion at up to 3 views × N nodes), a drag-end `PATCH` still touches exactly one field path on one item, and it stays trivially inside the existing "single `Query` on `PK = MAP#{id}`" design — no new item type for the Map partition to fan out over.
- **Links are view-scoped, not shared across views.** A `Link` belongs to exactly one View: `PK: MAP#{mapId} SK: LINK#{viewId}#{nodeA}#{nodeB}`. This is the literal reading of the ticket's own objective — "a different arrangement of positions *and links*" — a theme-clustering view and a timeline view plausibly want different connective structure between the same nodes, not merely a different layout of one fixed link set. If the same relationship genuinely belongs in two views, it's two `Link` records (one per view), not one record referenced twice — keeps authorization/deletion unambiguous (deleting a view cleanly deletes exactly its own links, nothing shared to orphan-check).
- **Views get their own item, sibling to `Node`/`Link` under the same Map partition:** `PK: MAP#{mapId} SK: VIEW#{viewId} -> {name, order?}` — named here explicitly since the first draft implied but never wrote this key pattern.
- **Every Map always has at least one View.** A Map is created with exactly one default View; a Map's last remaining View cannot be deleted. This avoids an empty-view broken state and matches the existing mockup default (Freeform is always populated).
- **New nodes get a position in every existing View.** When a node is created, the backend seeds a positions entry for every View the Map currently has (same coordinates initially is acceptable — the owner repositions per view afterward) — otherwise a node created while viewing View A would be invisible/undefined when switching to View B.
- **View creation/naming/switching UI is explicitly out of scope here** (belongs to #40) — this spec fixes the data contract those UI pieces are built against.

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
| CON-2 | A Node's `kind`, `tier`, `note`, `urls`, and content body MUST be identical across every View — only `positions[viewId]` and View-scoped Links vary. | Cross-references `box-sizing.md` CON-1 (tier) and `content-authoring.md` (content fields) rather than re-deciding either. |
| CON-3 | A `Link` MUST belong to exactly one View (`viewId` is part of its key, not a shared/multi-view reference). | The relationship-in-two-views case is modeled as two `Link` records, not one shared one — see Decisions. |
| CON-4 | `Node`, `Link`, and `View` records MUST remain retrievable in the same single `Query` on `PK = MAP#{mapId}` — introducing Views MUST NOT require a second query or a per-view endpoint. | Preserves the existing Lambda-lean, single-partition-query design named in `application_architecture.md`. |
| CON-5 | Deleting a View MUST delete only that View's own Links and its nodes' `positions[viewId]` entries — it MUST NOT delete the nodes themselves or their other Views' data. | Direct consequence of CON-3's per-view Link ownership. |

## Open questions

None blocking — the ticket's storage-shape and link-scoping questions are both resolved above.

## Out of scope

No implementation. Does not decide View creation/naming/switching UI (#40) or how a View's name is chosen/validated beyond existing (that's a UI-copy detail for #40, not a schema decision).
