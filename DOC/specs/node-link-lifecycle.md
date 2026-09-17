# Spec: Node & Link lifecycle (create/delete) (#43)

Format per `DOC/templates/spec_design_template.md` (ADR-006). Owns the create/delete actions themselves for Nodes and Links — cites `box-sizing.md` for the tier picker, `content-authoring.md` for per-kind content authoring, and `alternate-views.md` for view-scoping, rather than redeciding any of those. Fills a real gap: none of the other four Stage-A specs actually define how a Node or Link comes into existence or gets removed.

## Objective

Define how Nodes and Links get created and deleted — `boxes-plan.md` names link creation loosely ("drag from one box's edge to another") and mentions a link create/delete endpoint in passing, but specifies no Node-creation UX, no deletion mechanic for either entity, and no uniqueness constraints. `alternate-views.md`'s BHV-6 already assumes Node creation as an event without defining what triggers it — this spec is that missing trigger.

## Context

- Ticket: #43.
- Updates once accepted: `boxes-plan.md` §5 (link creation mechanics) and §7 (MVP scope wording); `application_architecture.md`'s schema section (uniqueness/cascade notes on `Node`/`Link`).
- Depends on (cites, doesn't redecide): `box-sizing.md` (tier picker, CON-1/CON-2), `content-authoring.md` (per-kind content authoring flows), `alternate-views.md` (BHV-6 node-creation seeding, CON-3 one-View-per-Link).

## Decisions

- **Node creation: a small "+" affordance on the canvas, not a modal-first flow.** Clicking empty canvas space (or a persistent toolbar "+") drops a new Node at that point, in the currently active View. This matches `boxes-plan.md` §10's "calm, minimalist" bar — no dialog interrupts the canvas for the most common authoring action.
- **Kind is chosen immediately at creation**, via a small inline picker (note / media / group / annotation) right after the "+" interaction — before size or content, since `kind` determines what the rest of the creation flow even looks like (a `media` node immediately offers an upload per `content-authoring.md`; a `group` node starts with zero children; a `note` node starts with empty title/body; an `annotation` node starts with its single empty text field, per `content-authoring.md`'s later addition).
- **Initial tier defaults to S** (the least visually committal choice) — the owner can change it via `box-sizing.md`'s picker at any time after creation; tier is never asked as a required creation-time step, keeping the "+" flow to one decision (kind) before a node exists on the canvas.
- **A newly created Node is seeded into every existing View** at the same coordinates it was created at, per `alternate-views.md` BHV-6 — this spec doesn't redecide that, just confirms the creation flow is what triggers it.
- **Node deletion requires a confirmation step**, since it can destroy authored content (an article body, uploaded media) with no version history (`content-authoring.md` CON-6: always-overwrite, no undo). Confirmation copy explicitly names the consequence for a `group`-kind node (its inline children are lost too, since they have no independent id — `application_architecture.md`'s group-nesting exception).
- **Deleting a Node cascades to its Links.** Any `Link` referencing the deleted Node (in any View) is deleted too — a dangling Link endpoint is not a valid state. No separate confirmation for the cascaded Links; the Node-deletion confirmation covers it.
- **Link creation: drag from one node's edge to another** (confirms `boxes-plan.md` §5 as written), releasing over a second node opens a small inline picker for link type (theme / timeline / soft) before the Link is actually written — matches the "click-vs-drag threshold" convention already established for boxes-plan.md's opener pattern (§9's build note), so a drag-release is unambiguous from an accidental click.
- **A Link MAY carry an optional label** — already named in `boxes-plan.md` §2's original schema (`Link` attrs: "link type... optional label") but never carried into a creation flow anywhere until now. The type picker (above) includes an optional short-text field for it; leaving it blank is the common case, not an error. Unlike type (CON-2: delete-then-recreate to change), the label is freely editable after creation — it's descriptive metadata, not part of the uniqueness/visual-system constraint type governs.
- **A Link is scoped to the View active when it's created** (already `alternate-views.md` CON-3 — restated here as the trigger, not a new decision).
- **At most one Link between any two Nodes within a given View.** Creating a second link between an already-linked pair (in the same View) is rejected, not silently duplicated — keeps curves from overlapping ambiguously, consistent with `boxes-plan.md` §5's "no more than two link colors on screen at once, or it stops reading as a system." To change a relationship's *type*, the owner deletes the existing Link and creates a new one — no separate "edit link type" action needed for something this infrequent. (The label, unlike type, is editable in place — see above.)
- **A Node MUST NOT link to itself.** Rejected client-side before any request fires.
- **Link deletion: click to select, then a small delete affordance.** Clicking a Link curve selects it (already visually distinguished via `boxes-plan.md` §5's hover/focus behavior); a small "×" appears at its midpoint, or the `Delete`/`Backspace` key removes the selected Link. No confirmation step — a Link carries no content of its own, so the cost of a mistaken deletion is one re-drag, not lost authored work.
- **Group-inline children are never Link endpoints.** A `group` node's children are lightweight inline summaries with no id of their own (`application_architecture.md`'s group-nesting exception) — Links only ever connect two top-level Nodes. Promoting a child (the existing, separate escape hatch) is required before it can be linked to anything.

## Expected behaviors (`BHV-*`)

| ID | Statement | Testability check | Notes |
|---|---|---|---|
| BHV-1 | WHEN the owner clicks empty canvas space (or the toolbar "+"), THE canvas SHALL present an inline kind picker (note / media / group / annotation) before creating anything. | ✅ — component test: click empty canvas, assert the picker renders with exactly 4 options, no Node created yet | Updated from 3 to 4 options when `annotation` was added in `content-authoring.md`. |
| BHV-2 | WHEN the owner selects a kind from that picker, THE backend SHALL create a Node of that kind, tier `S`, at the clicked coordinates, in the active View. | ✅ — integration test: select "note," assert a Node exists with `kind: note`, `tier: S`, and a `positions[activeViewId]` matching the click point | |
| BHV-3 | WHEN a Node is created, THE backend SHALL seed a `positions` entry for it in every other existing View of the Map (per `alternate-views.md` BHV-6). | ✅ — already covered by `alternate-views.md` BHV-6; restated here only as the trigger | Not re-tested independently — same test as `alternate-views.md` BHV-6 covers this. |
| BHV-4 | WHEN the owner requests deletion of a Node, THE UI SHALL show a confirmation naming what will be lost (content, and — for a `group` node — its inline children) before the backend deletes anything. | ✅ — component test: trigger delete on a `group` node, assert the confirmation copy mentions its children | |
| BHV-5 | WHEN a Node is deleted, THE backend SHALL also delete every Link that references it, in every View. | ✅ — integration test: delete a Node with Links in two Views, assert all referencing Links are gone from both | |
| BHV-6 | WHEN the owner drags from one node's edge and releases over a second node, THE canvas SHALL present an inline link-type picker (theme / timeline / soft) before creating the Link. | ✅ — drag-simulation test: drag node A's edge to node B, assert the picker renders, no Link created yet | Release over empty canvas (not another node) cancels the gesture — no Link, no picker. |
| BHV-7 | IF a Link already exists between the two selected nodes in the active View, THEN THE backend SHALL reject the new Link request. | ✅ — integration test: attempt a second Link between an already-linked pair in the same View, assert 4xx | |
| BHV-8 | IF the drag-release target is the same node the drag started from, THEN THE UI SHALL cancel the gesture without opening the link-type picker. | ✅ — drag-simulation test: drag and release on the same node, assert no picker, no request | |
| BHV-9 | WHEN the owner clicks a Link curve, THE canvas SHALL select it and show a delete affordance at its midpoint. | ✅ — component test: click a rendered link path, assert a delete control appears | |
| BHV-10 | WHEN the owner deletes a selected Link (click the delete affordance, or press Delete/Backspace), THE backend SHALL remove it immediately, with no confirmation step. | ✅ — integration test: delete a Link, assert it's gone and no confirmation dialog was rendered | |
| BHV-11 | WHEN the owner edits a selected Link's label, THE backend SHALL update it in place without requiring the Link to be deleted and recreated. | ✅ — integration test: edit a Link's label, assert the same Link id persists with the new label | Contrast with type, which is immutable per CON-2. |

## Constraints (`CON-*`)

| ID | Statement | Notes |
|---|---|---|
| CON-1 | A Node MUST NOT have a Link where both endpoints are itself. | Rejected client-side before any request; also enforced server-side as the authoritative boundary. |
| CON-2 | At most one Link MUST exist between any two Nodes within a given View, regardless of type. | Changing a relationship's type is delete-then-recreate, not an edit action. |
| CON-2a | A Link's `label` MUST be optional and freely editable in place — it MUST NOT require delete-then-recreate the way type does. | Distinguishes descriptive metadata (label) from the uniqueness-governing field (type). |
| CON-3 | Deleting a Node MUST cascade-delete every Link referencing it, in every View — a Link MUST NOT be left pointing at a nonexistent Node. | |
| CON-4 | A Link's endpoints MUST both be top-level Nodes — a `group` node's inline children MUST NOT be a Link endpoint. | Consistent with `application_architecture.md`'s group-nesting exception; promotion is the existing escape hatch. |
| CON-5 | A newly created Node's `tier` MUST default to `S`. | Cites `box-sizing.md` CON-2's enum, doesn't redecide it. |
| CON-6 | Node deletion MUST require an explicit confirmation step; Link deletion MUST NOT. | Reflects the asymmetric cost: a Node can hold unrecoverable authored content (`content-authoring.md` CON-6), a Link holds none. |

## Open questions

None blocking — every task from #43 is resolved above.

## Out of scope

No implementation (that's #37/#38). Does not decide the exact visual design of the "+" affordance, the inline kind/link-type pickers, or the delete-midpoint control — those are UI-design details for the implementation tickets, not modeling decisions.
