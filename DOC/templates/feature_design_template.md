# Feature design template (ADR-009 FP-4)

The design says **how** the feature is built, layer by layer, before any code exists. Each design element is its own `###` heading with an ID, so that sub-branch plans, code, tests (and the rabbit hop trial's build cards) can cite it, and tools can cut it out of the file.

Save as `DOC/features/<issue>-<slug>/design.md`. Keep only the layers the feature touches. If any element is in a sensitive area (access control, cross-Map checks, multi-item writes), `plan-reviewer` reviews this file before the first sub-branch plan (FP-7).

**Element IDs:** `<issue>-<layer><n>`, with layer `I` (infra), `B` (backend) or `F` (frontend). Example: `57-B3`. Never reuse a number, even if an element is dropped.

**Every element states its source:** a manifest row, a spec row, an ADR rule, or `decided here`, followed by the reason. A decision with no source is the thing review looks for.

**Diagrams are Mermaid** (FP-10), in a fenced `mermaid` block inside the element they illustrate. The examples below are indented only so they display inside this template; in your `design.md`, start the ` ```mermaid ` line at the left margin.

---

```markdown
# <issue> — <feature name>: design

**Manifest:** [manifest.md](manifest.md)  ·  **Plan depth:** light | full

## Infra

### <issue>-I1 — <resource or group>

- **Source:** <manifest row / spec / ADR / decided here: reason>
- **Resources:** <what Terraform creates, in which module>
- **Permissions:** <IAM actions granted, to whom, on which ARN; and what is deliberately not granted>
- **Outputs:** <names and values handed to the backend: table name, env vars>

    ```mermaid
    flowchart LR
      Lambda[api Lambda] -->|Query, TransactWriteItems| Table[(DynamoDB table)]
    ```

## Backend

### <issue>-B1 — Module structure

- **Source:** <…>
- **Modules:** <files in the slice and what each owns>
- **Allowed dependencies:** <which module may import which; anything else is a defect>

    ```mermaid
    classDiagram
      class router
      class repository
      router --> repository
    ```

### <issue>-B2 — <METHOD /path>

- **Source:** <manifest rows it implements>
- **Request:** <body / params, with types and limits>
- **Response:** <status codes and bodies, including every error>
- **Data access:** <access patterns used; items read and written; which writes are one transaction and which conditions they check>
- **Sensitive:** <none | access control | cross-Map | multi-item write>

    ```mermaid
    sequenceDiagram
      participant C as Client
      participant R as Router
      participant P as Repository
      participant D as DynamoDB
      C->>R: POST /path
      R->>P: create(...)
      P->>D: TransactWriteItems (n items)
      D-->>P: ok
      P-->>R: entity
      R-->>C: 201
    ```

## Frontend

### <issue>-F1 — <component>

- **Source:** <manifest rows; mockup in DOC/frontend/…>
- **States:** <empty, loading, error, populated…: what is shown in each>
- **Interactions:** <user action → effect → API call (cite the B element)>
- **Animations:** <trigger, property, duration, easing; or none>

    ```mermaid
    stateDiagram-v2
      [*] --> Loading
      Loading --> Ready
      Loading --> Error
    ```
```

---

## What review looks for

- **Responsibilities:** each module or component has one job, and no two elements do the same thing.
- **Dependencies:** nothing imports across the boundaries stated in the module diagram.
- **Sequences:** no loop of calls where one query would do, and no extra round trips. A Map load stays one `Query` (CON-4 of `alternate-views`).
- **Contracts:** every frontend call matches a backend element exactly; every error has a frontend state.
- **Permissions:** least privilege, and nothing granted "for later".
- **Sources:** every element says where it came from.
