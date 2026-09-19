# Spec: Map visibility (private / unlisted / public) (raised during #36)

Format per `DOC/templates/spec_design_template.md` (ADR-006). Owns *who may read a Map*, how a Map becomes discoverable, and how visibility relates to the membership role model. **Deliberately does not decide any DynamoDB key, item or index shape** — that is #36's, recorded in `ADR-007`; this spec states the requirements storage must satisfy without prescribing how.

No ticket of its own yet: this is the inherited open item `application_architecture.md` ("Open items / TBD") and `accounts-and-auth.md` ("Open questions") both carried since the multi-tenancy work — "can a Map be private" — surfaced as a real gap while designing #36's read paths, and settled here in discussion (2026-09-19) rather than left implicit in the membership model.

## Objective

Decide who can read a Map and everything under it, whether and how a Map is listed for others to find, what the default is, and how this sits alongside the owner/editor/viewer membership roles — before #36 builds read authorization and the "see other users' Maps" use case on top of an undefined concept.

## Context

- Driving discussion: #36 (data foundation). Related: #35 (`accounts-and-auth.md`), which owns write authorization and the membership role model; #23 (Map-as-Code), whose export/import payload should carry the visibility value.
- Updates once accepted: `application_architecture.md`'s "Auth" section (replaces "whether every Saga is public, or … private/unlisted, is an open question") and its "Open items / TBD" list (drops "can Sagas be private"); `accounts-and-auth.md`'s open question on Map visibility (points here instead).
- Reuses, doesn't redecide: `accounts-and-auth.md` CON-3 (v1 creates only `owner` memberships) and BHV-6 (a write without membership is rejected with 403).

## Decisions

### Three states, set on the top-level Map

**A top-level Map has exactly one visibility: `private`, `unlisted`, or `public`.**

- **`private`** — only members of the Map can read it. To everyone else it does not exist.
- **`unlisted`** — anyone who has the Map's link can read it, signed in or not, but it appears in no listing. The standard "anyone with the link" model (the same idea as an unlisted video or a secret gist). It is **not** access control: whoever holds the link can forward it, and the only revocation is switching the Map back to `private`.
- **`public`** — readable by anyone with the link, signed in or not, **and** listed in the public gallery of Maps that anyone can browse.

**The default is `private`**, for every Map at creation — first-login provisioning and "+ New Map" alike, including the seeded placeholder Nodes (`accounts-and-auth.md`). A Map only becomes reachable by others through an explicit owner action.

### Visibility governs reading only, never writing

Write authorization is unchanged: a write requires a membership on the Map (`accounts-and-auth.md` BHV-6). A `public` Map is readable by everyone and writable only by its owner. Only an owner may change a Map's visibility (in v1, the only members are owners).

### Visibility is an explicit attribute of the Map, not a membership

"Viewer: all users" could have been modeled as a wildcard membership. It is deliberately **not**: that would make visibility implicit (its state would be the presence or absence of a membership record, invisible on the Map itself), it cannot express `unlisted` (readable by link but not listed) without a second wildcard, and it would mix two different concepts — *who is a named participant* (membership, still inert beyond `owner` in v1) and *who may look* (visibility). The membership role model is unchanged; visibility is a separate field on the Map that the Map itself reports.

### One visibility per Map tree; nested Maps inherit

Visibility is a property of the **top-level** Map. A nested Map (`window-system.md`) is part of its root and inherits whatever the root says — there is no per-group or per-Node visibility. Reading any Node, Link, View or content at any depth is decided by the root Map's visibility.

### What a reader sees

A non-member who is allowed to read (unlisted or public) gets the whole Map read-only: its Nodes, Links, Views and the content behind every Node (article, gallery, note, URLs). There is no partial or redacted view in v1. A read-only viewer sees no editing affordances and cannot change anything.

### The public gallery

The gallery lists `public` Maps only, newest-published first, in bounded pages. Each entry carries the Map's name and enough to open it — **not** the owner's identity: no name or email is stored for users (`accounts-and-auth.md` decides identity comes from the JWT), and exposing it is a privacy decision this spec does not make (see Open questions). A Map's place in the gallery is set by when it last became public: making it public records that moment; making it `unlisted` or `private` and public again resets it.

### Revocation

Changing a Map to a more restrictive visibility takes effect **immediately for opening it**: the next read by a non-member is refused. The gallery listing may briefly lag behind (an entry can linger for moments after a Map is made `unlisted` or `private`), but following that entry to the Map must fail. Nothing about the Map's content is cached at a shared layer in a way that outlives a visibility change.

### Existence is not revealed for `private` Maps

A read of a `private` Map, or anything under it, by someone who isn't a member is answered as **not found (404)**, not forbidden (403) — the system does not confirm that a private Map exists. Writes by non-members keep `accounts-and-auth.md` BHV-6's 403.

### `unlisted` rests on the id being unguessable

Because an `unlisted` Map's only protection is its link, the top-level Map identifier MUST be unguessable — random, not derived from a name, email or counter.

## Expected behaviors (`BHV-*`)

| ID | Statement | Testability check | Notes |
|---|---|---|---|
| BHV-1 | WHEN a top-level Map is created (first-login provisioning or "+ New Map"), THE backend SHALL set its visibility to `private`. | ✅ — integration test: provision a user and create a second Map, assert both report `private` | Includes the seeded placeholder Nodes — nothing is reachable by others until the owner acts. |
| BHV-2 | WHEN an owner sets a Map's visibility to `private`, `unlisted` or `public`, THE backend SHALL persist that value on the Map. | ✅ — integration test: set each value in turn, read the Map back as its owner, assert it reports the value | |
| BHV-3 | IF a requester who is not an owner of a Map attempts to change its visibility, THEN THE backend SHALL reject the request. | ✅ — integration test: as a non-member, attempt to set `public`, assert 403 and the visibility unchanged | Same 403 as `accounts-and-auth.md` BHV-6. |
| BHV-4 | WHEN a requester who is not a member (signed in or not) reads an `unlisted` or `public` Map, or any Node, Link, View or content under it at any depth, THE backend SHALL return it read-only. | ✅ — integration test: with no credentials, read a public Map's contents, a nested Node's content, and an unlisted Map's contents; assert success | Anonymous read is intended (matches `application_architecture.md`: "no auth needed to view"). |
| BHV-5 | IF a requester who is not a member reads a `private` Map, or anything under it, THEN THE backend SHALL answer as not found (404). | ✅ — integration test: as a non-member and as an anonymous requester, read a private Map and a Node's content under it, assert 404 for both | Does not confirm existence. |
| BHV-6 | WHEN a member reads a Map, THE backend SHALL return it regardless of its visibility. | ✅ — integration test: as the owner, read a `private`, an `unlisted` and a `public` Map, assert success for all | |
| BHV-7 | WHEN a requester who is not a member attempts to write to a `public` or `unlisted` Map, THE backend SHALL reject it with 403. | ✅ — integration test: anonymous and non-member writes against a public Map, assert rejection and no change | Visibility never grants write. Same rule as `accounts-and-auth.md` BHV-6. |
| BHV-8 | WHEN a requester asks for the public gallery, THE backend SHALL return `public` Maps only, newest-published first, in bounded pages. | ✅ — integration test: create private, unlisted and public Maps, assert only the public one is listed; create several public Maps, assert order and paging | Never includes `unlisted` or `private` Maps. |
| BHV-9 | WHEN a Map's visibility changes from `public` to `unlisted` or `private`, THE backend SHALL refuse a subsequent read of it by a non-member. | ✅ — integration test: make a public Map private, immediately read it as a non-member, assert 404 | Immediate for opening. The gallery listing itself may lag briefly (see Revocation). |
| BHV-10 | WHEN a Map becomes `public` from any other visibility, THE backend SHALL record that moment as its published time, used to order the gallery. | ✅ — integration test: publish A, then B, then republish A, assert gallery order B before A | |
| BHV-11 | WHEN an owner lists their own Maps, THE backend SHALL report each Map's visibility. | ✅ — integration test: list Maps with mixed visibilities, assert each entry carries its visibility | Lets the UI show a lock or link indicator. |
| BHV-12 | IF a request would set visibility on a nested Map, THEN THE backend SHALL reject it. | ✅ — integration test: attempt to set visibility on a nested Map, assert 4xx and the root's visibility unchanged | Nested Maps inherit; there is nothing to set. |

## Constraints (`CON-*`)

| ID | Statement | Notes |
|---|---|---|
| CON-1 | A top-level Map's visibility MUST be exactly one of `private`, `unlisted`, `public`, MUST default to `private`, and MUST NOT be absent. | |
| CON-2 | Visibility MUST be a property of the top-level Map only; a nested Map MUST inherit it and MUST NOT carry its own. | |
| CON-3 | Visibility MUST NOT be modeled as a membership (no wildcard/anonymous-user membership); the owner/editor/viewer role model is unchanged. | Keeps "who is a participant" and "who may look" as separate concepts. `accounts-and-auth.md` CON-3 still holds. |
| CON-4 | Write authorization MUST depend on membership only; visibility MUST NOT grant, widen or narrow write access. | |
| CON-5 | A top-level Map's identifier MUST be unguessable (randomly generated, not derived from a name, email or counter). | `unlisted` access rests on the link alone. |
| CON-6 | A non-member's read of a `private` Map MUST NOT reveal that it exists (not-found, never forbidden). | Writes are excluded: BHV-7 keeps 403. |
| CON-7 | The public gallery MUST NOT list `unlisted` or `private` Maps, and MUST be answerable in bounded pages **without a table scan**. | Anticipated requirement for #36. |
| CON-8 | A public gallery entry MUST NOT expose the owner's identity in v1. | No name/email is stored for users; exposing identity is not decided here. |
| CON-9 | A read authorization decision MUST be answerable from a single lookup of the top-level Map's record, before any of the Map's contents are loaded — a refused read MUST cost no more than that lookup. | Anticipated requirement for #36. Prevents an anonymous requester from making the backend load a large private Map only to discard it. |
| CON-10 | Changing visibility MUST be a single narrow write to that one Map's record, and MUST take effect for opening the Map immediately. | Anticipated requirement for #36. The gallery listing may lag briefly (BHV-9's note). |
| CON-11 | The visibility value MUST be part of a Map's own reported state, readable by a member in the same request that returns the Map. | Lets the UI show it without another call. |

## Open questions

- **Owner attribution in the gallery** — CON-8 withholds it for v1. Showing "by <name>" needs either storing a public display name or a user-chosen handle; not designed here.
- **Moderation of the public gallery** — a public listing invites abuse (spam, harmful content). A report/takedown path is real, unresolved scope; nothing in this spec provides one, and anyone able to sign in can publish. Flagged before the gallery ships, not designed here.
- **Search-engine indexing** — whether `unlisted` pages should carry a `noindex` signal and whether `public` ones should be indexable. A frontend/infra concern, not a modeling one.
- **Link rotation for `unlisted`** — the only revocation is switching to `private`; a Map's link never changes. A "regenerate link" action would need a second identifier and is not offered.
- **A "signed-in users only" audience** — deliberately not a fourth state; add only if a real need appears.
- **Exact confirmation UX** when making a Map `public` — a UI detail.

## Out of scope

No implementation. No DynamoDB key, item or index shape, and no transaction mechanics — that is #36's decision, informed by CON-7, CON-9 and CON-10 (recorded in `ADR-007`). No gallery UI, no visibility picker UI, no account-settings changes. No collaboration/sharing invites (`accounts-and-auth.md` CON-3 keeps the role model inert). No moderation, owner attribution, or forking/copying of another user's Map.
