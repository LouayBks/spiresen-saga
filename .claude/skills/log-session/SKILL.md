---
name: log-session
description: Appends one tagged entry to DOC/usage/notes.md for the current session, per DOC/templates/session_notes_template.md. On-demand only — invoke manually; no session-end hook exists to trigger it automatically.
---

# Log session

`DOC/usage/session_index.md` (written automatically at session start by
`.claude/hooks/session-start-log.py`) already has this session's short ID, branch, and start
reason. This Skill uses that instead of re-deriving or asking for it, then writes one entry to
`DOC/usage/notes.md` following `DOC/templates/session_notes_template.md` exactly.

## Procedure

1. **Get the session ID.** Use the short ID already surfaced via this session's `SessionStart`
   `additionalContext` (or the latest matching row in `DOC/usage/session_index.md` if that
   context isn't visible for some reason). Don't ask the user for it.
2. **Get the measured fields from `ccusage`** for this session (see the template's field notes):
   - Cache-read share and cache-write share of total tokens.
   - Turn count — the `ccusage` API-call count, not the user-prompt count.
   - Idle gaps >60 minutes mid-session (Claude Code's cache TTL), and how many.
3. **Check the fixed driver list** from the template against what actually happened this session.
   This is an annotated judgment call, not a measurement — check any that apply, no free-text
   ranking, no inventing categories outside the closed list.
4. **Write the one-line summary** — factual, no adjectives, no "what actually drove cost, in
   order" narrative and no forward-looking recommendation. Those belong to the periodic rollup
   (see the template), never to a single entry.
5. **Append the entry** to `DOC/usage/notes.md`, using the template's block format verbatim
   (`## <session-id-short> — <ticket/group>` heading, then the fields in the template's order).
   Use the current branch (from `session_index.md`) or ask the user only if the ticket/group
   isn't obvious from it.

## Out of scope

- Backfilling `notes.md`'s existing narrative-style entries into this tagged format — they
  predate the template and stay as they are.
- Writing the periodic rollup table — that happens separately, every N sessions, pooling checked
  drivers across many entries, per the template's own "Where this sits" section.
