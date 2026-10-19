# ADR-009: Feature planning and traceability — specs as the business layer, a per-feature design, every decision linked to its source

**Status:** Proposed (owner to accept on merge of `dev/louay/onboarding-guide`).
**Date:** 2026-10-17
**Scope:** what is planned for a feature before its first sub-branch is built, where that planning lives, and how code and tests are linked back to it. Applies to every feature in `DOC/architecture/delivery_sequence.md`, starting with #57. Amends ADR-004 Part 5, ADR-006 and ADR-008 WS-2/WS-8; each of those carries a dated amendment pointing here.

## Context

The design phase (#22, #36) produced the product's behaviour as specs, cut **by domain**: nine files in `DOC/specs/` holding 100 behaviours (`BHV-*`) and 82 constraints (`CON-*`), each behaviour with a testability check, plus 26 access patterns (`AP-*`) in `data_cartography.md`. ADR-008 then cut delivery **by feature**, and a feature draws on several specs. Three things connect the two today, and all three stop short:

- **The feature issue body** (WS-8) lists tasks and points to whole spec files. #57 cites no behaviour ID; #55 cites two.
- **`delivery_sequence.md`** maps access patterns to features, but not behaviours or constraints.
- **The sub-branch plan** (`plan_template.md`, AW-5) is the only plan, and it covers one layer.

As a result:

1. **No one can say which behaviours a feature must deliver.** Each sub-branch session selects them from its own reading of a spec. A gap, or an overlap between two features, goes unnoticed.
2. **Nothing designs how the layers meet.** The API contract, what infra hands to the backend, and the flows that cross layers are rediscovered by each sub-branch session. The frontend sub-branch would read the backend code to learn the API.
3. **No design is reviewed before code exists.** Module structure, call sequences and cloud architecture are only seen once written, when changing them costs a rework session. The repo has two diagrams, both of the data model.
4. **Nothing links code or tests back to a decision.** A reviewer can check the code that exists, but not whether everything the feature owes is there, or where a given choice came from.

## Decision

| ID | Rule |
|---|---|
| FP-1 | **The specs are the business layer, and a feature never restates them.** A feature's expected behaviour is the set of spec rows it delivers, cited by ID. If a feature needs a behaviour or constraint that no spec states, or a different one, the spec is amended first, in its own commit, and the feature cites the new row. |
| FP-2 | **Every feature gets a folder, `DOC/features/<issue>-<slug>/`, written before its first sub-branch plan.** It holds `manifest.md`, `design.md` and `tests.md`, built from the templates in `DOC/templates/feature_*_template.md`. It is the first commit on the feature branch. |
| FP-3 | **The manifest selects; it doesn't describe.** It lists every spec row (qualified ID, FP-6) and access pattern the feature delivers, the sub-branch that implements each, and the rows it explicitly leaves to a later feature. It may add one or two end-to-end scenarios that chain rows across specs, written only as a sequence of cited IDs. It has no behaviour text of its own. |
| FP-4 | **The design covers each layer the feature touches, one element per heading, each with an ID and a source.** Element IDs are `<issue>-<layer><n>`, with layer `I` (infra), `B` (backend) or `F` (frontend): `57-B3`. Each element cites where it comes from: a manifest row, a spec, an ADR, or "decided here", followed by the reason. Per layer: **infra:** an architecture diagram, the resources and permissions, and the outputs handed to the backend; **backend:** a module diagram of the slice, a sequence diagram per endpoint or flow, the API contract (method, path, request, response, errors) and the data access (access patterns, items written, which writes are transactions); **frontend:** the element inventory (components, their states, interactions, animations with trigger, duration and easing), a state diagram for each component with non-trivial state, and the API calls each element makes, citing the backend contract's IDs. |
| FP-5 | **The test plan turns each spec row's testability check into a planned test.** One line per behaviour: test name, level (unit, integration, component, end-to-end, or a real-environment gate per TS-5) and file. Every behaviour has at least one test. Constraints are covered by the tests of the behaviours that must respect them (ADR-006). |
| FP-6 | **Everything is linked by IDs.** Spec rows are cited outside their own file as `<spec-file-stem>.<ID>` (`alternate-views.BHV-2`), because behaviour numbers restart in each spec. The chain runs spec row → manifest → design element → code → test: code entry points name the design element they implement (CC-34), tests name the behaviour they prove (TS-20), and each sub-branch commit and the PR description list the design IDs they cover. A trace check script verifies the chain: every behaviour has a test, every cited ID exists, every manifest row has a design element. |
| FP-7 | **Reviews follow the layers.** The owner reviews the manifest, since it is a product-scope decision (`CODEOWNERS` covers `DOC/features/`). `plan-reviewer` reviews the design when any element touches a sensitive area (AW-4, extended from plans to designs). The sub-branch plan then cites the design elements it implements instead of re-deriving them. |
| FP-8 | **The depth scales with the feature.** A **light** plan, for a feature on one layer with at most about 15 manifest rows, is: the manifest, that layer's design, and the test plan. Within it, a sequence diagram is still required for every multi-item transaction; other diagrams are optional. Every other feature gets the full set. |
| FP-9 | **The design is checked against what was built.** After a sub-branch merges into the feature branch, its diagrams are compared with the code. Any difference is fixed in the code, or recorded in the design as a decision with its reason. |
| FP-10 | **Diagrams are Mermaid, inside the markdown.** GitHub renders Mermaid in PRs and VS Code renders it in preview, so a reviewer sees the diagram where they review the design. `agentic_workflow_processes.md` already uses it. The two existing PlantUML data diagrams stay as they are. |

## Options considered

1. **Status quo: the issue body plus one plan per sub-branch.** Rejected for the four reasons in Context.
2. **A feature brief that restates the expected behaviour.** Rejected: the specs already hold it, with testability checks (ADR-006). A second copy drifts from the specs, and nothing says which copy wins. FP-1 and FP-3 keep one source.
3. **One file per feature instead of a folder.** Rejected: the manifest is reviewed by the owner on its own, the design grows large with diagrams, and the test plan is read by a different audience. Three files keep each reviewable.
4. **Full UML for every feature.** Rejected: the cost is real for a feature with one layer and a dozen rows. FP-8 keeps the one diagram that catches the most expensive mistakes (multi-item transactions) mandatory everywhere.
5. **PlantUML for the new diagrams.** Rejected: it needs a render step to SVG, and the rendered file lags its source. Mermaid is reviewed where the PR is.
6. **A reference on every function.** Rejected: it buries the code in IDs, and most of them go stale. Entry points only (CC-34) are few and stable, and the trace check covers the rest.
7. **Leave mechanical defects to design review.** Rejected as a design goal: unused imports are already caught by `ruff`, and import cycles or forbidden dependencies can be enforced by an import-contract check in CI. Design review is for what tools can't see: responsibilities, duplication, call loops, data flow.

## Consequences

- **More planning before code, less rework after.** Planning a feature now takes its own sessions (Opus, Plan Mode). The bet is that the rework it avoids costs more: contracts rediscovered per sub-branch, frontend built on a guessed API, transactions redesigned after review. This is a FinOps hypothesis to measure with the token ledger, as ADR-008's was.
- **A one-off coverage matrix is needed first.** Every behaviour and constraint is assigned to exactly one feature, or marked deferred, in `delivery_sequence.md`. Its gaps (rows no feature owns) are a design finding in their own right.
- **Rules amended:** ADR-004 Part 5 (a feature planning stage before sub-branch plans; plan review extended to designs), ADR-006 (qualified IDs; spec first), ADR-008 WS-2 and WS-8 (the feature plan is the plan of record; the issue body links to it), AW-5, the new AW-28 and AW-29, TS-20 and CC-34.
- **Not built yet:** the trace check script (FP-6) and the as-built comparison (FP-9). Both need code to run against, so they are built with #57's first sub-branch. Until then both checks are done by hand in review.
- **Build cards are not decided here.** The rabbit hop trial (headless relay sessions, documented on its own branch) adds a fourth layer, cards cut from this design, as part of the trial's input. If the trial is adopted, cards join this ADR by amendment.
