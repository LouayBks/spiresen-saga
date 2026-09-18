# Spec: Content authoring mechanics (#33)

Format per `DOC/templates/spec_design_template.md` (ADR-006). Owns article/media content, the `note`/`urls` fields attachable to any node, and — as of the 2026-09-18 revision — the dynamic visualization-inference rules that replace the stored `kind` field. Orthogonal to `box-sizing.md` (`tier`) and `alternate-views.md` (position/links); no overlap, since content and its attachments don't vary per view or tier.

**Revision note (2026-09-18):** `kind` is retired as a stored field (`naming.md`). A node's presentation is now inferred from what it actually contains, decided live in conversation (not asked for in ticket #33's original tasks, but this is the only spec that owns per-content-type behavior, so it's the natural home). The concrete authoring mechanics below (markdown editor, presigned upload, note fields) are unchanged — what changed is *what triggers* each one.

## Objective

Decide how content actually gets created and edited, and — per the revision — decide the rules that infer a node's visualization from its contents rather than from a chosen-at-creation `kind`.

## Context

- Ticket: #33.
- Updates once accepted: `application_architecture.md`'s DynamoDB schema section (drops `kind` from the `Node` attrs list entirely; `ARTICLE#{id}`/`PRESENTATION#{id}`/`DESIGN#{id}` `DETAILS` records unchanged) and `boxes-plan.md` §7a's content-types section (reframed as visualization states, not a `kind` enum).
- Cites `window-system.md`'s "a node with 2+ children" trigger for map/group visualization — doesn't redecide it, just supplies the content-side half of the inference (what makes a node render as media vs. a plain info node).

## Decisions

- **Visualization is inferred from contents, evaluated in this order:**
  1. **Has 2+ child Nodes** (a real nested Map, per `application_architecture.md`'s correction) → renders as a map/group: opens a window, per `window-system.md`.
  2. **Has exactly 1 child Node** → click-through directly to that child's own content (see below) — not a 1-item map/grid.
  3. **Has an attached article/video `DETAILS` record** → renders with media chrome (thumbnail, kind pill).
  4. **Neither** → renders as a plain info node: whatever title/body/date/note/urls it directly carries, shown inline, no window.
- **A node with exactly 1 child click-throughs straight to it — confirmed.** It does not count toward the "2+ children" map threshold; clicking the parent opens directly on the one child's content (its Map if that child itself has children, its leaf view if it's a media node, or its plain fields if neither), the same way a `media` node already skips straight to its content rather than showing a pointless single-item grid.
- **Article editor: markdown source + live rendered preview, not a custom rich-text/block editor.** A plain text area for markdown plus an existing markdown-to-HTML rendering library for the preview pane is a well-trodden, cheaply-built pattern — it sidesteps the risk `#33` flagged (building a Notion-style block editor from scratch with nothing to crib from). Article body is stored as markdown text in the existing `PK: ARTICLE#{id} SK: DETAILS` record's body field — no schema change beyond formalizing that field's content type as markdown. Trigger, per the revision: attaching an article is now an explicit action available on *any* node (not gated by a prior `kind` choice) — the act of attaching one is what makes the node subsequently render with media chrome.
- **Image/video upload: direct-to-S3 presigned upload, never proxied through the backend.** The frontend requests a presigned PUT URL from the API, uploads the file bytes straight to S3, then tells the backend only the resulting S3 key. Keeps upload payloads out of Lambda entirely, consistent with `application_architecture.md`'s existing "Files/media: S3, referenced by key... never store binary blobs in item bodies" rule.
- **Notes and URLs are their own fields on `Node`, independent of visualization state.** A note and a list of URLs can be attached to *any* node regardless of what it's currently rendering as — `Node` carries `note?: string` and `urls?: [{url, label}]`, both optional, orthogonal to the inference rules above the same way `tier` already is.
- **No content versioning — always-overwrite on edit.** Matches `application_architecture.md`'s stated goal; version history is deliberately deferred scope.
- **Editor library candidates** (for the implementation ticket's own feasibility check, not decided here): a plain `<textarea>` paired with a lightweight markdown-render library (e.g. `marked` or Angular's `ngx-markdown`).
- **Plain info-node editing: plain text fields (title, body, date), not markdown.** `date` is a free-text short string, not a strict date type — the mockup's own sample data uses year-only precision.
- **Info-node body length is a soft guideline, not a hard limit — but a real one.** A `.box`'s CSS is `overflow: hidden` with no internal scroll — the editor warns (doesn't block) when body text is likely to overflow the node's current tier.
- **`annotation` doesn't infer cleanly from contents — flagged as the one place dynamic breaks down, not silently resolved.** Its whole distinguishing feature (no theme dot, minimal chrome — "for explaining, not informing") is a *presentation* choice, and nothing about its data shape differs from a short info node (both are "just some text, nothing attached"). Proposing it survive as an explicit, owner-set **display toggle** (`Node.lightweight?: true`) rather than a kind — orthogonal to the content-inference rules above, checked *after* them (a node can't be both a map/media node and lightweight-styled at the same time). This is a real fork from "everything is dynamic" and needs your confirmation, not just my inference.

## Expected behaviors (`BHV-*`)

| ID | Statement | Testability check | Notes |
|---|---|---|---|
| BHV-1 | WHEN the owner attaches an article to a node, THE editor SHALL present a markdown source pane and a live rendered preview pane side by side. | ✅ — component test: attach an article, assert both panes render | Trigger changed from "opens a `article`-kind node" to "attaches an article" — same editor, different entry point. |
| BHV-2 | WHEN the owner selects an image or video file to upload, THE frontend SHALL request a presigned S3 upload URL from the backend and upload the file directly to S3. | ✅ — integration test mocking the presign endpoint and asserting the file `PUT` goes to the S3 URL, not the backend | |
| BHV-3 | IF a selected file exceeds the size/type limit (CON-1/CON-2), THEN THE upload UI SHALL reject it client-side before requesting a presigned URL. | ✅ — unit test with an oversized/wrong-type file asserts no presign request fires | |
| BHV-4 | WHEN the owner attaches a note or a URL to any node, THE node SHALL persist it regardless of that node's current visualization state. | ✅ — CRUD test attaching a note to a node with an article, and a URL to a node with 2+ children, asserting both persist | |
| BHV-5 | WHEN the owner saves an edit to an article's or media node's content, THE backend SHALL overwrite the existing `DETAILS` record with no retained prior version. | ✅ — integration test: edit twice, assert only the latest body is retrievable | |
| BHV-6 | WHEN the owner edits a node that has neither an attached article nor 2+ children, THE editor SHALL present plain text fields for title, body, and date — no markdown source/preview pane. | ✅ — component test: open a plain info node's editor, assert no markdown preview pane renders | |
| BHV-7 | IF an info node's body text is likely to overflow its current tier footprint, THEN THE editor SHALL show a non-blocking warning suggesting a larger tier. | ✅ — component test: type body text exceeding the S-tier footprint's measured capacity, assert a warning renders and save is still allowed | Warning, not validation error — CON-7 confirms the save isn't rejected. |
| BHV-8 | WHEN the owner marks a node as lightweight (`Node.lightweight = true`), THE editor SHALL present exactly one short-text field, with no title/body split, no date, and no markdown pane. | ✅ — component test: mark a node lightweight, assert exactly one text input renders | Pending confirmation of the lightweight-toggle proposal in Decisions. |
| BHV-9 | THE canvas SHALL render a lightweight node without a theme dot, regardless of whether it carries a `note`/`urls` value. | ✅ — snapshot test: render a lightweight node, assert no `.dot` element is present | |
| BHV-10 | WHEN the owner opens a node with exactly 1 child, THE UI SHALL navigate directly to that child's own content — no intermediate single-item grid/window for the parent. | ✅ — integration test: open a node with exactly 1 child, assert the window/view shown is the child's own (Map, leaf, or fields), never a 1-cell grid | Confirmed, no longer an open question. |

## Constraints (`CON-*`)

| ID | Statement | Notes |
|---|---|---|
| CON-1 | An uploaded image MUST NOT exceed 10 MB and MUST be `jpg`, `png`, or `webp`. | Adjustable at implementation time. |
| CON-2 | An uploaded video MUST NOT exceed 200 MB and MUST be `mp4`. | |
| CON-3 | Image/video bytes MUST NOT pass through the Lambda backend at any point in the upload flow — only the S3 key crosses the API. | Enforced server-side, not just client-side. |
| CON-4 | Article body content MUST be stored as plain markdown text, not a proprietary block/rich-text JSON format. | |
| CON-5 | `Node.note` and `Node.urls` MUST be optional and MUST NOT be restricted by visualization state. | |
| CON-6 | Content edits MUST overwrite in place — no version-history record is created or retained. | |
| CON-7 | An overflow warning on info-node body length MUST NOT block saving. | |
| CON-8 | A node's visualization MUST be evaluated in the fixed order: (1) 2+ children → map, (2) exactly 1 child → click-through directly to that child, (3) attached article/video → media, (4) neither → plain info node — never stored, always computed at read/render time. | The core inference rule; everything else in this spec derives from it. Updated to place the 1-child click-through case explicitly ahead of the media/info-node checks. |
| CON-9 | A node MUST NOT simultaneously have both 2+ children and an attached article/video `DETAILS` record. | Keeps the inference in CON-8 unambiguous — a node is either a container or a content leaf, never both at once. Enforced server-side (reject attaching an article to a node that already has 2+ children, and vice versa). |
| CON-10 | The lightweight display toggle (pending confirmation) MUST be independent of and checked after CON-8's inference — a node with 2+ children or attached media MUST NOT also render lightweight. | |

## Open questions

- **The `annotation`/lightweight toggle** — needs your explicit confirmation, since it's the one place this revision couldn't make "fully dynamic" work cleanly (see Decisions).
- The "1-2 concrete library candidates" task from the ticket is still intentionally left as a short technical spike inside the implementation ticket (#39) — not load-bearing here.

## Out of scope

No implementation UI (that's #39). Does not decide the exact presigned-URL request/response contract — that's #36's job.
