from fastapi import APIRouter

from src.db import ping_db
from src.observability import mark_ready, record_identity_db_failure

router = APIRouter()


@router.get("/health")
def health():
    return {"status": "ok", "service": "identity-service"}


@router.get("/ready")
def ready():
    if not ping_db():
        mark_ready(False)
        record_identity_db_failure()
        return {
            "status": "not_ready",
            "service": "identity-service",
            "dependency": "postgres-identity",
        }
    mark_ready(True)
    return {
        "status": "ready",
        "service": "identity-service",
        "dependency": "postgres-identity",
    }
