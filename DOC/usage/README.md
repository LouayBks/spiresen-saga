# Token usage tracking

Tracks Claude Code token/cost usage per ticket, using [`ccusage`](https://github.com/ryoppippi/ccusage) — a local CLI that reads Claude Code's own session logs (`~/.claude/projects/`) and reports token counts and estimated cost. No account or API access needed; it only reads local logs.

## Command

```bash
npx ccusage@latest session
```

Lists usage grouped by Claude Code session (one row per session, with input/output/cache tokens and estimated cost). Useful flags:

- `-s, --since <YYYY-MM-DD>` / `-u, --until <YYYY-MM-DD>` — filter to a date range (e.g. the days spent on a given ticket)
- `-i, --id <id>` — filter to one specific session
- `-j, --json` — machine-readable output, if we ever want to script the log entry

## Workflow

When starting work on a ticket, note the date/time. When the ticket is done (or at a natural checkpoint), run `npx ccusage@latest session` (optionally scoped with `--since`) and record the relevant session(s) in [`token_usage_log.md`](token_usage_log.md).

This is a manual log, not automated — the goal is a rough per-ticket cost signal over time, not exact billing reconciliation (a session can span multiple tickets, and `ccusage`'s cost figures are estimates based on published pricing, not actual invoiced amounts).
