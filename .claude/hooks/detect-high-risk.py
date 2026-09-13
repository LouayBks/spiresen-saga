#!/usr/bin/env python3
"""AW-6 tier 1: mechanical check of a touched file's path and content against
.claude/risk-paths.json (path_patterns + import_patterns per high-risk area).

On a match, or if the risk config itself can't be read, exits 2 so Claude Code
feeds the stderr message back to Claude (PreToolUse blocking-error semantics)
— exit 0 with a stderr-only message is silently invisible to the model, which
would make this check a no-op. AW-6 (ADR-004 Part 8) requires the mechanical
check to never quietly no-op, so an unreadable/corrupt config fails closed
(escalate) rather than failing open (silently treat everything as low-risk).
A match means "escalate to the risk-classifier subagent / plan-reviewer / a
pre-commit /code-review pass (TS-17)", not a permanent block: Claude sees the
reason and can retry once it has escalated.
"""
import fnmatch
import json
import os
import sys

# Keys searched for recursively under tool_input (matcher: Edit|Write in
# settings.json). Walking the whole structure, rather than reading one fixed
# top-level field, keeps this tolerant of a tool_input shape it wasn't
# written against — e.g. a future multi-file-edit tool — instead of silently
# finding nothing.
PATH_KEYS = {"file_path"}
TEXT_KEYS = {"content", "new_string", "old_string"}


def find_values(node, keys: set) -> list[str]:
    """Collect every string value anywhere under `node` whose key is in `keys`."""
    found: list[str] = []
    if isinstance(node, dict):
        for key, value in node.items():
            if key in keys and isinstance(value, str):
                found.append(value)
            else:
                found.extend(find_values(value, keys))
    elif isinstance(node, list):
        for item in node:
            found.extend(find_values(item, keys))
    return found


def main() -> int:
    """Return 0 (no match / not parseable) or 2 (high-risk match or unreadable config)."""
    try:
        hook_input = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0

    tool_input = hook_input.get("tool_input", {})
    file_paths = find_values(tool_input, PATH_KEYS)
    text_blobs = find_values(tool_input, TEXT_KEYS)
    if not file_paths and not text_blobs:
        return 0

    risk_config_path = os.path.join(os.path.dirname(__file__), "..", "risk-paths.json")
    try:
        with open(risk_config_path) as f:
            risk_config = json.load(f)
    except (OSError, json.JSONDecodeError) as exc:
        print(
            f"AW-6: .claude/risk-paths.json could not be read ({exc}). "
            "Tier-1 mechanical detection cannot run, so this fails closed: "
            "escalate to the risk-classifier subagent before proceeding.",
            file=sys.stderr,
        )
        return 2

    for area, spec in risk_config.get("areas", {}).items():
        for pattern in spec.get("path_patterns", []):
            for file_path in file_paths:
                if fnmatch.fnmatch(file_path, pattern):
                    _escalate(area, spec, f"path '{file_path}' matches '{pattern}'")
                    return 2
        for pattern in spec.get("import_patterns", []):
            for blob in text_blobs:
                if pattern in blob:
                    _escalate(area, spec, f"content contains import pattern '{pattern}'")
                    return 2

    return 0


def _escalate(area: str, spec: dict, reason: str) -> None:
    print(
        f"AW-6: {reason}, matching high-risk area '{area}' "
        f"({spec.get('description', '')}). Escalate to the risk-classifier "
        "subagent if scope is unclear, and route through plan-reviewer / a "
        "pre-commit /code-review pass (TS-17) before proceeding.",
        file=sys.stderr,
    )


if __name__ == "__main__":
    sys.exit(main())
