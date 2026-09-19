# Spec: Content authoring mechanics (#33)

Format per `DOC/templates/spec_design_template.md` (ADR-006). Owns article/media content, the `note`/`urls` fields attachable to any node, and — as of the 2026-09-18 revision — the dynamic visualization-inference rules that replace the stored `kind` field. Orthogonal to `box-sizing.md` (`size`) and `alternate-views.md` (position/links); no overlap, since content and its attachments don't vary per view or size.

**Revision note (2026-09-18, part 1):** `kind` is retired as a stored field (`naming.md`). A node's presentation is now inferred from what it actually contains. The concrete authoring mechanics below (markdown editor, presigned upload, note fields) are unchanged — what changed is *what triggers* each one.

**Revision note (2026-09-18, part 2): this is the first real content-*types* pass — everything before it was node-editing mechanics, not the content model itself.** Adds a gallery content type, a cover image orthogonal to every node, rich link previews, and drops direct video upload entirely (cost-driven — see Decisions). Also adds a standing constraint tying this spec to #23 ("Saga-as-Code," pending its own rename/update): every content shape decided here must be usable as-is as a JSON import/export payload, not just as live UI state.

**Revision note (2026-09-19):** (1) `tier` → `size`, per `box-sizing.md`. (2) **A node renders at most one URL thumbnail preview** — the first attached URL from a recognized provider (v1 = YouTube). `Node.urls` itself has no count cap (a node can carry as many plain links as the owner wants), but only one entry ever carries fetched preview metadata, so oEmbed is called at most once per node, and only while the node has no preview yet. Supersedes the per-entry preview wording in "Rich links" below and in BHV-11/CON-11.

**Revision note (2026-09-19, part 2):** closes the remove/edit gaps a CRUD coverage check found (`map-lifecycle.md`) — BHV-13..18 below — defines the difference between a node's `body` and its `note`, makes the first gallery image the default cover, and removes the last leftover storage-key wording (this spec states requirements only, per ADR-006's amendment).

## Objective

Decide how content actually gets created and edited, decide the rules that infer a node's visualization from its contents, and enumerate the actual content types a node can hold — which nothing has done yet.

## Context

- Ticket: #33.
- Updates once accepted: `application_architecture.md`'s DynamoDB schema section (drops `kind`; adds `images`/`coverImage` fields; drops video-upload references) and `boxes-plan.md` §7a's content-types section. Also flags #23 ("Saga-as-Code") as needing a refresh — it predates the Map rename and this session's concrete schema.
- Cites `window-system.md`'s "a node with 2+ children" trigger for map visualization — doesn't redecide it, just supplies the content-side half of the inference.

## Decisions

### Content types a node can hold (mutually exclusive primary content, per CON-9)

1. **Info** — title/body/date, plain text. The default when nothing else applies.
2. **Gallery** — a small set of images (`Node.images?: [{s3Key, caption?}]`), not a single image. Stored with the node's own content — image *keys* are short strings, not the large payload an article body is. The actual image bytes are fetched by the browser straight from S3/CloudFront when rendering, never via Lambda/DynamoDB.
3. **Article** — a markdown body, stored apart from the node's other fields so it is fetched only when the node is opened.
4. **Map** (2+ children) / **click-through** (exactly 1 child) — unchanged from the first revision, still the top two branches of the inference order.

**Cover image is orthogonal to all of the above, not a content type itself.** `Node.coverImage?: {s3Key}` is available on *every* node regardless of what it's otherwise showing — a single representative thumbnail for the node's own canvas tile, the same way `note`/`urls`/`size` already sit outside the inference order. A gallery node's cover image is independent of its gallery images (may or may not be one of them) — kept simple rather than auto-derived, since auto-derivation ("use the first gallery image") is a UI default the owner can still override, not a modeling requirement.

### Video is not a hosted content type — dropped entirely, not deferred

**Reversing the first draft's direct-to-S3 video upload.** Self-hosting video is real, ongoing money (S3 storage + data transfer) in a way images and text aren't, and this project's stated goal is "cheap to run at low-to-moderate traffic." Video content is a **rich link** (below) to wherever it already lives (YouTube, Vimeo, etc.) — never an uploaded file, never an S3 key, no player-frame window backed by a hosted file. `boxes-plan.md` §9's "video leaf opens a player-frame view" still happens, just backed by an embed/thumbnail from the link, not a `<video>` tag over a hosted file.

### Rich links: thumbnail preview for recognized providers, v1 = YouTube only

A `Node.urls` entry gains optional `thumbnailUrl`/`title` fields, populated **once**, at attach-time, via the provider's `oEmbed` endpoint (YouTube's is free, JSON, no scraping) — never re-fetched on every render. The thumbnail is linked, not re-hosted in S3 — accepted tradeoff (could break if YouTube changes the URL), not worth the extra upload/storage cost to guard against at this scale. Any URL that isn't a recognized provider renders as a plain link, no attempted preview — scraping arbitrary pages for Open Graph tags is real Lambda cost for something that fails unpredictably; deferred, not designed here.

### Article authoring: markdown, with drag-and-drop image insertion added

Keeps the first draft's core call (markdown source + live preview, not a rich-text/block editor — still the right way to avoid building an editor from scratch with nothing to crib from). Adds the piece that was actually missing for "easy insertion of text and image placement": dropping an image file onto the editor uploads it via the existing presigned-S3 flow and inserts `![](url)` markdown at the drop position automatically. This is a well-trodden pattern (GitHub's own comment box does the same thing) — a drop-handler on the existing textarea, not a new editor engine. Candidate libraries unchanged (`marked`/`ngx-markdown` for the preview pane); the drop-handler itself is plain enough not to need a library.

### Feature-as-code compliance (ties to #23)

**Every content shape decided in this spec MUST be directly usable as a JSON import/export payload — not just as internal UI state.** This is the concrete form of the FinOps instinct already running through this project: a user's own AI assistant should be able to generate a JSON document matching a published schema (creating/modifying a Map, an article, etc.) that the app then validates and applies via plain code — never an AI operating the live UI. Nothing above violates this (an image key, a gallery array, a rich-link object, a markdown string are all already flat, serializable data) — stated here explicitly so future content-type additions get held to the same bar. #23 itself needs a follow-up pass (Saga→Map rename, and it now has real schema to build the JSON contract against) — not done in this spec, flagged for whoever picks up #23.

### `body` versus `note`

Two different fields, deliberately. **`body`** is the info node's own text — the primary text of the info visualization, shown on its tile (as a short excerpt) and in full when opened, subject to the soft overflow warning (BHV-7). **`note`** is a short side annotation any node can carry whatever it currently shows (a gallery, an article, a map): it exists so a node that isn't an info node can still carry a line of text. An info node may have both.

### Removing and editing content

Everything the owner can attach, the owner can also change or take away, and the node's visualization is simply recomputed from what remains (CON-7) — nothing is "converted". Removing an article or the last gallery image turns the node back into whatever the remaining content implies. The first image added to a gallery becomes the node's cover image **if it has none** — a one-time default (an ordinary stored cover image, not a derived one) that the owner can replace or clear, so a new gallery node has a face on the canvas without extra work.

### Carried forward, unchanged from the first draft

- No content versioning — always-overwrite on edit.
- Notes and URLs are their own fields on `Node`, independent of visualization state.
- Plain info-node editing: plain text fields (title, body, date), free-text `date`.
- Info-node body length is a soft guideline (overflow warning, not a block).

**`annotation`/lightweight display toggle — dropped from this spec, deferred to the backlog as an unscoped suggestion (#46).** Not designed here, no BHV/CON below assumes it exists — explicitly not something planned for implementation now or with any commitment to ever building it.

## Expected behaviors (`BHV-*`)

| ID | Statement | Testability check | Notes |
|---|---|---|---|
| BHV-1 | WHEN the owner attaches an article to a node, THE editor SHALL present a markdown source pane and a live rendered preview pane side by side. | ✅ — component test: attach an article, assert both panes render | |
| BHV-2 | WHEN the owner selects an image file to upload (gallery, cover image, or inline in an article), THE frontend SHALL request a presigned S3 upload URL from the backend and upload the file directly to S3. | ✅ — integration test mocking the presign endpoint and asserting the file `PUT` goes to the S3 URL, not the backend | Scope narrowed to images only — video upload withdrawn. |
| BHV-3 | IF a selected image exceeds the size/type limit (CON-1), THEN THE upload UI SHALL reject it client-side before requesting a presigned URL. | ✅ — unit test with an oversized/wrong-type file asserts no presign request fires | |
| BHV-4 | WHEN the owner attaches a note or a URL to any node, THE node SHALL persist it regardless of that node's current visualization state. | ✅ — CRUD test attaching a note to a node with an article, and a URL to a node with 2+ children, asserting both persist | |
| BHV-5 | WHEN the owner saves an edit to an article's content, THE backend SHALL overwrite the article's stored body with no retained prior version. | ✅ — integration test: edit twice, assert only the latest body is retrievable | Narrowed to article — video is no longer a hosted type. |
| BHV-6 | WHEN the owner edits a node that has neither an attached article, a gallery, nor 2+ children, THE editor SHALL present plain text fields for title, body, and date — no markdown source/preview pane. | ✅ — component test: open a plain info node's editor, assert no markdown preview pane renders | |
| BHV-7 | IF an info node's body text is likely to overflow its current size footprint, THEN THE editor SHALL show a non-blocking warning suggesting a larger size. | ✅ — component test: type body text exceeding a 1×1 footprint's measured capacity, assert a warning renders and save is still allowed | Warning, not validation error — CON-7 confirms the save isn't rejected. |
| BHV-8 | WHEN the owner opens a node with exactly 1 child, THE UI SHALL navigate directly to that child's own content — no intermediate single-item grid/window for the parent. | ✅ — integration test: open a node with exactly 1 child, assert the window/view shown is the child's own (Map, gallery, article, or fields), never a 1-cell grid | |
| BHV-9 | WHEN the owner adds images to a node's gallery, THE backend SHALL append to `Node.images` (each entry an S3 key + optional caption), up to CON-10's cap. | ✅ — integration test: add 3 images, assert `Node.images` has 3 entries with keys and no caption required | |
| BHV-10 | WHEN the owner sets a cover image on any node, THE backend SHALL persist it to `Node.coverImage`, independent of that node's `images`/article/children. | ✅ — integration test: set a cover image on an article node and on a map node, assert both persist independently of their other content | |
| BHV-11 | WHEN the owner attaches a URL matching a recognized provider (YouTube at v1), THE backend SHALL, if the node has no URL preview yet, fetch that provider's `oEmbed` metadata once and store the returned thumbnail URL and title as the node's single preview; if it already has one, THE backend SHALL attach the URL as a plain link with no fetch. | ✅ — integration test: attach a YouTube URL to a node with no preview, assert a preview is stored; attach a second YouTube URL, assert no second oEmbed call and the first preview unchanged; attach an unrecognized URL first, assert no preview stored | One-time fetch at attach — never refetched on render (CON-11); at most one preview per node (2026-09-19). |
| BHV-12 | WHEN the owner drags an image file onto the article editor, THE editor SHALL upload it via the existing presigned flow and insert markdown image syntax at the drop position. | ✅ — component test: simulate a file drop at a cursor position, assert `![]()` syntax appears there after upload completes | |
| BHV-13 | WHEN the owner removes a node's attached article, THE backend SHALL delete the article body, and the node SHALL revert to the visualization inferred from what remains. | ✅ — integration test: remove an article, assert the body is gone and the node's inferred visualization is now info | Gap closed 2026-09-19 (`map-lifecycle.md` coverage matrix). |
| BHV-14 | WHEN the owner removes an image from a node's gallery, THE backend SHALL delete that entry and leave the others unchanged; WHEN the last image is removed, the node SHALL no longer be a gallery. | ✅ — integration test: remove one of three images, assert two remain; remove the rest, assert the node is no longer inferred as a gallery | |
| BHV-15 | WHEN the owner edits an image's caption, THE backend SHALL update only that caption. | ✅ — integration test: edit one caption, assert the other captions and images are unchanged | |
| BHV-16 | WHEN the owner sets, replaces or clears a node's cover image, THE backend SHALL persist the change independent of the node's other content. | ✅ — integration test: set, replace, then clear a cover image on a node with an article, assert each state and that the article is untouched | Clearing leaves it empty — no automatic re-derivation. |
| BHV-17 | WHEN the first image is added to a node's gallery and the node has no cover image, THE backend SHALL set the cover image to that image. | ✅ — integration test: add an image to a cover-less gallery, assert the cover equals it; repeat on a node that already has a cover, assert the cover is unchanged | A one-time default the owner can replace or clear (BHV-16). |
| BHV-18 | WHEN the owner edits or removes a note or a URL, THE backend SHALL persist the change; IF the removed URL is the one carrying the node's preview, THEN THE backend SHALL also remove that preview and SHALL NOT fetch a replacement automatically. | ✅ — integration test: remove the previewed URL, assert the preview is gone and no oEmbed call was made | |

## Constraints (`CON-*`)

| ID | Statement | Notes |
|---|---|---|
| CON-1 | An uploaded image MUST NOT exceed 10 MB and MUST be `jpg`, `png`, or `webp`. | Applies to gallery images, cover images, and inline article images alike. |
| CON-2 | Image bytes MUST NOT pass through the Lambda backend at any point in the upload flow — only the S3 key crosses the API. | Enforced server-side, not just client-side. Narrowed from "image/video" — video upload withdrawn. |
| CON-3 | Article body content MUST be stored as plain markdown text, not a proprietary block/rich-text JSON format. | |
| CON-4 | `Node.note` and `Node.urls` MUST be optional and MUST NOT be restricted by visualization state. | |
| CON-5 | Content edits MUST overwrite in place — no version-history record is created or retained. | |
| CON-6 | An overflow warning on info-node body length MUST NOT block saving. | |
| CON-7 | A node's visualization MUST be evaluated in the fixed order: (1) 2+ children → map, (2) exactly 1 child → click-through, (3) gallery (`images` populated) → gallery view, (4) attached article → article view, (5) neither → plain info node — never stored, always computed at read/render time. | The core inference rule. Gallery inserted ahead of article — both are "attached leaf content," gallery checked first since it's the simpler case. |
| CON-8 | A node MUST NOT simultaneously have 2+ children, a populated `images` gallery, and an attached article — exactly one primary-content branch of CON-7 applies at a time. | Extends the first draft's map/media exclusivity to include gallery. Enforced server-side. |
| CON-9 | `Node.coverImage` MUST be settable independent of and MUST NOT be restricted by a node's primary-content branch (CON-7). | Cover image is orthogonal, like `note`/`urls`/`size`. |
| CON-10 | `Node.images` MUST NOT exceed 10 entries. | A starting number for "small gallery" — adjustable at implementation time, not a hard product requirement. |
| CON-11 | Link-preview metadata (`thumbnailUrl`/`title`) MUST be fetched at most once per node, at attach-time — MUST NOT be refetched on every render, and a node MUST NOT hold more than one preview. `Node.urls` MUST NOT have a count cap of its own (bounded only by the node's overall size limit, if any). | Keeps this Lambda-lean; a stale thumbnail is an acceptable tradeoff over refetching per view. |
| CON-12 | Every content shape defined in this spec MUST be representable as a flat, serializable JSON value with no hidden client-only state. | The feature-as-code constraint — ties to #23, not enforced by any test here, but binding on every future addition to this spec. |
| CON-13 | Image or article content removed by the owner MUST become unreachable through the app immediately; the stored image files MAY remain in storage until a cleanup mechanism exists. | Cleanup is tracked with #54. |
| CON-14 | A content write (body, note, URL, article, gallery image, cover image) MUST be rejected as not found when the Node it targets does not exist. | Specialises `node-link-lifecycle.md` CON-8; also means a deleted Node's content can never be read back. |

## Open questions

- The "1-2 concrete library candidates" task from the ticket is still intentionally left as a short technical spike inside the implementation ticket (#39) — not load-bearing here.
- **#23 needs its own refresh pass** (rename, and building its JSON schema against this session's now-concrete Node/Link/View/content model) — noted, not scoped here.

## Out of scope

No implementation UI (that's #39). Does not decide the exact presigned-URL request/response contract — that's #36's job. Does not design #23's actual JSON schema — CON-12 only states the constraint future work must satisfy. **The `annotation`/lightweight display toggle is out of scope entirely** — deferred to the backlog (#46) as an unscoped suggestion, not designed, not committed to.
