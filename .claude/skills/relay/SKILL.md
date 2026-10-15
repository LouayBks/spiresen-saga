---
name: relay
description: Relay sessions (trial) — work a static reference doc one item per session, passing a short hop message to the next session instead of growing one long conversation. Invoke as `/relay start <doc>` to begin, `/relay` followed by a pasted hop message to continue, or `/relay hop` to end the current item and print the hop message. Guide: DOC/guides/relay_sessions.md.
---

<!-- Trial, not an adopted rule yet (DOC/guides/relay_sessions.md, "Status").
     This file is the single source of the hop rules: relay.sh strips this frontmatter
     and passes the body as --append-system-prompt, so manual and scripted hops follow
     the same text. Keep it short — every hop pays for it. -->

# Relay hop rules

You are one hop in a relay. You do **one item** of a static reference doc, verify it, commit it, and hand off with a hop message. You have no memory of earlier hops beyond the hop message you were given.

## Sources of truth, in order

1. **Git and the tests** — what is committed and what passes. Trust these over anything else.
2. **The reference doc** — what to build. It is static: never edit it.
3. **The hop message** — only what git can't show: the next item, dead ends, open questions, the failure count. It tells you where to look, not what is true.

## Starting a hop

1. Read the hop message. In `/relay start <doc>` mode there is none yet: the item is the doc's first item, `DONE -`, `FAILS <item>: 0`.
2. Check the doc is unchanged: `git hash-object <doc>` must start with the hash on the `RELAY` line. If it differs, or the doc has uncommitted changes, **stop** and report it — the relay is invalid.
3. Check the tree: `git status --short`. Unexpected changes → stop and report; don't clean them up.
4. Read the doc's header and your item only, plus the files the item names. Don't read other items' sections unless your item depends on them.

## Doing the item

- Do the item's scope and nothing else. Its "Out of scope" lines are binding.
- Don't retry anything listed under `DEAD`.
- Normal repo rules still apply: hooks, the high-risk escalation (AW-6), the commit conventions.
- If the doc is wrong or missing something you need to decide → don't guess. Put it under `OPEN` and hand off.

## Ending a hop

- **Item verified** (its "Done when" check passes): commit with `git commit -m "<CM-1..7 subject>" --trailer "Relay-Item: <item>"`, adding any other `-m` paragraphs before `--trailer` (the trailer is required — it's how the hop is measured, and `--trailer` keeps it in the last paragraph, where git reads trailers), then `NEXT` is the following item in the doc, or `END` after the last one. `FAILS` resets to 0 for the new item.
- **Item not done**: don't commit broken work. Run `git stash push -u -m "relay <item> attempt <n>"`, keep `NEXT` on the same item, increase its `FAILS` count, and record what failed under `DEAD` (cite the stash).
- **Going in circles**: the same approach failing twice in this hop is the signal to stop and hand off, not a third attempt.
- Carry forward only the `DEAD` lines that still matter for the next item; drop the rest.

Your **final output** is exactly one fenced block tagged `relay`, nothing after it:

```relay
RELAY <doc path> @ <first 7 chars of git hash-object of the doc>
DONE  <item> @ <short commit sha>     (or: DONE  -)
NEXT  <item>                          (or: NEXT  END)
DEAD  - <tried X; fails because Y; don't retry>   (or: DEAD  -)
OPEN  - <question only the human can answer>      (or: OPEN  -)
FAILS <next item>: <n>
```

Keep it under ~300 words. No narrative, no summary of the work — git has that.

## `/relay hop` (manual mode only)

The user wants to leave this session. Finish or stash the current item as above, then print the block. Don't start the next item.
