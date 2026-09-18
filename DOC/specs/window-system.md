# Spec: Window system (morph-open, breadcrumb, fullview, recursive canvas) (#44)

Format per `DOC/templates/spec_design_template.md` (ADR-006). Formalizes `boxes-plan.md` §9 into BHV-*/CON-* — unlike the other five specs, this one isn't resolving an open design question (§9 already reads as fully decided, documenting its own iteration), it's turning settled prose into testable rules before #38 implements it, and drawing an explicit boundary against `alternate-views.md`/`node-link-lifecycle.md` so the window's recursive mini-canvas doesn't get conflated with the top-level Node/Link/View system.

## Objective

Formalize the window/expansion mechanism — the thing that makes "nodes within nodes" actually buildable and navigable, and the direct answer to whether the app's recursion is covered by a spec anywhere.

## Context

- Ticket: #44.
- Updates once accepted: `boxes-plan.md` §9 only if a real gap is found (none expected — this is a formalization pass, not a redesign).
- Cites: `content-authoring.md` (article/video *authoring*; this spec owns *reading* an already-authored article/video), `box-sizing.md` (explicitly does not apply to window rects — see CON-1), `application_architecture.md`'s group-nesting exception (a group's inline children stay bounded, not promoted to full Nodes, inside the window too).

## Decisions

- **A window's rect is independently resizable — not governed by `box-sizing.md`'s tiers.** A Node's S/M/L tier is its footprint *on the canvas*; the window that opens when you click it is a separate UI surface with its own free-resize rect (min-size floor only). No contradiction with the "no free resize" decision for Nodes — different object, different purpose.
- **The recursive mini-canvas operates on a group's inline children, never on top-level Nodes/Links/Views.** This is the scope boundary that keeps this spec from overlapping `alternate-views.md`/`node-link-lifecycle.md`: a `group` window's contents are the lightweight inline summary records from `application_architecture.md`'s group-nesting exception (title, theme, optional nested `children[]`, optional `kind: media` leaf) — no id of their own, no independent Link, no per-View position. The mockup's own sample data already nests these two levels deep, confirming the recursion is real but bounded to this inline structure, not the general schema.
- **Risk, logged rather than silently accepted: the auto-layout gives the *appearance* of a curated space without the substance of one, and that gap compounds with depth.** The mockup's own layout algorithm for inline children scatters them by array index along a fixed curve (a sine-wave offset), and draws a link only between consecutive siblings — neither the position nor the connecting line carries any real relational meaning, unlike the outer canvas where the owner deliberately drags/links every Node. One level of that is a reasonable, cheap visual — a list dressed up as a small space. Left unbounded, a third or fourth level of the same fake structure stacked on top of itself stops reading as intentional and starts reading as a maze of arbitrary boxes, which directly undercuts `boxes-plan.md` §10's "classy, not busy Miro board" bar.
- **Mitigation: group nesting is capped at 2 inline-children levels — a child MAY have its own children, a grandchild MUST NOT.** This isn't an arbitrary number: it's exactly the deepest nesting the mockup's own sample data already uses (`"Clean Code, in practice" → "CLAUDE.md rules" → "CC-16 to CC-19"`, no further level) — the cap formalizes what's already true rather than inventing a new restriction, and caps window-stack depth at 2 as a direct consequence (there's nothing beyond level 2 to open further).
- **Everything else in §9 is confirmed as written, not redecided**: morph-open via FLIP from the clicked element's exact rect; fullview as one state with two triggers (automatic when a child opens, manual via maximize, both producing the identical edge-to-edge square-cornered state); breadcrumb-not-back-button navigation; fixed-once child layout (computed on first open, persisted, never recomputed on resize/reopen); article leaves open as a document view, video leaves as a player-frame view; the "opener" convention for click targets inside draggable regions.

## Expected behaviors (`BHV-*`)

| ID | Statement | Testability check | Notes |
|---|---|---|---|
| BHV-1 | WHEN the owner clicks a `group` or `media`-kind node (or a mini-node inside an already-open window), THE UI SHALL open a window that morphs (FLIP) from the clicked element's exact rect to its resting rect. | ✅ — component test: click a group node, assert the window's initial applied rect equals the node's `getBoundingClientRect()`, then animates to the target rect | Never fades in centered — confirms §9 as written. |
| BHV-2 | WHEN a window opens on top of an already-open window, THE parent window SHALL transition to fullview (edge-to-edge, square corners, drag/resize disabled) automatically. | ✅ — component test: open a child window, assert the parent's rect/class reflects fullview | |
| BHV-3 | WHEN the topmost child window closes, THE parent window SHALL reverse out of fullview back to its rect from before the child opened. | ✅ — component test: close the child, assert the parent's rect matches its pre-child value | |
| BHV-4 | WHEN the owner clicks the maximize control, THE window SHALL toggle fullview manually and remember its exact pre-maximize rect to restore to. | ✅ — component test: resize/move a window, maximize, restore, assert the restored rect equals the pre-maximize one | |
| BHV-5 | WHEN the owner clicks an earlier breadcrumb segment, THE UI SHALL close every window above that level in one action and un-fullview the window now on top. | ✅ — component test: open 3 levels deep, click the 1st-level breadcrumb, assert levels 2-3 are closed and level 1 is no longer fullview | |
| BHV-6 | WHEN a `group` window's mini-canvas is opened for the first time, THE backend SHALL compute and persist its children's layout; THE UI SHALL NOT recompute that layout on any later open, resize, or maximize. | ✅ — integration test: open a group window twice with a resize between, assert child coordinates are identical both times | |
| BHV-7 | WHEN the owner drags a mini-node inside a group window, THE UI SHALL reposition it within the fixed layout and persist the new coordinates on the parent group Node's own record, using the same click-vs-drag pointer-movement threshold as the outer canvas. | ✅ — integration test: drag a mini-node, reopen the window, assert the moved coordinates (not the original auto-computed ones) are shown | Persistence was missing from the first draft — without it, every reopen would silently discard the owner's rearrangement and fall back to the auto-scatter, which would make BHV-6's "computed once" guarantee pointless. |
| BHV-8 | WHEN a mini-node with its own nested `children` is clicked (not dragged), THE UI SHALL open another window one level deeper. | ✅ — component test: click a mini-node with children, assert a new window opens with that mini-node's children | Recursive — the same component instance handles every depth (`boxes-plan.md` §6's `<box-canvas [scope]>` requirement, restated as testable here). Capped at depth 2 by CON-6/BHV-12. |
| BHV-9 | WHEN the owner opens a `media`-kind node (or mini-node) whose `mediaKind` is `Article`, THE UI SHALL open a document view (hero, meta line, title, scrollable paragraphs) — never a mini-canvas. | ✅ — component test: open an Article media node, assert no pan/zoom mini-canvas renders | Reading view; `content-authoring.md` BHV-1 owns the separate editing view. |
| BHV-10 | WHEN the owner opens a `media`-kind node (or mini-node) whose `mediaKind` is `Video`, THE UI SHALL open a player-frame view with a caption — never a mini-canvas. | ✅ — component test: open a Video media node, assert a player frame renders, no mini-canvas | |
| BHV-11 | THE UI SHALL exempt every click target rendered inside a draggable region (window titlebar, canvas node, mini-node) from that region's pointer-capture drag handler, so the target's own click still fires. | ✅ — component test: render a close/expand button inside a draggable titlebar, simulate a click, assert the button's handler fires and no drag started | Structural convention per §9's own build note — a shared "opener" mechanism, not a per-button fix. |
| BHV-12 | IF the owner attempts to give a level-2 inline child its own `children` (a level-3 nesting), THEN THE backend SHALL reject it. | ✅ — integration test: attempt to add a child under a "CC-16 to CC-19"-depth item, assert 4xx | Enforces CON-6; applies once the (not-yet-specified) inline-children authoring flow exists — see Open questions. |

## Constraints (`CON-*`)

| ID | Statement | Notes |
|---|---|---|
| CON-1 | A window's rect (position/size) MUST be independently resizable and MUST NOT be constrained to `box-sizing.md`'s S/M/L tiers. | Different object (window vs. Node footprint), different rule. |
| CON-2 | Fullview MUST be a single visual/interaction state regardless of trigger — automatic and manual fullview MUST NOT produce visually distinct "half-maximized" states. | |
| CON-3 | A group window's children layout MUST be computed at most once, on first open, and persisted — MUST NOT be recalculated on resize, reopen, or maximize. | |
| CON-4 | A group's inline children (and their own nested children) MUST NOT be addressed as top-level Nodes — no id of their own, no independent Link, no per-View position. | Restates `application_architecture.md`'s group-nesting exception in this spec's own terms; doesn't redecide it. |
| CON-5 | Every draggable region's pointer-capture handler MUST exempt any descendant explicitly tagged as an opener, rather than relying on a per-button ad hoc check. | |
| CON-6 | A group node's inline children MUST NOT nest more than 2 levels deep — a child MAY have `children`; a grandchild MUST NOT. | Bounds the auto-layout's looks-structured-but-isn't risk (see Decisions) instead of allowing unbounded depth. Matches the mockup's own deepest demonstrated nesting exactly — no existing sample data needs to change. |

## Open questions

- **Adding/removing/editing a group's inline children** — an authoring flow parallel to what #43 solved for top-level Nodes, but for inline children specifically (which have no id and aren't part of the Node/Link CRUD model). Not decided here; likely needs its own small follow-up spec once #38 gets closer, since the mockup only ever shows pre-seeded children, never an "add a child" interaction. That future spec MUST respect CON-6's 2-level cap (BHV-12 names the rejection case now, ahead of the authoring flow itself existing).

## Out of scope

No implementation (that's #38). Exact FLIP animation timing/easing, breadcrumb truncation behavior at very deep paths, and document/player-view visual styling are implementation details, not modeling decisions.
