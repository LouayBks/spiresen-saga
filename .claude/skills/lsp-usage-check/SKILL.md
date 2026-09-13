---
name: lsp-usage-check
description: Periodic spot-check of whether LSP-based symbol lookup is actually being used in real sessions, vs. silently falling back to grep. Implements AW-17. On-demand only — invoke manually, not on a schedule.
---

<!-- AW-17 (DOC/architecture/agentic_workflow_processes.md section E; ADR-004 Part 6).
     "Installed ≠ used" — at least one practitioner survey found LSP-style
     code-intelligence integrations go under-used despite being installed.
     This Skill exists to catch that drift periodically, on demand. -->

# LSP usage check

AW-16 says LSP-based lookup is preferred over grep for symbol navigation, once the plugin
is installed for this stack. AW-17 exists because "preferred" in a `CLAUDE.md` line doesn't
guarantee it's actually invoked — this Skill spot-checks a recent session's real tool-use
log for the answer.

## TODO — scheduling

Deliberately **not** wired to a cron/Routine trigger. Same reasoning as AW-7/AW-8's
deferral: there's no live infra or session-log pipeline yet to justify automating this
check, so it stays a manual, on-demand Skill until that changes.

## Procedure

1. **Locate a recent session's tool-use log.** Ask the user which session/transcript to
   sample if it isn't obvious (e.g. the current session, or a specific saved transcript
   path). Do not fabricate a log — if none is available, say so and stop.
2. **Count symbol-navigation-shaped tool calls** in that log: calls to an LSP/code-intel
   tool (e.g. go-to-definition, find-references, symbol-search — whatever the installed
   plugin exposes) vs. `grep`/`rg`/`Grep`-tool calls used for the same purpose (finding a
   symbol's definition or usages, not free-text search over prose).
   - Only count grep calls that look like a symbol lookup a working LSP integration
     should have handled (e.g. `grep -rn "functionName("`) — not legitimate
     free-text/content searches where grep is the right tool regardless of LSP.
3. **Verdict.** Report one of:
   - `LSP USED` — LSP-based calls appear for symbol lookups in the sampled session.
   - `LSP NOT USED` — symbol lookups in the sampled session went through grep fallback
     even though an LSP call was available and applicable.
   - `LSP UNAVAILABLE` — the plugin isn't installed/enabled for this stack yet (AW-16 not
     done), so this check doesn't apply — say so plainly rather than forcing a verdict.
4. **Report format:** a short verdict line plus the specific calls that drove it (tool
   name, rough line/turn reference). Don't editorialize beyond the verdict — this is a
   detection Skill, not a place to redesign AW-16/17.

## Out of scope

This Skill does not install, configure, or reconfigure the LSP plugin (that's AW-16's
one-time setup, already a separate step). It only reports on usage.
