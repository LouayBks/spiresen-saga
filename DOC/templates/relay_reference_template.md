# Relay reference doc template (trial)

The static doc a relay works from (`DOC/guides/relay_sessions.md`). One doc per sub-branch (WS-2): the plan's fixed floor (`plan_template.md`) on top, then the items. Written once — by the strong model in Plan Mode, reviewed by you — committed, then never edited while a relay runs. If it turns out wrong, stop the relay, fix the doc, commit, and restart from the item that needs it.

Save as `DOC/relay/<issue>-<slug>.md` and commit it on the branch the relay will work on.

---

```markdown
# <issue> — <sub-branch title>

**Branch:** dev/<actor>/<issue>-<slug>  ·  **Spec:** DOC/specs/<spec>.md  ·  **Issue:** #<n>

## Plan floor

- **Affected files/interfaces:** <every file or interface the whole sub-branch touches>
- **Out of scope:** <what this sub-branch does not touch>
- **End-to-end verification:** <how the finished sub-branch is proven to work>
- **High-risk:** <yes/no, from AW-6 — if yes, plan-reviewer (AW-4) runs on this doc before the relay starts>

## Shared context

<Only what every item needs and can't get from the code or the spec: a naming decision, an
interface shape, an environment quirk. Short. Anything longer belongs in the spec.>

## Items

### T1 — <title>

- **Model:** opus | sonnet | haiku
- **Effort:** low | medium | high
- **Files:** <files this item creates or changes>
- **Do:** <what to build, in a few lines; cite spec IDs (BHV-*, CON-*) rather than restating them>
- **Out of scope:** <what the next items will do, so this one doesn't>
- **Done when:** <one command or check that passes — e.g. `pytest backend/tests/maps -q`>

### T2 — <title>

...
```

---

## Writing good items

- **One item = one hop = one commit.** Size it at roughly 20–60 turns of work. Smaller and the fixed start-up cost of a hop (~35k tokens) dominates; larger and the hop grows into the long session you're avoiding.
- **Every item needs its own "Done when".** If an item can't be verified on its own, merge it with the item that makes it verifiable.
- **Order by dependency.** A hop only knows the items before it through git.
- **Pick the model per item, here, once.** Planning-heavy or tricky items get `opus`; well-specified implementation gets `sonnet`; mechanical items (renames, wiring, boilerplate) can get `haiku`. This is the only place model routing happens.
- **Last item: the review.** For high-risk sub-branches (TS-17), end with an `opus` item that runs `/code-review` on the sub-branch diff and fixes what it finds.
