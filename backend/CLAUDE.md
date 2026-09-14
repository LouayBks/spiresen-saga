# backend/

FastAPI app (Mangum on Lambda). Vertical-slice layout (ADR-001): each feature gets its own
directory under `app/` with its own `APIRouter` (CC-27) — `health/` is the first, minimal slice.

- Format/lint/type-check: `ruff format`, `ruff check`, `pyright --strict` — see
  `../DOC/architecture/clean_code_rules.md` (CC-1..33) for the full rule set, `pyproject.toml`
  for the actual config.
- Tests: `pytest` (integration-first, `TestClient` hitting the real route — TS-1). See
  `../DOC/architecture/testing_strategy.md` for the full strategy.
- Run locally: `uvicorn app.main:app --reload` (from `backend/`, with `.venv` active).
- New route/slice checklist: separate Create/Update/Read Pydantic models (CC-9), collaborators as
  `Depends()` params so tests can override them (TS-3), errors via `HTTPException` or the
  centralized handler in `app/main.py` (CC-18) — not scattered per-route try/except.
