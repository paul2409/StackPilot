from fastapi import APIRouter

from src.db import ping_db

router = APIRouter()


@router.get("/health")
def health():
    return {"status": "ok", "service": "identity-service"}


@router.get("/ready")
def ready():
    if not ping_db():
        return {
            "status": "not_ready",
            "service": "identity-service",
            "dependency": "postgres-identity",
        }
    return {
        "status": "ready",
        "service": "identity-service",
        "dependency": "postgres-identity",
    }