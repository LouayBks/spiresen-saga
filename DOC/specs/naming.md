# Spec: Naming & framing (#31)

Format per `DOC/templates/spec_design_template.md` (ADR-006). Reconciles the app's public/internal terminology, before the other Stage-A specs (`box-sizing.md`, `content-authoring.md`, `alternate-views.md` — filenames kept as topic labels tied to their ticket numbers, not renamed to match the entity term below) harden a term that has to be unwound later — this spec is a dependency of those three, not overlapping content with them (it settles words; they settle behavior/domain model). All three have been updated to match this revision's rename (see their own diffs).

**Revision note (2026-09-18, part 1):** this spec inverts its own first-draft naming. The first draft kept "Saga" as the internal/schema term and "Athar" as the public brand. That's now reversed: **Athar is dropped** (already in use elsewhere, so it's off the table, not a live candidate), and **the public brand reverts to "Saga," including domain names** — but only for now, since a brand name has already had to move once. Because of that instability, the *data model* is deliberately decoupled from whatever the current brand word is: the entity schema uses an agnostic term (**Map**), not "Saga," so a future brand change again doesn't force a second schema migration. Two of the first draft's open questions (the exact UI replacement word for "Saga," and whether the tagline needs revisiting) are dropped as non-binding — the mockup's own copy was never authoritative, not worth debating.

**Revision note (2026-09-18, part 2):** the individual canvas item, called "Box" throughout the first two drafts, is renamed **Node**. And the UI/marketing feature name ("Boxes") is dropped from this spec's scope entirely — it's a minor branding detail, not an architecture-level naming decision this spec needs to settle one way or the other.

**Amendment (2026-09-18, `ADR-006`):** this spec originally included a "Schema rename" table asserting literal `PK`/`SK` patterns (old and new), including one row inventing a `View` key pattern that belonged to `alternate-views.md`, not here. `ADR-006`'s amendment retroactively rules physical key/item shape out of a spec's scope. The word-level rename decision below is unchanged — every occurrence of "Saga" as an entity term becomes "Map," every occurrence of "Box" becomes "Node" — but the literal old/new key-string table is removed: `#36` (Data foundation) decides the actual key shape realizing this rename, consistent with whatever word-choice constraints CON-1/CON-3 below still bind it to.

## Objective

Settle which name is used where (product brand vs. schema entities), and broaden the product's framing beyond "recruiter portfolio" — before any UI copy or schema-facing doc locks in inconsistent language.

## Context

- Ticket: #31.
- Updates once accepted: `application_architecture.md`'s "Naming" section; `boxes-plan.md`'s framing (§1) and data-model references; domain/DNS/ACM/CloudFront config (`infra/environments/*`) — flagged separately below since that's infra work, not a doc change, and out of this ticket's scope (tracked as #42, deferred until the first features ship). The schema section's actual key/id occurrences are `#36`'s to rename when it decides the physical shape — this spec only fixes which word ("Map"/"Node") that shape must use, per CON-1/CON-3.

## Naming table — all identified elements

| Element | Old name | New name | Scope |
|---|---|---|---|
| Product/brand | Athar | **Saga** (temporary — see CON-2) | Public-facing: marketing copy, landing page, domain names, site title. |
| Top-level per-user collection (entity) | Saga | **Map** | Schema/code/API: entity/class name, id namespacing, and (per CON-4) UI copy that names an individual collection — "a Map," "Your Maps." The DynamoDB key shape carrying this word is `#36`'s decision. |
| Individual canvas item (entity) | Box | **Node** | Schema/code/API: entity/class name, id namespacing, all field names (`size`, `note`, `urls`, `positions`, …). `kind` is not in this list — retired as a stored field entirely, see the row below. The DynamoDB key shape carrying this word is `#36`'s decision. |
| Link | Link | Link (unchanged) | |
| View (≤3 per Map, `alternate-views.md`) | View | View (unchanged) | |
| Node kinds | `note` / `media` / `group` | **retired as a stored field** — presentation is now inferred dynamically from a node's contents; see `content-authoring.md`'s dynamic-visualization rules | Not a rename — a real model change (2026-09-18), not just terminology. Info/gallery/article/map survive only as *visualization states*, not a `kind` column. (An `annotation`/lightweight state was proposed and dropped — deferred to the backlog as #46, not part of this model.) |
| Link types | `theme` / `timeline` / `soft` | unchanged | |

## Terminology rename (for `application_architecture.md` and the other specs)

Word-level only — no key/item shape asserted here, that's `#36`'s decision:

| Old term | New term | Applies wherever the old term appeared |
|---|---|---|
| Saga (as an entity/schema term) | Map | Entity/class names, DynamoDB key prefixes, id-namespacing scheme, content records' owning-collection attribute (`application_architecture.md`'s "Content records need to carry their Saga too") — every one of these keeps whatever physical shape it already had or `#36` gives it; only the word changes. |
| Box | Node | Same scope as above. |

**Id namespacing keeps its existing shape, only the words in it change:** a box-id like `{sagaId}.{shortId}` becomes a node-id like `{mapId}.{shortId}` — same dot-path structure, `application_architecture.md`'s existing convention, renamed words only.

## Decisions

- **Saga** is the product/brand name, reinstated in place of Athar (Athar is dropped as already in use elsewhere) — used in marketing copy, the landing page (#41), domain names, and anywhere the app refers to itself as a whole. Stated as *temporary, for now*: exactly the instability that motivates decoupling the schema from it (below).
- **Map** is the schema/entity term for what was called "Saga" as a data entity — a user's named collection of Nodes. Used in code identifiers, API field names, id namespacing, and (per CON-4) as the countable UI noun for an individual collection, independent of whatever the current product brand word is. Whatever DynamoDB key shape `#36` gives it, that shape's words follow this rename.
- **Node** is the schema/entity term for what was called "Box" — the individual item placed on the canvas (a note, a media item, a group). Used the same way Map is: code identifiers, API field names, id namespacing.
- The UI/marketing feature name ("Boxes," the mockup's own branding) is **out of this spec's scope** — a minor detail, not redecided here in either direction.
- **Framing** broadens from "recruiter portfolio" to "a canvas for visualizing pedagogic material or topics" generally — a recruiter-facing arrangement becomes one example Map among others (the mockup's existing sample data needs no change; only marketing/README-level framing text does).
- **Exact mockup copy (nav label wording, tagline) is explicitly non-binding** — the mockup's specific phrases were drafting scaffolding, not requirements; this spec settles the structural naming, not the exact prose. No further debate tracked on this.

## Expected behaviors (`BHV-*`)

| ID | Statement | Testability check | Notes |
|---|---|---|---|
| BHV-1 | WHERE UI copy names the app as a whole (site title, landing page, topbar brand mark), THE frontend SHALL display "Saga," not "Athar." | ✅ — snapshot/text-content assertion on the landing page and topbar brand mark | Doesn't constrain the UI feature-name copy (e.g. "Boxes") — out of this spec's scope. |
| BHV-2 | WHEN the nav panel lists a user's collections, THE UI SHALL refer to each individually as a "Map" (e.g. a "Your Maps" section), not as "a Saga." | ✅ — text-content assertion on the nav panel's collection-switcher section | Exact copy wording is non-binding (see Decisions) — this row checks the noun used, not the phrasing around it. |

## Constraints (`CON-*`)

| ID | Statement | Notes |
|---|---|---|
| CON-1 | Code identifiers, entity/class names, and API field names for the top-level per-user collection MUST use the word "Map," MUST NOT use "Saga." | Reverses the first draft's CON-1. Binding on whatever key/id shape `#36` decides — the word, not the physical shape, is this spec's call. See Terminology rename table above. |
| CON-2 | The product/brand name MUST be "Saga," including domain names — reversing the prior "Athar" decision. Actually changing `athar.spiresen.com` → a Saga-based domain is an **infra change (DNS/ACM/CloudFront), not a doc change**, and is out of this docs-only ticket's scope — tracked separately as #42, **deferred until the first features ship**, not immediate follow-up work. | Athar is dropped as a candidate entirely (already in use elsewhere), not merely deprioritized. |
| CON-3 | Code identifiers, entity/class names, and API field names for the individual canvas item MUST use the word "Node," MUST NOT use "Box." | Same as CON-1, for the other renamed entity. See Terminology rename table above. |
| CON-4 | UI copy referring to an individual collection MUST use "Map," MUST NOT use "Saga" as a countable/per-item noun — "Saga" is reserved for the product name only, never pluralized or used as "a Saga." | Prevents the exact ambiguity the first draft had (one word serving as both brand and entity name). |
| CON-5 | Marketing/framing copy (landing page, README, `boxes-plan.md` §1) MUST present the product as a general tool for visualizing pedagogic material or topics, not exclusively a recruiter-facing CV substitute. | The sample "For recruiters" Map in the mockup stays as one example dataset — this constrains framing copy, not sample data. |

## Open questions

None — both open questions from the first draft (exact UI replacement word, tagline revisit) are explicitly dropped as non-binding, per your direction. The UI feature name ("Boxes") is not an open question either — it's explicitly out of scope, not unresolved.

## Out of scope

No code changes. **The actual domain migration (`athar.spiresen.com` → a Saga-based domain, #42) is explicitly out of scope here and deferred until the first features ship** — it's infra work (Route 53 records, ACM cert SANs, CloudFront aliases, `infra/environments/{prod,int,dev}` Terraform, `.github/workflows/*-deploy*.yml` target hostnames), requires human execution per `branching_strategy.md` AW-24 (Claude never applies infra). **The UI/marketing feature name ("Boxes") is out of scope** — not decided, not redecided, a minor detail left alone. No decision on the landing page's actual content (#41) or account-flow copy (#35/accounts spec) beyond the naming rules above — those tickets inherit this spec's terminology, they don't redecide it.
