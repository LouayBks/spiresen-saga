"""FastAPI app assembly and the Lambda entry point (via Mangum)."""

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from mangum import Mangum

from app.health.router import router as health_router

app = FastAPI(title="Saga API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:4200"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(Exception)
def handle_unexpected_error(_request: Request, exc: Exception) -> JSONResponse:
    """Centralize unhandled-exception responses (CC-18) instead of per-route try/except."""
    return JSONResponse(status_code=500, content={"detail": str(exc)})


app.include_router(health_router)

handler = Mangum(app)
