#!/usr/bin/env python3
"""SessionStart: log this session's ID + a best-effort name to
DOC/usage/session_index.md, and surface both back to the model as
additionalContext so they're the first thing in context — no lookup needed
later when the log-session Skill (.claude/skills/log-session/SKILL.md) runs.

Claude Code hooks never pass a user-assigned "session name" — only
session_id — so the name here is derived (current git branch), not read.

Unlike detect-high-risk.py (a safety gate that fails closed), this hook
fails open: any error here is non-blocking bookkeeping, never a reason to
stop a session from starting.
"""
import datetime
import json
import os
import subprocess
import sys


def main() -> int:
    try:
        hook_input = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0

    session_id = hook_input.get("session_id", "")
    short_id = session_id[:8] if session_id else "unknown"
    start_reason = hook_input.get("source") or hook_input.get("session_start_reason") or "unknown"
    cwd = hook_input.get("cwd") or os.getcwd()

    branch = _git_branch(cwd)
    timestamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ")

    _append_row(cwd, timestamp, short_id, session_id, branch, start_reason)

    context = (
        f"Session started: id `{short_id}` (branch `{branch}`, reason `{start_reason}`), "
        f"logged to DOC/usage/session_index.md. When the user asks to log this session, "
        f"use this ID with the log-session Skill instead of re-deriving or asking for it."
    )
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": context,
        }
    }))
    return 0


def _git_branch(cwd: str) -> str:
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=cwd, capture_output=True, text=True, timeout=5,
        )
        return result.stdout.strip() or "unknown"
    except (OSError, subprocess.SubprocessError):
        return "unknown"


def _append_row(cwd: str, timestamp: str, short_id: str, full_id: str, branch: str, reason: str) -> None:
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", cwd)
    log_path = os.path.join(project_dir, "DOC", "usage", "session_index.md")
    try:
        row = f"| {timestamp} | `{short_id}` | `{full_id}` | {branch} | {reason} |\n"
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(row)
    except OSError:
        pass


if __name__ == "__main__":
    sys.exit(main())
