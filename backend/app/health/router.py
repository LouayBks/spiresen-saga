"""Health-check route, used to verify the deployed stack is alive."""

from fastapi import APIRouter

router = APIRouter(prefix="/health", tags=["health"])


@router.get("")
def get_health() -> dict[str, str]:
    """Report that the API is up."""
    return {"status": "ok"}
