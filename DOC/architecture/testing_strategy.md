# Point 3 — Final testing strategy

Step 4 of point 3, following `ADR-0003` (Testing Trophy shape + agentic verification policy). Every rule below carries a **recommended** implementation surface, using ADR-0002's taxonomy for continuity: **Hook** (deterministic CI/pre-commit gate), **Lint config**, **Skill** (on-demand review pass), **Agent/task def** (built into how a coding task is framed, point 4), **CLAUDE.md prose** (the small, uncheckable residual).

## A. Backend test structure (Testing Trophy — integration-first)

| ID | Rule | Surface | Notes |
|---|---|---|---|
| TS-1 | Every route/slice gets an integration-level test via FastAPI `TestClient` hitting the real route→service→repository path | Hook | `pytest`, wired into the same CI gate as ADR-0002's `ruff`/`pyright` checks |
| TS-2 | DynamoDB-touching tests use `moto`, with a fresh function-scoped mocked table per test — never shared/module-scoped state | Agent/task def | The concrete hermeticity discipline (see TS-12) applied to backend specifically |
| TS-3 | Collaborators (DynamoDB access, Cognito claim extraction) are exposed as `Depends()` parameters on every route handler, so `app.dependency_overrides` is the test-time substitution point | Agent/task def | Resolves ADR-0001's criterion E gap — apply when a task adds or touches a route |
| TS-4 | Pure, I/O-free business logic (fractional-order calculation, box-nesting validation) gets small-tier `pytest` unit tests, no mocking | Agent/task def | Google's "small" test-size tier; the one place classic isolated unit testing is the right shape |
| TS-5 | `moto`'s documented DynamoDB GSI-pagination gap is a residual risk this test shape doesn't remove — periodically supplement with a small number of hand-run tests against a real free-tier dev DynamoDB table for the GSI query patterns that matter most | Skill | A periodic verification pass, not an every-commit gate — cost-proportionate to the risk |
| TS-6 | `moto` is the default DynamoDB test double; no LocalStack dependency | N/A — tooling decision | LocalStack now requires an account/auth token even for non-commercial use (since March 2026) — documented here so it isn't silently reintroduced later |

## B. Frontend test structure

| ID | Rule | Surface | Notes |
|---|---|---|---|
| TS-7 | Vitest is the test runner | Hook | Angular 22 CLI's current default, not Jasmine/Karma — CI config |
| TS-8 | Interactive components (box-canvas above all) are tested via `TestBed` host-wrapper components exercising real composition, not isolated component tests with mocked children | Agent/task def | Directly resolves the C-criterion gap Classic Pyramid lost on in ADR-0003 |
| TS-9 | Assertions target simulated pointer/drag events and resulting DOM/state, never private signals or internal methods | CLAUDE.md prose | Judgment call, no linter can enforce "tests behavior not implementation" |
| TS-10 | A thin Playwright e2e suite covers only the critical path (sign in → create box → drag/reorder → reload → verify persisted state), not exhaustive scenarios | Agent/task def | Scope is deliberately narrow — e2e is the most expensive tier per ADR-0003's grid (criteria E/F) |

## C. Test hygiene

| ID | Rule | Surface | Notes |
|---|---|---|---|
| TS-11 | Arrange-Act-Assert structure per test | CLAUDE.md prose | Bill Wake's original pattern; not mechanically enforceable |
| TS-12 | Hermetic tests — no shared mutable fixtures or execution-order dependency | Hook | Run test suites in randomized order (`pytest-randomly` / Vitest's equivalent) as a CI check — order-dependence surfaces as a real, catchable failure, not just a style preference |
| TS-13 | No numeric coverage gate in CI | Hook config (explicit absence) | Coverage tooling stays diagnostic — deliberately *not* configured as a pass/fail threshold; documented here so it isn't added later without revisiting this decision |
| TS-14 | Test names follow `test_<unit>_<scenario>_<expected>` | CLAUDE.md prose | Convention-level, not doctrine — no canonical source found for this specifically |

## D. Agentic verification policy

Operationalizes ADR-0003 Part 2's adopted policies with concrete, actionable rules.

| ID | Rule | Surface | Notes |
|---|---|---|---|
| TS-15 | Grounded execution — tests actually run and pass — is required before a task counts as done; Claude's own assessment that code "looks correct" is never sufficient | Hook | The same blocking gate as TS-1, extended to be the completion criterion, not just a check |
| TS-16 | No mandatory test-first-before-implementation ordering. Tests and implementation may be iterated in either order; the task isn't done until both exist and TS-15 passes | Agent/task def | Evidence showed ordering barely matters, cost does (ADR-0003 Part 2) — this rule exists specifically to prevent a future default toward rigid TDD |
| TS-17 | Writer/reviewer separation is required for high-risk logic: any change touching fractional-order calculation, auth/allowlist checks, or cross-slice authorization boundaries gets its tests reviewed or written by a fresh-context or different-model pass before being considered complete | Agent/task def | Point 4 defines the concrete subagent/role split — this rule states *when* it's required, not *how* it's wired |
| TS-18 | Scoped test execution by default — an agent working within one slice runs that slice's tests during its inner loop; full-suite runs are reserved for pre-merge/CI | Agent/task def | Matches TDAD's finding that scoped/impact-driven testing beats both full-suite-every-time and un-scoped "just do more testing" instructions |
| TS-19 | Flaky-test handling: a failing test is rerun once (bounded) before being treated as environmental; a test whose result flips across 2 consecutive runs is marked flaky and tracked, never silently ignored or retried indefinitely | Hook + Agent/task def | Hook: bounded CI retry logic. Agent/task def: an agent encountering a flip must flag it, not quietly re-run until green |

## Summary: rule count by surface

| Surface | Count | Rules |
|---|---|---|
| Hook | 6 | TS-1, TS-7, TS-12, TS-13, TS-15, TS-19 (partial) |
| Skill | 1 | TS-5 |
| Agent/task def | 9 | TS-2, TS-3, TS-4, TS-8, TS-10, TS-16, TS-17, TS-18, TS-19 (partial) |
| CLAUDE.md prose | 3 | TS-9, TS-11, TS-14 |
| N/A (tooling decision, documented not enforced) | 1 | TS-6 |

Consistent with ADR-0002's pattern: the prose tier stays small (3 rules), most of the weight sits on Agent/task def because testing discipline for this app is mostly about *how a coding task gets scoped and completed*, not something a linter alone can check — Hook coverage handles what can be made deterministic (test execution itself, order-randomization, retry bounds), and Skill is reserved for the one place a full mechanical check isn't cost-proportionate (TS-5's periodic real-DynamoDB verification).

## Note on what this closes

TS-3 resolves ADR-0001's criterion E (vertical-slice's missing verifiability seam) concretely, not just in principle. TS-1/TS-2/TS-4 give ADR-0002's fail-fast rules (CC-16–CC-19) an actual enforcement path — those rules made failure *visible in code*; these tests are what exercises the failure paths. TS-17 gives ADR-0001's criterion D (dependency-direction discipline, vertical-slice's other accepted tradeoff) a partial compensating control: cross-slice authorization boundaries are exactly the kind of undisciplined reach ADR-0001 flagged as a risk to watch, and TS-17 puts a second, fresh-context check on exactly that surface.