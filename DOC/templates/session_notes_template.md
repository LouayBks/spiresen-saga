# Session note template (for DOC/usage/notes.md entries)

**Purpose:** tag what happened, don't narrate or conclude. Conclusions come later, from a rollup across many tagged entries, never from one entry alone. This exists because the two entries written so far each drew a general "takeaway" from a single session, which isn't a sound basis for one.

---

## What an entry contains

```markdown
## <session-id-short> — <ticket/group>

- Cache-read share: __%  (from ccusage: cache_read / total_tokens) — measured
- Cache-write share: __%  — measured
- Turn count: __  — measured
- Idle gaps >60min mid-session (Claude Code's cache TTL): yes/no (count: __) — measured
- Drivers present (check any that apply) — annotated, not measured
  [ ] High turn count          [ ] Diagnostic overhead        [ ] Dead-end retries
  [ ] Idle-gap cache reset     [ ] External wait/polling      [ ] Tool/context bloat
  [ ] One-time context load    [ ] Clarification round-trips  [ ] Output volume
  [ ] Cache-tier setting       [ ] Model-tier choice          [ ] Session-length compounding
  [ ] Rework                   [ ] Scope churn                [ ] Planned review (not a cost problem)
- One line: <what happened, factual, no adjectives> — annotated, not measured
```

### Field notes

- **Turn count** is defined as the API-call count from ccusage entries, not the user-prompt count. The two can differ 2x+ in tool-heavy sessions. API calls are what re-pay the cache-read cost, so that's the definition used here.
- **Drivers present** are checked from the fixed list above, with no free-text ranking. This is annotated, not measured: it is a human judgment call about cause, not a value pulled from the log.
- **One line** is factual, with no adjectives. Example: "Two cache resets after >2h idle gaps; ~30 turns of environment debugging (Node/npm/Vitest) that didn't resolve."

That's the whole entry. No "what actually drove cost, in order," no "takeaway for future tickets," no re-explaining what a cache-read is. If a driver needs explaining, that explanation goes once in a shared reference note, not in every entry that cites it.

## What an entry does NOT contain

- A ranked narrative of causes. Check boxes instead of writing a story.
- A general rule or recommendation ("we should do X going forward"). That's a rollup's job, once the pattern shows up in more than one session.
- A restated token-type breakdown table. Two numbers (cache-read %, cache-write %) are enough; the full breakdown lives in one reference doc.

---

## The rollup (separate, periodic, not per-session)

Every N sessions (or at each stage-tag boundary from the tracking pipeline doc), pool the checked drivers across all entries since the last rollup:

| Driver | Sessions it appeared in | Share of pooled cost |
|--------|-------------------------|----------------------|
| ...    | ...                     | ...                  |

A takeaway or standard only gets written once a driver shows up repeatedly, with the count stated ("appeared in 4 of 9 sessions since last rollup"), not from a single vivid example. This is what turns "we noticed X once" into an actual FinOps finding.

---

## Where this sits

- The 15 drivers above come from what's already been observed across the two existing `notes.md` entries, the project's earlier pricing/cache analysis, and the log's own session prose (rework vs. planned review).
- It's a closed list on purpose. Add a category only when a session shows a genuinely new mechanism, not a rephrasing of an existing one.
- This template trades per-entry richness for consistency across entries. The richness moves to the rollup, where it's earned by volume of evidence instead of asserted from one session's story.