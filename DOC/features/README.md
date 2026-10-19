# Feature plans

One folder per feature, written before the feature's first sub-branch is built (ADR-009). The specs in `DOC/specs/` say what the product does. A feature folder says which of those rows this feature delivers, how it is built, and how each row is proven.

| File | What it holds | Template | Reviewed by |
|---|---|---|---|
| `manifest.md` | The spec rows the feature delivers, per sub-branch, and the rows it leaves to others | `DOC/templates/feature_manifest_template.md` | The owner |
| `design.md` | The design per layer: architecture, modules and call sequences, API contract, UI elements, with Mermaid diagrams. Every element has an ID like `57-B3` and a source | `DOC/templates/feature_design_template.md` | `plan-reviewer`, when an element is in a sensitive area |
| `tests.md` | One planned test per behaviour, with its level and name | `DOC/templates/feature_test_plan_template.md` | Together with the design |

Folder name: `<issue>-<slug>`, matching the feature branch, for example `57-foundation`.

How to write one, step by step: `DOC/guides/using_coding_agents.md`, step 3.
