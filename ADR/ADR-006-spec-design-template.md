# ADR-006: Spec design template — behavior/constraint format for pre-implementation specs

**Status:** Accepted. The concrete artifact is `DOC/templates/spec_design_template.md`, updated to match this decision once accepted.
**Date:** 2026-09-17
**Scope:** this ADR decides the *format* a domain-model design spec uses to state expected behaviors and constraints before implementation starts (Stage A of the Boxes/Athar backlog, issue #22 — tickets #31–#35) — not the content of any individual spec (that's each Stage-A ticket's own deliverable), and not the implementation-planning process itself (`plan_template.md`/AW-1..AW-6 already own that, unchanged by this decision).

## Context and objective

`spec_design_template.md` was drafted ahead of this ADR, adopting EARS (Easy Approach to Requirements Syntax) for expected-behavior rows and RFC 2119 keywords for constraint rows, with an inline rationale. That's out of step with how every other recurring rule-set in this repo was actually decided — `ADR-002` → `clean_code_rules.md`, `ADR-003` → `testing_strategy.md`, `ADR-004` → `agentic_workflow_processes.md` each went through a scored comparison against real alternatives, backed by a `*_research.md` file, before the concrete rules doc was written. This ADR closes that gap retroactively: it either confirms the format already drafted, on the record, or changes it.

Evidence backing this decision lives in `DOC/research/spec_design_finops.md` and is cited by reference below, not reproduced here. Its headline finding, load-bearing for several criteria: **ambiguity in a requirement measurably degrades LLM code-generation correctness (Tier 1, multiple studies), and resolving that ambiguity with structure *up front* is more token-efficient than resolving it conversationally after a bad generation (also Tier 1) — but no study measures EARS specifically against other structured formats, and no study measures the second-order claim ("better specs → fewer agent rework tokens") for coding agents at all.** Several criteria below score options against that honestly-graded evidence rather than against unverified claims a lot of 2026 spec-driven-development commentary makes about the same topic.

Objective: decide which requirement-writing format the spec design template should use for `BHV-*` (behavior) and `CON-*` (constraint) rows, balancing measured/adoption evidence against setup burden and fit with this repo's existing documentation conventions — not to draft any Stage-A spec itself (that follows once this is settled).

## Decision drivers (criteria)

| ID | Criterion | Question it answers | Source |
|---|---|---|---|
| A | Ambiguity/correctness impact | Is there real evidence this format's structure reduces the kind of requirement ambiguity shown to degrade LLM code-gen correctness? | Orchid benchmark, ClarifyGPT, structured-prompting study — `spec_design_finops.md` Tier 1 |
| B | Token/authoring efficiency | Does paying the structuring cost once, up front, measurably cost less than resolving the same ambiguity conversationally later? | Structured-prompting study (checklist: +32% quality, −29% tokens vs. raw prompt) — `spec_design_finops.md` Tier 1 |
| C | Testability | Does the format's own structure push every row toward "verifiable by one unambiguous test," or does that depend entirely on author discipline? | EARS-in-PLC empirical study (completeness was the top residual issue) + Orchid's vagueness category — `spec_design_finops.md` Tier 2/1 |
| D | Adoption in AI-agent-specific spec tooling | Is this the format real spec-driven-development tools for coding agents already converge on, or is it convergence from an unrelated lineage (human-team BDD, traditional RE)? | AWS Kiro, GitHub Spec Kit both use EARS-shaped acceptance criteria — verified adoption fact, `spec_design_finops.md` |
| E | Behavior/constraint coverage | Does the format cleanly separate a trigger→response behavior from a standing boundary condition, or does everything collapse into one undifferentiated list? | Format inspection (EARS vs. RFC 2119 vs. each alternative's native vocabulary) |
| F | Setup/maintenance burden | How much syntax has to be learned and kept consistent, given this project's scale (a handful of Stage-A specs, not an enterprise RE program)? | Reasoned judgment, same as ADR-002 criterion F |
| G | Consistency with existing repo convention | Does it fit the `ID \| Rule \| Notes` table pattern already used for `CC-*`/`TS-*`/`AW-*`, or does it introduce a third documentation dialect? | `clean_code_rules.md`, `testing_strategy.md`, `agentic_workflow_processes.md` |

## Considered options

1. **EARS (behaviors) + RFC 2119 (constraints)** — the format already drafted in `spec_design_template.md`: five fixed EARS sentence shapes for `BHV-*`, RFC 2119 modal keywords for `CON-*`.
2. **Gherkin/BDD (Given/When/Then)** — scenario-per-requirement, designed to double as an executable test spec via a BDD runner (Cucumber, pytest-bdd).
3. **Formal SRS (IEEE 29148 / Volere requirements shell)** — comprehensive requirements-engineering standards: stakeholders, rationale, fit criteria, functional/non-functional split, per requirement.
4. **Generic structured checklist, no fixed grammar** — the actual format the structured-prompting study measured (not EARS): a plain checklist of requirement statements with no imposed sentence template.
5. **Baseline: freeform prose ticket description** — the status quo before this template existed (a plain issue body, as #2/#3 originally were). Included as the zero-cost comparison point, not a serious candidate.

## Evaluation

Scores use a 1–3 scale (1 = Weak, 2 = Moderate, 3 = Strong; N/A where a criterion doesn't apply).

### Option 1 — EARS + RFC 2119

| A | B | C | D | E | F | G |
|---|---|---|---|---|---|---|
| 2 | 2 | 2 | 3 | 3 | 2 | 3 |

Contested points:
- **A and B are 2, not 3** — this is the honesty correction the research forced: EARS operationalizes the validated general principle (fixed trigger+response shapes remove ambiguity by construction; structure-up-front beats conversational resolution), but no study isolates EARS itself as the vehicle for that benefit. Scoring these 3 would repeat the overclaim `spec_design_finops.md` flagged in the template's own original rationale.
- **C is 2, its real weakness before this ADR's fix** — EARS's grammar forces a trigger and a response onto the page, but doesn't guarantee the response is *specific* enough to verify with one test; the EARS-in-PLC study's own finding (completeness, not ambiguity, was the top issue encountered) lands directly on this gap.
- **D is 3** — the strongest, most directly relevant evidence of any criterion for any option: this is what real AI-agent spec-driven-development tooling (Kiro, Spec Kit) already does, for the same "spec before code, consumed by an agent" use case this project is in.
- **E is 3** — the explicit two-vocabulary split (EARS for behavior, RFC 2119 for constraints) is designed specifically to keep a trigger→response statement and a standing boundary condition from collapsing into one undifferentiated bullet list.
- **G is 3** — built to match the `ID | Rule | Notes` table convention already used by `CC-*`/`TS-*`/`AW-*` by construction.

### Option 2 — Gherkin/BDD

| A | B | C | D | E | F | G |
|---|---|---|---|---|---|---|
| 2 | 2 | 3 | 1 | 1 | 1 | 1 |

Contested points:
- **A and B are 2**, same reasoning as option 1 — Given/When/Then also forces an explicit trigger→response structure, so it benefits from the same general (not format-specific) evidence.
- **C is 3, Gherkin's genuine strength** — its entire design point is a 1:1 mapping to an executable scenario; used with a BDD runner, testability isn't just encouraged, it's structural.
- **D is 1** — Gherkin's convergence is from BDD/human-team-collaboration tooling, not the AI-agent-spec lineage the research actually verified (Kiro/Spec Kit use EARS-shaped criteria, not Gherkin).
- **F and G are 1** — this project's testing stack (`testing_strategy.md`: FastAPI `TestClient`, Angular `TestBed`, thin Playwright e2e) has no Cucumber/pytest-bdd runner; adopting Gherkin without one forfeits C's actual advantage while still paying its syntax cost, and per-scenario blocks don't fit the repo's `ID | Rule | Notes` table convention.

### Option 3 — Formal SRS (IEEE 29148 / Volere)

| A | B | C | D | E | F | G |
|---|---|---|---|---|---|---|
| 1 | 1 | 2 | 1 | 3 | 1 | 1 |

Contested points:
- **A, B, D are all 1** — these standards predate LLM code generation entirely; nothing in `spec_design_finops.md` or the broader search touches AI-agent adoption of formal RE standards, and their exhaustive per-requirement authoring (stakeholders, rationale, fit criteria) is the opposite of what the token-efficiency evidence favors (a lean structure, not an exhaustive one).
- **E is 3, its one real strength** — most comprehensive native functional/non-functional split of any option, by design.
- **F and G are 1** — multi-page-per-requirement templates are disproportionate at this project's scale (five Stage-A specs, not an enterprise RE program) and don't fit the repo's lightweight table convention at all.

### Option 4 — Generic structured checklist

| A | B | C | D | E | F | G |
|---|---|---|---|---|---|---|
| 3 | 3 | 1 | 1 | 1 | 3 | 2 |

Contested points:
- **A and B are 3, the strongest scores of any option on these two criteria** — this is the one format with a *direct, measured* result in the evidence (structured-prompting study: +32% quality, −29% tokens vs. raw prompt, beating even a clarifying-question loop), not an inference from a related format the way options 1 and 2 are scored.
- **C is 1** — no fixed grammar means a checklist item can itself be vague ("handle errors gracefully") with nothing structural to stop it; testability depends entirely on author discipline, which is exactly the gap option 1's Testability-check addition (below) closes without this format's tooling cost.
- **D and E are 1** — not the format AI-agent-spec tooling has converged on, and no native behavior/constraint split (a checklist is one flat list unless the author manually sections it — which just reinvents option 1's split with weaker guardrails).
- **F is 3, G is 2** — cheapest to write, no syntax to learn; could sit in an `ID | Item | Notes` table but without EARS's uniform grammar per row.

### Option 5 — Baseline: freeform prose

| A | B | C | D | E | F | G |
|---|---|---|---|---|---|---|
| 1 | 1 | 1 | N/A | 1 | 3 | N/A |

Contested points:
- **A and B are 1, not a neutral absence** — this is literally the "raw prompt" condition the structured-prompting study measured as worst on both quality and token efficiency, same logic ADR-002 applied to its own baseline option.
- **F is 3**, the only reason to include it as the comparison point, not as a serious candidate given what A/B/C cost in return.

## Full comparison table

| ID | EARS + RFC 2119 | Gherkin/BDD | Formal SRS | Structured checklist | Baseline/prose |
|---|---|---|---|---|---|
| A | 2 | 2 | 1 | 3 | 1 |
| B | 2 | 2 | 1 | 3 | 1 |
| C | 2 | 3 | 2 | 1 | 1 |
| D | 3 | 1 | 1 | 1 | N/A |
| E | 3 | 1 | 3 | 1 | 1 |
| F | 2 | 1 | 1 | 3 | 3 |
| G | 3 | 1 | 1 | 2 | N/A |

## Decision

**EARS (behaviors) + RFC 2119 (constraints), confirming the format already drafted in `spec_design_template.md` — with one addition: a Testability check on every `BHV-*` row.** It wins D, E, and G outright, the three criteria that most directly reflect this project's actual situation (an AI-agent-consuming spec, needing both behavior and constraint vocabulary, inside a repo with an established ID-tagged-table convention). It does **not** win A, B, or C outright — the structured-checklist option is honestly better-evidenced on A/B (directly measured, not inferred) and Gherkin is structurally stronger on C (native test-mapping) — but those wins don't survive contact with D/F/G: a checklist has no behavior/constraint split and no fixed grammar to prevent the vagueness that undercuts its own A/B advantage at the row level, and Gherkin's C advantage requires a BDD runner this project's stack doesn't have, so adopting it would pay a real setup cost (F) for an advantage (C) this project can't fully cash in on.

The one real gap — C, testability — is closed directly rather than left as an accepted weakness: **every `BHV-*` row gets an explicit Testability check** ("can this row's SHALL be verified by a single, unambiguous test?"), per `spec_design_finops.md`'s recommendation. This is what a checklist or Gherkin would give structurally; EARS + an explicit testability gate gives the same outcome without adopting either format's downsides (checklist's missing behavior/constraint split, Gherkin's missing runner).

## Consequences and limitations

- **The FinOps/cost framing must be stated as an inference, not a proven claim.** `spec_design_template.md`'s rationale is corrected to say: ambiguity removal is Tier-1 evidenced to help Pass@1 and reduce conflicting generations, and doing that once at spec time is Tier-1 evidenced to be more token-efficient than resolving it conversationally later — for structured requirements *in general* — but no study measures either effect for EARS specifically, or for coding-agent rework tokens specifically. Claiming a specific cost saving from this template is not supported by anything found and shouldn't be asserted.
- **The Testability check is new discipline, not free.** Every `BHV-*` row now needs a second gate ("is this verifiable by one unambiguous test?") checked at spec-writing time, not just at implementation time — a real, if small, per-row cost, justified because it's the cheapest way to close criterion C without changing format entirely (per the decision above).
- **Track it like the rest of this project does.** Since token usage is already logged per session/ticket, the Stage-A spec tickets (#31–#35) are a real, cheap opportunity to observe — not assume — whether specs written to this template correlate with fewer follow-up/rework sessions on the implementation ticket that consumes them. This turns `spec_design_finops.md`'s Tier-3 gap ("not found in literature, for coding agents specifically") into this project's own evidence, the same way `finops-shift-left-slide-content.md` point 6 already did for a different claim.
- **This format is for pre-implementation domain-model specs (Stage A), not a replacement for `plan_template.md`.** A settled spec still needs an ordinary implementation plan once work starts — AW-1's bypass check, AW-4's high-risk review path, and the rest of the dev workflow apply unchanged. `BHV-*`/`CON-*` rows are expected to be citable from that later plan (e.g., as the "Objective" or "Out-of-scope" grounding), not duplicated into it.
- **Re-evaluate if the stack changes.** Option 2 (Gherkin) lost primarily on F/G given this project's *current* testing stack — if a BDD runner is ever adopted for another reason, criterion C's weight relative to D/E/G would need revisiting, not assumed to still favor option 1 by the same margin.

### How the template closes the C gap

`spec_design_template.md`'s table format gains a fourth column on `BHV-*` rows specifically:

| ID | Statement | Testability check | Notes |
|---|---|---|---|
| BHV-1 | WHEN … THE … SHALL … | ✅ / ⚠️ needs a fixture for … | |

`CON-*` rows don't get this column — a constraint is a standing boundary, not a single triggerable scenario, so "verifiable by one test" doesn't map the same way; constraints get verified by whatever tests exercise the behaviors that must respect them, not by a test of their own.
