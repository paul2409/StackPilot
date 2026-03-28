from fastapi import APIRouter

from src.db import ping_db

router = APIRouter()


@router.get("/health")
def health():
    return {"status": "ok", "service": "wallet-service"}


@router.get("/ready")
def ready():
    if not ping_db():
        return {
            "status": "not_ready",
            "service": "wallet-service",
            "dependency": "postgres-wallet",
        }
    return {
        "status": "ready",
        "service": "wallet-service",
        "dependency": "postgres-wallet",
    }