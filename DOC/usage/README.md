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

`ccusage` must run online: with `--offline` its bundled price table charges models newer than the release at $0 (Opus 5.5 among them). It also groups by launch directory, so a session started outside this repo is missed or mixed with other work — use the token ledger below to attribute sessions.

## Token ledger

[`session_tokens.py`](session_tokens.py) reads Claude Code's transcripts and writes one CSV row per (project, session, model) with raw token counts — input, 5-minute and 1-hour cache writes, cache reads, output (and its thinking share), cold calls (full cache rebuilds), subagent calls, and the flags that change the per-token rate (web search/fetch, fast mode, US-only inference, Claude Haiku 5.5 prompts over 100K). No prices: apply a rate table to these counts when computing cost.

```bash
python3 DOC/usage/session_tokens.py --update DOC/usage/token_ledger.csv   # refresh the snapshot
python3 DOC/usage/session_tokens.py --since 2026-10-01                     # print a date range
```

Each API call is attributed by what it touched (paths in this repo, `LouayBks/spiresen-saga` references), so a session launched from any directory is counted, and a session that also worked elsewhere only contributes its calls here. `first`/`last` span the whole session, not only its calls here.

[`token_ledger.csv`](token_ledger.csv) is a committed snapshot. Refresh it at the end of a ticket with `--update`, never by redirecting output into it: `--update` recomputes the sessions still on disk and keeps the rows of sessions whose transcripts are gone, and it writes through a temp file, so a failed run leaves the ledger as it was. A session refreshed while it's still running is recomputed whole on the next refresh. Transcripts are read from `$CLAUDE_CONFIG_DIR` (default `~/.claude`), and the script exits with an error if it finds none. Claude Code deletes transcripts after `cleanupPeriodDays` (30 by default), so anything not snapshotted is lost — sessions from before 13 Sep 2026 are already gone and exist only in `token_usage_log.md`. Rows in that log were taken mid-session and undercount several sessions; the ledger is the source for token counts from 13 Sep on.
