# Data cartography — #36 data foundation

**Status: proposal, not yet accepted.** Drafted 2026-09-19 for ticket #36, before implementation. The physical layout's rationale and the options rejected are in [`ADR-007`](../../ADR/ADR-007-physical-data-layout.md) (also *Proposed*); this doc applies it entity by entity. It has not been through the AW-4 `plan-reviewer` pass, and `application_architecture.md` (the schema source of truth) is **not** updated until both are accepted — at which point the physical layout moves there and this doc keeps the cross-cutting map (entities, access patterns, invariants, limits).

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
| User | Cognito `sub` (never email) | itself | `createdAt` only — email/name come from JWT claims, not stored | accounts-and-auth CON-1 |
| Membership | (`sub`, root Map id) | User ↔ root Map | `role` (`owner` only in v1), `joinedAt` | accounts-and-auth CON-3 |
| Map | root: minted id; nested: its parent Node's id | Membership (root) / parent Node (nested) | `name` (root only), `nodeCount`, `viewCount` | naming, window-system CON-3/4 |
| View | minted id | Map | `name`, `order`, `linkCount` | alternate-views |
| Node **tile** | `{parentMapId}.{shortId}` | Map | canvas fields only: `title`, `date`, `size {w,h}`, `positions {viewId → {x,y}}`, `coverImage`, `preview`, `excerpt`, and derived `childCount`, `imageCount`, `hasArticle` | box-sizing, content-authoring, alternate-views |
| Node **detail** | the owning Node's id | Node | `body`, `note`, `urls[]`, `images[]` (gallery); created on first write, absent = empty | content-authoring |
| Link | unordered node pair + View | View | `nodeA`, `nodeB` (sorted), `type`, `label` | node-link-lifecycle |
| Article body | the owning Node's id | Node | `markdown` | content-authoring CON-3, CON-5 |
| Map directory entry | root Map id | itself | `ownerSub`, `createdAt` — immutable pointer, nothing else | ADR-007 D2 |

**Field notes**
- `size`: two integers, min 1, max 12 (tunable constant), default 1×1, identical across Views (box-sizing CON-1/CON-2). `positions` values use the same grid unit; grid layout snaps at render time and stored freeform positions are only overwritten by an explicit drag.
- **Tile vs. detail** (ADR-007): the tile holds only what the canvas renders, every field individually capped, so a Map load is bounded. Everything else — full text, note, URLs, gallery — is in the detail, fetched only when a node is opened. `excerpt` is the first 200 characters of `body`, `imageCount` is the length of `images`, `hasArticle` mirrors the article item, `childCount` mirrors the nested Map's Node count; these four are the only derived copies and are written only inside the transaction that writes their source.
- `preview`: at most one per node — the first recognised-provider URL (YouTube in v1), fetched once via oEmbed at attach time. `urls` is a plain list of strings with no count cap.
- `images`: at most 10 `{s3Key, caption?}`. Bytes never touch Lambda (content-authoring CON-2); only keys are stored.
- `type`: `theme | timeline | soft`. Presentation label only — it drives no layout or logic. The value set is inconsistent across `boxes-plan.md` (which also says `causal`) and needs a spec fix; the store treats it as a validated string so changing the set needs no migration.
- Provisioned defaults: a new top-level Map gets 1 View and 2 placeholder Nodes joined by 1 Link (accounts-and-auth BHV-1/BHV-7). Placeholder copy is a code constant.

## 3. Physical layout (proposed — ADR-007)

![Physical layout](diagrams/physical_layout.svg)

Source: [`diagrams/physical_layout.puml`](diagrams/physical_layout.puml).

One table, generic key attributes `PK` and `SK` (both strings), on-demand billing, point-in-time recovery on, deletion protection on, no GSI and **no LSI** in v1. A TTL attribute is reserved for a future trash bin (#45), unused now.

| Item | PK | SK |
|---|---|---|
| User profile | `USER#{sub}` | `PROFILE` |
| Membership | `USER#{sub}` | `MEMBER#{rootMapId}` |
| Map meta | `MAP#{mapId}` | `META` |
| View | `MAP#{mapId}` | `VIEW#{viewId}` |
| Node tile | `MAP#{mapId}` | `NODE#{shortId}` |
| Link | `MAP#{mapId}` | `LINK#{viewId}#{lo}#{hi}` (`lo`/`hi` = sorted node short ids) |
| Node detail | `CONTENT#{nodeId}` | `DETAIL` |
| Article body | `CONTENT#{nodeId}` | `ARTICLE` |
| Map directory entry | `MAP#ALL` | `MAP#{rootMapId}` |

- **One Query opens a Map**: `PK = MAP#{mapId}` returns META, all Views, Node **tiles** and Links together (alternate-views CON-4, ticket "no N+1") — and nothing heavier. A nested Map is the same shape one level down, with `mapId` = the group Node's id.
- **One Query opens a node**: `PK = CONTENT#{nodeId}` returns the detail and, by CON-8 exclusivity, at most the article beside it.
- **Parent lookup from an id needs no read**: split at the last dot. Node `r.a.b` is tile `NODE#b` in partition `MAP#r.a`; the root Map is the first segment `r`. Content items are keyed by node id, so a content write authorizes off the same first segment.
- **Positions live in the tile**, so a drag is one narrow `SET positions.#view` on a ~1 KB item (alternate-views' single-write requirement) and item count never scales with nodes × views. Trade-off accepted: deleting a View cannot atomically strip its position from every tile. The View item is deleted first; leftover `positions[viewId]` entries and Links are best-effort cleanup, harmless because readers ignore unknown viewIds and viewIds are never reused.
- **`MAP#ALL` is a constant-key directory of immutable pointers** — "list every Map" is a paginated `Query`, never a Scan. It holds no name and no mutable field (CON-6). No v1 endpoint reads it. Filtering by visibility, when decided, is a sparse GSI on META, not new attributes here.
- **The application never scans** — enforced by leaving `dynamodb:Scan` out of the Lambda's IAM policy.

## 4. Access patterns

| # | Pattern | Operation | Notes |
|---|---|---|---|
| AP-1 | First authenticated request provisions a User | `TransactWriteItems` | Puts profile (`attribute_not_exists`), Membership, Map META (`nodeCount = 2`), default View (`linkCount = 1`), 2 placeholder tiles (+ their details if they carry body copy), 1 Link, and the `MAP#ALL` directory entry — at most 10 items, each touched once (a transaction cannot act on one item twice). A concurrent duplicate fails the profile condition; the handler re-reads and returns the existing Map (accounts-and-auth CON-7). |
| AP-2 | List "Your Maps" | `Query USER#{sub}` `begins_with MEMBER#`, then `BatchGetItem` of each META | Two calls, paginated at 100. The name lives only in META — never copied onto Membership or the directory (CON-6). |
| AP-3 | Open a Map | one `Query PK = MAP#{id}` | Returns tiles only. Also used for nested Maps and for BHV-6 of window-system. |
| AP-4 | Authorize any write | one consistent `GetItem USER#{sub} / MEMBER#{rootId}` | Root id = first dot segment of the id in the request; applies to content writes too. |
| AP-5 | Drag a Node | `UpdateItem SET positions.#viewId` on the tile | Debounced on pointer-up. ~1 KB item. |
| AP-6 | Create a Node | `TransactWriteItems` | Put blank tile (with a `positions` entry for every existing View — one small Query of the Views first; no detail item yet, CON-5), Update META `nodeCount + 1` (condition `< 50`), ConditionCheck on the parent tile exists, and when nested, Update the parent tile `childCount + 1` (condition: `imageCount = 0`, `hasArticle = false`). |
| AP-7 | Create a Link | `TransactWriteItems` | Put Link (`attribute_not_exists` — the sorted-pair key enforces "one per pair per View" in either direction), ConditionCheck on both endpoint tiles (same Map), Update View `linkCount + 1` (condition `< 100`). |
| AP-8 | Delete a Link | `TransactWriteItems` | Delete Link, Update View `linkCount − 1`. |
| AP-9 | Delete a Node (cascade) | Delete + cleanup | Delete the tile first (subtree becomes unreachable), then its `CONTENT#` items, its Links (`Query begins_with LINK#` on the Map, filter in code) and, if it has children, the whole nested partition recursively. Not atomic above 100 items — see §6. |
| AP-10 | Create / delete a View | `TransactWriteItems` | META `viewCount` conditions enforce 1..3 (BHV-2/3). Delete = View item first, then best-effort cleanup. |
| AP-11 | Attach / remove an article | `TransactWriteItems` | Put/Delete `ARTICLE` + Update tile `hasArticle`; attach requires `childCount = 0` and `imageCount = 0`. |
| AP-12 | Rename a Map | `UpdateItem` on META | The single canonical name (CON-6). |
| AP-13 | Add / remove gallery images | `TransactWriteItems` | Update `DETAIL` `images` (cap 10, upsert) + Update tile `imageCount`; requires tile `childCount = 0` and `hasArticle = false`. |
| AP-14 | Open a node | one `Query PK = CONTENT#{nodeId}` | Detail plus, if present, the article. Absent items mean "empty". |
| AP-15 | Edit title / date / size / cover | `UpdateItem` on the tile | Single item, no transaction. |
| AP-16 | Edit body | `TransactWriteItems` when the excerpt changes, else `UpdateItem` | `DETAIL` `body` + tile `excerpt` together. |
| AP-17 | Edit note / urls | `UpdateItem` on `DETAIL` | Single item. Attaching the first recognised-provider URL also sets the tile `preview` (transaction). |
| AP-18 | List all Maps | `Query PK = MAP#ALL` | Not exposed in v1 (ADR-007 D2); paginated, never a Scan. |

There is **no Scan** anywhere in v1.

## 5. Invariants and how each is enforced

| Invariant | Source | Enforcement |
|---|---|---|
| Exactly one User and one Map per first login, even on retry/race | accounts-and-auth CON-7 | AP-1 conditional put on the profile inside one transaction |
| A write is allowed only with a Membership on the root Map | accounts-and-auth BHV-6 | AP-4 on every write route; `ALLOWED_WRITER_SUBS` deleted in the same change (CON-2) |
| A client cannot forge a node id into a Map they don't own | derived | Strict id regex (no `#`, fixed alphabet); PK built only from the validated id; parent Node must exist (ConditionCheck), so no stray partitions can be minted under an owned root |
| Map has 1..3 Views | alternate-views CON-1 | META `viewCount` condition in a transaction |
| Map has ≤ 50 Nodes; View has ≤ 100 Links | limits, §7 | `nodeCount` / `linkCount` conditions in the same transaction as the create |
| At most one Link per unordered node pair per View | node-link-lifecycle CON-2 | sorted-pair sort key + `attribute_not_exists` |
| A Link joins two Nodes of the same Map; no self-link | node-link-lifecycle CON-1/CON-4 | ConditionChecks on both endpoints in one partition; reject `nodeA = nodeB` |
| Primary content exclusivity (children / gallery / article) | content-authoring CON-8 | conditions on the tile's `childCount`, `imageCount`, `hasArticle`, inside the transaction that writes the child, the images or the article |
| Size is `w,h` integers in range | box-sizing CON-2 | request validation (Pydantic), one constant for the max |
| Every Map always has ≥ 1 View | alternate-views CON-1 | created with the Map; last-View delete rejected |
| Map name is one canonical value | accounts-and-auth CON-6 | stored only in root META; never denormalized onto Membership or the `MAP#ALL` directory |
| The application never scans | ADR-007 D2 | the Lambda IAM policy omits `dynamodb:Scan` |
| A Map load is bounded regardless of content | ADR-007 criterion A | tile fields individually capped; bodies, URLs and galleries live only in the detail |
| Only `owner` memberships exist in v1 | accounts-and-auth CON-3 | provisioning code path is the only writer |
| Layout mode is never stored | window-system CON-6 | there is no attribute for it |

## 6. Lifecycle and risk notes

- **DynamoDB limits that shape this**: 400 KB per item; 100 items per transaction; 25 per batch write; 1 MB per Query page; a single partition key is capped near 1000 WCU / 3000 RCU per second. At 50 Nodes a Map load is bounded by construction — tiles of about 0.5 KB typical and 2 KB worst case, up to 300 Links, plus META and Views — on the order of 0.1–0.2 MB, inside one page and independent of body, URL or gallery size.
- **Cascade delete is not atomic beyond 100 items.** Deleting a Node with a large nested subtree deletes the Node item first, which makes everything below it unreachable, then cleans up orphan partitions synchronously in bounded batches. With ≤ 50 Nodes per Map and nesting, the worst case is bounded per level but recursive; if a cleanup fails midway the leftovers are unreachable, not corrupt. A sweeper for orphans is a future item, not v1.
- **Derived fields** (`nodeCount`, `viewCount`, `linkCount`, `childCount`, `imageCount`, `hasArticle`, `excerpt`) can drift only if a write path bypasses the transaction that maintains them. They are written only inside those transactions, and every one of them has a test (TS-2/TS-3).
- **New View vs. concurrent node create** can leave a Node without a position in the new View. Readers fall back to the Node's position in another View; a new View is seeded by copying the active View's positions.
- **Write cost**: DynamoDB bills a write on the whole item size, so the tile stays small (§7 caps) — that is the reason `positions` lives on the tile (~1 KB) and not on a shared View item that would grow with every Node, and the reason full text lives in the detail. Transactions cost twice the write units; plain `UpdateItem` is used wherever one item is enough (AP-5, AP-12, AP-15, AP-17).
- **A transaction cannot act on the same item twice.** Any operation that would update one item in two ways (e.g. two nodes incrementing one `nodeCount`) must be folded into a single update.
- **Testing**: `moto` (TS-2) is the test double, but its fidelity on `TransactWriteItems` condition failures is exactly the risk TS-5 names. Add a small set of hand-run checks against a real dev table for AP-1, AP-6, AP-7 and AP-9.

## 7. Limits

All are constants in one settings module — tunable without a schema change.

| Limit | Value | Basis |
|---|---|---|
| Nodes per Map | **50** (decided 2026-09-19) | one-page Map load; "tens of boxes, not thousands" (`boxes-plan.md`) |
| Links per View | 100 | proposal: about 2 per Node at 50 Nodes — confirm |
| Views per Map | 3 | alternate-views CON-1 |
| Node `size` max | 12 per side | proposal — a grid needs some bound |
| Images per gallery | 10 | content-authoring CON-10 |
| `urls` per Node | no count cap | guarded only by the `DETAIL` item's serialized size (about 64 KB) — proposal; it never affects a Map load |
| Tile fields | `title` 200, `date` 30, `excerpt` 200 chars; `preview` fields ~300 | proposal; these caps are what bound a Map load, so treat them as schema constants |
| Map-load payload | ≲ 0.2 MB by construction | 50 tiles ≤ 2 KB, ≤ 300 Links ≤ 0.2 KB, plus META and Views |
| `title` / `note` / `body` | 200 / 1,000 / 10,000 chars | proposal; the UI's overflow warning stays soft |
| Link `label`, Image `caption` | 100 / 200 chars | proposal |
| Map name / View name | 100 / 50 chars | proposal |
| Article markdown | 100K chars | proposal; far under the 400 KB item limit |
| Nesting depth | no cap | window-system decision; key-length limits are nowhere near |
| Image upload | 10 MB, jpg/png/webp | content-authoring CON-1 |

## 8. Identifiers

- Root Map id: a time-sortable random id (ULID or UUIDv7 form), minted server-side, no dots. Node short id: 12 random characters from a fixed alphabet, unique per Map. Both validated by regex on every request.
- Node id = `{parentMapId}.{shortId}`; a nested Map's id is its parent Node's id. The dot path encodes full ancestry, so the owning root Map is always the first segment (O(1) authorization, no tree walk).
- Ids are never reused, and are minted by the server only.

## 9. Authorization flow

1. Cognito JWT → `sub` (never email).
2. First request for an unknown `sub` → AP-1.
3. Any write: parse the target id → root Map id (first dot segment) → AP-4 consistent read of the Membership → 403 if absent.
4. v1 has only `owner`, so this is a pure existence check; role branching stays inert until a sharing feature exists (CON-3).
5. Reads of public content stay unauthenticated; Map visibility (public/private/unlisted) is an open item and not decided here.

This path is the "auth-allowlist" and "cross-slice-authorization" high-risk area (AW-6): implementing it needs the AW-4 fresh-context plan review first.

## 10. Map-as-Code (#23) implications

- The JSON export/import is a **nested tree** (Map → Nodes → child Map), using **local ids and view names**, not storage ids, so an import mints fresh ids and never collides across accounts.
- Pydantic models are the published schema (`model_json_schema`); a single mapper module translates them to and from items, so repositories never leak key shapes. Every content shape stays flat and serializable (content-authoring CON-12).
- The JSON keeps `gallery`, `article` and `children` as separate optional keys with a validator allowing at most one — this is what stops a generated document from stuffing everything into one node, without reintroducing a stored `kind`.
- An import writes the Map's items first and the Membership last, so a half-written import is invisible and can be swept up. Imports over 100 items cannot be one transaction.
- The 50-Node cap applies to imports; an over-cap document is rejected before any write.

## 11. Infrastructure impact (human applies — AW-24)

Add to the `api` Terraform module: the table (`PAY_PER_REQUEST`, point-in-time recovery, deletion protection, hash key `PK`, range key `SK`), a Lambda IAM policy scoped to that table's ARN (`GetItem`, `PutItem`, `UpdateItem`, `DeleteItem`, `Query`, `BatchGetItem`, `BatchWriteItem` — `TransactWriteItems` is authorized through the underlying write actions; **deliberately no `Scan`**, ADR-007 D2), a `TABLE_NAME` environment variable, and an output. Claude writes the Terraform; a human runs `plan`/`apply`.

## 12. Open items

1. ~~`MAP#ALL` directory vs. sparse GSI~~ — decided in ADR-007 D2: immutable constant-key directory now, unread in v1; filtering later via a sparse GSI on META.
1a. Gallery tile thumbnail: the tile carries `coverImage` only. If a gallery node without a cover should show its first image, the tile also needs a `firstImage` key (one short string) — not decided.
2. Grid drag-rearrange: is a drag inside a grid View persisted, and where (`window-system.md` open question)?
3. `LinkType` value set (`theme | timeline | soft` vs. `causal`) — spec inconsistency to resolve.
4. Confirm the proposed limits marked "proposal" in §7.
5. Whether "+ New Map" seeds the two placeholders like first login (currently assumed yes).
6. Map visibility (public/private/unlisted) — inherited open item.
7. Amend `boxes-plan.md` (§2 schema, §4 tiers, §7a) — flagged by the specs' "updates once accepted" notes, not done here.

## 13. Traceability

`ADR-007` (physical layout, constant-key collections, no Scan) · `naming.md` CON-1/CON-3 (words) · `box-sizing.md` CON-1..3 (size) · `content-authoring.md` CON-2, CON-3, CON-7..12 (content, previews) · `alternate-views.md` CON-1..5 (Views, positions, Links) · `node-link-lifecycle.md` CON-1..6 (create/delete, Link rules) · `window-system.md` CON-3/4/6 (nested Map, derived layout) · `accounts-and-auth.md` CON-1..7 (identity, membership, provisioning).

