# Delivery sequence — the post-design backlog (#22)

The concrete order for the tickets planned after the design phase (#36 done). Reasoning and rules (`WS-*`) are in `ADR/ADR-008-work-slicing-and-sequencing.md`; this file is the living plan and should be updated as features merge. Behavior comes from `DOC/specs/`, the access patterns (`AP-*`) from `DOC/architecture/data_cartography.md`.

**Status:** accepted by the owner 2026-09-20; GitHub issues re-scoped to match (#57 reused as Foundation, labels unchanged: `NEW`).

## Features

One row = one issue = one PR into `int` (WS-1). Sub-branches run infra → backend → frontend (WS-2). "Gate" is a real-environment check that must pass on the `dev` table before merge (`testing_strategy.md` TS-5: `moto` does not cover these faithfully).

| # | Feature (issue) | Sub-branches | Waits for | Gate |
|---|---|---|---|---|
| 0 | **Promote the spec phase** (`int` → `main`) | none | — | Human merge; prod deploy workflows run behind the prod reviewer gate. Unblocks `/review` on PRs. |
| 1 | **Foundation** (#57, re-scoped) | kernel (models, one-file-per-entity mapper, limits, ids, repository skeleton, fail-closed dependency aliases, `risk-paths.json` patterns — a human-only governance edit, proposed in the plan, kernel `CLAUDE.md`) → table infra → users / first-login provisioning (AP-1, 18, 22) | 0 | AP-1 on the real table |
| 2 | **Sign-in and accounts** (#55, re-scoped; absorbs #56) | Cognito infra → auth (JWT/JWKS, AP-19 read decision, AP-4 write membership) → sign-in and account-settings UI | 1; the human-only Google OAuth client | — |
| 3 | **Canvas and Nodes** (#37, re-scoped) | open-a-Map and Node/Link CRUD (AP-3, 5–9, 14, 15) → canvas core | 2 | AP-6, 7, 9 on the real table |
| 4 | **Maps and Views** (#40, re-scoped) | Map list/rename/delete/visibility, Views (AP-2, 10, 12, 21, 23, 24, 25) → nav menu, View switcher (top level), Map settings | 3 | — |
| 5 | **Content** (#39, re-scoped) | media-bucket infra → content (AP-11, 13, 16, 17, upload URL, oEmbed) → authoring UI | 3 | — |
| 6 | **Windows** (#38, re-scoped) | add-inside (AP-26) → window system, visualizations, breadcrumb, nested-window View switcher | 3 | — |
| 7 | **Public** (#41, re-scoped; absorbs the gallery) | gallery-index infra → gallery (AP-20) → read-only pages, not-found, landing page | 4 | AP-20 paging and order on the real table; **gallery exposure held until moderation (#52) is decided** |

**Merge order:** 0, 1, 2, 3, then 4 / 5 / 6 in parallel, then 7.

## Why this order

- **1 before everything:** every slice imports the kernel; the table is created by its first user (WS-3).
- **2 before 3:** nothing is testable through a real UI without a signed-in user. Auth is high-risk (AW-6), so it merges early and gets reviewed while little depends on it.
- **3 is the hub:** four features (4, 5, 6, 7) render on the canvas. That serial dependency is inherent to the product, not chosen (WS-6).
- **4 / 5 / 6 in parallel:** independent of each other once the canvas exists. Only Content carries infra; while its branch is pushed and unmerged, the other two must branch from it or stay unpushed (WS-4), or its bucket lands first as a small sub-PR (WS-5).
- **7 last:** it carries the release gate.

## Boundary calls made

- **Open-a-Map (AP-3)** sits in feature 3 because the canvas cannot render without it; feature 4 keeps list, rename, delete and visibility.
- **The nested-window View switcher** sits in feature 6, not 4, because it needs the window.
- **Views** sit in feature 4 with Maps (both Map-level); **the gallery** sits in feature 7 with the public surfaces (`map-visibility.md` owns it).
- **Foundation and sign-in are separate PRs** — foundation has no user-facing surface, and merging them would leave nothing mergeable until the whole chain is done (WS-5a).

## Ticket mapping

| Ticket | Becomes | Disposition |
|---|---|---|
| #57 | Feature 1 (Foundation) | Re-scoped; its other tasks are redistributed to features 3–7 |
| #55 | Feature 2 | Re-scoped; absorbs #56 and the auth tasks of #57 |
| #37 | Feature 3 | Re-scoped; absorbs the Node/Link/open-Map tasks of #57 |
| #40 | Feature 4 | Re-scoped; absorbs the Map/View tasks of #57 |
| #39 | Feature 5 | Re-scoped; absorbs the content tasks of #57 and the bucket from #53 |
| #38 | Feature 6 | Re-scoped; absorbs add-inside (AP-26) |
| #41 | Feature 7 | Re-scoped; absorbs the gallery task of #57 and the index from #53 |
| #53, #56 | — | Closed as superseded, each with a comment mapping its tasks to features 1, 2, 5, 7 |
| #43, #44 | — | Closed as delivered (specs merged with #36) |
| #52 | — | Unchanged; gates feature 7's gallery |
