# Using the coding agents — a walkthrough for devs

This is the practical "what do I actually do" guide for picking up a ticket with Claude Code in
this repo. It doesn't restate rules — every step links to the doc that owns that rule, per AW-14
(pointers, not duplication). Read this once end-to-end before your first ticket; after that, use
it as a checklist.

**Companions, not duplicates:** `DOC/ai_assistance/units_overview.md` (which of the five units
fires on its own vs. needs invoking), `DOC/architecture/agentic_workflow_processes.md` (the
rule-tagged mechanics, AW-1..20), `DOC/architecture/branching_strategy.md` (branch/actor rules,
AW-21..26), `DOC/templates/plan_template.md` (the literal template referenced in step 2).

## 0. Before your first ticket ever

- Read `CLAUDE.md` once — it's short by design (AW-14) and points at everything else.
- Confirm `.claude/settings.json` is present and `permissions.deny` includes the Tier-1 hard
  denies (branch deletion, force-push, `terraform apply`/`destroy`, `gh pr merge`) —
  `branching_strategy.md`'s AW-22/AW-24.
- If you haven't already: `/plugin install typescript-lsp@claude-plugins-official` and
  `pyright-lsp@claude-plugins-official` (AW-16) — see `DOC/setup/claude_code_setup.md` section A
  for the exact commands and the separate binaries they depend on.

## 1. Branch

Per `branching_strategy.md`'s taxonomy: `dev/<actor>/<issue>-<slug>`, branched from `int` (or
from another `dev/<human>/<slug>` branch if you're pairing on something already in flight).
`<actor>` is your username for a session you're driving; it's `claude` only for a branch Claude
creates entirely on its own (autonomous work — not the normal case yet, see AW-21).

Never work directly on `int` or `main` — everything lands there via PR (AW-25).

## 2. Decide: bypass, or Plan Mode?

**AW-1's bypass** applies only when the change is one file, changes no logic/control-flow, and
is describable in one sentence (a typo, a log line, a rename). Almost no real ticket qualifies —
default to planning when unsure; bypass is scoped to skipping Plan Mode specifically, nothing
else (hooks, tests, review all still run regardless).

Otherwise, Plan Mode, using `DOC/templates/plan_template.md`:
- **Fixed floor, always**: affected files/interfaces, an explicit out-of-scope statement, an
  end-to-end verification step.
- **Conditional, when the change is multi-file/unfamiliar/uncertain**: objective, a boundaries
  tier (✅ always do / ⚠️ ask first / 🚫 never do), open questions, complexity justification, and
  the high-risk-logic flag (set by step 3 below, never self-declared).

## 3. High-risk detection runs automatically — but check its config is real

Every `Edit`/`Write` triggers `.claude/hooks/detect-high-risk.py` against
`.claude/risk-paths.json` (AW-6 tier 1) before it escalates to the `risk-classifier` subagent
(tier 2) on anything ambiguous. You don't invoke this — it's a `PreToolUse` Hook.

**Known gap as of this writing**: `risk-paths.json`'s three areas (auth-allowlist,
cross-slice-authorization, data-invariant-transactions) all have empty `path_patterns`/`import_patterns` —
placeholders from before any real slice existed. The first ticket that creates the actual
directories these areas describe (#57, the persistence and CRUD backend) should fill in real patterns as part of that ticket's plan,
otherwise tier 1 is a no-op and tier 2 (`risk-classifier`) carries more load than intended.

If a plan or a diff gets flagged high-risk:
- **Plan stage** → `plan-reviewer` subagent, fresh-context review before implementation starts
  (AW-4).
- **Pre-commit stage** → `/code-review` as a background subagent, fresh context (TS-17).

Never treat a high-risk call as something you or Claude should self-judge past the mechanical
check — that's the entire point of the two-tier design (AW-6, ADR-004 Part 8).

## 4. Implement, mechanical checks, tests

- Mechanical checks (formatter/linter/type-checker) run as Hooks/CI per ADR-002 — not something
  you invoke by hand.
- Tests: TS-15 (grounded execution — actually run them, don't just assert), TS-16 (no rigid
  test-first ordering), scoped to what the change touched in the inner loop (TS-18). If a test
  flips across two runs, flag it — don't silently retry until it's green (TS-19).
- First ticket to add real app code beyond scaffolding: this is also the trigger to wire the
  currently-blocked pytest/Vitest CI gates (TS-1/7/12/15/19's Hook halves) and add a per-slice
  `CLAUDE.md` (AW-15) for wherever that code lands.

## 5. Commit

Normal commits, `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>` trailer. AW-26's
Author/Committer override is **deliberately dormant** for interactive sessions like this one — it
only activates once an unattended/autonomous Claude action exists in this repo (see
`branching_strategy.md` AW-26). Don't add it yourself in the meantime.

## 6. PR into `int`

- `claude-review.yml` fires automatically (AW-11), posts advisory inline comments, and its
  check-run is always `neutral` — it never blocks merge (AW-13). Read the findings anyway; the
  neutral conclusion is about merge authority, not about whether the findings are worth acting on.
- `CODEOWNERS` flags the PR if it touches `CLAUDE.md`, `ADR/`, `DOC/architecture/`, `.claude/`, or
  `.github/workflows/` — plain app-code changes under a feature slice won't trigger it.
- Branch protection (once set up per `branching_strategy.md`'s manual steps) blocks direct push,
  force-push, and deletion on `int`/`main` regardless of any of the above.
- You merge. No commit reaches `int`/`main` without a human clicking merge (AW-25) — that's true
  today by construction (Claude has no separate GitHub identity yet), and stays true once it does.

## 7. If something goes wrong mid-ticket

- A test flips inconsistently → flag it in the PR description, don't retry-until-green (TS-19).
- A high-risk area you didn't expect gets flagged → let the review chain run (step 3) rather than
  overriding it because you're confident it's fine; that confidence is exactly what AW-6/ADR-004
  Part 8 doesn't trust as the sole gate.
- Claude proposes touching `main`/`int` directly, deleting a branch, or running
  `terraform apply`/`destroy` → it shouldn't get that far (`permissions.deny`), but if you ever
  see it attempted, that's a bug in the Tier-1 config, not a judgment call to wave through.

## Where the deeper mechanics live, if this guide isn't enough

| Question | Doc |
|---|---|
| Why these rules exist, not just what they are | `ADR/ADR-002..004` |
| Exact Hook/subagent wiring, flow diagrams | `DOC/architecture/agentic_workflow_processes.md` |
| Branch/actor rules, enforcement-surface ladder | `DOC/architecture/branching_strategy.md` |
| Which of the 5 units fires on its own vs. needs invoking | `DOC/ai_assistance/units_overview.md` |
| Plugin/MCP/credential setup | `DOC/setup/claude_code_setup.md` |
| Open TBD items (Claude identity, ADR-004 amendment, deferred Hooks) | [issue #19](https://github.com/LouayBks/spiresen-saga/issues/19) |
