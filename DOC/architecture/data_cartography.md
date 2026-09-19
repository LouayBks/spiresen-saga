# Data cartography — #36 data foundation

**Status: accepted with `ADR-007` (2026-09-19); the working reference for #57.** Drafted for ticket #36 before implementation. The physical layout's rationale and the options rejected are in [`ADR-007`](../../ADR/ADR-007-physical-data-layout.md); this doc applies it entity by entity. Map visibility (private / unlisted / public) is specified in [`map-visibility.md`](../specs/map-visibility.md). The AW-4 `plan-reviewer` pass belongs to #57's *implementation plan*, not to this design; a fresh-context review of this design was done on PR #51 and its gaps are closed here. `application_architecture.md` (the schema source of truth) carries the layout summary.

**What this is:** one place that maps every piece of data the app stores — what it is, where it lives, who can touch it, what reads and writes it, and what keeps it consistent. **What it is not:** a spec. Behavior lives in `DOC/specs/*.md` (ADR-006); this doc cites spec rule IDs and turns them into storage requirements. Where a spec still asserts a PK/SK shape, this doc supersedes it (per ADR-006's amendment).

Naming follows `naming.md`: **Map** (per-user collection) and **Node** (canvas item). "Saga" is the product brand only.

## 1. Domain model

![Domain model](diagrams/data_model.svg)

Source: [`diagrams/data_model.puml`](diagrams/data_model.puml). Regenerate after editing: `plantuml -tsvg DOC/architecture/diagrams/data_model.puml`.

Reading notes:
- This diagram is the **logical** model: a Node is shown with all its fields. How they are split across physical items (tile vs. detail) is §3 and ADR-007.
- There is **no `kind`** on Node and **no `userId`** on any Node or Map content. Identity lives only on Membership (`application_architecture.md`, multi-tenancy).
- A Node's visualization is **computed, never stored**, in this order (`content-authoring.md` CON-7): 2+ children → map; exactly 1 child → click-through; `images` present → gallery; article attached → article; otherwise info. `childCount`, `imageCount` and `hasArticle` exist only so a parent Map can be rendered from one query without asking each child.
- **Primary content is exclusive** (CON-8): at most one of Gallery / Article / nested Map. Attachments (`note`, `urls`, `preview`, `coverImage`) are orthogonal and allowed on every node (CON-4, CON-9).
- **Layout is derived per View** (`window-system.md` CON-6): no Links → grid, at least one → freeform. Nothing stores it.
- `body` is the info-node text (the primary text of an info visualization); `note` is a side annotation any node can carry. They are deliberately different fields.

## 2. Entity catalogue

| Entity | Identity | Owned by | Stored attributes | Spec source |
|---|---|---|---|---|
| User | Cognito `sub` (never email) | itself | `createdAt`, `username`, `handle` — email is not stored (it comes from the JWT claims and is never public) | accounts-and-auth CON-1, CON-8..12 |
| Membership | (`sub`, root Map id) | User ↔ root Map | `role` (`owner` only in v1), `joinedAt` | accounts-and-auth CON-3 |
| Map | root: minted id; nested: its parent Node's id | Membership (root) / parent Node (nested) | `name` (root only), `nodeCount`, `viewCount`; root only: `ownerSub`, `visibility` (`private` default), `publishedAt` (only while public) | naming, window-system CON-3/4, map-visibility |
| View | minted id | Map | `name`, `order`, `linkCount` | alternate-views |
| Node **tile** | `{parentMapId}.{shortId}` | Map | canvas fields only: `title`, `date`, `size {w,h}`, `positions {viewId → {x,y}}`, `coverImage`, `preview`, `excerpt`, and derived `childCount`, `imageCount`, `hasArticle` | box-sizing, content-authoring, alternate-views |
| Node **detail** | the owning Node's id | Node | `body`, `note`, `urls[]`, `images[]` (gallery); created on first write, absent = empty | content-authoring |
| Link | unordered node pair + View | View | `nodeA`, `nodeB` (sorted), `type`, `label` | node-link-lifecycle |
| Article body | the owning Node's id | Node | `markdown` | content-authoring CON-3, CON-5 |
| Handle claim | the handle | User | `sub` — a uniqueness record, one per handle in use | accounts-and-auth CON-9 |

**Field notes**
- `size`: two integers, min 1, max 12 (tunable constant), default 1×1, identical across Views (box-sizing CON-1/CON-2). `positions` values use the same grid unit; grid layout snaps at render time and stored freeform positions are only overwritten by an explicit drag.
- **Tile vs. detail** (ADR-007): the tile holds only what the canvas renders, every field individually capped, so a Map load is bounded. Everything else — full text, note, URLs, gallery — is in the detail, fetched only when a node is opened. `excerpt` is the first 200 characters of `body`, `imageCount` is the length of `images`, `hasArticle` mirrors the article item, `childCount` mirrors the nested Map's Node count; these four are the only derived copies and are written only inside the transaction that writes their source.
- `handle`: unique across users, `[a-z0-9_]+`, 3–20 chars; claimed by its own item so uniqueness is a key condition (ADR-007 D4). `username`: free text, 1–20 chars, not unique. Both are public wherever a Map is publicly listed; the email never is.
- `visibility`: on the **root** Map only (a nested Map inherits, and never carries it). Governs reading, never writing (map-visibility CON-3/CON-4). While `public`, the Map's META also carries the gallery-index keys and `publishedAt`; they are removed when it leaves `public`.
- `preview`: at most one per node — the first recognised-provider URL (YouTube in v1), fetched once via oEmbed at attach time. `urls` is a plain list of strings with no count cap.
- `images`: at most 10 `{s3Key, caption?}`. Bytes never touch Lambda (content-authoring CON-2); only keys are stored.
- `type`: `theme | timeline | soft`. Presentation label only — it drives no layout or logic. The value set is settled (`node-link-lifecycle.md`; `boxes-plan.md` was aligned 2026-09-19); the store still treats it as a validated string so changing the set needs no migration.
- Provisioned defaults: a new top-level Map gets 1 View and 2 placeholder Nodes joined by 1 Link (accounts-and-auth BHV-1/BHV-7). Placeholder copy is a code constant.

## 3. Physical layout (ADR-007)

![Physical layout](diagrams/physical_layout.svg)

Source: [`diagrams/physical_layout.puml`](diagrams/physical_layout.puml).

One table, generic key attributes `PK` and `SK` (both strings), on-demand billing, point-in-time recovery on, deletion protection on, **one sparse GSI** (`GSI1`, the public gallery, below) and **no LSI**. A TTL attribute is reserved for a future trash bin (#45), unused now.

| Item | PK | SK |
|---|---|---|
| User profile (`username`, `handle`) | `USER#{sub}` | `PROFILE` |
| Membership | `USER#{sub}` | `MEMBER#{rootMapId}` |
| Map meta | `MAP#{mapId}` | `META` |
| View | `MAP#{mapId}` | `VIEW#{viewId}` |
| Node tile | `MAP#{mapId}` | `NODE#{shortId}` |
| Link | `MAP#{mapId}` | `LINK#{viewId}#{lo}#{hi}` (`lo`/`hi` = sorted node short ids) |
| Node detail | `CONTENT#{nodeId}` | `DETAIL` |
| Article body | `CONTENT#{nodeId}` | `ARTICLE` |
| Handle claim | `HANDLE#{handle}` | `HANDLE` |
| Public gallery index (**GSI1**, sparse, on the root META) | `GSI1PK = MAP#PUBLIC` | `GSI1SK = {publishedAt}#{mapId}` — present only while `visibility = public`; projects `name`, `ownerSub` |

- **One Query opens a Map**: `PK = MAP#{mapId}` returns META, all Views, Node **tiles** and Links together (alternate-views CON-4, ticket "no N+1") — and nothing heavier. A nested Map is the same shape one level down, with `mapId` = the group Node's id.
- **One `BatchGetItem` opens a node**: the node's tile, `DETAIL` and `ARTICLE` (plus the ancestor tiles and root META of AP-19) in a single call. An absent `DETAIL`/`ARTICLE` means "empty"; an absent tile means 404 whatever content items exist, so an orphaned content item is never returned.
- **The existence rule** (ADR-007 D1): no write creates the thing it targets except an explicit create. Every `UpdateItem` carries `attribute_exists(PK)`; every content (`DETAIL`/`ARTICLE`) write is a transaction that also checks the owning tile; a nested Map's `META` is created only by "Add inside" (AP-26). **Reads verify reachability**: a Node is readable only if every ancestor Node's tile exists (AP-19), so a deleted subtree is unreachable at once even while cleanup lags.
- **Parent lookup from an id needs no read**: split at the last dot. Node `r.a.b` is tile `NODE#b` in partition `MAP#r.a`; the root Map is the first segment `r`. Content items are keyed by node id, so a content write authorizes off the same first segment.
- **Positions live in the tile**, so a drag is one narrow `SET positions.#view` on a ~1 KB item (alternate-views' single-write requirement) and item count never scales with nodes × views. Trade-off accepted: deleting a View cannot atomically strip its position from every tile. The View item is deleted first; leftover `positions[viewId]` entries and Links are best-effort cleanup, harmless because readers ignore unknown viewIds and viewIds are never reused.
- **No directory of all Maps.** A constant-key `MAP#ALL` directory was considered and dropped (ADR-007 D2): the gallery has its own index and nothing else needed one.
- **The public gallery is `GSI1`, a sparse index on the root META with a constant key** (`MAP#PUBLIC`): only public Maps carry the two index attributes, so the gallery is a paginated descending `Query` that touches nothing else, and DynamoDB maintains the index — no second write, no drift. Making a Map public or not is one `UpdateItem` on its META. Owner labels are read, not copied: the gallery `Query` is followed by one `BatchGetItem` on the page's owners' profiles (ADR-007 D4).
- **A handle is a unique key claim** (`HANDLE#{handle}`), created in the same transaction as the profile write, so two users can never hold one handle and a change is atomic.
- **Every read is authorized before any Map content is loaded**: root id (first dot segment) and the ancestor Nodes on the id's path → one `BatchGetItem` of the root META (consistent read) plus each ancestor tile → visibility decides, then every ancestor tile must exist (AP-19).
- **The application never scans** — enforced by leaving `dynamodb:Scan` out of the Lambda's IAM policy.

## 4. Access patterns

| # | Pattern | Operation | Notes |
|---|---|---|---|
| AP-1 | First authenticated request provisions a User | `TransactWriteItems` | Puts profile (`attribute_not_exists`; generated `handle`, `username`), the handle claim (`attribute_not_exists`), Membership, Map META (`nodeCount = 2`, `visibility = private`, `ownerSub`), default View (`linkCount = 1`), 2 placeholder tiles (+ their details if they carry body copy) and 1 Link — at most 10 items, each touched once (a transaction cannot act on one item twice). A duplicate first request fails the profile condition; the handler re-reads and returns the existing Map (accounts-and-auth CON-7). A generated-handle collision fails the claim condition instead — told apart by the per-item cancellation reasons — and is retried with a fresh handle. |
| AP-2 | List "Your Maps" | `Query USER#{sub}` `begins_with MEMBER#`, then `BatchGetItem` of each META | Two calls; the API pages at about 20 Maps (there is no cap on Maps per user), retrying unprocessed keys. META supplies name, counters and `visibility` (map-visibility BHV-11); no tiles or details are read. The name lives only in META — never copied onto Membership or the directory (CON-6). Time-sortable ids give creation order for free. |
| AP-3 | Open a Map | one `Query PK = MAP#{id}` | Returns tiles only. Also used for nested Maps and for BHV-6 of window-system. Runs only after AP-19 has allowed the read — which for a nested Map also proves every ancestor Node's tile still exists. |
| AP-4 | Authorize any write | one consistent `GetItem USER#{sub} / MEMBER#{rootId}` | Root id = first dot segment of the id in the request; applies to content writes too. |
| AP-5 | Drag a Node | `UpdateItem SET positions.#viewId` on the tile, condition `attribute_exists(PK)` | Debounced on pointer-up. ~1 KB item. The condition stops the update from creating a stray tile for a deleted or forged id. |
| AP-6 | Create a Node | `TransactWriteItems` | Put blank tile (with a `positions` entry for every existing View — one small Query of the Views first; no detail item yet, CON-5); Update META `nodeCount + 1` (conditions: `attribute_exists`, `< 50`). For a nested Map that META **must already exist** (created by AP-26), so a create in a Map with no META fails cleanly instead of upserting one. When nested, also Update the parent tile `childCount + 1` (conditions: exists, `imageCount = 0`, `hasArticle = false`) — which doubles as the parent-exists check. |
| AP-7 | Create a Link | `TransactWriteItems` | Put Link (`attribute_not_exists` — the sorted-pair key enforces "one per pair per View" in either direction), ConditionCheck on both endpoint tiles (same Map), Update View `linkCount + 1` (condition `< 100`). |
| AP-8 | Delete a Link | `TransactWriteItems` | Delete Link, Update View `linkCount − 1`. |
| AP-9 | Delete a Node | Links first, then one transaction, then cleanup | (1) Query the Map's Links (`begins_with LINK#`, filtered in code) for those touching the Node and delete them in transactions of at most ~90 actions, each also Updating the affected Views' `linkCount − n`, so `linkCount` stays exact and no Link is ever left pointing at a missing Node. (2) One transaction: Delete the tile, Update META `nodeCount − 1` and, when nested, Update the parent tile `childCount − 1`. (3) Best-effort, in the same request: its `CONTENT#` items and, if it has children, the whole nested partition (META, Views, Nodes) recursively — plus a final sweep for any Link created against it in the gap between steps 1 and 2. A failure before step 2 leaves the Node intact with fewer Links (safe to retry); a failure after it leaves only unreachable orphans (AP-19 verifies the ancestor chain). As defense in depth, a Map load drops any Link whose endpoint tile is not in the same result. |
| AP-10 | Create / delete a View | `TransactWriteItems` | META `viewCount` conditions enforce 1..3 (BHV-2/3). Delete = View item first, then best-effort cleanup. |
| AP-11 | Attach / remove an article | `TransactWriteItems` | Put/Delete `ARTICLE` + Update tile `hasArticle` (conditions: tile exists; attach also requires `childCount = 0` and `imageCount = 0`). |
| AP-12 | Rename a Map | `UpdateItem` on META | The single canonical name (CON-6). |
| AP-13 | Add / remove gallery images | `TransactWriteItems` | Update `DETAIL` `images` (cap 10, upsert) + Update tile `imageCount` — and, when the first image is added to a node with no cover, tile `coverImage` (`content-authoring.md` BHV-17); tile conditions: exists, `childCount = 0`, `hasArticle = false`. |
| AP-14 | Open a node | one `BatchGetItem`: the tile, `DETAIL`, `ARTICLE` (and, with AP-19, the root META and ancestor tiles) | Absent `DETAIL`/`ARTICLE` = empty; an absent tile = 404 regardless of content items, so orphan content of a deleted Node is never returned. |
| AP-15 | Edit title / date / size / cover | `UpdateItem` on the tile, condition `attribute_exists(PK)` | Single item, no transaction. |
| AP-16 | Edit body | `TransactWriteItems` | `DETAIL` `body` (upsert) + the tile: an Update of `excerpt` when it changes, otherwise a `ConditionCheck` that the tile exists. Always a transaction, so a forged or deleted id cannot mint a content item. |
| AP-17 | Edit note / urls | `TransactWriteItems` | `DETAIL` upsert + a `ConditionCheck` on the tile (an Update of the tile instead when the write also sets the `preview`, `content-authoring.md` BHV-11/18). Same reason as AP-16: no content item without its tile. |
| AP-18 | Change handle | `TransactWriteItems` | Put the new claim (`attribute_not_exists`), Delete the old claim (its `sub` must match), Update the profile (its current handle must match). Exactly one of two simultaneous claimants wins (accounts-and-auth BHV-9/10/12). |
| AP-19 | Authorize and locate a read (any Map, Node or content, any depth) | one `BatchGetItem` of the root META (consistent read) and the tile of every ancestor Node on the id's path — their keys are derivable from the id — then at most one membership `GetItem` | The META decides: `unlisted`/`public` → allow, signed in or not; `private` → allow a member, otherwise 404 (never 403) so existence isn't revealed (map-visibility CON-6, CON-9). Then every ancestor tile must exist, else 404 — reachability. A refused read costs a bounded number of keyed lookups, never a Map load. Nesting is guarded at 32 levels (suggested), keeping the batch small. |
| AP-20 | Browse the public gallery | `Query GSI1` on `GSI1PK = MAP#PUBLIC`, descending, then one `BatchGetItem` of the page's owners' profiles | Public Maps only, newest-published first, paged (map-visibility BHV-8); each entry shows name, owner handle and username, never email. The index is eventually consistent and projects `name` and `ownerSub`. Not a scan. |
| AP-21 | Change a Map's visibility | `UpdateItem` on the root META | To `public`: set `visibility`, `publishedAt` and the index keys; leaving `public`: remove the last three. Owner only; rejects a nested Map (map-visibility BHV-2/3/12). |
| AP-22 | Change username | `UpdateItem` on the profile | Single item, no uniqueness check (accounts-and-auth BHV-11). |
| AP-23 | Delete a Map (cascade) | delete + cleanup | Owner-only. Delete the root META first (the Map is unreachable at once, and leaves the gallery index in the same write), delete the memberships, then remove Nodes, Links, Views and content partitions (recursively into nested Maps) in bounded batches; not atomic above 100 items, leftovers are unreachable, not corrupt (`map-lifecycle.md` BHV-4/5). |
| AP-24 | Add a View | `TransactWriteItems` | META `viewCount` condition (< 3), Put the View (ordered last), and copy the active View's position into every Node's tile — batched in bounded transactions when the Map has many Nodes (`map-lifecycle.md` BHV-7). |
| AP-25 | Rename / reorder / delete a View | `UpdateItem` / `TransactWriteItems` | Rename is a single update; reorder rewrites the (at most three) Views' `order`; delete removes the View item first, then its Links and each tile's `positions[viewId]` best-effort, and closes the order gap (`map-lifecycle.md` BHV-8..10). |
| AP-26 | Add inside (create a nested Map) | `TransactWriteItems` | Put the nested META (`MAP#{nodeId}`, `attribute_not_exists`, `nodeCount = 0`, `viewCount = 1`), Put its default View (`linkCount = 0`, order 1), ConditionCheck that the Node's tile exists. Idempotent: a repeat fails the condition and is treated as "already there". The nested META and Views **survive removal of the last child** (an empty nested Map; the Node is info again because `childCount = 0`) and are deleted only with the Node (AP-9) or the root Map (AP-23). |

There is **no Scan** anywhere in v1.

## 5. Invariants and how each is enforced

| Invariant | Source | Enforcement |
|---|---|---|
| Exactly one User and one Map per first login, even on retry/race | accounts-and-auth CON-7 | AP-1 conditional put on the profile inside one transaction |
| A write is allowed only with a Membership on the root Map | accounts-and-auth BHV-6 | AP-4 on every write route; `ALLOWED_WRITER_SUBS` deleted in the same change (CON-2) |
| A client cannot forge, mint or resurrect ids | derived | Strict id regex (no `#`, fixed alphabet); PK built only from the validated id; every `UpdateItem` carries `attribute_exists`; every content write is a transaction that checks the owning tile; a nested META exists only via AP-26 with a check on the Node's tile; reads verify the ancestor tiles (AP-19) |
| After a Node is deleted, its content and subtree are unreachable at once | node-link-lifecycle CON-7 | the tile is deleted first, in the same transaction that fixes the counters; AP-19 and AP-14 require the tile chain, so orphan content and orphan partitions are never returned while cleanup lags |
| No Link points at a missing Node, and none is counted against a View's cap | node-link-lifecycle CON-9 | AP-9 deletes a Node's Links (with the `linkCount` decrement) before its tile; a Map load drops any Link whose endpoint tile is missing; a post-delete sweep catches late arrivals |
| Map has 1..3 Views | alternate-views CON-1 | META `viewCount` condition in a transaction |
| Map has ≤ 50 Nodes; View has ≤ 100 Links | limits, §7 | `nodeCount` / `linkCount` conditions in the same transaction as the create |
| At most one Link per unordered node pair per View | node-link-lifecycle CON-2 | sorted-pair sort key + `attribute_not_exists` |
| A Link joins two Nodes of the same Map; no self-link | node-link-lifecycle CON-1/CON-4 | ConditionChecks on both endpoints in one partition; reject `nodeA = nodeB` |
| Primary content exclusivity (children / gallery / article) | content-authoring CON-8 | conditions on the tile's `childCount`, `imageCount`, `hasArticle`, inside the transaction that writes the child, the images or the article |
| Size is `w,h` integers in range | box-sizing CON-2 | request validation (Pydantic), one constant for the max |
| Every Map always has ≥ 1 View | alternate-views CON-1 | created with the Map; last-View delete rejected |
| Map name is one canonical value | accounts-and-auth CON-6 | stored only in root META; never denormalized onto Membership or anywhere else |
| A Map's visibility is exactly one of three values, default `private`, on the root only | map-visibility CON-1/CON-2 | always written at creation; request validation rejects other values and rejects a nested Map |
| A private Map's existence is not revealed to non-members | map-visibility CON-6 | AP-19 answers 404 before any content read |
| A refused read never loads the Map | map-visibility CON-9 | AP-19 runs first, on the root META alone |
| Only public Maps are in the gallery | map-visibility CON-7 | the index keys exist only while `visibility = public`, and are removed in the same `UpdateItem` that changes it |
| Visibility never grants write | map-visibility CON-4 | write routes use AP-4 only; AP-19 is read-only |
| Root Map ids are unguessable | map-visibility CON-5 | server-side CSPRNG ids, never derived from a name/email/counter |
| The application never scans | ADR-007 D2 | the Lambda IAM policy omits `dynamodb:Scan` |
| A Map load is bounded regardless of content | ADR-007 criterion A | tile fields individually capped; bodies, URLs and galleries live only in the detail |
| Only `owner` memberships exist in v1 | accounts-and-auth CON-3 | provisioning code path is the only writer |
| A handle is unique, well-formed, and changes atomically | accounts-and-auth CON-8/9 | the claim item's `attribute_not_exists` inside the transaction; format validated before it; reserved handles rejected in code |
| An email is never public, and a handle is never derived from one | accounts-and-auth CON-12 | email is not stored; handles are generated from random characters or chosen by the user |
| Layout mode is never stored | window-system CON-6 | there is no attribute for it |

## 6. Lifecycle and risk notes

- **DynamoDB limits that shape this**: 400 KB per item; 100 items per transaction; 25 per batch write; 1 MB per Query page; a single partition key is capped near 1000 WCU / 3000 RCU per second. At 50 Nodes a Map load is bounded by construction — tiles of about 0.5 KB typical and about 6 KB worst case (multibyte text at DynamoDB's 4 bytes per character, longest preview), up to 300 Links, plus META and Views — typically tens of KB and at most about 0.5 MB, inside one page and independent of body, URL or gallery size.
- **Cleanup is not retried in v1 — a known limitation.** Deletes that exceed one transaction (a Node's Links, a large nested subtree, a Map's leftovers) run synchronously and best-effort; if one fails partway, nothing re-runs it. What can leak is unreachable orphan items (a deleted Node's content, orphan nested partitions, a deleted Map's leftovers): **storage cost only** — reads verify the ancestor chain (AP-19) so they are never returned, and they never count against any cap. Links are handled separately (AP-9 deletes them before the tile), so a failed cleanup cannot leave a Map load returning dangling Links. A scheduled orphan sweeper is deferred, tracked with the orphaned-media cleanup in #54.
- **Cascade delete is not atomic beyond 100 items.** Deleting a Node with a large nested subtree deletes the Node item first, which makes everything below it unreachable, then cleans up orphan partitions synchronously in bounded batches. With ≤ 50 Nodes per Map and nesting, the worst case is bounded per level but recursive; if a cleanup fails midway the leftovers are unreachable, not corrupt. A sweeper for orphans is a future item, not v1.
- **Derived fields** (`nodeCount`, `viewCount`, `linkCount`, `childCount`, `imageCount`, `hasArticle`, `excerpt`) can drift only if a write path bypasses the transaction that maintains them. They are written only inside those transactions, and every one of them has a test (TS-2/TS-3).
- **New View vs. concurrent node create** can leave a Node without a position in the new View. Readers fall back to the Node's position in another View; a new View is seeded by copying the active View's positions.
- **Write cost**: DynamoDB bills a write on the whole item size, so the tile stays small (§7 caps) — that is the reason `positions` lives on the tile (~1 KB) and not on a shared View item that would grow with every Node, and the reason full text lives in the detail. Transactions cost twice the write units; plain `UpdateItem` (always with an existence condition) is used only where one item is enough (AP-5, AP-12, AP-15); note and URL edits are transactions because `DETAIL` is an upsert (AP-17).
- **A transaction cannot act on the same item twice.** Any operation that would update one item in two ways (e.g. two nodes incrementing one `nodeCount`) must be folded into a single update.
- **Testing**: `moto` (TS-2) is the test double, but its fidelity on `TransactWriteItems` condition failures is exactly the risk TS-5 names. Add a small set of hand-run checks against a real dev table for AP-1, AP-6, AP-7 and AP-9. **AP-20 is the first GSI query, and `moto`'s GSI-pagination gap (GitHub #7725, TS-5) applies to it directly** — the gallery's paging and ordering must be verified on the real dev table, not only under `moto`.
- **The gallery is eventually consistent; opening a Map is not.** A privatized Map's name can linger in the gallery for moments, but AP-19 re-checks the root META with a consistent read, so following the entry fails (map-visibility BHV-9). Any edge cache in front of the gallery must keep a TTL in the same brief range.
- **One extra single-item read per read request** (AP-19) is the price of never loading a private Map for an unauthorized caller.

## 7. Limits

**Suggested starting values, all constants in one settings module — tunable without a schema change, to be adjusted as real use teaches us.** Checked 2026-09-19 against DynamoDB's byte-based limits (UTF-8, up to 4 bytes per character; 400 KB per item; 1 MB per `Query` page); two earlier figures were corrected (article length, detail-item guard), noted below.

| Limit | Suggested value | Basis |
|---|---|---|
| Nodes per Map | **50** (decided) | one-page Map load; "tens of boxes, not thousands" (`boxes-plan.md`) |
| Links per View | 100 | about 2 per Node at 50 Nodes |
| Views per Map | 3 | alternate-views CON-1 |
| Node `size` max | 12 per side | matches the grid's 12 columns (`window-system.md`) |
| Images per gallery | 10 | content-authoring CON-10 |
| `urls` per Node | no count cap; each URL ≤ 2,048 chars | bounded only by the `DETAIL` item's serialized size guard below — it never affects a Map load |
| `DETAIL` item guard | 100 KB serialized | corrected from 64 KB: a 10,000-character `body` can be 40 KB in multibyte text, and 64 KB left too little for the uncapped URLs; 100 KB leaves room for ~100 URLs and stays far under 400 KB |
| Tile fields | `title` 200, `date` 30, `excerpt` 200 chars; `preview`: url ≤ 2,048, `thumbnailUrl` ≤ 512, `title` ≤ 100; `coverImage` key ≤ 512 | these caps are what bound a Map load — treat them as schema constants |
| Map-load payload | ≲ 0.5 MB worst case, typically tens of KB | 50 tiles ≤ ~6 KB, ≤ 300 Links ≤ ~0.6 KB (label 100 chars), plus META and Views |
| `title` / `note` / `body` | 200 / 1,000 / 10,000 chars | the UI's overflow warning stays soft |
| Link `label`, Image `caption` | 100 / 200 chars | short labels |
| Map name / View name | 100 / 50 chars | display text |
| Handle / username | 3–20 / 1–20 chars | decided (accounts-and-auth CON-8) |
| Article markdown | 50K chars | corrected from 100K: at 4 bytes per character 100K chars is exactly the 400 KB item limit; 50K is ≤ 200 KB worst case (roughly 8,000 words of ordinary text) |
| Nesting depth | no product cap; technical guard 32 levels | `window-system.md` sets no product cap; the guard (suggested, tunable) keeps ids short and the AP-19 ancestor batch small |
| Image upload | 10 MB, jpg/png/webp | content-authoring CON-1 |
| Page size (My Maps, gallery) | about 20 | keeps each page small |

## 8. Identifiers

- Root Map id: a time-sortable random id (ULID or UUIDv7 form), minted server-side, no dots. Node short id: 12 random characters from a fixed alphabet, unique per Map. Both validated by regex on every request.
- Node id = `{parentMapId}.{shortId}`; a nested Map's id is its parent Node's id. The dot path encodes full ancestry, so the owning root Map is always the first segment (O(1) authorization, no tree walk).
- Ids are never reused, and are minted by the server only.

## 9. Authorization flow

1. Cognito JWT → `sub` (never email).
2. First request for an unknown `sub` → AP-1.
3. Any **write**: parse the target id → root Map id (first dot segment) → AP-4 consistent read of the Membership → 403 if absent.
4. v1 has only `owner`, so this is a pure existence check; role branching stays inert until a sharing feature exists (CON-3).
5. **Reads follow AP-19**, not the write path: `unlisted`/`public` Maps are readable by anyone including anonymous callers; `private` ones only by members, and a non-member gets 404. Visibility governs reading only — it never widens write access (map-visibility CON-4).

This path is the "auth-allowlist" and "cross-slice-authorization" high-risk area (AW-6): implementing it needs the AW-4 fresh-context plan review first.

## 10. Map-as-Code (#23) implications

- The JSON export/import is a **nested tree** (Map → Nodes → child Map), using **local ids and view names**, not storage ids, so an import mints fresh ids and never collides across accounts.
- Pydantic models are the published schema (`model_json_schema`); a single mapper module translates them to and from items, so repositories never leak key shapes. Every content shape stays flat and serializable (content-authoring CON-12).
- The JSON keeps `gallery`, `article` and `children` as separate optional keys with a validator allowing at most one — this is what stops a generated document from stuffing everything into one node, without reintroducing a stored `kind`.
- An import writes the Map's items first and the Membership last, so a half-written import is invisible and can be swept up. Imports over 100 items cannot be one transaction.
- The 50-Node cap applies to imports; an over-cap document is rejected before any write.

## 11. Infrastructure impact (human applies — AW-24)

Add to the `api` Terraform module: the table (`PAY_PER_REQUEST`, point-in-time recovery, deletion protection, hash key `PK`, range key `SK`, and the sparse `GSI1` on `GSI1PK`/`GSI1SK` projecting `name` and `ownerSub`), a Lambda IAM policy scoped to that table's ARN (`GetItem`, `PutItem`, `UpdateItem`, `DeleteItem`, `Query`, `BatchGetItem`, `BatchWriteItem` — `TransactWriteItems` is authorized through the underlying write actions; **deliberately no `Scan`**, ADR-007 D2 — plus `Query` on the `GSI1` index ARN), a `TABLE_NAME` environment variable, and an output. Claude writes the Terraform; a human runs `plan`/`apply`.

## 12. Open items

Everything from the earlier list was decided on 2026-09-19 (see `DOC/specs/`): `LinkType` is `theme | timeline | soft`; grid mechanics and drag persistence are `window-system.md`'s initial defaults; a gallery's first image becomes the default cover (`content-authoring.md` BHV-17); new Maps are seeded with two guiding notes on every top-level creation; the numbers in §7 are suggested starting values; `boxes-plan.md` and `application_architecture.md` are updated; ADR-007 is accepted. What remains:

1. **Moderation and takedown for public Maps** — ticket #52. It must land before the public gallery ships.
2. **Account deletion, leave-Map, data export, and cleanup of orphaned media** — ticket #54.
3. **Mobile presentation** of a Map below a width breakpoint — no spec decides it (`boxes-plan.md` §3).
4. **#57's implementation plan** goes through the AW-4 `plan-reviewer` pass, and its plan fills in `.claude/risk-paths.json`'s empty patterns (a human-only governance edit).
5. **Handle squatting** — a released handle is free at once (`accounts-and-auth.md`); an accepted trade-off, with impersonating handles listed under #52.

## 13. Traceability

`ADR-007` (physical layout, constant-key collections, no Scan) · `naming.md` CON-1/CON-3 (words) · `box-sizing.md` CON-1..3 (size) · `content-authoring.md` CON-2, CON-3, CON-7..12 (content, previews) · `alternate-views.md` CON-1..5 (Views, positions, Links) · `node-link-lifecycle.md` CON-1..6 (create/delete, Link rules) · `window-system.md` CON-3/4/6 (nested Map, derived layout) · `accounts-and-auth.md` CON-1..12 (identity, membership, provisioning, username/handle) · `map-visibility.md` CON-1..11 (visibility, gallery, read authorization).

