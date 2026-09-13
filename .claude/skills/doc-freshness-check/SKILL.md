---
name: doc-freshness-check
description: Periodic pass over CLAUDE.md files (root + per-slice) that verifies referenced files, paths, and symbols still exist, and reports stale references. Implements AW-20. On-demand only — invoke manually, not on a schedule.
---

<!-- AW-20 (DOC/architecture/agentic_workflow_processes.md section E; ADR-004 Part 6).
     Agent-facing config files measurably rot: roughly a quarter of a large sampled
     repo set had at least one stale code-element reference in its agent docs.
     This Skill is the periodic-hygiene check ADR-004 Part 6 commits to, matching
     TS-5's periodic-check pattern. -->

# Doc freshness check

`CLAUDE.md` files accumulate pointers to files, directories, and symbols over time.
Nothing currently re-verifies those pointers stay valid as the codebase changes — this
Skill is that check, run on demand.

## TODO — scheduling

Deliberately **not** wired to a cron/Routine trigger. Same reasoning as AW-7/AW-8's
deferral: no live infra yet to justify automating this beyond a manual, on-demand Skill.

## Procedure

1. **Find every `CLAUDE.md` in scope**: the root `CLAUDE.md`, plus any per-slice
   `CLAUDE.md` files that exist under the app's vertical-slice directories (AW-15 — none
   exist yet as of this writing, since the app is still in `draft/`; re-check each run,
   don't assume the list from a prior run).
2. **Extract every concrete reference** in each file: relative file/directory paths
   (e.g. `DOC/architecture/application_architecture.md`, `ADR/ADR-004-agentic-workflow.md`),
   and any named symbol, script, or config path it points to (e.g.
   `.claude/risk-paths.json`, `.claude/hooks/detect-high-risk.py`,
   `.claude/agents/plan-reviewer.md`, `DOC/templates/plan_template.md`).
3. **Verify each reference still resolves**:
   - File/directory paths: confirm the path exists (`ls` / a direct file check).
   - Named symbols (a function, class, or rule ID like `AW-14`, `TS-17`): grep for the
     symbol/rule ID in the file it's supposed to live in, confirm it's still there and
     not renamed or removed.
4. **Report stale references** — a list of `file:line` in the `CLAUDE.md` that made the
   claim, what it pointed to, and why it's stale (path doesn't exist / symbol not found /
   rule ID renumbered or removed). If everything resolves, report that plainly — an empty
   findings list is a valid, useful result, not a reason to invent something to flag.
5. Do not silently fix stale references yourself — report them so the user can decide
   whether the doc or the code drifted (either could be the "wrong" side).

## Out of scope

This Skill only checks `CLAUDE.md` files, not the ADR/`DOC/architecture` source-of-truth
docs those files point to — cross-checking prose accuracy inside the ADRs is a separate,
heavier task this Skill doesn't attempt.
