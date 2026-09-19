# spiresen-saga

Multi-tenant box-canvas app (Angular + FastAPI/Mangum/Lambda + DynamoDB). This file is pointers and gotchas only — decisions and reasoning live in `ADR/` and `DOC/architecture/`, not here (AW-14).

## Source of truth

- `ADR/` — accepted decisions and why (code architecture, cloud architecture, rules of coding and testing, agentic workflow, etc.).
- `DOC/architecture/application_architecture.md` — stack, schema, current open items.
- `DOC/specs/` — behavior specs (`BHV-*` in EARS, `CON-*` in RFC 2119; format in `DOC/templates/spec_design_template.md`, ADR-006): what the product does and must always hold, one per design ticket. A spec decides the domain model, never the physical storage shape. To find which spec owns a behavior, start from the CRUD coverage matrix in `map-lifecycle.md`.
- `DOC/architecture/data_cartography.md` — every stored entity, the DynamoDB key layout, access patterns, invariants and limits; the rationale is `ADR/ADR-007-physical-data-layout.md`. Diagrams are PlantUML source plus rendered SVG in `DOC/architecture/diagrams/` (regenerate with `plantuml -tsvg <file>.puml`).
- `DOC/architecture/dependencies.md` — tracked runtime/tooling versions for the actual stack (Python, Node, Angular, etc.); kept current, not a snapshot.
- `DOC/architecture/clean_code_rules.md` (CC-1..33), `testing_strategy.md` (TS-1..19), `agentic_workflow_processes.md` (AW-1..20) — the concrete, rule-tagged specs.
- `DOC/architecture/branching_strategy.md` (AW-21..26) — branch taxonomy, actor permissions (human vs. Claude), deploy trigger contract, and an enforcement-surface ladder (prose/Skill → Hook → GitHub-side config) for picking a control's strength by consequence severity. Claude may only push to `dev/claude/*` branches and reach `main`/`int` via human-approved PR — never delete a branch, never apply infra, never edit agentic-definition files autonomously.
- `DOC/architecture/commit_conventions.md` (CM-1..7) — commit message format, enumerated types/scopes, length limits. Applies to new commits only; existing history isn't rewritten to match.
- `DOC/templates/plan_template.md` — the plan template referenced below.
- `DOC/guides/using_coding_agents.md` — the step-by-step dev walkthrough (branch → plan → implement → PR) tying the rules above together; start here if you're picking up a ticket for the first time.
- `DOC/guides/running_locally.md` — how to actually run each slice on your machine (setup, dev server, lint/test commands), per slice as it's scaffolded.
- `DOC/guides/infra_setup.md` — human-only walkthrough for AWS account/domain/cert/pipeline setup (#10/#11); pairs with `ADR-005` for the credential-strategy reasoning behind it.
- `DOC/frontend/` — product/UI specs (e.g. `boxes-plan.md`) for the box-canvas surface. These describe *what to build* (where they conflict with `DOC/specs/`, the specs win); any new data-model entity or field they introduce must be reconciled back into `application_architecture.md` (the schema source of truth), not left to live only here.

(A consolidated `DOC/architecture/agentic_fleet.md` — how the artifacts below fit together and how to invoke them — is planned but not yet written; this section will point to it once it exists, not before.)

## Dev workflow

Full mechanics are in `DOC/architecture/agentic_workflow_processes.md` — don't restate them here, just the pointers:

- **AW-1** — Plan Mode bypass criterion. **AW-2/AW-3** — worktree-per-issue, cross-session coordination only at real shared boundaries.
- **AW-6/TS-17** — two-tier high-risk detection (`.claude/hooks/detect-high-risk.py` against `.claude/risk-paths.json`, falling back to the `risk-classifier` subagent). Never the primary agent's own unassisted call.
- **AW-4** — high-risk plans get a fresh-context review via the `plan-reviewer` subagent before implementation starts.
- **TS-16/18/19** — no rigid test-first ordering; scoped test execution in the inner loop; flag (don't silently retry) a test that flips across 2 runs.
- **TS-1/7/12/15/19's Hook halves** (pytest/Vitest CI gates, order-randomization, retry bounds) — wired as of #9 (`backend-ci.yml`/`frontend-ci.yml`), now that real app code (`backend/`, `frontend/`) exists.
- **TS-13** — no numeric coverage gate in CI, deliberately and permanently (not blocked-pending-tooling like the row above): coverage stays diagnostic-only unless a future decision explicitly revisits this.

## Code navigation

AW-16: LSP over grep for symbol navigation, once the plugin is installed for this stack — not yet done (`DOC/architecture/agentic_workflow_processes.md` section E).

## Structure

Vertical-slice architecture (ADR-001) — no standalone `ARCHITECTURE.md`, the directory structure is the map (AW-18). Per-slice `CLAUDE.md` files get added as slices are built (AW-15) — `backend/CLAUDE.md` and `frontend/CLAUDE.md` are the first, added by #9. (An earlier `draft/` folder was a throwaway POC used to validate the stack choice, deleted once that was confirmed — it was never a real slice and left no code behind.)
