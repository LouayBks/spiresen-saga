# Spec: Window system (morph-open, breadcrumb, fullview, recursive canvas) (#44)

Format per `DOC/templates/spec_design_template.md` (ADR-006). Formalizes `boxes-plan.md` §9 into BHV-*/CON-*.

**Revision note (2026-09-18):** the first draft of this spec assumed a group node's window shows flattened, no-id "inline children" (per `application_architecture.md`'s then-current "group-nesting exception") and spent most of its content managing the consequences of that: an auto-scatter layout with no real meaning, a fake-structure risk, and a depth cap to bound it. That underlying model was wrong — corrected in `application_architecture.md` (2026-09-18): a `group`-kind Node contains a real **nested Map** (its own id doubles as the Map partition key), using the exact same Node/Link/View system as the top level. This draft removes everything that only existed to manage the old model's fake-structure problem, because that problem no longer exists — a nested Map's contents are real Nodes the owner drags and links exactly like the top-level canvas, not an algorithm's guess at where they should sit.

## Objective

Formalize the window/expansion mechanism — the thing that makes "nodes within nodes" actually buildable and navigable, and the direct answer to whether the app's recursion is covered by a spec anywhere.

## Context

- Ticket: #44.
- Updates once accepted: `boxes-plan.md` §9 only if a real gap is found (none expected — this is a formalization pass, not a redesign).
- Cites, doesn't redecide: `node-link-lifecycle.md` (Node/Link creation, drag, deletion — applies unchanged inside a nested Map), `alternate-views.md` (a nested Map gets the same ≤3-View system as any Map), `box-sizing.md` (tiers — explicitly does not apply to window rects, see CON-1), `content-authoring.md` (article/video *authoring*; this spec owns *reading* an already-authored one).

## Decisions

- **A window's rect is independently resizable — not governed by `box-sizing.md`'s tiers.** A Node's S/M/L tier is its footprint *on the canvas*; the window that opens when you click it is a separate UI surface with its own free-resize rect (min-size floor only). No contradiction with the "no free resize" decision for Nodes — different object, different purpose.
- **A `group` window shows a real nested Map, not a rendering of summary data.** Opening it runs one `Query` on `PK: MAP#{thatNodeId}` (per `application_architecture.md`'s correction) and gets back real Node/Link rows — the same shape a top-level Map's canvas gets. Dragging a Node inside that window *is* `node-link-lifecycle.md`'s existing drag/position behavior; drawing a link between two of them *is* its existing drag-to-link flow. Nothing new is invented here — this spec's only job is confirming those rules apply unchanged one (or more) levels down.
- **A nested Map gets the same ≤3-View system as any Map.** `alternate-views.md`'s rules (1–3 Views, per-View positions, View-scoped Links) are written generically ("a Map," never "the top-level Map") — they already apply here without modification. A window for a deeply-nested group can have its own alternate arrangements exactly like the outer canvas can.
- **No depth cap.** The earlier cap existed only to bound the old model's fake-auto-layout problem, which doesn't exist anymore — a nested Map is fetched lazily (one `Query` per level, only when opened), so depth doesn't multiply cost the way embedding everything upfront would have. This matches `boxes-plan.md` §9 as literally written: depth is allowed, and breadcrumb-plus-fullview-stacking is the tool that keeps it legible, not a limit on how deep an owner can nest.
- **Everything else in §9 is confirmed as written, not redecided**: morph-open via FLIP from the clicked element's exact rect; fullview as one state with two triggers (automatic when a child opens, manual via maximize, both producing the identical edge-to-edge square-cornered state); breadcrumb-not-back-button navigation; article leaves open as a document view, video leaves as a player-frame view; the "opener" convention for click targets inside draggable regions.

## Expected behaviors (`BHV-*`)

| ID | Statement | Testability check | Notes |
|---|---|---|---|
| BHV-1 | WHEN the owner clicks a `group` or `media`-kind Node (on the outer canvas or inside an already-open window), THE UI SHALL open a window that morphs (FLIP) from the clicked element's exact rect to its resting rect. | ✅ — component test: click a group Node, assert the window's initial applied rect equals the node's `getBoundingClientRect()`, then animates to the target rect | Never fades in centered — confirms §9 as written. |
| BHV-2 | WHEN a window opens on top of an already-open window, THE parent window SHALL transition to fullview (edge-to-edge, square corners, drag/resize disabled) automatically. | ✅ — component test: open a child window, assert the parent's rect/class reflects fullview | |
| BHV-3 | WHEN the topmost child window closes, THE parent window SHALL reverse out of fullview back to its rect from before the child opened. | ✅ — component test: close the child, assert the parent's rect matches its pre-child value | |
| BHV-4 | WHEN the owner clicks the maximize control, THE window SHALL toggle fullview manually and remember its exact pre-maximize rect to restore to. | ✅ — component test: resize/move a window, maximize, restore, assert the restored rect equals the pre-maximize one | |
| BHV-5 | WHEN the owner clicks an earlier breadcrumb segment, THE UI SHALL close every window above that level in one action and un-fullview the window now on top. | ✅ — component test: open 3 levels deep, click the 1st-level breadcrumb, assert levels 2-3 are closed and level 1 is no longer fullview | |
| BHV-6 | WHEN a `group` window opens, THE frontend SHALL fetch its contents via a single `Query` on that Node's own id used as a Map partition key — THE UI SHALL NOT render the window before that Query resolves. | ✅ — integration test: open a group window, assert exactly one Query fires against `PK: MAP#{nodeId}` | Replaces the withdrawn "fixed-once layout" rule — there's no precomputed layout to withdraw from; positions are real, per `alternate-views.md`. |
| BHV-7 | WHEN the owner drags a Node inside an open group window, THE UI SHALL update its position using the identical mechanism as `node-link-lifecycle.md`/`alternate-views.md` define for the outer canvas. | ✅ — same test as the outer canvas's drag-position test, run against a nested Map's window instead | No separate rule — citing, not redefining. |
| BHV-8 | WHEN the owner clicks a `group`-kind Node inside an open window (not dragging it), THE UI SHALL open another window one level deeper, running the identical `Query`-on-open behavior as BHV-6. | ✅ — component test: click a nested group Node, assert a new window opens and its own Query fires | Recursive by reusing the same component/behavior at every depth (`boxes-plan.md` §6's `<box-canvas [scope]>` requirement) — no depth limit, per Decisions. |
| BHV-9 | WHEN the owner opens a `media`-kind Node (at any depth) whose `mediaKind` is `Article`, THE UI SHALL open a document view (hero, meta line, title, scrollable paragraphs) — never a mini-canvas. | ✅ — component test: open an Article media node, assert no pan/zoom canvas renders | Reading view; `content-authoring.md` BHV-1 owns the separate editing view. |
| BHV-10 | WHEN the owner opens a `media`-kind Node (at any depth) whose `mediaKind` is `Video`, THE UI SHALL open a player-frame view with a caption — never a mini-canvas. | ✅ — component test: open a Video media node, assert a player frame renders, no canvas | |
| BHV-11 | THE UI SHALL exempt every click target rendered inside a draggable region (window titlebar, canvas Node at any depth) from that region's pointer-capture drag handler, so the target's own click still fires. | ✅ — component test: render a close/expand button inside a draggable titlebar, simulate a click, assert the button's handler fires and no drag started | Structural convention per §9's own build note — a shared "opener" mechanism, not a per-button fix. |

## Constraints (`CON-*`)

| ID | Statement | Notes |
|---|---|---|
| CON-1 | A window's rect (position/size) MUST be independently resizable and MUST NOT be constrained to `box-sizing.md`'s S/M/L tiers. | Different object (window vs. Node footprint), different rule. |
| CON-2 | Fullview MUST be a single visual/interaction state regardless of trigger — automatic and manual fullview MUST NOT produce visually distinct "half-maximized" states. | |
| CON-3 | A `group` Node's contents MUST be real Node/Link/View rows, addressable and authorizable exactly like a top-level Map's — MUST NOT be flattened into non-addressable summary data. | Reverses the withdrawn CON-4 from the first draft; restates `application_architecture.md`'s correction in this spec's own terms. |
| CON-4 | A `group` Node's own id MUST double as its nested Map's partition key (`PK: MAP#{nodeId}`) — MUST NOT require a separate stored reference to find it. | |
| CON-5 | Every draggable region's pointer-capture handler MUST exempt any descendant explicitly tagged as an opener, rather than relying on a per-button ad hoc check. | |

## Open questions

- **#40's scope needs widening.** It was written assuming View-switching UI exists only on the outer canvas; per this spec's Decisions, a nested Map can have its own Views too, so the switching UI needs to exist inside a group window as well. Not resolved here — flagging for whoever picks up #40.

## Out of scope

No implementation (that's #38). Exact FLIP animation timing/easing, breadcrumb truncation behavior at very deep paths, and document/player-view visual styling are implementation details, not modeling decisions.
