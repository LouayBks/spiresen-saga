# Spec: Map & View lifecycle, and CRUD coverage (raised during #36)

Format per `DOC/templates/spec_design_template.md` (ADR-006). Owns the create/read/update/delete behaviors that no other spec covered — chiefly **Map deletion**, the **View** operations beyond the create/delete rules in `alternate-views.md`, and a **user profile read** — and records, for every entity in the app, which spec owns each of its four operations. **Deliberately does not decide any DynamoDB key, item or transaction shape** (ADR-006's amendment; the physical side is `ADR-007`).

No ticket of its own: found during #36's data-foundation design when the CRUD API the implementation ticket (#57) must build turned out to have no behavioral spec behind several of its endpoints.

## Objective

Make sure every entity the backend stores has an explicit, testable specification for creating, reading, updating and deleting it — closing the gaps a coverage check found — before an implementation ticket builds endpoints for behaviors nobody wrote down.

## Context

- Ticket: raised during #36; implemented by #57. Related: #35 (`accounts-and-auth.md`), #40 (View/Map switching UI), #45 (trash bin — recovery of deleted content), #54 (account deletion, deferred).
- Updates once accepted: nothing in `application_architecture.md` beyond what `ADR-007` and `data_cartography.md` already carry.
- Cites, doesn't redecide: `alternate-views.md` (View floor/ceiling, per-View positions and Links), `accounts-and-auth.md` (Map create and rename, membership), `map-visibility.md` (who may read), `node-link-lifecycle.md` (Node/Link create and delete).

## CRUD coverage matrix

`—` means the operation does not exist for that entity by design. **Gap** means it was unspecified before this spec; the row closing it is named.

| Entity | Create | Read | Update | Delete |
|---|---|---|---|---|
| **User** | first login (`accounts-and-auth` BHV-1, 8) | own profile: **gap → BHV-12** | username, handle (`accounts-and-auth` BHV-9–11) | deferred, not designed (#54, `accounts-and-auth` CON-5) |
| **Map** (top-level) | first login / "+ New Map" (`accounts-and-auth` BHV-1, 7) | list mine: **BHV-1**; open (`map-visibility` BHV-4–6) | rename (`accounts-and-auth` BHV-4); visibility (`map-visibility` BHV-2) | **gap → BHV-3–6** |
| **View** | default with the Map (`alternate-views` BHV-1); add another: **BHV-7** | switch (`alternate-views` BHV-5) | rename: **BHV-8**; reorder: **BHV-9** | **BHV-10** (floor rule: `alternate-views` BHV-3) |
| **Node** | `node-link-lifecycle` BHV-1 | open (`window-system`, `content-authoring` BHV-8) | title/date/size: `node-link-lifecycle` BHV-14; position: `alternate-views` BHV-4 | `node-link-lifecycle` BHV-5, 6 |
| **Link** | `node-link-lifecycle` BHV-7 | rendered per View (`alternate-views` BHV-5) | label: `node-link-lifecycle` BHV-13 (type: delete and recreate, CON-2) | `node-link-lifecycle` BHV-12 |
| **Article** | `content-authoring` BHV-1 | `window-system` BHV-8 | `content-authoring` BHV-5 | `content-authoring` BHV-13 (**gap, closed**) |
| **Gallery image** | `content-authoring` BHV-9 | `window-system` BHV-9 | caption: `content-authoring` BHV-15 (**gap, closed**) | `content-authoring` BHV-14 (**gap, closed**) |
| **Cover image** | `content-authoring` BHV-10 | rendered on the tile | replace/clear: `content-authoring` BHV-16 (**gap, closed**) | `content-authoring` BHV-16 |
| **Note / URL** | `content-authoring` BHV-4 | rendered | edit: `content-authoring` BHV-18 (**gap, closed**) | `content-authoring` BHV-18 (**gap, closed**) |
| **URL preview** | `content-authoring` BHV-11 | rendered on the tile | — (fetched once, CON-11) | removed with its URL: `content-authoring` BHV-18 |
| **Membership** | provisioning only (`accounts-and-auth` CON-3) | authorization only | — (roles inert in v1) | with its Map (BHV-4) |
| **Handle claim** | with the profile | — | change (`accounts-and-auth` BHV-9) | released on change |

Moving a Node from one Map to another (re-parenting) is **not** covered and is a deliberately deferred v2 feature (see `node-link-lifecycle.md` Out of scope).

## Decisions

### Deleting a Map

**An owner can delete a top-level Map they own, including their last one.** Deletion is destructive and has no undo in v1 (`content-authoring.md` CON-5: no versioning; recovery is the unscheduled trash-bin idea, #45), so the UI names what will be lost — every Node, nested Map, View, Link, article body and gallery reference under it — and requires confirmation, the same rule `node-link-lifecycle.md` applies to deleting a Node.

The Map stops existing for everyone **at once**: it can no longer be opened (a read answers 404, as for any Map that does not exist), it disappears from the public gallery, and its memberships are gone. Physically removing everything beneath it may finish a moment later, but nothing beneath it stays reachable in the meantime.

Deleting a Map does not touch the owner's other Maps, their profile, or their handle. A user with no Maps left is a normal state: the first-login provisioning does **not** run again (they already exist), and "+ New Map" creates a fresh seeded one.

Uploaded image files are only *referenced* by Maps. Deleting a Map (or removing an image or article) makes them unreachable through the app immediately, but the stored files themselves may linger until a cleanup mechanism exists — tracked with #54, not designed here.

### Views: adding, naming, ordering, deleting

- **A new View** takes the default name `"View {n}"` (renamable), is placed last in the Map's order, gives every existing Node a position in it **copied from the View that was active when it was created**, and starts with **no Links**. With no Links it renders as a grid (`window-system.md` CON-6) until the owner draws one; the copied positions are preserved underneath and become the freeform arrangement the moment a Link exists.
- **A View's order is its position among the Map's Views**: a contiguous integer from 1 to the number of Views (at most 3), no gaps and no ties. Reordering moves one View and shifts the others; there is no fractional ordering — with at most three items it would add machinery for no benefit.
- **Deleting a View** removes its own Links and its Nodes' positions in it, leaves every Node and every other View untouched, and closes the order gap. The last remaining View cannot be deleted (`alternate-views.md` BHV-3).

### Reading your own Maps and profile

Listing "Your Maps" returns only Maps the caller is a member of, oldest first, in bounded pages, each with its name and visibility. A user's own profile read returns their email (taken from their sign-in token, never stored), username and handle.

## Expected behaviors (`BHV-*`)

| ID | Statement | Testability check | Notes |
|---|---|---|---|
| BHV-1 | WHEN a signed-in user lists their Maps, THE backend SHALL return exactly the top-level Maps they are a member of, oldest first, in bounded pages, each with its name and visibility. | ✅ — integration test: two users with different Maps, assert each list contains only their own, in creation order, and pages when there are more than one page's worth | Extends `map-visibility.md` BHV-11 with scope and paging. |
| BHV-2 | IF an unauthenticated requester asks for the Maps list, THEN THE backend SHALL reject the request. | ✅ — integration test: request without credentials, assert 401 | |
| BHV-3 | WHEN an owner requests deletion of a top-level Map, THE UI SHALL show a confirmation naming what will be lost (its Nodes, nested Maps, Views, Links, articles and gallery references) before the backend deletes anything. | ✅ — component test: trigger delete, assert the confirmation copy renders and no request has fired yet | Mirrors `node-link-lifecycle.md` BHV-5. |
| BHV-4 | WHEN an owner confirms deletion of a top-level Map, THE backend SHALL delete the Map together with everything beneath it (Nodes, nested Maps, Views, Links, article bodies) and its memberships. | ✅ — integration test: build a Map with a nested Map, a Link and an article, delete it, assert every part is no longer readable and the owner's other Map is unchanged | |
| BHV-5 | WHEN a Map is deleted, THE backend SHALL answer any subsequent read of it as not found (404), and THE public gallery SHALL no longer list it. | ✅ — integration test: publish a Map, delete it, assert a read gives 404 and the gallery excludes it | Immediate for reads; physical cleanup may complete later. |
| BHV-6 | IF a requester who is not an owner of a Map requests its deletion, THEN THE backend SHALL reject it with 403 and delete nothing. | ✅ — integration test: as a non-member, attempt delete, assert 403 and the Map intact | Same 403 as `accounts-and-auth.md` BHV-6. |
| BHV-7 | WHEN an owner adds a View to a Map that has fewer than 3, THE backend SHALL create it named `"View {n}"`, ordered last, with every existing Node given a position in it copied from the active View, and with no Links. | ✅ — integration test: add a View, assert its name, order, that each Node's position equals its position in the source View, and that it has no Links | Ceiling: `alternate-views.md` BHV-2. |
| BHV-8 | WHEN an owner renames a View, THE backend SHALL persist the new name without changing the View's order, Links or positions. | ✅ — integration test: rename a View, assert only the name changed | |
| BHV-9 | WHEN an owner moves a View to a new position among the Map's Views, THE backend SHALL persist the new order so that orders remain contiguous from 1 with no ties. | ✅ — integration test: with three Views, move the third to first, assert orders are 1, 2, 3 and the others shifted | |
| BHV-10 | WHEN an owner deletes a View that is not the Map's last, THE backend SHALL remove that View's Links and its Nodes' positions in it, and close the order gap, leaving every Node and every other View unchanged. | ✅ — integration test: delete the middle of three Views, assert its Links are gone, the other two Views' data is untouched, and orders are 1, 2 | Only-remaining-View rule: `alternate-views.md` BHV-3. |
| BHV-11 | IF a requester who is not an owner tries to add, rename, reorder or delete a View, THEN THE backend SHALL reject it with 403. | ✅ — integration test: each of the four operations as a non-member, assert 403 | |
| BHV-12 | WHEN a signed-in user requests their own profile, THE backend SHALL return their email (from their sign-in token), username and handle. | ✅ — integration test: request the profile, assert the three values | Email is never stored (`accounts-and-auth.md` CON-12). |

## Constraints (`CON-*`)

| ID | Statement | Notes |
|---|---|---|
| CON-1 | Deleting a Map MUST be owner-only and MUST require an explicit confirmation step in the UI; there is no undo in v1. | Recovery is the unscheduled trash-bin idea (#45). |
| CON-2 | A deleted Map's identifier MUST NOT be reused. | Ids are unguessable and random, so this holds by construction; stated so a future id scheme can't break it. |
| CON-3 | Deleting a Map MUST NOT alter the owner's other Maps, profile or handle. | |
| CON-4 | After a Map is deleted, nothing that was beneath it MUST be reachable through the app, even if physical removal is still in progress. | Stored image files MAY linger until a cleanup mechanism exists (#54). |
| CON-5 | A Map's Views MUST always be ordered 1..n with no gaps or ties, n between 1 and 3. | Fractional ordering is deliberately not used. |
| CON-6 | A user with zero Maps MUST be a valid state, and MUST NOT trigger first-login provisioning again. | Provisioning is keyed to the user being new, not to having no Maps. |

## Open questions

None blocking. Cleanup of unreferenced image files in storage is real but unscheduled (#54).

## Out of scope

No implementation (#57). No physical storage shape or transaction mechanics (`ADR-007`). No Map duplication/forking, no moving a Node between Maps, no transferring Map ownership, no account deletion (#54). No UI design for the delete confirmation, the View controls or the Maps list beyond BHV-3's requirement that the confirmation names what is lost (#40).
