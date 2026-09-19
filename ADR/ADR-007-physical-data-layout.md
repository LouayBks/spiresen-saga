# ADR-007: Physical data layout — DynamoDB keys, item split, and constant-key collections

**Status:** Proposed
**Date:** 2026-09-19
**Scope:** how the app's data is physically laid out in DynamoDB — partition/sort key design, which attributes live in which item, and the rule for keys that have no natural owner (listings). It does **not** decide product behavior (that is `DOC/specs/*.md`, per ADR-006's amendment), IAM/Terraform wiring beyond the one control named below, or API shapes. The entity-by-entity map that applies this decision is `DOC/architecture/data_cartography.md`.

## Context and objective

Ticket #36 implements the persistence layer after the Stage-A specs (#31–#35, #43, #44) settled what must be stored. ADR-006's amendment reserves the physical shape for #36, and `application_architecture.md` already commits to a single-table design, FastAPI on Lambda, and "single `Query` per Map partition, no N+1 fan-out, payloads sized for cold-start-sensitive Lambda."

The owner's stated priorities, proposed on several occasions before this ADR, are: **use constant ("dummy") keys where needed so every read is a key lookup and nothing scans; and retrieve only what a given view needs** — opening a Map must not pull every node's full details.

Requirements handed down by the specs that any layout must satisfy:
- A Map's Nodes, Links and Views fetchable in one request (`alternate-views.md` CON-4).
- Repositioning one node in one View is a single narrow write, and item count does not scale with nodes × Views (`alternate-views.md`).
- Nested Maps are real Nodes/Links/Views, addressable and authorizable like a top-level Map (`window-system.md` CON-3/CON-4).
- One canonical Map name (`accounts-and-auth.md` CON-6); atomic, idempotent first-login provisioning (CON-7).
- Primary node content is exclusive — children, gallery, or article, never two (`content-authoring.md` CON-8) — and a node's visualization is computed, never stored (CON-7).
- Caps: 50 Nodes per Map, `urls` uncapped, gallery ≤ 10 (`data_cartography.md` §7).

Verified DynamoDB facts this decision leans on (AWS Developer Guide):
- A `ProjectionExpression` **does not reduce consumed capacity** — read units are computed on the size of the items read, not the data returned. Projection only trims bytes on the wire.
- For `Query`, the total size of all items evaluated is summed and rounded up to the next 4 KB; an eventually consistent read costs half a strongly consistent one.
- Writes are billed on the whole item size, so updating one attribute of a large item costs the whole item.
- A transaction (`TransactWriteItems`) allows up to 100 actions and 4 MB total, cannot act on the same item twice, and costs twice the write units of a standalone write.
- Item collections are capped at 10 GB only when a local secondary index exists.
- A single partition key is bounded near 1000 write / 3000 read units per second.

## Decision drivers (criteria)

| ID | Criterion | Question it answers | Source |
|---|---|---|---|
| A | Bytes evaluated to open a Map, including the worst case | Is the size of a Map load bounded by construction, or only by typical content? Does it stay inside one 1 MB `Query` page? | AWS DynamoDB Developer Guide (capacity billed on item size; `Query` page limit); owner requirement to retrieve only what the view needs. |
| B | Requests per common user action | Do open-Map, open-node, drag and edit each take a bounded, small number of requests, with no scan and no N+1? | `application_architecture.md`; ticket #36 ("Lambda-lean"). |
| C | Write cost and narrowness of the most frequent write | What does a node drag cost, and how many attributes/items does it touch? | AWS docs (write billed on item size); `alternate-views.md` single-narrow-write requirement. |
| D | Atomic enforcement of invariants | Can uniqueness, caps and content exclusivity be enforced by conditions in one transaction, without a read-then-write race? | AWS docs (conditional writes, transactions); `accounts-and-auth.md` CON-7, `content-authoring.md` CON-8. |
| E | Drift risk from denormalized copies | How many fields exist in more than one place, and what keeps them in step? | Classical denormalization trade-off; `application_architecture.md` already names the two-write cost of display-field copies. |
| F | Implementation and test ceremony | How much repository/transaction machinery and test surface does this need, given `moto`'s known fidelity gaps? | ADR-003 / `testing_strategy.md` TS-2, TS-5; YAGNI (as in ADR-001 criterion F). |
| G | Cascade-delete and export/import (#23) tractability | How hard is deleting a node's subtree and mapping a Map to/from a JSON document? | `node-link-lifecycle.md` CON-3; `content-authoring.md` CON-12. |
| H | Scan and hot-key freedom | Is every read a key lookup, and is any single key a write hot spot? | AWS docs (partition limits); owner requirement (no costly scans). |

## Considered options

1. **One fat item per Node** — everything about a node (display fields, body, note, urls, images, positions) in a single item, article body aside. The layout `data_cartography.md`'s first draft proposed.
2. **Tile + detail split in one table** — a small "tile" item per node in the Map's own partition, carrying only what the canvas needs; a separate "detail" item (and article item) per node in its own partition, read only when the node is opened.
3. **One document per Map** — the whole Map (nodes, links, views, details) as a single item. The baseline.
4. **Fully normalized fine-grained items** — one item per position per View, per attribute group, per link endpoint. Included to test the other end.

Excluded: multi-table designs (contradicts the committed single-table decision), and a relational/other store (out of scope, the stack is fixed).

## Evaluation

Scores use a 1–3 scale (1 = Weak, 2 = Moderate, 3 = Strong) against the criteria above.

### Option 1 — One fat item per Node

Simplest mental model: one node, one item. Positions embedded as a map keyed by `viewId`, so a drag is one `SET positions.#view`. Every invariant sits on a single item.

| A | B | C | D | E | F | G | H |
|---|---|---|---|---|---|---|---|
| 1 | 3 | 1 | 3 | 3 | 3 | 3 | 3 |

Contested points:
- **A is 1, not 2.** Typical content is small, but the caps make the worst case unbounded in practice: `urls` has no count cap and `body` allows 10,000 characters, so 50 nodes can exceed the 1 MB `Query` page. That breaks the single-`Query`-per-Map guarantee exactly when a Map is content-heavy. A projection cannot rescue this — it trims the response, not the capacity or the item read.
- **C is 1.** A drag rewrites the whole item's billed size; a node carrying a large URL list or body makes the most frequent write the most expensive one.

### Option 2 — Tile + detail split in one table

The Map's partition holds only tiles, views, links and meta; a node's full text lives in a separate partition keyed by node id. Opening a Map is one `Query` returning only what the canvas renders. Opening a node is one `Query` on its own content partition, which returns the detail item and, by CON-8 exclusivity, at most one heavy item beside it (the article).

| A | B | C | D | E | F | G | H |
|---|---|---|---|---|---|---|---|
| 3 | 3 | 3 | 2 | 2 | 2 | 2 | 3 |

Contested points:
- **A is 3 by construction.** Tile fields are individually capped (title, date, excerpt, preview, cover), so a 50-node Map is bounded — on the order of 0.1–0.2 MB even with multibyte text and the maximum links — regardless of how large bodies, URL lists or galleries get.
- **C is 3 for the dominant write.** A drag touches only a ~1 KB tile. Edits that change the excerpt must update tile and detail together, a transaction at twice the write cost; that is real but concerns a rare, larger write, and is skipped when the excerpt is unchanged.
- **D is 2, not 3.** Exclusivity now spans two items (`childCount`/`imageCount`/`hasArticle` on the tile, images in the detail), so those checks are transactional rather than a single-item condition.
- **E is 2.** Four tile fields are derived copies (`excerpt`, `imageCount`, `hasArticle`, `childCount`). They change only inside the transaction that changes their source, and each has a test; every other field has exactly one home.
- **F is 2, G is 2.** More items per node (tile, detail, maybe article) means more repository code, a slightly bigger cascade and a join on export — modest, and no worse than the counters Option 1 already needs.

### Option 3 — One document per Map

The whole Map is a single item — one `GetItem` opens it.

| A | B | C | D | E | F | G | H |
|---|---|---|---|---|---|---|---|
| 1 | 3 | 1 | 1 | 3 | 2 | 2 | 3 |

Contested points:
- **A and C are 1.** Every open reads every detail; every drag rewrites the entire Map at whole-item billing.
- **D is 1.** The 400 KB item limit is reachable (50 nodes × their details), concurrent edits overwrite each other unless optimistic locking is bolted on, and a nested Map needs its own document anyway.
- **B is 3** — one request — which is the only thing it wins.

### Option 4 — Fully normalized fine-grained items

One item per (node, View) position, one per attribute group.

| A | B | C | D | E | F | G | H |
|---|---|---|---|---|---|---|---|
| 2 | 3 | 3 | 2 | 2 | 1 | 1 | 3 |

Contested points:
- **It fails a hard requirement**, whatever its score: `alternate-views.md` says item count MUST NOT scale with nodes × Views, and per-View position items do exactly that (up to 3× the nodes).
- **F and G are 1.** The most machinery, the most items to keep coherent, the largest cascade.

### Full comparison table

| ID | 1. Fat item | 2. Tile + detail | 3. Map document | 4. Fully normalized |
|---|---|---|---|---|
| A | 1 | 3 | 1 | 2 |
| B | 3 | 3 | 3 | 3 |
| C | 1 | 3 | 1 | 3 |
| D | 3 | 2 | 1 | 2 |
| E | 3 | 2 | 3 | 2 |
| F | 3 | 2 | 2 | 1 |
| G | 3 | 2 | 2 | 1 |
| H | 3 | 3 | 3 | 3 |

## Decision

**Option 2: split each node into a tile and a detail, in a single table, with keys designed so every read is a `GetItem`/`Query` on a key computable from the request.** It wins A and C outright — the two criteria the owner named — and loses D/E/F/G by exactly one point each to the fat item, the price of one extra item per node and four derived fields. Option 1 is the honest runner-up and the right choice if content were guaranteed small; the uncapped `urls` and the 10,000-character body are what make its worst case unacceptable. Option 3 fails on capacity and concurrency; Option 4 fails a spec constraint.

### D1 — The layout

![Physical layout](../DOC/architecture/diagrams/physical_layout.svg)

Source: [`DOC/architecture/diagrams/physical_layout.puml`](../DOC/architecture/diagrams/physical_layout.puml).

- **`MAP#{mapId}` partition — the canvas.** One `Query` returns `META`, every `VIEW#`, every `NODE#{shortId}` **tile**, and every `LINK#`. A nested Map is the same shape, with `mapId` equal to its group Node's id. Sort-key prefixes keep item types separable if a later access pattern wants only one of them (`begins_with`).
- **Tile (`NODE#`)** carries only what the canvas renders: `title`, `date`, `size`, `positions`, `coverImage`, the single `preview`, a capped `excerpt` of the body, and the derived `childCount`, `imageCount`, `hasArticle`. Every field is individually capped, so the tile's size is bounded.
- **`CONTENT#{nodeId}` partition — the node's full data.** `DETAIL` holds `body`, `note`, `urls[]`, `images[]`. `ARTICLE` holds the markdown. One `Query` on this partition opens a node; exclusivity (CON-8) means at most one heavy item accompanies the detail. `DETAIL` is created on the first write of any detail field; an absent item means "empty". The content partition is keyed by node id, so the owning root Map is still derivable from the id (first dot segment) — no `mapId` attribute is needed to authorize a content write.
- **Positions live in the tile**, so a drag is one narrow `SET positions.#view` on a ~1 KB item and the item count does not scale with nodes × Views. Deleting a View cannot atomically strip its position from every tile: the View item is deleted first, and leftover `positions[viewId]` entries and Links are best-effort cleanup — harmless because readers ignore unknown viewIds and viewIds are never reused.
- **Links** sort as `LINK#{viewId}#{lo}#{hi}` with the two endpoint short ids in sorted order, so "at most one Link per node pair per View, in either direction" is enforced by an `attribute_not_exists` put — no read-then-write race.
- **Which copy is authoritative.** Each tile field is the single source of truth except the four derived ones: `excerpt` (from `body`), `imageCount` (from `images`), `hasArticle` (from the article item), `childCount` (from the nested Map's Nodes). A derived field is written only inside the transaction that writes its source.
- **All multi-item writes with invariants are `TransactWriteItems`** — first-login provisioning, node/link/view create and delete, article attach, gallery changes, excerpt-changing body edits. Counters (`nodeCount` on the Map, `linkCount` on a View) live beside the items they cap so a cap is a condition on the same transaction.

### D2 — Constant keys for listings, and no Scan

- **Rule:** every read is a `GetItem`, `BatchGetItem` or `Query` on a key derivable from the request or from a constant. **The application never scans.** This is enforced, not just intended: the Lambda's IAM policy omits `dynamodb:Scan`. A future need to enumerate something gets a key design, not a scan.
- **Constant-key collections are allowed, on one condition: they hold immutable pointers only.** The first is **`PK = MAP#ALL`, `SK = MAP#{rootMapId}`**, written in the first-login/new-Map transaction and carrying only `ownerSub` and `createdAt`. It gives "list every Map" (admin, a future public gallery or landing-page showcase) as a paginated `Query` on a known key. Because the item is immutable, the hot-key concern is limited to creates and deletes, and no second copy of the Map name exists (CON-6) — names are always read from `META`, batched across partitions. No v1 endpoint reads the directory; it exists so the capability needs no migration.
- **What would change this:** if a listing must be filtered (e.g. by visibility), the answer is a sparse GSI on `META`, not adding mutable attributes to `MAP#ALL` — this happened once visibility was specified; see the 2026-09-19 amendment (D3) below. If `MAP#ALL` traffic ever approached a partition's limits, the key is sharded (`MAP#ALL#{n}`) — neither is v1.
- **No local secondary index, ever**, so no 10 GB item-collection cap applies to any partition.

## Consequences and limitations

- **The latency benefit is an inference, not a measurement.** A single-item read's latency does not scale meaningfully with size at these sizes. What the split reliably buys is a bounded Map-load payload across the Lambda → API Gateway → browser path, less JSON parsing and Lambda memory, cheaper read units (a Map load costs roughly a tile's bytes, not a node's), and a much cheaper drag. Do not claim a specific latency figure; measure it on the dev table (AW-24's `dev` environment exists for this) once the endpoints exist.
- **Opening a node is a second request** that the fat-item layout would not need. It is the deliberate trade: pay it only when a node is actually opened, instead of on every Map open for every node.
- **Transactions cost twice the write units** and are the only atomic path across items. At this app's volume that is negligible in money terms; it is why a plain `UpdateItem` is used wherever a write touches one item (drags, title/size/cover edits, note/url edits, renames).
- **Derived fields are a discipline, not a guarantee.** They stay correct only if no write path bypasses the maintaining transaction. Each needs a test, and the repository layer is the single place allowed to write them.
- **More items per node.** Cascade delete removes tile, `DETAIL`, `ARTICLE`, its Links, and — for a group — the nested partition; it is not atomic above 100 items (delete the tile first so the subtree becomes unreachable, then clean up). Export to JSON (#23) joins tile and detail.
- **`moto` fidelity risk (TS-5) applies to the transaction paths in particular.** Supplement with a few hand-run checks on the real dev table for provisioning, node create, link create and cascade delete.
- **Field caps are now schema constants.** The tile caps (title, date, excerpt, preview) are what bound the Map load; raising the 50-node cap or a tile cap re-opens the worst-case arithmetic in criterion A.
- **`MAP#ALL` is built but unused in v1.** That is a deliberate, small carrying cost (one extra item per Map) in exchange for not needing a backfill later; revisit if it is still unread when visibility is decided.
- **Re-evaluate if** the per-Map node cap rises substantially, if a tile field grows large enough to threaten the Map-load bound, or if measured Map-load payloads show the split is not paying for itself.

## Amendment (2026-09-19): visibility and the public gallery (D3)

**Trigger:** `DOC/specs/map-visibility.md` (three visibilities — `private`, `unlisted`, `public` — default `private`; a public gallery; anonymous read of unlisted/public Maps). This is the "filtering a listing → sparse GSI" case D2 anticipated, now real. It supersedes the earlier "no GSI in v1": there is exactly one, sparse, GSI.

**Gallery options considered** (each judged against `map-visibility.md` CON-7/CON-9/CON-10):
- **Query `MAP#ALL` and filter by visibility.** Rejected: every page evaluates (and is billed for) all Maps, public or not; a page of 100 entries may hold three public ones, so paging is wasteful and unpredictable, and it needs a mutable visibility copy on the directory item, breaking D2's immutable-pointer rule.
- **Wildcard membership items (`USER#PUBLIC` / `MEMBER#{mapId}`).** Rejected: makes visibility implicit (its state is the presence of another item), cannot express `unlisted` without a second wildcard, and conflates membership with visibility (`map-visibility.md` CON-3).
- **A scan.** Forbidden by D2.
- **A sparse GSI on the Map's META with a constant partition key** — chosen.

**D3 — the layout**
- The **root** Map's META gains `visibility` (`private | unlisted | public`, always present, default `private`). A nested Map's META never carries it (`map-visibility.md` CON-2); the Map's own Query returns it, so the UI gets it for free (CON-11).
- **`GSI1`**, sparse: `GSI1PK = "MAP#PUBLIC"` (a constant key — the owner's dummy-key idea, applied where it earns its keep) and `GSI1SK = {publishedAt}#{mapId}`. These two attributes exist on a META **only while it is `public`**; DynamoDB maintains the index, so there is no second write and no drift. The index projects `name` (a projection is maintained by DynamoDB, not a hand-kept copy, so `accounts-and-auth.md` CON-6 still holds). The gallery is a paginated descending `Query` on `MAP#PUBLIC`, newest-published first.
- **Changing visibility is one `UpdateItem` on the root META** (CON-10): to `public` it sets `visibility`, `publishedAt`, `GSI1PK`, `GSI1SK`; leaving `public` it removes the last three. It must reject a nested Map.
- **Read authorization order** (CON-9): from any request id take the first dot segment (the root Map id) → `GetItem` on its META with a **consistent read** → if `visibility` is `unlisted` or `public`, allow; if `private`, an authenticated caller needs a membership (`GetItem`, as AP-4) → otherwise answer 404 (CON-6) → only then run the Map or content `Query`. A refused read costs one or two single-item reads, never a Map load. Writes keep the membership-only path (CON-4).
- **`MAP#ALL` is unchanged from D2** (immutable pointer directory, unread in v1) but no longer serves any v1 use case — the gallery runs off `GSI1`. It is kept as the ops-side list of every Map, private ones included; drop it if it is still unused when the gallery ships.

**Consequences**
- **The gallery is eventually consistent** (a GSI cannot be read consistently): after a Map is made non-public its name can linger in the listing for moments. Opening it re-checks META consistently, so nothing beyond the name is exposed in that window, matching `map-visibility.md`'s revocation rule. Any edge cache put in front of the gallery must keep a TTL in the same "brief" range.
- **One extra single-item read per read request** (the visibility check). That is the price of never loading a private Map for an unauthorized caller.
- **Write amplification is confined to public Maps:** a rename or visibility change on a public Map also writes the index entry. Non-public Maps pay nothing.
- **A constant GSI partition key concentrates the gallery's writes and reads on one key.** Writes happen only on publish, unpublish and rename of a public Map; reads are paged and cacheable. At v1 volume this is far below a partition's limits; if it ever were not, shard the constant (`MAP#PUBLIC#{n}`).
- **`moto`'s GSI-pagination gap (GitHub #7725) is exactly the risk ADR-003 / TS-5 name, and this is the first GSI it applies to.** The gallery's paging and ordering must be verified against the real dev table, not only against `moto`.
- **Infrastructure:** the table needs the GSI, and the Lambda's IAM policy must allow `Query` on the index ARN as well as the table; `Scan` stays excluded.
