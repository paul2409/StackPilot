from fastapi import APIRouter

from src.clients import identity_client, wallet_client, system_client
from src.observability import mark_ready, record_dependency_unready

router = APIRouter()


@router.get("/ready")
def ready():
    dependencies = {
        "identity-service": "unknown",
        "wallet-service": "unknown",
        "system-service": "unknown",
    }

    all_ready = True

    try:
        identity = identity_client.ready()
        dependencies["identity-service"] = identity.get("status", "unknown")
        if identity.get("status") != "ready":
            record_dependency_unready("identity-service")
            all_ready = False
    except Exception:
        dependencies["identity-service"] = "down"
        record_dependency_unready("identity-service")
        all_ready = False

    try:
        wallet = wallet_client.ready()
        dependencies["wallet-service"] = wallet.get("status", "unknown")
        if wallet.get("status") != "ready":
            record_dependency_unready("wallet-service")
            all_ready = False
    except Exception:
        dependencies["wallet-service"] = "down"
        record_dependency_unready("wallet-service")
        all_ready = False

    try:
        system = system_client.ready()
        dependencies["system-service"] = system.get("status", "unknown")
        if system.get("status") != "ready":
            record_dependency_unready("system-service")
            all_ready = False
    except Exception:
        dependencies["system-service"] = "down"
        record_dependency_unready("system-service")
        all_ready = False

    mark_ready(all_ready)
    return {
        "status": "ready" if all_ready else "not_ready",
        "service": "ops-portal",
        "dependencies": dependencies,
    }
