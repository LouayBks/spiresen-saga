# Spec design template

Used for the domain-model design tickets (Stage A of the Boxes/Athar backlog, issue #22 — #31–#35) and any future ticket that needs to settle *what should happen* and *what must always hold* before implementation starts. A finished spec produces (or updates) the relevant section of `boxes-plan.md` / `application_architecture.md` — this template is the working document that gets there, not a replacement for those source-of-truth files. Once a spec is settled, implementation still goes through the normal `plan_template.md` flow (AW-1 bypass check → Plan Mode) — a spec answers "what", a plan answers "how to build it safely".

## Why this shape, not a bespoke one

Decided in `ADR-006`, scored against Gherkin/BDD, a formal SRS (IEEE 29148/Volere), a generic structured checklist, and freeform prose — see that ADR for the full comparison and evidence grading in `DOC/research/spec_design_finops.md`. Summary, stated at the evidence tier it actually earns rather than overclaimed:

- **Expected behaviors use [EARS](https://alistairmavin.com/ears/) syntax** (Easy Approach to Requirements Syntax) — five fixed sentence shapes (ubiquitous / event-driven / state-driven / optional-feature / unwanted-behavior), each a `SHALL` statement with the trigger and system response made explicit, so there's no ambiguous middle ground for an implementer (or an agent) to interpret. Originated at Rolls-Royce for airworthiness-critical requirements; it's since become the format AI-agent spec-driven-development tools converge on specifically — AWS Kiro's `requirements.md` and GitHub's Spec Kit both use EARS-shaped acceptance criteria (verified adoption fact, `ADR-006` criterion D).
- **Constraints use [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119.html) keywords** (`MUST` / `MUST NOT` / `SHOULD` / `SHOULD NOT` / `MAY`) — the standard IETF/W3C vocabulary for binding vs. advisory requirements. Kept as a separate category from behaviors on purpose: a constraint (e.g. "positions MUST NOT be recomputed on window resize") isn't a trigger→response pair, it's a boundary condition that behaviors have to respect — collapsing both into one flat bullet list loses that distinction.
- **Table format with stable IDs** matches the repo's existing convention (`CC-*`, `TS-*`, `AW-*` in `DOC/architecture/`) rather than introducing a new documentation style. Unlike those fleet-wide rule sets, spec IDs are scoped per file (reset per spec) and prefixed with the spec's slug when cited elsewhere — these are narrower, more numerous, and specific to one design decision, not a standing cross-cutting rule.

**What's actually evidenced vs. inferred (don't overclaim this in a spec or a PR description):** removing requirement ambiguity is Tier-1 evidenced to raise LLM code-gen Pass@1 and reduce conflicting generations, and doing that once up front is Tier-1 evidenced to cost fewer tokens than resolving the same ambiguity conversationally later — but both results are for structured requirements *in general* (a plain checklist, in the actual study), not for EARS specifically, and nothing measures the token/rework cost of ambiguity for coding agents directly. Treat "this template saves tokens" as a reasoned inference, not a proven claim, until this project's own Stage-A tickets (#31–#35) give it real evidence one way or the other — see `ADR-006`'s consequences section for how that's being tracked against the token-usage logs this project already keeps.

## Fields

- **Objective** — one line: what this spec settles and why it needs settling before code (mirrors `plan_template.md`'s conditional "Objective" field).
- **Context** — links to the driving ticket and to the doc section(s) this spec will update once finalized.
- **Expected behaviors (`BHV-*`)** — one row per behavior, in EARS syntax, each with a **Testability check** (per `ADR-006`'s decision, closing EARS's one real weakness — see that ADR's criterion C): can this row's `SHALL` be verified by a single, unambiguous test? If not, the row is too vague or bundles more than one behavior — split it or sharpen the response before moving on.
  - Ubiquitous: `THE <system> SHALL <response>`
  - Event-driven: `WHEN <trigger>, THE <system> SHALL <response>`
  - State-driven: `WHILE <state>, THE <system> SHALL <response>`
  - Optional feature: `WHERE <feature is present>, THE <system> SHALL <response>`
  - Unwanted behavior: `IF <trigger>, THEN THE <system> SHALL <response>`
- **Constraints (`CON-*`)** — one row per constraint, using RFC 2119 keywords, for boundaries that aren't themselves a trigger→response behavior (data-model rules, non-functional limits, explicit non-goals, cost/perf ceilings). No Testability check column — a constraint is a standing boundary, not a single triggerable scenario; it gets verified by whatever tests exercise the behaviors that must respect it, not by a test of its own.
- **Open questions** — anything genuinely unresolved when the spec is drafted (skip, don't leave blank, if none).
- **Out of scope** — explicit list of what this spec does not decide (fixed floor, same discipline as `plan_template.md`).

## Table format

```
| ID    | Statement                                     | Testability check          | Notes |
|-------|------------------------------------------------|-----------------------------|-------|
| BHV-1 | WHEN <trigger>, THE <system> SHALL <response>  | ✅ / ⚠️ needs a fixture for … |       |
| BHV-2 | THE <system> SHALL <response>                  | ✅ / ⚠️ …                    |       |

| ID    | Statement                          | Notes |
|-------|--------------------------------------|-------|
| CON-1 | The <thing> MUST <constraint>        |       |
| CON-2 | The <thing> MUST NOT <constraint>    |       |
```

`<system>` should name the actual component/entity (e.g. "the canvas", "a `Box` write", "the article editor"), not a generic placeholder — genericity is exactly what EARS is meant to remove.

## Where specs live

`DOC/specs/<slug>.md`, one per Stage-A ticket (e.g. `DOC/specs/naming.md`, `DOC/specs/alternate-views.md`). Cite a spec's rows from elsewhere as `<slug>.BHV-n` / `<slug>.CON-n`.
