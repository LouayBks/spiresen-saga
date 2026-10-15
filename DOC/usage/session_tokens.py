#!/usr/bin/env python3
"""Token ledger for this repo, read from Claude Code's local transcripts.

Reads every transcript under ~/.claude/projects/ (main sessions and their subagents), so it
works whichever directory a session was launched from. Each API call is attributed to a
project by what it touched: paths under the workspace that holds this repo (its parent and
grandparent directories), or `<github-owner>/<repo>` references. A call with no such evidence
inherits the project of the previous call in the same transcript. Streamed entries are
de-duplicated on (message.id, requestId); a call keeps the project of its first entry.

Output is CSV, one row per (project, session, model), with raw token counts only — no prices,
so any rate table can be applied later. Usage:

    python3 DOC/usage/session_tokens.py                 # this repo's rows only, to stdout
    python3 DOC/usage/session_tokens.py --all           # every project
    python3 DOC/usage/session_tokens.py --since 2026-10-01
    python3 DOC/usage/session_tokens.py --update DOC/usage/token_ledger.csv

Transcripts are deleted by Claude Code after `cleanupPeriodDays` (default 30) — snapshot the
output before then with --update, which keeps the rows of sessions whose transcripts are gone.
Transcripts are read from $CLAUDE_CONFIG_DIR (default ~/.claude). See README.md here.
"""
import argparse
import collections
import csv
import datetime
import glob
import json
import os
import re
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REPO_NAME = os.path.basename(REPO)
ROOTS = [os.path.dirname(REPO), os.path.dirname(os.path.dirname(REPO))]
ROOT_NAMES = {os.path.basename(r) for r in ROOTS}
REPO_SEGMENT = re.compile(rf"/{re.escape(REPO_NAME)}(?:/|$)")
CONFIG_DIR = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
KEY = ["project", "session", "model"]
FIELDS = [
    "calls", "input", "cache_write_5m", "cache_write_1h", "cache_read", "output", "thinking",
    "cold_calls", "subagent_calls", "web_search", "web_fetch", "fast_calls", "us_geo_calls",
    "haiku55_over100k_calls",
]
# Haiku 5.5 is billed at a higher rate when one prompt (input + cache read + cache write)
# exceeds this many tokens: https://platform.claude.com/docs/en/about-claude/pricing
HAIKU55_MODEL_PREFIX = "claude-haiku-5-5"
HAIKU55_LONG_PROMPT_TOKENS = 100_000


def github_owner():
    try:
        url = subprocess.run(["git", "-C", REPO, "remote", "get-url", "origin"],
                             capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        return None
    m = re.search(r"github\.com[:/]([^/]+)/", url)
    return m.group(1) if m else None


def project_pattern():
    roots = "|".join(re.escape(r) for r in ROOTS)
    owner = github_owner()
    gh = rf"|{re.escape(owner)}/(?P<gh>[A-Za-z0-9_.-]+)" if owner else ""
    return re.compile(rf"(?:{roots})/(?P<name>[A-Za-z0-9_.-]+)(?P<rest>[^\"'\s\\]*){gh}")


def project_of(text, pattern):
    hits = collections.Counter()
    for m in pattern.finditer(text):
        if m.groupdict().get("gh"):
            # A clone URL ends in .git; a reference in prose can end in a full stop.
            name = re.sub(r"\.git$", "", m.group("gh").rstrip("."))
        elif REPO_SEGMENT.search("/" + m.group("name") + m.group("rest")):
            # Also covers transcripts from before the repo moved to its current directory.
            name = REPO_NAME
        else:
            name = m.group("name").rstrip(".")
            if not name or name in ROOT_NAMES:
                continue
        hits[name] += 1
    return hits.most_common(1)[0][0] if hits else None


def calls_in(path, pattern):
    """Yield (project, model, usage, timestamp) per API call in one transcript file."""
    calls, current = {}, None
    with open(path, encoding="utf-8") as f:
        for number, line in enumerate(f):
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            if not isinstance(entry, dict):
                continue
            kind = entry.get("type")
            if kind not in ("assistant", "user"):
                continue
            message = entry.get("message") or {}
            evidence = json.dumps(message.get("content"))
            if kind == "assistant":
                evidence = entry.get("cwd", "") + " " + evidence
            project = project_of(evidence, pattern) or project_of(entry.get("cwd", ""), pattern)
            if project:
                current = project
            usage = message.get("usage") if kind == "assistant" else None
            model = message.get("model", "")
            if usage and model and not model.startswith("<"):
                key = (message.get("id"), entry.get("requestId"))
                if key == (None, None):
                    key = ("line", number)  # nothing to de-duplicate on: count it on its own
                # The last streamed entry holds the final usage. The project is fixed by the
                # first entry that has one, so a later entry can't move the call elsewhere.
                project = calls[key][0] if key in calls else "unattributed"
                if project == "unattributed":
                    project = current or "unattributed"
                calls[key] = (project, model, usage, entry.get("timestamp") or "")
    return calls.values()


def iso_date(text):
    try:
        return datetime.date.fromisoformat(text).isoformat()
    except ValueError:
        raise argparse.ArgumentTypeError(f"not a YYYY-MM-DD date: {text!r}") from None


def write_csv(path, header, lines):
    """Write to a temp file next to `path`, then rename, so a crash never leaves it truncated."""
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(os.path.abspath(path)), suffix=".csv")
    try:
        with os.fdopen(fd, "w", newline="") as f:
            out = csv.writer(f, lineterminator="\n")
            out.writerow(header)
            out.writerows(lines)
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--all", action="store_true", help="include every project, not just this repo")
    parser.add_argument("--since", default=None, type=iso_date,
                        help="only calls on or after this date (YYYY-MM-DD)")
    parser.add_argument("--update", metavar="CSV",
                        help="merge into this ledger: replace the rows of sessions still on disk, "
                             "keep the rest, and write it back")
    args = parser.parse_args()

    transcripts = glob.glob(os.path.join(CONFIG_DIR, "projects", "*", "*.jsonl"))
    if not transcripts:
        sys.exit(f"session_tokens: no transcripts under {CONFIG_DIR}/projects — "
                 "set CLAUDE_CONFIG_DIR if Claude Code keeps them elsewhere")
    pattern = project_pattern()
    rows = collections.defaultdict(collections.Counter)
    span = {}
    undated = 0
    for main_file in transcripts:
        session = os.path.basename(main_file)[:-len(".jsonl")]
        subagents = glob.glob(main_file[:-len(".jsonl")] + "/subagents/*.jsonl")
        for path in [main_file] + subagents:
            for project, model, u, ts in calls_in(path, pattern):
                if not ts:
                    undated += 1  # can't be placed in a session span or a --since window
                    continue
                # first/last span the whole session, so update them before filtering.
                first, last = span.get(session, (ts, ts))
                span[session] = (min(first, ts), max(last, ts))
                if (args.since and ts[:10] < args.since) or (not args.all and project != REPO_NAME):
                    continue
                cc = u.get("cache_creation") or {}
                w5 = cc.get("ephemeral_5m_input_tokens", 0)
                w1 = cc.get("ephemeral_1h_input_tokens", 0)
                # Writes the breakdown doesn't account for (missing or partial) count as 5m.
                w5 += max(u.get("cache_creation_input_tokens", 0) - w5 - w1, 0)
                inp, read = u.get("input_tokens", 0), u.get("cache_read_input_tokens", 0)
                tools = u.get("server_tool_use") or {}
                r = rows[(project, session, model)]
                r["calls"] += 1
                r["input"] += inp
                r["cache_write_5m"] += w5
                r["cache_write_1h"] += w1
                r["cache_read"] += read
                r["output"] += u.get("output_tokens", 0)
                r["thinking"] += (u.get("output_tokens_details") or {}).get("thinking_tokens", 0)
                r["cold_calls"] += read == 0 and w5 + w1 > 0
                r["subagent_calls"] += path != main_file
                r["web_search"] += tools.get("web_search_requests", 0)
                r["web_fetch"] += tools.get("web_fetch_requests", 0)
                r["fast_calls"] += u.get("speed") == "fast"
                r["us_geo_calls"] += u.get("inference_geo") == "us"
                r["haiku55_over100k_calls"] += (model.startswith(HAIKU55_MODEL_PREFIX)
                                                and inp + read + w5 + w1 > HAIKU55_LONG_PROMPT_TOKENS)

    if undated:
        print(f"session_tokens: skipped {undated} calls with no timestamp", file=sys.stderr)
    header = KEY + ["first", "last"] + FIELDS
    lines = [[project, session, model, span[session][0][:16], span[session][1][:16]]
             + [r[k] for k in FIELDS] for (project, session, model), r in rows.items()]
    if args.update and os.path.exists(args.update):
        with open(args.update, newline="") as f:
            old = list(csv.DictReader(f))
        if old and list(old[0]) != header:
            sys.exit(f"session_tokens: {args.update} has different columns — not merging")
        # A session still on disk is recomputed whole; any other row is a session whose
        # transcript has expired, and the ledger is now its only record.
        on_disk = {line[1] for line in lines}
        lines += [[row[k] for k in header] for row in old if row["session"] not in on_disk]
    lines.sort(key=lambda line: (line[0], line[3], line[2]))
    if args.update:
        write_csv(args.update, header, lines)
    else:
        out = csv.writer(sys.stdout, lineterminator="\n")
        out.writerow(header)
        out.writerows(lines)


if __name__ == "__main__":
    main()
