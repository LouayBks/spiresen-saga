# Feature test plan template (ADR-009 FP-5)

The test plan turns each spec row's **testability check** into a concrete, named test before the code is written. The check already says what to assert. The plan adds where the test lives, at which level, and under which name.

Save as `DOC/features/<issue>-<slug>/tests.md`.

---

```markdown
# <issue> — <feature name>: test plan

**Manifest:** [manifest.md](manifest.md)  ·  **Design:** [design.md](design.md)

| Row | Design element | Level | Test (file::name) |
|---|---|---|---|
| alternate-views.BHV-2 | 57-B4 | integration | backend/tests/maps/test_views.py::test_create_view_on_full_map_rejected |
| alternate-views.BHV-5 | 57-F2 | component | frontend/src/app/canvas/view-switch.spec.ts::"[alternate-views.BHV-5] re-renders at the new view's positions" |
| AP-1 | 57-B2 | real-env gate | Run against the dev table and record the result in the PR (TS-5) |

## Constraints

How each constraint in the manifest is held: name the behaviour tests that enforce it, or say why no test can.

| Row | Held by |
|---|---|
| alternate-views.CON-1 | BHV-1, BHV-2, BHV-3 tests |
```

---

## Rules

- **Every behaviour row in the manifest has at least one test here.** The trace check fails otherwise.
- **Levels follow `testing_strategy.md`:** integration through the real route for every endpoint (TS-1), unit for pure logic (TS-4), component tests for interactive UI (TS-8), and a real-environment gate where `moto` isn't trustworthy (TS-5).
- **Tests carry the row ID** (TS-20): `@pytest.mark.bhv("alternate-views.BHV-2")` in Python, and the ID in brackets at the start of the test title in Vitest and Playwright.
- **Names still follow TS-14:** `test_<unit>_<scenario>_<expected>`.
