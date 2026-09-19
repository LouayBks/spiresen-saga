# Architecture decisions — personal site

Working notes from planning, kept here so they survive the move to local dev / Claude Code. Update this file as decisions change; it's meant to be the source of truth for "why is it built this way."

## Goals

**Spiresen is the umbrella brand and root domain (spiresen.com), not this product.** This repo builds one specific thing that will live on a subdomain of spiresen.com: a place to store articles, papers, presentations, and designs — and a place where *other people* keep their own such collections too, not just Lou. **Subdomain settled as `athar.spiresen.com`** (prod) / `int.athar.spiresen.com` (int) / `dev.athar.spiresen.com` (dev), as of the minimal-deploy-pipeline work (2026-09-16/17); `int` was briefly on `dev.athar.spiresen.com` before the third `dev` environment claimed that hostname (2026-09-17). **Naming (`DOC/specs/naming.md`, 2026-09-18):** the product brand is **Saga** (temporary, and moving the hostname to match is deferred — #42); the data-model entities are **Map** (a user's named collection) and **Node** (one canvas item), deliberately decoupled from the brand so a future rename doesn't force a schema migration.

- Not just a static page — a working CRUD app with a drag-and-drop canvas of nested "boxes" you can rearrange and fill.
- Multi-tenant: each user has one or more **Maps** (their own named collections), each with its own Nodes, Links and Views, and each `private`, `unlisted` or `public` (`DOC/specs/map-visibility.md`). See "Maps: multi-tenancy" below.
- Eventually a sibling subdomain for an "agentic playroom" (separate product, same root domain, same infra patterns).
- Cheap to run at low-to-moderate traffic, low maintenance, fast to build.

## Stack

- Frontend: Angular (Angular CDK drag-drop for the nested-box canvas), compiled and served as static assets.
- Backend: FastAPI, wrapped with Mangum, running on Lambda behind API Gateway (HTTP API, not REST API — cheaper, lower latency).
- Data: DynamoDB, single-table design.
- Files/media: S3, referenced by key from DynamoDB items — never store binary blobs in item bodies.
- Delivery: CloudFront in front of both the S3-hosted frontend and (optionally) the API, with ACM for TLS.
- DNS: Route 53 hosted zone on the root domain; site lives on a subdomain, future projects get their own subdomains off the same zone.
- IaC: Terraform, modularized (dns, static-site, api) so each subdomain project reuses the same modules instead of duplicating config.
- CI/CD: GitHub Actions running Terraform + build/deploy steps.
- Auth: Google SSO via Cognito (first-class supported provider — this is why we dropped LinkedIn, which requires a custom OIDC shim and isn't worth the friction for a single-admin site).

## Why Lambda, not an always-on instance

Personal-site traffic is spiky/low-volume. Pay-per-request (Lambda + API Gateway HTTP API) keeps this near-free at this scale versus paying for an idle instance. Cold starts (low hundreds of ms to a couple seconds for Python) are a non-issue for this use case. Revisit only if the agentic playroom subdomain needs heavier, long-running compute.

## Why S3 + CloudFront still works even though the app is "dynamic"

The static part is the *compiled* Angular bundle (JS/CSS/HTML) — that's what sits in S3/CloudFront. The app calls the FastAPI backend at runtime for CRUD. Static hosting for the shell + dynamic API behind it is the standard SPA-on-AWS split; it doesn't conflict with the app feeling interactive.

## Auth

- **Identity:** Cognito User Pool with Google as the identity provider (built-in, no shim needed). A user is identified by their Cognito `sub`, never their email (`DOC/specs/accounts-and-auth.md`). Every user also has a free-text **username** and a unique **handle** (`[a-z0-9_]`, 3–20 characters) — the public labels shown where their Map is public. The infrastructure is ticket #56; nothing of it exists yet.
- **Read access follows the Map's visibility** (`DOC/specs/map-visibility.md`): `private` — members only, and everyone else gets *not found*; `unlisted` — anyone with the link, signed in or not, not indexed by search engines; `public` — anyone with the link, and listed in the public gallery. New Maps are `private`. Because unauthenticated reads are intended, the JWT is verified inside FastAPI with authentication optional on read routes, not by an API Gateway authorizer that rejects anonymous callers.
- **Write access is authorization, not authentication, and it happens at the Map level:** a write requires a membership on the top-level Map above the thing being written. v1 creates only `owner` memberships; visibility never grants write. The old single-admin allowlist (`ALLOWED_WRITER_SUBS`) was a placeholder in earlier design docs and never shipped in code; the design no longer uses it.

## DynamoDB schema (single-table)

**Status:** accepted — `ADR/ADR-007-physical-data-layout.md` (decision, options weighed, gates, consequences) is the rationale, and `DOC/architecture/data_cartography.md` maps it entity by entity (access patterns, invariants, limits). It supersedes the earlier box-tree sketch (`PK: BOX#… SK: BOX#/ARTICLE#/…`), which is no longer used.

**Principles.** Every read is a `GetItem`, `Query` or `BatchGetItem` on a key computable from the request — the application never scans (the Lambda's IAM policy omits `Scan`). **Opening a Map is one `Query` that returns only what the canvas draws**: a small "tile" per Node, the Views and the Links — not every Node's full text. A Node's full content (`DETAIL`, plus its article if any) lives in its own partition and is fetched only when the Node is opened; projection cannot achieve this because DynamoDB bills reads on the size of the items read, not the data returned. Multi-item writes with invariants (first-login provisioning, counters, exclusivity, one-Link-per-pair, handle claims) are `TransactWriteItems`. No write may create the thing it targets except an explicit create (every update carries an existence condition, every content write also checks its tile), and a Node is readable only if all its ancestor Nodes still exist.

| Item | PK | SK |
|---|---|---|
| User profile (`username`, `handle`) | `USER#{sub}` | `PROFILE` |
| Membership (`role`) | `USER#{sub}` | `MEMBER#{rootMapId}` |
| Handle claim (uniqueness) | `HANDLE#{handle}` | `HANDLE` |
| Map meta (`name`, counters; root also `visibility`, `ownerSub`) | `MAP#{mapId}` | `META` |
| View | `MAP#{mapId}` | `VIEW#{viewId}` |
| Node tile | `MAP#{mapId}` | `NODE#{shortId}` |
| Link | `MAP#{mapId}` | `LINK#{viewId}#{lo}#{hi}` |
| Node detail | `CONTENT#{nodeId}` | `DETAIL` |
| Article body | `CONTENT#{nodeId}` | `ARTICLE` |
| Public gallery index (sparse **GSI1** on the root META) | `GSI1PK = MAP#PUBLIC` | `GSI1SK = {publishedAt}#{mapId}` |

Notes:
- A **nested Map** is the same shape one level down: its `mapId` is its parent Node's id.
- **Ids** are dot paths: a top-level Map has an unguessable random id, a Node is `{parentMapId}.{shortId}`. The owning top-level Map is always the first segment, so authorizing a write or read on a deeply nested Node needs no tree walk.
- **Positions** live inside the tile as a map keyed by `viewId`, so dragging a Node is one narrow write and item count never scales with Nodes × Views.
- **Order** of a Map's Views is a plain contiguous integer (1–3); there is no fractional ordering anywhere.
- **Media** (images) lives in S3; items hold only the S3 key. Image bytes never pass through the API.

## Maps: multi-tenancy

A **Map** is a user's named collection; a user can own several, and each belongs to (or is shared by) specific users.

**Core decision: Nodes never store a userId.** Only the User↔Map relationship carries identity. Everything below that — the entire Node/Link/View tree — stays completely identity-agnostic.

Why: if a Node pointed at a user directly, then every permission change, added collaborator, or ownership transfer would mean rewriting every Node in that tree. Pushing ownership one level up means a Map can be transferred, shared, or have its access list changed with a single write to a small membership record — nothing inside the tree has to move. It also keeps reads exactly as cheap as before: a Node doesn't need to know who's allowed to view it, only what the Map above it says (its visibility, plus whether the caller has a membership).

The membership relationship supports `owner | editor | viewer`, but **v1 creates only `owner` memberships** and exposes no sharing flow. Visibility (who may *look*) is a separate, explicit attribute of the Map, deliberately not modelled as a membership (`map-visibility.md` CON-3).

**Id namespacing:** every Node id is `{parentMapId}.{shortId}` (deeper Nodes nest the path), so a Node's owning top-level Map is derivable from its own id with no lookup — needed to authorize a write on a deeply nested Node. Content (article, detail) is keyed by its Node's id, so it authorizes off the same first segment and needs no separate owner attribute.

## Nodes, Links, Views and nested Maps

The product surface and its rules are in `DOC/frontend/boxes-plan.md` (UI) and `DOC/specs/*.md` (behavior); this is the schema-side summary.

- **No stored `kind`.** A Node's presentation — info, gallery, article, map, or click-through — is computed at read time from what it contains: 2+ children → map; exactly 1 child → click-through; images present → gallery; an article attached → article; otherwise info (`content-authoring.md` CON-7). At most one of children / gallery / article at a time. Video is not a hosted type — it is a link with one fetched thumbnail preview.
- **Size** is an explicit, owner-chosen `{w, h}` in grid units, identical across Views (`box-sizing.md`).
- **A Node with children contains a real nested Map**, using the same Node/Link/View schema as the top level — its own id is the nested Map's identifier. It is fetched lazily, one request per level, only when opened; there is no depth cap and no flattened "group children" summary.
- **`Link`** joins two Nodes of the same Map, belongs to exactly one View, is undirected, at most one per node pair per View, with a `type` (`theme | timeline | soft`) and an optional label (`node-link-lifecycle.md`).
- **`View`**: 1–3 per Map, each owner-arranged, each with its own Node positions and Links (`alternate-views.md`, `map-lifecycle.md`).
- **Layout is derived, never stored:** a View with no Links renders as a grid; one with at least one Link renders freeform (`window-system.md` CON-6).
- **Moving a Node into a different Map** (re-parenting) is a deferred v2 feature.

## Terraform module layout

```
infra/
  modules/
    dns/           # Route 53 hosted zone + records, ACM cert (wildcard, us-east-1 for CloudFront)
    static-site/   # S3 bucket + CloudFront distribution for a compiled SPA
    api/           # Lambda + API Gateway HTTP API (+ DynamoDB table, GSI, media bucket — #53; Cognito — #56)
  environments/
    prod/          # wires the modules together for this subdomain
```

Each future subdomain (agentic playroom, etc.) becomes a new `environments/<name>` that reuses `dns`, `static-site`, and `api` rather than copy-pasting infra.

## Naming

Root domain: **spiresen.com** — settled, this is the umbrella brand. "Spire" (a cathedral spire, Gothic architecture, the historic/ethereal register) + "-sen" (the Danish/Norwegian patronymic suffix, as in Andersen/Hansen/Jensen). Reads as a constructed surname rather than a borrowed word, in the same register as how real consulting/advisory firms (Roland Berger, Oliver Wyman) are just literally someone's real name — the trust comes from what's built under the name over time, not from the word itself.

This repo's product (the canvas app) lives on a **subdomain** of spiresen.com — currently **athar.spiresen.com** (prod) / **int.athar.spiresen.com** (int) / **dev.athar.spiresen.com** (dev), 2026-09-16/17. Its brand name is now **Saga** (`naming.md` dropped "Athar", already in use elsewhere); changing the hostname to match is infra work deferred until the first features ship (#42). The **entities** in code and schema are **Map** and **Node** — never "Saga" or "Box" — so a further brand change never touches the data model.

This is the *first* domain under the Spiresen umbrella — treat it as its own root domain with its own Route 53 hosted zone (not a subdomain of something else at the AWS level; the "subdomain" language above refers to the hostname `athar.spiresen.com`, which is a record within spiresen.com's own hosted zone). If a future project (the agentic playroom, etc.) gets its own separate domain rather than a `*.spiresen.com` subdomain, that's just another instantiation of the same `dns` / `static-site` / `api` Terraform modules against a new root domain — nothing about the module design assumes shared DNS across projects.

## Open items / TBD

- **Data foundation is designed, not built.** #36 is the design pass (specs, `ADR-007`, `data_cartography.md`). Building it is split: **#53** (DynamoDB table, GSI, IAM, media bucket — ops), **#56** (Cognito + Google sign-in — ops), **#57** (persistence and CRUD API), **#55** (sign-in and account UI).
- **Infra CI/CD plumbing is built (#10/#11)**, and `static-site`/`api` are now built too (minimal-deploy-pipeline work, 2026-09-16/17, since extended to three environments): `infra/modules/{dns,static-site,api}` + `infra/environments/{prod,int,dev}` (Route 53 zone, wildcard ACM cert, S3+CloudFront frontend, Lambda+HTTP-API backend — no DynamoDB table yet — #53), `infra/bootstrap` (Terraform remote-state S3 bucket, native S3 state locking), and `.github/workflows/{infra-deploy,infra-deploy-int,infra-deploy-dev,frontend-deploy,frontend-deploy-int,frontend-deploy-dev}.yml` (plan-on-PR for prod/int; apply on push to `main`→prod reviewer-gated, `int`→int unattended, any `dev/**` branch→dev unattended with no PR gate at all — `dev` exists specifically to surface deploy/permission failures before the `int` PR stage, AW-24). All three environments currently share one AWS account and one CI OIDC role — fully separate per-environment AWS identity is a known future item (ADR-005), not yet built.
- Whether the API sits behind its own CloudFront distribution or is called directly via the API Gateway invoke URL (custom domain on API Gateway is the cleaner option now that the domain is settled).
- Angular CDK drag-drop wiring for arbitrarily nested Nodes (recursive component, `boxes-plan.md` §6).
- Whether future projects live as `*.spiresen.com` subdomains or get entirely separate domains — decide before the second project starts, since it changes whether the wildcard ACM cert here gets reused.
- **Moderation** of public Maps (#52) — must be decided before the public gallery ships; it will also settle whether a platform-admin role exists distinct from Map ownership.
- Account deletion, leave-Map and data export (#54); trash-bin recovery (#45); domain rename to match the Saga brand (#42); how a Map presents on narrow (mobile) screens — no spec decides it yet.
- *Resolved:* a user can own several Maps; a Map can be private/unlisted/public (`map-visibility.md`); the sizing, content-type and View models (the Stage-A specs).
