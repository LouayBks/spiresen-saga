# Boxes (by Spiresen) — Canvas Concept & Build Plan

*Codename: Saga. "Don't just put me in a box."*

**Revision note (2026-09-19):** this is the **product/UI plan** — what the canvas should feel like and how it behaves. Where it disagrees with `DOC/specs/*.md`, **the specs win**: they settled naming (`naming.md`: **Saga** is the brand, **Map** and **Node** are the entities), sizing (`box-sizing.md`), content types (`content-authoring.md`), Views (`alternate-views.md`), the window system (`window-system.md`), visibility (`map-visibility.md`), and the create/delete behaviors (`node-link-lifecycle.md`, `map-lifecycle.md`). This revision rewrote §2–§4, §6–§7a and §9–§10 to match them; the visual-language prose (§1, the chrome and link styling, the hidden nav, the ambient canvas) is unchanged. Section numbers are kept so existing citations still resolve; there has never been a §8. Physical storage is not described here — see `DOC/architecture/data_cartography.md`.

## 1. The idea, restated as a product

A recruiter (or anyone) lands on your portfolio and sees your work, skills, and experience as physical-feeling **boxes** scattered on a canvas — not a resume template, not a grid of cards. They (or you, as the owner arranging your own Map) can drag boxes around, connect them, and draw the shape of a career that doesn't fit one category. The tagline does the positioning for you: the *interaction itself* — refusing to stay in the box a recruiter would put you in — is the message. (The same canvas serves any topic — pedagogic material, research, a portfolio — per `naming.md`; the recruiter case is one example Map among others.)

That means the canvas isn't decoration. It's the pitch. Three qualities have to hold simultaneously or it stops working:

- **Legible fast** — a recruiter skimming for 20 seconds should immediately get "this person has range," not "this is a fun toy."
- **Calm** — minimalist and classy per the existing Spiresen visual language (dark ground, restrained serif type, one warm accent), not a busy Miro board.
- **Actually yours** — it has to hold real content (case studies, skills, timeline entries) without collapsing into generic SaaS-card sameness.

## 2. Data model (how this sits on top of what's already decided)

A **Map** is a user's named collection (a user can own several); a **Node** is one item on its canvas; a **Link** joins two Nodes; a **View** is one of up to three owner-arranged arrangements of the same Nodes. Nodes never store an owner — only the User↔Map relationship carries identity (`application_architecture.md`, multi-tenancy). Field-level definitions and rules live in the specs; the storage design is `ADR-007` and `data_cartography.md`.

| Entity | Holds | Owning spec |
|---|---|---|
| **Map** | name, visibility (`private` default / `unlisted` / `public`), its Views, its Nodes and Links | `naming`, `map-visibility`, `map-lifecycle` |
| **Node** | title, date, `body` (info text), size `{w, h}` in grid units, a position per View, an optional cover image, an optional `note`, URLs (one of which can show a thumbnail preview), and at most one primary content: a gallery, an article, or a nested Map of child Nodes | `box-sizing`, `content-authoring`, `alternate-views`, `node-link-lifecycle` |
| **Link** | the two Nodes it joins (undirected), a type (`theme` / `timeline` / `soft`), an optional label; belongs to exactly one View | `node-link-lifecycle`, `alternate-views` |
| **View** | a name and an order (1–3); owns its own Links and its own Node positions | `alternate-views`, `map-lifecycle` |

There is **no stored "kind"**: how a Node is presented — info, gallery, article, map, or click-through — is inferred from what it actually contains (`content-authoring.md` CON-7). There are also **no theme tags** in the data model; they belonged to the withdrawn Theme auto-layout (§3), so the small "theme dot" from earlier drafts is not rendered in v1 and would return only if a future spec adds tags.

Drag events fire at high frequency (pointermove) but the network should not: update a local Angular **signal** on every frame for instant visual feedback, and only persist the Node's position for the active View on `pointerup`/dragend, debounced. This keeps the "instant, physical" feel of dragging without turning every gesture into a write.

## 3. Canvas & scrolling

**Recommendation: an infinite pannable/zoomable canvas as the primary mode, with up to three owner-arranged Views of the same Nodes.**

- **Layout is derived per View, and never stored** (`window-system.md` CON-6): a View with **no Links** lays its Nodes out in a **grid** (each Node occupies its `w × h` block of cells); a View with **at least one Link** is **freeform** — pan by click-drag on empty space or two-finger trackpad scroll, zoom with pinch/scroll-wheel plus a small `–  100%  +` control in the corner. A freshly created top-level Map ships with one Link, so it opens freeform. Deleting a View's last Link returns it to grid; the stored freeform positions are untouched.
- **Views replace the earlier Timeline/Theme "lens" idea.** The auto-computed Timeline and Theme layouts were speculative scope invented during mockup drafting (`alternate-views.md`); what shipped in their place is real owner control: up to three **Views**, each its own arrangement of the same Nodes and its own set of Links. A View is arranged by hand, not computed. Switching Views is a single orchestrated reflow to the other View's stored positions.
- Freeform positions are **never overwritten** by switching Views or by a View going back to grid.

**Scrolling mechanics:**
- Canvas content lives in a single `<div>` transformed with `translate3d(x, y, 0) scale(z)` — GPU-composited, no browser scrollbars, no layout thrashing on pan.
- A soft **boundary with rubber-banding** (not infinite emptiness) keeps a visitor from panning into a void — the canvas has real bounds sized to the content's bounding box plus margin, calculated on load.
- Off-screen Nodes are **not rendered** past a viewport-plus-margin culling window once a Map has enough Nodes to matter — irrelevant at 15 Nodes, and a Map is capped at 50 (a nested Map has its own 50), so this stays a refinement, not a necessity.
- **Mobile is an open item.** The earlier assumption (Timeline as the default and only view on narrow screens) no longer holds because Timeline was withdrawn. Free pan-and-zoom on a small viewport is still a poor experience; how a Map presents below a width breakpoint is not decided by any spec yet.

## 4. Node size

**Recommendation: a deliberate, owner-chosen size in grid units — `{w, h}`, two integers — not automatic sizing and not free pixel resize** (`box-sizing.md`, revised 2026-09-19).

Size is the emphasis mechanic: the owner decides how large an idea is, and a passing mention stays small while a featured idea takes more room. It is never inferred from content, and it is the same in every View.

- **One unit is grid-relative, not pixel-fixed** — it scales with zoom, so the whole canvas stays proportionate at any zoom. In a grid-layout View a Node occupies exactly a `w × h` block of cells; in a freeform View the same `w × h` is its footprint. The default for a new Node is `1 × 1`; the grid has 12 columns and a suggested maximum of 12 per side (both tunable).
- **Soft-snap on drop (freeform):** while dragging, faint alignment guides (a thin `1px` line in the muted accent color) appear when a Node's edge or center nears another's edge or center — Figma/Keynote-style, not a rigid visible grid. Snapping is a suggestion (hold to override), never a hard lock.
- Node chrome stays quiet regardless of size: hairline `1px` border, no drop shadow at rest (a very faint one only appears while actively dragging, to lift the Node off the canvas), and no filled colour background — this is the deliberate anti-SaaS-card choice: identical soft rounded cards with the same grey shadow is the single most common "AI-generated" tell, so Nodes are closer to framed index cards than dashboard widgets.

## 5. Drawing classy links between boxes

**Recommendation: a single SVG overlay layer, quadratic-bezier curves, not orthogonal flowchart connectors.**

- One `<svg>` sits between the canvas background and the Nodes layer, `pointer-events: none` except on the curves themselves (for hover/click).
- Each link is a smooth curve between two anchor points (Node edge midpoints, chosen by relative position so the curve always looks intentional rather than crossing through a Node). A single quadratic control point pulled perpendicular to the midpoint gives a gentle arc — this alone is what separates "classy diagram" from "flowchart," since right angles and straight lines read as technical/engineering, not as narrative connection.
- **Link weight communicates meaning, not decoration**: a solid hairline in the slate accent for a *theme* link, a solid hairline in the clay accent for a *timeline* link, a short-dashed hairline for a lighter, optional *soft* relation. No more than two link colors on screen at once — more than that stops reading as a system. A link may carry a short optional label.
- Creating and deleting links (drag from one Node's edge to another, pick a type, one link per pair per View, no self-links, both ends in the same Map) is specified in `node-link-lifecycle.md`.
- On hover/focus of a Node, its links brighten and every unrelated Node + link fades to ~35% opacity — a **focus state**, so a busy Map doesn't force the visitor to parse everything at once; they explore Node by Node.
- Curves must **re-path on every drag frame** the Nodes they connect are attached to — this is the main real-time computation cost of the feature and the reason link endpoints are computed from live signals, not recalculated from the DOM on each frame.

## 6. Technical feasibility on the current stack

Everything above is buildable natively on **Angular 22 signals + CDK primitives + the already-decided DynamoDB/FastAPI backend** (`DOC/architecture/application_architecture.md` — there is no standalone `ARCHITECTURE.md`, per AW-18/ADR-001), with these build choices worth calling out explicitly:

- **Don't reach for Angular CDK's `cdkDrag` directive wholesale.** CDK drag-drop is built around list reordering and drop lists, not a free 2D canvas with pan/zoom coexisting with drag. Use CDK's low-level `DragDrop` service (or raw Pointer Events) for the actual drag gesture, and keep Node position as a `WritableSignal<{x,y}>` per Node (or a single `Signal<Map<NodeId, Position>>` in a canvas service) — this is exactly the "immutable state, new references on every change" discipline already locked in for `OnPush` correctness (`CC-20`/`CC-21`), and it's what a drag-and-drop canvas needs regardless of AI-authorship concerns.
- **The SVG link layer reads from the same signal**, via a `computed()` that re-derives every curve's `d` attribute whenever any connected Node's position signal changes — so the browser's own change-detection does the re-path work; no manual `requestAnimationFrame` loop is needed except for the pan/zoom transform itself, which should use `requestAnimationFrame` directly (bypassing Angular change detection with `NgZone.runOutsideAngular`) since that's a 60fps concern that shouldn't trigger a full CD pass.
- **View switching and layout mode are pure client-side derivations** — re-render at the other View's stored positions; decide grid versus freeform from whether the View has any Link; compute the grid arrangement at render time. No layout endpoint exists or is needed.
- **Persistence cost stays low by design**: only `pointerup` writes a position update for the active View (and link create/delete/label edits write links) — dragging itself is a pure client-side, zero-network interaction, consistent with the project's existing FinOps-for-agentic-dev lens of keeping the *system's* running costs (here: API calls, not tokens) proportionate to what the interaction actually needs.
- **Opening a Map is one request, and it returns only what the canvas draws** — Node "tiles", Views and Links — not every Node's full text (`ADR-007`); opening a Node fetches its full content. No graph database is warranted at this scale.
- **The window's inner canvas should be the same Angular component as the root canvas, parameterized by scope — not a second implementation.** §9 depends on the root Map view and a nested Map's window rendering identically (pan, zoom, drag, curved links, click-vs-drag threshold, grid/freeform layout); building that twice is exactly how the two would quietly drift apart the first time only one gets updated. A single `<box-canvas [scope]="...">` taking either the root Map's Nodes or a nested Map's, rendered once at full-viewport size and once inside a CDK `Overlay`-hosted window, keeps the "it's Nodes all the way down" guarantee true by construction rather than by convention.

## 7. Phased scope

**MVP (v1):**
- Canvas: pan, zoom, drag Nodes, soft-snap alignment guides; grid layout for Views without Links, freeform once a View has one
- Nodes with a free grid-unit size; inferred presentation (info / gallery / article / map / click-through); cover image, note, URLs with one YouTube-style thumbnail preview
- Manual link creation (drag from one Node's edge to another) with the three link types (theme / timeline / soft) and an optional label
- Up to three owner-arranged **Views** per Map, switchable, each with its own positions and Links
- The window system (§9): one window at a time, morph-open, breadcrumb, manual fullview with remembered size and position, the recursive canvas inside a nested Map's window, document and lightbox views for article and gallery Nodes
- Multiple Maps per user, switchable from the hidden nav; a new Map is seeded with two short guiding notes
- Visibility per Map — `private` (default), `unlisted` (anyone with the link), `public` (also in the public gallery); owner-only editing; read-only viewing is still interactive locally (visitors can drag to explore, nothing persists for them — a "reset view" affordance handles anyone who wanders)
- Usernames and unique handles

**v2 candidates (deliberately deferred, not designed yet):**
- Node templates for common content types (case study, skill, testimonial)
- A shareable "read-only tour" — a scripted camera path through a Map for a link you send someone who won't discover it by dragging
- Moving a Node from one Map to another (re-parenting)
- Moderation and reporting for public Maps (#52), trash-bin recovery (#45), a lightweight annotation display (#46), account deletion and data export (#54)

*Withdrawn, not deferred:* the Timeline and Theme auto-layout views and theme auto-clustering (`alternate-views.md` — confirmed speculative scope), hosted video (`content-authoring.md`), and the S/M/L tiers (`box-sizing.md`).

## 7a. Addendum — richer content, nested Maps, multiple Maps, visibility, and a less "void" canvas

**Node content.** A Node is no longer just title + body. What it shows is inferred from what it contains, in this fixed order (`content-authoring.md` CON-7): **2 or more child Nodes → a map** (its own nested Map, opened in a window); **exactly one child → click-through** to that child; **a gallery of images → a gallery** (up to ten images, opened as a lightbox); **an attached article → an article** (a markdown document); otherwise a plain **info** Node (title, body, date). At most one of children / gallery / article at a time. A **cover image**, a short **note** and any number of **URLs** are available on every Node regardless. Video is not hosted: a video is a link, and a recognised provider (YouTube in v1) shows one fetched thumbnail preview.
- A nested Map is not a summary: its children are real Nodes with their own positions, Links and Views, exactly like the top level (recursion, no separate "group" schema). The Node crosses into "map" presentation automatically when it gets its second child — there is no "convert to group" step; **"Add inside"** is always available on any Node.

**Multiple Maps — core scope.** The same person plausibly wants to tell more than one story: a recruiter-facing arrangement, a more personal "behind the work" one, a technical deep-dive. Rather than one canvas with a filter, each is a **separate Map** — its own Nodes, its own Links and Views — switchable from the nav menu. Nodes are not shared across Maps by reference (two stories would otherwise fight over one shared position/link graph); if the same underlying case study appears in two Maps, it's two Nodes with a common source. This keeps each Map's arrangement fully yours to compose without cross-Map side effects — the cost is some content duplication, an acceptable, deliberate tradeoff at this scale.

**Visibility.** Each Map is `private` (only you), `unlisted` (readable by anyone with the link, not listed anywhere, not indexed by search engines) or `public` (readable by anyone and listed in the public gallery). New Maps are `private`. See `map-visibility.md`.

**A hidden nav, not a visible one.** The canvas is the whole page — a persistent visible nav bar would compete with it for the "calm, uncluttered" read. Everything that isn't the canvas itself (switching Maps, account settings, About Spiresen, Contact) lives behind a single small menu affordance in the top-left, opening a slide-in panel over a dimmed scrim. The Map switcher lives inside that same panel rather than as a separate always-visible control — one hidden surface for "everything that isn't looking at the Nodes," not two.

**The canvas needed something in it.** A large flat near-black plane with only a handful of Nodes on it reads as unfinished rather than minimal — restraint only reads as intentional when there's something to be restrained *around*. Fixed to the viewport (so it doesn't pan away with the content and become a distraction), three quiet layers now sit behind the Nodes: a soft warm radial glow roughly where the Node cluster tends to sit, a scattering of slow-drifting dust-mote points (barely-there, an ambient sense of depth rather than decoration), and a single faint botanical line-sprig in one corner — an abstracted, line-art nod to the nature photography already used in the Spiresen slide deck, rather than a literal photo competing with the Nodes for attention. None of these carry information; they exist purely so the empty parts of the canvas read as considered negative space instead of an unfinished void.

## 9. Expansion: one window

Opening a Node that is a map, a gallery or an article doesn't happen in place on the canvas — it opens a floating window over a dimmed backdrop. This section is the behavior summary; the binding rules are in `window-system.md`.

**One window at a time, for now.** Navigating deeper (clicking a Node inside the open window) or shallower (clicking an earlier breadcrumb segment) **replaces that same window's content** and grows or shrinks the breadcrumb — it never opens a second simultaneous window. The earlier stacked-windows model (each child opening on top of its parent, the parent auto-fullviewing as a backdrop) is withdrawn; multi-window stacking isn't rejected forever, just out of scope until there is a real reason for it.

**The window itself.** Apple-ish but not literal: three small muted dots (a nod, not a working traffic light), a breadcrumb in the titlebar rather than a plain title, a close `×`, and a maximize toggle. Draggable by the titlebar, resizable from the bottom-right corner — free-resize in pixels, unrelated to Node size. Rounded corners at rest; square corners the instant it's edge-to-edge (fullview) — the shape itself communicates which state it's in.

**Opening morphs, it doesn't fade in.** A window grows directly out of the exact Node that was clicked — same position, same size, animating open from there to its resting size. This is a small thing that matters a lot for the "little adventure" feeling the whole expansion idea is chasing: a window that just fades in centered reads as a dialog box; a window that visibly grows out of the thing you clicked reads as *opening* that thing.

**Fullview is manual, and the window remembers.** Fullview is reached only with the maximize button: edge-to-edge, square-cornered, no drag or resize. It persists through navigation in both directions until the owner restores it, and the window's mode and size/position are remembered like a desktop OS window — maximize once and the next window you open (even for another Node, even next session) opens maximized; resize while windowed and that becomes the remembered size. Stored in the visitor's own browser, not on the server.

**Breadcrumb, not a back button.** Every window's titlebar shows the full path from the Map root down to itself. Clicking any earlier segment replaces the window's content with that level, in one action — this is the only navigation control the feature needs; there's no separate "back."

**What's inside a nested Map's window is the same canvas, smaller — not a simplified stand-in.** An early version rendered a window's contents as a static grid of cards, then as a fixed wave-shaped trail. Neither held up, because the whole pitch is "everything is a Node that can hold Nodes," and a flattened list inside the window quietly broke that promise one level down. So the window's interior has the exact same mechanics as the root canvas: pan by dragging empty area, zoom with the wheel, drag individual Nodes freely, the same curved-link visual language, the same click-vs-drag threshold (a small pointer-movement threshold decides whether a release counts as "open this" or "I just repositioned it"), the same Views, and the same grid-until-linked layout rule. A window is a smaller instance of the same thing the Map itself is.

**Layout inside a window is derived like everywhere else.** A nested Map with no Links is laid out as a grid; the moment a View gets a Link it is freeform, and positions are real, stored, per-View data (not a layout computed once and frozen). Resizing or maximizing the window reveals or crops more of the room; it never rearranges the furniture.

**Depth is allowed, without a cap.** A nested Map is fetched lazily — one request per level, only when opened — so depth doesn't multiply cost, and the breadcrumb is the tool that keeps a Map inside a Map inside a Map legible, without the outer canvas ever needing to show more than one level at once.

**Leaves open as content, not as another canvas.** An article or a gallery isn't a space to arrange things in, so clicking one skips the canvas entirely: an article opens a document view (hero image, meta line, title, scrollable paragraphs), a gallery opens a lightbox/carousel. A video is just a link with a thumbnail, rendered where links render — it has no window of its own. Which kind of window a Node opens is a property of what it contains, not a single shape everything gets forced into.

**A build note worth carrying forward on purpose.** Twice during mockup iteration, a button nested inside a draggable region silently stopped responding to clicks — not because the click handler was wrong, but because the drag handler's `pointer capture`, set the instant any press lands anywhere in the draggable area, retargets the subsequent click away from the button and onto the draggable ancestor instead. It's an easy bug to reintroduce one control at a time. Worth enforcing structurally in the real build (a shared "opener" convention, or a lint rule) rather than re-discovering it per button, since the fix is trivial once you know to look for it and invisible until you do.

## 10. What "classy" means in code, concretely

A short checklist to hold every future canvas PR against, consistent with the existing Spiresen visual language (dark warm-black ground, one italic serif for eyebrows/tagline, one bold serif for display type, a restrained clay/slate two-color accent system):

- No Node ever gets a filled color background — only a hairline border. Color is a signal, not a fill.
- No more than two link colors on screen at once.
- No shadow at rest; a shadow only appears in response to an action (drag, hover).
- Curves, never right angles, for anything expressing a relationship between two Nodes.
- View switches animate as one orchestrated reflow, never staggered per-Node entrance effects.
- Empty states (a Map with zero Nodes, or zero Links) are written in the interface's own voice — an invitation to add the first Node, not a generic "no data" placeholder. A brand-new Map isn't empty at all: it starts with two guiding notes.
- A window opens by growing out of the thing that was clicked, never by fading in centered.
- Anything a window shows as a space to arrange (a nested Map's contents) uses the same canvas component as the root Map — never a simplified stand-in "for now."
- Any click target inside a draggable region gets an explicit opt-out from the drag handler, checked in review — not discovered by a bug report.
