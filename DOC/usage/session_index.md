# Session index

Append-only log of every session start, written automatically by
`.claude/hooks/session-start-log.py` (`SessionStart` hook). One row per start event — a session
that resumes/clears/compacts gets a new row each time, not a dedup'd one. Purpose: capture the
session ID and a derived name (current git branch, the closest available proxy — Claude Code
never passes a user-assigned session name to a hook) at the moment a session begins, so the
`log-session` Skill doesn't have to re-derive or ask for it later.

| Timestamp (UTC) | Session ID (short) | Session ID (full) | Branch | Start reason |
|---|---|---|---|---|
