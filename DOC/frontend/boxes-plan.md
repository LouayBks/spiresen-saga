# Boxes (by Spiresen) — Canvas Concept & Build Plan

*Codename: Saga. "Don't just put me in a box."*

## 1. The idea, restated as a product

A recruiter (or anyone) lands on your portfolio and sees your work, skills, and experience as physical-feeling **boxes** scattered on a canvas — not a resume template, not a grid of cards. They (or you, as the owner arranging your own Saga) can drag boxes around, cluster them by theme, field, or timeline, and draw the shape of a career that doesn't fit one category. The tagline does the positioning for you: the *interaction itself* — refusing to stay in the box a recruiter would put you in — is the message.

That means the canvas isn't decoration. It's the pitch. Three qualities have to hold simultaneously or it stops working:

- **Legible fast** — a recruiter skimming for 20 seconds should immediately get "this person has range," not "this is a fun toy."
- **Calm** — minimalist and classy per the existing Spiresen visual language (dark ground, restrained serif type, one warm accent), not a busy Miro board.
- **Actually yours** — it has to hold real content (case studies, skills, timeline entries) without collapsing into generic SaaS-card sameness.

## 2. Data model (how this sits on top of what's already decided)

`DOC/architecture/application_architecture.md` already names **Sagas** as multi-tenant, user-owned collections that sit above the box tree — Boxes is that concept made into an actual product surface. Three entities, all under the existing DynamoDB single-table design; `Box` and `Link` follow the `{sagaId}.{shortId}` box-id namespacing convention already decided there (needed to authorize a write without walking back up the tree — see that file's "Sagas: multi-tenancy" section):

| Entity | Key shape (indicative) | Holds |
|---|---|---|
| **Saga** | `PK: USER#<id>` / `SK: SAGA#<id>` | Owner, title, tagline, view-mode default, camera (pan/zoom) state |
| **Box** | `PK: SAGA#<id>` / `SK: BOX#<id>` (id namespaced `{sagaId}.{shortId}`) | Title, body/content ref, `kind` (note / media / group — see §7a), size tier (S/M/L), position `{x, y}`, theme tag(s), timeline date (optional), z-order (fractional) |
| **Link** | `PK: SAGA#<id>` / `SK: LINK#<boxA>#<boxB>` (id namespaced `{sagaId}.{shortId}`) | The two box IDs, link type (theme / causal / timeline), optional label |

Boxes reuses the **fractional-ordering** convention already decided for the box tree — here it governs *z-order* (which box sits on top when overlapping) and the ordering of boxes within a theme cluster in non-freeform views, not the free `{x, y}` position itself, which is just two floats updated on drag-end.

See `DOC/architecture/application_architecture.md`'s "Boxes product surface" section for how `Link`, `Box.kind`, and `group`-kind children (§7a) reconcile with the general recursive box-tree schema (`PK: BOX#{boxId} / SK: BOX#{childBoxId}`) — group children are a bounded, named exception to that schema, not a second competing one.

Drag events fire at high frequency (pointermove) but the network should not: update a local Angular **signal** on every frame for instant visual feedback, and only PATCH the box's position to the API on `pointerup`/dragend, debounced. This keeps the "instant, physical" feel of dragging without turning every gesture into a write.

## 3. Canvas & scrolling

**Recommendation: infinite pannable/zoomable canvas as the primary mode, with two "lens" views layered on top of the same data.**

- **Freeform (default)** — the canvas described above: no scrollbars, pan by click-drag on empty space or two-finger trackpad scroll, zoom with pinch/scroll-wheel + a small `–  100%  +` control in the corner. This is the mode that actually delivers "throw around and order as you want."
- **Timeline** and **Theme** — the *same* boxes, the *same* links, but the layout engine repositions them along a horizontal axis (timeline) or into loose clusters (theme/field), animated as a single reflow (one orchestrated transition, not per-box staggered fades — see skill note on motion). These are read-only arrangements: a recruiter who wants structure gets it in one click without you having to maintain two separate representations of your content.
- Freeform positions are **never overwritten** by switching views — Timeline/Theme are computed layouts shown *instead of* the canvas, and Freeform still remembers exactly where you left everything when you switch back.

**Scrolling mechanics:**
- Canvas content lives in a single `<div>` transformed with `translate3d(x, y, 0) scale(z)` — GPU-composited, no browser scrollbars, no layout thrashing on pan.
- A soft **boundary with rubber-banding** (not infinite emptiness) keeps a recruiter from panning into a void — the canvas has real bounds sized to the content's bounding box plus margin, calculated on load.
- Off-screen boxes are **not rendered** past a viewport-plus-margin culling window once a Saga has enough boxes to matter (virtualization) — irrelevant at 15 boxes, load-bearing if a Saga ever holds 100+.
- Mobile: no free pan-and-zoom canvas (thumb-based freeform dragging on a small viewport is not a "classy" experience, it's a chore) — Timeline becomes the default and only view below a width breakpoint, with Freeform/Theme available but explicitly opt-in via the view toggle.

## 4. Box size

**Recommendation: three fixed size tiers (S / M / L), not free resize.**

Free-resizing is the fastest way to turn a curated canvas into visual noise — two adjacent boxes at odd, almost-but-not-quite matching sizes read as sloppy, not organic. Three tiers keep the canvas harmonious while still giving content room to breathe:

| Tier | Footprint (freeform units) | Use |
|---|---|---|
| S | 1 × 1 | A single skill, tool, or one-line fact |
| M | 2 × 1 | A role, a project summary, a short write-up |
| L | 2 × 2 | A case study, a featured piece with an image |

- Tiers are **grid-relative, not pixel-fixed** — one "unit" scales with zoom level, so the whole canvas stays proportionate at any zoom.
- **Soft-snap on drop**: while dragging, faint alignment guides (a thin `1px` line in the muted accent color) appear when a box's edge or center nears another box's edge or center — Figma/Keynote-style, not a rigid visible grid. Snapping is a suggestion (hold to override), never a hard lock.
- Box chrome stays quiet regardless of tier: hairline `1px` border, no drop shadow at rest (a very faint one only appears while actively dragging, to lift the box off the canvas), one small colored dot for theme tag rather than a colored card background — this is the deliberate anti-SaaS-card choice: identical soft rounded cards with the same grey shadow is the single most common "AI-generated" tell, so Boxes' cards are closer to framed index cards than dashboard widgets.

## 5. Drawing classy links between boxes

**Recommendation: a single SVG overlay layer, quadratic-bezier curves, not orthogonal flowchart connectors.**

- One `<svg>` sits between the canvas background and the boxes layer, `pointer-events: none` except on the curves themselves (for hover/click).
- Each link is a smooth curve between two anchor points (box edge midpoints, chosen by relative position so the curve always looks intentional rather than crossing through a box). A single quadratic control point pulled perpendicular to the midpoint gives a gentle arc — this alone is what separates "classy diagram" from "flowchart," since right angles and straight lines read as technical/engineering, not as narrative connection.
- **Link weight communicates meaning, not decoration**: a solid hairline in the slate accent for a *theme* link, a solid hairline in the clay accent for a *timeline/causal* link, a short-dashed hairline for a lighter, optional relation. No more than two link colors on screen at once — more than that stops reading as a system.
- On hover/focus of a box, its links brighten and every unrelated box + link fades to ~35% opacity — a **focus state**, so a busy Saga (many boxes) doesn't force the recruiter to parse everything at once; they explore box-by-box.
- Curves must **re-path on every drag frame** the boxes they connect are attached to — this is the main real-time computation cost of the feature (see feasibility below) and the reason link endpoints are computed from live signals, not recalculated from the DOM on each frame.

## 6. Technical feasibility on the current stack

Everything above is buildable natively on **Angular 22 signals + CDK primitives + the already-decided DynamoDB/FastAPI backend** (`DOC/architecture/application_architecture.md` — there is no standalone `ARCHITECTURE.md`, per AW-18/ADR-001), with two build choices worth calling out explicitly:

- **Don't reach for Angular CDK's `cdkDrag` directive wholesale.** CDK drag-drop is built around list reordering and drop lists, not a free 2D canvas with pan/zoom coexisting with drag. Use CDK's low-level `DragDrop` service (or raw Pointer Events) for the actual drag gesture, and keep box position as a `WritableSignal<{x,y}>` per box (or a single `Signal<Map<BoxId, Position>>` in a `BoxCanvasService`) — this is exactly the "immutable state, new references on every change" discipline already locked in for `OnPush` correctness (`CC-20`/`CC-21`), and it's what a drag-and-drop canvas needs regardless of AI-authorship concerns.
- **The SVG link layer reads from the same signal**, via a `computed()` that re-derives every curve's `d` attribute whenever any connected box's position signal changes — so the browser's own change-detection does the re-path work; no manual `requestAnimationFrame` loop is needed except for the pan/zoom transform itself, which should use `requestAnimationFrame` directly (bypassing Angular change detection with `NgZone.runOutsideAngular`) since that's a 60fps concern that shouldn't trigger a full CD pass.
- **View-mode transitions (Freeform ↔ Timeline ↔ Theme)** are a single computed layout pass on the server or client (pure function: `boxes[] → positions[]`) — cheap either way at portfolio scale (tens of boxes, not thousands), so this can live entirely client-side with no new backend endpoint.
- **Persistence cost stays low by design**: only `pointerup` writes a `PATCH /sagas/{id}/boxes/{id}` (position) or `PATCH /sagas/{id}/boxes/{id}/links` (link create/delete) — dragging itself is a pure client-side, zero-network interaction, consistent with the project's existing FinOps-for-agentic-dev lens of keeping the *system's* running costs (here: API calls, not tokens) proportionate to what the interaction actually needs.
- **Nothing here requires a new backend paradigm.** Box/Link fit the existing single-table DynamoDB design as two more item types under a Saga's partition; no graph database is warranted at this scale — a Saga with dozens of boxes and links is trivially queried with one `Query` on `PK = SAGA#<id>`.
- **The window's inner canvas should be the same Angular component as the root canvas, parameterized by scope — not a second implementation.** §9 depends on the root Saga view and a group's window rendering identically (pan, zoom, drag, curved links, click-vs-drag threshold); building that twice is exactly how the two would quietly drift apart the first time only one gets updated. A single `<box-canvas [scope]="...">` taking either the Saga's root box list or a group's children, rendered once at full-viewport size and once inside a CDK `Overlay`-hosted window, keeps the "it's boxes all the way down" guarantee true by construction rather than by convention.

## 7. Phased scope

**MVP (v1):**
- Freeform canvas: pan, zoom, drag boxes, soft-snap alignment guides
- S/M/L box tiers, all three `kind`s (note / media / group)
- Manual link creation (drag from one box's edge to another) with the two link types (theme / timeline)
- Timeline view as the one alternate layout (most directly useful to a recruiter skimming career progression)
- The window system in full (§9): morph-open, breadcrumb, fullview (automatic and manual), the recursive pan/zoom canvas inside `group` windows, and document/player windows for `media` leaves
- At least two Sagas switchable from the hidden nav, since "tell different stories about myself" is core to the pitch, not a nice-to-have
- Owner-only editing; public Saga is read-only but still interactive (recruiters can drag to explore, changes don't persist for them — a "reset view" affordance handles anyone who wanders)

**v2 candidates (deliberately deferred, not designed yet):**
- Theme/field auto-clustering view
- Box templates for common content types (case study, skill, testimonial)
- Shareable "read-only tour" — a scripted camera path through a Saga for a link you send someone who won't discover it by dragging
- Manually reordering/promoting a group's child out into a full top-level box (mentioned in §7a as the deliberate escape hatch, not yet designed as an actual interaction)

## 7a. Addendum — richer box content, nested boxes, multiple sagas, and a less "void" canvas

Four refinements against the first pass, folded in rather than left as a separate v2 list:

**Box content types.** A box is no longer just title + body. Three `kind`s, same S/M/L footprint rules:
- `note` — the original: title, short body, theme dot, date.
- `media` — a thumbnail-led box for an article or video: image area on top (with a small "Article"/"Video" pill and, for video, a play affordance), title underneath. No body copy — the image and title carry it, consistent with keeping box content scannable rather than dense.
- `group` — a box that contains other boxes rather than showing content of its own directly. Collapsed, it shows its title and an item count ("4 items inside"). Clicking it doesn't expand in place — it opens a window (see §9); a group box on the canvas is an *entry point*, not a container that visually grows.
- Data-model consequence: `Box` gets a `kind` field and, for `group`, a `children` array of lightweight inline records (title + theme) rather than full child `Box` items — a group's children are a summary, not first-class boxes with their own position/links. This is the named, bounded exception to the general recursive box-tree schema reconciled in `application_architecture.md`'s "Boxes product surface" section — it does not replace that schema elsewhere. If a child later needs to stand fully on its own (its own links, its own place in Timeline view), promote it out of the group into a real top-level `Box` (minted with its own `{sagaId}.{shortId}` id, per the namespacing convention) — a deliberate, visible action, not silent auto-promotion.

**Multiple sagas — promoted from "v2 candidate" to core scope.** The same person plausibly wants to tell more than one story: a recruiter-facing arrangement, a more personal "behind the work" arrangement leaning on `media` boxes, a technical deep-dive. Rather than one canvas with a filter, each is a **separate Saga** — its own set of boxes, its own links, its own freeform layout and default view-mode — switchable from the nav menu (below). Boxes are not shared across Sagas by reference (a "featured project" story and a "technical deep-dive" story would otherwise fight over one shared position/link graph); if the same underlying case study appears in two Sagas, it's two boxes with a common source, not one box in two places. This keeps each Saga's freeform arrangement fully yours to compose without cross-Saga side effects — the cost is some content duplication, which is an acceptable, deliberate tradeoff at this scale.

**A hidden nav, not a visible one.** The canvas is the whole page — a persistent visible nav bar would compete with it for the "calm, uncluttered" read. Everything that isn't the canvas itself (switching Sagas, Profile, About Spiresen, Contact) lives behind a single small menu affordance in the top-left, opening a slide-in panel over a dimmed scrim. The Saga switcher lives inside that same panel rather than as a separate always-visible control — one hidden surface for "everything that isn't looking at the boxes," not two.

**The canvas needed something in it.** A large flat near-black plane with only a handful of boxes on it reads as unfinished rather than minimal — restraint only reads as intentional when there's something to be restrained *around*. Fixed to the viewport (so it doesn't pan away with the content and become a distraction), three quiet layers now sit behind the boxes: a soft warm radial glow roughly where the box cluster tends to sit, a scattering of slow-drifting dust-mote points (barely-there, an ambient sense of depth rather than decoration), and a single faint botanical line-sprig in one corner — an abstracted, line-art nod to the nature photography already used in the Spiresen slide deck, rather than a literal photo competing with the boxes for attention. None of these carry information; they exist purely so the empty parts of the canvas read as considered negative space instead of an unfinished void.

## 9. Box expansion: a stack of windows

Opening a group, article, or video doesn't happen in place on the canvas — it opens a floating window over a dimmed backdrop. This section is the full behavior spec, since it went through several iterations before landing:

**The window itself.** Apple-ish but not literal: three small muted dots (a nod, not a working traffic light), a breadcrumb in the titlebar rather than a plain title, a close `×`, and a maximize toggle. Draggable by the titlebar, resizable from the bottom-right corner. Rounded corners at rest; square corners the instant it's edge-to-edge (see "fullview" below) — the shape itself communicates which state it's in.

**Opening morphs, it doesn't fade in.** A window grows directly out of the exact box (or, one level deeper, the exact node) that was clicked — same position, same size, animating open from there to its resting size. This is a small thing that matters a lot for the "little adventure" feeling the whole expansion idea is chasing: a window that just fades in centered reads as a dialog box; a window that visibly grows out of the thing you clicked reads as *opening* that thing.

**Fullview is one concept with two triggers.** A window goes edge-to-edge, fills the whole stage, and becomes the backdrop in exactly two situations: automatically, when you open something inside it (the parent steps back to make room for the child, and reverses the moment the child closes); and manually, via the maximize button, when you just want more room. Both produce the identical edge-to-edge, square-cornered, no-drag-no-resize state — "expand" *is* fullview, not a separate halfway-maximized size. The manual version remembers exactly the rect it was at and returns to it, not a generic default, when you restore it.

**Breadcrumb, not a back button.** Every window's titlebar shows the full path from the Saga root down to itself ("Boxes / Talks & interviews / Podcast: shift-left"). Clicking any earlier segment collapses everything above that level in one action and un-fullviews the window that's now back on top — this is the only navigation control the feature needs; there's no separate "back."

**What's inside a `tree` window is the same canvas, smaller — not a simplified stand-in.** This was the one real course-correction: an early version rendered a window's contents as a static grid of cards, then as a fixed wave-shaped trail. Neither held up, because the whole pitch of Boxes is "everything is a box that can hold boxes," and a flattened list inside the window quietly broke that promise one level down. The fix was to stop treating the window's interior as a different, lighter component and instead give it the exact same mechanics as the root canvas: a dot-grid space you pan by dragging empty area, zoom with the wheel, and drag individual nodes around freely — the same curved-link visual language connecting them, the same click-vs-drag distinction (a small pointer-movement threshold decides whether a release counts as "open this" or "I just repositioned it") that boxes use on the outer canvas. A window is a smaller instance of the same thing the Saga itself is, not a different, simpler UI bolted on for depth. "The initial view is just a giant box like the tiny boxes" is the literal rule now, not a metaphor that stops applying past the first level.

**Positions inside a window are fixed, independent of the window's size.** A group's children get their layout computed once, the first time that group is opened, and stored on the data itself — reopening the window, resizing it, or maximizing it never recomputes or re-scatters that layout. The window is a frame onto a space, and a frame changing size reveals or crops more of the room; it doesn't rearrange the furniture. This is what makes the space feel like a real, persistent place you're arranging rather than a report that regenerates its layout each time you look at it.

**Depth is allowed here, even though the canvas itself stays flat.** §7a's one-level nesting rule is a rule about the outer canvas's *data model and legibility*, not about how deep this window mechanism can go — breadcrumb-plus-fullview-stacking is exactly the tool that makes real depth (a group inside a group) legible without the outer canvas ever needing to show more than one level at once. The two rules aren't in tension: the canvas stays simple because the window is where complexity is allowed to live.

**Media leaves open as content, not as another canvas.** An article or video isn't a space to arrange things in, so clicking one skips the tree canvas entirely and opens a document view instead: hero image, meta line, title, a few paragraphs, scrollable if it runs long. A video gets the lighter equivalent — a dark player frame with a centered play affordance and a caption. Which kind of window a box opens is a property of its content type, not a single shape everything gets forced into.

**A build note worth carrying forward on purpose.** Twice during mockup iteration, a button nested inside a draggable region silently stopped responding to clicks — not because the click handler was wrong, but because the drag handler's `pointer capture`, set the instant any press lands anywhere in the draggable area, retargets the subsequent click away from the button and onto the draggable ancestor instead. It's an easy bug to reintroduce one control at a time. Worth enforcing structurally in the real build (a shared "opener" convention, or a lint rule) rather than re-discovering it per button, since the fix is trivial once you know to look for it and invisible until you do.

## 10. What "classy" means in code, concretely

A short checklist to hold every future box-canvas PR against, consistent with the existing Spiresen visual language (dark warm-black ground, one italic serif for eyebrows/tagline, one bold serif for display type, a restrained clay/slate two-color accent system):

- No box ever gets a filled color background — only a hairline border and a single theme dot. Color is a signal, not a fill.
- No more than two link colors on screen at once.
- No shadow at rest; a shadow only appears in response to an action (drag, hover).
- Curves, never right angles, for anything expressing a relationship between two boxes.
- View-mode changes animate as one orchestrated reflow, never staggered per-box entrance effects.
- Empty states (a Saga with zero boxes, or zero links) are written in the interface's own voice — an invitation to add the first box, not a generic "no data" placeholder.
- A window opens by growing out of the thing that was clicked, never by fading in centered.
- Anything a window shows as a space to arrange (a `group`'s contents) uses the same canvas component as the root Saga — never a simplified stand-in "for now."
- Any click target inside a draggable region gets an explicit opt-out from the drag handler, checked in review — not discovered by a bug report.