#!/usr/bin/env python3
"""AW-6 tier 1: mechanical check of a touched file path against .claude/risk-paths.json.

On a match, exits 2 so Claude Code feeds the stderr message back to Claude
(PreToolUse blocking-error semantics) — exit 0 with a stderr-only message is
silently invisible to the model, which would make this check a no-op. A match
means "escalate to the risk-classifier subagent / plan-reviewer / a pre-commit
/code-review pass (TS-17)", not a permanent block: Claude sees the reason and
can retry once it has escalated.
"""
import fnmatch
import json
import os
import sys


def main() -> int:
    try:
        hook_input = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0

    file_path = hook_input.get("tool_input", {}).get("file_path")
    if not file_path:
        return 0

    risk_config_path = os.path.join(os.path.dirname(__file__), "..", "risk-paths.json")
    try:
        with open(risk_config_path) as f:
            risk_config = json.load(f)
    except (OSError, json.JSONDecodeError):
        return 0

    for area, spec in risk_config.get("areas", {}).items():
        for pattern in spec.get("path_patterns", []):
            if fnmatch.fnmatch(file_path, pattern):
                print(
                    f"AW-6: '{file_path}' matches high-risk area '{area}' "
                    f"({spec.get('description', '')}). Escalate to the "
                    "risk-classifier subagent if scope is unclear, and route "
                    "through plan-reviewer / a pre-commit /code-review pass "
                    "(TS-17) before proceeding.",
                    file=sys.stderr,
                )
                return 2

    return 0


if __name__ == "__main__":
    sys.exit(main())
