from fastapi import APIRouter

from src.clients import identity_client, wallet_client
from src.observability import mark_ready, record_dependency_unready

router = APIRouter()


@router.get("/ready")
def ready():
    results = {
        "identity-service": "unknown",
        "wallet-service": "unknown",
    }

    all_ready = True

    try:
        identity_ready = identity_client.get_ready()
        results["identity-service"] = identity_ready.get("status", "unknown")
        if identity_ready.get("status") != "ready":
            record_dependency_unready("identity-service")
            all_ready = False
    except Exception:
        results["identity-service"] = "down"
        record_dependency_unready("identity-service")
        all_ready = False

    try:
        wallet_ready = wallet_client.get_ready()
        results["wallet-service"] = wallet_ready.get("status", "unknown")
        if wallet_ready.get("status") != "ready":
            record_dependency_unready("wallet-service")
            all_ready = False
    except Exception:
        results["wallet-service"] = "down"
        record_dependency_unready("wallet-service")
        all_ready = False

    mark_ready(all_ready)
    return {
        "status": "ready" if all_ready else "not_ready",
        "service": "system-service",
        "dependencies": results,
    }
