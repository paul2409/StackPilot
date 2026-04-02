from fastapi import APIRouter

from src.db import ping_db
from src.observability import mark_ready, record_wallet_db_failure, record_wallet_db_ok

router = APIRouter()


@router.get("/health")
def health():
    return {"status": "ok", "service": "wallet-service"}


@router.get("/ready")
def ready():
    if not ping_db():
        mark_ready(False)
        record_wallet_db_failure()
        return {
            "status": "not_ready",
            "service": "wallet-service",
            "dependency": "postgres-wallet",
        }
    mark_ready(True)
    record_wallet_db_ok()
    return {
        "status": "ready",
        "service": "wallet-service",
        "dependency": "postgres-wallet",
    }
