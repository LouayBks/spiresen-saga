# Spec: Node & Link lifecycle (create/delete) (#43)

Format per `DOC/templates/spec_design_template.md` (ADR-006). Owns the create/delete actions themselves for Nodes and Links — cites `box-sizing.md` for the size model, `content-authoring.md` for the content-inference rules, and `alternate-views.md` for view-scoping, rather than redeciding any of those. Fills a real gap: none of the other four Stage-A specs actually define how a Node or Link comes into existence or gets removed.

**Revision note (2026-09-18, part 1):** every rule below applies inside any nested Map exactly as written, not just at the top level (`application_architecture.md`'s correction, `window-system.md`) — "the active View"/"the Map" throughout means whichever Map's window the owner currently has open.

**Revision note (2026-09-18, part 2):** `kind` is retired as a stored, chosen-at-creation field (`naming.md`, `content-authoring.md`). The inline kind picker this spec's first draft described is withdrawn — creation is now kind-less, and a node's presentation emerges from what's subsequently attached to it. This draft adds the mechanic that was previously implicit: how a node actually *gets* its first child, since there's no more "pick group" step to trigger it.

**Revision note (2026-09-19):** (1) `tier` → `size` (`box-sizing.md`); new Nodes default to `1×1`. (2) Links are undirected — at most one per unordered pair of Nodes per View. (3) Deleting a View's last Link returns it to grid layout (`window-system.md` CON-6).

## Objective

Define how Nodes and Links get created and deleted — `boxes-plan.md` names link creation loosely ("drag from one box's edge to another") and mentions a link create/delete endpoint in passing, but specifies no Node-creation UX, no deletion mechanic for either entity, and no uniqueness constraints. `alternate-views.md`'s BHV-6 already assumes Node creation as an event without defining what triggers it — this spec is that missing trigger.

## Context

- Ticket: #43.
- Updates once accepted: `boxes-plan.md` §5 (link creation mechanics) and §7 (MVP scope wording); `application_architecture.md`'s schema section (uniqueness/cascade notes on `Node`/`Link`).
- Depends on (cites, doesn't redecide): `box-sizing.md` (size model, CON-1/CON-2), `window-system.md` (CON-6, layout derived from Link count), `content-authoring.md` (visualization-inference rules, CON-8/CON-9), `alternate-views.md` (BHV-6 node-creation seeding, CON-3 one-View-per-Link).

## Decisions

- **Node creation: a small "+" affordance, not a modal-first flow.** Clicking empty canvas space (or a persistent toolbar "+"), on the outer canvas or inside any open Map window, drops a new **blank** Node at that point, in the active View. No kind picker — the node starts as a plain info node (title empty, no content) and becomes whatever `content-authoring.md`'s inference rules say once something is attached or nested inside it.
- **Initial size defaults to the minimum, 1×1** — the owner can change it at any time after creation, via whatever size-editing affordance `box-sizing.md`'s implementation ticket settles on.
- **"Add inside" is a new, always-available action on every Node, regardless of its current visualization.** This is the mechanic that replaces "pick group at creation": since there's no more explicit group choice, something has to let the owner start nesting content under *any* node, even one that currently renders as a plain info node. Triggering it opens (creating, if this is the first time) that node's own nested Map — a window, per `window-system.md` — and the same "+" flow runs inside it, recursively. The node's outer-canvas rendering updates automatically once it crosses `content-authoring.md` CON-8's 2-child threshold.
- **A newly created Node is seeded into every existing View** at the same coordinates it was created at, per `alternate-views.md` BHV-6.
- **Node deletion requires a confirmation step**, since it can destroy authored content (an article body, uploaded media, or an entire nested Map) with no version history (`content-authoring.md` CON-6: always-overwrite, no undo). Confirmation copy names what's actually at stake: if the node has children, everything in its nested Map goes with it (real Nodes, real Links, real Views — not a small inline list). See #45 for the separate, not-yet-designed trash-bin/recovery idea raised alongside this.
- **Deleting a Node cascades to its Links, in whichever Map it lives in.** Any `Link` referencing the deleted Node (in any View of *that* Map) is deleted too. Deleting a node that has its own nested Map deletes that entire Map — its Nodes, Links, Views, all of it — not just the one row.
- **Link creation: drag from one node's edge to another** (confirms `boxes-plan.md` §5 as written), releasing over a second node opens a small inline picker for link type (theme / timeline / soft) before the Link is actually written.
- **A Link MAY carry an optional label** — named in `boxes-plan.md` §2's original schema. The type picker includes an optional short-text field for it; leaving it blank is the common case. Unlike type (CON-2: delete-then-recreate to change), the label is freely editable after creation.
- **A Link is scoped to the View active when it's created** (`alternate-views.md` CON-3).
- **At most one Link between any two Nodes within a given View, in either direction.** A Link is undirected — A→B and B→A are the same relationship, so a second Link between the same pair is rejected whichever endpoint the owner drags from. To change a relationship's *type*, the owner deletes the existing Link and creates a new one. (The label is editable in place — see above.)
- **A Node MUST NOT link to itself.** Rejected client-side before any request fires.
- **A Link's two endpoints MUST both belong to the same Map.** Replaces the withdrawn "only top-level Nodes can be linked" rule from the first draft — now that children are real Nodes with real Links, the actual constraint is scope, not level: a node inside one nested Map can't link to a node inside a *different* Map (nested or top-level). Drawing a link is only ever offered between two nodes visible in the same open window/canvas, so this is enforced structurally by the drag gesture itself, not just server-side.
- **Deleting a View's last Link returns that View to grid layout** (`window-system.md` CON-6) — a consequence worth surfacing in the UI, but not a separate confirmation step.
- **Link deletion: click to select, then a small delete affordance.** A small "×" appears at its midpoint, or `Delete`/`Backspace` removes the selected Link. No confirmation step — a Link carries no content of its own.

## Expected behaviors (`BHV-*`)

| ID | Statement | Testability check | Notes |
|---|---|---|---|
| BHV-1 | WHEN the owner clicks empty canvas space (or the toolbar "+"), THE backend SHALL create a blank Node (no content, size `1×1`) at the clicked coordinates, in the active View — with no intermediate picker. | ✅ — integration test: click empty canvas, assert a Node exists immediately with size `1×1` and no content, no picker rendered | Replaces the withdrawn kind-picker BHV. |
| BHV-2 | WHEN a Node is created, THE backend SHALL seed a `positions` entry for it in every other existing View of its Map (per `alternate-views.md` BHV-6). | ✅ — same test as `alternate-views.md` BHV-6 | |
| BHV-3 | WHEN the owner triggers "Add inside" on any Node, THE UI SHALL open (creating if it doesn't yet exist) that Node's own nested Map as a window. | ✅ — component test: trigger "Add inside" on a node with 0 children, assert a window opens showing an empty Map | First use of this action is what brings the nested Map into existence. |
| BHV-4 | WHEN a Node crosses from 1 to 2 children, THE outer view containing it SHALL re-render it with map/group visualization (per `content-authoring.md` CON-8), with no separate "convert to group" action required. | ✅ — integration test: add a 2nd child under a node, re-fetch its parent Map, assert the node's inferred visualization is now "map" | The emergent-type mechanic this whole revision is built around. |
| BHV-5 | WHEN the owner requests deletion of a Node, THE UI SHALL show a confirmation naming what will be lost — content, and, if it has children, its entire nested Map (Nodes, Links, Views) — before the backend deletes anything. | ✅ — component test: trigger delete on a node with children, assert the confirmation copy names the nested Map's contents | |
| BHV-6 | WHEN a Node is deleted, THE backend SHALL cascade-delete every Link referencing it in its own Map, and — if it has children — its entire nested Map (all Nodes/Links/Views under `PK: MAP#{thatNodeId}`). | ✅ — integration test: delete a node with a nested Map containing further nodes/links, assert the whole partition is gone | |
| BHV-7 | WHEN the owner drags from one node's edge and releases over a second node in the same Map, THE canvas SHALL present an inline link-type picker (theme / timeline / soft) before creating the Link. | ✅ — drag-simulation test: drag node A's edge to node B in the same window, assert the picker renders, no Link created yet | |
| BHV-8 | IF the drag-release target is a node in a different Map than the drag started in, THEN THE UI SHALL cancel the gesture — cross-Map linking is not offered. | ✅ — test: attempt to drag from an outer-canvas node onto a node visible in a different open window, assert no picker (structurally prevented by what's draggable into what) | Enforces the new CON-4. |
| BHV-9 | IF a Link already exists between the two selected nodes in the active View — in either direction — THEN THE backend SHALL reject the new Link request. | ✅ — integration test: create a Link A→B, attempt B→A and a second A→B in the same View, assert both rejected with 4xx | Links are undirected (2026-09-19). |
| BHV-10 | IF the drag-release target is the same node the drag started from, THEN THE UI SHALL cancel the gesture without opening the link-type picker. | ✅ — drag-simulation test: drag and release on the same node, assert no picker, no request | |
| BHV-11 | WHEN the owner clicks a Link curve, THE canvas SHALL select it and show a delete affordance at its midpoint. | ✅ — component test: click a rendered link path, assert a delete control appears | |
| BHV-12 | WHEN the owner deletes a selected Link, THE backend SHALL remove it immediately, with no confirmation step. | ✅ — integration test: delete a Link, assert it's gone and no confirmation dialog was rendered | |
| BHV-13 | WHEN the owner edits a selected Link's label, THE backend SHALL update it in place without requiring the Link to be deleted and recreated. | ✅ — integration test: edit a Link's label, assert the same Link id persists with the new label | |

## Constraints (`CON-*`)

| ID | Statement | Notes |
|---|---|---|
| CON-1 | A Node MUST NOT have a Link where both endpoints are itself. | |
| CON-2 | At most one Link MUST exist between any two Nodes within a given View, regardless of type and regardless of which endpoint the owner dragged from. | Links are undirected; a Link has no from/to ordering. Changing a relationship's type is delete-then-recreate. |
| CON-2a | A Link's `label` MUST be optional and freely editable in place. | |
| CON-3 | Deleting a Node MUST cascade-delete every Link referencing it in its own Map, and — if it has children — its entire nested Map. | Widened from the first draft's "just its Links" to match real recursive deletion. |
| CON-4 | A Link's two endpoints MUST both belong to the same Map — no Link may span two different Maps (nested or top-level). | Replaces the withdrawn "top-level Nodes only" rule from the first draft. |
| CON-5 | A newly created Node's `size` MUST default to `1×1` and MUST carry no content of any kind at creation. | Widened: no `kind` to default either, since the field no longer exists. |
| CON-6 | Node deletion MUST require an explicit confirmation step; Link deletion MUST NOT. | |

## Open questions

None — `content-authoring.md`'s exactly-1-child behavior is now resolved, and its lightweight/annotation toggle is deferred to the backlog (#46), not an open question anymore.

## Out of scope

No implementation (that's #37/#38). Does not decide the exact visual design of the "+" affordance, "Add inside," the link-type picker, or the delete-midpoint control.
