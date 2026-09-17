# Spec: Naming & framing (#31)

Format per `DOC/templates/spec_design_template.md` (ADR-006). Reconciles the app's public/internal terminology and removes the stale `HANDOFF.md` pointer, before the other Stage-A specs (`box-sizing.md`, `content-authoring.md`, `alternate-views.md`) harden a term that has to be unwound later — this spec is a dependency of those three, not overlapping content with them (it settles words; they settle behavior/schema). All three have been updated to match this revision's rename (see their own diffs).

**Revision note (2026-09-18):** this spec inverts its own first-draft naming. The first draft kept "Saga" as the internal/schema term and "Athar" as the public brand. That's now reversed: **Athar is dropped** (already in use elsewhere, so it's off the table, not a live candidate), and **the public brand reverts to "Saga," including domain names** — but only for now, since a brand name has already had to move once. Because of that instability, the *data model* is deliberately decoupled from whatever the current brand word is: the entity schema uses an agnostic term (**Map**), not "Saga," so a future brand change again doesn't force a second schema migration. Two of the first draft's open questions (the exact UI replacement word for "Saga," and whether the tagline needs revisiting) are dropped as non-binding — the mockup's own copy was never authoritative, not worth debating.

## Objective

Settle which name is used where (product brand vs. schema entity vs. UI feature name), broaden the product's framing beyond "recruiter portfolio," and retire the dead `HANDOFF.md` pointer — before any UI copy or schema-facing doc locks in inconsistent language.

## Context

- Ticket: #31.
- Updates once accepted: `application_architecture.md`'s "Naming" section, schema section (every `SAGA#`/`{sagaId}` occurrence), and `HANDOFF.md` reference; `boxes-plan.md`'s framing (§1) and data-model references; domain/DNS/ACM/CloudFront config (`infra/environments/*`) — flagged separately below since that's infra work, not a doc change, and out of this ticket's scope.

## Naming table — all identified elements

| Element | Old name | New name | Scope |
|---|---|---|---|
| Product/brand | Athar | **Saga** (temporary — see CON-2) | Public-facing: marketing copy, landing page, domain names, site title. |
| Top-level per-user collection (entity) | Saga | **Map** | Schema/code/API: DynamoDB key prefix, box-id namespacing, and (per CON-4) UI copy that names an individual collection — "a Map," "Your Maps." |
| Box | Box | Box (unchanged) | Already agnostic, already the feature's own identity — not brand-coupled. |
| Link | Link | Link (unchanged) | |
| View (≤3 per Map, `alternate-views.md`) | View | View (unchanged) | |
| Box kinds | `note` / `media` / `group` | unchanged | Content-type descriptors, not brand terms. |
| Link types | `theme` / `timeline` / `soft` | unchanged | |
| Feature/UI name | Boxes | Boxes (unchanged) | The canvas feature's own identity, independent of whatever the product brand is. |

## Schema rename (for `application_architecture.md` and the other three specs)

| Old | New |
|---|---|
| `PK: USER#{userId} SK: SAGA#{sagaId}` | `PK: USER#{userId} SK: MAP#{mapId}` |
| `PK: SAGA#{sagaId} SK: BOX#{boxId}` | `PK: MAP#{mapId} SK: BOX#{boxId}` |
| `PK: SAGA#{sagaId} SK: LINK#{viewId}#{boxA}#{boxB}` | `PK: MAP#{mapId} SK: LINK#{viewId}#{boxA}#{boxB}` |
| *(new in `alternate-views.md`, not yet given an explicit key)* | `PK: MAP#{mapId} SK: VIEW#{viewId} -> {name, order?}` |
| Box-id namespacing `{sagaId}.{shortId}` | `{mapId}.{shortId}` |
| Content record's `sagaId` attribute (`application_architecture.md`'s "Content records need to carry their Saga too") | `mapId` attribute |

## Decisions

- **Saga** is the product/brand name, reinstated in place of Athar (Athar is dropped as already in use elsewhere) — used in marketing copy, the landing page (#41), domain names, and anywhere the app refers to itself as a whole. Stated as *temporary, for now*: exactly the instability that motivates decoupling the schema from it (below).
- **Map** is the schema/entity term for what was called "Saga" as a data entity — a user's named collection of boxes. Used in code identifiers, DynamoDB key names, API field names, box-id namespacing, and (per CON-4) as the countable UI noun for an individual collection, independent of whatever the current product brand word is.
- **Boxes** stays the name of the canvas feature itself — unaffected by either rename; it already carries its own tagline and identity, coupled to neither Athar nor Saga.
- **Framing** broadens from "recruiter portfolio" to "a canvas for visualizing pedagogic material or topics" generally — a recruiter-facing arrangement becomes one example Map among others (the mockup's existing sample data needs no change; only marketing/README-level framing text does).
- `HANDOFF.md` is retired as a **dead reference**, not recreated: it was the one-time Claude Cowork → Claude Code phase handoff, not a living task list. `application_architecture.md`'s pointer to it is removed and replaced with a one-line historical note. Unaffected by this revision.
- **Exact mockup copy (nav label wording, tagline) is explicitly non-binding** — the mockup's specific phrases were drafting scaffolding, not requirements; this spec settles the structural naming, not the exact prose. No further debate tracked on this.

## Expected behaviors (`BHV-*`)

| ID | Statement | Testability check | Notes |
|---|---|---|---|
| BHV-1 | WHERE UI copy names the app as a whole (site title, landing page, topbar brand mark), THE frontend SHALL display "Saga," not "Athar" or "Boxes" alone. | ✅ — snapshot/text-content assertion on the landing page and topbar brand mark | |
| BHV-2 | WHEN the nav panel lists a user's collections, THE UI SHALL refer to each individually as a "Map" (e.g. a "Your Maps" section), not as "a Saga." | ✅ — text-content assertion on the nav panel's collection-switcher section | Exact copy wording is non-binding (see Decisions) — this row checks the noun used, not the phrasing around it. |

## Constraints (`CON-*`)

| ID | Statement | Notes |
|---|---|---|
| CON-1 | DynamoDB key names, code identifiers, and API field names for the top-level per-user collection MUST use "Map"/`MAP#`, MUST NOT use "Saga"/`SAGA#`. | Reverses the first draft's CON-1. See Schema rename table above for every affected key pattern. |
| CON-2 | The product/brand name MUST be "Saga," including domain names — reversing the prior "Athar" decision. Actually changing `athar.spiresen.com` → a Saga-based domain is an **infra change (DNS/ACM/CloudFront), not a doc change**, and is out of this docs-only ticket's scope — tracked as a separate follow-up ticket (see Out of scope). | Athar is dropped as a candidate entirely (already in use elsewhere), not merely deprioritized. |
| CON-3 | The UI feature name "Boxes" MUST NOT be renamed as part of this pass. | Unaffected by the revision — answers ticket #31's "confirm whether Boxes stays as-is" task: yes. |
| CON-4 | UI copy referring to an individual collection MUST use "Map," MUST NOT use "Saga" as a countable/per-item noun — "Saga" is reserved for the product name only, never pluralized or used as "a Saga." | Prevents the exact ambiguity the first draft had (one word serving as both brand and entity name). |
| CON-5 | `application_architecture.md` MUST NOT reference `HANDOFF.md` as a file to be created or maintained — only, if mentioned at all, as deprecated history. | Resolves the stale pointer named in ticket #31's context; unaffected by the rename. |
| CON-6 | Marketing/framing copy (landing page, README, `boxes-plan.md` §1) MUST present the product as a general tool for visualizing pedagogic material or topics, not exclusively a recruiter-facing CV substitute. | The sample "For recruiters" Map in the mockup stays as one example dataset — this constrains framing copy, not sample data. |

## Open questions

None — both open questions from the first draft (exact UI replacement word, tagline revisit) are explicitly dropped as non-binding, per your direction.

## Out of scope

No code changes. **The actual domain migration (`athar.spiresen.com` → a Saga-based domain) is explicitly out of scope here** — it's infra work (Route 53 records, ACM cert SANs, CloudFront aliases, `infra/environments/{prod,int,dev}` Terraform, `.github/workflows/*-deploy*.yml` target hostnames), requires human execution per `branching_strategy.md` AW-24 (Claude never applies infra), and deserves its own ticket rather than riding along inside a docs-only naming pass. No decision on the landing page's actual content (#41) or account-flow copy (#35/accounts spec) beyond the naming rules above — those tickets inherit this spec's terminology, they don't redecide it.
