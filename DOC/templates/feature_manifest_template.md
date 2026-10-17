# Feature manifest template (ADR-009 FP-3)

The manifest says **which** spec rows a feature delivers and which sub-branch builds each one. It never says **what** they mean: that's the spec's job (FP-1). If you're tempted to write a behaviour here, it's missing from a spec. Amend the spec first, then cite the new row.

Save as `DOC/features/<issue>-<slug>/manifest.md`. The owner reviews it before any design work starts.

---

```markdown
# <issue> — <feature name>: manifest

**Issue:** #<n>  ·  **Feature branch:** dev/<actor>/<issue>-<slug>  ·  **Plan depth:** light | full (FP-8)

## Delivers

One row per spec row or access pattern. IDs are qualified: `<spec-file-stem>.<ID>`.

| Row | Sub-branch | Notes |
|---|---|---|
| alternate-views.BHV-1 | backend | |
| alternate-views.CON-1 | backend | Enforced by BHV-1..3 |
| AP-1 | backend | First-login provisioning |
| alternate-views.BHV-5 | frontend | |

## Deferred

Rows a reader might expect here, but which another feature delivers.

| Row | Delivered by | Why not here |
|---|---|---|
| map-lifecycle.BHV-8 | #40 | Renaming a View belongs with the View switcher UI |

## End-to-end scenarios (optional)

At most two. Each one is a chain of cited rows, not new behaviour.

1. **New user's first Map:** accounts-and-auth.BHV-1 → AP-1 → alternate-views.BHV-1 → node-link-lifecycle.BHV-2.

## Sub-branches

In build order (WS-2).

| Sub-branch | Branch name | Rows |
|---|---|---|
| infra | dev/<actor>/<issue>-<slug>-infra | <count> |
| backend | dev/<actor>/<issue>-<slug>-backend | <count> |
| frontend | dev/<actor>/<issue>-<slug>-frontend | <count> |
```

---

## Checks before the owner signs it off

- Every row is a real ID, and its spec says what the feature is expected to do there.
- No row is delivered by two features. The coverage matrix in `delivery_sequence.md` is the reference.
- Every constraint has at least one behaviour in the same feature that enforces it, or a note saying how it's held.
- Nothing in the file reads as a behaviour statement.
