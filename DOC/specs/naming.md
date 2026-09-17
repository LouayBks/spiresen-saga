# Spec: Naming & framing (#31)

Format per `DOC/templates/spec_design_template.md` (ADR-006). Reconciles the app's public/internal terminology and removes the stale `HANDOFF.md` pointer, before the other Stage-A specs (`box-sizing.md`, `content-authoring.md`, `alternate-views.md`) harden a term that has to be unwound later — this spec is a dependency of those three, not overlapping content with them (it settles words; they settle behavior/schema).

## Objective

Settle which name is used where (Athar / Saga / Boxes), broaden the product's framing beyond "recruiter portfolio," and retire the dead `HANDOFF.md` pointer — before any UI copy or schema-facing doc locks in inconsistent language.

## Context

- Ticket: #31.
- Updates once accepted: `application_architecture.md`'s "Naming" section and `HANDOFF.md` reference; `boxes-plan.md`'s framing (§1) and any UI copy strings (`boxes-mockup.html`'s nav/eyebrow text) that hardcode "Saga."
- `application_architecture.md` already settled **Athar** as the subdomain/product name and **Saga** as the entity name kept "in code/schema" — this spec extends that into an explicit public-copy rule, since the existing text never said whether "Saga" itself may appear in UI strings.

## Decisions

- **Athar** is the product/brand name — used in marketing copy, the landing page (#41), and anywhere the app refers to itself as a whole.
- **Saga** stays an internal/schema term (`PK: USER#id / SK: SAGA#id`, code identifiers, ADRs, this repo's docs) and does **not** appear verbatim in user-facing UI copy. The mockup's own nav label ("Sagas — different stories, same boxes") and eyebrow text already reach for "story" as the natural human word for the concept — see Open questions below for the exact replacement word, which is a copy/taste call, not a structural one.
- **Boxes** stays the name of the canvas feature itself (distinct from the Athar product name) — it already carries its own tagline ("Don't just put me in a box") and is used consistently across `boxes-plan.md`/the mockup; renaming it would cost that identity for no structural gain.
- **Framing** broadens from "recruiter portfolio" to "a canvas for visualizing pedagogic material or topics" generally — a recruiter-facing arrangement becomes one example Saga among others (the mockup's existing sample data needs no change; only marketing/README-level framing text does).
- `HANDOFF.md` is retired as a **dead reference**, not recreated: it was the one-time Claude Cowork → Claude Code phase handoff, not a living task list. `application_architecture.md`'s pointer to it is removed and replaced with a one-line historical note.

## Expected behaviors (`BHV-*`)

| ID | Statement | Testability check | Notes |
|---|---|---|---|
| BHV-1 | WHERE UI copy names the app as a whole, THE frontend SHALL display "Athar," not "Saga" or "Boxes" alone. | ✅ — snapshot/text-content assertion on the landing page and nav brand strings | Applies to the landing page (#41) and the topbar brand mark. |
| BHV-2 | THE frontend SHALL NOT render the literal word "Saga" in any user-facing string (nav, labels, empty states, tooltips). | ✅ — a lint/test scanning compiled UI strings (or a Playwright text-content check across the nav panel and topbar) for the literal substring | Internal code identifiers, DynamoDB keys, and this repo's own docs are exempt — this row governs rendered UI text only. |
| BHV-3 | WHEN a visitor opens the hidden nav panel, THE UI SHALL label the Saga-switcher section with the replacement word settled in Open questions, not "Saga." | ⚠️ needs the replacement word settled first (see Open questions) — once picked, a single text-content assertion covers it | Directly supersedes the mockup's `navlabel` text ("Sagas — different stories, same boxes"). |

## Constraints (`CON-*`)

| ID | Statement | Notes |
|---|---|---|
| CON-1 | Code identifiers, DynamoDB key names, API field names, and internal docs MUST keep using "Saga" — this spec does not rename the entity. | No schema change; `application_architecture.md`'s existing "Sagas: multi-tenancy" section is unaffected. |
| CON-2 | The subdomain and product-facing brand name MUST remain "Athar" (`athar.spiresen.com` / `int.athar.spiresen.com` / `dev.athar.spiresen.com`) — already settled, restated here so this spec doesn't silently contradict it. | Carries forward `application_architecture.md`'s existing decision, doesn't reopen it. |
| CON-3 | The UI feature name "Boxes" MUST NOT be renamed as part of this pass. | Answers ticket #31's "confirm whether Boxes stays as-is" task directly: yes. |
| CON-4 | `application_architecture.md` MUST NOT reference `HANDOFF.md` as a file to be created or maintained — only, if mentioned at all, as deprecated history. | Resolves the stale pointer named in ticket #31's context. |
| CON-5 | Marketing/framing copy (landing page, README, `boxes-plan.md` §1) MUST present the product as a general tool for visualizing pedagogic material or topics, not exclusively a recruiter-facing CV substitute. | The sample "For recruiters" Saga in the mockup stays as one example dataset — this constrains framing copy, not sample data. |

## Open questions

- **Exact public-facing replacement word for "Saga"** (BHV-3) — candidates on the table: "Story," "Space," "Collection." The mockup's own copy already leans toward "story" colloquially ("different stories about myself"), but "Story" reads oddly doubled against a Saga that itself might contain `media` boxes labeled "Article"/"Video" — this is a brand-voice call, not a structural one, and is left to you rather than picked here.
- Whether "Boxes" itself ever needs a tagline update once the framing broadens past recruiters (e.g., does "Don't just put me in a box" still land for a pedagogic-visualization framing?) — flagged, not decided; low urgency since it doesn't block any other Stage-A spec.

## Out of scope

No code changes. No decision on the landing page's actual content (#41) or account-flow copy (#35/accounts spec) beyond the naming rules above — those tickets inherit this spec's terminology, they don't redecide it.
