# Plan template (AW-5)

Fixed-floor fields apply to every plan that reaches Plan Mode (i.e., didn't qualify for the AW-1 bypass). Conditional fields apply only when the change is multi-file, touches unfamiliar code, or has an uncertain approach — skip them, don't leave them blank, otherwise.

## Fixed floor (always present)

- **Affected files/interfaces** — every file/interface this change touches.
- **Out-of-scope statement** — what this change explicitly does *not* touch.
- **End-to-end verification step** — how "done" will be proven, not just asserted.

## Conditional (only when AW-1's escalation triggers apply)

- **Objective** — one line: why this change, not just what.
- **Boundaries tier** — ✅ Always do / ⚠️ Ask first / 🚫 Never do.
- **Open questions** — anything genuinely unresolved going in.
- **Complexity justification** — "simpler alternative rejected because…" — only if the plan reaches for more machinery than the task obviously requires.
- **High-risk-logic flag** — set by the AW-6 detection mechanism (mechanical check, then `risk-classifier` subagent if ambiguous), never self-declared by the planning agent alone. If set, this plan gets a fresh-context review via the `plan-reviewer` subagent (AW-4) before implementation starts.
