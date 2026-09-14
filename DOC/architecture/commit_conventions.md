# Commit message conventions

Git history before this doc was ad hoc — `docs:`, `doc(...)`, `assist(unit):`, `fix(...)` all
appear for similar changes, and scope naming drifted (`claude` vs. `ai assistance` for the same
area). This is the fix: one enumerated format, applied going forward. Existing history is **not**
rewritten to match — this governs new commits only.

Rule IDs use `CM-` (commit message), continuing the project's tagging convention (CC-/TS-/AW-)
rather than starting an untagged doc.

## CM-1 — Format

```
<type>(<scope>): <subject>

[optional body]

[optional footer(s)]
```

Conventional Commits shape, with the type and scope lists below enumerated and closed — no ad hoc
values. If a change genuinely doesn't fit an existing type or scope, add the new one to the
relevant list below *in the same commit*, don't invent it silently.

## CM-2 — Types (enumerated, closed list)

| Type | Use for |
|---|---|
| `feat` | New capability — a route, a component, a feature slice |
| `fix` | Bug fix |
| `docs` | Documentation only (`DOC/`, `ADR/`, `CLAUDE.md`, READMEs) |
| `chore` | Tooling/config/dependency changes with no behavior change (`.gitignore`, lockfile bumps) |
| `ci` | `.github/workflows/**` |
| `refactor` | Restructuring with no behavior change (not `feat`, not `fix`) |
| `test` | Test-only changes (adding/fixing tests, no production code) |

Deliberately excludes `assist(unit)`-style and bare `doc(...)` — those are the drift this doc
exists to stop. `perf`, `style`, `revert` aren't added until a real change needs them (CC-15-style
"ruthlessly prune" — don't pre-populate the list for hypothetical future use).

## CM-3 — Scopes (enumerated, closed list)

Scopes track the actual directory structure (ADR-001's "directory structure is the map," AW-18),
so they stay meaningful instead of drifting per-author:

| Scope | Covers |
|---|---|
| `backend` | `backend/` |
| `frontend` | `frontend/` |
| `infra` | `infra/` (not yet built — #11) |
| `docs` | `DOC/`, `ADR/`, `CLAUDE.md` and per-slice `CLAUDE.md` files, root `README.md` |
| `governance` | `.claude/` (hooks, agents, skills, settings, `risk-paths.json`), `CODEOWNERS` |
| `ci` | `.github/workflows/**` (redundant with the `ci` type when both apply — prefer `ci(ci):` never; just use type `ci` with the scope of what it's testing, e.g. `ci(backend):`) |
| `repo` | Root-level files that don't belong to any slice (`.gitignore`, top-level config) |

A commit spanning multiple scopes picks the dominant one, or splits into multiple commits (usually
the right call — see `using_coding_agents.md` on keeping changes reviewable).

## CM-4 — Length

Subject line (`<type>(<scope>): <subject>` in full) ≤ 72 characters, imperative mood ("add", not
"added"/"adds"), no trailing period. Body lines wrap at 72 characters if a body is present.

## CM-5 — Body

Optional. Explain *why*, not *what* — same principle as CC-24's docstring/comment rule, applied to
commit messages. Skip it entirely when the subject line already says everything worth saying.

## CM-6 — Footers

Trailers only, one per line (`Key: value`) — e.g. the `Co-Authored-By:` attribution trailer
already in use for Claude-assisted commits (see `using_coding_agents.md` step 5; not restated
here, per AW-14).

## CM-7 — Enforcement status

Currently rung 1 only (prose, this doc) on the enforcement-surface ladder defined in
`branching_strategy.md` — advisory, not checked. A `commit-msg` Hook (e.g. `commitlint` against
CM-1..4) would be the natural rung-4 upgrade once this repo has any Hook-running CI wired for
commit-time checks; not yet built, same "documented contract, not implemented" status as several
`branching_strategy.md` items (AW-23's mechanical Hook, AW-26's attribution override).
