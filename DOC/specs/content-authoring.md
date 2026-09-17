# Spec: Content authoring mechanics (#33)

Format per `DOC/templates/spec_design_template.md` (ADR-006). Owns article/media content and the `note`/`urls` fields attachable to any node — orthogonal to `box-sizing.md` (`tier`) and `alternate-views.md` (position/links); no overlap, since content and its attachments don't vary per view or tier.

## Objective

Decide how media (image/video) and article content actually get created and edited — named in ticket #33 as the hardest piece, particularly the article editor, which risks becoming a from-scratch rich-text build with no external reference to lean on. Also closes a smaller gap found later: the plain `note`-kind's own title/body/date fields were never given an authoring flow anywhere else, since #33's own title emphasized media/article as the hard part — this spec is the natural (only) home for it.

## Context

- Ticket: #33.
- Updates once accepted: `application_architecture.md`'s DynamoDB schema section (`ARTICLE#{id}`/`PRESENTATION#{id}`/`DESIGN#{id}` `DETAILS` records, plus new `Node.note`/`Node.urls` fields) and `boxes-plan.md` §7a's content-types section.
- Directly answers the "no external reference, tough to build from scratch" risk named in the ticket by choosing **not** to build a custom rich-text/block editor at all (see Decision).

## Decisions

- **Article editor: markdown source + live rendered preview, not a custom rich-text/block editor.** A plain text area for markdown plus an existing markdown-to-HTML rendering library for the preview pane is a well-trodden, cheaply-built pattern — it sidesteps the exact risk the ticket flags (building a Notion-style block editor from scratch with nothing to crib from). Article body is stored as markdown text in the existing `PK: ARTICLE#{id} SK: DETAILS` record's body field — no schema change beyond formalizing that field's content type as markdown.
- **Image/video upload: direct-to-S3 presigned upload, never proxied through the backend.** The frontend requests a presigned PUT URL from the API, uploads the file bytes straight to S3, then tells the backend only the resulting S3 key. This keeps upload payloads out of Lambda entirely — the concrete answer to "let's hope we don't overload the lambda" for this specific ticket, and consistent with `application_architecture.md`'s existing "Files/media: S3, referenced by key... never store binary blobs in item bodies" rule.
- **Notes and URLs are their own fields on `Node`, independent of `kind`.** Per the correction that a node "can contain other nodes, articles, videos, or images with notes, urls" — a note and a list of URLs can be attached to *any* node regardless of its `kind` (a `media` node can carry a note; a `group` node can carry a reference URL), not folded into the `note`-kind's own `body` field. `Node` gains `note?: string` and `urls?: [{url, label}]`, both optional, orthogonal to `kind` and `tier` the same way those two already are to each other.
- **No content versioning — always-overwrite on edit.** Matches `application_architecture.md`'s stated goal ("cheap to run, low maintenance, fast to build"); version history is real scope, deliberately deferred, not an oversight.
- **Editor library candidates** (for the implementation ticket's own feasibility check, not decided here): a plain `<textarea>` paired with a lightweight markdown-render library (e.g. `marked` or Angular's `ngx-markdown`) for the preview pane — no WYSIWYG/ProseMirror-class dependency needed for a markdown-source model.
- **`note`-kind editing: plain text fields (title, body, date), not markdown.** Unlike an article, a note is meant to be a short, scannable fact (`boxes-plan.md` §4: "a single skill, tool, or one-line fact" at S tier) — markdown source/preview overhead isn't warranted for it. `date` is a free-text short string, not a strict date type — the mockup's own sample data uses year-only precision ("2026," "2025"), so the field shouldn't force day-level granularity nobody asked for.
- **Note body length is a soft guideline, not a hard limit — but a real one.** A `.box`'s CSS is `overflow: hidden` with no internal scroll (per the mockup) — content that doesn't fit its tier's fixed footprint is silently clipped, not reflowed. The editor should warn (not block) when body text is likely to overflow its node's current tier, since the fix is usually "pick a bigger tier" (`box-sizing.md`), not "shorten the text."

## Expected behaviors (`BHV-*`)

| ID | Statement | Testability check | Notes |
|---|---|---|---|
| BHV-1 | WHEN the owner opens the editor for an `article`-kind node, THE editor SHALL present a markdown source pane and a live rendered preview pane side by side. | ✅ — component test typing markdown into the source pane and asserting the preview pane's rendered HTML updates | |
| BHV-2 | WHEN the owner selects an image or video file to upload, THE frontend SHALL request a presigned S3 upload URL from the backend and upload the file directly to S3. | ✅ — integration test mocking the presign endpoint and asserting the file `PUT` goes to the S3 URL, not the backend | |
| BHV-3 | IF a selected file exceeds the size/type limit (CON-1/CON-2), THEN THE upload UI SHALL reject it client-side before requesting a presigned URL. | ✅ — unit test with an oversized/wrong-type file asserts no presign request fires | Client-side check is a UX courtesy; CON-3 covers the enforced/authoritative boundary. |
| BHV-4 | WHEN the owner attaches a note or a URL to any node, THE node SHALL persist it regardless of the node's `kind`. | ✅ — CRUD test attaching a note to a `media` node and a URL to a `group` node, asserting both persist | |
| BHV-5 | WHEN the owner saves an edit to an article's or media node's content, THE backend SHALL overwrite the existing `DETAILS` record with no retained prior version. | ✅ — integration test: edit twice, assert only the latest body is retrievable | |
| BHV-6 | WHEN the owner edits a `note`-kind node, THE editor SHALL present plain text fields for title, body, and date — no markdown source/preview pane. | ✅ — component test: open a `note` node's editor, assert no markdown preview pane renders | |
| BHV-7 | IF a note's body text is likely to overflow its node's current tier footprint, THEN THE editor SHALL show a non-blocking warning suggesting a larger tier. | ✅ — component test: type body text exceeding the S-tier footprint's measured capacity, assert a warning renders and save is still allowed | Warning, not validation error — CON-8 confirms the save isn't rejected. |

## Constraints (`CON-*`)

| ID | Statement | Notes |
|---|---|---|
| CON-1 | An uploaded image MUST NOT exceed 10 MB and MUST be `jpg`, `png`, or `webp`. | Adjustable at implementation time; stated here so #36/#39 have a concrete starting number rather than an open-ended one. |
| CON-2 | An uploaded video MUST NOT exceed 200 MB and MUST be `mp4`. | Same — a starting constraint, not a hard external requirement. |
| CON-3 | Image/video bytes MUST NOT pass through the Lambda backend at any point in the upload flow — only the S3 key crosses the API. | The binding version of BHV-2/3's presigned-upload behavior; enforced server-side (the backend never accepts a multipart file body for media uploads), not just a client-side courtesy. |
| CON-4 | Article body content MUST be stored as plain markdown text, not a proprietary block/rich-text JSON format. | Keeps the door open to swapping the render library later without a data migration. |
| CON-5 | `Node.note` and `Node.urls` MUST be optional and MUST NOT be restricted to any particular `kind`. | |
| CON-6 | Content edits MUST overwrite in place — no version-history record is created or retained. | States the no-versioning decision as a binding constraint, not just a design note. |
| CON-7 | A `note`-kind node's `date` field MUST be a free-text short string, not a strict date type — MUST NOT require day-level precision. | Matches the mockup's own year-only sample data. |
| CON-8 | An overflow warning on note body length MUST NOT block saving. | Distinguishes a soft authoring aid from an enforced constraint — the owner may accept clipped text deliberately. |

## Open questions

None load-bearing — the "1-2 concrete library candidates" task from the ticket is intentionally left as a short technical spike inside the implementation ticket (#39), not a decision this design-pass spec needs to pin down, since either candidate satisfies every constraint above identically (both are markdown-render libraries, not architectural choices).

## Out of scope

No implementation UI (that's #39). Does not decide the exact presigned-URL request/response contract (endpoint shape, expiry) — that's #36's job once this spec's direct-upload decision is accepted.
