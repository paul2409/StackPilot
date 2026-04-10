from fastapi import APIRouter

from src.clients import wallet_client, system_client
from src.observability import mark_ready, record_dependency_unready

router = APIRouter()


@router.get("/health")
def health():
    return {"status": "ok", "service": "admin-portal"}


@router.get("/ready")
def ready():
    deps = {
        "wallet-service": "unknown",
        "system-service": "unknown",
    }
    all_ready = True

    try:
        w = wallet_client.ready()
        deps["wallet-service"] = w.get("status")
        if w.get("status") != "ready":
            record_dependency_unready("wallet-service")
            all_ready = False
    except Exception:
        deps["wallet-service"] = "down"
        record_dependency_unready("wallet-service")
        all_ready = False

    try:
        s = system_client.ready()
        deps["system-service"] = s.get("status")
        if s.get("status") != "ready":
            record_dependency_unready("system-service")
            all_ready = False
    except Exception:
        deps["system-service"] = "down"
        record_dependency_unready("system-service")
        all_ready = False

    mark_ready(all_ready)
    return {
        "status": "ready" if all_ready else "not_ready",
        "dependencies": deps,
    }
