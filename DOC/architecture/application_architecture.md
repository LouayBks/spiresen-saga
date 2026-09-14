# Architecture decisions — personal site

Working notes from planning, kept here so they survive the move to local dev / Claude Code. Update this file as decisions change; it's meant to be the source of truth for "why is it built this way."

## Goals

**Spiresen is the umbrella brand and root domain (spiresen.com), not this product.** This repo builds one specific thing that will live on a subdomain of spiresen.com: a place to store articles, papers, presentations, and designs — and, potentially, a place where *other people* keep their own such collections too, not just Lou. Working name for this specific product/subdomain: **Saga** (an Arabic-rooted alternative, **Sīra**, is also on the table — see Naming). The final subdomain name is not yet decided; refer to it as "Saga" in code/schema regardless of what the marketing name ends up being, per the handoff notes below.

- Not just a static page — a working CRUD app with a drag-and-drop canvas of nested "boxes" you can rearrange and fill.
- Multi-tenant: each user has one or more Sagas (their own named collection). This was a late addition — see the "Sagas: multi-tenancy" section below, which supersedes the original single-owner assumption baked into earlier parts of this doc.
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

- Cognito User Pool, Google as the identity provider (built-in, no shim needed). This part is unchanged by multi-tenancy — Google SSO authenticates *a* user; it says nothing about which Sagas they can touch.
- Read access to a public Saga's content is public (no auth needed to view). Whether every Saga is public, or a Saga can be private/unlisted, is an open question — see the handoff doc.
- Write access is authorization, not authentication, and it now happens at the **Saga** level, not via a single global allowlist. See "Sagas: multi-tenancy" below — the old single-admin allowlist (`ALLOWED_WRITER_SUBS`) was a placeholder for this and is being replaced as part of the current implementation task (see `HANDOFF.md`).

## DynamoDB schema (single-table)

Pattern: each "box" is a container. Querying a box's own partition key returns everything inside it — child boxes AND content items — in one request, with no GSI needed. This mirrors a pattern used before (`SPACES#{id}` / `THEMES#{id}` style), extended so a box can recursively contain other boxes.

```
PK: BOX#{boxId}   SK: BOX#{childBoxId}        -> nested box link.        attrs: title, order, thumbnail
PK: BOX#{boxId}   SK: ARTICLE#{articleId}     -> article link.           attrs: title, excerpt, thumbnail, order
PK: BOX#{boxId}   SK: PRESENTATION#{presId}   -> presentation link.      attrs: title, thumbnail, order
PK: BOX#{boxId}   SK: DESIGN#{designId}       -> design link.            attrs: title, thumbnail, order

PK: ARTICLE#{articleId}      SK: DETAILS      -> full body/blocks (fetched only when opened)
PK: PRESENTATION#{presId}    SK: DETAILS      -> full slide data
PK: DESIGN#{designId}        SK: DETAILS      -> full canvas data
PK: BOX#{boxId}              SK: DETAILS      -> optional box-level config beyond what's on the parent link item
```

Notes:
- Display fields (`title`, `thumbnail`, `order`) are denormalized onto the link item itself so rendering a box's contents never touches a `DETAILS` record. Trade-off: renaming/re-thumbnailing an item means two writes (the link item under its parent, and the `DETAILS` item) — don't forget the second write in the update handler.
- `order` should be a fractional/lexicographic string (e.g. `"a0"`, `"a1"`, then `"a0m"` to insert between them), not a plain integer — otherwise every drag-and-drop reorder rewrites every sibling instead of just the moved item.
- Media (images, PDFs, deck assets) lives in S3; DynamoDB items hold only the S3 key.
- **Superseded:** this section originally described a single global `BOX#ROOT` singleton and "no SITE# partition — single-tenant." That assumption no longer holds now that multiple users each need their own collection. See the next section.

## Sagas: multi-tenancy

A **Saga** is a user's named collection — it's what `BOX#ROOT` used to be, except there can be many of them, each belonging to (or shared by) specific users.

**Core decision: boxes never store a userId.** Only the User↔Saga relationship carries identity. Everything below that — the entire box-containment tree, exactly as designed above — stays completely identity-agnostic, unchanged in shape.

Why: if a box pointed at a user directly, then every permission change, added collaborator, or ownership transfer would mean rewriting every box in that tree. Pushing ownership one level up means a Saga can be transferred, shared, or have its access list changed with a single write to a small membership record — nothing inside the box tree has to move. It also keeps reads exactly as cheap as before: a box doesn't need to know who's allowed to view it, only whether the Saga above it is public.

```
PK: USER#{userId}   SK: SAGA#{sagaId}      -> membership: role (owner | editor | viewer), joined_at
PK: SAGA#{sagaId}   SK: BOX#{boxId}        -> top-level box of that saga (same link-item shape as the BOX# pattern above)
```

Everything from `PK: BOX#{boxId}` downward is unchanged — a Saga simply replaces the old singleton `BOX#ROOT` as the top-level parent.

**Box-id namespacing:** mint every box id as `{sagaId}.{shortId}` (not a bare UUID). This makes a box's owning Saga derivable from its own id, with no extra lookup — needed to authorize a write on a deeply nested box without walking back up the tree to find out which Saga it belongs to.

**Content records need to carry their Saga too:** an `ARTICLE#{id}` / `PRESENTATION#{id}` / `DESIGN#{id}` `DETAILS` record should store a `sagaId` attribute at creation time, for the same reason — so a write to that content can be authorized against Saga membership without an extra tree walk.

Concrete implementation task list, open questions, and which files to touch are in `HANDOFF.md` — that file is the one to hand to a coding agent; this section is background for *why*, not a step-by-step.

## Terraform module layout

```
infra/
  modules/
    dns/           # Route 53 hosted zone + records, ACM cert (wildcard, us-east-1 for CloudFront)
    static-site/   # S3 bucket + CloudFront distribution for a compiled SPA
    api/           # Lambda + API Gateway HTTP API + DynamoDB table
  environments/
    prod/          # wires the modules together for this subdomain
```

Each future subdomain (agentic playroom, etc.) becomes a new `environments/<name>` that reuses `dns`, `static-site`, and `api` rather than copy-pasting infra.

## Naming

Root domain: **spiresen.com** — settled, this is the umbrella brand. "Spire" (a cathedral spire, Gothic architecture, the historic/ethereal register) + "-sen" (the Danish/Norwegian patronymic suffix, as in Andersen/Hansen/Jensen). Reads as a constructed surname rather than a borrowed word, in the same register as how real consulting/advisory firms (Roland Berger, Oliver Wyman) are just literally someone's real name — the trust comes from what's built under the name over time, not from the word itself.

This repo's product (the box-canvas, multi-tenant Saga app) lives on a **subdomain** of spiresen.com — name not yet decided. Working name in code and docs: **Saga**. An Arabic-rooted alternative under consideration: **Sīra** (the classical Arabic term for a recorded life-narrative — the closest genre-for-genre match to "saga"). Do not hardcode either as the actual subdomain hostname until it's confirmed; keep the entity name "Saga" in code/schema regardless, since that's a data-model term now, somewhat decoupled from the final product name.

This is the *first* domain under the Spiresen umbrella — treat it as its own root domain with its own Route 53 hosted zone (not a subdomain of something else at the AWS level; the "subdomain" language above refers to the eventual hostname, e.g. `saga.spiresen.com`, which is still a record within spiresen.com's own hosted zone). If a future project (the agentic playroom, etc.) gets its own separate domain rather than a `*.spiresen.com` subdomain, that's just another instantiation of the same `dns` / `static-site` / `api` Terraform modules against a new root domain — nothing about the module design assumes shared DNS across projects.

## Open items / TBD

- Final subdomain name (Saga vs. Sīra vs. something else) and whether it's `<name>.spiresen.com` or its own separate domain.
- Whether the API sits behind its own CloudFront distribution or is called directly via the API Gateway invoke URL (custom domain on API Gateway is the cleaner option now that the domain is settled).
- Angular CDK drag-drop wiring for arbitrarily nested boxes (recursive component).
- Whether future projects live as `*.spiresen.com` subdomains or get entirely separate domains — decide before the second project starts, since it changes whether the wildcard ACM cert here gets reused.
- The multi-tenancy questions listed in `HANDOFF.md` (can a user have more than one Saga, is there still a platform-admin role distinct from Saga ownership, can Sagas be private).
