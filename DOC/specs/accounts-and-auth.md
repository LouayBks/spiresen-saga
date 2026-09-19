# Spec: User accounts & auth flow (#35)

Format per `DOC/templates/spec_design_template.md` (ADR-006). Owns the *flow*: how a Google-SSO login ties a person to a Map they own, whether the owner/editor/viewer role model is live in v1, what replaces the `ALLOWED_WRITER_SUBS` placeholder, and the minimal account-settings surface. **Deliberately does not decide any DynamoDB key/item shape** — that's #36 ("Data foundation"), sequenced after this spec specifically so the schema gets built once. This spec states the requirements #36's storage design must satisfy (durable identity, one canonical Map name, atomic first-login provisioning, no hot-partition regression) without prescribing PK/SK syntax to meet them. Does not touch `naming.md`'s terminology decisions (uses **Map**, not Saga, for the entity, per `naming.md` CON-1/CON-4) and does not redecide Map visibility (public/private/unlisted) — that stays the open item `application_architecture.md` already tracks, since it isn't one of this ticket's tasks.

**Revision note (2026-09-19):** a newly created top-level Map (first-login provisioning and "+ New Map" alike) is no longer empty — it is seeded with two placeholder Nodes joined by one Link, in its default View, so it starts in freeform layout (`window-system.md` CON-6: a View with at least one Link is freeform; with none, grid) and gives the owner something to react to. Decided during #36's data-model discussion. The placeholder content itself is copy defined in application code, not in this spec; the placeholders are ordinary Nodes and the Link an ordinary Link, deletable like any other (deleting the last Link returns that View to grid).

**Revision note (2026-09-19):** users now have a **username** and a **handle**. Raised while specifying the public gallery (`map-visibility.md`), which needs a public, chosen label for a Map's owner — the earlier "email and display name come from the JWT, nothing is stored" position gave a gallery nothing it could safely show. The handle is unique across all users and restricted to lowercase letters, digits and underscores; the username is free text. Both are editable, both are public where a Map is public, and identity stays the Cognito `sub` (CON-1): a handle is a label, never an identity. Account settings (below) and BHV-5 change accordingly.

## Objective

Decide how a signed-in user becomes tied to Map ownership, whether the owner/editor/viewer role model is live in v1, what replaces the `ALLOWED_WRITER_SUBS` placeholder, and the minimal account-settings surface — as requirements #36 can build against, not as a schema.

## Context

- Ticket: #35. Related: #22 (backlog prioritization tracker; no content of its own).
- Feeds #36 ("Data foundation — DynamoDB table + Saga/Box/Link/User CRUD"), which implements "per-Saga write authorization against the User↔Saga membership record" and User CRUD per its own task list. This spec supplies the requirements that implementation must satisfy (below); #36 owns the actual key design, item shape, and transaction mechanics.
- Updates once accepted: `application_architecture.md`'s "Auth" section (drops the `ALLOWED_WRITER_SUBS`-is-being-replaced language in favor of the membership-based mechanism below, still without naming concrete keys) and its "Open items / TBD" list, which loses "can a user have more than one Saga/Map from day one" (resolved: yes, see Decisions) but keeps "is there still a platform-admin role" and "can Maps be private" as still open — neither is one of this ticket's tasks.
- Reuses the User↔Map membership relationship already named in `application_architecture.md` ("Sagas: multi-tenancy" section, role: owner | editor | viewer) and carried forward by `naming.md`'s rename — not redecided here, only built on.
- No implementation — this is the design pass; Cognito/backend wiring is #36's job, per the parent ticket's own "Out of scope" note.

## Decisions

### Sign-up: auto-provision on first authenticated request, not a Cognito trigger

**A person becomes a User, with a first Map they own, the first time a backend request carries a valid Cognito JWT for an identity the system hasn't seen before — not via a Cognito Post-Confirmation/Post-Authentication Lambda trigger.** Federated (Google) sign-ins skip Cognito's confirmation step entirely, so Post-Confirmation never fires for them, and Post-Authentication fires on *every* login, not just the first — either one needs its own new-user-detection logic layered on top, which a backend-side check already gives for free. Doing it in the same FastAPI request path the app already authenticates every call through avoids a second, Cognito-console-configured code path with its own deploy/test story, for a project whose stated goal is cheap and fast to build. There is deliberately no separate onboarding wizard/form in v1 — the first Map is created with a default name (below), renamable afterward from account settings.

**Anticipated requirement for #36:** this provisioning step (creating the User and their first Map together) MUST be atomic and idempotent with respect to a retried or concurrent first request for the same identity — it must be impossible for a flaky client retry or a race between two near-simultaneous first requests to produce two Users or two Maps for the same person. How that's guaranteed (a conditional write, a transaction, something else) is #36's call.

### Identity: the Cognito `sub`, never the Google email

**A User is tied to their Cognito `sub` claim, not their email.** Email can change or be reused across accounts at the identity-provider level; `sub` is the stable identifier Cognito itself assigns a federated user and never reassigns. This is a flow/identity decision (what makes two logins "the same person"), independent of how #36 chooses to store it.

### A user can own multiple Maps from day one — the role model exists conceptually but stays inert

**A user can own more than one Map in v1 — ownership is per-Map, not a single slot per user.** This matches `naming.md` BHV-2's own "Your Maps" nav copy, which was already written as a plural list, not a single item. Beyond the one auto-provisioned at first login (Decisions above), the owner can create additional Maps explicitly (a "+ New Map" affordance, e.g. in the nav's "Your Maps" list) — each new Map is created with them as its sole owner, independent of and unaffected by their other Maps. A newly created (non-first) Map defaults to the fixed name `"My Map"`, not the given-name-personalized default reserved for first-login onboarding — the owner explicitly chose to create it, so an immediate rename is expected rather than a special-cased greeting.

**The owner/editor/viewer membership relationship has to support more than one member per Map eventually, for a future sharing feature — but v1 exposes no invite/share flow that would ever produce an `editor`/`viewer` membership.** Multiple Maps per user is about ownership cardinality (one person, many Maps, each with one owner); it is not the same axis as sharing (one Map, many members) — this spec resolves the former for v1 and explicitly leaves the latter inert. **Every membership created in v1 has role `owner`.** This directly matches `boxes-plan.md`'s existing "owner-only editing" line — it isn't a new restriction, just the first place that line gets a concrete behavioral consequence. Whether/how a future sharing feature turns editor/viewer on is explicitly not decided here.

### `ALLOWED_WRITER_SUBS` is replaced by a membership check, in the same change, no transition period

**A write to a Map (or anything under it) is authorized if and only if the requesting person has a membership on that Map** — the existing User↔Map relationship #36's own task list already targets ("per-Saga write authorization against the User↔Saga membership record, replacing `ALLOWED_WRITER_SUBS`"). Since v1 only ever creates `owner` memberships, this is currently equivalent to a plain existence check, not real role-branching — that distinction only starts to matter once a future ticket turns on sharing. `ALLOWED_WRITER_SUBS` is deleted in the same change that ships this check, not deprecated alongside it — there is currently exactly one real writer (Lou), whose access is re-created as a single owner membership rather than staged behind a feature flag or dual-checked during a migration window.

### Username and handle

**A User has a username and a handle, both owner-editable.**

- **Handle** — unique across every user, lowercase only: it MUST match `[a-z0-9_]+`, 3–30 characters (the length bounds are a proposal; the character set is decided). Lowercase-only means uniqueness needs no case-folding. It is the user's public label wherever they are named (the public gallery, and any future profile or link).
- **Username** — free-text display name, not unique, up to 50 characters (proposal). It may repeat across users and carries no identity or authorization meaning.
- **At first login (no onboarding wizard in v1),** the handle is **generated** — a fixed prefix plus random lowercase/digit characters, retried on collision — and the username defaults to the Google given-name claim (falling back to the generated handle if absent). Both can be changed straight away in account settings. **The handle is never derived from the email or a name claim**: doing so would publish personal data the user never chose to share.
- **Public exposure:** a user's handle and username are shown where their Map is publicly listed (`map-visibility.md`). Their email is never shown on any public surface.
- **Changing a handle releases the old one immediately** for anyone else to claim. That is the simple rule, with the usual squatting/impersonation trade-off; a small set of system-reserved handles is rejected outright (the list is code, not spec).

**Anticipated requirement for #36:** handle uniqueness MUST hold under concurrency — two users claiming the same handle at once must yield exactly one winner — and changing a handle must be atomic (the old is released and the new claimed together, never both or neither). How that's guaranteed (a uniqueness record claimed in a transaction, or otherwise) is #36's call.

### Minimal account-settings surface: identity display + username/handle + rename-the-open-Map

**v1's account-settings surface is: the signed-in user's Google-linked email, shown read-only; their editable username and handle; and a single editable field for whichever Map is currently open's display name.** Switching between a user's multiple Maps is the nav's "Your Maps" list (`naming.md` BHV-2), not an account-settings concern — account settings only ever acts on the one Map currently open, the same way it would if a user had exactly one. No avatar/profile-photo display, no delete-account action, no leave-Map action — each either has no v1 feature to attach to (no collaborators exist yet to leave a Map from) or is real, unresolved scope on its own (account deletion needs a cascade-delete story for all of an owner's Maps, not designed here). Sign-out itself is the standard Cognito/Amplify sign-out call — a mechanical integration detail, not a design decision this spec needs to make.

**A Map has an owner-editable display name, defaulted at creation.** The default reads as `"{givenName}'s Map"` from the Google profile's given-name claim, falling back to a fixed `"My Map"` if that claim is absent — "Map," per `naming.md` CON-4, which reserves "Map" as the countable per-item noun for an individual collection. **Anticipated requirement for #36:** this name MUST be a single canonical value shared by every member of a Map, not a per-viewer/per-membership value — renaming it must change what every member sees, not just the renamer's own view. Where that value physically lives is #36's decision, not this spec's.

## Expected behaviors (`BHV-*`)

| ID | Statement | Testability check | Notes |
|---|---|---|---|
| BHV-1 | WHEN a request carries a valid Cognito JWT for an identity the system has never seen, THE backend SHALL create that person as a User and create one Map they own — seeded with two placeholder Nodes joined by one Link in its default View — before returning the request's own response. | ✅ — integration test: call an authenticated endpoint with a JWT for a never-seen identity, assert a User and an owned Map both now exist and the Map has exactly two Nodes and one Link (via the API, not a raw storage assertion) | Seeding per the 2026-09-19 revision. |
| BHV-2 | IF a request carries a JWT for an identity that already exists as a User, THEN THE backend SHALL NOT create an additional User or Map. | ✅ — integration test: call the same endpoint twice with the same identity, assert exactly one owned Map exists after both calls | Also covers concurrent/retried first requests — see the atomicity requirement in Decisions. |
| BHV-3 | WHEN the backend auto-provisions a user's first Map, THE backend SHALL set its display name from the Google profile's given-name claim (`"{givenName}'s Map"`), or `"My Map"` if that claim is absent. | ✅ — unit test with a mocked claim set containing a given name, and one without, asserts each resulting name | |
| BHV-4 | WHEN the owner submits a new value in the account-settings Map-name field, THE backend SHALL persist it as the currently-open Map's new display name, visible to every member on next read, without affecting the owner's other Maps. | ✅ — integration test: submit a new name for one Map, then read that Map and a second Map owned by the same user, assert only the targeted Map's name changed | |
| BHV-5 | THE account-settings surface SHALL render the signed-in user's email as non-editable text, and their username and handle as editable fields. | ✅ — component test: render account settings, assert the email has no edit control and the username and handle each have one | Revised 2026-09-19 (was: email and display name both read-only). |
| BHV-6 | IF a write request targets a Map (or anything under it) for which the requesting person has no membership, THEN THE backend SHALL reject the request. | ✅ — integration test: authenticate as a user with no membership on a given Map, attempt a write, assert 403; repeat as a member, assert success | Supersedes `ALLOWED_WRITER_SUBS`-based authorization entirely. |
| BHV-7 | WHEN the owner requests a new Map, THE backend SHALL create it with them as its sole owner and the default name `"My Map"`, seeded the same way as a first Map (two placeholder Nodes, one Link), independent of their existing Maps. | ✅ — integration test: an existing user requests a new Map, assert a second owned Map now exists, named `"My Map"`, seeded with two Nodes and one Link, with the first Map's data unchanged | |
| BHV-8 | WHEN the backend auto-provisions a user, THE backend SHALL assign a unique, well-formed generated handle, and SHALL set the username from the Google given-name claim, or from the handle if that claim is absent. | ✅ — integration test: provision two never-seen identities, assert distinct handles matching `[a-z0-9_]+`, and usernames set as described | Never derived from email or a name claim (CON-12). |
| BHV-9 | WHEN a user submits a new handle that is well-formed, not reserved and not held by anyone else, THE backend SHALL make it their handle and release their previous one. | ✅ — integration test: change a handle, assert it reads back, then have a second user claim the released one successfully | |
| BHV-10 | IF a submitted handle is malformed, reserved or already held by another user, THEN THE backend SHALL reject the request with a 4xx and leave the user's handle unchanged. | ✅ — integration test: submit `Has-Caps`, a reserved handle and a taken handle, assert each is rejected and the original handle unchanged | |
| BHV-11 | WHEN a user submits a new username, THE backend SHALL persist it without a uniqueness check. | ✅ — integration test: two users set the same username, assert both succeed | |
| BHV-12 | WHEN two users submit the same free handle at the same moment, THE backend SHALL grant it to exactly one of them. | ⚠️ needs a concurrent-request fixture — integration test firing two simultaneous claims, assert exactly one 2xx | Anticipated requirement for #36; the real-table hand-check applies (transactions under `moto`, TS-5). |

## Constraints (`CON-*`)

| ID | Statement | Notes |
|---|---|---|
| CON-1 | A User's identity MUST resolve from the Cognito `sub` claim, MUST NOT resolve from email. | Email can change/be reused at the IdP; `sub` is Cognito's stable federated-user identifier. Binding on #36's implementation, doesn't prescribe how `sub` is stored. |
| CON-2 | `ALLOWED_WRITER_SUBS` MUST be removed in the same change that introduces membership-based write authorization (BHV-6) — MUST NOT run alongside it as a fallback or during a migration window. | One real writer today; re-created as one owner membership, not staged. |
| CON-3 | v1 MUST create only `owner` memberships — MUST NOT create `editor`/`viewer` memberships through any v1 UI or API path. | Keeps a future sharing feature additive rather than a migration. |
| CON-4 | The backend MUST NOT cap the number of Maps a user owns, and creating an additional Map MUST NOT require or default to sharing it with anyone else. | Reverses the first draft's CON-4. Ownership cardinality (many Maps per user) is orthogonal to sharing (many members per Map, still inert per CON-3). |
| CON-5 | The account-settings surface MUST NOT expose account-deletion or leave-Map actions in v1. | Deferred — an owner's sole-Map cascade-delete story isn't designed here. |
| CON-6 | A Map's display name MUST be one canonical value visible to every member, MUST NOT vary per member/viewer. | An anticipated requirement for #36's storage design, not a storage decision itself. |
| CON-7 | First-login provisioning (User + owned Map) MUST be atomic and idempotent — a retried or concurrent first request for the same identity MUST NOT produce two Users or two Maps. | Anticipated requirement for #36; the mechanism (transaction, conditional write, etc.) is #36's decision. |
| CON-8 | A handle MUST match `[a-z0-9_]+` and be 3–30 characters. | Character set decided; length bounds proposed. |
| CON-9 | A handle MUST be unique across all users at all times, and changing one MUST be atomic (old released and new claimed together). | Anticipated requirement for #36. |
| CON-10 | A username MAY be shared by several users, and MUST NOT be used for identity or authorization. | Identity is the `sub` (CON-1). |
| CON-11 | The system MUST reject a code-defined set of reserved handles. | The list is code, not spec. |
| CON-12 | A handle MUST NOT be derived from an email or a name claim, and an email MUST NOT appear on any public surface. | Privacy: the user chooses what becomes public. |

## Open questions

- Whether/how a Google profile photo is stored or displayed — not needed for v1's read-only identity display (BHV-5 covers text fields only); left for whoever eventually wants an avatar.
- Map visibility (public/private/unlisted) — resolved in `map-visibility.md` (2026-09-19), not here: default `private`, three states, governs reading only. Nothing in this spec's write-authorization or membership decisions changes.
- What the eventual sharing flow looks like once CON-3 is revisited (an invite step, how a pending invite is represented, etc.) — no ticket assigned yet; this spec only establishes that v1 deliberately stops short of it. Multi-Map ownership itself (CON-4) is not part of this open question — that's resolved for v1, above.
- The exact nav UI/UX for switching between and creating a user's multiple Maps ("Your Maps," the "+ New Map" affordance) — this spec fixes the behavioral contract (BHV-7) and where it lives (nav, not account settings), not its visual design.
- **The concrete storage shape for everything decided here (how a User is keyed, where a Map's display name lives, how the provisioning atomicity requirement is implemented) is explicitly left to #36** — flagged here, not as a gap in this spec, but so #36's author knows CON-1/CON-6/CON-7 are binding requirements handed down from this ticket, not free design choices.

## Out of scope

No DynamoDB key design, item shape, or transaction mechanics — that's #36's decision to make once, informed by CON-1/CON-6/CON-7 above. No implementation of any kind (Cognito configuration, actual FastAPI routes/dependencies) — also #36, per #35's own "Out of scope" note. No collaboration/sharing UI or API (invite an editor/viewer) — CON-3 keeps the role model inert in v1. No visual/UX design for the "Your Maps" nav list or the "+ New Map" affordance — BHV-7 fixes the behavior, not the UI. No account-deletion or leave-Map flow — CON-5. No decision on Map visibility (public/private/unlisted) — pre-existing open item, not a task on this ticket. No avatar/profile-photo handling.
