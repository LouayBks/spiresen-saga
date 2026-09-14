# ADR-001: Codebase architecture for the portfolio app (Saga)

**Status:** Accepted
**Date:** 2026-09-08
**Scope:** how application code is organized into modules/directories only. Clean-code rules (typing, fail-fast, LOC discipline), testing strategy, and the agent/workflow setup are separate decisions (points 2–4) and are deliberately excluded here.

## Context and objective

The portfolio app is a single-service, low-traffic personal site: FastAPI (via Mangum) on Lambda behind API Gateway, an Angular 22 frontend built around a drag-and-drop nested-box canvas, DynamoDB in a single-table design, Terraform-managed infra, Cognito/Google SSO for auth. Per `ARCHITECTURE.md`, the infrastructure and data model are already decided — including a recent addition, **Sagas** (multi-tenant, user-owned collections that sit above the box tree) — and that document explicitly defers all application-code-organization decisions to this work.

Claude Code is the primary coding tool for this build, and the project is explicitly meant to demonstrate a well set-up Claude Code workflow: high output quality/correctness at low token cost. The objective of this ADR is to choose how the codebase is organized so that a Claude Code session can cheaply and correctly discover, write, edit, and re-orient itself in the code — while the choice still holds up as a sound architecture on ordinary software-engineering grounds, independent of any AI angle.

## Decision drivers (criteria)

Only properties of module/directory organization count here — nothing about how code is written inside a module.

| ID | Criterion | Question it answers | Source |
|---|---|---|---|
| A | Cohesion-to-coupling ratio per module | Does one unit of work live inside one directory, or does a single change ripple across many unrelated files? | Classical SE principle (Constantine & Yourdon, coupling/cohesion). Reinforced by the Co-Coder finding: cohesion-aware task partitioning raised coding pass rates 11–14pp and cut cost 28–35% vs. naive splitting. |
| B | Indirection depth to trace one feature end-to-end | How many files/layers must be opened to go from "user request" to "code that handles it"? | ["Code for the AI Reader"](https://dasroot.net/posts/2026/05/code-for-ai-reader-redesigning-architecture-llm-era/) — deep indirection pushes concrete behavior outside a model's effective attention. |
| C | Directory-to-documentation alignment | Do module boundaries match natural CLAUDE.md scopes? | Anthropic, ["How Claude Code works in large codebases"](https://claude.com/blog/how-claude-code-works-in-large-codebases-best-practices-and-where-to-start); Claude Certification Guide [3.1](https://claudecertificationguide.com/learn/3-claude-code-config/3-1-claude-md-hierarchy). |
| D | Dependency-direction discipline / blast-radius containment | Does the pattern enforce which layers may depend on which? | Classical SE principle — Dependency Inversion / Clean Architecture (Robert C. Martin). |
| E | Verifiability seam built into the structure | Does the pattern create a natural boundary to substitute a fake/stub for isolated testing? | Hexagonal architecture's original rationale (Alistair Cockburn). Reinforced by this session's self-correction research: grounded verification needs exactly this kind of seam. |
| F | Ceremony-to-domain-complexity fit | Does structural scaffolding match how many genuinely distinct domains this app has? | Professional heuristic (YAGNI) applied to this app's actual size — a judgment call, not a study. |
| G | Structural cohesion guarantee vs. "modular mirage" risk | Does the pattern's shape make true cohesion likely, or can it look organized while staying scattered underneath? | ["AI-Generated Smells," arXiv 2605.02741](https://arxiv.org/html/2605.02741v1) — "modular mirage" is the paper's own term. |
| H | Extensibility cost as the system grows | How much restructuring does a genuinely new domain require later? | Classical SE principle — Open/Closed Principle (Meyer/Martin). |
| I | Ecosystem/idiomatic fit for the stack | How well does the pattern match the conventional way of structuring FastAPI + Angular standalone components? | **Reasoned inference, not a sourced finding** — treated as a tiebreaker, not a hard requirement. |
| J | Global onboarding cost | How long until a fresh agent session with zero prior context has a correct mental model of the whole system? | Claude Certification Guide [5.4](https://claudecertificationguide.com/learn/5-context-management/5-4-codebase-exploration). |

## Considered options

Narrowed to patterns that are (a) real, commonly-taught alternatives for a single-service backend + SPA at this scale, and (b) actually distinguishable by the criteria above.

1. **Vertical Slice / feature-based** — group by what changes together; the shape the app already leans toward (box-canvas + auth).
2. **Layered / N-tier** — the default baseline (routes/services/repos split by technical type); the low bar the others are measured against.
3. **DDD** — used on a prior project, giving it real precedent to weigh directly.
4. **Hexagonal / ports-and-adapters** — the pattern that most directly targets D and E, needed to test whether those two criteria should dominate.

Excluded: microservices (one Lambda-backed service — nothing to split across service boundaries); MVC (frontend-only, not comparable at this scope); Clean/Onion Architecture (same family as hexagonal — same tradeoffs, no distinct signal); modular monolith (not distinct from vertical-slice at this app's size).

## Evaluation

Scores use a 1–3 scale (1 = Weak, 2 = Moderate, 3 = Strong; N/A where a criterion doesn't apply) against the criteria lettered above.

### Option 1 — Vertical Slice / feature-based

Organizes code by feature rather than by technical role: each slice (`boxes/`, `auth/`) holds its own route, logic, and data access together, end-to-end. Popularized as a reaction against layered architecture's fragmentation (Jimmy Bogard's "Vertical Slice Architecture," common in CQRS-style codebases). Generally reached for when features are relatively independent and a team wants related code kept physically together with minimal ceremony.

| A | B | C | D | E | F | G | H | I | J |
|---|---|---|---|---|---|---|---|---|---|
| 3 | 3 | 3 | 2 | 2 | 3 | 2 | 1 | 3 | 3 |

Contested points:
- **D is 2, not 3 or 1** — nothing structurally stops one slice reaching into another, but slice boundaries at least make that reach visible and nameable in review, which plain layered doesn't offer.
- **E is 2** — a test can live right next to its slice, but the seam has to be deliberately built; it isn't handed to you by the pattern the way hexagonal hands it to you.
- **H is 1** — cheapest option today, but the same lack of interface boundaries that keeps it cheap now makes it the most expensive of the four to retrofit if a genuinely new domain shows up.

### Option 2 — Layered / N-tier

Organizes code by technical responsibility instead of feature: a presentation/routing layer, a service/business layer, and a data-access/repository layer, each spanning every feature. The oldest and most widely-taught pattern — the default shape of most framework tutorials, including FastAPI's own docs. Generally used because it's simple to explain and enforces a basic separation of concerns even without any domain modeling.

| A | B | C | D | E | F | G | H | I | J |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 1 | 1 | 1 | 2 | 1 | 2 | 3 | 2 |

Contested points:
- **I is 3 despite everything else scoring low** — it's still the most-tutorialed way to structure a FastAPI app; genuinely idiomatic, just a poor fit for this app's actual shape.
- **H is 2, not 1** — adding a new layer-consistent feature (another route+service+repo trio) is mechanically easy even though *understanding* existing features is hard — a real split between "cost to add" and "cost to trace."
- **D scores 1 here too, same as vertical-slice** — layering by technical type doesn't actually enforce dependency direction any better; it just adds the appearance of structure without the discovery benefit.

### Option 3 — DDD

Organizes code around explicit domain concepts — entities, value objects, aggregates, bounded contexts — with domain logic deliberately isolated from infrastructure. Introduced by Eric Evans (2003). Generally used for large, genuinely complex business domains where the hard part is modeling the domain correctly and protecting it from infrastructure churn — overkill when the domain itself is thin, as it is here.

| A | B | C | D | E | F | G | H | I | J |
|---|---|---|---|---|---|---|---|---|---|
| 2 | 1 | 2 | 3 | 2 | 1 | 2 | 3 | 2 | 1 |

Contested points:
- **A is 2, not a clean 3** — cohesion is strong *within* a bounded context, but this app barely has more than one real bounded context yet, so much of the benefit is currently theoretical.
- **F is the central objection to DDD here** — aggregates, value objects, and repository interfaces are ceremony sized for a domain complexity this app doesn't have yet.
- **J is 1** — the most onboarding-expensive option: a fresh session has to learn DDD vocabulary on top of learning the app itself.

### Option 4 — Hexagonal / ports-and-adapters

Organizes code around a domain/application core that depends only on interfaces ("ports"), with concrete infrastructure ("adapters" — database, HTTP, queue) plugged in from outside. Coined by Alistair Cockburn (2005). Generally used when a system must be testable in isolation from infrastructure, or needs to swap infrastructure implementations without touching core logic.

| A | B | C | D | E | F | G | H | I | J |
|---|---|---|---|---|---|---|---|---|---|
| 2 | 1 | 1 | 3 | 3 | 1 | 2 | 3 | 1 | 1 |

Contested points:
- **E is its clear, uncontested 3** — ports-and-adapters exists specifically to swap fakes at the boundary; no other option earns this one for free.
- **I is 1, its own weakest point** — the least idiomatic of the four for FastAPI/Angular specifically; ecosystem tutorials rarely reach for ports-and-adapters at this scale.
- **F shares DDD's over-scaling objection** — interface-per-boundary ceremony sized for more real domains than currently exist.

### Full comparison table

| ID | Vertical Slice | Layered/N-tier | DDD | Hexagonal |
|---|---|---|---|---|
| A | 3 | 1 | 2 | 2 |
| B | 3 | 1 | 1 | 1 |
| C | 3 | 1 | 2 | 1 |
| D | 2 | 1 | 3 | 3 |
| E | 2 | 1 | 2 | 3 |
| F | 3 | 2 | 1 | 1 |
| G | 2 | 1 | 2 | 2 |
| H | 1 | 2 | 3 | 3 |
| I | 3 | 3 | 2 | 1 |
| J | 3 | 2 | 1 | 1 |

## Decision

**Vertical Slice / feature-based organization**, on the strength of A, B, C, F, I, J. DDD and hexagonal genuinely win D and E, and hexagonal alone wins H — these are accepted tradeoffs at the app's current scale, not oversights.

## Consequences and limitations

Risks and limitations of the choice itself, from Claude's cost/performance angle — stated generally so they carry into how future tasks get scoped and prompted:

- **Boundary enforcement here is discipline-based, not structural.** Nothing blocks one slice from reaching into another's internals the way a port/interface would. Risk scales with task framing: work scoped to one slice keeps this contained; work framed across multiple slices at once raises the odds of ad-hoc coupling this pattern won't catch on its own.
- **Cohesion is asserted by folder, not guaranteed by it.** Correct file placement says nothing about whether the code inside is actually cohesive — verify that directly.
- **No built-in verification seam changes the cost/reliability profile of self-correction.** Without a structural point to substitute a fake, self-correction defaults toward self-review over cheap grounded (execute/test) verification unless a task explicitly sets one up.
- **Low ceremony now trades against retrofit cost later.** Treat this as a deferred cost to plan for, not one avoided.
- **Per-session onboarding cost is relatively low, not zero.** Every fresh agent session still pays some fixed discovery cost — worth weighing when batching related work into fewer, longer sessions versus many short ones.
- **Criterion I (ecosystem fit) is reasoned inference, not evidence** — keep treating it as a tiebreaker only in any future re-scoring.